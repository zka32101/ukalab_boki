import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../common/wrapping_app_bar.dart';
import '../journal_input/account_catalog.dart';
import '../journal_input/journal_question_view.dart';
import '../journal_input/journal_result_banner.dart';
import '../progress/progress_revision.dart';
import 'company_ledger.dart';
import 'company_mode_history_store.dart';
import 'company_mode_session.dart';

/// 1シナリオを通して遊ぶ画面。導入→各ターンの仕訳入力→最終結果（累積の
/// 貸借対照表・損益計算書）までをこの1画面で進行する。
///
/// 各ターンの仕訳入力・採点には既存の [JournalQuestionView]・`judgeJournal` を
/// そのまま使う（`docs/company_mode_v1_design.md` の設計方針）。
class CompanyScenarioPlayPage extends StatefulWidget {
  const CompanyScenarioPlayPage({super.key, required this.scenario, required this.historyStore});

  final CompanyScenario scenario;

  /// プレイ結果の保存先（「記録」タブの経営履歴に表示する）。
  final CompanyModeHistoryStore historyStore;

  @override
  State<CompanyScenarioPlayPage> createState() => _CompanyScenarioPlayPageState();
}

class _CompanyScenarioPlayPageState extends State<CompanyScenarioPlayPage> {
  late final CompanyModeSession _session;
  bool _started = false;
  bool? _lastAnswerCorrect;

  @override
  void initState() {
    super.initState();
    _session = CompanyModeSession(scenario: widget.scenario);
  }

  void _start() => setState(() => _started = true);

  void _onAnswered(JournalJudgeResult result, List<JournalLine> userInput) {
    _lastAnswerCorrect = result.isCorrect;
  }

  void _onNext() {
    final correct = _lastAnswerCorrect ?? false;
    setState(() {
      _session.recordAndAdvance(correct: correct);
      _lastAnswerCorrect = null;
    });
    if (_session.isFinished) {
      unawaited(_saveResult());
    }
  }

  Future<void> _saveResult() async {
    await widget.historyStore.addResult(
      CompanyModeResult(
        scenarioId: widget.scenario.scenarioId,
        companyName: widget.scenario.companyName,
        correctCount: _session.turnCount - _session.wrongCount,
        turnCount: _session.turnCount,
        netIncome: _session.ledger.netIncome,
        playedAt: DateTime.now(),
      ),
    );
    progressRevision.value++;
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return _IntroView(scenario: widget.scenario, onStart: _start);
    }
    if (_session.isFinished) {
      return _ResultView(session: _session);
    }
    final turn = _session.current!;
    return Scaffold(
      appBar: wrappingAppBar(context, '${widget.scenario.companyName}（${_session.index + 1}/${_session.turnCount}）'),
      body: SafeArea(
        child: JournalQuestionView(
          key: ValueKey(turn.turnId),
          prompt: turn.eventText,
          correctAnswer: turn.answer,
          explanation: turn.explanation,
          onAnswered: _onAnswered,
          onNext: _onNext,
        ),
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({required this.scenario, required this.onStart});

  final CompanyScenario scenario;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: wrappingAppBar(context, scenario.companyName),
      body: SafeArea(
        // 文字が大きいと縦に収まらないので、全体をスクロールにし、開始ボタンは余白があるときだけ下に寄せる。
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scenario.industry, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(height: 8),
                    Text(scenario.companyName, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Text(scenario.introText, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Text(
                      '初期資本金: ${scenario.initialCapital}円 / 全${scenario.turns.length}ターン',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: onStart, child: const Text('経営を始める')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.session});

  final CompanyModeSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ledger = session.ledger;
    final correctCount = session.turnCount - session.wrongCount;

    return Scaffold(
      appBar: wrappingAppBar(context, '${session.scenario.companyName} 経営成績'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('経営成績', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '仕訳の正答: $correctCount / ${session.turnCount}ターン',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('貸借対照表（期末時点）', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _BalanceSheetTable(ledger: ledger),
            const SizedBox(height: 24),
            Text('損益計算書', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _IncomeStatementTable(ledger: ledger),
            if (session.wrongTurns.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('間違えたターンを振り返る', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final turn in session.wrongTurns) _WrongTurnReview(turn: turn),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('シナリオ選択に戻る'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 間違えたターンの「正解の仕訳＋解説」を振り返り表示する。
/// [JournalResultBanner] をそのまま使うことで、解説中の用語集連携
/// （`ExplanationWithTerms`）も自動的に効く。
class _WrongTurnReview extends StatelessWidget {
  const _WrongTurnReview({required this.turn});

  final CompanyTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(turn.eventText, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          JournalResultBanner(
            result: judgeJournal(turn.answer, turn.answer.lines),
            explanation: turn.explanation,
          ),
        ],
      ),
    );
  }
}

class _BalanceSheetTable extends StatelessWidget {
  const _BalanceSheetTable({required this.ledger});

  final CompanyLedger ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assets = ledger.entriesOf(AccountGroup.asset);
    final liabilities = ledger.entriesOf(AccountGroup.liability);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('資産', style: theme.textTheme.labelLarge),
              for (final e in assets) Text('${accountNameOf(e.key)}  ${e.value}円'),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('負債・純資産', style: theme.textTheme.labelLarge),
              for (final e in liabilities) Text('${accountNameOf(e.key)}  ${e.value}円'),
              Text('資本金・利益  ${ledger.totalEquity}円'),
            ],
          ),
        ),
      ],
    );
  }
}

class _IncomeStatementTable extends StatelessWidget {
  const _IncomeStatementTable({required this.ledger});

  final CompanyLedger ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final revenues = ledger.entriesOf(AccountGroup.revenue);
    final expenses = ledger.entriesOf(AccountGroup.expense);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('収益', style: theme.textTheme.labelLarge),
        for (final e in revenues) Text('${accountNameOf(e.key)}  ${e.value}円'),
        const SizedBox(height: 8),
        Text('費用', style: theme.textTheme.labelLarge),
        for (final e in expenses) Text('${accountNameOf(e.key)}  ${e.value}円'),
        const Divider(),
        Text(
          '当期純利益  ${ledger.netIncome}円',
          style: theme.textTheme.titleMedium?.copyWith(
            color: ledger.netIncome >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
