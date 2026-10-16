import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'test_support.dart';

Question _q(String qid, Map<String, dynamic> extra) => Question.fromJson({
      'qid': qid,
      'examId': 'boki3',
      'subjectId': 'sub',
      'topicId': 't1',
      'prompt': '問題$qid',
      'explanation': '解説テキスト',
      'source': 'original',
      'sourceRef': '自作',
      'contentVer': '1',
      ...extra,
    });

final _tf = _q(
    'tf1', {'type': 'trueFalse', 'prompt': '現金は流動資産である。', 'answerBool': true});
final _cloze = _q('cl1', {
  'type': 'cloze',
  'prompt': '{{1}}は資産の勘定である。',
  'blanks': [
    {
      'id': 1,
      'answers': ['現金'],
    },
  ],
});
final _rev = _q('rv1', {
  'type': 'reverseLookup',
  'prompt': '次の説明にあたる用語は何か。',
  'clue': '商品を掛けで売り上げたときの債権。',
  'answers': ['売掛金'],
});
final _choice = _q('ch1', {
  'type': 'choice',
  'choices': ['現金', '売掛金', '買掛金'],
  'answerIndex': 0,
});

Future<void> _pump(
  WidgetTester tester,
  ProgressStore store,
  List<Question> qs, {
  required bool enabled,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: studyNotesTestOverrides(),
      child: MaterialApp(
        home: PracticePage(
            progressStore: store,
            questionsOverride: qs,
            newTypesEnabled: enabled),
      ),
    ),
  );
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<List<ProgressRecord>> _records(
    WidgetTester tester, ProgressStore s) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  return (await tester.runAsync(s.loadRecords))!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('フラグ OFF: 新タイプは出題プールから除かれる', (tester) async {
    await _pump(tester, InMemoryProgressStore(), [_tf, _cloze, _rev, _choice],
        enabled: false);
    expect(find.text('1 / 1問目'), findsOneWidget);
    expect(find.text('現金は流動資産である。'), findsNothing);
  });

  testWidgets('フラグ ON: ○×を解答すると記録される', (tester) async {
    final store = InMemoryProgressStore();
    await _pump(tester, store, [_tf], enabled: true);
    expect(find.text('現金は流動資産である。'), findsOneWidget);
    await tester.tap(find.text('正しい'));
    await tester.pumpAndSettle();
    expect(find.text('正解です'), findsOneWidget);
    final recs = await _records(tester, store);
    expect(recs.single.qid, 'tf1');
    expect(recs.single.correct, isTrue);
  });

  testWidgets('フラグ ON: 空欄補充を解答すると記録され、自己申告で履歴が正解に直る', (tester) async {
    final store = InMemoryProgressStore();
    await _pump(tester, store, [_cloze], enabled: true);
    await tester.enterText(find.byType(TextField), 'げんきん');
    await tester.pump();
    await tester.tap(find.text('解答する'));
    await tester.pumpAndSettle();
    expect(find.text('不正解です'), findsOneWidget);
    expect((await _records(tester, store)).single.correct, isFalse);
    await tester.tap(find.text('合っていた（自己申告）'));
    await tester.pumpAndSettle();
    expect(find.text('自己申告で正解にしました'), findsOneWidget);
    final recs = await _records(tester, store);
    expect(recs, hasLength(1));
    expect(recs.single.correct, isTrue);
  });

  testWidgets('フラグ ON: 説明から用語を解答すると記録される', (tester) async {
    final store = InMemoryProgressStore();
    await _pump(tester, store, [_rev], enabled: true);
    await tester.enterText(find.byType(TextField), '売掛金');
    await tester.pump();
    await tester.tap(find.text('解答する'));
    await tester.pumpAndSettle();
    expect(find.text('正解です'), findsOneWidget);
    final recs = await _records(tester, store);
    expect(recs.single.qid, 'rv1');
    expect(recs.single.correct, isTrue);
  });

  test('markLatestCorrect は直近の同一 qid の誤答だけを正解に直す', () async {
    final store = InMemoryProgressStore();
    final t = DateTime(2026, 1, 1);
    await store.addRecord(
        ProgressRecord(qid: 'a', subjectId: 's', correct: false, at: t));
    await store.addRecord(
        ProgressRecord(qid: 'b', subjectId: 's', correct: false, at: t));
    await markLatestCorrect(store, 'a');
    final recs = await store.loadRecords();
    expect(recs.map((r) => r.correct), [true, false]);
  });
}
