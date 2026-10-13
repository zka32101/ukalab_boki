import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'account_catalog.dart';
import 'account_picker_sheet.dart';
import 'journal_input_controller.dart';
import 'journal_input_state.dart';

/// 仕訳の表形式入力（借方科目｜借方金額｜貸方科目｜貸方金額）。
///
/// 答え合わせ後は [cellDiffs] で行・セルごとの判定（✓／科目違い／金額違い／貸借逆）を
/// 表示できる。採点前は null。
class JournalInputTable extends ConsumerWidget {
  const JournalInputTable({
    super.key,
    required this.recentAccountCodes,
    this.cellDiffs,
    this.readOnly = false,
    this.onAccountSelected,
    this.accountPool = boki3Accounts,
  });

  final List<String> recentAccountCodes;
  final Map<JournalCellRef, JournalLineDiffKind>? cellDiffs;
  final bool readOnly;
  final ValueChanged<String>? onAccountSelected;

  /// 科目ピッカーに表示する勘定科目一覧。旧区分表（`level3_until_2027_03`）向けの
  /// 問題では [boki3AccountsLegacy] を渡す（手形科目を選べるようにするため）。
  final List<AccountDef> accountPool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalInputProvider);
    final controller = ref.read(journalInputProvider.notifier);

    return Column(
      children: [
        const _TableHeaderRow(),
        for (var i = 0; i < state.rows.length; i++)
          _JournalRow(
            rowIndex: i,
            row: state.rows[i],
            selectedCell: state.selectedCell,
            cellDiffs: cellDiffs,
            readOnly: readOnly,
            onSelectCell: (cell) => _handleSelect(context, ref, cell),
            onRemove: state.rows.length > 1 && !readOnly ? () => controller.removeRow(i) : null,
          ),
        if (!readOnly && state.rows.length < JournalInputState.maxRows)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.addRow,
              icon: const Icon(Icons.add),
              label: const Text('行を追加'),
            ),
          ),
      ],
    );
  }

  Future<void> _handleSelect(BuildContext context, WidgetRef ref, JournalCellRef cell) async {
    if (readOnly) return;
    final controller = ref.read(journalInputProvider.notifier);
    controller.selectCell(cell);
    if (cell.field == JournalCellField.account) {
      final code = await showAccountPicker(context, recent: recentAccountCodes, pool: accountPool);
      if (code != null) {
        controller.setAccount(code);
        onAccountSelected?.call(code);
      }
    }
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    // 下の入力セルと同じ左右の余白を持たせ、隣の見出し（借方金額｜貸方科目）が詰まらないようにする。
    Widget label(String text, {bool alignEnd = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(text, style: style, textAlign: alignEnd ? TextAlign.right : TextAlign.left),
        );
    return Row(
      children: [
        Expanded(flex: 4, child: label('借方科目')),
        Expanded(flex: 3, child: label('借方金額', alignEnd: true)),
        Expanded(flex: 4, child: label('貸方科目')),
        Expanded(flex: 3, child: label('貸方金額', alignEnd: true)),
        const SizedBox(width: 32),
      ],
    );
  }
}

class _JournalRow extends StatelessWidget {
  const _JournalRow({
    required this.rowIndex,
    required this.row,
    required this.selectedCell,
    required this.cellDiffs,
    required this.readOnly,
    required this.onSelectCell,
    required this.onRemove,
  });

  final int rowIndex;
  final JournalLineInputRow row;
  final JournalCellRef? selectedCell;
  final Map<JournalCellRef, JournalLineDiffKind>? cellDiffs;
  final bool readOnly;
  final ValueChanged<JournalCellRef> onSelectCell;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _Cell(
            cell: JournalCellRef(rowIndex: rowIndex, side: JournalSide.debit, field: JournalCellField.account),
            text: row.debitAccount != null ? accountNameOf(row.debitAccount!) : '',
            selected: selectedCell,
            diffKind: cellDiffs?[JournalCellRef(rowIndex: rowIndex, side: JournalSide.debit, field: JournalCellField.account)],
            onTap: onSelectCell,
          ),
        ),
        Expanded(
          flex: 3,
          child: _Cell(
            cell: JournalCellRef(rowIndex: rowIndex, side: JournalSide.debit, field: JournalCellField.amount),
            text: row.debitAmount?.toString() ?? '',
            alignEnd: true,
            selected: selectedCell,
            diffKind: cellDiffs?[JournalCellRef(rowIndex: rowIndex, side: JournalSide.debit, field: JournalCellField.amount)],
            onTap: onSelectCell,
          ),
        ),
        Expanded(
          flex: 4,
          child: _Cell(
            cell: JournalCellRef(rowIndex: rowIndex, side: JournalSide.credit, field: JournalCellField.account),
            text: row.creditAccount != null ? accountNameOf(row.creditAccount!) : '',
            selected: selectedCell,
            diffKind: cellDiffs?[JournalCellRef(rowIndex: rowIndex, side: JournalSide.credit, field: JournalCellField.account)],
            onTap: onSelectCell,
          ),
        ),
        Expanded(
          flex: 3,
          child: _Cell(
            cell: JournalCellRef(rowIndex: rowIndex, side: JournalSide.credit, field: JournalCellField.amount),
            text: row.creditAmount?.toString() ?? '',
            alignEnd: true,
            selected: selectedCell,
            diffKind: cellDiffs?[JournalCellRef(rowIndex: rowIndex, side: JournalSide.credit, field: JournalCellField.amount)],
            onTap: onSelectCell,
          ),
        ),
        SizedBox(
          width: 32,
          child: onRemove != null
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'この行を削除',
                  onPressed: onRemove,
                )
              : null,
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.text,
    required this.selected,
    required this.onTap,
    this.diffKind,
    this.alignEnd = false,
  });

  final JournalCellRef cell;
  final String text;
  final JournalCellRef? selected;
  final JournalLineDiffKind? diffKind;
  final bool alignEnd;
  final ValueChanged<JournalCellRef> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = selected == cell;
    final (icon, color) = _diffVisual(theme, diffKind);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: () => onTap(cell),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.12) : null,
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: alignEnd
                    // 金額は途中で切らず、セルの幅に合わせて縮小して全桁を見せる。
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(text, textAlign: TextAlign.right),
                      )
                    : Text(
                        text,
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData?, Color?) _diffVisual(ThemeData theme, JournalLineDiffKind? kind) {
    if (kind == null) return (null, null);
    return switch (kind) {
      JournalLineDiffKind.correct => (Icons.check, theme.colorScheme.primary),
      JournalLineDiffKind.wrongAccount => (Icons.close, theme.colorScheme.error),
      JournalLineDiffKind.wrongAmount => (Icons.close, theme.colorScheme.error),
      JournalLineDiffKind.sideSwapped => (Icons.swap_horiz, theme.colorScheme.error),
      JournalLineDiffKind.missing => (Icons.remove_circle_outline, theme.colorScheme.error),
      JournalLineDiffKind.extra => (Icons.close, theme.colorScheme.error),
    };
  }
}
