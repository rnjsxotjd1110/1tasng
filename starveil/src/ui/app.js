// 앱 코어: 화면 전환·저장·전역 효과음·별 배경·업적 알림
import { h, toast, topSheetClose, closeAllSheets, countTo, numEl, ic } from './dom.js';
import { loadProfile, saveProfile, checkAchievements, ensureDaily } from '../core/profile.js';
import { sfx, unlockAudio, setVolumes, playBgm } from '../audio/audio.js';
import { DIE_DEFS } from '../art/dice.js';
import { fmt } from '../core/util.js';

export const App = {
  p: null,
  root: null,
  cur: null,
  cleanup: null,
  onBack: null,
  resEls: [],
};

export function boot(rootEl) {
  App.root = rootEl;
  App.p = loadProfile();
  ensureDaily(App.p);
  setVolumes(App.p.settings.sfx, App.p.settings.bgm);
  document.body.insertAdjacentHTML('beforeend', DIE_DEFS);
  starfield(rootEl);
  // 첫 터치에서 오디오 잠금 해제
  const unlock = () => { unlockAudio(); window.removeEventListener('pointerdown', unlock, true); };
  window.addEventListener('pointerdown', unlock, true);
  // 모든 버튼 클릭음(4상태는 CSS)
  document.addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (b && !b.disabled && !b.dataset.silent) sfx(b.classList.contains('tab') ? 'tab' : 'click');
  }, true);
  document.addEventListener('pointerover', (e) => {
    if (e.pointerType !== 'mouse') return;
    const b = e.target.closest('button');
    if (b && !b.disabled && b !== App._hov) { App._hov = b; sfx('hover'); }
  });
  // 안드로이드 뒤로 가기(웹뷰에서 호출) + 브라우저 Esc
  window.__starveilBack = () => {
    if (topSheetClose()) return true;
    if (App.onBack) return !!App.onBack();
    return false;
  };
  window.addEventListener('keydown', (e) => { if (e.key === 'Escape') window.__starveilBack(); });
  // 주기적 저장·플레이 시간
  setInterval(() => { App.p.stats.playMs += 10000; saveNow(); }, 10000);
  document.addEventListener('visibilitychange', () => { if (document.hidden) saveNow(); });
  window.addEventListener('pagehide', saveNow);
}

export function go(screenFn, ...args) {
  closeAllSheets();
  if (App.cleanup) { try { App.cleanup(); } catch (e) { /* 정리 오류 무시 */ } }
  App.cleanup = null;
  App.onBack = null;
  App.resEls = [];
  const old = App.cur;
  const el = h('div.screen');
  App.root.appendChild(el);
  App.cur = el;
  if (old) { old.classList.add('leaving'); setTimeout(() => old.remove(), 170); }
  const c = screenFn(el, ...args);
  if (typeof c === 'function') App.cleanup = c;
  return el;
}

let saveTimer = null;
export function saveSoon() { clearTimeout(saveTimer); saveTimer = setTimeout(saveNow, 250); }
export function saveNow() { clearTimeout(saveTimer); if (App.p) saveProfile(App.p); }

// 재화 표시(카운트업)
export function resBar(which = ['dust', 'shards']) {
  const wrap = h('div.res');
  for (const k of which) {
    const n = numEl(App.p[k]);
    n.dataset.k = k;
    App.resEls.push(n);
    wrap.appendChild(h('span.pill', ic(k === 'dust' ? 'dust' : 'shard', k === 'dust' ? 'dustc' : 'shardc'), n));
  }
  return wrap;
}
export function refreshRes() { for (const n of App.resEls) if (n.isConnected) countTo(n, App.p[n.dataset.k]); }

export function checkAch() {
  const got = checkAchievements(App.p);
  for (const a of got) { toast(`업적 달성 · <b>${a.name}</b> <span class="gold">+${a.r}</span>`, { icon: 'trophy', ms: 3000 }); sfx('level'); }
  if (got.length) { refreshRes(); saveSoon(); }
  return got;
}

export function bgm(name) { if (App.p.settings.bgm > 0) playBgm(name); }

// ───────── 별 배경 ─────────
function starfield(root) {
  const cv = h('canvas#stars');
  root.appendChild(cv);
  const g = cv.getContext('2d');
  let W = 0, H = 0, stars = [];
  const resize = () => {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    W = root.clientWidth; H = root.clientHeight;
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    stars = [];
    const n = Math.round((W * H) / 5200);
    for (let i = 0; i < n; i++) stars.push({ x: Math.random() * W, y: Math.random() * H, r: Math.random() * 1.3 + 0.3, p: Math.random() * Math.PI * 2, s: 0.6 + Math.random() * 1.4 });
  };
  resize();
  window.addEventListener('resize', resize);
  let last = 0;
  const draw = (t) => {
    requestAnimationFrame(draw);
    if (t - last < 50 || document.hidden) return;
    last = t;
    const grd = g.createLinearGradient(0, 0, 0, H);
    grd.addColorStop(0, '#080a24'); grd.addColorStop(0.6, '#15174a'); grd.addColorStop(1, '#241c55');
    g.fillStyle = grd; g.fillRect(0, 0, W, H);
    for (const s of stars) {
      const a = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t / 1000 * s.s + s.p));
      g.globalAlpha = a; g.fillStyle = '#fff';
      g.beginPath(); g.arc(s.x, s.y, s.r, 0, Math.PI * 2); g.fill();
    }
    g.globalAlpha = 1;
  };
  requestAnimationFrame(draw);
}

export function levelUpFx(html) {
  const el = h('div.level-up', h('div.lu', { html }));
  document.body.appendChild(el);
  sfx('level');
  setTimeout(() => el.remove(), 1900);
}
export { fmt };
