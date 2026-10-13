/// 相互紹介（cross_promo_kit）で自アプリを掲載リストから除外するための ID。
///
/// TODO(要確認): 本番の Android applicationId に置き換える。
/// このリポジトリには android/ が無く、CI・README にも記載がないため未確定。
/// 推測値は入れない（仮の値だと自アプリが自分のリストに出る）。
const String kCrossPromoAppId = 'TODO.confirm.production.application.id';

/// 紹介は同じシリーズ内だけ（docs/ROLLOUT.md の方針）。うかラボ＝資格系。
const String kCrossPromoCategory = 'うかラボ';
