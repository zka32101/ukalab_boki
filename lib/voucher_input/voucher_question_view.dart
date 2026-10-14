import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../journal_input/account_catalog.dart';
import '../journal_input/account_picker_sheet.dart';
import '../journal_input/journal_question_view.dart';
import '../journal_input/journal_result_banner.dart';
import '../journal_input/numeric_keypad.dart';
import '../practice/question_body_layout.dart';
import 'voucher_input_controller.dart';
import 'voucher_input_state.dart';
import 'voucher_kind.dart';
import 'voucher_slip_frame.dart';
import '../practice/tap_guard.dart';

/// 伝票（入金・出金・振替）1問分の画面。
///
/// 振替伝票は現金の受け払いを伴わないため、通常の仕訳入力（[JournalQuestionView]）
/// をそのまま伝票風の枠に入れて使う。入金伝票・出金伝票は現金側が伝票の種類で
/// 決まっている（入金伝票は借方が現金、出金伝票は貸方が現金）ため、実際の
/// 伝票の記入項目と同じく、相手科目と金額の2項目だけを入力させる。
class VoucherQuestionView extends StatelessWidget {
  const VoucherQuestionView({
    super.key,
    required this.prompt,
    required this.correctAnswer,
    required this.kind,
    this.explanation,
    this.onAnswered,
    this.onNext,
    this.revealResult = true,
  });

  final String prompt;
  final JournalAnswer correctAnswer;
  final VoucherKind kind;
  final String? explanation;

  /// 答え合わせボタンが押されたときに、判定結果とユーザー入力（通常の仕訳と
  /// 同じ borrow/credit 2行）を通知する。[JournalQuestionView] と同じ形にして
  /// 呼び出し側（[PracticeSession.answerJournal] など）をそのまま使えるようにする。
  final void Function(JournalJudgeResult result, List<JournalLine> userInput)? onAnswered;

  final VoidCallback? onNext;
  final bool revealResult;

  @override
  Widget build(BuildContext context) {
    return VoucherSlipFrame(
      kind: kind,
      child: kind == VoucherKind.transfer
          ? JournalQuestionView(
              prompt: prompt,
              correctAnswer: correctAnswer,
              explanation: explanation,
              onAnswered: onAnswered,
              onNext: onNext,
              revealResult: revealResult,
            )
          : _SingleLineVoucherForm(
              prompt: prompt,
              kind: kind,
              correctAnswer: correctAnswer,
              explanation: explanation,
              onAnswered: onAnswered,
              onNext: onNext,
              revealResult: revealResult,
            ),
    );
  }
}

/// 入金伝票・出金伝票の入力フォーム（相手科目・金額の1行だけ）。
class _SingleLineVoucherForm extends ConsumerStatefulWidget {
  const _SingleLineVoucherForm({
    required this.prompt,
    required this.kind,
    required this.correctAnswer,
    this.explanation,
    this.onAnswered,
    this.onNext,
    this.revealResult = true,
  });

  final String prompt;
  final VoucherKind kind;
  final JournalAnswer correctAnswer;
  final String? explanation;
  final void Function(JournalJudgeResult result, List<JournalLine> userInput)? onAnswered;
  final VoidCallback? onNext;
  final bool revealResult;

  @override
  ConsumerState<_SingleLineVoucherForm> createState() => _SingleLineVoucherFormState();
}

class _SingleLineVoucherFormState extends ConsumerState<_SingleLineVoucherForm> with TapGuardMixin<_SingleLineVoucherForm> {
  static const _maxRecent = 5;
  final List<String> _recentAccounts = [];
  JournalJudgeResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voucherInputProvider.notifier).reset();
    });
  }

  @override
  void didUpdateWidget(covariant _SingleLineVoucherForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prompt != widget.prompt) {
      startTapGuard();
      setState(() {
        _result = null;
        _recentAccounts.clear();
      });
      ref.read(voucherInputProvider.notifier).reset();
    }
  }

  /// 相手科目を記入する側（入金伝票なら貸方、出金伝票なら借方。借方は常に
  /// 入金伝票では現金、出金伝票では現金が貸方という前提に基づく）。
  JournalSide get _counterpartSide =>
      widget.kind == VoucherKind.receipt ? JournalSide.credit : JournalSide.debit;

  List<JournalLine> _buildLines(VoucherInputState input) {
    final account = input.account;
    final amount = input.amount;
    if (account == null || amount == null) return const [];
    final cashSide =
        _counterpartSide == JournalSide.credit ? JournalSide.debit : JournalSide.credit;
    return [
      JournalLine(side: _counterpartSide, account: account, amount: amount),
      JournalLine(side: cashSide, account: 'cash', amount: amount),
    ];
  }

  Future<void> _selectAccount() async {
    final code = await showAccountPicker(context, recent: _recentAccounts);
    if (code != null) {
      setState(() {
        _recentAccounts.remove(code);
        _recentAccounts.insert(0, code);
        if (_recentAccounts.length > _maxRecent) _recentAccounts.removeLast();
      });
      ref.read(voucherInputProvider.notifier).setAccount(code);
    }
  }

  void _checkAnswer() {
    startTapGuard(); // 直後の「次の問題へ」への誤タップ（ダブルタップ）を無視する
    final input = ref.read(voucherInputProvider);
    final lines = _buildLines(input);
    final result = judgeJournal(widget.correctAnswer, lines);
    widget.onAnswered?.call(result, lines);
    if (widget.revealResult) {
      setState(() => _result = result);
    } else {
      widget.onNext?.call();
    }
  }

  void _retry() {
    setState(() => _result = null);
    ref.read(voucherInputProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(voucherInputProvider);
    final controller = ref.read(voucherInputProvider.notifier);
    final theme = Theme.of(context);
    final readOnly = _result != null;
    final showKeypad = !readOnly && input.selectedField == VoucherSelectedField.amount;

    return QuestionBodyLayout(
      scrollChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(widget.prompt, style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('勘定科目', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              _SlipFieldCell(
                text: input.account != null ? accountNameOf(input.account!) : '',
                selected: !readOnly && input.selectedField == VoucherSelectedField.account,
                onTap: readOnly ? null : _selectAccount,
              ),
              const SizedBox(height: 16),
              Text('金額', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              _SlipFieldCell(
                text: input.amount?.toString() ?? '',
                alignEnd: true,
                selected: !readOnly && input.selectedField == VoucherSelectedField.amount,
                onTap: readOnly ? null : () => controller.selectField(VoucherSelectedField.amount),
              ),
            ],
          ),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: JournalResultBanner(result: _result!, explanation: widget.explanation),
          ),
      ],
      bottomChildren: [
        if (showKeypad)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: NumericKeypad(
              onDigit: controller.appendDigit,
              onTripleZero: controller.appendTripleZero,
              onBackspace: controller.backspaceAmount,
              onClear: controller.clearAmount,
              onNext: controller.confirmAmount,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _result == null
              ? FilledButton(
                  onPressed: guardTap(_checkAnswer),
                  child: Text(widget.revealResult ? '答え合わせ' : '次へ'),
                )
              : (widget.onNext != null
                  ? FilledButton(onPressed: guardTap(widget.onNext), child: const Text('次の問題へ'))
                  : OutlinedButton(onPressed: _retry, child: const Text('もう一度'))),
        ),
      ],
    );
  }
}

class _SlipFieldCell extends StatelessWidget {
  const _SlipFieldCell({
    required this.text,
    required this.selected,
    required this.onTap,
    this.alignEnd = false,
  });

  final String text;
  final bool selected;
  final VoidCallback? onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.12) : theme.colorScheme.surface,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(text, style: theme.textTheme.titleMedium),
        ),
      ),
    );
  }
}
