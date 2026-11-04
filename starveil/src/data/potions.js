const N = (b) => ({ b, m: 0 });
// 물약: 전투 중 자유롭게 사용. rar r 은 상점·보물에서만
export const POTIONS = [
  { id: 'p_heal',   rar: 'c', name: '치유 물약', color: '#ff7a9a', desc: '체력 15 회복', fx: [{ t: 'heal', v: N(15) }] },
  { id: 'p_block',  rar: 'c', name: '방어 물약', color: '#7ab8ff', desc: '방어도 12', fx: [{ t: 'block', v: N(12) }] },
  { id: 'p_fire',   rar: 'c', name: '화염병',   color: '#ff9a4c', desc: '모든 적에게 피해 10', fx: [{ t: 'dmg', v: N(10), aoe: 1, pierce: 1 }] },
  { id: 'p_poison', rar: 'c', name: '독병',     color: '#8be36b', desc: '대상에게 중독 7', fx: [{ t: 'st', s: 'poison', v: N(7) }] },
  { id: 'p_frost',  rar: 'c', name: '서리병',   color: '#9fe0ff', desc: '모든 적에게 빙결 3', fx: [{ t: 'st', s: 'frost', v: N(3), aoe: 1 }] },
  { id: 'p_luck',   rar: 'c', name: '행운 물약', color: '#b8ffcf', desc: '재굴림 +3', fx: [{ t: 'reroll', v: N(3) }] },
  { id: 'p_str',    rar: 'c', name: '힘 물약',   color: '#ffcf5a', desc: '힘 2', fx: [{ t: 'st', s: 'str', v: N(2), self: 1 }] },
  { id: 'p_weak',   rar: 'c', name: '흐림 물약', color: '#b9a7ff', desc: '모든 적에게 약화 2, 취약 2', fx: [{ t: 'st', s: 'weak', v: N(2), aoe: 1 }, { t: 'st', s: 'vuln', v: N(2), aoe: 1 }] },
  { id: 'p_dice',   rar: 'c', name: '주사위 물약', color: '#f3ecff', desc: '주사위 2개 추가', fx: [{ t: 'addDice', v: 2 }] },
  { id: 'p_clean',  rar: 'c', name: '정화 물약', color: '#e0fff8', desc: '해로운 효과 제거, 체력 6 회복', fx: [{ t: 'cleanse' }, { t: 'heal', v: N(6) }] },
  { id: 'p_fate',   rar: 'r', name: '운명 물약', color: '#ffd6f5', desc: '운명 게이지 가득 충전', special: 'fortune', fx: [] },
  { id: 'p_giant',  rar: 'r', name: '거인 물약', color: '#ffb0b0', desc: '최대 체력 영구 +6', special: 'maxhp', v: 6, fx: [] },
];
export const POTION_BY_ID = {};
for (const p of POTIONS) POTION_BY_ID[p.id] = p;
