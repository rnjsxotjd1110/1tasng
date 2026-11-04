// 효과음 품질 검사: 오프라인 렌더링 후 최대 음량·튐(인접 샘플 급변)·끝 잔향 확인
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const NAMES = ['click', 'hover', 'open', 'close', 'tab', 'roll', 'pick', 'place', 'hit', 'hitBig', 'hurt', 'block', 'heal', 'status', 'gold', 'fortune', 'win', 'lose', 'level', 'buy', 'error', 'freeze', 'assist', 'page', 'heart', 'splash', 'tick', 'good', 'enemyTurn'];
(async () => {
  const bundle = fs.readFileSync(path.join(__dirname, '..', 'build', 'tmp', 'audio_bundle.js'), 'utf8');
  const b = await chromium.launch();
  const pg = await b.newPage();
  const rows = [];
  for (const n of NAMES) {
    await pg.setContent('<html><body></body></html>');
    const r = await pg.evaluate(async ({ bundle, n }) => {
      const SR = 44100;
      let off = null;
      window.AudioContext = function () { off = new OfflineAudioContext(1, SR * 2, SR); return off; };
      // eslint-disable-next-line no-eval
      (0, eval)(bundle);
      window.SV_AUDIO.setVolumes(0.7, 0.45);
      window.SV_AUDIO.unlockAudio();
      window.SV_AUDIO.sfx(n);
      const buf = await off.startRendering();
      const d = buf.getChannelData(0);
      let peak = 0, jump = 0, sum = 0, lastLoud = 0;
      for (let i = 0; i < d.length; i++) {
        const a = Math.abs(d[i]);
        if (a > peak) peak = a;
        if (i) jump = Math.max(jump, Math.abs(d[i] - d[i - 1]));
        sum += d[i] * d[i];
        if (a > 0.001) lastLoud = i;
      }
      return { peak, jump, rms: Math.sqrt(sum / d.length), tail: lastLoud / SR, end: Math.abs(d[d.length - 1]) };
    }, { bundle, n });
    rows.push({ n, ...r });
  }
  let bad = 0;
  for (const r of rows) {
    const issues = [];
    if (r.peak > 0.5) issues.push('너무 큼');
    if (r.jump > 0.12) issues.push('튐 의심');
    if (r.tail > 1.4) issues.push('길게 끌림');
    if (issues.length) bad++;
    console.log(`${r.n.padEnd(10)} 최대 ${r.peak.toFixed(3)}  인접변화 ${r.jump.toFixed(3)}  길이 ${r.tail.toFixed(2)}s  ${issues.join(', ') || 'OK'}`);
  }
  console.log(bad ? `문제 ${bad}개` : '모든 효과음 통과');
  await b.close();
})();
