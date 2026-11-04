// 몬스터 일러스트(SVG, 120×120). 귀엽고 둥근 스타일
let uid = 0;
const DARK = '#2a1f3a';

function eyes(x1, x2, y, r = 7, o = {}) {
  const one = (x, flip) => {
    let s = `<ellipse cx="${x}" cy="${y}" rx="${r}" ry="${r * 1.15}" fill="${o.white || '#fff'}"/>`;
    s += `<ellipse cx="${x + (o.look || 0)}" cy="${y + 1}" rx="${r * 0.62}" ry="${r * 0.8}" fill="${o.pupil || DARK}"/>`;
    s += `<circle cx="${x - r * 0.25 + (o.look || 0)}" cy="${y - r * 0.35}" r="${r * 0.28}" fill="#fff"/>`;
    if (o.angry) s += `<path d="M${x - r * 1.1} ${y - r * 1.5} L${x + r * 0.9} ${y - r * (flip ? 1.0 : 0.7)}" stroke="${DARK}" stroke-width="${r * 0.42}" stroke-linecap="round" transform="${flip ? `translate(${2 * x} 0) scale(-1 1)` : ''}"/>`;
    return s;
  };
  return one(x1, false) + one(x2, true);
}
const glowEyes = (x1, x2, y, c, r = 5) => `<g fill="${c}"><ellipse cx="${x1}" cy="${y}" rx="${r}" ry="${r * 0.7}"/><ellipse cx="${x2}" cy="${y}" rx="${r}" ry="${r * 0.7}"/></g><g fill="#fff" opacity=".8"><circle cx="${x1 - 1.5}" cy="${y - 1}" r="1.5"/><circle cx="${x2 - 1.5}" cy="${y - 1}" r="1.5"/></g>`;
const mouth = (x, y, w = 6, c = DARK) => `<path d="M${x - w} ${y} Q${x} ${y + w * 0.9} ${x + w} ${y}" fill="none" stroke="${c}" stroke-width="2.4" stroke-linecap="round"/>`;
const fangs = (x, y) => `<path d="M${x - 7} ${y}Q${x} ${y + 6} ${x + 7} ${y}" fill="#5a1f2a"/><path d="M${x - 5} ${y + 0.5}l2 4 2-3.5M${x + 1} ${y + 0.5}l2 3.5 2-4" fill="#fff"/>`;
const blush = (x1, x2, y) => `<g fill="#ff8fa8" opacity=".45"><ellipse cx="${x1}" cy="${y}" rx="5" ry="2.8"/><ellipse cx="${x2}" cy="${y}" rx="5" ry="2.8"/></g>`;
const hi = (x, y, rx, ry) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="#fff" opacity=".35"/>`;
const crown = (x, y, s = 1) => `<g transform="translate(${x} ${y}) scale(${s})"><path d="M-14 6L-14-6-7 0 0-10 7 0 14-6 14 6Z" fill="#ffd45a" stroke="#c9961e" stroke-width="1.6" stroke-linejoin="round"/><circle cx="0" cy="-1" r="2.4" fill="#ff6b8a"/></g>`;
const star = (x, y, r, c) => { const pts = []; for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5; const rr = i % 2 ? r * 0.45 : r; pts.push(`${(x + Math.cos(a) * rr).toFixed(1)},${(y + Math.sin(a) * rr).toFixed(1)}`); } return `<polygon points="${pts.join(' ')}" fill="${c}"/>`; };
const shadow = `<ellipse cx="60" cy="112" rx="38" ry="5" fill="#000" opacity=".25"/>`;

const SHAPES = {
  slime(a, k) {
    const ang = !!a.crown;
    return shadow + `<path d="M14 108C12 66 36 36 60 36S108 66 106 108Q60 116 14 108Z" fill="${a.c}"/>
      <path d="M22 104C24 84 30 72 40 64" fill="none" stroke="${a.c2}" stroke-width="5" stroke-linecap="round" opacity=".5"/>
      <path d="M14 108Q60 116 106 108L104 100Q60 108 16 100Z" fill="${a.c2}" opacity=".6"/>
      ${hi(42, 54, 10, 6)}${eyes(48, 72, 78, 7.5, { angry: ang })}${blush(38, 82, 90)}${mouth(60, 92, 5)}
      ${a.crown ? crown(60, 34, 1.1) : ''}`;
  },
  shroom(a) {
    return shadow + `<path d="M40 112C38 92 40 74 44 66H76C80 74 82 92 80 112Z" fill="${a.c2}"/>
      <path d="M8 70C8 34 34 14 60 14S112 34 112 70Q60 80 8 70Z" fill="${a.c}"/>
      <g fill="#fff" opacity=".85"><circle cx="34" cy="44" r="7"/><circle cx="62" cy="30" r="6"/><circle cx="86" cy="46" r="8"/><circle cx="50" cy="58" r="4"/></g>
      ${eyes(51, 69, 88, 5.5, { angry: !!a.crown })}${mouth(60, 100, 4)}${blush(44, 76, 97)}
      ${a.crown ? crown(60, 12, 1) : ''}`;
  },
  snake(a) {
    if (a.worm) return shadow + `${[0, 1, 2, 3].map((i) => `<circle cx="${28 + i * 16}" cy="${96 - (i % 2) * 6}" r="${15 - i}" fill="${i % 2 ? a.c : a.c2}"/>`).join('')}
      <circle cx="88" cy="66" r="20" fill="${a.c}"/>${eyes(81, 96, 62, 5.5)}<path d="M80 76Q88 82 96 76" fill="none" stroke="${DARK}" stroke-width="2.4" stroke-linecap="round"/>
      <path d="M82 46Q78 34 72 30M94 46Q98 34 104 30" stroke="${a.c2}" stroke-width="3" fill="none" stroke-linecap="round"/>`;
    return shadow + `<path d="M20 108C10 92 22 78 44 80S84 92 92 78 86 54 70 52" fill="none" stroke="${a.c}" stroke-width="18" stroke-linecap="round"/>
      <path d="M20 108C10 92 22 78 44 80S84 92 92 78" fill="none" stroke="${a.c2}" stroke-width="5" stroke-linecap="round" stroke-dasharray="2 9" opacity=".7"/>
      <ellipse cx="62" cy="42" rx="22" ry="18" fill="${a.c}"/>${eyes(54, 70, 38, 5.5, { angry: !!a.big })}
      <path d="M62 54v8M62 62l-4 4M62 62l4 4" stroke="#ff6b8a" stroke-width="2.2" stroke-linecap="round"/>`;
  },
  wisp(a, k) {
    const g = `wg${k}`;
    return `<defs><radialGradient id="${g}"><stop offset="0" stop-color="${a.c}" stop-opacity=".9"/><stop offset="1" stop-color="${a.c}" stop-opacity="0"/></radialGradient></defs>
      <circle cx="60" cy="66" r="50" fill="url(#${g})"/>
      <path d="M60 18C70 34 88 46 88 70A28 28 0 0132 70C32 46 50 34 60 18Z" fill="${a.c}"/>
      <path d="M60 40C66 50 76 58 76 72A16 16 0 0144 72C44 58 54 50 60 40Z" fill="#fff" opacity=".45"/>
      ${a.star ? star(60, 34, 9, '#fff3b0') : ''}
      ${eyes(51, 69, 70, 5.5, { angry: !!a.big || !!a.star })}${mouth(60, 82, 4, a.c2)}`;
  },
  golem(a) {
    return shadow + `<rect x="22" y="44" width="76" height="62" rx="14" fill="${a.c}"/>
      <rect x="8" y="58" width="20" height="38" rx="9" fill="${a.c2}"/><rect x="92" y="58" width="20" height="38" rx="9" fill="${a.c2}"/>
      <rect x="34" y="20" width="52" height="38" rx="12" fill="${a.c}"/>
      <path d="M34 30Q46 14 60 22T86 28V34H34Z" fill="${a.c3}"/>
      <path d="M30 70H90M40 88H80" stroke="${a.c2}" stroke-width="3" stroke-linecap="round" opacity=".6"/>
      ${glowEyes(50, 70, 40, a.c3 === '#ffffff' ? '#9fe8ff' : '#ffe08a', 5)}
      ${a.big ? '<path d="M28 50l10 6M92 50l-10 6" stroke="#2a1f3a" stroke-width="3" stroke-linecap="round"/>' : ''}`;
  },
  rat(a) {
    return shadow + `<path d="M96 96C112 90 116 72 108 62" fill="none" stroke="${a.c2}" stroke-width="4" stroke-linecap="round"/>
      <ellipse cx="60" cy="86" rx="34" ry="24" fill="${a.c}"/>
      <circle cx="36" cy="40" r="13" fill="${a.c}"/><circle cx="84" cy="40" r="13" fill="${a.c}"/><circle cx="36" cy="40" r="7" fill="#ffc2c8"/><circle cx="84" cy="40" r="7" fill="#ffc2c8"/>
      <ellipse cx="60" cy="58" rx="28" ry="24" fill="${a.c}"/>
      <path d="M34 50H86V62H34Z" fill="${DARK}" opacity=".85"/>${eyes(48, 72, 56, 5)}
      <ellipse cx="60" cy="70" rx="5" ry="4" fill="#ff8fa8"/><path d="M48 70l-12-2M48 74l-12 2M72 70l12-2M72 74l12 2" stroke="${a.c2}" stroke-width="1.5"/>
      <path d="M78 96l14-10 4 8z" fill="#c9a26a"/>`;
  },
  hedgehog(a) {
    let spikes = '';
    for (let i = 0; i < 9; i++) { const ang = Math.PI + (i / 8) * Math.PI; const x = 60 + Math.cos(ang) * 44, y = 80 + Math.sin(ang) * 40; spikes += `<path d="M${60 + Math.cos(ang - 0.18) * 30} ${80 + Math.sin(ang - 0.18) * 28}L${x} ${y}L${60 + Math.cos(ang + 0.18) * 30} ${80 + Math.sin(ang + 0.18) * 28}Z" fill="${a.c2}"/>`; }
    return shadow + spikes + `<ellipse cx="60" cy="82" rx="38" ry="28" fill="${a.c2}"/><ellipse cx="62" cy="88" rx="28" ry="20" fill="#f3dcc0"/>
      ${eyes(52, 72, 82, 5)}<circle cx="62" cy="94" r="3" fill="${DARK}"/>${blush(44, 80, 92)}`;
  },
  spider(a) {
    let legs = '';
    for (let i = 0; i < 4; i++) { const y = 70 + i * 8; legs += `<path d="M44 ${y}Q${20 - i * 2} ${y - 18} ${8 + i * 2} ${y + 16}M76 ${y}Q${100 + i * 2} ${y - 18} ${112 - i * 2} ${y + 16}" fill="none" stroke="${a.c2}" stroke-width="4" stroke-linecap="round"/>`; }
    return shadow + `<path d="M60 0V40" stroke="#fff" stroke-width="1" opacity=".5"/>` + legs + `<ellipse cx="60" cy="74" rx="30" ry="26" fill="${a.c}"/>
      ${hi(50, 60, 9, 5)}${eyes(50, 70, 72, 6)}<g fill="${DARK}"><circle cx="42" cy="62" r="2.5"/><circle cx="78" cy="62" r="2.5"/></g>${fangs(60, 86)}`;
  },
  wolf(a) {
    return shadow + `<path d="M24 108C20 80 30 60 60 60S100 80 96 108Z" fill="${a.c}"/>
      <path d="M22 54L30 14 50 38ZM98 54L90 14 70 38Z" fill="${a.c}"/><path d="M30 26L32 44 42 38ZM90 26L88 44 78 38Z" fill="${a.c2}"/>
      <path d="M22 54C20 34 38 26 60 26S100 34 98 54C98 72 82 84 60 84S22 72 22 54Z" fill="${a.c}"/>
      <path d="M40 66C44 80 76 80 80 66C74 74 46 74 40 66Z" fill="${a.c2}"/>
      ${glowEyes(46, 74, 52, a.eye || '#ff6b8a', 6)}<ellipse cx="60" cy="66" rx="6" ry="4" fill="${a.c2}"/>${fangs(60, 72)}
      <path d="M30 96L40 86M90 96L80 86" stroke="${a.c2}" stroke-width="3" stroke-linecap="round"/>`;
  },
  tree(a) {
    return shadow + `<path d="M30 112C34 90 36 66 34 40H86C84 66 86 90 90 112Z" fill="${a.c}"/>
      <path d="M30 112L16 104M90 112l14-8M34 48L12 30M86 48l22-18" stroke="${a.c}" stroke-width="9" stroke-linecap="round"/>
      <g fill="${a.c3}"><circle cx="60" cy="24" r="26"/><circle cx="30" cy="34" r="18"/><circle cx="90" cy="34" r="18"/><circle cx="12" cy="26" r="10"/><circle cx="108" cy="26" r="10"/></g>
      <g fill="#fff" opacity=".25"><circle cx="50" cy="14" r="8"/><circle cx="24" cy="28" r="5"/></g>
      <path d="M44 60C48 64 52 64 56 60M64 60C68 64 72 64 76 60" stroke="${a.c2}" stroke-width="3" fill="none"/>
      ${glowEyes(48, 72, 70, '#ffe08a', 6)}<path d="M46 92Q60 84 74 92Q60 100 46 92Z" fill="${a.c2}"/>
      <g fill="#ff9ad6">${star(30, 40, 4, '#ff9ad6')}${star(92, 22, 4, '#ff9ad6')}</g>`;
  },
  bat(a) {
    const wing = a.moth ? `<path d="M48 64C26 34 4 40 8 64S36 90 48 74ZM72 64C94 34 116 40 112 64S84 90 72 74Z" fill="${a.c}" opacity=".9"/><g fill="${a.c2}"><circle cx="24" cy="58" r="6"/><circle cx="96" cy="58" r="6"/></g>`
      : `<path d="M46 64C30 44 12 46 4 58 14 60 16 70 12 78 22 74 30 80 32 88 38 80 46 80 50 76ZM74 64C90 44 108 46 116 58 106 60 104 70 108 78 98 74 90 80 88 88 82 80 74 80 70 76Z" fill="${a.c2}"/>`;
    return `<ellipse cx="60" cy="112" rx="22" ry="4" fill="#000" opacity=".2"/>` + wing + `<ellipse cx="60" cy="70" rx="20" ry="22" fill="${a.c}"/>
      ${a.moth ? `<path d="M52 50Q44 34 40 32M68 50Q76 34 80 32" stroke="${a.c2}" stroke-width="2.4" fill="none" stroke-linecap="round"/>` : `<path d="M44 54L46 38 54 50ZM76 54L74 38 66 50Z" fill="${a.c}"/>`}
      ${eyes(53, 67, 68, 5, { angry: !!a.big })}${a.moth ? mouth(60, 80, 3) : fangs(60, 78)}${a.crown ? crown(60, 44, 0.9) : ''}`;
  },
  crab(a) {
    return shadow + `<path d="M22 70C8 60 6 40 18 32L28 46 20 50C26 58 30 62 34 66ZM98 70C112 60 114 40 102 32L92 46 100 50C94 58 90 62 86 66Z" fill="${a.c}"/>
      <path d="M30 100L16 112M40 104l-8 10M90 100l14 12M80 104l8 10" stroke="${a.c2}" stroke-width="4" stroke-linecap="round"/>
      <ellipse cx="60" cy="84" rx="36" ry="24" fill="${a.c}"/><path d="M28 80Q60 66 92 80" fill="none" stroke="${a.c2}" stroke-width="3" opacity=".6"/>
      <path d="M48 64V50M72 64V50" stroke="${a.c}" stroke-width="5"/>${eyes(48, 72, 48, 6)}${mouth(60, 92, 6)}`;
  },
  lizard(a) {
    return shadow + `<path d="M84 96C100 96 112 86 112 74" fill="none" stroke="${a.c}" stroke-width="10" stroke-linecap="round"/>
      <path d="M108 66C114 56 112 48 106 44C108 52 104 56 100 58Z" fill="#ffcf5a"/>
      <ellipse cx="60" cy="88" rx="32" ry="20" fill="${a.c}"/><ellipse cx="60" cy="94" rx="20" ry="10" fill="#ffe0b0"/>
      <ellipse cx="44" cy="62" rx="22" ry="18" fill="${a.c}"/>${eyes(38, 54, 58, 5.5)}${mouth(46, 70, 5)}
      <path d="M58 46l6-6 2 8 6-4" fill="none" stroke="${a.c2}" stroke-width="3" stroke-linecap="round"/>`;
  },
  ghost(a) {
    return `<ellipse cx="60" cy="112" rx="26" ry="4" fill="#000" opacity=".18"/><path d="M24 104V56C24 32 40 18 60 18S96 32 96 56V104L86 96 76 106 66 96 56 106 46 96 36 106Z" fill="${a.c}" opacity=".92"/>
      ${hi(46, 38, 10, 6)}${eyes(48, 72, 58, 6.5, { white: a.c2, pupil: DARK })}<ellipse cx="60" cy="76" rx="5" ry="6" fill="${DARK}"/>${blush(40, 80, 68)}`;
  },
  mimic(a) {
    return shadow + `<rect x="16" y="64" width="88" height="44" rx="6" fill="${a.c2}"/><rect x="16" y="64" width="88" height="10" fill="${a.c}"/>
      <path d="M16 62C16 34 30 22 60 22S104 34 104 62Z" fill="${a.c}"/><path d="M18 50H102" stroke="${a.c2}" stroke-width="4"/>
      <path d="M22 64L28 74 34 64 40 74 46 64 52 74 58 64 64 74 70 64 76 74 82 64 88 74 94 64 100 74" fill="#fff" stroke="#fff" stroke-width="1" stroke-linejoin="round"/>
      <path d="M56 84H64V96H56Z" fill="#ffcf5a"/><path d="M60 20L68 30 60 40 52 30Z" fill="${a.gem}"/>
      ${glowEyes(42, 78, 42, '#ff6b8a', 5)}<path d="M30 74Q44 90 60 80T90 74" fill="none" stroke="#ff6b8a" stroke-width="5" stroke-linecap="round"/>`;
  },
  skeleton(a) {
    return shadow + `<path d="M40 108V84H80V108" fill="none" stroke="${a.c}" stroke-width="8" stroke-linecap="round"/>
      <path d="M44 88H76M44 98H76" stroke="${a.c2}" stroke-width="3"/>
      <path d="M32 50C32 30 44 18 60 18S88 30 88 50C88 62 80 68 76 70V80H44V70C40 68 32 62 32 50Z" fill="${a.c}"/>
      <g fill="${DARK}"><ellipse cx="48" cy="50" rx="8" ry="9"/><ellipse cx="72" cy="50" rx="8" ry="9"/><path d="M58 60L62 60 60 66Z"/></g>
      <g fill="#ffe08a"><circle cx="48" cy="52" r="3"/><circle cx="72" cy="52" r="3"/></g><path d="M48 74V80M54 74V80M60 74V80M66 74V80M72 74V80" stroke="${a.c2}" stroke-width="2"/>
      <path d="M28 32C30 14 90 14 92 32Z" fill="${a.hat}"/><rect x="24" y="30" width="72" height="6" rx="3" fill="${a.hat}"/><circle cx="60" cy="24" r="5" fill="#fff8d0"/>`;
  },
  jelly(a, k) {
    if (a.tapir) return shadow + `<ellipse cx="60" cy="84" rx="40" ry="24" fill="${a.c}"/><path d="M24 76C10 74 6 86 12 94" fill="none" stroke="${a.c}" stroke-width="12" stroke-linecap="round"/>
      <path d="M30 104V112M50 106V114M70 106V114M90 104V112" stroke="${a.c2}" stroke-width="8" stroke-linecap="round"/>
      ${star(80, 60, 6, '#fff3b0')}${star(96, 74, 4, '#fff3b0')}${eyes(38, 54, 74, 5)}<path d="M20 92Q16 98 20 102" stroke="${a.c2}" stroke-width="3" fill="none"/>`;
    let t = '';
    for (let i = 0; i < 5; i++) t += `<path d="M${36 + i * 12} 74Q${30 + i * 12} 92 ${38 + i * 12} 110" fill="none" stroke="${a.c}" stroke-width="5" stroke-linecap="round" opacity=".8"/>`;
    return t + `<path d="M20 74C20 44 38 26 60 26S100 44 100 74Q80 80 60 74T20 74Z" fill="${a.c}" opacity=".92"/>${hi(44, 42, 10, 6)}
      ${eyes(50, 70, 56, 5.5)}${mouth(60, 66, 4, a.c2)}${blush(40, 80, 64)}`;
  },
  knight(a) {
    const op = a.ghost ? 0.78 : 1;
    return shadow + `<g opacity="${op}"><path d="M26 112C26 84 40 70 60 70S94 84 94 112Z" fill="${a.c2}"/>
      <path d="M40 112C40 92 48 82 60 82S80 92 80 112Z" fill="${a.c}"/>
      <ellipse cx="30" cy="80" rx="14" ry="10" fill="${a.c}"/><ellipse cx="90" cy="80" rx="14" ry="10" fill="${a.c}"/>
      <path d="M34 56C34 30 46 18 60 18S86 30 86 56V70H34Z" fill="${a.c}"/>
      <path d="M40 46H80V54H40Z" fill="${DARK}"/><path d="M60 40V66" stroke="${a.c2}" stroke-width="3"/>
      <path d="M60 18C66 6 80 4 90 10 80 12 72 18 68 26Z" fill="${a.plume}"/>
      ${glowEyes(50, 70, 50, a.ghost ? '#9fb0ff' : '#ffe08a', 4)}
      ${a.clock ? `<circle cx="60" cy="96" r="10" fill="#fff3d0" stroke="${a.c2}" stroke-width="2"/><path d="M60 96V89M60 96l5 3" stroke="${DARK}" stroke-width="2" stroke-linecap="round"/>` : ''}
      <path d="M104 40V100" stroke="#e0e6f0" stroke-width="5" stroke-linecap="round"/><path d="M96 92H112" stroke="${a.c2}" stroke-width="5" stroke-linecap="round"/></g>`;
  },
  queen(a, k) {
    const g = `qg${k}`;
    return `<defs><linearGradient id="${g}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${a.c}"/><stop offset="1" stop-color="${a.c2}"/></linearGradient></defs>` + shadow +
      `<path d="M28 112L42 66H78L92 112Z" fill="url(#${g})"/><path d="M42 66L60 112 78 66" fill="#fff" opacity=".15"/>
      <path d="M20 70L34 56 46 74ZM100 70L86 56 74 74Z" fill="${a.c3}" opacity=".85"/>
      <circle cx="60" cy="44" r="20" fill="${a.shade ? '#3a2f6a' : '#ffe7f0'}"/>
      <path d="M38 46C38 24 50 16 60 16S82 24 82 46L86 66 74 56 60 60 46 56 34 66Z" fill="${a.c2}"/>
      <path d="M44 20L48 4 56 14 60 0 64 14 72 4 76 20Z" fill="${a.c3}" stroke="#fff" stroke-width="1.5" stroke-linejoin="round"/>
      ${a.shade ? glowEyes(52, 68, 46, a.c3, 4) : eyes(52, 68, 46, 4.5, { angry: true, pupil: a.c2 })}
      ${a.shade ? '' : `<path d="M56 54Q60 57 64 54" fill="none" stroke="#c4566a" stroke-width="2" stroke-linecap="round"/>`}
      <g>${star(22, 30, 5, a.c3)}${star(100, 26, 6, a.c3)}${star(104, 90, 4, '#fff')}</g>`;
  },
  book(a) {
    return `<ellipse cx="60" cy="112" rx="26" ry="4" fill="#000" opacity=".2"/>
      <path d="M8 46C20 40 34 40 46 48 34 50 22 56 14 64ZM112 46C100 40 86 40 74 48 86 50 98 56 106 64Z" fill="${a.c2}" opacity=".8"/>
      <path d="M18 40L60 50 102 40V92L60 102 18 92Z" fill="${a.c}"/><path d="M24 44L58 53V96L24 88ZM96 44L62 53V96L96 88Z" fill="${a.c2}"/>
      <path d="M30 60L52 65M30 70L52 75M68 65L90 60M68 75L90 70" stroke="${a.c}" stroke-width="2" opacity=".5"/>
      ${a.eye ? `<ellipse cx="60" cy="74" rx="14" ry="10" fill="#fff"/><circle cx="60" cy="74" r="7" fill="#ff6b8a"/><circle cx="60" cy="74" r="3" fill="${DARK}"/>` : `${eyes(42, 78, 72, 5.5)}${mouth(60, 86, 4)}`}`;
  },
  candle(a) {
    return shadow + `<path d="M34 108L38 52H82L86 108Z" fill="${a.c}"/><path d="M38 52C46 60 50 52 56 60S70 52 82 52" fill="${a.c}" stroke="#fff" stroke-width="2"/>
      <path d="M60 46V40" stroke="${DARK}" stroke-width="2"/>
      <path d="M60 8C68 20 74 28 74 36A14 14 0 0146 36C46 28 52 20 60 8Z" fill="${a.c2}"/><path d="M60 20C64 26 66 30 66 36A6 6 0 0154 36C54 30 56 26 60 20Z" fill="#fff3b0"/>
      ${eyes(50, 70, 76, 5.5)}${mouth(60, 88, 4)}${blush(44, 76, 86)}`;
  },
  gargoyle(a) {
    return shadow + `<path d="M30 66C12 50 4 30 10 18 18 30 28 34 38 40ZM90 66C108 50 116 30 110 18 102 30 92 34 82 40Z" fill="${a.c2}"/>
      <path d="M28 112C26 88 36 72 60 72S94 88 92 112Z" fill="${a.c}"/>
      <path d="M36 50L30 24 46 38ZM84 50L90 24 74 38Z" fill="${a.c2}"/>
      <ellipse cx="60" cy="54" rx="26" ry="22" fill="${a.c}"/>${glowEyes(50, 70, 50, '#ff9a4c', 5)}${fangs(60, 64)}
      <path d="M40 90L50 100M80 90L70 100" stroke="${a.c2}" stroke-width="3" stroke-linecap="round"/>`;
  },
  librarian(a, k) {
    return shadow + `<path d="M24 112L36 60H84L96 112Z" fill="${a.c}"/>
      <path d="M36 60L60 112 84 60" fill="${a.c2}" opacity=".25"/>
      <rect x="64" y="70" width="34" height="26" rx="3" fill="${a.c3}" transform="rotate(-12 80 82)"/><path d="M80 70V96" stroke="#fff" stroke-width="2" transform="rotate(-12 80 82)"/>
      <circle cx="60" cy="42" r="20" fill="#f3ecff"/>
      <path d="M36 50C34 22 48 12 60 12S86 22 84 50L90 74 76 60H44L30 74Z" fill="${a.c2}"/>
      <g fill="none" stroke="${a.c}" stroke-width="2.4"><circle cx="52" cy="44" r="6"/><circle cx="68" cy="44" r="6"/><path d="M58 44H62"/></g>
      ${glowEyes(52, 68, 44, a.c3, 3)}<path d="M55 54Q60 52 65 54" stroke="${a.c}" stroke-width="2" fill="none" stroke-linecap="round"/>
      <g fill="${a.c3}" opacity=".8">${star(20, 40, 4, a.c3)}${star(104, 34, 5, a.c3)}</g>`;
  },
  rabbit(a) {
    return shadow + `<path d="M42 40C36 18 38 2 46 2S56 20 54 40ZM78 40C84 18 82 2 74 2S64 20 66 40Z" fill="${a.c}"/><path d="M45 34C42 20 43 10 46 10S50 20 50 34ZM75 34C78 20 77 10 74 10S70 20 70 34Z" fill="#ffc2d6"/>
      <path d="M28 112C28 88 40 76 60 76S92 88 92 112Z" fill="${a.armor}"/><path d="M48 80H72V112H48Z" fill="${a.c2}" opacity=".5"/>
      <ellipse cx="60" cy="56" rx="26" ry="24" fill="${a.c}"/>${eyes(50, 70, 56, 5.5, { pupil: '#c4566a' })}<path d="M57 66L60 68 63 66" fill="none" stroke="${DARK}" stroke-width="2"/>${blush(42, 78, 64)}
      <path d="M100 30V104" stroke="#ffe08a" stroke-width="4" stroke-linecap="round"/><path d="M100 24C96 30 96 34 100 38 104 34 104 30 100 24Z" fill="#ffe08a"/>`;
  },
  eye(a, k) {
    const g = `eg${k}`;
    let tent = '';
    for (let i = 0; i < 6; i++) { const ang = (i / 6) * Math.PI * 2; tent += `<path d="M${60 + Math.cos(ang) * 26} ${64 + Math.sin(ang) * 26}Q${60 + Math.cos(ang + 0.4) * 44} ${64 + Math.sin(ang + 0.4) * 44} ${60 + Math.cos(ang) * 50} ${64 + Math.sin(ang) * 50}" fill="none" stroke="${a.c}" stroke-width="6" stroke-linecap="round"/>`; }
    return `<defs><radialGradient id="${g}"><stop offset=".55" stop-color="${a.c2}"/><stop offset="1" stop-color="${a.c}"/></radialGradient></defs>` + tent +
      `<circle cx="60" cy="64" r="30" fill="${a.c}"/><circle cx="60" cy="64" r="24" fill="#fff"/><circle cx="60" cy="66" r="14" fill="url(#${g})"/><circle cx="60" cy="66" r="6" fill="${DARK}"/><circle cx="54" cy="60" r="3.5" fill="#fff"/>`;
  },
  nox(a, k) {
    const g = `ng${k}`;
    return `<defs><linearGradient id="${g}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${a.c}"/><stop offset="1" stop-color="#0a0718"/></linearGradient></defs>` + shadow +
      `<path d="M6 60C20 40 40 50 44 66 30 62 18 70 14 86ZM114 60C100 40 80 50 76 66 90 62 102 70 106 86Z" fill="${a.c}" opacity=".85"/>
      <path d="M22 114L40 64H80L98 114Z" fill="url(#${g})"/>${star(44, 96, 3, '#fff')}${star(74, 88, 2.5, '#fff')}${star(60, 104, 2, '#fff')}
      <path d="M48 66L60 80 72 66" fill="${a.c3}" opacity=".7"/>
      <path d="M32 60C28 26 44 12 60 12S92 26 88 60L94 96 80 70H40L26 96Z" fill="${a.c}"/>
      <circle cx="60" cy="44" r="18" fill="#efe6ff"/>
      <path d="M42 40C44 24 52 20 60 20S76 24 78 40C72 32 66 30 60 32 54 30 48 32 42 40Z" fill="${a.c}"/>
      ${eyes(53, 67, 46, 4.2, { angry: true, pupil: a.c3 })}<path d="M56 54Q60 56 64 54" fill="none" stroke="#c4566a" stroke-width="2" stroke-linecap="round"/>
      <path d="M44 14A20 20 0 0076 14 16 16 0 0144 14Z" fill="${a.c2}" transform="translate(0 -4)"/>${star(60, 2, 4, '#fff3b0')}`;
  },
};

export function monsterSVG(art, cls = '') {
  const fn = SHAPES[art.s] || SHAPES.slime;
  const k = ++uid;
  return `<svg class="mon ${cls}" viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">${fn(art, k)}</svg>`;
}
