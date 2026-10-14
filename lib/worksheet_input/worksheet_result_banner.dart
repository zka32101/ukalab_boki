import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../journal_input/account_catalog.dart';
import '../term/explanation_with_terms.dart';
import 'worksheet_table.dart' show WorksheetColumnLabel;

/// 答え合わせの結果（正解セル数＋誤りの内訳）を表示する。
class WorksheetResultBanner extends StatelessWidget {
  const WorksheetResultBanner({super.key, required this.result, this.explanation});

  final WorksheetJudgeResult result;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.isCorrect ? theme.colorScheme.primary : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(result.isCorrect ? Icons.check_circle : Icons.cancel, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.isCorrect
                      ? '正解です'
                      : '不正解です（${result.correctCount} / ${result.totalCount}セル正解）',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          for (final diff in result.diffs)
            if (diff.kind != WorksheetCellDiffKind.correct) _buildDiffLine(theme, diff),
          if (explanation != null && explanation!.isNotEmpty) ...[
            const Divider(),
            ExplanationWithTerms(explanation: explanation!),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffLine(ThemeData theme, WorksheetCellDiff diff) {
    final text = switch (diff.kind) {
      WorksheetCellDiffKind.wrongAmount =>
        '${accountNameOf(diff.expected!.account)}（${diff.expected!.column.label.replaceAll('\n', '')}）の金額が違います（正解: ${diff.expected!.amount}）',
      WorksheetCellDiffKind.missing =>
        '${accountNameOf(diff.expected!.account)}（${diff.expected!.column.label.replaceAll('\n', '')}）が未入力です（正解: ${diff.expected!.amount}）',
      WorksheetCellDiffKind.extra => 'この入力は不要です',
      WorksheetCellDiffKind.correct => '',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('・$text', style: theme.textTheme.bodySmall),
    );
  }
}
