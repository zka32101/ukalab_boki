import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_core/learning.dart';

import '../exam_data/exam_data_cache.dart';
import '../progress/progress_revision.dart';
import '../purchase/purchase_guide_page.dart';

/// 解答記録から推しの成長段階を決める。網羅率＝解いた問題の種類÷全問題数、
/// 正答率＝正解数÷回答数。範囲外の問題の記録は数えない。
MascotStage oshiStageFromRecords({
  required Set<String> questionIds,
  required List<ProgressRecord> records,
}) {
  final mastery = MasteryInput.fromLogs(
    questionIds: questionIds,
    logs: [for (final r in records) (questionId: r.qid, isCorrect: r.correct)],
  );
  return MasteryModel.standard.stageOf(mastery);
}

/// ホームに置く推しカード（共通キットの [UkalabOshiCard]）。成長段階・連続日数は
/// 解答記録から計算する。解答記録が増えたら（[progressRevision]）再計算する。
class Boki3OshiCard extends StatefulWidget {
  const Boki3OshiCard({super.key, required this.store});

  final ProgressStore store;

  @override
  State<Boki3OshiCard> createState() => _Boki3OshiCardState();
}

class _OshiData {
  const _OshiData(this.stage, this.streakDays);

  final MascotStage stage;
  final int streakDays;
}

class _Boki3OshiCardState extends State<Boki3OshiCard> {
  late Future<_OshiData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    progressRevision.addListener(_onChanged);
  }

  @override
  void dispose() {
    progressRevision.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    // setState のコールバックは Future を返してはいけない（debug で警告になる）ので、ブロックにして代入だけ行う。
    setState(() {
      _future = _load();
    });
  }

  Future<_OshiData> _load() async {
    final questions = await loadQuestions();
    final records = await widget.store.loadRecords();
    final streak = await loadCurrentStreak();
    return _OshiData(
      oshiStageFromRecords(questionIds: {for (final q in questions) q.qid}, records: records),
      streak,
    );
  }

  /// ロック中の資格専用キャラ（ソロ）のプレビューの「プレミアムを見る」から呼ばれる。
  /// 推しの選択画面を閉じてから、購入欄を出す画面を開く（下部タブは外から切り替えられない）。
  void _openPurchase() {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.push(MaterialPageRoute<void>(builder: (_) => const PurchaseGuidePage()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OshiData>(
      future: _future,
      builder: (context, snapshot) {
        final d = snapshot.data;
        return UkalabOshiCard(
          cert: UkalabCert.boki3,
          appId: 'boki3',
          stage: d?.stage ?? MascotStage.lv1,
          streakDays: d?.streakDays ?? 0,
          onLockedTap: _openPurchase,
        );
      },
    );
  }
}
