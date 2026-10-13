import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'test_support.dart';

/// 旧区分表専用の手形問題（6問）が、[PracticePage] の出題プールに
/// 2027年3月以前は含まれることをUIレベルで確認する（93問）。
void main() {
  testWidgets('2027年3月以前は旧区分表専用の手形問題を含む（93問）', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: studyNotesTestOverrides(),
        child: MaterialApp(
          home: PracticePage(
            progressStore: InMemoryProgressStore(),
            subjectId: 'q1_shiwake',
            now: DateTime(2026, 11, 1),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('/ 93問目'), findsOneWidget);
  });
}
