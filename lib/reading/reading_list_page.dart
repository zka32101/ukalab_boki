import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/glossary.dart' show openTermCard;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../common/wrapping_app_bar.dart';
import '../exam_data/exam_data_cache.dart';
import '../exam_data/feature_flags.dart';
import '../hands_free/hands_free_state.dart';
import '../practice/practice_page.dart';

/// 「学ぶ」タブから開く、章ごとの解説読み物（教科書的なまとめページ）の一覧。
///
/// 科目（第1問〜第3問）ごとに読み物を並べ、タップで [ReadingDetailPage] を開く。
class ReadingListPage extends StatefulWidget {
  const ReadingListPage({super.key, required this.progressStore});

  /// 関連問題を開くときの解答記録の保存先。
  final ProgressStore progressStore;

  @override
  State<ReadingListPage> createState() => _ReadingListPageState();
}

class _ReadingListPageState extends State<ReadingListPage> {
  late final Future<(List<ChapterReading>, ExamConfig)> _future = _load();

  Future<(List<ChapterReading>, ExamConfig)> _load() async {
    final readings = await loadChapterReadings();
    final exam = await loadExamConfig();
    return (readings, exam);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: wrappingAppBar(context, '章ごとの解説読み物'),
      body: FutureBuilder<(List<ChapterReading>, ExamConfig)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
          if (snapshot.hasError) return ErrorState(message: '読み込みに失敗しました: ${snapshot.error}');
          final (readings, exam) = snapshot.data!;
          if (readings.isEmpty) {
            return const EmptyState(message: '解説読み物のデータがまだありません。', icon: Icons.auto_stories_outlined);
          }
          final subjects = [...exam.subjects]..sort((a, b) => a.order.compareTo(b.order));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final subject in subjects)
                for (final (i, r) in readings.where((r) => r.subjectId == subject.subjectId).indexed) ...[
                  if (i == 0) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(subject.name, style: theme.textTheme.titleMedium),
                    ),
                  ],
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: Text(r.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReadingDetailPage(reading: r, progressStore: widget.progressStore),
                        ),
                      ),
                    ),
                  ),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// 解説読み物1本の詳細。節を順に表示し、末尾に関連用語・関連問題を出す。
/// 本文中の用語はタップして用語カードを開ける。読み上げはプレミアム機能。
class ReadingDetailPage extends ConsumerStatefulWidget {
  const ReadingDetailPage({
    super.key,
    required this.reading,
    required this.progressStore,
    this.protoEnabled = kReadingExplanationProtoEnabled,
  });

  final ChapterReading reading;
  final ProgressStore progressStore;

  /// 【試作】表・手順の描画（`ReadingSectionContent`）、関連問題リンク、解説カードを使う。
  /// 既定は [kReadingExplanationProtoEnabled]（false のときは従来の表示）。
  final bool protoEnabled;

  @override
  ConsumerState<ReadingDetailPage> createState() => _ReadingDetailPageState();
}

class _ReadingDetailPageState extends ConsumerState<ReadingDetailPage> {
  late final Future<(List<Term>, List<Question>)> _future = _load();

  Future<(List<Term>, List<Question>)> _load() async {
    final terms = await loadTerms();
    final questions = await loadQuestions();
    return (terms, questions);
  }

  /// 本文中で検出してタップ可能にする用語。「A・B」形式の見出し語は A・B それぞれを検出する。
  List<TermReference> _termReferences(List<Term> terms) => [
        for (final t in terms)
          for (final text in t.term.split('・')) TermReference(termId: t.termId, matchText: text),
      ];

  @override
  Widget build(BuildContext context) {
    final r = widget.reading;
    final isPremium = canUsePremiumFeature(
      PremiumFeature.readingReadAloud,
      isPremium: (ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium,
    );
    return Scaffold(
      appBar: wrappingAppBar(context, r.title),
      body: FutureBuilder<(List<Term>, List<Question>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
          if (snapshot.hasError) return ErrorState(message: '読み込みに失敗しました: ${snapshot.error}');
          final (terms, questions) = snapshot.data!;
          Term? termById(String id) => terms.where((t) => t.termId == id).firstOrNull;
          Question? questionById(String id) => questions.where((q) => q.qid == id).firstOrNull;
          void openQuestion(String qid) {
            if (questionById(qid) == null) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PracticePage(
                  progressStore: widget.progressStore,
                  restrictToQids: {qid},
                  title: '関連問題',
                ),
              ),
            );
          }

          if (widget.protoEnabled) {
            return ReadingProtoBody(
              reading: r,
              terms: terms,
              questions: questions,
              onOpenQuestion: openQuestion,
              onOpenTerm: (t) => openTermCard(context, terms, t),
            );
          }
          return ChapterReadingWidget(
            title: r.title,
            sections: [for (final s in r.sections) ReadingSectionView(heading: s.heading, body: s.body)],
            relatedTerms: [
              for (final id in r.relatedTermIds)
                if (termById(id) case final t?) RelatedTermRef(termId: id, label: t.term),
            ],
            relatedQuestions: [
              for (final id in r.relatedQuestionIds)
                if (questionById(id) case final q?) RelatedQuestionRef(questionId: id, label: q.displayPrompt),
            ],
            bodyTermReferences: _termReferences(terms),
            onRelatedTermTap: (termId) {
              if (termById(termId) case final t?) openTermCard(context, terms, t);
            },
            onRelatedQuestionTap: (qid) {
              if (questionById(qid) == null) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PracticePage(
                    progressStore: widget.progressStore,
                    restrictToQids: {qid},
                    title: '関連問題',
                  ),
                ),
              );
            },
            onReadAloud: !isPremium
                ? null
                : () => appSpeaker.speakNow(r.sections.map((s) => '${s.heading}。${s.body}').join('')),
          );
        },
      ),
    );
  }
}

/// 【試作】表・手順を含む読み物の本文。`ReadingSectionContent` で節を描画し、
/// 関連用語・例題の解説（`ExplanationCard.fromPlain`）・関連問題リンクを末尾に出す。
/// [kReadingExplanationProtoEnabled] が true のときだけ [ReadingDetailPage] から使われる。
class ReadingProtoBody extends StatelessWidget {
  const ReadingProtoBody({
    super.key,
    required this.reading,
    required this.terms,
    required this.questions,
    required this.onOpenQuestion,
    required this.onOpenTerm,
  });

  final ChapterReading reading;
  final List<Term> terms;
  final List<Question> questions;
  final ValueChanged<String> onOpenQuestion;
  final ValueChanged<Term> onOpenTerm;

  String _shorten(String s) => s.length <= 40 ? s : '${s.substring(0, 40)}…';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byQid = {for (final q in questions) q.qid: q};
    Question? example;
    for (final id in reading.relatedQuestionIds) {
      final q = byQid[id];
      if (q != null && q.type == QuestionType.journal) {
        example = q;
        break;
      }
    }
    final relatedTerms = [
      for (final id in reading.relatedTermIds)
        for (final t in terms)
          if (t.termId == id) t,
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(reading.title, style: theme.textTheme.titleLarge),
          for (final s in reading.sections) ...[
            const SizedBox(height: 20),
            ReadingSectionContent(section: s),
          ],
          if (relatedTerms.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('関連用語', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in relatedTerms) ActionChip(label: Text(t.term), onPressed: () => onOpenTerm(t)),
              ],
            ),
          ],
          if (example != null) ...[
            const SizedBox(height: 20),
            Text('例題の解説', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(example.prompt, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            ExplanationCard.fromPlain(example.explanation),
          ],
          const SizedBox(height: 20),
          ReadingQuestionLinks.forReading(
            reading: reading,
            onOpenQuestion: onOpenQuestion,
            labels: {
              for (final id in reading.relatedQuestionIds)
                if (byQid[id] case final q?) id: _shorten(q.displayPrompt),
            },
          ),
        ],
      ),
    );
  }
}
