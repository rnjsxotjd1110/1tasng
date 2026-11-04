// 성능 측정: CPU 감속 상태에서 화면별 초당 프레임(rAF) 측정
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const states = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'build', 'qa_states.json'), 'utf8'));
  const rate = Number(process.argv[2] || 4);
  const b = await chromium.launch();
  for (const key of ['act1', 'act2', 'hub']) {
    const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true });
    const st = JSON.parse(JSON.stringify(states[key]));
    st.settings = { ...(st.settings || {}), auto: true, speed: 1 };
    await ctx.addInitScript((s) => localStorage.setItem('starveil_save_v1', s), JSON.stringify(st));
    const pg = await ctx.newPage();
    const cdp = await ctx.newCDPSession(pg);
    await pg.goto('file://' + path.join(__dirname, '..', 'dist', 'index.html'));
    await pg.waitForTimeout(700);
    await pg.click('.tmenu.main'); await pg.waitForTimeout(700);
    if (key !== 'hub') { await pg.click('button:has-text("이어하기")'); }
    await pg.waitForTimeout(1500);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate });
    const r = await pg.evaluate(() => new Promise((res) => {
      let n = 0, worst = 0, last = performance.now();
      const t0 = last;
      const f = (t) => { n++; worst = Math.max(worst, t - last); last = t; if (t - t0 < 5000) requestAnimationFrame(f); else res({ fps: n / ((t - t0) / 1000), worst }); };
      requestAnimationFrame(f);
    }));
    console.log(`${key.padEnd(5)} CPU ×${rate}: 평균 ${r.fps.toFixed(1)}fps, 최장 프레임 ${r.worst.toFixed(0)}ms`);
    await ctx.close();
  }
  await b.close();
})();
