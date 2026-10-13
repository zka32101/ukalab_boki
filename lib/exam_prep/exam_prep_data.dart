import 'package:app_common_kit/app_common_kit.dart' show EntitlementState, entitlementStateProvider;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_data/current_level.dart';
import '../exam_data/exam_data_cache.dart';

/// ukalab_core の「試験に向けて」画面（`lib/ui/exam_prep/`）をこのアプリのデータにつなぐ部分。
/// 画面・文言は core 側。ここは取得・保存・premium 判定だけ。

const String kExamId = 'boki3';

const String updateLogAsset = 'assets/features/update_log.jsonl';
const String checklistAsset = 'assets/features/checklist.jsonl';

const String _examDateKey = 'ukalab_boki3_exam_date';
const String _checklistKey = 'ukalab_boki3_exam_checklist_v1';

/// 現在の試験区分（levelId）の問題だけ。10分プラン・試験直前は、演習画面
/// （`restrictToQids` 指定時は levelId で絞らない）に渡す前にここで絞る。
Future<List<Question>> loadCurrentLevelQuestions({DateTime? now}) async {
  final levelId = currentLevelId(now: now);
  return [
    for (final q in await loadQuestions())
      if (q.levelId == null || q.levelId == levelId) q,
  ];
}

/// 更新ログ（新しい順。未来の予定と90日より前は除く）。
Future<List<UpdateLogEntry>> loadUpdateLog({DateTime? now, AssetBundle? bundle}) async {
  final text = await (bundle ?? rootBundle).loadString(updateLogAsset);
  return recentUpdates(parseUpdateLogJsonl(text).entries, now ?? DateTime.now(), examId: kExamId);
}

/// 当日チェックリスト（全項目「公式で要確認」。受験形式に依らない項目だけ）。
Future<List<ChecklistItem>> loadChecklist({AssetBundle? bundle}) async {
  final text = await (bundle ?? rootBundle).loadString(checklistAsset);
  return checklistFor(kExamId, parseChecklistItemsJsonl(text).items, venue: ExamVenueKind.venue);
}

/// プレミアムか（10分プラン・試験直前・履歴の書き出しの利用可否は core のルールに従う）。
bool isPremiumFor(WidgetRef ref, PremiumFeature feature) => canUsePremiumFeature(
      feature,
      isPremium: (ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium,
    );

/// 試験日（端末内保存。未設定は null）。
class ExamDateNotifier extends Notifier<DateTime?> {
  late Future<void> _loaded;
  Future<void> get ready => _loaded;

  @override
  DateTime? build() {
    _loaded = _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_examDateKey);
      if (raw != null && state == null) state = DateTime.tryParse(raw);
    } catch (_) {}
  }

  Future<void> setDate(DateTime? date) async {
    await _loaded;
    state = date;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (date == null) {
        await prefs.remove(_examDateKey);
      } else {
        await prefs.setString(_examDateKey, DateTime(date.year, date.month, date.day).toIso8601String());
      }
    } catch (_) {}
  }
}

final examDateProvider = NotifierProvider<ExamDateNotifier, DateTime?>(ExamDateNotifier.new);

/// 当日チェックリストのチェック状態（端末内）。
class ChecklistNotifier extends Notifier<ChecklistProgress> {
  late Future<void> _loaded;
  Future<void> get ready => _loaded;

  @override
  ChecklistProgress build() {
    _loaded = _load();
    return const ChecklistProgress();
  }

  Future<void> _load() async {
    try {
      final ids = (await SharedPreferences.getInstance()).getStringList(_checklistKey);
      if (ids != null) state = ChecklistProgress({...ids, ...state.checkedIds});
    } catch (_) {}
  }

  Future<void> setProgress(ChecklistProgress p) async {
    await _loaded;
    state = p;
    try {
      await (await SharedPreferences.getInstance())
          .setStringList(_checklistKey, p.checkedIds.toList()..sort());
    } catch (_) {}
  }
}

final checklistProvider = NotifierProvider<ChecklistNotifier, ChecklistProgress>(ChecklistNotifier.new);
