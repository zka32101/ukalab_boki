import 'package:cross_promo_kit/cross_promo_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/settings/cross_promo_config.dart';
import 'package:ukalab_boki3/settings/settings_page.dart';

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

  testWidgets('appsOverride を渡すと紹介カードが例外なく表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              CrossPromoSection(
                currentAppId: kCrossPromoAppId,
                currentCategory: kCrossPromoCategory,
                appsOverride: [
                  PromotedApp(
                    id: 'com.example.other',
                    name: 'テストアプリ',
                    tagline: '紹介文',
                    iconUrl: '',
                    storeUrl: 'https://play.google.com/store/apps/details?id=com.example.other',
                    category: kCrossPromoCategory,
                  ),
                ],
              ),
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
