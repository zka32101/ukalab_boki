import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukalab_boki3/journal_input/account_picker_sheet.dart';
import 'package:ukalab_boki3/journal_input/journal_input_controller.dart';
import 'package:ukalab_boki3/journal_input/journal_input_state.dart';
import 'package:ukalab_boki3/journal_input/journal_input_table.dart';
import 'package:ukalab_boki3/journal_input/numeric_keypad.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'overflow_support.dart';

/// 仕訳入力で長い科目名・8桁の金額を、狭い幅・大きい文字でも省略せず出すことを確認する。
void main() {
  const debitName = '貸倒引当金繰入';
  const creditName = '減価償却累計額';

  void expectNoEllipsis(WidgetTester tester, String text, {bool inTile = false}) {
    final finder = inTile ? find.descendant(of: find.byType(ListTile), matching: find.text(text)) : find.text(text);
    expect(finder, findsWidgets, reason: '「$text」が描画されていない');
    for (final e in finder.evaluate()) {
      expect((e.widget as Text).overflow, isNot(TextOverflow.ellipsis));
      final p = e.renderObject! as RenderParagraph;
      expect(p.didExceedMaxLines, isFalse, reason: '「$text」が省略されている');
    }
  }

  for (final c in overflowCases) {
    testWidgets('仕訳の入力表: 長い科目名と8桁の金額が切れない: $c', (tester) async {
      applyScreen(tester, c);
      final errors = ErrorCollector();
      addTearDown(errors.dispose);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(journalInputProvider.notifier);
      for (final (side, code) in [(JournalSide.debit, 'provision_for_doubtful_accounts'), (JournalSide.credit, 'accumulated_depreciation')]) {
        controller.selectCell(JournalCellRef(rowIndex: 0, side: side, field: JournalCellField.account));
        controller.setAccount(code);
        controller.selectCell(JournalCellRef(rowIndex: 0, side: side, field: JournalCellField.amount));
        for (final d in '12345678'.split('')) {
          controller.appendDigit(d);
        }
      }
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: EdgeInsets.all(16), child: JournalInputTable(recentAccountCodes: [])),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(errors.drain(), isEmpty);
      errors.dispose();
      expectNoEllipsis(tester, debitName);
      expectNoEllipsis(tester, creditName);
      for (final e in find.text('12345678').evaluate()) {
        final p = e.renderObject! as RenderParagraph;
        expect(p.size.width, greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5));
      }
    });

    testWidgets('科目ピッカーとテンキー: 長い科目名・ボタン文字が切れない: $c', (tester) async {
      applyScreen(tester, c);
      final errors = ErrorCollector();
      addTearDown(errors.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            Builder(
              builder: (context) => ElevatedButton(onPressed: () => showAccountPicker(context), child: const Text('選ぶ')),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: NumericKeypad(onDigit: (_) {}, onTripleZero: () {}, onBackspace: () {}, onClear: () {}, onNext: () {}),
              ),
            ),
          ]),
        ),
      ));
      await tester.pump();
      expect(errors.drain(), isEmpty, reason: 'テンキー');
      await tester.tap(find.text('選ぶ'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), '貸倒引当金繰入');
      await tester.pump(const Duration(milliseconds: 300));
      expect(errors.drain(), isEmpty, reason: '科目ピッカー');
      errors.dispose();
      expectNoEllipsis(tester, '貸倒引当金繰入', inTile: true);
      expect(find.text('勘定科目を検索'), findsOneWidget);
    });
  }
}
