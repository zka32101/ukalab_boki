import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:ukalab_core/ukalab_core.dart';

Future<List<Question>>? _questionsFuture;
Future<ExamConfig>? _examConfigFuture;
Future<List<Term>>? _termsFuture;
Future<List<CompanyScenario>>? _companyScenariosFuture;
Future<List<ChapterReading>>? _chapterReadingsFuture;

/// `assets/exam/boki3.questions.jsonl` を読み込み・パースする。
///
/// `PracticePage`・`RecordsPage`・`MockExamPage` がそれぞれ独立にこのファイルを
/// 読み込み・パースしていたのをここに集約し、アプリ起動中は結果をキャッシュして
/// タブを行き来するたびに再読み込みしないようにする（問題データは実行中に
/// 変わらない静的アセットのため、キャッシュして問題ない）。
Future<List<Question>> loadQuestions() {
  return _questionsFuture ??= _loadQuestions();
}

Future<List<Question>> _loadQuestions() async {
  final text = await rootBundle.loadString('assets/exam/boki3.questions.jsonl');
  final parsed = parseQuestionsJsonl(text);
  if (parsed.issues.isNotEmpty) {
    throw StateError('問題データの読み込みに失敗しました: ${parsed.issues}');
  }
  return parsed.questions;
}

/// `assets/exam/boki3.exam.json` を読み込む（同様にキャッシュする）。
Future<ExamConfig> loadExamConfig() {
  return _examConfigFuture ??= _loadExamConfig();
}

Future<ExamConfig> _loadExamConfig() async {
  final text = await rootBundle.loadString('assets/exam/boki3.exam.json');
  return ExamConfig.fromJson(jsonDecode(text) as Map<String, dynamic>);
}

/// `assets/exam/boki3.terms.jsonl`（用語集）を読み込み・パースする（同様にキャッシュする）。
Future<List<Term>> loadTerms() {
  return _termsFuture ??= _loadTerms();
}

Future<List<Term>> _loadTerms() async {
  final text = await rootBundle.loadString('assets/exam/boki3.terms.jsonl');
  final parsed = parseTermsJsonl(text);
  if (parsed.issues.isNotEmpty) {
    throw StateError('用語集データの読み込みに失敗しました: ${parsed.issues}');
  }
  return parsed.terms;
}

/// `assets/exam/boki3.company_scenarios.jsonl`（会社経営モード）を読み込み・
/// パースする（同様にキャッシュする）。
Future<List<CompanyScenario>> loadCompanyScenarios() {
  return _companyScenariosFuture ??= _loadCompanyScenarios();
}

Future<List<CompanyScenario>> _loadCompanyScenarios() async {
  final text = await rootBundle.loadString('assets/exam/boki3.company_scenarios.jsonl');
  final parsed = parseCompanyScenariosJsonl(text);
  if (parsed.issues.isNotEmpty) {
    throw StateError('会社経営モードのシナリオデータの読み込みに失敗しました: ${parsed.issues}');
  }
  return parsed.scenarios;
}

/// `assets/exam/boki3.readings.jsonl`（章ごとの解説読み物）を読み込み・パースする（同様にキャッシュする）。
///
/// 用語・問題への参照の実在確認は `test/readings_data_test.dart` で配信前に検証する。
Future<List<ChapterReading>> loadChapterReadings() {
  return _chapterReadingsFuture ??= _loadChapterReadings();
}

Future<List<ChapterReading>> _loadChapterReadings() async {
  final text = await rootBundle.loadString('assets/exam/boki3.readings.jsonl');
  final parsed = parseChapterReadingsJsonl(text);
  if (parsed.issues.isNotEmpty) {
    throw StateError('解説読み物データの読み込みに失敗しました: ${parsed.issues}');
  }
  return parsed.items.where((r) => !r.disabled).toList();
}
