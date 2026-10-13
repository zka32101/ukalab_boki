/// 簿記3級の勘定科目マスタ。
///
/// `docs/accounts_v1_official.md`（確定版 v1）をコード化したもの。商工会議所の公式
/// 出題区分表（2026年7月31日最終改定、2027年4月1日施行）に基づく。[boki3Accounts] は
/// `level3_from_2027_04`（2027年4月以降実施分）向け。
///
/// 2026年度中（〜2027年3月実施分、`level3_until_2027_03`）は旧区分表（2022年4月1日施行）が
/// 適用され、[boki3AccountsLegacy] を使う。旧区分表との差分は [boki3LegacyOnlyAccounts]
/// （受取手形・支払手形・現金過不足・損益）のみで、それ以外の科目は共通（出典:
/// `docs/accounts_v1_official.md`「旧区分表（2022年度版）向け勘定科目一覧」）。
library;

/// 勘定科目の5要素グループ。
enum AccountGroup { asset, liability, equity, revenue, expense }

extension AccountGroupLabel on AccountGroup {
  String get label => switch (this) {
        AccountGroup.asset => '資産',
        AccountGroup.liability => '負債',
        AccountGroup.equity => '純資産',
        AccountGroup.revenue => '収益',
        AccountGroup.expense => '費用',
      };
}

/// 1つの勘定科目。[code] は `JournalLine.account` と同じ値を使う。
class AccountDef {
  const AccountDef({required this.code, required this.name, required this.group});

  final String code;
  final String name;
  final AccountGroup group;
}

/// 簿記3級の勘定科目一覧（確定版 v1、2027年4月以降の新区分表ベース）。
const List<AccountDef> boki3Accounts = [
  // 資産
  AccountDef(code: 'cash', name: '現金', group: AccountGroup.asset),
  AccountDef(code: 'petty_cash', name: '小口現金', group: AccountGroup.asset),
  AccountDef(code: 'checking_deposit', name: '当座預金', group: AccountGroup.asset),
  AccountDef(code: 'ordinary_deposit', name: '普通預金', group: AccountGroup.asset),
  AccountDef(code: 'time_deposit', name: '定期預金', group: AccountGroup.asset),
  AccountDef(code: 'accounts_receivable', name: '売掛金', group: AccountGroup.asset),
  AccountDef(
    code: 'credit_accounts_receivable',
    name: 'クレジット売掛金',
    group: AccountGroup.asset,
  ),
  AccountDef(code: 'electronic_receivable', name: '電子記録債権', group: AccountGroup.asset),
  AccountDef(code: 'loan_receivable', name: '貸付金', group: AccountGroup.asset),
  AccountDef(code: 'advance_paid', name: '立替金', group: AccountGroup.asset),
  AccountDef(code: 'accrued_revenue', name: '未収入金', group: AccountGroup.asset), // 注意: 商品以外の売却代金などの未収入金。経過勘定の「未収収益」ではない
  AccountDef(code: 'advance_payment', name: '前払金', group: AccountGroup.asset),
  AccountDef(code: 'temporary_payment', name: '仮払金', group: AccountGroup.asset),
  AccountDef(
    code: 'gift_certificates_receivable',
    name: '受取商品券',
    group: AccountGroup.asset,
  ),
  AccountDef(code: 'guarantee_deposit', name: '差入保証金', group: AccountGroup.asset),
  AccountDef(code: 'merchandise_inventory', name: '繰越商品', group: AccountGroup.asset),
  AccountDef(code: 'building', name: '建物', group: AccountGroup.asset),
  AccountDef(code: 'equipment', name: '備品', group: AccountGroup.asset),
  AccountDef(code: 'vehicle', name: '車両運搬具', group: AccountGroup.asset),
  AccountDef(code: 'land', name: '土地', group: AccountGroup.asset),
  AccountDef(
    code: 'accumulated_depreciation',
    name: '減価償却累計額',
    group: AccountGroup.asset,
  ),
  AccountDef(
    code: 'allowance_for_doubtful_accounts',
    name: '貸倒引当金',
    group: AccountGroup.asset,
  ),
  AccountDef(
    code: 'suspense_paid_consumption_tax',
    name: '仮払消費税',
    group: AccountGroup.asset,
  ),

  // 負債
  AccountDef(code: 'accounts_payable', name: '買掛金', group: AccountGroup.liability),
  AccountDef(code: 'electronic_payable', name: '電子記録債務', group: AccountGroup.liability),
  AccountDef(code: 'borrowings', name: '借入金', group: AccountGroup.liability),
  AccountDef(code: 'accrued_payable', name: '未払金', group: AccountGroup.liability), // 注意: 商品以外の購入代金などの未払金。経過勘定の「未払費用」(unpaid_expense)ではない
  AccountDef(code: 'advance_received', name: '前受金', group: AccountGroup.liability),
  AccountDef(code: 'deposit_received', name: '預り金', group: AccountGroup.liability),
  AccountDef(code: 'temporary_receipt', name: '仮受金', group: AccountGroup.liability),
  AccountDef(code: 'unpaid_expense', name: '未払費用', group: AccountGroup.liability),
  AccountDef(
    code: 'unpaid_corporate_tax',
    name: '未払法人税等',
    group: AccountGroup.liability,
  ),
  AccountDef(
    code: 'unpaid_consumption_tax',
    name: '未払消費税',
    group: AccountGroup.liability,
  ),
  AccountDef(
    code: 'suspense_received_consumption_tax',
    name: '仮受消費税',
    group: AccountGroup.liability,
  ),

  // 純資産
  AccountDef(code: 'capital_stock', name: '資本金', group: AccountGroup.equity),
  AccountDef(code: 'legal_reserve', name: '利益準備金', group: AccountGroup.equity),
  AccountDef(code: 'retained_earnings', name: '繰越利益剰余金', group: AccountGroup.equity),

  // 収益
  AccountDef(code: 'sales', name: '売上', group: AccountGroup.revenue),
  AccountDef(code: 'rent_income', name: '受取家賃', group: AccountGroup.revenue),
  AccountDef(code: 'land_rent_income', name: '受取地代', group: AccountGroup.revenue),
  AccountDef(code: 'commission_income', name: '受取手数料', group: AccountGroup.revenue),
  AccountDef(code: 'interest_income', name: '受取利息', group: AccountGroup.revenue),
  AccountDef(
    code: 'gain_on_disposal_of_fixed_assets',
    name: '固定資産売却益',
    group: AccountGroup.revenue,
  ),
  AccountDef(
    code: 'bad_debt_recovery',
    name: '償却債権取立益',
    group: AccountGroup.revenue,
  ),
  AccountDef(
    code: 'allowance_reversal',
    name: '貸倒引当金戻入',
    group: AccountGroup.revenue,
  ),
  AccountDef(code: 'miscellaneous_income', name: '雑益', group: AccountGroup.revenue),

  // 費用
  AccountDef(code: 'purchases', name: '仕入', group: AccountGroup.expense),
  AccountDef(code: 'shipping_expense', name: '発送費', group: AccountGroup.expense),
  AccountDef(code: 'salary', name: '給料', group: AccountGroup.expense),
  AccountDef(
    code: 'statutory_welfare_expense',
    name: '法定福利費',
    group: AccountGroup.expense,
  ),
  AccountDef(code: 'advertising_expense', name: '広告宣伝費', group: AccountGroup.expense),
  AccountDef(code: 'travel_expense', name: '旅費交通費', group: AccountGroup.expense),
  AccountDef(code: 'communication_expense', name: '通信費', group: AccountGroup.expense),
  AccountDef(code: 'supplies_expense', name: '消耗品費', group: AccountGroup.expense),
  AccountDef(code: 'utilities_expense', name: '水道光熱費', group: AccountGroup.expense),
  AccountDef(code: 'rent_expense', name: '支払家賃', group: AccountGroup.expense),
  AccountDef(code: 'land_rent_expense', name: '支払地代', group: AccountGroup.expense),
  AccountDef(code: 'insurance_expense', name: '保険料', group: AccountGroup.expense),
  AccountDef(code: 'repair_expense', name: '修繕費', group: AccountGroup.expense),
  AccountDef(code: 'miscellaneous_expense', name: '雑費', group: AccountGroup.expense),
  AccountDef(code: 'bad_debt_expense', name: '貸倒損失', group: AccountGroup.expense),
  AccountDef(
    code: 'provision_for_doubtful_accounts',
    name: '貸倒引当金繰入',
    group: AccountGroup.expense,
  ),
  AccountDef(code: 'interest_expense', name: '支払利息', group: AccountGroup.expense),
  AccountDef(code: 'commission_expense', name: '支払手数料', group: AccountGroup.expense),
  AccountDef(
    code: 'depreciation_expense',
    name: '減価償却費',
    group: AccountGroup.expense,
  ),
  AccountDef(
    code: 'loss_on_disposal_of_fixed_assets',
    name: '固定資産売却損',
    group: AccountGroup.expense,
  ),
  AccountDef(code: 'tax_and_dues', name: '租税公課', group: AccountGroup.expense),
  AccountDef(
    code: 'corporate_tax',
    name: '法人税、住民税及び事業税',
    group: AccountGroup.expense,
  ),
  AccountDef(code: 'miscellaneous_loss', name: '雑損', group: AccountGroup.expense),
];

/// 旧区分表（2022年度版）でのみ使う追加科目（新区分表の [boki3Accounts] には含まれない）。
///
/// - `notes_receivable`・`notes_payable`: 受取手形・支払手形。3級の出題範囲は振出・受入・支払
///   のみで、裏書・割引は2級以上の範囲（2026-10-09、ユーザー確認済み）。紙媒体の手形が廃止される
///   2027年4月以降は出題されなくなるため [boki3Accounts] からは除外している。
/// - `cash_over_short`・`income_summary`: 現金過不足・損益。`docs/accounts_v1_official.md` の
///   一次資料（商業簿記標準・許容勘定科目表）の3級欄に明記されている。
const List<AccountDef> boki3LegacyOnlyAccounts = [
  AccountDef(code: 'notes_receivable', name: '受取手形', group: AccountGroup.asset),
  AccountDef(code: 'notes_payable', name: '支払手形', group: AccountGroup.liability),
  AccountDef(code: 'cash_over_short', name: '現金過不足', group: AccountGroup.asset),
  // 決算振替（収益・費用を集約する仮勘定）。5要素のどれにも厳密には当てはまらないが、
  // 最終的に繰越利益剰余金（純資産）に振り替わる勘定のため純資産グループに置く。
  AccountDef(code: 'income_summary', name: '損益', group: AccountGroup.equity),
];

/// 簿記3級の勘定科目一覧（旧区分表、2022年4月1日施行、`level3_until_2027_03` 向け）。
const List<AccountDef> boki3AccountsLegacy = [...boki3Accounts, ...boki3LegacyOnlyAccounts];

final Map<String, AccountDef> _boki3AccountsByCode = {
  for (final a in [...boki3Accounts, ...boki3LegacyOnlyAccounts]) a.code: a,
};

/// コードから科目名を引く（未知のコードは `code` をそのまま返す）。
String accountNameOf(String code) => _boki3AccountsByCode[code]?.name ?? code;

/// 名前・コードの部分一致で絞り込む。
List<AccountDef> searchAccounts(String query, {List<AccountDef> pool = boki3Accounts}) {
  if (query.trim().isEmpty) return pool;
  final q = query.trim();
  return [
    for (final a in pool)
      if (a.name.contains(q) || a.code.contains(q)) a,
  ];
}
