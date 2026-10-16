import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ukalab_core.dart';

void main() {
  test('choice 形式の displayPrompt は prompt と同じ', () {
    final q = Question(
      qid: 'a',
      examId: 'boki3',
      subjectId: 's',
      topicId: 't',
      prompt: '問題文',
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: 'r',
      contentVer: '1',
      type: QuestionType.choice,
    );
    expect(q.displayPrompt, q.prompt);
  });
}
