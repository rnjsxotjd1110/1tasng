// UI 몽키 테스트: 실제 화면을 눌러 원정을 끝까지 진행
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const runsWanted = Number(process.argv[2] || 2);
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: false });
  await ctx.addInitScript(() => {
    if (!localStorage.getItem('starveil_save_v1')) {
      localStorage.setItem('starveil_save_v1', JSON.stringify({ created: Date.now(), settings: { bgm: 0, sfx: 0, vib: false, speed: 2, auto: true }, tutorial: { intro: true, camp: true, map: true, combat: true } }));
    }
  });
  const T_END = Date.now() + Number(process.argv[3] || 600) * 1000;
  const pg = await ctx.newPage();
  const errs = [];
  pg.on('pageerror', (e) => { console.log('PAGEERROR', e.message); errs.push('PAGEERROR ' + e.message + ' ' + (e.stack || '').split('\n')[1]); });
  pg.on('console', (m) => { if (m.type() === 'error') errs.push('console ' + m.text()); });
  await pg.goto('file://' + path.join(__dirname, '..', 'dist', 'index.html'));
  await pg.waitForTimeout(800);
  await pg.click('.tmenu.main'); await pg.waitForTimeout(500);
  if (await pg.$('.vn-skip')) { await pg.click('.vn-skip'); await pg.waitForTimeout(500); }
  let runs = 0, steps = 0, screens = {}, nodeTries = 0;
  const clickIf = async (sel) => { const el = await pg.$(sel); if (el && await el.isVisible() && await el.isEnabled()) { await el.click({ timeout: 2000 }).catch(() => {}); return true; } return false; };
  while (runs <= runsWanted && Date.now() < T_END) {
    steps++;
    await pg.waitForTimeout(250);
    if (process.env.V) { const info = await pg.evaluate(() => { const sh = document.querySelector('.sheet-back.in .sheet-title'); return (sh ? 'SHEET:' + sh.textContent : '') + ' ' + (document.querySelector('.node-title')?.textContent || '') + ' ' + (document.querySelector('.cb') ? 'CB' : ''); }); console.log(steps, info); }
    if (await clickIf('.tut .btn')) continue;
    if (await pg.$('.sheet-back.in')) {
      // 시트: 기술 선택 → 첫 카드 + 배우기 / 확인창 / 기타 닫기
      if (await clickIf('.sheet .skcard')) { await pg.waitForTimeout(150); await clickIf('.sheet .btn:not(.ghost)'); continue; }
      if (await clickIf('.sheet .reward-row:not(.claimed)')) continue;
      if (await clickIf('.sheet .btn.danger')) continue;
      if (await clickIf('.sheet .btn:not(.ghost)')) continue;
      await clickIf('.sheet .close');
      continue;
    }
    if (await pg.$('.vn')) { await clickIf('.vn-skip'); continue; }
    const scr = await pg.evaluate(() => {
      if (document.querySelector('.cb')) return 'combat';
      if (document.querySelector('.map-canvas')) return 'map';
      if (document.querySelector('.tabbar')) return 'hub';
      if (document.querySelector('.node-scr')) return 'node';
      return 'other';
    });
    screens[scr] = (screens[scr] || 0) + 1;
    if (scr === 'hub') {
      if (await clickIf('button:has-text("이어하기")')) continue;
      if (await pg.$('.tab.on') && !(await pg.$('button:has-text("미궁으로 출발")'))) { await clickIf('.tabbar .tab:nth-child(2)'); continue; }
      if (await clickIf('button:has-text("미궁으로 출발")')) { runs++; console.log('원정 시작', runs); continue; }
      continue;
    }
    if (scr === 'map') { await clickIf('.mnode.av'); continue; }
    if (scr === 'combat') {
      const autoOn = await pg.$('.auto-on');
      if (!autoOn) await clickIf('.cb-top .icon-btn[title="자동 전투"]');
      await pg.waitForTimeout(400);
      continue;
    }
    if (scr === 'node') {
      nodeTries = (nodeTries || 0) + 1;
      if (nodeTries < 4 && await clickIf('.reward-row:not(.claimed)')) continue;
      nodeTries = 0;
      if (await clickIf('button.choice:not([disabled])')) continue;
      for (const t of ['상자 열기', '푹 쉬기', '다음 구역으로', '야영지로 귀환', '야영지로', '계속', '상점 나가기', '떠나기', '지우지 않기', '기술 고르기']) { if (await clickIf(`button:has-text("${t}")`)) break; }
      continue;
    }
  }
  console.log('steps', steps, 'runs', runs, JSON.stringify(screens));
  const p = await pg.evaluate(() => JSON.parse(localStorage.getItem('starveil_save_v1') || '{}').stats);
  console.log('stats', JSON.stringify(p));
  console.log(errs.length ? 'ERRORS:\n' + [...new Set(errs)].join('\n') : 'no errors');
  await b.close();
})();
