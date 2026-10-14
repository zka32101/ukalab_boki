import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 文字切れ・はみ出し検証用の画面条件（幅・高さ・文字倍率）。
/// 高さは実機の小型端末相当（縦スクロールしない固定部分のはみ出しも検出するため、
/// 極端に高くしない）。
class ScreenCase {
  const ScreenCase(this.width, this.height, this.scale);
  final double width;
  final double height;
  final double scale;

  @override
  String toString() => '幅${width.toInt()}x高${height.toInt()}・文字$scale倍';
}

const overflowCases = [
  ScreenCase(320, 640, 1),
  ScreenCase(320, 640, 2),
  ScreenCase(320, 640, 3),
  ScreenCase(280, 600, 1),
  ScreenCase(280, 600, 2),
  ScreenCase(280, 600, 3),
];

void applyScreen(WidgetTester tester, ScreenCase c) {
  tester.view.physicalSize = Size(c.width, c.height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = c.scale;
  // 推しなどの常時アニメーションで pumpAndSettle が終わらないのを避ける。
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// 描画中に出たフレームワークの例外（RenderFlex overflow など）を集める。
/// 複数同時に出ても取りこぼさないよう、[FlutterError.onError] を差し替えて記録する。
class ErrorCollector {
  ErrorCollector() {
    _original = FlutterError.onError;
    FlutterError.onError = (details) => _errors.add(_summarize(details));
  }

  late final void Function(FlutterErrorDetails)? _original;
  final List<String> _errors = [];

  static String _summarize(FlutterErrorDetails d) {
    final text = d.exceptionAsString();
    final first = text.split('\n').first;
    final where = RegExp(r'file:///[^\s:]+/((?:lib|test)/[^\s:]+:\d+)').firstMatch(d.toString());
    final w = where == null ? '' : ' @${where.group(1)}';
    return '$first$w';
  }

  /// 溜まった例外を取り出して空にする。
  String drain() {
    final s = _errors.toSet().join('\n');
    _errors.clear();
    return s;
  }

  void dispose() => FlutterError.onError = _original;
}

/// 例外メッセージを「場所・辺」ごとに集計する（画面ごとの件数・最大はみ出し量つき）。
class ProblemTally {
  final Map<String, List<String>> _owners = {};
  final Map<String, int> _maxPx = {};

  void add(String owner, String errors) {
    for (final line in errors.split('\n')) {
      if (line.trim().isEmpty) continue;
      final px = RegExp(r'by ([\d.]+) pixels').firstMatch(line);
      final key = line.replaceAll(RegExp(r'by [\d.]+ pixels'), 'by N pixels');
      (_owners[key] ??= []).add(owner);
      final v = double.tryParse(px?.group(1) ?? '')?.ceil() ?? 0;
      if (v > (_maxPx[key] ?? 0)) _maxPx[key] = v;
    }
  }

  bool get isEmpty => _owners.isEmpty;

  @override
  String toString() => [
        for (final e in _owners.entries)
          '${e.key} [${e.value.length}件, 最大${_maxPx[e.key]}px] 例: ${e.value.take(3).join(',')}',
      ].join('\n');
}

extension ProblemTallyReport on ProblemTally {
  /// 失敗時に切り分けしやすいよう、1件1行で標準出力にも出す（失敗が無ければ何も出さない）。
  void report(String name) {
    for (final line in toString().split('\n').where((l) => l.isNotEmpty)) {
      // ignore: avoid_print
      print('TALLY|$name|${line.replaceAll('\n', ' ')}');
    }
  }
}
