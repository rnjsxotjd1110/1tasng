// 원정 화면: 지도 + 노드 화면(보상·이벤트·상점·휴식·보물·구역 돌파·결과)
import { h, btn, ic, sheet, toast, countTo, numEl, confirmBox, wait } from './dom.js';
import { App, go, saveSoon, saveNow, checkAch, bgm, levelUpFx, refreshRes } from './app.js';
import { icon } from '../art/icons.js';
import { monsterSVG } from '../art/monsters.js';
import { heroineSVG } from '../art/heroines.js';
import { dieSVG } from '../art/dice.js';
import { fmt } from '../core/util.js';
import * as R from '../core/run.js';
import * as P from '../core/profile.js';
import { skillById, resolveSkill } from '../data/skills.js';
import { relicById } from '../data/relics.js';
import { POTION_BY_ID } from '../data/potions.js';
import { DICE_BY_ID } from '../data/dice_index.js';
import { EVENT_BY_ID } from '../data/events.js';
import { enemyById } from '../data/enemies.js';
import { CLASS_BY_ID, classLevel, CLASS_XP, CLASS_MAX_LV } from '../data/classes.js';
import { GIFT_BY_ID } from '../data/gifts.js';
import { HEROINES } from '../data/heroines/index.js';
import { skillDesc, reqText, relicDesc, rarName, SKILL_RAR, potionDesc, diceDesc } from './describe.js';
import { combatScreen } from './scr_combat.js';
import { hubScreen } from './scr_hub.js';
import { settingsSheet } from './scr_misc.js';
import { sfx } from '../audio/audio.js';

const NODE_ICON = { battle: 'battle', elite: 'elite', event: 'event', shop: 'shop', rest: 'rest', treasure: 'treasure' };
const NODE_NAME = { battle: '전투', elite: '엘리트', event: '이벤트', shop: '상점', rest: '휴식', treasure: '보물' };

export function syncCodex(p, run) {
  for (const s of run.hero.skills) P.recordCodex(p, 'skills', s.id);
  for (const r of run.hero.relics) P.recordCodex(p, 'relics', r);
}

export function runScreen(el) {
  const p = App.p;
  const run = p.run;
  if (!run) { go(hubScreen, 'home'); return; }
  syncCodex(p, run);
  const t = run.screen.type;
  App.onBack = () => { runMenu(); return true; };
  if (t === 'combat') return combatScreen(el);
  if (t === 'map') return mapView(el, run);
  el.classList.add('node-scr', 'scroll');
  const views = { reward: rewardView, event: eventView, eventResult: eventResultView, shop: shopView, rest: restView, treasure: treasureView, actClear: actClearView, end: endView, skillPick: skillPickView, remove: removeView };
  const fn = views[t];
  if (!fn) { run.screen = { type: 'map' }; go(runScreen); return; }
  if (t !== 'end') el.appendChild(hud(run));
  return fn(el, run);
}
const next = () => { saveSoon(); go(runScreen); };

// ───────── HUD ─────────
export function hud(run, opt = {}) {
  const hh = run.hero;
  const pct = Math.max(0, (hh.hp / hh.maxHp) * 100);
  const top = h('div.hud',
    h('div.grow', { style: { minWidth: '120px' } }, h('div.hpbar', h('b', { style: { width: pct + '%' } }), h('i', { style: { width: pct + '%' } }), h('span', { text: `${hh.hp} / ${hh.maxHp}` }))),
    h('span.pill', ic('coin', 'goldc'), h('span.num.gold', { text: fmt(hh.gold) })),
    h('button.icon-btn', { type: 'button', onclick: () => deckSheet(run), html: icon('cards') }),
    opt.noMenu ? null : h('button.icon-btn', { type: 'button', onclick: runMenu, html: icon('gear') }));
  const strip = h('div.relic-strip');
  for (const id of hh.relics) {
    const r = relicById(id);
    const c = h('button.relic-chip.rar-' + r.rar, { type: 'button', 'data-relic': id, html: icon(r.icon), onclick: () => infoSheet(r.name, `<span class="tag bg-${r.rar}">${rarName(r.rar)}</span><p style="line-height:1.6">${r.desc}</p>`) });
    strip.appendChild(c);
  }
  for (let i = 0; i < hh.potionSlots; i++) {
    const id = hh.potions[i];
    const pt = id ? POTION_BY_ID[id] : null;
    strip.appendChild(h('button.relic-chip', { type: 'button', style: { color: pt ? pt.color : 'var(--dim)', opacity: pt ? 1 : 0.35, borderStyle: pt ? 'solid' : 'dashed' }, html: icon('potion'), onclick: () => pt && infoSheet(pt.name, `<p>${pt.desc}</p><p class="dim t13">물약은 전투 중에 사용할 수 있어요.</p>`) }));
  }
  return h('div.col.gap', { style: { marginBottom: opt.mb ?? '10px' } }, top, strip);
}
function infoSheet(title, html) { sheet((b) => { b.innerHTML = html; }, { title, cls: 'small' }); }

export function runMenu() {
  const p = App.p;
  sheet((b, close) => {
    b.append(
      btn('덱 보기', () => { close(); deckSheet(p.run); }, { cls: 'ghost wide', icon: 'cards' }), h('div', { style: { height: '8px' } }),
      btn('설정', () => { close(); settingsSheet(); }, { cls: 'ghost wide', icon: 'gear' }), h('div', { style: { height: '8px' } }),
      btn('야영지로 잠시 돌아가기', () => { close(); saveNow(); go(hubScreen, 'home'); }, { cls: 'ghost wide', icon: 'tent' }), h('div', { style: { height: '8px' } }),
      btn('원정 포기', () => { close(); confirmBox('이번 원정을 포기할까요?<br><span class="dim">지금까지 모은 별조각은 받을 수 있어요.</span>', () => { R.finishRun(p.run, 'lose'); next(); }, { danger: true, yes: '포기' }); }, { cls: 'danger wide' }),
    );
  }, { title: '원정 메뉴', cls: 'small' });
}

export function deckSheet(run) {
  sheet((b) => {
    const hh = run.hero;
    b.appendChild(h('div.b', { text: `주사위 ${hh.dice.length}개` }));
    const dr = h('div.row.gap.wrap', { style: { margin: '8px 0 14px' } });
    for (const d of hh.dice) { const di = h('button.die', { type: 'button', html: dieSVG(6, d), style: { width: '44px', height: '44px' }, onclick: () => infoSheet(DICE_BY_ID[d].name, `<p>${diceDesc(d)}</p>`) }); dr.appendChild(di); }
    b.appendChild(dr);
    b.appendChild(h('div.b', { text: `기술 ${hh.skills.length} / ${hh.skillSlots}` }));
    const sl = h('div', { style: { margin: '8px 0 14px' } });
    for (const s of hh.skills) sl.appendChild(skillCard(s.id, s.up));
    b.appendChild(sl);
    b.appendChild(h('div.b', { text: `유물 ${hh.relics.length}개` }));
    for (const id of hh.relics) { const r = relicById(id); b.appendChild(h('div.item', h('div.ico.rar-' + r.rar, { html: icon(r.icon) }), h('div.grow', h('div.tt', { text: r.name }), h('div.ds', { text: r.desc })))); }
  }, { title: '나의 덱' });
}

export function skillCard(id, up, opt = {}) {
  const def = resolveSkill(id, up);
  const card = h((opt.tag || 'div') + '.skcard' + (opt.sel ? '.sel' : ''), opt.onclick ? { type: 'button', onclick: opt.onclick } : null,
    h('div.sk-ic.rar-' + def.rar, { html: icon(def.icon) }),
    h('div.grow',
      h('div.row.gap', h('span.b' + (up ? '.good' : ''), { text: def.name }), h('span.tag.bg-' + def.rar, { text: SKILL_RAR[def.rar] }), h('span.grow'), h('span.pill.t12.gold', { text: reqText(def) })),
      h('div.t13', { style: { marginTop: '5px', lineHeight: '1.5', color: '#dcd8f6' }, html: skillDesc(def) })));
  return card;
}

// ───────── 지도 ─────────
function mapView(el, run) {
  bgm('map');
  const a = R.actDef(run.act);
  const head = h('div.map-head',
    h('div.row.between', h('div', h('div.b.t18', { text: R.isAbyss(run) ? `심연 ${run.act - 4}층 · ${a.name}` : `${run.act}구역 · ${a.name}`, style: { color: a.accent } }), h('div.t12.muted', { text: a.sub })),
      run.mode === 'daily' ? h('span.pill.pinkc', { text: '오늘의 도전' }) : run.phase ? h('span.pill', { text: `위상 ${run.phase}` }) : null),
    hud(run, { mb: '0' }));
  const sc = h('div.map-scroll');
  const canvas = h('div.map-canvas');
  sc.appendChild(canvas);
  const legend = h('div.map-legend', ...Object.keys(NODE_ICON).map((k) => h('span', ic(NODE_ICON[k]), NODE_NAME[k])));
  el.append(head, sc, legend);
  const ROW_H = 92, TOP = 120, BOT = 70;
  const H = TOP + R.ROWS * ROW_H + BOT;
  canvas.style.height = H + 'px';
  const av = R.availableNodes(run);
  const isAv = (r, c) => av.some((x) => x.r === r && x.c === c);
  const draw = () => {
    const W = canvas.clientWidth || 360;
    canvas.innerHTML = '';
    const pos = (n) => ({ x: Math.round(((n.c + 0.5) / R.COLS) * W + n.jx), y: Math.round(TOP + (R.ROWS - 1 - n.r) * ROW_H + ROW_H / 2 + n.jy) });
    const bossPos = { x: Math.round(W / 2), y: 58 };
    let lines = '';
    const done = new Set(run.map.done);
    for (const row of run.map.rows) for (const n of row) {
      if (!n) continue;
      const p1 = pos(n);
      const targets = n.r === R.ROWS - 1 ? [bossPos] : n.next.map((c) => pos(run.map.rows[n.r + 1][c]));
      n.next.forEach((c, i) => { });
      for (const p2 of targets) {
        const walked = done.has(`${n.r}:${n.c}`);
        lines += `<line x1="${p1.x}" y1="${p1.y}" x2="${p2.x}" y2="${p2.y}" stroke="${walked ? '#ffd98a' : '#ffffff'}" stroke-opacity="${walked ? 0.5 : 0.16}" stroke-width="${walked ? 2.5 : 2}" stroke-dasharray="${walked ? '' : '3 7'}" stroke-linecap="round"/>`;
      }
    }
    canvas.insertAdjacentHTML('beforeend', `<svg class="links" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">${lines}</svg>`);
    for (const row of run.map.rows) for (const n of row) {
      if (!n) continue;
      const p1 = pos(n);
      const isCur = run.pos && run.pos.r === n.r && run.pos.c === n.c;
      const isDone = done.has(`${n.r}:${n.c}`);
      const can = isAv(n.r, n.c);
      const b = h(`button.mnode.t-${n.t}` + (can ? '.av' : '') + (isCur ? '.cur' : '') + (isDone && !isCur ? '.done' : ''), { type: 'button', style: { left: p1.x + 'px', top: p1.y + 'px' }, html: icon(NODE_ICON[n.t]), 'aria-label': NODE_NAME[n.t] });
      if (can) b.addEventListener('click', () => { sfx('good'); R.enterNode(run, n.r, n.c); P.dailyProgress(App.p, 'node', 1); next(); });
      else b.addEventListener('click', () => toast(`${NODE_NAME[n.t]} 칸이에요`, { icon: NODE_ICON[n.t], ms: 1200 }));
      canvas.appendChild(b);
    }
    const bossId = R.isAbyss(run) ? ['treant', 'prism', 'lethe', 'nox'][(run.act - 5) % 4] : run.map.boss;
    const bd = enemyById(bossId);
    const bossCan = av.some((x) => x.boss);
    const bb = h('button.mnode.boss' + (bossCan ? '.av' : ''), { type: 'button', style: { left: bossPos.x + 'px', top: bossPos.y + 'px', padding: '6px' }, html: monsterSVG(bd.art) });
    bb.addEventListener('click', () => {
      if (bossCan) { sfx('good'); R.enterNode(run, R.ROWS, 2); next(); }
      else infoSheet(`${bd.title} ${bd.name}`, `<p class="muted">이 구역의 끝에서 기다리는 보스예요. 체력 ${bd.hp}</p>`);
    });
    canvas.appendChild(bb);
    // 현재 위치로 스크롤
    const focusRow = run.pos ? run.pos.r : -1;
    const y = TOP + (R.ROWS - 1 - Math.max(0, focusRow + 1)) * ROW_H;
    sc.scrollTop = Math.max(0, y - sc.clientHeight * 0.55);
  };
  requestAnimationFrame(draw);
  const onR = () => draw();
  window.addEventListener('resize', onR);
  if (!App.p.tutorial.map) {
    App.p.tutorial.map = true; saveSoon();
    setTimeout(() => tutorial('빛나는 칸을 눌러 이동해요. <b>전투</b>에서는 기술을, <b>휴식</b>에서는 체력을, <b>상점</b>에서는 골드로 물건을 얻어요. 지도 맨 위에는 <b>보스</b>가 기다려요.'), 400);
  }
  return () => window.removeEventListener('resize', onR);
}

export function tutorial(html, onOk) {
  const t = h('div.tut', { html });
  t.appendChild(h('div.row.end', btn('알겠어요', () => { t.remove(); onOk && onOk(); }, { cls: 'small' })));
  document.body.appendChild(t);
  return t;
}

// ───────── 보상 ─────────
function rewardView(el, run) {
  bgm('map');
  const rw = run.screen.reward;
  if (!rw.claimed.gold) { R.claimGold(run); sfx('gold'); }
  el.append(h('div.node-title', { text: rw.kind === 'boss' ? '보스 처치!' : rw.kind === 'elite' ? '엘리트 처치!' : '승리!' }), h('div.node-sub', { text: '전리품을 챙겨요' }));
  const list = h('div');
  el.appendChild(list);
  list.appendChild(h('div.reward-row.claimed', h('div.ico', { html: icon('coin'), style: { color: 'var(--gold)' } }), h('div.grow.b', { text: `골드 ${rw.gold}` }), h('span.good', { html: icon('check') })));
  if (rw.potion) {
    const pt = POTION_BY_ID[rw.potion];
    const row = h('button.reward-row' + (rw.claimed.potion ? '.claimed' : ''), { type: 'button', onclick: () => {
      if (!R.claimPotion(run)) { toast('물약 칸이 가득 찼어요', { icon: 'potion' }); sfx('error'); return; }
      sfx('buy'); row.classList.add('claimed'); saveSoon();
    } }, h('div.ico', { html: icon('potion'), style: { color: pt.color } }), h('div.grow', h('div.b', { text: pt.name }), h('div.t12.muted', { text: pt.desc })));
    list.appendChild(row);
  }
  if (rw.relic) {
    const r = relicById(rw.relic);
    const row = h('button.reward-row' + (rw.claimed.relic ? '.claimed' : ''), { type: 'button', onclick: () => { if (R.claimRelic(run)) { sfx('level'); row.classList.add('claimed'); P.recordCodex(App.p, 'relics', r.id); saveSoon(); } } },
      h('div.ico.rar-' + r.rar, { html: icon(r.icon) }), h('div.grow', h('div.row.gap', h('span.b', { text: r.name }), h('span.tag.bg-' + r.rar, { text: rarName(r.rar) })), h('div.t12.muted', { text: r.desc })));
    list.appendChild(row);
  }
  if (rw.bossRelics && rw.bossRelics.length) {
    const row = h('button.reward-row' + (rw.claimed.relic ? '.claimed' : ''), { type: 'button', onclick: () => {
      sheet((b, close) => {
        b.appendChild(h('div.t13.muted', { style: { marginBottom: '10px' }, text: '전설 유물 하나를 골라요.' }));
        for (const id of rw.bossRelics) {
          const r = relicById(id);
          b.appendChild(h('button.reward-row', { type: 'button', onclick: () => { R.claimRelic(run, id); sfx('level'); close(); saveSoon(); go(runScreen); } },
            h('div.ico.rar-l', { html: icon(r.icon) }), h('div.grow', h('div.b.rar-l', { text: r.name }), h('div.t12.muted', { text: r.desc }))));
        }
      }, { title: '전설 유물 선택' });
    } }, h('div.ico.rar-l', { html: icon('crown') }), h('div.grow', h('div.b.rar-l', { text: '전설 유물 선택' }), h('div.t12.muted', { text: '세 개 중 하나를 고를 수 있어요' })));
    list.appendChild(row);
  }
  if (rw.skills.length) {
    const row = h('button.reward-row' + (rw.claimed.skill ? '.claimed' : ''), { type: 'button', onclick: () => skillChoiceSheet(rw.skills, (i, rep) => R.claimSkill(run, i, rep), () => { R.skipSkill(run); toast('골드 +8', { icon: 'coin' }); }, () => go(runScreen)) },
      h('div.ico', { html: icon('cards'), style: { color: '#d9c2ff' } }), h('div.grow', h('div.b', { text: '새 기술 배우기' }), h('div.t12.muted', { text: `${rw.skills.length}개 중 하나를 골라요` })));
    list.appendChild(row);
  }
  el.appendChild(h('div', { style: { height: '18px' } }));
  el.appendChild(btn('계속', () => {
    const left = (rw.skills.length && !rw.claimed.skill) || (rw.bossRelics && rw.bossRelics.length && !rw.claimed.relic);
    const go2 = () => { R.leaveReward(run); next(); };
    if (left) confirmBox('아직 받지 않은 보상이 있어요. 그래도 넘어갈까요?', go2, { yes: '넘어가기' });
    else go2();
  }, { cls: 'wide big' }));
}

export function skillChoiceSheet(skills, onPick, onSkip, after) {
  const run = App.p.run;
  sheet((b, close) => {
    let sel = -1;
    const cards = h('div.skill-cards');
    const draw = () => {
      cards.innerHTML = '';
      skills.forEach((s, i) => cards.appendChild(skillCard(s.id, s.up, { tag: 'button', sel: sel === i, onclick: () => { sel = i; draw(); confirmBtn.disabled = false; } })));
    };
    const confirmBtn = btn('배우기', () => {
      if (sel < 0) return;
      const hh = run.hero;
      if (hh.skills.length >= hh.skillSlots) {
        replaceSheet(skills[sel], (rep) => { if (onPick(sel, rep)) { sfx('level'); close(); saveSoon(); after && after(); } });
        return;
      }
      if (onPick(sel)) { sfx('level'); close(); saveSoon(); after && after(); }
    }, { cls: 'grow', disabled: true });
    draw();
    b.append(cards, h('div.row.gap', { style: { marginTop: '14px' } }, onSkip ? btn('건너뛰기', () => { onSkip(); close(); saveSoon(); after && after(); }, { cls: 'ghost', sub: onSkip.label || '' }) : null, confirmBtn));
  }, { title: '기술 선택' });
}

function replaceSheet(newSk, cb) {
  const run = App.p.run;
  sheet((b, close) => {
    b.appendChild(h('div.t13.muted', { style: { marginBottom: '10px' }, html: `기술 칸이 가득 찼어요. <b class="gold">${resolveSkill(newSk.id, newSk.up).name}</b> 대신 잊을 기술을 골라요.` }));
    run.hero.skills.forEach((s, i) => b.appendChild(skillCard(s.id, s.up, { tag: 'button', onclick: () => { close(); cb(i); } })));
  }, { title: '기술 교체' });
}

// ───────── 이벤트 ─────────
function eventView(el, run) {
  bgm('map');
  const ev = EVENT_BY_ID[run.screen.id];
  const artIcon = { spring: 'drop', cart: 'treasure', altar: 'die', cat: 'cat', dummy: 'sword', teller: 'cards', shrooms: 'leaf', crystal: 'crystal', vein: 'coin', mirror: 'mirror', ink: 'quill', knight: 'shield2', moonwell: 'moon', stars: 'star', imp: 'die', ghost: 'homun', anvil: 'hammer', fallenstar: 'sparkle', tea: 'cup', shadow: 'eye' }[ev.art] || 'event';
  el.append(h('div.event-art', { html: icon(artIcon) }), h('div.node-title', { text: ev.title }), h('p.event-text', { text: ev.text }));
  ev.choices.forEach((c, i) => {
    const ok = R.eventChoiceOk(run, c);
    el.appendChild(h('button.choice', { type: 'button', disabled: ok ? null : true, onclick: () => { R.chooseEvent(run, i); sfx('good'); next(); } },
      h('div.ct', { text: c.t }), h('div.cd', { text: c.d + (ok ? '' : ' · 조건 부족') })));
  });
}
function eventResultView(el, run) {
  const s = run.screen;
  const ev = EVENT_BY_ID[s.id];
  el.append(h('div.event-art', { html: icon('sparkle') }), h('div.node-title', { text: ev.title }), h('p.event-text', { text: s.text }));
  const lst = h('div');
  for (const r of s.results) {
    let t = '';
    if (r.k === 'heal') t = `<span class="good">체력 +${r.v}</span>`;
    else if (r.k === 'hp') t = `<span class="bad">체력 ${r.v}</span>`;
    else if (r.k === 'maxHp') t = r.v > 0 ? `<span class="good">최대 체력 +${r.v}</span>` : `<span class="bad">최대 체력 ${r.v}</span>`;
    else if (r.k === 'gold') t = `<span class="gold">골드 ${r.v > 0 ? '+' : ''}${r.v}</span>`;
    else if (r.k === 'relic') { const x = relicById(r.id); t = `유물 <b class="rar-${x.rar}">${x.name}</b>`; P.recordCodex(App.p, 'relics', r.id); }
    else if (r.k === 'upgrade') t = `<span class="good">기술 강화 ${r.ids.map((id) => skillById(id).name).join(', ')}</span>`;
    else if (r.k === 'potion') t = `물약 <b>${POTION_BY_ID[r.id].name}</b>`;
    else if (r.k === 'potionFull') t = '<span class="dim">물약 칸이 가득 차서 받지 못했어요</span>';
    else if (r.k === 'dice') t = `주사위 <b>${DICE_BY_ID[r.id].name}</b>`;
    else if (r.k === 'shards') t = `<span class="gold">별조각 +${r.v}</span> <span class="dim">(원정 종료 시 지급)</span>`;
    else if (r.k === 'gift') t = `<span class="pinkc">선물 ${GIFT_BY_ID[r.id].name}</span> <span class="dim">(야영지로 가져가요)</span>`;
    if (t) lst.appendChild(h('div.item', h('div.grow.t14', { html: t })));
  }
  el.append(lst, h('div', { style: { height: '16px' } }), btn('계속', () => { R.backToMap(run); next(); }, { cls: 'wide big' }));
}
function skillPickView(el, run) {
  const s = run.screen;
  el.append(h('div.node-title', { text: '새 기술' }), h('div.node-sub', { text: '하나를 골라 배워요' }));
  el.appendChild(btn('기술 고르기', () => skillChoiceSheet(s.skills, (i, rep) => R.pickSkill(run, i, rep), Object.assign(() => { R.backToMap(run); }, {}), () => go(runScreen)), { cls: 'wide big' }));
}
function removeView(el, run) {
  el.append(h('div.node-title', { text: '기술 지우기' }), h('div.node-sub', { text: '잊고 싶은 기술 하나를 골라요' }));
  run.hero.skills.forEach((s, i) => { const c = skillCard(s.id, s.up, { tag: 'button', onclick: () => confirmBox(`${resolveSkill(s.id, s.up).name} 기술을 지울까요?`, () => { R.removeSkill(run, i); next(); }) }); c.style.marginBottom = '8px'; el.appendChild(c); });
  el.appendChild(btn('지우지 않기', () => { R.backToMap(run); next(); }, { cls: 'ghost wide' }));
}

// ───────── 상점 ─────────
function shopView(el, run) {
  bgm('camp');
  const s = run.screen;
  const p = App.p;
  const mioMet = P.heroineUnlocked(p, 'mio');
  if (mioMet) {
    const tier = P.heroineState(p, 'mio').lv;
    const lines = HEROINES.mio.greet[tier <= 2 ? 'low' : tier <= 5 ? 'mid' : 'high'];
    const line = lines[Math.floor(Math.random() * lines.length)];
    el.appendChild(h('div.shop-npc', h('div', { html: heroineSVG('mio', { e: line.e, outfit: p.heroines.mio.outfit }), style: { width: '90px', height: '110px', flex: 'none' } }), h('div.line', h('div.t12.b', { style: { color: '#c06a20' }, text: '미오의 출장 상점' }), line.t)));
  } else el.append(h('div.node-title', { text: '떠돌이 상점' }), h('div.node-sub', { text: '골드로 물건을 살 수 있어요' }));
  const grid = h('div.shop-grid');
  const hh = run.hero;
  const draw = () => {
    grid.innerHTML = '';
    s.stock.forEach((it, i) => {
      let name = '', icn = 'star', desc = '', cls = '', color = null;
      if (it.k === 'skill') { const d = resolveSkill(it.id, it.up); name = d.name; icn = d.icon; desc = reqText(d); cls = 'rar-' + d.rar; }
      if (it.k === 'relic') { const r = relicById(it.id); name = r.name; icn = r.icon; desc = r.desc; cls = 'rar-' + r.rar; }
      if (it.k === 'potion') { const pt = POTION_BY_ID[it.id]; name = pt.name; icn = 'potion'; desc = pt.desc; color = pt.color; }
      if (it.k === 'dice') { const d = DICE_BY_ID[it.id]; name = d.name; icn = 'die'; desc = d.desc; color = d.color; }
      const b = h('button.shop-it' + (it.sold ? '.sold' : '') + (hh.gold < it.price ? '.poor' : ''), { type: 'button', onclick: () => shopItemSheet(run, i, draw) },
        h('div.row.gap', h('span.' + (cls || 'x'), { html: icon(icn), style: { fontSize: '22px', color: color || null } }), h('span.b.t14', { text: name, style: { lineHeight: '1.2' } })),
        h('div.t12.muted', { text: desc.replace(/<[^>]+>/g, ''), style: { lineHeight: '1.35', display: '-webkit-box', WebkitLineClamp: '2', WebkitBoxOrient: 'vertical', overflow: 'hidden' } }),
        h('div.price', { html: icon('coin') + (it.sold ? '판매 완료' : it.price) }));
      grid.appendChild(b);
    });
    gold.textContent = fmt(hh.gold);
  };
  const gold = h('span.num.gold');
  el.append(grid, h('div.sep'),
    h('div.row.gap', btn('기술 지우기', () => serviceSheet(run, 'remove', draw), { cls: 'ghost grow small', sub: `${Math.round(run.removeCost * R.priceMult(run))}G` }), btn('기술 강화', () => serviceSheet(run, 'up', draw), { cls: 'ghost grow small', sub: `${Math.round(run.upCost * R.priceMult(run))}G` })),
    h('div', { style: { height: '14px' } }), btn('상점 나가기', () => { R.backToMap(run); next(); }, { cls: 'wide big' }));
  draw();
}
function shopItemSheet(run, i, redraw) {
  const it = run.screen.stock[i];
  sheet((b, close) => {
    if (it.k === 'skill') b.appendChild(skillCard(it.id, it.up));
    else if (it.k === 'relic') { const r = relicById(it.id); b.appendChild(h('div.item', h('div.ico.rar-' + r.rar, { html: icon(r.icon) }), h('div.grow', h('div.row.gap', h('span.tt', { text: r.name }), h('span.tag.bg-' + r.rar, { text: rarName(r.rar) })), h('div.ds', { text: r.desc })))); }
    else if (it.k === 'potion') { const pt = POTION_BY_ID[it.id]; b.appendChild(h('div.item', h('div.ico', { html: icon('potion'), style: { color: pt.color } }), h('div.grow', h('div.tt', { text: pt.name }), h('div.ds', { text: pt.desc })))); }
    else { const d = DICE_BY_ID[it.id]; b.appendChild(h('div.item', h('div.ico', { html: dieSVG(6, d.id) }), h('div.grow', h('div.tt', { text: d.name }), h('div.ds', { html: diceDesc(d.id) })))); }
    b.appendChild(h('div', { style: { height: '14px' } }));
    const doBuy = (rep) => {
      const res = R.buy(run, i, rep);
      if (res.ok) { sfx('buy'); close(); syncCodex(App.p, run); saveSoon(); redraw(); return; }
      if (res.why === 'slots') { replaceSheet({ id: it.id, up: it.up }, (r) => doBuy(r)); return; }
      sfx('error');
      toast(res.why === 'gold' ? '골드가 부족해요' : res.why === 'potion' ? '물약 칸이 가득 찼어요' : res.why === 'dice' ? '주사위는 6개까지 가질 수 있어요' : '살 수 없어요', { icon: 'coin' });
    };
    b.appendChild(btn('구매', () => doBuy(), { cls: 'wide', icon: 'coin', sub: String(it.price), disabled: it.sold || run.hero.gold < it.price }));
  }, { title: '상품', cls: 'small' });
}
function serviceSheet(run, kind, redraw) {
  const cost = Math.round((kind === 'remove' ? run.removeCost : run.upCost) * R.priceMult(run));
  sheet((b, close) => {
    b.appendChild(h('div.t13.muted', { style: { marginBottom: '10px' }, text: kind === 'remove' ? `골드 ${cost}로 기술 하나를 지워요.` : `골드 ${cost}로 기술 하나를 강화해요.` }));
    run.hero.skills.forEach((s, i) => {
      if (kind === 'up' && s.up) return;
      const c = skillCard(s.id, s.up, { tag: 'button', onclick: () => {
        const ok = kind === 'remove' ? R.shopRemove(run, i) : R.shopUpgrade(run, i);
        if (ok) { sfx(kind === 'up' ? 'level' : 'buy'); close(); saveSoon(); go(runScreen); } else { sfx('error'); toast('골드가 부족해요', { icon: 'coin' }); }
      } });
      c.style.marginBottom = '8px';
      if (kind === 'up') c.appendChild(h('div.t12.good', { style: { position: 'absolute', right: '12px', bottom: '8px' }, text: '→ ' + resolveSkill(s.id, true).name }));
      c.style.position = 'relative';
      b.appendChild(c);
    });
  }, { title: kind === 'remove' ? '기술 지우기' : '기술 강화' });
}

// ───────── 휴식 ─────────
function restView(el, run) {
  bgm('camp');
  const s = run.screen;
  const hh = run.hero;
  const both = hh.relics.includes('star_map');
  el.append(h('div.big-ico.anim', { html: icon('rest'), style: { color: '#ffb34c' } }), h('div.node-title', { text: '모닥불' }), h('div.node-sub', { text: both ? '별지도 덕분에 회복과 강화를 모두 할 수 있어요' : '하나를 골라 쉬어 가요' }));
  const locked = s.used && !both;
  el.appendChild(h('button.choice', { type: 'button', disabled: locked || s.healed ? true : null, onclick: () => { const n = R.restHeal(run); sfx('heal'); toast(`체력 +${n}`, { icon: 'heart' }); next(); } },
    h('div.ct', { text: '푹 쉬기' }), h('div.cd', { text: `체력 ${R.restHealAmount(run)} 회복` })));
  el.appendChild(h('button.choice', { type: 'button', disabled: locked || s.upgraded || !hh.skills.some((x) => !x.up) ? true : null, onclick: () => {
    sheet((b, close) => {
      hh.skills.forEach((sk, i) => { if (sk.up) return; const c = skillCard(sk.id, false, { tag: 'button', onclick: () => { R.restUpgrade(run, i); sfx('level'); close(); next(); } }); c.style.marginBottom = '8px'; b.appendChild(c); });
    }, { title: '단련할 기술' });
  } }, h('div.ct', { text: '단련하기' }), h('div.cd', { text: '기술 하나 강화' })));
  if (run.companion) {
    const cid = run.companion.id;
    el.appendChild(h('button.choice', { type: 'button', disabled: s.talked ? true : null, onclick: () => {
      R.restTalk(run);
      const d = HEROINES[cid];
      const list = d.greet[P.heroineState(App.p, cid).lv >= 7 ? 'high' : P.heroineState(App.p, cid).lv >= 4 ? 'mid' : 'low'];
      const line = list[Math.floor(Math.random() * list.length)];
      sfx('heart');
      sheet((b) => { b.append(h('div.row.gap2', h('div', { html: heroineSVG(cid, { head: 1, e: line.e, outfit: App.p.heroines[cid].outfit }), style: { width: '84px', height: '100px', flex: 'none' } }), h('div.grow.t15', { style: { lineHeight: '1.6' }, text: line.t })), h('div.t12.pinkc', { style: { marginTop: '10px' }, text: `${d.name} 호감도 +3 (원정이 끝나면 반영) · 체력 10% 회복` })); }, { title: `${josa(d.name, '와/과')} 대화`, cls: 'small', onClose: () => next() });
    } }, h('div.ct', { text: `${josa(HEROINES[cid].name, '와/과')} 이야기하기` }), h('div.cd', { text: '체력 10% 회복, 호감도 +3' })));
  }
  el.append(h('div', { style: { height: '14px' } }), btn('떠나기', () => { R.backToMap(run); next(); }, { cls: 'wide big' + (s.used ? '' : ' ghost') }));
}

// ───────── 보물 ─────────
function treasureView(el, run) {
  const s = run.screen;
  el.append(h('div.big-ico' + (s.opened ? '' : '.anim'), { html: icon('treasure') }), h('div.node-title', { text: '보물 상자' }));
  if (!s.opened) {
    el.append(h('div.node-sub', { text: '반짝이는 상자가 놓여 있어요' }), btn('상자 열기', () => { R.openTreasure(run); sfx('level'); next(); }, { cls: 'wide big' }));
    return;
  }
  el.appendChild(h('div.node-sub', { text: '상자 안에서 보물을 찾았어요!' }));
  el.appendChild(h('div.item', h('div.ico', { html: icon('coin'), style: { color: 'var(--gold)' } }), h('div.grow.tt', { text: `골드 ${s.gold}` })));
  if (s.relic) { const r = relicById(s.relic); el.appendChild(h('div.item', h('div.ico.rar-' + r.rar, { html: icon(r.icon) }), h('div.grow', h('div.row.gap', h('span.tt', { text: r.name }), h('span.tag.bg-' + r.rar, { text: rarName(r.rar) })), h('div.ds', { text: r.desc })))); }
  el.append(h('div', { style: { height: '14px' } }), btn('계속', () => { R.backToMap(run); next(); }, { cls: 'wide big' }));
}

// ───────── 구역 돌파 ─────────
function actClearView(el, run) {
  bgm('camp');
  const a = R.actDef(run.act);
  const bd = enemyById(R.isAbyss(run) ? ['treant', 'prism', 'lethe', 'nox'][(run.act - 5) % 4] : a.boss);
  el.append(h('div', { html: monsterSVG(bd.art), style: { width: '140px', height: '140px', margin: '10px auto 0', opacity: '.55', filter: 'grayscale(.6)' } }),
    h('div.node-title', { text: R.isAbyss(run) ? `심연 ${run.act - 4}층 돌파!` : `${run.act}구역 돌파!` }),
    h('div.node-sub', { text: `${bd.title} ${josa(bd.name, '을/를')} 쓰러뜨렸어요` }));
  if (run.act === 4 && !run.cleared) run.cleared = true;
  if (run.act < run.maxAct) {
    const na = R.actDef(run.act + 1);
    el.append(h('div.card', h('div.t12.muted', { text: '다음 구역' }), h('div.b.t18', { text: na.name, style: { color: na.accent } }), h('div.t13.muted', { text: na.sub }), h('div.t12.good', { style: { marginTop: '6px' }, text: '잃은 체력의 60%를 회복하고 출발해요' })),
      h('div', { style: { height: '14px' } }), btn('다음 구역으로', () => { R.nextAct(run); sfx('good'); next(); }, { cls: 'wide big' }));
  } else if (run.act < 4) {
    el.append(h('div.card.glow', h('div.b.t18.gold', { text: '원정 완주!' }), h('div.t13.muted', { style: { lineHeight: '1.6', marginTop: '4px' }, text: '별지기는 가라앉은 서고의 끝에서 깨진 달 조각을 찾았어요. 하지만 미궁 더 깊은 곳에서 누군가 달빛을 삼키고 있어요.' })),
      h('div', { style: { height: '14px' } }), btn('야영지로 귀환', () => { R.finishRun(run, 'win'); next(); }, { cls: 'wide big' }));
  } else {
    if (run.act === 4) el.append(h('div.card.glow', h('div.b.t18.gold', { text: '달이 다시 떠올라요' }), h('div.t13.muted', { style: { lineHeight: '1.6', marginTop: '4px' }, text: '녹스가 쓰러지자 깨진 달 조각들이 하늘로 올라가 빛나기 시작했어요. 야영지의 모두가 별지기를 기다리고 있어요.' })));
    el.append(h('div', { style: { height: '12px' } }),
      btn('야영지로 귀환', () => { R.finishRun(run, 'win'); next(); }, { cls: 'wide big' }), h('div', { style: { height: '8px' } }),
      btn(`심연으로 더 내려가기`, () => { R.nextAct(run); sfx('good'); next(); }, { cls: 'wide ghost', sub: `심연 ${run.act - 3}층` }),
      h('div.t12.dim', { style: { textAlign: 'center', marginTop: '6px' }, text: '심연은 끝이 없어요. 층마다 적이 강해지고 보상도 커져요.' }));
  }
}

// ───────── 결과 ─────────
function endView(el, run) {
  const p = App.p;
  const win = run.screen.result === 'win' || run.cleared;
  bgm(win ? 'camp' : 'map');
  sfx(win ? 'win' : 'lose');
  const clsBefore = p.classes[run.cls].xp;
  const res = P.onRunEnd(p, run);
  syncCodex(p, run);
  saveNow();
  const c = CLASS_BY_ID[run.cls];
  el.append(h('div.big-ico', { html: icon(win ? 'crown' : 'moon'), style: { color: win ? 'var(--gold)' : '#b9a7ff' } }),
    h('div.node-title', { text: win ? '원정 성공!' : '원정 종료' }),
    h('div.node-sub', { text: win ? '별지기는 무사히 야영지로 돌아왔어요' : `${R.isAbyss(run) ? `심연 ${run.act - 4}층` : `${run.act}구역`}에서 쓰러졌어요. 리라가 별지기를 야영지로 데려왔어요.` }));
  const sh = numEl(0), du = numEl(0);
  el.appendChild(h('div.end-reward', h('div.er', h('div', { html: icon('shard'), style: { color: '#9fe8ff', fontSize: '32px' } }), h('div.v', sh), h('div.t12.muted', { text: '별조각' })), h('div.er', h('div', { html: icon('dust'), style: { color: 'var(--gold)', fontSize: '32px' } }), h('div.v', du), h('div.t12.muted', { text: '달가루' }))));
  setTimeout(() => { countTo(sh, res.shards, 1100); countTo(du, res.dust, 1100); sfx('gold'); }, 300);
  const st = run.stats;
  el.appendChild(h('div.stat-grid',
    statBox('지나온 칸', st.nodes), statBox('쓰러뜨린 적', st.kills || 0), statBox('최고 한 방', st.maxHit || 0), statBox('얻은 골드', st.goldEarned || 0)));
  // 직업 경험치
  const lvA = classLevel(clsBefore), lvB = res.lvAfter;
  const nx = lvB < CLASS_MAX_LV ? CLASS_XP[lvB + 1] : CLASS_XP[CLASS_MAX_LV];
  el.appendChild(h('div.card', h('div.row.between', h('span.b', { text: `${c.name} Lv.${lvB}`, style: { color: c.color } }), h('span.t12.muted', { text: lvB < CLASS_MAX_LV ? `${fmt(p.classes[run.cls].xp)} / ${fmt(nx)}` : '최고 레벨' })),
    h('div.prog', { style: { marginTop: '6px' } }, h('i', { style: { width: lvB < CLASS_MAX_LV ? `${Math.min(100, ((p.classes[run.cls].xp - CLASS_XP[lvB]) / (nx - CLASS_XP[lvB])) * 100)}%` : '100%' } })),
    lvB > lvA ? h('div.t13.good', { style: { marginTop: '6px' }, text: `레벨 업! 새 기술과 유물이 보상 목록에 추가됐어요.` }) : null,
    res.phaseUp ? h('div.t13.gold', { style: { marginTop: '4px' }, text: `달의 위상 ${p.classes[run.cls].phase}이 열렸어요!` }) : null));
  const gifts = run.gifts;
  if (gifts.length) el.appendChild(h('div.item', h('div.ico', { html: icon('gift'), style: { color: 'var(--pink)' } }), h('div.grow', h('div.tt', { text: '가져온 선물' }), h('div.ds', { text: gifts.map((g) => GIFT_BY_ID[g].name).join(', ') }))));
  if (lvB > lvA) setTimeout(() => levelUpFx(`<div class="big">${c.name} Lv.${lvB}</div><div class="t13 muted">새 기술이 열렸어요</div>`), 1300);
  el.append(h('div', { style: { height: '14px' } }), btn('야영지로', () => { checkAch(); go(hubScreen, 'home'); }, { cls: 'wide big' }));
  setTimeout(checkAch, 1600);
}
function statBox(k, v) { return h('div.stat', h('div.k', { text: k }), h('div.v', { text: fmt(v) })); }
