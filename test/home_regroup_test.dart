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
    for (final t in const ['今日やること', '記録', '試験に向けて', '道具']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.byType(HomeSectionHeader), findsNWidgets(4));
    for (final type in <Type>[
      Boki3OshiCard,
      OshiMessageCard,
      DailyMissionCard,
      StudyReminderCard,
      ExamCountdownEntry,
      ExamPrepEntryCard,
      ProgressSummaryCard,
      WeeklyRecapSection,
      MistakeNoteTile,
    ]) {
      expect(find.byType(type, skipOffstage: false), findsOneWidget, reason: '$type');
    }
  }

  testWidgets('ホームに4つの見出しと既存の入口がすべてある', (tester) async {
    await pump(tester, size: const Size(800, 6000), scale: 1.0);
    expectAll();
    expect(tester.takeException(), isNull);
  });

  testWidgets('狭い幅・大きい文字でもオーバーフローしない', (tester) async {
    await pump(tester, size: const Size(320, 8000), scale: 2.0);
    expectAll();
    expect(tester.takeException(), isNull);
  });
}
