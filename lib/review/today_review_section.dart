import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_data/exam_data_cache.dart';
import '../mistake_note/mistake_note_data.dart';
import '../practice/practice_page.dart';
import '../progress/progress_revision.dart';
import 'review_schedule.dart';

/// ホーム「今日やること」の「今日の復習」。間違いノートから復習予定を同期し、
/// 期限分の件数を [TodayReviewCard] で見せる。「やってみる」は既存の演習画面
/// （[PracticePage] の解き直し）を期限分の問題だけで開く（出題画面は新設しない）。
class TodayReviewSection extends StatefulWidget {
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
  State<TodayReviewSection> createState() => _TodayReviewSectionState();
}

class _TodayReviewSectionState extends State<TodayReviewSection> {
  List<ReviewItem> _items = const [];

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
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // 読み込めなければ 0 件の静かな表示のままにする。
    }
  }

  Future<void> _start() async {
    final due = reviewSchedulerEngine.due(_items, widget.clock(), max: kTodayReviewMax);
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
  Widget build(BuildContext context) => TodayReviewCard(
        dueCount: reviewSchedulerEngine.dueCount(_items, widget.clock()),
        onStart: _start,
      );
}
