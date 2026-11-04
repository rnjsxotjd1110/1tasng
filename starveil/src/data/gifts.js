// 선물. price 는 야영지 상점 달가루 가격(0이면 상점에서 안 팖)
export const GIFTS = [
  { id: 'star_candy',    name: '별사탕',       price: 60,  color: '#ffd6f5', desc: '입안에서 톡톡 터지는 별 모양 사탕' },
  { id: 'moon_cookie',   name: '달 쿠키',      price: 90,  color: '#ffe8b0', desc: '버터 향이 진한 초승달 쿠키' },
  { id: 'ribbon',        name: '하늘색 리본',   price: 120, color: '#9fd8ff', desc: '부드러운 비단 리본' },
  { id: 'moonflower',    name: '달맞이꽃',      price: 70,  color: '#fff3a0', desc: '밤에만 피는 노란 꽃' },
  { id: 'fairy_book',    name: '낡은 동화책',   price: 160, color: '#c9a27a', desc: '달토끼가 나오는 오래된 동화책' },
  { id: 'star_tea',      name: '별빛 홍차',     price: 110, color: '#ff9a7a', desc: '찻잔 속에 별빛이 비치는 홍차' },
  { id: 'music_box',     name: '오르골',        price: 320, color: '#d9c2ff', desc: '자장가가 흘러나오는 작은 오르골' },
  { id: 'golden_carp',   name: '황금 붕어',     price: 0,   color: '#ffcf5a', desc: '별 낚시에서만 낚이는 반짝이는 붕어' },
  { id: 'bunny_plush',   name: '토끼 인형',     price: 260, color: '#f3ecff', desc: '귀가 축 늘어진 폭신한 인형' },
  { id: 'crystal',       name: '푸른 수정',     price: 180, color: '#8fdfff', desc: '수정 동굴에서 캔 맑은 수정' },
  { id: 'silver_cards',  name: '은빛 카드',     price: 220, color: '#dfe6f0', desc: '테두리가 은으로 된 카드 한 벌' },
  { id: 'hairpin',       name: '별 머리핀',     price: 200, color: '#ffe08a', desc: '작은 별이 달린 반짝이는 머리핀' },
  { id: 'moss_mushroom', name: '이끼 버섯',     price: 20,  color: '#8fbf6a', desc: '향이 아주 독특한 버섯' },
  { id: 'old_coin',      name: '옛날 금화',     price: 400, color: '#e0b050', desc: '여우 상단의 문장이 새겨진 금화' },
];
export const GIFT_BY_ID = {};
for (const g of GIFTS) GIFT_BY_ID[g.id] = g;
