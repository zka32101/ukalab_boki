import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../term/explanation_with_terms.dart';
import 'ledger_table.dart' show LedgerColumnKeyLabel;

/// 答え合わせの結果（正解セル数＋誤りの内訳）を表示する。
/// [WorksheetResultBanner]（`lib/worksheet_input/`）と同じパターン。
class LedgerResultBanner extends StatelessWidget {
  const LedgerResultBanner({
    super.key,
    required this.result,
    required this.rows,
    this.explanation,
  });

  final LedgerJudgeResult result;

  /// 行番号から日付・摘要を引くための行情報（[LedgerAnswer.rows]）。
  final List<LedgerRowMeta> rows;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.isCorrect ? theme.colorScheme.primary : theme.colorScheme.error;
    final rowsByIndex = {for (final r in rows) r.rowIndex: r};

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
            if (diff.kind != LedgerCellDiffKind.correct) _buildDiffLine(theme, diff, rowsByIndex),
          if (explanation != null && explanation!.isNotEmpty) ...[
            const Divider(),
            ExplanationWithTerms(explanation: explanation!),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffLine(
    ThemeData theme,
    LedgerCellDiff diff,
    Map<int, LedgerRowMeta> rowsByIndex,
  ) {
    final expected = diff.expected;
    final rowLabel = expected == null
        ? ''
        : (rowsByIndex[expected.rowIndex]?.description.isNotEmpty == true
            ? rowsByIndex[expected.rowIndex]!.description
            : '${expected.rowIndex + 1}行目');
    final columnLabel = expected == null ? '' : (expected.group, expected.field).label.replaceAll('\n', '');
    final text = switch (diff.kind) {
      LedgerCellDiffKind.wrongValue => '$rowLabel（$columnLabel）の値が違います（正解: ${expected!.value}）',
      LedgerCellDiffKind.missing => '$rowLabel（$columnLabel）が未入力です（正解: ${expected!.value}）',
      LedgerCellDiffKind.extra => 'この入力は不要です',
      LedgerCellDiffKind.correct => '',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('・$text', style: theme.textTheme.bodySmall),
    );
  }
}
