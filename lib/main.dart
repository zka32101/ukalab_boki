import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/achievements.dart'
    show
        AchievementsView,
        achievementUnlockOverrides,
        dailyGoalAchievementCategoryLabels,
        dailyGoalAchievementsOverride,
        watchAchievementUnlocks;
import 'package:ukalab_core/cross_promo.dart' show UkalabCrossPromo;
import 'package:ukalab_core/daily_goal.dart';
import 'package:ukalab_core/glossary.dart' show LearnedTermsStore;
import 'package:ukalab_core/reminder.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'company_mode/company_mode_history_store.dart';
import 'data/ad_unit_ids.dart';
import 'exam_prep/exam_prep_entry.dart';
import 'hands_free/hands_free_state.dart';
import 'company_mode/company_scenario_list_page.dart';
import 'mistake_note/mistake_note_page.dart';
import 'nagara/nagara_session_page.dart';
import 'mock_exam/mock_exam_page.dart';
import 'oshi/boki3_character_overrides.dart';
import 'oshi/boki3_coin_overrides.dart';
import 'oshi/boki3_oshi_card.dart';
import 'oshi/oshi_growth_section.dart';
import 'oshi/oshi_home_cards.dart';
import 'widgets/cert_prop_badge.dart';
import 'widgets/learn_tools_section.dart';
import 'practice/practice_page.dart';
import 'progress/progress_store.dart';
import 'purchase/purchase_guide_page.dart';
import 'purchase/revenuecat_key.dart';
import 'purchase/weak_drill_card.dart';
import 'purchase/weak_summary_section.dart';
import 'review/today_review_section.dart';
import 'progress/progress_summary_card.dart';
import 'records/records_page.dart';
import 'settings/boki_data_parts.dart';
import 'services/no_ads_backend.dart';
import 'settings/settings_page.dart';
import 'startup/boot_splash.dart';
import 'startup/legacy_key_migration.dart';

/// 演習・模擬試験の解答記録の保存先。端末内保存（アプリ全体で共有）。
final ProgressStore appProgressStore = SharedPreferencesProgressStore();

/// 会社経営モードのプレイ結果の保存先。端末内保存（アプリ全体で共有）。
final CompanyModeHistoryStore appCompanyModeHistoryStore = SharedPreferencesCompanyModeHistoryStore();

/// RevenueCat の公開SDKキー。コミットせず、ビルド時に `--dart-define` で渡す。
/// Android は `RC_GOOGLE_KEY`、iOS は `RC_APPLE_KEY`。未指定・Web・その他は偽の課金サービスで動く。
const _rcGoogleKey = String.fromEnvironment('RC_GOOGLE_KEY');
const _rcAppleKey = String.fromEnvironment('RC_APPLE_KEY');
final String? _rcKey = selectRevenueCatKey(
  isWeb: kIsWeb,
  isAndroid: !kIsWeb && Platform.isAndroid,
  isIOS: !kIsWeb && Platform.isIOS,
  googleKey: _rcGoogleKey,
  appleKey: _rcAppleKey,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初期化中はスプラッシュを出す（初期化完了後に runApp で本体へ差し替える）。
  runApp(const BootSplashApp());
  await migrateLegacyProgressKeys();
  await loadSavedThemeMode();
  // 文字の大きさ（アプリ内設定）を復元する
  await loadSavedTextScale();
  await loadHandsFree();

  // 相互紹介（Firebase 初期化＋掲載リスト取得）。失敗しても起動を止めず、起動もブロックしない。
  unawaited(UkalabCrossPromo.init());

  // 課金（RevenueCat）。Android(RC_GOOGLE_KEY)／iOS(RC_APPLE_KEY) のキー指定時は本物、それ以外は偽（Web・テスト用）。
  // Fake側の価格は競合調査を踏まえた暫定値で、運営者確認が必要（決定14）。
  final EntitlementService entitlementService = _rcKey != null
      ? await RevenueCatEntitlementService.init(publicSdkKey: _rcKey!)
      : FakeEntitlementService(
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

  // 広告。本番ユニットIDはビルド時に --dart-define で渡す（ad_unit_ids.dart）。
  // Web・iOS は広告を出さない。リリースで未指定なら空のIDで、広告なしのまま起動する。
  final adIds = adUnitIdsFor(
    isWeb: kIsWeb,
    isAndroid: !kIsWeb && Platform.isAndroid,
    isRelease: kReleaseMode,
  );
  final adGate = await AdGate.init(
    config: AdConfig(unitIds: adIds),
    // IDが空(Web・iOS、または本番IDが未指定のリリース)なら、広告SDKを使わず、広告なしで起動する。
    backend: adIds.banner.isEmpty && adIds.interstitial.isEmpty ? NoAdsBackend() : null,
    adsHidden: () => entitlementService.state.adsHidden,
    isRelease: kReleaseMode,
  );

  final studyNotes = await studyNotesOverrides('boki3');
  final dailyGoal = await dailyGoalOverrides('boki3');
  final reminder = await reminderOverrides('boki3');
  final achievementUnlock = await achievementUnlockOverrides('boki3');
  final coinOutfit = await coinOutfitOverrides('boki3');

  runApp(
    ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(entitlementService),
        adGateProvider.overrideWithValue(adGate),
        ...studyNotes,
        ...dailyGoal,
        ...reminder,
        ...achievementUnlock,
        ...coinOutfit,
        ...boki3CharacterOverrides(),
        dailyGoalAchievementsOverride,
      ],
      child: const UkalabBoki3App(),
    ),
  );
}

/// 実績の解除通知のスナックバーを、どの画面にいても表示するためのキー。
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class UkalabBoki3App extends ConsumerWidget {
  const UkalabBoki3App({super.key});

  static const _field = UkalabField.biz;
  static const _cert = UkalabCert.boki3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAchievementUnlocks(ref, scaffoldMessengerKey);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'うかラボ 簿記3級',
        scaffoldMessengerKey: scaffoldMessengerKey,
        // 文字の大きさ（設定画面で選ぶ）を端末の文字サイズに掛け合わせる。
        builder: applyAppTextScale,
        navigatorObservers: [homeRouteObserver],
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
              purchaseSection: const PurchaseBlock(),
              dataSection: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExamPrepSettingsSection(progressStore: appProgressStore),
                  const SizedBox(height: 16),
                  MistakeNoteTile(progressStore: appProgressStore, contentPadding: EdgeInsets.zero),
                  const SizedBox(height: 16),
                  const DailyGoalSetting(),
                  const SizedBox(height: 32),
                  const ReminderSettingsSection(showMockReminder: false),
                  const SizedBox(height: 32),
                  DataManagementSection(
                    parts: bokiDataParts(
                      progressStore: appProgressStore,
                      companyModeHistoryStore: appCompanyModeHistoryStore,
                      learnedTermsStore: LearnedTermsStore('boki3'),
                    ),
                    description: '解答記録・会社経営モードの履歴・「覚えた」にした用語・デイリーミッション・自分用メモ・間違いノートは、'
                        'テーマや購入を除いて、書き出し・読み込み・リセットができます。端末内にのみ保存されています。',
                  ),
                  const SizedBox(height: 16),
                  // build の context は MaterialApp より上で Navigator を含まないため、Builder で
                  // 画面の中の context を使って遷移する。
                  Builder(
                    builder: (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.emoji_events_outlined),
                      title: const Text('実績'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(c).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AchievementsView(categoryLabels: dailyGoalAchievementCategoryLabels),
                        ),
                      ),
                    ),
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
        // 資格小物は右端に控えめに（装飾のみ。狭い幅ではタイトルが折り返す）。
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text('うかラボ 簿記3級', style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(width: 8),
              const CertPropBadge(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Boki3OshiCard(store: appProgressStore),
        // 推しの一言（無料）。タップで別の一言。
        OshiMessageCard(progressStore: appProgressStore),
        // 見出しで3つに分ける（今日やること／記録／試験に向けて）。調べる系の入口は「学ぶ」の「道具」。
        // 既存の専用カードはそのまま置く。折りたたみは要素が少ないため使わない。
        HomeSection(
          title: '今日やること',
          child: Column(
            children: [
              // 今日の復習（間違いノートの問題を、忘れる頃に）。
              TodayReviewSection(progressStore: appProgressStore),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: DailyMissionCard()),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: StudyReminderCard()),
            ],
          ),
        ),
        HomeSection(
          title: '記録',
          child: Column(
            children: [
              ProgressSummaryCard(store: appProgressStore),
              // 推しの成長（これまでの積み重ねへの反応。節目では一度だけ祝う）。
              OshiGrowthSection(progressStore: appProgressStore),
              // 週間ふりかえり（無料。今週できたことだけを見せる）。
              WeeklyRecapSection(progressStore: appProgressStore),
            ],
          ),
        ),
        HomeSection(
          title: '試験に向けて',
          child: Column(
            children: [
              const ExamCountdownEntry(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ExamPrepEntryCard(progressStore: appProgressStore),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Consumer(
          builder: (context, ref, _) => Center(child: ref.watch(adGateProvider).banner(BannerPlacement.home)),
        ),
        const SizedBox(height: 16),
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => NagaraSessionPage(progressStore: appProgressStore)),
            ),
            icon: const Icon(Icons.headphones_outlined),
            label: const Align(
              alignment: Alignment.centerLeft,
              child: Text('ながら学習（選択式を読み上げで自動で進める）'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        WeakSummarySection(progressStore: appProgressStore),
        WeakDrillCard(progressStore: appProgressStore),
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
        const SizedBox(height: 24),
        LearnToolsSection(progressStore: appProgressStore),
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
