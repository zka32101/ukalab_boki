import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_prep/exam_prep_data.dart' show kExamId;
import '../mistake_note/mistake_note_data.dart';
import '../oshi/oshi_recap.dart';

/// 「今日の復習」の予定の保存先（端末内。キー `ukalab_boki3_review_schedule`）。
/// 間違いノートと同じアプリID（[kExamId]）を使う。
final ReviewSchedulerStore reviewSchedulerStore = SharedPreferencesReviewSchedulerStore(kExamId);

const ReviewSchedulerEngine reviewSchedulerEngine = ReviewSchedulerEngine();

/// 1回の「やってみる」で出す最大問題数。
const int kTodayReviewMax = 5;

/// 解答履歴から間違いノートを更新し（間違いノート画面と同じ処理。冪等）、
/// その内容で復習予定を同期して保存し、返す。
Future<List<ReviewItem>> syncReviewSchedule({
  required ProgressStore progressStore,
  required MistakeNoteStore noteStore,
  required ReviewSchedulerStore scheduleStore,
  required List<Question> questions,
}) async {
  final records = withTopics(await progressStore.loadRecords(), questions);
  final notes = mistakeNoteEngine.update(await noteStore.read(), records);
  await noteStore.write(notes);
  final items = reviewSchedulerEngine.sync(await scheduleStore.read(), notes);
  await scheduleStore.write(items);
  return items;
}

/// 演習で1問答えたとき、その問題が復習の期限に来ていれば結果を反映する。
/// 期限前・予定にない問題は何もしない（通常の演習で復習が早まらないように）。
/// [now] には解答記録（`ProgressRecord.at`）と同じ時刻を渡す。失敗しても演習は止めない。
Future<void> recordReviewResult(
  String qid, {
  required bool correct,
  required DateTime now,
  ReviewSchedulerStore? store,
}) async {
  try {
    final s = store ?? reviewSchedulerStore;
    final items = await s.read();
    final hit = items.where((i) => i.qid == qid && reviewSchedulerEngine.isDue(i, now));
    if (hit.isEmpty) return;
    await s.write(reviewSchedulerEngine.applyResult(items, qid, correct: correct, now: now));
  } catch (_) {
    // 復習予定の更新に失敗しても、解答の記録と演習は続ける。
  }
}
