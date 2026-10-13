import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/answer_feedback.dart' show WeakSummaryCard, canShowWeakSummary;
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_data/current_level.dart';
import '../exam_data/exam_data_cache.dart';
import '../progress/progress_revision.dart';

/// 「学ぶ」タブの、今週の弱点まとめ（premium の機能）。
///
/// 弱点ドリルの入口（[WeakDrillCard]）の上に出す。premium でなければ何も出さない
/// （案内は弱点ドリル側にある）。解答記録に論点が無いため、問題データで補う。
class WeakSummarySection extends ConsumerStatefulWidget {
  const WeakSummarySection({
    super.key,
    required this.progressStore,
    this.loadQuestionList = loadQuestions,
    this.clock = DateTime.now,
  });

  final ProgressStore progressStore;
  final Future<List<Question>> Function() loadQuestionList;
  final DateTime Function() clock;

  @override
  ConsumerState<WeakSummarySection> createState() => _WeakSummarySectionState();
}

class _WeakSummarySectionState extends ConsumerState<WeakSummarySection> {
  List<ProgressRecord>? _records;
  List<Question> _questions = const [];

  @override
  void initState() {
    super.initState();
    progressRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    progressRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final records = await widget.progressStore.loadRecords();
    final levelId = currentLevelId(now: widget.clock());
    final questions = [
      for (final q in await widget.loadQuestionList())
        if (q.levelId == null || q.levelId == levelId) q,
    ];
    if (!mounted) return;
    setState(() {
      _records = records;
      _questions = questions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium =
        (ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium;
    final records = _records;
    if (!canShowWeakSummary(isPremium: isPremium) || records == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WeakSummaryCard(
        records: records,
        now: widget.clock(),
        questions: _questions,
        includeCalculation: false,
      ),
    );
  }
}
