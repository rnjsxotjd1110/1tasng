// 유물: mods = 정적 수치, on = 전투 훅(api, payload). rar: c r e l, cls: 직업 전용(없으면 공용), boss: 보스 보상 전용
export const RELICS = [
  // ── 직업 시작 유물 ──
  { id: 'knight_crest', cls: 'knight', rar: 's', name: '기사의 문장', icon: 'shield', desc: '전투 시작 시 방어도 6. 매 턴 시작 시 방어도 3',
    on: { start(a) { a.block(6); a.flash(); }, turn(a) { a.block(3); } } },
  { id: 'grimoire', cls: 'witch', rar: 's', name: '달빛 마도서', icon: 'book', desc: '화상과 빙결을 부여할 때 1 더 부여', mods: { stBonus: { burn: 1, frost: 1 } } },
  { id: 'loaded_die', cls: 'gambler', rar: 's', name: '행운의 주사위', icon: 'die', desc: '6이 나올 때마다 운명 +2, 골드 +1',
    on: { roll(a, p) { const n = p.dice.filter((d) => d.value === 6).length; if (n) { a.fortune(2 * n); a.gold(n); a.flash(); } } } },
  { id: 'alch_bag', cls: 'alch', rar: 's', name: '연금술 가방', icon: 'bag', desc: '물약 칸 +1. 전투 시작 시 무작위 적 하나에게 중독 3',
    mods: { potionSlots: 1 }, on: { start(a) { const e = a.rng.pick(a.enemies); if (e) { a.status(e, 'poison', 3); a.flash(); } } } },

  // ── 일반 ──
  { id: 'pebble', rar: 'c', name: '반짝이는 조약돌', icon: 'pebble', desc: '전투 시작 시 방어도 5', on: { start(a) { a.block(5); a.flash(); } } },
  { id: 'old_charm', rar: 'c', name: '오래된 부적', icon: 'charm', desc: '최대 체력 +8', mods: { maxHp: 8 } },
  { id: 'clover', rar: 'c', name: '네잎 클로버', icon: 'clover', desc: '첫 턴에 재굴림 +2', on: { turn(a, p) { if (p.n === 1) { a.reroll(2); a.flash(); } } } },
  { id: 'lantern', rar: 'c', name: '따뜻한 랜턴', icon: 'lantern', desc: '전투 승리 시 체력 4 회복', on: { win(a) { a.heal(4); a.flash(); } } },
  { id: 'coin_pouch', rar: 'c', name: '동전 주머니', icon: 'pouch', desc: '전투 보상 골드 +30%', mods: { goldMult: 0.3 } },
  { id: 'whetstone', rar: 'c', name: '숫돌', icon: 'stone', desc: '전투 시작 시 힘 1', on: { start(a) { a.status(a.h, 'str', 1); a.flash(); } } },
  { id: 'gloves', rar: 'c', name: '가죽 장갑', icon: 'glove', desc: '턴 시작 시 방어도 2', on: { turn(a) { a.block(2); } } },
  { id: 'candy_jar', rar: 'c', name: '별사탕 병', icon: 'jar', desc: '최대 체력 +4. 휴식 회복량 +10%', mods: { maxHp: 4, restHeal: 0.1 } },
  { id: 'quill', rar: 'c', name: '깃털 펜', icon: 'quill', desc: '6이 나올 때마다 운명 +2', on: { roll(a, p) { const n = p.dice.filter((d) => d.value === 6).length; if (n) { a.fortune(2 * n); } } } },
  { id: 'bell', rar: 'c', name: '작은 은종', icon: 'bell', desc: '전투 시작 시 모든 적에게 약화 1', on: { start(a) { for (const e of a.enemies) a.status(e, 'weak', 1); a.flash(); } } },
  { id: 'petal', rar: 'c', name: '마른 꽃잎', icon: 'petal', desc: '1이 나올 때마다 방어도 3', on: { roll(a, p) { const n = p.dice.filter((d) => d.value === 1).length; if (n) { a.block(3 * n); a.flash(); } } } },
  { id: 'compass', rar: 'c', name: '구리 나침반', icon: 'compass', desc: '엘리트와 보스 처치 시 골드 +20', on: { kill(a, p) { if (p.e.def.kind !== 'normal') { a.gold(20); a.flash(); } } } },
  { id: 'bandage', rar: 'c', name: '깨끗한 붕대', icon: 'bandage', desc: '체력이 절반 이하로 전투를 시작하면 체력 6 회복', on: { start(a) { if (a.h.hp <= a.h.maxHp / 2) { a.heal(6); a.flash(); } } } },
  { id: 'map_scrap', rar: 'c', name: '지도 조각', icon: 'map', desc: '상점 가격 -10%', mods: { shopDisc: 0.1 } },

  // ── 희귀 ──
  { id: 'dice_cup', rar: 'r', name: '은빛 주사위 컵', icon: 'cup', desc: '매 턴 재굴림 +1', mods: { rerolls: 1 } },
  { id: 'thorn_mail', rar: 'r', name: '가시 갑옷', icon: 'thorns', desc: '전투 시작 시 가시 3', on: { start(a) { a.status(a.h, 'thorns', 3); a.flash(); } } },
  { id: 'moon_tear', rar: 'r', name: '달의 눈물', icon: 'tear', desc: '턴 종료 시 쓰지 않은 주사위 1개당 체력 1 회복', on: { end(a, p) { if (p.unused.length) { a.heal(p.unused.length); a.flash(); } } } },
  { id: 'witch_hat', rar: 'r', name: '마녀의 모자', icon: 'hat', desc: '화상을 부여할 때 1 더 부여', mods: { stBonus: { burn: 1 } } },
  { id: 'fang', rar: 'r', name: '독사의 이빨', icon: 'fang', desc: '중독을 부여할 때 1 더 부여', mods: { stBonus: { poison: 1 } } },
  { id: 'frost_ring', rar: 'r', name: '서리 반지', icon: 'ring', desc: '빙결을 부여할 때 1 더 부여', mods: { stBonus: { frost: 1 } } },
  { id: 'twin_mirror', rar: 'r', name: '쌍둥이 거울', icon: 'mirror', desc: '같은 눈이 2개 이상 나오면 방어도 4', on: { roll(a, p) { if (p.reroll) return; const v = p.dice.map((d) => d.value); if (new Set(v).size < v.length) { a.block(4); a.flash(); } } } },
  { id: 'chain_charm', rar: 'r', name: '연쇄 부적', icon: 'chain', desc: '한 턴에 기술을 세 번째로 쓸 때마다 운명 +4, 재굴림 +1', on: { use(a) { if (a.c.turnUses === 3) { a.fortune(4); a.reroll(1); a.flash(); } } } },
  { id: 'lucky_coin', rar: 'r', name: '행운의 금화', icon: 'coin', desc: '첫 턴에 주사위 +1', on: { start(a) { a.c.rs._firstExtra = (a.c.rs._firstExtra || 0) + 1; } } },
  { id: 'hammer', rar: 'r', name: '무거운 망치', icon: 'hammer', desc: '기술로 12 이상 피해를 주면 대상에게 취약 1', on: { use(a, p) { const lastBig = a.c.ev.some((x) => x.k === 'dmg' && x.amt >= 12 && x.u !== 'hero'); if (lastBig && p.target && !p.target.dead) { a.status(p.target, 'vuln', 1); } } } },
  { id: 'star_map', rar: 'r', name: '별지도', icon: 'map', desc: '휴식처에서 회복과 강화를 모두 할 수 있음' },
  { id: 'scale', rar: 'r', name: '상인의 저울', icon: 'scale', desc: '상점 가격 -20%', mods: { shopDisc: 0.2 } },
  { id: 'pocket_watch', rar: 'r', name: '회중시계', icon: 'watch', desc: '전투 시작 시 모든 카운트다운 -4', on: { start(a) { for (const s of a.c.skills) if (s.def.cd) s.cdLeft = Math.max(1, s.cdLeft - 4); a.flash(); } } },
  { id: 'feather', rar: 'r', name: '바람 깃털', icon: 'feather', desc: '턴 종료 시 방어도가 0이면 방어도 5를 미리 얻음', on: { end(a) { if (a.h.block === 0) { a.c.rs._feather = 1; } }, turn(a) { if (a.c.rs._feather) { a.c.rs._feather = 0; a.block(5); a.flash(); } } } },
  { id: 'ember', rar: 'r', name: '꺼지지 않는 불씨', icon: 'fire', desc: '전투 시작 시 모든 적에게 화상 2', on: { start(a) { for (const e of a.enemies) a.status(e, 'burn', 2); a.flash(); } } },

  // ── 영웅 ──
  { id: 'rusty_crown', rar: 'e', name: '녹슨 왕관', icon: 'crown', desc: '주사위 +1. 최대 체력 -10', mods: { dice: 1, maxHp: -10 } },
  { id: 'sixth_star', rar: 'e', name: '여섯 번째 별', icon: 'star', desc: '6이 나온 주사위는 어떤 요구 조건도 만족' },
  { id: 'vamp_fang', rar: 'e', name: '흡혈 송곳니', icon: 'fang', desc: '적을 처치할 때마다 체력 4 회복', on: { kill(a) { a.heal(4); a.flash(); } } },
  { id: 'fate_thread', rar: 'e', name: '운명의 실', icon: 'thread', desc: '운명 최대치 -4', mods: { fortuneMax: -4 } },
  { id: 'hourglass', rar: 'e', name: '영원의 모래시계', icon: 'hourglass', desc: '턴이 바뀌어도 방어도의 절반이 남음' },
  { id: 'star_crown', rar: 'e', name: '별빛 왕관', icon: 'crown', desc: '주는 피해 +15%', mods: { dmgMult: 0.15 } },
  { id: 'devil_die', rar: 'e', name: '악마의 주사위', icon: 'die', desc: '주사위 +1. 턴 시작 시 체력 1 잃음', mods: { dice: 1 }, on: { turn(a) { a.c.h.hp = Math.max(1, a.c.h.hp - 1); a.c.ev.push({ k: 'dmg', u: 'hero', amt: 1, blocked: 0, hp: a.c.h.hp, block: a.c.h.block, kind: 'self' }); } } },
  { id: 'giant_heart', rar: 'e', name: '거인의 심장', icon: 'heart', desc: '최대 체력 +20', mods: { maxHp: 20 } },
  { id: 'crystal_ball', rar: 'e', name: '수정 구슬', icon: 'orb', desc: '전투 시작 시 운명 게이지 절반 충전', on: { start(a) { a.fortune(Math.floor(a.c.fortuneMax / 2)); a.flash(); } } },
  { id: 'golden_hand', rar: 'e', name: '황금 손', icon: 'glove', desc: '턴 종료 시 쓰지 않은 주사위 1개당 골드 1', on: { end(a, p) { if (p.unused.length) a.gold(p.unused.length); } } },
  { id: 'lucky_cat', rar: 'e', name: '행운 고양이', icon: 'cat', desc: '도박 효과 성공 확률 +15%', on: { start(a) { a.c.rs._luck = (a.c.rs._luck || 0) + 0.15; } } },
  { id: 'phoenix', rar: 'e', name: '불사조 깃털', icon: 'phoenix', desc: '쓰러질 때 한 번 최대 체력 40%로 부활',
    on: { lethal(a) { if (a.c.phoenixUsed) return false; a.c.phoenixUsed = true; a.c.h.hp = Math.floor(a.c.h.maxHp * 0.4); a.c.ev.push({ k: 'heal', u: 'hero', amt: a.c.h.hp, hp: a.c.h.hp }); a.text('불사조의 불꽃!', '#ffb34c'); a.flash(); return true; } } },

  // ── 전설 (보스 보상) ──
  { id: 'moon_shard', rar: 'l', boss: 1, name: '달의 파편', icon: 'moon', desc: '주사위 +1', mods: { dice: 1 } },
  { id: 'star_heart', rar: 'l', boss: 1, name: '별의 심장', icon: 'heart', desc: '매 턴 재굴림 +1. 최대 체력 +10', mods: { rerolls: 1, maxHp: 10 } },
  { id: 'cog', rar: 'l', boss: 1, name: '시간의 톱니', icon: 'cog', desc: '매 턴 처음 쓴 주사위를 같은 눈으로 돌려받음', on: { use(a, p) { if (a.c.turnUses === 1 && p.dice.length === 1) { a.addDie(p.dice[0].type, p.dice[0].value); a.flash(); } } } },
  { id: 'ouroboros', rar: 'l', boss: 1, name: '무한의 고리', icon: 'ring', desc: '운명 기술을 쓴 뒤 게이지가 절반 남음' },
  { id: 'comet_tail', rar: 'l', boss: 1, name: '혜성 꼬리', icon: 'comet', desc: '턴 시작 시 무작위 적에게 피해 6', on: { turn(a) { const e = a.rng.pick(a.enemies); if (e) { a.hit(e, 6); a.flash(); } } } },
  { id: 'cluster', rar: 'l', boss: 1, name: '별무리 조각', icon: 'constel', desc: '기술 칸 +1', mods: { skillSlots: 1 } },
  { id: 'aurora', rar: 'l', boss: 1, name: '오로라 망토', icon: 'cape', desc: '매 턴 처음 받는 피해 절반', on: { turn(a) { a.c.rs._aur = 1; }, hurt(a, p) { if (a.c.rs._aur) { a.c.rs._aur = 0; const back = Math.floor(p.amt / 2); if (back > 0) { a.c.h.hp = Math.min(a.c.h.maxHp, a.c.h.hp + back); a.c.ev.push({ k: 'heal', u: 'hero', amt: back, hp: a.c.h.hp }); a.flash(); } } } } },
  { id: 'nova', rar: 'l', boss: 1, name: '초신성 핵', icon: 'boom', desc: '전투 시작 시 모든 적에게 피해 12', on: { start(a) { for (const e of a.enemies) a.hit(e, 12, { pierce: 1 }); a.flash(); } } },
];

const BY = {};
for (const r of RELICS) BY[r.id] = r;
export const relicById = (id) => BY[id];
export const RELIC_RAR_NAME = { s: '시작', c: '일반', r: '희귀', e: '영웅', l: '전설' };
