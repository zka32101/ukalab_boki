import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/learning.dart' show loadCurrentStreak;

/// 連続学習でコインが付く日数（core の CoinRules: 7日=30 / 30日=100 / 100日=300）。
const boki3StreakCoinMilestones = [7, 30, 100];

/// コインの Notifier を取る。coinServiceProvider が未 override（テスト等）でも落ちず null を返す。
CoinNotifier? coinNotifierOrNull(WidgetRef ref) {
  try {
    return ref.read(coinProvider.notifier);
  } catch (_) {
    return null;
  }
}

Future<void> _grant(CoinNotifier? coins, CoinEvent e) async {
  if (coins == null) return;
  try {
    await coins.grant(e);
  } catch (_) {
    // コイン付与の失敗で学習を止めない。
  }
}

/// 連続学習の節目（7/30/100日）ならストリークのコインを付ける（各1回は core が保証）。
/// 学習日の記録（recordStudyToday）の後に呼ぶ。
Future<void> earnStreakCoin(CoinNotifier? coins) async {
  if (coins == null) return;
  try {
    final days = await loadCurrentStreak();
    if (boki3StreakCoinMilestones.contains(days)) {
      await _grant(coins, CoinEvent.streak(days));
    }
  } catch (_) {}
}

/// 1問解いたとき（演習・ながら共通）。正誤は問わない。同じ問題は生涯1回、1日30コインまで（core 側で判定）。
Future<void> earnAnswerCoin(CoinNotifier? coins, String qid) async {
  await _grant(coins, CoinEvent.newQuestion(qid));
  await earnStreakCoin(coins);
}

/// 模擬試験を終えたとき。合格点以上なら mockPass も（試験IDごとに1回）。
Future<void> earnMockCoins(CoinNotifier? coins, {required String examId, required bool passed}) async {
  await _grant(coins, CoinEvent.mockDone());
  if (passed) await _grant(coins, CoinEvent.mockPass(examId));
  await earnStreakCoin(coins);
}
