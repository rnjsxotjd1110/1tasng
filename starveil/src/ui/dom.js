// DOM 도우미 — 요소 생성, 카운트업, 토스트, 시트(패널), 확인창
import { icon } from '../art/icons.js';
import { sfx } from '../audio/audio.js';
import { fmt } from '../core/util.js';

export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

// h('div.cls#id', {attrs}, children...)
export function h(tag, attrs, ...kids) {
  const m = /^([a-z0-9]+)?((?:[.#][\w-]+)*)$/i.exec(tag) || [];
  const el = document.createElement(m[1] || 'div');
  if (m[2]) for (const part of m[2].match(/[.#][\w-]+/g) || []) { if (part[0] === '.') el.classList.add(part.slice(1)); else el.id = part.slice(1); }
  if (attrs && (typeof attrs !== 'object' || attrs instanceof Node || Array.isArray(attrs))) { kids.unshift(attrs); attrs = null; }
  if (attrs) {
    for (const k in attrs) {
      const v = attrs[k];
      if (v === undefined || v === null || v === false) continue;
      if (k === 'html') el.innerHTML = v;
      else if (k === 'text') el.textContent = v;
      else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
      else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
      else if (k === 'cls') el.className += ' ' + v;
      else el.setAttribute(k, v === true ? '' : v);
    }
  }
  append(el, kids);
  return el;
}
function append(el, kids) {
  for (const k of kids) {
    if (k === null || k === undefined || k === false) continue;
    if (Array.isArray(k)) append(el, k);
    else if (k instanceof Node) el.appendChild(k);
    else el.appendChild(document.createTextNode(String(k)));
  }
}
export const ic = (name, cls) => h('span.icw', { html: icon(name, cls) });

// 버튼: 모든 버튼은 4상태(CSS) + 클릭음(전역 위임)
export function btn(label, onClick, opt = {}) {
  const b = h(`button.btn${opt.cls ? '.' + opt.cls.split(' ').join('.') : ''}`, { type: 'button', disabled: opt.disabled ? true : null });
  if (opt.icon) b.appendChild(ic(opt.icon));
  if (label) b.appendChild(h('span.lbl', { html: label }));
  if (opt.sub) b.appendChild(h('span.sub', { html: opt.sub }));
  b.addEventListener('click', (e) => { if (b.disabled) return; onClick && onClick(e); });
  return b;
}

// 카운트업 숫자
const tweens = new WeakMap();
export function countTo(el, to, ms = 450, format = fmt) {
  if (!el) return;
  const from = Number(el.dataset.v || 0);
  el.dataset.v = to;
  const prev = tweens.get(el);
  if (prev) cancelAnimationFrame(prev);
  if (from === to || ms <= 0) { el.textContent = format(to); return; }
  const t0 = performance.now();
  const step = (t) => {
    const k = Math.min(1, (t - t0) / ms);
    const e = 1 - Math.pow(1 - k, 3);
    el.textContent = format(Math.round(from + (to - from) * e));
    if (k < 1) tweens.set(el, requestAnimationFrame(step));
  };
  tweens.set(el, requestAnimationFrame(step));
}
export function numEl(v, cls = '') { const s = h(`span.num${cls ? '.' + cls : ''}`); s.dataset.v = v; s.textContent = fmt(v); return s; }

// 토스트
let toastRoot = null;
export function toast(msg, opt = {}) {
  if (!toastRoot) { toastRoot = h('div.toasts'); document.body.appendChild(toastRoot); }
  const t = h('div.toast' + (opt.kind ? '.' + opt.kind : ''), opt.icon ? ic(opt.icon) : null, h('span', { html: msg }));
  toastRoot.appendChild(t);
  requestAnimationFrame(() => t.classList.add('in'));
  setTimeout(() => { t.classList.remove('in'); t.classList.add('out'); setTimeout(() => t.remove(), 260); }, opt.ms || 2200);
}

// 시트(아래에서 올라오는 패널) — 0.22초 전환
let sheetStack = [];
export function sheet(content, opt = {}) {
  const back = h('div.sheet-back');
  const box = h('div.sheet' + (opt.cls ? '.' + opt.cls : ''));
  if (opt.title) box.appendChild(h('div.sheet-head', h('div.sheet-title', { html: opt.title }), opt.noClose ? null : h('button.icon-btn.close', { type: 'button', onclick: () => close(), html: icon('close') })));
  const body = h('div.sheet-body');
  if (typeof content === 'function') content(body, () => close());
  else append(body, [content]);
  box.appendChild(body);
  back.appendChild(box);
  document.body.appendChild(back);
  requestAnimationFrame(() => back.classList.add('in'));
  sfx('open');
  let closed = false;
  function close(silent) {
    if (closed) return;
    closed = true;
    sheetStack = sheetStack.filter((x) => x !== close);
    back.classList.remove('in'); back.classList.add('out');
    if (!silent) sfx('close');
    setTimeout(() => back.remove(), 230);
    opt.onClose && opt.onClose();
  }
  if (!opt.modal) back.addEventListener('click', (e) => { if (e.target === back) close(); });
  sheetStack.push(close);
  return { close, body, box };
}
export function closeAllSheets() { for (const c of sheetStack.slice()) c(true); }
export function topSheetClose() { const c = sheetStack[sheetStack.length - 1]; if (c) { c(); return true; } return false; }

export function confirmBox(msg, yes, opt = {}) {
  sheet((body, close) => {
    body.appendChild(h('p.confirm-msg', { html: msg }));
    body.appendChild(h('div.row.gap.end',
      btn(opt.no || '취소', () => close(), { cls: 'ghost' }),
      btn(opt.yes || '확인', () => { close(); yes(); }, { cls: opt.danger ? 'danger' : '' })));
  }, { title: opt.title || '확인', cls: 'small' });
}

// 떠오르는 숫자
export function floatText(parent, text, cls = '') {
  if (!parent) return;
  const r = parent.getBoundingClientRect();
  const f = h('div.float' + (cls ? '.' + cls : ''), { text });
  f.style.left = Math.round(r.left + r.width / 2 + (Math.random() * 24 - 12)) + 'px';
  f.style.top = Math.round(r.top + r.height * 0.35) + 'px';
  document.body.appendChild(f);
  setTimeout(() => f.remove(), 900);
}

export function wait(ms) { return new Promise((r) => setTimeout(r, ms)); }
export function vibrate(ms, settings) { try { if (settings && settings.vib && navigator.vibrate) navigator.vibrate(ms); } catch (e) { /* 진동 미지원 */ } }

// 길게 누르거나 탭하면 정보 표시
export function infoTap(el, getHtml, title) {
  el.addEventListener('click', (e) => { e.stopPropagation(); sheet((b) => { b.innerHTML = getHtml(); }, { title: title || '정보', cls: 'small' }); });
}
