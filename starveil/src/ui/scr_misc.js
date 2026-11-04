// 설정·일일 임무·업적·도감·선물 상점
import { h, btn, ic, sheet, toast, confirmBox } from './dom.js';
import { App, go, saveSoon, saveNow, resBar, refreshRes, checkAch, bgm } from './app.js';
import { icon } from '../art/icons.js';
import { monsterSVG } from '../art/monsters.js';
import * as P from '../core/profile.js';
import { setVolumes, playBgm, stopBgm, sfx, currentBgm } from '../audio/audio.js';
import { ACHIEVEMENTS } from '../data/achievements.js';
import { SKILLS, resolveSkill } from '../data/skills.js';
import { RELICS } from '../data/relics.js';
import { ENEMIES } from '../data/enemies.js';
import { FISH, RECIPES, INGREDIENTS } from '../data/minigames.js';
import { GIFTS } from '../data/gifts.js';
import { CLASS_BY_ID } from '../data/classes.js';
import { skillDesc, reqText, rarName, SKILL_RAR } from './describe.js';
import { fishSVG } from './scr_mini.js';
import { hubScreen } from './scr_hub.js';
import { fmt } from '../core/util.js';

// ───────── 설정 ─────────
export function settingsSheet() {
  const p = App.p;
  const st = p.settings;
  sheet((b, close) => {
    const slider = (label, key) => {
      const val = h('span.t13.muted', { text: Math.round(st[key] * 100) + '%' });
      const inp = h('input.slider', { type: 'range', min: '0', max: '100', value: String(Math.round(st[key] * 100)) });
      inp.addEventListener('input', () => {
        st[key] = Number(inp.value) / 100; val.textContent = inp.value + '%';
        setVolumes(st.sfx, st.bgm);
        if (key === 'bgm') { if (st.bgm <= 0) stopBgm(); else if (!currentBgm()) playBgm('camp'); }
        saveSoon();
      });
      inp.addEventListener('change', () => sfx('click'));
      return h('div', { style: { marginBottom: '10px' } }, h('div.row.between', h('span.b', { text: label }), val), inp);
    };
    const toggle = (label, key, desc) => {
      const sw = h('button.switch' + (st[key] ? '.on' : ''), { type: 'button', onclick: () => { st[key] = !st[key]; sw.classList.toggle('on', st[key]); saveSoon(); } });
      return h('div.row.gap', { style: { padding: '8px 0' } }, h('div.grow', h('div.b', { text: label }), desc ? h('div.t12.muted', { text: desc }) : null), sw);
    };
    const speedRow = h('div.row.gap', { style: { padding: '8px 0' } }, h('div.grow.b', { text: '연출 속도' }));
    const sp = h('div.seg', { style: { margin: '0', flex: 'none' } });
    ['느리게', '보통', '빠르게'].forEach((n, i) => sp.appendChild(h('button' + (st.speed === i ? '.on' : ''), { type: 'button', onclick: () => { st.speed = i; saveSoon(); sp.querySelectorAll('button').forEach((x, k) => x.classList.toggle('on', k === i)); } }, n)));
    speedRow.appendChild(sp);
    b.append(slider('효과음', 'sfx'), slider('배경음악', 'bgm'), toggle('진동', 'vib', '맞거나 큰 피해를 줄 때 살짝 진동해요'), speedRow, h('div.sep'),
      h('div.b', { text: '저장 데이터' }), h('div.t12.muted', { style: { margin: '4px 0 8px' }, text: '진행 상황은 기기에 자동 저장돼요. 기기를 옮길 때는 저장 코드를 복사해 두세요.' }),
      h('div.row.gap', btn('저장 코드 복사', () => exportSheet(), { cls: 'ghost grow small' }), btn('코드로 불러오기', () => importSheet(), { cls: 'ghost grow small' })),
      h('div', { style: { height: '8px' } }),
      btn('처음부터 다시 하기', () => confirmBox('모든 진행 상황을 지우고 처음부터 시작할까요?<br><span class="bad">되돌릴 수 없어요.</span>', () => { P.resetSave(); location.reload(); }, { danger: true, yes: '모두 지우기' }), { cls: 'danger wide small' }),
      h('div.sep'), statsBlock());
  }, { title: '설정' });
}
function statsBlock() {
  const s = App.p.stats;
  const hrs = Math.floor(s.playMs / 3600000), mins = Math.floor((s.playMs % 3600000) / 60000);
  const wrap = h('div', h('div.b', { text: '기록', style: { marginBottom: '6px' } }));
  for (const [k, v] of [['플레이 시간', `${hrs}시간 ${mins}분`], ['원정', `${fmt(s.runs)}회 (완주 ${fmt(s.wins)}회)`], ['쓰러뜨린 적', fmt(s.kills)], ['최고 한 방', fmt(s.maxHit)], ['가장 깊은 곳', s.maxAct > 4 ? `심연 ${s.maxAct - 4}층` : `${s.maxAct}구역`], ['낚은 물고기', fmt(s.fish)], ['나눈 대화', fmt(s.talks)]]) wrap.appendChild(h('div.kv', h('span', { text: k }), h('span.b', { text: v })));
  return wrap;
}
function exportSheet() {
  const code = P.exportSave(App.p);
  sheet((b) => {
    const ta = h('textarea.code', { readonly: true });
    ta.value = code;
    b.append(h('div.t13.muted', { style: { marginBottom: '8px' }, text: '아래 코드를 메모장 같은 곳에 보관해 두세요.' }), ta, h('div', { style: { height: '8px' } }),
      btn('복사하기', async () => { try { await navigator.clipboard.writeText(code); toast('복사했어요', { icon: 'check' }); } catch (e) { ta.select(); document.execCommand('copy'); toast('복사했어요', { icon: 'check' }); } }, { cls: 'wide' }));
  }, { title: '저장 코드', cls: 'small' });
}
function importSheet() {
  sheet((b, close) => {
    const ta = h('textarea.code', { placeholder: 'SV1: 로 시작하는 코드를 붙여 넣어요' });
    b.append(ta, h('div', { style: { height: '8px' } }), btn('불러오기', () => {
      try { const np = P.importSave(ta.value); App.p = np; saveNow(); toast('불러왔어요', { icon: 'check' }); close(); go(hubScreen, 'home'); }
      catch (e) { sfx('error'); toast(e.message || '코드를 읽을 수 없어요', { icon: 'close' }); }
    }, { cls: 'wide' }));
  }, { title: '코드로 불러오기', cls: 'small' });
}

// ───────── 일일 임무 ─────────
export function missionsSheet(onDone) {
  const p = App.p;
  sheet((b) => {
    const draw = () => {
      b.innerHTML = '';
      const d = P.ensureDaily(p);
      b.appendChild(h('div.t13.muted', { style: { marginBottom: '10px' }, text: `임무는 매일 자정에 바뀌어요. 하나에 별조각 ${P.MISSION_REWARD.shards}, 달가루 ${P.MISSION_REWARD.dust}` }));
      d.missions.forEach((m, i) => {
        const def = P.MISSION_DEFS[m.id];
        const done = m.prog >= m.n;
        b.appendChild(h('div.item.mission', h('div.ico', { html: icon(m.claimed ? 'check' : 'star'), style: { color: m.claimed ? 'var(--good)' : 'var(--gold)' } }),
          h('div.grow', h('div.tt', { text: def.name(m.n) }), h('div.prog', h('i', { style: { width: `${(m.prog / m.n) * 100}%` } })), h('div.t12.dim', { style: { marginTop: '3px' }, text: `${m.prog} / ${m.n}` })),
          m.claimed ? h('span.t12.good', { text: '완료' }) : btn('받기', () => { if (P.claimMission(p, i)) { sfx('gold'); refreshRes(); saveSoon(); checkAch(); draw(); } }, { cls: 'small', disabled: !done })));
      });
      const all = d.missions.every((m) => m.claimed);
      b.appendChild(h('div.card', { style: { marginTop: '10px' } }, h('div.row.gap2', h('div.grow', h('div.b', { text: '모두 완료 보너스' }), h('div.t12.muted', { text: '별조각 40, 별사탕 1개' })),
        d.bonus ? h('span.t12.good', { text: '받음' }) : btn('받기', () => { if (P.claimDailyBonus(p)) { sfx('level'); refreshRes(); saveSoon(); checkAch(); draw(); } }, { cls: 'small pink', disabled: !all }))));
    };
    draw();
  }, { title: '오늘의 임무', onClose: onDone });
}

// ───────── 업적 ─────────
export function achievementsScreen(el) {
  const p = App.p;
  App.onBack = () => { go(hubScreen, 'home'); return true; };
  const got = ACHIEVEMENTS.filter((a) => p.ach[a.id]).length;
  el.append(h('div.page-head', h('button.icon-btn', { type: 'button', html: icon('back'), onclick: () => go(hubScreen, 'home') }), h('div.ttl', { text: '업적' }), h('span.pill', { text: `${got} / ${ACHIEVEMENTS.length}` })));
  const list = h('div.scroll.grow.list-pad');
  const sorted = ACHIEVEMENTS.slice().sort((a, b) => (p.ach[b.id] ? 0 : 1) - (p.ach[a.id] ? 0 : 1));
  for (const a of sorted) {
    const ok = !!p.ach[a.id];
    list.appendChild(h('div.item' + (ok ? '' : '.locked'), h('div.ico', { html: icon(ok ? 'trophy' : 'lock'), style: { color: ok ? 'var(--gold)' : 'var(--dim)' } }),
      h('div.grow', h('div.tt', { text: a.name }), h('div.ds', { text: a.desc })), h('span.pill.t12', ic('shard'), String(a.r))));
  }
  el.appendChild(list);
}

// ───────── 도감 ─────────
export function codexScreen(el, tab = 'skill') {
  const p = App.p;
  App.onBack = () => { go(hubScreen, 'home'); return true; };
  const tabs = [['skill', '기술'], ['relic', '유물'], ['enemy', '적'], ['fish', '물고기'], ['recipe', '요리']];
  const seg = h('div.seg');
  for (const [k, n] of tabs) seg.appendChild(h('button' + (k === tab ? '.on' : ''), { type: 'button', onclick: () => go(codexScreen, k) }, n));
  const grid = h('div.codex-grid');
  let have = 0, total = 0;
  const cell = (known, art, name, onclick) => { const c = h('button.cx' + (known ? '' : '.unk'), { type: 'button', onclick: known ? onclick : () => toast('아직 발견하지 못했어요', { icon: 'lock', ms: 1200 }) }); c.innerHTML = art + `<span class="cn">${known ? name : '???'}</span>`; return c; };
  if (tab === 'skill') {
    for (const s of SKILLS) { total++; const k = !!p.codex.skills[s.id] || !!s.start; if (k) have++; grid.appendChild(cell(k, `<span class="rar-${s.rar}">${icon(s.icon)}</span>`, s.name, () => skillInfo(s))); }
  } else if (tab === 'relic') {
    for (const r of RELICS) { total++; const k = !!p.codex.relics[r.id]; if (k) have++; grid.appendChild(cell(k, `<span class="rar-${r.rar}">${icon(r.icon)}</span>`, r.name, () => sheet((b) => { b.innerHTML = `<span class="tag bg-${r.rar}">${rarName(r.rar)}</span>${r.cls ? ` <span class="tag bg-s">${CLASS_BY_ID[r.cls].name} 전용</span>` : ''}<p style="line-height:1.6">${r.desc}</p>`; }, { title: r.name, cls: 'small' }))); }
  } else if (tab === 'enemy') {
    for (const e of ENEMIES) { total++; const k = !!p.codex.enemies[e.id]; if (k) have++; grid.appendChild(cell(k, monsterSVG(e.art), e.name, () => sheet((b) => { b.innerHTML = `<div style="width:140px;margin:0 auto">${monsterSVG(e.art)}</div><p class="muted" style="text-align:center">${e.title ? e.title + ' · ' : ''}${{ normal: '일반', elite: '엘리트', boss: '보스' }[e.kind]} · ${e.act}구역 · 체력 ${Array.isArray(e.hp) ? e.hp.join('~') : e.hp}</p>${e.intro ? `<p style="line-height:1.6;text-align:center">“${e.intro}”</p>` : ''}`; }, { title: e.name, cls: 'small' }))); }
  } else if (tab === 'fish') {
    for (const f of FISH) { total++; const k = !!p.codex.fish[f.id]; if (k) have++; grid.appendChild(cell(k, `<div style="width:80%">${fishSVG(f.color)}</div>`, f.name, () => sheet((b) => { b.innerHTML = `<div style="width:160px;margin:0 auto">${fishSVG(f.color)}</div><p class="muted" style="text-align:center"><span class="rar-${f.rar}">${SKILL_RAR[f.rar]}</span> · 달가루 ${f.dust}</p>`; }, { title: f.name, cls: 'small' }))); }
  } else {
    for (const r of RECIPES) { total++; const k = !!p.codex.recipes[r.id]; if (k) have++; grid.appendChild(cell(k, icon('pot'), r.name, () => sheet((b) => { b.innerHTML = `<p class="muted">${r.steps.map((s) => INGREDIENTS.find((x) => x.id === s).name).join(' → ')}</p><p class="good">${r.buffText}</p>`; }, { title: r.name, cls: 'small' }))); }
  }
  el.append(h('div.page-head', h('button.icon-btn', { type: 'button', html: icon('back'), onclick: () => go(hubScreen, 'home') }), h('div.ttl', { text: '도감' }), h('span.pill', { text: `${have} / ${total}` })), seg, h('div.scroll.grow', grid));
}
function skillInfo(s) {
  sheet((b) => {
    const base = resolveSkill(s.id, false), up = resolveSkill(s.id, true);
    b.innerHTML = `<div class="row gap"><span class="tag bg-${s.rar}">${SKILL_RAR[s.rar]}</span><span class="tag bg-c">${s.cls === 'any' ? '공용' : CLASS_BY_ID[s.cls].name}</span>${s.lock ? `<span class="tag bg-c">직업 Lv.${s.lock}</span>` : ''}</div>
      <p style="line-height:1.6"><b class="gold">${reqText(base)}</b> · ${skillDesc(base)}</p><p style="line-height:1.6" class="good">강화: <b>${reqText(up)}</b> · ${skillDesc(up)}</p>`;
  }, { title: s.name, cls: 'small' });
}

// ───────── 선물 상점 ─────────
export function giftShopSheet() {
  const p = App.p;
  sheet((b) => {
    const draw = () => {
      b.innerHTML = '';
      b.appendChild(h('div.row.between', { style: { marginBottom: '10px' } }, h('span.t13.muted', { text: '달가루로 선물을 살 수 있어요' }), h('span.pill', ic('dust'), h('span.gold', { text: fmt(p.dust) }))));
      for (const g of GIFTS) {
        if (!g.price) continue;
        const own = p.inv.gifts[g.id] || 0;
        b.appendChild(h('div.item', h('div.ico', { html: icon('gift'), style: { color: g.color } }), h('div.grow', h('div.tt', { text: g.name }), h('div.ds', { text: `${g.desc} · 보유 ${own}` })),
          btn(fmt(g.price), () => { if (p.dust < g.price) { sfx('error'); toast('달가루가 부족해요', { icon: 'dust' }); return; } p.dust -= g.price; P.addGift(p, g.id, 1); sfx('buy'); refreshRes(); saveSoon(); draw(); }, { cls: 'small', icon: 'dust', disabled: p.dust < g.price })));
      }
    };
    draw();
  }, { title: '선물 상점' });
}
