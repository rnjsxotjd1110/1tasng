// 구역별 전투 배경(SVG 400×700, 원경·중경·근경 레이어). 지평선 y≈300 근처에 적이 서요.
let uid = 0;

function seeded(seed) { let x = seed; return () => { x = (x * 9301 + 49297) % 233280; return x / 233280; }; }
function starsLayer(n, seed, h, c = '#fff') {
  const r = seeded(seed);
  let s = '';
  for (let i = 0; i < n; i++) {
    const x = (r() * 400).toFixed(1), y = (r() * h).toFixed(1), rad = (r() * 1.3 + 0.3).toFixed(2), op = (r() * 0.6 + 0.3).toFixed(2);
    s += `<circle cx="${x}" cy="${y}" r="${rad}" fill="${c}" opacity="${op}"/>`;
    if (r() < 0.06) s += `<path d="M${x} ${y - 4}L${+x + 0.8} ${y - 0.8}L${+x + 4} ${y}L${+x + 0.8} ${+y + 0.8}L${x} ${+y + 4}L${x - 0.8} ${+y + 0.8}L${x - 4} ${y}L${x - 0.8} ${y - 0.8}Z" fill="${c}" opacity="${op}"/>`;
  }
  return s;
}
function defs(k, sky) {
  return `<defs>
    <linearGradient id="bs${k}" x1="0" y1="0" x2="0" y2="1">${sky.map((c, i) => `<stop offset="${(i / (sky.length - 1)).toFixed(2)}" stop-color="${c}"/>`).join('')}</linearGradient>
    <filter id="bb${k}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="10"/></filter>
    <filter id="bb2${k}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="3"/></filter>
    <radialGradient id="spot${k}" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#fff" stop-opacity=".22"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
    <radialGradient id="vig${k}" cx=".5" cy=".42" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".6"/></radialGradient>
    <linearGradient id="floor${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></linearGradient>
  </defs>`;
}
const glow = (k, cx, cy, r, c, op = 0.5) => `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${c}" opacity="${op}" filter="url(#bb${k})"/>`;
const tail = (k) => `<ellipse cx="200" cy="300" rx="190" ry="34" fill="url(#spot${k})"/><rect y="330" width="400" height="370" fill="url(#floor${k})"/><rect width="400" height="700" fill="url(#vig${k})"/>`;

// ───────── 1구역 이끼 정원 ─────────
function garden(k) {
  const tree = (x, y, s, c) => `<g transform="translate(${x} ${y}) scale(${s})"><rect x="-6" y="-40" width="12" height="60" fill="${c}"/><circle cx="0" cy="-56" r="30" fill="${c}"/><circle cx="-22" cy="-40" r="20" fill="${c}"/><circle cx="22" cy="-42" r="22" fill="${c}"/></g>`;
  const shroom = (x, y, s, c) => `<g transform="translate(${x} ${y}) scale(${s})">${glow(k, 0, -10, 18, c, 0.55)}<rect x="-2.5" y="-12" width="5" height="12" rx="2" fill="#e8f6e0"/><path d="M-11 -11C-11 -22 11 -22 11 -11Z" fill="${c}"/><circle cx="-4" cy="-16" r="1.6" fill="#fff" opacity=".8"/><circle cx="4" cy="-14" r="1.2" fill="#fff" opacity=".8"/></g>`;
  let trees = '', trees2 = '';
  for (let i = 0; i < 8; i++) trees += tree(i * 56 - 10, 250 + (i % 2) * 8, 1.1, '#173a3c');
  for (let i = 0; i < 6; i++) trees2 += tree(i * 78 + 20, 285 + (i % 2) * 6, 1.4, '#102a2c');
  return defs(k, ['#06131f', '#0d2a33', '#1a4a44', '#1e3a30']) + starsLayer(70, 11, 220) +
    glow(k, 300, 90, 60, '#d8ffe8', 0.25) + `<circle cx="300" cy="90" r="24" fill="#f2fff4"/><circle cx="292" cy="84" r="6" fill="#d8eedd" opacity=".6"/>` +
    `<path d="M0 230Q60 200 120 222T250 214T400 222V330H0Z" fill="#14343a" opacity=".9"/>` + trees +
    // 무너진 돌 아치
    `<g opacity=".95"><path d="M120 300V170Q120 120 200 116Q280 120 280 170V300H256V176Q256 146 200 142Q144 146 144 176V300Z" fill="#2e4a4a"/>
      <path d="M120 170Q120 120 200 116Q280 120 280 170" fill="none" stroke="#7fd8a8" stroke-width="5" stroke-opacity=".55" stroke-dasharray="14 9"/>
      <path d="M150 300V250L158 246V300ZM248 300V236L240 232V300Z" fill="#244040"/></g>` +
    glow(k, 200, 190, 50, '#8fffc8', 0.18) + trees2 +
    `<path d="M0 300Q100 286 200 292T400 296V700H0Z" fill="#183a30"/>
     <path d="M0 312Q120 300 220 306T400 310V700H0Z" fill="#14302a"/>
     <g fill="#2f6a4a" opacity=".85">${[20, 70, 130, 270, 330, 380].map((x, i) => `<ellipse cx="${x}" cy="${306 + (i % 2) * 6}" rx="${26 + (i % 3) * 8}" ry="7"/>`).join('')}</g>` +
    shroom(40, 316, 1.4, '#8affc0') + shroom(70, 322, 1, '#ff9ad6') + shroom(340, 318, 1.5, '#8afff0') + shroom(372, 326, 1, '#c8ff8a') + shroom(300, 330, 0.8, '#ff9ad6') +
    // 근경 덩굴·잎
    `<g fill="#0a1f1c"><path d="M0 0H70Q60 40 40 60T10 130Q0 120 0 100Z"/><path d="M400 0H320Q336 50 360 70T392 150Q400 140 400 110Z"/>
     <path d="M0 560Q40 520 90 540T140 600V700H0Z"/><path d="M400 570Q360 530 310 550T270 620V700H400Z"/></g>
     <g stroke="#2f6a4a" stroke-width="2.4" fill="none" stroke-linecap="round"><path d="M50 0Q56 60 40 110"/><path d="M350 0Q340 70 362 130"/></g>
     <g fill="#3f8a5a">${[[44, 40], [38, 74], [352, 50], [360, 96]].map(([x, y]) => `<ellipse cx="${x}" cy="${y}" rx="7" ry="4" transform="rotate(30 ${x} ${y})"/>`).join('')}</g>` + tail(k);
}

// ───────── 2구역 수정 동굴 ─────────
function cave(k) {
  const crystal = (x, y, h, w, c, rot = 0) => `<g transform="translate(${x} ${y}) rotate(${rot})"><path d="M0 0L${-w} ${-h * 0.25}L${-w * 0.5} ${-h}L${w * 0.4} ${-h * 1.05}L${w} ${-h * 0.3}Z" fill="${c}"/><path d="M0 0L${-w * 0.5} ${-h}L${w * 0.4} ${-h * 1.05}Z" fill="#fff" opacity=".28"/><path d="M0 0L${w} ${-h * 0.3}L${w * 0.4} ${-h * 1.05}Z" fill="#000" opacity=".18"/></g>`;
  let stal = '';
  for (let i = 0; i < 11; i++) { const x = i * 40 + 8, h = 30 + ((i * 37) % 60); stal += `<path d="M${x - 16} 0L${x} ${h}L${x + 16} 0Z" fill="#0a0f26"/>`; }
  return defs(k, ['#05081a', '#0c1436', '#16245a', '#141a44']) +
    `<path d="M0 0H400V250Q300 210 200 226T0 240Z" fill="#0d1534"/>` + stal +
    glow(k, 200, 200, 90, '#5ab8ff', 0.22) +
    // 빛줄기
    `<g opacity=".16"><path d="M170 0L230 0L290 330H150Z" fill="#bfe6ff"/><path d="M60 0L90 0L130 320H60Z" fill="#bfe6ff" opacity=".6"/></g>` +
    `<path d="M0 240Q100 226 200 236T400 232V330H0Z" fill="#16204a"/>` +
    glow(k, 70, 240, 40, '#7ad8ff', 0.5) + crystal(70, 290, 90, 22, '#5ab8f0') + crystal(95, 296, 60, 16, '#8fd8ff', 12) + crystal(48, 300, 50, 14, '#3a8ad0', -14) +
    glow(k, 335, 236, 40, '#ff9ae6', 0.45) + crystal(330, 292, 100, 24, '#c87ae8') + crystal(358, 298, 58, 15, '#ff9ae6', 14) + crystal(305, 300, 46, 12, '#8a5ad0', -12) +
    crystal(200, 240, 30, 9, '#5a7ad0') + crystal(150, 246, 22, 7, '#4a6ab0', -8) + crystal(250, 244, 26, 8, '#6a5ab8', 8) +
    `<path d="M0 300Q100 288 200 294T400 298V700H0Z" fill="#121a40"/>
     <path d="M30 330H370" stroke="#7ad8ff" stroke-opacity=".12" stroke-width="20" filter="url(#bb2${k})"/>
     <g opacity=".35">${crystal(80, 344, -40, 18, '#5ab8f0')}${crystal(330, 344, -44, 20, '#c87ae8')}</g>` +
    `<g fill="#070a1c"><path d="M0 700V500Q30 460 60 520L80 450 110 560 140 700Z"/><path d="M400 700V480Q370 450 350 510L320 440 296 560 270 700Z"/></g>` +
    crystal(40, 620, 110, 26, '#2a5a9a') + crystal(370, 640, 120, 28, '#5a3a9a') + tail(k);
}

// ───────── 3구역 가라앉은 서고 ─────────
function library(k) {
  const shelf = (x, y, w, h, c) => {
    let s = `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}"/>`;
    for (let yy = y + 10; yy < y + h - 14; yy += 26) {
      s += `<rect x="${x + 4}" y="${yy + 20}" width="${w - 8}" height="3" fill="#000" opacity=".35"/>`;
      for (let bx = x + 6; bx < x + w - 8; bx += 7) s += `<rect x="${bx}" y="${yy + (bx % 3) * 2}" width="5" height="${20 - (bx % 3) * 2}" fill="${['#7a4a5a', '#4a5a8a', '#5a7a6a', '#8a6a3a', '#6a4a8a'][bx % 5]}" opacity=".75"/>`;
    }
    return s;
  };
  return defs(k, ['#060c18', '#0c1a2c', '#13304a', '#0e2a3c']) +
    glow(k, 200, 120, 70, '#ffd9a0', 0.18) +
    // 높은 아치 창
    `<path d="M170 250V110Q170 70 200 66Q230 70 230 110V250Z" fill="#1d3a5a"/><path d="M178 250V112Q178 80 200 76Q222 80 222 112V250Z" fill="#ffe0b0" opacity=".22"/><path d="M200 76V250M178 150H222" stroke="#0c1a2c" stroke-width="3"/>` +
    shelf(10, 70, 80, 230, '#1a2438') + shelf(96, 100, 64, 200, '#162034') + shelf(240, 100, 64, 200, '#162034') + shelf(310, 70, 80, 230, '#1a2438') +
    `<path d="M0 60Q200 20 400 60V70Q200 30 0 70Z" fill="#0a1222"/>` +
    // 떠다니는 책
    `<g opacity=".85">${[[120, 70, -12], [290, 54, 14], [210, 30, -4]].map(([x, y, r]) => `<g transform="translate(${x} ${y}) rotate(${r})"><path d="M-12 0L0 3 12 0V12L0 15-12 12Z" fill="#c9a27a"/><path d="M0 3V15" stroke="#8a6a4a" stroke-width="1.2"/></g>`).join('')}</g>` +
    // 물 바닥과 반영
    `<rect y="300" width="400" height="400" fill="#123a52"/>
     <g opacity=".22" transform="translate(0 600) scale(1 -1)">${shelf(10, 300, 80, 0, '#1a2438')}<rect x="10" y="300" width="80" height="120" fill="#2a4a6a"/><rect x="310" y="300" width="80" height="120" fill="#2a4a6a"/><rect x="178" y="300" width="44" height="120" fill="#ffe0b0" opacity=".4"/></g>
     <g stroke="#9fe0ff" stroke-opacity=".25" stroke-width="1.5" fill="none">${[318, 334, 356, 384, 420].map((y, i) => `<path d="M${20 + i * 10} ${y}Q${100} ${y - 3} ${200} ${y}T${380 - i * 10} ${y}"/>`).join('')}</g>
     <ellipse cx="200" cy="330" rx="40" ry="5" fill="#ffe0b0" opacity=".25"/>` +
    `<g fill="#050a14"><path d="M0 0H40V700H0Z" opacity=".7"/><path d="M360 0H400V700H360Z" opacity=".7"/><path d="M0 0Q200 40 400 0V14Q200 54 0 14Z"/></g>` + tail(k);
}

// ───────── 4구역 달의 왕좌 ─────────
function throne(k) {
  const pillar = (x, y, h, w) => `<g><rect x="${x - w / 2}" y="${y - h}" width="${w}" height="${h}" fill="#2a2458"/><rect x="${x - w / 2}" y="${y - h}" width="${w * 0.35}" height="${h}" fill="#fff" opacity=".07"/><rect x="${x - w / 2 - 5}" y="${y - h - 8}" width="${w + 10}" height="10" fill="#3a3270"/><rect x="${x - w / 2 - 5}" y="${y - 6}" width="${w + 10}" height="8" fill="#3a3270"/></g>`;
  const shard = (x, y, s, r) => `<g transform="translate(${x} ${y}) rotate(${r}) scale(${s})"><path d="M0-10L7-2 3 9-6 6-8-3Z" fill="#e8deff"/><path d="M0-10L7-2 0 0Z" fill="#fff" opacity=".6"/></g>`;
  return defs(k, ['#05030f', '#120a2e', '#2a1a5a', '#1a1240']) + starsLayer(130, 41, 320) +
    glow(k, 120, 60, 90, '#7a5aff', 0.22) + glow(k, 320, 150, 80, '#ff6bd6', 0.14) +
    // 금 간 거대한 달
    glow(k, 200, 130, 110, '#fff2d0', 0.3) +
    `<circle cx="200" cy="130" r="86" fill="#f4ecd8"/><circle cx="200" cy="130" r="86" fill="#d8c8f0" opacity=".25"/>
     <g fill="#d8cdb8" opacity=".7"><circle cx="170" cy="110" r="14"/><circle cx="230" cy="150" r="18"/><circle cx="215" cy="92" r="8"/><circle cx="178" cy="168" r="10"/></g>
     <path d="M200 44L208 92 186 120 214 150 196 216" fill="none" stroke="#2a1a5a" stroke-width="3.5" stroke-linejoin="round"/><path d="M186 120L150 116M214 150L262 160" stroke="#2a1a5a" stroke-width="2.4"/>` +
    shard(108, 110, 1.4, 20) + shard(300, 90, 1.8, -30) + shard(80, 190, 1, 60) + shard(330, 200, 1.2, 10) + shard(260, 40, 0.9, 45) +
    // 떠 있는 기둥과 단상
    pillar(60, 300, 150, 30) + pillar(340, 300, 150, 30) + pillar(120, 296, 100, 22) + pillar(280, 296, 100, 22) +
    `<path d="M70 210L80 300M330 210L320 300" stroke="#ff8fe0" stroke-opacity=".0"/>
     <path d="M30 300H370L350 330H50Z" fill="#2a2260"/><path d="M50 330H350L330 352H70Z" fill="#1c1846"/><path d="M30 300H370" stroke="#d9c2ff" stroke-opacity=".5" stroke-width="2"/>
     <g fill="#d9c2ff" opacity=".6">${[70, 130, 200, 270, 330].map((x) => `<path d="M${x} 314l3 3-3 3-3-3z"/>`).join('')}</g>
     <rect y="352" width="400" height="348" fill="#0c0820"/>
     <path d="M70 352L40 700M330 352L360 700" stroke="#3a2a7a" stroke-opacity=".5" stroke-width="2"/>` +
    `<g opacity=".6">${shard(40, 420, 2, 30)}${shard(370, 460, 2.4, -20)}${shard(60, 600, 1.6, 80)}${shard(350, 640, 1.8, 10)}</g>` + tail(k);
}

export function battleBgFor(actDef, abyss) {
  const k = 'bg' + (++uid);
  const fn = { 1: garden, 2: cave, 3: library, 4: throne }[actDef.id] || garden;
  const tint = abyss ? `<rect width="400" height="700" fill="#3a0a6a" opacity=".28" style="mix-blend-mode:color"/>` : '';
  return `<svg class="scene" viewBox="0 0 400 700" preserveAspectRatio="xMidYMin slice">${fn(k)}${tint}</svg>`;
}
