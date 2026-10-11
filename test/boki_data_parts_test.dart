import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/company_mode/company_mode_history_store.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/settings/boki_data_parts.dart';
import 'package:ukalab_boki3/term/learned_terms_store.dart';
import 'package:ukalab_core/ui.dart';

import 'test_support.dart';

void main() {
  testWidgets('解答記録・経営履歴・覚えた用語を書き出し→リセット→読み込みで戻せる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final progressStore = InMemoryProgressStore();
    final historyStore = InMemoryCompanyModeHistoryStore();
    final learned = LearnedTermsStore();
    final parts = bokiDataParts(
      progressStore: progressStore,
      companyModeHistoryStore: historyStore,
      learnedTermsStore: learned,
    );
    expect([for (final p in parts) p.id], ['progress', 'companyMode', 'learnedTerms', 'dailyGoal', 'dailyGoalHistory', 'questionMemo']);

    late WidgetRef ref;
    await tester.pumpWidget(ProviderScope(
      overrides: studyNotesTestOverrides(),
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          }),
        ),
      ),
    ));

    await tester.runAsync(() async {
      await progressStore.addRecord(
        ProgressRecord(qid: 'boki3-c-0001', subjectId: 'q2_choubo', correct: false, at: DateTime(2026, 10, 6)),
      );
      await historyStore.addResult(CompanyModeResult(
        scenarioId: 's1',
        companyName: 'カフェどんぐり',
        correctCount: 3,
        turnCount: 4,
        netIncome: 1200,
        playedAt: DateTime(2026, 10, 7),
      ));
      await learned.setLearned('t1', true);

      final text = await encodeLearningDataBackupAsync(ref, parts);

      await resetLearningData(ref, parts);
      expect(await progressStore.loadRecords(), isEmpty);
      expect(await historyStore.loadResults(), isEmpty);
      expect(await learned.load(), isEmpty);

      await restoreLearningDataBackup(ref, parts, text);
      expect((await progressStore.loadRecords()).single.qid, 'boki3-c-0001');
      expect((await historyStore.loadResults()).single.companyName, 'カフェどんぐり');
      expect(await learned.load(), {'t1'});
    });
  });
}
