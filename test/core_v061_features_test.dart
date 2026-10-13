import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/evidence_input/evidence_question_view.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/hands_free/hands_free_choice_question.dart';
import 'package:ukalab_boki3/journal_input/journal_question_view.dart';
import 'package:ukalab_boki3/ledger_input/ledger_question_view.dart';
import 'package:ukalab_boki3/mistake_note/mistake_note_data.dart';
import 'package:ukalab_boki3/mistake_note/mistake_note_page.dart';
import 'package:ukalab_boki3/oshi/oshi_home_cards.dart';
import 'package:ukalab_boki3/oshi/oshi_recap.dart';
import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/settings/boki_data_parts.dart';
import 'package:ukalab_boki3/company_mode/company_mode_history_store.dart';
import 'package:ukalab_boki3/worksheet_input/worksheet_question_view.dart';
import 'package:ukalab_core/glossary.dart' show LearnedTermsStore;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'test_support.dart';

// 2026-10-14 は水曜。月曜始まりの今週は 10/12〜10/18。
final _now = DateTime(2026, 10, 14, 12);

Question _q(String qid, {String topic = 'ch1'}) => Question(
      qid: qid,
      examId: 'boki3',
      subjectId: 'q1_shiwake',
      topicId: topic,
      prompt: '問題文-$qid',
      choices: const ['a', 'b'],
      answerIndex: 0,
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

ProgressRecord _rec(String qid, DateTime at, {bool correct = true, String subject = 'q1_shiwake'}) =>
    ProgressRecord(qid: qid, subjectId: subject, correct: correct, at: at);

Future<InMemoryProgressStore> _store(List<ProgressRecord> records) async {
  final s = InMemoryProgressStore();
  for (final r in records) {
    await s.addRecord(r);
  }
  return s;
}

/// 非同期の読み込み（実際の非同期）を待ってから描画に反映する。
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump();
}

Future<void> _pump(WidgetTester tester, Widget child, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  // 試験区分のデータは fake async の外で先に読んでキャッシュしておく。
  await tester.runAsync(() async {
    await loadExamConfig();
    await loadQuestions();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: studyNotesTestOverrides(),
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  ));
  await _settle(tester);
}

void main() {
  group('入力の作り方(推しの一言)', () {
    test('履歴も試験日もなければ、最小の状況になる', () {
      final c = oshiMessageContextFor(records: const [], currentStreak: 0, now: _now);
      expect(c.daysSinceLastStudy, isNull);
      expect(c.streakDays, 0);
      expect(c.todayAnswered, 0);
      expect(c.todayCorrectRate, isNull);
      expect(c.examDaysLeft, isNull);
      expect(c.hasWeakTopics, isFalse);
    });

    test('今日の解答数・正答率・最終学習からの日数・連続日数・試験日・苦手が反映される', () {
      final c = oshiMessageContextFor(
        records: [
          _rec('a', DateTime(2026, 10, 13, 9)),
          _rec('b', DateTime(2026, 10, 14, 9)),
          _rec('c', DateTime(2026, 10, 14, 10)),
          _rec('d', DateTime(2026, 10, 14, 11), correct: false),
        ],
        currentStreak: 2,
        now: _now,
        examDate: DateTime(2026, 11, 13),
        questions: [_q('a'), _q('b'), _q('c'), _q('d')],
      );
      expect(c.daysSinceLastStudy, 0);
      expect(c.streakDays, 2);
      expect(c.todayAnswered, 3);
      expect(c.todayCorrectRate, closeTo(2 / 3, 1e-9));
      expect(c.examDaysLeft, 30);
      expect(c.hasWeakTopics, isTrue);
    });

    test('久しぶりのときは連続日数を使わない。過ぎた試験日は渡さない', () {
      final c = oshiMessageContextFor(
        records: [_rec('a', DateTime(2026, 10, 9, 9))],
        currentStreak: 5,
        now: _now,
        examDate: DateTime(2026, 10, 1),
      );
      expect(c.daysSinceLastStudy, 5);
      expect(c.streakDays, 0);
      expect(c.examDaysLeft, isNull);
    });

    test('分野の表示名は、その問題の科目名になる(無ければID)', () {
      final label = topicLabelFor([_q('a')], (id) => id == 'q1_shiwake' ? '第1問 仕訳' : null);
      expect(label('ch1'), '第1問 仕訳');
      expect(label('unknown'), 'unknown');
    });

    test('論点の無い記録は、出題データの qid から補う', () {
      final out = withTopics([_rec('a', _now), _rec('zzz', _now)], [_q('a', topic: 'ch9')]);
      expect(out[0].topicId, 'ch9');
      expect(out[1].topicId, isNull);
    });
  });

  group('推しの一言(ホーム)', () {
    testWidgets('履歴なし: あいさつが出る', (tester) async {
      await _pump(
        tester,
        OshiMessageCard(
          progressStore: await _store(const []),
          clock: () => _now,
          loadQuestionList: () async => const [],
          loadStreak: () async => 0,
        ),
      );
      expect(find.byType(OshiMessageBubble), findsOneWidget);
      final greetings = OshiMessageStrings.ja.variants(OshiSituation.greeting);
      expect(greetings.any((g) => find.text(g).evaluate().isNotEmpty), isTrue);
    });

    testWidgets('履歴あり(5日空いた): おかえりの一言が出る', (tester) async {
      await _pump(
        tester,
        OshiMessageCard(
          progressStore: await _store([_rec('a', DateTime(2026, 10, 9, 9))]),
          clock: () => _now,
          loadQuestionList: () async => const [],
          loadStreak: () async => 0,
        ),
      );
      final texts = OshiMessageStrings.ja.variants(OshiSituation.welcomeBack);
      expect(texts.any((t) => find.text(t).evaluate().isNotEmpty), isTrue);
    });

    testWidgets('今日たくさん解いた: 達成の一言が出る(久しぶりにはならない)', (tester) async {
      await _pump(
        tester,
        OshiMessageCard(
          progressStore:
              await _store([for (var i = 0; i < 4; i++) _rec('q$i', DateTime(2026, 10, 14, 9, i))]),
          clock: () => _now,
          loadQuestionList: () async => const [],
          loadStreak: () async => 1,
        ),
      );
      final texts = OshiMessageStrings.ja.variants(OshiSituation.praise);
      expect(texts.any((t) => find.text(t).evaluate().isNotEmpty), isTrue);
    });
  });

  group('週間ふりかえり(ホーム)', () {
    final strings = WeeklyRecapStrings.ja;

    testWidgets('今週解いていれば、できたことが出る', (tester) async {
      await _pump(
        tester,
        WeeklyRecapSection(
          progressStore: await _store([
            _rec('a', DateTime(2026, 10, 12, 9)),
            _rec('b', DateTime(2026, 10, 14, 9)),
            _rec('c', DateTime(2026, 10, 14, 10), correct: false),
          ]),
          clock: () => _now,
          loadQuestionList: () async => [_q('a'), _q('b'), _q('c')],
        ),
      );
      expect(find.text(strings.title), findsOneWidget);
      expect(find.text(strings.emptyTitle), findsNothing);
      expect(find.textContaining('3${strings.questionsUnit}'), findsWidgets);
    });

    testWidgets('履歴なしの週(0件)は、責めずに穏やかな表示', (tester) async {
      await _pump(
        tester,
        WeeklyRecapSection(
          progressStore: await _store(const []),
          clock: () => _now,
          loadQuestionList: () async => const [],
        ),
      );
      expect(find.text(strings.emptyTitle), findsOneWidget);
    });

    testWidgets('先週だけ解いていた場合も、今週は0件として穏やかに表示する', (tester) async {
      await _pump(
        tester,
        WeeklyRecapSection(
          progressStore: await _store([_rec('a', DateTime(2026, 10, 8, 9))]),
          clock: () => _now,
          loadQuestionList: () async => [_q('a')],
        ),
      );
      expect(find.text(strings.emptyTitle), findsOneWidget);
    });
  });

  group('間違いノート', () {
    final strings = MistakeNoteStrings.ja;

    Future<void> pumpPage(
      WidgetTester tester, {
      required InMemoryMistakeNoteStore noteStore,
      required InMemoryProgressStore progress,
    }) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await loadExamConfig();
        await loadQuestions();
      });
      await tester.pumpWidget(ProviderScope(
        overrides: studyNotesTestOverrides(),
        child: MaterialApp(home: MistakeNotePage(progressStore: progress, store: noteStore)),
      ));
      await _settle(tester);
    }

    testWidgets('履歴なし: これからが空のメッセージ', (tester) async {
      await pumpPage(tester, noteStore: InMemoryMistakeNoteStore(), progress: await _store(const []));
      expect(find.text(strings.emptyUpcomingTitle), findsOneWidget);
    });

    testWidgets('出題データに無い問題は出さない', (tester) async {
      await pumpPage(
        tester,
        noteStore: InMemoryMistakeNoteStore(),
        progress: await _store([_rec('gone', DateTime(2026, 10, 14, 9), correct: false)]),
      );
      expect(find.text(strings.retry), findsNothing);
      expect(find.text(strings.emptyUpcomingTitle), findsOneWidget);
    });

    testWidgets('間違えた問題が一覧に出て、履歴から取り込んだ内容が保存される', (tester) async {
      final noteStore = InMemoryMistakeNoteStore();
      await pumpPage(
        tester,
        noteStore: noteStore,
        progress: await _store([
          _rec('boki3-c-0001', DateTime(2026, 10, 14, 9), correct: false, subject: 'q2_choubo'),
          _rec('boki3-c-0002', DateTime(2026, 10, 14, 10), subject: 'q2_choubo'),
        ]),
      );
      expect(find.text('次のうち、資産に分類される勘定科目はどれか。'), findsOneWidget);
      expect(find.text(strings.retry), findsOneWidget);
      expect((await noteStore.read()).map((e) => e.qid), ['boki3-c-0001']);
    });

    // 解き直しは既存の演習画面を、その1問(restrictToQids)で起動する。形式ごとに起動できること。
    for (final (qid, subject, viewType, label) in <(String, String, Type, String)>[
      ('boki3-c-0001', 'q2_choubo', HandsFreeChoiceQuestion, '選択式'),
      ('boki3-j-0001', 'q1_shiwake', JournalQuestionView, '仕訳'),
      ('boki3-l-0001', 'q2_choubo', LedgerQuestionView, '帳簿'),
      ('boki3-w-0001', 'q3_kessan', WorksheetQuestionView, '精算表'),
    ]) {
      testWidgets('解き直す($label): 演習画面がその1問で開き、戻ると一覧に戻る', (tester) async {
        final noteStore = InMemoryMistakeNoteStore();
        await pumpPage(
          tester,
          noteStore: noteStore,
          // 演習画面は現在時刻で記録するため、間違いは十分過去の日時にしておく。
          progress: await _store([_rec(qid, DateTime(2020, 1, 1, 9), correct: false, subject: subject)]),
        );
        await tester.tap(find.text(strings.retry));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();

        final page = tester.widget<PracticePage>(find.byType(PracticePage));
        expect(page.restrictToQids, {qid});
        expect(find.byType(viewType), findsOneWidget);
        // 出題形式が「そのほか」に化けていない(証ひょう読み取りなど別ビューではない)。
        expect(find.byType(EvidenceQuestionView), findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await _settle(tester);
        expect(find.byType(PracticePage), findsNothing);
        expect(find.byType(MistakeNotePage), findsOneWidget);
        expect((await noteStore.read()).single.qid, qid);
      });
    }

    testWidgets('解き直して正解すると、戻ったときにノートへ反映される', (tester) async {
      final noteStore = InMemoryMistakeNoteStore();
      final progress =
          await _store([_rec('boki3-c-0001', DateTime(2020, 1, 1, 9), correct: false, subject: 'q2_choubo')]);
      await pumpPage(tester, noteStore: noteStore, progress: progress);

      await tester.tap(find.text(strings.retry));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      // boki3-c-0001 の答えは index 2。
      await tester.tap(find
          .descendant(of: find.byType(HandsFreeChoiceQuestion), matching: find.byType(InkWell))
          .at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('答え合わせ'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.byType(PracticePage), findsNothing);
      final saved = (await tester.runAsync(noteStore.read))!;
      expect(saved.single.qid, 'boki3-c-0001');
      expect(saved.single.correctStreak, 1);
      expect(saved.single.overcome, isFalse);
    });

    testWidgets('設定のタイルから間違いノートが開ける', (tester) async {
      await _pump(tester, MistakeNoteTile(progressStore: await _store(const [])));
      await tester.tap(find.text('間違いノート'));
      await tester.pumpAndSettle();
      expect(find.byType(MistakeNotePage), findsOneWidget);
    });
  });

  group('間違いノート: バックアップ・リセット', () {
    testWidgets('データの管理に mistakeNotes が登録され、書き出し・リセット・読み込みができる', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late WidgetRef wref;
      await tester.pumpWidget(ProviderScope(
        child: Consumer(builder: (context, ref, _) {
          wref = ref;
          return const SizedBox.shrink();
        }),
      ));
      final noteStore = InMemoryMistakeNoteStore();
      final parts = bokiDataParts(
        progressStore: InMemoryProgressStore(),
        companyModeHistoryStore: InMemoryCompanyModeHistoryStore(),
        learnedTermsStore: LearnedTermsStore('boki3'),
        mistakeNotes: noteStore,
      );
      final part = parts.firstWhere((p) => p.id == 'mistakeNotes');
      final entry = MistakeNoteEntry(
        qid: 'boki3-c-0001',
        firstMissedAt: DateTime(2026, 10, 14),
        lastMissedAt: DateTime(2026, 10, 14),
        missCount: 1,
        overcome: false,
        topicId: 'classification_asset',
        correctStreak: 0,
        lastAnsweredAt: DateTime(2026, 10, 14),
      );
      await tester.runAsync(() async {
        await noteStore.write([entry]);
        final exported = await part.export(wref);
        expect(exported, isA<List>());
        expect((exported as List), hasLength(1));

        await part.reset(wref);
        expect(await noteStore.read(), isEmpty);

        await part.restore(wref, exported);
        final restored = await noteStore.read();
        expect(restored.single.qid, 'boki3-c-0001');
        expect(restored.single.topicId, 'classification_asset');
      });
    });

    test('既定の保存先は端末内のストア', () {
      expect(mistakeNoteStore, isA<SharedPreferencesMistakeNoteStore>());
    });
  });
}
