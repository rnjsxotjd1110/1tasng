// 캔버스 이펙트 엔진 — 파티클·궤적·발사체·충격파·화면 번쩍임·환경 파티클
// 화면 전체를 덮는 투명 캔버스 하나. 할 일이 없으면 렌더링을 멈춰요.
let cv = null, g = null, W = 0, H = 0, dpr = 1;
let parts = [], fxs = [], ambient = null, raf = 0, last = 0;
let quality = 1; // 1 = 높음, 0.5 = 낮음
const TAU = Math.PI * 2;
const rnd = (a, b) => a + Math.random() * (b - a);

export const ELEMENT_COLOR = {
  phys: ['#ffffff', '#ffe7b0'], fire: ['#ffb347', '#ff5a2a'], frost: ['#d8f4ff', '#6fc8ff'], poison: ['#c8ff8a', '#5fd04a'],
  bolt: ['#fff7a8', '#ffd23a'], arcane: ['#f0d8ff', '#b27bff'], holy: ['#fff6d0', '#ffd98a'], heal: ['#c8ffd8', '#6fe89a'],
  gold: ['#fff0a0', '#ffc23a'], shield: ['#dff0ff', '#7ab8ff'], dark: ['#d8b8ff', '#6a3fd0'], blood: ['#ffb0b8', '#ff4a6a'], pink: ['#ffd6ef', '#ff7ac0'],
};

export function initFx(root) {
  if (cv) return;
  cv = document.createElement('canvas');
  cv.id = 'fx';
  cv.style.cssText = 'position:fixed;left:0;top:0;width:100%;height:100%;pointer-events:none;z-index:45';
  document.body.appendChild(cv);
  g = cv.getContext('2d');
  const resize = () => {
    dpr = Math.min(2, window.devicePixelRatio || 1) * (quality < 1 ? 0.75 : 1);
    W = window.innerWidth; H = window.innerHeight;
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  resize();
  window.addEventListener('resize', resize);
  initFx._resize = resize;
}
export function setFxQuality(q) { quality = q; if (initFx._resize) initFx._resize(); }
export function fxQuality() { return quality; }

function kick() { if (!raf) { last = performance.now(); raf = requestAnimationFrame(loop); } }

// ───────── 파티클 ─────────
// shape: spark(선) circle star shard ring smoke heart coin
export function burst(x, y, o = {}) {
  if (!g) return;
  const n = Math.round((o.n || 14) * quality);
  const cols = o.colors || ELEMENT_COLOR[o.el || 'phys'];
  for (let i = 0; i < n; i++) {
    const a = o.angle !== undefined ? o.angle + rnd(-(o.spread || 0.6), o.spread || 0.6) : rnd(0, TAU);
    const sp = rnd(o.speed ? o.speed * 0.5 : 80, o.speed || 260);
    parts.push({
      x: x + rnd(-(o.jitter || 4), o.jitter || 4), y: y + rnd(-(o.jitter || 4), o.jitter || 4),
      vx: Math.cos(a) * sp, vy: Math.sin(a) * sp + (o.vy || 0),
      life: 0, max: rnd(o.life ? o.life * 0.6 : 0.35, o.life || 0.7),
      size: rnd((o.size || 4) * 0.5, o.size || 4), color: cols[i % cols.length],
      shape: o.shape || 'spark', g: o.gravity ?? 260, drag: o.drag ?? 2.2, rot: rnd(0, TAU), vr: rnd(-8, 8), add: o.add !== false,
    });
  }
  kick();
}
// 위로 피어오르는 입자(화상 불씨, 독 거품, 회복 반짝이)
export function rise(x, y, o = {}) {
  burst(x, y, { n: o.n || 12, colors: o.colors || ELEMENT_COLOR[o.el || 'heal'], shape: o.shape || 'circle', angle: -Math.PI / 2, spread: 0.9, speed: o.speed || 120, gravity: o.gravity ?? -60, drag: 1.2, life: o.life || 1.1, size: o.size || 4, jitter: o.jitter || 24 });
}
// 베기 궤적
export function slash(x, y, o = {}) {
  if (!g) return;
  const a = o.angle ?? rnd(-0.9, -0.5);
  fxs.push({ t: 'slash', x, y, a, r: o.r || 46, life: 0, max: 0.26, cols: o.colors || ELEMENT_COLOR[o.el || 'phys'], w: o.w || 9 });
  kick();
}
// 충격파 고리
export function ring(x, y, o = {}) {
  if (!g) return;
  fxs.push({ t: 'ring', x, y, r0: o.r0 || 8, r1: o.r || 70, life: 0, max: o.life || 0.42, col: (o.colors || ELEMENT_COLOR[o.el || 'phys'])[1], w: o.w || 5 });
  kick();
}
// 화면 번쩍임
export function flash(color = '#ffffff', alpha = 0.25, dur = 0.18) {
  if (!g || quality < 1 && alpha > 0.2) alpha *= 0.6;
  fxs.push({ t: 'flash', color, alpha, life: 0, max: dur });
  kick();
}
// 발사체: from → to, 끝나면 resolve
export function projectile(from, to, o = {}) {
  return new Promise((res) => {
    if (!g) { res(); return; }
    const dur = o.dur || 0.24;
    fxs.push({ t: 'proj', x0: from.x, y0: from.y, x1: to.x, y1: to.y, arc: o.arc ?? -60, life: 0, max: dur, cols: o.colors || ELEMENT_COLOR[o.el || 'phys'], size: o.size || 7, done: res, trail: [] });
    kick();
  });
}
// 빛줄기(위에서 내려오는 기둥)
export function pillar(x, y, o = {}) {
  if (!g) return;
  fxs.push({ t: 'pillar', x, y, w: o.w || 46, life: 0, max: o.life || 0.5, cols: o.colors || ELEMENT_COLOR[o.el || 'holy'] });
  kick();
}
// 금화가 날아가요
export function coins(from, to, n = 6) {
  for (let i = 0; i < Math.min(12, n); i++) {
    setTimeout(() => projectile({ x: from.x + rnd(-14, 14), y: from.y + rnd(-10, 10) }, to, { el: 'gold', size: 5, dur: rnd(0.35, 0.5), arc: rnd(-120, -40) }).then(() => burst(to.x, to.y, { el: 'gold', n: 3, size: 2.5, speed: 90, life: 0.3 })), i * 45);
  }
}

// ───────── 환경 파티클 ─────────
// type: fireflies, sparkles, bubbles, motes, embers, snow, petals
export function setAmbient(type, opt = {}) {
  ambient = type ? { type, list: [], area: opt.area || null, n: Math.round((opt.n || 26) * quality), color: opt.color } : null;
  if (ambient) kick();
}
function spawnAmb(a, init) {
  const ar = a.area ? a.area() : { x: 0, y: 0, w: W, h: H };
  const t = a.type;
  const p = { x: ar.x + Math.random() * ar.w, y: init ? ar.y + Math.random() * ar.h : (t === 'bubbles' || t === 'embers' || t === 'motes' ? ar.y + ar.h + 6 : t === 'snow' || t === 'petals' ? ar.y - 6 : ar.y + Math.random() * ar.h), ph: Math.random() * TAU, life: 0, max: rnd(5, 11) };
  if (t === 'fireflies') { p.vx = rnd(-12, 12); p.vy = rnd(-10, 10); p.size = rnd(1.4, 2.6); p.c = a.color || '#e8ff9a'; }
  else if (t === 'sparkles') { p.vx = 0; p.vy = rnd(-4, 4); p.size = rnd(1.5, 3.2); p.c = a.color || '#bff4ff'; p.max = rnd(1.6, 3.4); }
  else if (t === 'bubbles') { p.vx = rnd(-4, 4); p.vy = rnd(-34, -18); p.size = rnd(1.6, 4); p.c = a.color || '#bfe8ff'; }
  else if (t === 'motes') { p.vx = rnd(-6, 6); p.vy = rnd(-16, -6); p.size = rnd(1, 2.4); p.c = a.color || '#e6d6ff'; }
  else if (t === 'embers') { p.vx = rnd(-8, 8); p.vy = rnd(-40, -20); p.size = rnd(1.2, 2.4); p.c = a.color || '#ffb34c'; p.max = rnd(2, 4); }
  else if (t === 'snow') { p.vx = rnd(-8, 8); p.vy = rnd(14, 30); p.size = rnd(1.2, 2.8); p.c = a.color || '#ffffff'; }
  else if (t === 'shoot') { p.x = ar.x + Math.random() * ar.w * 0.8; p.y = ar.y + Math.random() * ar.h * 0.4; p.vx = rnd(260, 380); p.vy = rnd(120, 200); p.size = rnd(1.2, 2); p.c = a.color || '#ffffff'; p.max = rnd(0.6, 0.9); p.wait = rnd(0.5, 4); }
  else if (t === 'petals') { p.vx = rnd(10, 26); p.vy = rnd(16, 30); p.size = rnd(2.5, 4); p.c = a.color || '#ffc2e0'; p.rot = rnd(0, TAU); }
  return p;
}

// ───────── 렌더 ─────────
let skip = false;
function loop(t) {
  // 환경 파티클만 있으면 30fps로 그려 배터리를 아껴요
  if (!parts.length && !fxs.length) { skip = !skip; if (skip) { raf = requestAnimationFrame(loop); return; } }
  const dt = Math.min(0.05, (t - last) / 1000);
  last = t;
  g.clearRect(0, 0, W, H);
  // 환경
  if (ambient && !document.hidden) {
    const a = ambient;
    while (a.list.length < a.n) a.list.push(spawnAmb(a, a.type !== 'shoot' && !a.started));
    a.started = true;
    g.globalCompositeOperation = 'lighter';
    for (let i = a.list.length - 1; i >= 0; i--) {
      const p = a.list[i];
      if (p.wait > 0) { p.wait -= dt; continue; }
      p.life += dt; p.ph += dt * 2;
      p.x += (p.vx + Math.sin(p.ph) * (a.type === 'fireflies' ? 8 : 4)) * dt; p.y += p.vy * dt;
      const k = p.life / p.max;
      let al = Math.sin(Math.min(1, k) * Math.PI);
      if (a.type === 'sparkles') al = Math.pow(al, 3);
      if (a.type === 'fireflies') al *= 0.6 + 0.4 * Math.sin(p.ph * 2.2);
      if (k >= 1 || p.y < -20 || p.y > H + 20) { a.list.splice(i, 1); continue; }
      g.globalAlpha = Math.max(0, al) * 0.85;
      if (a.type === 'shoot') { const grd = g.createLinearGradient(p.x, p.y, p.x - p.vx * 0.18, p.y - p.vy * 0.18); grd.addColorStop(0, p.c); grd.addColorStop(1, 'rgba(255,255,255,0)'); g.strokeStyle = grd; g.lineWidth = p.size; g.lineCap = 'round'; g.beginPath(); g.moveTo(p.x, p.y); g.lineTo(p.x - p.vx * 0.18, p.y - p.vy * 0.18); g.stroke(); glowDot(p.x, p.y, p.size * 1.4, p.c, 3); }
      else if (a.type === 'sparkles') drawStar(p.x, p.y, p.size * 2.2, p.c, p.ph);
      else if (a.type === 'petals') { g.fillStyle = p.c; g.save(); g.translate(p.x, p.y); g.rotate(p.ph); g.beginPath(); g.ellipse(0, 0, p.size, p.size * 0.55, 0, 0, TAU); g.fill(); g.restore(); }
      else glowDot(p.x, p.y, p.size, p.c, a.type === 'bubbles' ? 2 : 4);
    }
  }
  // 효과
  for (let i = fxs.length - 1; i >= 0; i--) {
    const f = fxs[i];
    f.life += dt;
    const k = Math.min(1, f.life / f.max);
    g.globalCompositeOperation = f.t === 'flash' ? 'source-over' : 'lighter';
    if (f.t === 'slash') {
      const e = 1 - Math.pow(1 - k, 3);
      g.save(); g.translate(f.x, f.y); g.rotate(f.a);
      g.globalAlpha = 1 - k;
      const grd = g.createLinearGradient(-f.r, 0, f.r, 0);
      grd.addColorStop(0, 'rgba(255,255,255,0)'); grd.addColorStop(0.5, f.cols[0]); grd.addColorStop(1, f.cols[1]);
      g.strokeStyle = grd; g.lineCap = 'round';
      g.lineWidth = f.w * (1 - k * 0.7);
      g.beginPath(); g.arc(0, f.r * 0.9, f.r, -Math.PI / 2 - 1.1 * e, -Math.PI / 2 + 1.1 * e); g.stroke();
      g.lineWidth = f.w * 0.35; g.strokeStyle = '#ffffff';
      g.beginPath(); g.arc(0, f.r * 0.9, f.r, -Math.PI / 2 - 1.0 * e, -Math.PI / 2 + 1.0 * e); g.stroke();
      g.restore();
    } else if (f.t === 'ring') {
      const e = 1 - Math.pow(1 - k, 2);
      g.globalAlpha = (1 - k) * 0.9;
      g.strokeStyle = f.col; g.lineWidth = f.w * (1 - k) + 1;
      g.beginPath(); g.arc(f.x, f.y, f.r0 + (f.r1 - f.r0) * e, 0, TAU); g.stroke();
    } else if (f.t === 'flash') {
      g.globalAlpha = f.alpha * (1 - k);
      g.fillStyle = f.color; g.fillRect(0, 0, W, H);
    } else if (f.t === 'pillar') {
      const al = Math.sin(k * Math.PI);
      const grd = g.createLinearGradient(f.x - f.w, 0, f.x + f.w, 0);
      grd.addColorStop(0, 'rgba(0,0,0,0)'); grd.addColorStop(0.5, f.cols[1]); grd.addColorStop(1, 'rgba(0,0,0,0)');
      g.globalAlpha = al * 0.7; g.fillStyle = grd; g.fillRect(f.x - f.w, 0, f.w * 2, f.y);
      g.globalAlpha = al; glowDot(f.x, f.y, f.w * 0.5 * al + 2, f.cols[0], 2);
    } else if (f.t === 'proj') {
      const e = k < 1 ? k * k * (3 - 2 * k) : 1;
      const x = f.x0 + (f.x1 - f.x0) * e, y = f.y0 + (f.y1 - f.y0) * e + Math.sin(e * Math.PI) * f.arc;
      f.trail.push({ x, y });
      if (f.trail.length > 10) f.trail.shift();
      for (let j = 0; j < f.trail.length; j++) { const q = f.trail[j]; g.globalAlpha = (j / f.trail.length) * 0.6; glowDot(q.x, q.y, f.size * (0.4 + j / f.trail.length * 0.6), f.cols[1], 2.5); }
      g.globalAlpha = 1; glowDot(x, y, f.size, f.cols[0], 3);
      if (k >= 1 && f.done) { const d = f.done; f.done = null; d(); }
    }
    if (k >= 1) fxs.splice(i, 1);
  }
  // 파티클
  for (let i = parts.length - 1; i >= 0; i--) {
    const p = parts[i];
    p.life += dt;
    if (p.life >= p.max) { parts.splice(i, 1); continue; }
    const d = Math.exp(-p.drag * dt);
    p.vx *= d; p.vy = p.vy * d + p.g * dt;
    p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
    const k = p.life / p.max;
    g.globalCompositeOperation = p.add ? 'lighter' : 'source-over';
    g.globalAlpha = 1 - k * k;
    const s = p.size * (1 - k * 0.5);
    if (p.shape === 'spark') {
      g.strokeStyle = p.color; g.lineWidth = s * 0.7; g.lineCap = 'round';
      g.beginPath(); g.moveTo(p.x, p.y); g.lineTo(p.x - p.vx * 0.045, p.y - p.vy * 0.045); g.stroke();
    } else if (p.shape === 'star') drawStar(p.x, p.y, s * 1.8, p.color, p.rot);
    else if (p.shape === 'shard') { g.fillStyle = p.color; g.save(); g.translate(p.x, p.y); g.rotate(p.rot); g.beginPath(); g.moveTo(0, -s * 1.6); g.lineTo(s * 0.6, 0); g.lineTo(0, s * 1.6); g.lineTo(-s * 0.6, 0); g.closePath(); g.fill(); g.restore(); }
    else if (p.shape === 'heart') drawHeart(p.x, p.y, s * 1.4, p.color);
    else if (p.shape === 'smoke') { g.globalCompositeOperation = 'source-over'; g.globalAlpha = (1 - k) * 0.35; g.fillStyle = p.color; g.beginPath(); g.arc(p.x, p.y, s * (1 + k * 2), 0, TAU); g.fill(); }
    else glowDot(p.x, p.y, s, p.color, 2.2);
  }
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
  if (parts.length || fxs.length || (ambient && !document.hidden)) raf = requestAnimationFrame(loop);
  else { raf = 0; g.clearRect(0, 0, W, H); }
}
const SPR = {};
function sprite(c, glow) {
  const key = c + glow;
  if (SPR[key]) return SPR[key];
  const S = 64, o = document.createElement('canvas');
  o.width = o.height = S;
  const q = o.getContext('2d');
  const grd = q.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
  grd.addColorStop(0, c); grd.addColorStop(Math.min(0.9, 1 / glow), c); grd.addColorStop(1, 'rgba(0,0,0,0)');
  q.fillStyle = grd; q.fillRect(0, 0, S, S);
  SPR[key] = o;
  return o;
}
function glowDot(x, y, r, c, glow) {
  const R = r * glow;
  if (R < 0.3) return;
  g.drawImage(sprite(c, glow), x - R, y - R, R * 2, R * 2);
}
function drawStar(x, y, r, c, rot = 0) {
  g.fillStyle = c; g.save(); g.translate(x, y); g.rotate(rot * 0.3);
  g.beginPath();
  for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; const rr = i % 2 ? r * 0.22 : r; g.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); }
  g.closePath(); g.fill(); g.restore();
}
function drawHeart(x, y, s, c) {
  g.fillStyle = c; g.beginPath();
  g.moveTo(x, y + s * 0.9);
  g.bezierCurveTo(x - s * 1.6, y - s * 0.2, x - s * 0.6, y - s * 1.3, x, y - s * 0.4);
  g.bezierCurveTo(x + s * 0.6, y - s * 1.3, x + s * 1.6, y - s * 0.2, x, y + s * 0.9);
  g.fill();
}

// 요소 중심 좌표
export function centerOf(el, oy = 0.5) {
  if (!el) return { x: W / 2, y: H / 2 };
  const r = el.getBoundingClientRect();
  return { x: r.left + r.width / 2, y: r.top + r.height * oy };
}
export function clearFx() { parts = []; fxs = []; }
