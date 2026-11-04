// 비주얼 노벨식 대화 상자 — 스토리 장면, 대화 선택지
import { h } from './dom.js';
import { App } from './app.js';
import { heroineSVG } from '../art/heroines.js';
import { sceneSVG } from '../art/scenes.js';
import { HEROINES } from '../data/heroines/index.js';
import { sfx } from '../audio/audio.js';

// opt: { bg, who, title, lines:[{s,e,t}], choices:[{t, ...}], onChoice(i) → lines | null, onEnd }
export function playVN(opt) {
  const root = h('div.vn');
  root.innerHTML = sceneSVG(opt.bg || 'camp');
  const dim = h('div.vn-dim');
  const chara = h('div.vn-chara.breathe');
  const nameEl = h('div.vn-name');
  const textEl = h('div.vn-text');
  const nextEl = h('div.vn-next', { text: '▼' });
  const box = h('div.vn-box', nameEl, textEl, nextEl);
  const choicesEl = h('div.vn-choices');
  const skip = h('button.btn.ghost.small.vn-skip', { type: 'button' }, '건너뛰기');
  root.append(dim, chara);
  if (opt.title) root.appendChild(h('div.vn-title', { text: opt.title }));
  root.append(choicesEl, box, skip);
  document.body.appendChild(root);

  let lines = opt.lines.slice();
  let i = -1, typing = false, full = '', timer = null, curWho = opt.who, curE = 'normal', inChoice = false, ended = false;
  const outfitOf = (id) => (App.p.heroines[id] || {}).outfit || 'default';
  let blinkT = null;
  function drawChara(id, e) {
    if (!id || !HEROINES[id]) { chara.innerHTML = ''; return; }
    chara.innerHTML = heroineSVG(id, { e, outfit: outfitOf(id) });
  }
  function blinkLoop() {
    const svg = chara.querySelector('.heroine');
    if (svg) { svg.classList.add('blinking'); setTimeout(() => svg.classList.remove('blinking'), 130); }
    blinkT = setTimeout(blinkLoop, 2600 + Math.random() * 2400);
  }
  blinkT = setTimeout(blinkLoop, 1800);
  drawChara(curWho, curE);

  function show(line) {
    const me = line.s === 'me';
    if (!me && line.s && HEROINES[line.s]) { if (line.s !== curWho || line.e !== curE) { curWho = line.s; curE = line.e || 'normal'; drawChara(curWho, curE); } }
    else if (!me && line.e && line.e !== curE) { curE = line.e; drawChara(curWho, curE); }
    nameEl.textContent = me ? App.p.name : (HEROINES[line.s || curWho] || { name: '' }).name;
    nameEl.className = 'vn-name' + (me ? ' me' : '');
    chara.classList.toggle('talk', !me);
    full = line.t;
    textEl.textContent = '';
    typing = true;
    nextEl.style.visibility = 'hidden';
    let k = 0;
    clearInterval(timer);
    const speed = App.p.settings.speed >= 2 ? 10 : App.p.settings.speed <= 0 ? 34 : 20;
    timer = setInterval(() => {
      k += 1;
      textEl.textContent = full.slice(0, k);
      if (k >= full.length) finishType();
    }, speed);
  }
  function finishType() { clearInterval(timer); typing = false; textEl.textContent = full; nextEl.style.visibility = 'visible'; }
  function next() {
    if (inChoice || ended) return;
    if (typing) { finishType(); return; }
    i++;
    if (i < lines.length) { sfx('page'); show(lines[i]); return; }
    if (opt.choices && opt.choices.length && !opt._chosen) { openChoices(); return; }
    end();
  }
  function openChoices() {
    inChoice = true;
    box.style.opacity = '0.6';
    choicesEl.innerHTML = '';
    opt.choices.forEach((c, ci) => {
      choicesEl.appendChild(h('button.choice', { type: 'button', onclick: (e) => {
        e.stopPropagation();
        opt._chosen = true;
        inChoice = false;
        choicesEl.innerHTML = '';
        box.style.opacity = '1';
        const more = opt.onChoice ? opt.onChoice(ci) : null;
        lines = [{ s: 'me', t: c.t }].concat(more || []);
        i = -1;
        next();
      } }, h('div.ct', { text: c.t })));
    });
  }
  function end() {
    if (ended) return;
    ended = true;
    if (App.vnClose === end) App.vnClose = null;
    clearInterval(timer);
    clearTimeout(blinkT);
    root.style.transition = 'opacity .2s';
    root.style.opacity = '0';
    setTimeout(() => root.remove(), 210);
    opt.onEnd && opt.onEnd();
  }
  box.addEventListener('click', next);
  root.addEventListener('click', (e) => { if (e.target === root || e.target === dim || chara.contains(e.target)) next(); });
  skip.addEventListener('click', (e) => {
    e.stopPropagation();
    if (opt.choices && !opt._chosen) { i = lines.length; finishType(); openChoices(); return; }
    end();
  });
  if (opt.noSkip) skip.style.display = 'none';
  App.vnClose = end;
  next();
  return { end };
}
