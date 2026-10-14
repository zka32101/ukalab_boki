import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/mock_exam/mock_exam_page.dart';
import 'package:ukalab_boki3/practice/choice_question_view.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'test_support.dart';

/// 狭い幅・大きい文字で RenderFlex overflow しないことを確認する。
void main() {
  // 問題データは全体でキャッシュされる。フェイク時間の中で読み始めると完了しないことがあるため、先に実時間で読み込む。
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadQuestions();
    await loadExamConfig();
  });

  for (final width in [320.0, 280.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('解答中画面と結果画面は幅${width.toInt()}・文字$scale倍でオーバーフローしない', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 4000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(ProviderScope(
          overrides: studyNotesTestOverrides(),
          child: MaterialApp(home: MockExamPage(progressStore: InMemoryProgressStore())),
        ));
        for (var i = 0; i < 30 && find.text('模擬試験を開始する').evaluate().isEmpty; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.text('模擬試験を開始する'));
        await tester.pump();

        // 解答中: 問題番号と残り時間のヘッダー。
        expect(find.textContaining('問目'), findsWidgets);
        expect(find.textContaining('残り'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '解答中画面');

        for (var i = 0; i < 20; i++) {
          if (find.byType(ChoiceQuestionView).evaluate().isNotEmpty) {
            await tester.tap(find.byType(InkWell).first);
            await tester.pump();
          }
          await tester.tap(find.text('次へ'));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '解答中画面 ${i + 1}問目の後');
        }
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('合格ラインまであと'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '結果画面');
      });
    }
  }
}
