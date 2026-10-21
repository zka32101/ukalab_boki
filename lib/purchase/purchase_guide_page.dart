import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';

import 'premium_benefits_section.dart';

/// 設定の購入欄（購入・復元の欄＋プレミアムの特典）。設定タブと購入案内の画面で同じ内容を出す。
class PurchaseBlock extends StatelessWidget {
  const PurchaseBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (c) => PurchaseSection(titleStyle: Theme.of(c).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        const PremiumBenefitsSection(),
      ],
    );
  }
}

/// ホームの推しカードから、ロック中の資格専用キャラ（ソロ）の「プレミアムを見る」で開く購入案内の画面。
/// 下部タブはアプリ側から切り替えられないため、設定の購入欄と同じ内容を単独の画面で出す。
class PurchaseGuidePage extends StatelessWidget {
  const PurchaseGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('購入・プレミアム')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [PurchaseBlock()],
      ),
    );
  }
}
