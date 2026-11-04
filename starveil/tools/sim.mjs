import { defaultProfile } from '../src/core/profile.js';
import { newRun } from '../src/core/run.js';
import { playRun } from './autopilot.mjs';

const N = Number(process.argv[2] || 200);
const tree = process.argv[3] || 'none';
const phase = Number(process.argv[4] || 0);
const classes = ['knight', 'witch', 'gambler', 'alch'];
for (const cls of classes) {
  let wins = 0; const acts = {}; const deaths = {};
  for (let i = 0; i < N; i++) {
    const p = defaultProfile();
    p.unlocked.act4 = true;
    if (tree === 'mid') p.tree = { hp: 5, heal: 3, rest: 3, gold: 3, shop: 2, potstart: 1, upgrade: 2, fortune: 2 };
    if (tree === 'max') p.tree = { hp: 10, heal: 5, rest: 5, gold: 5, shop: 5, potstart: 2, upgrade: 3, fortune: 4, potion: 2, relic: 1, choice: 1, slot: 1, lucky: 1, reroll: 1, master: 5, luck: 3, assist: 2 };
    p.classes[cls].xp = tree === 'none' ? 0 : 99999;
    const run = newRun(p, { cls, phase, seed: 1000 + i * 7919, companion: { id: 'lyra', lv: tree === 'none' ? 0 : 6 } });
    playRun(p, run, { maxAct: 4 });
    if (run.over === 'win') wins++;
    acts[run.act] = (acts[run.act] || 0) + 1;
    if (run.deathBy) deaths[run.deathBy] = (deaths[run.deathBy] || 0) + 1;
  }
  console.log(`${cls.padEnd(8)} 승률 ${(100 * wins / N).toFixed(1)}%  도달 구역 분포 ${JSON.stringify(acts)}`);
  if (process.env.DEATHS) console.log('   사망 원인 상위', Object.entries(deaths).sort((a, b) => b[1] - a[1]).slice(0, 6).map((x) => x.join(':')).join('  '));
}
