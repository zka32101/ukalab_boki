# うかラボ 簿記3級

日商簿記検定3級の学習アプリ（非公式）。日本商工会議所・各地商工会議所とは関係ありません。

## スコープの方針（簿記2級・AFPなど）

簿記2級は**別アプリ**にする方針（2026-10-10、方針転換。旧方針は「このアプリに含める」だった。
詳細は`docs/boki2_expansion_design.md`の検討経緯を参照）。journal/ledger/worksheet型の入力UI・
勘定科目エンジン・採点ロジックは共用できる見込みのため、`ukalab_core`・`app_common_kit`という
共通エンジンはそのまま再利用する想定（モノレポの元々の設計思想どおり）。一方で2級は科目構成
（3科目→5科目）・工業簿記という新ドメインが加わり、`ExamConfig`の構成が3級とは別物になるため、
このリポジトリに同居させず別アプリ（別リポジトリ）として作る方が既存設計と整合する。
2026-10時点ではまだ着手していない。

AFP・FP技能士など簿記と異なるドメインの資格も**別アプリ**にする方針。選択式・計算問題が中心で、
今回作り込んだ仕訳・帳簿・精算表の入力UIがほぼ使えず、勘定科目一覧などのドメイン知識も無関係。
ASOキーワード・ブランドが混ざるのを避けるため。ただし`ukalab_core`・`app_common_kit`という
共通エンジンはそのまま再利用する想定（モノレポの元々の設計思想どおり）。2026-10時点ではまだ着手していない。

## 構成と依存

```
ukalab-boki3（このリポジトリ） → yourwish_kentei（検定エンジン） → app_common_kit（共通基盤）
```

このリポジトリは「ExamConfig・問題データ・テーマ・ストア設定」だけを持つ薄いリポジトリとして保つ方針です。
依存は `pubspec.yaml` で `ref: vX.Y.Z` のタグ固定（`main` は参照しない）。

| リポジトリ | タグ |
|---|---|
| `zka32101/app_common_kit` | v0.10.0 |
| `zka32101/yourwish_kentei` | v0.13.0 |

タグ作成（この環境からの `git push --tags` はネットワークプロキシにHTTP 403で拒否される）は、
`yourwish_kentei` リポジトリに追加した `.github/workflows/create-tag.yml`（workflow_dispatch、
手動トリガーのみ）経由で行う。`tag_name`・`target_sha`・`message` を入力して実行すると、
CI上でタグを作成・pushできる。`yourwish_kentei` は他プロジェクトとも共有する依存のため、
バージョン番号が他セッションの変更と衝突することがある（実例: v0.11.0は別の変更が先に
使用していたため、本リポジトリの変更はv0.12.0とした）。タグ作成前に `git fetch --tags` で
既存タグと重複しないか確認すること。

## 開発時の表示確認手順（ヘッドレスブラウザ）

このリポジトリの開発はクラウド上のコンテナ内で行っており、本物のスマホ・PC実機やユーザーの手元環境は
使えない。これまでのログで「実機確認」と書いてきた箇所は、正確には**コンテナ内にプリインストールされた
Chromiumをヘッドレスモードで動かし、スクリーンショットで見た目を確認したもの**であり、実機ではない
（フォントレンダリング・実際のタッチ操作・画面サイズのばらつきなどは反映されない）。手順は以下の通り。

1. `export PATH="/opt/flutter/bin:$PATH"` でflutterコマンドを有効化する（`PATH`にデフォルトで
   入っていない。「root権限で実行している」という警告は無視してよい）。
2. `flutter build web --release` でビルドする。デバッグビルドや素のreleaseビルドはCanvasKitを
   `gstatic.com` のCDNから取得しようとするが、このコンテナのネットワークポリシーでブロックされ
   `ERR_TUNNEL_CONNECTION_FAILED` になる。ローカルにCanvasKitを同梱させるため、必ず
   `--release` でビルドする。
3. `build/web/flutter_bootstrap.js` 内の `_flutter.loader.load({...})` 呼び出しに
   `config: { canvasKitBaseUrl: "canvaskit/" }` を手動で追記するパッチを当てる（ローカル同梱版を
   参照させるため）。`build/web` は`.gitignore`対象でビルドのたびに作り直されるため、**ビルドする
   たびに毎回このパッチを当て直す必要がある**（当て忘れるとCanvasKit読み込み失敗で画面が真っ白になる）。
4. `python3 -m http.server 8766` で `build/web` を配信する。Bashツールでは `(cd build/web &&
   nohup python3 -m http.server 8766 > /tmp/http_server.log 2>&1 &)` のようにサブシェル＋
   バックグラウンド実行にしないと、フォアグラウンドのまま張り付いてタイムアウトする。
5. Python版Playwright（`PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers`、
   `executable_path="/opt/pw-browsers/chromium"`）でヘッドレスChromiumを起動し、
   `http://localhost:8766/` を開く。CanvasKit描画のため `find.text()` のようなDOMテキスト取得は
   機能せず、操作は `page.mouse.click(x, y)` の座標クリックで行う。確認は `page.screenshot(path=...)`
   で撮った画像をReadツールで見て行う（コンソールエラー・pageerrorも`page.on("console"/"pageerror")`
   で拾って確認するとよい）。
6. 確認用に一時的に `lib/main.dart` の `PracticePage(...)` 呼び出しへ `restrictToQids: {特定qid}` を
   足して特定の問題に固定する手法が、特定の問題タイプ（choice型など）をすぐ出すのに有効。確認が終わったら
   必ず元に戻す。

## 現状（2026-10-04時点）

- `pubspec.yaml`・`assets/exam/boki3.exam.json`（ExamConfig）・最小限の `lib/main.dart` のみ
- 問題データ（JSONL）は `assets/exam/boki3.questions.jsonl` に289問作成済み（2026-10-28時点の実数: journal型175・choice型55・trueFalse型16・ledger型13・cloze型12・worksheet型10・reverseLookup型8。以下は初期作成時の内訳メモ: journal型106問・choice型27問・worksheet型10問・ledger型8問（商品有高帳〈移動平均法〉1問、現金出納帳2問、当座預金出納帳1問、得意先元帳〈売掛金元帳〉1問、仕入先元帳〈買掛金元帳〉1問、仕入帳1問、売上帳1問）。固定資産の買換え、貸付金・借入金の利息天引き、固定資産税の見越し計上を追加。理論（choice型）は仕訳日計表・試算表の目的・主要簿の分類・転記の定義などの帳簿組織に関する問題を追加。定率法による減価償却（2027年度版で新規追加された項目。未償却残高×償却率で計算し、定額法と異なり年数が経つほど金額が小さくなる点を扱う。簡易な出題にとどめる方針に合わせ、計算の分かりやすい例題のみ）を仕訳2問・理論1問追加。固定資産の除却・廃棄および販売のつど売上原価勘定に振り替える方法は、勘定科目一覧にない科目（固定資産除却損・貯蔵品・売上原価）を要するため、科目一覧を独断で拡張しない方針により見送り。固定資産の購入・売却損益、前払金・前受金・仮払金・仮受金・未収入金・未払金・貸付金・預り金・小口現金、受取家賃・地代、貸倒損失・償却債権取立益・貸倒引当金戻入、法人税等、繰越利益剰余金の配当、売上原価の算定（しいくり）、電子記録債権・電子記録債務の発生〜決済、クレジット売掛金・受取商品券の精算、差入保証金、定期預金、当座借越、未払消費税の決算整理、雑損・雑益、費用の見越し（未払費用）、増資、仕入・売上の諸掛り（引取運賃・発送費）、証ひょう読み取りバリエーション、仕入戻し・売上戻り・仕入値引き・売上値引き、通貨代用証券（他人振出小切手・送金小切手・郵便為替証書）、資本的支出・収益的支出の区別、固定資産の期中取得（減価償却の月割り計算）、収入印紙の処理、精算表の貸倒引当金設定・減価償却と未払費用の複合パターン・消費税の決算整理・決算整理なしの基礎パターン・売上原価の算定（しいくり）・法人税等の計上（決算整理で新規計上するため残高試算表欄は空欄になるパターン）・貸倒引当金/減価償却/消費税を1枚にまとめた総合精算表・定率法による減価償却などをカバー。理論（choice型）は貸借対照表・損益計算書の区分、精算表の仕組み、減価償却の要素、伝票の種類、証ひょうの分類、勘定記入の法則、試算表の種類、仕入戻しの処理方向、通貨代用証券、資本的支出の定義なども追加。出典欄 `sourceRef` に根拠の区分表項目を明記。`test/questions_data_test.dart` で出典必須・貸借一致・ExamConfigとの整合性を機械検証）。過去問の転載はしない方針
- 第2問・第3問の出題形式の設計は `docs/question_types_v1_design.md`。精算表・財務諸表の穴埋めは `QuestionType.worksheet`（`yourwish_kentei` v0.10.0、PR#13）として実装・マージ済み
- 簿記3級に必須の「仕訳タイプ（借方・貸方の勘定科目＋金額を入力する表形式）」は `yourwish_kentei`（`QuestionType.journal`・`JournalLine`・`JournalAnswer`・`judgeJournal`）で実装済み。`PracticeSession`（演習セッション）のjournal対応（`answerJournal`）・worksheet対応（`answerWorksheet`）も実装・マージ済み（v0.9.1〜v0.10.0、PR#11・#13）
- `assets/exam/boki3.questions.jsonl` の仕訳（journal型）・理論（choice型）・精算表（worksheet型）問題を `PracticeSession` で連続出題する画面 `lib/practice/practice_page.dart` を実装。精算表入力UIは `lib/worksheet_input/`（表形式・セル選択・テンキー入力・セル単位の正誤表示、`lib/journal_input/` と対になる構成）。「学ぶ」タブの「問題を練習する（問題集）」から開ける。Playwrightで実機確認済み（journal/choice/worksheet混在、精算表5セル全入力→正解判定まで確認、console error 0件）
- 精算表（worksheet型）の入力セルを選択すると、横スクロールした先（画面外）にあっても自動でスクロールして見える位置まで追従する（`WorksheetTable` が `Scrollable.ensureVisible` を使用）。`test/worksheet_autoscroll_test.dart` でオフセット変化を検証
- 精算表（worksheet型）に、貸倒引当金の差額補充法設定と減価償却を組み合わせた総合決算整理パターン（blankCells 10個）を追加し、単一の決算整理事項だけだった既存問題から出題の難易度幅を広げた
- 「模擬」タブから、本試験形式（`level3_from_2027_04`：15問・60分・合格ライン総合70%、科目別出題数は仕訳10/帳簿伝票3/決算2）で1回通しで解く模擬試験モード `lib/mock_exam/mock_exam_page.dart` を実装。本試験と同じく解答中は正誤を表示せず、全問解答後に `yourwish_kentei` の `pickMockExamQuestions`・`scoreMockExam` でまとめて採点し、総合点・科目別得点・合否を表示する。`JournalQuestionView`・`ChoiceQuestionView`・`WorksheetQuestionView` に `revealResult: false` を追加し、模擬試験では即答で正誤を見せずに次の問題へ進めるようにした。`test/mock_exam_page_test.dart` で開始〜全15問解答〜結果表示までを検証
- `PracticePage`（「問題を練習する（問題集）」）の結果画面に「間違えたN問を復習する」ボタンを追加。`PracticeSession.records` から不正解だった qid を集め、`PracticePage(restrictToQids: ...)` でその問題だけに絞った復習セッションを開く（`test/practice_page_review_test.dart` で検証）
- 演習・模擬試験の解答を `lib/progress/progress_store.dart`（`SharedPreferences` による端末内保存）に記録し、ホーム画面に科目別の正答率カード `lib/progress/progress_summary_card.dart` を表示するようにした。正答率70%未満の科目は「苦手科目」として警告アイコン付きで強調する。`test/progress_summary_test.dart`・`test/progress_summary_card_empty_test.dart`・`test/progress_summary_card_filled_test.dart` で検証
- 間隔反復（直近で不正解のまま放置されている問題を優先出題する）を `lib/progress/review_priority.dart`
  （`reviewPriorityQids`）で実装。既存の解答記録（`ProgressStore.loadRecords()`）から、各qidの最新の
  解答が不正解だったものを抽出し、不正解のまま最も長く放置されている順に並べる。`yourwish_kentei` の
  `PracticeSession` には元々 `priorityQids`（出題順の先頭に優先出題する仕組み）が用意されていたが
  アプリ側では未使用だったため、新しいエンジン実装は不要だった。「問題を練習する（問題集）」を開く
  たびに `PracticePage._loadSession()` で計算し、優先出題中の問題には「苦手な問題を復習中」の表示を
  出す。`test/review_priority_test.dart`（優先順位の計算ロジック）・
  `test/practice_page_review_priority_test.dart`（実際に先頭に出題されることを確認）で検証
- 下部ナビの「記録」タブ（従来は `準備中` のプレースホルダー）を `lib/records/records_page.dart`
  （`RecordsPage`）として実装。科目別正答率カード（ホーム画面と同じ `ProgressSummaryCard`）に加え、
  間隔反復で復習待ちになっている問題の一覧と、まとめて復習セッションを開くボタンを表示する。
  実装の過程で2つの不具合を発見・修正した。(1) 下部タブは `app_common_kit` の `UkalabShell` が
  `IndexedStack` で管理しており、一度マウントされたタブは破棄・再ビルドされないため、起動時に
  読み込んだデータのまま固定され、他のタブで新しい解答記録を追加しても自動的には反映されなかった
  （`ProgressSummaryCard` も同じ不具合を抱えていたため合わせて修正）。`lib/progress/progress_revision.dart`
  の `ValueNotifier<int>`（解答記録が追加されるたびに増える版数）をリッスンし、変化があれば
  明示的に読み直す形で解決した。(2) 模擬試験の結果画面（`MockExamPage._finish()`）が出題数ぶん
  （15件）の `addRecord` を `unawaited` で並行に呼んでいたため、`SharedPreferencesProgressStore`
  の読み込み→追記→書き込みが競合し、ほとんどの記録が失われていた。`await` で順番に書き込む形に修正。
  `test/records_page_empty_test.dart`・`test/records_page_review_test.dart`・
  `test/records_page_live_update_test.dart`（タブを再マウントせずに自動更新されることを確認）で検証。
  `flutter build web` + Playwrightで実機確認（記録タブを開いたまま演習で1問不正解にし、タブに
  戻らず裏側のナビゲーションだけで正答率・復習待ち一覧が自動更新されることを確認、console error 0件）
- 下部ナビの「設定」タブ（従来はアプリ説明のみの静的ページ）に、解答記録をリセットする機能を追加。
  `ProgressStore` に `clearRecords()` を追加し（`SharedPreferencesProgressStore`・`InMemoryProgressStore`
  両方に実装）、`lib/settings/settings_page.dart`（`SettingsPage`）から確認ダイアログを経て呼び出す。
  リセット後は `progressRevision` を進め、ホーム・記録タブが開いたままでも正答率・復習待ち一覧が
  即座に空へ更新される。`test/settings_page_test.dart`（キャンセル時は削除されないこと・確定時に
  削除されリセット完了のスナックバーが出ることを確認）で検証。`flutter build web` + Playwrightで
  実機確認（確認ダイアログ→リセット→スナックバー表示まで、console error 0件）
- 「学ぶ」タブに科目別の練習モードを追加。`PracticePage` に `subjectId`（絞り込み）・`title`
  （AppBarタイトルの上書き）パラメータを追加し、第1問 仕訳／第2問 帳簿・伝票等／第3問 決算の
  いずれかだけを集中的に解けるようにした（従来は147問全部をまとめて1セッションにするか、
  「間違えた問題を復習する」の qid 絞り込みしかできなかった）。開発確認用だった「仕訳の問題を試す
  （サンプル）」ボタン（固定1問・`ProgressStore` に記録されない）は実用上の価値が薄いため削除し、
  科目選択ボタンに置き換えた。`test/learn_subject_practice_test.dart` で検証。実装の過程で、
  widget テストから実機相当の `SharedPreferencesProgressStore`（`appProgressStore`）を経由する画面を
  開くとテスト環境にプラグイン実体がなく `MissingPluginException` になる問題に気づき、
  `SharedPreferences.setMockInitialValues({})` を使うよう修正（従来は `ProgressStore` に依存しない
  静的な画面しかフルアプリ経由でテストしていなかったため表面化していなかった）。
  `flutter build web` + Playwrightで実機確認（科目選択→該当科目のみ出題されることを確認、
  console error 0件）
- 模擬試験の結果画面（`MockExamPage` の `_MockExamResultView`）に「間違えた問題を復習する」ボタンを
  追加。`PracticePage._ResultView` と同じパターンで、不正解だった qid を集めて
  `PracticePage(restrictToQids: ...)` の復習セッションを開く（従来は模擬試験後にそのまま復習に
  入る導線がなく、「記録」タブの間隔反復に頼るしかなかった）。`test/mock_exam_page_test.dart` に
  復習ボタンのタップ〜復習セッション開始までの検証を追加
- 「設定」タブにライト／ダーク／端末設定の3択で表示モードを切り替える機能を追加。
  `lib/settings/theme_mode_store.dart` の `ValueNotifier<ThemeMode>`（`appThemeMode`）を
  `SharedPreferences` で永続化し、`MaterialApp` の `themeMode` に直接バインドする
  （`MaterialApp` 自体がリスナーのため、`IndexedStack` でマウントされたままの他タブにも
  選択直後に反映される）。起動時は `main()` で `loadSavedThemeMode()` を await してから
  `runApp` するため、誤った配色が一瞬表示されるちらつきが起きない。
  `test/theme_mode_test.dart` で検証（保存・復元・不正値のフォールバック・設定タブでの
  切り替えでMaterialAppのthemeModeが変わること）。`flutter build web` + Playwrightで
  実機確認（設定タブで「ダーク」を選ぶと即座に全体に反映され、他タブへ移動しても
  維持されることを確認、console error 0件）
- 問題データ（`boki3.questions.jsonl`・`boki3.exam.json`）の読み込みキャッシュを
  `lib/exam_data/exam_data_cache.dart`（`loadQuestions`・`loadExamConfig`）に集約。従来は
  `PracticePage`・`RecordsPage`・`MockExamPage`・`ProgressSummaryCard` の4箇所がそれぞれ
  独立に同じファイルを読み込み・パースしており、タブを行き来するたびに147問のJSONLを
  再パースしていた。アプリ起動中は最初の呼び出し結果（`Future`）をキャッシュして使い回す
  ようにし、2回目以降の表示を高速化した。`test/exam_data_cache_test.dart`
  （2回目の呼び出しが同じFutureインスタンスを返すことを確認）で検証。`flutter build web` +
  Playwrightで実機確認（初回の「問題を練習する」表示まで約1.5秒かかっていたのが、タブを
  行き来して再度開くと0.5秒未満で表示されることを確認、console error 0件）
- 模擬試験の結果画面に「解答結果の詳細を見る」ボタンを追加し、`lib/mock_exam/mock_exam_review_page.dart`
  （`MockExamReviewPage`）で全問の正誤・自分の解答・正解・解説をまとめて振り返れるようにした。
  「間違えた問題を復習する」（解き直し）とは別に、本試験前に「どこをどう間違えたか」を確認できる
  画面がなかったギャップを埋める。新しいデータモデルは追加せず、出題した `Question` リストと
  解答記録（`Map<String, Object?>`）に対して `judgeJournal`・`judgeWorksheet`・`judgeLedger` を
  再計算するだけで実現し、各問題種別の表示は既存の `JournalResultBanner`・`WorksheetResultBanner`・
  `LedgerResultBanner`（journal/worksheet/ledger型の入力画面で使っているものをそのまま再利用）＋
  choice型用に新規の簡易表示で構成した。`test/mock_exam_page_test.dart` にレビュー画面を開いて
  1問目・15問目（スクロール）・不正解表示までを検証する手順を追加。`flutter build web` +
  Playwrightで全タブ巡回のスモークテストを実施（console error 0件）。15問の対話的な自動操作は
  （選択肢の座標が問題文の行数で変動し自動化コストが高いため）widgetテストでの検証で代替した
- 第2問の伝票記入（入金・出金・振替伝票）を、実際の伝票の見た目で再現する専用UI `lib/voucher_input/`
  （`VoucherQuestionView`）を追加。新しい `QuestionType` は増やさず、既存の `journal` 型データを
  そのまま使う（`topicId` が `voucher_payment`/`voucher_receipt`/`voucher_transfer` の問題だけ
  `PracticePage`・`MockExamPage` 側で判定して切り替える）。入金伝票・出金伝票は、現金側が伝票の
  種類から自明（入金伝票は借方が現金、出金伝票は貸方が現金）なため、実物の伝票と同じく相手科目・
  金額の2項目だけを入力させる簡易フォームにし、現金側は自動的に補って通常の仕訳判定（`judgeJournal`）
  にかける。振替伝票は現金の受け払いを伴わないため、既存の `JournalQuestionView`（借方・貸方の
  表形式入力）をそのまま使い、見た目だけ伝票風の枠（`VoucherSlipFrame`）に入れる。配色は実物の
  伝票の慣習（入金伝票は赤系、出金伝票は青系、振替伝票は黒系の用紙）に合わせた。
  `test/voucher_question_view_test.dart` で3種類とも検証済み。`flutter build web`・ローカルの
  CanvasKitアセット・Playwrightで実機のレンダリングも確認（3種類の配色・簡易フォーム・通常の
  仕訳テーブルがそれぞれ正しく表示され、console error 0件）
- 第2問の証ひょう読み取り問題（`topicId: voucher_reading`）向けに、領収書・請求書などの記載内容を
  書類風のカードで表示する `lib/evidence_input/`（`EvidenceQuestionView`）を追加。新しい画像アセット
  は使わず、既存の `prompt` テキスト（`「品名A 5個×1,000円＝5,000円、...」` のように証ひょうの内容を
  `「」` で囲む自作ルールで統一済み）をパースして、経緯の説明文・証ひょう風カード（タイトル・項目・
  合計の強調表示）・短縮した指示文の3つに分解表示する（`EvidenceDocument.parseEvidenceDocument`）。
  `「」` で囲まれていない問題（証ひょうの内容を地の文だけで説明しているもの）は、通常の
  `JournalQuestionView` にそのままフォールバックする。本格的な画像添付（写真・PDF）はアセット管理・
  採点ロジックへの影響が未検討なトレードオフがあるため見送り、既存のテキストデータだけで実現できる
  範囲にとどめた。`test/evidence_document_test.dart`（パース）・`test/evidence_question_view_test.dart`
  （表示・採点・フォールバック）で検証済み。`flutter build web` + Playwrightで実機のレンダリングも
  確認（領収書・納品書（兼請求書）・「」なしフォールバックの3パターンとも正しく表示、console error 0件）
- 第2問の補助簿記入（商品有高帳・現金出納帳など）向けに `QuestionType.ledger`（`yourwish_kentei` v0.12.0）を実装。`LedgerCell`（記入行×列グループ〈受入/払出/残高〉×項目〈数量/単価/金額〉）の `givenCells`/`blankCells` を `judgeLedger` でセル単位に採点する、`worksheet` 型と同じ設計パターン。入力UIは `lib/ledger_input/`（`WorksheetTable` と対になる構成、`LedgerTable`・`LedgerQuestionView` など）。商品有高帳（移動平均法）・現金出納帳・得意先元帳（売掛金元帳）・仕入先元帳（買掛金元帳）・仕入帳・売上帳の問題を計7問追加し、`PracticePage`・`MockExamPage` 双方で出題・採点できる（仕入帳・売上帳は `issue`/`balance` を使わず `receipt` のみの帳簿で、列フィルタリングが単一グループでも正しく動くことを兼ねて確認）。設計の詳細は `docs/question_types_v1_design.md`（Phase 2）。先入先出法で複数ロットが並存する一般ケースはPhase 2.5として先送り。`test/ledger_question_view_test.dart` で商品有高帳（数量・単価・金額の9列）・現金出納帳（金額のみ3列）それぞれ全セル入力→正解判定までを検証
- `yourwish_kentei` v0.4.0では `LevelConfig.subjectQuestionCounts`（科目別の出題数配分）も追加された（別PR）。簿記3級の大問別出題数に使える
- 推し・コイン・衣装・学習体験の「型」は共通仕様（`app_common_kit` v0.2.0）を適用可能だが、簿記固有の学習体験の「型」9部品はまだ `yourwish_kentei` 側に実装されていない
- 仕訳入力UI（表形式テーブル・科目リストボックス・テンキー）の設計は `docs/journal_input_ui_v0.md`。実装はまず `ukalab-boki3` 側（`lib/journal_input/`）で行う方針
- 勘定科目一覧は `docs/accounts_v1_official.md`（確定版 v1。商工会議所の公式出題区分表PDF（2026-07-31最終改定、2027-04-01施行）をユーザーが提供し、照合済み。ただし2026年度中〜2027年3月実施分の旧区分表はまだ一次資料未入手）
- `/code-review` でこれまでの変更（補助簿記入の設計〜精算表データ拡充まで）をレビューし、見つかった不具合3件を修正した。
  (1) `MockExamPage._finish()` に二重実行ガードを追加。制限時間切れのTimerと最終問題の「次へ」連打がほぼ同時に
  発生すると、出題数ぶんの `addRecord`（読み込み→追記→書き込み）が並行実行され記録が壊れる恐れがあった
  （`test/mock_exam_double_finish_test.dart` で回帰テスト、修正前に実際に30件へ壊れることを確認してから修正）。
  (2) `VoucherSlipFrame`（入金・出金・振替伝票の枠）が `Colors.red.shade50` など固定のMaterial色を使っており、
  後から追加したダークモードで背景が明るいまま・文字が白のままになり低コントラストになっていた不具合を修正
  （`Theme.of(context).brightness` を見て、ダーク時は濃い用紙色＋ライトモードと同じアクセント色にする）。
  (3) `parseEvidenceDocument`（証ひょうカードのパーサー）が `lastIndexOf('」')` を使っており、将来
  `「」` で囲んだ語句が2箇所以上ある問題文では無関係な区間まで証ひょうの内容に巻き込む可能性があった
  （現行データでは未発生）。最初に閉じる `」` だけを使うように修正し、回帰テストを追加。
  なお、`LedgerInputController` が `WorksheetInputController` とほぼ同じロジックを重複して持っている点も
  指摘されたが、両方とも独立にテスト済みで動作しているため、リスクに見合わないと判断し今回は見送った。
- 第2問の補助簿記入（ledger型）問題データを4問追加（計12問）。worksheet型と同様に手薄だったため拡充した。
  既存の帳簿種別（得意先元帳・仕入先元帳・現金出納帳・当座預金出納帳）に、返品（売上戻り・仕入戻し）や
  出資の受入・雑収入など、既存パターンよりやや応用的な取引を組み込んだバリエーションを追加
  （`accounts_receivable_ledger_return`・`accounts_payable_ledger_return`・`cash_book_capital`・
  `checking_account_book_variation`）。既存の `LedgerCell`（`receipt`/`issue`/`balance` グループ）の
  スキーマのまま表現できることを確認済み。先入先出法（複数ロット並存）は従来どおりPhase 2.5として先送り。
- 第1〜2問向けのchoice型（定義・分類の知識問題）を4問追加（計31問）。既存の資産/負債分類問題とは異なる科目
  （前受収益・電子記録債権など経過勘定・電子記録債権等）、税抜方式の消費税の仮受消費税の分類、費用の勘定の
  増減ルール（資産と同じ借方増加）を取り上げ、既存トピックと重複しないよう設計した
  （`classification_accrued_accounts`・`classification_electronic_records`・
  `consumption_tax_account_nature`・`account_rule_expense`）。
- ゲーミフィケーション要素として、連続学習日数（ストリーク）表示を追加（`lib/progress/streak_store.dart`）。
  `SharedPreferences` に最終学習日・連続日数のみを保存する軽量な仕組みで、`ProgressStore` とは独立。
  演習・模擬試験で解答を記録するたび `recordStudyToday()` を呼び、前日から続けていれば+1、
  2日以上空いていれば1から数え直す（同じ日に何度呼んでも加算しない）。表示は後述の `StreakBadge`
  （`app_common_kit`）差し替えにより、0日でも「今日から始めよう」と前向きな文言で常に出す形になっている。
  `test/streak_store_test.dart`（日付ロジック）・`test/progress_summary_card_streak_test.dart`・
  `test/progress_summary_card_streak_zero_test.dart`（表示）で検証済み。なお `ProgressSummaryCard` が
  `SharedPreferences` に依存するようになったため、これを使う既存の6テストファイル
  （模擬試験・練習・記録タブ関連）に `setMockInitialValues({})` を追加する必要があった。
- 「共通基盤に実装したほうが良いモノの洗い出し」をユーザーに依頼され、`app_common_kit`（v0.2.0）の
  `ui_kit/` を実際に読んで確認したところ、ukalab-boki3側が気づかず独自実装してしまっていたUI部品が
  複数見つかった。見た目の一貫性とコード量削減のため、以下を共通コンポーネントに差し替えた。
  - `StreakBadge`（`ProgressSummaryCard`の自作🔥表示を差し替え。「0日でも責めない」設計のため、
    0日のときは「今日から始めよう」と常時表示する仕様に変わった）
  - `ChoiceTile`/`ChoiceState`（`choice_question_view.dart`の自作`_ChoiceTile`を差し替え。
    選択肢に「ア・イ・ウ・エ」のラベルが付くようになった）
  - `ResultSummary`+`ProgressRing`（`practice_page.dart`の演習結果画面`_ResultView`を差し替え。
    「正解 n / m問」→「n / m 問正解」の文言変化に合わせて`test/practice_page_review_test.dart`を修正）
  - `EmptyState`/`ErrorState`（`records_page.dart`の「復習が必要な問題はありません」・読み込み失敗表示を差し替え）

  見送った項目とその理由:
  - `ExplanationPanel`：choice/journal/ledger/worksheetの各`ResultBanner`は「正誤ヘッダー＋詳細差分＋
    解説」を1枚のカードで表示する自作パターンで統一されている。`ExplanationPanel`は単体で完結した
    Cardウィジェットのため、無理に組み込むとカードの中にカードが入る二重構造になり見た目が崩れる。
    4箇所とも自作パターンのまま統一しておく方が一貫性がある。
  - `ResultSummary`（`mock_exam_page.dart`側）：模擬試験の結果は配点ベース（◯点/◯点）で、
    `ResultSummary`が前提とする「correct/total問正解」という単純な正答数ベースの構造と合わない
    （科目別の足切り判定なども表示しており、そのまま置き換えると情報が失われる）。
  - `QuestionCard`：5種類あるQuestionView（journal/ledger/worksheet/voucher/evidence）すべての
    問題文表示に影響する変更になり、各画面のレイアウト前提（Expanded内のスクロール計算など）への
    影響範囲が大きいため、今回は見送った。
  - `app_common_kit`側に既にある「StreakBadgeの表示」と対になる「ストリークの永続化ロジック」が
    まだない、`ProgressStore`・間隔反復（`review_priority.dart`）・ダークモード切替の永続化
    （`theme_mode_store.dart`）・問題データのロード＋キャッシュ（`exam_data_cache.dart`）・
    `IndexedStack`配下のタブ間リアクティブ更新パターン（`progressRevision`）など、検定の種類を
    問わず必要になる汎用ロジックがukalab-boki3側に留まっている。これらを`app_common_kit`・
    `yourwish_kentei`に上げる作業は今回のスコープ外（差し替えではなく新規の共通化のため）。
- 上記で見送った共通化のうち、永続化ロジック4点（`theme_mode_store.dart`・`streak_store.dart`・
  `ProgressStore`/`ProgressRecord`・`review_priority.dart`）を実際に`app_common_kit`・`yourwish_kentei`
  へ移した（`exam_data_cache.dart`・`progressRevision`パターン・模擬試験レビュー画面のテンプレート化は
  今回も見送り、理由は下記の通り）。
  - `app_common_kit`（v0.2.0→v0.10.0、PR [#63](https://github.com/zka32101/app_common_kit/pull/63)）:
    `lib/theme/theme_mode_store.dart`（`appThemeMode`/`loadSavedThemeMode`/`setThemeMode`）・
    `lib/progress/streak_store.dart`（`recordStudyToday`/`loadCurrentStreak`、既存の`StreakBadge`と
    対になる永続化ロジック）を追加。
  - `yourwish_kentei`（v0.12.0→v0.13.0、PR [#26](https://github.com/zka32101/yourwish_kentei/pull/26)）:
    `lib/progress/progress_record.dart`（`ProgressRecord`/`ProgressStore`(抽象)/`InMemoryProgressStore`）・
    `lib/progress/review_priority.dart`（`reviewPriorityQids`）を追加。永続化の具体実装
    （`SharedPreferences`依存）はFlutterプラグインに依存するため、純Dart方針の`yourwish_kentei`には
    置かず、引き続きukalab-boki3側（`SharedPreferencesProgressStore`）に残した。
  - 調査の過程で、`yourwish_kentei`に**既に本格的な間隔反復エンジン**（`Srs`/`SrsItem`、Leitner方式の
    箱システム）が実装済みだったことが判明した。`reviewPriorityQids`（直近不正解を放置期間順に並べる
    だけの単純な版）とは設計が異なり（`Srs`は専用の永続化状態`SrsItem`が必要）、無理に統合すると
    復習間隔の挙動が変わりユーザー体験に影響するため、**今回は統合せず別物として共存**させた。
  - `app_common_kit`にはタグ作成用のworkflow（`yourwish_kentei`の`create-tag.yml`相当）が無かったため、
    同じ仕組みを追加した（PR [#64](https://github.com/zka32101/app_common_kit/pull/64)）。このクラウド
    環境からの`git push --tags`はネットワークプロキシにHTTP 403で拒否されるため、`workflow_dispatch`
    経由でタグを作成する。
  - ukalab-boki3側は、重複していた`lib/settings/theme_mode_store.dart`・`lib/progress/streak_store.dart`・
    `lib/progress/review_priority.dart`を削除し、`lib/progress/progress_store.dart`は
    `SharedPreferencesProgressStore`（具体実装）だけを残して`ProgressRecord`/`ProgressStore`の定義は
    `yourwish_kentei`からexportし直す形にした（`export 'package:ukalab_core/ukalab_core.dart'
    show ...`）。これにより、直接`yourwish_kentei`をimportしている他ファイルとの間でambiguous import
    にならない。単体テスト（`streak_store_test.dart`・`review_priority_test.dart`・`theme_mode_test.dart`
    の一部）は移植先の各パッケージ側で重複してテスト済みのため削除し、ukalab-boki3固有の統合テスト
    （UIが実際に表示・動作することの確認）だけ残した。`flutter analyze`0件・`flutter test`（39件）成功、
    `app_common_kit`v0.10.0同梱でのWebビルド成功、ヘッドレスブラウザでの表示確認（ホーム画面の
    `StreakBadge`・設定タブの表示モード切替、console error 0件）も実施済み。
- `/code-review`で上記の共通基盤移行をレビューし、見つかった不具合を修正した。
  (1) `SharedPreferences`のキー名が`ukalab_boki3_theme_mode`等（アプリ固有）から
  `app_common_kit_theme_mode`等（パッケージ共通）に変わったことで、移行コード無しでは既存ユーザーの
  ダークモード設定・学習ストリークが無言でリセットされる不具合があった。`lib/startup/legacy_key_migration.dart`
  （`migrateLegacyProgressKeys()`）を追加し、`main()`の起動時に旧キーの値を新キーへ一度だけコピーする
  移行処理を入れた（新キーに既に値があれば何もしない、2回呼んでも安全）。`test/legacy_key_migration_test.dart`
  で検証済み。
  (2) `app_common_kit`が単一のbarrel export（`app_common_kit.dart`）で`entitlement`（RevenueCat）・
  `stats`（Firebase）・`ads`（Google Mobile Ads）を無条件にexportしているため、v0.10.0への更新で
  ukalab-boki3が使わない`cloud_firestore`・`firebase_core`等が新たに依存に加わった。現時点では
  iosのプラットフォームディレクトリが無く（androidは追加済み）ネイティブビルドをしていないため問題は顕在化していないが、
  将来これらを追加してネイティブビルドする際、Firebase設定（`google-services.json`等）が無いとビルドが
  失敗する可能性がある。`app_common_kit`側でexportを機能ごとに分割する設計変更が必要になるため、
  今回は見送り、既知の技術的負債として記録するに留めた。
- C分類（簿記特有の入力UI、`lib/journal_input/`・`lib/ledger_input/`・`lib/worksheet_input/`・
  `lib/voucher_input/`・`lib/evidence_input/`、計約3150行）も洗い出した。簿記ドメイン知識
  （勘定科目・借方貸方・仕訳の概念）に強く依存する約13ファイルは簿記2級アプリ内に限定、
  `numeric_keypad.dart`や`*_input_state.dart`/`*_input_controller.dart`など約6ファイルは
  セル参照の型を汎用化すればドメインを問わず転用できる構造だった。`*_table.dart`・
  `*_question_view.dart`など約8ファイルはジェネリクス化すれば汎用化できる中間的な構造。
  共通基盤（yourwish_kentei等）に上げるのは簿記2級アプリが実在して恩恵を確認できてからにする
  方針は変えないが、調査の過程で以前「リスクに見合わないため見送った」と記録していた
  `LedgerInputController`と`WorksheetInputController`の重複が**ほぼ1行単位で同一**だったことが
  判明したため、ukalab-boki3内でDRY化した。
  - `lib/cell_grid_input/`（新規）にセル参照型`C`をジェネリクスにした`CellGridInputState<C, Self>`・
    `CellGridInputController<C, Self>`を追加。テンキー操作（桁追加・000・バックスペース・クリア・
    桁数上限99999999）とセル選択・次の未入力セルへの自動遷移という、両コントローラで文字通り
    同一だったロジックをここに集約した。`Self`はF-bounded polymorphism（`class Foo extends
    CellGridInputState<C, Foo>`という自己参照）で、`copyWithGrid`が具象の状態クラスを保ったまま
    複製できるようにしている。
  - `LedgerInputController`/`WorksheetInputController`・`LedgerInputState`/`WorksheetInputState`は、
    基底クラスを継承する薄いラッパーに縮小（`LedgerInputState`は`toLedgerCells()`、
    `WorksheetInputState`は`toWorksheetCells()`と`amountAt()`〈`valueAt()`の別名〉だけを残した）。
    呼び出し側（`*_table.dart`・`*_question_view.dart`）はクラス名・プロバイダ名・メソッド名を
    一切変えていないため無修正で動く。
  - `test/cell_grid_input_controller_test.dart`で基底クラスのロジック（セル選択・テンキー入力・
    桁数上限・次セルへの自動遷移）を直接検証。`flutter analyze`0件・`flutter test`（47件）成功、
    Webビルド＋ヘッドレスブラウザでの表示確認（精算表のセル選択→テンキー入力→「次へ」で次の
    未入力セルへ自動遷移、console error 0件）も実施済み。

## 2027年4月の配点変更

2027年4月1日以降に施行する3級は配点が 45/25/30（従来 45/20/35）に変わる（日商が2026-09-25発表、
合格ラインは70点のまま据え置き。直近の第174回〈2026-11-15〉は旧配点）。
`assets/exam/boki3.exam.json` では `level3_until_2027_03`（旧配点）と `level3_from_2027_04`（新配点）の
2つの level を用意し、`lib/exam_data/current_level.dart` の `currentLevelId({now})` が2027-04-01を境に
どちらを使うか自動判定する（`lib/mock_exam/mock_exam_page.dart` が起動時に呼ぶ）。

当初このデータ構造だけ用意して「切り替えられる設計にした」と書いていたが、実際には
`mock_exam_page.dart` が `level3_from_2027_04` を決め打ちしており、切り替えロジックが存在しなかった
（ユーザーからの指摘で判明）。あわせて、`scoreMockExam`（`yourwish_kentei`）の満点は `exam.json` の
`name` に書いた「45/25/30」という表示ラベルではなく、各問題の `points` フィールドの合計で決まる設計
だったため、全159問が `points: 1` のままでは実際の満点が出題数（旧15問→20問）そのままになり、
表示と乖離していた不具合も見つかった。

旧配点は新配点用に作った既存の問題データをそのまま流用する方針（ユーザー判断）とし、以下を実装した。

- 45:25:30 の最大公約数5で単純化した `9:5:6`（合計20問）を新配点の `subjectQuestionCounts` に、
  同様に45:20:35を単純化した `9:4:7`（合計20問）を旧配点に設定。全問題の `points` を1→5にすることで、
  `points` の型（int）を変えずに「出題数配分を変えるだけ」で正しい100点満点を実現できる
  （9問+5問+6問=20問×5点=100点、9+4+7=20問×5点=100点）。
  `test/mock_exam_level_pool_test.dart` で、両levelとも科目別の必要数ぶん問題が揃っていることを検証。
- 問題データの `levelId` フィールドを削除（null化）し、新旧どちらのlevelでも同じ問題プールを共有する
  （`Question.levelId` は null なら全levelで出題対象、という既存の仕様どおり）。
  `mock_exam_page.dart` の出題プール選択も `q.levelId == null || q.levelId == level.levelId` に変更。
  なお、`lib/journal_input/account_catalog.dart` に「〜2027年3月実施分は旧区分表が適用される」という
  コメントが以前から残っており、本来は旧配点時代の出題範囲（勘定科目等）が新配点時代と異なる可能性が
  あるが、今回は配点・出題数の調整のみにとどめ、勘定科目一覧や問題内容そのものの作り分けはしていない
  （ユーザー指示どおり「既存データを流用」）。
- `currentLevelId({DateTime? now})` はテスト用に時刻を注入できる。`test/current_level_test.dart` で
  2027-03-31／2027-04-01の境界・2026-11-15（第174回）を検証。
- 出題数が15→20問に変わったため、`test/mock_exam_page_test.dart`・`test/mock_exam_double_finish_test.dart`
  の件数も合わせて更新。
- `currentLevelId()` 単体の日付ロジックだけでなく、実際の試験日程を踏まえて `MockExamPage` のイントロ画面
  （配点の表示文言・出題数）が正しく切り替わることも統合テストで確認した。`MockExamPage` に
  `now`（テスト用、省略時は実時刻）を追加し、`currentLevelId(now: widget.now)` に渡す形にした。
  - `test/mock_exam_174th_date_test.dart`：第174回試験日（2026-11-15、統一試験）は旧配点
    「配点45/20/35」・20問で表示される
  - `test/mock_exam_scoring_cutover_before_test.dart`：施行前日（2027-03-31）はまだ旧配点のまま
  - `test/mock_exam_scoring_cutover_after_test.dart`：施行日当日（2027-04-01）から新配点
    「配点45/25/30」に切り替わる

  次回（175回以降）の正確な試験日はまだ分からないため、175回固有の日付ではなく施行日そのものを境界に
  検証している。3件とも同一ファイルに書くと原因不明のタイムアウトが起きたため、1テスト1ファイルに
  分割した（これまでの他のテストでも繰り返し踏んできたFlutter Webテストの既知の制約）。
  `flutter analyze` 0件・`flutter test`（58件）成功、Webビルド＋ヘッドレスブラウザでの表示確認
  （現在日時で模擬試験の導入画面に「3級（〜2027年3月実施・配点45/20/35）」「出題数: 20問」が
  表示されることを確認、console error 0件）も実施済み。

  **TODO対応（2026-10-08、Web検索で判明）**: 第175回の統一試験日は**2027年2月28日**（日）。
  これは配点変更の施行日（2027-04-01）より前のため、**第175回はまだ旧配点45/20/35のまま**で
  実施される（当初このREADMEでは「第175回＝新配点の初回」と想定していたが誤りだった。新配点の
  初回になるのは次の第176回〈2027年6月頃と推測されるが、日商からの公式発表は未確認〉）。
  `test/mock_exam_175th_date_test.dart`を新規追加し、第175回試験日（2027-02-28）で旧配点
  45/20/35・20問のまま表示されることを確認した。第176回の正確な日程が判明したら、同様に
  `test/mock_exam_176th_date_test.dart`等で新配点での表示を確認するテストを追加する。
  `flutter analyze` 0件・`flutter test`（76件）成功

## 旧区分表（2022年度版）向け勘定科目の実装（2026-10-09追加）

- ユーザーがGoogle Driveで提供した一次資料を基に、`lib/journal_input/account_catalog.dart`に
  旧区分表（2022年4月1日施行、`level3_until_2027_03`向け）の勘定科目一覧
  `boki3AccountsLegacy`（新区分表`boki3Accounts`＋`boki3LegacyOnlyAccounts`）を追加した
- `boki3LegacyOnlyAccounts`は受取手形・支払手形・現金過不足・損益の4科目。手形は紙媒体の廃止に
  伴い2027年4月以降は出題されなくなるため`boki3Accounts`からは除外している。**3級の出題範囲は
  手形の振出・受入・支払のみで、裏書・割引は2級以上の範囲**（2026-10-09、ユーザー確認済み）
- `accountNameOf`は新区分表・旧区分表どちらの科目コードも解決できるようにマップを拡張した
- `test/account_catalog_legacy_test.dart`を追加（科目差分・重複なし・グループ分類・検索の確認）。
  `flutter analyze` 0件・`flutter test`（82件）成功
- **残課題**: `assets/exam/boki3.exam.json`の`level3_until_2027_03`向け問題データ（手形の振出・
  受入・支払を扱う仕訳問題）はまだ1問もない。科目一覧の追加だけでは演習素材として機能しないため、
  問題データの拡充が次のステップ

## 旧区分表向けの手形問題を追加（2026-10-09追加・その2）

- `assets/exam/boki3.questions.jsonl`に手形の仕訳問題6問（`boki3-j-0107`〜`0112`、
  `levelId: "level3_until_2027_03"`）を追加。仕入代金としての振出・売上代金としての受入・
  手形代金の支払/取立・買掛金の支払いに代えた振出・売掛金の回収に代えた受入の6パターン。
  3級の出題範囲（振出・受入・支払のみ、裏書・割引は2級以上）に沿い、全て貸借一致を確認済み
- 実装してみて、**科目一覧を追加しただけでは問題が解けない**ことが分かった。`JournalQuestionView`の
  科目ピッカーはデフォルトで新区分表の`boki3Accounts`しか見せないため、受取手形・支払手形が
  選択肢に出ない状態だった。`JournalInputTable`・`JournalQuestionView`に`accountPool`引数を追加し、
  `PracticePage`・`MockExamPage`で問題の`levelId`が`level3_until_2027_03`なら`boki3AccountsLegacy`
  （手形を含む）を渡すようにして解決した
- `PracticePage`に`levelId`フィルタを追加（`q.levelId == null || q.levelId == currentLevelId()`）。
  `restrictToQids`指定時（復習セッション）は、過去の出題当時の問題をそのまま見られるようこの
  フィルタを適用しない。`now`（テスト用の時刻注入）パラメータも追加した
- `test/practice_page_level_filter_test.dart`（データレベルのフィルタ検証）・
  `test/practice_page_legacy_level_ui_test.dart`・`practice_page_legacy_level_ui_before_test.dart`
  （2027年4月の前後で出題数が88→82問に変わることのUI確認）・
  `test/journal_question_view_legacy_pool_test.dart`・`journal_question_view_default_pool_test.dart`
  （科目ピッカーに`accountPool`が正しく伝わることの確認）を追加。`flutter analyze` 0件・
  `flutter test`（89件）成功、Webビルド＋ヘッドレスブラウザでの表示確認（手形問題の表示、科目ピッカーで
  「支払手形」を検索・選択できることを確認、console error 0件）も実施済み

## 2027-04施行 出題区分改訂に伴う既存データの修正（2026-10-28、AI下書き・専門家確認前）

- 手形（受取手形・支払手形）は2027年4月以降の3級の範囲外。手形に言及する新範囲向けの文言を修正した:
  `j-0011`の解説から「紙の手形に代わる」を削除、`c-0028`の選択肢「受取手形」を「電子記録債権」に差し替え
  （正解は「前受収益」のまま不変）、用語`t-018`から手形への言及を削除、用語`t-037`（受取手形・支払手形）は
  用語データにlevelId相当の仕組みが無いため削除せず、定義冒頭に「旧区分表向け・2027年4月以降は範囲外」と明記
- 定率法（`j-0105`・`j-0106`・`c-0027`・`w-0010`）は2級→3級へ移行した項目のため`level3_from_2027_04`に限定
  （旧範囲〜2027年3月の出題プール 289→285問、新範囲 273問のまま）
- 現金過不足（`levelId: level3_until_2027_03`付き7問: j-0115〜0119・j-0172・j-0173）は**未変更・要確認**。
  確定版区分表では3級に残るが、`boki3Accounts`に`cash_over_short`が未登録のため、限定を外すだけでは
  新範囲で科目ピッカーから選べない。科目追加（Dart側）とセットで別PRとする
- 変更した行の`contentVer`は`2026.10.0`→`2026.10.1`

## 問題データの網羅性チェック（2026-10-11）

- 新区分表（2027年4月以降）の勘定科目69個のうち、仕訳問題で使われていない科目を機械的に
  抽出したところ、**支払家賃（`rent_expense`）・支払地代（`land_rent_expense`）を使う仕訳問題が
  1問も無い**ことが判明（対になる受取家賃・受取地代は出題済みだった）。`boki3-j-0113`・
  `boki3-j-0114`として追加した
- 補助簿（ledger型）のカバレッジも確認したところ、商品有高帳・現金出納帳・得意先元帳・
  仕入先元帳・仕入帳・売上帳・当座預金出納帳の7種はあるが、**小口現金出納帳**が無かった。
  `boki3-l-0013`として追加した（既存の`cash_book`と同じ受入/支払/残高の構造で表現できた）
- **固定資産台帳**も抜けていたが、既存の`LedgerColumnGroup`（受入・支払・残高の3区分固定）・
  `WorksheetColumn`（精算表専用8列固定）のどちらにも固定資産台帳の列構成（取得日・取得価額・
  減価償却累計額・未償却残高）が収まらないと判断し、帳簿記入形式のUIは見送った。代わりに
  「固定資産台帳は何を記録する補助簿か」という選択式問題（`boki3-c-0032`）で仕組みの理解を
  問う形にした。帳簿記入形式で出題したい場合は新規UI型の設計が必要（将来の検討課題）
- 用語集（`boki3.terms.jsonl`）は15語のみで、155トピックに対してかなり少ないことも分かった
  → **対応済み（2026-10-11）**。貸倒引当金・貸倒引当金繰入・電子記録債権・電子記録債務・
  仮払消費税・仮受消費税・現金過不足・商品有高帳・得意先元帳・仕入先元帳・当座借越・資本金・
  繰越利益剰余金・損益・仕訳日計表・転記・前払金・前受金・仮払金・仮受金の15語（`t-016`〜`t-030`）
  を追加し、計30語にした。既存15語との重複がないよう選定し、`relatedTermIds`の相互参照も
  整合することを確認済み
- 4問追加した結果、選択式問題の正解位置の分布が8/8/7/8→8/8/8/8の完全均等になった（新規の
  選択式問題1問の正解位置を調整）。出題プールは90問（旧区分表）/84問（新区分表、第1問のみ）に
  増加。`flutter analyze` 0件・`flutter test`（99件）成功（出題数が変わった既存2テストを更新）

## 選択式問題（choice型）の正解位置のばらつきチェック（2026-10-10）

- `boki3.questions.jsonl`の選択式問題（全31問、全て4択）で、正解の位置（`answerIndex`）を
  集計したところ、1番目の選択肢（index 0）に正解が偏っていた（12問・39%）一方、3番目
  （index 2）はわずか3問（10%）しかなく、「最初の選択肢を選ぶ」戦略が通用してしまう状態だった
- 問題文・正解の文言は変えず、選択肢の並び順のみ入れ替えて6問（`boki3-c-0014`・`0019`・`0021`・
  `0023`・`0025`・`0030`）の`answerIndex`を調整。結果、分布は index0:8問・index1:8問・
  index2:7問・index3:8問（31問、ほぼ均等）に改善した
- `flutter test`（`test/questions_data_test.dart`含む全96件）で品質ゲート・既存テストとも
  影響なしを確認済み

## 並行開発の統合（2026-10-10）

- 別セッションで進んでいた9件のコミットを`git pull --no-rebase`で取り込んだ（コンフリクトなし）。
  主な変更点:
  - 共通エンジンパッケージが`yourwish_kentei`から`ukalab_core`（v0.22.0）に改名。
    全`import 'package:yourwish_kentei/...'`が`import 'package:ukalab_core/...'`に置き換わった
  - `app_common_kit`がv0.24.0に更新（`PurchaseSection`/`ExamDateTile`等）
  - 課金機能（`purchases_flutter`、`entitlementServiceProvider`、弱点ドリル`weak_drill_card.dart`）、
    ながら学習モード（`flutter_tts`による読み上げ、`lib/hands_free/`配下）が追加
  - CI（`.github/workflows/ci.yml`）・E2E（`e2e/`）が追加
- 統合後、`flutter pub get`・`flutter analyze`（0件）・`flutter test`（96件成功）で検証済み。
  このセッションで実装した旧区分表向け勘定科目・手形問題・`accountPool`切り替え・電卓案内は、
  上記の課金機能・ながら学習モードとも問題なく共存している

## 未決・要確認（企画設計書 第6章より）

1. ~~ネット試験の解答入力方式とアプリの入力UIの合わせ方~~ → **調査済み（2026-10-08、Web検索）**。
   ネット試験（CBT方式）は勘定科目をプルダウン（科目名そのものの選択、コードの手入力ではない）で選び、
   金額はキーボードで数値を直接入力する。採点は仕訳単位で部分点なし（借方・貸方すべての科目・金額が
   一致して正解）。アプリの`journal_input`（`AccountPickerSheet`での科目名検索・選択＋テンキーでの
   金額入力、`judgeJournal().isCorrect`が全行一致を要求）は、この操作・採点方式と本質的に一致している。
   見た目は検索付きボトムシート（ネット試験の実機はプルダウン）だが、「科目名をリストから選ぶ」という
   操作の本質は同じで、検索機能は学習アプリとしての使いやすさの付加価値。相違点は、アプリでは答え合わせ
   後に科目違い・金額違い・貸借逆などの行ごとの誤りを個別に表示する点（ネット試験は合否のみ）で、これは
   学習効果を高めるための意図的な差分（企画設計書3-2）。精算表（worksheet型）はネット試験でも手入力の
   空欄があるとされ、アプリのセル直接入力方式と同様。問題画面への書き込みができず計算用紙を使う点は
   アプリでは未対応（画面内メモ機能等は現時点で検討していない）。
   出典: [日商簿記検定試験 ネット試験の操作方法（TAC）](https://www.tac-school.co.jp/kouza_boki/tacchannel/tGRuZO4BkFk.html)、
   [日商簿記のネット試験（CBT方式）とは（STUDYing）](https://studying.jp/boki/about-more/cbt01.html)
2. 公式の出題区分表（現行版）の取得と科目一覧への落とし込み → **2027年4月以降向けは対応済み**
   （2026-10-03、ユーザーが公式PDFを直接提供し`docs/accounts_v1_official.md`に確定版を作成済み）。
   2026年度中（〜2027年3月実施分）向けの旧区分表についても、**勘定科目一覧の一次資料（2026-10-08、
   Google Drive）・コードへの反映（2026-10-09、`account_catalog.dart`の`boki3AccountsLegacy`）まで
   対応済み**。手形の裏書・割引は3級の範囲外（2級以上、2026-10-09ユーザー確認）であることも明記した。
   **問題データの作成・出題への反映も対応済み**（2026-10-09）: 手形の仕訳問題6問を追加し、
   `levelId`に応じた出題フィルタ・科目ピッカーの切り替えまで実装した（詳細は上記「旧区分表向けの
   手形問題を追加」を参照）。**残課題**: 出題区分表そのもの（階層構造を持つ原本）はまだ未入手
3. 「日商簿記」の表記の可否（商標・誤認）、J-PlatPat・専門家確認 → **部分的に調査（2026-10-08、
   Web検索）、最終判断は未了**。「日商簿記」は正式名称「日本商工会議所及び各地商工会議所主催簿記検定
   試験」の略称・通称として広く使われている。App Store等で「日商簿記」を商品名・説明文に含む民間の
   非公式アプリが多数公開されている実例を確認でき（例:「日商簿記検定3級 仕訳マラソン」等）、通称の
   使用自体は一定の商慣行として行われている傍証にはなる。一方、**J-PlatPat（特許情報プラットフォーム）
   での「日商簿記」の商標登録の有無・区分の直接確認はできなかった**（このセッションのネットワーク
   ポリシー上、`j-platpat.inpit.go.jp`への直接アクセスが遮断されており、検索エンジン経由でも
   データベース検索結果は拾えなかった）。本アプリは既にアプリ名を「うかラボ 簿記3級」とし、README
   冒頭で「非公式」と明記する対応は取っているが、**商標権侵害・誤認（公式アプリと誤解される表示）の
   リスクの最終判断には、J-PlatPatでの実地検索と弁理士・弁護士への相談が引き続き必要**
4. ~~問題の出典（過去問の著作権。自作・自動生成を基本にする）~~ → **対応済み（運用中）**。
   問題（`boki3.questions.jsonl`）・用語（`boki3.terms.jsonl`）・会社経営モードのシナリオ
   （`boki3.company_scenarios.jsonl`）すべてで `source`（`original`/`statute`/`licensed`）・
   `sourceRef`（根拠の説明）を必須とし、過去問の転載はせず自作・出題区分表ベースの例題のみを収録する
   方針で統一。各データの配信前検証（`validateQuestions`・`validateTerms`・`validateCompanyScenarios`）
   で出典の欠落を機械チェックし、`test/questions_data_test.dart`・`test/terms_data_test.dart`・
   `test/company_scenarios_data_test.dart`で継続的に検証している
5. ~~統一試験・ネット試験の日程（第175回の日程が判明したら〜）~~ → **第175回は判明・対応済み**
   （2026-10-08、Web検索。2027年2月28日、まだ旧配点のまま。上記「2027年4月の配点変更」参照）。
   **残課題**: 第176回（新配点45/25/30の初回になる見込み）の正確な日程は、2026-10-10のWeb検索で
   「2027年6月13日（日）」という情報が複数の予備校サイト（広告・掲示板）で見つかったが、**日商の
   公式発表ではなく信頼度が低い**（1級受験案内での言及が中心で、2・3級も同日実施かは確証がない）。
   誤った日付でテストを追加するとかえって混乱するため、公式発表の確認が取れるまでテスト追加は見送る。
   同日、再度Web検索で確認したが状況に変化なし。1件の検索結果に「2級・3級は統一試験ではなくネット
   試験に移行」という記述があったが、再検索で1級だけがネット試験の対象外（統一試験のみ残る）という
   文脈の誤読と判断した。東京・名古屋など一部の商工会議所で2・3級の紙の統一試験が廃止されている
   事実はあるが、全国一律の廃止は確認できず地域差がある（出題区分表自体は統一試験・ネット試験で
   共通のため、アプリの実装方針には影響しない）
   ネット試験は通年実施のため日程という概念がなく対応不要
6. ~~会社経営モードの無料範囲~~ → **対応済み（2026-10-10、Phase 4）**。別セッションの統合で
   アプリ全体の課金導線が実装されたため、最初の2シナリオ（カフェどんぐり・雑貨屋ことり）を無料、
   残り3シナリオ（フリーランス事務所・法律事務所つくし・卸売商事にじいろ）をプレミアム限定に
   変更した。詳細は`docs/company_mode_v1_design.md`「有料化の実装（2026-10-10、Phase 4）」を参照
7. 本試験に持ち込める電卓の条件、ネット試験の画面構成 → **調査済み（2026-10-08、Web検索）**。
   - **電卓**: プリンター・音声（メロディー）・辞書・文字入力・自動記憶などの機能がない、計算機能のみの
     シンプルな電卓に限って持ち込み可。関数電卓・金融電卓は不可。日数計算・時間計算・検算機能は可。
     統一試験・ネット試験とも**実物の電卓を手元に用意して使う**方式で、PC画面内蔵の電卓機能があるわけ
     ではない（ネット試験でもスマートフォン・タブレットは電卓としても不可）。
   - **ネット試験の画面構成**: 問題文・解答欄は同一のPC画面に表示され、マウス（勘定科目のプルダウン
     選択）とキーボード（金額の数値入力）で解答する。画面（問題文）への書き込みはできず、計算・メモは
     会場で配布される用紙に手書きで行う。日本商工会議所・資格予備校（TAC等）が公式の体験プログラムを
     公開しており、実際の画面操作を確認できる。
   - **アプリへの反映 → 対応済み（2026-10-10）**: 模擬試験（`MockExamPage`）の導入画面に「本試験
     （統一試験・ネット試験とも）では電卓を実機で持ち込んで使います。このアプリに電卓機能はないため、
     お手元の電卓を使って解いてみましょう。」という案内を追加した。本試験の電卓持ち込み条件自体を
     アプリ側で強制することはせず、案内のみにとどめている。`test/mock_exam_calculator_notice_test.dart`
     で表示を検証済み。`flutter analyze` 0件・`flutter test`（90件）成功。ヘッドレスブラウザでの表示
     確認は、模擬試験画面のみ原因不明の描画欠落（変更前のコードでも再現する既存の環境依存の問題で、
     今回の変更が原因ではないことを確認済み）が起きたため見送り、ウィジェットテストでの検証に留めた
8. 簿記2級の追加 → **方針転換・対応済み（2026-10-10）**。検討の結果、2級は**別アプリ**にする
   方針に転換した（当初は「このアプリに含める」方針だったが、商業簿記・工業簿記の両方を検討対象に
   既存アーキテクチャ（`QuestionType`・`AccountDef`・`ExamConfig`）の再利用性を調査したところ、
   科目構成が3科目→5科目＋新ドメインと大きく変わり、このリポジトリに同居させるより別アプリ
   （別リポジトリ）として作る方が既存設計と整合すると判断した）。`ukalab_core`・`app_common_kit`
   という共通エンジンは別アプリでも再利用する想定。**このリポジトリでの実装は対象外**になったため、
   以降は未着手のまま。詳細な検討経緯は`docs/boki2_expansion_design.md`を参照

## 用語集機能（2026-10-08追加）

- 専門用語の解説（決定50「専門用語の解説（全アプリ共通）」）を簿記3級アプリにも導入。`yourwish_kentei`の
  `Term`モデル・`term_validator.dart`、`app_common_kit`の`TermCard`/`showTermCard`（既存の汎用コンポーネント）
  をそのまま再利用し、ukalab-boki3側は用語データと一覧画面のみを新規実装した
- `assets/exam/boki3.terms.jsonl`に15語を作成（仕訳・複式簿記・借方・貸方・試算表・精算表・貸借対照表・
  損益計算書・減価償却・減価償却累計額・売掛金・買掛金・補助簿・伝票・証ひょう）。全て`source: "original"`、
  出典は商工会議所出題区分表ベース
- `lib/exam_data/exam_data_cache.dart`に`loadTerms()`を追加（既存のJSONLキャッシュパターンを踏襲）
- `lib/term/term_list_page.dart`（`TermListPage`）を新規実装。検索フィールドで絞り込み可能な一覧から
  `showTermCard`で詳細（①ひとことで言うと→②正確な意味→③たとえ話→④よくある間違い→⑤関連用語→⑥関連問題）
  を開ける。関連用語をタップすると再帰的に別の用語カードへ遷移できる
- 「学ぶ」タブに「用語を調べる」セクションと「用語集」ボタンを追加して導線を用意
- `test/terms_data_test.dart`（データ品質検証）・`test/term_list_page_test.dart`（一覧→カード表示）・
  `test/term_list_page_search_test.dart`（検索絞り込み）・`test/learn_term_list_navigation_test.dart`
  （「学ぶ」タブからの導線）を追加。`flutter analyze` 0件・`flutter test`（63件）成功、Webビルド＋
  ヘッドレスブラウザでの表示確認（「学ぶ」タブ→「用語集」ボタン→一覧表示まで、console error 0件）も実施済み
- ついでに`test/progress_summary_card_streak_test.dart`の既存バグ（`DateTime(2026, 10, 6)`という絶対日付
  ハードコードのため、実行日が進むにつれてテストが壊れていた）を発見し、相対日付指定に修正した

### 用語集の拡張（2026-10-08追加・その2）: 「覚えた」チェック＋フィルタ、解説からの用語集連携

- `TermListPage`の各行にチェックボックスを追加し、「覚えた」用語の`termId`を`lib/term/learned_terms_store.dart`
  （`LearnedTermsStore`、`SharedPreferences`永続化。`SharedPreferencesProgressStore`と同じ「永続化の具体実装
  だけをukalab-boki3側に持つ」パターン）に保存するようにした。一覧上部に「すべて／覚えた／未習得」の
  `SegmentedButton`を追加し、未習得の用語だけに絞って復習できる
- 演習・模擬試験の答え合わせ後に表示される解説文（`journal`/`choice`/`worksheet`/`ledger`の各
  `*ResultBanner`、模擬試験振り返り画面`MockExamReviewPage`）から、用語集の見出し語を検索・リンクできる
  ようにした。`lib/term/explanation_with_terms.dart`（`ExplanationWithTerms`）が解説文の中に含まれる
  見出し語を`Term`一覧との文字列マッチで検出し、タップで`showTermCard`を開くチップとして解説の下に添える。
  **設問文・選択肢にはチップを出さない**（答える前に用語が分かるとヒントになってしまうため、答え合わせ後の
  解説にのみ表示する設計上の制約）
- `TermListPage`と`ExplanationWithTerms`で重複していた「`relatedTermIds`を解決して`showTermCard`を開き、
  関連用語タップで次のカードへ遷移する」ロジックを`lib/term/term_card_opener.dart`（`openTermCard`関数）に
  共通化した
- `test/term_list_learned_filter_test.dart`（チェック→フィルタの確認）・
  `test/explanation_with_terms_test.dart`（設問中はチップなし→解答後にチップが出てタップでカードが開く
  ことの確認）を追加。`flutter analyze` 0件・`flutter test`（65件）成功

### 設計思想のメモ（他機能にも展開したい方針）

- **既存の汎用コンポーネントは自分で作り直さず再利用する**: `Term`/`TermCard`/`showTermCard`は
  `yourwish_kentei`・`app_common_kit`（全アプリ共通ライブラリ）側に既にあったため、ukalab-boki3側は
  用語データ（JSONL）とそれをつなぐ薄い画面・ロジックだけを足した。アプリ固有の実装を増やさない
- **「教材／解説コンテンツの中の重要語」を、独立した一覧画面だけでなく、学習の文脈（解説文）からも
  たどれるようにする**という横展開可能なパターン。データ同士を明示的なID参照で結ばず、既存の文字列
  （用語の見出し語）の出現を検出して自動的にリンクを張る軽量な方式を採用した。Question側に
  `relatedTermIds`のような新しいフィールドを追加する（yourwish_kentei側の変更が要る）よりコストが低く、
  将来語彙を追加・修正してもリンクが自動的に追従する利点がある
- **「ヒントになる場所には出さない」という表示タイミングの制約を明示する**: 解答前（設問文・選択肢）には
  絶対に出さず、答え合わせ後（解説）にのみ出す。学習支援機能を追加するときは、それが正解を導くヒントに
  ならないかを毎回検討する
- **「覚えた／未習得」のようなユーザー自身の進捗管理は`SharedPreferences`で端末内完結させる**
  （`LearnedTermsStore`は`SharedPreferencesProgressStore`と同じ最小限の実装パターン）。サーバー同期は
  将来の検討事項とし、今は作らない

### 苦手科目から用語集への連携（2026-10-08追加・その3）

- ホーム画面・記録タブの科目別正答率カード（`ProgressSummaryCard`）で正答率70%未満（苦手科目）になった
  科目の行に「用語集で復習する」ボタンを追加した。タップすると、その科目（`Term.subjectId`）かつ
  未習得の用語だけに絞った`TermListPage`が開く
- `assets/exam/boki3.terms.jsonl`の15語のうち`subjectId`未設定だった9語（仕訳・複式簿記・試算表・精算表・
  貸借対照表・損益計算書・減価償却・補助簿・証ひょう）に、出題区分表上の分類（仕訳／帳簿・伝票等／決算）に
  沿って`subjectId`を補完し、全15語が3科目いずれかに属するようにした
- `TermListPage`に`initialSubjectId`・`initialSubjectLabel`を追加。指定時は科目一致＋未習得で初期絞り込みし、
  AppBarタイトルに科目名を出す。絞り込みチップの×タップで解除し全科目・全フィルタに戻れる
- `test/weak_subject_term_review_test.dart`（苦手科目カード→用語集起動の確認）・
  `test/term_list_subject_filter_test.dart`（科目絞り込み→解除の確認）を追加。`flutter analyze` 0件・
  `flutter test`（67件）成功、Webビルド＋ヘッドレスブラウザでの表示確認（わざと不正解にして苦手科目を
  作り、「用語集で復習する」→科目絞り込み済みの一覧が開くまで、console error 0件）も実施済み
- 「既存の進捗データ（`ProgressSummaryCard`）と用語集を、新しいデータモデルを増やさずに結ぶ」という、
  前回の解説連携と同じ設計思想の横展開

## 会社経営モード Phase 1（2026-10-08追加）

`docs/company_mode_v1_design.md` の企画に基づき実装。仕訳ドリブン型・初回3シナリオ無料公開の方針どおり。

- `yourwish_kentei`（v0.14.0）に `CompanyScenario`・`CompanyTurn`（`lib/company_mode/company_scenario.dart`）
  と配信前検証 `validateCompanyScenarios`（`lib/content/company_mode_validator.dart`）を追加。既存の
  `JournalAnswer`/`JournalLine`をそのまま再利用し、取引イベント文（`eventText`）を添えるだけで採点ロジックは
  増やしていない
- `lib/company_mode/company_ledger.dart`（`CompanyLedger`・`buildCompanyLedger`）で、複数ターンぶんの仕訳を
  積み上げて勘定科目ごとの残高・資産/負債/純資産/収益/費用の合計・当期純利益を計算する。勘定科目グループの
  判定（`AccountGroup`）はアプリ固有の科目マスタ（`account_catalog.dart`）に依存するため、`yourwish_kentei`
  側ではなくここ（ukalab-boki3側）に置いた
- `lib/company_mode/company_mode_session.dart`（`CompanyModeSession`）でシナリオの進行を管理。不正解でも
  正解仕訳を帳簿に反映して次のターンへ進む（詰みを防ぐ設計、不正解回数は記録するだけで進行に影響しない）
- `lib/company_mode/company_scenario_list_page.dart`（一覧）・`company_scenario_play_page.dart`（導入→
  ターン進行→結果の貸借対照表・損益計算書表示を1画面で管理）を実装。ターンの仕訳入力・採点には既存の
  `JournalQuestionView`をそのまま使う。「学ぶ」タブに「実践する」セクションと「会社を経営する」ボタンを追加
- `assets/exam/boki3.company_scenarios.jsonl`に3シナリオを作成（カフェどんぐり〈飲食業・6ターン〉・
  雑貨屋ことり〈小売業・7ターン、売掛金の計上・回収を含む〉・フリーランス事務所〈サービス業・6ターン、
  決算整理〈減価償却〉を含む〉）。全ターンの貸借一致をスクリプトで確認済み
- `test/company_ledger_test.dart`（残高・財務諸表集計のロジック検証）・
  `test/company_scenarios_data_test.dart`（データ品質検証）・
  `test/company_scenario_play_test.dart`（1シナリオを最後まで正しく仕訳し、結果画面に貸借対照表・損益計算書
  が表示されるまでのE2E）・`test/learn_company_mode_navigation_test.dart`（「学ぶ」タブからの導線）を追加。
  `flutter analyze` 0件・`flutter test`（73件）成功、Webビルド＋ヘッドレスブラウザでの表示確認
  （「学ぶ」タブ→「会社を経営する」→シナリオ一覧→導入画面→1ターン目の仕訳入力画面まで、console error 0件）
  も実施済み
- Phase 3（シナリオ追加・有料化検討）は`docs/company_mode_v1_design.md`のフェーズ分割のとおり未着手

### 会社経営モード Phase 2（2026-10-08追加・その2）

- `lib/company_mode/company_mode_history_store.dart`（`CompanyModeResult`・`CompanyModeHistoryStore`・
  `SharedPreferencesCompanyModeHistoryStore`）を追加。`SharedPreferencesProgressStore`と同じパターンで、
  シナリオ完走時に会社名・仕訳の正答数・当期純利益・プレイ日時を端末内保存する
- `CompanyModeSession`に`wrongTurns`（不正解だったターンの一覧）を追加。結果画面に「間違えたターンを
  振り返る」セクションを設け、不正解だったターンの正解仕訳・解説を`JournalResultBanner`でそのまま表示する。
  解説中の用語集連携（`ExplanationWithTerms`）は既存の仕組みがそのまま効くため、新規実装は不要だった
  （「経営中の誤答を用語集・復習導線につなげる」という企画の狙いを、新しい連携コードを書かずに達成できた）
- 「記録」タブ（`RecordsPage`）に「経営履歴」セクションを追加。直近5件のプレイ結果（会社名・仕訳の正答数・
  当期純利益）をカード表示する。履歴が1件もない間はセクション自体を出さない
- `test/company_scenario_wrong_turn_review_test.dart`（不正解でも進行し振り返りが出ることの確認）・
  `test/records_page_company_mode_history_test.dart`（記録タブへの履歴表示の確認）を追加。既存の
  `company_scenario_play_test.dart`にも履歴保存の確認を追加。`flutter analyze` 0件・`flutter test`
  （75件）成功、Webビルド＋ヘッドレスブラウザでの表示確認（シナリオのターン画面・履歴なし時の記録タブの
  表示、console error 0件）も実施済み

### 会社経営モード Phase 3（2026-10-08追加・その3）

- `assets/exam/boki3.company_scenarios.jsonl`に決算整理を含む本格シナリオを2本追加（法律事務所つくし
  〈サービス業・7ターン、貸倒引当金の差額補充法設定と減価償却の2つの決算整理〉・卸売商事にじいろ
  〈卸売業・7ターン、借入・売上値引き・支払利息〉）。計5シナリオに拡充。全ターンの貸借一致をスクリプトで
  確認済み
- **有料化は見送り**: アプリ全体でまだ課金導線（`isPremium`判定・`FreeTierLimits`の適用）が一切
  実装されていないため、会社経営モードだけ先行して課金ゲートを作るのは時期尚早と判断した。計5シナリオを
  すべて無料のまま公開する。アプリ全体の課金導線実装時に`docs/company_mode_v1_design.md`の方針に沿って
  再検討する
- `test/company_scenarios_data_test.dart`・`test/learn_company_mode_navigation_test.dart`を5シナリオ
  に合わせて更新。`flutter analyze` 0件・`flutter test`（75件）成功

## 欠落分野の問題追加（2026-10-14）

- `boki3.questions.jsonl` を176問→195問にした（journal型134・choice型38・ledger型13・worksheet型10）。
  再レビューで0件だった6分野を追加: 有価証券（売買目的の購入・売却）3問、訂正仕訳（誤記訂正）4問、
  再振替仕訳3問、貯蔵品（未使用の収入印紙・切手・消耗品の決算振替）3問、手形記入帳（受取・支払、
  旧区分表向け `level3_until_2027_03`）3問、繰越試算表・帳簿締切3問。
- 有価証券・貯蔵品の問題に必要な科目（有価証券・貯蔵品・有価証券売却益・有価証券売却損）を
  `lib/journal_input/account_catalog.dart` に追加した（`docs/accounts_v1_official.md` 末尾参照）。
  従来は「科目一覧を独断で拡張しない」方針で見送っていた分野のため、**3級の範囲かどうかを簿記講師等の
  専門家が確認する必要がある**。
- 追加により出題プールが増えたため、`practice_page_legacy_level_ui*_test.dart` の期待件数を
  93→96問・84→87問に更新した（第1問の仕訳が3問増えたため）。
- choice型の正解位置は 0:9・1:10・2:9・3:10 で均等。数値は生成スクリプトで検算済み（仕訳の貸借一致、
  株式売却の損益、繰越試算表の貸借一致）。

## Firebase 設定ファイルの注入（相互紹介 / CI）

`google-services.json` は秘密扱いでコミットしない（`.gitignore` 済み）。
`android/app/google-services.json` が存在するときだけ google-services プラグインが適用され、無い環境（PR の CI・テスト・ローカル）では Firebase 未設定のままビルドできる。

リリースビルド（`.github/workflows/release-android.yml`、手動実行）で使う Secret:

- `GOOGLE_SERVICES_JSON_BASE64`: `google-services.json` を base64 した文字列

登録手順: Firebase コンソールから `google-services.json` をダウンロードし、`base64 -w0 google-services.json`（macOS は `base64 -i google-services.json`）の出力を、リポジトリの Settings > Secrets and variables > Actions に `GOOGLE_SERVICES_JSON_BASE64` として登録する。Secret が空ならステップはスキップされる。

iOS の `GoogleService-Info.plist` の注入は未対応（現状 `ios/` ディレクトリが無い）。
