import 'progress_store.dart';

/// 1科目分の正答率（`ukalab_core` の `SubjectProgress` と名前が衝突するため
/// `SubjectAccuracy` と命名）。
class SubjectAccuracy {
  const SubjectAccuracy(
      {required this.subjectId, required this.correct, required this.total});

  final String subjectId;
  final int correct;
  final int total;

  /// 正答率（%）。記録が0件なら0。
  double get pct => total == 0 ? 0 : correct * 100 / total;
}

/// 解答記録を科目（`subjectId`）ごとに集計する。
Map<String, SubjectAccuracy> summarizeBySubject(List<ProgressRecord> records) {
  final correct = <String, int>{};
  final total = <String, int>{};
  for (final r in records) {
    total[r.subjectId] = (total[r.subjectId] ?? 0) + 1;
    if (r.correct) correct[r.subjectId] = (correct[r.subjectId] ?? 0) + 1;
  }
  return {
    for (final id in total.keys)
      id: SubjectAccuracy(
          subjectId: id, correct: correct[id] ?? 0, total: total[id]!),
  };
}
