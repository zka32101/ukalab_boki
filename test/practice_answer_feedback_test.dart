import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'test_support.dart';

/// 解答直後は、解答した問題の解説・正誤が出続け、次の問題のものは出ないことを固定する。
/// `PracticeSession.current` は解答を記録した時点で次の問題へ進むため、解答直後に
/// 親の再描画などで画面が組み直されても解説がずれないことも、親を明示的に
/// 再描画して確認する。
Question _q(String qid, Map<String, dynamic> extra) => Question.fromJson({
      'qid': qid,
      'examId': 'boki3',
      'subjectId': 'sub',
      'topicId': 't1',
      'source': 'original',
      'sourceRef': '自作',
      'contentVer': '1',
      ...extra,
    });

Question _choice(String qid, String prompt, String expl, int answer) =>
    _q(qid, {
      'type': 'choice',
      'prompt': prompt,
      'choices': ['選択肢甲', '選択肢乙', '選択肢丙'],
      'answerIndex': answer,
      'explanation': expl,
    });

Question _journal(String qid, String prompt, String expl) => _q(qid, {
      'type': 'journal',
      'topicId': 'purchase_cash',
      'prompt': prompt,
      'journalAnswer': [
        {'side': 'debit', 'account': 'purchases', 'amount': 50000},
        {'side': 'credit', 'account': 'cash', 'amount': 50000},
      ],
      'explanation': expl,
    });

/// 親の再描画（同じ内容の PracticePage を作り直す）を起こせるホスト。
late ValueNotifier<int> _rebuild;

Future<void> _pump(WidgetTester tester, List<Question> qs) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _rebuild = ValueNotifier(0);
  addTearDown(_rebuild.dispose);
  final store = InMemoryProgressStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: studyNotesTestOverrides(),
      child: MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: _rebuild,
          builder: (_, __, ___) => PracticePage(
            progressStore: store,
            questionsOverride: qs,
          ),
        ),
      ),
    ),
  );
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
}

/// 画面に出ている問題文から、いま出題中の問題を返す。
Question _shown(List<Question> qs) =>
    qs.singleWhere((q) => find.text(q.prompt).evaluate().isNotEmpty);

Future<void> _rebuildParent(WidgetTester tester) async {
  _rebuild.value++;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _answerChoiceWrong(WidgetTester tester, Question q) async {
  final wrong = q.answerIndex == 0 ? 1 : 0;
  await tester.tap(find.text(q.choices[wrong]));
  await tester.pump();
  await tester.tap(find.text('答え合わせ'));
  await tester.pumpAndSettle();
}

void main() {
  final c1 = _choice('c1', '選択問題その一', '解説その一です', 0);
  final c2 = _choice('c2', '選択問題その二', '解説その二です', 1);
  final j1 = _journal('j1', '仕訳問題その一', '仕訳解説その一です');
  final j2 = _journal('j2', '仕訳問題その二', '仕訳解説その二です');

  testWidgets('選択式: 解答直後は解答した問題の解説・正誤が出て、次の問題のものは出ない', (tester) async {
    final qs = [c1, c2];
    await _pump(tester, qs);
    final first = _shown(qs);
    final second = qs.firstWhere((q) => q != first);
    await _answerChoiceWrong(tester, first);

    expect(find.text('不正解です'), findsOneWidget);
    expect(find.textContaining(first.explanation), findsOneWidget);
    expect(find.textContaining(second.explanation), findsNothing);
    expect(find.text(second.prompt), findsNothing);
    expect(find.text('1 / 2問目'), findsOneWidget);

    // 解答直後に親が再描画されても、解答した問題のまま。
    await _rebuildParent(tester);
    expect(find.text('不正解です'), findsOneWidget);
    expect(find.textContaining(first.explanation), findsOneWidget);
    expect(find.text(second.prompt), findsNothing);
    expect(find.text('1 / 2問目'), findsOneWidget);
  });

  testWidgets('選択式: 次へで次の問題に進み、最後は解説を見てから結果画面へ移る', (tester) async {
    final qs = [c1, c2];
    await _pump(tester, qs);
    final first = _shown(qs);
    final second = qs.firstWhere((q) => q != first);
    await _answerChoiceWrong(tester, first);
    await _rebuildParent(tester);

    await tester.tap(find.text('次の問題へ'));
    await tester.pumpAndSettle();
    expect(find.text(second.prompt), findsOneWidget);
    expect(find.text('2 / 2問目'), findsOneWidget);
    expect(find.text('不正解です'), findsNothing);
    expect(find.textContaining(first.explanation), findsNothing);

    // 最後の問題: 解答直後（再描画後も）は解説が見え、結果画面ではない。
    await _answerChoiceWrong(tester, second);
    await _rebuildParent(tester);
    expect(find.text('不正解です'), findsOneWidget);
    expect(find.textContaining(second.explanation), findsOneWidget);
    expect(find.text('戻る'), findsNothing);

    await tester.tap(find.text('次の問題へ'));
    await tester.pumpAndSettle();
    expect(find.text('戻る'), findsOneWidget);
    expect(find.textContaining(second.explanation), findsNothing);
  });

  testWidgets('仕訳: 解答直後は解答した問題の解説・正誤が出て、次の問題のものは出ない', (tester) async {
    final qs = [j1, j2];
    await _pump(tester, qs);
    final first = _shown(qs);
    final second = qs.firstWhere((q) => q != first);
    await tester.tap(find.text('答え合わせ')); // 未入力なので不正解
    await tester.pumpAndSettle();

    expect(find.text('不正解です'), findsOneWidget);
    expect(find.textContaining(first.explanation), findsOneWidget);
    expect(find.textContaining(second.explanation), findsNothing);

    await _rebuildParent(tester);
    expect(find.text('不正解です'), findsOneWidget);
    expect(find.text(first.prompt), findsOneWidget);
    expect(find.textContaining(first.explanation), findsOneWidget);
    expect(find.text(second.prompt), findsNothing);
    expect(find.text('1 / 2問目'), findsOneWidget);
  });

  testWidgets('仕訳: 次へで次の問題に進み、最後は解説を見てから結果画面へ移る', (tester) async {
    final qs = [j1, j2];
    await _pump(tester, qs);
    final first = _shown(qs);
    final second = qs.firstWhere((q) => q != first);
    await tester.tap(find.text('答え合わせ'));
    await tester.pumpAndSettle();
    await _rebuildParent(tester);

    await tester.tap(find.text('次の問題へ'));
    await tester.pumpAndSettle();
    expect(find.text(second.prompt), findsOneWidget);
    expect(find.text('2 / 2問目'), findsOneWidget);
    expect(find.textContaining(first.explanation), findsNothing);
    expect(find.text('不正解です'), findsNothing);

    await tester.tap(find.text('答え合わせ'));
    await tester.pumpAndSettle();
    await _rebuildParent(tester);
    expect(find.textContaining(second.explanation), findsOneWidget);
    expect(find.text('戻る'), findsNothing);

    await tester.tap(find.text('次の問題へ'));
    await tester.pumpAndSettle();
    expect(find.text('戻る'), findsOneWidget);
  });
}
