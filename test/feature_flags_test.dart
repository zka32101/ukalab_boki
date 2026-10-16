import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_boki3/exam_data/feature_flags.dart';
import 'package:ukalab_core/ukalab_core.dart';

Question _q(String qid, QuestionType type) => Question(
      qid: qid,
      examId: 'boki3',
      subjectId: 's',
      topicId: 't',
      prompt: 'p',
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: 'r',
      contentVer: '1',
      type: type,
    );

void main() {
  final all = [
    _q('a', QuestionType.choice),
    _q('b', QuestionType.trueFalse),
    _q('c', QuestionType.cloze),
    _q('d', QuestionType.reverseLookup),
    _q('e', QuestionType.choice),
  ];

  test('フラグの既定は false', () {
    expect(kNewQuestionTypesEnabled, isFalse);
  });

  test('無効時は新タイプを除き順序を保つ', () {
    final r = filterByNewQuestionTypes(all, enabled: false);
    expect(r.map((q) => q.qid), ['a', 'e']);
  });

  test('有効時はそのまま残す', () {
    expect(filterByNewQuestionTypes(all, enabled: true), hasLength(5));
  });
}
