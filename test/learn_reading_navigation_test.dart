import 'package:app_common_kit/app_common_kit.dart' show FakeEntitlementService, entitlementServiceProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ukalab_boki3/main.dart';
import 'test_support.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('「学ぶ」タブから解説読み物の一覧を開き、1本の詳細を読める', (WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [entitlementServiceProvider.overrideWithValue(FakeEntitlementService()), ...studyNotesTestOverrides()],
      child: const UkalabBoki3App(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('学ぶ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('章ごとの解説読み物'), 100);
    await tester.pumpAndSettle();
    await tester.tap(find.text('章ごとの解説読み物'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('第1問 仕訳'), findsOneWidget);
    expect(find.text('1 仕訳の基本（取引・借方と貸方）'), findsOneWidget);

    await tester.tap(find.text('1 仕訳の基本（取引・借方と貸方）'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('簿記上の取引とは'), findsOneWidget);
  });
}
