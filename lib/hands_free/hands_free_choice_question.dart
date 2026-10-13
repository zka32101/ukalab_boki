import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';

import '../practice/choice_question_view.dart';
import '../term/explanation_with_terms.dart';
import 'hands_free_state.dart';

/// 選択式の問題。ながら学習モードがオフなら従来の [ChoiceQuestionView]、オンなら
/// 大きな選択肢ボタンを下に寄せた画面で出し、問題と解説を自動で読み上げる。
class HandsFreeChoiceQuestion extends StatefulWidget {
  const HandsFreeChoiceQuestion({
    super.key,
    required this.prompt,
    required this.choices,
    required this.answerIndex,
    this.explanation,
    this.onAnswered,
    this.onNext,
    this.feedbackBuilder,
  });

  final String prompt;
  final List<String> choices;
  final int answerIndex;
  final String? explanation;
  final void Function(int selectedIndex, bool correct)? onAnswered;
  final VoidCallback? onNext;

  /// 答え合わせ後に足す解答後フィードバック（選んだ選択肢の番号を受け取る）。
  final Widget Function(int selectedIndex)? feedbackBuilder;

  @override
  State<HandsFreeChoiceQuestion> createState() => _HandsFreeChoiceQuestionState();
}

class _HandsFreeChoiceQuestionState extends State<HandsFreeChoiceQuestion> {
  static const _labels = ['ア', 'イ', 'ウ', 'エ', 'オ', 'カ'];

  int? _selected;

  @override
  void initState() {
    super.initState();
    appSpeaker.readQuestion(widget.prompt, widget.choices);
  }

  @override
  void dispose() {
    // 画面を離れたら読み上げを止める。
    appSpeaker.stop();
    super.dispose();
  }

  void _select(int i) {
    if (_selected != null) return;
    setState(() => _selected = i);
    widget.onAnswered?.call(i, i == widget.answerIndex);
    final explanation = widget.explanation;
    if (explanation != null && explanation.isNotEmpty) {
      appSpeaker.readExplanation(explanation);
    }
  }

  String _labelFor(int i) => i < _labels.length ? _labels[i] : '${i + 1}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HandsFreeSettings>(
      valueListenable: appHandsFree,
      builder: (context, settings, _) {
        if (!settings.enabled) {
          return ChoiceQuestionView(
            prompt: widget.prompt,
            choices: widget.choices,
            answerIndex: widget.answerIndex,
            explanation: widget.explanation,
            onAnswered: widget.onAnswered,
            onNext: widget.onNext,
            feedbackBuilder: widget.feedbackBuilder,
          );
        }
        final selected = _selected;
        if (selected == null) return _buildQuestion(context);
        return _buildResult(context, selected);
      },
    );
  }

  Widget _buildQuestion(BuildContext context) {
    return HandsFreeQuestionLayout(
      question: Text(widget.prompt, style: Theme.of(context).textTheme.titleLarge),
      trailing: ReadAloudButton(
        onPressed: () => appSpeaker.speakNow(questionReadAloudText(widget.prompt, widget.choices)),
      ),
      choices: [
        for (var i = 0; i < widget.choices.length; i++)
          HandsFreeChoiceTile(
            label: _labelFor(i),
            text: widget.choices[i],
            state: ChoiceState.idle,
            onTap: () => _select(i),
          ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, int selected) {
    final theme = Theme.of(context);
    final correct = selected == widget.answerIndex;
    final color = correct ? theme.colorScheme.primary : theme.colorScheme.error;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(correct ? Icons.check_circle : Icons.cancel, color: color, size: 32),
            const SizedBox(width: 8),
            Text(
              correct ? '正解です' : '不正解です',
              style: theme.textTheme.titleLarge?.copyWith(color: color),
            ),
          ],
        ),
        if (!correct) ...[
          const SizedBox(height: 8),
          Text('正解: ${_labelFor(widget.answerIndex)}　${widget.choices[widget.answerIndex]}'),
        ],
        if (widget.explanation != null && widget.explanation!.isNotEmpty) ...[
          const Divider(height: 32),
          ExplanationWithTerms(explanation: widget.explanation!),
        ],
        if (widget.feedbackBuilder != null) ...[
          const SizedBox(height: 16),
          widget.feedbackBuilder!(selected),
        ],
        const SizedBox(height: 24),
        if (widget.onNext != null)
          FilledButton(
            onPressed: widget.onNext,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: const Text('次の問題へ'),
          ),
      ],
    );
  }
}
