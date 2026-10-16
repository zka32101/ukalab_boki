/// 実行環境に応じて使う RevenueCat の公開SDKキーを選ぶ。
///
/// Android は [googleKey]、iOS は [appleKey] を使う。該当キーが空・Web・
/// その他のプラットフォームでは null（＝偽の課金サービスで動く）。
String? selectRevenueCatKey({
  required bool isWeb,
  required bool isAndroid,
  required bool isIOS,
  required String googleKey,
  required String appleKey,
}) {
  if (isWeb) return null;
  if (isAndroid && googleKey.isNotEmpty) return googleKey;
  if (isIOS && appleKey.isNotEmpty) return appleKey;
  return null;
}
