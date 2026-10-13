import 'dart:math';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart' show NagaraSessionView;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/hands_free/hands_free_section.dart';
import 'package:ukalab_boki3/hands_free/hands_free_state.dart';
import 'package:ukalab_boki3/main.dart';
import 'package:ukalab_boki3/nagara/nagara_session_page.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'test_support.dart';

Question _q(String qid, {String explanation = '解説-', String? level}) => Question(
      qid: qid,
      examId: 'boki3',
      subjectId: 'q2_choubo',
      topicId: 'ch1',
      prompt: '問題文-$qid',
      choices: ['正しい-$qid', '誤り-$qid'],
      answerIndex: 0,
      explanation: '$explanation$qid',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
      levelId: level,
    );

Future<void> _tick(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  late FakeSpeechBackend speech;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    speech = FakeSpeechBackend();
    appSpeechBackendForTest = speech;
    // 考える間・間は短くして、テストを速く進める。
    appHandsFree.value = const HandsFreeSettings(thinkSeconds: 1, betweenSeconds: 0);
  });

  tearDown(() {
    appSpeechBackendForTest = null;
    appHandsFree.value = const HandsFreeSettings();
  });

  Future<InMemoryProgressStore> pumpPage(
    WidgetTester tester,
    List<Question> questions, {
    int max = kNagaraMaxQuestions,
  }) async {
    final store = InMemoryProgressStore();
    await tester.pumpWidget(ProviderScope(
      overrides: studyNotesTestOverrides(),
      child: MaterialApp(
        home: NagaraSessionPage(
          progressStore: store,
          maxQuestions: max,
          questionLoader: () async => questions,
          random: Random(1),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return store;
  }

  testWidgets('学ぶタブの「ながら学習」から、ながらセッションを開ける', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [entitlementServiceProvider.overrideWithValue(FakeEntitlementService()), ...studyNotesTestOverrides()],
      child: const UkalabBoki3App(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('学ぶ'));
    await tester.pumpAndSettle();
    final entry = find.textContaining('ながら学習（');
    await tester.scrollUntilVisible(entry, 100);
    await tester.tap(entry);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(NagaraSessionView), findsOneWidget);
    expect(speech.spoken, isNotEmpty);
    expect(speech.spoken.first, startsWith('問題。'));

    // 画面を離れたら止まる。
    await tester.pumpWidget(const SizedBox());
    expect(speech.stopCount, greaterThan(0));
  });

  test('出題は選択式だけで、復習が必要な問題が先頭に来る', () async {
    final all = await loadQuestions();
    final picked = pickNagaraQuestions(all, const [], random: Random(1));
    expect(picked, isNotEmpty);
    expect(picked.every((q) => q.type == QuestionType.choice), isTrue);

    final wrong = picked[picked.length - 1];
    final again = pickNagaraQuestions(
      all,
      [ProgressRecord(qid: wrong.qid, subjectId: wrong.subjectId, correct: false, at: DateTime.now())],
      random: Random(1),
    );
    expect(again.first.qid, wrong.qid);
  });

  testWidgets('設定: 考える間・次までの間・自動で次へを保存し、反映する', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: HandsFreeSection()))));

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('nagara-think-seconds')), matching: find.text('8 秒')));
    await tester.pump();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('nagara-between-seconds')), matching: find.text('5 秒')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nagara-auto-advance')));
    await tester.pump();

    expect(appHandsFree.value.thinkSeconds, 8);
    expect(appHandsFree.value.betweenSeconds, 5);
    expect(appHandsFree.value.autoAdvance, isFalse);

    // 端末内に保存され、読み直しても同じ。
    appHandsFree.value = const HandsFreeSettings();
    await tester.runAsync(loadHandsFree);
    expect(appHandsFree.value.thinkSeconds, 8);
    expect(appHandsFree.value.betweenSeconds, 5);
    expect(appHandsFree.value.autoAdvance, isFalse);
  });

  testWidgets('設定した考える間のあいだは次へ進まず、過ぎたら答えを読む', (tester) async {
    appHandsFree.value = const HandsFreeSettings(thinkSeconds: 3, betweenSeconds: 0);
    await pumpPage(tester, [_q('a')]);
    expect(speech.spoken.length, 1);
    await _tick(tester, 2);
    expect(speech.spoken.length, 1);
    await _tick(tester, 2);
    expect(speech.spoken.length, 2);
    expect(speech.spoken.last, contains('解説。解説-a'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('誤答は解答記録（間違いノートの元）に載り、解説も読む', (tester) async {
    final store = await pumpPage(tester, [_q('a'), _q('b')]);

    await tester.tap(find.text('誤り-a'));
    await tester.pump();
    await tester.pump();

    final records = await tester.runAsync(store.loadRecords) ?? [];
    expect(records, hasLength(1));
    expect(records.single.qid, 'a');
    expect(records.single.correct, isFalse);
    expect(records.single.subjectId, 'q2_choubo');
    expect(speech.spoken.last, contains('解説-a'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('正解は、終わったときに解答記録に載る', (tester) async {
    final store = await pumpPage(tester, [_q('a'), _q('b')]);

    await tester.tap(find.text('正しい-a'));
    await tester.pump();
    await _tick(tester, 3);
    await tester.tap(find.text('正しい-b'));
    await tester.pump();
    await _tick(tester, 3);

    expect(find.text('おつかれさまでした'), findsOneWidget);
    final records = await tester.runAsync(store.loadRecords) ?? [];
    expect(records.map((r) => r.qid).toSet(), {'a', 'b'});
    expect(records.every((r) => r.correct), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('時間切れは誤答として記録しない。上限に着いたら責めずにひと休みを促す', (tester) async {
    final store = await pumpPage(tester, [_q('a'), _q('b'), _q('c')], max: 2);
    await _tick(tester, 12);

    expect(find.text('おつかれさまでした'), findsOneWidget);
    expect(find.text(NagaraStrings.ja.restSuggestion), findsOneWidget);
    expect(await tester.runAsync(store.loadRecords), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('終了で止まり、その後は読み上げない', (tester) async {
    await pumpPage(tester, [_q('a'), _q('b')]);
    await tester.tap(find.text(NagaraStrings.ja.stop));
    await tester.pump();
    final before = speech.spoken.length;
    expect(speech.stopCount, greaterThan(0));
    expect(find.text('おつかれさまでした'), findsOneWidget);

    await _tick(tester, 30);
    expect(speech.spoken.length, before);
    await tester.pumpWidget(const SizedBox());
  });
}
