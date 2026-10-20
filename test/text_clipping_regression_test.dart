import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/journal_input/journal_input_controller.dart';
import 'package:ukalab_boki3/journal_input/journal_input_state.dart';
import 'package:ukalab_boki3/journal_input/journal_input_table.dart';
import 'package:ukalab_boki3/ledger_input/ledger_table.dart';
import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_boki3/records/records_page.dart';
import 'package:ukalab_boki3/company_mode/company_mode_history_store.dart';
import 'package:ukalab_boki3/worksheet_input/worksheet_table.dart';
import 'overflow_support.dart';
import 'test_support.dart';

/// 「…」で隠れる・豆粒に縮む・題名が切れる、といった、オーバーフロー例外が出ない種類の
/// 文字切れを確認する。
void main() {
  // テスト本体（FakeAsync の中）で `await loadQuestions()` すると pumpWidget が進まなくなることがあるため、先に読む。
  late List<Question> allQuestions;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    allQuestions = await loadQuestions();
    await loadExamConfig();
    await loadTerms();
  });

  /// 数字だけの文字列が、省略（…）されず全桁そのまま描画されているか。
  void expectDigitsNotTruncated(WidgetTester tester, Finder within, String reason) {
    final texts = find.descendant(of: within, matching: find.byType(Text)).evaluate();
    var checked = 0;
    for (final e in texts) {
      final t = (e.widget as Text).data ?? '';
      if (!RegExp(r'^\d{4,}$').hasMatch(t)) continue;
      final p = e.renderObject! as RenderParagraph;
      final needed = p.getMaxIntrinsicWidth(double.infinity);
      expect(p.size.width, greaterThanOrEqualTo(needed - 0.5), reason: '$reason: 「$t」が切り詰められている');
      checked++;
    }
    expect(checked, greaterThan(0), reason: '$reason: 検査対象の数字が無い');
  }

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('帳簿の表の金額は文字$scale倍でも省略されず、セルの高さも伸びる', (tester) async {
      applyScreen(tester, ScreenCase(320, 640, scale));
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LedgerTable(
                rows: [LedgerRowMeta(rowIndex: 0, date: '4/1', description: '前月繰越')],
                givenCells: [
                  LedgerCell(rowIndex: 0, group: LedgerColumnGroup.balance, field: LedgerField.amount, value: 123456),
                  LedgerCell(rowIndex: 0, group: LedgerColumnGroup.receipt, field: LedgerField.amount, value: 654321),
                ],
                blankCells: [],
              ),
            ),
          ),
        ),
      ));
      expectDigitsNotTruncated(tester, find.byType(LedgerTable), '帳簿');
      // 数字の高さが枠（固定48dp）を超えて、隣の行にはみ出さない。
      for (final box in find.descendant(of: find.byType(LedgerTable), matching: find.byType(Container)).evaluate()) {
        final text = find.descendant(of: find.byWidget(box.widget), matching: find.text('123456'));
        if (text.evaluate().isEmpty) continue;
        expect(tester.getSize(find.byWidget(box.widget)).height, greaterThanOrEqualTo(tester.getSize(text).height));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('精算表の金額は文字$scale倍でも省略されない', (tester) async {
      applyScreen(tester, ScreenCase(320, 640, scale));
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorksheetTable(
                givenCells: [
                  WorksheetCell(account: 'equipment', column: WorksheetColumn.trialBalanceDebit, amount: 123456),
                  WorksheetCell(account: 'equipment', column: WorksheetColumn.balanceSheetDebit, amount: 654321),
                ],
                blankCells: [],
              ),
            ),
          ),
        ),
      ));
      expectDigitsNotTruncated(tester, find.byType(WorksheetTable), '精算表');
      expect(tester.takeException(), isNull);
    });
  }

  for (final (width, scale) in [(320.0, 1.0), (360.0, 2.0), (280.0, 3.0)]) {
    testWidgets('仕訳の金額セルは幅${width.toInt()}・文字$scale倍でも縮めず全桁出る', (tester) async {
      applyScreen(tester, ScreenCase(width, 800, scale));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(journalInputProvider.notifier);
      for (final side in [JournalSide.debit, JournalSide.credit]) {
        controller.selectCell(JournalCellRef(rowIndex: 0, side: side, field: JournalCellField.amount));
        for (final d in '12345678'.split('')) {
          controller.appendDigit(d);
        }
      }
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Padding(padding: EdgeInsets.all(16), child: JournalInputTable(recentAccountCodes: []))),
        ),
      ));
      await tester.pump();

      // 金額は縮めず（FittedBoxなし）、全桁が1行で描画される。
      expect(find.ancestor(of: find.text('12345678'), matching: find.byType(FittedBox)), findsNothing);
      for (final e in find.text('12345678').evaluate()) {
        final p = e.renderObject! as RenderParagraph;
        expect(p.size.width, greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('復習待ちの問題文は文字$scale倍でも省略（…）されず全文が出る', (tester) async {
      SharedPreferences.setMockInitialValues({});
      applyScreen(tester, ScreenCase(320, 20000, scale));
      final long = allQuestions.firstWhere((q) => q.qid == 'boki3-w-0009');
      final store = InMemoryProgressStore();
      await store.addRecord(ProgressRecord(qid: long.qid, subjectId: long.subjectId, correct: false, at: DateTime.now()));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordsPage(progressStore: store, companyModeHistoryStore: InMemoryCompanyModeHistoryStore()),
        ),
      ));
      for (var i = 0; i < 60 && find.text(long.prompt).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
      final p = tester.renderObject<RenderParagraph>(find.text(long.prompt));
      expect(p.didExceedMaxLines, isFalse);
      expect(p.maxLines, isNull);
    });

    testWidgets('AppBarの長い題名は文字$scale倍でも省略されず全部見える', (tester) async {
      SharedPreferences.setMockInitialValues({});
      applyScreen(tester, ScreenCase(280, 600, scale));
      // 「学ぶ」タブの科目別練習と同じ題名の付け方（第2問 帳簿・伝票等 + を練習する）。
      const title = '第2問 帳簿・伝票等を練習する';
      await tester.pumpWidget(ProviderScope(
        overrides: studyNotesTestOverrides(),
        child: MaterialApp(
          home: PracticePage(progressStore: InMemoryProgressStore(), subjectId: 'q2_choubo', title: title),
        ),
      ));
      await tester.pump();
      final p = tester.renderObject<RenderParagraph>(find.text(title));
      expect(p.didExceedMaxLines, isFalse, reason: '題名が省略されている');
      expect(tester.getRect(find.text(title)).bottom, lessThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
