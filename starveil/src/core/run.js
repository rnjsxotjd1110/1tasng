// 원정(런) 진행 로직 — 맵, 노드, 보상, 상점, 휴식, 이벤트
import { Rng, hashStr } from './rng.js';
import { CLASS_BY_ID, classLevel } from '../data/classes.js';
import { SKILLS, skillById } from '../data/skills.js';
import { RELICS, relicById } from '../data/relics.js';
import { POTIONS } from '../data/potions.js';
import { DICE } from '../data/dice.js';
import { ACTS, BOSSES } from '../data/enemies.js';
import { EVENTS, EVENT_BY_ID } from '../data/events.js';
import { phaseScale } from '../data/meta.js';
import { companionPassive } from '../data/companions.js';

export const ROWS = 9;
export const COLS = 5;
export const BASE_SKILL_SLOTS = 5;
export const BASE_POTION_SLOTS = 2;

const rngOf = (run) => { const r = new Rng(1); r.state = run.rngS; return r; };
const saveRng = (run, r) => { run.rngS = r.state; };
function withRng(run, fn) { const r = rngOf(run); const out = fn(r); saveRng(run, r); return out; }

// ───────── 새 원정 ─────────
export function newRun(profile, opt) {
  const seed = opt.seed || (Date.now() ^ Math.floor(Math.random() * 1e9)) >>> 0;
  const cls = CLASS_BY_ID[opt.cls];
  const t = profile.tree || {};
  const lv = (id) => t[id] || 0;
  const phase = opt.phase || 0;
  const rng = new Rng(seed);
  let maxHp = cls.hp + 4 * lv('hp') + lv('infinite');
  if (phase >= 6) maxHp = Math.floor(maxHp * 0.9);
  const hero = {
    cls: cls.id, hp: maxHp, maxHp, gold: 50 + 15 * lv('gold'),
    dice: cls.dice.slice(), skills: cls.skills.map((id) => ({ id, up: false })),
    skillSlots: BASE_SKILL_SLOTS + lv('slot'), relics: [], potions: [], potionSlots: BASE_POTION_SLOTS + lv('potion'),
    rerolls: Math.max(0, cls.rerolls + lv('reroll') - (phase >= 17 ? 1 : 0)), fortuneMax: cls.fortuneMax - lv('fortune'),
    dmgBonus: 0.03 * lv('master') + 0.01 * lv('infinite'), luck: 0.05 * lv('luck'), assistBonus: lv('assist'),
    winHeal: lv('heal'), restBonus: 0.05 * lv('rest'), shopDisc: 0.04 * lv('shop'), eliteGold: 10 * lv('elite'),
    phoenixUsed: false,
  };
  for (let i = 0; i < Math.min(lv('upgrade'), hero.skills.length); i++) hero.skills[i].up = true;
  if (lv('lucky')) hero.dice[0] = 'lucky';
  const run = {
    v: 1, seed, rngS: rng.state, mode: opt.mode || 'normal', cls: cls.id, phase,
    classLv: classLevel((profile.classes[cls.id] || {}).xp || 0),
    companion: opt.companion || null, act: 1, maxAct: profile.unlocked.act4 ? 4 : 3,
    map: null, pos: null, hero, stats: { nodes: 0, elites: 0, bosses: 0, bossShards: 0, kills: 0, dmg: 0, maxHit: 0, goldEarned: 0, eventShards: 0 },
    screen: { type: 'map' }, queue: [], next: {}, shopVisits: 0, removeCost: 75, upCost: 60, gifts: [], affGain: {},
    dailyMods: opt.dailyMods || [], started: Date.now(), over: null, log: [], metaChoice: lv('choice'),
  };
  addRelic(run, cls.relic);
  if (lv('relic')) withRng(run, (r) => { const pool = relicPool(run, 'c'); if (pool.length) addRelic(run, r.pick(pool).id); });
  withRng(run, (r) => { for (let i = 0; i < lv('potstart'); i++) run.hero.potions.push(r.pick(POTIONS.filter((p) => p.rar === 'c')).id); });
  if (opt.buff) applyStartBuff(run, opt.buff);
  for (const m of run.dailyMods) applyDailyMod(run, m);
  run.map = genMap(run);
  return run;
}

function applyStartBuff(run, b) {
  if (b.maxHp) { run.hero.maxHp += b.maxHp; run.hero.hp += b.maxHp; }
  if (b.gold) run.hero.gold += b.gold;
  if (b.potion) run.hero.potions.push(b.potion);
  if (b.upgrade) for (const s of run.hero.skills.slice(0, b.upgrade)) s.up = true;
  if (b.str) run.next.str = b.str;
  run.startBuff = b;
}

export const DAILY_MODS = {
  rich: { name: '부자의 밤', desc: '시작 골드 +100' },
  glass: { name: '유리 대포', desc: '최대 체력 -30%, 주는 피해 +30%' },
  dice: { name: '주사위 축제', desc: '주사위 +1, 재굴림 -1' },
  elite: { name: '사냥의 밤', desc: '엘리트가 자주 등장, 엘리트 골드 2배' },
  potion: { name: '약초꾼', desc: '물약 칸 +2, 시작 물약 3개' },
  cursed: { name: '저주받은 밤', desc: '모든 적 힘 +1, 별조각 +30%' },
  lucky: { name: '행운의 밤', desc: '시작 주사위가 모두 행운 주사위' },
  frail: { name: '연약한 밤', desc: '휴식 회복 2배, 최대 체력 -15' },
};
function applyDailyMod(run, m) {
  const h = run.hero;
  if (m === 'rich') h.gold += 100;
  if (m === 'glass') { h.maxHp = Math.floor(h.maxHp * 0.7); h.hp = h.maxHp; h.dmgBonus += 0.3; }
  if (m === 'dice') { h.dice.push('normal'); h.rerolls = Math.max(0, h.rerolls - 1); }
  if (m === 'potion') { h.potionSlots += 2; withRng(run, (r) => { for (let i = 0; i < 3; i++) h.potions.push(r.pick(POTIONS.filter((p) => p.rar === 'c')).id); }); }
  if (m === 'lucky') h.dice = h.dice.map(() => 'lucky');
  if (m === 'frail') { h.maxHp -= 15; h.hp = h.maxHp; h.restBonus += 1; }
}

export function addRelic(run, id) {
  const r = relicById(id);
  if (!r || run.hero.relics.includes(id)) return false;
  run.hero.relics.push(id);
  const m = r.mods || {};
  if (m.maxHp) { run.hero.maxHp = Math.max(1, run.hero.maxHp + m.maxHp); run.hero.hp = Math.max(1, Math.min(run.hero.maxHp, run.hero.hp + Math.max(0, m.maxHp))); }
  if (m.potionSlots) run.hero.potionSlots += m.potionSlots;
  if (m.skillSlots) run.hero.skillSlots += m.skillSlots;
  return true;
}

// ───────── 맵 ─────────
export function actDef(act) { return ACTS[((act - 1) % 4) + 1]; }
export function isAbyss(run) { return run.act > 4; }

export function genMap(run) {
  return withRng(run, (r) => {
    const grid = [];
    for (let i = 0; i < ROWS; i++) grid.push(new Array(COLS).fill(null));
    const edges = new Set();
    const ek = (r1, c1, c2) => `${r1}:${c1}>${c2}`;
    const starts = r.sample([0, 1, 2, 3, 4], 2).concat([r.int(0, COLS - 1), r.int(0, COLS - 1)]);
    for (const s of starts) {
      let c = s;
      for (let row = 0; row < ROWS; row++) {
        if (!grid[row][c]) grid[row][c] = { r: row, c, t: null, next: [], jx: r.int(-9, 9), jy: r.int(-6, 6) };
        if (row === ROWS - 1) break;
        let opts = [c - 1, c, c + 1].filter((x) => x >= 0 && x < COLS);
        opts = opts.filter((nc) => nc === c || !edges.has(ek(row, nc, c)));
        const nc = r.pick(opts);
        edges.add(ek(row, c, nc));
        if (!grid[row][c].next.includes(nc)) grid[row][c].next.push(nc);
        c = nc;
      }
    }
    // 종류 배정
    const elitePlus = (run.phase >= 7 ? 6 : 0) + (run.dailyMods.includes('elite') ? 10 : 0);
    for (let row = 0; row < ROWS; row++) {
      for (const n of grid[row]) {
        if (!n) continue;
        if (row === 0) n.t = 'battle';
        else if (row === 4) n.t = 'treasure';
        else if (row === ROWS - 1) n.t = 'rest';
        else {
          const w = [['battle', 46], ['event', 22], ['elite', row >= 2 ? 11 + elitePlus : 0], ['shop', row >= 2 ? 9 : 0], ['rest', row >= 3 && row !== ROWS - 2 ? 10 : 0]];
          n.t = r.weighted(w.filter((x) => x[1] > 0));
        }
      }
    }
    // 같은 특수 칸이 연속되지 않게
    for (let row = 1; row < ROWS - 1; row++) {
      for (const n of grid[row]) {
        if (!n || !['rest', 'shop', 'elite'].includes(n.t)) continue;
        const parents = grid[row - 1].filter((p) => p && p.next.includes(n.c));
        if (parents.some((p) => p.t === n.t)) n.t = 'battle';
      }
    }
    return { rows: grid, boss: actDef(run.act).boss, done: [] };
  });
}

export function nodeAt(run, row, col) { return run.map.rows[row] && run.map.rows[row][col]; }

export function availableNodes(run) {
  if (run.screen.type !== 'map') return [];
  if (!run.pos) return run.map.rows[0].filter(Boolean).map((n) => ({ r: n.r, c: n.c }));
  if (run.pos.r === ROWS - 1) return [{ r: ROWS, c: 2, boss: true }];
  const n = nodeAt(run, run.pos.r, run.pos.c);
  return n.next.map((c) => ({ r: run.pos.r + 1, c }));
}

// ───────── 노드 진입 ─────────
export function scaleFor(run, kind, row) {
  const s = phaseScale(run.phase, kind);
  let hp = s.hp * (1 + 0.025 * (row || 0));
  let atk = s.atk;
  if (run.act > 4) { const k = run.act - 4; hp *= 1 + 0.35 * k; atk *= 1 + 0.2 * k; }
  return { hp, atk };
}

export function enterNode(run, row, col) {
  const av = availableNodes(run);
  if (!av.some((a) => a.r === row && a.c === col)) return false;
  run.stats.nodes++;
  if (row === ROWS) { run.pos = { r: ROWS, c: 2 }; startFight(run, [run.map.boss], 'boss', row); return true; }
  run.pos = { r: row, c: col };
  run.map.done.push(`${row}:${col}`);
  const n = nodeAt(run, row, col);
  const a = actDef(run.act);
  withRng(run, (r) => {
    if (n.t === 'battle') {
      const pool = row < 2 && run.act <= 4 ? a.easy : a.normal;
      startFight(run, r.pick(pool).slice(), 'normal', row);
    } else if (n.t === 'elite') startFight(run, r.pick(a.elite).slice(), 'elite', row);
    else if (n.t === 'event') {
      const actIdx = ((run.act - 1) % 4) + 1;
      const seen = run.seenEvents || (run.seenEvents = []);
      let pool = EVENTS.filter((e) => e.acts.includes(actIdx) && !seen.includes(e.id));
      if (!pool.length) pool = EVENTS.filter((e) => e.acts.includes(actIdx));
      if (r.chance(0.2)) { startFight(run, r.pick(a.normal).slice(), 'normal', row, { ambush: true }); return; }
      const ev = r.pick(pool);
      seen.push(ev.id);
      run.screen = { type: 'event', id: ev.id };
    } else if (n.t === 'shop') run.screen = { type: 'shop', stock: genShop(run, r) };
    else if (n.t === 'rest') run.screen = { type: 'rest', used: false };
    else if (n.t === 'treasure') {
      const rar = r.weighted([['c', 40], ['r', 40], ['e', 20]]);
      const pool = relicPool(run, rar);
      run.screen = { type: 'treasure', relic: pool.length ? r.pick(pool).id : null, gold: r.int(25, 45), opened: false };
    }
  });
  return true;
}

function startFight(run, ids, kind, row, extra = {}) {
  const seed = withRng(run, (r) => r.int(1, 2 ** 31 - 2));
  let enemies = ids;
  if (run.act > 4 && kind === 'boss') enemies = [BOSSES[(run.act - 5) % 4]];
  run.screen = { type: 'combat', enemies, kind, seed, scale: scaleFor(run, kind, row), ...extra };
}

export function combatOptions(run) {
  const s = run.screen;
  const mods = {};
  if (run.phase >= 13 && s.kind === 'boss') mods.enemyStr = 2;
  if (run.phase >= 18) mods.enemyStr = (mods.enemyStr || 0) + 1;
  if (run.dailyMods.includes('cursed')) mods.enemyStr = (mods.enemyStr || 0) + 1;
  let comp = null;
  if (run.companion) comp = { id: run.companion.id, lv: Math.min(10, run.companion.lv + (run.hero.assistBonus || 0) * 3) };
  return { seed: s.seed, kind: s.kind, scale: s.scale, mods, companion: comp };
}

// 전투 시작 직후 런 수준 효과(다음 전투 예약 효과 등)
export function preCombat(run, c) {
  const n = run.next || {};
  if (n.st) for (const k in n.st) c.h.st[k] = (c.h.st[k] || 0) + n.st[k];
  if (n.block) c.h.block += n.block;
  if (n.str) c.h.st.str = (c.h.st.str || 0) + n.str;
  run.next = {};
  c.dmgMult += run.hero.dmgBonus || 0;
  c.rs._luck = (c.rs._luck || 0) + (run.hero.luck || 0);
  if (run.companion) {
    const p = companionPassive(run.companion.id, run.companion.lv);
    if (p.startBlock) c.h.block += p.startBlock;
  }
}

// ───────── 전투 결과 ─────────
export function onCombatWin(run) {
  const s = run.screen;
  const h = run.hero;
  const out = withRng(run, (r) => {
    const goldMult = 1 + (sumRelicMod(run, 'goldMult')) + (run.companion ? (companionPassive(run.companion.id, run.companion.lv).goldMult || 0) : 0);
    const phaseGold = run.phase >= 3 ? 0.8 : 1;
    let gold;
    const a = Math.min(run.act, 8);
    if (s.kind === 'boss') gold = 70 + a * 20;
    else if (s.kind === 'elite') gold = r.int(28, 36) + a * 4 + (h.eliteGold || 0);
    else gold = r.int(10, 16) + a * 2;
    if (s.kind === 'elite' && run.dailyMods.includes('elite')) gold *= 2;
    gold = Math.round(gold * goldMult * phaseGold);
    const reward = { gold, skills: [], potion: null, relic: null, kind: s.kind, claimed: {} };
    const nChoices = Math.max(2, 3 + (run.metaChoice || 0) - (run.phase >= 10 ? 1 : 0));
    reward.skills = skillChoices(run, r, nChoices, s.kind);
    const pChance = (s.kind === 'elite' ? 0.6 : 0.4) * (run.phase >= 9 ? 0.6 : 1);
    if (s.kind !== 'boss' && h.potions.length < h.potionSlots + 2 && r.chance(pChance)) reward.potion = r.pick(POTIONS.filter((p) => p.rar === 'c')).id;
    if (s.kind === 'elite') { const rar = r.weighted([['c', 50], ['r', 35], ['e', 15]]); const pool = relicPool(run, rar); if (pool.length) reward.relic = r.pick(pool).id; }
    if (s.reward === 'relicE') { const pool = relicPool(run, 'e'); if (pool.length) reward.relic = r.pick(pool).id; }
    if (s.reward === 'skillR') reward.skills = skillChoices(run, r, nChoices, 'elite');
    if (s.kind === 'boss') reward.bossRelics = r.sample(relicPool(run, 'l', true), 3).map((x) => x.id);
    return reward;
  });
  // 승리 회복
  let wh = h.winHeal || 0;
  if (run.companion && run.phase < 15) wh += companionPassive(run.companion.id, run.companion.lv).winHeal || 0;
  if (wh > 0) h.hp = Math.min(h.maxHp, h.hp + wh);
  if (s.kind === 'elite') run.stats.elites++;
  if (s.kind === 'boss') { run.stats.bosses++; run.stats.bossShards += 30 * Math.min(run.act, 6) + (run.act > 4 ? 40 : 0); }
  run.screen = { type: 'reward', reward: out, from: s.kind };
  return out;
}

function sumRelicMod(run, k) {
  let v = 0;
  for (const id of run.hero.relics) { const r = relicById(id); if (r && r.mods && r.mods[k]) v += r.mods[k]; }
  return v;
}

export function skillPool(run) {
  return SKILLS.filter((s) => !s.start && (s.cls === run.cls || s.cls === 'any') && (!s.lock || s.lock <= run.classLv));
}

function skillChoices(run, r, n, kind) {
  const owned = new Set(run.hero.skills.map((s) => s.id));
  const pool = skillPool(run).filter((s) => !owned.has(s.id));
  const weights = kind === 'boss' ? { c: 0, r: 40, e: 45, l: 15 } : kind === 'elite' ? { c: 40, r: 45, e: 14, l: 1 } : { c: 62, r: 31, e: 7, l: 0 };
  const out = [];
  const used = new Set();
  for (let i = 0; i < n * 4 && out.length < n; i++) {
    const rar = r.weighted(Object.entries(weights).filter((x) => x[1] > 0));
    const cand = pool.filter((s) => s.rar === rar && !used.has(s.id));
    const pick = cand.length ? r.pick(cand) : null;
    if (pick) { used.add(pick.id); out.push(pick.id); }
  }
  if (out.length < n) for (const s of r.shuffle(pool)) { if (out.length >= n) break; if (!used.has(s.id)) { used.add(s.id); out.push(s.id); } }
  const upChance = run.act >= 2 ? 0.12 * Math.min(run.act, 4) : 0;
  return out.map((id) => ({ id, up: r.chance(upChance) }));
}

export function relicPool(run, rar, boss) {
  return RELICS.filter((x) => (boss ? x.rar === 'l' : x.rar === rar && !x.boss) && (!x.cls) && !run.hero.relics.includes(x.id));
}

// 보상 수령
export function claimGold(run) {
  const rw = run.screen.reward;
  if (!rw || rw.claimed.gold) return;
  rw.claimed.gold = true;
  run.hero.gold += rw.gold;
  run.stats.goldEarned += rw.gold;
}
export function claimPotion(run) {
  const rw = run.screen.reward;
  if (!rw || !rw.potion || rw.claimed.potion) return false;
  if (run.hero.potions.length >= run.hero.potionSlots) return false;
  rw.claimed.potion = true;
  run.hero.potions.push(rw.potion);
  return true;
}
export function claimRelic(run, id) {
  const rw = run.screen.reward;
  if (!rw || rw.claimed.relic) return false;
  if (id ? !(rw.bossRelics || []).includes(id) && rw.relic !== id : !rw.relic) return false;
  rw.claimed.relic = true;
  addRelic(run, id || rw.relic);
  return true;
}
// 기술 얻기: 칸이 가득 차면 replaceIdx 필요
export function learnSkill(run, sk, replaceIdx) {
  const h = run.hero;
  if (h.skills.length < h.skillSlots) { h.skills.push({ id: sk.id, up: !!sk.up }); return true; }
  if (replaceIdx === undefined || replaceIdx < 0 || replaceIdx >= h.skills.length) return false;
  h.skills[replaceIdx] = { id: sk.id, up: !!sk.up };
  return true;
}
export function claimSkill(run, idx, replaceIdx) {
  const rw = run.screen.reward;
  if (!rw || rw.claimed.skill) return false;
  const sk = rw.skills[idx];
  if (!sk) return false;
  if (!learnSkill(run, sk, replaceIdx)) return false;
  rw.claimed.skill = true;
  return true;
}
export function skipSkill(run) {
  const rw = run.screen.reward;
  if (!rw || rw.claimed.skill) return;
  rw.claimed.skill = true;
  rw.skipped = true;
  run.hero.gold += 8;
}

// 보상 화면 → 다음 단계
export function leaveReward(run) {
  const from = run.screen.from;
  claimGold(run);
  if (from === 'boss') {
    run.screen = { type: 'actClear', act: run.act };
    return;
  }
  backToMap(run);
}

export function backToMap(run) {
  if (run.queue.length) { run.screen = run.queue.shift(); return; }
  run.screen = { type: 'map' };
}

// 다음 구역
export function canContinue(run) { return run.act < run.maxAct || run.act >= 4; }
export function nextAct(run) {
  if (run.act >= run.maxAct && run.act < 4) { finishRun(run, 'win'); return; }
  run.act++;
  run.pos = null;
  const h = run.hero;
  h.hp = Math.min(h.maxHp, h.hp + Math.ceil((h.maxHp - h.hp) * 0.6));
  run.map = genMap(run);
  run.screen = { type: 'map' };
}

export function finishRun(run, result) {
  run.over = result;
  run.screen = { type: 'end', result };
}

// ───────── 휴식 ─────────
export function restHealAmount(run) {
  const h = run.hero;
  let pct = 0.3 * (1 + (h.restBonus || 0) + sumRelicMod(run, 'restHeal'));
  if (run.phase >= 5) pct *= 0.7;
  return Math.ceil(h.maxHp * pct);
}
export function restHeal(run) {
  const s = run.screen;
  if (s.type !== 'rest' || s.healed || (s.used && !run.hero.relics.includes('star_map'))) return 0;
  const h = run.hero;
  const amt = Math.min(h.maxHp - h.hp, restHealAmount(run));
  h.hp += amt;
  s.used = true; s.healed = true;
  return amt;
}
export function restUpgrade(run, idx) {
  const s = run.screen;
  if (s.type !== 'rest' || s.upgraded || (s.used && !run.hero.relics.includes('star_map'))) return false;
  const sk = run.hero.skills[idx];
  if (!sk || sk.up) return false;
  sk.up = true;
  s.used = true; s.upgraded = true;
  return true;
}
export function restTalk(run) {
  const s = run.screen;
  if (s.type !== 'rest' || s.talked || !run.companion) return false;
  s.talked = true;
  const h = run.hero;
  h.hp = Math.min(h.maxHp, h.hp + Math.ceil(h.maxHp * 0.1));
  run.affGain[run.companion.id] = (run.affGain[run.companion.id] || 0) + 3;
  return true;
}

// ───────── 상점 ─────────
const SKILL_PRICE = { c: 50, r: 80, e: 125, l: 190 };
const RELIC_PRICE = { c: 140, r: 200, e: 280, l: 400 };
const DIE_PRICE = { c: 60, r: 95, e: 150, l: 240 };
export function priceMult(run) {
  let m = 1 - Math.min(0.6, (run.hero.shopDisc || 0) + sumRelicMod(run, 'shopDisc'));
  if (run.phase >= 11) m *= 1.2;
  return m;
}
function genShop(run, r) {
  const pm = priceMult(run);
  const owned = new Set(run.hero.skills.map((s) => s.id));
  const pool = skillPool(run).filter((s) => !owned.has(s.id));
  const items = [];
  const cls = r.sample(pool.filter((s) => s.cls !== 'any'), 3);
  const neu = r.sample(pool.filter((s) => s.cls === 'any'), 1);
  for (const s of cls.concat(neu)) items.push({ k: 'skill', id: s.id, up: false, price: Math.round(SKILL_PRICE[s.rar] * pm * (0.9 + r.next() * 0.2)) });
  const relics = r.sample(RELICS.filter((x) => !x.cls && !x.boss && !run.hero.relics.includes(x.id) && x.rar !== 'l'), 3);
  for (const x of relics) items.push({ k: 'relic', id: x.id, price: Math.round(RELIC_PRICE[x.rar] * pm * (0.9 + r.next() * 0.2)) });
  for (const p of r.sample(POTIONS, 3)) items.push({ k: 'potion', id: p.id, price: Math.round((p.rar === 'r' ? 95 : 55) * pm) });
  const dice = r.sample(DICE.filter((d) => d.id !== 'normal' && d.rar !== 'l'), 1);
  for (const d of dice) items.push({ k: 'dice', id: d.id, price: Math.round(DIE_PRICE[d.rar] * pm) });
  run.shopVisits++;
  return items;
}
export function buy(run, idx, replaceIdx) {
  const s = run.screen;
  if (s.type !== 'shop') return { ok: false };
  const it = s.stock[idx];
  const h = run.hero;
  if (!it || it.sold || h.gold < it.price) return { ok: false, why: 'gold' };
  if (it.k === 'skill') {
    if (h.skills.length >= h.skillSlots && replaceIdx === undefined) return { ok: false, why: 'slots' };
    learnSkill(run, { id: it.id, up: it.up }, replaceIdx);
  } else if (it.k === 'relic') addRelic(run, it.id);
  else if (it.k === 'potion') { if (h.potions.length >= h.potionSlots) return { ok: false, why: 'potion' }; h.potions.push(it.id); }
  else if (it.k === 'dice') { if (h.dice.length >= 6) return { ok: false, why: 'dice' }; h.dice.push(it.id); }
  h.gold -= it.price;
  it.sold = true;
  run.stats.spent = (run.stats.spent || 0) + it.price;
  return { ok: true };
}
export function shopRemove(run, idx) {
  const h = run.hero;
  const cost = Math.round(run.removeCost * priceMult(run));
  if (run.screen.type !== 'shop' || h.gold < cost || h.skills.length <= 1 || !h.skills[idx]) return false;
  h.gold -= cost; h.skills.splice(idx, 1); run.removeCost += 25;
  return true;
}
export function shopUpgrade(run, idx) {
  const h = run.hero;
  const cost = Math.round(run.upCost * priceMult(run));
  const sk = h.skills[idx];
  if (run.screen.type !== 'shop' || h.gold < cost || !sk || sk.up) return false;
  h.gold -= cost; sk.up = true; run.upCost += 20;
  return true;
}

// ───────── 보물 ─────────
export function openTreasure(run) {
  const s = run.screen;
  if (s.type !== 'treasure' || s.opened) return;
  s.opened = true;
  run.hero.gold += s.gold;
  if (s.relic) addRelic(run, s.relic);
}

// ───────── 이벤트 ─────────
export function eventChoiceOk(run, choice) {
  const q = choice.req;
  if (!q) return true;
  if (q.gold && run.hero.gold < q.gold) return false;
  if (q.dice && !run.hero.dice.includes(q.dice)) return false;
  return true;
}

// 이벤트 선택 → 결과 텍스트와 후속 화면(큐)을 만들어요
export function chooseEvent(run, ci) {
  const ev = EVENT_BY_ID[run.screen.id];
  const ch = ev && ev.choices[ci];
  if (!ch || !eventChoiceOk(run, ch)) return null;
  const results = [];
  let text = ch.res || '';
  const follow = [];
  withRng(run, (r) => {
    const apply = (list) => {
      for (const fx of list) {
        if (fx.t === 'chance') { const win = r.chance(fx.p + (run.hero.luck || 0)); text = win ? ch.win : ch.lose; apply(win ? fx.win : fx.lose); continue; }
        const res = applyRunFx(run, r, fx, follow);
        if (res) results.push(res);
      }
    };
    apply(ch.fx);
  });
  run.screen = { type: 'eventResult', id: ev.id, text, results };
  run.queue.unshift(...follow);
  return run.screen;
}

export function applyRunFx(run, r, fx, follow) {
  const h = run.hero;
  switch (fx.t) {
    case 'heal': { const amt = Math.min(h.maxHp - h.hp, fx.pct ? Math.ceil(h.maxHp * fx.pct / 100) : fx.v); h.hp += amt; return { k: 'heal', v: amt }; }
    case 'hp': { h.hp = Math.max(1, h.hp + fx.v); return { k: 'hp', v: fx.v }; }
    case 'maxHp': { h.maxHp = Math.max(10, h.maxHp + fx.v); h.hp = Math.min(h.maxHp, Math.max(1, h.hp + Math.max(0, fx.v))); return { k: 'maxHp', v: fx.v }; }
    case 'gold': { const v = Array.isArray(fx.v) ? r.int(fx.v[0], fx.v[1]) : fx.v; h.gold = Math.max(0, h.gold + v); return { k: 'gold', v }; }
    case 'relic': { const pool = relicPool(run, fx.rar, fx.rar === 'l'); if (!pool.length) return null; const x = r.pick(pool); addRelic(run, x.id); return { k: 'relic', id: x.id }; }
    case 'relicId': { if (addRelic(run, fx.id)) return { k: 'relic', id: fx.id }; h.gold += 40; return { k: 'gold', v: 40 }; }
    case 'skill': {
      const rars = fx.rar === 'r' ? ['r', 'e'] : [fx.rar];
      const owned = new Set(h.skills.map((s) => s.id));
      const pool = skillPool(run).filter((s) => rars.includes(s.rar) && !owned.has(s.id));
      const picks = r.sample(pool, 3).map((s) => ({ id: s.id, up: false }));
      if (picks.length) follow.push({ type: 'skillPick', skills: picks });
      return null;
    }
    case 'copySkill': { const s = r.pick(h.skills); if (s) follow.push({ type: 'skillPick', skills: [{ id: s.id, up: s.up }] }); return null; }
    case 'upgrade': {
      const cand = h.skills.filter((s) => !s.up);
      const picks = r.sample(cand, fx.n);
      for (const s of picks) s.up = true;
      return picks.length ? { k: 'upgrade', ids: picks.map((s) => s.id) } : null;
    }
    case 'potion': { if (h.potions.length >= h.potionSlots) return { k: 'potionFull' }; const id = fx.id || r.pick(POTIONS.filter((p) => p.rar === 'c')).id; h.potions.push(id); return { k: 'potion', id }; }
    case 'dice': {
      let id = fx.id;
      if (!id) id = r.pick(DICE.filter((d) => d.rar === fx.rar)).id;
      if (h.dice.length >= 6) { const i = h.dice.indexOf('normal'); if (i >= 0) h.dice[i] = id; else return null; } else h.dice.push(id);
      return { k: 'dice', id };
    }
    case 'loseDie': { const i = h.dice.indexOf(fx.id); if (i >= 0) h.dice.splice(i, 1); return null; }
    case 'remove': follow.push({ type: 'remove' }); return null;
    case 'fight': {
      const seed = r.int(1, 2 ** 31 - 2);
      follow.push({ type: 'combat', enemies: fx.ids.slice(), kind: 'normal', seed, scale: scaleFor(run, 'normal', run.pos ? run.pos.r : 0), reward: fx.reward });
      return null;
    }
    case 'nextFight': { run.next = { ...run.next, ...(fx.st ? { st: fx.st } : {}), ...(fx.block ? { block: fx.block } : {}) }; return null; }
    case 'shards': run.stats.eventShards += fx.v; return { k: 'shards', v: fx.v };
    case 'gift': run.gifts.push(fx.id); return { k: 'gift', id: fx.id };
    default: return null;
  }
}

export function removeSkill(run, idx) {
  if (run.screen.type !== 'remove') return false;
  if (run.hero.skills.length <= 1 || !run.hero.skills[idx]) return false;
  run.hero.skills.splice(idx, 1);
  backToMap(run);
  return true;
}
export function pickSkill(run, i, replaceIdx) {
  if (run.screen.type !== 'skillPick') return false;
  const sk = run.screen.skills[i];
  if (!sk) return false;
  if (!learnSkill(run, sk, replaceIdx)) return false;
  backToMap(run);
  return true;
}

// ───────── 정산 ─────────
export function shardReward(run, profile) {
  const st = run.stats;
  let base = st.nodes * 2 + st.elites * 8 + st.bossShards + st.eventShards;
  if (run.over === 'win') base += 100;
  const lv = (profile.tree && profile.tree.shard) || 0;
  let mult = (1 + 0.08 * run.phase) * (1 + 0.05 * lv);
  if (run.dailyMods.includes('cursed')) mult *= 1.3;
  if (run.mode === 'daily') mult *= 1.2;
  return Math.floor(base * mult);
}

export function dailySeed(key) { return hashStr('starveil-daily-' + key); }
