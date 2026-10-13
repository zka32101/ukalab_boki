import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_data/exam_data_cache.dart';
import '../oshi/oshi_recap.dart';
import '../practice/practice_page.dart';
import 'mistake_note_data.dart';

/// 間違いノート。ukalab_core の [MistakeNoteView] に、このアプリの履歴・保存先・出題画面をつなぐ。
/// 無料で使える（core の `PremiumFeature` に該当機能がないため）。
///
/// 開いたとき・解き直しから戻ったときに、解答履歴から取り込んで保存する
/// （同じ履歴を何度渡しても結果は同じ）。「解き直す」は既存の演習画面（[PracticePage]）を
/// その1問だけで開く。演習画面は選択式・仕訳・帳簿・精算表のどの形式も扱える。
class MistakeNotePage extends StatefulWidget {
  const MistakeNotePage({
    super.key,
    required this.progressStore,
    this.store,
    this.loadQuestionList,
    this.loadExam,
  });

  final ProgressStore progressStore;

  /// テスト用の差し替え。省略時は端末内の保存先。
  final MistakeNoteStore? store;

  /// 問題の読み込み（テストで差し替える）。
  final Future<List<Question>> Function()? loadQuestionList;
  final Future<ExamConfig> Function()? loadExam;

  @override
  State<MistakeNotePage> createState() => _MistakeNotePageState();
}

class _MistakeNotePageState extends State<MistakeNotePage> {
  List<MistakeNoteEntry>? _entries;
  Set<String> _celebrate = const {};
  List<Question> _questions = const [];
  Map<String, String> _subjectNames = const {};

  MistakeNoteStore get _store => widget.store ?? mistakeNoteStore;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  /// 保存済みのノートに、解答履歴を取り込んで保存する。
  Future<void> _sync() async {
    final questions = await (widget.loadQuestionList ?? loadQuestions)();
    final exam = await (widget.loadExam ?? loadExamConfig)();
    final records = withTopics(await widget.progressStore.loadRecords(), questions);
    final before = await _store.read();
    final after = mistakeNoteEngine.update(before, records);
    await _store.write(after);
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _subjectNames = {for (final s in exam.subjects) s.subjectId: s.name};
      _entries = after;
      _celebrate = mistakeNoteEngine.newlyOvercome(before, after).toSet();
    });
  }

  Future<void> _retry(MistakeNoteEntry entry) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PracticePage(
        progressStore: widget.progressStore,
        restrictToQids: {entry.qid},
        title: '解き直す',
      ),
    ));
    if (mounted) await _sync();
  }

  @override
  Widget build(BuildContext context) {
    final byQid = {for (final q in _questions) q.qid: q};
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: const Text('間違いノート')),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : MistakeNoteView(
              // 出題データに無い問題は問題文を出せないので省く。
              entries: [for (final e in entries) if (byQid.containsKey(e.qid)) e],
              celebrateQids: _celebrate,
              topicLabel: topicLabelFor(_questions, (id) => _subjectNames[id]),
              questionBuilder: (context, entry) => Text(byQid[entry.qid]!.prompt),
              onRetry: _retry,
            ),
    );
  }
}

/// 間違いノートを開く入口（ホームのカードと設定のタイルで共通）。
class MistakeNoteTile extends StatelessWidget {
  const MistakeNoteTile({super.key, required this.progressStore, this.contentPadding});

  final ProgressStore progressStore;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: contentPadding,
        leading: const Icon(Icons.edit_note_outlined),
        title: const Text('間違いノート'),
        subtitle: const Text('間違えた問題を見返して、解き直せます。'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => MistakeNotePage(progressStore: progressStore),
        )),
      );
}
