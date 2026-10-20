import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart';

import '../exam_data/exam_data_cache.dart';
import '../mistake_note/mistake_note_page.dart';
import '../progress/progress_store.dart';
import '../reading/reading_list_page.dart';
import '../term/term_list_page.dart';

/// 「学ぶ」タブ下部の「道具」。間違いノート・用語集・解説読み物・メモ（ブックマーク）への入口。
/// 以前、間違いノートはホームの「道具」にあった。見出し名は ukalab_it_passport / ukalab_infosecmanage の「学ぶ」と同じ。
class LearnToolsSection extends StatelessWidget {
  const LearnToolsSection({super.key, required this.progressStore});

  final ProgressStore progressStore;

  Widget _entry({required IconData icon, required String label, required Widget page, required BuildContext context}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
            icon: Icon(icon),
            label: Align(alignment: Alignment.centerLeft, child: Text(label)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return HomeSection(
      title: '道具',
      subtitle: '調べる・見返す',
      leading: const Icon(Icons.handyman_outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(child: MistakeNoteTile(progressStore: progressStore)),
          const SizedBox(height: 8),
          const StudyNotesHomeCards(loadQuestions: loadQuestions),
          const SizedBox(height: 8),
          _entry(context: context, icon: Icons.menu_book_outlined, label: '用語集', page: const TermListPage()),
          _entry(
            context: context,
            icon: Icons.auto_stories_outlined,
            label: '章ごとの解説読み物',
            page: ReadingListPage(progressStore: progressStore),
          ),
        ],
      ),
    );
  }
}
