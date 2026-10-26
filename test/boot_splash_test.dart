import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_boki3/startup/boot_splash.dart';
import 'package:ukalab_core/ui.dart' show UkalabStartupSplash;

void main() {
  testWidgets('BootSplashApp は UkalabStartupSplash にアイコンと背景色を渡す', (tester) async {
    await tester.pumpWidget(const BootSplashApp());
    final splash =
        tester.widget<UkalabStartupSplash>(find.byType(UkalabStartupSplash));
    expect(splash.iconAsset, kBootSplashIconAsset);
    expect(splash.backgroundColor, kBootSplashBackground);
    expect(kBootSplashBackground, const Color(0xFFA35600));
    expect(find.byType(Image), findsWidgets);
  });
}
