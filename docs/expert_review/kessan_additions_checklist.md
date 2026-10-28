# 決算（q3_kessan）追加分の専門確認チェックリスト

- 対象: 2026-10 追加の 30 問（仕訳 22・択一 8）。すべて `source: original`。AI が下書きしたもの。**専門家確認済み（2026-10-28）**: `ai-draft` タグを外し、sourceRef を「AI下書き・専門家確認済み」に更新済み（確認時点では `tags: [ai-draft]`・`contentVer: 2026.10.0`）。
- 必要な専門性: 簿記講師・日商簿記3級の指導経験者
- 新形式（○×・空欄・逆引き）は使っていない。`kNewQuestionTypesEnabled` は変更しない。
- 反映は別PRで。確認後に `ai-draft` を外した。記録は確認日（年月）と確認者区分のみ（氏名は記録しない）。

## 専門家に確認してほしい点

1. **勘定科目の選び方**
   - 前払保険料・前払家賃は `prepaid_expense`（前払費用）、未払利息・未払家賃は `unpaid_expense`（未払費用）、受取利息・地代の前受けは `unearned_revenue`（前受収益）、未収地代は `accrued_income`（未収収益）で統一した。これで答えとして足りるか。「前払保険料」「未払利息」など個別の科目名を求めるべきか。
   - 貸倒引当金が設定額を上回る場合に `allowance_reversal`（貸倒引当金戻入）を使った（j-0161）。3級で戻入として扱う範囲か。
   - 消耗品・切手の未使用分は `stored_goods`（貯蔵品）とした（j-0174）。貸方を消耗品費と通信費の2行に分ける形式でよいか。項番が未突合。
   - 売上原価の算定は仕入勘定で行う4行の複合仕訳（j-0163, j-0164）。2組の仕訳に分けて答える形式のほうがよいか。
   - 現金過不足（j-0172, j-0173）は旧区分表のみ（`levelId: level3_until_2027_03`）。原因が一部判明・一部不明の分割仕訳と、雑損・雑益の使い方が妥当か。
2. **端数処理**
   - 月割計算はすべて整数になるよう数値を選んだ（端数は出ない）。月割で1か月未満を数える設定（月初取得）は使っていない。この前提で足りるか。
   - 貸倒引当金の率（2%、2.5%、1.5%）で端数が出ない設定にしている。
3. **問題文の曖昧さ**
   - 期間の数え方（例: 10/1から12か月、6/1から1年、8月末・2月末払い）が一意に読めるか。
   - j-0162 は「前期末に設定した24,000円のうち当期に10,000円を引当金で処理、決算整理前残高14,000円」。前提が冗長で混乱しないか。
   - c-0055 の資料（決算整理前の数値と未計上の項目が混在）が曖昧でないか。
   - c-0051 の選択肢の言い回し。
4. **範囲外として除外した項目**
   - 当座借越、引出金は、3級の範囲かどうかが `docs/accounts_v1_official.md` で未確定で、勘定科目マスタにも無いため、今回は作問していない。範囲かどうかの判断も依頼したい。

## 追加した問題の一覧

| qid | 形式 | topicId | 難易度 | 確認してほしい点 |
|---|---|---|---|---|
| boki3-j-0154 | 仕訳 | dep_indirect_basic | 1 | — |
| boki3-j-0155 | 仕訳 | dep_direct_basic | 2 | 直接法の貸方科目 |
| boki3-j-0156 | 仕訳 | dep_residual_value | 3 | 残存価額を取得原価の10%とする設定が3級で出題されるか |
| boki3-j-0157 | 仕訳 | dep_partial_indirect | 4 | 月割計算（9か月）と端数なし。月割の取得日の数え方（月初取得） |
| boki3-j-0158 | 仕訳 | dep_partial_direct | 4 | 同上（5か月、直接法） |
| boki3-j-0159 | 仕訳 | allowance_first_set | 2 | — |
| boki3-j-0160 | 仕訳 | allowance_multi_receivable | 3 | 電子記録債権を含める点、率2.5%（端数なし） |
| boki3-j-0161 | 仕訳 | allowance_excess_reversal | 3 | 貸倒引当金戻入(allowance_reversal)の科目選択。決算整理前残高が設定額を上回る処理が3級範囲か |
| boki3-j-0162 | 仕訳 | allowance_after_writeoff | 4 | 「前期末設定24,000円のうち当期に10,000円を引当金で処理」→残高14,000円という前提が分かりやすいか |
| boki3-j-0163 | 仕訳 | cogs_open_close | 3 | 複合仕訳(4行)の形式で解答できるか。「仕入勘定で算定」との明記が十分か |
| boki3-j-0164 | 仕訳 | cogs_count_unit_cost | 4 | 数量×単価で期末棚卸高を出す設定の自然さ |
| boki3-j-0165 | 仕訳 | cogs_closing_only | 1 | 期首商品なしの設定が現実的か |
| boki3-j-0166 | 仕訳 | prepaid_insurance_oct | 2 | 前払費用(prepaid_expense)を用いる科目選択（前払保険料との表記差） |
| boki3-j-0167 | 仕訳 | prepaid_rent_june | 3 | 同上。支払期間が6/1〜5/31で月割2か月になる点 |
| boki3-j-0168 | 仕訳 | accrued_interest_borrowing | 3 | 利払日が年2回で「見越し」の期間が4か月になる前提が読み取れるか。未払費用と未払金の使い分け |
| boki3-j-0169 | 仕訳 | accrued_land_rent_income | 4 | 後払い地代の見越し。受取地代(land_rent_income)と受取家賃の区別、未収収益の科目名 |
| boki3-j-0170 | 仕訳 | unearned_interest_nov | 3 | 前受収益(unearned_revenue)の科目選択。受取利息の繰延べが3級範囲か |
| boki3-j-0171 | 仕訳 | reversal_prepaid_insurance | 2 | 再振替仕訳の科目選択と、期首日の仕訳として問題文が明確か |
| boki3-j-0172 | 仕訳 | cash_diff_debit_partly_known | 4 | 現金過不足は旧区分表のみ(levelId=level3_until_2027_03)。原因判明分と不明分の分割仕訳が出題範囲か |
| boki3-j-0173 | 仕訳 | cash_diff_credit_partly_known | 3 | 同上。雑益(miscellaneous_income)の科目選択 |
| boki3-j-0174 | 仕訳 | stored_goods_supplies_stamps | 3 | 貯蔵品の項番が未突合。消耗品費・通信費を貸方に分けて貸方2行にする形式の妥当性 |
| boki3-j-0175 | 仕訳 | accrued_rent_semiannual | 3 | 未払家賃を月割(1/6)で出す前提が分かりやすいか |
| boki3-c-0048 | 択一 | accumulated_depreciation_presentation | 1 | 表示区分の説明の正確さ |
| boki3-c-0049 | 択一 | net_receivable_presentation | 2 | 貸借対照表の純額表示（控除形式）の説明 |
| boki3-c-0050 | 択一 | dep_residual_calc | 3 | 残存価額の割合を用いる定額法の計算 |
| boki3-c-0051 | 択一 | worksheet_prepaid_column | 3 | 精算表の欄の選択肢の言い回し |
| boki3-c-0052 | 択一 | cogs_calc_amount | 4 | 「純仕入高」の用語使用 |
| boki3-c-0053 | 択一 | allowance_calc_amount | 4 | 選択肢の誤答設計（差額補充を誤った値） |
| boki3-c-0054 | 択一 | insurance_pl_amount | 4 | 前払分の表現（168,000円が試算表上の全額であることの明確さ） |
| boki3-c-0055 | 択一 | net_income_calc | 4 | 資料の記載（決算整理前/後の混在）が曖昧でないか、受取利息を含める点 |

確認列（OK / 修正 / 削除、確認日、確認者区分）は、確認時にこの表の右に追記する。
