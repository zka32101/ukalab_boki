import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../journal_input/numeric_keypad.dart';
import '../practice/question_body_layout.dart';
import 'worksheet_diff_mapper.dart';
import 'worksheet_input_controller.dart';
import 'worksheet_result_banner.dart';
import 'worksheet_table.dart';
import '../practice/tap_guard.dart';

/// 表埋め（精算表・財務諸表）問題1問分の画面。問題文・入力テーブル・
/// テンキー・答え合わせをまとめる。[JournalQuestionView] の表埋め版。
class WorksheetQuestionView extends ConsumerStatefulWidget {
  const WorksheetQuestionView({
    super.key,
    required this.prompt,
    required this.correctAnswer,
    this.explanation,
    this.onAnswered,
    this.onNext,
    this.revealResult = true,
  });

  final String prompt;
  final WorksheetAnswer correctAnswer;
  final String? explanation;

  /// 答え合わせボタンが押されたときに、判定結果とユーザー入力を通知する。
  final void Function(WorksheetJudgeResult result, List<WorksheetCell> userInput)? onAnswered;

  /// 非null なら、答え合わせ後に「もう一度」の代わりに「次の問題へ」ボタンを表示し、
  /// 押されたときにこれを呼ぶ（複数問を連続して出題する画面向け）。
  final VoidCallback? onNext;

  /// false なら、答え合わせの正誤・解説を表示せず、入力を確定したら即座に
  /// [onNext] を呼ぶ（模擬試験モード向け。本試験では解答中に正誤が分からない）。
  final bool revealResult;

  @override
  ConsumerState<WorksheetQuestionView> createState() => _WorksheetQuestionViewState();
}

class _WorksheetQuestionViewState extends ConsumerState<WorksheetQuestionView> with TapGuardMixin<WorksheetQuestionView> {
  WorksheetJudgeResult? _result;

  @override
  void initState() {
    super.initState();
    // journalQuestionViewと同様、グローバルな状態（worksheetInputProvider）を
    // 表示開始時に必ずこの問題用にリセットする。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(worksheetInputProvider.notifier).initFor([
        for (final c in widget.correctAnswer.blankCells) (c.account, c.column),
      ]);
    });
  }

  void _checkAnswer() {
    startTapGuard(); // 直後の「次の問題へ」への誤タップ（ダブルタップ）を無視する
    final cells = ref.read(worksheetInputProvider).toWorksheetCells();
    final result = judgeWorksheet(widget.correctAnswer, cells);
    widget.onAnswered?.call(result, cells);
    if (widget.revealResult) {
      setState(() => _result = result);
    } else {
      widget.onNext?.call();
    }
  }

  void _retry() {
    setState(() => _result = null);
    ref.read(worksheetInputProvider.notifier).initFor([
      for (final c in widget.correctAnswer.blankCells) (c.account, c.column),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(worksheetInputProvider);
    final controller = ref.read(worksheetInputProvider.notifier);
    final cellDiffs = _result == null ? null : buildWorksheetCellDiffs(_result!.diffs);
    final showKeypad = _result == null && state.selectedCell != null;

    return QuestionBodyLayout(
      scrollChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(widget.prompt, style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: WorksheetTable(
            givenCells: widget.correctAnswer.givenCells,
            blankCells: widget.correctAnswer.blankCells,
            cellDiffs: cellDiffs,
            readOnly: _result != null,
          ),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: WorksheetResultBanner(result: _result!, explanation: widget.explanation),
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
