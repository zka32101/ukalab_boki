import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/daily_goal.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'company_mode/company_mode_history_store.dart';
import 'exam_data/exam_data_cache.dart';
import 'hands_free/hands_free_state.dart';
import 'company_mode/company_scenario_list_page.dart';
import 'mock_exam/mock_exam_page.dart';
import 'oshi/boki3_oshi_card.dart';
import 'practice/practice_page.dart';
import 'progress/progress_store.dart';
import 'purchase/weak_drill_card.dart';
import 'progress/progress_summary_card.dart';
import 'records/records_page.dart';
import 'settings/boki_data_parts.dart';
import 'settings/settings_page.dart';
import 'startup/legacy_key_migration.dart';
import 'term/learned_terms_store.dart';
import 'term/term_list_page.dart';

/// 演習・模擬試験の解答記録の保存先。端末内保存（アプリ全体で共有）。
final ProgressStore appProgressStore = SharedPreferencesProgressStore();

/// 会社経営モードのプレイ結果の保存先。端末内保存（アプリ全体で共有）。
final CompanyModeHistoryStore appCompanyModeHistoryStore = SharedPreferencesCompanyModeHistoryStore();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await migrateLegacyProgressKeys();
  await loadSavedThemeMode();
  await loadHandsFree();

  // 課金（RevenueCat）。実際のAPIキー取得後にRevenueCatEntitlementServiceへ差し替える。
  // 価格は競合調査を踏まえた暫定値で、運営者確認が必要（決定14）。
  final entitlementService = FakeEntitlementService(
    availableOffers: const [
      EntitlementOffer(
        id: 'noads',
        productId: 'boki3_noads',
        title: '広告非表示',
        priceString: '¥480',
      ),
      EntitlementOffer(
        id: 'premium',
        productId: 'boki3_premium',
        title: 'プレミアム（広告非表示＋追加機能）',
        priceString: '¥1,500',
      ),
    ],
    grantOnPurchase: const {
      'boki3_noads': EntitlementState(hasNoAds: true),
      'boki3_premium': EntitlementState(hasPremium: true),
    },
  );

  final studyNotes = await studyNotesOverrides('boki3');
  final dailyGoal = await dailyGoalOverrides('boki3');

  runApp(
    ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(entitlementService),
        ...studyNotes,
        ...dailyGoal,
      ],
      child: const UkalabBoki3App(),
    ),
  );
}

class UkalabBoki3App extends StatelessWidget {
  const UkalabBoki3App({super.key});

  static const _field = UkalabField.biz;
  static const _cert = UkalabCert.boki3;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'うかラボ 簿記3級',
        theme: UkalabTheme.light(field: _field, cert: _cert),
        darkTheme: UkalabTheme.dark(field: _field, cert: _cert),
        themeMode: mode,
        home: UkalabShell(
          pages: [
            const _HomePage(),
            const _LearnPage(),
            const _MockExamTab(),
            RecordsPage(
              progressStore: appProgressStore,
              companyModeHistoryStore: appCompanyModeHistoryStore,
            ),
            SettingsPage(
              progressStore: appProgressStore,
              purchaseSection: Builder(
                builder: (c) => PurchaseSection(titleStyle: Theme.of(c).textTheme.titleLarge),
              ),
              dataSection: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DailyGoalSetting(),
                  const SizedBox(height: 32),
                  DataManagementSection(
                    parts: bokiDataParts(
                      progressStore: appProgressStore,
                      companyModeHistoryStore: appCompanyModeHistoryStore,
                      learnedTermsStore: LearnedTermsStore(),
                    ),
                    description: '解答記録・会社経営モードの履歴・「覚えた」にした用語・デイリーミッション・自分用メモは、'
                        'テーマや購入を除いて、書き出し・読み込み・リセットができます。端末内にのみ保存されています。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 24),
        Center(
          child: Text('うかラボ 簿記3級', style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        Boki3OshiCard(store: appProgressStore),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: DailyMissionCard()),
        ProgressSummaryCard(store: appProgressStore),
      ],
    );
  }
}

/// 「学ぶ」タブ。科目別の練習（第1〜3問）と、全問をまとめて解く問題集への入口。
class _LearnPage extends StatelessWidget {
  const _LearnPage();

  /// `assets/exam/boki3.exam.json` の `subjects` と対応する
  /// （subjectId, 表示名）。3つで固定のため、ここでは読み込まずハードコードする。
  static const _subjects = [
    ('q1_shiwake', '第1問 仕訳'),
    ('q2_choubo', '第2問 帳簿・伝票等'),
    ('q3_kessan', '第3問 決算'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Center(child: Text('学ぶ', style: theme.textTheme.titleLarge)),
        const SizedBox(height: 24),
        Text('科目別に練習する', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (subjectId, name) in _subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PracticePage(
                      progressStore: appProgressStore,
                      subjectId: subjectId,
                      title: '$nameを練習する',
                    ),
                  ),
                ),
                child: Align(alignment: Alignment.centerLeft, child: Text(name)),
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PracticePage(progressStore: appProgressStore)),
          ),
          child: const Text('すべての問題を練習する（問題集）'),
        ),
        const SizedBox(height: 8),
        WeakDrillCard(progressStore: appProgressStore),
        const SizedBox(height: 24),
        Text('用語を調べる', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermListPage()),
            ),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Align(alignment: Alignment.centerLeft, child: Text('用語集')),
          ),
        ),
        const SizedBox(height: 24),
        Text('ブックマークとメモ', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        const StudyNotesHomeCards(loadQuestions: loadQuestions),
        const SizedBox(height: 24),
        Text('実践する', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CompanyScenarioListPage(historyStore: appCompanyModeHistoryStore),
              ),
            ),
            icon: const Icon(Icons.storefront_outlined),
            label: const Align(alignment: Alignment.centerLeft, child: Text('会社を経営する')),
          ),
        ),
      ],
    );
  }
}

/// 「模擬」タブ。本試験形式（出題数・制限時間・配点）で1回通しで解く
/// 模擬試験モードへの入口。
class _MockExamTab extends StatelessWidget {
  const _MockExamTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MockExamPage(progressStore: appProgressStore)),
        ),
        child: const Text('模擬試験を始める'),
      ),
    );
  }
}
