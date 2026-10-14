import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/main.dart';
import 'package:ukalab_boki3/mock_exam/mock_exam_page.dart';
import 'package:ukalab_boki3/oshi/boki3_coin_overrides.dart';
import 'package:ukalab_boki3/practice/choice_question_view.dart';
import 'package:ukalab_boki3/practice/tap_guard.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/progress/progress_revision.dart';
import 'package:app_common_kit/app_common_kit.dart' show FakeEntitlementService, entitlementServiceProvider;
import 'package:ukalab_core/achievements.dart' show AchievementsView;
import 'package:ukalab_core/ui.dart';

import 'test_support.dart';

/// 全体確認で見つかった不具合の回帰テスト（実績画面の遷移・着替えショップ・連打ガード・模擬の分野集計・setState警告）。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadQuestions();
    await loadExamConfig();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, {List<Override> extra = const []}) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
        ...studyNotesTestOverrides(),
        ...extra,
      ],
      child: const UkalabBoki3App(),
    ));
    await settle(tester);
  }

  testWidgets('設定の「実績」をタップすると実績画面が開く（Navigator の context 不具合の回帰）', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('設定'));
    await settle(tester);
    final tile = find.text('実績');
    await tester.scrollUntilVisible(tile, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(tile);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(AchievementsView), findsOneWidget);
  });

  testWidgets('推しメニューの「着替え・ショップ」が開く（coinServiceProvider の配線の回帰）', (tester) async {
    final coin = await tester.runAsync(() => coinOutfitOverrides('test'));
    await pumpApp(tester, extra: coin!);
    // 推しカードのメニュー（⋮ 相当）を開く。
    final menu = find.descendant(of: find.byType(UkalabOshiCard), matching: find.byType(PopupMenuButton<Object>));
    expect(menu, findsWidgets);
    await tester.tap(menu.first);
    await settle(tester);
    await tester.tap(find.text('着替え・ショップ'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(WardrobeScreen), findsOneWidget);
  });

  testWidgets('答え合わせ・次の問題へのダブルタップは2回目を無視する（連打ガード）', (tester) async {
    BokiTapGuard.duration = const Duration(milliseconds: 450);
    addTearDown(() => BokiTapGuard.duration = null);
    var next = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChoiceQuestionView(
          prompt: 'Q',
          choices: const ['a', 'b'],
          answerIndex: 0,
          explanation: '解説',
          onNext: () => next++,
        ),
      ),
    ));
    // 表示直後の答え合わせは無視される（問題切替直後のダブルタップ）。
    await tester.tap(find.text('a'));
    await tester.pump();
    await tester.tap(find.text('答え合わせ'));
    await tester.pump();
    expect(find.text('次の問題へ'), findsNothing);

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.tap(find.text('答え合わせ'));
    await tester.pump();
    expect(find.text('次の問題へ'), findsOneWidget);
    // 答え合わせ直後の「次の問題へ」は無視される（解説を見ずに進まない）。
    await tester.tap(find.text('次の問題へ'));
    await tester.pump();
    expect(next, 0);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.tap(find.text('次の問題へ'));
    await tester.pump();
    expect(next, 1);
  });

  testWidgets('模擬の結果「分野ごと」は科目（第1〜3問）単位で集計され、同名の行が並ばない', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: studyNotesTestOverrides(),
      child: MaterialApp(home: MockExamPage(progressStore: InMemoryProgressStore())),
    ));
    for (var i = 0; i < 30 && find.text('模擬試験を開始する').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
    final card = tester.widget<MockExamAnalysisCard>(find.byType(MockExamAnalysisCard));
    final ids = card.analysis.topics.map((t) => t.topicId).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.length, lessThanOrEqualTo(3));
    expect(ids.every((id) => id.startsWith('q')), isTrue);
    expect(card.analysis.answered, 20);
  });

  testWidgets('答え合わせで解答記録が変わっても setState の Future 警告が出ない（推しカード）', (tester) async {
    await pumpApp(tester);
    progressRevision.value++;
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
