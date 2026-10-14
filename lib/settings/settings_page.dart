import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:ukalab_core/cross_promo.dart' show UkalabCrossPromoSection;

import '../hands_free/hands_free_section.dart';
import '../progress/progress_revision.dart';
import '../progress/progress_store.dart';
import 'cross_promo_config.dart';

/// 「設定」タブ。アプリの説明と、解答記録をリセットする機能を提供する。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.progressStore, this.purchaseSection, this.dataSection});

  final ProgressStore progressStore;

  /// 購入の欄（Riverpod の ProviderScope と権利サービスが必要なため、アプリ側から差し込む）。
  final Widget? purchaseSection;

  /// 「データの管理」（書き出し・読み込み・リセット）。Riverpod の ProviderScope が必要なため、
  /// アプリ側から差し込む。渡すと、下の簡易な「データ」欄（リセットのみ）の代わりに表示する。
  final Widget? dataSection;

  Future<void> _confirmAndReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // 文字が大きいときに、題名と本文が画面に収まらず切れないよう、スクロールできるようにする。
        scrollable: true,
        title: const Text('解答記録をリセットしますか？'),
        content: const Text(
          '演習・模擬試験の解答記録と科目別の正答率がすべて削除されます。この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('リセットする'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await progressStore.clearRecords();
    // ホーム・記録タブは IndexedStack でマウントされたままのため、明示的に
    // 再読み込みさせる（practice_page.dart が記録追加時に行うのと同じ仕組み）。
    progressRevision.value++;

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('解答記録をリセットしました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('表示', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        const ThemeModeSetting(),
        const SizedBox(height: 16),
        const TextScaleSetting(strings: TextScaleStrings.ja),
        const SizedBox(height: 32),
        const HandsFreeSection(),
        if (purchaseSection != null) ...[
          const SizedBox(height: 32),
          purchaseSection!,
        ],
        const SizedBox(height: 32),
        Text('このアプリについて', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text(
          '「うかラボ 簿記3級」は、日本商工会議所および各地商工会議所とは一切関係のない、'
          '非公式の学習アプリです。「日商簿記」は各団体の商標・登録商標である可能性があります。',
        ),
        // 掲載リストが空なら何も表示しない（余白も出ない）。大人向けのため isChildDirected は付けない。
        const UkalabCrossPromoSection(currentAppId: kCrossPromoAppId),
        const SizedBox(height: 32),
        if (dataSection != null)
          dataSection!
        else ...[
        Text('データ', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          '演習・模擬試験の解答記録（科目別の正答率・復習待ちの問題）は端末内にのみ保存されています。',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmAndReset(context),
          style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('解答記録をリセットする'),
        ),
        ],
      ],
    );
  }
}

/// 表示（ライト／ダーク／端末設定）の切り替え。
class ThemeModeSetting extends StatelessWidget {
  const ThemeModeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
          // 幅が狭い端末や文字が大きいとき（文字サイズ換算で約330dp未満）は、アイコンを省いて文字だけにして折れ・溢れを防ぐ。
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final narrow = MediaQuery.sizeOf(context).width / scale < 330;
          return SegmentedButton<ThemeMode>(
            showSelectedIcon: !narrow,
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: const Text('ライト'),
                icon: narrow ? null : const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: const Text('ダーク'),
                icon: narrow ? null : const Icon(Icons.dark_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: const Text('端末設定'),
                icon: narrow ? null : const Icon(Icons.smartphone_outlined),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selected) => setThemeMode(selected.first),
          );
        },
    );
  }
}
