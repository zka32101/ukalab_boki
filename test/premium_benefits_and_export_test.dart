import 'dart:convert';
import 'dart:typed_data';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_boki3/exam_data/exam_data_cache.dart';
import 'package:ukalab_boki3/exam_prep/exam_prep_entry.dart';
import 'package:ukalab_boki3/progress/progress_store.dart';
import 'package:ukalab_boki3/purchase/premium_benefits_section.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';


const _s = ExamPrepStrings.ja;

Future<void> _pumpSection(WidgetTester tester, {required bool premium}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      entitlementServiceProvider
          .overrideWithValue(FakeEntitlementService(initial: EntitlementState(hasPremium: premium))),
    ],
    child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PremiumBenefitsSection()))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PremiumBenefitsSection', () {
    testWidgets('無料のときは、実装済みのプレミアム機能だけを出す', (tester) async {
      await _pumpSection(tester, premium: false);
      expect(find.byType(PremiumBenefitsCard), findsOneWidget);
      for (final f in kBoki3PremiumFeatures) {
        expect(find.byKey(ValueKey('premiumBenefit_${f.name}')), findsOneWidget, reason: f.name);
      }
      // 未実装の機能は載せない。
      expect(find.byKey(const ValueKey('premiumBenefit_mockExamHistory')), findsNothing);
      expect(find.byKey(const ValueKey('premiumBenefit_customMockExam')), findsNothing);
      expect(find.byKey(const ValueKey('premiumFreeNote')), findsNothing);
      expect(find.text(PremiumBenefitsSection.note), findsOneWidget);
    });

    testWidgets('プレミアムのときは出さない', (tester) async {
      await _pumpSection(tester, premium: true);
      expect(find.byType(PremiumBenefitsCard), findsNothing);
      expect(find.text(PremiumBenefitsSection.note), findsNothing);
    });

    test('文言に「公式」「合格保証」「価格」を含まない', () {
      final texts = [
        PremiumBenefitsSection.note,
        for (final f in kBoki3PremiumFeatures) ...[
          PremiumBenefitsStrings.ja.benefits[f]!.name,
          PremiumBenefitsStrings.ja.benefits[f]!.description,
        ],
      ].join('\n');
      expect(texts, isNot(contains('公式')));
      expect(texts, isNot(contains('合格保証')));
      expect(texts, isNot(contains('円')));
    });
  });

  group('学習履歴の書き出し（ファイル保存）', () {
    Future<void> openExport(WidgetTester tester, FileSaver saver) async {
      final store = InMemoryProgressStore();
      await store.addRecord(
        ProgressRecord(qid: 'boki3-c-0001', subjectId: 'q2_choubo', correct: true, at: DateTime(2026, 10, 12, 9)),
      );
      await tester.runAsync(loadQuestions);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          entitlementServiceProvider
              .overrideWithValue(FakeEntitlementService(initial: const EntitlementState(hasPremium: true))),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExamPrepSettingsSection(
                progressStore: store,
                saver: saver,
                now: () => DateTime(2026, 10, 20, 8),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_s.exportTitle));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('コピーではなくダウンロード。BOM付き・text/csv・ukalab_history_YYYYMMDD.csv で渡す', (tester) async {
      Uint8List? savedBytes;
      String? savedName;
      String? savedMime;
      await openExport(tester, ({
        required Uint8List bytes,
        required String fileName,
        required String mimeType,
        Rect? sharePositionOrigin,
      }) async {
        savedBytes = bytes;
        savedName = fileName;
        savedMime = mimeType;
        return true;
      });
      expect(find.byKey(const ValueKey('copyCsv')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('downloadCsv')));
      await tester.pump();
      expect(savedName, 'ukalab_history_20261020.csv');
      expect(savedMime, 'text/csv');
      expect(savedBytes!.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final csv = utf8.decode(savedBytes!.sublist(3));
      expect(csv, contains('2026-10-12'));
      // 個人情報・端末情報・問題IDの列を持たない。
      expect(csv, isNot(contains('boki3-c-0001')));
      expect(find.text(_s.exportSaved), findsOneWidget);
    });

    testWidgets('保存に失敗したら案内を出す', (tester) async {
      await openExport(tester, ({
        required Uint8List bytes,
        required String fileName,
        required String mimeType,
        Rect? sharePositionOrigin,
      }) async => throw Exception('x'));
      await tester.tap(find.byKey(const ValueKey('downloadCsv')));
      await tester.pump();
      expect(find.text(_s.exportSaveFailed), findsOneWidget);
    });
  });
}
