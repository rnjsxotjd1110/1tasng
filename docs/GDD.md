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
| 광택 배율 | 1.25^광택 단계 (0~5) | upgrade:marble_polish 수정자 |
| 광택 비용 | 현재 재질 polish_base_cost(= 재질 비용 × 0.08) × 1.7^현재 단계 × upgrade_cost_mult | UpgradeService.cost_at |
| 스핀 시간 | max(1.5, 6.0 × 0.9^(휠 속도 레벨) × spin_duration_mult) 초 | Economy.spin_duration |
| 파산 | 보유 칩 < 최소 베팅액 **이고** 진행 중인 스핀이 없음 | Economy.is_bankrupt |

**배율은 당첨에만 붙는다** → 기대값이 1을 넘을 수 있다.
- 나무 구슬(×1) 빨강 기대값 = 18/37 × 2 = **0.973** (손해)
- 돌 구슬(×1.5) 빨강 기대값 = 0.973 × 1.5 = **1.46** (이득) — 첫 업그레이드가 게임의 전환점.

### 4-1. 반환액 세부 (SpinContext)

```
반환 = 베팅액 × (배당+1)
     × marble_mult        (base 1 × upgrade:marble_tier(재질 배율) × upgrade:marble_polish(1.25^광택) × 그 외 수정자)
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

## 5. 업그레이드 (3단계 구현. 수치는 초안, 9단계에서 조정)

구매 규칙은 `UpgradeService`(scripts/core), 데이터는 `data/upgrades/*.tres`(UpgradeDef). 효과는 전부 StatModifiers 수정자(source `upgrade:<id>`), 비용에는 모두 `upgrade_cost_mult` 가 곱해진다.

| id (카드 순서) | 이름 | 효과 | 상한 | 비용 | 조건 |
|---|---|---|---|---|---|
| marble_tier | 구슬 재질 | 다음 재질로 교체. marble_mult MULT = 재질 배율 | 14(코스믹), **현재 층 marble_tier_cap** 까지 | 다음 재질 `MarbleDef.cost` | 한 번에 한 단계(승급 연출) |
| marble_polish | 광택 | marble_mult MULT 1.25/레벨. **재질이 오르면 0** | 5 | 현재 재질 비용 × 0.08 × 1.7^레벨 (`polish_base_cost`) | 돌 구슬부터(required_marble_tier 1) |
| bet_limit | 베팅 한도 | max_bet_mult MULT 1.35/레벨 | 무제한 | 20 × 1.2^레벨 | |
| marble_count | 구슬 개수 | marble_slots_bonus ADD 1 (최대 8개) | 7 | 300 × 22^(개수−1) | |
| spin_speed | 휠 속도 | spin_duration_mult MULT 0.9/레벨 (최소 1.5초) | 13 | 150 × 3.2^레벨 | |
| golden_pocket | 황금 포켓 | golden_pocket_count ADD 1. 결과가 황금 포켓이면 모든 당첨 ×3 | 5 | 50K × 800^레벨 | required_floor 2 (2F 에서 해금, 7단계 `FloorService` 로 실제 이동 가능) |

- **구매 수량**: ×1 / ×10 / MAX. ×10 은 남은 레벨이 적으면 그만큼만. MAX 는 등비수열 합 `base·g^L·(g^n − 1)/(g − 1)` 을 역산한 최대 n(부동소수 오차는 ±1 로 보정)이고, 한 레벨도 못 사면 1레벨 비용을 보여 준다. 재질은 수량과 무관하게 한 단계.
- **연속 구매**: 버튼을 누르고 있으면 0.4초 뒤부터 0.18초 간격으로 반복, 간격은 매번 ×0.85(최소 0.04초).
- **재질 상한**: `FloorDef.marble_tier_cap`(B1 철, 1F 금, 2F 루비, 3F 흑요석, PH 코스믹, 7단계에서 조정 — 7장 참고). 상한에 닿으면 카드에 "다음 재질은 1F에서".
- 황금 포켓 위치: 개수가 늘 때 아직 황금이 아닌 포켓 중 무작위(RngService misc). 0번 포함 가능. 새 포켓은 `EventBus.golden_pockets_added` 로 알린다.

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
| 6 | 옥 | ×70K | 164B | 2F |
| 7 | 루비 | ×800K | 13.1T | 2F |
| 8 | 사파이어 | ×1.2B | 1.05Qa | 3F |
| 9 | 에메랄드 | ×15B | 83.9Qa | 3F |
| 10 | 다이아몬드 | ×200B | 6.71Qi | 3F |
| 11 | 흑요석 | ×3T | 537Qi | 3F |
| 12 | 별빛 | ×50T | 42.9Sx | PH |
| 13 | 공허 | ×800T | 3.44Sp | PH |
| 14 | 코스믹 | ×15Qa | 275Sp | PH |

- 각 재질은 팔레트 5색(outline/shadow/base/light/shine)과 fx_id 를 가진다(ART_BIBLE "구슬 팔레트").

---

## 6. 스킬트리 (6단계 구현)

- 중앙 **"도박꾼의 심장"**(`heart`, 처음부터 레벨 1 보유, 구매 불가)에서 4갈래로 뻗는다.
  - 북 **FORTUNE**(-90°, 배당): 색·홀짝·개별숫자 배당, 황금 포켓 배율, 핫 넘버, 럭키 세븐, 잭팟 체인
  - 동 **MACHINE**(0°, 자동화): 오토 스핀, 스마트 베팅, 오토 업그레이드, 오프라인·휴식 보상, 딜러 고용
  - 남 **ECONOMY**(90°, 경제): 업그레이드 할인, 캐시백, 비상금, 투자 수익, 빚 조건, 황금 저금통, 복리
  - 서 **MYSTIC**(180°, 특수 기능): 제로 가드, 예지·천리안, 미러, 피버 타임, 더블 볼, 황금 폭풍, 운명 뒤집기, 운명의 휠
- **고리 3개(반지름 55/105/150) + 갈래별 궁극기(반지름 185), 노드 57개**(갈래당 1링 4·2링 5·3링 4·궁극기 1 = 14, ×4 + HEART = 57), **총비용 269 클로버**(`tools/data/generate_skill_data.gd` 가 생성 시 코드로 검증, `test_skill_service.gd::test_57_nodes_and_total_cost_269` 로 회귀 고정).
- 노드 위치는 갈래 중심각 ±40° 안에서 고리별 개수만큼 균등 분포(같은 링 안에서 서로를 선행조건으로 삼는 경우도 있다 — 링은 "선행조건 단계"가 아니라 "시각적 반지름"이다).
- 데이터: `SkillNodeDef`(branch, ring, position, costs[]=레벨별 클로버, prerequisites[]+prerequisite_mode(ALL/ANY), effects[]={stat,op,per_level} 배열(노드 하나가 여러 스탯에 동시에 영향 가능), feature_id, is_ultimate). 전체 노드 정의는 `data/skills/*.tres`(원본은 `tools/data/generate_skill_data.gd`).
- 효과는 `StatModifiers` 수정자(source `skill:<id>`)로 적용(`GameState.set_skill_level`/`rebuild_skill_modifiers`, `UpgradeService`/`GameState.set_upgrade_level` 와 동형). 스탯이 아닌 기능 해금(오토 스핀 등)은 `feature_id` 로 표시하고 `SkillService.feature_level(id)`/`has_feature(id)` 로 조회한다.
- 구매: `SkillService.purchase(id)`. 클로버 부족·잠김(선행조건 미충족)·최대 레벨이면 실패(-1). 재분배(리셋) 없음.

### 6-1. 효과 수치 표기 규칙(6단계에서 정함)

GDD 원문의 "+X%/Lv"·"×N/Lv"·"+N" 표기를 아래 규칙으로 기계적으로 변환했다(전부 초안, 9단계에서 재조정):

| 원문 표기 | 변환 | 예 |
|---|---|---|
| "×N/Lv" 또는 "×N (곱)" | `MULT`, per_level=N(복리, `pow(N, level)`) | F12 ×1.5/Lv → `payout_mult_all` MULT 1.5 |
| "+X%/Lv"·"−X%/Lv"·"X% 감면" | `MULT`, per_level=1±X/100(복리) | F1 +15%/Lv → `payout_mult_color` MULT 1.15 |
| 베이스가 0인 스탯(캐시백·확률 등)의 "+X%/Lv" | `ADD`, per_level=X/100(0에 곱연산은 의미가 없어 예외) | E2 캐시백 5%/Lv → `cashback_rate` ADD 0.05 |
| 베이스와 반대 방향(간격 vs 빈도)인 경우 | 역수로 변환(예외, 주석으로 표시) | E7 "빈도 −25%/Lv" → `penalty_interval_mult` MULT 4/3 |
| 절대값 "+N"(단위 있음: 초·시간·개수 등) | `ADD`, per_level=N | M4 오프라인 +2시간/Lv → `offline_cap_hours` ADD 2.0 |
| 배당 배수로 환산해야 하는 "+N"(개별숫자 배당) | `ADD`, per_level=N/36(35:1 을 (1+bonus) 곱셈 체계로 환산) | F3 +2/Lv → `straight_payout_bonus` ADD 2/36 |

### 6-2. 새 스탯·조건부 효과 처리(`SpinContext`/`RouletteRules`/`SpinController`)

- 결정론적(순수) 조건부 효과는 `SpinContext` 필드로 `RouletteRules.resolve()` 안에서 처리한다: `zero_guard`(Y1, 0이면 색·홀짝 반환), `cashback_rate`(E2), `hot_numbers`+`hot_number_straight_mult`(F6), `lucky_seven_mult`(F9), `zero_straight_mult`(Y7), `multi_hit_bonus`(F8).
- RNG 가 필요한 재판정·확률형 효과는 `RouletteRules` 를 순수하게 유지하기 위해 `SpinController._resolve_with_specials()`(운명 뒤집기 Y8, RngService misc 스트림으로 재판정 뒤 유리할 때만 채택)와 `_apply_mirror()`(미러 Y3, 진 베팅마다 확률로 무승부)로 분리했다.
- 스핀마다 반복되는 효과(VIP 컴프 E3, 보너스 칩 E9, 잭팟 체인 F14 충전·소모, 황금 폭풍 Y12, 피버 타임 Y5, 황금 저금통 E13)는 `SpinController._apply_outcome()` 뒤에 붙는 전용 `_apply_*()` 함수로 처리한다.
- 연승 보너스(F5+F11)·복리의 마법(E14)처럼 "현재 상태(연승 수·칩 자릿수)에 비례"하는 효과는 `GameState.build_spin_context()` 에서 직접 계산해 `payout_mult_all` 에 곱해 넣는다(별도 StatModifiers 항목이 아니라 매 스핀 재계산).
- 시간제(초) 버프는 전부 `GameState.add_buff()` 를 거치며, `skill:y13`(시간 왜곡)의 `buff_duration_mult` 스탯이 자동으로 곱해진다. 잭팟 체인·피버는 이 버프 체계를 그대로 써서 저장/복원과 `buff_started`/`buff_ended` 신호를 공짜로 얻는다.

---

## 7. 층 (7단계 구현)

B1(시작) → 1F(1M) → 2F(1T) → 3F(1Sx) → PH(1No) → 엔딩(1Dc로 하우스 인수)

| index | 층 | 이동 비용 | 당첨 배율(초안) | 베팅 배율(초안) | 해금 | 구슬 상한 tier | 클로버 | 목표 도달 |
|---|---|---|---|---|---|---|---|---|
| 0 | B1 | — | ×1 | ×1 | 기본 | 3 (철) | — | 0:00 |
| 1 | 1F | 1M | ×10 | ×100 | — | 5 (금) | +10 | 0:30 |
| 2 | 2F | 1T | ×1K | ×10K | 황금 포켓(`golden_pocket` 업그레이드) | 7 (루비) | +10 | 1:30 |
| 3 | 3F | 1Sx | ×100K | ×1M | — | 11 (흑요석) | +10 | 2:45 |
| 4 | PH | 1No | ×10M | ×100M | — | 14 (코스믹) | +10 | 4:00 |
| — | 엔딩 | 1Dc | | | | | | 5:00 |

- 층 이동은 칩을 지불한다. **리셋 없음**(업그레이드·구슬·스킬 유지). 배율 상승, 클로버 +10. `FloorService.move_to_next()`.
- 재질 상한에 닿으면(`UpgradeService.Status.CAPPED_BY_FLOOR`) 구슬 재질 카드에 "다음 층에서 해금"이 뜬다(`UpgradeService.floor_for_marble_tier`, 3단계부터 이미 구현돼 있었다).
- 배율(payout_mult)·구슬 상한은 7단계에서 1단계 초안을 다시 조정했다(17장 참고). 이동 비용(1M/1T/1Sx/1No/1Dc)·베팅 배율·클로버 보상은 1단계 값 그대로.

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
- 빚이 있는 동안 랜덤 패널티(20~30초 지속, 직전과 같은 종류 연속 금지)가 걸린다. 간격은 대출 건수가 늘수록 짧아진다
  (`penalty_interval_mult` 로 추가 조정): 1건 60~120초 / 2건 45~90초 / 3건 30~60초.

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

## 10. 엔딩과 업적 (7단계 구현)

### 10-1. 엔딩 시퀀스

PH 에서 1Dc 지불(`EndingService.trigger()`, `Economy.ENDING_COST`) → 마담 벨벳의 "마지막 한 판" 대사 → **최후의 스핀**(8초, 오직 연출용 — `RngService.*_misc()` 로 뽑은 결과를 `wheel.play_spin()` 에 직접 넘기고 `SpinController`/경제 정산은 전혀 거치지 않는다) → 착지 효과(화면 흔들림·플래시·코인 파티클) → 골드 웨이브(휠 위에 금색 원호가 한 바퀴 돈다) → 양도 증서 서명(`ContractPopup.open_custom()` 으로 5단계 계약서 컴포넌트를 재사용, 서명·도장 메커니즘 동일) → 에필로그(벨벳→루시→남작 순서로 대사, 남작이 남은 빚 탕감을 언급) → 네온 간판 "HOUSE EDGE" 점등(`NeonText` 재사용, `NEON_CHARS` 에 H·S·D 3글자 추가) → 크레딧(`EndingCredits`).
`EndingService.can_trigger()` 는 PH(마지막 층)이고 보유 칩이 `ENDING_COST` 이상이며 아직 엔딩을 안 봤을 때만 true. `trigger()` 는 칩을 낸 뒤 `GameState.ending_reached=true` 로 표시하고 남은 빚을 전부 탕감(`GameState.forgive_debt(1.0)`)한 뒤 `EventBus.ending_triggered()` 를 발행한다(실제 컷신은 `EndingSequence.play()` 가 재생 — `AcquisitionButton` 을 누르면 `Main._on_acquisition_pressed()` 가 `trigger()` 와 `play()` 를 함께 부른다).
`EndingSequence` 는 `wheel`·`shaker`·`flash` 를 Main 이 소유한 화면 요소로 직접 참조 주입받는다(다른 컷신은 `signed()`/`finished()` 신호로 Main 에 되돌리지만, 이 연출은 사실상 화면 전체를 쓰는 이펙트라 직접 참조가 더 단순하다는 판단, 17장 참고).

### 10-2. 무한 모드

엔딩 크레딧(`EndingCredits`: 플레이 시간·총 스핀·최대 당첨금·최대 연승·대출 횟수·최다 출현 숫자·최종 구슬 통계 카드) 뒤 "계속하기"를 누르면 `Main._on_ending_continue_pressed()` 가 `EndingService.enter_infinite_mode()` 를 불러 `GameState.infinite_mode=true` 로 표시하고 영구 수정자 `ending:owner_mode`(`payout_mult_all` MULT `Economy.OWNER_MODE_PAYOUT_MULT`=2.0, 오너 모드 "수익 ×2")를 건다. 불러오기 뒤에는 `GameState.rebuild_ending_modifiers()` 가 `infinite_mode` 값을 보고 이 수정자를 다시 건다(`rebuild_upgrade_modifiers`/`rebuild_skill_modifiers` 와 같은 패턴). 상단 바 오른쪽(클로버 옆)에 작은 금색 왕관 아이콘이 뜬다(`TopBar._draw_crown()`, 절차적 드로잉이라 새 스프라이트 없음).

### 10-3. 업적

- `data/achievements.json`(표시용 메타데이터: id·category·name_key·desc_key·icon·hidden) + `AchievementData`(정적 로더, `DialogueData` 와 동형) + `AchievementManager`(`GameState.achievement_manager` 가 소유, `PenaltyManager` 와 동형인 RefCounted — `attach()` 로 필요한 `EventBus` 신호를 구독해 조건을 판정하고, 시간 기반 조건(1시간 무파산)만 `process(delta)` 로 잰다).
- 조건 판정은 데이터가 아니라 코드(`AchievementManager._on_*`)로 한다 — 30개 안팎의 대부분이 한 번뿐인 개별 조건이라 범용 규칙 엔진보다 명시적 분기가 더 읽기 쉽다(6단계 특수 기능과 같은 판단).
- 해금되면 `GameState.unlocked_achievements`(Array[String], 저장됨)에 추가하고 `EventBus.achievement_unlocked(id)` 를 발행한다. `AchievementToast`(화면 우하단, `BadgeGolden` 패널, 0.3초 슬라이드인·4초 유지·0.2초 슬라이드아웃, 여러 개는 큐에 쌓아 순서대로) 와 일시정지 메뉴의 `AchievementScreen`(카테고리별 아이콘 그리드, 달성=원색 아이콘, 미달성=실루엣, 숨김+미달성="???")이 이 신호와 `GameState.unlocked_achievements` 를 그대로 읽어 그린다.
- 아이콘 30종+숨김용 1종은 `tools/art/gen_achievements.py` 가 `gen_skills.py` 의 배지+글리프 조합 방식을 재사용해 24px 로 그린다(카테고리별 5색 램프, 달성/실루엣/숨김 세 버전).
- 숨김 업적(벨벳 대사 전부 보기)은 `GameState.achievement_dialogue_seen`(저장됨, `{대사 키: {변형 인덱스: true}}`)에 `AchievementManager.mark_dialogue_seen()` 으로 기록하다가 한 키의 모든 변형을 다 보면 해금된다. 호출부는 `Main._show_velvet_periodic_line()`(벨벳의 주기 대사 `ph_periodic` 키 — 대사 자체가 랜덤 변형을 도는 유일한 키라 이 업적에 쓸 수 있는 키다. `DialogueData.pick()` 은 내부에서 무작위로 골라 인덱스를 감추므로, 인덱스가 필요한 이 호출부만 별도로 둔 `DialogueData.variant_at()` 을 쓴다).
- 목록: 30개 요청 중 "누적 스핀 1000/10000"은 2개로 센다. 명시된 항목을 모두 헤아리면 27개라, 진행·기능 카테고리에 3개(2F 도달·3F 도달·첫 황금 포켓 적중)를 채워 30개를 맞췄다.

### 10-4. 마담 벨벳

펜트하우스 전용 월드 액터(`MadameVelvet`, `Lucy`/`Baron` 과 동형인 순수 연출 클래스 — idle/wine/gesture/clap 4가지 애니메이션). PH 에 있을 때만 보이고(`Main._refresh_velvet()`), 다른 층으로 가면 주기 대사 타이머가 꺼진다.
- **첫 방문**: `GameState.velvet_intro_seen`(저장됨) 이 false 면 도착 즉시 소개 대사(`ph_first_visit`, 3줄)를 보여주고 true 로 바꾼다.
- **주기 대사**: PH 에 있는 동안 5~8분(`Main.VELVET_PERIODIC_MIN/MAX`)마다 `ph_periodic`(변형 4개) 중 하나를 무작위로 말한다.
- **엔딩 대사**: 하우스 인수 버튼을 누르면 `velvet_last_hand`(마지막 한 판 요구), 서명 뒤에는 `velvet_epilogue`.
- 루시·벨벳 모두 같은 대사창(`DialogueBox`, `_npc_dialogue`)을 공유해 화면에 한 번에 하나만 뜬다. 엔딩이 시작되면 마침 떠 있던 주변 대사(`_npc_dialogue`)를 먼저 숨긴다(엔딩 전용 대사창과 자리가 겹치므로).
- 초상화·월드 스프라이트는 `tools/art/gen_velvet.py`(은발 올림머리·짙은 빨강 드레스·진주 목걸이, `gen_lucy.py` 와 같은 골격 재사용).

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
| `upgrade_purchased(id: String, level: int)` | 업그레이드 구매 완료(구매 후 레벨, 여러 레벨을 한 번에 사도 1회) |
| `golden_pockets_added(numbers: Array[int])` | 황금 포켓이 새로 생김(빛줄기·베팅칸 금 테두리 연출) |
| `skill_purchased(id: String, level: int)` | 스킬 구매 (6단계) |
| `floor_changed(floor_index: int)` | 층 이동 (7단계) |
| `milestone_reached(suffix_index: int)` | 새 칩 단위 첫 도달 |
| `buff_started(id: String, duration: float)` | 시간제 버프·패널티 시작 |
| `buff_ended(id: String)` | 시간제 버프·패널티 종료(소모형 패널티는 charges 가 0 이 될 때도 발행) |
| `penalty_triggered(id: String, duration: float)` | 패널티 발동(5단계, 토스트 표시용 — `buff_started` 와 별개로 즉시·소모형 패널티도 받는다) |
| `toast_requested(text: String, icon: String)` | 알림 요청 |
| `save_started()` | 저장 시작(4단계). TopBar 가 구석에 칩 회전 아이콘을 0.8초 보여준다 |
| `save_finished(ok: bool)` | 저장 끝(저장은 동기 처리라 save_started 와 거의 동시) |
| `piggy_bank_broken(amount: float)` | 황금 저금통(E13)이 100스핀마다 깨지며 칩 지급(6단계) |
| `wheel_of_fortune_ready()` | 운명의 휠(Y14) 등장 시각. `GameState.wheel_of_fortune_consumed()` 로 다음 주기 시작 |
| `golden_storm_triggered(spins: int)` | 황금 폭풍(Y12) 발동 |
| `destiny_flip(from_number: int, to_number: int)` | 운명 뒤집기(Y8) 재판정 발생 |
| `auto_spin_stopped(reason: String)` | 오토 스핀이 자동으로 꺼짐(칩 부족·베팅 없음·대화 시작·파산) |
| `streak_clover_earned(count: int)` | 5연승 클로버 지급(연출용, 클로버 자체는 `clovers_changed` 로도 옴) |
| `first_clover_earned()` | 살면서 처음 클로버 획득 — 스킬트리 탭 자물쇠 해제 + 루시 대사 트리거 |
| `achievement_unlocked(id: String)` | 업적 해금(7단계). `AchievementData` 로 이름·아이콘 조회 |
| `ending_triggered()` | PH 에서 1Dc 를 내고 하우스 인수 확정(7단계, 엔딩 컷신 시작 신호) |
| `infinite_mode_started()` | 엔딩 크레딧 뒤 "계속하기"로 무한 모드(오너 모드) 진입 |
| `tutorial_reset_requested()` | 설정 화면의 튜토리얼 "다시 보기"(8단계 2/N). `TutorialGuide.restart()` 가 이 신호를 구독해 1단계부터 다시 시작한다 |

### 11-3. GameState

- 필드: chips(시작 100), clovers, floor_index, upgrade_levels, skill_levels, marble_tier, polish_level, current_bets(Array[Bet]), last_bets, chip_size_mode, debts, win_streak, result_history(최근 100), number_frequency(포켓 번호 → 누적 출현 횟수, 통계용), golden_pockets, highest_milestone, spin_in_progress, pending_spin_bets/pending_spin_results(스핀 도중 저장용 스냅샷, 4단계), auto_spin_enabled(6단계 자동 스핀. 해금 수단이 없어 지금은 항상 false), last_income_per_second(마지막 저장 시점 초당 순수익, 오프라인 수익 계산용), modifiers(StatModifiers), income_tracker(IncomeTracker, 최근 Economy.LOAN_INCOME_WINDOW(5분) 이동평균, 오프라인 수익·5단계 대출액 계산에 공용), unlocked_achievements(Array[String], 7단계), achievement_dialogue_seen(Dictionary, 7단계 숨김 업적용), achievement_manager(AchievementManager, 7단계), ending_reached/infinite_mode/velvet_intro_seen(bool, 7단계)
- stats: total_spins(총 스핀), total_wins(당첨 스핀 수, 승률 계산용), biggest_win(최대 당첨=한 스핀 최대 반환액), best_streak(최대 연승), play_time(초), loans_taken(대출 횟수), straight_hits(적중 숫자 수), total_earned(누적 획득 칩 = 당첨 반환액 합계, 대출금·오프라인 수익 제외)
- `add_chips()/spend_chips()` 는 음수·NaN·INF 를 거부하고(경고 로그) false 를 돌려준다. spend 는 잔액 부족도 거부.
- `to_dict()/from_dict()`(4단계): SaveManager 가 쓴다. `from_dict()` 호출 뒤에는 반드시 `rebuild_upgrade_modifiers()`(영구 수정자 재구성)를 불러야 한다(SaveManager.load_game() 은 이미 그렇게 한다). 시간제(`buff:`) 수정자만 함께 저장/복원하고, 영구 수정자는 upgrade_levels/skill_levels 에서 다시 만든다.

### 11-4. StatModifiers

- 수정자: `{source_id, stat, op(ADD/MULT), value, duration(PERMANENT=-1), charges(5단계, -1=무제한)}`
- `get_stat(key, base) = (base + ADD 합) × MULT 곱`. 스탯별 캐시, 변경 시 무효화.
- 같은 source_id + stat 으로 다시 추가하면 **교체**(업그레이드 레벨 갱신에 사용).
- `tick(delta)`: 시간제 수정자 만료 → source 의 수정자가 모두 사라지면 `source_expired` → GameState 가 `buff:`/`penalty:` 접두어면 `EventBus.buff_ended` 로 전달.
- `consume_charges(source_id, amount=1)`(5단계): 시간이 아니라 "횟수"로 소모되는 수정자(압류=스핀 1회, 클로버 수수료=클로버 획득 1회)를
  줄이고, 0 이하가 되면 duration 과 마찬가지로 제거·`source_expired` 발행.
- `remove_source(source_id)`: 일괄 제거.
- 스탯 키(`StatModifiers.ALL_STATS`, 1~5단계): payout_mult_all, payout_mult_color, payout_mult_parity, straight_payout_bonus, marble_mult, floor_mult, golden_pocket_count, golden_pocket_mult, max_bet_mult, marble_slots_bonus, locked_marbles, extra_balls, spin_duration_mult, spin_delay, upgrade_cost_mult, cashback_rate, offline_efficiency, offline_cap_hours, clover_gain_mult, debt_repay_mult, penalty_interval_mult, debt_paid_clover_bonus
- 6단계 추가 스탯: clover_bonus_chance(F4), streak_bonus_per_win/streak_bonus_cap(F5·F11), hot_number_straight_mult(F6), multi_hit_bonus(F8), lucky_seven_mult(F9), milestone_clover_bonus(F13), smart_betting_bonus(M12), min_spin_duration_stat(M10), vip_comp_rate(E3), investment_rate(E5), marble_cost_mult(E8), bonus_chip_per_hit(E9), upgrade_growth_mult(E12), piggy_bank_rate(E13), compound_interest_per_digit(E14), mirror_chance(Y3), zero_straight_mult(Y7), destiny_flip_chance(Y8), fever_period_reduction/fever_duration_bonus(Y11), golden_storm_chance(Y12), buff_duration_mult(Y13). 전체 정의는 `scripts/core/stat_modifiers.gd` 참고.

### 11-5. RngService

- 스핀 결과(outcome 스트림)와 그 외(misc 스트림)를 분리 → 연출·패널티 난수가 결과를 바꾸지 않는다.
- `peek_next(n)`: 다음 n개 결과를 소비하지 않고 본다. 이후 `consume_next()` 는 반드시 그 결과를 낸다(예지 스킬).
- `get_state()/set_state()`: 저장용. SaveManager 가 save 데이터의 `"rng"` 필드로 함께 저장·복원한다.

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
| 광택 비용 | ~~polish_base_cost × 2^단계~~ → 3단계에서 재질 비용 × 0.08 × 1.7^단계로 변경(14장) | 초안 |

---

## 13. 2단계에서 정한 세부 규칙 (메인 화면·스핀 연출)

| 항목 | 결정 | 이유·구현 |
|---|---|---|
| 스핀 중 베팅 | 휠이 도는 동안 베팅창 잠금(클릭 시 거부음) | 판 위 구슬이 "걸린 구슬"로 보이게. `BetBoard.locked` |
| 스킵 | 스핀 중 SPIN·Space·휠 클릭 → 남은 연출을 0.3초로 감음 | `RouletteWheel.skip()` |
| 다음 스핀 | 정산 직후 바로 가능, 당첨 연출은 겹쳐서 계속된다. JACKPOT 만 클릭 대기, 오토 중엔 3초 뒤 자동으로 닫힘 | 방치 흐름 유지. `GameState.auto_spin_enabled`(4단계에서 GameState 로 옮김, 6단계에서 실제 자동 스핀 루프가 채운다) |
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

---

## 14. 3단계에서 정한 세부 규칙 (업그레이드·구슬 재질)

| 항목 | 결정 | 이유·구현 |
|---|---|---|
| 업그레이드 id | `wheel_speed` → `spin_speed`, 재질·광택도 업그레이드(`marble_tier`, `marble_polish`)로 통일 | 요청 명세. 모든 효과를 `upgrade:<id>` 수정자로 |
| 재질 배율 | marble_mult 의 base 는 1, 재질 배율은 `upgrade:marble_tier` MULT(나무 레벨 0 도 ×1 로 건다), 광택은 `upgrade:marble_polish` | "효과는 전부 StatModifiers" 규칙. `GameState.marble_tier/polish_level` 은 읽기용 사본 |
| 광택 초기화 | 재질 구매 시 `UpgradeService.purchase` 가 광택을 0 으로(`set_upgrade_level` 자체는 초기화하지 않음) | 불러오기(4단계)에서 레벨을 다시 걸 때 광택이 지워지지 않게 |
| 나무 구슬 광택 | 불가(돌부터). 광택 5 나무(×3.05)가 돌(×1.5)보다 높아 돌 구매가 손해가 되는 역전 방지 | "첫 업그레이드 = 돌" 전환점 유지 |
| 재질 구매 수량 | ×10·MAX 여도 한 단계 | 단계마다 승급 연출 |
| MAX 표시 | 살 수 있는 수량을 버튼에 "×37" 로, 0 이면 "×1" + 1레벨 비용 + 부족분 진행 바 | 요청 명세 |
| 효과 표시 | 재질: 재질 배율(광택 제외) / 광택: 광택 배율 / 베팅 한도: 한도 배율 / 구슬: 보유 개수 / 휠: 스핀 초 / 황금: 개수. MAX·×10 이면 "다음" 은 그 수량 뒤의 값 | `UpgradeService.display_value` |
| 탭 빨간 점 | 1레벨이라도 살 수 있는 업그레이드가 있으면. 업그레이드창을 연 동안은 숨김 | 이미 보고 있는 화면에 알림을 겹치지 않게 |
| 승급 적용 시점 | 재질은 구매 즉시 GameState·당첨금에 반영, 화면의 구슬 모양은 승급 연출에서 구슬이 목적지(베팅창 트레이 또는 재질 카드)에 닿는 순간 한꺼번에 바뀐다. 클릭·Space 로 건너뛰면 즉시 | "모든 구슬이 새 재질로 바뀐다" 연출. `MarbleSprite.sync_shared` |
| 새 슬롯 연출 | 구슬 개수 구매 시 베팅창이 보일 때 재생(업그레이드창에서 샀으면 돌아왔을 때) | 보이지 않는 곳에서 끝나 버리지 않게 |
| 황금 포켓 표시 | 빛줄기가 포켓에 닿는 순간(0.46초) 휠 포켓이 금색, 베팅칸 금 테두리도 같은 시각 | 요청 명세 |
| 숫자 표기 | 배율 `format_mult`("×1.25", 1000 미만도 유효숫자 3자리), 초 `format_seconds`, 백분율 `format_percent`. 번역 문자열의 숫자 자리는 `%s` + NumberFormat(%d 금지, 테스트로 검사) | 전수 점검 |
| 0 과 O | 큰 숫자 폰트(num14)의 0 가운데에 점 | 단위 Oc·Ocd 의 O 와 구분 |
| 디버그 패널 | F9, 개발 빌드(`OS.is_debug_build()`)에서만 Main 이 `scenes/debug/debug_panel.gd` 를 동적 로드 | 내보내기 빌드에는 붙지 않음 |

---

## 15. 4단계에서 정한 세부 규칙 (저장·오프라인 수익·설정·일시정지·통계)

| 항목 | 결정 | 이유·구현 |
|---|---|---|
| 저장 형식 | `{"version","saved_at","checksum","data"}`, `data` 는 (객체가 아니라) `JSON.stringify()` 한 **문자열**을 한 번 더 담는다 | Godot 의 JSON 숫자 파서가 1e250 급 극단적으로 큰 실수를 다시 읽을 때 마지막 몇 비트가 흔들리는 것을 실측 확인. `data` 를 객체로 두면 "체크섬 검증"이 재직렬화 과정에서 그 흔들림 때문에 정상 파일을 손상으로 오검출할 수 있다. 문자열로 감싸면 체크섬은 항상 원문 바이트를 그대로 비교하므로 안전하다. 값 자체의 오차는 상대오차 1e-9 이내로, `NumberFormat` 표시 정밀도(3자리)에는 전혀 영향 없다(`check_rel` 로 테스트) |
| 원자적 저장 | `save.tmp` 에 쓰고 다시 읽어 JSON 파싱까지 확인 → 기존 `save.json` 이 있으면 `save.bak` 으로 교체 → `save.tmp` 를 `save.json` 으로 교체(둘 다 `DirAccess.rename_absolute`, 대상이 있으면 먼저 지움 — Windows 호환) | 쓰다가 중단돼도 `save.json` 은 항상 이전 버전이거나 완전한 새 버전만 있다 |
| 손상 복구 | `save.json` 체크섬이 안 맞으면 `save.bak` 을 시도. 그것도 실패하면 토스트로 알리고 새 게임처럼 시작(되돌릴 수 없음) | 요청 명세 |
| 마이그레이션 | `SaveManager._migrate(data, from_version)`: `match from_version` 에 케이스를 추가하는 구조만 미리 만들어 둠(지금은 버전 1뿐이라 실제 변환은 없음) | 5단계 이후 세이브 필드가 늘 때를 위한 틀 |
| 스핀 도중 저장 | `SpinController.start_spin()` 이 `GameState.pending_spin_bets/pending_spin_results` 에 스냅샷을 남기고(`spin_in_progress=true`), `finish_spin()` 이 정상 종료되면 비운다. 불러온 뒤 `spin_in_progress` 가 true 면 `SpinController.settle_pending_spin()` 이 연출 없이 즉시 정산(Main 이 UI 를 만들기 전에 호출) | GameState 만 보고도 SaveManager 가 스핀 상태를 저장·복원할 수 있게(core 레이어 안에서 해결) |
| 오프라인 수익 분기 | `OfflineIncome.compute()`: 오토 스핀 해금 전(`GameState.auto_spin_unlocked()`, 6단계 전엔 항상 false) → 항상 "팁" 모드(효율 5%). 해금 후 오토가 켜져 있었으면 "전체"(기본 30%). 해금 후 꺼져 있었으면 "없음"(0) | 요청 명세. 6단계가 `auto_spin_unlocked()` 를 실제 스킬 조건으로 바꾸고 `GameState.auto_spin_enabled` 를 실제 토글에 연결하면 그대로 동작한다 |
| 오프라인 수익 상한 | `Economy.offline_income(초당수익, 경과초, cap_hours, efficiency)`: `min(경과, cap_hours×3600) × efficiency`. 경과가 음수(시계 조작)거나 60초(`Economy.OFFLINE_MIN_ELAPSED`) 미만이면 계산 자체를 하지 않음(팝업도 없음) | 요청 명세 |
| 초당 수익 공용화 | `GameState.income_tracker`(`IncomeTracker`, 창 `Economy.LOAN_INCOME_WINDOW`=5분)를 스핀마다 `SpinController._apply_outcome` 이 채운다. 저장 시점 값을 `income_per_second_at_save` 로 저장 | GDD 9장 "대출액" 공식도 "최근 5분 평균 초당 순수익" 을 쓰므로 5단계가 같은 트래커를 그대로 쓸 수 있다. TopBar 의 60초 창 트래커(2단계, 화면 표시용)와는 별개 |
| offline_efficiency 기본값 | 1단계 초안 0.25 → 요청 명세대로 **0.3** 으로 조정(`Economy.OFFLINE_EFFICIENCY`) | 초안 수치를 확정 명세로 |
| 설정 파일 | `user://settings.cfg`(ConfigFile), 세이브(`save.json`)와 완전히 분리. `SettingsManager` 오토로드가 필드를 갖고, 화면은 필드를 직접 바꾼 뒤 `commit()`(적용+저장)만 부른다 | 개별 setter 를 필드마다 만들지 않아도 됨(요청 규모 대비 최소 구현) |
| 스핀 연출 속도 | `SettingsManager.spin_visual_speed`(보통/빠름/최고속, ×1/×1.5/×2)는 `Main._on_spin_started` 가 `wheel.play_spin` 에 넘기는 duration 에만 곱한다 | `GameState.spin_duration()`(경제 공식)·`Economy` 는 그대로 — "연출"이라는 이름대로 scenes 레이어에서만 적용. `SpinChoreography` 는 이미 다양한 duration 에 적응하므로 추가 변경 없이 동작 |
| 큰 당첨/오토 연출 간략화 | `VisualSettings.full_effects(tier, is_auto_spin)`: 오토 스핀 중이고 "오토 연출 줄이기" 켜져 있으면 BIG 미만은 파티클·흔들림 생략. "큰 당첨 연출 간략" 이면 BIG·JACKPOT 도 배너·플래시·흔들림 생략. 두 경우 모두 떠오르는 텍스트·소리·클로버 비행은 그대로 | 요청 명세. `auto_spin_enabled` 가 실제로 true 가 되는 건 6단계부터라 지금은 이 분기가 항상 "전체 연출" 쪽으로만 간다 |
| 색약 보조 | 새 텍스처 없이 프로시저럴로: 휠은 빨강 포켓 채우기 위에 아이보리 점 2개(`RouletteWheel._draw_colorblind_dots`), 베팅판은 숫자 칸 토큰·바깥 R 칸에 같은 방식(`BetBoard._draw_colorblind_dots`) | 새 팔레트 확인이 필요한 에셋을 늘리지 않음 |
| 일시정지 시간 흐름 | 기본은 "흐름"(옵션 꺼짐, `SettingsManager.pause_time_flows=true`) → `get_tree().paused` 를 건드리지 않는다. 옵션을 켜면(흐름 끔) 일시정지 메뉴·통계 화면이 열려 있는 동안만 `get_tree().paused=true`. `PauseMenu`·`StatsScreen` 은 `process_mode=PROCESS_MODE_ALWAYS` 라 멈춰 있어도 자기 자신은 계속 동작(Esc 로 닫기 포함) | 방치형 기본 정체성(항상 진행)은 지키면서 원하면 완전히 멈출 수 있게. `Main._update_pause_freeze()` |
| Esc 우선순위 | 통계 → 설정 → 스킬트리 → 일시정지 메뉴 순으로 열려 있는 것부터 닫고, 아무것도 없으면 일시정지 메뉴를 연다. 일시정지 메뉴가 열려 있을 때 닫는 것은 `PauseMenu` 자신의 `_unhandled_input` 이 맡는다(Main 은 `pause_menu.visible` 이면 그 branch 를 건너뛴다) | `Main` 은 `PROCESS_MODE_ALWAYS` 가 아니라 tree 가 paused 면 입력을 못 받으므로, "멈춰 있을 때도 Esc 로 닫기"는 항상 동작하는 PauseMenu 쪽이 책임진다 |
| 통계 신규 항목 | `GameState.stats["total_wins"]`(당첨 스핀 수, 승률=`total_wins/total_spins`), `GameState.number_frequency`(포켓 번호 → 누적 횟수, `most_frequent_number()`) 를 4단계에서 추가 | 승률·최다 출현 숫자는 기존 필드로 계산할 수 없었음 |
| 복귀 팝업 | 딜러 루시 초상화가 없으면(`assets/sprites/npc/lucy_portrait.png` 존재 여부로 자동 판단) `icon_vault.png`. [받기] 를 누르면 `GameState.add_chips(income, count_as_earned=false)` | 오프라인 수익은 "당첨 반환액"이 아니므로 `total_earned` 통계에는 넣지 않는다(GDD 11-3 정의 유지). 8단계에서 초상화 파일만 추가하면 자동으로 바뀐다 |
| auto_spin 이동 | `Main.auto_spin`(항상 false 였던 6단계용 자리) 를 `GameState.auto_spin_enabled` 로 옮김 | 오프라인 수익·저장이 필요로 하는 값이라 GameState 소유가 맞음. `SpinControls.auto_locked` 는 여전히 true(6단계에서 스킬로 해금) |
| 테스트 격리 | `tests/lib/test_case.gd` 의 공용 `before_each()` 가 `save.json/.tmp/.bak` 을 먼저 지운다 | `Main._ready()` 가 이제 `SaveManager.load_game()` 을 부르므로, 컨테이너에 실제로 남은 저장 파일이 있으면 Main 을 새로 만드는 모든 테스트가 그 값을 그대로 불러와 버린다(실제로 겪은 문제) |

---

## 16. 5단계에서 정한 세부 규칙 (빚·래칫 남작·대화·패널티)

| 항목 | 결정 | 이유·구현 |
|---|---|---|
| 4번째 대출(합산) | 새 항목을 만들지 않고 **잔액이 가장 큰 기존 빚**에 원금·잔액을 그대로 더한다(`DebtService.take_loan`). 전용 대사(`loan_overflow`, "장부가 꽉 찼는데… 뭐, 한 줄 더 쓰지.") 로 표시 | "최대 3건" 규칙을 넘지 않으면서도 "빚이 하나 더 늘었다"는 사실 자체는 서사적으로 살려야 했다 |
| 자동 상환 순서 | 여러 건일 때 **오래된 순**(배열 인덱스 순)으로 갚고, 한 건을 다 갚고 남은 초과분은 다음 빚으로 넘어간다(`DebtService.apply_auto_repay`) | 어느 빚부터 갚을지 원 설계에 명시가 없어 "먼저 진 빚부터"를 기본으로 정함 |
| 완납 컷신 발동 조건 | 개별 대출이 0 이 되는 시점이 아니라 **총 빚(모든 대출 합)이 0** 이 되는 순간에만 발동(`GameState._repay_debt` 가 합계를 확인) | 여러 건 중 하나만 갚아도 매번 남작이 등장하면 과하다. "빚에서 완전히 벗어났다"는 순간만 컷신으로 축하 |
| 수동 상환 버튼 의미 | `DebtPanel` 의 [전액 상환]=그 건의 **잔액 전부**, [절반 상환]=그 건의 **잔액의 50%**(원금 기준 아님, 매번 그 시점 잔액 기준) | 명세에 정확한 산식이 없어 "지금 남은 만큼"을 기준으로 통일. 둘 다 보유 칩으로 한도를 건다 |
| 컷신 중단 후 재개 | 저장 시점에 아직 못 본 컷신은 `GameState.pending_baron_event` 에 남고, 다음 로드 때 **처음부터 다시 재생**한다(중간 지점 재현 아님) | 대출/완납으로 인한 실제 수치 변화(칩·debts 배열)는 파산·완납 감지 즉시 동기적으로 끝내고, 컷신은 그 결과를 보여주기만 하는 연출이다(스핀 도중 저장을 연출 없이 즉시 정산하는 4단계 패턴과 동일). 그래서 수치는 항상 정확하고 연출만 다시 보여주면 안전하다 |
| 클로버 최소 1 | `GameState.add_clovers()`: 배율이 0 보다 크고 원래 수량도 0 보다 크면 결과가 최소 1 이 되도록 보정 | 클로버 수수료 패널티 전용 분기가 아니라 **일반 규칙**으로 넣었다 — 나중에 다른 배율 디버프가 추가돼도 "클로버 획득이 통째로 0" 이 되는 극단은 항상 막힌다 |
| 소모형(charges) 수정자 | `StatModifiers.Modifier` 에 시간(`duration`)과 별개로 `charges` 축을 추가, `consume_charges()` 로 소모 | 압류(스핀 1회)·클로버 수수료(획득 1회)처럼 "시간"이 아니라 "횟수"로 끝나는 효과가 1단계부터 표현할 수단이 없었던 이슈를 최소 확장으로 해결 |
| 패널티도 버프 체계 재사용 | 시간제 패널티(감시하는 부하·흐려진 구슬·시가 연기)는 `buff:` 가 아니라 `penalty:` 접두어만 다르고 나머지는 기존 시간제 수정자·`buff_started`/`buff_ended` 신호를 그대로 쓴다. 새 시그널은 토스트 표시에 필요한 `penalty_triggered(id, duration)` 1개뿐 | 이미 있는 시간제 만료·저장/복원 체계를 그대로 재사용해 중복 구현을 피함 |
| 소매치기만 별도 방어 | `steal = min(chips × rate, max(0, chips − 최소베팅×3))` | 6종 중 유일하게 "즉시 차감"형이라 패널티 자체가 파산을 유발할 수 있는 경로였다. 나머지 5종은 배율·소모형 수정자라 애초에 칩을 직접 줄이지 않는다 |
| 범위에서 뺀 것 | (1) BIG 이상 당첨 연출·오토스핀 중 패널티 억제는 `PenaltyManager.suppressed` 를 대화창·계약서 팝업 동안만 실제로 세운다(BIG+ 연출 중 억제는 발생 빈도가 낮아 이번 범위에서 제외). (2) 남작 컷신 중 음악 볼륨 덕킹은 음악 시스템 자체가 아직 없어(8단계 예정) 스킵 — 대신 `bass_drop` 효과음 한 번으로 파산 순간을 표현 | 명세의 핵심(대출·상환·패널티·컷신)에 집중하고, 아직 없는 시스템에 의존하는 디테일은 다음 단계로 미룸 |

---

## 17. 7단계에서 정한 세부 규칙 (층 진행·엔딩·업적)

| 항목 | 결정 | 이유·구현 |
|---|---|---|
| 층 배율·구슬 상한 재조정 | 1단계 초안(payout_mult ×2/×4/×8/×16, 1F/2F/3F 구슬 상한 옥/에메랄드/별빛)을 이번 단계 요청 명세(×10/×1K/×100K/×10M, 상한 금/루비/흑요석)로 교체. 이동 비용(1M/1T/1Sx/1No)·베팅 배율(×100/×10K/×1M/×100M)·클로버 보상(+10)·PH 구슬 상한(코스믹)은 요청과 1단계 값이 이미 같아 그대로 뒀다. 황금 포켓 업그레이드의 `required_floor=2`(2F)도 1단계부터 이미 요청과 일치했다 | "초안 — 9단계에서 조정" 이라 명시된 값이라 최신 요청을 그대로 반영. `test_data.gd::test_floors()` 는 배율 단조증가·PH 전체 재질만 검사해 구체적 수치 변경에 영향받지 않는다 |
| 층 이동 로직 위치 | `FloorService`(신규, `UpgradeService` 와 동형인 static 클래스): `next_floor_def/is_max_floor/progress/can_move/move_to_next`. `move_to_next()` 가 `spend_chips`→`floor_index` 갱신→`add_clovers`→`EventBus.floor_changed` 순서로 처리 | 기존 "Service = 상태 없는 판정·구매" 패턴을 그대로 따름(구매 성격의 동작이라 `GameState` 에 새 메서드를 얹지 않음) |
| "다음 층에서 해금" 표시 | 이미 3단계 `UpgradeService.floor_for_marble_tier()` + `UpgradeCard._lock_text()` 가 구현돼 있었다 — 이번 단계는 손대지 않음 | 요청 명세를 살펴보니 설계·구현 모두 이미 끝나 있었다(3단계 작업 범위가 앞서 여기까지 포함) |
| 업적 조건 판정 방식 | `data/achievements.json` 은 표시 메타데이터만(id·category·name_key·desc_key·icon·hidden), 조건은 `AchievementManager` 코드에서 `EventBus` 구독으로 판정 | 30개 중 다수가 "한 번만 있는" 개별 조건이라 범용 규칙 엔진을 만드는 비용이 이득보다 크다(6단계 특수 기능과 같은 결정) |
| 더블 볼 "둘 다 적중" 판정 | 결과 배열의 두 숫자 각각에 대해 `RouletteRules.bet_wins(bet, number)` 를 현재 베팅들로 다시 계산해 "그 공 결과 하나만으로 이기는 베팅이 있는가"로 판정(`SpinOutcome.BetResult.hit_count` 는 공 두 개를 합산해 버려서 공별로 못 나눈다) | 기존 순수 함수(`bet_wins`)를 재사용해 새 상태를 안 늘림 |
| 오너 모드(무한 모드) 배율 | `payout_mult_all` MULT ×2(`Economy.OWNER_MODE_PAYOUT_MULT`), 영구 수정자 `ending:owner_mode` | "수익 ×2" 를 기존 스킬·버프와 같은 곱연산 체계로 표현. 불러오기 후에는 `GameState.rebuild_ending_modifiers()`(`rebuild_upgrade_modifiers` 와 동형)가 다시 건다 |
| 업적 수 30개 맞추기 | 요청 명세를 항목별로 세면 27개("누적 스핀 1000/10000"은 2개로 계산해도)라, 진행·기능 카테고리에 "2F 도달"·"3F 도달"·"첫 황금 포켓 적중" 3개를 추가해 30개를 채웠다 | 아이콘·조건 모두 기존 시스템(층 이동·황금 포켓)만으로 구현 가능해 새 의존성이 없다. 원치 않으면 9단계에서 제거 가능 |
| 벨벳 대사 전부 보기(숨김) | `AchievementManager.mark_dialogue_seen(key, variant_index)` 를 대사 재생부(7단계 3/N, 마담 벨벳 화면)가 호출하는 형태로 인터페이스만 1/N 에서 먼저 만들었다 | 벨벳 대사 자체가 3/N(화면) 작업이라 로직 커밋(1/N)에서는 실제 호출부가 없다 — `test_achievement_manager.gd` 는 직접 호출로 검증 |
| 층별 휠 스킨 색 표현 | 팔레트에 "마호가니"(1F) 전용 색이 없어 wood 램프를 그대로 쓰고 `gloss`(반사 세기)·`grain_accent`(결 강조색)로 차별화했다. 3F "네온 청록 라인"·PH "보석 8개 순차 반짝임"은 정적 텍스처가 아니라 `RouletteWheel._draw_fx()` 런타임 효과로 구현(회전하지 않는 고정 반지름 애니메이션) | 36색 팔레트 제약 안에서 "재질 교체"라는 형태 그대로(기하 불변) 재질감만 바꾸는 것이 요청 명세("림·트랙·터렛만 교체")에 가장 가까웠다 |
| UI 패널 프레임 5색 테마 축소 | 오른쪽 패널의 큰 펠트 텍스처(216×328)를 층마다 다시 굽는 대신, `scripts/core/floor_theme.gd`(강조색 표, 순수 표시용)를 만들어 엘리베이터 확인 팝업 썸네일에만 적용했다 | 배경·휠 스킨이 이미 층 구분을 강하게 전달해서, 큰 텍스처 5벌을 더 굽는 비용 대비 이득이 낮다고 판단(2/N 남은 이슈에 기록, 8단계에서 원하면 표를 재사용해 확장 가능) |
| 최후의 스핀 = 연출 전용 | `EndingSequence` 가 `wheel.play_spin(results, 8.0)` 을 직접 부른다. `results` 는 `RngService.*_misc()` 로 뽑고, `SpinController`/베팅·정산은 전혀 거치지 않는다 | 이 스핀은 승패를 가리는 실제 베팅이 아니라 "승리를 보여주는" 연출이라, 경제 로직을 전혀 안 건드리는 편이 안전하고 `RouletteWheel.play_spin()` 은 애초에 연출·경제를 분리해 만들어져 그대로 재사용 가능했다 |
| 양도 증서 = 계약서 컴포넌트 재사용 | 5단계 `ContractPopup`(양피지 펼침·서명·도장)에 `open_custom(title, line1, line2, line3)` 을 추가해, 대출 전용이던 `open()` 과 공통 로직(`_open_common()`)만 공유한다 | 서명·도장 메커니즘이 대출과 완전히 같고, 각 연출이 자기 `ContractPopup` 인스턴스를 새로 만들어 쓰므로 두 진입점이 서로 간섭하지 않는다(대출 계약서의 빨간 상환액 강조색을 증서에서는 `remove_theme_color_override()` 로 끈다) |
| `EndingSequence` 가 wheel·shaker·flash 를 직접 참조 | 다른 컷신은 `signed()`/`finished()` 신호로 Main 에 되돌려 처리하지만, 엔딩은 화면 전체(휠 스핀·흔들림·플래시·코인비)를 오케스트레이션해야 해서 Main 이 생성 직후 세 참조를 필드로 바로 꽂아준다(`shaker.targets=[...]` 처럼 이미 있던 직접 주입 패턴과 같은 결) | 신호를 늘리는 것보다 참조 주입이 더 단순하고, 세 참조 모두 null 이어도(테스트 환경) 안전하게 동작하도록 각 사용처에 null 체크를 뒀다 |
| 네온사인 "HOUSE EDGE" | `tools/art/gen_fx.py` 의 `NEON_CHARS` 에 H·S·D 3글자를 추가(폭이 가장 넓은 W 가 이미 있어 아틀라스 셀 크기·기존 글자 좌표는 그대로 유지됨, 재생성 후 바이트 비교로 확인) | 기존 "LUCKY" 간판용 `NeonText`/아틀라스가 완전히 범용이라(트루타입 폰트에서 글리프를 뽑는 방식) 필요한 글자만 추가하면 됐다 |
| 루시·벨벳 대사창 공유 | `Main._npc_dialogue`(옛 `_lucy_dialogue`, 화자 무관 공용 이름으로 변경)를 두 NPC가 함께 쓴다. 엔딩 시작 시 이 대사창이 열려 있으면 먼저 숨긴다(`_on_acquisition_pressed()`) | `DialogueBox` 는 화면에 하나만 뜨는 고정 위치 UI라, PH 도착 인사 대사와 엔딩 전용 대사창(`EndingSequence.dialogue`, 별도 인스턴스)이 동시에 겹칠 수 있었다(실제로 스크린샷 검수에서 발견). 엔딩 쪽은 독립 인스턴스를 유지하되, 겹치는 원인(주변 대사)만 치우는 쪽이 더 단순했다 |
| 엔딩 컷신은 스킵 미지원 | 층 이동 컷신과 달리 엔딩은 스킵 버튼이 없다(대사만 클릭으로 넘길 수 있다) | 세이브당 한 번뿐인 축하 이벤트라 반복 스킵 수요가 낮고, 최후의 스핀(8초)·골드 웨이브 등 여러 연출이 서로 다른 방식(휠 애니메이션·파티클·네온)으로 얽혀 있어 범용 스킵 로직을 만드는 비용이 크다고 판단(9단계에서 필요하면 추가) |
| 크레딧 화면 범위 축소 | "스크롤링 카지노 풍경" 대신 고정 화면(제목+부제+통계 7줄+계속하기 버튼)으로 축소, `StatsScreen` 과 같은 자리·행 구조를 재사용 | 이미 있는 4단계 통계 집계·`CountLabel` 카운트업을 그대로 재사용할 수 있어 새 연출 코드 없이도 "성과를 보여준다"는 목적을 달성한다 |
| 마담 벨벳 아트 | 은발 올림머리·진한 빨강 드레스(이름 그대로 "벨벳")·팔은 드레스와 같은 색이면 실루엣이 안 보여 대비되는 검은 장갑(`HAIR[0]`)으로 그렸다. 초상화 7프레임(표정 5+입벙긋 2)·월드 스프라이트 48×72×4(idle/wine/gesture/clap) 는 `gen_lucy.py` 골격을 그대로 재사용 | 루시·남작과 같은 절차적 파이프라인을 그대로 쓰되(새 그리기 헬퍼 없음), 옷·머리색만 바꿔 카지노 소유주다운 관록을 표현했다 |

---

## 18. 8단계 1/N 에서 정한 세부 규칙 (부팅·타이틀·인트로 컷신)

| 항목 | 결정 | 이유·구현 |
|---|---|---|
| 부팅 순서 | `run/main_scene` 을 `Main.tscn` 에서 `SplashScreen.tscn` 으로 바꿨다: 스플래시(개발사 로고, 클릭·아무 키로 스킵) → `TitleScreen.tscn`(이어하기/새 게임/설정/업적/크레딧/종료) → (새 게임이면 `IntroCutscene` 재생 후) `Main.tscn` | 요청 명세대로 부팅→타이틀→게임 흐름을 만들되, `Main._ready()` 의 기존 `SaveManager.load_game()` 호출은 그대로 둬서(4단계부터 있던 동작) 348개 기존 테스트가 전부 그대로 통과하게 했다 |
| "이어하기" 는 이중 로드 안 함 | `TitleScreen` 은 `SaveManager.load_game()` 을 부르지 않고 `get_tree().change_scene_to_file(Main.tscn)` 만 한다. 대신 저장 요약(층·칩·플레이 시간)은 `SaveManager.peek_summary()`(신규, GameState 를 건드리지 않고 저장 파일만 읽는다)로 미리 보여준다 | Main 이 이미 부팅마다 `load_game()` 을 부르므로 타이틀에서 한 번 더 부르면 이중 로드(효과는 같지만 낭비)가 된다. `peek_summary()` 는 "미리보기"와 "실제 적용"을 분리해 취소 가능한 UI(이어하기 버튼에 요약만 표시)를 만들 수 있게 한다 |
| "새 게임" | `SaveManager.delete_save()`(신규) 로 기존 저장을 지우고 `GameState.reset()` 을 부른 뒤 `IntroCutscene` 을 재생한다. 기존 저장이 있으면 먼저 확인 팝업("기존 저장 파일을 덮어씁니다")을 보여준다 | 이 게임은 저장 슬롯이 하나뿐이라(4단계) "새 게임 = 기존 저장 덮어쓰기"가 유일한 의미. `GameState.reset()` 은 이미 모든 필드와 수정자를 정확히 초기화하는 함수라(1단계) 그대로 재사용했다 |
| "저장 후 타이틀로" 활성화 | `PauseMenu` 에 잠겨 있던 버튼을 `title_requested` 신호로 바꾸고, `Main._on_title_requested()` 가 `SaveManager.save_game()` 후 `TitleScreen.tscn` 으로 전환한다 | 이미 저장된 상태로 돌아가므로 확인 팝업이 필요 없다(새 게임과 달리 데이터 손실 위험이 없다) |
| 인트로 컷신 상태 전이는 델타 누적만 | `IntroCutscene` 의 각 단계(골목→구슬→문→대사) 전환은 전부 `_process(delta)` 안의 `_phase_time` 누적으로만 결정한다. 코스메틱 페이드(디밍 등)는 `create_tween()` 을 써도 되지만 다음 단계로 넘어가는 조건에는 쓰지 않는다 | 7단계 `EndingSequence`/`ElevatorCutscene` 과 같은 이유: 헤드리스 테스트가 `_process(dt)` 를 직접 여러 번 불러 진행 상황을 재현해야 하는데, 트윈은 실제 엔진 프레임 없이는 진행되지 않아 테스트가 불가능해진다 |
| 헤드리스 테스트는 실제 씬 전환을 부르지 않는다 | `test_splash_screen.gd`/`test_title_screen.gd` 는 `get_tree().change_scene_to_file()` 로 이어지는 경로(이어하기 클릭, 인트로 완주)를 직접 실행하지 않고, 그 앞 단계의 상태(비활성 여부·요약 문구·리셋 여부)만 검사한다 | `-s tests/run_tests.gd` 는 모든 테스트가 하나의 SceneTree 를 공유한다 — 실제 씬 전환이 한 번이라도 일어나면 그 씬의 `_ready()`(예: `Main` 전체 빌드)가 트리에 남아 이후 테스트를 오염시킨다. 전환 자체는 캡처 스크린샷과 수동 실행으로 검증한다 |
| 개발사 이름 자리표시자 | 정식 이름이 아직 없어 `Economy.STUDIO_NAME = "HOUSE EDGE"` 를 스플래시 로고·크레딧·(5단계) Windows 회사명에 임시로 쓴다. `tools/art/gen_title.py` 의 같은 이름 상수와 반드시 맞춰야 한다 | 나중에 이름이 정해지면 두 상수만 바꾸고 `python3 tools/art/gen_title.py` 를 다시 돌리면 전부 갱신된다 |
| 네온 로고는 기존 `NeonText` 재사용 | 타이틀의 "HOUSE EDGE" 마퀴는 새 컴포넌트가 아니라 7단계 엔딩 네온사인과 같은 `NeonText`(글자 H·O·U·S·E·D·G 가 이미 `neon_pink.png` 아틀라스에 있다)를 그대로 쓴다. `flicker_on()` 으로 인트로에 지직거리며 켜지고, 이후 `idle_flicker=true` 로 가끔 한 글자가 깜빡인다 | 요청 명세("글자가 하나씩 지직거리며 켜지고, 이후 가끔 한 글자가 깜빡")가 `NeonText` 가 이미 제공하는 기능과 정확히 같다 |
| 인트로 실루엣은 절차적 도형 | "주인공의 뒷모습"은 새 스프라이트 없이 `IntroCutscene._WalkingFigure`(내부 클래스)가 `_draw()` 로 그리는 단순 도형(머리 원 + 몸통 사각형)이다. 처음에는 `void` 하나로만 채웠더니 어두운 배경(디밍 알파 0.75)에 완전히 묻혀 안 보였다 — `ink` 바탕 + `mist` 테두리(빗물에 젖어 반짝이는 느낌)로 바꿔 실루엣이 또렷이 보이게 했다(캡처로 발견) | 이름 없는 주인공의 얼굴·표정이 필요 없는 장면이라(요청 명세도 "뒷모습"만 요구) 전용 캐릭터 시트를 만드는 비용이 이득보다 크다고 판단. 대신 대비색 실루엣으로 "빗속의 사람" 인상은 충분히 전달한다 |

## 19. 8단계 2/N 에서 정한 세부 규칙 (튜토리얼)

| 항목 | 결정 | 이유·구현 |
|---|---|---|
| 튜토리얼 진행 방식 | `scenes/fx/tutorial_guide.gd`(`TutorialGuide`, `Main` 의 fx 레이어에 상주) 가 `enum Step { PLACE_BET, SPIN, RESULT, UPGRADE_TAB, UPGRADE_BUY, CLOVER, SKILLTREE, DONE }` 을 실제 `EventBus` 이벤트(`bets_changed`/`spin_resolved`/`tab_pressed`/`upgrade_purchased`/`first_clover_earned`)로만 전진시킨다. 진행 값은 `GameState.tutorial_step`(저장됨) | 요청 명세("각 단계는 실제 게임 이벤트가 조건을 채우면 넘어간다")를 그대로 구현. 저장에 포함시켜 중간에 끄고 켜도 이어서 진행된다 |
| 대상 강조 방식 | 화면을 덮는 4조각 `ColorRect`(대상 위/아래/좌/우를 뺀 "구멍" 모양)로 어둡게 하고, 대상 둘레에 금테 4조각(`Palette.GOLD_HL`)을 두른다. 입력은 막지 않는다(`mouse_filter = IGNORE`) — 대사를 닫지 않고도 실제 칸을 클릭·탭을 누르는 등 진짜 조작을 할 수 있다 | 요청 명세("자연스럽게 녹인다")대로 별도 확인 버튼이나 입력 차단 레이어 없이 실제 UI를 그대로 조작하게 했다 |
| **알파 블렌딩 렌더링 버그(중요)** | `DIM_ALPHA` 를 처음엔 `JackpotOverlay` 와 같은 0.85 로 맞췄지만, 스크린샷 픽셀 비교로 "world(휠·배경, Node2D)" 위에서는 알파값과 무관하게 반투명 `ColorRect` 가 전혀 합성되지 않는 것을 발견했다(같은 fx_layer 의 UI 패널 위에서는 정상 동작). 완전 불투명(`DIM_ALPHA := 1.0`)으로 바꾸니 블렌딩이 필요 없어져 문제가 사라졌다. **기존 `JackpotOverlay`(DIM_ALPHA=0.85)도 같은 증상**(잭팟이 터져도 휠 자체는 안 어두워짐)임을 확인해 별도 작업(spawn_task)으로 보고했다 | 이 프로젝트 렌더러 조합(gl_compatibility, 소프트웨어 Mesa llvmpipe)의 환경 특성으로 보인다. 근본 원인은 못 찾았지만 완전 불투명이 확실한 우회책이라 채택했다 — 앞으로 반투명 오버레이가 휠/배경 같은 world 콘텐츠를 덮어야 할 때는 이 문제를 먼저 의심할 것 |
| **대사 강제 교체(중요)** | `Main._say_npc_entry()` 에 `force: bool` 매개변수를 추가했다. 기존에는 "대사창이 이미 열려 있으면 무시"했는데, 튜토리얼은 플레이어가 대사를 안 닫고 바로 다음 행동(베팅·탭 클릭)을 할 수 있으므로 이전 단계 대사가 안 지워지고 그대로 남는 버그가 있었다(캡처로 발견 — SPIN 단계인데 "판 위의 칸을 하나" PLACE_BET 문구가 그대로 보였다). `TutorialGuide._show_step_line()` 은 항상 `force=true` 로 부른다 | 대사 표시 자체를 담당하는 `_say_npc_entry` 는 그대로 두고(다른 호출자는 기존처럼 "말하는 중이면 무시"), 튜토리얼만 강제 교체하도록 최소로 고쳤다 |
| SPIN 단계에서 대사창이 SPIN 버튼을 가림 | `DialogueBox`(y=268~352) 와 SPIN 버튼(전역 좌표 y=318~352)이 원래 겹치는 레이아웃이다(대사가 있으면 항상 이렇다 — 튜토리얼만의 문제가 아니다). 플레이어가 대사를 한 번 닫으면 버튼과 스포트라이트가 드러난다 | 기존 레이아웃 관례를 그대로 따랐다. 별도 재배치는 이번 단계 범위 밖으로 판단(대사를 읽고 닫으면 정상적으로 보인다) |
| 1회성 신규 기능 팁 | 첫 대출(`debt_changed` + `STAT_LOANS_TAKEN>=1`)·첫 층 이동(`floor_changed(1)`)·황금 포켓 해금(`floor_changed(>=2)`) 은 `TutorialGuide` 의 활성 여부와 무관하게 항상 검사하고, `GameState.tutorial_tips_seen`(Array[String], 저장됨) 으로 한 번만 띄운다. `SettingsManager.tutorial_enabled` 로만 전부 끌 수 있다 | 튜토리얼 6단계가 끝난 뒤에도(또는 튜토리얼을 꺼도) 새로 나타나는 기능은 계속 짧게 짚어줘야 한다는 요청 명세 반영 |
| 설정 "다시 보기" | `SettingsManager.tutorial_enabled`(bool, 체크박스) + "다시 보기" 버튼이 `GameState.tutorial_step=0`, `tutorial_tips_seen=[]` 로 리셋하고 `EventBus.tutorial_reset_requested` 를 발행, `TutorialGuide.restart()` 가 받아 처음부터 재생한다 | 요청 명세대로 튜토리얼을 끄거나 다시 볼 수 있게 했다 |

## 20. 8단계 3/N 에서 정한 세부 규칙 (음악·사운드 최종화)

### 20-1. 음악 소싱 — 진행 중(사용자 승인 대기)

사용자가 "CC0/무료 음원 제안" 방식을 선택했으나, 이 클라우드 컨테이너의 네트워크 정책이 incompetech.com·
opengameart.org·freesound.org 등 후보 사이트 접속을 막고 있어(egress 차단) 실제로 후보를 듣고 내려받을 수
없었다. 사용자에게 네트워크 허용 범위 확장을 요청했다 — **`assets/audio/music/*.ogg` 파일은 아직 하나도 없다.**
필요한 트랙 id(전부 `FloorDef.music_id`/코드에 이미 슬롯이 있다): `bgm_title`(타이틀), `bgm_b1`/`bgm_1f`/`bgm_2f`/
`bgm_3f`/`bgm_ph`(층별 5종, 위로 갈수록 화려하게), `bgm_fever_layer`(피버 중 층 BGM 위에 겹치는 레이어),
`bgm_ending`(엔딩 컷신), `bgm_credits`(엔딩 크레딧). 승인된 트랙이 오면 `assets/audio/music/<id>.ogg`(또는
`.wav`, `AudioManager._music_stream()` 이 `.ogg` 를 먼저 찾고 없으면 `.wav` 로 대체)로 넣기만 하면 아래 재생·
믹싱 로직이 그대로 동작한다(파일이 없는 동안은 경고만 남기고 조용히 무시하도록 미리 만들어 뒀다).

### 20-2. AudioManager.play_music() — 크로스페이드·믹싱

| 항목 | 결정 | 이유·구현 |
|---|---|---|
| 크로스페이드 | 음악용 `AudioStreamPlayer` 두 개(`_music`/`_music_b`)를 번갈아 "현재"로 써서 겹쳐 페이드(기본 1.5초). 같은 id 가 이미 재생 중이면 아무것도 안 함 | 끊김 없이 층·화면이 바뀔 때 음악이 자연스럽게 넘어가야 한다 |
| 기준 볼륨 | `MUSIC_BASE_VOLUME_DB = -12.0` | 요청 명세("음악은 -12dB 기준")를 그대로 상수화 |
| 빅윈 duck | `SpinOutcome.Tier.BIG`/`JACKPOT` 적중 시 `duck_music(-6dB, attack 0.1s, hold 0.4s, release 0.8s)` | 당첨 SFX·연출이 도드라지게 순간적으로 음악을 낮췄다가 되돌린다 |
| 파산 duck | `BaronLoanSequence.play()`(대출·상환 공용, `bass_drop` 재생과 같은 시점)에서 `duck_music(-14dB, 0.2s, 1.6s, 1.2s)` | 5단계에서 "음악 시스템이 없어 스킵"했던 항목(GDD 17장 "범위에서 뺀 것")을 이번에 채웠다 |
| 피버 레이어 | `set_fever_layer(true/false)` 가 `bgm_fever_layer` 를 층 BGM 위에 겹쳐 0.6초로 페이드 인/아웃. `_on_penalty_buff_started/_ended("fever", ...)` 가 `wheel.set_rainbow_mode()`/`fever_start`·`fever_end` SFX 와 나란히 호출 | 피버는 "층 음악 위에 얹는 두 번째 레이어"로 설계(레이어 자체를 다른 곡으로 완전히 바꾸지 않음 — 크로스페이드 중 피버가 겹치는 경우를 단순하게 유지) |
| 오토 스핀 감쇠 | 오토 스핀 중엔 음악 `AUTO_SPIN_MUSIC_ATTEN_DB = -3dB`, SFX 표에서 `jitter=true`(반복음)로 표시된 항목은 재생마다 `AUTO_SPIN_SFX_ATTEN_DB = -4dB` 추가 감쇠 | `VisualSettings.auto_spin_effects_reduced`(오토 스핀 중 약한 등급 연출 생략)와 같은 결로, 이미 있던 `jitter` 플래그가 "흔한/반복 소리"를 정확히 가리키고 있어 그대로 재사용했다 — 별도 시간 누적형 "피로도" 타이머는 만들지 않았다(요청한 결과와 같은 체감 효과를 훨씬 적은 코드로 얻는다) |
| 파일 없을 때 | `_music_stream()`/`play_music()`/`set_fever_layer()` 모두 `ResourceLoader.exists()` 로 확인하고, 없으면 `push_warning` 만 남기고 기존 상태를 그대로 둔다(재생 시도·크래시 없음) | 20-1 의 음원 승인 전에도 나머지 게임 로직·테스트가 전혀 영향받지 않게 한다 |
| 헤드리스 테스트 | `AudioManager.enabled=false`(헤드리스) 인 동안 `play_music()`/`set_fever_layer()` 는 상태(  `_music_id`  등)만 즉시 반영하고 트윈 대신 값을 바로 대입한다. `duck_music()` 도 `!enabled` 면 트윈 없이 `_set_duck_offset()` 을 즉시 한 번만 부른다(release 로 돌아오는 건 실제 재생 환경에서만) | 7단계까지 정착된 "트윈은 헤드리스 테스트에서 흐르지 않는다" 제약(GDD 18장)과 같은 이유 — 로직 자체(오프셋 계산·상태 전이)는 헤드리스에서도 검증 가능해야 한다 |

### 20-3. SFX 감사 — 빠진 두 곳 발견·수정

`AudioManager.SFX` 설정 딕셔너리(48개 id, 전부 `tools/audio/gen_sfx.py` 로 생성된 실제 파일이 있음을 확인)를
실제 `assets/audio/sfx/*.wav` 파일 목록과 대사창 화자 표(`DialogueBox.SPEAKERS`)의 `voice` id 와 교차 검사해
두 개의 공백을 찾았다(둘 다 소리가 "안 나는" 게 아니라 표에 없어 기본값(bus=SFX, 0dB, max=3)으로 재생되던
것 — 다른 항목과 어울리지 않는 볼륨으로 재생되고 있었다):

| id | 문제 | 수정 |
|---|---|---|
| `dialogue_blip_velvet` | 마담 벨벳 대사 타이핑 블립(`DialogueBox._voice_id`)이 `dialogue_blip_baron`/`_lucy` 와 같은 자리에서 쓰이는데 표에는 없었다(7단계에서 벨벳 추가 시 누락) | `dialogue_blip_baron`/`_lucy` 와 똑같이 `{bus: UI, volume_db: -10, max: 4, jitter: false}` 추가 |
| `achievement_unlock` | `AchievementToast` 가 업적 해금마다 재생하는데(7단계) 표에 없었다 | `clover_get`/`piggy_break` 와 비슷한 축하 사운드로 `{bus: SFX, volume_db: -2, max: 1, jitter: false}` 추가 |

그 외 46개 id 는 전부 표와 실제 파일이 일치했다(빠진 파일 0개). 표 전체는 `scripts/autoload/audio_manager.gd`
의 `SFX` 딕셔너리 자체가 최신 출처이므로 이 문서에 다시 옮겨 적지 않는다(중복 유지 비용 방지) — 항목을
추가·수정할 때는 그 파일만 고치면 된다.

