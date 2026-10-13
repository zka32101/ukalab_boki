import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:ukalab_core/src/cross_promo_test_support.dart';

import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/settings/cross_promo_config.dart';
import 'package:ukalab_boki3/settings/settings_page.dart';

const _list = '''
[
  {"id":"com.example.other","name":"テストアプリ","tagline":"紹介文","iconUrl":"","storeUrl":"https://play.google.com/store/apps/details?id=com.example.other","category":"うかラボ"}
]
''';

void main() {
  testWidgets('Firebase無しでも設定画面は例外なく表示でき、掲載が空なら紹介は出ない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SettingsPage(progressStore: InMemoryProgressStore()))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('他のアプリもチェック！'), findsNothing);
    expect(find.text('解答記録をリセットする'), findsOneWidget);
  });

  testWidgets('掲載リストがあると紹介カードが例外なく表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ukalabCrossPromoSectionForTest(currentAppId: kCrossPromoAppId, rawJson: _list),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('他のアプリもチェック！'), findsOneWidget);
    expect(find.text('テストアプリ'), findsOneWidget);
  });
}
