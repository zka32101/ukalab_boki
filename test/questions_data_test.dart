import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// 問題データ（JSONL）の機械検証。出典必須・貸借一致・ExamConfigとの整合性を確認する。
void main() {
  test('boki3.questions.jsonl が出典必須・貸借一致などの品質ゲートを通る', () {
    final examJson = jsonDecode(
      File('assets/exam/boki3.exam.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final exam = ExamConfig.fromJson(examJson);

    final text = File('assets/exam/boki3.questions.jsonl').readAsStringSync();
    final parsed = parseQuestionsJsonl(text);
    expect(parsed.issues, isEmpty, reason: '${parsed.issues}');

    final issues = validateQuestions(parsed.questions, exam: exam);
    expect(issues, isEmpty, reason: '$issues');

    expect(parsed.questions, isNotEmpty);
    for (final q in parsed.questions) {
      expect(
        q.type,
        anyOf(
          QuestionType.journal,
          QuestionType.choice,
          QuestionType.worksheet,
          QuestionType.ledger,
          // 新3形式（フラグ kNewQuestionTypesEnabled が false の間は出題されない）
          QuestionType.trueFalse,
          QuestionType.cloze,
          QuestionType.reverseLookup,
        ),
      );
    }
  });

  test('qid に重複がない', () {
    final text = File('assets/exam/boki3.questions.jsonl').readAsStringSync();
    final parsed = parseQuestionsJsonl(text);
    final ids = [for (final q in parsed.questions) q.qid];
    expect(ids.toSet().length, ids.length);
  });
}
