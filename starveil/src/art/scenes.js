// 배경 장면(SVG, 400×700 세로). 화면을 꽉 채우도록 slice
let uid = 0;
function stars(n, seed, h = 420, c = '#fff') {
  let s = '', x = seed;
  const rnd = () => { x = (x * 9301 + 49297) % 233280; return x / 233280; };
  for (let i = 0; i < n; i++) s += `<circle cx="${(rnd() * 400).toFixed(1)}" cy="${(rnd() * h).toFixed(1)}" r="${(rnd() * 1.4 + 0.4).toFixed(2)}" fill="${c}" opacity="${(rnd() * 0.6 + 0.3).toFixed(2)}"/>`;
  return s;
}
function sky(k, top, mid, bot) {
  return `<defs><linearGradient id="sk${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${top}"/><stop offset=".6" stop-color="${mid}"/><stop offset="1" stop-color="${bot}"/></linearGradient></defs><rect width="400" height="700" fill="url(#sk${k})"/>`;
}
const moon = (x, y, r) => `<circle cx="${x}" cy="${y}" r="${r * 2.2}" fill="#fff6d8" opacity=".08"/><circle cx="${x}" cy="${y}" r="${r}" fill="#fff4cf"/><circle cx="${x + r * 0.35}" cy="${y - r * 0.15}" r="${r * 0.92}" fill="#1a1d4a" opacity=".0"/>`;
const tent = (x, y, s, c) => `<g transform="translate(${x} ${y}) scale(${s})"><path d="M0 0L60-80 120 0Z" fill="${c}"/><path d="M60-80L44 0H76Z" fill="#000" opacity=".25"/><path d="M60-80L52 0" stroke="#fff" stroke-opacity=".15" stroke-width="2"/></g>`;
const pine = (x, y, s, c) => `<path transform="translate(${x} ${y}) scale(${s})" d="M0-90L24-40H12L34 0H-34L-12-40H-24Z" fill="${c}"/>`;

export const SCENES = {
  camp(k) {
    const pine = (x, y, sc, c) => `<path transform="translate(${x} ${y}) scale(${sc})" d="M0-96L14-66H7L26-36H14L36 0H-36L-14-36H-26L-7-66H-14Z" fill="${c}"/>`;
    const tentX = (x, y, sc, c1, c2) => `<g transform="translate(${x} ${y}) scale(${sc})">
      <path d="M0 0L64-92L128 0Z" fill="${c1}"/><path d="M64-92L40 0H88Z" fill="${c2}"/>
      <path d="M64-92L22 0M64-92L106 0" stroke="#fff" stroke-opacity=".12" stroke-width="5"/>
      <path d="M52 0Q64-40 76 0Z" fill="#ffcf7a" class="sc-glow"/><path d="M56 0Q64-30 72 0Z" fill="#fff0c0"/>
      <path d="M64-92V-104" stroke="#8a6a4a" stroke-width="3"/><path d="M64-104L80-98 64-94Z" fill="#ff8fc8"/></g>`;
    let bulbs = '';
    for (let i = 0; i <= 10; i++) { const t = i / 10; const x = 70 + t * 240, y = 462 + Math.sin(t * Math.PI) * 26; bulbs += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="7" fill="${['#ffcf7a', '#ff9ad6', '#9fe8ff'][i % 3]}" opacity=".35" filter="url(#sb${k})"/><circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="2.4" fill="${['#fff0c0', '#ffd6ef', '#e0f8ff'][i % 3]}" class="sc-tw" style="animation-delay:${(i * 0.37) % 2}s"/>`; }
    return `<defs><linearGradient id="sk${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#05071c"/><stop offset=".45" stop-color="#141a4c"/><stop offset=".8" stop-color="#2e2766"/><stop offset="1" stop-color="#3a2c6a"/></linearGradient>
      <filter id="sb${k}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="9"/></filter>
      <linearGradient id="mt1${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2a2a66"/><stop offset="1" stop-color="#1a1a44"/></linearGradient>
      <linearGradient id="mt2${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1c1f4e"/><stop offset="1" stop-color="#121434"/></linearGradient>
      <linearGradient id="gr${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#262c62"/><stop offset="1" stop-color="#161a40"/></linearGradient>
      <linearGradient id="fog${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9fb4ff" stop-opacity="0"/><stop offset=".5" stop-color="#9fb4ff" stop-opacity=".16"/><stop offset="1" stop-color="#9fb4ff" stop-opacity="0"/></linearGradient>
      <radialGradient id="vg${k}" cx=".5" cy=".45" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></radialGradient></defs>
      <rect width="400" height="700" fill="url(#sk${k})"/>
      <circle cx="90" cy="150" r="90" fill="#7a4ad0" opacity=".22" filter="url(#sb${k})"/><circle cx="250" cy="250" r="110" fill="#d05aa8" opacity=".12" filter="url(#sb${k})"/>
      <path d="M-20 260Q80 200 200 230T420 210" stroke="#cfc0ff" stroke-opacity=".07" stroke-width="60" fill="none" filter="url(#sb${k})"/>
      ${stars(110, 7, 430)}
      <g fill="#fff">${[[60, 80], [180, 60], [340, 210], [130, 300], [260, 40]].map(([x, y], i) => `<path class="sc-tw" style="animation-delay:${i * 0.6}s" d="M${x} ${y - 6}L${x + 1.2} ${y - 1.2}L${x + 6} ${y}L${x + 1.2} ${y + 1.2}L${x} ${y + 6}L${x - 1.2} ${y + 1.2}L${x - 6} ${y}L${x - 1.2} ${y - 1.2}Z"/>`).join('')}</g>
      <circle cx="300" cy="110" r="70" fill="#fff2c8" opacity=".22" filter="url(#sb${k})"/><circle cx="300" cy="110" r="34" fill="#fff6dc"/><circle cx="290" cy="102" r="8" fill="#efe2c0" opacity=".7"/><circle cx="312" cy="122" r="5" fill="#efe2c0" opacity=".6"/>
      <path d="M0 440L60 380 110 420 170 360 240 430 300 384 360 420 400 396V700H0Z" fill="url(#mt1${k})"/>
      <path d="M0 470Q100 430 200 452T400 440V700H0Z" fill="url(#mt2${k})"/>
      ${pine(30, 480, 1.1, '#101336')}${pine(80, 470, 0.8, '#12163c')}${pine(360, 466, 1.3, '#101336')}${pine(318, 486, 0.9, '#12163c')}${pine(150, 470, 0.6, '#151a44')}${pine(250, 468, 0.7, '#151a44')}
      <rect y="440" width="400" height="120" fill="url(#fog${k})"/>
      <path d="M0 520Q120 494 220 512T400 502V700H0Z" fill="url(#gr${k})"/>
      <path d="M70 462V420M310 462V420" stroke="#5a4a3a" stroke-width="3"/>
      ${bulbs}
      ${tentX(-24, 552, 0.95, '#6a4aa8', '#4a3484')}${tentX(292, 538, 0.75, '#8a5aa8', '#64418a')}
      <g transform="translate(52 640)"><circle cy="-40" r="46" fill="#9fe8ff" opacity=".32" filter="url(#sb${k})" class="sc-glow"/><path d="M0 0L-18-32 0-78 18-32Z" fill="#8fdcff"/><path d="M0-78L-7-32 0 0Z" fill="#fff" opacity=".6"/><path d="M0-78L18-32 0 0Z" fill="#3a8ad0" opacity=".45"/><ellipse cy="2" rx="24" ry="6" fill="#000" opacity=".3"/></g>
      <g transform="translate(345 640) scale(.85)">
        <circle cy="-30" r="80" fill="#ff9a3a" opacity=".2" filter="url(#sb${k})" class="sc-glow"/>
        <ellipse rx="56" ry="11" fill="#000" opacity=".3"/>
        <g fill="#7a6a6a">${[-34, -18, 0, 18, 34].map((x) => `<ellipse cx="${x}" cy="0" rx="9" ry="6"/>`).join('')}</g>
        <path d="M-30 -2L28 -10M-28 -10L30 -2" stroke="#6a4226" stroke-width="8" stroke-linecap="round"/>
        <g class="sc-flame"><path d="M0-66C12-44 26-34 26-16A26 26 0 01-26-16C-26-34-12-44 0-66Z" fill="#ff7a2a"/></g>
        <g class="sc-flame f2"><path d="M0-50C8-34 18-26 18-14A18 18 0 01-18-14C-18-26-8-34 0-50Z" fill="#ffb34c"/></g>
        <g class="sc-flame f3"><path d="M0-34C5-24 11-19 11-11A11 11 0 01-11-11C-11-19-5-24 0-34Z" fill="#fff3b0"/></g>
      </g>
      <g fill="#0c0f2a">${[0, 30, 64, 100, 300, 330, 362, 392].map((x, i) => `<path d="M${x} 700Q${x + 6} ${660 - (i % 3) * 12} ${x + 10} 700ZM${x + 8} 700Q${x + 18} ${672 - (i % 2) * 10} ${x + 22} 700Z"/>`).join('')}</g>
      <rect width="400" height="700" fill="url(#vg${k})"/>`;
  },
  lake(k) {
    return sky(k, '#0a1030', '#1a2a5a', '#2a4a7a') + stars(80, 11, 380) + moon(110, 120, 30) +
      `<path d="M0 400Q100 370 200 390T400 380V420H0Z" fill="#1a2348"/>${pine(330, 400, 1, '#121a38')}${pine(60, 395, 0.8, '#121a38')}
      <rect y="410" width="400" height="290" fill="#1a3a6a"/><g opacity=".5">${stars(30, 5, 280, '#9fd8ff').replace(/cy="(\d+\.?\d*)"/g, (m, v) => `cy="${410 + Number(v)}"`)}</g>
      <ellipse cx="110" cy="470" rx="30" ry="6" fill="#fff4cf" opacity=".35"/><ellipse cx="110" cy="500" rx="18" ry="4" fill="#fff4cf" opacity=".2"/>
      <path d="M240 520H400V560H240Z" fill="#5a3f2a"/><path d="M250 560V620M300 560V620M350 560V620" stroke="#4a3220" stroke-width="8"/>`;
  },
  kitchen(k) {
    return sky(k, '#3a2a2a', '#5a3f3a', '#6a4a3a') +
      `<rect y="0" width="400" height="420" fill="#4a3330"/><g fill="#5a3f3a">${[0, 1, 2, 3, 4, 5, 6, 7].map((i) => `<rect x="${i * 52}" y="0" width="48" height="420"/>`).join('')}</g>
      <rect x="60" y="110" width="120" height="110" rx="6" fill="#1a2148"/><path d="M120 110V220M60 165H180" stroke="#6a4a3a" stroke-width="6"/>${moon(150, 140, 14)}
      <rect x="220" y="140" width="140" height="10" fill="#7a5a3a"/><g>${[0, 1, 2, 3].map((i) => `<rect x="${230 + i * 32}" y="${108 - (i % 2) * 8}" width="22" height="${32 + (i % 2) * 8}" rx="4" fill="${['#ffcf9a', '#ff9aaa', '#bfe9ff', '#d9f5b0'][i]}"/>`).join('')}</g>
      <rect y="420" width="400" height="280" fill="#7a5a40"/><rect y="420" width="400" height="18" fill="#9a7a5a"/>
      <g transform="translate(200 470)"><ellipse rx="60" ry="10" fill="#000" opacity=".2"/><path d="M-50-50H50L44 0H-44Z" fill="#3a3a4a"/><path d="M-56-54H56" stroke="#4a4a5a" stroke-width="8" stroke-linecap="round"/></g>`;
  },
  market(k) {
    const stall = (x, c) => `<g transform="translate(${x} 470)"><rect x="-55" y="-90" width="110" height="90" fill="#6a4a2a"/><path d="M-62-90H62L52-130H-52Z" fill="${c}"/><path d="M-62-90Q-46-80-31-90T0-90T31-90T62-90" fill="${c}" stroke="#fff" stroke-opacity=".4" stroke-width="2"/><rect x="-50" y="-60" width="100" height="10" fill="#8a6a4a"/></g>`;
    let lanterns = '';
    for (let i = 0; i < 9; i++) lanterns += `<circle cx="${20 + i * 46}" cy="${210 + Math.sin(i) * 12}" r="9" fill="#ffb34c"/><circle cx="${20 + i * 46}" cy="${210 + Math.sin(i) * 12}" r="22" fill="#ffb34c" opacity=".12"/>`;
    return sky(k, '#120f30', '#2a1f4a', '#4a2f5a') + stars(60, 3, 300) + `<path d="M0 200Q200 240 400 196" stroke="#2a2040" stroke-width="2" fill="none"/>` + lanterns +
      `<rect y="470" width="400" height="230" fill="#3a2f4a"/>${stall(80, '#e85a5a')}${stall(220, '#5a8ae8')}${stall(350, '#e8b05a')}`;
  },
  library(k) {
    let shelves = '';
    for (let x = 0; x < 400; x += 100) {
      shelves += `<rect x="${x + 6}" y="60" width="88" height="420" fill="#2a2240"/>`;
      for (let y = 80; y < 460; y += 60) for (let b = 0; b < 7; b++) shelves += `<rect x="${x + 12 + b * 11}" y="${y + (b % 3) * 3}" width="9" height="${48 - (b % 3) * 3}" fill="${['#5a7bd6', '#c94a6a', '#8a6ad0', '#4aa08a', '#d9a03a'][(b + x / 100 + y) % 5]}" opacity=".8"/>`;
    }
    return sky(k, '#0c1420', '#14243a', '#1a3448') + shelves +
      `<rect y="480" width="400" height="220" fill="#1a3a50"/><path d="M0 500Q100 490 200 500T400 498V700H0Z" fill="#2a5a7a" opacity=".6"/>
      <g fill="#9fe8ff" opacity=".25">${[50, 140, 260, 330].map((x) => `<ellipse cx="${x}" cy="540" rx="24" ry="4"/>`).join('')}</g>`;
  },
  hill(k) {
    return sky(k, '#070a24', '#141a4a', '#2a2a6a') + stars(160, 21, 520) +
      `<path d="M40 120Q200 60 360 150" stroke="#fff" stroke-opacity=".12" stroke-width="30" fill="none"/>${moon(290, 140, 26)}
      <path d="M0 560Q200 470 400 540V700H0Z" fill="#1a2050"/><path d="M0 600Q200 540 400 600V700H0Z" fill="#232a66"/>
      <g fill="#fff3a0">${[60, 130, 250, 330].map((x, i) => `<circle cx="${x}" cy="${590 - i * 6}" r="3"/>`).join('')}</g>`;
  },
  ruins(k) {
    const col = (x, h) => `<rect x="${x}" y="${520 - h}" width="34" height="${h}" fill="#4a4f6a"/><rect x="${x - 6}" y="${520 - h}" width="46" height="12" fill="#5a5f7a"/>`;
    return sky(k, '#0e1226', '#1f2444', '#2f3658') + stars(70, 13, 360) + moon(80, 100, 22) +
      `${col(40, 220)}${col(150, 160)}${col(300, 260)}<path d="M240 520L270 430 290 520Z" fill="#3a3f58"/>
      <rect y="520" width="400" height="180" fill="#2a2f48"/><g fill="#8fe0a0" opacity=".5">${[30, 120, 210, 300, 370].map((x) => `<ellipse cx="${x}" cy="526" rx="26" ry="6"/>`).join('')}</g>`;
  },
};

function hx(h) { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function mixc(h, t, a) { const p = hx(h), q = hx(t); return '#' + p.map((v, i) => Math.round(v + (q[i] - v) * a).toString(16).padStart(2, '0')).join(''); }
// 단색 장면에 그라디언트·성운·안개·비네팅을 더해 깊이감을 줘요
function enhance(body, k) {
  const map = {};
  let defs = '';
  const out = body.replace(/fill="(#[0-9a-fA-F]{6})"/g, (m, c) => {
    c = c.toLowerCase();
    if (!map[c]) { const id = `eg${k}_${Object.keys(map).length}`; map[c] = id; defs += `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${mixc(c, '#ffffff', 0.12)}"/><stop offset=".6" stop-color="${c}"/><stop offset="1" stop-color="${mixc(c, '#0a0820', 0.3)}"/></linearGradient>`; }
    return `fill="url(#${map[c]})"`;
  });
  return `<defs>${defs}<filter id="eb${k}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="12"/></filter>
    <linearGradient id="ef${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b8c4ff" stop-opacity="0"/><stop offset=".5" stop-color="#b8c4ff" stop-opacity=".13"/><stop offset="1" stop-color="#b8c4ff" stop-opacity="0"/></linearGradient>
    <radialGradient id="ev${k}" cx=".5" cy=".45" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></radialGradient></defs>
    ${out}<circle cx="80" cy="140" r="90" fill="#7a4ad0" opacity=".16" filter="url(#eb${k})"/><circle cx="320" cy="260" r="100" fill="#d05aa8" opacity=".09" filter="url(#eb${k})"/>
    <rect y="360" width="400" height="160" fill="url(#ef${k})"/><rect width="400" height="700" fill="url(#ev${k})"/>`;
}

export function sceneSVG(id, cls = '', align = 'xMidYMid') {
  const fn = SCENES[id] || SCENES.camp;
  const k = ++uid;
  const body = id === 'camp' ? fn(k) : enhance(fn(k), k);
  return `<svg class="scene ${cls}" viewBox="0 0 400 700" preserveAspectRatio="${align} slice">${body}</svg>`;
}

// 전투 배경(구역별)
export function battleBg(actDef) {
  const k = ++uid;
  const [a, b, c] = actDef.sky;
  return `<svg class="scene" viewBox="0 0 400 700" preserveAspectRatio="xMidYMid slice">${sky(k, a, b, c)}${stars(70, actDef.id * 17, 360)}
    <path d="M0 330Q100 300 200 320T400 310V700H0Z" fill="${b}" opacity=".7"/>
    <ellipse cx="200" cy="350" rx="230" ry="40" fill="${actDef.accent}" opacity=".08"/></svg>`;
}
