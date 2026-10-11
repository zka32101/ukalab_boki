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

  testWidgets('起動してホーム画面と下部5タブが表示される', (WidgetTester tester) async {
    // 推しは動き続けるので、「動きを減らす」設定にして pumpAndSettle が終わるようにする。
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(ProviderScope(
        overrides: [entitlementServiceProvider.overrideWithValue(FakeEntitlementService()), ...studyNotesTestOverrides()],
        child: const UkalabBoki3App(),
      ));
    await tester.pumpAndSettle();

    expect(find.text('うかラボ 簿記3級'), findsOneWidget);
    for (final label in const ['ホーム', '学ぶ', '模擬', '記録', '設定']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
