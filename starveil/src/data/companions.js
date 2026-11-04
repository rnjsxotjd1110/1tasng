// 원정 동행 동료의 지원 기술. 호감도 레벨(lv 0~10)에 따라 강해져요.
const N = (b) => ({ b, m: 0 });
export const COMPANIONS = {
  lyra: { name: '리라', skill: '별빛 응원', passive: '전투 승리 시 체력 회복 +2(호감도 5 이상 +4)' },
  mio: { name: '미오', skill: '행운의 동전', passive: '전투 골드 +10%(호감도 5 이상 +20%)' },
  seren: { name: '세렌', skill: '수호의 기록', passive: '전투 시작 시 방어도 3(호감도 5 이상 6)' },
};
export function companionAssist(id, lv) {
  const max = Math.max(4, 7 - Math.floor(lv / 3));
  if (id === 'lyra') return { name: '별빛 응원', max, desc: `체력 ${6 + 2 * lv} 회복, 재굴림 +1`, fx: [{ t: 'heal', v: N(6 + 2 * lv) }, { t: 'reroll', v: N(1) }] };
  if (id === 'mio') return { name: '행운의 동전', max, rerollUp: 1, desc: `남은 주사위를 다시 굴리고 눈 +1, 골드 ${3 + lv}`, fx: [{ t: 'gold', v: N(3 + lv) }] };
  return { name: '수호의 기록', max, desc: `방어도 ${8 + 2 * lv}, 모든 적에게 약화 2`, fx: [{ t: 'block', v: N(8 + 2 * lv) }, { t: 'st', s: 'weak', v: N(2), aoe: 1 }] };
}
export function companionPassive(id, lv) {
  const hi = lv >= 5;
  if (id === 'lyra') return { winHeal: hi ? 4 : 2 };
  if (id === 'mio') return { goldMult: hi ? 0.2 : 0.1 };
  return { startBlock: hi ? 6 : 3 };
}
