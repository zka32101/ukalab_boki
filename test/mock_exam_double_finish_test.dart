import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ukalab_boki3/mock_exam/mock_exam_page.dart';
import 'package:ukalab_boki3/practice/choice_question_view.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'test_ads.dart';

/// 最終問題で「次へ」を連打すると `_finish()` が二重に走り、
/// `SharedPreferencesProgressStore.addRecord`（読み込み→追記→書き込み）が
/// 競合して記録が壊れる不具合の回帰テスト。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('最終問題で「次へ」を連打しても解答記録が20件ちょうどになる', (tester) async {
    final progressStore = InMemoryProgressStore();
    await tester.pumpWidget(
      ProviderScope(overrides: [stubAdGateOverride()], child: MaterialApp(home: MockExamPage(progressStore: progressStore))),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    for (var i = 0; i < 10 && find.text('模擬試験を開始する').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('模擬試験を開始する'));
    await tester.pump();

    for (var i = 0; i < 19; i++) {
      if (find.byType(ChoiceQuestionView).evaluate().isNotEmpty) {
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
      }
      await tester.tap(find.text('次へ'));
      await tester.pump();
    }

    // 最終問題（20問目）: 連打を再現するため、1回目のタップで走る
    // _finish() の非同期処理が終わる前に、同じフレームでもう一度タップする。
    if (find.byType(ChoiceQuestionView).evaluate().isNotEmpty) {
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
    }
    await tester.tap(find.text('次へ'));
    await tester.tap(find.text('次へ'), warnIfMissed: false);
    await tester.pump();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    final records = await progressStore.loadRecords();
    expect(records, hasLength(20));
  });
}
