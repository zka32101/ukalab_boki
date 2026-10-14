import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../journal_input/journal_question_view.dart';
import 'evidence_document.dart';
import 'evidence_document_card.dart';

/// 証ひょう読み取り問題（topicId: `voucher_reading`）1問分の画面。
///
/// `prompt` から証ひょうの記載内容を取り出せた場合は、経緯の説明文＋証ひょう
/// 風のカード＋[JournalQuestionView]（通常の仕訳入力）の構成で表示する。
/// 取り出せなかった場合（`「」` で内容を囲んでいない問題）は、通常どおり
/// [JournalQuestionView] に `prompt` をそのまま渡す。
class EvidenceQuestionView extends StatelessWidget {
  const EvidenceQuestionView({
    super.key,
    required this.prompt,
    required this.correctAnswer,
    this.explanation,
    this.onAnswered,
    this.onNext,
    this.revealResult = true,
  });

  final String prompt;
  final JournalAnswer correctAnswer;
  final String? explanation;
  final void Function(JournalJudgeResult result, List<JournalLine> userInput)? onAnswered;
  final VoidCallback? onNext;
  final bool revealResult;

  @override
  Widget build(BuildContext context) {
    final document = parseEvidenceDocument(prompt);
    if (document == null) {
      return JournalQuestionView(
        prompt: prompt,
        correctAnswer: correctAnswer,
        explanation: explanation,
        onAnswered: onAnswered,
        onNext: onNext,
        revealResult: revealResult,
      );
    }

    return JournalQuestionView(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (document.narrative.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(document.narrative, style: Theme.of(context).textTheme.titleMedium),
              ),
            EvidenceDocumentCard(document: document),
          ],
        ),
      ),
      prompt: document.instruction,
      correctAnswer: correctAnswer,
      explanation: explanation,
      onAnswered: onAnswered,
      onNext: onNext,
      revealResult: revealResult,
    );
  }
}
