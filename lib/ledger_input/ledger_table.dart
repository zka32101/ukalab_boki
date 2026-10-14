import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../practice/table_text_factor.dart';
import 'ledger_input_controller.dart';
import 'ledger_input_state.dart';

/// 補助簿の列（列グループ × 項目）の組み合わせ。表示順はこの並び。
typedef LedgerColumnKey = (LedgerColumnGroup group, LedgerField field);

const List<LedgerColumnKey> ledgerColumnOrder = [
  (LedgerColumnGroup.receipt, LedgerField.quantity),
  (LedgerColumnGroup.receipt, LedgerField.unitPrice),
  (LedgerColumnGroup.receipt, LedgerField.amount),
  (LedgerColumnGroup.issue, LedgerField.quantity),
  (LedgerColumnGroup.issue, LedgerField.unitPrice),
  (LedgerColumnGroup.issue, LedgerField.amount),
  (LedgerColumnGroup.balance, LedgerField.quantity),
  (LedgerColumnGroup.balance, LedgerField.unitPrice),
  (LedgerColumnGroup.balance, LedgerField.amount),
];

/// 補助簿の列グループ・項目の日本語表示名。
extension LedgerColumnKeyLabel on LedgerColumnKey {
  String get label {
    final groupLabel = switch ($1) {
      LedgerColumnGroup.receipt => '受入',
      LedgerColumnGroup.issue => '払出',
      LedgerColumnGroup.balance => '残高',
    };
    final fieldLabel = switch ($2) {
      LedgerField.quantity => '数量',
      LedgerField.unitPrice => '単価',
      LedgerField.amount => '金額',
    };
    return '$groupLabel\n$fieldLabel';
  }
}

/// 補助簿（商品有高帳・現金出納帳など）の表埋めテーブル。[WorksheetTable]
/// （`lib/worksheet_input/`）と同じ構造だが、行の軸が「勘定科目」ではなく
/// 「記入行（日付・摘要）」になる。[givenCells] は固定値として、
/// [blankCells] は入力可能セルとして表示する。横方向にスクロールする。
class LedgerTable extends ConsumerStatefulWidget {
  const LedgerTable({
    super.key,
    required this.rows,
    required this.givenCells,
    required this.blankCells,
    this.cellDiffs,
    this.readOnly = false,
  });

  final List<LedgerRowMeta> rows;
  final List<LedgerCell> givenCells;
  final List<LedgerCell> blankCells;
  final Map<LedgerCellRef, LedgerCellDiffKind>? cellDiffs;
  final bool readOnly;

  static const _metaColumnWidth = 72.0;
  static const _dataColumnWidth = 76.0;

  @override
  ConsumerState<LedgerTable> createState() => _LedgerTableState();
}

class _LedgerTableState extends ConsumerState<LedgerTable> {
  final Map<LedgerCellRef, GlobalKey> _cellKeys = {};
  LedgerCellRef? _lastSelectedCell;

  GlobalKey _keyFor(LedgerCellRef cell) => _cellKeys.putIfAbsent(cell, GlobalKey.new);

  void _scrollToIfSelected(LedgerCellRef? cell) {
    if (cell == null || cell == _lastSelectedCell) return;
    _lastSelectedCell = cell;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cellContext = _cellKeys[cell]?.currentContext;
      if (cellContext == null || !cellContext.mounted) return;
      Scrollable.ensureVisible(
        cellContext,
        duration: const Duration(milliseconds: 200),
        alignment: 0.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final allCells = [...widget.givenCells, ...widget.blankCells];
    final columns = ledgerColumnOrder
        .where((key) => allCells.any((c) => c.group == key.$1 && c.field == key.$2))
        .toList();

    final rowsByIndex = {for (final r in widget.rows) r.rowIndex: r};
    final sortedRowIndices = widget.rows.map((r) => r.rowIndex).toList()..sort();

    final givenByCell = {
      for (final c in widget.givenCells) (c.rowIndex, c.group, c.field): c.value,
    };
    final blankByCell = {
      for (final c in widget.blankCells) (c.rowIndex, c.group, c.field): true,
    };

    final state = ref.watch(ledgerInputProvider);
    final controller = ref.read(ledgerInputProvider.notifier);
    _scrollToIfSelected(state.selectedCell);

    // 文字が大きいときは列幅も広げる（固定幅のままだと数字が「…」で切れ、摘要が1文字ずつ折り返す）。
    // 表は横スクロールなので、広げても画面からはみ出さない。
    final f = tableTextFactor(context);
    // 金額（最大6桁）が「…」で切れない幅を、実際の文字の幅から求める（通常の大きさでは従来の幅のまま）。
    final dataWidth = math.max(LedgerTable._dataColumnWidth, amountCellWidth(context, digits: 6));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Theme.of(context).colorScheme.outlineVariant),
        columnWidths: {
          0: FixedColumnWidth(LedgerTable._metaColumnWidth * f),
          1: FixedColumnWidth(LedgerTable._metaColumnWidth * f),
          for (var i = 0; i < columns.length; i++)
            i + 2: FixedColumnWidth(dataWidth),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            children: [
              const _HeaderCell('日付'),
              const _HeaderCell('摘要'),
              for (final col in columns) _HeaderCell(col.label),
            ],
          ),
          for (final rowIndex in sortedRowIndices)
            TableRow(
              children: [
                _MetaCell(rowsByIndex[rowIndex]!.date),
                _MetaCell(rowsByIndex[rowIndex]!.description),
                for (final col in columns)
                  _buildDataCell(
                    context,
                    rowIndex: rowIndex,
                    column: col,
                    given: givenByCell[(rowIndex, col.$1, col.$2)],
                    editable: blankByCell[(rowIndex, col.$1, col.$2)] == true,
                    state: state,
                    controller: controller,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDataCell(
    BuildContext context, {
    required int rowIndex,
    required LedgerColumnKey column,
    required int? given,
    required bool editable,
    required LedgerInputState state,
    required LedgerInputController controller,
  }) {
    if (given != null) {
      return _ValueCell(value: given, variant: _CellVariant.given);
    }
    if (!editable) {
      return const _ValueCell(value: null, variant: _CellVariant.empty);
    }
    final cell = (rowIndex, column.$1, column.$2);
    final diffKind = widget.cellDiffs?[cell];
    final variant = switch (diffKind) {
      LedgerCellDiffKind.correct => _CellVariant.correct,
      LedgerCellDiffKind.wrongValue || LedgerCellDiffKind.missing => _CellVariant.wrong,
      _ => _CellVariant.editable,
    };
    return _ValueCell(
      key: _keyFor(cell),
      value: state.valueAt(cell),
      variant: variant,
      selected: !widget.readOnly && state.selectedCell == cell,
      onTap: widget.readOnly ? null : () => controller.selectCell(cell),
    );
  }
}

enum _CellVariant { given, empty, editable, correct, wrong }

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({
    super.key,
    required this.value,
    required this.variant,
    this.selected = false,
    this.onTap,
  });

  final int? value;
  final _CellVariant variant;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? background;
    Color? textColor;
    IconData? icon;
    switch (variant) {
      case _CellVariant.given:
        background = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
        textColor = theme.colorScheme.onSurfaceVariant;
      case _CellVariant.empty:
        background = null;
      case _CellVariant.editable:
        background = selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : null;
      case _CellVariant.correct:
        background = theme.colorScheme.primary.withValues(alpha: 0.12);
        textColor = theme.colorScheme.primary;
        icon = Icons.check;
      case _CellVariant.wrong:
        background = theme.colorScheme.error.withValues(alpha: 0.12);
        textColor = theme.colorScheme.error;
        icon = Icons.close;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        // 文字が大きいときは高さを伸ばす（固定高さだと数字が枠からはみ出す）。
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: value == null && variant == _CellVariant.empty
            ? Text('ー', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, size: 14, color: textColor),
                  if (icon != null) const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      value?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
