# 解説読み物（表・手順）と出題範囲による出し分け

ukalab_core v0.87.0 の読み物機能を使う。データは `assets/exam/boki3.readings.jsonl`（既存の読み物と同じファイル）。

## 出題範囲（levelId）による出し分け

- 読み物は任意の `levelId` を持てる。省略した読み物は全範囲向け（既存の13本）。
- 一覧（`ReadingListPage`）と、選択式を間違えたときの「読み物でおさらい」は、`readingsForLevel(readings, currentLevelId())` で現在の範囲に合う読み物だけを使う（`loadChapterReadingsForCurrentLevel`）。
- `currentLevelId()` は日付で決まる。〜2027-03-31 は `level3_until_2027_03`、2027-04-01〜は `level3_from_2027_04`。問題データの `levelId` による出し分けと同じ仕組み。

| 読み物 | levelId | 〜2027-03 | 2027-04〜 |
|---|---|---|---|
| 1〜13（既存） | なし | 出る | 出る |
| 14 固定資産の除却・廃棄 | `level3_from_2027_04` | 出ない | 出る |

除却・廃棄は2027-04から3級の範囲に入るため、新範囲限定にしている。関連問題（`boki3-j-0176`〜`0181`、`boki3-c-0057`/`0058`）も新範囲の問題。

## 表示

- 表・手順・図の節を含む読み物は `ReadingSectionContent` で描画する（`ReadingRichBody`）。本文だけの既存の読み物は従来の `ChapterReadingWidget` のまま（用語タップ・読み上げも従来どおり）。
- 末尾に関連用語、例題の解説（`ExplanationCard.fromPlain`）、確認問題リンク（`ReadingQuestionLinks`）を出す。
- 切り戻し用に `kReadingExplanationEnabled`（`lib/exam_data/feature_flags.dart`、既定 true）。false で従来の表示・導線なしに戻る。

## 誤答時の導線

選択式の結果表示は、すでに `AnswerFeedbackPanel`（誤答原因の選択欄つき）を使っているため、その `relatedReadings` / `onOpenReading` で出す。`RelatedReadingsCard` を別に置くと原因欄と二重になるので使わない。仕訳・帳簿・精算表は結果バナーに行ごとの診断があるため、従来どおり読み物導線は出さない。

## 表の作り方（スマホ幅）

core の表は4列以上で内容に応じた列幅になり、収まらないと横スクロールになる。幅390で3列目までしか見えないため、この読み物の表は3列以下にした（列を統合）。新しく表を足すときも、まず3列以下を目安にする。

## 出典（sourceRef）

AI下書き由来の自作で、体験コンテンツのため専門家確認は不要と判断した。`sourceRef` は「自作(AI下書き由来。体験コンテンツのため専門家確認は不要と判断)」とし、「専門家確認済み」とは書かない。`contentVer` は既存の読み物と同じ `"1"`。

## テスト

`test/reading_explanation_test.dart`（データ検証・日付ごとの出し分け・画面）。core v0.87.0 は4文字以上の数字語に U+2060 を入れるため、完全一致の検索は U+2060 を除いて比べる。
