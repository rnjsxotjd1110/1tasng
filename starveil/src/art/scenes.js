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
    return sky(k, '#0b0f2e', '#1f2357', '#3a2f6a') + stars(90, 7) + moon(300, 110, 34) +
      `<path d="M0 470Q100 430 200 450T400 440V700H0Z" fill="#1d2148"/>${pine(40, 470, 1.1, '#151838')}${pine(360, 460, 1.3, '#151838')}${pine(330, 480, 0.9, '#181b40')}
      <path d="M0 520Q120 490 220 510T400 500V700H0Z" fill="#242a5a"/>
      ${tent(-20, 540, 0.9, '#5a4a9a')}${tent(300, 530, 0.75, '#7a5aa0')}
      <g transform="translate(345 640) scale(.8)"><ellipse rx="70" ry="14" fill="#000" opacity=".25"/><path d="M-30 0L30-6M-26-6L28 2" stroke="#6a4a2a" stroke-width="7" stroke-linecap="round"/>
      <path d="M0-60C10-40 22-30 22-14A22 22 0 01-22-14C-22-30-10-40 0-60Z" fill="#ffb34c"/><path d="M0-40C6-28 12-22 12-12A12 12 0 01-12-12C-12-22-6-28 0-40Z" fill="#fff3b0"/>
      <circle r="90" cy="-20" fill="#ffb34c" opacity=".08"/></g>
      <g transform="translate(52 640)"><path d="M0 0L-16-30 0-70 16-30Z" fill="#9fe8ff"/><path d="M0-70L-6-30 0 0Z" fill="#fff" opacity=".5"/><circle cy="-35" r="40" fill="#9fe8ff" opacity=".12"/></g>
      <path d="M0 650Q200 620 400 650V700H0Z" fill="#2c3366"/>`;
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

export function sceneSVG(id, cls = '') {
  const fn = SCENES[id] || SCENES.camp;
  return `<svg class="scene ${cls}" viewBox="0 0 400 700" preserveAspectRatio="xMidYMid slice">${fn(++uid)}</svg>`;
}

// 전투 배경(구역별)
export function battleBg(actDef) {
  const k = ++uid;
  const [a, b, c] = actDef.sky;
  return `<svg class="scene" viewBox="0 0 400 700" preserveAspectRatio="xMidYMid slice">${sky(k, a, b, c)}${stars(70, actDef.id * 17, 360)}
    <path d="M0 330Q100 300 200 320T400 310V700H0Z" fill="${b}" opacity=".7"/>
    <ellipse cx="200" cy="350" rx="230" ry="40" fill="${actDef.accent}" opacity=".08"/></svg>`;
}
