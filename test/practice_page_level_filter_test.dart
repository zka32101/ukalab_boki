import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// `PracticePage._loadSession` が使うのと同じフィルタ式
/// （`q.levelId == null || q.levelId == levelId`）で、旧区分表専用の問題
/// （手形の仕訳、`levelId: level3_until_2027_03`）が正しく出し分けられるかを
/// データレベルで検証する。
void main() {
  late List<Question> questions;

  setUpAll(() {
    final text = File('assets/exam/boki3.questions.jsonl').readAsStringSync();
    final parsed = parseQuestionsJsonl(text);
    expect(parsed.issues, isEmpty);
    questions = parsed.questions;
  });

  test('旧区分表専用の問題（手形の仕訳）が存在する', () {
    final legacyOnly = questions.where((q) => q.levelId == 'level3_until_2027_03').toList();
    expect(legacyOnly, isNotEmpty);
    // 仕訳は手形・現金過不足の科目を使うこと。選択式（手形記入帳など）は topicId が notes_ で始まること。
    expect(
      legacyOnly.every((q) {
        final journal = q.journalAnswer;
        if (journal != null) {
          return journal.lines.any((l) => l.account.startsWith('notes_') || l.account == 'cash_over_short');
        }
        return q.topicId.startsWith('notes_');
      }),
      isTrue,
    );
  });

  test('新区分表の時期（level3_from_2027_04）は旧区分表専用の問題を除外する', () {
    final pool = questions.where((q) => q.levelId == null || q.levelId == 'level3_from_2027_04');
    final legacyOnlyIds = questions
        .where((q) => q.levelId == 'level3_until_2027_03')
        .map((q) => q.qid)
        .toSet();

    expect(pool.map((q) => q.qid).toSet().intersection(legacyOnlyIds), isEmpty);
  });

  test('旧区分表の時期（level3_until_2027_03）は旧区分表専用の問題を含む', () {
    final pool = questions.where((q) => q.levelId == null || q.levelId == 'level3_until_2027_03');
    final legacyOnlyIds = questions
        .where((q) => q.levelId == 'level3_until_2027_03')
        .map((q) => q.qid)
        .toSet();

    expect(pool.map((q) => q.qid).toSet().containsAll(legacyOnlyIds), isTrue);
  });
}
