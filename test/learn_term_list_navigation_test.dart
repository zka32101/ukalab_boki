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

  testWidgets('「学ぶ」タブから用語集を開ける', (WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(ProviderScope(
        overrides: [entitlementServiceProvider.overrideWithValue(FakeEntitlementService()), ...studyNotesTestOverrides()],
        child: const UkalabBoki3App(),
      ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('学ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用語集'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('用語を検索'), findsOneWidget);
    expect(find.text('仕訳'), findsOneWidget);
  });
}
