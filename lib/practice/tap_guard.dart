import 'package:flutter/widgets.dart';

/// 「答え合わせ」「次の問題へ」の素早い連続タップ（ダブルタップ）による誤操作を防ぐ設定。
/// app_common_kit v3.11.0 の KitTapGuard と同じ考え方（問題の切替・答え合わせの直後の約0.45秒は無視）。
class BokiTapGuard {
  BokiTapGuard._();

  /// 実アプリでの既定の無視時間。
  static const defaultDuration = Duration(milliseconds: 450);

  /// 無視する時間。null なら既定: 実アプリでは [defaultDuration]、Flutter のテスト環境では無効。
  /// 明示指定すればテスト環境でも有効になる。[Duration.zero] で常に無効。
  static Duration? duration;

  static Duration get effectiveDuration {
    final d = duration;
    if (d != null) return d;
    final testing = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    return testing ? Duration.zero : defaultDuration;
  }
}

/// 問題画面の State に混ぜる。画面の表示開始と [startTapGuard] の呼び出しから一定時間、
/// [guardTap] で包んだボタンの押下を無視する。
mixin TapGuardMixin<T extends StatefulWidget> on State<T> {
  DateTime? _guardUntil;

  @override
  void initState() {
    super.initState();
    startTapGuard();
  }

  /// 以後 [BokiTapGuard.effectiveDuration] の間、[guardTap] のボタンを無視する。
  void startTapGuard() {
    final d = BokiTapGuard.effectiveDuration;
    _guardUntil = d <= Duration.zero ? null : DateTime.now().add(d);
  }

  bool get isTapGuarded {
    final until = _guardUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  VoidCallback? guardTap(VoidCallback? onTap) {
    if (onTap == null) return null;
    return () {
      if (isTapGuarded) return;
      onTap();
    };
  }
}
