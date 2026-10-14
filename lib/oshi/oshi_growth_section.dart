import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_prep/exam_prep_data.dart' show kExamId;
import '../progress/progress_revision.dart';

/// 画面の出入りを知るための observer（`MaterialApp.navigatorObservers` に渡す）。
/// 演習から戻ったときに、ホームの推しの節目を確かめ直すために使う。
final RouteObserver<ModalRoute<Object?>> homeRouteObserver = RouteObserver<ModalRoute<Object?>>();

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// 解答記録から推しの成長入力を作る。回答数は記録の件数、学習日数は記録のある日の数（連続ではなく合計）。
/// 記録は端末内に直近 2000 件まで保存される（`SharedPreferencesProgressStore.maxRecords`）ため、
/// それより古い分は数えられない。個人情報は入れない。
OshiGrowthProgress oshiGrowthProgressFrom(List<ProgressRecord> records) => OshiGrowthProgress(
      totalAnswered: records.length,
      studyDays: {for (final r in records) _day(r.at)}.length,
    );

/// ホーム「学習の記録」に置く、推しの成長の節目の見張り役。吹き出し（[OshiGrowthBubble]）はホームに出さない
/// （常時表示は「推しの一言」だけ）。節目に届いたら一度だけ祝福（[showOshiGrowthDialog]）。
/// 祝福はホームが最前面のときだけ出す（演習中は出さず、戻ったときに出る）。
class OshiGrowthSection extends StatefulWidget {
  const OshiGrowthSection({super.key, required this.progressStore, this.store});

  final ProgressStore progressStore;

  /// 祝福済みの節目の保存先。テスト用の差し替え。省略時は端末内（キー `ukalab_oshi_growth_boki3`）。
  final OshiGrowthStore? store;

  @override
  State<OshiGrowthSection> createState() => _OshiGrowthSectionState();
}

class _OshiGrowthSectionState extends State<OshiGrowthSection> with RouteAware {
  late final OshiGrowthService _service =
      OshiGrowthService(store: widget.store ?? SharedPreferencesOshiGrowthStore(kExamId));
  bool _checking = false;
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    progressRevision.addListener(_reload);
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) homeRouteObserver.unsubscribe(this);
      _route = route;
      homeRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    progressRevision.removeListener(_reload);
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// 演習などから戻ってきたとき。
  @override
  void didPopNext() => _reload();

  Future<void> _reload() async {
    if (_checking) return;
    _checking = true;
    OshiGrowthMilestone? milestone;
    try {
      final records = await widget.progressStore.loadRecords();
      final progress = oshiGrowthProgressFrom(records);
      if (!mounted) return;
      // ホームが最前面でなければ確認しない（祝福済みにせず、戻ったときに祝う）。
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        await _service.load();
        milestone = await _service.checkHeadline(progress);
      }
    } catch (_) {
      // 読み込み・保存に失敗しても、ホームは崩さない（保存に失敗した節目は次回また祝える）。
    } finally {
      _checking = false;
    }
    if (milestone != null && mounted) {
      await showOshiGrowthDialog(context, milestone: milestone);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
