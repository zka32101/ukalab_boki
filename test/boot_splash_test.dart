import 'package:app_common_kit/app_common_kit.dart' show StartupSplash;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_boki3/startup/boot_splash.dart';

void main() {
  testWidgets('BootSplashApp は StartupSplash にアイコンと背景色を渡す', (tester) async {
    await tester.pumpWidget(const BootSplashApp());
    final splash = tester.widget<StartupSplash>(find.byType(StartupSplash));
    expect(splash.appIconAsset, kBootSplashIconAsset);
    expect(splash.backgroundColor, kBootSplashBackground);
    expect(kBootSplashBackground, const Color(0xFFA35600));
    expect(find.byType(Image), findsWidgets);
  });
}
