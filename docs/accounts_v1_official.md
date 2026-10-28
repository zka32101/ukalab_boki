# 簿記3級 勘定科目一覧（確定版 v1・2027年4月以降の新区分表ベース）

## 出典

- 「商工会議所簿記検定試験出題区分表」（日本商工会議所。1959年9月1日制定、2025年12月25日改定、
  2026年7月31日最終改定、**2027年4月1日施行**）
- 「紙媒体による手形・小切手の廃止および企業会計基準第34号『リースに関する会計基準』等の適用に
  ともなう商工会議所簿記検定試験出題区分表などの改定について【確定版】」（2026年7月31日 日本商工会議所）
- 「簿記検定試験初級　出題範囲・内容」（同日付最終改定。「使用する勘定科目」一覧を実務的な参考として使用）

ユーザーが商工会議所の公式PDFを直接ダウンロードして提供（2026-10-03）。本一覧はこれら一次資料を
Claudeが読み取って作成した。転記ミスの可能性があるため、問題データ作成時は該当箇所を都度この
一覧と突き合わせること。

## 重要な注意（2026年度と2027年度で範囲が異なる）

- **2026年度中（〜2027年3月実施分、ネット試験・統一試験とも）は2022年度適用の旧区分表が
  引き続き適用される。** 旧区分表では手形（受取手形・支払手形）・小切手の振出しが3級の範囲に
  含まれていたと見られるが、**旧区分表（2022年度版）の一次資料は未入手**のため、本一覧には含めない。
  `assets/exam/boki3.exam.json` の `level3_until_2027_03` 向け問題を作る際は別途確認が必要。
- **2027年4月1日以降（`level3_from_2027_04`）は本一覧が確定版として使える。**
- 紙媒体の手形・小切手は全国銀行協会が2026年度末で電子交換所での交換を廃止する方針を受け、
  手形関連の規定は区分表からすべて削除された（小切手も同様。当座預金自体は存続）。
- 今回の改定で3級に新規追加された主な項目: 普通預金（イ．の明記追加）、販売のつど売上原価勘定に
  振り替える方法、有形固定資産の除却・廃棄、定率法による減価償却（簡易な出題にとどめる）。
- リースは3級の出題範囲外（引き続き賃貸借処理＝支払家賃・支払地代で出題）。

## 資産（assets）

| account | 科目名 | 備考 |
|---|---|---|
| cash | 現金 | |
| petty_cash | 小口現金 | |
| cash_over_short | 現金過不足 | 2026-10-28追加。2027年度版 勘定科目表 3級（下記「追加科目」参照） |
| checking_deposit | 当座預金 | |
| ordinary_deposit | 普通預金 | 2027年度版で新規明記 |
| time_deposit | 定期預金（その他の預貯金） | |
| accounts_receivable | 売掛金 | |
| credit_accounts_receivable | クレジット売掛金 | キャッシュレス決済を含む |
| electronic_receivable | 電子記録債権 | |
| loan_receivable | 貸付金 | |
| advance_paid | 立替金 | |
| accrued_revenue | 未収入金 | |
| advance_payment | 前払金 | |
| temporary_payment | 仮払金 | |
| gift_certificates_receivable | 受取商品券 | |
| guarantee_deposit | 差入保証金 | ※印（上級由来だが3級で簡易出題の可能性） |
| merchandise_inventory | 繰越商品 | |
| building | 建物 | |
| equipment | 備品 | |
| vehicle | 車両運搬具 | |
| land | 土地 | |
| accumulated_depreciation | 減価償却累計額 | |
| allowance_for_doubtful_accounts | 貸倒引当金 | 資産のマイナス（評価勘定） |
| suspense_paid_consumption_tax | 仮払消費税 | 税抜方式 |

## 負債（liabilities）

| account | 科目名 | 備考 |
|---|---|---|
| accounts_payable | 買掛金 | |
| electronic_payable | 電子記録債務 | |
| borrowings | 借入金 | |
| accrued_payable | 未払金 | |
| advance_received | 前受金 | |
| deposit_received | 預り金 | |
| temporary_receipt | 仮受金 | |
| unpaid_expense | 未払費用 | 決算整理 |
| unpaid_corporate_tax | 未払法人税等 | |
| unpaid_consumption_tax | 未払消費税 | |
| suspense_received_consumption_tax | 仮受消費税 | 税抜方式 |

## 純資産（equity）

| account | 科目名 |
|---|---|
| capital_stock | 資本金 |
| legal_reserve | 利益準備金 |
| retained_earnings | 繰越利益剰余金 |

## 収益（revenue）

| account | 科目名 |
|---|---|
| sales | 売上 |
| rent_income | 受取家賃 |
| land_rent_income | 受取地代 |
| commission_income | 受取手数料 |
| interest_income | 受取利息 |
| gain_on_disposal_of_fixed_assets | 固定資産売却益 |
| bad_debt_recovery | 償却債権取立益 |
| allowance_reversal | 貸倒引当金戻入 |
| miscellaneous_income | 雑益 |

## 費用（expense）

| account | 科目名 | 備考 |
|---|---|---|
| purchases | 仕入 | |
| shipping_expense | 発送費 | |
| salary | 給料 | |
| statutory_welfare_expense | 法定福利費 | |
| advertising_expense | 広告宣伝費 | |
| travel_expense | 旅費交通費 | |
| communication_expense | 通信費 | |
| supplies_expense | 消耗品費 | |
| utilities_expense | 水道光熱費 | |
| rent_expense | 支払家賃 | |
| land_rent_expense | 支払地代 | |
| insurance_expense | 保険料 | |
| repair_expense | 修繕費 | |
| miscellaneous_expense | 雑費 | |
| bad_debt_expense | 貸倒損失 | |
| provision_for_doubtful_accounts | 貸倒引当金繰入 | |
| interest_expense | 支払利息 | |
| commission_expense | 支払手数料 | |
| depreciation_expense | 減価償却費 | |
| loss_on_disposal_of_fixed_assets | 固定資産売却損 | |
| tax_and_dues | 租税公課 | 固定資産税など |
| corporate_tax | 法人税、住民税及び事業税 | |
| miscellaneous_loss | 雑損 | |

## v0からの主な変更点

| 変更 | 内容 |
|---|---|
| 削除 | `notes_receivable`（受取手形）、`notes_payable`（支払手形） — 2027年度版で廃止 |
| 削除 | `consumption_tax`（費用科目としての「消費税」）— 税抜方式では使わず、`suspense_paid_consumption_tax`・`suspense_received_consumption_tax`・`unpaid_consumption_tax` に置き換え |
| 追加 | `ordinary_deposit`（普通預金）、`advance_paid`（立替金）、`gift_certificates_receivable`（受取商品券）、`guarantee_deposit`（差入保証金）、`accrued_payable`（未払金）、`suspense_paid_consumption_tax`（仮払消費税）、`suspense_received_consumption_tax`（仮受消費税） |
| 追加 | `shipping_expense`（発送費）、`statutory_welfare_expense`（法定福利費）、`land_rent_expense`（支払地代）、`repair_expense`（修繕費）、`miscellaneous_expense`（雑費）、`tax_and_dues`（租税公課） |

## 未確認・要対応

1. ~~2022年度版（旧区分表、〜2027年3月実施分）の一次資料入手~~ → **一次資料は入手済み（2026-10-08）**。
   下記「旧区分表（2022年度版）向け勘定科目一覧」を参照。ただし `level3_until_2027_03` 向けの
   `account_catalog.dart`・問題データへの反映はまだ未着手
2. 勘定科目コード（account slug）の最終確定（他の会計系アプリ・簿記2級との共用も考慮）
3. 出題区分表の版（lawVersion相当）の記録方法。本アプリでは `sourceRef`/`lawVersion` に
   「商工会議所簿記検定試験出題区分表 2026-07-31最終改定（2027-04-01施行）」のように記録する方針

---

## 旧区分表（2022年度版・〜2027年3月実施分）向け勘定科目一覧

### 出典

- 「商工会議所簿記検定試験　商業簿記標準・許容勘定科目表」（日本商工会議所。2016年2月1日制定、
  2021年12月10日改定、**2022年4月1日施行**）
- 「簿記初級　出題範囲・内容」（同日程度の参考資料。「使用する勘定科目」一覧を実務的な参考として使用）
- 「2021年度出題区分表の改定事項」（2021年3月19日　日本商工会議所。収益認識基準対応の経緯の参考）

ユーザーがGoogle Driveで公式PDFを提供（2026-10-08）。上の新区分表（2027年4月以降向け）と同じ方針で、
Claudeがこれら一次資料を読み取って作成した。**この表は「商業簿記標準・許容勘定科目表」のA欄（標準的な
勘定科目）を中心に抽出したものであり、出題区分表そのもの（「ア．現金」のような大項目・中項目の階層
構造）の原本は未入手。** そのため「3級で出題されるか」の判定根拠が勘定科目表のみに依存しており、
PDFのテーブルレイアウト抽出が一部崩れている（3級列・2級列の境界や当座借越・未払配当金・福利厚生費
などの帰属級が不確実な箇所がある）。問題データ作成時は該当箇所を慎重に確認すること。

### 新区分表との主な差分（2027年4月以降版 → 2022年度版で戻す/追加する）

| 差分 | 内容 |
|---|---|
| 復活 | `notes_receivable`（受取手形）・`notes_payable`（支払手形） — 2027年度版で削除されたが、
  旧区分表では3級の範囲（振出・受入・支払） |
| 新区分表のみ | `ordinary_deposit`（普通預金）は旧区分表では「エ．当座預金、その他の預貯金」に
  黙示的に含まれる扱いで、2027年度版で初めて明記された（2022_kamoku.pdfのA欄には「普通預金」の
  記載があるため、実務上は旧区分表でも使われていたと見られる） |
| 新区分表のみ | 「販売のつど売上原価勘定に振り替える方法」「有形固定資産の除却・廃棄」「定率法による
  減価償却」は2027年度版で2級から3級に移行した項目のため、旧区分表（2022年度版）では**出題対象外**
  （2級の範囲） |
| 旧区分表のみ | 「現金過不足」（※2026-10-28に新区分表側へも追加済み、末尾参照）「損益」（決算振替の勘定）が2022_kamoku.pdfの3級欄に明記されている
  （2027年度版の一覧には含めていなかったため、新区分表側の`accounts_v1_official.md`本編にも
  追加漏れの可能性があり、要再確認） |

### 資産（assets、追加・変更分のみ）

| account | 科目名 | 備考 |
|---|---|---|
| notes_receivable | 受取手形 | 旧区分表のみ。**3級の出題範囲は振出・受入・支払のみ**。裏書・割引は
  2級以上の範囲（2026-10-09、ユーザー確認済み） |
| （他は新区分表と同じ） | | `ordinary_deposit`・`guarantee_deposit`・`gift_certificates_receivable`等も
  2022_kamoku.pdfのA欄に記載があり、旧区分表でも使える |

### 負債（liabilities、追加・変更分のみ）

| account | 科目名 | 備考 |
|---|---|---|
| notes_payable | 支払手形 | 旧区分表のみ。3級の出題範囲は振出・受入・支払のみ（裏書・割引は2級以上） |
| cash_overdraft | 当座借越 | 2022_kamoku.pdfのB欄に「借入金」と注記あり。独立科目として
  出すか借入金に含めるかは問題文の指示次第（要確認） |

### その他（新区分表の一覧になかった科目）

| account | 科目名 | 備考 |
|---|---|---|
| cash_over_short | 現金過不足 | 決算整理前の一時的な不一致を処理する勘定。3級の基本論点 |
| income_summary | 損益 | 決算振替（収益・費用を損益勘定に振り替える）で使う勘定 |

### 未確認・要対応（旧区分表固有）

1. 出題区分表そのもの（階層構造を持つ原本、新区分表でいう`2027kubunhyo_fixed.pdf`に相当するもの）が
   未入手。`2022_kamoku.pdf`（勘定科目表）だけでは、各科目がどの大項目・中項目に属するかまでは
   カバーしきれない。ただし**手形の裏書・割引は2026-10-09にユーザーが確認済みで、3級の範囲外
   （2級以上）**。3級では受取手形・支払手形の振出・受入・支払のみを出題する
2. ~~`account_catalog.dart`に`level3_until_2027_03`向けの科目一覧を追加~~ → **対応済み（2026-10-09）**。
   `boki3AccountsLegacy`（新区分表`boki3Accounts`＋`boki3LegacyOnlyAccounts`〈受取手形・支払手形・
   現金過不足・損益〉）を追加し、`accountNameOf`がどちらの時代の科目コードも解決できるようにした。
   `test/account_catalog_legacy_test.dart`で検証済み。
   ~~`level3_until_2027_03`向け問題データの作成~~ → **対応済み（2026-10-09）**。手形の振出・受入・支払
   を扱う仕訳問題6問（`boki3-j-0107`〜`0112`）を追加し、`levelId: "level3_until_2027_03"`を付与した。
   `PracticePage`・`MockExamPage`に`levelId`フィルタ（現在の試験区分に合わない問題を除外）と、
   問題のlevelIdに応じた`accountPool`切り替え（手形問題では`JournalQuestionView`の科目ピッカーに
   `boki3AccountsLegacy`を渡し、受取手形・支払手形を選べるようにする）を実装した。これがないと、
   科目一覧に追加しただけでは問題の科目ピッカーに手形が出ず正解できない、という見落としがあった
3. 当座借越・未払配当金・福利厚生費の3級該当性（PDFのテーブル抽出が一部崩れており確信が持てない）

## 追加科目（2026-10-14、出題区分表の項番は未突合・専門確認が必要）

上記の一覧にはなかったが、有価証券（売買目的の購入・売却）と貯蔵品（未使用の収入印紙・切手・消耗品の
決算振替）の問題追加にともない、`account_catalog.dart` に次の4科目を追加した。いずれも3級の範囲に
含まれるかどうかは、簿記講師等による確認が必要。

| account | 科目名 | 区分 |
|---|---|---|
| securities | 有価証券 | 資産 |
| stored_goods | 貯蔵品 | 資産 |
| gain_on_sale_of_securities | 有価証券売却益 | 収益 |
| loss_on_sale_of_securities | 有価証券売却損 | 費用 |

## 追加科目（2026-10-28、2027年度版 商業簿記標準・許容勘定科目表 3級A欄に記載）

販売のつど売上原価勘定に振り替える方法・有形固定資産の除却の問題追加にともない、
`account_catalog.dart` に次の3科目を追加した（`level3_from_2027_04` 向け問題で使用）。

| account | 科目名 | 区分 | 備考 |
|---|---|---|---|
| merchandise | 商品 | 資産 | 売上原価勘定に振り替える方法で仕入時に使う |
| cost_of_goods_sold | 売上原価 | 費用 | 販売のつど商品から振り替える |
| loss_on_retirement_of_fixed_assets | 固定資産除却損 | 費用 | 許容: 固定資産廃棄損・備品除却損・建物除却損 |

## 追加科目（2026-10-28、現金過不足を新区分表側にも追加）

2027年度版 勘定科目表（3級）に「現金過不足」が記載されており、区分表（第二1ウ）でも3級に残ることを
一次情報で確認した。このため上記「新区分表側の追加漏れの可能性」を解消し、`boki3Accounts` に追加した
（旧区分表との重複定義は避け、`boki3LegacyOnlyAccounts` からは削除。`boki3AccountsLegacy` は両者の和集合のため変更なし）。
現金過不足の問題7問（boki3-j-0115〜0119, j-0172, j-0173）は `levelId` 限定を外し、新旧両範囲で出題する。
（AI下書き・専門家確認前）

| account | 科目名 | 区分 | 備考 |
|---|---|---|---|
| cash_over_short | 現金過不足 | その他（コード上のグループは資産） | 出典: 2027年度版 勘定科目表 3級 |
