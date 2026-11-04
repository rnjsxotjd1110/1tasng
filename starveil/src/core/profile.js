// 영구 저장 데이터(프로필) — 재화, 성장, 동료, 도감, 업적, 일일 임무, 별빛 수정
import { todayKey } from './util.js';
import { Rng, hashStr } from './rng.js';
import { CLASSES, classLevel } from '../data/classes.js';
import { TREE_BY_ID, MAX_PHASE } from '../data/meta.js';
import { ACHIEVEMENTS } from '../data/achievements.js';
import { HEROINE_META, HEROINE_IDS, affLevel, AFF_MAX_LV, DAILY, GIFT_AFF } from '../data/heroine_meta.js';
import { shardReward } from './run.js';

export const SAVE_KEY = 'starveil_save_v1';
export const SAVE_VERSION = 1;

export function defaultProfile(now = Date.now()) {
  const heroines = {};
  for (const id of HEROINE_IDS) heroines[id] = { aff: 0, lv: 0, day: '', talks: 0, touches: 0, gifts: 0, seen: [], outfit: 'default', outfits: ['default'], talkSeen: [], minis: 0, met: id === 'lyra' };
  const classes = {};
  for (const c of CLASSES) classes[c.id] = { xp: 0, phase: 0, wins: 0, runs: 0, bestAct: 0 };
  return {
    v: SAVE_VERSION, created: now, lastSeen: now, name: '별지기',
    shards: 0, dust: 100,
    tree: {},
    classes,
    unlocked: { classes: ['knight'], act4: false },
    bossKills: { 1: 0, 2: 0, 3: 0, 4: 0 },
    heroines,
    inv: { gifts: { star_candy: 2 } },
    codex: { enemies: {}, skills: {}, relics: {}, fish: {}, recipes: {} },
    ach: {},
    stats: { runs: 0, wins: 0, kills: 0, maxHit: 0, maxGold: 0, maxAct: 0, gambleWins: 0, fortunes: 0, gifts: 0, fish: 0, cooks: 0, hiloBest: 0, constelBest: 0, dailyDays: 0, challengeWins: 0, playMs: 0, talks: 0 },
    daily: null,
    challenge: { key: '', done: false, best: 0 },
    crystal: { last: now, carry: 0 },
    settings: { bgm: 0.45, sfx: 0.7, vib: true, speed: 1, auto: false, shake: true, fxLow: false },
    tutorial: { intro: false, combat: false, camp: false },
    run: null,
    nextBuff: null,
    lastCompanion: null,
    news: [],
  };
}

// 저장 형식 마이그레이션·보정
export function normalize(p) {
  const d = defaultProfile(p.created || Date.now());
  const out = { ...d, ...p };
  for (const k of ['unlocked', 'bossKills', 'inv', 'codex', 'stats', 'settings', 'tutorial', 'crystal', 'challenge']) out[k] = { ...d[k], ...(p[k] || {}) };
  out.codex = { ...d.codex, ...(p.codex || {}) };
  for (const id of HEROINE_IDS) out.heroines[id] = { ...d.heroines[id], ...((p.heroines || {})[id] || {}) };
  for (const c of CLASSES) out.classes[c.id] = { ...d.classes[c.id], ...((p.classes || {})[c.id] || {}) };
  out.v = SAVE_VERSION;
  return out;
}

// ───────── 저장소 ─────────
let memStore = {};
function storage() {
  try { if (typeof localStorage !== 'undefined') { localStorage.setItem('__sv', '1'); localStorage.removeItem('__sv'); return localStorage; } } catch (e) { /* 저장소를 쓸 수 없는 환경 */ }
  return { getItem: (k) => (k in memStore ? memStore[k] : null), setItem: (k, v) => { memStore[k] = String(v); }, removeItem: (k) => { delete memStore[k]; } };
}
export function loadProfile() {
  const st = storage();
  for (const key of [SAVE_KEY, SAVE_KEY + '_bak']) {
    try {
      const raw = st.getItem(key);
      if (raw) return normalize(JSON.parse(raw));
    } catch (e) { /* 손상된 저장은 백업으로 */ }
  }
  return defaultProfile();
}
export function saveProfile(p) {
  const st = storage();
  try {
    p.lastSeen = Date.now();
    const raw = JSON.stringify(p);
    const prev = st.getItem(SAVE_KEY);
    if (prev) st.setItem(SAVE_KEY + '_bak', prev);
    st.setItem(SAVE_KEY, raw);
    return true;
  } catch (e) { return false; }
}
export function exportSave(p) {
  const json = JSON.stringify(p);
  const bytes = new TextEncoder().encode(json);
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return 'SV1:' + btoa(bin);
}
export function importSave(code) {
  const s = code.trim();
  if (!s.startsWith('SV1:')) throw new Error('형식이 맞지 않아요');
  const bin = atob(s.slice(4));
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  const p = JSON.parse(new TextDecoder().decode(bytes));
  if (!p || typeof p !== 'object' || !p.heroines) throw new Error('저장 데이터가 아니에요');
  return normalize(p);
}
export function resetSave() { const st = storage(); st.removeItem(SAVE_KEY); st.removeItem(SAVE_KEY + '_bak'); }

// ───────── 별자리 트리 ─────────
export function treeLv(p, id) { return p.tree[id] || 0; }
export function treeCost(p, id) { const n = TREE_BY_ID[id]; return n.cost(treeLv(p, id)); }
export function treeAvailable(p, id) {
  const n = TREE_BY_ID[id];
  if (treeLv(p, id) >= n.max) return false;
  return !n.req || treeLv(p, n.req) >= 1;
}
export function buyTree(p, id) {
  if (!treeAvailable(p, id)) return false;
  const cost = treeCost(p, id);
  if (p.shards < cost) return false;
  p.shards -= cost;
  p.tree[id] = treeLv(p, id) + 1;
  return true;
}

// ───────── 별빛 수정(방치 수익) ─────────
export const CRYSTAL_BASE = 40; // 시간당 달가루
export function crystalRate(p) { return CRYSTAL_BASE * (1 + 0.1 * treeLv(p, 'crystal')) * (1 + 0.05 * Math.min(10, p.heroines.lyra.lv)); }
export function crystalCapHours(p) { return 8 + 2 * treeLv(p, 'vault'); }
export function crystalStored(p, now = Date.now()) {
  const hrs = Math.max(0, Math.min(crystalCapHours(p), (now - p.crystal.last) / 3600000));
  return Math.floor(hrs * crystalRate(p) + (p.crystal.carry || 0));
}
export function crystalCollect(p, now = Date.now()) {
  const n = crystalStored(p, now);
  p.dust += n;
  p.crystal.last = now;
  p.crystal.carry = 0;
  if (n > 0) dailyProgress(p, 'crystal', 1);
  return n;
}

// ───────── 동료 ─────────
export function heroineUnlocked(p, id) {
  const u = HEROINE_META[id].unlock;
  return !u || (p.bossKills[u.boss] || 0) >= 1;
}
function refreshDay(p, h) {
  const k = todayKey();
  if (h.day !== k) { h.day = k; h.talks = 0; h.touches = 0; h.gifts = 0; h.minis = 0; }
}
export function heroineState(p, id) { const h = p.heroines[id]; refreshDay(p, h); return h; }
export function addAff(p, id, n) {
  const h = p.heroines[id];
  const before = h.lv;
  h.aff = Math.max(0, h.aff + n);
  h.lv = Math.min(AFF_MAX_LV, affLevel(h.aff));
  const ups = [];
  if (h.lv > before) {
    for (let l = before + 1; l <= h.lv; l++) {
      ups.push(l);
      for (const o of HEROINE_META[id].outfits) if (o.lv === l && !h.outfits.includes(o.id)) h.outfits.push(o.id);
    }
  }
  return ups;
}
export function canTalk(p, id) { return heroineState(p, id).talks < DAILY.talk; }
export function canTouch(p, id) { return heroineState(p, id).touches < DAILY.touch; }
export function canGift(p, id) { return heroineState(p, id).gifts < DAILY.gift; }
export function pickTalk(p, id, data, rng = Math.random) {
  const h = heroineState(p, id);
  const pool = data.talks.filter((t) => t.minLv <= h.lv);
  const fresh = pool.filter((t) => !h.talkSeen.includes(t.id));
  const list = fresh.length ? fresh : pool;
  return list[Math.floor(rng() * list.length)];
}
export function doTalk(p, id, talk, choiceIdx) {
  const h = heroineState(p, id);
  if (h.talks >= DAILY.talk) return null;
  const ch = talk.choices[choiceIdx];
  h.talks++;
  if (!h.talkSeen.includes(talk.id)) h.talkSeen.push(talk.id);
  if (h.talkSeen.length >= 20) h.talkSeen = [];
  p.stats.talks++;
  dailyProgress(p, 'talk', 1);
  const ups = addAff(p, id, ch.aff + 1);
  return { aff: ch.aff + 1, ups };
}
export function doTouch(p, id) {
  const h = heroineState(p, id);
  if (h.touches >= DAILY.touch) return null;
  h.touches++;
  return { aff: 1, ups: addAff(p, id, 1) };
}
export function giftKind(data, giftId) {
  if (data.gifts.love.includes(giftId)) return 'love';
  if (data.gifts.like.includes(giftId)) return 'like';
  if (data.gifts.dislike.includes(giftId)) return 'dislike';
  return 'neutral';
}
export function doGift(p, id, data, giftId) {
  const h = heroineState(p, id);
  if (h.gifts >= DAILY.gift || !(p.inv.gifts[giftId] > 0)) return null;
  h.gifts++;
  p.inv.gifts[giftId]--;
  if (!p.inv.gifts[giftId]) delete p.inv.gifts[giftId];
  const kind = giftKind(data, giftId);
  p.stats.gifts++;
  dailyProgress(p, 'gift', 1);
  return { kind, aff: GIFT_AFF[kind], ups: addAff(p, id, GIFT_AFF[kind]) };
}
export function addGift(p, giftId, n = 1) { p.inv.gifts[giftId] = (p.inv.gifts[giftId] || 0) + n; }
export function pendingScenes(p, id) {
  const h = p.heroines[id];
  const out = [];
  for (let l = 1; l <= h.lv; l++) if (!h.seen.includes(l)) out.push(l);
  return out;
}

// ───────── 일일 임무 ─────────
export const MISSION_DEFS = {
  kill: { name: (n) => `적 ${n}마리 처치`, n: [20, 30] },
  win: { name: (n) => `전투 ${n}회 승리`, n: [6, 10] },
  elite: { name: (n) => `엘리트 ${n}회 처치`, n: [1, 2] },
  talk: { name: (n) => `동료와 대화 ${n}회`, n: [2, 4] },
  gift: { name: (n) => `선물 ${n}번 주기`, n: [1, 2] },
  mini: { name: (n) => `놀이 ${n}회 하기`, n: [2, 3] },
  fish: { name: (n) => `물고기 ${n}마리 낚기`, n: [3, 5] },
  crystal: { name: () => '별빛 수정 수확하기', n: [1, 1] },
  fortune: { name: (n) => `운명 기술 ${n}회 사용`, n: [2, 4] },
  run: { name: () => '원정 떠나기', n: [1, 1] },
  node: { name: (n) => `미궁 칸 ${n}개 지나기`, n: [10, 16] },
};
export function ensureDaily(p) {
  const k = todayKey();
  if (p.daily && p.daily.key === k) return p.daily;
  const r = new Rng(hashStr('missions-' + k + '-' + p.created));
  const keys = r.sample(Object.keys(MISSION_DEFS), 3);
  p.daily = { key: k, missions: keys.map((id) => { const d = MISSION_DEFS[id]; return { id, n: r.int(d.n[0], d.n[1]), prog: 0, claimed: false }; }), bonus: false };
  return p.daily;
}
export function dailyProgress(p, id, n) {
  const d = ensureDaily(p);
  for (const m of d.missions) if (m.id === id && !m.claimed) m.prog = Math.min(m.n, m.prog + n);
}
export const MISSION_REWARD = { shards: 30, dust: 120 };
export function claimMission(p, i) {
  const d = ensureDaily(p);
  const m = d.missions[i];
  if (!m || m.claimed || m.prog < m.n) return false;
  m.claimed = true;
  p.shards += MISSION_REWARD.shards;
  p.dust += MISSION_REWARD.dust;
  return true;
}
export function claimDailyBonus(p) {
  const d = ensureDaily(p);
  if (d.bonus || !d.missions.every((m) => m.claimed)) return false;
  d.bonus = true;
  p.shards += 40;
  addGift(p, 'star_candy', 1);
  p.stats.dailyDays++;
  return true;
}

// ───────── 업적 ─────────
export function checkAchievements(p) {
  const got = [];
  for (const a of ACHIEVEMENTS) {
    if (p.ach[a.id]) continue;
    let ok = false;
    try { ok = a.c(p); } catch (e) { ok = false; }
    if (ok) { p.ach[a.id] = Date.now(); p.shards += a.r; got.push(a); }
  }
  return got;
}

// ───────── 원정 시작·종료 ─────────
export function onRunStart(p, run) {
  p.stats.runs++;
  p.classes[run.cls].runs++;
  dailyProgress(p, 'run', 1);
  if (run.companion) p.lastCompanion = run.companion.id;
  p.nextBuff = null;
}

export function recordCodex(p, kind, id) { if (!p.codex[kind][id]) p.codex[kind][id] = 1; }

export function onRunEnd(p, run) {
  const shards = shardReward(run, p);
  const dust = Math.floor(run.stats.nodes * 4 + run.stats.elites * 10 + run.stats.bosses * 40);
  p.shards += shards;
  p.dust += dust;
  const c = p.classes[run.cls];
  const lvBefore = classLevel(c.xp);
  c.xp += shards;
  const lvAfter = classLevel(c.xp);
  c.bestAct = Math.max(c.bestAct, run.act);
  p.stats.maxAct = Math.max(p.stats.maxAct, run.act);
  p.stats.kills += run.stats.kills || 0;
  p.stats.maxHit = Math.max(p.stats.maxHit, run.stats.maxHit || 0);
  p.stats.maxGold = Math.max(p.stats.maxGold, run.stats.goldEarned || 0);
  p.stats.gambleWins += run.stats.gambleWins || 0;
  p.stats.fortunes += run.stats.fortunes || 0;
  const unlocks = [];
  let phaseUp = false;
  const cleared = run.over === 'win' || !!run.cleared;
  if (cleared) {
    p.stats.wins++; c.wins++;
    if (run.mode === 'normal' && run.phase >= c.phase && c.phase < MAX_PHASE) { c.phase = run.phase + 1; phaseUp = true; }
    if (run.mode === 'daily' && run.over === 'win') p.stats.challengeWins++;
  }
  if (run.mode === 'daily') { p.challenge.done = true; p.challenge.best = Math.max(p.challenge.best, run.act); }
  for (const g of run.gifts) addGift(p, g, 1);
  for (const id in run.affGain) addAff(p, id, run.affGain[id]);
  p.run = null;
  return { shards, dust, lvBefore, lvAfter, unlocks, phaseUp };
}

// 보스 처치 시 즉시 해금 처리
export function onBossKill(p, act) {
  const a = Math.min(4, ((act - 1) % 4) + 1);
  const first = (p.bossKills[a] || 0) === 0;
  p.bossKills[a] = (p.bossKills[a] || 0) + 1;
  const out = [];
  if (!first) return out;
  for (const c of CLASSES) {
    if (c.unlock && c.unlock.boss === a && !p.unlocked.classes.includes(c.id)) { p.unlocked.classes.push(c.id); out.push({ k: 'class', id: c.id }); }
  }
  for (const id of HEROINE_IDS) {
    const u = HEROINE_META[id].unlock;
    if (u && u.boss === a) { p.heroines[id].met = true; out.push({ k: 'heroine', id }); }
  }
  if (a === 3 && !p.unlocked.act4) { p.unlocked.act4 = true; out.push({ k: 'act4' }); }
  return out;
}
