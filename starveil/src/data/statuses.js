// 상태 이상 정의. 설명은 UI 도움말에 그대로 쓰여요.
export const STATUS = {
  burn:   { name: '화상', icon: 'burn',   color: '#ff8a4c', debuff: true,  desc: '턴 시작 시 화상 수치만큼 피해를 받고 수치가 절반으로 줄어요.' },
  poison: { name: '중독', icon: 'poison', color: '#8be36b', debuff: true,  desc: '턴 시작 시 중독 수치만큼 피해를 받고 수치가 1 줄어요.' },
  frost:  { name: '빙결', icon: 'frost',  color: '#8fd3ff', debuff: true,  desc: '적: 3 이상 쌓이면 행동을 한 번 건너뛰어요. 별지기: 다음 턴에 그 수만큼 주사위가 얼어요.' },
  weak:   { name: '약화', icon: 'weak',   color: '#b9a7ff', debuff: true,  desc: '주는 피해가 25% 줄어요. 턴이 끝나면 1 줄어요.' },
  vuln:   { name: '취약', icon: 'vuln',   color: '#ff6b8a', debuff: true,  desc: '받는 피해가 50% 늘어요. 턴이 끝나면 1 줄어요.' },
  str:    { name: '힘',   icon: 'str',    color: '#ffcf5a', debuff: false, desc: '공격 1회마다 피해가 힘 수치만큼 늘어요.' },
  dex:    { name: '견고', icon: 'dex',    color: '#7fe0d0', debuff: false, desc: '방어도를 얻을 때마다 견고 수치만큼 더 얻어요.' },
  thorns: { name: '가시', icon: 'thorns', color: '#c8e06b', debuff: false, desc: '공격받을 때마다 공격한 대상에게 가시 수치만큼 피해를 줘요.' },
  regen:  { name: '재생', icon: 'regen',  color: '#7dffb0', debuff: false, desc: '턴이 끝날 때 재생 수치만큼 회복하고 수치가 1 줄어요.' },
};
export const STATUS_ORDER = ['str', 'dex', 'thorns', 'regen', 'burn', 'poison', 'frost', 'weak', 'vuln'];
