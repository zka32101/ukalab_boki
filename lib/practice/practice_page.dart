import 'dart:async';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/answer_feedback.dart' show AnswerFeedbackPanel, readingsForQuestion;
import '../oshi/boki3_coin_earn.dart';
import 'package:ukalab_core/daily_goal.dart' show recordDailyAnswer;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_core/learning.dart';

import '../common/wrapping_app_bar.dart';
import '../evidence_input/evidence_question_view.dart';
import '../exam_data/current_level.dart';
import '../exam_data/exam_data_cache.dart';
import '../exam_data/feature_flags.dart';
import '../journal_input/account_catalog.dart';
import '../journal_input/journal_question_view.dart';
import '../ledger_input/ledger_question_view.dart';
import '../progress/progress_revision.dart';
import '../reading/reading_list_page.dart' show ReadingDetailPage;
import '../progress/progress_store.dart' show attachCause, markLatestCorrect;
import '../review/review_schedule.dart' show recordReviewResult;
import '../voucher_input/voucher_kind.dart';
import '../voucher_input/voucher_question_view.dart';
import '../worksheet_input/worksheet_question_view.dart';
import '../hands_free/hands_free_choice_question.dart';

/// `assets/exam/boki3.questions.jsonl` の問題（type: journal・choice・worksheet）を
/// [PracticeSession] で順に出題する画面。問題データのロード・パース・品質ゲート
/// （出典必須・貸借一致など）は `test/questions_data_test.dart` で
/// 別途検証済みのため、ここではロード失敗のみハンドリングする。
class PracticePage extends StatefulWidget {
  const PracticePage({
    super.key,
    required this.progressStore,
    this.restrictToQids,
    this.subjectId,
    this.title,
    this.now,
    this.questionsOverride,
    this.newTypesEnabled = kNewQuestionTypesEnabled,
    this.readingProtoEnabled = kReadingExplanationProtoEnabled,
    this.readingsOverride,
  });

  /// 【試作】誤答時に関連する読み物へ誘導する（`AnswerFeedbackPanel.relatedReadings`）。
  /// 既定は [kReadingExplanationProtoEnabled]。false のときは従来のフィードバックのまま。
  final bool readingProtoEnabled;

  /// テスト用: 指定すると読み物データのロードの代わりにこの読み物群を使う。
  @visibleForTesting
  final List<ChapterReading>? readingsOverride;

  /// テスト用: 指定すると問題データのロードの代わりにこの問題群を使う。
  @visibleForTesting
  final List<Question>? questionsOverride;

  /// 新3タイプ（○×・空欄補充・説明から用語）を解答させるか。既定は
  /// [kNewQuestionTypesEnabled]。false のときは新タイプを出題プールから除く。
  final bool newTypesEnabled;

  /// 解答記録の保存先（ホーム画面の科目別正答率に反映される）。
  final ProgressStore progressStore;

  /// 非null なら、全問題の中からこの qid 集合に含まれる問題だけを出題する
  /// （「間違えた問題を復習する」から開くとき用）。[subjectId] と同時には使わない。
  /// 指定時は [now] による出題範囲（levelId）の絞り込みを行わない
  /// （復習は過去の出題当時の問題をそのまま見られるようにするため）。
  final Set<String>? restrictToQids;

  /// 非null なら、この科目（`ExamConfig.subjects` の `subjectId`）の問題だけを
  /// 出題する（「学ぶ」タブの科目別練習から開くとき用）。
  final String? subjectId;

  /// AppBarのタイトル。省略時は [restrictToQids] の有無から自動で決める。
  final String? title;

  /// テスト用の時刻注入（省略時は現在時刻）。`currentLevelId` に渡し、
  /// 出題範囲を現在の試験区分（`levelId`）に絞り込む。
  final DateTime? now;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  late Future<PracticeSession> _sessionFuture;

  /// 直近の解答記録から優先的に出題した問題数（間隔反復）。0ならUIに出さない。
  int _priorityCount = 0;

  /// 【試作】誤答時に出す関連読み物の候補（[PracticePage.readingProtoEnabled] が true のときだけ読む）。
  List<ChapterReading> _readings = const [];

  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadSession();
  }

  Future<PracticeSession> _loadSession() async {
    final questions = widget.questionsOverride != null
        ? filterByNewQuestionTypes(widget.questionsOverride!,
            enabled: widget.newTypesEnabled)
        : await loadQuestions();
    if (widget.readingProtoEnabled) {
      _readings = widget.readingsOverride ?? await loadChapterReadings();
    }
    final restrict = widget.restrictToQids;
    final subjectId = widget.subjectId;

    // levelId が null の問題は全levelで共通利用。levelId が指定されている問題
    // （例: 旧区分表〈level3_until_2027_03〉専用の手形問題）は、現在の試験区分と
    // 一致するものだけを出す。復習（restrictToQids指定）は、過去の出題当時の
    // 問題をそのまま見られるよう、この絞り込みを行わない。
    final levelId = currentLevelId(now: widget.now);
    final byLevel =
        questions.where((q) => q.levelId == null || q.levelId == levelId);

    final pool = restrict != null
        ? questions.where((q) => restrict.contains(q.qid)).toList()
        : subjectId != null
            ? byLevel.where((q) => q.subjectId == subjectId).toList()
            : byLevel.toList();

    // 直近の解答で不正解のまま放置されている問題（間隔反復の「期限切れ」相当）を
    // 先頭に優先出題する。`PracticeSession` 側は、対象の qid が pool になければ
    // 無視するので、ここでの絞り込みは厳密でなくてよい。
    final records = await widget.progressStore.loadRecords();
    final priority = reviewPriorityQids(records);
    final poolQids = {for (final q in pool) q.qid};
    _priorityCount = priority.where(poolQids.contains).length;

    return PracticeSession(
        pool: pool, size: pool.length, priorityQids: priority);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: wrappingAppBar(
        context,
        widget.title ??
            (widget.restrictToQids == null ? '問題を練習する' : '間違えた問題を復習する'),
      ),
      body: SafeArea(
        child: FutureBuilder<PracticeSession>(
          future: _sessionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('読み込みに失敗しました: ${snapshot.error}'));
            }
            return _SessionBody(
              session: snapshot.data!,
              progressStore: widget.progressStore,
              priorityCount: _priorityCount,
              newTypesEnabled: widget.newTypesEnabled,
              readings: _readings,
              onOpenReading: !widget.readingProtoEnabled
                  ? null
                  : (r) => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReadingDetailPage(
                            reading: r,
                            progressStore: widget.progressStore,
                            protoEnabled: true,
                          ),
                        ),
                      ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionBody extends ConsumerStatefulWidget {
  const _SessionBody({
    required this.session,
    required this.progressStore,
    this.priorityCount = 0,
    this.newTypesEnabled = false,
    this.readings = const [],
    this.onOpenReading,
  });

  /// 【試作】誤答時に関連づける読み物。空・[onOpenReading] が null なら導線は出ない。
  final List<ChapterReading> readings;
  final ValueChanged<ChapterReading>? onOpenReading;

  final bool newTypesEnabled;

  final PracticeSession session;
  final ProgressStore progressStore;

  /// 間隔反復で優先出題している問題数（先頭から何問分か）。
  final int priorityCount;

  @override
  ConsumerState<_SessionBody> createState() => _SessionBodyState();
}

class _SessionBodyState extends ConsumerState<_SessionBody> {
  /// 解答済みで「次の問題へ」待ちの問題。[PracticeSession.current] は解答を記録した
  /// 時点で次の問題へ進むため、解答直後に親の再描画などでこの画面が組み直されても、
  /// 解答した問題の解説・正誤を出し続けるよう、解答した問題を保持して描く。
  Question? _answered;

  void _next() => setState(() => _answered = null);

  void _recordProgress(String qid, String subjectId, {required bool correct}) {
    unawaited(recordDailyAnswer(ref));
    final coins = coinNotifierOrNull(ref);
    final now = DateTime.now();
    unawaited(
      widget.progressStore
          .addRecord(
        ProgressRecord(
            qid: qid, subjectId: subjectId, correct: correct, at: now),
      )
          .then((_) async {
        // 「今日の復習」の期限に来ている問題なら結果を反映する（履歴と同じ時刻で）。
        await recordReviewResult(qid, correct: correct, now: now);
        progressRevision.value++;
        await recordStudyToday();
        // 初めて解く問題なら学習コイン（失敗しても学習は止めない）。
        await earnAnswerCoin(coins, qid);
      }),
    );
  }

  /// 次の問題へ進む。最後の問題だったら、結果表示のタイミングで全画面広告を出す。
  void _afterNext() {
    _next();
    if (widget.session.current == null) {
      unawaited(ref.read(adGateProvider).maybeShowInterstitial(InterstitialTrigger.sessionEnd));
    }
  }

  /// 自由入力の打ち間違いを本人の申告で正解に直す（履歴・復習予定も補正）。
  void _selfReport(String qid) {
    widget.session.markLastSelfReportedCorrect();
    final now = DateTime.now();
    unawaited(
      markLatestCorrect(widget.progressStore, qid).then((_) async {
        await recordReviewResult(qid, correct: true, now: now);
        progressRevision.value++;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final current = _answered ?? session.current;
    if (current == null) {
      return _ResultView(session: session, progressStore: widget.progressStore);
    }
    // 解答済みなら session.index は既に次の問題を指すので、1つ戻して表示中の問題の番号にする。
    final shownIndex = _answered != null ? session.index - 1 : session.index;
    final isPriorityQuestion = shownIndex < widget.priorityCount;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 問題番号と「苦手な問題を復習中」は、狭い幅・大きい文字では折り返して全部見せる。
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${shownIndex + 1} / ${session.questions.length}問目',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (isPriorityQuestion)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.replay,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '苦手な問題を復習中',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'メモ',
                icon: const Icon(Icons.sticky_note_2_outlined),
                onPressed: () => _showMemo(context, current.qid),
              ),
              BookmarkToggleButton(qid: current.qid),
            ],
          ),
        ),
        Expanded(child: _buildQuestion(current, session)),
      ],
    );
  }

  /// 問題の形式（仕訳・帳簿・精算表など）に依らず書けるよう、メモは下からのシートで開く。
  void _showMemo(BuildContext context, String qid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: QuestionMemoField(key: ValueKey(qid), qid: qid),
      ),
    );
  }

  /// core の新形式画面は縦に伸びる Column なので、スクロールできる枠で包む。
  Widget _scrollable(Widget child) =>
      SingleChildScrollView(padding: const EdgeInsets.all(16), child: child);

  Widget _buildQuestion(Question current, PracticeSession session) {
    switch (current.type) {
      case QuestionType.journal:
        final voucherKind = voucherKindOfTopic(current.topicId);
        void onJournalAnswered(
            JournalJudgeResult result, List<JournalLine> lines) {
          _answered = current;
          session.answerJournal(lines);
          _recordProgress(current.qid, current.subjectId,
              correct: result.isCorrect);
        }
        if (voucherKind != null) {
          return VoucherQuestionView(
            key: ValueKey(current.qid),
            prompt: current.prompt,
            correctAnswer: current.journalAnswer!,
            kind: voucherKind,
            explanation: current.explanation,
            onAnswered: onJournalAnswered,
            onNext: _afterNext,
          );
        }
        if (current.topicId == 'voucher_reading') {
          return EvidenceQuestionView(
            key: ValueKey(current.qid),
            prompt: current.prompt,
            correctAnswer: current.journalAnswer!,
            explanation: current.explanation,
            onAnswered: onJournalAnswered,
            onNext: _afterNext,
          );
        }
        return JournalQuestionView(
          key: ValueKey(current.qid),
          prompt: current.prompt,
          correctAnswer: current.journalAnswer!,
          explanation: current.explanation,
          onAnswered: onJournalAnswered,
          onNext: _afterNext,
          accountPool: current.levelId == 'level3_until_2027_03'
              ? boki3AccountsLegacy
              : boki3Accounts,
        );
      case QuestionType.choice:
        return HandsFreeChoiceQuestion(
          key: ValueKey(current.qid),
          prompt: current.prompt,
          choices: current.choices,
          answerIndex: current.answerIndex,
          explanation: current.explanation,
          onAnswered: (selectedIndex, correct) {
            _answered = current;
            session.answer(selectedIndex);
            _recordProgress(current.qid, current.subjectId, correct: correct);
          },
          onNext: _afterNext,
          // 選択式には独自の誤答診断が無いので、共通の原因ラベル・対策で補う。
          // 仕訳・帳簿・精算表は結果バナーの行ごとの診断があるため、重ねて出さない。
          feedbackBuilder: (selectedIndex) => AnswerFeedbackPanel(
            key: ValueKey('feedback-${current.qid}'),
            question: current,
            selectedIndex: selectedIndex,
            includeCalculation: false,
            relatedReadings: widget.onOpenReading == null
                ? const []
                : readingsForQuestion(widget.readings, current.qid),
            onOpenReading: widget.onOpenReading,
            onCause: (c) =>
                unawaited(attachCause(widget.progressStore, current.qid, c)),
          ),
        );
      case QuestionType.worksheet:
        return WorksheetQuestionView(
          key: ValueKey(current.qid),
          prompt: current.prompt,
          correctAnswer: current.worksheetAnswer!,
          explanation: current.explanation,
          onAnswered: (result, cells) {
            _answered = current;
            session.answerWorksheet(cells);
            _recordProgress(current.qid, current.subjectId,
                correct: result.isCorrect);
          },
          onNext: _afterNext,
        );
      case QuestionType.ledger:
        return LedgerQuestionView(
          key: ValueKey(current.qid),
          prompt: current.prompt,
          correctAnswer: current.ledgerAnswer!,
          explanation: current.explanation,
          onAnswered: (result, cells) {
            _answered = current;
            session.answerLedger(cells);
            _recordProgress(current.qid, current.subjectId,
                correct: result.isCorrect);
          },
          onNext: _afterNext,
        );
      case QuestionType.trueFalse:
        if (!widget.newTypesEnabled) return const SizedBox.shrink();
        return _scrollable(
          TrueFalseQuestionView(
          key: ValueKey(current.qid),
          question: current,
          onAnswered: (r) {
            _answered = current;
            session.answerTrueFalse(r.boolAnswer ?? false);
            _recordProgress(current.qid, current.subjectId, correct: r.correct);
          },
          onCause: (c) =>
              unawaited(attachCause(widget.progressStore, current.qid, c)),
          onNext: _afterNext,
          ),
        );
      case QuestionType.cloze:
        if (!widget.newTypesEnabled) return const SizedBox.shrink();
        return _scrollable(
          ClozeQuestionView(
          key: ValueKey(current.qid),
          question: current,
          onAnswered: (r) {
            _answered = current;
            session.answerCloze(r.blankAnswers ?? const {});
            _recordProgress(current.qid, current.subjectId, correct: r.correct);
          },
          onSelfReported: () => _selfReport(current.qid),
          onCause: (c) =>
              unawaited(attachCause(widget.progressStore, current.qid, c)),
          onNext: _afterNext,
          ),
        );
      case QuestionType.reverseLookup:
        if (!widget.newTypesEnabled) return const SizedBox.shrink();
        return _scrollable(
          ReverseLookupQuestionView(
          key: ValueKey(current.qid),
          question: current,
          onAnswered: (r) {
            _answered = current;
            session.answerReverseLookup(r.text ?? '');
            _recordProgress(current.qid, current.subjectId, correct: r.correct);
          },
          onSelfReported: () => _selfReport(current.qid),
          onCause: (c) =>
              unawaited(attachCause(widget.progressStore, current.qid, c)),
          onNext: _afterNext,
          ),
        );
    }
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.session, required this.progressStore});

  final PracticeSession session;
  final ProgressStore progressStore;

  @override
  Widget build(BuildContext context) {
    final total = session.questions.length;
    final correct = session.correctCount;
    final wrongQids = {
      for (final r in session.records)
        if (!r.correct) r.qid,
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ResultSummary(
        correct: correct,
        total: total,
        onRetry: wrongQids.isEmpty
            ? null
            : () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => PracticePage(
                        progressStore: progressStore,
                        restrictToQids: wrongQids),
                  ),
                ),
        retryLabel: '間違えた${wrongQids.length}問を復習する',
        onClose: () => Navigator.of(context).pop(),
        closeLabel: '戻る',
      ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) => ref.watch(adGateProvider).banner(BannerPlacement.result),
            ),
          ],
        ),
      ),
    );
  }
}
