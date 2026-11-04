// 놀이 탭 + 미니게임 4종
import { h, btn, ic, sheet, toast, wait, countTo, numEl } from './dom.js';
import { App, go, saveSoon, resBar, refreshRes, checkAch, bgm, levelUpFx } from './app.js';
import { icon } from '../art/icons.js';
import { heroineSVG } from '../art/heroines.js';
import { sceneSVG } from '../art/scenes.js';
import * as P from '../core/profile.js';
import { HEROINES } from '../data/heroines/index.js';
import { FISH, FISH_BY_ID, INGREDIENTS, RECIPES, RECIPE_BY_ID } from '../data/minigames.js';
import { GIFT_BY_ID } from '../data/gifts.js';
import { hubScreen } from './scr_hub.js';
import { settingsSheet } from './scr_misc.js';
import { sfx } from '../audio/audio.js';
import { fmt, todayKey, josa } from '../core/util.js';
import { Rng } from '../core/rng.js';

const MINIS = [
  { id: 'fish', name: '별 낚시', who: 'lyra', icon: 'fish', desc: '리라와 별 호수에서 물고기를 낚아요', bg: 'lake' },
  { id: 'cook', name: '달빛 요리', who: 'lyra', icon: 'pot', desc: '순서를 기억해 요리하면 다음 원정이 든든해요', bg: 'kitchen' },
  { id: 'hilo', name: '하이로우', who: 'mio', icon: 'cards', desc: '미오와 카드 한 판. 연승하면 배당이 쑥쑥', bg: 'market' },
  { id: 'constel', name: '별자리 잇기', who: 'seren', icon: 'constel', desc: '세렌이 보여 주는 별의 순서를 기억해요', bg: 'hill' },
];
const FULL_PLAYS = 6;

function playMult(p) {
  const k = todayKey();
  if (!p.miniDay || p.miniDay.key !== k) p.miniDay = { key: k, n: 0 };
  const base = p.miniDay.n < FULL_PLAYS ? 1 : 0.35;
  return base * (1 + 0.1 * P.treeLv(p, 'dust'));
}
function finishPlay(p, who, dust) {
  p.miniDay.n++;
  p.dust += dust;
  P.dailyProgress(p, 'mini', 1);
  const hs = P.heroineState(p, who);
  let ups = [];
  if (P.heroineUnlocked(p, who) && hs.minis < 1) { hs.minis++; ups = P.addAff(p, who, 4); }
  refreshRes(); saveSoon(); checkAch();
  if (ups.length) setTimeout(() => levelUpFx(`<div class="big">${HEROINES[who].name} 호감도 ${ups[ups.length - 1]}</div><div class="t13 muted">새 이야기가 열렸어요</div>`), 700);
  return hs.minis === 1 && ups !== null;
}

export function playTab(body) {
  bgm('mini');
  const p = App.p;
  playMult(p);
  const list = h('div.mini-list');
  for (const m of MINIS) {
    const ok = P.heroineUnlocked(p, m.who);
    const card = h('button.mini-card', { type: 'button', disabled: ok ? null : true, onclick: () => startMini(m.id) });
    card.innerHTML = `<div class="mc-art">${sceneSVG(m.bg)}${ok ? heroineSVG(m.who, { e: 'smile', outfit: p.heroines[m.who].outfit }) : ''}</div>
      <div class="mc-ic" style="color:var(--gold)">${icon(ok ? m.icon : 'lock')}</div>
      <div class="mc-tx"><div class="mc-nm">${m.name}</div><div class="mc-ds">${ok ? m.desc : '동료를 만나면 열려요'}</div></div>`;
    list.appendChild(card);
  }
  const left = Math.max(0, FULL_PLAYS - p.miniDay.n);
  body.append(h('div.topbar', resBar(), h('button.icon-btn', { type: 'button', onclick: () => settingsSheet(), html: icon('gear') })),
    h('div.row.between', { style: { padding: '0 14px 8px' } }, h('div.b.t18', { text: '놀이' }), h('span.pill', { text: left ? `오늘 보상 ${left}회 남음` : '오늘 보상 감소 중' })),
    h('div.scroll.grow', list,
      h('div.card', { style: { margin: '0 12px 14px' } }, h('div.b', { text: '놀이 보상' }), h('div.t13.muted', { style: { lineHeight: '1.6', marginTop: '4px' }, text: `놀이를 하면 달가루를 얻어요. 하루 ${FULL_PLAYS}번까지는 보상을 전부 받고, 그 뒤로는 조금만 받아요. 함께 논 동료는 하루 한 번 호감도가 올라요.` }))));
}

export function startMini(id) { go(miniScreen, id); }

function miniScreen(el, id) {
  const m = MINIS.find((x) => x.id === id);
  const p = App.p;
  bgm('mini');
  el.classList.add('mini-scr');
  App.onBack = () => { go(hubScreen, 'play'); return true; };
  const field = h('div.mini-field');
  field.innerHTML = sceneSVG(m.bg);
  const comp = h('div.mini-comp');
  const who = m.who;
  const hs = P.heroineState(p, who);
  const drawComp = (e) => { comp.innerHTML = heroineSVG(who, { e, outfit: hs.outfit }); };
  drawComp('smile');
  field.appendChild(comp);
  let sayEl = null;
  const say = (line, ms = 2600) => { if (!line) return; if (sayEl) sayEl.remove(); sayEl = h('div.mini-say', { text: line.t }); field.appendChild(sayEl); drawComp(line.e || 'smile'); clearTimeout(say.t); say.t = setTimeout(() => { if (sayEl) { sayEl.remove(); sayEl = null; } }, ms); };
  const line = (k) => { const l = HEROINES[who].minigame[k]; return l[Math.floor(Math.random() * l.length)]; };
  const bottom = h('div.mini-bottom');
  el.append(h('div.mini-head', h('button.icon-btn', { type: 'button', html: icon('back'), onclick: () => go(hubScreen, 'play') }), h('div.ttl', { text: m.name }), resBar(['dust'])), field, bottom);
  const ctx = { el, field, bottom, say, line, drawComp, p, who };
  setTimeout(() => say(line('start')), 300);
  const games = { fish: fishGame, cook: cookGame, hilo: hiloGame, constel: constelGame };
  return games[id](ctx);
}

// ───────── 별 낚시 ─────────
function fishGame(ctx) {
  const { field, bottom, say, line, p } = ctx;
  let state = 'idle', raf = 0, timers = [];
  const bob = h('div.bobber', { html: `<svg viewBox="0 0 28 28"><circle cx="14" cy="16" r="9" fill="#fff"/><path d="M5 16a9 9 0 0118 0z" fill="#ff6b8a"/><path d="M14 2v6" stroke="#fff" stroke-width="2"/></svg>` });
  const rip = h('div.ripple');
  const info = h('div.t14.muted', { style: { textAlign: 'center', minHeight: '22px' } }, '찌를 던져서 낚시를 시작해요');
  const meterWrap = h('div', { style: { display: 'none' } });
  const zone = h('div.fish-zone.perfect');
  const mark = h('div.fish-mark');
  const meter = h('div.fish-meter', zone, mark);
  const rounds = h('div.fish-round');
  meterWrap.append(meter, h('div', { style: { height: '8px' } }), rounds);
  const action = btn('찌 던지기', () => onTap(), { cls: 'wide big blue' });
  bottom.append(info, meterWrap, action);
  let fish = null, round = 0, results = [], pos = 0, dir = 1, zStart = 0, zW = 0.25, speed = 1;
  const clear = () => { cancelAnimationFrame(raf); timers.forEach(clearTimeout); timers = []; };
  const pickFish = () => {
    const r = Math.random();
    const rar = r < 0.02 + 0.002 * ctx.p.heroines.lyra.lv ? 'l' : r < 0.12 ? 'e' : r < 0.42 ? 'r' : 'c';
    const pool = FISH.filter((f) => f.rar === rar);
    return pool[Math.floor(Math.random() * pool.length)];
  };
  function onTap() {
    if (state === 'idle' || state === 'done') cast();
    else if (state === 'wait') { info.textContent = '아직 입질이 없어요. 조금만 기다려요'; sfx('error'); }
    else if (state === 'bite') hook();
    else if (state === 'reel') stopMeter();
  }
  function cast() {
    clear();
    state = 'wait'; results = []; round = 0;
    meterWrap.style.display = 'none';
    field.appendChild(rip); field.appendChild(bob);
    bob.classList.remove('bite');
    sfx('splash');
    info.textContent = '찌를 지켜봐요…';
    action.querySelector('.lbl').textContent = '기다리는 중';
    timers.push(setTimeout(() => {
      state = 'bite'; fish = pickFish();
      bob.classList.add('bite');
      sfx('tick'); sfx('pick');
      info.innerHTML = '<b class="gold">입질이 왔어요! 지금 당겨요!</b>';
      action.querySelector('.lbl').textContent = '당기기!';
      timers.push(setTimeout(() => { if (state === 'bite') { state = 'done'; info.textContent = '물고기가 도망갔어요… 다시 던져 봐요'; say(line('lose')); action.querySelector('.lbl').textContent = '다시 던지기'; bob.classList.remove('bite'); } }, 1100));
    }, 1500 + Math.random() * 2500));
  }
  function hook() {
    state = 'reel';
    bob.classList.remove('bite');
    sfx('good');
    meterWrap.style.display = 'block';
    info.innerHTML = '초록 칸에서 멈추면 릴을 감아요. <span class="gold">가운데</span>는 완벽!';
    action.querySelector('.lbl').textContent = '멈추기';
    startMeter();
  }
  function drawRounds() { rounds.innerHTML = ''; for (let i = 0; i < 3; i++) rounds.appendChild(h('i.' + (results[i] === 2 ? 'pf' : results[i] === 1 ? 'ok' : results[i] === 0 ? 'bad' : 'x'))); }
  function startMeter() {
    zW = fish.zone * (1 - round * 0.08);
    zStart = 0.1 + Math.random() * (0.8 - zW);
    zone.style.left = zStart * 100 + '%'; zone.style.width = zW * 100 + '%';
    speed = fish.speed * (1 + round * 0.12);
    pos = 0; dir = 1;
    drawRounds();
    let last = performance.now();
    const step = (t) => {
      const dt = Math.min(50, t - last) / 1000; last = t;
      pos += dir * dt * 0.9 * speed;
      if (pos >= 1) { pos = 1; dir = -1; } if (pos <= 0) { pos = 0; dir = 1; }
      mark.style.left = pos * 100 + '%';
      raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
  }
  function stopMeter() {
    cancelAnimationFrame(raf);
    const inZ = pos >= zStart && pos <= zStart + zW;
    const center = zStart + zW / 2;
    const perfect = Math.abs(pos - center) <= zW * 0.15;
    results.push(perfect ? 2 : inZ ? 1 : 0);
    sfx(perfect ? 'fortune' : inZ ? 'good' : 'error');
    drawRounds();
    round++;
    if (round < 3) { state = 'pause'; timers.push(setTimeout(() => { state = 'reel'; startMeter(); }, 420)); return; }
    const okN = results.filter((x) => x > 0).length;
    state = 'done';
    action.querySelector('.lbl').textContent = '다시 던지기';
    if (okN >= 2) caught(results.every((x) => x === 2));
    else { info.textContent = `${josa(fish.name, '이/가')} 줄을 끊고 도망갔어요…`; say(line('lose')); }
  }
  function caught(perfect) {
    const mult = playMult(p);
    const dust = Math.max(1, Math.round(fish.dust * (perfect ? 1.5 : 1) * mult));
    p.stats.fish++;
    P.recordCodex(p, 'fish', fish.id);
    P.dailyProgress(p, 'fish', 1);
    if (fish.gift) P.addGift(p, fish.gift, 1);
    finishPlay(p, 'lyra', dust);
    sfx('win');
    say(line('win'));
    info.innerHTML = `<b class="rar-${fish.rar}">${fish.name}</b>${josa(fish.name, '을/를').slice(fish.name.length)} 낚았어요! ${perfect ? '<span class="gold">완벽!</span> ' : ''}달가루 <b class="gold">+${dust}</b>${fish.gift ? ` · <span class="pinkc">선물 ${GIFT_BY_ID[fish.gift].name}</span>` : ''}`;
    const art = h('div', { html: fishSVG(fish.color), style: { position: 'absolute', left: '50%', top: '30%', width: '120px', marginLeft: '-60px', zIndex: '3', animation: 'pop .3s ease-out' } });
    ctx.field.appendChild(art);
    setTimeout(() => art.remove(), 1800);
  }
  return () => clear();
}
export function fishSVG(c) {
  return `<svg viewBox="0 0 120 70"><path d="M8 35C26 12 60 6 84 22L106 8V62L84 48C60 64 26 58 8 35Z" fill="${c}"/><path d="M84 22L106 8V62L84 48Z" fill="#000" opacity=".12"/><circle cx="30" cy="31" r="5" fill="#2a1f3a"/><circle cx="28.5" cy="29.5" r="1.8" fill="#fff"/><path d="M48 22C56 30 56 40 48 48" stroke="#fff" stroke-opacity=".5" stroke-width="3" fill="none"/></svg>`;
}

// ───────── 달빛 요리 ─────────
function cookGame(ctx) {
  const { field, bottom, say, line, p } = ctx;
  const lyraLv = p.heroines.lyra.lv;
  let timers = [], raf = 0;
  const clear = () => { timers.forEach(clearTimeout); timers = []; cancelAnimationFrame(raf); };
  const menu = () => {
    clear();
    bottom.innerHTML = '';
    bottom.appendChild(h('div.t14.muted', { text: '만들 요리를 골라요. 요리는 다음 원정에 효과를 줘요.' }));
    for (const r of RECIPES) {
      const ok = lyraLv >= r.lv;
      bottom.appendChild(h('button.reward-row', { type: 'button', disabled: ok ? null : true, style: ok ? null : { opacity: '.45' }, onclick: () => play(r) },
        h('div.ico', { html: icon(ok ? 'pot' : 'lock'), style: { color: '#ffb34c' } }),
        h('div.grow', h('div.b', { text: r.name + (p.codex.recipes[r.id] ? '' : ' · 처음') }), h('div.t12.muted', { text: ok ? `${r.steps.length}단계 · ${r.buffText}` : `리라 호감도 ${r.lv}에 열려요` }))));
    }
  };
  const play = (r) => {
    clear();
    bottom.innerHTML = '';
    const steps = h('div.cook-steps');
    const ing = h('div.ingr-grid');
    const tb = h('i', { style: { width: '100%' } });
    const timer = h('div.timer-bar', tb);
    const msg = h('div.t14', { style: { textAlign: 'center', minHeight: '22px' } }, '순서를 잘 기억해요!');
    bottom.append(msg, steps, timer, ing);
    let idx = 0, miss = 0, running = false;
    const drawSteps = (hide) => {
      steps.innerHTML = '';
      r.steps.forEach((s, i) => { const g = INGREDIENTS.find((x) => x.id === s); steps.appendChild(h('div.cook-step' + (i < idx ? '.done' : '') + (hide && i >= idx ? '.hidden' : ''), { style: { borderColor: i < idx ? null : null } }, h('span', { text: g.name }))); });
    };
    drawSteps(false);
    for (const g of INGREDIENTS) {
      const b = h('button.ingr', { type: 'button', disabled: true, onclick: () => pick(g.id, b) }, h('span.dot', { style: { background: g.color } }), h('span', { text: g.name }));
      ing.appendChild(b);
    }
    const memo = 1800 + r.steps.length * 350;
    timers.push(setTimeout(() => {
      drawSteps(true);
      msg.textContent = '기억한 순서대로 재료를 넣어요!';
      ing.querySelectorAll('button').forEach((x) => { x.disabled = false; });
      running = true;
      const total = r.steps.length * 2200, t0 = performance.now();
      const tick = (t) => { const k = 1 - (t - t0) / total; tb.style.width = Math.max(0, k * 100) + '%'; if (k <= 0 && running) { fail('시간이 다 됐어요…'); return; } if (running) raf = requestAnimationFrame(tick); };
      raf = requestAnimationFrame(tick);
    }, memo));
    function pick(id2, b) {
      if (!running) return;
      if (r.steps[idx] === id2) { idx++; sfx('place'); drawSteps(true); if (idx >= r.steps.length) success(); }
      else { miss++; sfx('error'); b.classList.remove('wrong'); void b.offsetWidth; b.classList.add('wrong'); msg.innerHTML = `<span class="bad">앗 순서가 틀렸어요! (실수 ${miss}/2)</span>`; if (miss >= 2) fail('요리가 타 버렸어요…'); }
    }
    function fail(t) { running = false; cancelAnimationFrame(raf); msg.innerHTML = `<span class="bad">${t}</span>`; say(line('lose')); sfx('lose'); ing.querySelectorAll('button').forEach((x) => { x.disabled = true; }); bottom.appendChild(btn('다시 하기', () => menu(), { cls: 'wide' })); }
    function success() {
      running = false; cancelAnimationFrame(raf);
      const dust = Math.round((30 + r.steps.length * 10) * (miss ? 1 : 1.3) * playMult(p));
      p.stats.cooks++;
      P.recordCodex(p, 'recipes', r.id);
      p.nextBuff = { id: r.id };
      finishPlay(p, 'lyra', dust);
      say(line('win'));
      sfx('win');
      msg.innerHTML = `<b class="gold">${r.name} 완성!</b> 달가루 +${dust}<br><span class="t13 good">다음 원정: ${r.buffText}</span>`;
      ing.querySelectorAll('button').forEach((x) => { x.disabled = true; });
      bottom.appendChild(btn('다른 요리 하기', () => menu(), { cls: 'wide' }));
    }
  };
  menu();
  return () => clear();
}

// ───────── 하이로우 ─────────
const HILO_MULT = [1, 1.35, 1.8, 2.4, 3.2, 4.3, 5.8, 7.8, 10.5, 14, 19];
function hiloGame(ctx) {
  const { field, bottom, say, line, p } = ctx;
  const table = h('div.hilo-table', { style: { position: 'absolute', top: '0', left: '0', right: '0', bottom: '0', zIndex: '2', paddingRight: '90px' } });
  field.appendChild(table);
  const SUITS = ['♠', '♥', '♦', '♣'];
  const NAMES = { 1: 'A', 11: 'J', 12: 'Q', 13: 'K' };
  let bet = 0, streak = 0, cur = null, playing = false;
  const card = (c, back) => { const d = h('div.pcard' + (back ? '.back' : '') + (!back && (c.s === 1 || c.s === 2) ? '.red' : '') + '.flip'); if (!back) d.append(h('div.ps', { text: SUITS[c.s] }), h('div.pv', { text: NAMES[c.v] || c.v }), h('div.ps', { text: SUITS[c.s], style: { textAlign: 'right' } })); return d; };
  const draw = () => ({ v: 1 + Math.floor(Math.random() * 13), s: Math.floor(Math.random() * 4) });
  const info = h('div.hilo-streak');
  const ctrl = h('div.col.gap');
  bottom.append(info, ctrl);
  const lobby = () => {
    playing = false; streak = 0;
    table.innerHTML = ''; table.append(card(null, true), card(null, true));
    info.innerHTML = '달가루를 걸고 시작해요. 다음 카드가 <b>높을지 낮을지</b> 맞혀요.';
    ctrl.innerHTML = '';
    const row = h('div.row.gap');
    for (const b of [20, 50, 100, 250]) row.appendChild(btn(`${b}`, () => start(b), { cls: 'grow small' + (p.dust < b ? '' : ' ghost'), icon: 'dust', disabled: p.dust < b }));
    ctrl.append(row, h('div.t12.dim', { style: { textAlign: 'center' }, text: `배당: 1연승 ×${HILO_MULT[1]} · 3연승 ×${HILO_MULT[3]} · 5연승 ×${HILO_MULT[5]} · 10연승 ×${HILO_MULT[10]}` }));
  };
  const start = (b) => {
    if (p.dust < b) return;
    p.dust -= b; refreshRes(); bet = b; streak = 0; playing = true;
    cur = draw();
    sfx('page');
    say({ e: 'smile', t: HEROINES.mio.minigame.start[0].t });
    show();
  };
  const show = (prev, ok) => {
    table.innerHTML = '';
    table.append(card(cur), card(null, true));
    const payout = Math.floor(bet * HILO_MULT[streak]);
    info.innerHTML = streak ? `<b>${streak}</b>연승 · 지금 그만두면 <span class="gold">${payout}</span>` : `건 달가루 <span class="gold">${bet}</span>`;
    ctrl.innerHTML = '';
    const hi = btn('높다 ▲', () => guess(1), { cls: 'grow blue', sub: `${Math.round(((13 - cur.v) / 12) * 100)}%`, disabled: cur.v === 13 });
    const lo = btn('낮다 ▼', () => guess(-1), { cls: 'grow pink', sub: `${Math.round(((cur.v - 1) / 12) * 100)}%`, disabled: cur.v === 1 });
    ctrl.append(h('div.row.gap', lo, hi), btn(streak ? `그만두고 ${payout} 받기` : '그만두기 (돌려받기)', () => cash(), { cls: 'ghost wide' }));
  };
  const guess = (d) => {
    let nx = draw();
    while (nx.v === cur.v) nx = draw();
    const win = d > 0 ? nx.v > cur.v : nx.v < cur.v;
    table.innerHTML = '';
    table.append(card(cur), card(nx));
    sfx('page');
    ctrl.innerHTML = '';
    setTimeout(() => {
      if (win) {
        streak++; sfx('good');
        p.stats.hiloBest = Math.max(p.stats.hiloBest, streak);
        if (streak % 3 === 0) { const lv = p.heroines.mio.lv; const who = lv <= 2 ? '손님' : lv <= 5 ? '단골' : '별지기'; say({ e: 'surprise', t: `${josa(who, '은/는')} 오늘 운이 너무 좋은 거 아니야? 나는 조금 무서워졌어!` }); }
        cur = nx;
        if (streak >= HILO_MULT.length - 1) { cash(); return; }
        show();
      } else {
        sfx('lose');
        say(line('lose'));
        info.innerHTML = `<span class="bad">아쉽게 틀렸어요…</span> ${streak}연승에서 멈췄어요`;
        playing = false;
        finishPlay(p, 'mio', 0);
        ctrl.appendChild(btn('한 판 더', () => lobby(), { cls: 'wide' }));
      }
    }, 450);
  };
  const cash = () => {
    const payout = Math.floor(bet * HILO_MULT[streak]);
    playing = false;
    if (streak > 0) { sfx('win'); say(line('win')); }
    const bonus = streak >= 3 ? Math.round(10 * streak * playMult(p)) : 0;
    p.dust += payout;
    finishPlay(p, 'mio', bonus);
    info.innerHTML = streak ? `<b class="gold">${payout + bonus}</b> 달가루를 챙겼어요!${bonus ? ` <span class="dim">(연승 보너스 ${bonus})</span>` : ''}` : '걸었던 달가루를 돌려받았어요';
    ctrl.innerHTML = '';
    ctrl.appendChild(btn('한 판 더', () => lobby(), { cls: 'wide' }));
    checkAch();
  };
  lobby();
  return () => { if (playing) { p.dust += Math.floor(bet * HILO_MULT[streak]); saveSoon(); } };
}

// ───────── 별자리 잇기 ─────────
function constelGame(ctx) {
  const { field, bottom, say, line, p } = ctx;
  const box = h('div.cs-field', { style: { position: 'absolute', top: '0', left: '0', right: '0', bottom: '0', zIndex: '2' } });
  field.appendChild(box);
  const POS = [[22, 20], [52, 14], [78, 24], [34, 42], [64, 40], [18, 64], [48, 66], [76, 60]];
  const stars = POS.map(([x, y], i) => { const b = h('button.cs-star', { type: 'button', 'data-silent': '1', style: { left: x + '%', top: y + '%' }, html: icon('star'), disabled: true, onclick: () => tap(i) }); box.appendChild(b); return b; });
  const NOTES = ['click', 'pick', 'tab', 'tick', 'page', 'good', 'place', 'heart'];
  const info = h('div.t15', { style: { textAlign: 'center', minHeight: '24px' } }, '세렌이 보여 주는 별의 순서를 기억해요');
  const act = btn('시작', () => begin(), { cls: 'wide big' });
  bottom.append(info, act);
  let seq = [], input = 0, round = 0, showing = false, timers = [];
  const clear = () => { timers.forEach(clearTimeout); timers = []; };
  const light = (i, ms = 380) => { stars[i].classList.add('lit'); sfx(NOTES[i]); timers.push(setTimeout(() => stars[i].classList.remove('lit'), ms)); };
  const begin = () => { clear(); seq = []; round = 0; act.style.display = 'none'; nextRound(); };
  const nextRound = () => {
    round++;
    seq.push(Math.floor(Math.random() * stars.length));
    input = 0; showing = true;
    info.innerHTML = `<b class="gold">${round}단계</b> · 잘 봐요`;
    stars.forEach((s) => { s.disabled = true; });
    const gap = Math.max(260, 560 - round * 22);
    seq.forEach((v, k) => timers.push(setTimeout(() => light(v, gap * 0.7), 600 + k * gap)));
    timers.push(setTimeout(() => { showing = false; info.innerHTML = `<b class="gold">${round}단계</b> · 같은 순서로 눌러요`; stars.forEach((s) => { s.disabled = false; }); }, 600 + seq.length * gap));
  };
  const tap = (i) => {
    if (showing) return;
    light(i, 200);
    if (seq[input] !== i) {
      stars[i].classList.add('wrong'); setTimeout(() => stars[i].classList.remove('wrong'), 400);
      sfx('error');
      const reached = round - 1;
      p.stats.constelBest = Math.max(p.stats.constelBest, reached);
      const dust = Math.round(reached * 9 * playMult(p));
      finishPlay(p, 'seren', dust);
      say(reached >= 6 ? line('win') : line('lose'));
      info.innerHTML = `${reached}단계까지 성공했어요 · 달가루 <b class="gold">+${dust}</b>`;
      stars.forEach((s) => { s.disabled = true; });
      act.style.display = ''; act.querySelector('.lbl').textContent = '다시 하기';
      return;
    }
    input++;
    if (input >= seq.length) { stars.forEach((s) => { s.disabled = true; }); sfx('good'); if (round % 4 === 0) say(line('win'), 1800); timers.push(setTimeout(nextRound, 650)); }
  };
  return () => clear();
}
