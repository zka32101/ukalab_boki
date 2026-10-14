import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../journal_input/account_catalog.dart';
import '../practice/table_text_factor.dart';
import 'worksheet_input_controller.dart';
import 'worksheet_input_state.dart';

/// [WorksheetColumn] の日本語表示名。
extension WorksheetColumnLabel on WorksheetColumn {
  String get label => switch (this) {
        WorksheetColumn.trialBalanceDebit => '試算表\n借方',
        WorksheetColumn.trialBalanceCredit => '試算表\n貸方',
        WorksheetColumn.adjustmentDebit => '修正記入\n借方',
        WorksheetColumn.adjustmentCredit => '修正記入\n貸方',
        WorksheetColumn.incomeStatementDebit => '損益計算書\n借方',
        WorksheetColumn.incomeStatementCredit => '損益計算書\n貸方',
        WorksheetColumn.balanceSheetDebit => '貸借対照表\n借方',
        WorksheetColumn.balanceSheetCredit => '貸借対照表\n貸方',
      };
}

/// 精算表・財務諸表の表埋めテーブル。[givenCells] は固定値として、
/// [blankCells] は入力可能セルとして表示する。横方向にスクロールする。
class WorksheetTable extends ConsumerStatefulWidget {
  const WorksheetTable({
    super.key,
    required this.givenCells,
    required this.blankCells,
    this.cellDiffs,
    this.readOnly = false,
  });

  final List<WorksheetCell> givenCells;
  final List<WorksheetCell> blankCells;
  final Map<WorksheetCellRef, WorksheetCellDiffKind>? cellDiffs;
  final bool readOnly;

  static const _accountColumnWidth = 104.0;
  static const _dataColumnWidth = 92.0;

  @override
  ConsumerState<WorksheetTable> createState() => _WorksheetTableState();
}

class _WorksheetTableState extends ConsumerState<WorksheetTable> {
  final Map<WorksheetCellRef, GlobalKey> _cellKeys = {};
  WorksheetCellRef? _lastSelectedCell;

  GlobalKey _keyFor(WorksheetCellRef cell) => _cellKeys.putIfAbsent(cell, GlobalKey.new);

  void _scrollToIfSelected(WorksheetCellRef? cell) {
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
    // 出現順でユニーク化。
    final seen = <String>{};
    final uniqueAccounts = [
      for (final c in allCells)
        if (seen.add(c.account)) c.account,
    ];
    final columns = WorksheetColumn.values.where((col) => allCells.any((c) => c.column == col)).toList();

    final givenByCell = {for (final c in widget.givenCells) (c.account, c.column): c.amount};
    final blankByCell = {for (final c in widget.blankCells) (c.account, c.column): true};

    final state = ref.watch(worksheetInputProvider);
    final controller = ref.read(worksheetInputProvider.notifier);
    _scrollToIfSelected(state.selectedCell);

    // 文字が大きいときは列幅も広げる（固定幅のままだと数字が「…」で切れ、科目名が1文字ずつ折り返す）。
    // 表は横スクロールなので、広げても画面からはみ出さない。
    final f = tableTextFactor(context);
    // 金額（最大6桁）が「…」で切れない幅を、実際の文字の幅から求める（通常の大きさでは従来の幅のまま）。
    final dataWidth = math.max(WorksheetTable._dataColumnWidth, amountCellWidth(context, digits: 6));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Theme.of(context).colorScheme.outlineVariant),
        columnWidths: {
          0: FixedColumnWidth(WorksheetTable._accountColumnWidth * f),
          for (var i = 0; i < columns.length; i++)
            i + 1: FixedColumnWidth(dataWidth),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            children: [
              const _HeaderCell('勘定科目'),
              for (final col in columns) _HeaderCell(col.label),
            ],
          ),
          for (final account in uniqueAccounts)
            TableRow(
              children: [
                _AccountNameCell(accountNameOf(account)),
                for (final col in columns)
                  _buildDataCell(
                    context,
                    account: account,
                    column: col,
                    given: givenByCell[(account, col)],
                    editable: blankByCell[(account, col)] == true,
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
    required String account,
    required WorksheetColumn column,
    required int? given,
    required bool editable,
    required WorksheetInputState state,
    required WorksheetInputController controller,
  }) {
    if (given != null) {
      return _ValueCell(amount: given, variant: _CellVariant.given);
    }
    if (!editable) {
      return const _ValueCell(amount: null, variant: _CellVariant.empty);
    }
    final cell = (account, column);
    final diffKind = widget.cellDiffs?[cell];
    final variant = switch (diffKind) {
      WorksheetCellDiffKind.correct => _CellVariant.correct,
      WorksheetCellDiffKind.wrongAmount || WorksheetCellDiffKind.missing => _CellVariant.wrong,
      _ => _CellVariant.editable,
    };
    return _ValueCell(
      key: _keyFor(cell),
      amount: state.amountAt(cell),
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

class _AccountNameCell extends StatelessWidget {
  const _AccountNameCell(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({
    super.key,
    required this.amount,
    required this.variant,
    this.selected = false,
    this.onTap,
  });

  final int? amount;
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
        child: amount == null && variant == _CellVariant.empty
            ? Text('ー', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, size: 14, color: textColor),
                  if (icon != null) const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      amount?.toString() ?? '',
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
