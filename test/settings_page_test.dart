import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukalab_boki3/progress/progress_revision.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/settings/settings_page.dart';

void main() {
  testWidgets('リセットボタンは確認ダイアログを経てからレコードを削除する', (tester) async {
    final progressStore = InMemoryProgressStore();
    await progressStore.addRecord(
      ProgressRecord(qid: 'boki3-c-0001', subjectId: 'q2_choubo', correct: false, at: DateTime.now()),
    );
    final revisionBefore = progressRevision.value;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SettingsPage(progressStore: progressStore))),
    );
    await tester.pumpAndSettle();

    // 設定項目が増えて画面外になったので、スクロールして出す。
    await tester.scrollUntilVisible(find.text('解答記録をリセットする'), 200);
    expect(find.text('解答記録をリセットする'), findsOneWidget);
    await tester.tap(find.text('解答記録をリセットする'));
    await tester.pumpAndSettle();

    // 確認ダイアログが出る。まずキャンセルすると削除されない。
    expect(find.text('解答記録をリセットしますか？'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(await progressStore.loadRecords(), hasLength(1));

    // 改めてリセットを実行すると削除され、progressRevisionも進む。
    await tester.tap(find.text('解答記録をリセットする'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リセットする'));
    await tester.pumpAndSettle();

    expect(await progressStore.loadRecords(), isEmpty);
    expect(progressRevision.value, greaterThan(revisionBefore));
    expect(find.text('解答記録をリセットしました'), findsOneWidget);
  });
}
