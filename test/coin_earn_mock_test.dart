import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/mock_exam/mock_exam_page.dart';
import 'package:ukalab_boki3/practice/choice_question_view.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_core/ui.dart';

import 'test_support.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('模擬を終えると mockDone のコインが入る（不合格なら合格コインなし）', (tester) async {
    final service = CoinService(store: InMemoryCoinStore());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...studyNotesTestOverrides(),
        coinServiceProvider.overrideWith((ref) => service)
      ],
      child: MaterialApp(
          home: MockExamPage(progressStore: InMemoryProgressStore())),
    ));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    for (var i = 0; i < 10 && find.text('模擬試験を開始する').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('模擬試験を開始する'));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      if (find.byType(ChoiceQuestionView).evaluate().isNotEmpty) {
        await tester.tap(find.byType(InkWell).first);
        await tester.pump();
      }
      await tester.tap(find.text('次へ'));
      await tester.pump();
    }
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(service.balance, 10);
  });
}
