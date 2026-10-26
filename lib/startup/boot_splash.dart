import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart' show UkalabStartupSplash;

/// アイコン背景の茶色。Android のネイティブ起動画面
/// (`res/values/colors.xml` の `launch_background_color`) と同じ値にする。
const Color kBootSplashBackground = Color(0xFFA35600);

/// 起動アイコンのアセット。
const String kBootSplashIconAsset = 'assets/branding/app_icon.png';

/// 初期化（設定・進捗の復元など）が終わるまで出す画面。
/// ネイティブ起動画面と同じ背景色で、端末側の画面から切れ目なくつなげる。
class BootSplashApp extends StatelessWidget {
  const BootSplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UkalabStartupSplash(
        iconAsset: kBootSplashIconAsset,
        backgroundColor: kBootSplashBackground,
      ),
    );
  }
}
