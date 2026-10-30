# 相互紹介（クロスプロモ）

うかラボ各アプリの「他のアプリもチェック！」。共通パッケージ `cross_promo_kit` を、`ukalab_core` の薄いラッパー
（`package:ukalab_core/cross_promo.dart`）経由で使う。独自実装は持たない。

## このアプリの実装

| 項目 | 内容 |
|---|---|
| appId | `com.yourwish.ukalab.boki3`（`lib/settings/cross_promo_config.dart` の `kCrossPromoAppId`。Play の applicationId と一致させる） |
| 起動時 | `lib/main.dart` で `unawaited(UkalabCrossPromo.init())`。Firebase 初期化（未初期化のときだけ）と掲載リスト取得を行う。失敗しても例外を投げず、起動を止めない |
| 画面 | 設定画面「このアプリについて」の直下に `UkalabCrossPromoSection(currentAppId: kCrossPromoAppId)`。問題・模擬試験・復習の画面には置かない |
| 掲載0件 | 何も表示しない（余白も出ない） |
| 対象 | 大人向けのため `isChildDirected` は付けない（既定の false） |
| テスト | `test/settings_cross_promo_test.dart` |

## 掲載リスト（Remote Config）

掲載内容はコードでは変えられない。Firebase Remote Config のキー `cross_promo_apps` に JSON 配列を入れる。
`category` が一致するアプリ同士だけが表示される（うかラボは `うかラボ`）。自アプリ（`currentAppId` と同じ `id`）は除外される。

```json
[
  {
    "id": "<他アプリの applicationId>",
    "name": "<アプリ名>",
    "tagline": "<ひとこと紹介>",
    "iconUrl": "<アイコン画像のURL>",
    "storeUrl": "<Google Play のURL>",
    "category": "うかラボ"
  }
]
```

- 掲載リストの正、検証コマンド、投入手順、プロジェクト単位の管理は `cross_promo_kit` の `docs/ROLLOUT.md` と README を参照。
- 実際のストアURL・アイコンURLは上記の正から取り、ここには書かない。
- 投入先の Firebase プロジェクトと掲載アプリは運営判断。
