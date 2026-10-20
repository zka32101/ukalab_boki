import 'package:app_common_kit/app_common_kit.dart' show FakeEntitlementService, entitlementServiceProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/main.dart';
import 'package:ukalab_boki3/exam_prep/exam_prep_entry.dart';
import 'package:ukalab_boki3/mistake_note/mistake_note_page.dart';
import 'package:ukalab_boki3/oshi/boki3_oshi_card.dart';
import 'package:ukalab_boki3/oshi/oshi_home_cards.dart';
import 'package:ukalab_boki3/progress/progress_summary_card.dart';
import 'package:ukalab_boki3/reading/reading_list_page.dart';
import 'package:ukalab_boki3/term/term_list_page.dart';
import 'package:ukalab_core/daily_goal.dart';
import 'package:ukalab_core/reminder.dart';
import 'package:ukalab_core/ui.dart';

import 'test_support.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, {required Size size, required double scale}) async {
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

  void expectAll() {
    for (final t in const ['今日やること', '記録', '試験に向けて']) {
      expect(find.descendant(of: find.byType(HomeSectionHeader), matching: find.text(t)), findsOneWidget, reason: t);
    }
    expect(find.byType(HomeSectionHeader), findsNWidgets(3));
    for (final type in <Type>[
      Boki3OshiCard,
      OshiMessageCard,
      DailyMissionCard,
      StudyReminderCard,
      ExamCountdownEntry,
      ExamPrepEntryCard,
      ProgressSummaryCard,
      WeeklyRecapSection,
    ]) {
      expect(find.byType(type, skipOffstage: false), findsWidgets, reason: '$type');
    }
  }

  testWidgets('ホームは3つの見出し（今日やること／記録／試験に向けて）で、調べる系の入口は「学ぶ」へ移った', (tester) async {
    await pump(tester, size: const Size(800, 6000), scale: 1.0);
    expectAll();
    expect(find.text('間違いノート', skipOffstage: false), findsNothing);
    expect(find.byType(MistakeNoteTile, skipOffstage: false), findsNothing);
    expect(find.text('用語集', skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('「学ぶ」の「道具」から間違いノート・メモ・用語集・読み物に行ける', (tester) async {
    await pump(tester, size: const Size(800, 6000), scale: 1.0);
    await tester.tap(find.text('学ぶ'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(HomeSectionHeader), matching: find.text('道具')), findsOneWidget);
    expect(find.byType(StudyNotesHomeCards), findsOneWidget);
    // 会社経営（簿記固有）も学ぶに残っている。
    expect(find.text('会社を経営する'), findsOneWidget);

    Future<void> openAndBack(String label, Type page) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.byType(page), findsOneWidget, reason: label);
      Navigator.of(tester.element(find.byType(page))).pop();
      await tester.pumpAndSettle();
    }

    await openAndBack('間違いノート', MistakeNotePage);
    await openAndBack('用語集', TermListPage);
    await openAndBack('章ごとの解説読み物', ReadingListPage);
  });

  testWidgets('狭い幅・大きい文字でもオーバーフローしない', (tester) async {
    await pump(tester, size: const Size(320, 8000), scale: 2.0);
    expectAll();
    expect(tester.takeException(), isNull);
  });
}
