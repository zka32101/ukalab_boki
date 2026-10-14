import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/progress/progress_summary_card.dart';

/// 「科目別の正答率」が狭い幅・大きい文字でも溢れない（RenderFlex overflow が出ない）ことの確認。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadExamConfig();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAt(WidgetTester tester,
      {required double width,
      required double scale,
      required bool weak}) async {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final store = InMemoryProgressStore();
    final exam = await tester.runAsync(loadExamConfig);
    for (final subject in exam!.subjects) {
      // 苦手（警告アイコンと復習ボタンあり）／得意（なし）で、全科目に件数の多い記録を入れる。
      for (var i = 0; i < 120; i++) {
        await store.addRecord(ProgressRecord(
          qid: '${subject.subjectId}_$i',
          subjectId: subject.subjectId,
          correct: weak ? i % 4 == 0 : true,
          at: DateTime(2026, 10, 5),
        ));
      }
    }
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body:
              SingleChildScrollView(child: ProgressSummaryCard(store: store))),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressSummaryCard), findsOneWidget);
    expect(
        find.textContaining('120/120問').evaluate().isNotEmpty || weak, isTrue);
  }

  for (final weak in [true, false]) {
    for (final (width, scale) in [
      (320.0, 1.0),
      (320.0, 2.0),
      (280.0, 2.0),
      (320.0, 3.0)
    ]) {
      testWidgets('幅$width・文字$scale倍でオーバーフローしない（${weak ? '苦手あり' : '全科目良好'}）',
          (tester) async {
        await pumpAt(tester, width: width, scale: scale, weak: weak);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
