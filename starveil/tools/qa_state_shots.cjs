const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const states = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'build', 'qa_states.json'), 'utf8'));
const OUT = path.join(__dirname, '..', 'build', 'shots');
(async () => {
  const b = await chromium.launch();
  const errs = [];
  const which = (process.argv[2] || Object.keys(states).join(',')).split(',');
  for (const k of which) {
    const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    await ctx.addInitScript((s) => { localStorage.setItem('starveil_save_v1', s); }, JSON.stringify(states[k]));
    const pg = await ctx.newPage();
    pg.on('pageerror', (e) => errs.push(k + ': ' + e.message));
    pg.on('console', (m) => { if (m.type() === 'error') errs.push(k + ' console: ' + m.text()); });
    await pg.goto('file://' + path.join(__dirname, '..', 'dist', 'index.html'));
    await pg.waitForTimeout(900);
    await pg.click('.tmenu.main');
    await pg.waitForTimeout(800);
    const extra = (process.argv[3] || '').split('|').filter(Boolean);
    if (k !== 'hub') { await pg.click('text=이어하기'); await pg.waitForTimeout(k === 'boss' ? 2600 : 1200); }
    for (const st of extra) { if (st.startsWith('click:')) { await pg.click(st.slice(6)); await pg.waitForTimeout(800); } }
    await pg.screenshot({ path: path.join(OUT, 's_' + k + '.png') });
    await ctx.close();
  }
  console.log(errs.length ? errs.join('\n') : 'no errors');
  await b.close();
})();
