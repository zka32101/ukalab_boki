import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'test_support.dart';

/// 旧区分表専用の手形問題（6問）が、[PracticePage] の出題プールから
/// 2027年4月以降は除外されることをUIレベルで確認する（108→105問）。
void main() {
  testWidgets('2027年4月以降は旧区分表専用の手形問題が出題プールから除外される（108→105問）', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: studyNotesTestOverrides(),
        child: MaterialApp(
          home: PracticePage(
            progressStore: InMemoryProgressStore(),
            subjectId: 'q1_shiwake',
            now: DateTime(2027, 5, 1),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('/ 105問目'), findsOneWidget);
  });
}
