import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/hands_free/hands_free_choice_question.dart';
import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/purchase/weak_summary_section.dart';
import 'package:ukalab_core/answer_feedback.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'test_support.dart';

/// rootBundle の読み込み（実時間）を待ちながら、[f] が現れるまで描画を進める。
Future<void> _waitFor(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<InMemoryProgressStore> _pumpPractice(WidgetTester tester) async {
  // 解答後フィードバックは選択肢の下に並ぶので、縦に十分な画面にする。
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // 問題データ（rootBundle）は実時間で読むので、先に読み込んでキャッシュしておく。
  await tester.runAsync(loadQuestions);
  final store = InMemoryProgressStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: studyNotesTestOverrides(),
      child: MaterialApp(
        home: PracticePage(
          progressStore: store,
          restrictToQids: const {'boki3-c-0001', 'boki3-c-0002'},
        ),
      ),
    ),
  );
  await _waitFor(tester, _choiceTiles());
  return store;
}

Finder _choiceTiles() =>
    find.descendant(of: find.byType(HandsFreeChoiceQuestion), matching: find.byType(InkWell));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('選択式で不正解のとき原因選択が出て、選ぶと直近の誤答記録に保存される', (tester) async {
    final store = await _pumpPractice(tester);
    expect(find.byType(AnswerFeedbackPanel), findsNothing);

    await tester.tap(_choiceTiles().first); // boki3-c-0001 の正解は index 2
    await tester.pumpAndSettle();
    await tester.tap(find.text('答え合わせ'));
    await tester.pumpAndSettle();

    expect(find.text('不正解です'), findsOneWidget);
    expect(find.byType(WrongCauseSelector), findsOneWidget);
    // 無料の範囲では「計算ミス」は選択肢に出さない。
    expect(find.text(AnswerFeedbackStrings.ja.causeLabel(WrongCause.calculation)), findsNothing);

    await tester.tap(find.text(AnswerFeedbackStrings.ja.causeLabel(WrongCause.trap)));
    await tester.pumpAndSettle();
    final records = await store.loadRecords();
    expect(records.single.correct, isFalse);
    expect(records.single.cause, WrongCause.trap);
  });

  testWidgets('正解のときは何も出さない', (tester) async {
    await _pumpPractice(tester);
    await tester.tap(_choiceTiles().at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('答え合わせ'));
    await tester.pumpAndSettle();
    expect(find.text('正解です'), findsOneWidget);
    expect(find.byType(WrongCauseSelector), findsNothing);
  });

  test('attachCause は SharedPreferences 保存先でも記録を書き換える', () async {
    final store = SharedPreferencesProgressStore();
    await store.addRecord(
        ProgressRecord(qid: 'q1', subjectId: 's', correct: false, at: DateTime(2026, 11, 1)));
    await attachCause(store, 'q1', WrongCause.knowledge);
    expect((await store.loadRecords()).single.cause, WrongCause.knowledge);
    await attachCause(store, 'q1', null);
    expect((await store.loadRecords()).single.cause, isNull);
  });

  Future<void> pumpSummary(WidgetTester tester, {required bool premium}) async {
    final store = InMemoryProgressStore();
    await store.addRecord(ProgressRecord(
        qid: 'q1',
        subjectId: 'q1_shiwake',
        correct: false,
        at: DateTime(2026, 11, 20, 9),
        topicId: 'ch1'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementServiceProvider.overrideWithValue(
              FakeEntitlementService(initial: EntitlementState(hasPremium: premium))),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WeakSummarySection(
              progressStore: store,
              loadQuestionList: () async => const [],
              clock: () => DateTime(2026, 11, 20, 12),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('今週の弱点カードは premium のときだけ出る', (tester) async {
    await pumpSummary(tester, premium: false);
    expect(find.byType(WeakSummaryCard), findsNothing);
    await pumpSummary(tester, premium: true);
    expect(find.byType(WeakSummaryCard), findsOneWidget);
  });
}
