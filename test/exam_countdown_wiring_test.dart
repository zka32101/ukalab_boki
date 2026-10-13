import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/exam_prep/exam_prep_data.dart';
import 'package:ukalab_boki3/exam_prep/exam_prep_entry.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'test_support.dart';

final _now = DateTime(2026, 10, 14, 12);
const _s = ExamCountdownStrings.ja;

Future<ProviderContainer> _pump(WidgetTester tester, {DateTime? examDate}) async {
  SharedPreferences.setMockInitialValues({
    if (examDate != null) 'ukalab_boki3_exam_date': examDate.toIso8601String(),
  });
  final container = ProviderContainer(overrides: studyNotesTestOverrides());
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: ExamCountdownEntry(clock: () => _now))),
  ));
  container.read(examDateProvider);
  await tester.runAsync(() => container.read(examDateProvider.notifier).ready);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  testWidgets('未設定なら何も出ない', (tester) async {
    await _pump(tester);
    expect(find.byType(Chip), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  final cases = <String, (DateTime, String)>{
    'farAway(200日)': (DateTime(2027, 5, 2), _s.chipDays(200)),
    'approaching(50日)': (DateTime(2026, 12, 3), _s.chipDays(50)),
    'close(20日)': (DateTime(2026, 11, 3), _s.chipDays(20)),
    'finalDays(3日)': (DateTime(2026, 10, 17), _s.chipDays(3)),
    '当日': (DateTime(2026, 10, 14), _s.chipToday),
    '過ぎた日': (DateTime(2026, 10, 10), _s.chipDone),
  };
  for (final e in cases.entries) {
    testWidgets('設定済み: ${e.key}', (tester) async {
      await _pump(tester, examDate: e.value.$1);
      expect(find.byType(ExamCountdownChip), findsOneWidget);
      expect(find.text(e.value.$2), findsOneWidget);
    });
  }

  test('過ぎた日はおつかれさま', () {
    expect(_s.chipDone, 'おつかれさまでした');
  });

  testWidgets('タップで試験日の設定画面が開く', (tester) async {
    await _pump(tester, examDate: DateTime(2026, 11, 3));
    await tester.tap(find.byType(ActionChip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ExamDateSettingsPage), findsOneWidget);
  });
}
