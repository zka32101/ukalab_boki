import 'package:flutter/material.dart';

import 'account_catalog.dart';

/// 勘定科目を選ぶボトムシート。検索・最近使った科目・5要素グループ見出しを持つ。
///
/// 使い方: `final code = await showAccountPicker(context, recent: recentCodes);`
Future<String?> showAccountPicker(
  BuildContext context, {
  List<String> recent = const [],
  List<AccountDef> pool = boki3Accounts,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AccountPickerSheet(recent: recent, pool: pool),
  );
}

class _AccountPickerSheet extends StatefulWidget {
  const _AccountPickerSheet({required this.recent, required this.pool});

  final List<String> recent;
  final List<AccountDef> pool;

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  final _controller = TextEditingController();
  late List<AccountDef> _filtered = widget.pool;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() => _filtered = searchAccounts(query, pool: widget.pool));
  }

  @override
  Widget build(BuildContext context) {
    final recentDefs = [
      for (final code in widget.recent)
        if (widget.pool.any((a) => a.code == code))
          widget.pool.firstWhere((a) => a.code == code),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 入力欄のラベルは1行に収まらないと「…」で切れるため、折り返せる見出しとして外に出す。
              Align(
                alignment: Alignment.centerLeft,
                child: Text('勘定科目を検索', style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                decoration: const InputDecoration(
                  hintText: '科目名を入力',
                  hintMaxLines: 2,
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (_controller.text.isEmpty && recentDefs.isNotEmpty) ...[
                      const _SectionHeader(icon: Icons.history, label: '最近使った科目'),
                      for (final a in recentDefs) _AccountTile(account: a),
                      const Divider(),
                    ],
                    for (final group in AccountGroup.values) ...[
                      if (_filtered.any((a) => a.group == group)) ...[
                        _SectionHeader(icon: _iconFor(group), label: group.label),
                        for (final a in _filtered.where((a) => a.group == group))
                          _AccountTile(account: a),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static IconData _iconFor(AccountGroup group) => switch (group) {
        AccountGroup.asset => Icons.account_balance_wallet_outlined,
        AccountGroup.liability => Icons.request_quote_outlined,
        AccountGroup.equity => Icons.savings_outlined,
        AccountGroup.revenue => Icons.trending_up,
        AccountGroup.expense => Icons.trending_down,
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final AccountDef account;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 12,
      title: Text(account.name),
      onTap: () => Navigator.of(context).pop(account.code),
    );
  }
}
