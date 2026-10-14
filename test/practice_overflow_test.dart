import 'package:app_common_kit/app_common_kit.dart' show ChoiceTile, FakeSpeechBackend, HandsFreeChoiceTile, HandsFreeSettings;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart' show Question, QuestionType;

import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/hands_free/hands_free_state.dart';
import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'overflow_support.dart';
import 'test_support.dart';

/// 全問題（仕訳・伝票・証憑・選択式・帳簿・精算表）の演習画面が、狭い幅・大きい文字・小さい高さで
/// RenderFlex overflow しないことを、解答前と答え合わせ後の両方で確認する。
void main() {
  late List<Question> questions;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    questions = await loadQuestions();
  });

  Future<void> pumpQuestion(WidgetTester tester, Question q) async {
    await tester.pumpWidget(ProviderScope(
      overrides: studyNotesTestOverrides(),
      child: MaterialApp(
        home: PracticePage(
          key: ValueKey(q.qid),
          progressStore: InMemoryProgressStore(),
          restrictToQids: {q.qid},
        ),
      ),
    ));
    for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump();
  }

  for (final type in QuestionType.values) {
    for (final c in overflowCases) {
      testWidgets('演習画面 ${type.name}: $c', (tester) async {
        SharedPreferences.setMockInitialValues({});
        applyScreen(tester, c);
        final problems = ProblemTally();
        final errors = ErrorCollector();
        addTearDown(errors.dispose);
        for (final q in questions.where((q) => q.type == type)) {
          await pumpQuestion(tester, q);
          var err = errors.drain();
          if (err.isNotEmpty) problems.add('${q.qid}(解答前)', err);

          // 答え合わせ（選択式は1つ目を選んでから）。
          if (type == QuestionType.choice && find.byType(ChoiceTile).evaluate().isNotEmpty) {
            await tester.tap(find.byType(ChoiceTile).first, warnIfMissed: false);
            await tester.pump();
          }
          final check = find.text('答え合わせ');
          if (check.evaluate().isNotEmpty) {
            await tester.tap(check.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            err = errors.drain();
            if (err.isNotEmpty) problems.add('${q.qid}(答え合わせ後)', err);
          }
        }
        errors.dispose();
        problems.report('${type.name} $c');
        expect(problems, isEmpty, reason: problems.toString());
      });
    }
  }

  // ながら学習モード（選択式を大きなボタンで出す）。
  for (final c in overflowCases) {
    testWidgets('ながら学習モードの選択式: $c', (tester) async {
      SharedPreferences.setMockInitialValues({});
      applyScreen(tester, c);
      appSpeechBackendForTest = FakeSpeechBackend();
      appHandsFree.value = const HandsFreeSettings(enabled: true);
      addTearDown(() {
        appSpeechBackendForTest = null;
        appHandsFree.value = const HandsFreeSettings();
      });
      final problems = ProblemTally();
      final errors = ErrorCollector();
      addTearDown(errors.dispose);
      for (final q in questions.where((q) => q.type == QuestionType.choice)) {
        await pumpQuestion(tester, q);
        var err = errors.drain();
        if (err.isNotEmpty) problems.add('${q.qid}(解答前)', err);
        if (find.byType(HandsFreeChoiceTile).evaluate().isNotEmpty) {
          await tester.tap(find.byType(HandsFreeChoiceTile).first, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          err = errors.drain();
          if (err.isNotEmpty) problems.add('${q.qid}(解答後)', err);
        }
      }
      errors.dispose();
      problems.report('ながら学習 $c');
      expect(problems.isEmpty, isTrue, reason: problems.toString());
    });
  }

  // 勘定科目ピッカー（ボトムシート）とメモ欄のシート。
  for (final c in overflowCases) {
    testWidgets('科目ピッカーとメモのシート: $c', (tester) async {
      SharedPreferences.setMockInitialValues({});
      applyScreen(tester, c);
      final q = questions.firstWhere((q) => q.type == QuestionType.journal && q.topicId == 'sales_credit');
      final problems = ProblemTally();
      final errors = ErrorCollector();
      addTearDown(errors.dispose);
      await pumpQuestion(tester, q);
      problems.add('開いた直後', errors.drain());

      await tester.tap(find.byTooltip('メモ'));
      await tester.pump(const Duration(milliseconds: 400));
      problems.add('メモのシート', errors.drain());
      await tester.tapAt(const Offset(2, 2)); // 外側をタップして閉じる
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(InkWell).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      problems.add('科目ピッカー', errors.drain());
      errors.dispose();
      problems.report('ピッカー・メモ $c');
      expect(problems.isEmpty, isTrue, reason: problems.toString());
    });
  }
}
