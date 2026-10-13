import 'dart:convert';

import 'package:app_common_kit/app_common_kit.dart' show FakeEntitlementService, entitlementServiceProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/main.dart';
import 'package:ukalab_boki3/mock_exam/mock_exam_page.dart';
import 'package:ukalab_boki3/oshi/oshi_growth_section.dart';
import 'package:ukalab_boki3/practice/choice_question_view.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/review/review_schedule.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'test_support.dart';

/// ukalab_core v0.67〜v0.69 の機能（今日の復習・模擬試験の結果分析・推しの成長演出）の組み込み確認。
void main() {
  final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

  /// 3日前に12問答えた記録（6問不正解）。今日の復習の期限が来ていて、回答10問の節目にも届く。
  Map<String, Object> seededPrefs() => {
        'ukalab_boki3_progress_records': jsonEncode([
          for (var i = 0; i < 12; i++)
            ProgressRecord(qid: 'seed$i', subjectId: 'q1_shiwake', correct: i.isEven, at: threeDaysAgo).toJson(),
        ]),
      };

  Future<void> pumpApp(WidgetTester tester, {required Size size, required double scale}) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [entitlementServiceProvider.overrideWithValue(FakeEntitlementService()), ...studyNotesTestOverrides()],
      child: const UkalabBoki3App(),
    ));
    await tester.pumpAndSettle();
  }

  Finder inGroup(String title, Type type) => find.descendant(
        of: find.byWidgetPredicate((w) => w is HomeSection && w.title == title),
        matching: find.byType(type, skipOffstage: false),
      );

  group('ホーム', () {
    testWidgets('今日の復習は「今日やること」、推しの成長は「学習の記録」にある（見出しは4つのまま）', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpApp(tester, size: const Size(800, 6000), scale: 1.0);
      expect(inGroup('今日やること', TodayReviewCard), findsOneWidget);
      expect(inGroup('学習の記録', OshiGrowthBubble), findsOneWidget);
      expect(find.byType(HomeSectionHeader), findsNWidgets(4));
      expect(find.byType(OshiGrowthCelebrationCard), findsNothing); // 記録が無いので祝福は出ない
      expect(tester.takeException(), isNull);
    });

    testWidgets('幅320・文字2倍でオーバーフローしない（復習の期限あり・節目の祝福あり）', (tester) async {
      SharedPreferences.setMockInitialValues(seededPrefs());
      await pumpApp(tester, size: const Size(320, 8000), scale: 2.0);
      // 回答10問の節目の祝福が一度だけ出る。閉じるとホームが見える。
      expect(find.byType(OshiGrowthCelebrationCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(find.byType(OshiGrowthCelebrationCard), findsNothing);

      // 期限が来ているので、復習カードに「やってみる」ボタンがある。
      expect(find.descendant(of: find.byType(TodayReviewCard), matching: find.byType(FilledButton)), findsOneWidget);
      expect(inGroup('学習の記録', OshiGrowthBubble), findsOneWidget);
      expect(find.byType(HomeSectionHeader), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('節目の祝福は一度だけ（作り直しても同じ節目では出ない）', (tester) async {
      SharedPreferences.setMockInitialValues(seededPrefs());
      await pumpApp(tester, size: const Size(800, 6000), scale: 1.0);
      expect(find.byType(OshiGrowthCelebrationCard), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, size: const Size(800, 6000), scale: 1.0);
      expect(find.byType(OshiGrowthCelebrationCard), findsNothing);
    });
  });

  group('今日の復習の予定', () {
    final store = InMemoryProgressStore();
    late InMemoryMistakeNoteStore notes;
    late InMemoryReviewSchedulerStore schedule;

    setUp(() async {
      notes = InMemoryMistakeNoteStore();
      schedule = InMemoryReviewSchedulerStore();
      await store.clearRecords();
      await store.addRecord(ProgressRecord(qid: 'a', subjectId: 's', correct: false, at: threeDaysAgo));
      await store.addRecord(ProgressRecord(qid: 'b', subjectId: 's', correct: true, at: threeDaysAgo));
    });

    test('間違いノートから同期し、間違えた問題だけが期限に来る（何度呼んでも同じ）', () async {
      final a = await syncReviewSchedule(
          progressStore: store, noteStore: notes, scheduleStore: schedule, questions: const []);
      final b = await syncReviewSchedule(
          progressStore: store, noteStore: notes, scheduleStore: schedule, questions: const []);
      expect([for (final i in a) i.qid], ['a']);
      expect(b.length, 1);
      expect(reviewSchedulerEngine.dueCount(b, DateTime.now()), 1);
    });

    test('期限に来ている問題の結果だけが反映される（期限前・予定外は変えない）', () async {
      await syncReviewSchedule(progressStore: store, noteStore: notes, scheduleStore: schedule, questions: const []);
      final now = DateTime.now();
      await recordReviewResult('zzz', correct: true, now: now, store: schedule); // 予定外
      expect((await schedule.read()).single.stage, 0);

      await recordReviewResult('a', correct: true, now: now, store: schedule);
      final after = (await schedule.read()).single;
      expect(after.stage, 1);
      expect(reviewSchedulerEngine.isDue(after, now), isFalse);

      // 期限前の問題は、通常の演習で解いても段は進まない。
      await recordReviewResult('a', correct: true, now: now, store: schedule);
      expect((await schedule.read()).single.stage, 1);
    });
  });

  group('推しの成長の入力', () {
    test('回答数は記録の件数、学習日数は記録のある日の数（連続ではなく合計）', () {
      final d = DateTime(2026, 10, 1, 9);
      final p = oshiGrowthProgressFrom([
        ProgressRecord(qid: 'a', subjectId: 's', correct: true, at: d),
        ProgressRecord(qid: 'b', subjectId: 's', correct: false, at: d.add(const Duration(hours: 5))),
        ProgressRecord(qid: 'c', subjectId: 's', correct: true, at: d.add(const Duration(days: 5))),
      ]);
      expect(p.totalAnswered, 3);
      expect(p.studyDays, 2);
      expect(oshiGrowthProgressFrom(const []).totalAnswered, 0);
    });
  });

  group('模擬試験の結果画面', () {
    testWidgets('結果分析カードが出る（幅320・文字2倍でオーバーフローなし）', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 8000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(ProviderScope(
        overrides: studyNotesTestOverrides(),
        child: MaterialApp(home: MockExamPage(progressStore: InMemoryProgressStore())),
      ));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      for (var i = 0; i < 10 && find.text('模擬試験を開始する').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('模擬試験を開始する'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        if (find.byType(ChoiceQuestionView).evaluate().isNotEmpty) {
          await tester.tap(find.byType(InkWell).first);
          await tester.pump();
        }
        await tester.tap(find.text('次へ'));
        await tester.pump();
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MockExamAnalysisCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
