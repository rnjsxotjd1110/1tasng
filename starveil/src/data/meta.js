// 별자리 트리(영구 성장). cost(lv) = 현재 레벨 lv 에서 다음 레벨로 가는 비용
const g = (base, r = 1.45) => (lv) => Math.round(base * Math.pow(r, lv));

export const TREE = [
  { id: 'hp', name: '생명의 별', icon: 'heart', max: 10, cost: g(30), desc: (l) => `최대 체력 +${4 * l}`, x: 50, y: 8 },
  { id: 'heal', name: '치유의 별', icon: 'heal', max: 5, cost: g(60), desc: (l) => `전투 승리 시 체력 ${l} 회복`, x: 25, y: 18, req: 'hp' },
  { id: 'rest', name: '휴식의 별', icon: 'moon', max: 5, cost: g(50), desc: (l) => `휴식 회복량 +${5 * l}%`, x: 75, y: 18, req: 'hp' },
  { id: 'gold', name: '황금의 별', icon: 'coin', max: 5, cost: g(40), desc: (l) => `시작 골드 +${15 * l}`, x: 12, y: 30, req: 'heal' },
  { id: 'shop', name: '상인의 별', icon: 'scale', max: 5, cost: g(60), desc: (l) => `상점 가격 -${4 * l}%`, x: 35, y: 32, req: 'heal' },
  { id: 'potstart', name: '약초의 별', icon: 'potion', max: 2, cost: g(90, 2), desc: (l) => `시작 시 물약 ${l}개`, x: 65, y: 32, req: 'rest' },
  { id: 'upgrade', name: '대장장이 별', icon: 'hammer', max: 3, cost: g(150, 1.8), desc: (l) => `시작 기술 ${l}개 강화`, x: 88, y: 30, req: 'rest' },
  { id: 'elite', name: '사냥꾼의 별', icon: 'sword', max: 3, cost: g(100, 1.7), desc: (l) => `엘리트 처치 골드 +${10 * l}`, x: 10, y: 44, req: 'gold' },
  { id: 'fortune', name: '운명의 별', icon: 'star', max: 4, cost: g(120, 1.7), desc: (l) => `운명 최대치 -${l}`, x: 30, y: 47, req: 'shop' },
  { id: 'potion', name: '물약 주머니 별', icon: 'bag', max: 2, cost: g(220, 2.5), desc: (l) => `물약 칸 +${l}`, x: 55, y: 46, req: 'potstart' },
  { id: 'luck', name: '행운의 별', icon: 'clover', max: 3, cost: g(150, 1.7), desc: (l) => `도박 성공 확률 +${5 * l}%`, x: 80, y: 45, req: 'upgrade' },
  { id: 'relic', name: '유물의 별', icon: 'charm', max: 1, cost: g(400), desc: () => '시작 시 일반 유물 1개', x: 20, y: 60, req: 'fortune' },
  { id: 'choice', name: '선택의 별', icon: 'cards', max: 1, cost: g(500), desc: () => '기술 보상 선택지 +1', x: 42, y: 61, req: 'fortune' },
  { id: 'assist', name: '유대의 별', icon: 'twinstar', max: 2, cost: g(300, 2), desc: (l) => `동료 지원 충전 -${l}`, x: 64, y: 60, req: 'potion' },
  { id: 'shard', name: '별조각의 별', icon: 'shard', max: 10, cost: g(80, 1.4), desc: (l) => `별조각 획득 +${5 * l}%`, x: 86, y: 60, req: 'luck' },
  { id: 'slot', name: '기술 칸의 별', icon: 'constel', max: 1, cost: g(700), desc: () => '기술 칸 +1', x: 30, y: 74, req: 'relic' },
  { id: 'lucky', name: '행운 주사위 별', icon: 'die', max: 1, cost: g(1200), desc: () => '시작 주사위 하나가 행운 주사위', x: 55, y: 75, req: 'choice' },
  { id: 'reroll', name: '재굴림의 별', icon: 'cycle', max: 1, cost: g(900), desc: () => '매 턴 재굴림 +1', x: 78, y: 74, req: 'assist' },
  { id: 'crystal', name: '수정의 별', icon: 'crystal', max: 10, cost: g(50, 1.4), desc: (l) => `별빛 수정 생산량 +${10 * l}%`, x: 15, y: 88, req: 'slot' },
  { id: 'vault', name: '저장고의 별', icon: 'jar', max: 6, cost: g(70, 1.5), desc: (l) => `수정 저장 한도 +${2 * l}시간`, x: 40, y: 90, req: 'slot' },
  { id: 'dust', name: '달가루의 별', icon: 'moon', max: 5, cost: g(60, 1.5), desc: (l) => `놀이 달가루 +${10 * l}%`, x: 62, y: 90, req: 'lucky' },
  { id: 'master', name: '별지기의 별', icon: 'crown', max: 5, cost: g(1500, 1.6), desc: (l) => `모든 기술 피해 +${3 * l}%`, x: 86, y: 88, req: 'reroll' },
  { id: 'infinite', name: '무한의 별', icon: 'sparkle', max: 100, cost: (lv) => Math.round(2500 * Math.pow(1.06, lv)), desc: (l) => `모든 피해 +${l}%, 최대 체력 +${l}`, x: 50, y: 97, req: 'master' },
];
export const TREE_BY_ID = {};
for (const t of TREE) TREE_BY_ID[t.id] = t;

// 달의 위상(어려움 단계). 각 단계는 이전 단계 효과를 모두 포함해요.
export const PHASES = [
  '기본 난이도',
  '엘리트 체력 +15%',
  '일반 적 피해 +10%',
  '전투 골드 -20%',
  '보스 체력 +15%',
  '휴식 회복량 -30%',
  '시작 체력 -10%',
  '엘리트가 더 자주 등장',
  '모든 적 체력 +10%',
  '물약을 얻을 확률 감소',
  '기술 보상 선택지 -1',
  '상점 가격 +20%',
  '엘리트 피해 +15%',
  '보스가 힘 2를 가지고 시작',
  '모든 적 피해 +10%',
  '동료 승리 회복 효과 없음',
  '모든 적 체력 +10%',
  '매 턴 재굴림 -1',
  '모든 적이 힘 1을 가지고 시작',
  '보스 체력 +20%',
  '모든 적 체력과 피해 +15%',
];
export const MAX_PHASE = 20;

export function phaseScale(phase, kind) {
  let hp = 1, atk = 1;
  const p = (n) => phase >= n;
  if (kind === 'elite' && p(1)) hp += 0.15;
  if (kind === 'normal' && p(2)) atk += 0.1;
  if (kind === 'boss' && p(4)) hp += 0.15;
  if (p(8)) hp += 0.1;
  if (kind === 'elite' && p(12)) atk += 0.15;
  if (p(14)) atk += 0.1;
  if (p(16)) hp += 0.1;
  if (kind === 'boss' && p(19)) hp += 0.2;
  if (p(20)) { hp += 0.15; atk += 0.15; }
  return { hp, atk };
}
