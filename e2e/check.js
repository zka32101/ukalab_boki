// アプリ（Flutter Web）を Playwright で操作して、主要タブ・設定の購入欄・受験日を確認する。
//   node check.js [スクリーンショットの保存先]
// 期待値は環境変数で渡す（アプリごとに違うため）:
//   E2E_SETTINGS   設定タブに出るはずの文言（カンマ区切り）
//   E2E_EXAM_DATE  1 なら、受験日の入力→再読み込みで残る→解除 を確認する
//   E2E_HOME / E2E_LEARN  ホーム／学ぶタブに出るはずの文言（カンマ区切り。画面外はスクロールして探す）
//   E2E_READING    「入口の文言|読み物の題名(一部)|最初の節の見出し」。あれば、解説読み物の一覧と詳細を確認する
// Flutter Web は文字をキャンバスに描くので、アクセシビリティ（semantics）を有効にして文字とボタンを拾う。
const { chromium } = require('playwright');

const shots = process.argv[2] || '.';
const settingsExpect = (process.env.E2E_SETTINGS || '購入,ながら学習モード').split(',').filter(Boolean);
const examDate = process.env.E2E_EXAM_DATE === '1';
const reading = (process.env.E2E_READING || '').split('|').filter(Boolean);
if (reading.length && reading.length !== 3) throw new Error('E2E_READING は「入口|題名|見出し」の3つ');
const tabs = ['ホーム', '学ぶ', '模擬', '記録', '設定'];
const failures = [];

function check(name, ok) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}`);
  if (!ok) failures.push(name);
}

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--no-sandbox'] });
  const page = await browser.newPage({ locale: 'ja-JP', viewport: { width: 420, height: 1000 } });
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));

  // 文字は innerText と aria-label の両方から拾う（タブやボタンの名前は aria-label にだけ入る）。
  const text = async () =>
    page.evaluate(() =>
      [...document.querySelectorAll('flt-semantics')]
        .map(e => `${e.innerText || ''}\n${e.getAttribute('aria-label') || ''}`)
        .join('\n'));
  const waitText = async (s, timeout = 8000) => {
    const end = Date.now() + timeout;
    while (Date.now() < end) {
      if ((await text()).includes(s)) return true;
      await page.waitForTimeout(200);
    }
    return false;
  };
  const click = async (name) => {
    const byRole = page.getByRole('tab', { name, exact: false });
    const loc = (await byRole.count()) > 0 ? byRole : page.getByRole('button', { name, exact: false });
    await loc.first().click({ force: true });
    await page.waitForTimeout(700);
  };
  const boot = async () => {
    await page.goto('http://localhost:8099/');
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 90000 });
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
    await page.waitForTimeout(1500);
  };

  await boot();
  check('起動してホームが出る', await waitText('ホーム', 20000));
  await page.screenshot({ path: `${shots}/home.png` });

  // 5つのタブを順に開く
  for (const t of tabs) {
    check(`タブ「${t}」がある`, await waitText(t));
  }
  for (const t of tabs.slice(1, 4)) {
    await click(t);
    await page.screenshot({ path: `${shots}/tab-${t}.png` });
  }
  check('ページエラーなし（各タブ）', errors.length === 0);

  // アプリ固有の文言（ホーム／学ぶ）。画面外の項目は上からスクロールして探す。
  const expectOn = async (tab, env) => {
    const items = (process.env[env] || '').split(',').filter(Boolean);
    if (!items.length) return;
    await click(tab);
    for (const s of items) {
      let ok = await waitText(s, 1500);
      await page.mouse.move(210, 500);
      for (let i = 0; !ok && i < 14; i++) {
        await page.mouse.wheel(0, 500);
        await page.waitForTimeout(300);
        ok = await waitText(s, 500);
      }
      check(`${tab}に「${s}」`, ok);
      await page.mouse.wheel(0, -10000);
      await page.waitForTimeout(300);
    }
  };
  await expectOn('ホーム', 'E2E_HOME');
  await expectOn('学ぶ', 'E2E_LEARN');

  // 設定タブ
  await click('設定');
  for (const s of settingsExpect) check(`設定に「${s}」`, await waitText(s));
  await page.screenshot({ path: `${shots}/settings.png` });

  if (examDate) {
    const today = await page.evaluate(() => {
      const d = new Date();
      return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`;
    });
    check('受験日は未設定', await waitText('未設定'));
    await click('受験日');
    await click('OK');
    check(`受験日に今日（${today}）が入る`, await waitText(today));
    await page.screenshot({ path: `${shots}/exam-date-set.png` });

    // 再読み込みしても残る（端末内の保存）
    await boot();
    await click('設定');
    check('再読み込み後も受験日が残る', await waitText(today));

    await click('受験日を解除');
    check('受験日を解除すると未設定に戻る', await waitText('未設定'));
  }

  // 章ごとの解説読み物: 入口 → 一覧に題名 → 開くと節の見出しが出る
  //   E2E_READING=入口の文言|読み物の題名(一部)|最初の節の見出し
  if (reading) {
    const [entry, title, heading] = reading;
    await boot();
    await click('学ぶ');
    check(`学ぶタブに「${entry}」`, await waitText(entry));
    await click(entry);
    check(`読み物の一覧に「${title}」`, await waitText(title));
    await page.screenshot({ path: `${shots}/reading-list.png` });
    await click(title);
    check(`読み物を開くと節「${heading}」が出る`, await waitText(heading));
    await page.screenshot({ path: `${shots}/reading-detail.png` });
  }

  check('ページエラーなし', errors.length === 0);
  if (errors.length) console.log(errors.join('\n'));
  await browser.close();
  if (failures.length) {
    console.log(`\n${failures.length} 件失敗`);
    process.exitCode = 1;
  }
})();
