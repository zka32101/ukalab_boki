import 'package:app_common_kit/app_common_kit.dart' show FakeEntitlementService, entitlementServiceProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart' show UkalabCert, UkalabField, UkalabTheme;
import 'package:ukalab_core/ukalab_core.dart';

import 'package:ukalab_boki3/company_mode/company_mode_history_store.dart';
import 'package:ukalab_boki3/company_mode/company_scenario_list_page.dart';
import 'package:ukalab_boki3/company_mode/company_scenario_play_page.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/exam_prep/exam_prep_entry.dart';
import 'package:ukalab_boki3/main.dart';
import 'package:ukalab_boki3/mistake_note/mistake_note_page.dart';
import 'package:ukalab_boki3/mock_exam/mock_exam_review_page.dart';
import 'package:ukalab_boki3/reading/reading_list_page.dart';
import 'package:ukalab_boki3/settings/settings_page.dart';
import 'package:ukalab_boki3/term/term_list_page.dart';
import 'overflow_support.dart';
import 'test_support.dart';

/// 主要画面（ホーム・学ぶ・記録・設定・各ページ・ダイアログ）が、狭い幅・大きい文字で
/// RenderFlex overflow しないことを確認する。
///
/// スクロールする一覧は縦に十分高い画面で全項目を組み立て、横方向のはみ出しを見る。
/// 縦に固定の画面（問題画面など）は `practice_overflow_test.dart` 側で小さい高さで見る。
void main() {
  // テスト本体（FakeAsync の中）で `await loadXxx()` すると、続きの pumpWidget が進まなくなることがあるため、
  // 問題データなどは先に実時間で読んでおき、本体では変数を使う。
  late List<Question> allQuestions;
  late List<CompanyScenario> allScenarios;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    allQuestions = await loadQuestions();
    allScenarios = await loadCompanyScenarios();
    await loadExamConfig();
    await loadTerms();
    await loadChapterReadings();
  });

  ThemeData theme() => UkalabTheme.light(field: UkalabField.biz, cert: UkalabCert.boki3);

  /// 一覧系の画面用（縦は十分に高くして、全項目を組み立てる）。
  ScreenCase tall(ScreenCase c) => ScreenCase(c.width, 6000, c.scale);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> seedWrongAnswers() async {
    final now = DateTime.now();
    for (final q in allQuestions.take(40)) {
      await appProgressStore.addRecord(
        ProgressRecord(qid: q.qid, subjectId: q.subjectId, correct: false, at: now),
      );
    }
  }

  Widget app(Widget home) => ProviderScope(
        overrides: [
          entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
          ...studyNotesTestOverrides(),
        ],
        child: MaterialApp(theme: theme(), home: home),
      );

  // 実機と同じく、アプリ全体（下部タブ）を組んで各タブを開く。
  for (final base in overflowCases) {
    final c = tall(base);
    for (final tab in const ['ホーム', '学ぶ', '模擬', '記録', '設定']) {
      testWidgets('タブ「$tab」: $base', (tester) async {
        SharedPreferences.setMockInitialValues({});
        applyScreen(tester, c);
        await tester.runAsync(seedWrongAnswers);
        final errors = ErrorCollector();
        addTearDown(errors.dispose);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
            ...studyNotesTestOverrides(),
          ],
          child: const UkalabBoki3App(),
        ));
        await settle(tester);
        if (tab != 'ホーム') {
          await tester.tap(find.text(tab).last);
          await settle(tester);
        }
        final tally = ProblemTally()..add(tab, errors.drain());
        errors.dispose();
        tally.report('タブ$tab $base');
        expect(tally.isEmpty, isTrue, reason: tally.toString());
      });
    }
  }

  // 単体で開く画面。
  final pages = <String, Widget Function()>{
    '用語集': () => const TermListPage(),
    '用語集(科目絞り込み)': () => const TermListPage(initialSubjectId: 'q3_kessan', initialSubjectLabel: '第3問 決算'),
    '解説読み物一覧': () => ReadingListPage(progressStore: InMemoryProgressStore()),
    '会社を経営する一覧': () => CompanyScenarioListPage(historyStore: InMemoryCompanyModeHistoryStore()),
    '間違いノート': () => MistakeNotePage(progressStore: appProgressStore),
    '試験日': () => const ExamDateSettingsPage(),
    '設定(既定のデータ欄)': () => Scaffold(body: SettingsPage(progressStore: InMemoryProgressStore())),
  };
  for (final base in overflowCases) {
    final c = tall(base);
    for (final e in pages.entries) {
      testWidgets('${e.key}: $base', (tester) async {
        SharedPreferences.setMockInitialValues({});
        applyScreen(tester, c);
        await tester.runAsync(seedWrongAnswers);
        final errors = ErrorCollector();
        addTearDown(errors.dispose);
        await tester.pumpWidget(app(e.value()));
        await settle(tester);
        final tally = ProblemTally()..add(e.key, errors.drain());
        errors.dispose();
        tally.report('${e.key} $base');
        expect(tally.isEmpty, isTrue, reason: tally.toString());
      });
    }

    testWidgets('解説読み物の各ページ: $base', (tester) async {
      SharedPreferences.setMockInitialValues({});
      applyScreen(tester, c);
      final errors = ErrorCollector();
      addTearDown(errors.dispose);
      final tally = ProblemTally();
      await tester.pumpWidget(app(ReadingListPage(progressStore: InMemoryProgressStore())));
      await settle(tester);
      final count = find.byType(ListTile).evaluate().length;
      expect(count, greaterThan(0));
      for (var i = 0; i < count; i++) {
        await tester.tap(find.byType(ListTile).at(i));
        await settle(tester);
        tally.add('読み物${i + 1}', errors.drain());
        await tester.pageBack();
        await settle(tester);
      }
      errors.dispose();
      tally.report('解説読み物 $base');
      expect(tally.isEmpty, isTrue, reason: tally.toString());
    });

    testWidgets('模擬試験の解答結果の詳細: $base', (tester) async {
      SharedPreferences.setMockInitialValues({});
      applyScreen(tester, c);
      final errors = ErrorCollector();
      addTearDown(errors.dispose);
      // 模擬試験と同じく20問ほどを、4形式が混ざるように等間隔で選ぶ。
      final all = allQuestions;
      final qs = [for (var i = 0; i < all.length; i += (all.length / 20).ceil()) all[i]];
      await tester.pumpWidget(app(MockExamReviewPage(questions: qs, answers: const {})));
      await settle(tester);
      final tally = ProblemTally()..add('review', errors.drain());
      errors.dispose();
      tally.report('模擬試験の詳細 $base');
      expect(tally.isEmpty, isTrue, reason: tally.toString());
    });
  }

  // 会社経営モード: 導入 → 各ターン → 結果（間違えたターンの振り返りつき）。
  for (final c in const [
    ScreenCase(320, 640, 1),
    ScreenCase(320, 640, 2),
    ScreenCase(280, 600, 3),
  ]) {
    testWidgets('会社を経営する(全シナリオ): $c', (tester) async {
      SharedPreferences.setMockInitialValues({});
      applyScreen(tester, c);
      final errors = ErrorCollector();
      addTearDown(errors.dispose);
      final tally = ProblemTally();
      // 導入 → 全ターン（答え合わせ前後）→ 経営成績まで進める。読み込みが済んだ後は実時間の待ちは要らない。
      Future<void> step() async {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      }

      for (final s in allScenarios) {
        try {
          await tester.pumpWidget(app(CompanyScenarioPlayPage(
            key: ValueKey(s.scenarioId),
            scenario: s,
            historyStore: InMemoryCompanyModeHistoryStore(),
          )));
          await step();
          tally.add('${s.scenarioId} 導入', errors.drain());
          // 文字が大きいと開始ボタンが画面の下に出るので、スクロールしてから押す。
          await tester.ensureVisible(find.text('経営を始める'));
          await tester.pump();
          await tester.tap(find.text('経営を始める'));
          await step();
          for (var i = 0; i < s.turns.length; i++) {
            tally.add('${s.scenarioId} ${i + 1}ターン目', errors.drain());
            await tester.tap(find.text('答え合わせ'), warnIfMissed: false);
            await step();
            tally.add('${s.scenarioId} ${i + 1}ターン目(答え合わせ後)', errors.drain());
            await tester.tap(find.text('次の問題へ'), warnIfMissed: false);
            await step();
          }
          tally.add('${s.scenarioId} 結果', errors.drain());
        } catch (e) {
          tally.add(s.scenarioId, 'テストの進行中に例外: ${e.toString().split('\n').first}');
        }
      }
      errors.dispose();
      tally.report('会社経営 $c');
      expect(tally.isEmpty, isTrue, reason: tally.toString());
    });
  }

  // ダイアログ・ボトムシート。
  for (final c in overflowCases) {
    testWidgets('解答記録のリセット確認ダイアログ: $c', (tester) async {
      SharedPreferences.setMockInitialValues({});
      applyScreen(tester, c);
      final errors = ErrorCollector();
      addTearDown(errors.dispose);
      await tester.pumpWidget(app(Scaffold(body: SettingsPage(progressStore: InMemoryProgressStore()))));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('解答記録をリセットする'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('解答記録をリセットする'));
      await settle(tester);
      expect(find.text('リセットする'), findsOneWidget);
      final tally = ProblemTally()..add('dialog', errors.drain());
      errors.dispose();
      tally.report('リセット確認 $c');
      expect(tally.isEmpty, isTrue, reason: tally.toString());
    });
  }
}
