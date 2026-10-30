# CHANGELOG

## 未リリース

- 新範囲（2027-04〜、`level3_from_2027_04`）向けの読み物「14 固定資産の除却・廃棄」を追加（表・手順つき）。旧範囲（〜2027-03）の期間は一覧にも誤答導線にも出ないため、現時点で見た目の変更はない。
- 読み物に任意の `levelId` を追加し、`readingsForLevel(readings, currentLevelId())` で出し分け（ukalab_core v0.87.0）。`levelId` のない既存の読み物は全範囲で従来どおり。
- 選択式を間違えたとき、現在の範囲に合う関連読み物へ誘導（`AnswerFeedbackPanel.relatedReadings`）。切り戻し用フラグ `kReadingExplanationEnabled`（既定 true）。
- 出典（sourceRef）は「自作(AI下書き由来。体験コンテンツのため専門家確認は不要と判断)」。
- 詳細は `docs/reading_explanation.md`。
