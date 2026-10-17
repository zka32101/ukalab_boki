import 'package:ukalab_core/ukalab_core.dart';

/// 新しい問題タイプ（○×=trueFalse / 空欄補充=cloze / 説明から用語=reverseLookup。
/// ukalab_core v0.75.0〜）を出題に含めるか。
///
/// **false（既定）**: 出題データにこれらのタイプが含まれていても出題プールから除く。
/// ユーザーに見える変化はない（現状のデータにも含まれない）。
/// **true**: プールに残す。演習画面は新タイプに対応済みで、一覧系画面（間違いノート・
/// 読み物・記録・模擬試験の振り返り）の問題文も `displayPrompt` で表示する。
/// true にする前に、新タイプ問題データの内容確認（AI 下書きの要確認分）と、模擬試験など
/// 残りの画面での新タイプの動作確認が必要。
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
