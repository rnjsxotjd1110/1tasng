// 동료 메타 정보(해금 조건·의상·호감도 구간)
export const AFF_TABLE = [0, 20, 50, 90, 140, 200, 270, 350, 440, 540, 650];
export const AFF_MAX_LV = 10;
export const DAILY = { talk: 3, touch: 3, gift: 1 };
export const GIFT_AFF = { love: 15, like: 8, neutral: 3, dislike: -3 };

export const HEROINE_META = {
  lyra: {
    order: 0, color: '#ff9ad6', unlock: null, tiers: [3, 6], mini: ['fish', 'cook'],
    outfits: [
      { id: 'default', name: '견습 마녀복' },
      { id: 'casual', name: '야영지 앞치마', lv: 4 },
      { id: 'festival', name: '달 축제 유카타', lv: 8 },
      { id: 'starlight', name: '별빛 드레스', price: 2500 },
    ],
  },
  mio: {
    order: 1, color: '#ffb06a', unlock: { boss: 1, text: '이끼 정원 보스를 처치하면 만날 수 있어요' }, tiers: [2, 5], mini: ['hilo'],
    outfits: [
      { id: 'default', name: '떠돌이 상인복' },
      { id: 'casual', name: '여우 잠옷', lv: 4 },
      { id: 'festival', name: '달 축제 유카타', lv: 8 },
      { id: 'starlight', name: '은여우 선장복', price: 2500 },
    ],
  },
  seren: {
    order: 2, color: '#a8c8ff', unlock: { boss: 2, text: '수정 동굴 보스를 처치하면 만날 수 있어요' }, tiers: [3, 6], mini: ['constel'],
    outfits: [
      { id: 'default', name: '사서 기사복' },
      { id: 'casual', name: '독서용 카디건', lv: 4 },
      { id: 'festival', name: '달 축제 유카타', lv: 8 },
      { id: 'starlight', name: '월광 무도회복', price: 2500 },
    ],
  },
};
export const HEROINE_IDS = ['lyra', 'mio', 'seren'];

export function affLevel(aff) {
  let lv = 0;
  for (let i = 1; i <= AFF_MAX_LV; i++) if (aff >= AFF_TABLE[i]) lv = i;
  return lv;
}
export function tierOf(id, lv) {
  const t = HEROINE_META[id].tiers;
  return lv <= t[0] ? 'low' : lv <= t[1] ? 'mid' : 'high';
}
