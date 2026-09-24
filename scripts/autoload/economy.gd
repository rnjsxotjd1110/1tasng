extends Node
## 경제 상수와 공식. 밸런스 수치는 여기(전역 규칙)와 data/*.tres(항목별 수치)에만 둔다.
## 공식은 전부 static 이고 상태가 없다. 현재 상태를 넣은 값은 GameState 의 편의 함수가 계산한다.

enum ChipSize { TENTH, HALF, MAX }

# ── 시작 상태 ─────────────────────────────────────────────
const STARTING_CHIPS := 100.0
const STARTING_MARBLES := 1

# ── 베팅 ──────────────────────────────────────────────────
## 구슬당 최대 베팅액 = BASE_MAX_BET × 1.35^(베팅 한도 레벨) × 층 bet_mult × (그 외 max_bet_mult)
## 1.35^레벨은 bet_limit 업그레이드의 MULT 수정자로 max_bet_mult 에 들어간다.
const BASE_MAX_BET := 10.0
const BET_LIMIT_GROWTH := 1.35
## 최소 베팅액 = 최대 베팅액 × MIN_BET_RATIO
const MIN_BET_RATIO := 0.1
## 칩 크기 선택 → 최대 베팅액 대비 비율.
const CHIP_SIZE_RATIOS: Dictionary = {ChipSize.TENTH: 0.1, ChipSize.HALF: 0.5, ChipSize.MAX: 1.0}
## 업그레이드로 늘릴 수 있는 구슬 수 상한 / 스킬 포함 전체 상한.
const MAX_MARBLES_FROM_UPGRADES := 8
const MAX_MARBLES_TOTAL := 12
## 기본 공 개수(더블 볼 스킬은 EXTRA_BALLS 로 더한다).
const BASE_BALLS := 1
## 부동소수 오차 허용(베팅 한도 검사).
const BET_EPSILON := 1e-9

# ── 스핀 ──────────────────────────────────────────────────
## 스핀 시간 = BASE_SPIN_DURATION × 0.9^(휠 속도 레벨) × (그 외 spin_duration_mult), 최소 MIN_SPIN_DURATION
const BASE_SPIN_DURATION := 6.0
const SPIN_SPEED_FACTOR := 0.9
const MIN_SPIN_DURATION := 1.5
## 자동 스핀 사이 대기(6단계 자동화에서 사용).
const AUTO_SPIN_DELAY := 1.0
const HISTORY_SIZE := 100

# ── 구슬 재질·광택 ────────────────────────────────────────
const POLISH_MAX_LEVEL := 5
const POLISH_MULT_PER_LEVEL := 1.25
## 광택 n→n+1 비용 = 현재 재질 MarbleDef.polish_base_cost(재질 비용 × 0.08) × POLISH_COST_GROWTH^n
## marble_polish 업그레이드 데이터의 growth 와 같아야 한다(test_upgrade_service 가 검사).
const POLISH_COST_GROWTH := 1.7

# ── 황금 포켓 ─────────────────────────────────────────────
const GOLDEN_POCKET_MAX := 5
const GOLDEN_POCKET_MULT := 3.0

# ── 클로버 ────────────────────────────────────────────────
const CLOVER_PER_STRAIGHT_HIT := 1
const CLOVER_PER_STREAK := 1
## 한 스핀에 1개 이상 당첨이 이만큼 연속되면(5, 10, 15…) 클로버.
const STREAK_LENGTH := 5
const CLOVER_PER_MILESTONE := 3
const CLOVER_PER_FLOOR := 10
const CLOVER_PER_DEBT_PAID := 2

# ── 빚(5단계) ─────────────────────────────────────────────
## 대출액 = max(최소 베팅액 × LOAN_MIN_BET_MULT, 최근 LOAN_INCOME_WINDOW초 평균 초당 순수익 × LOAN_INCOME_SECONDS)
const LOAN_MIN_BET_MULT := 20.0
const LOAN_INCOME_SECONDS := 600.0
const LOAN_INCOME_WINDOW := 300.0
## 상환액 = 대출액 × DEBT_REPAY_FACTOR
const DEBT_REPAY_FACTOR := 2.0
## 당첨금 중 자동 상환 비율.
const DEBT_AUTO_REPAY_RATE := 0.25
const MAX_LOANS := 3
const PENALTY_INTERVAL_MIN := 60.0
const PENALTY_INTERVAL_MAX := 120.0
const PENALTY_DURATION_MIN := 20.0
const PENALTY_DURATION_MAX := 30.0
## 감시하는 부하: 휠 속도 −15% → 스핀 시간 ÷ 0.85
const PENALTY_WATCHER_SPEED := 0.85
## 소매치기: 칩의 1%, 최소 베팅 × 3 아래로는 뺏지 않는다.
const PENALTY_PICKPOCKET_RATE := 0.01
const PENALTY_PICKPOCKET_FLOOR_MIN_BETS := 3.0
## 흐려진 구슬: 구슬 배율 −10%
const PENALTY_BLUR_MARBLE_MULT := 0.9
## 압류: 다음 1스핀 구슬 1개 사용 불가
const PENALTY_SEIZE_MARBLES := 1
## 클로버 수수료: 다음 클로버 획득 절반
const PENALTY_CLOVER_FEE_MULT := 0.5

# ── 오프라인(4단계) ───────────────────────────────────────
const OFFLINE_EFFICIENCY := 0.25
const OFFLINE_CAP_HOURS := 2.0

# ── 엔딩 ──────────────────────────────────────────────────
## 1Dc. PH 에서 지불하면 하우스 인수.
const ENDING_COST := 1e33


## 구슬당 최대 베팅액. max_bet_mult 에는 베팅 한도 업그레이드(1.35^레벨)가 포함돼 있다.
static func max_bet(floor_bet_mult: float, max_bet_mult: float) -> float:
	return BASE_MAX_BET * floor_bet_mult * max_bet_mult


## 베팅 한도 레벨만으로 본 배율(1.35^레벨). bet_limit 업그레이드 데이터와 같아야 한다.
static func bet_limit_mult(level: int) -> float:
	return pow(BET_LIMIT_GROWTH, level)


static func min_bet(max_bet_value: float) -> float:
	return max_bet_value * MIN_BET_RATIO


static func chip_size_ratio(mode: int) -> float:
	return float(CHIP_SIZE_RATIOS.get(mode, CHIP_SIZE_RATIOS[ChipSize.MAX]))


## 선택한 칩 크기의 구슬당 베팅액.
static func chip_amount(max_bet_value: float, mode: int) -> float:
	return max_bet_value * chip_size_ratio(mode)


## 업그레이드 비용 = base × growth^level × upgrade_cost_mult
static func upgrade_cost(base: float, growth: float, level: int, cost_mult: float = 1.0) -> float:
	return base * pow(growth, level) * cost_mult


## 스핀 시간. spin_duration_mult 에는 휠 속도 업그레이드(0.9^레벨)가 포함돼 있다.
static func spin_duration(spin_duration_mult: float) -> float:
	return maxf(MIN_SPIN_DURATION, BASE_SPIN_DURATION * spin_duration_mult)


static func polish_mult(level: int) -> float:
	return pow(POLISH_MULT_PER_LEVEL, clampi(level, 0, POLISH_MAX_LEVEL))


static func polish_cost(polish_base_cost: float, level: int, cost_mult: float = 1.0) -> float:
	return upgrade_cost(polish_base_cost, POLISH_COST_GROWTH, level, cost_mult)


## 보유 구슬 수 = 기본 + 보너스, 전체 상한 적용.
static func marble_slots(slots_bonus: float) -> int:
	return clampi(STARTING_MARBLES + int(slots_bonus), STARTING_MARBLES, MAX_MARBLES_TOTAL)


static func is_bankrupt(chips: float, min_bet_value: float, spin_in_progress: bool) -> bool:
	return not spin_in_progress and chips < min_bet_value


## 대출액(5단계). avg_income_per_second 는 최근 5분 평균 초당 순수익.
static func loan_amount(min_bet_value: float, avg_income_per_second: float) -> float:
	return maxf(min_bet_value * LOAN_MIN_BET_MULT, avg_income_per_second * LOAN_INCOME_SECONDS)


static func debt_repay_amount(loan: float, repay_factor: float = DEBT_REPAY_FACTOR) -> float:
	return loan * repay_factor
