// QA 시나리오용 저장 데이터 생성
import fs from 'fs';
import { defaultProfile, addAff, onBossKill } from '../src/core/profile.js';
import * as R from '../src/core/run.js';
const out = {};
function base() {
  const p = defaultProfile();
  p.tutorial = { intro: true, combat: true, camp: true, map: true };
  p.shards = 1840; p.dust = 2650;
  onBossKill(p, 1); onBossKill(p, 2); p.news = [];
  addAff(p, 'lyra', 230); addAff(p, 'mio', 150); addAff(p, 'seren', 60);
  p.inv.gifts = { star_candy: 3, old_coin: 1, fairy_book: 2, moonflower: 1 };
  p.tree = { hp: 4, heal: 2, rest: 2, gold: 3, shop: 1 };
  p.classes.gambler.xp = 1500;
  return p;
}
function mkRun(p, cls = 'gambler', act = 2) {
  const run = R.newRun(p, { cls, seed: 4242, companion: { id: 'mio', lv: p.heroines.mio.lv } });
  run.act = act; run.map = R.genMap(run);
  run.hero.relics.push('dice_cup', 'lantern', 'lucky_cat');
  run.hero.potions = ['p_heal', 'p_fire'];
  run.hero.skills.push({ id: 'g_seven', up: false }, { id: 'g_high', up: true });
  run.hero.gold = 214; run.hero.hp = 41;
  p.run = run;
  return run;
}
{ const p = base(); const run = mkRun(p); R.enterNode(run, 0, run.map.rows[0].find(Boolean).c); run.screen = { type: 'map' }; out.map = p; }
{ const p = base(); const run = mkRun(p); run.screen = { type: 'event', id: 'fortune_teller' }; out.event = p; }
{ const p = base(); const run = mkRun(p); const n = run.map.rows[2].find(Boolean); run.pos = { r: 1, c: n.c }; n.t = 'shop'; run.map.rows[1][n.c] = run.map.rows[1][n.c] || { r: 1, c: n.c, t: 'battle', next: [n.c], jx: 0, jy: 0 }; run.map.rows[1][n.c].next = [n.c]; R.enterNode(run, 2, n.c); out.shop = p; }
{ const p = base(); const run = mkRun(p); run.screen = { type: 'rest', used: false }; out.rest = p; }
{ const p = base(); const run = mkRun(p); run.screen = { type: 'combat', enemies: ['crystal_knight'], kind: 'elite', seed: 1, scale: { hp: 1, atk: 1 } }; R.onCombatWin(run); out.reward = p; }
{ const p = base(); const run = mkRun(p, 'witch', 1); run.companion = { id: 'seren', lv: 3 }; run.screen = { type: 'combat', enemies: ['treant'], kind: 'boss', seed: 77, scale: { hp: 1, atk: 1 } }; out.boss = p; }
{ const p = base(); p.unlocked.act4 = true; const run = mkRun(p, 'knight', 4); run.maxAct = 4; run.screen = { type: 'actClear', act: 4 }; out.clear = p; }
{ const p = base(); const run = mkRun(p, 'alch', 3); run.stats = { ...run.stats, nodes: 27, elites: 2, bosses: 3, bossShards: 180, kills: 61, maxHit: 48, goldEarned: 512 }; run.gifts = ['star_tea']; run.over = 'win'; run.screen = { type: 'end', result: 'win' }; out.end = p; }
{ const p = base(); out.hub = p; }
{ const p = base(); const run = mkRun(p); run.screen = { type: 'treasure', relic: 'moon_tear', gold: 33, opened: false }; out.treasure = p; }
{ const p = base(); const run = mkRun(p); for (let r = 0; r < 4; r++) { const av = R.availableNodes(run); R.enterNode(run, av[0].r, av[0].c); run.screen = { type: 'map' }; } out.map2 = p; }
const ENC = { 1: ['moss_slime', 'shroom', 'vine'], 2: ['crystal_bat', 'mimic'], 3: ['armor_ghost', 'candle'], 4: ['nox_guard', 'void_eye'] };
for (let a = 1; a <= 4; a++) { const p = base(); const run = mkRun(p, 'knight', a); run.screen = { type: 'combat', enemies: ENC[a], kind: 'normal', seed: 9 + a, scale: { hp: 1, atk: 1 } }; out['act' + a] = p; }
fs.writeFileSync('build/qa_states.json', JSON.stringify(out));
console.log(Object.keys(out).join(','));
