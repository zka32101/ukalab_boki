import 'package:ukalab_core/daily_goal.dart';
import 'package:ukalab_core/ui.dart';

import '../company_mode/company_mode_history_store.dart';
import '../progress/progress_revision.dart';
import '../progress/progress_store.dart';
import '../term/learned_terms_store.dart';

/// 設定タブの「データの管理」（書き出し・読み込み・リセット）の対象。
///
/// 解答記録、会社経営モードの履歴、「覚えた」にした用語、デイリーミッション、自分用メモが対象。
/// テーマ・購入・ブックマークは含めない。
List<DataPart> bokiDataParts({
  required ProgressStore progressStore,
  required CompanyModeHistoryStore companyModeHistoryStore,
  required LearnedTermsStore learnedTermsStore,
}) =>
    [
      DataPart(
        id: 'progress',
        export: (ref) async => [for (final r in await progressStore.loadRecords()) r.toJson()],
        restore: (ref, json) async {
          await progressStore.clearRecords();
          for (final e in json as List) {
            if (ProgressRecord.fromJson(e) case final r?) await progressStore.addRecord(r);
          }
          // ホーム・記録タブは IndexedStack でマウントされたままのため、再読み込みさせる。
          progressRevision.value++;
        },
        reset: (ref) async {
          await progressStore.clearRecords();
          progressRevision.value++;
        },
      ),
      DataPart(
        id: 'companyMode',
        export: (ref) async => [for (final r in await companyModeHistoryStore.loadResults()) r.toJson()],
        restore: (ref, json) async {
          await companyModeHistoryStore.clearResults();
          for (final e in json as List) {
            if (CompanyModeResult.fromJson(e) case final r?) await companyModeHistoryStore.addResult(r);
          }
          progressRevision.value++;
        },
        reset: (ref) async {
          await companyModeHistoryStore.clearResults();
          progressRevision.value++;
        },
      ),
      DataPart(
        id: 'learnedTerms',
        export: (ref) async => (await learnedTermsStore.load()).toList()..sort(),
        restore: (ref, json) async {
          final next = (json as List).cast<String>().toSet();
          final current = await learnedTermsStore.load();
          for (final id in current.difference(next)) {
            await learnedTermsStore.setLearned(id, false);
          }
          for (final id in next.difference(current)) {
            await learnedTermsStore.setLearned(id, true);
          }
        },
        reset: (ref) async {
          for (final id in await learnedTermsStore.load()) {
            await learnedTermsStore.setLearned(id, false);
          }
        },
      ),
      DataPart(
        id: 'dailyGoal',
        export: (ref) => ref.read(dailyGoalProvider).toJson(),
        restore: (ref, json) =>
            ref.read(dailyGoalProvider.notifier).restore(DailyGoal.fromJson(json as Map<String, dynamic>)),
        reset: (ref) => ref.read(dailyGoalProvider.notifier).reset(),
      ),
      DataPart(
        id: 'dailyGoalHistory',
        export: (ref) => [for (final e in ref.read(dailyGoalHistoryProvider)) e.toJson()],
        restore: (ref, json) => ref.read(dailyGoalHistoryProvider.notifier).restore([
          for (final j in (json as List).cast<Map<String, dynamic>>()) DailyGoalHistoryEntry.fromJson(j),
        ]),
        reset: (ref) => ref.read(dailyGoalHistoryProvider.notifier).reset(),
      ),
      DataPart(
        id: 'questionMemo',
        export: (ref) => ref.read(questionMemoProvider),
        restore: (ref, json) =>
            ref.read(questionMemoProvider.notifier).restore((json as Map<String, dynamic>).cast<String, String>()),
        reset: (ref) => ref.read(questionMemoProvider.notifier).reset(),
      ),
    ];
