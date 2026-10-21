import 'package:app_common_kit/app_common_kit.dart' show FakeEntitlementService, PurchaseSection, entitlementServiceProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/main.dart';
import 'package:ukalab_boki3/oshi/boki3_character_overrides.dart';
import 'package:ukalab_boki3/purchase/purchase_guide_page.dart';
import 'package:ukalab_core/ui.dart';

import 'test_support.dart';

/// ロック中の資格専用キャラ（ソロ）のプレビューから、購入欄へ誘導する配線の回帰テスト。
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

  Future<void> pumpApp(WidgetTester tester) async {
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
        ...boki3CharacterOverrides(),
      ],
      child: const UkalabBoki3App(),
    ));
    await settle(tester);
  }

  testWidgets('ホームの推しカードに onLockedTap が渡っている', (tester) async {
    await pumpApp(tester);
    final card = tester.widget<UkalabOshiCard>(find.byType(UkalabOshiCard));
    expect(card.onLockedTap, isNotNull);
    expect(card.appId, 'boki3');
  });

  testWidgets('無料のとき、ソロのプレビューの「プレミアムを見る」で選択画面を閉じ、購入欄の画面が開く', (tester) async {
    await pumpApp(tester);
    final menu = find.descendant(of: find.byType(UkalabOshiCard), matching: find.byType(PopupMenuButton<Object>));
    await tester.tap(menu.first);
    await settle(tester);
    await tester.tap(find.text('推しを選ぶ'));
    await settle(tester);
    expect(find.byType(CharacterSelectScreen), findsOneWidget);

    // ロック中のソロをタップするとプレビューが開く。
    await tester.tap(find.text('ソロ'));
    await settle(tester);
    expect(find.text('プレミアムを見る'), findsOneWidget);

    await tester.tap(find.text('プレミアムを見る'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(CharacterSelectScreen), findsNothing);
    expect(find.byType(PurchaseGuidePage), findsOneWidget);
    expect(find.byType(PurchaseSection), findsOneWidget);
  });
}
