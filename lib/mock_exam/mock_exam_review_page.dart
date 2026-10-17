import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../common/wrapping_app_bar.dart';
import '../journal_input/journal_result_banner.dart';
import '../ledger_input/ledger_result_banner.dart';
import '../term/explanation_with_terms.dart';
import '../worksheet_input/worksheet_result_banner.dart';

/// 模擬試験終了後、全問の正誤・自分の解答・正解・解説を振り返る画面。
///
/// 解答中は正誤を見せない模擬試験の性質上、終了後にまとめて確認できる場所が
/// 必要なため、結果画面の「間違えた問題を復習する」（解き直し）とは別に設ける。
/// 各問題の判定は [judgeJournal]・[judgeWorksheet]・[judgeLedger] を解答記録
/// （[answers]）に対して再計算するだけで、新しいデータモデルは要らない。
class MockExamReviewPage extends StatelessWidget {
  const MockExamReviewPage({super.key, required this.questions, required this.answers});

  final List<Question> questions;
  final Map<String, Object?> answers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: wrappingAppBar(context, '解答結果の詳細'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var index = 0; index < questions.length; index++) ...[
              if (index > 0) const Divider(height: 32),
              _QuestionReview(
                index: index,
                question: questions[index],
                answer: answers[questions[index].qid],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionReview extends StatelessWidget {
  const _QuestionReview({required this.index, required this.question, required this.answer});

  final int index;
  final Question question;
  final Object? answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${index + 1}問目',
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 4),
        Text(question.displayPrompt, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildResult(context),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    switch (question.type) {
      case QuestionType.journal:
        final lines = answer is List<JournalLine> ? answer! as List<JournalLine> : const <JournalLine>[];
        return JournalResultBanner(
          result: judgeJournal(question.journalAnswer!, lines),
          explanation: question.explanation,
        );
      case QuestionType.worksheet:
        final cells = answer is List<WorksheetCell> ? answer! as List<WorksheetCell> : const <WorksheetCell>[];
        return WorksheetResultBanner(
          result: judgeWorksheet(question.worksheetAnswer!, cells),
          explanation: question.explanation,
        );
      case QuestionType.ledger:
        final cells = answer is List<LedgerCell> ? answer! as List<LedgerCell> : const <LedgerCell>[];
        return LedgerResultBanner(
          result: judgeLedger(question.ledgerAnswer!, cells),
          rows: question.ledgerAnswer!.rows,
          explanation: question.explanation,
        );
      case QuestionType.choice:
        return _ChoiceReview(question: question, selectedIndex: answer is int ? answer! as int : null);
      case QuestionType.trueFalse:
      case QuestionType.cloze:
      case QuestionType.reverseLookup:
        return const SizedBox.shrink(); // 未対応タイプ（データに含まれない）
    }
  }
}

class _ChoiceReview extends StatelessWidget {
  const _ChoiceReview({required this.question, required this.selectedIndex});

  final Question question;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = selectedIndex == question.answerIndex;
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
          const SizedBox(height: 4),
          Text(
            selectedIndex == null ? 'あなたの解答: （未解答）' : 'あなたの解答: ${question.choices[selectedIndex!]}',
            style: theme.textTheme.bodySmall,
          ),
          if (!correct)
            Text('正解: ${question.choices[question.answerIndex]}', style: theme.textTheme.bodySmall),
          if (question.explanation.isNotEmpty) ...[
            const Divider(),
            ExplanationWithTerms(explanation: question.explanation),
          ],
        ],
      ),
    );
  }
}
