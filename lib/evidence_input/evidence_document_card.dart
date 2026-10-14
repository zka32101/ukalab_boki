import 'package:flutter/material.dart';

import 'evidence_document.dart';

/// 証ひょう（領収書・請求書など）の記載内容を、実物の書類風のカードで表示する。
class EvidenceDocumentCard extends StatelessWidget {
  const EvidenceDocumentCard({super.key, required this.document});

  final EvidenceDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(document.icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  document.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          for (final item in document.items) _ItemLine(text: item),
        ],
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTotal = text.startsWith('合計');
    final line = Text(
      text,
      style: isTotal
          ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
          : theme.textTheme.bodyMedium,
    );
    if (!isTotal) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: line);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Divider(height: 12), line],
      ),
    );
  }
}
