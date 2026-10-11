import 'dart:async';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/daily_goal.dart' show recordDailyAnswer;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../evidence_input/evidence_question_view.dart';
import '../exam_data/current_level.dart';
import '../exam_data/exam_data_cache.dart';
import '../journal_input/account_catalog.dart';
import '../journal_input/journal_question_view.dart';
import '../ledger_input/ledger_question_view.dart';
import '../progress/progress_revision.dart';
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
  });

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

  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadSession();
  }

  Future<PracticeSession> _loadSession() async {
    final questions = await loadQuestions();
    final restrict = widget.restrictToQids;
    final subjectId = widget.subjectId;

    // levelId が null の問題は全levelで共通利用。levelId が指定されている問題
    // （例: 旧区分表〈level3_until_2027_03〉専用の手形問題）は、現在の試験区分と
    // 一致するものだけを出す。復習（restrictToQids指定）は、過去の出題当時の
    // 問題をそのまま見られるよう、この絞り込みを行わない。
    final levelId = currentLevelId(now: widget.now);
    final byLevel = questions.where((q) => q.levelId == null || q.levelId == levelId);

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

    return PracticeSession(pool: pool, size: pool.length, priorityQids: priority);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? (widget.restrictToQids == null ? '問題を練習する' : '間違えた問題を復習する'),
        ),
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
            );
          },
        ),
      ),
    );
  }
}

class _SessionBody extends ConsumerStatefulWidget {
  const _SessionBody({required this.session, required this.progressStore, this.priorityCount = 0});

  final PracticeSession session;
  final ProgressStore progressStore;

  /// 間隔反復で優先出題している問題数（先頭から何問分か）。
  final int priorityCount;

  @override
  ConsumerState<_SessionBody> createState() => _SessionBodyState();
}

class _SessionBodyState extends ConsumerState<_SessionBody> {
  void _recordProgress(String qid, String subjectId, {required bool correct}) {
    unawaited(recordDailyAnswer(ref));
    unawaited(
      widget.progressStore
          .addRecord(
            ProgressRecord(qid: qid, subjectId: subjectId, correct: correct, at: DateTime.now()),
          )
          .then((_) {
            progressRevision.value++;
            unawaited(recordStudyToday());
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final current = session.current;
    if (current == null) {
      return _ResultView(session: session, progressStore: widget.progressStore);
    }
    final isPriorityQuestion = session.index < widget.priorityCount;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${session.index + 1} / ${session.questions.length}問目',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (isPriorityQuestion) ...[
                const SizedBox(width: 8),
                Icon(Icons.replay, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 2),
                Text(
                  '苦手な問題を復習中',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ],
              const Spacer(),
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
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: QuestionMemoField(key: ValueKey(qid), qid: qid),
      ),
    );
  }

  Widget _buildQuestion(Question current, PracticeSession session) {
    switch (current.type) {
      case QuestionType.journal:
        final voucherKind = voucherKindOfTopic(current.topicId);
        void onJournalAnswered(JournalJudgeResult result, List<JournalLine> lines) {
          session.answerJournal(lines);
          _recordProgress(current.qid, current.subjectId, correct: result.isCorrect);
        }
        if (voucherKind != null) {
          return VoucherQuestionView(
            key: ValueKey(current.qid),
            prompt: current.prompt,
            correctAnswer: current.journalAnswer!,
            kind: voucherKind,
            explanation: current.explanation,
            onAnswered: onJournalAnswered,
            onNext: () => setState(() {}),
          );
        }
        if (current.topicId == 'voucher_reading') {
          return EvidenceQuestionView(
            key: ValueKey(current.qid),
            prompt: current.prompt,
            correctAnswer: current.journalAnswer!,
            explanation: current.explanation,
            onAnswered: onJournalAnswered,
            onNext: () => setState(() {}),
          );
        }
        return JournalQuestionView(
          key: ValueKey(current.qid),
          prompt: current.prompt,
          correctAnswer: current.journalAnswer!,
          explanation: current.explanation,
          onAnswered: onJournalAnswered,
          onNext: () => setState(() {}),
          accountPool: current.levelId == 'level3_until_2027_03' ? boki3AccountsLegacy : boki3Accounts,
        );
      case QuestionType.choice:
        return HandsFreeChoiceQuestion(
          key: ValueKey(current.qid),
          prompt: current.prompt,
          choices: current.choices,
          answerIndex: current.answerIndex,
          explanation: current.explanation,
          onAnswered: (selectedIndex, correct) {
            session.answer(selectedIndex);
            _recordProgress(current.qid, current.subjectId, correct: correct);
          },
          onNext: () => setState(() {}),
        );
      case QuestionType.worksheet:
        return WorksheetQuestionView(
          key: ValueKey(current.qid),
          prompt: current.prompt,
          correctAnswer: current.worksheetAnswer!,
          explanation: current.explanation,
          onAnswered: (result, cells) {
            session.answerWorksheet(cells);
            _recordProgress(current.qid, current.subjectId, correct: result.isCorrect);
          },
          onNext: () => setState(() {}),
        );
      case QuestionType.ledger:
        return LedgerQuestionView(
          key: ValueKey(current.qid),
          prompt: current.prompt,
          correctAnswer: current.ledgerAnswer!,
          explanation: current.explanation,
          onAnswered: (result, cells) {
            session.answerLedger(cells);
            _recordProgress(current.qid, current.subjectId, correct: result.isCorrect);
          },
          onNext: () => setState(() {}),
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
      child: ResultSummary(
        correct: correct,
        total: total,
        onRetry: wrongQids.isEmpty
            ? null
            : () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => PracticePage(progressStore: progressStore, restrictToQids: wrongQids),
                  ),
                ),
        retryLabel: '間違えた${wrongQids.length}問を復習する',
        onClose: () => Navigator.of(context).pop(),
        closeLabel: '戻る',
      ),
    );
  }
}
