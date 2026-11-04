// 사운드 — WebAudio 합성. 원칙: 음정 미끄러짐 없음, 노이즈 없음, 작은 음량, 부드러운 시작·끝
let ctx = null, master = null, sfxBus = null, bgmBus = null;
let vol = { sfx: 0.7, bgm: 0.45 };
let unlocked = false;

const NOTE = (n) => 440 * Math.pow(2, (n - 69) / 12); // MIDI → Hz

function ensure() {
  if (ctx) return ctx;
  const AC = typeof window !== 'undefined' && (window.AudioContext || window.webkitAudioContext);
  if (!AC) return null;
  ctx = new AC();
  master = ctx.createDynamicsCompressor();
  master.threshold.value = -18; master.knee.value = 12; master.ratio.value = 3; master.attack.value = 0.01; master.release.value = 0.2;
  const out = ctx.createGain(); out.gain.value = 1.4;
  master.connect(out); out.connect(ctx.destination);
  sfxBus = ctx.createGain(); sfxBus.gain.value = vol.sfx; sfxBus.connect(master);
  bgmBus = ctx.createGain(); bgmBus.gain.value = vol.bgm * 0.6; bgmBus.connect(master);
  return ctx;
}

export function unlockAudio() {
  if (unlocked) return;
  const c = ensure();
  if (!c) return;
  if (c.state === 'suspended') c.resume();
  unlocked = true;
  if (pendingTrack) { const t = pendingTrack; pendingTrack = null; playBgm(t); }
}
export function setVolumes(s, b) {
  vol.sfx = s; vol.bgm = b;
  if (sfxBus) sfxBus.gain.setTargetAtTime(s, ctx.currentTime, 0.05);
  if (bgmBus) bgmBus.gain.setTargetAtTime(b * 0.6, ctx.currentTime, 0.1);
}

// 한 음: 부드러운 시작(attack)과 지수 감쇠. 주파수는 고정(미끄러짐 없음)
function tone(freq, at, dur, o = {}) {
  if (!ctx) return;
  const t0 = ctx.currentTime + (at || 0);
  const osc = ctx.createOscillator();
  osc.type = o.type || 'sine';
  osc.frequency.value = freq;
  const g = ctx.createGain();
  const v = (o.vol || 0.1);
  const a = o.attack || 0.008;
  g.gain.setValueAtTime(0, t0);
  g.gain.linearRampToValueAtTime(v, t0 + a);
  g.gain.setTargetAtTime(0, t0 + a + (o.hold || 0), Math.max(0.015, dur / 4));
  osc.connect(g);
  if (o.lp) { const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = o.lp; g.connect(f); f.connect(o.bus || sfxBus); }
  else g.connect(o.bus || sfxBus);
  osc.start(t0);
  osc.stop(t0 + a + (o.hold || 0) + dur * 1.6 + 0.05);
}

const C5 = 72, D5 = 74, E5 = 76, F5 = 77, G5 = 79, A5 = 81, B5 = 83, C6 = 84, D6 = 86, E6 = 88, G6 = 91, A6 = 93;
const SFX = {
  click: () => { tone(NOTE(81), 0, 0.05, { type: 'triangle', vol: 0.06 }); },
  hover: () => { tone(NOTE(88), 0, 0.03, { vol: 0.015 }); },
  open: () => { tone(NOTE(C6), 0, 0.08, { vol: 0.045 }); tone(NOTE(E6), 0.05, 0.1, { vol: 0.04 }); },
  close: () => { tone(NOTE(E6), 0, 0.06, { vol: 0.035 }); tone(NOTE(C6), 0.045, 0.08, { vol: 0.03 }); },
  tab: () => { tone(NOTE(G5), 0, 0.06, { type: 'triangle', vol: 0.05 }); },
  roll: () => { const ns = [84, 86, 88, 91, 93]; for (let i = 0; i < 5; i++) tone(NOTE(ns[(i * 3) % 5]), i * 0.045, 0.04, { type: 'triangle', vol: 0.035 }); },
  pick: () => { tone(NOTE(A5), 0, 0.05, { type: 'triangle', vol: 0.05 }); },
  place: () => { tone(NOTE(E5), 0, 0.12, { type: 'triangle', vol: 0.08 }); tone(NOTE(B5), 0.01, 0.08, { vol: 0.035 }); },
  hit: () => { tone(150, 0, 0.12, { vol: 0.22, lp: 900 }); tone(NOTE(60), 0, 0.08, { type: 'triangle', vol: 0.05, lp: 1400 }); },
  hitBig: () => { tone(110, 0, 0.18, { vol: 0.26, lp: 800 }); tone(165, 0, 0.14, { vol: 0.12, lp: 900 }); tone(NOTE(67), 0.02, 0.1, { type: 'triangle', vol: 0.05 }); },
  hurt: () => { tone(130, 0, 0.14, { vol: 0.2, lp: 700 }); tone(NOTE(56), 0, 0.1, { type: 'triangle', vol: 0.04, lp: 1000 }); },
  block: () => { tone(NOTE(C5), 0, 0.16, { vol: 0.06 }); tone(NOTE(G5), 0, 0.14, { vol: 0.04 }); },
  heal: () => { [C5, E5, G5].forEach((n, i) => tone(NOTE(n), i * 0.07, 0.16, { vol: 0.05 })); },
  status: () => { tone(NOTE(67), 0, 0.1, { type: 'triangle', vol: 0.05 }); tone(NOTE(70), 0.06, 0.1, { type: 'triangle', vol: 0.04 }); },
  gold: () => { tone(NOTE(B5), 0, 0.06, { vol: 0.05 }); tone(NOTE(E6), 0.06, 0.12, { vol: 0.05 }); },
  fortune: () => { [C6, D6, E6, G6, A6].forEach((n, i) => tone(NOTE(n), i * 0.05, 0.14, { vol: 0.035 })); },
  win: () => { [C5, E5, G5, C6].forEach((n, i) => tone(NOTE(n), i * 0.1, i === 3 ? 0.5 : 0.18, { type: 'triangle', vol: 0.07 })); },
  lose: () => { [69, 65, 62].forEach((n, i) => tone(NOTE(n), i * 0.2, 0.3, { vol: 0.06 })); },
  level: () => { [G5, C6, E6, G6].forEach((n, i) => tone(NOTE(n), i * 0.08, i === 3 ? 0.4 : 0.14, { vol: 0.05 })); },
  buy: () => { tone(NOTE(E6), 0, 0.06, { vol: 0.05 }); tone(NOTE(A6), 0.06, 0.12, { vol: 0.04 }); },
  error: () => { tone(NOTE(64), 0, 0.08, { type: 'triangle', vol: 0.05 }); tone(NOTE(60), 0.09, 0.1, { type: 'triangle', vol: 0.05 }); },
  freeze: () => { tone(NOTE(E6), 0, 0.14, { vol: 0.03 }); tone(NOTE(B5), 0.05, 0.14, { vol: 0.03 }); },
  assist: () => { [E5, A5, C6, E6].forEach((n, i) => tone(NOTE(n), i * 0.06, 0.18, { vol: 0.045 })); },
  page: () => { tone(NOTE(76), 0, 0.03, { type: 'triangle', vol: 0.025 }); },
  heart: () => { tone(NOTE(A5), 0, 0.1, { vol: 0.05 }); tone(NOTE(E6), 0.08, 0.16, { vol: 0.045 }); },
  splash: () => { [79, 76, 72].forEach((n, i) => tone(NOTE(n), i * 0.04, 0.08, { vol: 0.03 })); },
  tick: () => { tone(NOTE(84), 0, 0.025, { type: 'triangle', vol: 0.025 }); },
  good: () => { tone(NOTE(C6), 0, 0.08, { vol: 0.05 }); tone(NOTE(G6), 0.07, 0.12, { vol: 0.045 }); },
  enemyTurn: () => { tone(NOTE(57), 0, 0.12, { type: 'triangle', vol: 0.04 }); },
};
export function sfx(name) {
  if (!unlocked || !ctx || vol.sfx <= 0) return;
  const f = SFX[name];
  if (f) try { f(); } catch (e) { /* 소리 오류는 무시 */ }
}

// ───────── 배경음악(생성형) ─────────
// 화음: MIDI 근음 배열. 각 화음은 [근음, 3음, 5음, 7음?]
const TRACKS = {
  camp: { bpm: 72, chords: [[53, 57, 60, 64], [50, 53, 57, 60], [46, 50, 53, 57], [48, 52, 55, 58]], scale: [65, 67, 69, 72, 74, 77, 79, 81], arp: 'box', mel: 0.35 },
  map: { bpm: 66, chords: [[48, 52, 55, 59], [45, 48, 52, 55], [41, 45, 48, 52], [43, 47, 50, 53]], scale: [72, 74, 76, 79, 81, 84], arp: 'soft', mel: 0.25 },
  battle: { bpm: 96, chords: [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 44, 47]], scale: [69, 72, 74, 76, 79, 81], arp: 'drive', mel: 0.3, bass: 1 },
  boss: { bpm: 104, chords: [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 49, 52]], scale: [62, 65, 67, 69, 72, 74], arp: 'drive', mel: 0.35, bass: 1 },
  mini: { bpm: 100, chords: [[55, 59, 62], [52, 55, 59], [48, 52, 55], [50, 54, 57]], scale: [74, 76, 79, 81, 83, 86], arp: 'box', mel: 0.4 },
  title: { bpm: 64, chords: [[52, 55, 59, 62], [48, 52, 55, 59], [45, 48, 52, 55], [47, 50, 54, 57]], scale: [71, 74, 76, 78, 79, 83], arp: 'soft', mel: 0.3 },
};
let cur = null, timer = null, nextT = 0, step = 0, pendingTrack = null, trackGain = null;

export function playBgm(name) {
  if (!unlocked) { pendingTrack = name; return; }
  if (cur === name) return;
  stopBgm();
  const tr = TRACKS[name];
  if (!tr || !ctx) return;
  cur = name;
  trackGain = ctx.createGain();
  trackGain.gain.setValueAtTime(0, ctx.currentTime);
  trackGain.gain.linearRampToValueAtTime(1, ctx.currentTime + 1.2);
  trackGain.connect(bgmBus);
  step = 0;
  nextT = ctx.currentTime + 0.1;
  const spb = 60 / tr.bpm / 2; // 8분음표 길이
  let rnd = 1;
  const r = () => { rnd = (rnd * 16807) % 2147483647; return rnd / 2147483647; };
  timer = setInterval(() => {
    if (!ctx || document.hidden) return;
    while (nextT < ctx.currentTime + 0.35) {
      const bar = Math.floor(step / 8) % tr.chords.length;
      const ch = tr.chords[bar];
      const s8 = step % 8;
      const at = nextT - ctx.currentTime;
      const bus = trackGain;
      if (s8 === 0) {
        for (const n of ch) tone(NOTE(n + 12), at, spb * 7, { vol: 0.012, attack: 0.35, hold: spb * 5, bus });
        if (tr.bass) tone(NOTE(ch[0] - 12), at, spb * 1.5, { vol: 0.05, bus, lp: 600 });
        else tone(NOTE(ch[0]), at, spb * 4, { vol: 0.025, attack: 0.04, bus });
      }
      if (tr.bass && s8 === 4) tone(NOTE(ch[0] - 12), at, spb * 1.5, { vol: 0.04, bus, lp: 600 });
      if (tr.arp === 'box') { const n = ch[[0, 1, 2, 3, 2, 1, 2, 3][s8] % ch.length] + 24; tone(NOTE(n), at, spb * 1.4, { vol: 0.022, bus }); }
      else if (tr.arp === 'soft') { if (s8 % 2 === 0) { const n = ch[(s8 / 2) % ch.length] + 24; tone(NOTE(n), at, spb * 2.2, { vol: 0.02, type: 'triangle', bus }); } }
      else if (tr.arp === 'drive') { const n = ch[[0, 1, 2, 1][s8 % 4]] + 12; tone(NOTE(n), at, spb * 0.8, { vol: 0.022, type: 'triangle', bus, lp: 2200 }); }
      if (s8 % 2 === 0 && r() < tr.mel) { const n = tr.scale[Math.floor(r() * tr.scale.length)]; tone(NOTE(n), at, spb * 2.5, { vol: 0.022, bus }); }
      nextT += spb;
      step++;
    }
  }, 90);
}
export function stopBgm() {
  if (timer) clearInterval(timer);
  timer = null;
  if (trackGain && ctx) { const g = trackGain; g.gain.setTargetAtTime(0, ctx.currentTime, 0.25); setTimeout(() => g.disconnect(), 1500); }
  trackGain = null;
  cur = null;
}
export function currentBgm() { return cur || pendingTrack; }
