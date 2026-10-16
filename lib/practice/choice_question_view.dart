import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';

import '../term/explanation_with_terms.dart';
import 'question_body_layout.dart';
import 'tap_guard.dart';

/// 選択式（type: choice）問題1問分の画面。問題文・選択肢・答え合わせをまとめる。
/// [JournalQuestionView]（lib/journal_input/）と並ぶ、第2問の理論問題向けの
/// シンプルな選択式UI。
class ChoiceQuestionView extends StatefulWidget {
  const ChoiceQuestionView({
    super.key,
    required this.prompt,
    required this.choices,
    required this.answerIndex,
    this.explanation,
    this.onAnswered,
    this.onNext,
    this.revealResult = true,
    this.feedbackBuilder,
  });

  final String prompt;
  final List<String> choices;
  final int answerIndex;
  final String? explanation;

  /// 答え合わせボタンが押されたときに、選んだ選択肢と正誤を通知する。
  final void Function(int selectedIndex, bool correct)? onAnswered;

  /// 非null なら、答え合わせ後に「もう一度」の代わりに「次の問題へ」ボタンを表示し、
  /// 押されたときにこれを呼ぶ（複数問を連続して出題する画面向け）。
  final VoidCallback? onNext;

  /// false なら、答え合わせの正誤・解説を表示せず、選択したら即座に
  /// [onNext] を呼ぶ（模擬試験モード向け。本試験では解答中に正誤が分からない）。
  final bool revealResult;

  /// 答え合わせ後に選択肢の下へ足す部品（解答後フィードバック）。選んだ選択肢の番号を受け取る。
  final Widget Function(int selectedIndex)? feedbackBuilder;

  @override
  State<ChoiceQuestionView> createState() => _ChoiceQuestionViewState();
}

class _ChoiceQuestionViewState extends State<ChoiceQuestionView>
    with TapGuardMixin<ChoiceQuestionView> {
  int? _selected;
  bool _answered = false;

  void _checkAnswer() {
    startTapGuard(); // 直後の「次の問題へ」への誤タップ（ダブルタップ）を無視する
    final selected = _selected;
    if (selected == null) return;
    final correct = selected == widget.answerIndex;
    widget.onAnswered?.call(selected, correct);
    if (widget.revealResult) {
      setState(() => _answered = true);
    } else {
      widget.onNext?.call();
    }
  }

  void _retry() {
    setState(() {
      _answered = false;
      _selected = null;
    });
  }

  static const _labels = ['ア', 'イ', 'ウ', 'エ', 'オ', 'カ'];

  String _labelFor(int i) => i < _labels.length ? _labels[i] : '${i + 1}';

  ChoiceState _stateFor(int i) {
    if (!_answered) {
      return _selected == i ? ChoiceState.selected : ChoiceState.idle;
    }
    if (i == widget.answerIndex) return ChoiceState.correct;
    if (_selected == i) return ChoiceState.incorrect;
    return ChoiceState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = _selected == widget.answerIndex;

    return QuestionBodyLayout(
      scrollChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(widget.prompt, style: theme.textTheme.titleMedium),
        ),
        for (var i = 0; i < widget.choices.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ChoiceTile(
              label: _labelFor(i),
              text: widget.choices[i],
              state: _stateFor(i),
              onTap: _answered ? null : () => setState(() => _selected = i),
            ),
          ),
        if (_answered && widget.feedbackBuilder != null && _selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: widget.feedbackBuilder!(_selected!),
          ),
        if (_answered)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _ChoiceResultBanner(
                correct: correct, explanation: widget.explanation),
          ),
      ],
      bottomChildren: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: !_answered
              ? FilledButton(
                  onPressed: guardTap(_selected == null ? null : _checkAnswer),
                  child: Text(widget.revealResult ? '答え合わせ' : '次へ'),
                )
              : (widget.onNext != null
                  ? FilledButton(
                      onPressed: guardTap(widget.onNext),
                      child: const Text('次の問題へ'))
                  : OutlinedButton(
                      onPressed: _retry, child: const Text('もう一度'))),
        ),
      ],
    );
  }
}

class _ChoiceResultBanner extends StatelessWidget {
  const _ChoiceResultBanner({required this.correct, this.explanation});

  final bool correct;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = correct ? theme.colorScheme.primary : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correct ? '正解です' : '不正解です',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          if (explanation != null && explanation!.isNotEmpty) ...[
            const Divider(),
            ExplanationWithTerms(explanation: explanation!),
          ],
        ],
      ),
    );
  }
}
