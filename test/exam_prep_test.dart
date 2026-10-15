import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/exam_prep/exam_prep_data.dart';
import 'package:ukalab_boki3/exam_prep/exam_prep_entry.dart';
import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'test_support.dart';

final _now = DateTime(2026, 10, 14, 12);
const _s = ExamPrepStrings.ja;

Question _choice(String qid) => Question(
      qid: qid,
      examId: 'boki3',
      subjectId: 'q1_shiwake',
      topicId: 'ch1',
      prompt: 'p-$qid',
      choices: const ['a', 'b'],
      answerIndex: 0,
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required bool premium,
  DateTime? examDate,
  InMemoryProgressStore? store,
  Widget? child,
}) async {
  // 演習画面が読む問題データは、fake async の外で先に読んでキャッシュしておく。
  await tester.runAsync(loadQuestions);
  SharedPreferences.setMockInitialValues({
    if (examDate != null) 'ukalab_boki3_exam_date': examDate.toIso8601String(),
  });
  final progress = store ?? InMemoryProgressStore();
  final container = ProviderContainer(overrides: [
    ...studyNotesTestOverrides(),
    entitlementServiceProvider
        .overrideWithValue(FakeEntitlementService(initial: EntitlementState(hasPremium: premium))),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child ??
              ExamPrepEntryCard(
                progressStore: progress,
                clock: () => _now,
                loadQuestionList: () async => [_choice('q1'), _choice('q2')],
              ),
        ),
      ),
    ),
  ));
  container.read(examDateProvider);
  await tester.runAsync(() => container.read(examDateProvider.notifier).ready);
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  group('データ', () {
    testWidgets('チェックリストは全項目が「公式で要確認」で、電卓・受験票・本人確認を含む', (tester) async {
      final items = await tester.runAsync(loadChecklist) as List<ChecklistItem>;
      expect(items, isNotEmpty);
      expect(items.every((i) => !i.officialConfirmed), isTrue);
      final text = items.map((i) => i.label).join();
      expect(text, contains('電卓'));
      expect(text, contains('受験票'));
      expect(text, contains('本人確認'));
      // 断定しない: 電卓の可否は「確かめた」という確認項目で、可否を言い切らない。
      expect(items.firstWhere((i) => i.itemId == 'b-calc-allowed').label, contains('確かめた'));
    });

    testWidgets('更新ログは実際の日付で、解析エラーなく読める', (tester) async {
      final entries = await tester.runAsync(() => loadUpdateLog(now: _now)) as List<UpdateLogEntry>;
      expect(entries, hasLength(4));
      expect(entries.every((e) => e.examId == 'boki3'), isTrue);
      expect(entries.first.date, DateTime(2026, 10, 13));
    });
  });

  group('ホームのカード', () {
    testWidgets('無料: 10分プランは案内を出し、演習画面は開かない', (tester) async {
      await _pump(tester, premium: false);
      await tester.tap(find.byKey(const ValueKey('tenMinPlanTile')));
      await tester.pump();
      expect(find.text(_s.premiumNote), findsWidgets);
      expect(find.byType(PracticePage), findsNothing);
    });

    testWidgets('premium: 10分プランから演習画面が開く', (tester) async {
      await _pump(tester, premium: true);
      await tester.tap(find.byKey(const ValueKey('tenMinPlanTile')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(PracticePage), findsOneWidget);
      expect(find.text(_s.tenMinTitle), findsWidgets);
    });

    testWidgets('試験日が未設定ならチェックリストと試験直前の行は出ない', (tester) async {
      await _pump(tester, premium: true);
      expect(find.byKey(const ValueKey('checklistTile')), findsNothing);
      expect(find.byKey(const ValueKey('examEveTile')), findsNothing);
    });

    testWidgets('試験日が近いと試験直前の行が出る。無料なら案内のみ', (tester) async {
      await _pump(tester, premium: false, examDate: DateTime(2026, 10, 16));
      expect(find.byKey(const ValueKey('examEveTile')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('examEveTile')));
      await tester.pump();
      expect(find.byType(PracticePage), findsNothing);
    });

    testWidgets('チェックリストを開いてチェックすると端末内に保存される', (tester) async {
      final container = await _pump(tester, premium: false, examDate: DateTime(2026, 12, 1));
      await tester.runAsync(() => container.read(checklistProvider.notifier).ready);
      await tester.tap(find.byKey(const ValueKey('checklistTile')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(find.byType(ExamDayChecklistView), findsOneWidget);
      expect(find.text(_s.confirmNeeded), findsWidgets);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('ukalab_boki3_exam_checklist_v1'), hasLength(1));
    });
  });

  group('出題形式', () {
    // ukalab_core v0.75.0 で追加された trueFalse/cloze/reverseLookup は、本アプリのデータに無いので対象外。
    for (final type in const [
      QuestionType.choice,
      QuestionType.journal,
      QuestionType.worksheet,
      QuestionType.ledger,
    ]) {
      testWidgets('${type.name} 形式の問題でも演習画面が起動する', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final all = await tester.runAsync(loadQuestions) as List<Question>;
        final q = all.firstWhere((q) => q.type == type);
        await tester.pumpWidget(ProviderScope(
          overrides: studyNotesTestOverrides(),
          child: MaterialApp(
            home: PracticePage(
              progressStore: InMemoryProgressStore(),
              restrictToQids: {q.qid},
              title: 'x',
              now: DateTime(2026, 10, 14),
            ),
          ),
        ));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        for (var i = 0; i < 10 && find.textContaining('1 / 1問目').evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        expect(find.textContaining('1 / 1問目'), findsOneWidget);
      });
    }

    testWidgets('現在の試験区分の問題だけを10分プランに渡す', (tester) async {
      final qs = await tester.runAsync(() => loadCurrentLevelQuestions(now: _now)) as List<Question>;
      expect(qs.every((q) => q.levelId == null || q.levelId == 'level3_until_2027_03'), isTrue);
    });
  });

  group('設定', () {
    testWidgets('試験日の保存・解除と、無料での書き出しは案内のみ', (tester) async {
      final container = await _pump(
        tester,
        premium: false,
        child: ExamPrepSettingsSection(progressStore: InMemoryProgressStore()),
      );
      await tester.runAsync(() => container.read(examDateProvider.notifier).setDate(DateTime(2026, 12, 1)));
      await tester.pump();
      expect(find.text('2026/12/1'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ukalab_boki3_exam_date'), isNotNull);
      await tester.runAsync(() => container.read(examDateProvider.notifier).setDate(null));
      await tester.pump();
      expect(prefs.getString('ukalab_boki3_exam_date'), isNull);

      await tester.tap(find.text(_s.exportTitle));
      await tester.pump();
      expect(find.byType(HistoryExportView), findsNothing);
      expect(find.text(_s.premiumNote), findsWidgets);
    });
  });
}
