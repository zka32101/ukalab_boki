import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';

/// 学習コイン・衣装（着替え・ショップ）のサービスを差し込む override。
/// 財布・衣装台帳はアプリごとに端末内保存。ショップには簿記3級の通常衣装（コイン購入）を並べる。
/// 無いと「coinServiceProvider を override してください」で着替え・ショップが開けない。
Future<List<Override>> coinOutfitOverrides(String appKey) async {
  final coinService = CoinService(
    store: SharedPreferencesCoinStore(appKey),
    shop: OutfitCatalog.shopItems([UkalabCert.boki3]),
  );
  await coinService.load();
  final outfitService = OutfitService(store: SharedPreferencesOutfitStore(appKey));
  await outfitService.load();
  return [
    coinServiceProvider.overrideWithValue(coinService),
    outfitServiceProvider.overrideWithValue(outfitService),
  ];
}
