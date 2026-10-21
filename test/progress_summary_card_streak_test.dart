import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/progress/progress_summary_card.dart';
import 'package:ukalab_core/learning.dart';

void main() {
  testWidgets('連続学習日数が1日以上あるとストリーク表示が出る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // 絶対日付をハードコードすると、テスト実行日が進むにつれて「2日以上空いた」
    // 扱いになり表示が消えてしまうため、実行時刻からの相対日付で記録する。
    await recordStudyToday(now: DateTime.now().subtract(const Duration(days: 1)));

    final store = InMemoryProgressStore();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProgressSummaryCard(store: store))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('日連続'), findsOneWidget);
  });
}
