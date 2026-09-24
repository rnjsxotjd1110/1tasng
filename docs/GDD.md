# HOUSE EDGE — 게임 설계 문서 (GDD)

> 이 문서가 설계의 원본이다. 코드와 문서가 다르면 문서를 기준으로 코드를 고치거나, 합의된 변경이면 문서를 먼저 고친다.
> 수치 중 "초안"으로 표시된 것은 9단계 밸런스 시뮬레이션에서 조정한다. 조정 결과는 `data/*.tres`·`Economy` 와 이 문서에 함께 반영한다.

---

## 1. 개요

- **장르**: 1인용 방치형(idle/incremental) 룰렛, 픽셀아트, PC(스팀)
- **플레이 시간**: 약 5시간 뒤 엔딩, 이후 무한 모드
- **해상도**: 기준 640×360, 정수 배율 확대(기본 창 1920×1080 = ×3)
- **핵심 재미**: 배율이 당첨에만 붙어 기대값이 1을 넘는 순간부터 룰렛이 "돈 버는 기계"가 된다. 구슬 재질·광택·층·스킬로 배율을 쌓아 숫자가 폭발적으로 커지는 쾌감.

### 1-1. 스토리

나무 구슬 하나뿐인 빈털터리 도박꾼이 카지노 5개 층을 올라간다.

| 층 | 이름 | 분위기 |
|---|---|---|
| B1 | 뒷골목 도박장 | 눅눅한 지하실, 시작 지점 |
| 1F | 다운타운 카지노 | 네온과 담배 연기 |
| 2F | 리버보트 카지노 | 강 위의 호화 유람선 |
| 3F | 스카이 라운지 | 도시가 내려다보이는 VIP 라운지 |
| PH | 펜트하우스 "더 하우스" | 마담 벨벳의 본거지 |

마지막에 **1Dc 칩으로 카지노를 인수해 '하우스'가 된다.**

### 1-2. 등장인물

| 인물 | 설정 | 말투 |
|---|---|---|
| **래칫 남작** | 쥐 사채업자. 핀스트라이프 정장, 중절모, 외알 안경, 시가 | 능글맞은 신사 사기꾼. 정중한 척하며 협박("이런, 이런… 신사분께서 빈 주머니라니요?") |
| **딜러 루시** | 튜토리얼 안내. 스킬 '딜러 고용'으로 고용 가능 | 친절하고 쿨한 크루피에. 짧고 명확하게 |
| **마담 벨벳** | 펜트하우스 오너이자 최종 상대 | 우아하고 여유로움. 절대 서두르지 않는다 |

---

## 2. 재화

### 2-1. 칩 (주 재화)
- 시작 100칩(`Economy.STARTING_CHIPS`). 베팅·업그레이드·층 이동·엔딩에 쓴다.
- 저장은 float(double). 1Dc(1e33)를 넘어 Vg(1e63) 이상까지 표시한다.

### 2-2. 클로버 (스킬트리 전용)

| 획득 조건 | 보상 | 구현 |
|---|---|---|
| 개별숫자 적중 | 적중 1건당 +1 (베팅 1개 × 공 1개 = 1건) | SpinController |
| 5연승 (한 스핀에 1개 이상 당첨이 5스핀 연속) | +1. 연승 5·10·15…회마다 반복 | SpinController |
| 보유 칩 단위(K, M, B…)에 처음 도달 | 새 단위마다 +3 (한 번에 여러 단위를 넘으면 모두 지급) | GameState.add_chips |
| 층 이동 | +10 (FloorDef.clover_reward) | 7단계 |
| 빚 완납 | +2 | 5단계 |

- 엔딩까지 약 230개 획득, 스킬트리 총비용 269(엔딩 전 전부 찍을 수는 없음 → 선택의 재미, 무한 모드에서 완성).
- 획득량에는 `clover_gain_mult` 스탯이 곱해지고 내림한다(클로버 수수료 패널티 = ×0.5).

### 2-3. 빚
- 파산 시 대출. 2배로 갚는다. 자세한 규칙은 9장.

---

## 3. 룰렛 규칙

- **유럽식 싱글 제로**, 포켓 37개(0~36).
- **휠 배열 순서** (`RouletteRules.WHEEL_ORDER`, 인덱스 0 = 0번 포켓, 인덱스가 커지는 방향 = 각도 증가 방향):
  `0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26`
- **빨강**: 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36. 나머지 1~36 은 검정, 0 은 초록.
- **홀짝**: 0 은 홀도 짝도 아니다.
- **포켓 각도**: `pocket_angle(n) = WHEEL_ORDER 인덱스 × 360/37` (도). 0번 포켓이 0도. Godot 2D(y 아래)에서 양의 각도는 화면상 시계 방향.
- **이웃 포켓**: 휠 배열에서 바로 양옆(`RouletteRules.neighbors`).

### 3-1. 베팅 종류

| 베팅 | 이기는 결과 | 배당 | 반환(원금 포함) |
|---|---|---|---|
| RED | 빨강 숫자 | 1:1 | 2배 |
| BLACK | 검정 숫자 | 1:1 | 2배 |
| ODD | 1~36 홀수 | 1:1 | 2배 |
| EVEN | 1~36 짝수 | 1:1 | 2배 |
| STRAIGHT n (0~36) | n | 35:1 | 36배 |

- 0이 나오면 외부 베팅(RED/BLACK/ODD/EVEN)은 전부 패배.

### 3-2. 구슬과 베팅
- **구슬 1개 = 베팅 1개.** 한 스핀의 베팅 수 ≤ 보유 구슬 수.
- 보유 구슬: 초기 1, 업그레이드로 최대 8(`MAX_MARBLES_FROM_UPGRADES`), 스킬 포함 최대 12(`MAX_MARBLES_TOTAL`).
- 같은 칸에 여러 구슬 가능.
- 구슬당 베팅액은 모두 같고, **칩 크기 선택**(1/10, 1/2, MAX — 최대 베팅액 대비)으로 정한다.
- 베팅은 스핀 후에도 그대로 남는다(같은 베팅 반복이 기본. 방치형에 맞춤). 직전 스핀의 실제 베팅은 `GameState.last_bets`.
- **칩 부족 시 자동 축소**: 선택한 칩 크기 × 베팅 수가 보유 칩보다 많으면 구슬당 베팅액을 (보유 칩 ÷ 베팅 수)로 줄인다. 그래도 최소 베팅액 미만이면 스핀 불가(`NOT_ENOUGH_CHIPS`).

### 3-3. 공 여러 개 (더블 볼 대비)
- 스핀 결과는 **배열**이다(`Array[int]`, 공마다 1개). 기본 공 1개 + `extra_balls` 스탯.
- 공이 여러 개면 **각 결과마다 모든 베팅을 판정해 반환액을 합산**하고, **비용은 한 번만** 뗀다.

---

## 4. 핵심 공식

| 항목 | 공식 | 코드 |
|---|---|---|
| 베팅 비용 | 구슬당 베팅액 × 베팅 수 (배율 없음) | SpinController.start_spin |
| **당첨 반환액** | 베팅액 × (배당+1) × 구슬 재질 배율 × 광택 배율 × 층 배율 × 스킬·버프 배율 | RouletteRules.bet_return |
| 구슬당 최대 베팅액 | 10 × 1.35^(베팅 한도 레벨) × 층 bet_mult × max_bet_mult | Economy.max_bet, GameState.max_bet |
| 최소 베팅액 | 최대 베팅액 × 0.1 | Economy.min_bet |
| 칩 크기 | 최대 베팅액 × {0.1, 0.5, 1.0} | Economy.chip_amount |
| 업그레이드 비용 | base × growth^level × upgrade_cost_mult | Economy.upgrade_cost |
| 광택 배율 | 1.25^광택 단계 (0~5) | Economy.polish_mult |
| 광택 비용 | polish_base_cost × 2^현재 단계 × upgrade_cost_mult (초안) | Economy.polish_cost |
| 스핀 시간 | max(1.5, 6.0 × 0.9^(휠 속도 레벨) × spin_duration_mult) 초 | Economy.spin_duration |
| 파산 | 보유 칩 < 최소 베팅액 **이고** 진행 중인 스핀이 없음 | Economy.is_bankrupt |

**배율은 당첨에만 붙는다** → 기대값이 1을 넘을 수 있다.
- 나무 구슬(×1) 빨강 기대값 = 18/37 × 2 = **0.973** (손해)
- 돌 구슬(×1.5) 빨강 기대값 = 0.973 × 1.5 = **1.46** (이득) — 첫 업그레이드가 게임의 전환점.

### 4-1. 반환액 세부 (SpinContext)

```
반환 = 베팅액 × (배당+1)
     × marble_mult        (base = 재질 배율 × 광택 배율, 구슬 수정자 적용)
     × floor_mult         (base = 층 payout_mult)
     × payout_mult_all
     × { RED/BLACK: payout_mult_color | ODD/EVEN: payout_mult_parity | STRAIGHT: 1 + straight_payout_bonus }
     × (결과가 황금 포켓이면 golden_pocket_mult, base 3)
```

- 베팅 한도 업그레이드의 1.35^레벨과 휠 속도의 0.9^레벨은 각각 `max_bet_mult`, `spin_duration_mult` 에 MULT 수정자로 들어간다(업그레이드 데이터가 공식을 표현).

### 4-2. 연출 등급 판정 (SpinOutcome.Tier)

배율 = 순이익 ÷ 총 베팅액.

| 등급 | 조건 (위에서부터 먼저 맞는 것) |
|---|---|
| JACKPOT | 배율 ≥ 100 또는 개별숫자 적중 2건 이상 |
| BIG | 배율 ≥ 20 또는 개별숫자 적중 1건 |
| GOOD | 배율 ≥ 5 |
| NORMAL | 당첨이 1개 이상 (순손실이어도 당첨이 있으면 NORMAL) |
| LOSS | 당첨 없음 |

- **아깝다(near_miss)**: 빗나간 개별숫자 베팅의 숫자가 결과 포켓의 바로 옆이면 true. LOSS 일 때만 "아깝다!" 표시.

---

## 5. 업그레이드 (구현은 3단계, 데이터는 1단계에서 초안 작성)

| id | 이름 | 효과 | 상한 | 데이터(초안) |
|---|---|---|---|---|
| (별도) | 구슬 재질 | 15단계, 아래 표 | 층별 상한 | `data/marbles/*.tres` |
| (별도) | 광택 | 재질마다 0~5단계, 단계당 ×1.25. **재질이 오르면 0으로 초기화** | 5 | MarbleDef.polish_base_cost |
| bet_limit | 베팅 한도 | 최대 베팅액 ×1.35/레벨 (max_bet_mult MULT 1.35) | 무제한 | base 25, growth 1.55 |
| marble_count | 구슬 개수 | 구슬 +1/레벨 (marble_slots_bonus ADD 1) | 7레벨(=8개) | base 100, growth 12 |
| wheel_speed | 휠 속도 | 스핀 시간 ×0.9/레벨 (spin_duration_mult MULT 0.9), 최소 1.5초 | 13레벨 | base 40, growth 2.2 |
| golden_pocket | 황금 포켓 | 황금 포켓 +1/레벨. 결과가 황금 포켓이면 모든 당첨 ×3 | 5 | base 5000, growth 40, 1F부터 |

- 황금 포켓 위치: 개수가 늘 때 아직 황금이 아닌 포켓 중 무작위(RngService misc). 0번 포함 가능.

### 5-1. 구슬 재질 15단계

비용은 돌 50부터 단계마다 ×80 (초안: `cost = 50 × 80^(tier-1)`).

| tier | 재질 | 배율 | 비용(초안) | 해금 층 |
|---|---|---|---|---|
| 0 | 나무 | ×1 | 0 (시작) | B1 |
| 1 | 돌 | ×1.5 | 50 | B1 |
| 2 | 구리 | ×12 | 4.00K | B1 |
| 3 | 철 | ×100 | 320K | B1 |
| 4 | 은 | ×900 | 25.6M | 1F |
| 5 | 금 | ×8K | 2.05B | 1F |
| 6 | 옥 | ×70K | 164B | 1F |
| 7 | 루비 | ×800K | 13.1T | 2F |
| 8 | 사파이어 | ×1.2B | 1.05Qa | 2F |
| 9 | 에메랄드 | ×15B | 83.9Qa | 2F |
| 10 | 다이아몬드 | ×200B | 6.71Qi | 3F |
| 11 | 흑요석 | ×3T | 537Qi | 3F |
| 12 | 별빛 | ×50T | 42.9Sx | 3F |
| 13 | 공허 | ×800T | 3.44Sp | PH |
| 14 | 코스믹 | ×15Qa | 275Sp | PH |

- 각 재질은 팔레트 5색(outline/shadow/base/light/shine)과 fx_id 를 가진다(ART_BIBLE "구슬 팔레트").

---

## 6. 스킬트리 (구현·세부 정의는 6단계)

- 중앙 **"도박꾼의 심장"** 에서 4갈래로 뻗는다.
  - 북 **FORTUNE** (배당): 색·홀짝·개별숫자 배당, 황금 포켓 배율
  - 동 **MACHINE** (자동화): 자동 스핀, 스핀 간격, 휠 속도, 자동 베팅 패턴
  - 남 **ECONOMY** (경제): 업그레이드 할인, 캐시백, 오프라인 수익, 빚 조건
  - 서 **MYSTIC** (특수 기능): 예지(다음 결과 미리 보기, `RngService.peek_next`), 더블 볼(`extra_balls`), 딜러 고용(루시), 구슬 추가(`marble_slots_bonus`, 최대 +4)
- **고리 3개 + 갈래별 궁극기, 노드 57개**, 총비용 269 클로버.
- 데이터: `SkillNodeDef` (branch, ring, position, costs[], prerequisites[], effect_stat/op/per_level 또는 feature_id).
- 효과는 `StatModifiers` 수정자(source `skill:<id>`)로 적용.

---

## 7. 층 (구현은 7단계, 데이터는 1단계 초안)

B1(시작) → 1F(1M) → 2F(1T) → 3F(1Sx) → PH(1No) → 엔딩(1Dc로 하우스 인수)

| index | 층 | 이동 비용 | 당첨 배율(초안) | 베팅 배율(초안) | 구슬 상한 tier | 클로버 | 목표 도달 |
|---|---|---|---|---|---|---|---|
| 0 | B1 | — | ×1 | ×1 | 3 (철) | — | 0:00 |
| 1 | 1F | 1M | ×2 | ×100 | 6 (옥) | +10 | 0:30 |
| 2 | 2F | 1T | ×4 | ×10K | 9 (에메랄드) | +10 | 1:30 |
| 3 | 3F | 1Sx | ×8 | ×1M | 12 (별빛) | +10 | 2:45 |
| 4 | PH | 1No | ×16 | ×100M | 14 (코스믹) | +10 | 4:00 |
| — | 엔딩 | 1Dc | | | | | 5:00 |

- 층 이동은 칩을 지불한다. **리셋 없음**(업그레이드·구슬·스킬 유지). 배율 상승, 클로버 +10.

---

## 8. 숫자 표기 (NumberFormat)

- 단위: `K M B T Qa Qi Sx Sp Oc No Dc Ud Dd Td Qad Qid Sxd Spd Ocd Nod Vg` (K=1e3 … Dc=1e33 … Vg=1e63)
- 1000 미만: 반올림한 정수("999"). 1000 이상: **유효숫자 3자리**("1.23K", "12.3K", "123K").
- 반올림 경계: 999,950 → "1.00M"("1000K" 금지), 999.5 → "1.00K".
- Vg 다음(≥1e66)은 과학적 표기("1.23e66"). 설정에서 과학적 표기로 전환 가능(`NumberFormat.scientific_mode`).
- 음수는 "-1.23K"(ASCII 하이픈). `format_signed` 는 "+1.23K".
- NaN/INF 는 "∞" + 에러 로그.
- `format_full`: 툴팁용 쉼표 전체 표기("1,234,567"), 1e15 이상은 과학적 표기.
- `suffix_index(value)`: 단위 인덱스(마일스톤 판정).

---

## 9. 빚 (구현은 5단계)

- **대출액** = max(최소 베팅액 × 20, 최근 5분 평균 초당 순수익 × 600)
- **상환액** = 대출액 × 2 (`debt_repay_mult` 스탯으로 조정 가능)
- 당첨금의 25%가 자동 상환되고, 수동 상환도 가능. 완납 시 클로버 +2.
- 동시 대출 최대 3건. 4번째는 가장 큰 빚에 합산.
- 빚이 있는 동안 60~120초마다(`penalty_interval_mult`) 랜덤 패널티(20~30초 지속):

| 패널티 | 효과 | 수정자 |
|---|---|---|
| 감시하는 부하 | 휠 속도 −15% | spin_duration_mult × 1/0.85 |
| 소매치기 | 칩 1% 뺏김 (최소 베팅 × 3 아래로는 안 뺏음) | 즉시 spend_chips |
| 시가 연기 | 연출만(화면 연기) | 없음 |
| 흐려진 구슬 | 구슬 배율 −10% | marble_mult × 0.9 |
| 압류 | 다음 1스핀 구슬 1개 사용 불가 | locked_marbles + 1 (1스핀) |
| 클로버 수수료 | 다음 클로버 획득 절반 | clover_gain_mult × 0.5 (1회) |

- 래칫 남작이 대출·패널티·완납 때 대사로 등장한다. 대사 데이터는 `data/dialogue/`.
- 상수는 `Economy` 의 `LOAN_*`, `DEBT_*`, `PENALTY_*`.

---

## 10. 엔딩

PH 에서 1Dc 지불 → 마담 벨벳과 **최후의 스핀**(연출, 승리 확정) → 크레딧·통계 → **무한 모드**(계속 플레이, 스킬트리 완성 가능).

---

## 11. 시스템 구조 (구현 참고)

### 11-1. 흐름

```
[UI 베팅창] → GameState.add_bet() → EventBus.bets_changed
[스핀 버튼] → SpinController.start_spin()
                 검증 → spend_chips → RngService.consume_next() × 공 수 → EventBus.spin_started(results, duration)
[휠 연출]   → duration 동안 공을 results 로 보냄 → SpinController.finish_spin()
                 RouletteRules.resolve(bets, results, GameState.build_spin_context()) → SpinOutcome
                 add_chips(반환) · 기록 · 통계 · 클로버 · 연승 → EventBus.spin_resolved(outcome) → 파산 검사
[당첨 연출] → outcome.tier 에 따라 연출
```

헤드리스·테스트에서는 `SpinController.instant_resolve = true`(헤드리스 기본값)라 start_spin 안에서 바로 정산한다.

### 11-2. EventBus 시그널

| 시그널 | 발행 시점 |
|---|---|
| `chips_changed(new_value: float, delta: float)` | 칩 변화 |
| `clovers_changed(new_value: int, delta: int)` | 클로버 변화 |
| `bets_changed()` | 베팅 목록·칩 크기 변화 |
| `spin_started(results: Array[int], duration: float)` | 스핀 시작(결과 확정) |
| `spin_resolved(outcome: SpinOutcome)` | 정산 완료 |
| `bankrupt()` | 파산 조건 성립 |
| `debt_changed()` | 빚 변화 (5단계) |
| `upgrade_purchased(id: String, level: int)` | 업그레이드 구매 (3단계) |
| `skill_purchased(id: String, level: int)` | 스킬 구매 (6단계) |
| `floor_changed(floor_index: int)` | 층 이동 (7단계) |
| `milestone_reached(suffix_index: int)` | 새 칩 단위 첫 도달 |
| `buff_started(id: String, duration: float)` | 시간제 버프·패널티 시작 |
| `buff_ended(id: String)` | 시간제 버프·패널티 종료 |
| `toast_requested(text: String, icon: String)` | 알림 요청 |

### 11-3. GameState

- 필드: chips(시작 100), clovers, floor_index, upgrade_levels, skill_levels, marble_tier, polish_level, current_bets(Array[Bet]), last_bets, chip_size_mode, debts, win_streak, result_history(최근 100), golden_pockets, highest_milestone, spin_in_progress, modifiers(StatModifiers)
- stats: total_spins(총 스핀), biggest_win(최대 당첨=한 스핀 최대 반환액), best_streak(최대 연승), play_time(초), loans_taken(대출 횟수), straight_hits(적중 숫자 수), total_earned(누적 획득 칩 = 당첨 반환액 합계, 대출금 제외)
- `add_chips()/spend_chips()` 는 음수·NaN·INF 를 거부하고(경고 로그) false 를 돌려준다. spend 는 잔액 부족도 거부.

### 11-4. StatModifiers

- 수정자: `{source_id, stat, op(ADD/MULT), value, duration(PERMANENT=-1)}`
- `get_stat(key, base) = (base + ADD 합) × MULT 곱`. 스탯별 캐시, 변경 시 무효화.
- 같은 source_id + stat 으로 다시 추가하면 **교체**(업그레이드 레벨 갱신에 사용).
- `tick(delta)`: 시간제 수정자 만료 → source 의 수정자가 모두 사라지면 `source_expired` → GameState 가 `buff:` 접두어면 `EventBus.buff_ended` 로 전달.
- `remove_source(source_id)`: 일괄 제거.
- 스탯 키(`StatModifiers.ALL_STATS`): payout_mult_all, payout_mult_color, payout_mult_parity, straight_payout_bonus, marble_mult, floor_mult, golden_pocket_count, golden_pocket_mult, max_bet_mult, marble_slots_bonus, locked_marbles, extra_balls, spin_duration_mult, spin_delay, upgrade_cost_mult, cashback_rate, offline_efficiency, offline_cap_hours, clover_gain_mult, debt_repay_mult, penalty_interval_mult

### 11-5. RngService

- 스핀 결과(outcome 스트림)와 그 외(misc 스트림)를 분리 → 연출·패널티 난수가 결과를 바꾸지 않는다.
- `peek_next(n)`: 다음 n개 결과를 소비하지 않고 본다. 이후 `consume_next()` 는 반드시 그 결과를 낸다(예지 스킬).
- `get_state()/set_state()`: 저장용(4단계).

---

## 12. 1단계에서 정한 세부 규칙 (원 설계에 명시되지 않았던 것)

| 항목 | 결정 | 이유 |
|---|---|---|
| 베팅 유지 | 스핀 후에도 베팅이 남음 | 방치형 반복 플레이 |
| 구슬당 금액 | 모든 베팅이 같은 금액(칩 크기 설정), 스핀 시작 시 확정 | "구슬당 베팅액" 규칙 |
| 칩 부족 | 구슬당 금액을 보유 칩 ÷ 베팅 수로 자동 축소, 최소 베팅 미만이면 불가 | 자동 스핀 중 멈춤 방지 |
| 연승 클로버 | 연승 5의 배수마다 +1, 패배(당첨 0개) 시 연승 0 | "5연승 +1" 의 반복 해석 |
| 개별숫자 클로버 | 적중 1건(베팅×공)마다 +1 | 공 2개·같은 칸 여러 구슬도 공정 |
| 부분 당첨 등급 | 당첨이 있으면 순손실이어도 NORMAL | LOSS 는 "진 연출"이라 이긴 구슬이 있으면 어색 |
| straight_payout_bonus | 개별숫자 당첨 × (1 + 값), base 0 | 다른 배율과 같은 곱셈 체계 |
| 황금 포켓 위치 | 개수가 늘 때 무작위 추가(0 포함) | 3단계에서 재배치 기능 추가 가능 |
| 스핀 시간 최소값 | 모든 배율 적용 후 1.5초로 제한 | 연출 가독성 |
| 광택 비용 | polish_base_cost × 2^단계 (나무 10, 그 외 재질 비용 × 0.5) | 초안, 3단계에서 조정 |

---

## 13. 2단계에서 정한 세부 규칙 (메인 화면·스핀 연출)

| 항목 | 결정 | 이유·구현 |
|---|---|---|
| 스핀 중 베팅 | 휠이 도는 동안 베팅창 잠금(클릭 시 거부음) | 판 위 구슬이 "걸린 구슬"로 보이게. `BetBoard.locked` |
| 스킵 | 스핀 중 SPIN·Space·휠 클릭 → 남은 연출을 0.3초로 감음 | `RouletteWheel.skip()` |
| 다음 스핀 | 정산 직후 바로 가능, 당첨 연출은 겹쳐서 계속된다. JACKPOT 만 클릭 대기, 오토 중엔 3초 뒤 자동으로 닫힘 | 방치 흐름 유지. `Main.auto_spin`(6단계) |
| SPIN 활성 | 칩 부족(자동 축소해도 최소 베팅 미만)이면 비활성 + 칩 카운터가 빨갛게 1회 흔들림. 베팅이 없으면 활성이지만 누르면 안내 툴팁 | 원인이 다른 두 상황을 구분 |
| 다시 걸기 | 직전 스핀의 칸 배치를 복원(`GameState.restore_last_bets`). 베팅이 이미 같으면 비활성 | 베팅이 스핀 후에도 남으므로 "초기화 뒤 복구" 용도 |
| 드래그 이동 | 칸 → 칸 은 `GameState.replace_bet_at`(구슬 수 불변), 칸 → 바깥은 회수 | 베팅 변경은 GameState 로만 |
| 초당 수익 | 스핀 순이익을 최근 60초 창으로 합산 ÷ min(60, 경과 시간[최소 10초]) | `IncomeTracker`. 초반 과소평가 방지 |
| 핫/콜드 | 최근 100 결과에서 많이 나온 3개(동률 → 최근), 적게 나온 3개(0회 포함, 동률 → 오래 안 나온 것 → 작은 숫자) | `HistoryStats` |
| 착지 보정 | 목표 포켓과의 차이를 먼저 전체 속도 배율(±12%, 발사 세기 차이로만 보임)로 흡수하고 나머지만 B 구간 창에 분산 | 짧은 스핀에서도 B 구간 속도 변화가 눈에 띄지 않게. `SpinChoreography` |
| 당첨 칩 표시 | 정산 즉시 GameState 에는 더해지지만, 상단 카운터는 날아온 칩 하나당 (반환액 ÷ 칩 수)만큼 올라간다 | "칩이 날아와 쌓이는" 연출. `TopBar.hold_payout()` |
| 날아가는 칩 수 | NORMAL 5 · GOOD 10 · BIG 16 · JACKPOT 24 | `Main.CHIP_FLIGHTS` |
| 새 게임 공 위치 | 기록이 없으면 0번 포켓에 공 | 휠에 항상 공이 보이게 |
| 연출 난수 | 휠 궤적 씨앗·불꽃·흔들림·피치는 `RngService` misc 스트림 | 결과 스트림을 건드리지 않음 |
| 결과 강제 | `RngService.force_next()` 는 테스트·캡처 도구 전용 | 게임 코드에서 쓰지 않는다 |
| 헤드리스 소리 | 헤드리스에서는 AudioManager 가 재생하지 않음(`enabled`) | 출력 장치 없음, 종료 시 누수 경고 방지 |
| 흔들림·번쩍임 설정 | `VisualSettings.screen_shake`, `reduce_flashing`(4단계 설정 화면이 바꿈) | ART_BIBLE 7장 |
