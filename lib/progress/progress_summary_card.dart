import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_data/exam_data_cache.dart';
import '../term/term_list_page.dart';
import 'progress_revision.dart';
import 'progress_summary.dart';

/// ホーム画面に表示する、科目別の正答率カード。
///
/// `assets/exam/boki3.exam.json` の科目一覧（表示順・名称）と、
/// [ProgressStore] に溜まった解答記録（演習・模擬試験どちらも対象）を
/// 突き合わせて、科目ごとの正答率バーを表示する。
class ProgressSummaryCard extends StatefulWidget {
  const ProgressSummaryCard({super.key, required this.store});

  final ProgressStore store;

  @override
  State<ProgressSummaryCard> createState() => _ProgressSummaryCardState();
}

class _ProgressSummaryCardState extends State<ProgressSummaryCard> {
  late Future<_ProgressCardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
    // ホームタブは `IndexedStack` で一度マウントされると破棄されないため、
    // 他のタブで新しい解答記録が追加されても自動では再読み込みされない。
    progressRevision.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    progressRevision.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    setState(() {
      _dataFuture = _load();
    });
  }

  Future<_ProgressCardData> _load() async {
    final exam = await loadExamConfig();
    final records = await widget.store.loadRecords();
    final streakDays = await loadCurrentStreak();
    return _ProgressCardData(
      exam: exam,
      bySubject: summarizeBySubject(records),
      streakDays: streakDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProgressCardData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!;
        final hasAny = data.bySubject.values.any((s) => s.total > 0);
        final theme = Theme.of(context);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(alignment: Alignment.centerLeft, child: StreakBadge(days: data.streakDays)),
                const SizedBox(height: 12),
                Text('科目別の正答率', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (!hasAny)
                  Text(
                    '演習や模擬試験を解くと、ここに科目別の正答率が表示されます。',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  )
                else
                  for (final subject in data.exam.subjects)
                    if (data.bySubject[subject.subjectId] case final s? when s.total > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SubjectProgressRow(
                          subjectId: subject.subjectId,
                          name: subject.name,
                          progress: s,
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressCardData {
  const _ProgressCardData({required this.exam, required this.bySubject, required this.streakDays});

  final ExamConfig exam;
  final Map<String, SubjectAccuracy> bySubject;
  final int streakDays;
}

class _SubjectProgressRow extends StatelessWidget {
  const _SubjectProgressRow({required this.subjectId, required this.name, required this.progress});

  final String subjectId;
  final String name;
  final SubjectAccuracy progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 7割未満は「苦手科目」として強調する（模擬試験の合格ラインと揃える）。
    final isWeak = progress.pct < 70;
    final barColor = isWeak ? theme.colorScheme.error : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 狭い幅・大きい文字でも溢れないよう、科目名は残り幅に収めて折り返す。
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: name),
                    if (isWeak) ...[
                      const WidgetSpan(child: SizedBox(width: 6)),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${progress.pct.toStringAsFixed(0)}%（${progress.correct}/${progress.total}問）',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (progress.pct / 100).clamp(0, 1),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        if (isWeak)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TermListPage(initialSubjectId: subjectId, initialSubjectLabel: name),
                ),
              ),
              icon: const Icon(Icons.menu_book, size: 16),
              label: const Text('用語集で復習する'),
            ),
          ),
      ],
    );
  }
}
