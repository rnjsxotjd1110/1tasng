// 24×24 아이콘 세트. currentColor 로 칠하고 o() 는 반투명 보조색이에요.
const o = (d, a = 0.45) => `<path d="${d}" opacity="${a}"/>`;
const p = (d) => `<path d="${d}"/>`;
const c = (x, y, r, a) => `<circle cx="${x}" cy="${y}" r="${r}"${a ? ` opacity="${a}"` : ''}/>`;
const s = (d, w = 2) => `<path d="${d}" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;

const SWORD = p('M20.5 2.5L21.5 3.5 21 6 11.3 15.7 8.3 12.7 18 3z') + o('M18 3l2.5-.5.5.5-.5 2.5-8 8-2-2z', 0.35) + p('M5.6 12.2l6.2 6.2-1.4 1.4-1.5-1.5-3 3-1.8-1.8 3-3-1.5-1.5z');
const SHIELD = p('M12 2l8.5 3.2v6.1c0 5.1-3.6 9.2-8.5 10.7C7.1 20.5 3.5 16.4 3.5 11.3V5.2z') + o('M12 4.4v15.4c3.6-1.4 6.1-4.6 6.1-8.5V6.7z', 0.3);
const STAR = p('M12 2.2l2.9 6 6.6.8-4.9 4.5 1.3 6.5L12 16.8 6.1 20l1.3-6.5L2.5 9l6.6-.8z');
const FIRE = p('M12 2c1 3.5 5.5 5.6 5.5 11a5.5 5.5 0 01-11 0c0-2.6 1.3-4.3 2.4-5.6.3 1.7 1 2.8 2.1 3.3C10.3 7.6 11 4.6 12 2z') + o('M12 12c1.3 1.5 2.6 2.4 2.6 4.3a2.6 2.6 0 01-5.2 0c0-1.6 1.2-2.6 2.6-4.3z', 0.55);
const SNOW = s('M12 2.5v19M3.8 7.2l16.4 9.6M3.8 16.8l16.4-9.6M9.5 3.8L12 6.2l2.5-2.4M9.5 20.2L12 17.8l2.5 2.4', 2);
const DROP = p('M12 2.5c3.2 4.4 6.5 8.3 6.5 12a6.5 6.5 0 01-13 0c0-3.7 3.3-7.6 6.5-12z') + o('M9 14.5a3 3 0 003 3', 0.5);
const HEART = p('M12 21s-8.5-5.2-8.5-11.2A4.8 4.8 0 0112 6.6a4.8 4.8 0 018.5 3.2C20.5 15.8 12 21 12 21z') + o('M7.5 7.5a2.5 2.5 0 00-2 2.5', 0.5);
const COIN = c(12, 12, 9.5) + `<circle cx="12" cy="12" r="6.5" fill="none" stroke="#000" stroke-opacity=".25" stroke-width="1.6"/>` + o('M10.6 8.5h2.8v7h-2.8z', 0.35);
const MOON = p('M15.5 2.8A9.5 9.5 0 1021.2 15 7.6 7.6 0 0115.5 2.8z');
const CARD = p('M6 2.5h9.5a2 2 0 012 2v15a2 2 0 01-2 2H6a2 2 0 01-2-2v-15a2 2 0 012-2z') + o('M10.75 7.5l2.6 4-2.6 4-2.6-4z', 0.5);
const FLASK = p('M9 2.5h6v1.8h-1v4.6l5.2 9.1A2.3 2.3 0 0117.2 21.5H6.8a2.3 2.3 0 01-2-3.5L10 8.9V4.3H9z') + o('M7.4 15h9.2l1.6 2.9a.9.9 0 01-.8 1.3H6.6a.9.9 0 01-.8-1.3z', 0.5);
const POTION = p('M10 2.5h4v2h-.5v3.1a7 7 0 11-3 0V4.5H10z') + o('M6.4 13.5h11.2a5.6 5.6 0 01-11.2 0z', 0.5);
const BOOK = p('M4 4.5A2.5 2.5 0 016.5 2H20v16.5H6.5a1.5 1.5 0 000 3H20V23H6.5A2.5 2.5 0 014 20.5z') + o('M8 6h8v2H8z', 0.4);
const DIE = p('M6 3h12a3 3 0 013 3v12a3 3 0 01-3 3H6a3 3 0 01-3-3V6a3 3 0 013-3z') + `<g fill="#000" fill-opacity=".35">${c(8, 8, 1.6)}${c(16, 16, 1.6)}${c(12, 12, 1.6)}${c(16, 8, 1.6)}${c(8, 16, 1.6)}</g>`;
const CRYSTAL = p('M12 1.5l6 6.5-6 14.5L6 8z') + o('M12 1.5L9 8h6z M9 8l3 14.5V8z', 0.4);
const CYCLE = s('M19.5 9A8 8 0 006 6.3M4.5 15a8 8 0 0013.5 2.7') + p('M5.2 2.8l.9 4.9 4.8-1.2z M18.8 21.2l-.9-4.9-4.8 1.2z');
const BOOM = p('M12 1.5l2.3 5.3 5.4-2-1.6 5.5 4.4 2.2-4.8 2.4 1.3 5.6-5.2-2.6L12 22.5l-1.8-4.6L5 20.5l1.3-5.6L1.5 12.5l4.4-2.2-1.6-5.5 5.4 2z');
const FANG = p('M4 3h16c0 4-2 6-4 7l-2 11-2-6-2 6-2-11C6 9 4 7 4 3z');
const RING = `<circle cx="12" cy="14" r="6.5" fill="none" stroke="currentColor" stroke-width="2.6"/>` + p('M12 2l3.2 3.4L12 8.8 8.8 5.4z');
const CROWN = p('M3 7l4.5 4L12 4l4.5 7L21 7l-1.8 12H4.8z') + o('M4.8 19h14.4v2H4.8z', 0.6);
const LEAF = p('M20.5 3.5C8 3.5 3.5 9 3.5 15c0 2 .6 3.7 1.6 5.2C7 14 11 10.5 16 8.5c-4.4 2.6-7.7 6.4-9.3 11.6 1.3.6 2.8.9 4.3.9 6 0 9.5-6 9.5-17.5z');
const EYE = p('M12 5C6.5 5 2.6 9.2 1.5 12c1.1 2.8 5 7 10.5 7s9.4-4.2 10.5-7C21.4 9.2 17.5 5 12 5z') + `<circle cx="12" cy="12" r="3.6" fill="#000" fill-opacity=".4"/>`;
const ARROW_UP = p('M12 3l7 8h-4.3v9.5H9.3V11H5z');
const ARROW_DN = p('M12 21l-7-8h4.3V3.5h5.4V13H19z');
const PLUS = p('M10 4h4v6h6v4h-6v6h-4v-6H4v-4h6z');

export const ICONS = {
  sword: SWORD,
  sword2: SWORD + `<g transform="translate(24 0) scale(-1 1)" opacity=".55">${SWORD}</g>`,
  starsword: SWORD + `<g transform="translate(13 13) scale(.45)">${STAR}</g>`,
  dagger: p('M14 3.5l5.5-1-1 5.5-7.2 7.2-4.5-4.5z') + p('M5.3 11.2l7.5 7.5-1.4 1.4-1.6-1.6-2.4 2.4-1.9-1.9 2.4-2.4-1.6-1.6z'),
  spear: s('M4 20L18 6', 2.4) + p('M15.5 3.5L21 3l-.5 5.5-3.6-1.4z'),
  axe: s('M6 21L16 6', 2.4) + p('M12.5 3.5c3.5-.8 7 .8 8.5 4-2.2 1.8-5 2.3-7.7 1.6z'),
  hammer: s('M5 20l9-9', 3) + p('M11.5 3.5l5-1.5 5.5 5.5-1.5 5-3.5-3.5-1.5 1.5-2.5-2.5 1.5-1.5z'),
  shield: SHIELD,
  shield2: SHIELD + `<g fill="#fff" fill-opacity=".85" transform="translate(6.5 6) scale(.46)">${STAR}</g>`,
  armor: p('M7 3l2.5 2h5L17 3l4 3-2 5v9.5a1.5 1.5 0 01-1.5 1.5h-11A1.5 1.5 0 015 20.5V11L3 6z') + o('M9.5 5h5v6h-5z', 0.4),
  castle: p('M3 21V8h3V5h3v3h2V3h2v5h2V5h3v3h3v13h-7v-5a2 2 0 00-4 0v5z'),
  horn: p('M3 10h3l11-6v16L6 14H3z') + o('M19 8a5 5 0 010 8', 0.6),
  thorns: p('M12 1.5l2 5.5 5.5-2-2 5.5L23 12l-5.5 1.5 2 5.5-5.5-2-2 5.5-2-5.5-5.5 2 2-5.5L1 12l5.5-1.5-2-5.5 5.5 2z') + c(12, 12, 3.5, 0.4),
  fist: p('M6 9a2 2 0 014 0V8a2 2 0 014 0v.5a2 2 0 014 0V14c0 4-3 7.5-7 7.5S5 18.5 5 15v-3.5a2 2 0 011-2.5z'),
  heal: HEART + p('M11 10h2v2h2v2h-2v2h-2v-2H9v-2h2z'),
  heart: HEART,
  whirl: s('M12 4a8 8 0 107.5 10.5M12 8a4 4 0 103.8 5.2', 2.2) + p('M17 2.5l3.5 3-4 2.2z'),
  blood: DROP,
  drop: DROP,
  holy: c(12, 12, 4.5) + s('M12 1.5v3.5M12 19v3.5M1.5 12H5M19 12h3.5M4.6 4.6l2.5 2.5M16.9 16.9l2.5 2.5M4.6 19.4l2.5-2.5M16.9 7.1l2.5-2.5', 2),
  orb: c(12, 12, 9) + c(8.5, 8.5, 2.6, 0.5),
  frost: SNOW, snow: SNOW,
  fire: FIRE, burn: FIRE,
  ice: CRYSTAL,
  crystal: CRYSTAL,
  cycle: CYCLE,
  flip: p('M8 2l5 6H9.6v6H6.4V8H3z') + p('M16 22l-5-6h3.4v-6h3.2v6H21z'),
  plus: PLUS,
  split: s('M12 21v-7M12 14L5 6M12 14l7-8', 2.6) + c(5, 5, 2.5) + c(19, 5, 2.5),
  boom: BOOM,
  meteor: c(15.5, 8.5, 5.5) + o('M11.5 12.5L3 21M9.5 9.5L4 13M14 15l-3.5 6', 0) + s('M11.5 12.5L3 21M9.8 9.6L5 12M14.2 14.6L11 20', 2),
  comet: STAR + s('M7 15L2 21', 2.2),
  bolt: p('M13.5 1.5L4.5 13.5H11l-1.5 9 9-12H12z'),
  moon: MOON,
  mirror: `<ellipse cx="12" cy="9" rx="6.5" ry="7.5"/>` + p('M10.8 16h2.4v6.5h-2.4z') + `<ellipse cx="10" cy="7" rx="2" ry="3" fill="#fff" fill-opacity=".45"/>`,
  chain: `<g fill="none" stroke="currentColor" stroke-width="2.4"><rect x="2" y="8.5" width="11" height="7" rx="3.5" transform="rotate(-30 7.5 12)"/><rect x="11" y="8.5" width="11" height="7" rx="3.5" transform="rotate(-30 16.5 12)"/></g>`,
  card: CARD,
  cardback: p('M6 2.5h12a2 2 0 012 2v15a2 2 0 01-2 2H6a2 2 0 01-2-2v-15a2 2 0 012-2z') + `<path d="M7 5.5h10v13H7z" fill="#000" fill-opacity=".2"/>`,
  cards: o('M3 6.3l7.8-2.1 3.6 13.5-7.8 2.1z', 0.45) + p('M10 4.5h8a2 2 0 012 2v13a2 2 0 01-2 2h-8a2 2 0 01-2-2v-13a2 2 0 012-2z'),
  ace: CARD + `<path d="M10.75 6l3 7h-1.6l-.5-1.4h-1.8l-.5 1.4H7.75z" fill="#000" fill-opacity=".4"/>`,
  joker: CARD + `<circle cx="10.75" cy="11" r="3" fill="#000" fill-opacity=".3"/>`,
  seven: p('M5 3h14v3.2L11.8 21H7.9l6.9-14.8H5z'),
  coin: COIN, gold: COIN,
  chips: `<ellipse cx="12" cy="17" rx="8" ry="3.5"/><ellipse cx="12" cy="12.5" rx="8" ry="3.5" opacity=".75"/><ellipse cx="12" cy="8" rx="8" ry="3.5" opacity=".55"/>`,
  clover: c(8.5, 8.5, 4) + c(15.5, 8.5, 4) + c(8.5, 15.5, 4) + c(15.5, 15.5, 4) + c(12, 12, 2.5, 0.5),
  mask: p('M2 8c3-1.5 6.5-1.5 10 0 3.5-1.5 7-1.5 10 0-.3 5-3 8-6 8-2 0-3.2-1.5-4-3-.8 1.5-2 3-4 3-3 0-5.7-3-6-8z') + `<g fill="#000" fill-opacity=".45"><ellipse cx="7.5" cy="11" rx="2.2" ry="1.4"/><ellipse cx="16.5" cy="11" rx="2.2" ry="1.4"/></g>`,
  roulette: c(12, 12, 9.5) + `<g fill="#000" fill-opacity=".3"><path d="M12 2.5v9.5L5.3 5.3A9.5 9.5 0 0112 2.5z"/><path d="M12 12l9.5 0a9.5 9.5 0 01-2.8 6.7z"/><path d="M12 12l-6.7 6.7A9.5 9.5 0 012.5 12z"/></g>` + c(12, 12, 2),
  poison: p('M12 2.5c3.2 4.4 6.5 8.3 6.5 12a6.5 6.5 0 01-13 0c0-3.7 3.3-7.6 6.5-12z') + `<g fill="#000" fill-opacity=".35">${c(10, 15, 1.4)}${c(14, 15, 1.4)}<path d="M10 18.5h4v1h-4z"/></g>`,
  flask: FLASK, catalyst: FLASK + `<g transform="translate(14 1) scale(.38)">${STAR}</g>`,
  potion: POTION,
  leaf: LEAF, regen: LEAF,
  fog: s('M3 8h12M7 12h14M3 16h12M9 20h10', 2.4),
  rain: p('M7 13a4.5 4.5 0 01.6-9 6 6 0 0111 1.8A3.6 3.6 0 0118 13z') + s('M8 16.5l-1 3M12.5 16.5l-1 3M17 16.5l-1 3', 2),
  homun: c(12, 6.5, 4) + p('M5 22c0-5 3-8.5 7-8.5s7 3.5 7 8.5z') + `<g fill="#000" fill-opacity=".4">${c(10.5, 6, 1)}${c(13.5, 6, 1)}</g>`,
  stone: p('M12 2l8 7-8 13L4 9z') + o('M4 9h16L12 2z', 0.35),
  wind: s('M3 8h11a3 3 0 10-3-3M3 12h15a3 3 0 11-3 3M3 16h7', 2.2),
  eye: EYE,
  star: STAR, sparkle: p('M12 2l2 7.5L21.5 12 14 14.5 12 22l-2-7.5L2.5 12 10 9.5z'),
  twinstar: `<g transform="translate(-1 1) scale(.62)">${STAR}</g><g transform="translate(9 7) scale(.62)" opacity=".7">${STAR}</g>`,
  constel: s('M4 18L9 9l6 4 5-8', 1.6) + c(4, 18, 2.2) + c(9, 9, 2.2) + c(15, 13, 2.2) + c(20, 5, 2.2),
  book: BOOK, codex: BOOK,
  die: DIE,
  bag: p('M8 7V6a4 4 0 018 0v1h3l1 14H4L5 7z') + o('M9.5 7V6a2.5 2.5 0 015 0v1z', 0),
  pebble: `<ellipse cx="12" cy="13.5" rx="9" ry="7"/>` + `<ellipse cx="9" cy="11" rx="3" ry="1.8" fill="#fff" fill-opacity=".5"/>`,
  charm: p('M12 2l2.5 3h3.5v3.5L21 11l-3 2.5V17h-3.5L12 20l-2.5-3H6v-3.5L3 11l3-2.5V5h3.5z') + c(12, 11, 3, 0.4),
  lantern: p('M9 2h6v2h1.5v2H18l-1 12h1v2H6v-2h1L6 6h1.5V4H9z') + `<ellipse cx="12" cy="12" rx="3" ry="4" fill="#fff" fill-opacity=".55"/>`,
  pouch: p('M8 5l1.5-2.5h5L16 5l-1.5 1.5c4 2 6.5 5.5 6.5 9 0 3.5-3 6-9 6s-9-2.5-9-6c0-3.5 2.5-7 6.5-9z'),
  glove: p('M7 22V11L5 6.5a1.5 1.5 0 012.7-1.3L9 8V3.5a1.5 1.5 0 013 0V8V3a1.5 1.5 0 013 0v5V4.5a1.5 1.5 0 013 0V15c0 4-2.5 7-6 7z'),
  jar: p('M8 2h8v3h-.8l2.8 3.5V20a2 2 0 01-2 2H8a2 2 0 01-2-2V8.5L8.8 5H8z') + `<g fill="#fff" fill-opacity=".55" transform="translate(8 10) scale(.33)">${STAR}</g>`,
  quill: p('M21 2.5C13 3.5 7.5 9 6 16l-2.5 5.5 1 1L8 18c7-1.5 12.5-7.5 13-15.5z') + o('M6 16l9-9', 0),
  bell: p('M12 2.5a1.5 1.5 0 011.5 1.5v.7A6.5 6.5 0 0118.5 11v5l2 2.5h-17l2-2.5v-5a6.5 6.5 0 015-6.3V4A1.5 1.5 0 0112 2.5z') + c(12, 20.5, 2),
  petal: p('M12 21C6 18 3.5 12.5 6 7c2.5-4 6-4.5 6-4.5S15.5 3 18 7c2.5 5.5 0 11-6 14z') + o('M12 5v15', 0),
  compass: c(12, 12, 9.5, 0.45) + p('M15.5 8.5l-2 5.5-5 1.5 2-5.5z'),
  bandage: `<rect x="1.5" y="8" width="21" height="8" rx="4" transform="rotate(-35 12 12)"/>` + `<g fill="#000" fill-opacity=".3">${c(10.6, 12.5, 0.9)}${c(13.4, 11.5, 0.9)}${c(12, 10.4, 0.9)}${c(12, 13.6, 0.9)}</g>`,
  map: p('M2.5 5l6-2.5 7 2.5 6-2.5v16.5l-6 2.5-7-2.5-6 2.5z') + o('M8.5 2.5v16.5M15.5 5v16.5', 0) + `<path d="M8.5 2.5v16.5M15.5 5v16.5" stroke="#000" stroke-opacity=".25" stroke-width="1.4"/>`,
  cup: p('M5 3h14l-1.5 7a5.5 5.5 0 01-11 0z') + p('M10.8 15h2.4v4h3.3v2.5h-9V19h3.3z'),
  tear: DROP,
  hat: p('M12 1.5l5 10.5c2.5.5 5.5 1.7 5.5 3.5 0 2.2-4.7 4-10.5 4S1.5 17.7 1.5 15.5c0-1.8 3-3 5.5-3.5z') + o('M7 12c3 1 7 1 10 0l.8 1.8c-3.5 1.2-8 1.2-11.6 0z', 0.5),
  watch: c(12, 13, 8.5) + `<path d="M12 8.5V13l3 2" stroke="#000" stroke-opacity=".45" stroke-width="2" fill="none" stroke-linecap="round"/>` + p('M10 1.5h4v3h-4z'),
  feather: p('M20 3C11 3 5 9 4.5 18.5L3 21.5 4 22l2-3c9 0 14-6.5 14-16z'),
  crown: CROWN,
  thread: s('M5 19c3-10 12-4 14-14', 2.2) + c(5, 19, 2.6) + c(19, 5, 2.6),
  hourglass: p('M5 2h14v3c0 3-2.5 5.2-4.5 7 2 1.8 4.5 4 4.5 7v3H5v-3c0-3 2.5-5.2 4.5-7C7.5 10.2 5 8 5 5z') + o('M8 19.5c0-2 2-3.6 4-4.5 2 .9 4 2.5 4 4.5z', 0.6),
  cat: p('M4 3l4 4.5h8L20 3v10c0 4.5-3.6 8-8 8s-8-3.5-8-8z') + `<g fill="#000" fill-opacity=".4">${c(9, 12, 1.4)}${c(15, 12, 1.4)}<path d="M11 15h2l-1 1.2z"/></g>`,
  phoenix: p('M12 22c-1-3-4-4-6-7 2 .5 3.5 0 4-1C6 12 3 8 3 3c3 3 6 3.5 8 6 0-2.5.5-5 1-7 .5 2 1 4.5 1 7 2-2.5 5-3 8-6 0 5-3 9-7 11 .5 1 2 1.5 4 1-2 3-5 4-6 7z'),
  cog: p('M10.5 1.5h3l.5 2.8 2 .8 2.3-1.6 2.1 2.1-1.6 2.3.8 2 2.8.5v3l-2.8.5-.8 2 1.6 2.3-2.1 2.1-2.3-1.6-2 .8-.5 2.8h-3l-.5-2.8-2-.8-2.3 1.6-2.1-2.1 1.6-2.3-.8-2-2.8-.5v-3l2.8-.5.8-2-1.6-2.3 2.1-2.1 2.3 1.6 2-.8z') + `<circle cx="12" cy="12" r="3.5" fill="#000" fill-opacity=".35"/>`,
  gear: p('M10.5 1.5h3l.5 2.8 2 .8 2.3-1.6 2.1 2.1-1.6 2.3.8 2 2.8.5v3l-2.8.5-.8 2 1.6 2.3-2.1 2.1-2.3-1.6-2 .8-.5 2.8h-3l-.5-2.8-2-.8-2.3 1.6-2.1-2.1 1.6-2.3-.8-2-2.8-.5v-3l2.8-.5.8-2-1.6-2.3 2.1-2.1 2.3 1.6 2-.8z') + `<circle cx="12" cy="12" r="3.5" fill="#000" fill-opacity=".35"/>`,
  cape: p('M8 2h8l1 3 4 16c-3 1-6 1.5-9 1.5S6 22 3 21L7 5z') + o('M12 5v17', 0),
  shard: p('M12 1.5l4 8.5-4 12.5-4-12.5z') + o('M8 10h8l-4-8.5z', 0.4),
  scale: s('M12 3v18M6 21h12M4 7h16', 2) + p('M4 7l-3 7a3 3 0 006 0zM20 7l-3 7a3 3 0 006 0z'),
  // 상태·의도
  str: p('M3 14l9-11 9 11h-5v7H8v-7z'),
  dex: SHIELD,
  weak: s('M5 19L19 5', 2.4) + p('M16 2.5l5.5 0 0 5.5zM2.5 21.5l0-5.5 5.5 5.5z', 0.5) + `<path d="M11 6l3 3-1 1-3-3z" fill="#000" fill-opacity=".4"/>`,
  vuln: SHIELD + `<path d="M12 4.5l-2 5 3 2-2.5 6" stroke="#000" stroke-opacity=".5" stroke-width="1.8" fill="none"/>`,
  atk: SWORD, def: SHIELD, buff: ARROW_UP, debuff: ARROW_DN,
  summon: c(12, 12, 9.5, 0.4) + PLUS,
  steal: COIN, charge: p('M5 2h14v3c0 3-2.5 5.2-4.5 7 2 1.8 4.5 4 4.5 7v3H5v-3c0-3 2.5-5.2 4.5-7C7.5 10.2 5 8 5 5z'), drain: FANG,
  atkdef: SWORD,
  // UI
  trophy: p('M6 2.5h12v2h3v2.5a4.5 4.5 0 01-4.6 4.5A6 6 0 0113.2 14v3.5H17v3.5H7v-3.5h3.8V14a6 6 0 01-3.2-2.5A4.5 4.5 0 013 7V4.5h3z'),
  gift: p('M3 8h18v4H3zM4.5 12h15v9.5h-15z') + `<path d="M10.8 8h2.4v13.5h-2.4z" fill="#000" fill-opacity=".25"/>` + p('M12 8C10 4 6.5 3 6 5.5 5.6 7.5 9 8 12 8zM12 8c2-4 5.5-5 6-2.5.4 2-3 2.5-6 2.5z'),
  chat: p('M4 3.5h16a2 2 0 012 2v10a2 2 0 01-2 2h-9l-5 4v-4H4a2 2 0 01-2-2v-10a2 2 0 012-2z') + `<g fill="#000" fill-opacity=".35">${c(8, 10.5, 1.4)}${c(12, 10.5, 1.4)}${c(16, 10.5, 1.4)}</g>`,
  hand: p('M8 21c-2.5-2-4-5-4-8V9.5a1.5 1.5 0 013 0V12h.8V4.5a1.5 1.5 0 013 0V11h.8V3a1.5 1.5 0 013 0v8h.8V5a1.5 1.5 0 013 0v9c0 4-2 6-3 7z'),
  play: p('M7 3.5l13 8.5-13 8.5z'),
  lock: p('M7 10V7a5 5 0 0110 0v3h1.5v12h-13V10zM9.5 10h5V7a2.5 2.5 0 00-5 0z'),
  check: s('M4 12.5l5 5L20 6.5', 3),
  close: s('M6 6l12 12M18 6L6 18', 2.8),
  back: s('M15 4l-8 8 8 8', 3),
  next: s('M9 4l8 8-8 8', 3),
  tent: p('M12 2.5L22 21H2z') + `<path d="M12 9l4 12H8z" fill="#000" fill-opacity=".35"/>`,
  game: p('M7 6h10a5 5 0 015 5v3a4 4 0 01-7 2.6L14 15h-4l-1 1.6A4 4 0 012 14v-3a5 5 0 015-5z') + `<g fill="#000" fill-opacity=".35"><path d="M6 10h1.5v1.5H9V13H7.5v1.5H6V13H4.5v-1.5H6z"/>${c(16, 11, 1.2)}${c(18, 13.5, 1.2)}</g>`,
  dust: MOON + `<g transform="translate(3 9) scale(.32)">${STAR}</g>`,
  hp: HEART,
  info: c(12, 12, 10, 0.35) + p('M10.8 10h2.4v7.5h-2.4zM12 5.5a1.6 1.6 0 110 3.2 1.6 1.6 0 010-3.2z'),
  sound: p('M3 9h4l5-4.5v15L7 15H3z') + s('M15.5 8.5a5 5 0 010 7M18.5 5.5a9 9 0 010 13', 2),
  music: p('M9 4.5L20 2v13.5a3 3 0 11-2-2.8V6.5L11 8v10a3 3 0 11-2-2.8z'),
  bolt2: p('M13.5 1.5L4.5 13.5H11l-1.5 9 9-12H12z'),
  auto: CYCLE,
  skull: p('M12 2.5c5 0 8.5 3.5 8.5 8 0 3-1.5 5-3.5 6v3.5h-10V16.5c-2-1-3.5-3-3.5-6 0-4.5 3.5-8 8.5-8z') + `<g fill="#000" fill-opacity=".45">${c(8.5, 11, 2.2)}${c(15.5, 11, 2.2)}</g>`,
  fish: p('M2 12c3-5 8-6.5 12-5 2 .8 3.5 2 4.5 3.2L22 7v10l-3.5-3.2c-1 1.2-2.5 2.4-4.5 3.2-4 1.5-9 0-12-5z') + `<circle cx="7.5" cy="11" r="1.3" fill="#000" fill-opacity=".45"/>`,
  pot: p('M3 9h18v2h-1v6a4 4 0 01-4 4H8a4 4 0 01-4-4v-6H3z') + s('M8 3c0 2 1.5 2 1.5 4M12 2.5c0 2 1.5 2 1.5 4M16 3c0 2 1.5 2 1.5 4', 1.6),
  rest: FIRE,
  treasure: p('M3 10a5 5 0 015-5h8a5 5 0 015 5v1H3zM3 12h18v8a1.5 1.5 0 01-1.5 1.5h-15A1.5 1.5 0 013 20z') + `<path d="M10.5 10.5h3V15h-3z" fill="#000" fill-opacity=".35"/>`,
  shop: p('M3 9l2-5.5h14L21 9a3 3 0 01-6 0 3 3 0 01-6 0 3 3 0 01-6 0zM4.5 13h15v8.5h-15z') + `<path d="M9.5 15.5h5v6h-5z" fill="#000" fill-opacity=".3"/>`,
  event: p('M12 2a7 7 0 017 7c0 3-2 4.6-3.2 5.8-.9.9-1.3 1.7-1.3 2.7h-5c0-1-.4-1.8-1.3-2.7C7 13.6 5 12 5 9a7 7 0 017-7z') + p('M9.5 19h5v1.5a2.5 2.5 0 01-5 0z'),
  battle: SWORD + `<g transform="translate(24 0) scale(-1 1)">${SWORD}</g>`,
  elite: p('M12 2.5c5 0 8.5 3.5 8.5 8 0 3-1.5 5-3.5 6v3.5h-10V16.5c-2-1-3.5-3-3.5-6 0-4.5 3.5-8 8.5-8z') + `<g fill="#000" fill-opacity=".45">${c(8.5, 11, 2.2)}${c(15.5, 11, 2.2)}</g>`,
  boss: CROWN,
};

export function icon(name, cls = '', title = '') {
  const body = ICONS[name] || ICONS.star;
  return `<svg class="ic ${cls}" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">${title ? `<title>${title}</title>` : ''}${body}</svg>`;
}
