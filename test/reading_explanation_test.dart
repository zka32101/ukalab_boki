import 'dart:convert';
import 'dart:io';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/exam_data/feature_flags.dart';
import 'package:ukalab_boki3/hands_free/hands_free_choice_question.dart';
import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_boki3/reading/reading_list_page.dart';
import 'package:ukalab_core/answer_feedback.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'test_support.dart';

const _readingsPath = 'assets/exam/boki3.readings.jsonl';
const _readingId = 'reading-boki3-fixed-asset-retirement';
const _newLevel = 'level3_from_2027_04';

/// 旧範囲（〜2027-03）と新範囲（2027-04〜）の代表日。
final _oldDate = DateTime(2026, 10, 30);
final _newDate = DateTime(2027, 4, 1);

/// 表・手順を使う読み物（固定資産の除却・廃棄、新範囲限定）のデータ検証と画面テスト。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('読み物データ', () {
    late ExamConfig exam;
    late List<Term> terms;
    late List<Question> questions;
    late List<ChapterReading> all;
    late ChapterReading reading;

    setUpAll(() {
      exam = ExamConfig.fromJson(
        jsonDecode(File('assets/exam/boki3.exam.json').readAsStringSync()) as Map<String, dynamic>,
      );
      final t = parseTermsJsonl(File('assets/exam/boki3.terms.jsonl').readAsStringSync());
      expect(t.issues, isEmpty, reason: '${t.issues}');
      terms = t.terms;
      final q = parseQuestionsJsonl(File('assets/exam/boki3.questions.jsonl').readAsStringSync());
      expect(q.issues, isEmpty, reason: '${q.issues}');
      questions = q.questions;
      final p = parseChapterReadingsJsonl(File(_readingsPath).readAsStringSync());
      expect(p.issues, isEmpty, reason: '${p.issues}');
      all = p.items;
      reading = all.singleWhere((r) => r.readingId == _readingId);
    });

    test('全読み物が validateChapterReadings を通り、readingId が重複しない', () {
      final issues = validateChapterReadings(
        all,
        exam: exam,
        termIds: [for (final t in terms) t.termId],
        questionIds: [for (final q in questions) q.qid],
      );
      expect(issues, isEmpty, reason: '$issues');
      final ids = [for (final r in all) r.readingId];
      expect(ids.toSet().length, ids.length);
    });

    test('除却・廃棄の読み物は新範囲限定で、表と手順を使い、出典は体験コンテンツの表記', () {
      expect(reading.levelId, _newLevel);
      final kinds = reading.sections.map((s) => s.kind).toSet();
      expect(kinds, containsAll(['text', 'table', 'steps']));
      expect(reading.sections.where((s) => s.kind == 'table').length, greaterThanOrEqualTo(2));
      expect(reading.source, QuestionSource.original);
      expect(reading.sourceRef, '自作(AI下書き由来。体験コンテンツのため専門家確認は不要と判断)');
      expect(reading.sourceRef, isNot(contains('専門家確認済み')));
      expect(reading.contentVer, '1');
      expect(reading.relatedTermIds, isNotEmpty);
    });

    test('関連問題は実在し、すべて新範囲の問題', () {
      final byQid = {for (final q in questions) q.qid: q};
      expect(reading.relatedQuestionIds, isNotEmpty);
      for (final id in reading.relatedQuestionIds) {
        expect(byQid[id], isNotNull, reason: '$id が存在しない');
        expect(byQid[id]!.levelId, _newLevel, reason: id);
      }
    });

    test('表は3列以下（スマホ幅で横スクロールしない）', () {
      for (final s in reading.sections.where((s) => s.kind == 'table')) {
        expect(s.table!.columns.length, lessThanOrEqualTo(3), reason: s.heading);
      }
    });

    test('他の読み物は levelId なし（全範囲向け）のまま、禁止表現を含まない', () {
      for (final r in all.where((r) => r.readingId != _readingId)) {
        expect(r.levelId, isNull, reason: r.readingId);
      }
      final text = File(_readingsPath).readAsStringSync();
      for (final w in ['合格保証', '公式', '絶対', '本試験相当', '過去問']) {
        // 既存の読み物の出典に含まれる語は対象外。追加した読み物の行だけを見る。
        final line = text.split('\n').firstWhere((l) => l.contains('"$_readingId"'));
        expect(line.contains(w), isFalse, reason: w);
      }
    });

    test('現在の出題範囲で絞ると、旧範囲では出ず新範囲では出る', () {
      expect(readingsForLevel(all, 'level3_until_2027_03').map((r) => r.readingId), isNot(contains(_readingId)));
      expect(readingsForLevel(all, _newLevel).map((r) => r.readingId), contains(_readingId));
      expect(readingsForLevel(all, 'level3_until_2027_03'), hasLength(all.length - 1));
      expect(readingsForLevel(all, _newLevel), hasLength(all.length));
    });
  });

  test('フラグの既定は true', () {
    expect(kReadingExplanationEnabled, isTrue);
  });

  test('loadChapterReadingsForCurrentLevel は日付で出し分ける', () async {
    final old = await loadChapterReadingsForCurrentLevel(now: _oldDate);
    final next = await loadChapterReadingsForCurrentLevel(now: _newDate);
    final before = await loadChapterReadingsForCurrentLevel(now: DateTime(2027, 3, 31));
    expect(old.map((r) => r.readingId), isNot(contains(_readingId)));
    expect(before.map((r) => r.readingId), isNot(contains(_readingId)));
    expect(next.map((r) => r.readingId), contains(_readingId));
    expect(next.length, old.length + 1);
  });

  group('画面', () {
    Future<void> prepare(WidgetTester tester, {double width = 1200}) async {
      tester.view.physicalSize = Size(width, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await loadQuestions();
        await loadTerms();
        await loadChapterReadings();
        await loadExamConfig();
      });
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Widget app(Widget home) => ProviderScope(
          overrides: [
            entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
            ...studyNotesTestOverrides(),
          ],
          child: MaterialApp(home: home),
        );

    // core v0.87.0 は4文字以上の数字語に U+2060 を入れるため、除いて比較する。
    Finder textEq(String s) => find.byWidgetPredicate(
          (w) => w is Text && w.data?.replaceAll('⁠', '') == s,
        );

    Future<ChapterReading> loadTarget(WidgetTester tester) async {
      final all = (await tester.runAsync(loadChapterReadings))!;
      return all.singleWhere((r) => r.readingId == _readingId);
    }

    const title = '14 固定資産の除却・廃棄';

    testWidgets('一覧: 旧範囲の日付では除却・廃棄の読み物は出ず、既存の読み物は出る', (tester) async {
      await prepare(tester);
      await tester.pumpWidget(app(ReadingListPage(progressStore: InMemoryProgressStore(), now: _oldDate)));
      await settle(tester);
      expect(find.text(title), findsNothing);
      expect(find.text('1 仕訳の基本（取引・借方と貸方）'), findsOneWidget);
      expect(find.text('13 精算表と財務諸表'), findsOneWidget);
    });

    testWidgets('一覧: 新範囲の日付では除却・廃棄の読み物も出て、開ける', (tester) async {
      await prepare(tester);
      await tester.pumpWidget(app(ReadingListPage(progressStore: InMemoryProgressStore(), now: _newDate)));
      await settle(tester);
      expect(find.text('1 仕訳の基本（取引・借方と貸方）'), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text(title));
      await settle(tester);
      expect(find.byType(ReadingDetailPage), findsOneWidget);
      expect(find.byType(ReadingSectionContent), findsWidgets);
    });

    testWidgets('詳細: 表・手順・解説カード・関連問題リンクが出る', (tester) async {
      await prepare(tester);
      final reading = await loadTarget(tester);
      await tester.pumpWidget(app(
        ReadingDetailPage(reading: reading, progressStore: InMemoryProgressStore()),
      ));
      await settle(tester);

      expect(find.byType(ReadingSectionContent), findsNWidgets(reading.sections.length));
      expect(find.byType(Table), findsAtLeastNWidgets(2));
      expect(textEq('減価償却累計額'), findsWidgets);
      expect(textEq('帳簿価額を求める（取得原価－減価償却累計額）。'), findsOneWidget);
      expect(find.byType(ExplanationCard), findsOneWidget);
      expect(find.text('例題の解説'), findsOneWidget);
      expect(find.byType(ReadingQuestionLinks), findsOneWidget);
      expect(find.text(AnswerFeedbackStrings.ja.readingBackToQuestion), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(ReadingQuestionLinks), matching: find.byType(OutlinedButton)).first);
      await settle(tester);
      expect(find.byType(PracticePage), findsOneWidget);
    });

    testWidgets('詳細: 画面幅390でも表があふれず、横スクロールの表にならない', (tester) async {
      await prepare(tester, width: 390);
      final reading = await loadTarget(tester);
      await tester.pumpWidget(app(
        ReadingDetailPage(reading: reading, progressStore: InMemoryProgressStore()),
      ));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(Table), findsAtLeastNWidgets(2));
      expect(
        find.descendant(of: find.byType(ReadingSectionContent), matching: find.byType(SingleChildScrollView)),
        findsNothing,
      );
    });

    testWidgets('詳細: 本文だけの既存の読み物は従来の表示のまま', (tester) async {
      await prepare(tester);
      final all = (await tester.runAsync(loadChapterReadings))!;
      final plain = all.firstWhere((r) => r.readingId != _readingId);
      await tester.pumpWidget(app(
        ReadingDetailPage(reading: plain, progressStore: InMemoryProgressStore()),
      ));
      await settle(tester);
      expect(find.byType(ChapterReadingWidget), findsOneWidget);
      expect(find.byType(ReadingSectionContent), findsNothing);
    });

    testWidgets('詳細: フラグ off なら表の読み物も従来の表示', (tester) async {
      await prepare(tester);
      final reading = await loadTarget(tester);
      await tester.pumpWidget(app(
        ReadingDetailPage(reading: reading, progressStore: InMemoryProgressStore(), richEnabled: false),
      ));
      await settle(tester);
      expect(find.byType(ChapterReadingWidget), findsOneWidget);
      expect(find.byType(ReadingSectionContent), findsNothing);
    });

    Future<void> answerWrong(WidgetTester tester) async {
      final tiles = find.descendant(of: find.byType(HandsFreeChoiceQuestion), matching: find.byType(InkWell));
      for (var i = 0; i < 40 && tiles.evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(tiles.first); // boki3-c-0057 の正解は index 1
      await tester.pumpAndSettle();
      await tester.tap(find.text('答え合わせ'));
      await tester.pumpAndSettle();
      expect(find.text('不正解です'), findsOneWidget);
    }

    testWidgets('誤答導線: 新範囲の日付では関連読み物へ誘導し、タップで読み物を開く', (tester) async {
      await prepare(tester);
      await tester.pumpWidget(app(
        PracticePage(
          progressStore: InMemoryProgressStore(),
          restrictToQids: const {'boki3-c-0057'},
          now: _newDate,
        ),
      ));
      await answerWrong(tester);

      expect(find.text(AnswerFeedbackStrings.ja.relatedReadingsTitle), findsOneWidget);
      // 原因選択欄（AnswerFeedbackPanel）も従来どおり出る。
      expect(find.byType(AnswerFeedbackPanel), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, title));
      await settle(tester);
      expect(find.byType(ReadingDetailPage), findsOneWidget);
      expect(find.byType(ReadingSectionContent), findsWidgets);
    });

    testWidgets('誤答導線: 旧範囲の日付では読み物への誘導は出ない', (tester) async {
      await prepare(tester);
      await tester.pumpWidget(app(
        PracticePage(
          progressStore: InMemoryProgressStore(),
          restrictToQids: const {'boki3-c-0057'},
          now: _oldDate,
        ),
      ));
      await answerWrong(tester);

      expect(find.byType(AnswerFeedbackPanel), findsOneWidget);
      expect(find.text(AnswerFeedbackStrings.ja.relatedReadingsTitle), findsNothing);
    });

    testWidgets('誤答導線: フラグ off なら新範囲でも誘導は出ない', (tester) async {
      await prepare(tester);
      await tester.pumpWidget(app(
        PracticePage(
          progressStore: InMemoryProgressStore(),
          restrictToQids: const {'boki3-c-0057'},
          now: _newDate,
          readingEnabled: false,
        ),
      ));
      await answerWrong(tester);

      expect(find.text(AnswerFeedbackStrings.ja.relatedReadingsTitle), findsNothing);
    });
  });
}
