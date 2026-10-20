import 'package:flutter/material.dart';

/// 金額入力用のテンキー（電卓風）。システムのソフトキーボードは使わない。
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onTripleZero,
    required this.onBackspace,
    required this.onClear,
    required this.onNext,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onTripleZero;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onNext;

  static const double _minKeySize = 44;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['7', '8', '9'],
          ['4', '5', '6'],
          ['1', '2', '3'],
          ['000', '0', '⌫'],
        ])
          Row(
            children: [
              for (final key in row)
                Expanded(child: _buildKey(context, key)),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: _KeypadButton(
                label: 'クリア',
                onTap: onClear,
                minSize: _minKeySize,
              ),
            ),
            Expanded(
              child: _KeypadButton(
                label: '次へ',
                onTap: onNext,
                emphasize: true,
                minSize: _minKeySize,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(BuildContext context, String key) {
    switch (key) {
      case '000':
        return _KeypadButton(label: '000', onTap: onTripleZero, minSize: _minKeySize);
      case '⌫':
        return _KeypadButton(
          label: '⌫',
          semanticLabel: '1文字削除',
          onTap: onBackspace,
          minSize: _minKeySize,
        );
      default:
        return _KeypadButton(label: key, onTap: () => onDigit(key), minSize: _minKeySize);
    }
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.label,
    required this.onTap,
    required this.minSize,
    this.semanticLabel,
    this.emphasize = false,
  });

  final String label;
  final VoidCallback onTap;
  final double minSize;
  final String? semanticLabel;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        label: semanticLabel ?? label,
        button: true,
        // 文字が大きいときはキーも縦に伸びる（固定の高さだと文字の上下が切れる）。
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minSize),
          child: emphasize
              ? FilledButton(onPressed: onTap, child: Text(label))
              : OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(textStyle: theme.textTheme.titleMedium),
                  child: Text(label),
                ),
        ),
      ),
    );
  }
}
