import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../journal_input/numeric_keypad.dart';
import '../practice/question_body_layout.dart';
import 'ledger_diff_mapper.dart';
import 'ledger_input_controller.dart';
import 'ledger_result_banner.dart';
import 'ledger_table.dart';
import '../practice/tap_guard.dart';

/// 補助簿（商品有高帳・現金出納帳など）問題1問分の画面。問題文・入力テーブル・
/// テンキー・答え合わせをまとめる。[WorksheetQuestionView]（`lib/worksheet_input/`）
/// の補助簿版。
class LedgerQuestionView extends ConsumerStatefulWidget {
  const LedgerQuestionView({
    super.key,
    required this.prompt,
    required this.correctAnswer,
    this.explanation,
    this.onAnswered,
    this.onNext,
    this.revealResult = true,
  });

  final String prompt;
  final LedgerAnswer correctAnswer;
  final String? explanation;

  /// 答え合わせボタンが押されたときに、判定結果とユーザー入力を通知する。
  final void Function(LedgerJudgeResult result, List<LedgerCell> userInput)? onAnswered;

  /// 非null なら、答え合わせ後に「もう一度」の代わりに「次の問題へ」ボタンを表示し、
  /// 押されたときにこれを呼ぶ（複数問を連続して出題する画面向け）。
  final VoidCallback? onNext;

  /// false なら、答え合わせの正誤・解説を表示せず、入力を確定したら即座に
  /// [onNext] を呼ぶ（模擬試験モード向け。本試験では解答中に正誤が分からない）。
  final bool revealResult;

  @override
  ConsumerState<LedgerQuestionView> createState() => _LedgerQuestionViewState();
}

class _LedgerQuestionViewState extends ConsumerState<LedgerQuestionView> with TapGuardMixin<LedgerQuestionView> {
  LedgerJudgeResult? _result;

  @override
  void initState() {
    super.initState();
    // worksheetQuestionViewと同様、グローバルな状態（ledgerInputProvider）を
    // 表示開始時に必ずこの問題用にリセットする。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(ledgerInputProvider.notifier).initFor([
        for (final c in widget.correctAnswer.blankCells) (c.rowIndex, c.group, c.field),
      ]);
    });
  }

  void _checkAnswer() {
    startTapGuard(); // 直後の「次の問題へ」への誤タップ（ダブルタップ）を無視する
    final cells = ref.read(ledgerInputProvider).toLedgerCells();
    final result = judgeLedger(widget.correctAnswer, cells);
    widget.onAnswered?.call(result, cells);
    if (widget.revealResult) {
      setState(() => _result = result);
    } else {
      widget.onNext?.call();
    }
  }

  void _retry() {
    setState(() => _result = null);
    ref.read(ledgerInputProvider.notifier).initFor([
      for (final c in widget.correctAnswer.blankCells) (c.rowIndex, c.group, c.field),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ledgerInputProvider);
    final controller = ref.read(ledgerInputProvider.notifier);
    final cellDiffs = _result == null ? null : buildLedgerCellDiffs(_result!.diffs);
    final showKeypad = _result == null && state.selectedCell != null;

    return QuestionBodyLayout(
      scrollChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(widget.prompt, style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LedgerTable(
            rows: widget.correctAnswer.rows,
            givenCells: widget.correctAnswer.givenCells,
            blankCells: widget.correctAnswer.blankCells,
            cellDiffs: cellDiffs,
            readOnly: _result != null,
          ),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LedgerResultBanner(
              result: _result!,
              rows: widget.correctAnswer.rows,
              explanation: widget.explanation,
            ),
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
                  onPressed: guardTap(_checkAnswer),
                  child: Text(widget.revealResult ? '答え合わせ' : '次へ'),
                )
              : (widget.onNext != null
                  ? FilledButton(onPressed: guardTap(widget.onNext), child: const Text('次の問題へ'))
                  : OutlinedButton(onPressed: _retry, child: const Text('もう一度'))),
        ),
      ],
    );
  }
}
