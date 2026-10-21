import 'package:ukalab_core/learning.dart' show loadCurrentStreak;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_data/exam_data_cache.dart';
import '../exam_prep/exam_prep_data.dart' show examDateProvider;
import '../progress/progress_revision.dart';
import 'oshi_recap.dart';

/// 解答履歴・問題データ・（任意で）科目名を読み込み、解答記録が増えるたびに読み直す下請け。
mixin _HomeDataLoader<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  ProgressStore get store;
  Future<List<Question>> Function()? get loadQuestionList;
  DateTime Function() get clock;

  List<ProgressRecord> records = const [];
  List<Question> questions = const [];

  @override
  void initState() {
    super.initState();
    progressRevision.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    progressRevision.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    final qs = await (loadQuestionList ?? loadQuestions)();
    final rs = await store.loadRecords();
    final extra = await loadExtra();
    if (!mounted) return;
    setState(() {
      questions = qs;
      records = withTopics(rs, qs);
      applyExtra(extra);
    });
  }

  Future<Object?> loadExtra() async => null;
  void applyExtra(Object? extra) {}
}

/// ホームの「推しの一言」。学習状況（解答履歴・連続学習・試験日）から、責めない一言を出す。
/// タップで別の一言。無料。文言・選び方は ukalab_core。
class OshiMessageCard extends ConsumerStatefulWidget {
  const OshiMessageCard({
    super.key,
    required this.progressStore,
    this.clock = DateTime.now,
    this.loadQuestionList,
    this.loadStreak,
  });

  final ProgressStore progressStore;
  final DateTime Function() clock;

  /// 問題の読み込み（テストで差し替える）。
  final Future<List<Question>> Function()? loadQuestionList;

  /// 現在も続いている連続日数（テストで差し替える。省略時は `loadCurrentStreak`）。
  final Future<int> Function()? loadStreak;

  @override
  ConsumerState<OshiMessageCard> createState() => _OshiMessageCardState();
}

class _OshiMessageCardState extends ConsumerState<OshiMessageCard> with _HomeDataLoader {
  int _streak = 0;

  @override
  ProgressStore get store => widget.progressStore;
  @override
  Future<List<Question>> Function()? get loadQuestionList => widget.loadQuestionList;
  @override
  DateTime Function() get clock => widget.clock;

  @override
  Future<Object?> loadExtra() => (widget.loadStreak ?? loadCurrentStreak)();

  @override
  void applyExtra(Object? extra) => _streak = extra as int? ?? 0;

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final situation = oshiMessageContextFor(
      records: records,
      currentStreak: _streak,
      now: now,
      examDate: ref.watch(examDateProvider),
      questions: questions,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OshiMessageBubble(situation: situation, now: now),
    );
  }
}

/// ホームの「週間ふりかえり」。今週（月曜始まり）にできたことだけを見せる。無料。
/// 解いていない週は、責めずに穏やかな表示になる（core 側）。
/// message スロットは、推しの一言と二重にならないよう使わない。
class WeeklyRecapSection extends ConsumerStatefulWidget {
  const WeeklyRecapSection({
    super.key,
    required this.progressStore,
    this.clock = DateTime.now,
    this.loadQuestionList,
  });

  final ProgressStore progressStore;
  final DateTime Function() clock;
  final Future<List<Question>> Function()? loadQuestionList;

  @override
  ConsumerState<WeeklyRecapSection> createState() => _WeeklyRecapSectionState();
}

class _WeeklyRecapSectionState extends ConsumerState<WeeklyRecapSection> with _HomeDataLoader {
  Map<String, String> _subjectNames = const {};

  @override
  ProgressStore get store => widget.progressStore;
  @override
  Future<List<Question>> Function()? get loadQuestionList => widget.loadQuestionList;
  @override
  DateTime Function() get clock => widget.clock;

  @override
  Future<Object?> loadExtra() async {
    final exam = await loadExamConfig();
    return {for (final s in exam.subjects) s.subjectId: s.name};
  }

  @override
  void applyExtra(Object? extra) => _subjectNames = (extra as Map<String, String>?) ?? const {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: WeeklyRecapCard(
        recap: weeklyRecapFor(records: records, now: widget.clock()),
        topicLabel: topicLabelFor(questions, (id) => _subjectNames[id]),
      ),
    );
  }
}
