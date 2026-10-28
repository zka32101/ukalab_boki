import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_boki3/journal_input/account_catalog.dart';

/// 旧区分表（2022年度版、〜2027年3月実施分）向けの勘定科目一覧の検証。
void main() {
  test('boki3AccountsLegacy は新区分表の科目に受取手形・支払手形・損益を加えたもの', () {
    final legacyCodes = boki3AccountsLegacy.map((a) => a.code).toSet();
    final newCodes = boki3Accounts.map((a) => a.code).toSet();

    expect(legacyCodes.containsAll(newCodes), isTrue);
    expect(legacyCodes.difference(newCodes), {
      'notes_receivable',
      'notes_payable',
      'income_summary',
    });
    expect(newCodes, contains('cash_over_short'));
  });

  test('新区分表の科目コードに重複がない', () {
    final codes = [for (final a in boki3Accounts) a.code];
    expect(codes.toSet().length, codes.length);
  });

  test('旧区分表の科目コードに重複がない', () {
    final codes = [for (final a in boki3AccountsLegacy) a.code];
    expect(codes.toSet().length, codes.length);
  });

  test('accountNameOf は旧区分表のみの科目（受取手形・支払手形）も解決できる', () {
    expect(accountNameOf('notes_receivable'), '受取手形');
    expect(accountNameOf('notes_payable'), '支払手形');
    expect(accountNameOf('cash_over_short'), '現金過不足');
    expect(accountNameOf('income_summary'), '損益');
  });

  test('受取手形は資産、支払手形は負債グループに分類される', () {
    final receivable = boki3AccountsLegacy.firstWhere((a) => a.code == 'notes_receivable');
    final payable = boki3AccountsLegacy.firstWhere((a) => a.code == 'notes_payable');
    expect(receivable.group, AccountGroup.asset);
    expect(payable.group, AccountGroup.liability);
  });

  test('searchAccounts は旧区分表のpoolを指定すると受取手形も検索できる', () {
    final results = searchAccounts('受取手形', pool: boki3AccountsLegacy);
    expect(results.map((a) => a.code), contains('notes_receivable'));

    // 新区分表（デフォルトpool）には受取手形が含まれない。
    expect(searchAccounts('受取手形'), isEmpty);
  });
}
