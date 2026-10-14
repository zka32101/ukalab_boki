import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../term/explanation_with_terms.dart';
import 'account_catalog.dart';

/// 答え合わせの結果（全体の正誤＋行ごとの誤りの内訳）を表示する。
class JournalResultBanner extends StatelessWidget {
  const JournalResultBanner({super.key, required this.result, this.explanation});

  final JournalJudgeResult result;
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
                  result.isCorrect ? '正解です' : '不正解です',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          for (final diff in result.diffs)
            if (diff.kind != JournalLineDiffKind.correct) _buildDiffLine(theme, diff),
          if (explanation != null && explanation!.isNotEmpty) ...[
            const Divider(),
            ExplanationWithTerms(explanation: explanation!),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffLine(ThemeData theme, JournalLineDiff diff) {
    final text = switch (diff.kind) {
      JournalLineDiffKind.wrongAccount =>
        '科目が違います（正解: ${accountNameOf(diff.expected!.account)}）',
      JournalLineDiffKind.wrongAmount => '金額が違います（正解: ${diff.expected!.amount}）',
      JournalLineDiffKind.sideSwapped => '貸借が逆です',
      JournalLineDiffKind.missing =>
        '仕訳が足りません（${diff.expected!.side == JournalSide.debit ? "借方" : "貸方"} '
            '${accountNameOf(diff.expected!.account)} ${diff.expected!.amount}）',
      JournalLineDiffKind.extra => 'この行は不要です',
      JournalLineDiffKind.correct => '',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('・$text', style: theme.textTheme.bodySmall),
    );
  }
}
