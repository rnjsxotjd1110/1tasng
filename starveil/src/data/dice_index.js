import { DICE } from './dice.js';
export const DICE_BY_ID = {};
for (const d of DICE) DICE_BY_ID[d.id] = d;
