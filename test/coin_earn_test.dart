import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/hands_free/hands_free_choice_question.dart';
import 'package:ukalab_boki3/oshi/boki3_coin_earn.dart';
import 'package:ukalab_boki3/practice/practice_page.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_core/ui.dart';

import 'test_support.dart';

Override _coinOverride() => coinServiceProvider
    .overrideWithValue(CoinService(store: InMemoryCoinStore()));

ProviderContainer _container() {
  final c = ProviderContainer(overrides: [_coinOverride()]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('1問解くと+1、同じ問題は生涯1回', () async {
    final c = _container();
    final coins = c.read(coinProvider.notifier);
    await earnAnswerCoin(coins, 'q1');
    expect(c.read(coinProvider).balance, 1);
    await earnAnswerCoin(coins, 'q1');
    expect(c.read(coinProvider).balance, 1);
    await earnAnswerCoin(coins, 'q2');
    expect(c.read(coinProvider).balance, 2);
  });

  test('1日30コインまで', () async {
    final c = _container();
    final coins = c.read(coinProvider.notifier);
    for (var i = 0; i < 40; i++) {
      await earnAnswerCoin(coins, 'q$i');
    }
    expect(c.read(coinProvider).balance, 30);
  });

  test('模擬の終了で mockDone(10)、合格で mockPass(50) は試験ごとに1回', () async {
    final c = _container();
    final coins = c.read(coinProvider.notifier);
    await earnMockCoins(coins, examId: 'boki3', passed: false);
    expect(c.read(coinProvider).balance, 10);
    await earnMockCoins(coins,
        examId: 'boki3', passed: true); // mockDone は同日2回目で付かない
    expect(c.read(coinProvider).balance, 60);
    await earnMockCoins(coins, examId: 'boki3', passed: true);
    expect(c.read(coinProvider).balance, 60);
  });

  test('連続学習7日で streak(30)', () async {
    final n = DateTime.now();
    final key =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'app_common_kit_streak_days': 7,
      'app_common_kit_last_study_date': key,
    });
    final c = _container();
    await earnStreakCoin(c.read(coinProvider.notifier));
    expect(c.read(coinProvider).balance, 30);
  });

  test('coinServiceProvider が未設定でも落ちない', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final ref = c.read(Provider((r) => r));
    expect(ref, isNotNull);
    await earnAnswerCoin(null, 'q1');
    await earnMockCoins(null, examId: 'boki3', passed: true);
  });

  testWidgets('演習で1問解くと残高が増え、同じ問題をやり直しても増えない', (tester) async {
    final store = InMemoryProgressStore();
    Future<void> openAndSolve(WidgetTester t) async {
      await t.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [...studyNotesTestOverrides(), _sharedCoin],
        child: MaterialApp(
          home: PracticePage(
              progressStore: store, restrictToQids: const {'boki3-c-0001'}),
        ),
      ));
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      for (var i = 0; i < 10 && find.text('答え合わせ').evaluate().isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.tap(find
          .descendant(
              of: find.byType(HandsFreeChoiceQuestion),
              matching: find.byType(InkWell))
          .first);
      await t.pumpAndSettle();
      await t.tap(find.text('答え合わせ'));
      await t.pumpAndSettle();
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump();
    }

    _sharedService = CoinService(store: InMemoryCoinStore());
    await openAndSolve(tester);
    expect(_sharedService.balance, 1);
    await openAndSolve(tester);
    expect(_sharedService.balance, 1);
  });
}

CoinService _sharedService = CoinService(store: InMemoryCoinStore());
final _sharedCoin = coinServiceProvider.overrideWith((ref) => _sharedService);
