import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:ukalab_core/glossary.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../exam_data/exam_data_cache.dart';

/// 「学ぶ」タブから開く用語集。一覧は core の [GlossaryListView]（検索・「覚えた」チェック・
/// 「すべて／覚えた／未習得」）。タップで解説をボトムシートに開く（決定50「専門用語の解説（全アプリ共通）」）。
///
/// [initialSubjectId]・[initialSubjectLabel] を渡すと、その科目（`Term.subjectId`）
/// かつ未習得の用語だけに絞った状態で開く（苦手科目カードからの導線向け）。
/// 「で絞り込み中 ×」で絞り込みを解除できる。
class TermListPage extends StatefulWidget {
  const TermListPage({super.key, this.initialSubjectId, this.initialSubjectLabel});

  final String? initialSubjectId;
  final String? initialSubjectLabel;

  @override
  State<TermListPage> createState() => _TermListPageState();
}

class _TermListPageState extends State<TermListPage> {
  late final Future<List<Term>> _termsFuture = loadTerms();
  final _learnedStore = LearnedTermsStore('boki3');

  @override
  Widget build(BuildContext context) {
    final subjectLabel = widget.initialSubjectLabel;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialSubjectId != null && subjectLabel != null ? '用語集（$subjectLabel）' : '用語集'),
      ),
      body: FutureBuilder<List<Term>>(
        future: _termsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
          if (snapshot.hasError) return ErrorState(message: '読み込みに失敗しました: ${snapshot.error}');
          return GlossaryListView(
            terms: snapshot.data!,
            store: _learnedStore,
            initialSubjectId: widget.initialSubjectId,
            initialSubjectLabel: subjectLabel,
            sortByTerm: false,
          );
        },
      ),
    );
  }
}
