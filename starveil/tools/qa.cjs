// 폰 화면 QA: 화면을 돌며 스크린샷 + 콘솔 오류 수집
const { chromium } = require('playwright');
const path = require('path');
const OUT = path.join(__dirname, '..', 'build', 'shots');
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const pg = await ctx.newPage();
  const errs = [];
  pg.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
  pg.on('pageerror', (e) => errs.push('PAGEERROR ' + e.message + '\n' + e.stack));
  await pg.goto('file://' + path.join(__dirname, '..', 'dist', 'index.html'));
  await pg.waitForTimeout(1500);
  const shot = async (n) => { await pg.waitForTimeout(450); await pg.screenshot({ path: path.join(OUT, n + '.png') }); };
  const steps = (process.argv[2] || 'title').split(',');
  for (const s of steps) {
    try {
      if (s === 'title') await shot('01_title');
      if (s === 'start') { await pg.click('.tmenu.main'); await pg.waitForTimeout(700); await shot('02_prologue'); await pg.click('.vn-skip'); await pg.waitForTimeout(800); await shot('03_home'); }
      if (s.startsWith('tab:')) { const n = s.slice(4); const idx = ['home', 'prep', 'tree', 'heroine', 'play'].indexOf(n); await pg.click(`.tabbar .tab:nth-child(${idx + 1})`); await pg.waitForTimeout(700); await shot('tab_' + n); }
      if (s === 'depart') { await pg.click('.tabbar .tab:nth-child(2)'); await pg.waitForTimeout(500); await pg.click('text=미궁으로 출발'); await pg.waitForTimeout(900); await shot('10_map'); }
      if (s === 'closetut') { const t = await pg.$('.tut .btn'); if (t) { await t.click(); await pg.waitForTimeout(300); } }
      if (s === 'node') { await pg.click('.mnode.av'); await pg.waitForTimeout(1600); await shot('11_node'); }
      if (s === 'combat') { await shot('12_combat'); }
      if (s === 'seldie') { await pg.click('.tray .die'); await pg.waitForTimeout(300); await shot('13_seldie'); }
      if (s === 'autowin') { await pg.click('.cb-top .icon-btn:nth-of-type(1)'); for (let i = 0; i < 60; i++) { await pg.waitForTimeout(1000); if (!(await pg.$('.cb'))) break; } await pg.waitForTimeout(800); await shot('14_after'); }
      if (s.startsWith('shot:')) await shot(s.slice(5));
      if (s.startsWith('click:')) { await pg.click(s.slice(6)); await pg.waitForTimeout(700); }
      if (s.startsWith('wait:')) await pg.waitForTimeout(Number(s.slice(5)));
      if (s.startsWith('eval:')) await pg.evaluate(s.slice(5));
    } catch (e) { errs.push('STEP ' + s + ': ' + e.message.split('\n')[0]); }
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no errors');
  await b.close();
})();
