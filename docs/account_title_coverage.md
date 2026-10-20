# 勘定科目カバレッジ（簿記3級 問題データ）

- 集計対象: `assets/exam/boki3.questions.jsonl`（追加前 241 問 → 追加後 259 問）
- 科目の範囲: `lib/journal_input/account_catalog.dart` の `boki3Accounts`（`docs/accounts_v1_official.md` 確定版 v1、2027年4月以降の新区分表ベース）。旧区分表のみの科目（受取手形・支払手形・現金過不足・損益）は別表に掲載
- 「解答」= 仕訳・精算表の正解行に科目コードが出る問題数、「文面」= 問題文・選択肢・穴埋め・手がかり・解説に科目名が出る問題数（`仕入れ`/`売上げ`/`売上原価`等の動詞・別科目は除外してマスク）、「合計」= 両者の和集合（1問は1回だけ数える）
- 「不足」= 追加前の合計が1問以下の科目（0問の科目はなし）。`test/account_coverage_test.dart` が同様の集計で「全科目が2問以上に登場すること」を検証する

| 区分 | 科目 | コード | 解答(前) | 文面(前) | 合計(前) | 合計(後) | 判定 |
|---|---|---|---:|---:|---:|---:|---|
| 資産 | 現金 | `cash` | 56 | 82 | 82 | 85 |  |
| 資産 | 小口現金 | `petty_cash` | 1 | 3 | 3 | 3 |  |
| 資産 | 当座預金 | `checking_deposit` | 9 | 13 | 13 | 15 |  |
| 資産 | 普通預金 | `ordinary_deposit` | 17 | 19 | 19 | 23 |  |
| 資産 | 定期預金 | `time_deposit` | 2 | 2 | 2 | 2 |  |
| 資産 | 売掛金 | `accounts_receivable` | 20 | 47 | 47 | 49 |  |
| 資産 | クレジット売掛金 | `credit_accounts_receivable` | 2 | 2 | 2 | 2 |  |
| 資産 | 電子記録債権 | `electronic_receivable` | 2 | 3 | 3 | 3 |  |
| 資産 | 貸付金 | `loan_receivable` | 3 | 6 | 6 | 6 |  |
| 資産 | 立替金 | `advance_paid` | 2 | 2 | 2 | 2 |  |
| 資産 | 未収入金 | `accrued_revenue` | 1 | 2 | 2 | 2 |  |
| 資産 | 前払金 | `advance_payment` | 2 | 7 | 7 | 8 |  |
| 資産 | 前払費用 | `prepaid_expense` | 3 | 4 | 4 | 4 |  |
| 資産 | 未収収益 | `accrued_income` | 3 | 4 | 4 | 4 |  |
| 資産 | 仮払金 | `temporary_payment` | 3 | 3 | 3 | 4 |  |
| 資産 | 受取商品券 | `gift_certificates_receivable` | 2 | 2 | 2 | 2 |  |
| 資産 | 差入保証金 | `guarantee_deposit` | 1 | 1 | 1 | 3 | 不足→追加 |
| 資産 | 繰越商品 | `merchandise_inventory` | 2 | 4 | 4 | 4 |  |
| 資産 | 有価証券 | `securities` | 3 | 3 | 3 | 7 |  |
| 資産 | 貯蔵品 | `stored_goods` | 3 | 3 | 3 | 3 |  |
| 資産 | 建物 | `building` | 2 | 4 | 4 | 7 |  |
| 資産 | 備品 | `equipment` | 11 | 24 | 24 | 28 |  |
| 資産 | 車両運搬具 | `vehicle` | 1 | 1 | 1 | 3 | 不足→追加 |
| 資産 | 土地 | `land` | 3 | 5 | 5 | 8 |  |
| 資産 | 減価償却累計額 | `accumulated_depreciation` | 9 | 13 | 13 | 13 |  |
| 資産 | 貸倒引当金 | `allowance_for_doubtful_accounts` | 5 | 9 | 9 | 10 |  |
| 資産 | 仮払消費税 | `suspense_paid_consumption_tax` | 4 | 6 | 6 | 6 |  |
| 負債 | 買掛金 | `accounts_payable` | 13 | 32 | 33 | 33 |  |
| 負債 | 電子記録債務 | `electronic_payable` | 2 | 3 | 3 | 3 |  |
| 負債 | 借入金 | `borrowings` | 3 | 8 | 8 | 8 |  |
| 負債 | 未払金 | `accrued_payable` | 4 | 7 | 7 | 7 |  |
| 負債 | 前受金 | `advance_received` | 3 | 10 | 10 | 10 |  |
| 負債 | 預り金 | `deposit_received` | 2 | 4 | 4 | 5 |  |
| 負債 | 仮受金 | `temporary_receipt` | 3 | 5 | 5 | 6 |  |
| 負債 | 未払費用 | `unpaid_expense` | 9 | 9 | 9 | 9 |  |
| 負債 | 前受収益 | `unearned_revenue` | 3 | 4 | 4 | 4 |  |
| 負債 | 未払法人税等 | `unpaid_corporate_tax` | 3 | 3 | 3 | 4 |  |
| 負債 | 未払消費税 | `unpaid_consumption_tax` | 4 | 4 | 4 | 4 |  |
| 負債 | 仮受消費税 | `suspense_received_consumption_tax` | 3 | 5 | 5 | 5 |  |
| 純資産 | 資本金 | `capital_stock` | 2 | 7 | 7 | 7 |  |
| 純資産 | 利益準備金 | `legal_reserve` | 1 | 1 | 1 | 3 | 不足→追加 |
| 純資産 | 繰越利益剰余金 | `retained_earnings` | 1 | 3 | 3 | 4 |  |
| 収益 | 売上 | `sales` | 11 | 26 | 26 | 26 |  |
| 収益 | 受取家賃 | `rent_income` | 3 | 3 | 3 | 3 |  |
| 収益 | 受取地代 | `land_rent_income` | 2 | 2 | 2 | 3 |  |
| 収益 | 受取手数料 | `commission_income` | 2 | 5 | 5 | 5 |  |
| 収益 | 受取利息 | `interest_income` | 6 | 7 | 7 | 8 |  |
| 収益 | 固定資産売却益 | `gain_on_disposal_of_fixed_assets` | 2 | 2 | 2 | 4 |  |
| 収益 | 償却債権取立益 | `bad_debt_recovery` | 1 | 1 | 1 | 3 | 不足→追加 |
| 収益 | 貸倒引当金戻入 | `allowance_reversal` | 1 | 2 | 2 | 3 |  |
| 収益 | 雑益 | `miscellaneous_income` | 2 | 2 | 2 | 2 |  |
| 収益 | 有価証券売却益 | `gain_on_sale_of_securities` | 1 | 1 | 1 | 4 | 不足→追加 |
| 費用 | 仕入 | `purchases` | 17 | 36 | 37 | 38 |  |
| 費用 | 発送費 | `shipping_expense` | 1 | 1 | 1 | 3 | 不足→追加 |
| 費用 | 給料 | `salary` | 7 | 13 | 13 | 13 |  |
| 費用 | 法定福利費 | `statutory_welfare_expense` | 2 | 2 | 2 | 2 |  |
| 費用 | 広告宣伝費 | `advertising_expense` | 2 | 2 | 2 | 2 |  |
| 費用 | 旅費交通費 | `travel_expense` | 4 | 4 | 4 | 5 |  |
| 費用 | 通信費 | `communication_expense` | 6 | 7 | 7 | 8 |  |
| 費用 | 消耗品費 | `supplies_expense` | 5 | 8 | 8 | 9 |  |
| 費用 | 水道光熱費 | `utilities_expense` | 2 | 4 | 4 | 4 |  |
| 費用 | 支払家賃 | `rent_expense` | 6 | 6 | 6 | 8 |  |
| 費用 | 支払地代 | `land_rent_expense` | 1 | 1 | 1 | 3 | 不足→追加 |
| 費用 | 保険料 | `insurance_expense` | 2 | 5 | 5 | 5 |  |
| 費用 | 修繕費 | `repair_expense` | 1 | 2 | 2 | 2 |  |
| 費用 | 雑費 | `miscellaneous_expense` | 1 | 2 | 2 | 2 |  |
| 費用 | 貸倒損失 | `bad_debt_expense` | 1 | 2 | 2 | 3 |  |
| 費用 | 貸倒引当金繰入 | `provision_for_doubtful_accounts` | 4 | 5 | 5 | 5 |  |
| 費用 | 支払利息 | `interest_expense` | 6 | 6 | 6 | 7 |  |
| 費用 | 支払手数料 | `commission_expense` | 2 | 1 | 2 | 2 |  |
| 費用 | 減価償却費 | `depreciation_expense` | 9 | 15 | 15 | 16 |  |
| 費用 | 固定資産売却損 | `loss_on_disposal_of_fixed_assets` | 1 | 1 | 1 | 3 | 不足→追加 |
| 費用 | 租税公課 | `tax_and_dues` | 3 | 4 | 4 | 4 |  |
| 費用 | 法人税、住民税及び事業税 | `corporate_tax` | 2 | 3 | 3 | 3 |  |
| 費用 | 雑損 | `miscellaneous_loss` | 2 | 2 | 2 | 4 |  |
| 費用 | 有価証券売却損 | `loss_on_sale_of_securities` | 1 | 1 | 1 | 4 | 不足→追加 |

## 旧区分表のみの科目（〜2027年3月実施分向け）

| 科目 | コード | 合計(前) | 合計(後) |
|---|---|---:|---:|
| 受取手形 | `notes_receivable` | 7 | 7 |
| 支払手形 | `notes_payable` | 6 | 6 |
| 現金過不足 | `cash_over_short` | 5 | 5 |
| 損益 | `income_summary` | 15 | 15 |

※旧区分表のみの科目も、解答の科目コードと文面（科目名）の和集合で集計している。

## 不足科目と追加した問題

追加分はすべて `tags: ["ai-draft"]` と sourceRef 末尾「（AI下書き・要確認）」を付与（既存の ai-draft 規則どおり）。1科目あたり 仕訳(journal) 1問＋選択式(choice) 1問、計18問。専門家確認が済むまで正式な出題内容として扱わないこと。

| 科目 | コード | 追加前 | 追加後 | 追加qid |
|---|---|---:|---:|---|
| 差入保証金 | `guarantee_deposit` | 1 | 3 | boki3-j-0147, boki3-c-0041 |
| 車両運搬具 | `vehicle` | 1 | 3 | boki3-j-0152, boki3-c-0046 |
| 利益準備金 | `legal_reserve` | 1 | 3 | boki3-j-0149, boki3-c-0043 |
| 償却債権取立益 | `bad_debt_recovery` | 1 | 3 | boki3-j-0145, boki3-c-0039 |
| 有価証券売却益 | `gain_on_sale_of_securities` | 1 | 4 | boki3-j-0146, boki3-c-0040 |
| 発送費 | `shipping_expense` | 1 | 3 | boki3-j-0151, boki3-c-0045 |
| 支払地代 | `land_rent_expense` | 1 | 3 | boki3-j-0148, boki3-c-0042 |
| 固定資産売却損 | `loss_on_disposal_of_fixed_assets` | 1 | 3 | boki3-j-0150, boki3-c-0044 |
| 有価証券売却損 | `loss_on_sale_of_securities` | 1 | 4 | boki3-j-0153, boki3-c-0047 |
