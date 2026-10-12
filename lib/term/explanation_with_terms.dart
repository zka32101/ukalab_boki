import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_core/ui.dart';

import '../exam_data/exam_data_cache.dart';
import 'package:ukalab_core/glossary.dart' show openTermCard;

/// 解説文を表示し、文中に用語集の見出し語が含まれていれば、その用語を
/// [showTermCard] で開けるチップを添える。
///
/// 設問文・選択肢には出さず、答え合わせ後の解説にのみ付ける方針
/// （解答前に用語が分かってしまうとヒントになってしまうため）。
class ExplanationWithTerms extends StatelessWidget {
  const ExplanationWithTerms({super.key, required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(explanation, style: theme.textTheme.bodyMedium),
        FutureBuilder<List<Term>>(
          future: loadTerms(),
          builder: (context, snapshot) {
            final all = snapshot.data;
            if (all == null) return const SizedBox.shrink();
            final hits = _findTermsIn(explanation, all);
            if (hits.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final term in hits)
                    ActionChip(
                      avatar: const Icon(Icons.menu_book, size: 16),
                      label: Text(term.term),
                      onPressed: () => openTermCard(context, all, term),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  List<Term> _findTermsIn(String text, List<Term> all) {
    final hits = <Term>[];
    // 短い見出し語が長い見出し語の部分文字列に埋もれて重複しないよう、
    // 長い語から先に判定する（例:「減価償却累計額」が先なら「減価償却」は除外）。
    final sorted = [...all]..sort((a, b) => b.term.length.compareTo(a.term.length));
    var remaining = text;
    for (final term in sorted) {
      if (remaining.contains(term.term)) {
        hits.add(term);
        remaining = remaining.replaceAll(term.term, '');
      }
    }
    return hits;
  }
}
