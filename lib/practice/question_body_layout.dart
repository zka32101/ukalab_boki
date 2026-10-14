import 'package:flutter/material.dart';

/// 問題1問分の縦レイアウト。
///
/// 問題文・入力表・答え合わせ結果・解説など「長くなりうる部分」は [scrollChildren] に入れて
/// ひとつの縦スクロールにまとめ、テンキーと操作ボタンなど「常に手が届いてほしい部分」は
/// [bottomChildren] として下に固定する。
///
/// 以前は問題文や結果バナーがスクロールの外にあり、狭い画面や大きい文字では
/// 固定部分の合計が画面を超えて RenderFlex overflow（内容が切れて読めない）になっていた。
/// 下の固定部分も、画面の [bottomMaxFraction] を超えるときだけ内部でスクロールさせ、
/// 上のスクロール部分に必ず高さが残るようにする。
class QuestionBodyLayout extends StatelessWidget {
  const QuestionBodyLayout({
    super.key,
    required this.scrollChildren,
    required this.bottomChildren,
    this.bottomMaxFraction = 0.75,
  });

  final List<Widget> scrollChildren;
  final List<Widget> bottomChildren;

  /// 下の固定部分に許す高さの割合（画面＝このウィジェットに与えられた高さに対して）。
  final double bottomMaxFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = constraints.hasBoundedHeight ? constraints.maxHeight * bottomMaxFraction : double.infinity;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: scrollChildren,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: cap),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: bottomChildren,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
