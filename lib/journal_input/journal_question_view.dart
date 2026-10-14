import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'account_catalog.dart';
import 'balance_indicator.dart';
import 'journal_diff_mapper.dart';
import 'journal_input_controller.dart';
import 'journal_input_state.dart';
import 'journal_input_table.dart';
import 'journal_result_banner.dart';
import '../practice/question_body_layout.dart';
import 'numeric_keypad.dart';

/// 仕訳問題1問分の画面。問題文・貸借バランス表示・入力テーブル・テンキー・
/// 答え合わせをまとめる。
class JournalQuestionView extends ConsumerStatefulWidget {
  const JournalQuestionView({
    super.key,
    required this.prompt,
    required this.correctAnswer,
    this.explanation,
    this.onAnswered,
    this.onNext,
    this.revealResult = true,
    this.accountPool = boki3Accounts,
    this.header,
  });

  /// 問題文の上に足す部品（証ひょうカードなど）。問題文と同じスクロールの中に置く。
  final Widget? header;

  final String prompt;
  final JournalAnswer correctAnswer;
  final String? explanation;

  /// 科目ピッカーに表示する勘定科目一覧。旧区分表（`level3_until_2027_03`）向けの
  /// 問題では [boki3AccountsLegacy] を渡す（手形科目を選べるようにするため）。
  final List<AccountDef> accountPool;

  /// 答え合わせボタンが押されたときに、判定結果とユーザー入力を通知する。
  final void Function(JournalJudgeResult result, List<JournalLine> userInput)? onAnswered;

  /// 非null なら、答え合わせ後に「もう一度」の代わりに「次の問題へ」ボタンを表示し、
  /// 押されたときにこれを呼ぶ（複数問を連続して出題する画面向け）。
  final VoidCallback? onNext;

  /// false なら、答え合わせの正誤・解説を表示せず、入力を確定したら即座に
  /// [onNext] を呼ぶ（模擬試験モード向け。本試験では解答中に正誤が分からない）。
  final bool revealResult;

  @override
  ConsumerState<JournalQuestionView> createState() => _JournalQuestionViewState();
}

class _JournalQuestionViewState extends ConsumerState<JournalQuestionView> {
  static const _maxRecent = 5;

  final List<String> _recentAccounts = [];
  JournalJudgeResult? _result;

  @override
  void initState() {
    super.initState();
    // 複数問を連続して出す画面（PracticeSession連動、問題ごとに key を変えて
    // Widget自体を作り直す）では initState が呼ばれ didUpdateWidget は呼ばれない。
    // journalInputProvider はグローバルな状態なので、表示開始時に必ずリセットして
    // 前の問題の入力が残らないようにする。riverpodはビルド中のprovider変更を
    // 許さないため、最初のフレーム描画後に行う。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(journalInputProvider.notifier).reset();
    });
  }

  void _onAccountSelected(String code) {
    setState(() {
      _recentAccounts.remove(code);
      _recentAccounts.insert(0, code);
      if (_recentAccounts.length > _maxRecent) _recentAccounts.removeLast();
    });
  }

  void _checkAnswer() {
    final lines = ref.read(journalInputProvider).toJournalLines();
    final result = judgeJournal(widget.correctAnswer, lines);
    widget.onAnswered?.call(result, lines);
    if (widget.revealResult) {
      setState(() => _result = result);
    } else {
      widget.onNext?.call();
    }
  }

  void _retry() {
    setState(() => _result = null);
    ref.read(journalInputProvider.notifier).reset();
  }

  @override
  void didUpdateWidget(covariant JournalQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 複数問を連続して出す画面（PracticeSession連動）で問題が切り替わったら、
    // 前の問題の入力・判定結果・最近使った科目をリセットする。
    if (oldWidget.prompt != widget.prompt) {
      setState(() {
        _result = null;
        _recentAccounts.clear();
      });
      ref.read(journalInputProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalInputProvider);
    final controller = ref.read(journalInputProvider.notifier);
    final cellDiffs = _result == null ? null : buildCellDiffs(state.rows, _result!.diffs);
    final showKeypad = _result == null && state.selectedCell?.field == JournalCellField.amount;

    return QuestionBodyLayout(
      scrollChildren: [
        if (widget.header != null) widget.header!,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(widget.prompt, style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BalanceIndicator(debitTotal: state.debitTotal, creditTotal: state.creditTotal),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: JournalInputTable(
            recentAccountCodes: _recentAccounts,
            cellDiffs: cellDiffs,
            readOnly: _result != null,
            onAccountSelected: _onAccountSelected,
            accountPool: widget.accountPool,
          ),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: JournalResultBanner(result: _result!, explanation: widget.explanation),
          ),
      ],
      bottomChildren: [
        if (showKeypad)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: NumericKeypad(
              onDigit: controller.appendDigit,
              onTripleZero: controller.appendTripleZero,
              onBackspace: controller.backspaceAmount,
              onClear: controller.clearAmount,
              onNext: controller.confirmAmount,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _result == null
              ? FilledButton(
                  onPressed: _checkAnswer,
                  child: Text(widget.revealResult ? '答え合わせ' : '次へ'),
                )
              : (widget.onNext != null
                  ? FilledButton(onPressed: widget.onNext, child: const Text('次の問題へ'))
                  : OutlinedButton(onPressed: _retry, child: const Text('もう一度'))),
        ),
      ],
    );
  }
}
