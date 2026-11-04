// 기술·유물·물약 설명문. d 가 주어지면 실제 수치로 미리보기
import { STATUS } from '../data/statuses.js';
import { relicById, RELIC_RAR_NAME } from '../data/relics.js';
import { POTION_BY_ID } from '../data/potions.js';
import { DICE_BY_ID } from '../data/dice_index.js';

const D = '<svg class="dtok" viewBox="0 0 20 20"><rect x="1" y="1" width="18" height="18" rx="5" fill="#f3ecff"/><g fill="#2a2150"><circle cx="6" cy="6" r="1.9"/><circle cx="14" cy="14" r="1.9"/><circle cx="10" cy="10" r="1.9"/><circle cx="14" cy="6" r="1.9"/><circle cx="6" cy="14" r="1.9"/></g></svg>';
function val(v, d) {
  if (typeof v === 'number') return String(v);
  if (d !== undefined && d !== null) return `<b class="gold">${Math.floor(v.b + v.m * d)}</b>`;
  if (v.m === 0) return String(v.b);
  let s = v.m === 1 ? D : v.m === 0.5 ? `${D}÷2` : `${D}×${v.m}`;
  if (v.b > 0) s += `+${v.b}`;
  else if (v.b < 0) s += `${v.b}`;
  return s;
}
const stn = (s) => (STATUS[s] ? STATUS[s].name : s);

export function fxText(fx, d) {
  const parts = [];
  for (const e of fx) {
    let t = '';
    const cond = e.cond ? (e.cond.eq ? `${e.cond.eq}이면 ` : e.cond.min ? `${e.cond.min} 이상이면 ` : '') : '';
    switch (e.t) {
      case 'dmg': t = `${e.aoe ? '모든 적에게 ' : ''}피해 ${val(e.v, d)}${e.hits > 1 ? `×${e.hits}` : ''}${e.pierce ? ' (방어 무시)' : ''}`; break;
      case 'block': t = `방어도 ${val(e.v, d)}`; break;
      case 'heal': t = `체력 ${val(e.v, d)} 회복`; break;
      case 'selfdmg': t = `체력 ${val(e.v, d)} 잃기`; break;
      case 'st': t = e.self ? `${stn(e.s)} ${val(e.v, d)} 얻기` : `${e.aoe ? '모든 적에게 ' : ''}${stn(e.s)} ${val(e.v, d)}`; break;
      case 'gold': t = `골드 ${val(e.v, d)}`; break;
      case 'reroll': t = `재굴림 +${val(e.v, d)}`; break;
      case 'fortune': t = `운명 +${val(e.v, d)}`; break;
      case 'cleanse': t = '해로운 효과 모두 제거'; break;
      case 'die': t = { plus: `눈 +${e.v} 주사위로 돌려받기`, flip: '뒤집은 눈(7−눈) 주사위로 돌려받기', set: `눈 ${e.v} 주사위로 돌려받기`, new: '새로 굴린 주사위로 돌려받기', copy: '같은 눈 주사위 2개로 돌려받기', split: '눈을 반으로 나눈 주사위 2개로 돌려받기' }[e.mode]; break;
      case 'dmgBlock': t = `현재 방어도${e.m !== 1 ? `×${e.m}` : ''}만큼 피해`; break;
      case 'dmgStatus': t = `대상의 ${stn(e.s)}×${e.m}만큼 피해`; break;
      case 'dmgGold': t = `보유 골드의 ${Math.round(e.m * 100)}%만큼 피해 (최대 ${e.cap})`; break;
      case 'double': t = `대상의 ${stn(e.s)} 2배`; break;
      case 'spread': t = `대상의 ${stn(e.s)}를 다른 적 모두에게 퍼뜨리기`; break;
      case 'execute': t = `체력 ${e.pct}% 이하인 적 처치 (보스 제외)`; break;
      case 'gamble': t = `<span class="pinkc">${Math.round(e.p * 100)}%</span> 확률로 ${fxText(e.win, d)} · 실패하면 ${e.lose.length ? fxText(e.lose, d) : '아무 일 없음'}`; break;
      case 'potion': t = '무작위 물약 얻기'; break;
      case 'addDice': t = `주사위 ${e.v}개 추가`; break;
      default: t = '';
    }
    if (t) parts.push(cond + t);
  }
  return parts.join(', ');
}

export function reqText(def) {
  if (def.cd) return `카운트 ${def.cd}`;
  const r = def.req;
  const slots = def.slots || 1;
  if (!r) return slots > 1 ? `주사위 ${slots}개` : '아무 눈';
  if (r.min) return `${r.min} 이상`;
  if (r.max) return `${r.max} 이하`;
  if (r.eq) return `${r.eq}만`;
  if (r.even) return '짝수';
  if (r.odd) return '홀수';
  if (r.same) return `같은 눈 ${slots}개`;
  if (r.sum) return `합 ${r.sum}`;
  if (r.straight) return `연속 ${slots}개`;
  return '';
}

export function skillDesc(def, d) {
  let s = fxText(def.fx, d);
  if (def.cd) s = `주사위를 넣은 만큼 카운트가 줄고, 0이 되면 ${s}`;
  if ((def.uses || 1) > 1) s += ` <span class="dim">(턴당 ${def.uses}회)</span>`;
  return s;
}

export function relicDesc(id) { const r = relicById(id); return r ? r.desc : ''; }
export function relicName(id) { const r = relicById(id); return r ? r.name : id; }
export function relicRar(id) { const r = relicById(id); return r ? r.rar : 'c'; }
export function rarName(r) { return RELIC_RAR_NAME[r] || ''; }
export const SKILL_RAR = { c: '일반', r: '희귀', e: '영웅', l: '전설' };
export function potionDesc(id) { const p = POTION_BY_ID[id]; return p ? p.desc : ''; }
export function diceDesc(id) { const d = DICE_BY_ID[id]; return d ? `${d.desc} <span class="dim">(눈: ${d.faces.join(' ')})</span>` : ''; }
