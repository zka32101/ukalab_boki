import 'dart:async';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../oshi/boki3_coin_earn.dart';
import 'package:ukalab_core/ui.dart' show MockExamAnalysisCard;
import 'package:ukalab_core/ukalab_core.dart';

import '../common/wrapping_app_bar.dart';
import '../evidence_input/evidence_question_view.dart';
import '../exam_data/current_level.dart';
import '../exam_data/exam_data_cache.dart';
import '../journal_input/account_catalog.dart';
import '../journal_input/journal_question_view.dart';
import '../ledger_input/ledger_question_view.dart';
import '../practice/choice_question_view.dart';
import '../practice/practice_page.dart';
import '../progress/progress_revision.dart';
import '../voucher_input/voucher_kind.dart';
import '../voucher_input/voucher_question_view.dart';
import '../worksheet_input/worksheet_question_view.dart';
import 'mock_exam_review_page.dart';

/// 本試験の形式（出題数・制限時間・配点）で1回通しで解き、最後にまとめて
/// 採点する模擬試験モード。[PracticePage]（`lib/practice/`）と異なり、
/// 解答中は正誤を表示しない（本試験では分からないため）。
class MockExamPage extends StatefulWidget {
  const MockExamPage({super.key, required this.progressStore, this.now});

  /// 解答記録の保存先（ホーム画面の科目別正答率に反映される）。
  final ProgressStore progressStore;

  /// 新旧配点levelの切り替え判定に使う「現在時刻」（テスト用。省略時は実際の現在時刻）。
  final DateTime? now;

  @override
  State<MockExamPage> createState() => _MockExamPageState();
}

class _MockExamPageState extends State<MockExamPage> {
  late Future<_MockExamData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_MockExamData> _load() async {
    final exam = await loadExamConfig();
    final levelId = currentLevelId(now: widget.now);
    final level = exam.level(levelId);
    if (level == null) {
      throw StateError('$levelId が見つかりません');
    }

    final questions = await loadQuestions();
    // 問題データの levelId は null（全levelで共通利用）のため、null か
    // 現在のlevelに一致するものを出題プールにする。
    final pool = questions.where((q) => q.levelId == null || q.levelId == level.levelId);

    return _MockExamData(exam: exam, level: level, pool: pool.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: wrappingAppBar(context, '模擬試験'),
      body: SafeArea(
        child: FutureBuilder<_MockExamData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('読み込みに失敗しました: ${snapshot.error}'));
            }
            return _MockExamBody(data: snapshot.data!, progressStore: widget.progressStore);
          },
        ),
      ),
    );
  }
}

class _MockExamData {
  const _MockExamData({required this.exam, required this.level, required this.pool});

  final ExamConfig exam;
  final LevelConfig level;
  final List<Question> pool;
}

enum _MockExamStage { intro, running, result }

class _MockExamBody extends ConsumerStatefulWidget {
  const _MockExamBody({required this.data, required this.progressStore});

  final _MockExamData data;
  final ProgressStore progressStore;

  @override
  ConsumerState<_MockExamBody> createState() => _MockExamBodyState();
}

class _MockExamBodyState extends ConsumerState<_MockExamBody> {
  _MockExamStage _stage = _MockExamStage.intro;
  late List<Question> _questions;
  int _index = 0;
  final Map<String, Object?> _answers = {};
  Timer? _timer;
  int _remainingSec = 0;
  MockExamResult? _result;

  /// 制限時間切れのTimerと、最終問題での「次へ」がほぼ同時に発生すると
  /// `_finish()` が二重に走り、`addRecord` の読み込み→書き込みが競合して
  /// 記録が壊れる恐れがある。最初の呼び出しだけ処理するためのガード。
  bool _finishing = false;

  LevelConfig get _level => widget.data.level;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _questions = pickMockExamQuestions(pool: widget.data.pool, level: _level);
    _answers.clear();
    _index = 0;
    _remainingSec = _level.timeLimitSec ?? 0;
    setState(() => _stage = _MockExamStage.running);
    if (_level.timeLimitSec != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _remainingSec -= 1);
        if (_remainingSec <= 0) {
          _timer?.cancel();
          _finish();
        }
      });
    }
  }

  void _onJournalAnswered(String qid, List<JournalLine> lines) => _answers[qid] = lines;

  void _onChoiceAnswered(String qid, int selectedIndex) => _answers[qid] = selectedIndex;

  void _onWorksheetAnswered(String qid, List<WorksheetCell> cells) => _answers[qid] = cells;

  void _onLedgerAnswered(String qid, List<LedgerCell> cells) => _answers[qid] = cells;

  void _next() {
    if (_index + 1 >= _questions.length) {
      _finish();
    } else {
      setState(() => _index += 1);
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    final coins = coinNotifierOrNull(ref);
    final result = scoreMockExam(
      questions: _questions,
      answers: _answers,
      rule: _level.passRule,
    );
    // `SharedPreferencesProgressStore.addRecord` は読み込み→追記→書き込みを
    // 行うため、並行に呼ぶと互いの書き込みを上書きして記録が失われる。
    // 出題数ぶん（15件程度）を順番に await する。
    for (final q in _questions) {
      await widget.progressStore.addRecord(
        ProgressRecord(
          qid: q.qid,
          subjectId: q.subjectId,
          correct: _isCorrect(q, _answers[q.qid]),
          at: DateTime.now(),
        ),
      );
    }
    progressRevision.value++;
    await recordStudyToday();
    if (mounted) {
      setState(() {
        _result = result;
        _stage = _MockExamStage.result;
      });
    }
    // 模擬を終えたコイン（合格点以上なら合格コインも）。失敗しても結果表示は止めない。
    await earnMockCoins(coins, examId: widget.data.exam.examId, passed: result.passed);
    // 結果を見せたあとに全画面広告（頻度は AdGate が制限する）。
    if (mounted) {
      await ref.read(adGateProvider).maybeShowInterstitial(InterstitialTrigger.mockExamResult);
    }
  }

  /// `ukalab_core` の `scoreMockExam` が内部で使う正誤判定と同じロジック
  /// （非公開のため進捗記録用にここで再実装）。
  bool _isCorrect(Question q, Object? answer) {
    switch (q.type) {
      case QuestionType.choice:
        return answer is int && answer == q.answerIndex;
      case QuestionType.journal:
        final expected = q.journalAnswer;
        if (expected == null || answer is! List<JournalLine>) return false;
        return judgeJournal(expected, answer).isCorrect;
      case QuestionType.worksheet:
        final expected = q.worksheetAnswer;
        if (expected == null || answer is! List<WorksheetCell>) return false;
        return judgeWorksheet(expected, answer).isCorrect;
      case QuestionType.ledger:
        final expected = q.ledgerAnswer;
        if (expected == null || answer is! List<LedgerCell>) return false;
        return judgeLedger(expected, answer).isCorrect;
      case QuestionType.trueFalse:
      case QuestionType.cloze:
      case QuestionType.reverseLookup:
        return false; // 簿記コレは新タイプ未対応（データに含まれない）
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _MockExamStage.intro:
        return _MockExamIntroView(
          exam: widget.data.exam,
          level: _level,
          poolSize: widget.data.pool.length,
          onStart: _start,
        );
      case _MockExamStage.running:
        return _MockExamRunningView(
          index: _index,
          total: _questions.length,
          remainingSec: _remainingSec,
          question: _questions[_index],
          onJournalAnswered: _onJournalAnswered,
          onChoiceAnswered: _onChoiceAnswered,
          onWorksheetAnswered: _onWorksheetAnswered,
          onLedgerAnswered: _onLedgerAnswered,
          onNext: _next,
        );
      case _MockExamStage.result:
        return _MockExamResultView(
          exam: widget.data.exam,
          result: _result!,
          wrongQids: {
            for (final q in _questions)
              if (!_isCorrect(q, _answers[q.qid])) q.qid,
          },
          progressStore: widget.progressStore,
          questions: _questions,
          answers: _answers,
        );
    }
  }
}

class _MockExamIntroView extends StatelessWidget {
  const _MockExamIntroView({
    required this.exam,
    required this.level,
    required this.poolSize,
    required this.onStart,
  });

  final ExamConfig exam;
  final LevelConfig level;
  final int poolSize;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = level.timeLimitSec == null ? null : level.timeLimitSec! ~/ 60;
    // 狭い画面・大きい文字では縦に収まらないので、スクロールできるようにする（収まるときは従来どおり縦中央）。
    // 開始ボタンが画面外で押せなくならないようにする。
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(level.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text('出題数: ${level.questionCount}問', style: theme.textTheme.bodyLarge),
            if (minutes != null)
              Text('制限時間: $minutes分', style: theme.textTheme.bodyLarge),
            Text(
              '合格ライン: 総合${level.passRule.totalPct.toStringAsFixed(0)}%以上',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '本試験と同じく、解答中は正誤が表示されません。全問解き終えると結果がまとめて表示されます。',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            Text(
              '本試験（統一試験・ネット試験とも）では電卓を実機で持ち込んで使います。'
              'このアプリに電卓機能はないため、お手元の電卓を使って解いてみましょう。',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: poolSize < level.questionCount ? null : onStart,
              child: const Text('模擬試験を開始する'),
            ),
            if (poolSize < level.questionCount) ...[
              const SizedBox(height: 8),
              Text(
                '問題データが不足しているため開始できません（必要: ${level.questionCount}問 / 現在: $poolSize問）',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ))));
  }
}

class _MockExamRunningView extends StatelessWidget {
  const _MockExamRunningView({
    required this.index,
    required this.total,
    required this.remainingSec,
    required this.question,
    required this.onJournalAnswered,
    required this.onChoiceAnswered,
    required this.onWorksheetAnswered,
    required this.onLedgerAnswered,
    required this.onNext,
  });

  final int index;
  final int total;
  final int remainingSec;
  final Question question;
  final void Function(String qid, List<JournalLine> lines) onJournalAnswered;
  final void Function(String qid, int selectedIndex) onChoiceAnswered;
  final void Function(String qid, List<WorksheetCell> cells) onWorksheetAnswered;
  final void Function(String qid, List<LedgerCell> cells) onLedgerAnswered;
  final VoidCallback onNext;

  String get _timeLabel {
    final m = (remainingSec ~/ 60).clamp(0, 999);
    final s = (remainingSec % 60).clamp(0, 59);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('${index + 1} / $total問目', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '残り $_timeLabel',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: remainingSec <= 60 ? theme.colorScheme.error : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildQuestion(context)),
      ],
    );
  }

  Widget _buildQuestion(BuildContext context) {
    switch (question.type) {
      case QuestionType.journal:
        final voucherKind = voucherKindOfTopic(question.topicId);
        if (voucherKind != null) {
          return VoucherQuestionView(
            key: ValueKey(question.qid),
            prompt: question.prompt,
            correctAnswer: question.journalAnswer!,
            kind: voucherKind,
            revealResult: false,
            onAnswered: (_, lines) => onJournalAnswered(question.qid, lines),
            onNext: onNext,
          );
        }
        if (question.topicId == 'voucher_reading') {
          return EvidenceQuestionView(
            key: ValueKey(question.qid),
            prompt: question.prompt,
            correctAnswer: question.journalAnswer!,
            revealResult: false,
            onAnswered: (_, lines) => onJournalAnswered(question.qid, lines),
            onNext: onNext,
          );
        }
        return JournalQuestionView(
          key: ValueKey(question.qid),
          prompt: question.prompt,
          correctAnswer: question.journalAnswer!,
          revealResult: false,
          onAnswered: (_, lines) => onJournalAnswered(question.qid, lines),
          onNext: onNext,
          accountPool: question.levelId == 'level3_until_2027_03' ? boki3AccountsLegacy : boki3Accounts,
        );
      case QuestionType.choice:
        return ChoiceQuestionView(
          key: ValueKey(question.qid),
          prompt: question.prompt,
          choices: question.choices,
          answerIndex: question.answerIndex,
          revealResult: false,
          onAnswered: (selectedIndex, _) => onChoiceAnswered(question.qid, selectedIndex),
          onNext: onNext,
        );
      case QuestionType.worksheet:
        return WorksheetQuestionView(
          key: ValueKey(question.qid),
          prompt: question.prompt,
          correctAnswer: question.worksheetAnswer!,
          revealResult: false,
          onAnswered: (_, cells) => onWorksheetAnswered(question.qid, cells),
          onNext: onNext,
        );
      case QuestionType.ledger:
        return LedgerQuestionView(
          key: ValueKey(question.qid),
          prompt: question.prompt,
          correctAnswer: question.ledgerAnswer!,
          revealResult: false,
          onAnswered: (_, cells) => onLedgerAnswered(question.qid, cells),
          onNext: onNext,
        );
      case QuestionType.trueFalse:
      case QuestionType.cloze:
      case QuestionType.reverseLookup:
        return const SizedBox.shrink(); // 未対応タイプ（データに含まれない）
    }
  }
}

class _MockExamResultView extends StatelessWidget {
  const _MockExamResultView({
    required this.exam,
    required this.result,
    required this.wrongQids,
    required this.progressStore,
    required this.questions,
    required this.answers,
  });

  final ExamConfig exam;
  final MockExamResult result;

  /// 不正解だった問題の qid。「間違えた問題を復習する」から
  /// `PracticePage(restrictToQids: ...)` を開くのに使う。
  final Set<String> wrongQids;
  final ProgressStore progressStore;

  /// 「解答結果の詳細を見る」から `MockExamReviewPage` を開くのに使う、
  /// 出題した全問とその解答。
  final List<Question> questions;
  final Map<String, Object?> answers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = result.total;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Icon(
              result.passed ? Icons.emoji_events : Icons.replay,
              color: result.passed ? theme.colorScheme.primary : theme.colorScheme.error,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.passed ? '合格ライン到達' : '合格ラインまであと${result.shortBy}点',
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '総合 ${total.score} / ${total.max}点（${total.pct.toStringAsFixed(1)}%）',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Text('科目別', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final subject in exam.subjects)
          if (result.bySubject[subject.subjectId] case final line?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(subject.name)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${line.score} / ${line.max}点'
                      '${result.subjectShortfalls.containsKey(subject.subjectId) ? '（足切り未達）' : ''}',
                      textAlign: TextAlign.end,
                      style: result.subjectShortfalls.containsKey(subject.subjectId)
                          ? TextStyle(color: theme.colorScheme.error)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MockExamReviewPage(questions: questions, answers: answers),
            ),
          ),
          child: const Text('解答結果の詳細を見る'),
        ),
        const SizedBox(height: 12),
        if (wrongQids.isNotEmpty)
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PracticePage(progressStore: progressStore, restrictToQids: wrongQids),
              ),
            ),
            child: Text('間違えた${wrongQids.length}問を復習する'),
          ),
        const SizedBox(height: 16),
        // 結果分析（分野別の様子と「次にやる分野」）。今回の解答だけから作り、何も保存しない。
        // 分野は「第1問〜第3問」の科目単位で集計する。このアプリの topicId は問題ごとにほぼ1つ
        // （1問1論点）なので、topicId で数えると「第3問 決算 / 1問中0問正解」のような行が大量に並ぶ。
        MockExamAnalysisCard(
          analysis: const MockExamAnalysisEngine().analyze([
            for (final q in questions) MockExamAnswer(topicId: q.subjectId, correct: !wrongQids.contains(q.qid)),
          ]),
          topicLabel: (id) {
            for (final s in exam.subjects) {
              if (s.subjectId == id) return s.name;
            }
            return id;
          },
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, _) => Center(child: ref.watch(adGateProvider).banner(BannerPlacement.result)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('戻る'),
        ),
      ],
    );
  }
}
