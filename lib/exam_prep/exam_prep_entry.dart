import 'package:app_common_kit/app_common_kit.dart' show ExamDateTile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../common/wrapping_app_bar.dart';
import '../practice/practice_page.dart';
import '../progress/progress_revision.dart';
import 'exam_prep_data.dart';

/// ホームの「試験に向けて」カード（10分プラン・試験直前・当日チェックリスト）。
///
/// 出題は既存の演習画面（[PracticePage]）で行う。演習画面は仕訳・選択式・帳簿・精算表の
/// すべての問題形式を扱えるため、10分プランの問題プールに仕訳などの非選択式が混じっても
/// そのまま起動できる（選択式だけに絞らない）。
class ExamPrepEntryCard extends ConsumerStatefulWidget {
  const ExamPrepEntryCard({
    super.key,
    required this.progressStore,
    this.clock = DateTime.now,
    this.loadQuestionList,
  });

  final ProgressStore progressStore;
  final DateTime Function() clock;

  /// 問題の読み込み（テストで差し替える）。省略時は現在の試験区分の問題。
  final Future<List<Question>> Function()? loadQuestionList;

  @override
  ConsumerState<ExamPrepEntryCard> createState() => _ExamPrepEntryCardState();
}

class _ExamPrepEntryCardState extends ConsumerState<ExamPrepEntryCard> {
  List<Question> _questions = const [];
  List<ProgressRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    progressRevision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    progressRevision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final qs = await (widget.loadQuestionList ?? () => loadCurrentLevelQuestions(now: widget.clock()))();
    final rs = await widget.progressStore.loadRecords();
    if (!mounted) return;
    setState(() {
      _questions = qs;
      _records = rs;
    });
  }

  void _openPractice(BuildContext context, String title, List<Question> pool, String empty) {
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(empty)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PracticePage(
        progressStore: widget.progressStore,
        restrictToQids: {for (final q in pool) q.qid},
        title: title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ExamPrepCard(
      clock: widget.clock,
      questions: () => _questions,
      records: () => _records,
      examDate: ref.watch(examDateProvider),
      tenMinUnlocked: isPremiumFor(ref, PremiumFeature.tenMinutePlan),
      examEveUnlocked: isPremiumFor(ref, PremiumFeature.examEveMode),
      onStartPractice: _openPractice,
      onOpenChecklist: (c) async {
        final notifier = ref.read(checklistProvider.notifier);
        await notifier.ready;
        if (!c.mounted) return;
        final items = await loadChecklist();
        if (!c.mounted) return;
        await Navigator.of(c).push(MaterialPageRoute<void>(
          builder: (_) => ExamDayChecklistView(
            examId: kExamId,
            items: items,
            initialProgress: ref.read(checklistProvider),
            onChanged: notifier.setProgress,
          ),
        ));
      },
    );
  }
}

/// ホームの試験日カウントダウン（core の [ExamCountdownChip]）。無料。
///
/// 試験日が未設定なら何も出ない（core の仕様）。タップで試験日の設定画面を開く。
/// 「試験に向けて」カード内の既存の試験日表示とは共存している（整理は別 PR）。
class ExamCountdownEntry extends ConsumerWidget {
  const ExamCountdownEntry({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(examDateProvider);
    if (date == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ExamCountdownChip(
          examDate: date,
          clock: clock,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ExamDateSettingsPage()),
          ),
        ),
      ),
    );
  }
}

/// 試験日の設定画面（設定タブと同じ [ExamDateTile] を単独で開く）。
class ExamDateSettingsPage extends ConsumerWidget {
  const ExamDateSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: wrappingAppBar(context, '試験日'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ExamDateTile(
          date: ref.watch(examDateProvider),
          onChanged: (d) => ref.read(examDateProvider.notifier).setDate(d),
        ),
      ),
    );
  }
}

/// 設定タブの、試験日・更新ログ・履歴書き出しの入口。
class ExamPrepSettingsSection extends ConsumerWidget {
  const ExamPrepSettingsSection({super.key, required this.progressStore, this.saver, this.now});

  final ProgressStore progressStore;

  /// 履歴CSVの渡し方（テスト用の差し替え。null なら core の既定: Web はダウンロード、他は共有シート）。
  final FileSaver? saver;

  /// 履歴CSVのファイル名の日付に使う現在時刻（テスト用）。
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExamDateTile(
          date: ref.watch(examDateProvider),
          onChanged: (d) => ref.read(examDateProvider.notifier).setDate(d),
        ),
        ExamPrepSettingsTiles(
          exportUnlocked: isPremiumFor(ref, PremiumFeature.historyExport),
          onOpenUpdateLog: (c) => Navigator.of(c).push(MaterialPageRoute<void>(
              builder: (_) => UpdateLogView(entriesFuture: loadUpdateLog()))),
          onOpenExport: (c) async {
            final records = await progressStore.loadRecords();
            final questions = await loadCurrentLevelQuestions();
            if (!c.mounted) return;
            await Navigator.of(c).push(MaterialPageRoute<void>(
                builder: (_) => HistoryExportView(records: records, questions: questions, saver: saver, now: now)));
          },
        ),
      ],
    );
  }
}
