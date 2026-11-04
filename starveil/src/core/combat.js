// 전투 엔진 — 순수 로직. 화면은 c.ev(이벤트 로그)를 받아 연출만 해요.
import { Rng } from './rng.js';
import { resolveSkill, FORTUNE_SKILLS } from '../data/skills.js';
import { relicById } from '../data/relics.js';
import { POTION_BY_ID, POTIONS } from '../data/potions.js';
import { enemyById } from '../data/enemies.js';
import { DICE_BY_ID } from '../data/dice_index.js';
import { STATUS } from '../data/statuses.js';
import { companionAssist } from '../data/companions.js';

export const MAX_ENEMIES = 4;
export const FREEZE_AT = 3;
export const ENRAGE_TURN = 20;
export function freezeAt(e) { return e.def.kind === 'boss' ? 8 : e.def.kind === 'elite' ? 5 : FREEZE_AT; }

const evalV = (v, d) => (typeof v === 'number' ? v : Math.floor(v.b + v.m * d));

// ───────── 생성 ─────────
export function createCombat(run, enemyIds, opt = {}) {
  const h = run.hero;
  const c = {
    rng: new Rng(opt.seed || 12345),
    run, kind: opt.kind || 'normal', scale: opt.scale || { hp: 1, atk: 1 },
    turn: 0, over: null, ev: [], uidSeq: 0,
    h: { uid: 'hero', hp: h.hp, maxHp: h.maxHp, block: 0, st: {} },
    cls: h.cls,
    rerolls: 0, fortune: 0, turnUses: 0, firstTurn: true,
    dice: [], extraDice: 0, tempDice: 0,
    skills: h.skills.map((s, i) => {
      const def = resolveSkill(s.id, s.up);
      return { i, id: s.id, up: !!s.up, def, used: 0, cdLeft: def.cd || 0, pending: [] };
    }),
    enemies: [],
    relics: h.relics.slice(),
    rs: {}, // 유물별 전투 상태
    stats: { dmg: 0, kills: 0, maxHit: 0, uses: 0, gambleWins: 0 },
    assist: null,
    phoenixUsed: !!h.phoenixUsed,
  };
  // 유물 정적 수치
  const m = sumMods(c.relics);
  c.rerollsMax = (h.rerolls || 1) + (m.rerolls || 0);
  c.fortuneMax = Math.max(6, (h.fortuneMax || 15) + (m.fortuneMax || 0));
  c.dmgMult = 1 + (m.dmgMult || 0);
  c.blockMult = 1 + (m.blockMult || 0);
  c.stBonus = m.stBonus || {};
  c.extraDice = m.dice || 0;
  if (opt.companion) {
    const a = companionAssist(opt.companion.id, opt.companion.lv);
    c.assist = { id: opt.companion.id, lv: opt.companion.lv, charge: 0, max: a.max, name: a.name };
  }
  for (const id of enemyIds) spawn(c, id);
  if (opt.mods) applyRunMods(c, opt.mods);
  return c;
}

function applyRunMods(c, mods) {
  if (mods.enemyStr) for (const e of c.enemies) addSt(e, 'str', mods.enemyStr);
  if (mods.heroStartBlock) c.h.block += mods.heroStartBlock;
}

export function sumMods(relics) {
  const m = { stBonus: {} };
  for (const id of relics) {
    const r = relicById(id);
    if (!r || !r.mods) continue;
    for (const k in r.mods) {
      if (k === 'stBonus') { for (const s in r.mods.stBonus) m.stBonus[s] = (m.stBonus[s] || 0) + r.mods.stBonus[s]; }
      else m[k] = (m[k] || 0) + r.mods[k];
    }
  }
  return m;
}

export function spawn(c, id, atHp) {
  const def = enemyById(id);
  if (!def) throw new Error('unknown enemy ' + id);
  const base = Array.isArray(def.hp) ? c.rng.int(def.hp[0], def.hp[1]) : def.hp;
  const hp = Math.max(1, Math.round(base * c.scale.hp));
  const e = {
    uid: 'e' + (++c.uidSeq), id, def, hp: atHp || hp, maxHp: hp, block: 0, st: { ...(def.st || {}) },
    mi: def.first || 0, intent: null, phase: 1, dead: false, rep: 0, lastMove: null,
  };
  c.enemies.push(e);
  pickIntent(c, e);
  return e;
}

export const alive = (c) => c.enemies.filter((e) => !e.dead);

// ───────── 이벤트 ─────────
function ev(c, e) { c.ev.push(e); }
export function drain(c) { const out = c.ev; c.ev = []; return out; }

// ───────── 유물 훅 ─────────
function api(c, id) {
  return {
    c, h: c.h, id,
    get enemies() { return alive(c); },
    rng: c.rng,
    st: c.rs[id] || (c.rs[id] = {}),
    flash() { ev(c, { k: 'relic', id }); },
    hit(e, amt, o = {}) { if (e && !e.dead) damage(c, e, amt, { kind: 'relic', pierce: o.pierce }); },
    block(n) { gainBlock(c, c.h, n, true); },
    heal(n) { heal(c, c.h, n); },
    status(u, s, n) { applyStatus(c, u, s, n); },
    gold(n) { gainGold(c, n); },
    fortune(n) { addFortune(c, n); },
    reroll(n) { c.rerolls += n; ev(c, { k: 'reroll', n: c.rerolls }); },
    addDie(type, value) { return addDie(c, type || 'normal', value); },
    text(t, color) { ev(c, { k: 'text', u: 'hero', t, color }); },
  };
}
function fire(c, name, payload) {
  for (const id of c.relics) {
    const r = relicById(id);
    if (r && r.on && r.on[name]) {
      const res = r.on[name](api(c, id), payload);
      if (res === true) return true;
    }
    if (c.over && name !== 'win') return false;
  }
  return false;
}

// ───────── 기본 동작 ─────────
function addSt(u, s, n) { u.st[s] = (u.st[s] || 0) + n; if (u.st[s] <= 0) delete u.st[s]; }

export function applyStatus(c, u, s, n) {
  if (!u || u.dead || n <= 0) return;
  if (u !== c.h && STATUS[s] && STATUS[s].debuff && c.stBonus[s]) n += c.stBonus[s];
  if (u !== c.h && u.def.immune && u.def.immune.includes(s)) { ev(c, { k: 'text', u: u.uid, t: '면역', color: '#cfc8ff' }); return; }
  addSt(u, s, n);
  ev(c, { k: 'status', u: u.uid, s, n, total: u.st[s] || 0 });
}

function gainBlock(c, u, n, raw) {
  if (n <= 0) return;
  let amt = n;
  if (!raw && u === c.h) amt = Math.floor((n + (u.st.dex || 0)) * c.blockMult);
  u.block += amt;
  ev(c, { k: 'block', u: u.uid, amt, block: u.block });
}

function heal(c, u, n) {
  if (n <= 0 || u.dead) return;
  const amt = Math.min(n, u.maxHp - u.hp);
  u.hp += amt;
  ev(c, { k: 'heal', u: u.uid, amt, hp: u.hp });
}

function gainGold(c, n) {
  if (n <= 0) return;
  c.run.hero.gold += n;
  c.run.stats.goldEarned = (c.run.stats.goldEarned || 0) + n;
  ev(c, { k: 'gold', amt: n, gold: c.run.hero.gold });
}

function addFortune(c, n) {
  if (n <= 0) return;
  c.fortune = Math.min(c.fortuneMax, c.fortune + n);
  ev(c, { k: 'fortune', n: c.fortune, max: c.fortuneMax });
}

// 공격 피해 계산(힘·약화·취약 반영)
export function attackValue(c, src, tgt, base) {
  let amt = base;
  if (src) {
    amt += src.st.str || 0;
    if (src.st.weak > 0) amt *= 0.75;
    if (src === c.h) amt *= c.dmgMult;
  }
  if (tgt && tgt.st.vuln > 0) amt *= 1.5;
  return Math.max(0, Math.floor(amt));
}

function hit(c, src, tgt, base, o = {}) {
  if (!tgt || tgt.dead || c.over) return 0;
  const amt = attackValue(c, src, tgt, base);
  return damage(c, tgt, amt, { src, pierce: o.pierce, kind: 'atk' });
}

function damage(c, tgt, amt, o = {}) {
  if (tgt.dead || c.over) return 0;
  let blocked = 0;
  if (!o.pierce && tgt.block > 0) { blocked = Math.min(tgt.block, amt); tgt.block -= blocked; amt -= blocked; }
  tgt.hp -= amt;
  if (tgt.hp < 0) tgt.hp = 0;
  ev(c, { k: 'dmg', u: tgt.uid, amt, blocked, hp: tgt.hp, block: tgt.block, kind: o.kind || 'atk' });
  if (tgt !== c.h && amt > 0) {
    c.stats.dmg += amt;
    if (amt > c.stats.maxHit) c.stats.maxHit = amt;
  }
  if (tgt === c.h && amt > 0) fire(c, 'hurt', { amt });
  // 가시
  if (o.kind === 'atk' && o.src && !o.src.dead && tgt.st.thorns > 0 && tgt.hp > 0) {
    damage(c, o.src, tgt.st.thorns, { kind: 'thorns' });
  }
  if (tgt.hp <= 0) onDeath(c, tgt);
  else if (tgt !== c.h) checkPhase(c, tgt);
  return amt;
}

function onDeath(c, u) {
  if (u === c.h) {
    if (fire(c, 'lethal', {})) return; // 부활 유물
    c.over = 'lose';
    ev(c, { k: 'lose' });
    return;
  }
  u.dead = true;
  u.block = 0;
  c.stats.kills++;
  ev(c, { k: 'death', u: u.uid });
  if (u.def.onDeath && u.def.onDeath.split) {
    for (const sid of u.def.onDeath.split) if (alive(c).length < MAX_ENEMIES) { const n = spawn(c, sid); ev(c, { k: 'spawn', u: n.uid }); }
  }
  fire(c, 'kill', { e: u });
  if (alive(c).length === 0 && !c.over) {
    c.over = 'win';
    fire(c, 'win', {});
    ev(c, { k: 'win' });
  }
}

function checkPhase(c, e) {
  const d = e.def;
  if (d.moves2 && e.phase === 1 && e.hp <= e.maxHp * 0.5) {
    e.phase = 2; e.mi = 0;
    if (d.phaseLine) ev(c, { k: 'say', u: e.uid, t: d.phaseLine });
    if (d.phaseSt) for (const s in d.phaseSt) applyStatus(c, e, s, d.phaseSt[s]);
    pickIntent(c, e);
    ev(c, { k: 'intent', u: e.uid });
  }
}

// ───────── 주사위 ─────────
function rollFace(c, type) {
  const def = DICE_BY_ID[type] || DICE_BY_ID.normal;
  return c.rng.pick(def.faces);
}

function addDie(c, type, value) {
  const d = { id: 'd' + (++c.uidSeq), type, value: value || rollFace(c, type), used: false, frozen: false, temp: true };
  c.dice.push(d);
  ev(c, { k: 'die_new', id: d.id, value: d.value });
  return d;
}

export function isWild(c, d) {
  if (!d) return false;
  if (d.value === 6 && (DICE_BY_ID[d.type]?.wild6 || c.relics.includes('sixth_star'))) return true;
  return false;
}

function rollAll(c) {
  const types = c.run.hero.dice.slice();
  const extra = c.extraDice + (c.firstTurn ? (c.rs._firstExtra || 0) : 0) + c.tempDice;
  for (let i = 0; i < extra; i++) types.push('normal');
  c.tempDice = 0;
  c.dice = types.map((t) => ({ id: 'd' + (++c.uidSeq), type: t, value: rollFace(c, t), used: false, frozen: false }));
  const fr = Math.min(c.h.st.frost || 0, c.dice.length);
  for (let i = 0; i < fr; i++) c.dice[c.dice.length - 1 - i].frozen = true;
  if (c.h.st.frost) { delete c.h.st.frost; }
  ev(c, { k: 'roll' });
  fire(c, 'roll', { dice: c.dice });
}

// ───────── 요구 조건 ─────────
export function dieOk(c, skill, die) {
  if (!die || die.used || die.frozen) return false;
  const s = skill.def;
  if (skill.used >= (s.uses || 1)) return false;
  if (s.cd) return true;
  const wild = isWild(c, die);
  const req = s.req;
  const slots = s.slots || 1;
  if (slots === 1) {
    if (!req || wild) return true;
    const v = die.value;
    if (req.min && v < req.min) return false;
    if (req.max && v > req.max) return false;
    if (req.eq && v !== req.eq) return false;
    if (req.even && v % 2 !== 0) return false;
    if (req.odd && v % 2 !== 1) return false;
    return true;
  }
  // 여러 칸
  const placed = skill.pending.map((id) => c.dice.find((x) => x.id === id)).filter(Boolean);
  const vals = placed.map((x) => x.value);
  if (wild && !req.sum) return true;
  if (req.same) {
    const nonWild = placed.filter((x) => !isWild(c, x)).map((x) => x.value);
    return nonWild.every((v) => v === die.value);
  }
  if (req.sum) {
    const sum = vals.reduce((a, b) => a + b, 0) + die.value;
    if (placed.length + 1 === slots) return sum === req.sum;
    return sum < req.sum;
  }
  if (req.straight) {
    const nonWild = placed.filter((x) => !isWild(c, x)).map((x) => x.value);
    const all = nonWild.concat([die.value]);
    if (new Set(all).size !== all.length) return false;
    return Math.max(...all) - Math.min(...all) <= slots - 1;
  }
  return true;
}

export function skillReady(c, skill) {
  return skill.used < (skill.def.uses || 1);
}

// ───────── 기술 사용 ─────────
export function placeDie(c, si, dieId, targetUid) {
  if (c.over) return [];
  const skill = c.skills[si];
  const die = c.dice.find((d) => d.id === dieId);
  if (!skill || !die || !dieOk(c, skill, die)) return [];
  die.used = true;
  const s = skill.def;
  const target = pickTarget(c, targetUid);
  if (s.cd) {
    skill.cdLeft -= die.value;
    ev(c, { k: 'cd', si, left: Math.max(0, skill.cdLeft) });
    applyDieOn(c, [die], target);
    if (skill.cdLeft <= 0) {
      skill.cdLeft = s.cd;
      skill.used++;
      execSkill(c, skill, die.value, [die], target);
    }
    return drain(c);
  }
  if ((s.slots || 1) > 1) {
    skill.pending.push(die.id);
    ev(c, { k: 'pend', si, n: skill.pending.length });
    if (skill.pending.length < s.slots) return drain(c);
    const ds = skill.pending.map((id) => c.dice.find((x) => x.id === id));
    skill.pending = [];
    skill.used++;
    const sum = ds.reduce((a, b) => a + b.value, 0);
    applyDieOn(c, ds, target);
    execSkill(c, skill, sum, ds, target);
    return drain(c);
  }
  skill.used++;
  applyDieOn(c, [die], target);
  execSkill(c, skill, die.value, [die], target);
  return drain(c);
}

export function cancelPending(c, si) {
  const skill = c.skills[si];
  if (!skill || !skill.pending.length) return [];
  for (const id of skill.pending) { const d = c.dice.find((x) => x.id === id); if (d) d.used = false; }
  skill.pending = [];
  ev(c, { k: 'pend', si, n: 0 });
  return drain(c);
}

function pickTarget(c, uid) {
  const al = alive(c);
  return al.find((e) => e.uid === uid) || al[0] || null;
}

function applyDieOn(c, dice, target) {
  for (const d of dice) {
    const on = DICE_BY_ID[d.type]?.on;
    if (!on) continue;
    if (on.block) gainBlock(c, c.h, on.block, true);
    if (on.heal) heal(c, c.h, on.heal);
    if (on.gold6 && d.value === 6) gainGold(c, on.gold6);
    if (target && !target.dead) {
      if (on.burn) applyStatus(c, target, 'burn', on.burn);
      if (on.frost) applyStatus(c, target, 'frost', on.frost);
      if (on.poison) applyStatus(c, target, 'poison', on.poison);
    }
  }
}

function execSkill(c, skill, d, dice, target) {
  ev(c, { k: 'use', si: skill.i, name: skill.def.name, icon: skill.def.icon, d });
  c.turnUses++;
  c.stats.uses++;
  runFx(c, skill.def.fx, { d, dice, target, skill });
  if (c.assist && c.assist.charge < c.assist.max) { c.assist.charge++; ev(c, { k: 'assist', charge: c.assist.charge }); }
  if (!c.over) fire(c, 'use', { skill: skill.def, d, dice, target });
}

function condOk(cond, d) {
  if (!cond) return true;
  if (cond.eq && d !== cond.eq) return false;
  if (cond.min && d < cond.min) return false;
  if (cond.max && d > cond.max) return false;
  return true;
}

export function runFx(c, fxList, ctx) {
  for (const fx of fxList) {
    if (c.over) return;
    if (!condOk(fx.cond, ctx.d)) continue;
    let target = ctx.target && !ctx.target.dead ? ctx.target : alive(c)[0];
    const val = fx.v !== undefined ? evalV(fx.v, ctx.d) : 0;
    switch (fx.t) {
      case 'dmg': {
        const hits = fx.hits || 1;
        for (let k = 0; k < hits; k++) {
          if (fx.aoe) for (const e of alive(c)) hit(c, c.h, e, val, fx);
          else { target = target && !target.dead ? target : alive(c)[0]; hit(c, c.h, target, val, fx); }
        }
        break;
      }
      case 'block': gainBlock(c, c.h, val); break;
      case 'heal': heal(c, c.h, val); break;
      case 'selfdmg': damage(c, c.h, val, { pierce: 1, kind: 'self' }); break;
      case 'st': {
        if (fx.self) applyStatus(c, c.h, fx.s, val);
        else if (fx.aoe) for (const e of alive(c)) applyStatus(c, e, fx.s, val);
        else applyStatus(c, target, fx.s, val);
        break;
      }
      case 'gold': gainGold(c, val); break;
      case 'reroll': c.rerolls += val; ev(c, { k: 'reroll', n: c.rerolls }); break;
      case 'fortune': addFortune(c, val); break;
      case 'cleanse': {
        for (const s of Object.keys(c.h.st)) if (STATUS[s] && STATUS[s].debuff) delete c.h.st[s];
        ev(c, { k: 'cleanse', u: 'hero' });
        break;
      }
      case 'die': dieFx(c, fx, ctx); break;
      case 'dmgBlock': if (target) hit(c, c.h, target, Math.floor(c.h.block * fx.m)); break;
      case 'dmgStatus': if (target) hit(c, c.h, target, Math.floor((target.st[fx.s] || 0) * fx.m)); break;
      case 'dmgGold': if (target) hit(c, c.h, target, Math.min(fx.cap || 999, Math.floor(c.run.hero.gold * fx.m))); break;
      case 'double': if (target && target.st[fx.s]) applyStatus(c, target, fx.s, target.st[fx.s]); break;
      case 'spread': {
        if (!target) break;
        const n = target.st[fx.s] || 0;
        if (n > 0) for (const e of alive(c)) if (e !== target) applyStatus(c, e, fx.s, n);
        break;
      }
      case 'execute': {
        if (target && !target.dead && target.def.kind !== 'boss' && target.hp <= target.maxHp * fx.pct / 100) {
          ev(c, { k: 'text', u: target.uid, t: '처형!', color: '#ff6b8a' });
          damage(c, target, target.hp, { pierce: 1, kind: 'exec' });
        }
        break;
      }
      case 'gamble': {
        const p = Math.min(0.95, fx.p + (c.rs._luck || 0));
        const win = c.rng.chance(p);
        if (win) c.stats.gambleWins++;
        ev(c, { k: 'gamble', win });
        runFx(c, win ? fx.win : fx.lose, ctx);
        break;
      }
      case 'potion': {
        const h = c.run.hero;
        if (h.potions.length < h.potionSlots) {
          const p = c.rng.pick(POTIONS.filter((x) => x.rar !== 'r'));
          h.potions.push(p.id);
          ev(c, { k: 'potion_get', id: p.id });
        } else ev(c, { k: 'text', u: 'hero', t: '물약 칸이 가득 찼어요', color: '#cfc8ff' });
        break;
      }
      case 'addDice': for (let k = 0; k < fx.v; k++) addDie(c, 'normal'); break;
      default: break;
    }
  }
}

function dieFx(c, fx, ctx) {
  const src = ctx.dice[0];
  const type = src ? src.type : 'normal';
  const d = ctx.d;
  switch (fx.mode) {
    case 'plus': addDie(c, type, Math.min(6, d + fx.v)); break;
    case 'flip': addDie(c, type, 7 - d); break;
    case 'set': addDie(c, type, fx.v); break;
    case 'new': addDie(c, type); break;
    case 'copy': addDie(c, type, d); addDie(c, type, d); break;
    case 'split': if (d >= 2) { addDie(c, 'normal', Math.floor(d / 2)); addDie(c, 'normal', Math.ceil(d / 2)); } break;
    default: break;
  }
}

// ───────── 재굴림·운명·물약·동료 ─────────
export function reroll(c, ids) {
  if (c.over || c.rerolls <= 0) return [];
  let targets = c.dice.filter((d) => !d.used && !d.frozen);
  if (ids && ids.length) targets = targets.filter((d) => ids.includes(d.id));
  if (!targets.length) return [];
  c.rerolls--;
  for (const d of targets) d.value = rollFace(c, d.type);
  ev(c, { k: 'reroll_dice', ids: targets.map((d) => d.id), n: c.rerolls });
  fire(c, 'roll', { dice: targets, reroll: true });
  return drain(c);
}

export function fortuneReady(c) { return c.fortune >= c.fortuneMax; }
export function useFortune(c, targetUid) {
  if (c.over || !fortuneReady(c)) return [];
  const f = FORTUNE_SKILLS[c.cls];
  c.fortune = c.relics.includes('ouroboros') ? Math.floor(c.fortuneMax / 2) : 0;
  ev(c, { k: 'fortune_use', name: f.name, n: c.fortune });
  runFx(c, f.fx, { d: 0, dice: [], target: pickTarget(c, targetUid) });
  c.run.stats.fortunes = (c.run.stats.fortunes || 0) + 1;
  return drain(c);
}

export function usePotion(c, pi, targetUid) {
  if (c.over) return [];
  const h = c.run.hero;
  const id = h.potions[pi];
  const p = POTION_BY_ID[id];
  if (!p) return [];
  h.potions.splice(pi, 1);
  ev(c, { k: 'potion', id });
  const target = pickTarget(c, targetUid);
  if (p.special === 'maxhp') { c.h.maxHp += p.v; c.h.hp += p.v; h.maxHp += p.v; ev(c, { k: 'heal', u: 'hero', amt: p.v, hp: c.h.hp }); }
  else if (p.special === 'fortune') addFortune(c, c.fortuneMax);
  else runFx(c, p.fx, { d: 0, dice: [], target });
  c.run.stats.potions = (c.run.stats.potions || 0) + 1;
  return drain(c);
}

export function assistReady(c) { return c.assist && c.assist.charge >= c.assist.max; }
export function useAssist(c, targetUid) {
  if (c.over || !assistReady(c)) return [];
  const a = companionAssist(c.assist.id, c.assist.lv);
  c.assist.charge = 0;
  ev(c, { k: 'assist_use', id: c.assist.id, name: a.name });
  if (a.rerollUp) {
    for (const d of c.dice) if (!d.used && !d.frozen) d.value = Math.min(6, rollFace(c, d.type) + a.rerollUp);
    ev(c, { k: 'reroll_dice', ids: c.dice.filter((d) => !d.used).map((d) => d.id), n: c.rerolls });
  }
  runFx(c, a.fx, { d: 0, dice: [], target: pickTarget(c, targetUid) });
  return drain(c);
}

// ───────── 턴 진행 ─────────
export function startCombat(c) {
  fire(c, 'start', {});
  startTurn(c);
  return drain(c);
}

function startTurn(c) {
  if (c.over) return;
  c.turn++;
  c.turnUses = 0;
  const keep = c.relics.includes('hourglass') ? Math.floor(c.h.block / 2) : 0;
  c.h.block = keep;
  for (const s of c.skills) { s.used = 0; s.pending = []; }
  c.rerolls = c.rerollsMax;
  ev(c, { k: 'turn', n: c.turn });
  tickStart(c, c.h);
  if (c.over) return;
  rollAll(c);
  fire(c, 'turn', { n: c.turn });
  c.firstTurn = false;
}

function tickStart(c, u) {
  if (u.st.burn > 0) {
    const n = u.st.burn;
    u.st.burn = Math.floor(n / 2); if (!u.st.burn) delete u.st.burn;
    damage(c, u, n, { pierce: 1, kind: 'burn' });
  }
  if (!u.dead && !c.over && u.st.poison > 0) {
    const n = u.st.poison;
    addSt(u, 'poison', -1);
    damage(c, u, n, { pierce: 1, kind: 'poison' });
  }
}

function tickEnd(c, u) {
  if (u.st.regen > 0) { heal(c, u, u.st.regen); addSt(u, 'regen', -1); }
  if (u.st.weak > 0) addSt(u, 'weak', -1);
  if (u.st.vuln > 0) addSt(u, 'vuln', -1);
}

export function endTurn(c) {
  if (c.over) return [];
  for (const s of c.skills) if (s.pending.length) cancelPending(c, s.i);
  const unused = c.dice.filter((d) => !d.used && !d.frozen);
  const sum = unused.reduce((a, b) => a + b.value, 0);
  if (sum > 0) addFortune(c, sum);
  fire(c, 'end', { unused });
  if (c.over) return drain(c);
  tickEnd(c, c.h);
  ev(c, { k: 'enemy_phase' });
  for (const e of c.enemies.slice()) {
    if (e.dead || c.over) continue;
    enemyTurn(c, e);
  }
  if (!c.over) {
    for (const e of alive(c)) { tickEnd(c, e); pickIntent(c, e); }
    if (c.turn >= ENRAGE_TURN) for (const e of alive(c)) { applyStatus(c, e, 'str', 3); }
    if (c.turn === ENRAGE_TURN) ev(c, { k: 'text', u: 'hero', t: '적들이 광폭해졌어요!', color: '#ff6b8a' });
    ev(c, { k: 'intents' });
    startTurn(c);
  }
  return drain(c);
}

// ───────── 적 ─────────
function pickIntent(c, e) {
  const d = e.def;
  const moves = (e.phase === 2 && d.moves2) || d.moves;
  let m;
  if ((e.phase === 2 ? d.pattern2 : d.pattern) === 'random') {
    let tries = 0;
    do {
      m = c.rng.weighted(moves.map((x) => [x, x.w || 1]));
      tries++;
    } while (tries < 6 && m === e.lastMove && e.rep >= 1);
    // 소환 제한
    if (m.t === 'summon' && alive(c).length >= MAX_ENEMIES) m = moves.find((x) => x.t !== 'summon') || m;
  } else {
    m = moves[e.mi % moves.length];
    e.mi++;
    if (m.t === 'summon' && alive(c).length >= MAX_ENEMIES) { m = moves[e.mi % moves.length]; e.mi++; }
  }
  e.rep = m === e.lastMove ? e.rep + 1 : 0;
  e.lastMove = m;
  e.intent = m;
}

export function intentView(c, e) {
  const m = e.intent;
  if (!m) return null;
  const sc = c.scale.atk;
  const out = { t: m.t, s: m.s, name: m.name };
  if (m.t === 'atk' || m.t === 'atkdef' || m.t === 'steal' || m.t === 'drain') {
    out.v = attackValue(c, e, c.h, Math.round(m.v * sc));
    out.hits = m.hits || 1;
  }
  if (m.t === 'def' || m.t === 'atkdef') out.b = Math.round((m.b || m.v) * (m.t === 'def' ? 1 : 1) * Math.max(1, sc * 0.9));
  if (m.t === 'buff' || m.t === 'debuff') out.sv = m.sv || m.v;
  if (m.t === 'heal') out.v = Math.round(m.v * sc);
  return out;
}

function enemyTurn(c, e) {
  e.block = e.def.keepBlock ? e.block : 0;
  tickStart(c, e);
  if (e.dead || c.over) return;
  if ((e.st.frost || 0) >= freezeAt(e)) {
    addSt(e, 'frost', -freezeAt(e));
    ev(c, { k: 'frozen', u: e.uid });
    return;
  }
  const m = e.intent;
  if (!m) return;
  const sc = c.scale.atk;
  ev(c, { k: 'act', u: e.uid, t: m.t });
  switch (m.t) {
    case 'atk': case 'atkdef': case 'steal': case 'drain': {
      const hits = m.hits || 1;
      for (let k = 0; k < hits && !c.over && !e.dead; k++) {
        const dealt = hit(c, e, c.h, Math.round(m.v * sc));
        if (m.t === 'drain' && dealt > 0) heal(c, e, dealt);
      }
      if (c.over || e.dead) break;
      if (m.t === 'atkdef') gainBlock(c, e, Math.round(m.b * Math.max(1, sc * 0.9)));
      if (m.t === 'steal') {
        const g = Math.min(c.run.hero.gold, m.g || 8);
        if (g > 0) { c.run.hero.gold -= g; ev(c, { k: 'gold', amt: -g, gold: c.run.hero.gold }); }
      }
      if (m.s) applyStatus(c, c.h, m.s, m.sv || 1);
      break;
    }
    case 'def': gainBlock(c, e, Math.round(m.v * Math.max(1, sc * 0.9))); if (m.s) applyStatus(c, e, m.s, m.sv || 1); break;
    case 'buff': {
      const tg = m.all ? alive(c) : [e];
      for (const x of tg) applyStatus(c, x, m.s, m.v);
      break;
    }
    case 'debuff': applyStatus(c, c.h, m.s, m.v); if (m.s2) applyStatus(c, c.h, m.s2, m.v2 || 1); break;
    case 'heal': {
      const al = alive(c);
      const tgt = al.reduce((a, b) => (b.hp / b.maxHp < a.hp / a.maxHp ? b : a), al[0]);
      heal(c, m.self ? e : tgt, Math.round(m.v * sc));
      break;
    }
    case 'summon': {
      const ids = Array.isArray(m.id) ? m.id : [m.id];
      for (const id of ids) if (alive(c).length < MAX_ENEMIES) { const n = spawn(c, id); ev(c, { k: 'spawn', u: n.uid }); }
      break;
    }
    case 'charge': ev(c, { k: 'text', u: e.uid, t: m.name || '힘을 모으는 중', color: '#ffcf5a' }); break;
    default: break;
  }
  if (m.say && !c.over) ev(c, { k: 'say', u: e.uid, t: m.say });
}

// 전투 종료 후 런에 결과 반영
export function finishCombat(c) {
  const h = c.run.hero;
  h.hp = Math.max(0, Math.min(c.h.hp, c.h.maxHp));
  h.maxHp = c.h.maxHp;
  h.phoenixUsed = c.phoenixUsed;
  const st = c.run.stats;
  st.kills = (st.kills || 0) + c.stats.kills;
  st.dmg = (st.dmg || 0) + c.stats.dmg;
  st.maxHit = Math.max(st.maxHit || 0, c.stats.maxHit);
  st.turns = (st.turns || 0) + c.turn;
  st.uses = (st.uses || 0) + c.stats.uses;
  st.gambleWins = (st.gambleWins || 0) + c.stats.gambleWins;
}
