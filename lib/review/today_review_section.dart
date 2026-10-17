import 'package:app_common_kit/app_common_kit.dart' show EntitlementState, entitlementStateProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/mock_exam_quota.dart';
import '../exam_data/exam_data_cache.dart';
import '../mistake_note/mistake_note_data.dart';
import '../mistake_note/mistake_note_page.dart';
import '../practice/practice_page.dart';
import '../progress/progress_revision.dart';
import 'review_schedule.dart';

/// ホーム「今日やること」の「今日の復習」。間違いノートから復習予定を同期し、
/// 期限分の件数を [TodayReviewCard] で見せる。「やってみる」は既存の演習画面
/// （[PracticePage] の解き直し）を期限分の問題だけで開く（出題画面は新設しない）。
class TodayReviewSection extends ConsumerStatefulWidget {
  const TodayReviewSection({
    super.key,
    required this.progressStore,
    this.noteStore,
    this.scheduleStore,
    this.loadQuestionList,
    this.clock = DateTime.now,
  });

  final ProgressStore progressStore;

  /// テスト用の差し替え。省略時は端末内の保存先。
  final MistakeNoteStore? noteStore;
  final ReviewSchedulerStore? scheduleStore;
  final Future<List<Question>> Function()? loadQuestionList;
  final DateTime Function() clock;

  @override
  ConsumerState<TodayReviewSection> createState() => _TodayReviewSectionState();
}

/// 無料版の「今日の復習」の1日の件数(方針 D6)。
const _freeReviewPerDay = 10;

class _TodayReviewSectionState extends ConsumerState<TodayReviewSection> {
  List<ReviewItem> _items = const [];

  /// 無料版の今日の残り回数。読み込み前は null(制限しない)。
  int? _freeRemaining;

  @override
  void initState() {
    super.initState();
    progressRevision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    progressRevision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final items = await syncReviewSchedule(
        progressStore: widget.progressStore,
        noteStore: widget.noteStore ?? mistakeNoteStore,
        scheduleStore: widget.scheduleStore ?? reviewSchedulerStore,
        questions: await (widget.loadQuestionList ?? loadQuestions)(),
      );
      final remaining = (await todayReviewQuota(isPremium: false)).remaining;
      if (mounted) {
        setState(() {
          _items = items;
          _freeRemaining = remaining;
        });
      }
    } catch (_) {
      // 読み込めなければ 0 件の静かな表示のままにする。
    }
  }

  Future<void> _start() async {
    // 無料版は1日の復習が決まった数まで(プレミアムは無制限)。
    final isPremium = (ref.read(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium;
    final remaining = isPremium ? null : _freeRemaining;
    final max = remaining == null ? kTodayReviewMax : remaining.clamp(0, kTodayReviewMax);
    final due = reviewSchedulerEngine.due(_items, widget.clock(), max: max);
    if (due.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PracticePage(
        progressStore: widget.progressStore,
        restrictToQids: {for (final i in due) i.qid},
        title: '今日の復習',
      ),
    ));
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    var due = reviewSchedulerEngine.dueCount(_items, widget.clock());
    // 無料版は1日の復習が決まった数まで(プレミアムは無制限)。
    final isPremium = (ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium;
    final remaining = isPremium ? null : _freeRemaining;
    if (remaining != null) {
      if (remaining <= 0 && due > 0) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日の復習', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                '無料版の今日の復習($_freeReviewPerDay問)は終わりました。\n'
                '続きは明日。プレミアムなら、続けて復習できます(間違いノートは、いつでも開けます)。',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => MistakeNotePage(progressStore: widget.progressStore),
                  ));
                  if (mounted) await _reload();
                },
                child: const Text('間違いノートを開く'),
              ),
            ],
          ),
        ),
      );
      }
      if (due > remaining) due = remaining;
    }
    return TodayReviewCard(dueCount: due, onStart: _start);
  }
}
