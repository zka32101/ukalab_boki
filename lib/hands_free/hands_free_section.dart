import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';

import 'hands_free_state.dart';

/// 設定タブに出す「ながら学習モード」の欄。
///
/// 上の 2 つは選択式の演習画面のモード。下の「ながら学習（自動で進める）」は
/// 学習メニューの「ながら学習」（自動進行のセッション）の間の長さの設定。
class HandsFreeSection extends StatelessWidget {
  const HandsFreeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = NagaraStrings.ja;
    return ValueListenableBuilder<HandsFreeSettings>(
      valueListenable: appHandsFree,
      builder: (context, settings, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ながら学習モード'),
            subtitle: const Text('選択式の問題を、大きなボタンと読み上げで解きます。'),
            value: settings.enabled,
            onChanged: (v) => updateHandsFree(settings.copyWith(enabled: v)),
          ),
          // 読み上げの設定は演習のモードと「ながら学習」セッションの両方で使うので、いつでも出す。
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('問題と解説を読み上げる'),
            value: settings.speakQuestion,
            onChanged: (v) =>
                updateHandsFree(settings.copyWith(speakQuestion: v, speakExplanation: v)),
          ),
          const SizedBox(height: 16),
          Text('ながら学習（自動で進める）', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(t.settingsThinkSeconds),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            key: const ValueKey('nagara-think-seconds'),
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              for (final s in HandsFreeSettings.thinkSecondsOptions)
                ButtonSegment(value: s, label: Text(t.secondsOption(s))),
            ],
            selected: HandsFreeSettings.thinkSecondsOptions.contains(settings.thinkSeconds)
                ? {settings.thinkSeconds}
                : <int>{},
            onSelectionChanged: (sel) {
              if (sel.isNotEmpty) updateHandsFree(settings.copyWith(thinkSeconds: sel.first));
            },
          ),
          const SizedBox(height: 16),
          Text(t.settingsBetweenSeconds),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            key: const ValueKey('nagara-between-seconds'),
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              for (final s in HandsFreeSettings.betweenSecondsOptions)
                ButtonSegment(value: s, label: Text(t.secondsOption(s))),
            ],
            selected: HandsFreeSettings.betweenSecondsOptions.contains(settings.betweenSeconds)
                ? {settings.betweenSeconds}
                : <int>{},
            onSelectionChanged: (sel) {
              if (sel.isNotEmpty) updateHandsFree(settings.copyWith(betweenSeconds: sel.first));
            },
          ),
          SwitchListTile(
            key: const ValueKey('nagara-auto-advance'),
            contentPadding: EdgeInsets.zero,
            title: Text(t.settingsAutoAdvance),
            value: settings.autoAdvance,
            onChanged: (v) => updateHandsFree(settings.copyWith(autoAdvance: v)),
          ),
        ],
      ),
    );
  }
}
