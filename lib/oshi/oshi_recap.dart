import 'package:ukalab_core/ukalab_core.dart';

/// 推しの一言・週間ふりかえり・間違いノートに渡す入力を、アプリの既存データ
/// （解答履歴・連続学習日数・試験日）から作る。文言・判定は ukalab_core 側。
/// ここは入力を作るだけ（個人情報・問題IDは推しの一言／ふりかえりには渡さない）。

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// 記録に論点（topicId）が無い場合（このアプリの演習は topicId を保存しない）、
/// 出題データの qid から補う。補えない記録はそのまま返す。
List<ProgressRecord> withTopics(List<ProgressRecord> records, List<Question> questions) {
  final byQid = {for (final q in questions) q.qid: q.topicId};
  return [
    for (final r in records)
      if (r.topicId == null && byQid[r.qid] != null)
        ProgressRecord(
          qid: r.qid,
          subjectId: r.subjectId,
          correct: r.correct,
          at: r.at,
          topicId: byQid[r.qid],
          subtopicId: r.subtopicId,
          ms: r.ms,
          cause: r.cause,
        )
      else
        r,
  ];
}

/// 推しの一言の状況。[now] は「今日」の基準（テストで固定できる）。
///
/// [currentStreak] は「現在も続いている」連続日数（`loadCurrentStreak`。途切れていれば 0）。
/// 途切れた連続日数や過去の試験日は入力に使わない。
OshiMessageContext oshiMessageContextFor({
  required List<ProgressRecord> records,
  required int currentStreak,
  required DateTime now,
  DateTime? examDate,
  List<Question> questions = const [],
}) {
  final today = _day(now);

  DateTime? lastStudy;
  var todayAnswered = 0;
  var todayCorrect = 0;
  for (final r in records) {
    final d = _day(r.at);
    if (d.isAfter(today)) continue; // 未来の記録（端末時計の巻き戻しなど）は使わない
    if (lastStudy == null || d.isAfter(lastStudy)) lastStudy = d;
    if (d == today) {
      todayAnswered++;
      if (r.correct) todayCorrect++;
    }
  }
  final since = lastStudy == null ? null : today.difference(lastStudy).inDays;

  int? examDaysLeft;
  if (examDate != null) {
    final left = _day(examDate).difference(today).inDays;
    if (left >= 0) examDaysLeft = left; // 過去の試験日は使わない
  }

  return OshiMessageContext(
    daysSinceLastStudy: since,
    // 連続日数は「今日か昨日まで続いている」ときだけ使う（途切れた古い値で褒めない）。
    streakDays: since != null && since <= 1 ? currentStreak : 0,
    todayAnswered: todayAnswered,
    todayCorrectRate: todayAnswered == 0 ? null : todayCorrect / todayAnswered,
    examDaysLeft: examDaysLeft,
    hasWeakTopics: computeWeakTopics(records, now: now, questions: questions, byChapter: true).isNotEmpty,
  );
}

/// 週間ふりかえり（今週。月曜始まり）。メダルは獲得日を持たないため数えない（0）。
WeeklyRecap weeklyRecapFor({required List<ProgressRecord> records, required DateTime now}) =>
    const WeeklyRecapEngine(weekStartsOn: DateTime.monday)
        .build(weeklyRecapDaysFromRecords(records), weekOf: now);

/// 分野（topicId）の表示名。topicId は章のslugなので、その問題の科目名で表す。
/// 見つからなければ ID をそのまま返す。
String Function(String topicId) topicLabelFor(
  List<Question> questions,
  String? Function(String subjectId) subjectName,
) {
  final byTopic = <String, String>{};
  for (final q in questions) {
    final name = subjectName(q.subjectId);
    if (name != null) byTopic.putIfAbsent(q.topicId, () => name);
  }
  return (id) => byTopic[id] ?? id;
}
