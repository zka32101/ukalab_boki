import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// 章ごとの解説読み物（JSONL）の機械検証。節が空でないこと・用語/問題への参照の実在・
/// subjectId が試験定義にあること・readingId の一意性を、配信前に確認する。
void main() {
  test('boki3.readings.jsonl が品質ゲートを通る', () {
    final exam = ExamConfig.fromJson(
      jsonDecode(File('assets/exam/boki3.exam.json').readAsStringSync()) as Map<String, dynamic>,
    );
    final terms = parseTermsJsonl(File('assets/exam/boki3.terms.jsonl').readAsStringSync());
    expect(terms.issues, isEmpty, reason: '${terms.issues}');
    final questions = parseQuestionsJsonl(File('assets/exam/boki3.questions.jsonl').readAsStringSync());
    expect(questions.issues, isEmpty, reason: '${questions.issues}');

    final parsed = parseChapterReadingsJsonl(File('assets/exam/boki3.readings.jsonl').readAsStringSync());
    expect(parsed.issues, isEmpty, reason: '${parsed.issues}');
    expect(parsed.items, isNotEmpty);

    final issues = validateChapterReadings(
      parsed.items,
      exam: exam,
      termIds: [for (final t in terms.terms) t.termId],
      questionIds: [for (final q in questions.questions) q.qid],
    );
    expect(issues, isEmpty, reason: '$issues');
  });

  test('読み物は全科目（第1問〜第3問）に1本以上あり、readingId が重複しない', () {
    final parsed = parseChapterReadingsJsonl(File('assets/exam/boki3.readings.jsonl').readAsStringSync());
    final ids = [for (final r in parsed.items) r.readingId];
    expect(ids.toSet().length, ids.length);
    for (final subjectId in ['q1_shiwake', 'q2_choubo', 'q3_kessan']) {
      expect(parsed.items.where((r) => r.subjectId == subjectId), isNotEmpty, reason: subjectId);
    }
  });
}
