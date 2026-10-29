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

const _protoPath = 'assets/exam/boki3.readings_proto.jsonl';

/// 【試作】表・手順を使う読み物（固定資産の除却・廃棄）のデータ検証と画面テスト。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('試作の読み物データ', () {
    late ExamConfig exam;
    late List<Term> terms;
    late List<Question> questions;
    late List<ChapterReading> proto;

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
      final p = parseChapterReadingsJsonl(File(_protoPath).readAsStringSync());
      expect(p.issues, isEmpty, reason: '${p.issues}');
      proto = p.items;
    });

    test('validateChapterReadings を通る', () {
      expect(proto, hasLength(1));
      final issues = validateChapterReadings(
        proto,
        exam: exam,
        termIds: [for (final t in terms) t.termId],
        questionIds: [for (final q in questions) q.qid],
      );
      expect(issues, isEmpty, reason: '$issues');
    });

    test('表と手順の節を使い、関連問題は新範囲の問題だけで、出典は試作の表記', () {
      final r = proto.single;
      final kinds = r.sections.map((s) => s.kind).toSet();
      expect(kinds, containsAll(['text', 'table', 'steps']));
      expect(r.sections.where((s) => s.kind == 'table').length, greaterThanOrEqualTo(2));
      expect(r.sourceRef, '自作(AI下書き由来。試作・専門家確認は未実施)');
      expect(r.source, QuestionSource.original);
      final byQid = {for (final q in questions) q.qid: q};
      expect(r.relatedQuestionIds, isNotEmpty);
      for (final id in r.relatedQuestionIds) {
        expect(byQid[id]?.levelId, 'level3_from_2027_04', reason: id);
      }
      expect(r.relatedTermIds, isNotEmpty);
    });

    test('既存の読み物と readingId が重複せず、禁止表現を含まない', () {
      final main = parseChapterReadingsJsonl(File('assets/exam/boki3.readings.jsonl').readAsStringSync());
      final ids = {for (final r in main.items) r.readingId};
      expect(ids, isNot(contains(proto.single.readingId)));
      final text = File(_protoPath).readAsStringSync();
      for (final w in ['合格保証', '公式', '絶対', '本試験相当', '過去問']) {
        expect(text.contains(w), isFalse, reason: w);
      }
    });
  });

  test('試作フラグの既定は false で、既存の読み物の読み込みに試作の読み物が混ざらない', () async {
    expect(kReadingExplanationProtoEnabled, isFalse);
    final readings = await loadChapterReadings();
    final proto = await loadProtoReadings();
    expect(readings.map((r) => r.readingId), isNot(contains(proto.single.readingId)));
  });

  group('画面', () {
    Future<void> prepare(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await loadQuestions();
        await loadTerms();
        await loadProtoReadings();
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

    testWidgets('試作オン: 読み物に表・手順・解説カード・関連問題リンクが出る', (tester) async {
      await prepare(tester);
      final reading = (await tester.runAsync(loadProtoReadings))!.single;
      await tester.pumpWidget(app(
        ReadingDetailPage(reading: reading, progressStore: InMemoryProgressStore(), protoEnabled: true),
      ));
      await settle(tester);

      expect(find.byType(ReadingSectionContent), findsNWidgets(reading.sections.length));
      expect(find.byType(Table), findsAtLeastNWidgets(2));
      expect(find.text('減価償却累計額'), findsWidgets);
      expect(find.text('帳簿価額を求める（取得原価－減価償却累計額）。'), findsOneWidget);
      expect(find.byType(ExplanationCard), findsOneWidget);
      expect(find.text('例題の解説'), findsOneWidget);
      expect(find.byType(ReadingQuestionLinks), findsOneWidget);
      expect(find.text(AnswerFeedbackStrings.ja.readingBackToQuestion), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(ReadingQuestionLinks), matching: find.byType(OutlinedButton)).first);
      await settle(tester);
      expect(find.byType(PracticePage), findsOneWidget);
    });

    testWidgets('試作オフ（既定）: 従来の読み物表示のまま', (tester) async {
      await prepare(tester);
      final reading = (await tester.runAsync(loadProtoReadings))!.single;
      await tester.pumpWidget(app(
        ReadingDetailPage(reading: reading, progressStore: InMemoryProgressStore()),
      ));
      await settle(tester);

      expect(find.byType(ChapterReadingWidget), findsOneWidget);
      expect(find.byType(ReadingSectionContent), findsNothing);
      expect(find.byType(ReadingQuestionLinks), findsNothing);
      expect(find.byType(ExplanationCard), findsNothing);
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

    testWidgets('試作オン: 誤答すると関連読み物へ誘導し、タップで読み物を開く', (tester) async {
      await prepare(tester);
      final readings = (await tester.runAsync(loadProtoReadings))!;
      await tester.pumpWidget(app(
        PracticePage(
          progressStore: InMemoryProgressStore(),
          restrictToQids: const {'boki3-c-0057'},
          readingProtoEnabled: true,
          readingsOverride: readings,
        ),
      ));
      await answerWrong(tester);

      expect(find.text(AnswerFeedbackStrings.ja.relatedReadingsTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, readings.single.title));
      await settle(tester);
      expect(find.byType(ReadingDetailPage), findsOneWidget);
      expect(find.byType(ReadingSectionContent), findsWidgets);
    });

    testWidgets('試作オフ（既定）: 誤答しても読み物への誘導は出ない', (tester) async {
      await prepare(tester);
      final readings = (await tester.runAsync(loadProtoReadings))!;
      await tester.pumpWidget(app(
        PracticePage(
          progressStore: InMemoryProgressStore(),
          restrictToQids: const {'boki3-c-0057'},
          readingsOverride: readings,
        ),
      ));
      await answerWrong(tester);

      expect(find.byType(AnswerFeedbackPanel), findsOneWidget);
      expect(find.text(AnswerFeedbackStrings.ja.relatedReadingsTitle), findsNothing);
    });
  });
}
