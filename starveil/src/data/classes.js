export const CLASSES = [
  { id: 'knight', name: '별검사', en: 'STAR KNIGHT', color: '#7ab8ff', hp: 66, rerolls: 1, fortuneMax: 15,
    dice: ['normal', 'normal', 'normal'], skills: ['k_slash', 'k_guard', 'k_charge'], relic: 'knight_crest',
    desc: '단단한 방패와 묵직한 검으로 싸워요. 방어도와 가시로 버티다가 한 번에 되갚는 직업이에요.',
    tip: '낮은 눈은 철벽처럼 방어 기술에, 높은 눈은 공격 기술에 넣으면 좋아요.', unlock: null },
  { id: 'witch', name: '달마녀', en: 'MOON WITCH', color: '#d98fff', hp: 50, rerolls: 1, fortuneMax: 14,
    dice: ['normal', 'normal', 'normal'], skills: ['w_bolt', 'w_veil', 'w_fireball'], relic: 'grimoire',
    desc: '화상과 빙결을 쌓아 적을 녹이고 얼려요. 주사위 눈을 바꾸는 마법도 다뤄요.',
    tip: '빙결이 3 쌓이면 적은 한 턴을 쉬어요. 화상은 크게 쌓을수록 강해요.', unlock: { boss: 1, text: '이끼 정원 보스 처치' } },
  { id: 'gambler', name: '운명술사', en: 'FORTUNE DEALER', color: '#ffcf5a', hp: 54, rerolls: 2, fortuneMax: 12,
    dice: ['normal', 'normal', 'normal'], skills: ['g_card', 'g_hide', 'g_coin'], relic: 'loaded_die',
    desc: '재굴림이 많고 확률에 모든 것을 거는 직업이에요. 6이 나오는 순간 판이 뒤집혀요.',
    tip: '운명 게이지가 빨리 차요. 잭팟으로 주사위를 3개 더 굴릴 수 있어요.', unlock: { boss: 2, text: '수정 동굴 보스 처치' } },
  { id: 'alch', name: '연금술사', en: 'ALCHEMIST', color: '#8be36b', hp: 56, rerolls: 1, fortuneMax: 15,
    dice: ['normal', 'normal', 'normal'], skills: ['a_vial', 'a_acid', 'a_shield'], relic: 'alch_bag',
    desc: '독을 쌓고 촉매로 터뜨려요. 물약을 많이 들고 다닐 수 있어요.',
    tip: '중독은 매 턴 피해를 주고 1씩만 줄어요. 촉매로 두 배로 만들어 보세요.', unlock: { boss: 3, text: '가라앉은 서고 보스 처치' } },
];
export const CLASS_BY_ID = {};
for (const c of CLASSES) CLASS_BY_ID[c.id] = c;

// 직업 레벨: 그 직업으로 얻은 별조각 누적
export const CLASS_XP = [0, 0, 120, 300, 550, 900, 1350, 1900, 2600, 3500, 4600];
export const CLASS_MAX_LV = 10;
export function classLevel(xp) {
  let lv = 1;
  for (let i = 2; i <= CLASS_MAX_LV; i++) if (xp >= CLASS_XP[i]) lv = i;
  return lv;
}
