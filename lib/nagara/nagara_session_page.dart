import 'dart:async';
import 'dart:math';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/daily_goal.dart' show recordDailyAnswer;
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_data/current_level.dart';
import '../exam_data/exam_data_cache.dart';
import '../hands_free/hands_free_state.dart';
import '../progress/progress_revision.dart';

/// 1 回の「ながら学習」で出す問題数の上限。超えたら「ひと休み」を促して終える。
const int kNagaraMaxQuestions = 20;

/// ながらセッションの出題を選ぶ。選択式（choice）だけを対象にする。
/// 仕訳・帳簿・精算表は画面での入力が必須なので、ながら学習には出さない。
///
/// 今の試験区分の問題から、解答記録で復習が必要な問題（[reviewPriorityQids]）を先頭に、
/// 残りは [random] で並べ替える。
List<Question> pickNagaraQuestions(
  List<Question> all,
  List<ProgressRecord> records, {
  DateTime? now,
  Random? random,
}) {
  final levelId = currentLevelId(now: now);
  final pool = all
      .where((q) => q.type == QuestionType.choice && (q.levelId == null || q.levelId == levelId))
      .toList();
  final byQid = {for (final q in pool) q.qid: q};
  final priority = <Question>[
    for (final qid in reviewPriorityQids(records))
      if (byQid.remove(qid) case final q?) q,
  ];
  final rest = byQid.values.toList()..shuffle(random);
  return [...priority, ...rest];
}

/// 「ながら学習」の画面。選択式の問題を、画面を点けたまま読み上げ→考える間→正解と解説→次へ、と
/// 自動で進める（kit の [NagaraSessionView]）。バックグラウンド再生や画面ロック中の再生はしない。
class NagaraSessionPage extends ConsumerStatefulWidget {
  const NagaraSessionPage({
    super.key,
    required this.progressStore,
    this.maxQuestions = kNagaraMaxQuestions,
    this.now,
    this.random,
    this.questionLoader = loadQuestions,
  });

  final ProgressStore progressStore;
  final int maxQuestions;
  final DateTime? now;
  final Random? random;
  final Future<List<Question>> Function() questionLoader;

  @override
  ConsumerState<NagaraSessionPage> createState() => _NagaraSessionPageState();
}

/// kit の画面が読む [handsFreeProvider] を、アプリ共通の設定（[appHandsFree]）につなぐ。
class _BoundHandsFreeNotifier extends HandsFreeNotifier {
  @override
  HandsFreeSettings build() {
    void sync() => state = appHandsFree.value;
    appHandsFree.addListener(sync);
    ref.onDispose(() => appHandsFree.removeListener(sync));
    return appHandsFree.value;
  }

  @override
  Future<void> update(HandsFreeSettings settings) => updateHandsFree(settings);
}

class _NagaraSessionPageState extends ConsumerState<NagaraSessionPage> {
  late final Future<List<Question>> _future = _load();
  final Map<String, Question> _byQid = {};
  final Set<String> _wrong = {};
  final Set<String> _unanswered = {};
  List<Question> _picked = const [];
  bool _flushed = false;

  Future<List<Question>> _load() async {
    final all = await widget.questionLoader();
    final records = await widget.progressStore.loadRecords();
    _picked = pickNagaraQuestions(all, records, now: widget.now, random: widget.random);
    _byQid.addAll({for (final q in _picked) q.qid: q});
    return _picked;
  }

  /// 通常の演習（PracticePage）と同じ記録経路: デイリーミッション・解答記録・進捗の再読込・学習日。
  void _record(Question q, {required bool correct}) {
    unawaited(recordDailyAnswer(ref));
    unawaited(
      widget.progressStore
          .addRecord(
            ProgressRecord(qid: q.qid, subjectId: q.subjectId, correct: correct, at: DateTime.now()),
          )
          .then((_) {
            progressRevision.value++;
            unawaited(recordStudyToday());
          }),
    );
  }

  void _onWrong(NagaraQuestion nq, int chosen) {
    _wrong.add(nq.id);
    final q = _byQid[nq.id];
    if (q != null) _record(q, correct: false);
  }

  void _onUnanswered(NagaraQuestion nq) => _unanswered.add(nq.id);

  /// kit は正解した問題を個別には通知しないので、終わったときに数を突き合わせて記録する。
  /// 誤答・時間切れの通知がない問題は「正解」か「スキップ」のどちらかで、区別がつかない。
  /// 件数が [NagaraSessionState.correctCount] と一致するとき（スキップなし）だけ正解として記録し、
  /// 一致しないときは誤って正解にしないよう記録しない。
  void _onFinished(NagaraSessionState summary) {
    if (_flushed) return;
    _flushed = true;
    final done = _picked.take(summary.completed).toList();
    final candidates = [
      for (final q in done)
        if (!_wrong.contains(q.qid) && !_unanswered.contains(q.qid)) q,
    ];
    if (candidates.length == summary.correctCount) {
      for (final q in candidates) {
        _record(q, correct: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ながら学習')),
      body: SafeArea(
        child: FutureBuilder<List<Question>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('読み込みに失敗しました: ${snapshot.error}'));
            }
            final questions = snapshot.data!;
            if (questions.isEmpty) {
              return const Center(child: Text('出せる選択式の問題がありません。'));
            }
            return ProviderScope(
              overrides: [
                speechBackendProvider.overrideWithValue(appSpeechBackend),
                handsFreeProvider.overrideWith(_BoundHandsFreeNotifier.new),
              ],
              child: NagaraSessionView(
                questions: [
                  for (final q in questions)
                    NagaraQuestion(
                      id: q.qid,
                      prompt: q.prompt,
                      choices: q.choices,
                      correctIndex: q.answerIndex,
                      explanation: q.explanation,
                    ),
                ],
                maxQuestions: widget.maxQuestions,
                onWrongAnswer: _onWrong,
                onUnanswered: _onUnanswered,
                onFinished: _onFinished,
                onClose: () => Navigator.of(context).maybePop(),
              ),
            );
          },
        ),
      ),
    );
  }
}
