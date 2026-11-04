// 전투 화면
import { h, btn, ic, sheet, toast, floatText, wait, vibrate } from './dom.js';
import { App, go, saveSoon, saveNow, bgm } from './app.js';
import { icon } from '../art/icons.js';
import { monsterSVG, IDLE } from '../art/monsters.js';
import * as FX from '../art/fx.js';
import { heroineSVG } from '../art/heroines.js';
import { dieSVG } from '../art/dice.js';
import { battleBgFor } from '../art/battlebg.js';
import * as C from '../core/combat.js';
import * as R from '../core/run.js';
import * as P from '../core/profile.js';
import { botStep } from '../core/bot.js';
import { STATUS, STATUS_ORDER } from '../data/statuses.js';
import { FORTUNE_SKILLS } from '../data/skills.js';
import { POTION_BY_ID } from '../data/potions.js';
import { relicById } from '../data/relics.js';
import { HEROINES } from '../data/heroines/index.js';
import { companionAssist } from '../data/companions.js';
import { skillDesc, reqText, fxText } from './describe.js';
import { runScreen, deckSheet, runMenu, tutorial } from './scr_run.js';
import { sfx } from '../audio/audio.js';
import { fmt, josa } from '../core/util.js';

const INTENT_ICON = { atk: 'atk', atkdef: 'atk', def: 'def', buff: 'buff', debuff: 'debuff', heal: 'heal', summon: 'summon', steal: 'steal', drain: 'drain', charge: 'charge' };

const EL_BY_ICON = { fire: 'fire', meteor: 'fire', comet: 'fire', boom: 'fire', ice: 'frost', snow: 'frost', frost: 'frost', poison: 'poison', fog: 'poison', flask: 'poison', rain: 'poison', catalyst: 'poison', drop: 'poison', bolt: 'bolt', moon: 'arcane', orb: 'arcane', star: 'holy', holy: 'holy', starsword: 'holy', constel: 'holy', twinstar: 'holy', mirror: 'arcane', chain: 'arcane', split: 'arcane', plus: 'arcane', flip: 'arcane', coin: 'gold', chips: 'gold', seven: 'gold', ace: 'gold', card: 'gold', cards: 'gold', roulette: 'gold', joker: 'gold', heal: 'heal', leaf: 'heal', shield: 'shield', shield2: 'shield', armor: 'shield', castle: 'shield', blood: 'blood', homun: 'poison', stone: 'holy' };
export function elemOf(def) {
  if (!def) return 'phys';
  for (const f of def.fx || []) if (f.t === 'st' && !f.self) { if (f.s === 'burn') return 'fire'; if (f.s === 'frost') return 'frost'; if (f.s === 'poison') return 'poison'; }
  return EL_BY_ICON[def.icon] || 'phys';
}
const ST_FX = { burn: 'fire', poison: 'poison', frost: 'frost', weak: 'dark', vuln: 'blood', str: 'gold', dex: 'shield', thorns: 'poison', regen: 'heal' };
const AMBIENT = { 1: ['fireflies', '#e8ff9a'], 2: ['sparkles', '#bff4ff'], 3: ['bubbles', '#bfe8ff'], 4: ['motes', '#e6d6ff'] };

export function combatScreen(el) {
  const p = App.p;
  const run = p.run;
  const s = run.screen;
  const act = R.actDef(run.act);
  bgm(s.kind === 'boss' ? 'boss' : 'battle');
  el.classList.add('cb');
  el.insertAdjacentHTML('afterbegin', battleBgFor(act, R.isAbyss(run)) + '<div class="cb-shade"></div>');
  const amb = R.isAbyss(run) ? ['motes', '#d0a8ff'] : AMBIENT[act.id];
  FX.setAmbient(amb[0], { color: amb[1], n: 22, area: () => ({ x: 0, y: 40, w: window.innerWidth, h: window.innerHeight * 0.5 }) });
  let curEl = 'phys';
  const shakeOn = () => p.settings.shake !== false;
  const spawnSet = new Set();

  const c = C.createCombat(run, s.enemies, R.combatOptions(run));
  R.preCombat(run, c);
  for (const e of c.enemies) P.recordCodex(p, 'enemies', e.id);
  const speed = () => (p.settings.speed >= 2 ? 0.55 : p.settings.speed <= 0 ? 1.4 : 1);
  let busy = false, selDie = null, target = null, auto = !!p.settings.auto, done = false, lowHpSaid = false;
  const foeEls = {};

  // ── 레이아웃 ──
  const turnEl = h('span.pill', { text: '1턴' });
  const autoBtn = h('button.icon-btn' + (auto ? '.auto-on' : ''), { type: 'button', html: icon('auto'), title: '자동 전투', onclick: () => { auto = !auto; p.settings.auto = auto; autoBtn.classList.toggle('auto-on', auto); toast(auto ? '자동 전투 켜짐' : '자동 전투 꺼짐', { icon: 'auto', ms: 1200 }); saveSoon(); if (auto && !busy) autoLoop(); } });
  const top = h('div.cb-top', turnEl, h('span.pill', { text: R.isAbyss(run) ? `심연 ${run.act - 4}` : `${run.act}구역`, style: { color: act.accent } }),
    s.kind !== 'normal' ? h('span.pill', { text: s.kind === 'boss' ? '보스' : '엘리트', style: { color: s.kind === 'boss' ? '#ffd45a' : '#ff8a9a' } }) : null,
    h('span.grow'), h('span.pill', ic('coin'), h('span.num.gold', { text: fmt(run.hero.gold), 'data-gold': '1' })),
    autoBtn, h('button.icon-btn', { type: 'button', html: icon('cards'), onclick: () => deckSheet(run) }), h('button.icon-btn', { type: 'button', html: icon('gear'), onclick: () => runMenu() }));
  const goldEl = top.querySelector('[data-gold]');
  const foes = h('div.cb-enemies');
  const heroHp = h('div.hpbar', h('b'), h('i'), h('span'));
  const heroBlock = h('div.hero-block', { html: icon('shield') + '<b>0</b>' });
  const heroSts = h('div.sts', { style: { justifyContent: 'flex-start' } });
  const fName = FORTUNE_SKILLS[run.cls].name;
  const fProg = h('i');
  const fGauge = h('div.gauge', h('div.gi', { html: icon('star'), style: { color: 'var(--gold)', background: 'rgba(255,217,138,.15)' } }), h('div.grow', h('div.gn', { text: `운명 · ${fName}` }), h('div.prog', fProg)));
  fGauge.addEventListener('click', () => { if (C.fortuneReady(c)) act2(() => C.useFortune(c, target)); else sheet((b) => { b.innerHTML = `<p style="line-height:1.6">쓰지 않고 남긴 주사위의 눈이 운명 게이지에 쌓여요. 가득 차면 <b class="gold">${fName}</b>${josa(fName, '을/를').slice(fName.length)} 쓸 수 있어요.</p><p class="muted">${fxText(FORTUNE_SKILLS[run.cls].fx)}</p><p class="dim t13">현재 ${c.fortune} / ${c.fortuneMax}</p>`; }, { title: fName, cls: 'small' }); });
  let aGauge = null, aProg = null, aBubble = null;
  if (c.assist) {
    aProg = h('i');
    const a = companionAssist(c.assist.id, c.assist.lv);
    aGauge = h('div.gauge.comp', h('div.gi', { html: heroineSVG(c.assist.id, { head: 1, e: 'smile', outfit: p.heroines[c.assist.id].outfit }) }), h('div.grow', h('div.gn', { text: `${HEROINES[c.assist.id].name} · ${a.name}` }), h('div.prog.pink', aProg)));
    aGauge.style.position = 'relative';
    aGauge.addEventListener('click', () => { if (C.assistReady(c)) { const ln = pickLine('assist'); act2(() => C.useAssist(c, target)).then(() => ln && bark(ln)); } else sheet((b) => { b.innerHTML = `<p style="line-height:1.6">기술을 쓸 때마다 지원 게이지가 차요. 가득 차면 <b class="pinkc">${a.name}</b>${josa(a.name, '을/를').slice(a.name.length)} 쓸 수 있어요.</p><p class="muted">${a.desc}</p>`; }, { title: a.name, cls: 'small' }); });
  }
  const heroPanel = h('div.cb-hero', h('div.hero-row', heroBlock, h('div.hero-hp', heroHp, heroSts)), h('div.gauges', fGauge, aGauge));
  const tray = h('div.tray');
  const skillsEl = h('div.skills');
  const potEl = h('div.potions');
  const rerollBtn = btn('재굴림', () => doReroll(), { cls: 'ghost small', icon: 'cycle' });
  const endBtn = btn('턴 종료', () => doEnd(), { cls: 'grow' });
  const bottom = h('div.cb-bottom', potEl, rerollBtn, endBtn);
  el.append(top, foes, heroPanel, tray, skillsEl, bottom);
  heroHp.addEventListener('click', () => statusSheet('별지기', c.h));
  heroSts.addEventListener('click', () => statusSheet('별지기', c.h));

  // ── 렌더 ──
  function buildFoes() {
    foes.innerHTML = '';
    for (const e of c.enemies) {
      if (e.dead && !foeEls[e.uid]) continue;
      const kind = e.def.kind;
      const f = h('div.foe' + (kind === 'elite' || e.def.art.big ? '.big' : '') + (kind === 'boss' ? '.boss' : '') + (e.dead ? '.dead' : ''), { 'data-uid': e.uid });
      const intent = h('div.intent');
      const mon = h('div.monwrap.idle-' + (IDLE[e.def.art.s] || 'bob'), { html: monsterSVG(e.def.art), style: { animationDelay: `-${(Math.random() * 2).toFixed(2)}s` } });
      if (spawnSet.has(e.uid)) { f.classList.add('spawning'); spawnSet.delete(e.uid); }
      const blockB = h('div.blockb', { html: icon('shield') + '<b></b>' });
      mon.appendChild(blockB);
      const hp = h('div.hpbar.enemy', h('b'), h('i'), h('span'));
      const sts = h('div.sts');
      f.append(intent, mon, h('div.fname', { text: e.def.name }), hp, sts, h('div.tmark', { text: '▼' }));
      f.addEventListener('click', () => {
        if (e.dead) return;
        if (target === e.uid) { statusSheet(e.def.name, e, e); return; }
        target = e.uid; sfx('pick'); syncFoes();
      });
      foeEls[e.uid] = { f, intent, hp, sts, blockB, mon };
      foes.appendChild(f);
    }
    syncFoes();
  }
  function setBar(bar, hpv, max) {
    const pct = Math.max(0, Math.min(100, (hpv / max) * 100));
    bar.children[0].style.width = pct + '%';
    bar.children[1].style.width = pct + '%';
    bar.children[2].textContent = `${Math.max(0, hpv)} / ${max}`;
  }
  function stChips(u) {
    const out = [];
    for (const k of STATUS_ORDER) {
      const v = u.st[k];
      if (!v) continue;
      out.push(`<span class="st" style="color:${STATUS[k].color}">${icon(STATUS[k].icon)}${v}</span>`);
    }
    return out.join('');
  }
  function intentHtml(e) {
    if ((e.st.frost || 0) >= C.freezeAt(e)) return { cls: 'intent frozen', html: `${icon('snow')}빙결` };
    const iv = C.intentView(c, e);
    if (!iv) return { cls: 'intent', html: '' };
    let tx = '';
    if (iv.v !== undefined && ['atk', 'atkdef', 'steal', 'drain'].includes(iv.t)) tx = iv.hits > 1 ? `${iv.v}×${iv.hits}` : `${iv.v}`;
    if (iv.t === 'atkdef') tx += ` ${icon('def')}${iv.b}`;
    if (iv.t === 'def') tx = `${iv.b}`;
    if (iv.t === 'heal') tx = `${iv.v}`;
    if (iv.t === 'buff' || iv.t === 'debuff') tx = STATUS[iv.s] ? STATUS[iv.s].name : '';
    if (iv.t === 'summon') tx = '소환';
    if (iv.t === 'charge') tx = '!';
    return { cls: `intent i-${iv.t}`, html: icon(INTENT_ICON[iv.t] || 'atk') + tx };
  }
  function syncFoes() {
    const al = C.alive(c);
    if (!al.find((e) => e.uid === target)) target = al[0] ? al[0].uid : null;
    for (const e of c.enemies) {
      const r = foeEls[e.uid];
      if (!r) continue;
      setBar(r.hp, e.hp, e.maxHp);
      r.blockB.style.display = e.block > 0 ? 'flex' : 'none';
      r.blockB.querySelector('b').textContent = e.block;
      r.sts.innerHTML = stChips(e);
      const it = intentHtml(e);
      if (r.intent.innerHTML !== it.html) { r.intent.className = it.cls + ' pop'; r.intent.innerHTML = it.html; } else r.intent.className = it.cls;
      r.f.classList.toggle('target', e.uid === target && al.length > 1);
      if (e.dead && !r.f.classList.contains('dying')) r.f.classList.add('dead');
    }
  }
  function syncHero() {
    setBar(heroHp, c.h.hp, c.h.maxHp);
    heroBlock.querySelector('b').textContent = c.h.block;
    heroBlock.classList.toggle('zero', c.h.block <= 0);
    heroSts.innerHTML = stChips(c.h);
    fProg.style.width = `${Math.min(100, (c.fortune / c.fortuneMax) * 100)}%`;
    fGauge.classList.toggle('ready', C.fortuneReady(c));
    if (aGauge) { aProg.style.width = `${Math.min(100, (c.assist.charge / c.assist.max) * 100)}%`; aGauge.classList.toggle('ready', C.assistReady(c)); }
    turnEl.textContent = `${c.turn}턴`;
    goldEl.textContent = fmt(run.hero.gold);
  }
  function renderDice(rollAnim, newIds = []) {
    tray.innerHTML = '';
    for (const d of c.dice) {
      if (d.used) continue;
      const b = h('button.die' + (selDie === d.id ? '.sel' : '') + (d.frozen ? '.frozen' : '') + (newIds.includes(d.id) ? '.new' : '') + (d.value === 6 ? '.six' : ''), { type: 'button', 'data-silent': '1', 'data-id': d.id, html: dieSVG(d.value, d.type) });
      attachDrag(b, d);
      tray.appendChild(b);
      if (rollAnim) tumble(b, d, tray.children.length - 1, 'tumble');
    }
    if (!c.dice.some((d) => !d.used)) tray.appendChild(h('div.t13.dim', { style: { alignSelf: 'center' }, text: '모든 주사위를 썼어요' }));
  }
  // 굴러가며 눈이 바뀌다가 멈춰요
  function tumble(b, d, i, cls) {
    const delay = i * 70;
    b.style.setProperty('--d', delay + 'ms');
    b.classList.add(cls);
    const svg = b.querySelector('.die-svg');
    if (svg) svg.style.animationDelay = delay + 'ms';
    let n = 0;
    const iv = setInterval(() => {
      n++;
      if (n * 55 > 380 + delay) { clearInterval(iv); b.innerHTML = dieSVG(d.value, d.type); b.classList.toggle('six', d.value === 6); if (d.value === 6) { const q = FX.centerOf(b); FX.burst(q.x, q.y, { el: 'gold', n: 8, shape: 'star', size: 3, speed: 120, gravity: 0, life: 0.5 }); } return; }
      b.innerHTML = dieSVG(1 + Math.floor(Math.random() * 6), d.type);
      const sv = b.querySelector('.die-svg'); if (sv) { sv.style.animation = 'none'; }
    }, 55);
    setTimeout(() => b.classList.remove(cls), 700 + delay);
  }
  function renderSkills() {
    skillsEl.innerHTML = '';
    const die = c.dice.find((d) => d.id === selDie);
    c.skills.forEach((sk) => {
      const def = sk.def;
      const ready = C.skillReady(c, sk);
      const ok = die ? C.dieOk(c, sk, die) : false;
      const preview = die && ok && !def.cd && (def.slots || 1) === 1 ? die.value : undefined;
      const cls = ['sk'];
      if (sk.up) cls.push('up');
      if (!ready) cls.push('spent');
      else if (die) cls.push(ok ? 'ok' : 'no');
      const b = h('button.' + cls.join('.'), { type: 'button', 'data-si': sk.i, 'data-silent': '1' },
        h('div.sk-top', h('span.sk-ic.rar-' + def.rar, { html: icon(def.icon) }), h('span.sk-nm', { text: def.name }), h('span.sk-req', { text: reqText(def) })),
        h('div.sk-ds', { html: skillDesc(def, preview) }));
      if (def.cd) b.appendChild(h('div.cdbar', h('i', { style: { width: `${Math.max(0, Math.min(100, (1 - sk.cdLeft / def.cd) * 100))}%` } })));
      if ((def.slots || 1) > 1) {
        const sl = h('div.slots');
        for (let k = 0; k < def.slots; k++) { const pid = sk.pending[k]; const pd = pid ? c.dice.find((x) => x.id === pid) : null; sl.appendChild(h('span.slot' + (pd ? '.f' : ''), { text: pd ? pd.value : '' })); }
        b.appendChild(sl);
      }
      if ((def.uses || 1) > 1) b.appendChild(h('span.sk-uses', { text: `${(def.uses || 1) - sk.used}회` }));
      if (def.cd) b.appendChild(h('span.sk-uses', { text: `${Math.max(0, sk.cdLeft)} 남음` }));
      b.addEventListener('click', () => onSkillTap(sk));
      skillsEl.appendChild(b);
    });
  }
  function renderBottom() {
    potEl.innerHTML = '';
    const hh = run.hero;
    for (let i = 0; i < hh.potionSlots; i++) {
      const id = hh.potions[i];
      const pt = id && POTION_BY_ID[id];
      const b = h('button.pot' + (pt ? '' : '.empty'), { type: 'button', html: icon('potion'), style: { color: pt ? pt.color : 'var(--dim)' } });
      if (pt) b.addEventListener('click', () => potionSheet(i));
      potEl.appendChild(b);
    }
    rerollBtn.querySelector('.lbl').textContent = selDie ? `이것만 ${c.rerolls}` : `재굴림 ${c.rerolls}`;
    rerollBtn.disabled = c.rerolls <= 0 || busy || c.over;
    endBtn.disabled = busy || !!c.over;
  }
  function renderAll(rollAnim, newIds) { syncFoes(); syncHero(); renderDice(rollAnim, newIds); renderSkills(); renderBottom(); }

  // ── 상호작용 ──
  function onSkillTap(sk) {
    if (busy || c.over) return;
    if (!selDie) {
      // 주사위를 안 골랐으면: 넣을 수 있는 가장 높은 주사위 자동 선택 대신 설명
      if (sk.pending.length) { C.cancelPending(c, sk.i); renderAll(); return; }
      sheet((b) => {
        b.innerHTML = `<div class="row gap"><span class="tag bg-${sk.def.rar}">${reqText(sk.def)}</span></div><p style="line-height:1.6">${skillDesc(sk.def)}</p><p class="dim t13">주사위를 먼저 고르거나 주사위를 이 칸으로 끌어다 놓으면 사용해요.</p>`;
      }, { title: sk.def.name, cls: 'small' });
      return;
    }
    place(sk.i, selDie);
  }
  function place(si, dieId) {
    const sk = c.skills[si];
    const die = c.dice.find((d) => d.id === dieId);
    if (!sk || !die) return;
    if (!C.dieOk(c, sk, die)) { sfx('error'); const el2 = skillsEl.querySelector(`[data-si="${si}"]`); if (el2) { el2.classList.remove('shake'); void el2.offsetWidth; el2.classList.add('shake'); } return; }
    selDie = null;
    sfx('place');
    const dEl = tray.querySelector(`[data-id="${dieId}"]`);
    const sEl = skillsEl.querySelector(`[data-si="${si}"]`);
    if (dEl && sEl) {
      const a = dEl.getBoundingClientRect(), t = sEl.getBoundingClientRect();
      const g = h('div.fly-die', { html: dieSVG(die.value, die.type), style: { left: a.left + 'px', top: a.top + 'px', width: a.width + 'px', height: a.height + 'px' } });
      document.body.appendChild(g);
      dEl.style.visibility = 'hidden';
      requestAnimationFrame(() => { g.style.transform = `translate(${Math.round(t.left + t.width / 2 - a.left - a.width / 2)}px, ${Math.round(t.top + t.height / 2 - a.top - a.height / 2)}px) scale(.55) rotate(180deg)`; g.style.opacity = '0.2'; });
      setTimeout(() => g.remove(), 220);
    }
    act2(() => C.placeDie(c, si, dieId, target), si, 170);
  }
  function selectDie(d) {
    if (busy || c.over || d.frozen) { if (d.frozen) toast('얼어붙은 주사위는 이번 턴에 쓸 수 없어요', { icon: 'snow', ms: 1400 }); return; }
    selDie = selDie === d.id ? null : d.id;
    sfx('pick');
    renderDice(); renderSkills(); renderBottom();
  }
  function doReroll() {
    if (busy || c.over || c.rerolls <= 0) return;
    const ids = selDie ? [selDie] : null;
    selDie = null;
    sfx('roll');
    const ev = C.reroll(c, ids);
    play(ev).then(() => { renderAll(false); const ids2 = (ev.find((x) => x.k === 'reroll_dice') || {}).ids || []; let k = 0; tray.querySelectorAll('.die').forEach((b) => { if (ids2.includes(b.dataset.id)) { const d = c.dice.find((x) => x.id === b.dataset.id); if (d) tumble(b, d, k++, 'reroll'); } }); });
  }
  function doEnd() {
    if (busy || c.over) return;
    selDie = null;
    busy = true;
    renderBottom();
    const ev = C.endTurn(c);
    play(ev).then(() => { busy = false; afterAction(); renderAll(true); if (!c.over) sfx('roll'); if (auto) autoLoop(); });
  }
  function potionSheet(i) {
    const pt = POTION_BY_ID[run.hero.potions[i]];
    sheet((b, close) => {
      b.append(h('p', { style: { lineHeight: '1.6' }, text: pt.desc }), h('div.row.gap',
        btn('버리기', () => { run.hero.potions.splice(i, 1); close(); renderBottom(); saveSoon(); }, { cls: 'ghost' }),
        btn('사용하기', () => { close(); sfx('heal'); act2(() => C.usePotion(c, i, target)); }, { cls: 'grow', disabled: busy || !!c.over })));
    }, { title: pt.name, cls: 'small' });
  }
  function statusSheet(name, u, e) {
    sheet((b) => {
      if (e) {
        const iv = C.intentView(c, e);
        const m = e.intent || {};
        let what = '';
        if ((e.st.frost || 0) >= C.freezeAt(e)) what = '얼어붙어서 다음 행동을 건너뛰어요.';
        else if (iv) what = { atk: `공격해요. 피해 ${iv.v}${iv.hits > 1 ? ` × ${iv.hits}` : ''}`, atkdef: `공격하고 방어해요. 피해 ${iv.v}, 방어도 ${iv.b}`, def: `방어도를 ${iv.b} 얻어요.`, buff: `스스로 ${STATUS[iv.s]?.name || ''} ${iv.sv} 상태가 돼요.`, debuff: `별지기에게 ${josa(STATUS[iv.s]?.name || '', '을/를')} 걸어요.`, heal: `동료의 체력을 ${iv.v} 회복해요.`, summon: '동료를 불러와요.', steal: `공격하고 골드를 훔쳐요. 피해 ${iv.v}`, drain: `공격하고 준 피해만큼 회복해요. 피해 ${iv.v}`, charge: '강한 공격을 준비하고 있어요!' }[iv.t] || '';
        b.appendChild(h('div.item', h('div.ico', { html: monsterSVG(e.def.art) , style: { padding: '2px' } }), h('div.grow', h('div.tt', { text: `${e.def.title ? e.def.title + ' ' : ''}${e.def.name}` }), h('div.ds', { text: `체력 ${e.hp} / ${e.maxHp}${e.block ? ` · 방어도 ${e.block}` : ''}` }))));
        b.appendChild(h('div.item', h('div.ico', { html: icon(INTENT_ICON[m.t] || 'atk') }), h('div.grow', h('div.tt', { text: '다음 행동' }), h('div.ds', { text: what }))));
        if (e.def.onDeath && e.def.onDeath.split) b.appendChild(h('div.t13.muted', { style: { margin: '8px 0' }, text: '쓰러지면 작게 나뉘어요.' }));
        b.appendChild(h('div.t13.muted', { style: { margin: '8px 0' }, text: `빙결 ${C.freezeAt(e)}이 쌓이면 행동을 한 번 건너뛰어요.` }));
      }
      const keys = STATUS_ORDER.filter((k) => u.st[k]);
      if (!keys.length) b.appendChild(h('div.t13.dim', { text: '걸려 있는 상태 효과가 없어요.' }));
      for (const k of keys) b.appendChild(h('div.item', h('div.ico', { html: icon(STATUS[k].icon), style: { color: STATUS[k].color } }), h('div.grow', h('div.tt', { text: `${STATUS[k].name} ${u.st[k]}` }), h('div.ds', { text: STATUS[k].desc }))));
    }, { title: name, cls: 'small' });
  }

  // 드래그 앤 드롭
  function attachDrag(b, d) {
    let sx = 0, sy = 0, drag = false, ghost = null, over = null, pid = null;
    b.addEventListener('pointerdown', (e) => {
      if (busy || c.over || d.frozen) return;
      sx = e.clientX; sy = e.clientY; drag = false; pid = e.pointerId;
      b.setPointerCapture(pid);
    });
    b.addEventListener('pointermove', (e) => {
      if (pid !== e.pointerId) return;
      if (!drag && Math.hypot(e.clientX - sx, e.clientY - sy) > 8) {
        drag = true;
        selDie = d.id; renderSkills();
        b.classList.add('dragging');
        ghost = h('div.drag-ghost', { html: dieSVG(d.value, d.type) });
        document.body.appendChild(ghost);
        sfx('pick');
      }
      if (drag) {
        ghost.style.left = e.clientX + 'px'; ghost.style.top = e.clientY + 'px';
        const t = document.elementFromPoint(e.clientX, e.clientY);
        const sk = t && t.closest('.sk');
        if (over && over !== sk) over.classList.remove('drop');
        over = sk; if (sk && sk.classList.contains('ok')) sk.classList.add('drop');
      }
    });
    const up = (e) => {
      if (pid !== e.pointerId) return;
      pid = null;
      if (!drag) { selectDie(d); return; }
      drag = false;
      b.classList.remove('dragging');
      if (ghost) ghost.remove();
      const t = document.elementFromPoint(e.clientX, e.clientY);
      const sk = t && t.closest('.sk');
      if (over) over.classList.remove('drop');
      if (sk) place(Number(sk.dataset.si), d.id);
      else { selDie = null; renderSkills(); }
    };
    b.addEventListener('pointerup', up);
    b.addEventListener('pointercancel', (e) => { if (ghost) ghost.remove(); drag = false; pid = null; b.classList.remove('dragging'); });
  }

  // ── 이벤트 재생 ──
  function act2(fn, si, delay = 0) {
    if (busy) return Promise.resolve();
    busy = true;
    renderBottom();
    const ev = fn();
    return wait(delay).then(() => launch(ev, si)).then(() => play(ev)).then(() => { busy = false; afterAction(); if (!c.over) renderAll(false, ev.filter((x) => x.k === 'die_new').map((x) => x.id)); });
  }
  // 기술 칸에서 대상에게 발사체
  async function launch(ev, si, fromEl) {
    const use = ev.find((x) => x.k === 'use');
    if (!use && !fromEl) return;
    const src = fromEl || skillsEl.querySelector(`[data-si="${use.si}"]`);
    if (src && !fromEl) src.classList.add('fire');
    if (use) curEl = elemOf(c.skills[use.si] && c.skills[use.si].def);
    const ids = [...new Set(ev.filter((x) => (x.k === 'dmg' || x.k === 'status') && x.u !== 'hero').map((x) => x.u))].slice(0, 4);
    if (!ids.length || !src) return;
    const from = FX.centerOf(src, 0.3);
    await Promise.all(ids.map((u, i) => { const r = foeEls[u]; return r ? FX.projectile(from, FX.centerOf(r.mon, 0.55), { el: curEl, dur: 0.2 + i * 0.04, arc: -40 - i * 15, size: 7 }) : null; }));
  }
  function unitEl(uid) { if (uid === 'hero') return heroHp; const r = foeEls[uid]; return r ? r.mon : null; }
  async function play(evs) {
    const sp = speed();
    for (const e of evs) {
      if (done) return;
      switch (e.k) {
        case 'dmg': {
          const isHero = e.u === 'hero';
          const tgt = unitEl(e.u);
          if (isHero) {
            setBar(heroHp, e.hp, c.h.maxHp); heroBlock.querySelector('b').textContent = e.block; heroBlock.classList.toggle('zero', e.block <= 0);
            if (e.amt > 0) {
              floatText(heroHp, `-${e.amt}`, 'hurt');
              const q = FX.centerOf(heroHp);
              if (e.kind === 'burn') FX.rise(q.x, q.y, { el: 'fire', n: 12 }); else if (e.kind === 'poison') FX.rise(q.x, q.y, { el: 'poison', n: 12 });
              else { FX.slash(q.x + 10, q.y - 30, { el: 'blood', r: 60, angle: 0.5 }); FX.burst(q.x, q.y, { el: 'blood', n: 12, shape: 'shard', size: 4, speed: 220 }); }
              el.classList.remove('hurtflash'); void el.offsetWidth; el.classList.add('hurtflash');
              if (shakeOn()) { el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake'); }
              sfx('hurt'); vibrate(30, p.settings);
            }
            else if (e.blocked) { floatText(heroBlock, '막음', 'block'); sfx('block'); }
          } else {
            const r = foeEls[e.u];
            if (r) {
              setBar(r.hp, e.hp, (c.enemies.find((x) => x.uid === e.u) || {}).maxHp || 1);
              r.blockB.style.display = e.block > 0 ? 'flex' : 'none'; r.blockB.querySelector('b').textContent = e.block;
              if (e.amt > 0) {
                const big = e.amt >= 20;
                floatText(r.mon, String(e.amt), big ? 'big' : 'dmg');
                const q = FX.centerOf(r.mon, 0.55);
                if (e.kind === 'burn') FX.rise(q.x, q.y, { el: 'fire', n: 14, size: 4 });
                else if (e.kind === 'poison') FX.rise(q.x, q.y, { el: 'poison', n: 14, size: 4 });
                else if (e.kind === 'thorns') FX.burst(q.x, q.y, { el: 'poison', n: 10, shape: 'shard', speed: 200 });
                else {
                  FX.slash(q.x, q.y, { el: curEl, r: big ? 66 : 52, w: big ? 14 : 11 });
                  FX.burst(q.x, q.y, { el: curEl, n: 14 + Math.min(24, e.amt), speed: big ? 420 : 300, size: big ? 6 : 5 });
                  FX.burst(q.x, q.y, { el: curEl, n: 6, shape: 'star', size: 3.5, speed: 160, gravity: 40, life: 0.5 });
                  FX.ring(q.x, q.y, { el: curEl, r: big ? 105 : 58, w: big ? 6 : 4, life: big ? 0.45 : 0.3 });
                  if (big) FX.flash('#ffffff', 0.16);
                }
                r.f.classList.remove('knock', 'hit'); void r.f.offsetWidth; r.f.classList.add('knock', 'hit');
                if (big && shakeOn()) { el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake'); }
                sfx(big ? 'hitBig' : 'hit'); if (big) vibrate(20, p.settings);
              }
              else if (e.blocked) { floatText(r.mon, '막음', 'block'); sfx('block'); }

            }
          }
          await wait(isHero ? 220 * sp : 130 * sp);
          break;
        }
        case 'block': { const t = unitEl(e.u); { const q = FX.centerOf(e.u === 'hero' ? heroBlock : t, 0.5); FX.ring(q.x, q.y, { el: 'shield', r: e.u === 'hero' ? 44 : 60, w: 4 }); FX.burst(q.x, q.y, { el: 'shield', n: 8, shape: 'star', size: 3, speed: 120, gravity: 0, life: 0.5 }); } if (e.u === 'hero') { heroBlock.querySelector('b').textContent = e.block; heroBlock.classList.remove('zero', 'gain'); void heroBlock.offsetWidth; heroBlock.classList.add('gain'); floatText(heroBlock, `+${e.amt}`, 'block'); } else { const r = foeEls[e.u]; if (r) { r.blockB.style.display = 'flex'; r.blockB.querySelector('b').textContent = e.block; floatText(r.mon, `+${e.amt}`, 'block'); } } sfx('block'); await wait(90 * sp); break; }
        case 'heal': { if (e.amt > 0) { const q = FX.centerOf(unitEl(e.u) || heroHp, 0.5); FX.rise(q.x, q.y, { el: 'heal', n: 14, shape: 'star', size: 3.5 }); } if (e.u === 'hero') { setBar(heroHp, e.hp, c.h.maxHp); floatText(heroHp, `+${e.amt}`, 'heal'); } else { const r = foeEls[e.u]; if (r) { setBar(r.hp, e.hp, (c.enemies.find((x) => x.uid === e.u) || {}).maxHp || 1); floatText(r.mon, `+${e.amt}`, 'heal'); } } if (e.amt > 0) sfx('heal'); await wait(110 * sp); break; }
        case 'status': { const t = unitEl(e.u); if (t && STATUS[e.s]) { floatText(t, `${STATUS[e.s].name} +${e.n}`, 'st'); const q = FX.centerOf(t, 0.55); const el2 = ST_FX[e.s] || 'arcane'; if (e.s === 'burn') FX.rise(q.x, q.y, { el: 'fire', n: 10 }); else if (e.s === 'poison') FX.rise(q.x, q.y, { el: 'poison', n: 10, size: 5 }); else if (e.s === 'frost') FX.burst(q.x, q.y, { el: 'frost', n: 12, shape: 'shard', speed: 200, gravity: 120 }); else FX.rise(q.x, q.y, { el: el2, n: 8, shape: 'star', size: 3 }); } if (e.u === 'hero') heroSts.innerHTML = stChips(c.h); else { const r = foeEls[e.u]; if (r) r.sts.innerHTML = stChips(c.enemies.find((x) => x.uid === e.u)); } sfx(e.s === 'frost' ? 'freeze' : 'status'); await wait(80 * sp); break; }
        case 'gold': { goldEl.textContent = fmt(e.gold); if (e.amt > 0) { const tr = foeEls[target] || Object.values(foeEls)[0]; FX.coins(FX.centerOf(tr ? tr.mon : skillsEl), FX.centerOf(goldEl), Math.min(8, 2 + Math.floor(e.amt / 3))); floatText(goldEl, `+${e.amt}`, 'gold'); sfx('gold'); } else floatText(goldEl, `${e.amt}`, 'hurt'); await wait(70 * sp); break; }
        case 'fortune': fProg.style.width = `${Math.min(100, (e.n / e.max) * 100)}%`; fGauge.classList.toggle('ready', e.n >= e.max); break;
        case 'fortune_use': { sfx('fortune'); const q = FX.centerOf(heroHp); FX.pillar(q.x, q.y, { el: 'holy', w: 70, life: 0.7 }); FX.flash('#fff2c0', 0.22, 0.3); FX.burst(q.x, q.y, { el: 'gold', n: 30, shape: 'star', size: 4, speed: 320, gravity: 60, life: 0.9 }); banner(e.name); await wait(420 * sp); break; }
        case 'assist': if (aProg) { aProg.style.width = `${Math.min(100, (e.charge / c.assist.max) * 100)}%`; aGauge.classList.toggle('ready', e.charge >= c.assist.max); } break;
        case 'assist_use': { sfx('assist'); const q = FX.centerOf(aGauge || heroHp); FX.burst(q.x, q.y, { el: 'pink', n: 18, shape: 'heart', size: 5, speed: 240, gravity: -40, life: 1 }); FX.ring(q.x, q.y, { el: 'pink', r: 80 }); banner(e.name, 'pink'); await wait(380 * sp); break; }
        case 'gamble': { floatText(skillsEl, e.win ? '성공!' : '실패…', e.win ? 'big' : 'st'); const q = FX.centerOf(skillsEl, 0.3); if (e.win) { FX.burst(q.x, q.y, { el: 'gold', n: 24, shape: 'star', size: 4, speed: 300, gravity: 120 }); FX.ring(q.x, q.y, { el: 'gold', r: 90 }); } else FX.burst(q.x, q.y, { colors: ['#9a96c0', '#6a6690'], n: 10, shape: 'smoke', size: 10, speed: 60, gravity: -20, add: false }); } sfx(e.win ? 'good' : 'error'); await wait(220 * sp); break;
        case 'death': {
          const r = foeEls[e.u];
          const en = c.enemies.find((x) => x.uid === e.u);
          if (r) {
            r.f.classList.add('dying');
            const q = FX.centerOf(r.mon, 0.55);
            const col = en ? en.def.art.c : '#ffffff';
            setTimeout(() => { FX.burst(q.x, q.y, { colors: ['#ffffff', col], n: 30, shape: 'star', size: 4, speed: 340, gravity: 160, life: 0.9 }); FX.ring(q.x, q.y, { colors: ['#fff', col], r: 90 }); FX.rise(q.x, q.y - 10, { colors: ['#ffffff', '#e6e0ff'], n: 10, size: 3, speed: 90 }); }, 260);
            setTimeout(() => { r.f.classList.remove('dying'); r.f.classList.add('dead'); }, 620);
          }
          sfx('splash'); await wait(300 * sp); break;
        }
        case 'spawn': spawnSet.add(e.u); buildFoes(); { const r = foeEls[e.u]; if (r) { const q = FX.centerOf(r.mon, 0.6); FX.ring(q.x, q.y, { el: 'dark', r: 70 }); FX.burst(q.x, q.y, { el: 'dark', n: 14, size: 3 }); } } await wait(260 * sp); break;
        case 'relic': { const chip = document.querySelector(`[data-relic="${e.id}"]`); if (chip) { chip.classList.remove('flash'); void chip.offsetWidth; chip.classList.add('flash'); } break; }
        case 'text': { const t = unitEl(e.u) || heroHp; floatText(t, e.t, 'st'); await wait(160 * sp); break; }
        case 'say': { const r = foeEls[e.u]; if (r) { const b = h('div.say', { text: e.t }); r.f.appendChild(b); setTimeout(() => b.remove(), 2600); } await wait(500 * sp); break; }
        case 'enemy_phase': curEl = 'blood'; syncHero(); renderDice(); renderSkills(); banner('적의 차례', 'enemy'); sfx('enemyTurn'); await wait(520 * sp); break;
        case 'act': { const r = foeEls[e.u]; if (r) { r.f.classList.remove('lunge'); void r.f.offsetWidth; r.f.classList.add('lunge'); } await wait(260 * sp); break; }
        case 'frozen': { const r = foeEls[e.u]; if (r) { floatText(r.mon, '꽁꽁!', 'block'); const q = FX.centerOf(r.mon, 0.5); FX.burst(q.x, q.y, { el: 'frost', n: 18, shape: 'shard', size: 5, speed: 200, gravity: 80 }); FX.ring(q.x, q.y, { el: 'frost', r: 70 }); } sfx('freeze'); await wait(300 * sp); break; }
        case 'intents': syncFoes(); break;
        case 'turn': if (e.n > 1) { banner(`${e.n}턴`); await wait(380 * sp); } break;
        case 'roll': break;
        case 'cd': break;
        case 'use': curEl = elemOf(c.skills[e.si] && c.skills[e.si].def); break;
        case 'potion_get': toast(`${josa(POTION_BY_ID[e.id].name, '을/를')} 얻었어요`, { icon: 'potion' }); break;
        default: break;
      }
    }
    syncFoes(); syncHero();
  }
  function banner(t, cls = '') { const b = h('div.turn-banner' + (cls ? '.' + cls : ''), { text: t }); el.appendChild(b); setTimeout(() => b.remove(), 950); }

  // 동료 말풍선
  function pickLine(kind) { if (!c.assist) return null; const d = HEROINES[c.assist.id].battle[kind]; return d && d.length ? d[Math.floor(Math.random() * d.length)] : null; }
  function bark(line) {
    if (!aGauge || !line) return;
    if (aBubble) aBubble.remove();
    aBubble = h('div.say', { text: line.t });
    aGauge.appendChild(aBubble);
    const g = aGauge.querySelector('.gi');
    g.innerHTML = heroineSVG(c.assist.id, { head: 1, e: line.e || 'smile', outfit: p.heroines[c.assist.id].outfit });
    setTimeout(() => { if (aBubble) { aBubble.remove(); aBubble = null; } }, 2600);
  }

  function afterAction() {
    if (c.over && !done) { finish(); return; }
    if (!lowHpSaid && c.h.hp < c.h.maxHp * 0.3) { lowHpSaid = true; bark(pickLine('lowHp')); }
  }
  async function finish() {
    done = true;
    renderBottom();
    C.finishCombat(c);
    P.dailyProgress(p, 'kill', c.stats.kills);
    P.dailyProgress(p, 'fortune', (run.stats.fortunes || 0) - fortunes0);
    if (c.over === 'win') {
      P.dailyProgress(p, 'win', 1);
      if (s.kind === 'elite') P.dailyProgress(p, 'elite', 1);
      bark(pickLine('victory'));
      sfx('win');
      banner('승리!');
      if (s.kind === 'boss') {
        const news = P.onBossKill(p, run.act);
        p.news = (p.news || []).concat(news);
        if (run.act === 4) run.cleared = true;
      }
      R.onCombatWin(run);
      run.stats.fortunes = run.stats.fortunes || 0;
      saveNow();
      await wait(1100);
      go(runScreen);
    } else {
      bark(pickLine('defeat'));
      banner('쓰러졌어요…', 'enemy');
      sfx('lose');
      R.finishRun(run, 'lose');
      saveNow();
      await wait(1500);
      go(runScreen);
    }
  }

  // 자동 전투
  async function autoLoop() {
    while (auto && !c.over && !done) {
      if (busy) { await wait(100); continue; }
      busy = true; renderBottom();
      const st = botStep(c);
      if (!st) {
        const ev = C.endTurn(c);
        await play(ev);
        busy = false; afterAction(); if (!c.over) { renderAll(true); sfx('roll'); }
        await wait(300 * speed());
        continue;
      }
      if (st.what === 'skill' && st.si !== undefined) { const el2 = skillsEl.querySelector(`[data-si="${st.si}"]`); if (el2) el2.classList.add('fire'); sfx('place'); }
      if (st.what === 'reroll') sfx('roll');
      if (st.what === 'skill') await launch(st.ev, st.si);
      await play(st.ev);
      busy = false; afterAction();
      if (!c.over) renderAll(st.what === 'reroll');
      await wait(260 * speed());
    }
  }

  // ── 시작 ──
  buildFoes();
  const startEv = C.startCombat(c);
  const fortunes0 = run.stats.fortunes || 0;
  renderAll(true);
  sfx('roll');
  busy = true;
  (async () => {
    if (s.kind === 'boss') {
      const boss = c.enemies[0];
      const r = foeEls[boss.uid];
      if (r && boss.def.intro) { const b = h('div.say', { text: boss.def.intro }); r.f.appendChild(b); setTimeout(() => b.remove(), 3600); }
      banner(`${boss.def.title} ${boss.def.name}`, 'enemy');
      await wait(900);
    }
    await play(startEv);
    busy = false;
    renderAll(false);
    bark(pickLine('start'));
    if (!p.tutorial.combat) {
      p.tutorial.combat = true; saveSoon();
      tutorial('<b>주사위를 눌러 고른 뒤 기술을 누르면</b> 사용해요. 주사위를 기술 칸으로 끌어다 놓아도 돼요.<br>기술마다 넣을 수 있는 눈이 달라요. 쓰지 않은 주사위의 눈은 <b>운명 게이지</b>에 쌓여요.<br>적 머리 위의 표시는 다음 행동이에요.', () => {
        tutorial('주사위가 마음에 안 들면 <b>재굴림</b>을 눌러요. 주사위 하나를 고른 채 누르면 그 주사위만 다시 굴려요.<br>할 일을 다 했으면 <b>턴 종료</b>를 눌러요. 오른쪽 위의 버튼으로 <b>자동 전투</b>도 켤 수 있어요.');
      });
    }
    if (auto) autoLoop();
  })();
  return () => { FX.setAmbient(null); FX.clearFx(); done = true; auto = false; document.querySelectorAll('.tut,.drag-ghost').forEach((x) => x.remove()); };
}
