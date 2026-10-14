import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 長い題名を「…」で省略せず折り返して全部見せる AppBar。
///
/// 標準の AppBar は題名を1行に固定し、はみ出した分を省略する。会社名＋進み具合（3/7）や
/// 「第2問 帳簿・伝票等を練習する」のような題名は、狭い画面や大きい文字で大事な部分が消えるため、
/// 最大3行まで折り返し、その分だけ高さを広げる（1行で収まるときは標準の高さのまま）。
AppBar wrappingAppBar(BuildContext context, String title) {
  final theme = Theme.of(context);
  final style = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge ?? const TextStyle(fontSize: 22);
  final media = MediaQuery.of(context);
  // AppBar の題名は文字倍率が 1.34 倍までに抑えられる。測るときも同じ条件にする。
  final scaler = _ClampedScaler(media.textScaler, 1.34);
  // 戻るボタン(56)と左右の余白(32)を除いた幅。
  final maxWidth = math.max(0.0, media.size.width - 56 - 32);
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: Directionality.of(context),
    textScaler: scaler,
    maxLines: 3,
  )..layout(maxWidth: maxWidth);
  final height = math.max(kToolbarHeight, painter.height + 16);
  painter.dispose();
  return AppBar(
    toolbarHeight: height,
    title: Text(title, maxLines: 3, softWrap: true, overflow: TextOverflow.ellipsis),
  );
}

class _ClampedScaler extends TextScaler {
  const _ClampedScaler(this.base, this.maxFactor);

  final TextScaler base;
  final double maxFactor;

  @override
  double scale(double fontSize) => math.min(base.scale(fontSize), fontSize * maxFactor);

  @override
  double get textScaleFactor => scale(14) / 14;
}
