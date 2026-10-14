import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 表の固定列幅にかける倍率。文字倍率が1以下なら1（今の幅のまま）、大きいときはそれに比例して広げる。
double tableTextFactor(BuildContext context) {
  const base = 14.0;
  return math.max(1.0, MediaQuery.textScalerOf(context).scale(base) / base);
}

/// 数字や文字 [sample] を、いまの文字サイズ・文字倍率・フォントで描いたときの幅。
/// 「数字1桁は文字サイズの0.6倍」のような見積もりでなく、実際に測るので、端末のフォントや文字倍率が
/// 変わっても、金額が列からはみ出したり「…」で切れたりしない幅を決められる。
double measureTextWidth(BuildContext context, String sample, {TextStyle? style}) {
  final painter = TextPainter(
    text: TextSpan(text: sample, style: style ?? Theme.of(context).textTheme.bodyMedium),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// 金額（[digits] 桁）が省略されずに入る、表のセルの幅。左右の余白と、答え合わせ後の ✓／✕ アイコン分を含む。
double amountCellWidth(BuildContext context, {required int digits, double cellPadding = 8, double markWidth = 18}) {
  return measureTextWidth(context, '8' * digits) + cellPadding + markWidth;
}
