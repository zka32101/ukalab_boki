import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_boki3/journal_input/account_catalog.dart';

/// 勘定科目カバレッジ（docs/account_title_coverage.md）の機械検証。
/// 新区分表の全科目が問題データの2問以上に登場すること、および
/// カバレッジ補完で追加した ai-draft 問題の規則を確認する。
const _metaKeys = {
  'qid',
  'examId',
  'subjectId',
  'topicId',
  'type',
  'source',
  'sourceRef',
  'contentVer',
  'tags',
};

// 動詞形・別科目名は科目名の一致から除外する（長い語を先に除去）。
const _maskWords = ['仕入れ', '売り上げ', '売上げ', '売上原価', '仕入先', '売上高'];

List<Map<String, dynamic>> _loadQuestions() {
  final lines = File('assets/exam/boki3.questions.jsonl')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty);
  return [
    for (final l in lines) jsonDecode(l) as Map<String, dynamic>,
  ];
}

void _collectCodes(Object? node, Set<String> out) {
  if (node is Map) {
    node.forEach((k, v) {
      if (k == 'account' && v is String) {
        out.add(v);
      } else {
        _collectCodes(v, out);
      }
    });
  } else if (node is List) {
    for (final e in node) {
      _collectCodes(e, out);
    }
  }
}

void _collectText(Object? node, StringBuffer out) {
  if (node is String) {
    out.writeln(node);
  } else if (node is List) {
    for (final e in node) {
      _collectText(e, out);
    }
  } else if (node is Map) {
    node.forEach((k, v) {
      if (!_metaKeys.contains(k)) _collectText(v, out);
    });
  }
}

Map<String, int> _coverage(List<Map<String, dynamic>> questions) {
  final byLength = [...boki3Accounts]
    ..sort((a, b) => b.name.length.compareTo(a.name.length));
  final counts = <String, int>{for (final a in boki3Accounts) a.code: 0};
  for (final q in questions) {
    final hit = <String>{};
    _collectCodes(q, hit);
    final buf = StringBuffer();
    _collectText(q, buf);
    var text = buf.toString();
    for (final w in _maskWords) {
      text = text.replaceAll(w, '□');
    }
    for (final a in byLength) {
      if (text.contains(a.name)) {
        hit.add(a.code);
        text = text.replaceAll(a.name, '■');
      }
    }
    for (final code in hit) {
      if (counts.containsKey(code)) counts[code] = counts[code]! + 1;
    }
  }
  return counts;
}

void main() {
  test('新区分表の全勘定科目が問題データの2問以上に登場する', () {
    final counts = _coverage(_loadQuestions());
    final lacking = {
      for (final e in counts.entries)
        if (e.value < 2) e.key: e.value,
    };
    expect(lacking, isEmpty, reason: '登場が2問未満の科目: $lacking');
  });

  test('カバレッジ補完で追加した18問は ai-draft 表記規則と禁止表現の規則を満たす', () {
    final questions = _loadQuestions();
    final byId = {for (final q in questions) q['qid'] as String: q};
    final addedIds = [
      for (var n = 145; n <= 153; n++) 'boki3-j-0$n',
      for (var n = 39; n <= 47; n++) 'boki3-c-00$n',
    ];
    expect(addedIds.length, 18);
    for (final id in addedIds) {
      final q = byId[id];
      expect(q, isNotNull, reason: '$id が存在しない');
      expect(q!['tags'], contains('ai-draft'), reason: id);
      expect(q['sourceRef'] as String, contains('AI下書き・要確認'), reason: id);
      final buf = StringBuffer();
      _collectText(q, buf);
      buf.write(q['sourceRef']);
      final text = buf.toString();
      for (final w in ['公式', '本試験相当', '合格保証']) {
        expect(text.contains(w), isFalse, reason: '$id に禁止表現「$w」');
      }
    }
  });

  test('全仕訳問題は貸借が一致し、選択式は正解インデックスが範囲内で選択肢が重複しない', () {
    final questions = _loadQuestions();
    for (final q in questions) {
      final id = q['qid'] as String;
      if (q['type'] == 'journal') {
        var debit = 0;
        var credit = 0;
        for (final l in q['journalAnswer'] as List) {
          final m = l as Map<String, dynamic>;
          final amount = m['amount'] as int;
          if (m['side'] == 'debit') {
            debit += amount;
          } else {
            credit += amount;
          }
        }
        expect(debit, credit, reason: '$id の貸借不一致');
      } else if (q['type'] == 'choice') {
        final choices = (q['choices'] as List).cast<String>();
        final idx = q['answerIndex'] as int;
        expect(idx >= 0 && idx < choices.length, isTrue, reason: '$id の answerIndex');
        expect(choices.toSet().length, choices.length, reason: '$id の選択肢重複');
      }
    }
  });

  test('qid の重複がなく、全 journal の勘定科目コードがカタログに存在する', () {
    final questions = _loadQuestions();
    final ids = [for (final q in questions) q['qid'] as String];
    expect(ids.toSet().length, ids.length);
    final known = {for (final a in boki3AccountsLegacy) a.code};
    for (final q in questions) {
      if (q['type'] != 'journal') continue;
      final codes = <String>{};
      _collectCodes(q['journalAnswer'], codes);
      expect(known.containsAll(codes), isTrue, reason: '${q['qid']}: 未定義の科目 ${codes.difference(known)}');
    }
  });
}
