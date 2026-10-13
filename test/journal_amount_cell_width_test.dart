import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_boki3/journal_input/journal_input_controller.dart';
import 'package:ukalab_boki3/journal_input/journal_input_state.dart';
import 'package:ukalab_boki3/journal_input/journal_input_table.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// 360dp 幅の端末でも、金額セルが数字を `…` に切り詰めないこと。
void main() {
  Future<void> pumpWithAmounts(WidgetTester tester, String digits) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(journalInputProvider.notifier);
    for (final side in [JournalSide.debit, JournalSide.credit]) {
      controller.selectCell(JournalCellRef(rowIndex: 0, side: side, field: JournalCellField.amount));
      for (final d in digits.split('')) {
        controller.appendDigit(d);
      }
    }

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: JournalInputTable(recentAccountCodes: [])),
      ),
    ));
    await tester.pump();
  }

  for (final digits in ['150000', '12345678']) {
    testWidgets('金額 $digits が360dp幅でも省略されず全桁表示される', (tester) async {
      await pumpWithAmounts(tester, digits);

      final texts = find.text(digits);
      expect(texts, findsNWidgets(2)); // 借方・貸方
      for (final element in texts.evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        final needed = paragraph.getMaxIntrinsicWidth(double.infinity);
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(needed - 0.5),
          reason: '金額セルの文字が切り詰められている（幅 ${paragraph.size.width} < 必要 $needed）',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('見出し「借方金額」と「貸方科目」が詰まって1語に見えない（360dp幅）', (tester) async {
    await pumpWithAmounts(tester, '1');

    final debitAmount = tester.getRect(find.text('借方金額'));
    final creditAccount = tester.getRect(find.text('貸方科目'));
    expect(creditAccount.left - debitAmount.right, greaterThanOrEqualTo(4));
  });
}
