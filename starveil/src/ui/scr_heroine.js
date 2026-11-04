// 동료 탭 — 대화·선물·쓰다듬기·추억·의상·함께 놀기
import { h, btn, ic, sheet, toast } from './dom.js';
import { App, go, saveSoon, resBar, refreshRes, checkAch, bgm, levelUpFx } from './app.js';
import { icon } from '../art/icons.js';
import { heroineSVG } from '../art/heroines.js';
import { sceneSVG } from '../art/scenes.js';
import * as P from '../core/profile.js';
import { HEROINES } from '../data/heroines/index.js';
import { HEROINE_META, HEROINE_IDS, AFF_TABLE, AFF_MAX_LV, DAILY, tierOf } from '../data/heroine_meta.js';
import { GIFTS, GIFT_BY_ID } from '../data/gifts.js';
import { companionAssist, COMPANIONS } from '../data/companions.js';
import { playVN } from './vn.js';
import { hubScreen } from './scr_hub.js';
import { settingsSheet, giftShopSheet } from './scr_misc.js';
import { startMini } from './scr_mini.js';
import { sfx } from '../audio/audio.js';
import { fmt } from '../core/util.js';

const SCENE_BG = { lyra: 'camp', mio: 'market', seren: 'library' };

export function heroineTab(body, arg) {
  bgm('camp');
  const p = App.p;
  let id = (arg && arg.id) || p.lastHeroineTab || 'lyra';
  if (!P.heroineUnlocked(p, id)) id = 'lyra';
  p.lastHeroineTab = id;
  const d = HEROINES[id];
  const meta = HEROINE_META[id];
  const hs = P.heroineState(p, id);
  const tabs = h('div.hero-tabs');
  for (const hid of HEROINE_IDS) {
    const ok = P.heroineUnlocked(p, hid);
    const t = h('button.hero-tab' + (hid === id ? '.on' : ''), { type: 'button', onclick: () => { if (!ok) { toast(HEROINE_META[hid].unlock.text, { icon: 'lock' }); return; } go(hubScreen, 'heroine', { id: hid }); } },
      ok ? HEROINES[hid].name : '???');
    if (ok && P.pendingScenes(p, hid).length) { t.style.position = 'relative'; t.appendChild(h('i.badge-dot')); }
    tabs.appendChild(t);
  }
  const stage = h('div.hero-stage');
  stage.innerHTML = sceneSVG(SCENE_BG[id]);
  const hw = h('div.heroine-wrap.breathe');
  let expr = 'smile';
  const draw = (e) => { expr = e || expr; hw.innerHTML = heroineSVG(id, { e: expr, outfit: hs.outfit }); };
  draw('smile');
  stage.appendChild(hw);
  // 호감도 카드
  const aff = h('div.aff-card');
  const drawAff = () => {
    const lv = hs.lv;
    const cur = AFF_TABLE[lv], nx = lv < AFF_MAX_LV ? AFF_TABLE[lv + 1] : null;
    aff.innerHTML = '';
    const hearts = h('div.hearts');
    for (let i = 1; i <= 10; i++) hearts.appendChild(h('span' + (i <= lv ? '' : '.off'), { html: icon('heart') }));
    aff.append(h('div.nm', { text: d.name, style: { color: meta.color } }), h('div.ti', { text: d.title }), hearts,
      nx ? h('div', h('div.prog.pink', h('i', { style: { width: `${Math.min(100, ((hs.aff - cur) / (nx - cur)) * 100)}%` } })), h('div.t12.dim', { style: { marginTop: '3px' }, text: `호감도 ${hs.aff - cur} / ${nx - cur}` })) : h('div.t12.pinkc', { text: '최고 호감도' }));
  };
  drawAff();
  stage.appendChild(aff);
  let bub = null;
  const say = (line, ms = 3800) => {
    if (bub) bub.remove();
    bub = h('div.bubble.side', { style: { top: '14px' } }, h('span.who', { text: d.name }), line.t.replace('{item}', ''));
    stage.appendChild(bub);
    draw(line.e);
    clearTimeout(say.t);
    say.t = setTimeout(() => { if (bub) { bub.remove(); bub = null; } draw('smile'); }, ms);
  };
  const afterAff = (res, label) => {
    if (!res) return;
    if (res.aff) { const pop = h('div.aff-pop', { text: `${res.aff > 0 ? '♥ +' : '♥ '}${res.aff}` }); document.body.appendChild(pop); setTimeout(() => pop.remove(), 1300); }
    if (res.ups && res.ups.length) {
      const lv = res.ups[res.ups.length - 1];
      setTimeout(() => levelUpFx(`<div class="big">${d.name} 호감도 ${lv}</div><div class="t13 muted">새 이야기 ${josa('「' + d.scenes[lv - 1].title + '」', '이/가')} 열렸어요</div>`), 500);
    }
    drawAff(); saveSoon(); checkAch();
  };
  // 쓰다듬기
  const touch = () => {
    const tier = tierOf(id, hs.lv);
    const line = d.touch[tier][Math.floor(Math.random() * d.touch[tier].length)];
    say(line);
    sfx('heart');
    const res = P.doTouch(p, id);
    if (res) afterAff(res); else toast('오늘은 충분히 쓰다듬었어요', { icon: 'hand', ms: 1400 });
    grid.replaceWith(grid = actions());
  };
  hw.addEventListener('click', (e) => {
    const r = hw.getBoundingClientRect();
    if (e.clientY - r.top < r.height * 0.42) touch();
    else { const tier = tierOf(id, hs.lv); const l = d.greet[tier]; say(l[Math.floor(Math.random() * l.length)]); sfx('page'); }
  });
  const blink = setInterval(() => { const s = hw.querySelector('.heroine'); if (s) { s.classList.add('blinking'); setTimeout(() => s.classList.remove('blinking'), 130); } }, 3200);

  const actions = () => {
    const pend = P.pendingScenes(p, id);
    const g = h('div.act-grid');
    const mk = (icn, label, cnt, fn, dis, dot) => { const b = h('button.act-btn', { type: 'button', disabled: dis ? true : null, onclick: fn }, ic(icn), h('span', { text: label }), cnt ? h('span.cnt', { text: cnt }) : null); if (dot) b.appendChild(h('i.badge-dot')); return b; };
    g.append(
      mk('chat', '대화', `오늘 ${DAILY.talk - hs.talks}회`, () => talk(), hs.talks >= DAILY.talk),
      mk('gift', '선물', `오늘 ${DAILY.gift - hs.gifts}회`, () => giftSheet()),
      mk('hand', '쓰다듬기', `오늘 ${DAILY.touch - hs.touches}회`, () => touch()),
      mk('book', '추억', `${hs.seen.length} / 10`, () => scenesSheet(), false, pend.length > 0),
      mk('star', '의상', `${hs.outfits.length} / ${meta.outfits.length}`, () => outfitSheet()),
      mk('game', '함께 놀기', id === 'lyra' ? '낚시 · 요리' : id === 'mio' ? '하이로우' : '별자리', () => startMini(meta.mini[0], id)),
    );
    return g;
  };
  let grid = actions();
  body.append(h('div.topbar', resBar(), h('button.icon-btn', { type: 'button', onclick: () => profileSheet(), html: icon('info') }), h('button.icon-btn', { type: 'button', onclick: () => settingsSheet(), html: icon('gear') })), tabs, h('div', { style: { height: '8px' } }), stage, grid);
  setTimeout(() => { const tier = tierOf(id, hs.lv); const l = d.greet[tier]; say(l[Math.floor(Math.random() * l.length)]); }, 350);
  if (P.pendingScenes(p, id).length) setTimeout(() => toast(`${d.name}의 새 이야기가 있어요 · 추억`, { icon: 'book', kind: 'pink' }), 900);

  function talk() {
    if (!P.canTalk(p, id)) { toast('오늘은 이야기를 충분히 나눴어요. 내일 또 와요!', { icon: 'chat' }); return; }
    const t = P.pickTalk(p, id, d);
    playVN({ bg: SCENE_BG[id], who: id, lines: t.lines.map((l) => ({ s: id, ...l })), choices: t.choices,
      onChoice: (i) => {
        const res = P.doTalk(p, id, t, i);
        setTimeout(() => afterAff(res), 50);
        return t.choices[i].reply.map((l) => ({ s: id, ...l }));
      },
      onEnd: () => { grid.replaceWith(grid = actions()); draw('smile'); } });
  }
  function giftSheet() {
    sheet((b, close) => {
      const inv = p.inv.gifts;
      const ids = Object.keys(inv).filter((k) => inv[k] > 0);
      b.appendChild(h('div.t13.muted', { style: { marginBottom: '10px' }, html: `하루에 ${DAILY.gift}번 선물할 수 있어요. ${d.likes}` }));
      if (!ids.length) b.appendChild(h('div.empty', { text: '가진 선물이 없어요. 상점이나 원정에서 구해 보세요.' }));
      for (const gid of ids) {
        const g = GIFT_BY_ID[gid];
        const known = hs.knownGifts && hs.knownGifts[gid];
        b.appendChild(h('button.reward-row', { type: 'button', disabled: !P.canGift(p, id) ? true : null, onclick: () => {
          const res = P.doGift(p, id, d, gid);
          if (!res) { toast('오늘은 이미 선물했어요', { icon: 'gift' }); return; }
          hs.knownGifts = hs.knownGifts || {}; hs.knownGifts[gid] = res.kind;
          close();
          const ls = d.giftLines[res.kind];
          const line = ls[Math.floor(Math.random() * ls.length)];
          say({ e: line.e, t: line.t.replace('{item}', g.name) }, 4500);
          sfx(res.kind === 'dislike' ? 'error' : 'heart');
          afterAff(res);
          grid.replaceWith(grid = actions());
        } }, h('div.ico', { html: icon('gift'), style: { color: g.color } }), h('div.grow', h('div.b', { text: `${g.name} ×${inv[gid]}` }), h('div.t12.muted', { text: g.desc })),
          known ? h('span.tag', { text: { love: '아주 좋아함', like: '좋아함', neutral: '보통', dislike: '싫어함' }[known], style: { color: known === 'love' ? 'var(--pink)' : known === 'dislike' ? 'var(--bad)' : 'var(--sub)' } }) : null));
      }
      b.appendChild(h('div', { style: { height: '10px' } }));
      b.appendChild(btn('선물 상점 가기', () => { close(); giftShopSheet(); }, { cls: 'ghost wide', icon: 'shop' }));
    }, { title: `${d.name}에게 선물하기` });
  }
  function scenesSheet() {
    sheet((b, close) => {
      d.scenes.forEach((sc, i) => {
        const lv = i + 1;
        const open = hs.lv >= lv;
        const seen = hs.seen.includes(lv);
        b.appendChild(h('button.reward-row' + (open ? '' : '.claimed'), { type: 'button', style: open ? null : { opacity: '.45' }, onclick: () => {
          if (!open) return;
          close();
          playVN({ bg: sc.bg, who: id, title: `${d.name} · ${lv}장 ${sc.title}`, lines: sc.lines, onEnd: () => {
            if (!hs.seen.includes(lv)) {
              hs.seen.push(lv);
              const reward = 60 * lv;
              p.dust += reward;
              toast(`추억을 간직했어요 · 달가루 +${reward}`, { icon: 'book', kind: 'pink' });
              refreshRes(); saveSoon(); checkAch();
            }
            grid.replaceWith(grid = actions());
          } });
        } }, h('div.ico', { html: icon(open ? 'book' : 'lock'), style: { color: open ? meta.color : 'var(--dim)' } }),
          h('div.grow', h('div.b', { text: open ? `${lv}장 · ${sc.title}` : `${lv}장 · 호감도 ${lv}에 열려요` }), h('div.t12.muted', { text: open ? (seen ? '다시 보기' : '새 이야기') : '???' })),
          open && !seen ? h('span.tag.bg-l', { text: 'NEW' }) : null));
      });
    }, { title: `${josa(d.name, '와/과')}의 추억` });
  }
  function outfitSheet() {
    sheet((b, close) => {
      const grid2 = h('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' } });
      for (const o of meta.outfits) {
        const has = hs.outfits.includes(o.id);
        const cell = h('button.cls-card' + (hs.outfit === o.id ? '.on' : '') + (has ? '' : '.locked'), { type: 'button', style: { padding: '6px', textAlign: 'center' }, onclick: () => {
          if (has) { hs.outfit = o.id; saveSoon(); close(); draw('happy'); say({ e: 'happy', t: d.greet[tierOf(id, hs.lv)][0].t }); return; }
          if (o.price) {
            if (p.dust < o.price) { sfx('error'); toast('달가루가 부족해요', { icon: 'dust' }); return; }
            p.dust -= o.price; hs.outfits.push(o.id); hs.outfit = o.id; sfx('buy'); refreshRes(); saveSoon(); checkAch(); close(); draw('happy');
            return;
          }
          toast(`호감도 ${o.lv}에 열려요`, { icon: 'lock' });
        } });
        cell.innerHTML = `<div style="height:150px">${heroineSVG(id, { e: 'smile', outfit: o.id })}</div><div class="b t13" style="margin-top:4px">${o.name}</div><div class="t12 ${has ? 'good' : 'dim'}">${has ? (hs.outfit === o.id ? '입는 중' : '보유') : o.price ? `달가루 ${fmt(o.price)}` : `호감도 ${o.lv}`}</div>`;
        grid2.appendChild(cell);
      }
      b.appendChild(grid2);
    }, { title: '의상' });
  }
  function profileSheet() {
    const a = companionAssist(id, hs.lv);
    sheet((b) => {
      b.append(h('p', { style: { lineHeight: '1.7', marginTop: '0' }, text: d.profile }), h('div.t13.muted', { text: d.likes }), h('div.sep'),
        h('div.b', { text: '원정 동행 효과' }), h('div.t13', { style: { lineHeight: '1.6', marginTop: '4px' }, html: `<b class="pinkc">${a.name}</b> · 기술 ${a.max}번 사용 시 충전<br>${a.desc}<br><span class="dim">${COMPANIONS[id].passive}</span>` }),
        h('div.t12.dim', { style: { marginTop: '8px' }, text: '호감도가 오를수록 지원 기술이 강해져요.' }));
    }, { title: d.name, cls: 'small' });
  }
  return () => { clearInterval(blink); clearTimeout(say.t); };
}
