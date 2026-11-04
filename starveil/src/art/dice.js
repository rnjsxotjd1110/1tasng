import { DICE_BY_ID } from '../data/dice_index.js';
const PIPS = { 1: [[50, 50]], 2: [[30, 30], [70, 70]], 3: [[28, 28], [50, 50], [72, 72]], 4: [[30, 30], [70, 30], [30, 70], [70, 70]], 5: [[28, 28], [72, 28], [50, 50], [28, 72], [72, 72]], 6: [[30, 26], [70, 26], [30, 50], [70, 50], [30, 74], [70, 74]] };
export function dieSVG(value, type = 'normal', o = {}) {
  const d = DICE_BY_ID[type] || DICE_BY_ID.normal;
  const v = Math.max(1, Math.min(6, value || 1));
  const pips = PIPS[v].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="${v === 1 ? 11 : 8.5}" fill="${v === 1 && type === 'normal' ? '#e0457a' : d.pip}"/>`).join('');
  const deco = type === 'star' ? '<path d="M84 8l3 6 6 1-4.5 4 1 6-5.5-3-5.5 3 1-6L75 15l6-1z" fill="#ffcf5a"/>' : type === 'fire' ? '<path d="M86 6c2 4 6 6 6 11a6 6 0 01-12 0c0-3 2-5 3-6 0 2 1 3 2 3 0-3 0-5 1-8z" fill="#ff6a2a"/>' : type === 'frost' ? '<path d="M86 5v20M77 10l18 10M77 20l18-10" stroke="#3a9ad0" stroke-width="2.5" stroke-linecap="round"/>' : type === 'gold' ? '<circle cx="86" cy="14" r="7" fill="#e0a020"/>' : type === 'venom' ? '<path d="M86 6c3 5 6 8 6 12a6 6 0 01-12 0c0-4 3-7 6-12z" fill="#5aa02a"/>' : type === 'moon' ? '<path d="M89 6a9 9 0 105 14 7 7 0 01-5-14z" fill="#8f7fe0"/>' : '';
  return `<svg class="die-svg" viewBox="0 0 100 100"><rect x="4" y="4" width="92" height="92" rx="20" fill="${d.color}"/><rect x="4" y="4" width="92" height="92" rx="20" fill="url(#dieShade)"/><rect x="5.5" y="5.5" width="89" height="89" rx="18.5" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="2"/>${deco}${pips}</svg>`;
}
export const DIE_DEFS = `<svg width="0" height="0" style="position:absolute"><defs><linearGradient id="dieShade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".35"/><stop offset=".55" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".18"/></linearGradient></defs></svg>`;
