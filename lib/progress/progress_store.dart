import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';

export 'package:ukalab_core/ukalab_core.dart'
    show ProgressRecord, ProgressStore, InMemoryProgressStore;

/// 端末内（`SharedPreferences`）への保存。記録が増え続けないよう、
/// 直近 [maxRecords] 件だけを残す。[ProgressRecord]・[ProgressStore] の
/// 定義自体は `ukalab_core`（純Dart）にあり、永続化の具体実装だけを
/// ここに持つ（`shared_preferences` はFlutterプラグインのため）。
class SharedPreferencesProgressStore
    implements ProgressStore, CauseRecordingStore, CorrectionRecordingStore {
  SharedPreferencesProgressStore({this.maxRecords = 2000});

  final int maxRecords;

  static const _key = 'ukalab_boki3_progress_records';

  @override
  Future<List<ProgressRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key);
    if (text == null) return [];
    try {
      final list = jsonDecode(text) as List<dynamic>;
      return [
        for (final e in list)
          if (ProgressRecord.fromJson(e) case final r?) r,
      ];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> addRecord(ProgressRecord record) async {
    final records = await loadRecords()
      ..add(record);
    final capped = records.length > maxRecords
        ? records.sublist(records.length - maxRecords)
        : records;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode([for (final r in capped) r.toJson()]));
  }

  @override
  Future<void> setCause(String qid, WrongCause? cause) async {
    final records = attachCauseToLatest(await loadRecords(), qid, cause);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode([for (final r in records) r.toJson()]));
  }

  @override
  Future<void> setLatestCorrect(String qid) async {
    final records = markLatestCorrectIn(await loadRecords(), qid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode([for (final r in records) r.toJson()]));
  }

  @override
  Future<void> clearRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// 直近の誤答記録に原因ラベルを後付けできる保存先。
abstract interface class CauseRecordingStore {
  Future<void> setCause(String qid, WrongCause? cause);
}

/// [qid] の直近の誤答記録に原因ラベルを付ける（[cause] が null なら外す）。
/// [CauseRecordingStore] でない保存先（テスト用のインメモリ等）は、全件を書き直して反映する。
Future<void> attachCause(
    ProgressStore store, String qid, WrongCause? cause) async {
  if (store is CauseRecordingStore) {
    await (store as CauseRecordingStore).setCause(qid, cause);
    return;
  }
  final next = attachCauseToLatest(await store.loadRecords(), qid, cause);
  await store.clearRecords();
  for (final r in next) {
    await store.addRecord(r);
  }
}

/// 直近の記録を正解に直せる保存先（自己申告の救済用）。
abstract interface class CorrectionRecordingStore {
  Future<void> setLatestCorrect(String qid);
}

/// [records] のうち [qid] の直近の記録を正解に直す（誤答の原因ラベルは外す）。
/// すでに正解、または該当記録なしなら変更しない。
List<ProgressRecord> markLatestCorrectIn(
    List<ProgressRecord> records, String qid) {
  final i = records.lastIndexWhere((r) => r.qid == qid);
  if (i < 0 || records[i].correct) return records;
  final r = records[i];
  final fixed = ProgressRecord(
    qid: r.qid,
    subjectId: r.subjectId,
    correct: true,
    at: r.at,
    topicId: r.topicId,
    subtopicId: r.subtopicId,
    ms: r.ms,
  );
  return [...records]..[i] = fixed;
}

/// [qid] の直近の解答記録を正解に直す（自由入力の打ち間違いを本人が申告したとき）。
Future<void> markLatestCorrect(ProgressStore store, String qid) async {
  if (store is CorrectionRecordingStore) {
    await (store as CorrectionRecordingStore).setLatestCorrect(qid);
    return;
  }
  final next = markLatestCorrectIn(await store.loadRecords(), qid);
  await store.clearRecords();
  for (final r in next) {
    await store.addRecord(r);
  }
}
