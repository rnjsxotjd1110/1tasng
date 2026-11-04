// 기술 정의
// req  : 주사위 요구 조건 {min}|{max}|{eq}|{even}|{odd}|{same}|{sum}|{straight}
// slots: 넣어야 하는 주사위 수(기본 1). d 는 넣은 주사위 눈의 합
// cd   : 카운트다운. 주사위 눈만큼 줄고 0 이하가 되면 발동
// uses : 한 턴 사용 횟수(기본 1)
// fx   : 효과 목록. v = {b, m} → b + m × d (내림)
// lock : 직업 레벨 몇에 보상 목록에 등장하는지(없으면 처음부터)
const D = (m = 1, b = 0) => ({ b, m });
const N = (b) => ({ b, m: 0 });

export const SKILLS = [
  // ───────── 별검사 (knight) ─────────
  { id: 'k_slash', cls: 'knight', rar: 'c', start: 1, name: '베기', icon: 'sword', fx: [{ t: 'dmg', v: D(1, 1) }] },
  { id: 'k_guard', cls: 'knight', rar: 'c', start: 1, name: '방패 올리기', icon: 'shield', fx: [{ t: 'block', v: D(1) }] },
  { id: 'k_charge', cls: 'knight', rar: 'c', start: 1, name: '돌진', icon: 'sword2', req: { min: 4 }, fx: [{ t: 'dmg', v: D(1, 5) }] },
  { id: 'k_wall', cls: 'knight', rar: 'c', name: '철벽', icon: 'shield2', req: { max: 3 }, fx: [{ t: 'block', v: D(3) }] },
  { id: 'k_stab', cls: 'knight', rar: 'c', name: '찌르기', icon: 'spear', req: { max: 2 }, uses: 2, fx: [{ t: 'dmg', v: N(4), pierce: 1 }] },
  { id: 'k_armor', cls: 'knight', rar: 'c', name: '단단한 갑옷', icon: 'armor', fx: [{ t: 'block', v: D(1, 2) }] },
  { id: 'k_twin', cls: 'knight', rar: 'c', name: '연속 베기', icon: 'sword', req: { even: 1 }, fx: [{ t: 'dmg', v: D(0.5, 1), hits: 2 }] },
  { id: 'k_shout', cls: 'knight', rar: 'c', name: '전투 함성', icon: 'horn', fx: [{ t: 'st', s: 'weak', v: N(1), aoe: 1 }, { t: 'block', v: D(0.5, 2) }] },
  { id: 'k_throw', cls: 'knight', rar: 'c', name: '방패 던지기', icon: 'shield', fx: [{ t: 'dmg', v: D(1) }, { t: 'block', v: D(0.5) }] },
  { id: 'k_smash', cls: 'knight', rar: 'r', name: '강타', icon: 'hammer', req: { min: 5 }, fx: [{ t: 'dmg', v: D(2) }] },
  { id: 'k_bash', cls: 'knight', rar: 'r', name: '방패 강타', icon: 'shield2', fx: [{ t: 'dmgBlock', m: 1 }], up: { fx: [{ t: 'dmgBlock', m: 1 }, { t: 'block', v: N(3) }] } },
  { id: 'k_counter', cls: 'knight', rar: 'r', name: '반격 태세', icon: 'thorns', fx: [{ t: 'st', s: 'thorns', v: D(0.5), self: 1 }] },
  { id: 'k_resolve', cls: 'knight', rar: 'r', name: '결의', icon: 'fist', req: { eq: 6 }, fx: [{ t: 'st', s: 'str', v: N(2), self: 1 }] },
  { id: 'k_light', cls: 'knight', rar: 'r', name: '수호의 빛', icon: 'heal', req: { odd: 1 }, fx: [{ t: 'heal', v: D(1) }] },
  { id: 'k_whirl', cls: 'knight', rar: 'r', name: '회전 베기', icon: 'whirl', req: { min: 4 }, fx: [{ t: 'dmg', v: D(1), aoe: 1 }] },
  { id: 'k_will', cls: 'knight', rar: 'r', name: '견고한 의지', icon: 'armor', lock: 2, fx: [{ t: 'st', s: 'dex', v: N(1), self: 1 }, { t: 'block', v: N(3) }] },
  { id: 'k_oath', cls: 'knight', rar: 'r', name: '피의 맹세', icon: 'blood', lock: 3, fx: [{ t: 'selfdmg', v: N(3) }, { t: 'st', s: 'str', v: N(1), self: 1 }, { t: 'reroll', v: N(1) }] },
  { id: 'k_taunt', cls: 'knight', rar: 'r', name: '도발', icon: 'horn', lock: 4, fx: [{ t: 'block', v: D(1, 4) }, { t: 'st', s: 'vuln', v: N(1) }] },
  { id: 'k_exec', cls: 'knight', rar: 'e', name: '처형', icon: 'axe', req: { min: 5 }, lock: 2, fx: [{ t: 'dmg', v: D(1, 5) }, { t: 'execute', pct: 25 }] },
  { id: 'k_dual', cls: 'knight', rar: 'e', name: '쌍검 난무', icon: 'sword2', slots: 2, req: { same: 1 }, fx: [{ t: 'dmg', v: D(2) }] },
  { id: 'k_paladin', cls: 'knight', rar: 'e', name: '성기사의 일격', icon: 'holy', cd: 15, lock: 5, fx: [{ t: 'dmg', v: N(30), pierce: 1 }] },
  { id: 'k_fortress', cls: 'knight', rar: 'e', name: '불굴의 성채', icon: 'castle', lock: 6, req: { min: 4 }, fx: [{ t: 'block', v: D(2, 4) }, { t: 'st', s: 'thorns', v: N(2), self: 1 }] },
  { id: 'k_starblade', cls: 'knight', rar: 'l', name: '별의 검', icon: 'starsword', req: { eq: 6 }, lock: 7, fx: [{ t: 'dmg', v: N(18), aoe: 1 }, { t: 'block', v: N(6) }] },

  // ───────── 달마녀 (witch) ─────────
  { id: 'w_bolt', cls: 'witch', rar: 'c', start: 1, name: '마력탄', icon: 'orb', fx: [{ t: 'dmg', v: D(1) }] },
  { id: 'w_veil', cls: 'witch', rar: 'c', start: 1, name: '서리 장막', icon: 'frost', fx: [{ t: 'block', v: D(1) }, { t: 'st', s: 'frost', v: N(1) }] },
  { id: 'w_fireball', cls: 'witch', rar: 'c', start: 1, name: '화염구', icon: 'fire', req: { min: 4 }, fx: [{ t: 'dmg', v: D(1, 1) }, { t: 'st', s: 'burn', v: N(2) }] },
  { id: 'w_icelance', cls: 'witch', rar: 'c', name: '얼음창', icon: 'ice', req: { even: 1 }, fx: [{ t: 'dmg', v: D(1, 2) }, { t: 'st', s: 'frost', v: N(1) }] },
  { id: 'w_ignite', cls: 'witch', rar: 'c', name: '점화', icon: 'fire', fx: [{ t: 'st', s: 'burn', v: D(1) }] },
  { id: 'w_moonheal', cls: 'witch', rar: 'c', name: '달빛 치유', icon: 'heal', req: { odd: 1 }, fx: [{ t: 'heal', v: D(1, 1) }] },
  { id: 'w_mana', cls: 'witch', rar: 'c', name: '마나 순환', icon: 'cycle', req: { max: 2 }, fx: [{ t: 'reroll', v: N(1) }, { t: 'fortune', v: N(3) }] },
  { id: 'w_flip', cls: 'witch', rar: 'c', name: '뒤집기 주문', icon: 'flip', fx: [{ t: 'die', mode: 'flip' }] },
  { id: 'w_prison', cls: 'witch', rar: 'c', name: '빙결 감옥', icon: 'ice', req: { max: 3 }, fx: [{ t: 'st', s: 'frost', v: D(1) }] },
  { id: 'w_hone', cls: 'witch', rar: 'r', name: '주사위 연성', icon: 'plus', fx: [{ t: 'die', mode: 'plus', v: 2 }], up: { fx: [{ t: 'die', mode: 'plus', v: 3 }] } },
  { id: 'w_split', cls: 'witch', rar: 'r', name: '쪼개기 마법', icon: 'split', req: { min: 2 }, fx: [{ t: 'die', mode: 'split' }], up: { req: { min: 2 }, fx: [{ t: 'die', mode: 'split' }, { t: 'block', v: N(3) }] } },
  { id: 'w_combust', cls: 'witch', rar: 'r', name: '연소 폭발', icon: 'boom', fx: [{ t: 'dmgStatus', s: 'burn', m: 2 }], up: { fx: [{ t: 'dmgStatus', s: 'burn', m: 3 }] } },
  { id: 'w_meteor', cls: 'witch', rar: 'r', name: '별똥별', icon: 'meteor', cd: 12, fx: [{ t: 'dmg', v: N(10), aoe: 1 }, { t: 'st', s: 'burn', v: N(2), aoe: 1 }] },
  { id: 'w_blizzard', cls: 'witch', rar: 'r', name: '눈보라', icon: 'snow', req: { min: 5 }, fx: [{ t: 'dmg', v: N(4), aoe: 1 }, { t: 'st', s: 'frost', v: N(2), aoe: 1 }] },
  { id: 'w_thunder', cls: 'witch', rar: 'r', name: '번개', icon: 'bolt', req: { min: 5 }, lock: 2, fx: [{ t: 'dmg', v: D(2), pierce: 1 }] },
  { id: 'w_moonveil', cls: 'witch', rar: 'r', name: '달의 장막', icon: 'moon', lock: 3, fx: [{ t: 'block', v: D(2) }] },
  { id: 'w_shatter', cls: 'witch', rar: 'r', name: '얼음 파쇄', icon: 'ice', lock: 4, fx: [{ t: 'dmgStatus', s: 'frost', m: 4 }] },
  { id: 'w_mirror', cls: 'witch', rar: 'e', name: '거울 마법', icon: 'mirror', lock: 2, fx: [{ t: 'die', mode: 'copy' }] },
  { id: 'w_chain', cls: 'witch', rar: 'e', name: '별빛 사슬', icon: 'chain', slots: 2, req: { same: 1 }, fx: [{ t: 'dmg', v: D(1) }, { t: 'st', s: 'weak', v: N(2) }, { t: 'st', s: 'burn', v: N(3) }] },
  { id: 'w_inferno', cls: 'witch', rar: 'e', name: '겁화', icon: 'fire', lock: 5, req: { min: 5 }, fx: [{ t: 'st', s: 'burn', v: D(1), aoe: 1 }] },
  { id: 'w_absolute', cls: 'witch', rar: 'e', name: '절대 영도', icon: 'snow', lock: 6, cd: 14, fx: [{ t: 'st', s: 'frost', v: N(3), aoe: 1 }, { t: 'dmg', v: N(8), aoe: 1 }] },
  { id: 'w_comet', cls: 'witch', rar: 'l', name: '혜성 강림', icon: 'comet', cd: 20, lock: 7, fx: [{ t: 'dmg', v: N(40), aoe: 1 }] },

  // ───────── 운명술사 (gambler) ─────────
  { id: 'g_card', cls: 'gambler', rar: 'c', start: 1, name: '카드 던지기', icon: 'card', fx: [{ t: 'dmg', v: D(1) }] },
  { id: 'g_hide', cls: 'gambler', rar: 'c', start: 1, name: '패 숨기기', icon: 'cardback', fx: [{ t: 'block', v: D(1) }] },
  { id: 'g_coin', cls: 'gambler', rar: 'c', start: 1, name: '동전 던지기', icon: 'coin', fx: [{ t: 'gamble', p: 0.5, win: [{ t: 'dmg', v: D(2, 2) }], lose: [{ t: 'dmg', v: D(0.5) }] }] },
  { id: 'g_lucky', cls: 'gambler', rar: 'c', name: '행운의 일격', icon: 'clover', fx: [{ t: 'dmg', v: D(1) }, { t: 'dmg', v: D(2), cond: { eq: 6 } }] },
  { id: 'g_swap', cls: 'gambler', rar: 'c', name: '주사위 바꿔치기', icon: 'cycle', fx: [{ t: 'die', mode: 'new' }] },
  { id: 'g_chips', cls: 'gambler', rar: 'c', name: '칩 쌓기', icon: 'chips', fx: [{ t: 'gold', v: D(0.5) }, { t: 'block', v: D(0.5, 1) }] },
  { id: 'g_bluff', cls: 'gambler', rar: 'c', name: '블러핑', icon: 'mask', req: { max: 3 }, fx: [{ t: 'block', v: D(2) }, { t: 'st', s: 'weak', v: N(1) }] },
  { id: 'g_flip', cls: 'gambler', rar: 'c', name: '운명 뒤집기', icon: 'flip', fx: [{ t: 'die', mode: 'flip' }] },
  { id: 'g_shuffle', cls: 'gambler', rar: 'c', name: '카드 셔플', icon: 'cards', req: { max: 4 }, fx: [{ t: 'reroll', v: N(2) }] },
  { id: 'g_high', cls: 'gambler', rar: 'r', name: '하이 롤러', icon: 'chips', req: { min: 5 }, fx: [{ t: 'dmg', v: D(1, 4) }, { t: 'gold', v: N(3) }] },
  { id: 'g_raise', cls: 'gambler', rar: 'r', name: '판돈 올리기', icon: 'chips', fx: [{ t: 'fortune', v: D(1) }] },
  { id: 'g_ace', cls: 'gambler', rar: 'r', name: '에이스', icon: 'ace', req: { eq: 6 }, fx: [{ t: 'dmg', v: N(12) }, { t: 'reroll', v: N(1) }] },
  { id: 'g_poker', cls: 'gambler', rar: 'r', name: '포커페이스', icon: 'mask', lock: 2, fx: [{ t: 'block', v: D(1, 3) }, { t: 'cleanse' }] },
  { id: 'g_roulette', cls: 'gambler', rar: 'r', name: '운명의 룰렛', icon: 'roulette', lock: 3, fx: [{ t: 'gamble', p: 0.34, win: [{ t: 'dmg', v: N(30) }], lose: [{ t: 'dmg', v: N(4) }] }] },
  { id: 'g_goldbomb', cls: 'gambler', rar: 'r', name: '금화 폭탄', icon: 'coin', lock: 4, fx: [{ t: 'dmgGold', m: 0.1, cap: 40 }] },
  { id: 'g_seven', cls: 'gambler', rar: 'e', name: '럭키 세븐', icon: 'seven', slots: 2, req: { sum: 7 }, fx: [{ t: 'dmg', v: N(21) }, { t: 'gold', v: N(7) }] },
  { id: 'g_double', cls: 'gambler', rar: 'e', name: '더블 다운', icon: 'chips', slots: 2, req: { same: 1 }, lock: 2, fx: [{ t: 'dmg', v: D(3) }] },
  { id: 'g_joker', cls: 'gambler', rar: 'e', name: '조커', icon: 'joker', req: { eq: 1 }, lock: 5, fx: [{ t: 'die', mode: 'set', v: 6 }], up: { req: { max: 2 }, fx: [{ t: 'die', mode: 'set', v: 6 }] } },
  { id: 'g_allin', cls: 'gambler', rar: 'e', name: '올인', icon: 'roulette', lock: 6, req: { min: 4 }, fx: [{ t: 'gamble', p: 0.5, win: [{ t: 'dmg', v: D(4), aoe: 1 }], lose: [{ t: 'selfdmg', v: N(4) }] }] },
  { id: 'g_straight', cls: 'gambler', rar: 'l', name: '스트레이트', icon: 'cards', slots: 3, req: { straight: 1 }, lock: 7, fx: [{ t: 'dmg', v: N(30), aoe: 1 }, { t: 'fortune', v: N(6) }] },
  { id: 'g_jackpot', cls: 'gambler', rar: 'l', name: '잭팟 일격', icon: 'seven', cd: 21, lock: 8, fx: [{ t: 'dmg', v: N(7), hits: 7 }] },

  // ───────── 연금술사 (alch) ─────────
  { id: 'a_vial', cls: 'alch', rar: 'c', start: 1, name: '독 투척', icon: 'poison', fx: [{ t: 'st', s: 'poison', v: D(0.5, 1) }, { t: 'dmg', v: N(2) }] },
  { id: 'a_acid', cls: 'alch', rar: 'c', start: 1, name: '산성 유리병', icon: 'flask', fx: [{ t: 'dmg', v: D(1) }, { t: 'st', s: 'vuln', v: N(1), cond: { min: 4 } }] },
  { id: 'a_shield', cls: 'alch', rar: 'c', start: 1, name: '보호 물약', icon: 'potion', fx: [{ t: 'block', v: D(1, 1) }] },
  { id: 'a_heal', cls: 'alch', rar: 'c', name: '치유 비약', icon: 'heal', req: { odd: 1 }, fx: [{ t: 'heal', v: D(1, 2) }] },
  { id: 'a_transmute', cls: 'alch', rar: 'c', name: '변성', icon: 'plus', req: { max: 3 }, fx: [{ t: 'die', mode: 'plus', v: 3 }] },
  { id: 'a_purify', cls: 'alch', rar: 'c', name: '정제', icon: 'drop', fx: [{ t: 'cleanse' }, { t: 'block', v: D(0.5, 3) }] },
  { id: 'a_corrode', cls: 'alch', rar: 'c', name: '부식', icon: 'flask', fx: [{ t: 'st', s: 'vuln', v: N(2) }, { t: 'st', s: 'weak', v: N(1) }] },
  { id: 'a_herb', cls: 'alch', rar: 'c', name: '약초 달이기', icon: 'leaf', fx: [{ t: 'st', s: 'regen', v: D(0.5, 1), self: 1 }] },
  { id: 'a_bomb', cls: 'alch', rar: 'c', name: '폭발 플라스크', icon: 'boom', req: { min: 3 }, fx: [{ t: 'dmg', v: D(1, -1), aoe: 1 }] },
  { id: 'a_venom', cls: 'alch', rar: 'r', name: '맹독', icon: 'poison', req: { min: 4 }, fx: [{ t: 'st', s: 'poison', v: D(1) }] },
  { id: 'a_burst', cls: 'alch', rar: 'r', name: '독 폭발', icon: 'boom', fx: [{ t: 'dmgStatus', s: 'poison', m: 1 }], up: { fx: [{ t: 'dmgStatus', s: 'poison', m: 1.5 }] } },
  { id: 'a_fog', cls: 'alch', rar: 'r', name: '독안개', icon: 'fog', req: { min: 5 }, fx: [{ t: 'st', s: 'poison', v: N(3), aoe: 1 }] },
  { id: 'a_homun', cls: 'alch', rar: 'r', name: '호문쿨루스', icon: 'homun', cd: 14, fx: [{ t: 'st', s: 'regen', v: N(3), self: 1 }, { t: 'block', v: N(10) }] },
  { id: 'a_rain', cls: 'alch', rar: 'r', name: '산성비', icon: 'rain', cd: 10, lock: 2, fx: [{ t: 'st', s: 'poison', v: N(2), aoe: 1 }, { t: 'st', s: 'vuln', v: N(1), aoe: 1 }] },
  { id: 'a_brew', cls: 'alch', rar: 'r', name: '물약 제조', icon: 'potion', req: { eq: 6 }, lock: 3, fx: [{ t: 'potion' }] },
  { id: 'a_mutagen', cls: 'alch', rar: 'r', name: '변이 촉진제', icon: 'flask', lock: 4, req: { even: 1 }, fx: [{ t: 'st', s: 'str', v: N(1), self: 1 }, { t: 'heal', v: N(2) }] },
  { id: 'a_catalyst', cls: 'alch', rar: 'e', name: '촉매', icon: 'catalyst', lock: 2, req: { min: 3 }, fx: [{ t: 'double', s: 'poison' }] },
  { id: 'a_distill', cls: 'alch', rar: 'e', name: '증류', icon: 'flask', slots: 2, req: { same: 1 }, fx: [{ t: 'st', s: 'poison', v: D(1) }] },
  { id: 'a_spread', cls: 'alch', rar: 'e', name: '연쇄 반응', icon: 'chain', lock: 5, fx: [{ t: 'spread', s: 'poison' }, { t: 'dmg', v: D(0.5) }] },
  { id: 'a_stone', cls: 'alch', rar: 'l', name: '현자의 돌', icon: 'stone', req: { eq: 6 }, lock: 7, fx: [{ t: 'st', s: 'str', v: N(3), self: 1 }, { t: 'st', s: 'regen', v: N(3), self: 1 }] },
  { id: 'a_plague', cls: 'alch', rar: 'l', name: '역병', icon: 'fog', cd: 18, lock: 8, fx: [{ t: 'st', s: 'poison', v: N(8), aoe: 1 }] },

  // ───────── 공용 (neutral) ─────────
  { id: 'n_breath', cls: 'any', rar: 'c', name: '숨 고르기', icon: 'leaf', fx: [{ t: 'block', v: D(1) }, { t: 'heal', v: N(1) }] },
  { id: 'n_dodge', cls: 'any', rar: 'c', name: '회피', icon: 'wind', req: { max: 2 }, fx: [{ t: 'block', v: N(7) }] },
  { id: 'n_dagger', cls: 'any', rar: 'c', name: '투척 단검', icon: 'dagger', req: { max: 3 }, uses: 2, fx: [{ t: 'dmg', v: N(4) }] },
  { id: 'n_focus', cls: 'any', rar: 'c', name: '집중', icon: 'eye', req: { max: 3 }, fx: [{ t: 'reroll', v: N(1) }, { t: 'block', v: N(2) }] },
  { id: 'n_moonblade', cls: 'any', rar: 'c', name: '달빛 칼날', icon: 'moon', req: { even: 1 }, fx: [{ t: 'dmg', v: D(1, 2) }] },
  { id: 'n_shadow', cls: 'any', rar: 'c', name: '그림자 일격', icon: 'dagger', req: { odd: 1 }, fx: [{ t: 'dmg', v: D(1, 2) }] },
  { id: 'n_bandage', cls: 'any', rar: 'c', name: '응급 처치', icon: 'heal', req: { max: 2 }, fx: [{ t: 'heal', v: N(4) }] },
  { id: 'n_bless', cls: 'any', rar: 'r', name: '별빛 축복', icon: 'star', req: { min: 5 }, fx: [{ t: 'fortune', v: N(4) }, { t: 'heal', v: N(3) }] },
  { id: 'n_twinstar', cls: 'any', rar: 'r', name: '쌍둥이별', icon: 'twinstar', slots: 2, req: { same: 1 }, fx: [{ t: 'dmg', v: D(1) }, { t: 'block', v: D(1) }] },
  { id: 'n_guardian', cls: 'any', rar: 'r', name: '수호성', icon: 'shield2', req: { max: 3 }, fx: [{ t: 'block', v: D(2, 2) }] },
  { id: 'n_power', cls: 'any', rar: 'r', name: '별의 힘', icon: 'fist', cd: 16, fx: [{ t: 'st', s: 'str', v: N(2), self: 1 }] },
  { id: 'n_sweep', cls: 'any', rar: 'r', name: '휩쓸기', icon: 'whirl', req: { min: 3 }, lock: 3, fx: [{ t: 'dmg', v: D(0.5, 1), aoe: 1 }] },
  { id: 'n_star', cls: 'any', rar: 'e', name: '유성 낙하', icon: 'meteor', cd: 24, fx: [{ t: 'dmg', v: N(24), aoe: 1 }] },
  { id: 'n_wish', cls: 'any', rar: 'e', name: '소원 빌기', icon: 'star', req: { eq: 6 }, lock: 4, fx: [{ t: 'heal', v: N(8) }, { t: 'fortune', v: N(6) }] },
  { id: 'n_constel', cls: 'any', rar: 'l', name: '별자리 완성', icon: 'constel', slots: 3, req: { straight: 1 }, lock: 6, fx: [{ t: 'dmg', v: D(2), aoe: 1 }, { t: 'block', v: D(1) }] },
];

// 운명 기술: 운명 게이지가 가득 차면 쓸 수 있는 직업 고유 기술
export const FORTUNE_SKILLS = {
  knight:  { name: '성채의 맹세', fx: [{ t: 'block', v: N(20) }, { t: 'st', s: 'thorns', v: N(3), self: 1 }] },
  witch:   { name: '달의 폭풍',   fx: [{ t: 'dmg', v: N(12), aoe: 1 }, { t: 'st', s: 'burn', v: N(3), aoe: 1 }] },
  gambler: { name: '잭팟',        fx: [{ t: 'addDice', v: 3 }, { t: 'gold', v: N(10) }] },
  alch:    { name: '현자의 비약', fx: [{ t: 'heal', v: N(12) }, { t: 'cleanse' }, { t: 'st', s: 'str', v: N(2), self: 1 }] },
};

const BY_ID = {};
for (const s of SKILLS) BY_ID[s.id] = s;
export const skillById = (id) => BY_ID[id];

function bumpV(v, n) { return { b: v.b + n, m: v.m }; }
function autoUp(fx) {
  return fx.map((e) => {
    const x = { ...e };
    if (x.t === 'gamble') { x.win = autoUp(x.win); x.lose = autoUp(x.lose); return x; }
    if (!x.v) { if (x.t === 'dmgStatus') x.m = x.m + 1; if (x.t === 'dmgBlock') x.m = x.m + 0.5; if (x.t === 'die' && x.mode === 'plus') x.v += 1; return x; }
    if (x.t === 'dmg') x.v = bumpV(x.v, x.hits > 2 ? 1 : (x.aoe ? 2 : 3));
    else if (x.t === 'block' || x.t === 'heal') x.v = bumpV(x.v, 3);
    else if (x.t === 'st') x.v = bumpV(x.v, 1);
    else if (x.t === 'gold' || x.t === 'reroll' || x.t === 'fortune') x.v = bumpV(x.v, x.t === 'reroll' ? 0 : 2);
    else if (x.t === 'selfdmg') x.v = bumpV(x.v, -1);
    return x;
  });
}

// 강화 여부를 반영한 실제 기술 정의
const CACHE = {};
export function resolveSkill(id, up) {
  const key = id + (up ? '+' : '');
  if (CACHE[key]) return CACHE[key];
  const base = BY_ID[id];
  if (!base) throw new Error('unknown skill ' + id);
  let s = { ...base };
  if (up) {
    if (base.up) s = { ...s, ...base.up };
    else {
      s.fx = autoUp(base.fx);
      if (base.cd) s.cd = Math.max(4, base.cd - 3);
      if (base.req && base.req.min && base.req.min > 2 && !base.slots && base.req.min < 6) s.req = { min: base.req.min - 1 };
      if (base.req && base.req.max && base.req.max < 5 && !base.slots) s.req = { max: base.req.max + 1 };
    }
    if (JSON.stringify(s.fx) === JSON.stringify(base.fx) && !base.up && s.req === base.req && s.cd === base.cd) s.uses = (base.uses || 1) + 1;
    s.name = base.name + '+';
    s.upgraded = true;
  }
  delete s.up;
  CACHE[key] = s;
  return s;
}
