import 'package:ukalab_core/ukalab_core.dart';

/// 新しい問題タイプ（○×=trueFalse / 空欄補充=cloze / 説明から用語=reverseLookup。
/// ukalab_core v0.75.0〜）を出題に含めるか。
///
/// **false（既定）**: 出題データにこれらのタイプが含まれていても出題プールから除く。
/// ユーザーに見える変化はない（現状のデータにも含まれない）。
/// **true**: プールに残す。ただし簿記コレの画面は新タイプ用の解答画面をまだ持たない
/// ため、true にする前に演習・復習・模擬試験の各画面の対応が必要。
///
/// コンパイル時定数。テストでは [filterByNewQuestionTypes] の引数で切り替える。
const bool kNewQuestionTypesEnabled = false;

/// ○×・空欄補充・説明から用語のいずれか。
bool isNewQuestionType(Question q) =>
    q.type == QuestionType.trueFalse ||
    q.type == QuestionType.cloze ||
    q.type == QuestionType.reverseLookup;

/// フラグに従って出題プールを絞る。[enabled] が false なら新タイプを除く（順序は保つ）。
List<Question> filterByNewQuestionTypes(
  List<Question> questions, {
  bool enabled = kNewQuestionTypesEnabled,
}) {
  if (enabled) return questions;
  return questions.where((q) => !isNewQuestionType(q)).toList();
}
