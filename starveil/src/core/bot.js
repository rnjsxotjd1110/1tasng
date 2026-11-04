// 자동 전투 AI. 게임의 '자동 전투'와 헤드리스 시뮬레이션이 함께 써요.
import { alive, dieOk, placeDie, reroll, endTurn, fortuneReady, useFortune, usePotion, assistReady, useAssist, intentView, attackValue, freezeAt } from './combat.js';
import { POTION_BY_ID } from '../data/potions.js';

const evalV = (v, d) => (typeof v === 'number' ? v : Math.floor(v.b + v.m * d));

export function incomingDamage(c) {
  let sum = 0;
  for (const e of alive(c)) {
    const iv = intentView(c, e);
    if (iv && iv.v && ['atk', 'atkdef', 'steal', 'drain'].includes(iv.t)) {
      if ((e.st.frost || 0) >= freezeAt(e)) continue;
      sum += iv.v * (iv.hits || 1);
    }
  }
  return sum;
}

function pickFocus(c) {
  const al = alive(c);
  if (!al.length) return null;
  // 가장 빨리 쓰러뜨릴 수 있는 적 우선
  return al.reduce((a, b) => (b.hp + b.block < a.hp + a.block ? b : a), al[0]);
}

function fxScore(c, fx, d, target, need) {
  let s = 0;
  const al = alive(c).length;
  for (const e of fx) {
    if (e.cond) {
      if (e.cond.eq && d !== e.cond.eq) continue;
      if (e.cond.min && d < e.cond.min) continue;
    }
    const v = e.v !== undefined ? evalV(e.v, d) : 0;
    switch (e.t) {
      case 'dmg': {
        const per = attackValue(c, c.h, target, v);
        const hits = e.hits || 1;
        const n = e.aoe ? al : 1;
        let dmg = per * hits * n;
        if (!e.aoe && target) dmg = Math.min(dmg, target.hp + (e.pierce ? 0 : target.block) + 4);
        s += dmg * 1.0;
        break;
      }
      case 'block': s += Math.min(v + (c.h.st.dex || 0), Math.max(0, need)) * 1.1 + v * 0.1; break;
      case 'heal': s += Math.min(v, c.h.maxHp - c.h.hp) * 0.9; break;
      case 'st': {
        const w = { burn: 1.6, poison: 2.2, frost: 2.2, weak: 3, vuln: 3.5, str: 6, dex: 4, thorns: 3, regen: 2.2 }[e.s] || 1;
        s += v * w * (e.aoe ? al : 1);
        break;
      }
      case 'gold': s += v * 0.3; break;
      case 'reroll': s += v * 2.5; break;
      case 'fortune': s += v * 0.6; break;
      case 'die': s += e.mode === 'copy' ? d * 1.6 : e.mode === 'split' ? 3 : e.mode === 'plus' ? Math.max(0, Math.min(6, d + e.v) - d) * 1.2 + 1 : e.mode === 'flip' ? Math.max(0, (7 - d) - d) + 1 : e.mode === 'set' ? 5 : 2; break;
      case 'cleanse': s += Object.keys(c.h.st).filter((k) => ['burn', 'poison', 'weak', 'vuln', 'frost'].includes(k)).length * 4; break;
      case 'dmgBlock': s += Math.floor(c.h.block * e.m); break;
      case 'dmgStatus': s += target ? Math.floor((target.st[e.s] || 0) * e.m) : 0; break;
      case 'dmgGold': s += Math.min(e.cap || 99, Math.floor(c.run.hero.gold * e.m)); break;
      case 'double': s += target ? (target.st[e.s] || 0) * 2 : 0; break;
      case 'spread': s += target ? (target.st[e.s] || 0) * (al - 1) * 1.5 : 0; break;
      case 'execute': s += target && target.def.kind !== 'boss' && target.hp <= target.maxHp * e.pct / 100 ? target.hp : 0; break;
      case 'gamble': s += fxScore(c, e.win, d, target, need) * e.p + fxScore(c, e.lose, d, target, need) * (1 - e.p); break;
      case 'selfdmg': s -= v * 1.2; break;
      case 'potion': s += c.run.hero.potions.length < c.run.hero.potionSlots ? 8 : 0; break;
      case 'addDice': s += v * 4; break;
      default: break;
    }
  }
  return s;
}

function bestMove(c) {
  const target = pickFocus(c);
  const need = incomingDamage(c) - c.h.block;
  let best = null;
  const free = c.dice.filter((d) => !d.used && !d.frozen);
  for (const sk of c.skills) {
    const s = sk.def;
    if (sk.used >= (s.uses || 1)) continue;
    const slots = s.slots || 1;
    if (s.cd) {
      for (const d of free) {
        if (!dieOk(c, sk, d)) continue;
        const fire = sk.cdLeft - d.value <= 0;
        const sc = fire ? fxScore(c, s.fx, 0, target, need) : d.value * 0.9;
        if (!best || sc > best.sc) best = { sc, sk, dice: [d] };
      }
      continue;
    }
    if (slots === 1) {
      for (const d of free) {
        if (!dieOk(c, sk, d)) continue;
        const sc = fxScore(c, s.fx, d.value, target, need);
        if (!best || sc > best.sc) best = { sc, sk, dice: [d] };
      }
    } else {
      // 여러 칸: 가능한 조합 탐색
      const combos = [];
      const rec = (start, arr) => {
        if (arr.length === slots) { combos.push(arr.slice()); return; }
        for (let i = start; i < free.length; i++) { arr.push(free[i]); rec(i + 1, arr); arr.pop(); }
      };
      if (free.length <= 7) rec(0, []);
      for (const cb of combos) {
        const saved = sk.pending;
        let ok = true;
        sk.pending = [];
        for (const d of cb) { if (!dieOk(c, sk, d)) { ok = false; break; } sk.pending.push(d.id); }
        sk.pending = saved;
        if (!ok) continue;
        const sum = cb.reduce((a, b) => a + b.value, 0);
        const sc = fxScore(c, s.fx, sum, target, need) - 2;
        if (!best || sc > best.sc) best = { sc, sk, dice: cb };
      }
    }
  }
  return best ? { ...best, target } : null;
}

// 한 동작 수행. 끝낼 동작이 없으면 false
export function botStep(c, opts = {}) {
  if (c.over) return false;
  const target = pickFocus(c);
  const tu = target ? target.uid : null;
  // 위급하면 물약
  const h = c.run.hero;
  if (opts.potions !== false && h.potions.length) {
    const inc = incomingDamage(c);
    for (let i = 0; i < h.potions.length; i++) {
      const p = POTION_BY_ID[h.potions[i]];
      const low = c.h.hp - Math.max(0, inc - c.h.block) < c.h.maxHp * 0.3;
      const boss = c.kind !== 'normal';
      if ((p.id === 'p_heal' && c.h.hp < c.h.maxHp * 0.4) || (low && ['p_block', 'p_heal', 'p_frost', 'p_weak'].includes(p.id)) ||
        (boss && c.turn === 1 && ['p_str', 'p_poison', 'p_fire', 'p_dice', 'p_luck', 'p_fate', 'p_giant'].includes(p.id))) {
        return { ev: usePotion(c, i, tu), what: 'potion' };
      }
    }
  }
  if (fortuneReady(c)) return { ev: useFortune(c, tu), what: 'fortune' };
  if (assistReady(c)) return { ev: useAssist(c, tu), what: 'assist' };
  const mv = bestMove(c);
  if (mv && mv.sc > 1.5) {
    let ev = [];
    for (const d of mv.dice) ev = ev.concat(placeDie(c, mv.sk.i, d.id, mv.target ? mv.target.uid : tu));
    return { ev, what: 'skill', si: mv.sk.i };
  }
  // 쓸 곳 없는 주사위 → 재굴림
  const free = c.dice.filter((d) => !d.used && !d.frozen);
  if (c.rerolls > 0 && free.length) {
    const low = free.filter((d) => d.value <= 3);
    const ev = reroll(c, (low.length ? low : free).map((d) => d.id));
    if (ev.length) return { ev, what: 'reroll' };
  }
  return false;
}

export function botTurn(c, opts) {
  let guard = 0;
  while (!c.over && guard++ < 40) { if (!botStep(c, opts)) break; }
  if (!c.over) endTurn(c);
}
