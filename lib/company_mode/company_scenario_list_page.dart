import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../common/wrapping_app_bar.dart';
import '../exam_data/exam_data_cache.dart';
import 'company_mode_history_store.dart';
import 'company_scenario_play_page.dart';

/// 無料で使えるシナリオ（業種違いの最初の2つ）。残りはプレミアム限定。
/// `docs/company_mode_v1_design.md`「有料化の検討」参照。
const Set<String> freeCompanyScenarioIds = {'cafe_donguri', 'zakka_kotori'};

/// 「学ぶ」タブから開く会社経営モードのシナリオ選択画面。
///
/// `docs/company_mode_v1_design.md` のPhase 1〜3。[freeCompanyScenarioIds] の
/// シナリオは無料、それ以外はプレミアム限定で、未購読タップは案内のみで画面に入れない。
class CompanyScenarioListPage extends ConsumerStatefulWidget {
  const CompanyScenarioListPage({super.key, required this.historyStore});

  /// プレイ結果の保存先（「記録」タブの経営履歴に表示する）。
  final CompanyModeHistoryStore historyStore;

  @override
  ConsumerState<CompanyScenarioListPage> createState() => _CompanyScenarioListPageState();
}

class _CompanyScenarioListPageState extends ConsumerState<CompanyScenarioListPage> {
  late Future<List<CompanyScenario>> _scenariosFuture;

  @override
  void initState() {
    super.initState();
    _scenariosFuture = loadCompanyScenarios();
  }

  void _openScenario(CompanyScenario scenario) {
    final entitlement = ref.read(entitlementStateProvider).valueOrNull ?? EntitlementState.free;
    if (!freeCompanyScenarioIds.contains(scenario.scenarioId) && !entitlement.hasPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このシナリオはプレミアムの機能です。設定から購入できます。')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyScenarioPlayPage(
          scenario: scenario,
          historyStore: widget.historyStore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // タップ時に読むだけだと未購読で読み込み中のまま「無料」と判定されるため、ここで購読しておく。
    ref.watch(entitlementStateProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: wrappingAppBar(context, '会社を経営する'),
      body: FutureBuilder<List<CompanyScenario>>(
        future: _scenariosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '読み込みに失敗しました: ${snapshot.error}');
          }
          final scenarios = snapshot.data!;
          if (scenarios.isEmpty) {
            return const EmptyState(message: '利用できるシナリオがありません。', icon: Icons.storefront_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: scenarios.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final scenario = scenarios[index];
              final isFree = freeCompanyScenarioIds.contains(scenario.scenarioId);
              return Card(
                child: ListTile(
                  title: Text(scenario.companyName),
                  subtitle: Text(
                    '${scenario.industry} ・ 全${scenario.turns.length}ターン',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: isFree
                      ? const Icon(Icons.chevron_right)
                      : Icon(Icons.lock_outline, color: theme.colorScheme.outline),
                  onTap: () => _openScenario(scenario),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
