// 허브: 하단 탭(야영지·원정·별자리·동료·놀이)
import { h, btn, ic, sheet, toast, countTo, numEl, confirmBox } from './dom.js';
import { App, go, saveSoon, resBar, refreshRes, checkAch, bgm, levelUpFx } from './app.js';
import { icon } from '../art/icons.js';
import { sceneSVG } from '../art/scenes.js';
import { heroineSVG } from '../art/heroines.js';
import { fmt, todayKey, josa } from '../core/util.js';
import * as P from '../core/profile.js';
import { newRun, dailySeed, DAILY_MODS } from '../core/run.js';
import { Rng } from '../core/rng.js';
import { CLASSES, CLASS_BY_ID, classLevel, CLASS_XP, CLASS_MAX_LV } from '../data/classes.js';
import { TREE, TREE_BY_ID, PHASES } from '../data/meta.js';
import { HEROINES } from '../data/heroines/index.js';
import { HEROINE_META, HEROINE_IDS, tierOf } from '../data/heroine_meta.js';
import { RECIPE_BY_ID } from '../data/minigames.js';
import { companionAssist, COMPANIONS } from '../data/companions.js';
import { runScreen } from './scr_run.js';
import { heroineTab } from './scr_heroine.js';
import { playTab } from './scr_mini.js';
import { settingsSheet, missionsSheet, achievementsScreen, codexScreen, giftShopSheet } from './scr_misc.js';
import { sfx } from '../audio/audio.js';

const TABS = [
  { id: 'home', name: '야영지', icon: 'tent' },
  { id: 'prep', name: '원정', icon: 'battle' },
  { id: 'tree', name: '별자리', icon: 'constel' },
  { id: 'heroine', name: '동료', icon: 'heart' },
  { id: 'play', name: '놀이', icon: 'game' },
];

export function hubScreen(el, tab = 'home', arg) {
  const p = App.p;
  P.ensureDaily(p);
  const body = h('div.col', { style: { flex: '1', minHeight: '0', position: 'relative' } });
  const bar = h('div.tabbar');
  for (const t of TABS) {
    const b = h('button.tab' + (t.id === tab ? '.on' : ''), { type: 'button', onclick: () => { if (t.id !== tab) go(hubScreen, t.id); } }, ic(t.icon), h('span', { text: t.name }));
    if (t.id === 'heroine' && HEROINE_IDS.some((id) => P.heroineUnlocked(p, id) && P.pendingScenes(p, id).length)) b.appendChild(h('i.badge-dot'));
    if (t.id === 'tree' && TREE.some((n) => P.treeAvailable(p, n.id) && p.shards >= P.treeCost(p, n.id))) b.appendChild(h('i.badge-dot'));
    bar.appendChild(b);
  }
  el.append(body, bar);
  App.onBack = () => { if (tab !== 'home') { go(hubScreen, 'home'); return true; } return false; };
  if (tab === 'home') return homeTab(body);
  if (tab === 'prep') return prepTab(body, arg);
  if (tab === 'tree') return treeTab(body);
  if (tab === 'heroine') return heroineTab(body, arg);
  if (tab === 'play') return playTab(body);
}

function topbar(extra) {
  return h('div.topbar', resBar(), extra || null, h('button.icon-btn', { type: 'button', onclick: () => settingsSheet(), html: icon('gear') }));
}

// ───────── 야영지 ─────────
function homeTab(body) {
  bgm('camp');
  const p = App.p;
  const featured = HEROINE_IDS.filter((id) => P.heroineUnlocked(p, id)).includes(p.lastCompanion) ? p.lastCompanion : 'lyra';
  const stage = h('div.camp-stage');
  stage.innerHTML = sceneSVG('camp');
  const hw = h('div.heroine-wrap.breathe');
  const hs = P.heroineState(p, featured);
  hw.innerHTML = heroineSVG(featured, { e: 'smile', outfit: hs.outfit });
  stage.appendChild(hw);
  let bub = null;
  const say = (line) => {
    if (bub) bub.remove();
    bub = h('div.bubble', { style: { bottom: '62%' } }, h('span.who', { text: HEROINES[featured].name }), line.t);
    stage.appendChild(bub);
    hw.innerHTML = heroineSVG(featured, { e: line.e || 'smile', outfit: hs.outfit });
    clearTimeout(say.t);
    say.t = setTimeout(() => { if (bub) { bub.remove(); bub = null; } }, 4200);
  };
  hw.addEventListener('click', () => {
    const tier = tierOf(featured, hs.lv);
    const list = HEROINES[featured].greet[tier];
    say(list[Math.floor(Math.random() * list.length)]);
    sfx('heart');
  });
  const blink = setInterval(() => { const s = hw.querySelector('.heroine'); if (s) { s.classList.add('blinking'); setTimeout(() => s.classList.remove('blinking'), 130); } }, 3400);
  // 오른쪽 아이콘
  const d = P.ensureDaily(p);
  const missionDot = d.missions.some((m) => !m.claimed && m.prog >= m.n) || (!d.bonus && d.missions.every((m) => m.claimed));
  const side = h('div.side-icons',
    sideBtn('chat', '임무', () => missionsSheet(() => go(hubScreen, 'home')), missionDot),
    sideBtn('gift', '상점', () => giftShopSheet()),
    sideBtn('book', '도감', () => go(codexScreen)),
    sideBtn('trophy', '업적', () => go(achievementsScreen)),
  );
  stage.appendChild(side);
  body.append(topbar(), stage);
  // 아래 패널
  const panel = h('div.camp-panel');
  if (p.run) {
    panel.appendChild(h('div.card.glow.row.gap2', h('div.crystal-ico', { html: icon('battle'), style: { color: 'var(--gold)' } }),
      h('div.grow', h('div.b', { text: '원정 진행 중' }), h('div.t13.muted', { text: `${CLASS_BY_ID[p.run.cls].name} · ${p.run.act}구역 · 체력 ${p.run.hero.hp}/${p.run.hero.maxHp}` })),
      btn('이어하기', () => go(runScreen), { cls: 'small' })));
  }
  const stored = numEl(P.crystalStored(p));
  const rate = P.crystalRate(p);
  const cap = P.crystalCapHours(p);
  const fill = h('i', { style: { width: `${Math.min(100, (P.crystalStored(p) / (rate * cap)) * 100)}%` } });
  const harvest = btn('수확', () => {
    const n = P.crystalCollect(p);
    if (n <= 0) { toast('아직 모인 달가루가 없어요', { icon: 'dust' }); return; }
    sfx('gold');
    toast(`달가루 <b class="gold">+${fmt(n)}</b>`, { icon: 'dust' });
    countTo(stored, 0); fill.style.width = '0%';
    refreshRes(); checkAch(); saveSoon();
  }, { cls: 'small blue' });
  panel.appendChild(h('div.card.crystal-card', h('div.crystal-ico', { html: icon('crystal') }),
    h('div.grow', h('div.row.between', h('span.b', { text: '별빛 수정' }), h('span.t12.muted', { text: `시간당 ${fmt(rate)} · 최대 ${cap}시간` })),
      h('div.row.gap', { style: { marginTop: '4px' } }, h('span.t15.b.gold', stored), h('span.t12.dim', { text: '달가루' })),
      h('div.prog.blue', { style: { marginTop: '5px' } }, fill)),
    harvest));
  const tick = setInterval(() => { countTo(stored, P.crystalStored(p), 300); fill.style.width = `${Math.min(100, (P.crystalStored(p) / (rate * cap)) * 100)}%`; }, 5000);
  // 오늘의 도전
  const ch = p.challenge;
  const todayDone = ch.key === todayKey() && ch.done;
  panel.appendChild(h('div.card.row.gap2', h('div.crystal-ico', { html: icon('moon'), style: { color: 'var(--pink)', background: 'radial-gradient(circle, rgba(255,154,214,.3), rgba(255,154,214,.05))' } }),
    h('div.grow', h('div.b', { text: '오늘의 도전' }), h('div.t12.muted', { text: todayDone ? '오늘 도전을 마쳤어요. 내일 새 도전이 열려요.' : '매일 바뀌는 규칙으로 도전해요. 별조각 +20%' })),
    btn(todayDone ? '완료' : '도전', () => go(hubScreen, 'prep', { daily: true }), { cls: 'small pink', disabled: todayDone || !!p.run })));
  body.appendChild(panel);
  // 첫 방문 안내
  if (!p.tutorial.camp) {
    p.tutorial.camp = true; saveSoon();
    setTimeout(() => say({ e: 'happy', t: '여기가 우리 야영지야! 원정 탭에서 미궁으로 출발할 수 있어.' }), 500);
  } else setTimeout(() => hw.click(), 600);
  // 해금 소식
  showNews();
  return () => { clearInterval(blink); clearInterval(tick); clearTimeout(say.t); };
}
function sideBtn(icn, cap, fn, dot) {
  return h('button.icon-btn', { type: 'button', onclick: fn, html: icon(icn) + `<span class="cap">${cap}</span>` + (dot ? '<i class="badge-dot"></i>' : '') });
}
function showNews() {
  const p = App.p;
  if (!p.news || !p.news.length) return;
  const items = p.news.splice(0);
  saveSoon();
  sheet((b, close) => {
    for (const n of items) {
      if (n.k === 'class') { const c = CLASS_BY_ID[n.id]; b.appendChild(h('div.item', h('div.ico', { html: icon('star'), style: { color: c.color } }), h('div.grow', h('div.tt', { text: `새 직업 해금 · ${c.name}` }), h('div.ds', { text: c.desc })))); }
      if (n.k === 'heroine') { const d = HEROINES[n.id]; b.appendChild(h('div.item', h('div.ico', { html: heroineSVG(n.id, { head: 1, e: 'smile' }), style: { padding: '0', overflow: 'hidden' } }), h('div.grow', h('div.tt', { text: `새 동료 · ${d.name}` }), h('div.ds', { text: d.profile })))); }
      if (n.k === 'act4') b.appendChild(h('div.item', h('div.ico', { html: icon('moon'), style: { color: 'var(--gold)' } }), h('div.grow', h('div.tt', { text: '달의 왕좌가 열렸어요' }), h('div.ds', { text: '이제 원정은 4구역까지 이어져요. 밤의 여왕 녹스가 기다리고 있어요.' }))));
    }
    b.appendChild(h('div', { style: { height: '12px' } }));
    b.appendChild(btn('좋아요', () => close(), { cls: 'wide' }));
  }, { title: '새 소식', cls: 'small' });
}

// ───────── 원정 준비 ─────────
function prepTab(body, arg = {}) {
  bgm('map');
  const p = App.p;
  const daily = !!arg.daily;
  const wrap = h('div.scroll.grow');
  body.append(topbar(), wrap);
  const box = h('div.prep.col.gap2');
  wrap.appendChild(box);
  if (p.run) {
    box.appendChild(h('div.card.glow', h('div.b.t18', { text: '진행 중인 원정이 있어요' }),
      h('div.t13.muted', { style: { margin: '4px 0 12px' }, text: `${CLASS_BY_ID[p.run.cls].name} · ${p.run.act}구역 · 위상 ${p.run.phase}` }),
      h('div.row.gap', btn('이어하기', () => go(runScreen), { cls: 'grow' }), btn('포기하기', () => confirmBox('이번 원정을 포기할까요?<br><span class="dim">지금까지의 별조각은 받을 수 있어요.</span>', () => {
        p.run.over = 'lose';
        const res = P.onRunEnd(p, p.run);
        toast(`별조각 +${res.shards}`, { icon: 'shard' });
        saveSoon(); go(hubScreen, 'prep');
      }, { danger: true, yes: '포기' }), { cls: 'ghost' }))));
    return;
  }
  // 오늘의 도전 설정
  let dcfg = null;
  if (daily) {
    const r = new Rng(dailySeed(todayKey()));
    const avail = p.unlocked.classes;
    dcfg = { cls: r.pick(avail), mods: r.sample(Object.keys(DAILY_MODS), 2), seed: dailySeed(todayKey()) };
    box.appendChild(h('div.card.glow', h('div.row.between', h('div.b.t18.pinkc', { text: '오늘의 도전' }), h('span.pill', { text: todayKey() })),
      h('div.t13.muted', { style: { margin: '6px 0' }, text: '모든 별지기가 같은 지도와 규칙으로 도전해요. 하루에 한 번 보상을 받을 수 있어요.' }),
      ...dcfg.mods.map((m) => h('div.item', h('div.ico', { html: icon('moon'), style: { color: 'var(--pink)' } }), h('div.grow', h('div.tt', { text: DAILY_MODS[m].name }), h('div.ds', { text: DAILY_MODS[m].desc })))),
    ));
  }
  let selCls = dcfg ? dcfg.cls : (p.lastClass && p.unlocked.classes.includes(p.lastClass) ? p.lastClass : 'knight');
  let phase = 0;
  let comp = p.lastCompanion && P.heroineUnlocked(p, p.lastCompanion) ? p.lastCompanion : 'lyra';
  // 직업
  const clsGrid = h('div.cls-cards');
  const clsInfo = h('div.card');
  const phaseBox = h('div.card');
  const renderCls = () => {
    clsGrid.innerHTML = '';
    for (const c of CLASSES) {
      const unlocked = p.unlocked.classes.includes(c.id);
      const lv = classLevel(p.classes[c.id].xp);
      const card = h('button.cls-card' + (selCls === c.id ? '.on' : '') + (unlocked ? '' : '.locked'), { type: 'button', disabled: dcfg && c.id !== dcfg.cls ? true : null, onclick: () => {
        if (!unlocked) { toast(`${c.unlock.text} 시 해금돼요`, { icon: 'lock' }); return; }
        selCls = c.id; phase = 0; renderCls();
      } },
        h('div.en', { text: c.en }), h('div.nm', { text: c.name, style: { color: unlocked ? c.color : 'var(--dim)' } }),
        h('div.t12.muted', { text: unlocked ? `체력 ${c.hp} · 재굴림 ${c.rerolls}` : c.unlock.text }),
        unlocked ? h('div.lv', { text: `Lv.${lv}` }) : h('div.lv', { html: icon('lock') }));
      clsGrid.appendChild(card);
    }
    const c = CLASS_BY_ID[selCls];
    const cx = p.classes[selCls];
    const lv = classLevel(cx.xp);
    const nextXp = lv < CLASS_MAX_LV ? CLASS_XP[lv + 1] : null;
    clsInfo.innerHTML = '';
    clsInfo.append(h('div.row.between', h('div.b.t18', { text: c.name, style: { color: c.color } }), h('span.pill', { text: `직업 레벨 ${lv}` })),
      h('div.t13.muted', { style: { margin: '6px 0', lineHeight: '1.6' }, text: c.desc }),
      h('div.t12.dim', { text: c.tip }),
      nextXp ? h('div', { style: { marginTop: '8px' } }, h('div.row.between.t12.muted', h('span', { text: '다음 레벨에서 새 기술과 유물이 열려요' }), h('span', { text: `${fmt(cx.xp)} / ${fmt(nextXp)}` })), h('div.prog', { style: { marginTop: '4px' } }, h('i', { style: { width: `${Math.min(100, ((cx.xp - CLASS_XP[lv]) / (nextXp - CLASS_XP[lv])) * 100)}%` } }))) : h('div.t12.gold', { text: '최고 레벨이에요' }));
    renderPhase();
  };
  const renderPhase = () => {
    const maxP = p.classes[selCls].phase;
    phaseBox.innerHTML = '';
    if (dcfg) { phaseBox.style.display = 'none'; return; }
    const moon = h('div.phase-moon', { html: phaseMoon(phase) });
    phaseBox.append(h('div.row.between', h('div.b', { text: '달의 위상' }), h('span.t12.muted', { text: `해금 ${maxP} / 20` })),
      h('div.phase-sel', { style: { marginTop: '8px' } },
        h('button.icon-btn', { type: 'button', disabled: phase <= 0 ? true : null, onclick: () => { phase--; renderPhase(); }, html: icon('back') }),
        moon, h('div.grow', h('div.b.t20', { text: `위상 ${phase}` }), h('div.t12.muted', { text: phase ? `별조각 +${phase * 8}%` : '기본 난이도' })),
        h('button.icon-btn', { type: 'button', disabled: phase >= maxP ? true : null, onclick: () => { phase++; renderPhase(); }, html: icon('next') })),
      phase ? h('div.t12', { style: { marginTop: '8px', color: '#d9c2ff', lineHeight: '1.6' }, html: PHASES.slice(1, phase + 1).map((x, i) => `<span class="dim">${i + 1}.</span> ${x}`).join('<br>') }) : h('div.t12.dim', { style: { marginTop: '6px' }, text: '원정을 완주하면 다음 위상이 열려요.' }));
  };
  box.append(h('div.b.t15', { text: '직업 선택' }), clsGrid, clsInfo, phaseBox);
  // 동료
  const compRow = h('div.comp-row');
  const compInfo = h('div.t12.muted', { style: { marginTop: '8px', lineHeight: '1.6' } });
  const renderComp = () => {
    compRow.innerHTML = '';
    for (const id of HEROINE_IDS) {
      const ok = P.heroineUnlocked(p, id);
      const b = h('button.comp-pick' + (comp === id ? '.on' : ''), { type: 'button', disabled: ok ? null : true, onclick: () => { comp = id; renderComp(); } });
      b.innerHTML = ok ? heroineSVG(id, { head: 1, e: comp === id ? 'happy' : 'smile', outfit: p.heroines[id].outfit }) + `<div class="cn">${HEROINES[id].name} · ♥${p.heroines[id].lv}</div>` : `<div class="cn" style="top:40%">${icon('lock')} 미해금</div>`;
      compRow.appendChild(b);
    }
    compRow.appendChild(h('button.comp-pick.none' + (comp === null ? '.on' : ''), { type: 'button', onclick: () => { comp = null; renderComp(); } }, '혼자'));
    if (comp) {
      const lv = p.heroines[comp].lv;
      const a = companionAssist(comp, lv);
      compInfo.innerHTML = `<b class="pinkc">${a.name}</b> · 기술 ${a.max}번 사용 시 충전<br>${a.desc}<br><span class="dim">상시 효과: ${COMPANIONS[comp].passive}</span>`;
    } else compInfo.textContent = '동료 없이 혼자 떠나요.';
  };
  box.append(h('div.b.t15', { text: '함께 갈 동료' }), h('div.card', compRow, compInfo));
  // 요리 효과
  if (p.nextBuff) box.appendChild(h('div.card.row.gap2', h('div.crystal-ico', { html: icon('pot'), style: { color: '#ffb34c' } }), h('div.grow', h('div.b', { text: RECIPE_BY_ID[p.nextBuff.id].name }), h('div.t12.muted', { text: RECIPE_BY_ID[p.nextBuff.id].buffText }))));
  box.appendChild(btn(daily ? '오늘의 도전 시작' : '미궁으로 출발', () => {
    const opt = { cls: selCls, phase, companion: comp ? { id: comp, lv: p.heroines[comp].lv } : null, buff: p.nextBuff ? RECIPE_BY_ID[p.nextBuff.id].buff : null };
    if (dcfg) { opt.mode = 'daily'; opt.seed = dcfg.seed; opt.dailyMods = dcfg.mods; opt.phase = 0; p.challenge = { key: todayKey(), done: false, best: 0 }; }
    const run = newRun(p, opt);
    p.run = run;
    p.lastClass = selCls;
    P.onRunStart(p, run);
    saveSoon();
    sfx('good');
    go(runScreen);
  }, { cls: 'big wide' + (daily ? ' pink' : '') }));
  box.appendChild(h('div', { style: { height: '8px' } }));
  renderCls(); renderComp();
}

export function phaseMoon(ph) {
  const k = ph / 20;
  const off = 22 - k * 44;
  return `<svg viewBox="0 0 44 44"><circle cx="22" cy="22" r="18" fill="#2a2660"/><clipPath id="pm${ph}"><circle cx="22" cy="22" r="18"/></clipPath><g clip-path="url(#pm${ph})"><circle cx="22" cy="22" r="18" fill="#fff3c8"/><circle cx="${22 + off + (k > 0 ? 0 : 40)}" cy="22" r="18" fill="#2a2660"/></g><circle cx="22" cy="22" r="18" fill="none" stroke="#ffd98a" stroke-opacity=".5"/></svg>`;
}

// ───────── 별자리 트리 ─────────
function treeTab(body) {
  bgm('map');
  const p = App.p;
  const wrap = h('div.tree-wrap');
  const canvas = h('div.tree-canvas');
  wrap.appendChild(canvas);
  const total = Object.values(p.tree).reduce((a, b) => a + b, 0);
  body.append(topbar(), h('div.row.between', { style: { padding: '0 14px 6px' } }, h('div.b.t18', { text: '별자리 트리' }), h('span.pill', { text: `총 ${total}레벨` })),
    h('div.t12.muted', { style: { padding: '0 14px 6px' }, text: '원정에서 모은 별조각으로 별을 밝혀 영원히 강해져요.' }), wrap);
  const render = () => {
    canvas.innerHTML = '';
    const H = 980;
    let lines = '';
    for (const n of TREE) if (n.req) { const q = TREE_BY_ID[n.req]; const on = P.treeLv(p, n.req) > 0; lines += `<line x1="${q.x}%" y1="${q.y / 100 * H + 25}" x2="${n.x}%" y2="${n.y / 100 * H + 25}" stroke="${on ? '#ffd98a' : '#ffffff'}" stroke-opacity="${on ? 0.55 : 0.12}" stroke-width="2" ${on ? '' : 'stroke-dasharray="4 6"'}/>`; }
    canvas.insertAdjacentHTML('beforeend', `<svg>${lines}</svg>`);
    for (const n of TREE) {
      const lv = P.treeLv(p, n.id);
      const av = P.treeAvailable(p, n.id);
      const can = av && p.shards >= P.treeCost(p, n.id);
      const b = h('button.tnode' + (lv ? '.has' : '') + (lv >= n.max ? '.max' : '') + (av ? '.av' : '') + (can ? '.buyable' : ''), { type: 'button', style: { left: n.x + '%', top: (n.y / 100 * H) + 'px' }, onclick: () => treeSheet(n, render) },
        h('div.orb', { html: icon(av || lv ? n.icon : 'lock') }), h('div.tl', { text: n.name }), h('div.tlv', { text: `${lv}/${n.max}` }));
      canvas.appendChild(b);
    }
  };
  render();
}
function treeSheet(n, rerender) {
  const p = App.p;
  sheet((b, close) => {
    const draw = () => {
      b.innerHTML = '';
      const lv = P.treeLv(p, n.id);
      const max = lv >= n.max;
      const av = P.treeAvailable(p, n.id);
      const cost = max ? 0 : P.treeCost(p, n.id);
      b.append(h('div.row.gap2', h('div.crystal-ico', { html: icon(n.icon), style: { color: 'var(--gold)' } }), h('div.grow', h('div.b.t18', { text: n.name }), h('div.t13.muted', { text: `레벨 ${lv} / ${n.max}` }))),
        h('div.sep'),
        h('div.kv', h('span', { text: '현재 효과' }), h('span', { text: lv ? n.desc(lv) : '없음' })),
        max ? null : h('div.kv', h('span', { text: '다음 레벨' }), h('span.gold', { text: n.desc(lv + 1) })),
        !av && !max ? h('div.t13.bad', { style: { marginTop: '8px' }, text: `${josa(TREE_BY_ID[n.req].name, '을/를')} 먼저 밝혀야 해요` }) : null,
        h('div', { style: { height: '14px' } }),
        max ? btn('최고 레벨', null, { cls: 'wide', disabled: true }) : btn(`별 밝히기`, () => {
          if (!P.buyTree(p, n.id)) { sfx('error'); toast('별조각이 부족해요', { icon: 'shard' }); return; }
          sfx('level'); refreshRes(); checkAch(); saveSoon(); rerender(); draw();
        }, { cls: 'wide', icon: 'shard', sub: fmt(cost), disabled: !av || p.shards < cost }));
    };
    draw();
  }, { title: '별자리', cls: 'small' });
}
