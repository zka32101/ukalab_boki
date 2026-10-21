import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';

/// 資格専用キャラ（ソロ）の出し分けに必要な override。
///
/// appId は資格id（`UkalabCert.boki3.id`）の綴り `boki3`。core の `soro.appIds` と一致させる。
/// プレミアム判定は権利状態（[entitlementStateProvider]）に追従する。
const boki3CharacterAppId = 'boki3';

List<Override> boki3CharacterOverrides() => [
      characterAppIdProvider.overrideWithValue(boki3CharacterAppId),
      characterPremiumProvider.overrideWith(
        (ref) => (ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium,
      ),
    ];
