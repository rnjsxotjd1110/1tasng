// 주사위 종류. faces 는 굴렸을 때 나올 수 있는 눈, on 은 사용했을 때 추가 효과.
export const DICE = [
  { id: 'normal',  name: '평범한 주사위', rar: 'c', faces: [1, 2, 3, 4, 5, 6], color: '#f3ecff', pip: '#2a2150', desc: '특별한 힘은 없지만 믿음직한 주사위예요.' },
  { id: 'heavy',   name: '무거운 주사위', rar: 'c', faces: [3, 3, 4, 4, 5, 5], color: '#9aa6c4', pip: '#1d2236', desc: '항상 중간 눈이 나와요. (3~5)' },
  { id: 'small',   name: '작은 주사위',   rar: 'c', faces: [1, 1, 2, 2, 3, 3], color: '#ffd6e7', pip: '#6a2846', on: { block: 2 }, desc: '낮은 눈만 나와요. 사용하면 방어도 2' },
  { id: 'lucky',   name: '행운 주사위',   rar: 'r', faces: [2, 3, 4, 5, 6, 6], color: '#b8ffcf', pip: '#174a2a', desc: '1이 나오지 않고 6이 두 면이에요.' },
  { id: 'fire',    name: '불꽃 주사위',   rar: 'r', faces: [1, 2, 3, 4, 5, 6], color: '#ffb38a', pip: '#5a1e08', on: { burn: 1 }, desc: '사용하면 대상에게 화상 1' },
  { id: 'frost',   name: '서리 주사위',   rar: 'r', faces: [1, 2, 3, 4, 5, 6], color: '#bfe9ff', pip: '#0d3550', on: { frost: 1 }, desc: '사용하면 대상에게 빙결 1' },
  { id: 'venom',   name: '독 주사위',     rar: 'r', faces: [1, 2, 3, 4, 5, 6], color: '#c9f59a', pip: '#26420c', on: { poison: 1 }, desc: '사용하면 대상에게 중독 1' },
  { id: 'gold',    name: '황금 주사위',   rar: 'r', faces: [1, 2, 3, 4, 5, 6], color: '#ffe08a', pip: '#5a3e00', on: { gold6: 3 }, desc: '6으로 사용하면 골드 3' },
  { id: 'moon',    name: '달 주사위',     rar: 'r', faces: [1, 2, 3, 4, 5, 6], color: '#e6e0ff', pip: '#3a2f7a', on: { heal: 1 }, desc: '사용하면 체력 1 회복' },
  { id: 'twin',    name: '극단 주사위',   rar: 'e', faces: [1, 1, 1, 6, 6, 6], color: '#ffc2f0', pip: '#4d0f3e', desc: '1 아니면 6만 나와요.' },
  { id: 'star',    name: '별 주사위',     rar: 'e', faces: [1, 2, 3, 4, 5, 6], color: '#fff3b0', pip: '#6a4a00', wild6: true, desc: '6이 나오면 어떤 요구 조건도 만족해요.' },
  { id: 'crystal', name: '수정 주사위',   rar: 'l', faces: [4, 4, 5, 5, 6, 6], color: '#a8f0ff', pip: '#0a3f52', desc: '높은 눈만 나오는 귀한 주사위예요. (4~6)' },
];
