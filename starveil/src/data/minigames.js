// 별 낚시 물고기
export const FISH = [
  { id: 'f_minnow',  name: '별송사리',     rar: 'c', dust: 12, color: '#bfe9ff', speed: 1.0, zone: 0.26 },
  { id: 'f_glow',    name: '반딧불 피라미', rar: 'c', dust: 15, color: '#fff3a0', speed: 1.1, zone: 0.25 },
  { id: 'f_moss',    name: '이끼 메기',     rar: 'c', dust: 18, color: '#8fbf6a', speed: 0.9, zone: 0.24 },
  { id: 'f_pink',    name: '분홍 납자루',   rar: 'c', dust: 16, color: '#ffb0d0', speed: 1.15, zone: 0.24 },
  { id: 'f_blue',    name: '푸른 은어',     rar: 'r', dust: 30, color: '#7ab8ff', speed: 1.35, zone: 0.2 },
  { id: 'f_crystal', name: '수정 잉어',     rar: 'r', dust: 36, color: '#a8f0ff', speed: 1.4, zone: 0.19 },
  { id: 'f_ink',     name: '잉크 오징어',   rar: 'r', dust: 34, color: '#5a5f9a', speed: 1.3, zone: 0.2 },
  { id: 'f_lantern', name: '등불 아귀',     rar: 'r', dust: 40, color: '#ffb34c', speed: 1.45, zone: 0.18 },
  { id: 'f_moon',    name: '달빛 해마',     rar: 'e', dust: 70, color: '#e6e0ff', speed: 1.65, zone: 0.16 },
  { id: 'f_comet',   name: '혜성 날치',     rar: 'e', dust: 80, color: '#ff9ae6', speed: 1.8, zone: 0.15 },
  { id: 'f_gold',    name: '황금 붕어',     rar: 'l', dust: 150, color: '#ffcf5a', speed: 2.0, zone: 0.13, gift: 'golden_carp' },
  { id: 'f_whale',   name: '꼬마 별고래',   rar: 'l', dust: 200, color: '#9fa8ff', speed: 1.9, zone: 0.13 },
];
export const FISH_BY_ID = {};
for (const f of FISH) FISH_BY_ID[f.id] = f;

// 달빛 요리 재료와 요리
export const INGREDIENTS = [
  { id: 'i_flour', name: '밀가루', color: '#f3ecdc' },
  { id: 'i_milk', name: '우유', color: '#ffffff' },
  { id: 'i_egg', name: '달걀', color: '#ffe8a0' },
  { id: 'i_berry', name: '별딸기', color: '#ff7a9a' },
  { id: 'i_honey', name: '꿀', color: '#ffcf5a' },
  { id: 'i_herb', name: '향초', color: '#8fe0a0' },
  { id: 'i_fish', name: '생선', color: '#9fd8ff' },
  { id: 'i_mush', name: '버섯', color: '#c9a27a' },
];
// buff: 다음 원정 시작 효과
export const RECIPES = [
  { id: 'r_pancake', name: '달빛 팬케이크', steps: ['i_flour', 'i_milk', 'i_egg', 'i_honey'], lv: 0, buff: { maxHp: 6 }, buffText: '다음 원정 최대 체력 +6' },
  { id: 'r_tart', name: '별딸기 타르트', steps: ['i_flour', 'i_egg', 'i_berry', 'i_berry', 'i_honey'], lv: 1, buff: { gold: 40 }, buffText: '다음 원정 시작 골드 +40' },
  { id: 'r_stew', name: '버섯 스튜', steps: ['i_mush', 'i_herb', 'i_milk', 'i_mush', 'i_herb'], lv: 2, buff: { potion: 'p_heal' }, buffText: '다음 원정 치유 물약 1개' },
  { id: 'r_grill', name: '향초 생선구이', steps: ['i_fish', 'i_herb', 'i_honey', 'i_fish', 'i_herb', 'i_egg'], lv: 3, buff: { str: 1 }, buffText: '다음 원정 첫 전투 힘 1' },
  { id: 'r_pudding', name: '별빛 푸딩', steps: ['i_milk', 'i_egg', 'i_honey', 'i_milk', 'i_berry', 'i_egg'], lv: 4, buff: { upgrade: 1 }, buffText: '다음 원정 시작 기술 1개 강화' },
  { id: 'r_feast', name: '야영지 만찬', steps: ['i_fish', 'i_mush', 'i_herb', 'i_flour', 'i_egg', 'i_berry', 'i_honey'], lv: 6, buff: { maxHp: 10, gold: 30 }, buffText: '다음 원정 최대 체력 +10, 골드 +30' },
];
export const RECIPE_BY_ID = {};
for (const r of RECIPES) RECIPE_BY_ID[r.id] = r;
