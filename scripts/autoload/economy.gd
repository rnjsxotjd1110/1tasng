extends Node
## 경제 상수와 공식. 밸런스 수치는 여기(전역 규칙)와 data/*.tres(항목별 수치)에만 둔다.
## 공식은 전부 static 이고 상태가 없다. 현재 상태를 넣은 값은 GameState 의 편의 함수가 계산한다.

enum ChipSize { TENTH, HALF, MAX }

## 스튜디오/개발자 이름(가제, 8단계 1/N). 스플래시 로고(tools/art/gen_title.py 의 STUDIO_NAME 과
## 반드시 같은 문자열)·크레딧·Windows 내보내기 회사명에 쓴다. 정식 이름이 정해지면 이 한 곳만 바꾸고
## `python3 tools/art/gen_title.py` 를 다시 돌린다.
const STUDIO_NAME := "HOUSE EDGE"

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
## 업그레이드(golden_pocket) 자체의 최대 레벨(5). 스킬(Y4 행운 부적)이 이보다 더 늘릴 수 있다.
const GOLDEN_POCKET_UPGRADE_MAX_LEVEL := 5
## 업그레이드 + 스킬을 합친 전체 상한(GDD 6장 "합쳐 최대 8").
const GOLDEN_POCKET_MAX := 8
const GOLDEN_POCKET_MULT := 3.0

# ── 클로버 ────────────────────────────────────────────────
const CLOVER_PER_STRAIGHT_HIT := 1
const CLOVER_PER_STREAK := 1
## 한 스핀에 1개 이상 당첨이 이만큼 연속되면(5, 10, 15…) 클로버.
const STREAK_LENGTH := 5
const CLOVER_PER_MILESTONE := 3
const CLOVER_PER_FLOOR := 10
const CLOVER_PER_DEBT_PAID := 2
## 제로의 축복(Y7): 0 스트레이트 적중 시 일반 적중 클로버에 더해지는 추가분.
const ZERO_BLESSING_CLOVER_BONUS := 2

# ── 빚(5단계) ─────────────────────────────────────────────
## 대출액 = max(최소 베팅액 × LOAN_MIN_BET_MULT, 최근 LOAN_INCOME_WINDOW초 평균 초당 순수익 × LOAN_INCOME_SECONDS)
const LOAN_MIN_BET_MULT := 20.0
const LOAN_INCOME_SECONDS := 600.0
const LOAN_INCOME_WINDOW := 300.0
## 상환액 = 대출액 × DEBT_REPAY_FACTOR
const DEBT_REPAY_FACTOR := 2.0
## 당첨금 중 자동 상환 비율.
const DEBT_AUTO_REPAY_RATE := 0.25
## 채무 관리인(M13) 선택 시 상향되는 자동 상환 비율.
const DEBT_AUTO_REPAY_RATE_HIGH := 0.5
const MAX_LOANS := 3
## 비상금(E4): 파산 직전 대출 대신 "최근 1분 수익"을 1회 지급. 쿨다운(레벨 인덱스, 0=Lv1): 10분/5분.
const EMERGENCY_FUND_WINDOW := 60.0
const EMERGENCY_FUND_COOLDOWN_BY_LEVEL: Array[float] = [600.0, 300.0]
const PENALTY_INTERVAL_MIN := 60.0
const PENALTY_INTERVAL_MAX := 120.0
## 패널티 간격은 빚 건수가 늘수록 짧아진다(인덱스 = 빚 건수 - 1): 1건 60~120, 2건 45~90, 3건 30~60.
const PENALTY_INTERVAL_MIN_BY_LOANS: Array[float] = [PENALTY_INTERVAL_MIN, 45.0, 30.0]
const PENALTY_INTERVAL_MAX_BY_LOANS: Array[float] = [PENALTY_INTERVAL_MAX, 90.0, 60.0]
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
const OFFLINE_EFFICIENCY := 0.3
const OFFLINE_CAP_HOURS := 2.0
## 오토 스핀이 아직 해금되지 않았을 때 주는 "팁 수익" 효율.
const OFFLINE_TIP_EFFICIENCY := 0.05
## 이보다 적게 경과했으면 오프라인 수익 자체를 계산하지 않는다(팝업도 없음).
const OFFLINE_MIN_ELAPSED := 60.0
## 휴식 보상(M9): Lv1 은 2시간당, Lv2 는 1시간당 클로버 +1(최대 4). 레벨 인덱스(0=Lv1)로 시간을 찾는다.
const OFFLINE_CLOVER_HOURS_PER_LEVEL: Array[float] = [2.0, 1.0]
const OFFLINE_CLOVER_MAX := 4

# ── 6단계: 스킬트리·자동화·특수 기능 ─────────────────────────
## 연승 보너스(F5) 최대 반영 연승 수(F11 끝없는 연승이 늘린다: 10→20→30).
const STREAK_BONUS_CAP_BASE := 10.0
## 투자 수익(E5): 이 초마다 이자를 지급한다. 상한은 최대 베팅×INVESTMENT_CAP_BET_MULT.
const INVESTMENT_INTERVAL := 10.0
const INVESTMENT_CAP_BET_MULT := 10.0
## 피버 타임(Y5): 기본 주기(스핀)·지속시간(초)·배당 배율. Y11 이 주기를 줄이고 지속시간을 늘린다.
const FEVER_PERIOD_SPINS := 50.0
const FEVER_DURATION := 10.0
const FEVER_MULT := 7.0
## 잭팟 체인(F14): 개별숫자 적중 시 다음 N 스핀 모든 배당 배율.
const JACKPOT_CHAIN_MULT := 5.0
const JACKPOT_CHAIN_SPINS := 3
## 황금 저금통(E13)이 정산되는 주기(스핀).
const PIGGY_BANK_INTERVAL_SPINS := 100
## 운명의 휠(Y14) 등장 주기(초).
const WHEEL_OF_FORTUNE_INTERVAL := 600.0
## 핫 넘버(F6): 최근 이만큼의 스핀에서 최다 숫자 상위 이만큼을 뽑는다.
const HOT_NUMBER_WINDOW := 20
const HOT_NUMBER_COUNT := 3

# ── 엔딩 ──────────────────────────────────────────────────
## 1Dc. PH 에서 지불하면 하우스 인수.
const ENDING_COST := 1e33
## 무한 모드(오너 모드) 진입 시 payout_mult_all 에 곱해지는 영구 배율("수익 ×2").
const OWNER_MODE_PAYOUT_MULT := 2.0

# ── 업적(7단계) ───────────────────────────────────────────
## "1시간 무파산" 업적 조건(초). 파산(bankrupt) 시 타이머가 0으로 돌아간다.
const ACHIEVEMENT_NO_BANKRUPT_SECONDS := 3600.0
## "오프라인 8시간" 업적 조건(시간).
const ACHIEVEMENT_OFFLINE_HOURS := 8.0
## "누적 칩 1Qa" 업적 조건(GameState.STAT_TOTAL_EARNED 기준).
const ACHIEVEMENT_TOTAL_CHIPS := 1e15
## "누적 스핀" 업적 2종의 조건(GameState.STAT_TOTAL_SPINS 기준).
const ACHIEVEMENT_TOTAL_SPINS_LOW := 1000.0
const ACHIEVEMENT_TOTAL_SPINS_HIGH := 10000.0


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
## min_duration 은 M10(터보 모드)이 StatModifiers.MIN_SPIN_DURATION 스탯으로 낮출 수 있다(기본 MIN_SPIN_DURATION).
static func spin_duration(spin_duration_mult: float, min_duration: float = MIN_SPIN_DURATION) -> float:
	return maxf(min_duration, BASE_SPIN_DURATION * spin_duration_mult)


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


## 오프라인 수익 금액. 분기(팁/없음/전체) 판단은 OfflineIncome 이 맡고 efficiency 만 받아 계산한다.
static func offline_income(income_per_second: float, elapsed_seconds: float, cap_hours: float, efficiency: float) -> float:
	if income_per_second <= 0.0 or elapsed_seconds <= 0.0:
		return 0.0
	var capped := minf(elapsed_seconds, cap_hours * 3600.0)
	return income_per_second * capped * efficiency
