extends Node
## 게임 진행 상태의 단일 원본.
## - 칩 변경은 add_chips()/spend_chips() 로만 한다(음수·NaN·INF 방어, 시그널 발행).
## - 클로버 변경은 add_clovers()/spend_clovers() 로만 한다.
## - 스탯 계산은 modifiers(StatModifiers)를 거친다.

const STAT_TOTAL_SPINS := "total_spins"
const STAT_TOTAL_WINS := "total_wins"
const STAT_BIGGEST_WIN := "biggest_win"
const STAT_BEST_STREAK := "best_streak"
const STAT_PLAY_TIME := "play_time"
const STAT_LOANS_TAKEN := "loans_taken"
const STAT_STRAIGHT_HITS := "straight_hits"
const STAT_TOTAL_EARNED := "total_earned"

const MILESTONE_ICON := "chip"
const UPGRADE_MARBLE_TIER := "marble_tier"
const UPGRADE_MARBLE_POLISH := "marble_polish"
const BUFF_SOURCE_PREFIX := "buff:"
const PENALTY_SOURCE_PREFIX := "penalty:"
## 소모형(횟수제) 패널티 id. PenaltyManager 가 걸고, 여기(클로버 획득 시)와 SpinController(스핀 시작 시)가 소모한다.
const PENALTY_ID_SEIZE_MARBLE := "seize_marble"
const PENALTY_ID_CLOVER_FEE := "clover_fee"
## 스킬트리 중앙 "도박꾼의 심장". 처음부터 보유(SkillService.level 이 항상 1을 돌려준다).
const SKILL_HEART_ID := "heart"
enum SmartBettingStrategy { KEEP, STABLE, AGGRESSIVE, HOT_NUMBERS, MARTINGALE }

var chips: float = Economy.STARTING_CHIPS
var clovers: int = 0
var floor_index: int = 0
## 업그레이드 id → 레벨.
var upgrade_levels: Dictionary = {}
## 스킬 id → 레벨.
var skill_levels: Dictionary = {}
## upgrade_levels["marble_tier"] / ["marble_polish"] 의 사본(읽기 편의). 바꿀 때는 set_upgrade_level 로.
var marble_tier: int = 0
var polish_level: int = 0
var current_bets: Array[Bet] = []
## 직전 스핀에 실제로 쓰인 베팅(금액 포함).
var last_bets: Array[Bet] = []
var chip_size_mode: int = Economy.ChipSize.MAX
## 빚 목록(5단계). 각 항목 {"principal": float, "remaining": float}
var debts: Array[Dictionary] = []
## 아직 안 보여준 남작 컷신(대출·완납). 저장된 뒤 컷신이 끝나기 전에 불러오면 처음부터 다시 재생한다
## (수치는 이미 즉시 반영돼 있고, 이 필드는 연출만 다시 보여주기 위한 것 — 4단계 "스핀 도중 저장" 과 같은 패턴).
## {"type": "loan", "principal": float, "repay": float, "merged": bool} 또는 {"type": "debt_paid"}. 없으면 {}.
var pending_baron_event: Dictionary = {}
## 한 스핀에 1개 이상 당첨이 연속된 횟수.
var win_streak: int = 0
## 최근 결과(오래된 것 → 최신). 공이 여러 개면 모두 들어간다. 표시용, HISTORY_SIZE 개만 유지.
var result_history: Array[int] = []
## 포켓 번호 → 지금까지 나온 횟수(전체 기록, 통계 "최다 출현 숫자"용).
var number_frequency: Dictionary = {}
var golden_pockets: Array[int] = []
## 지금까지 도달한 가장 큰 칩 단위(NumberFormat.suffix_index).
var highest_milestone: int = 0
var stats: Dictionary = {}
## SpinController 가 스핀 중에 true 로 둔다. 파산 판정에 쓴다.
var spin_in_progress: bool = false
## spin_in_progress 동안 SpinController 가 채워 두는 스냅샷(스핀 도중 저장 → 불러오기 즉시 정산용).
var pending_spin_bets: Array[Bet] = []
var pending_spin_results: Array[int] = []
## 6단계 자동 스핀(스킬로 해금). 지금은 해금 수단이 없어 항상 false.
var auto_spin_enabled: bool = false
## 마지막 저장 시점의 초당 순수익(오프라인 수익 계산용 스냅샷).
var last_income_per_second: float = 0.0
var modifiers := StatModifiers.new()
## 최근 5분(Economy.LOAN_INCOME_WINDOW) 초당 순수익 이동평균. 오프라인 수익·5단계 대출액 계산에 공용.
var income_tracker := IncomeTracker.new(Economy.LOAN_INCOME_WINDOW)
## 비상금(E4) 계산 전용 최근 1분 순수익 이동평균.
var emergency_fund_tracker := IncomeTracker.new(Economy.EMERGENCY_FUND_WINDOW)
## 비상금을 다시 쓸 수 있을 때까지 남은 시간(초).
var emergency_fund_cooldown: float = 0.0
## 빚이 있는 동안 랜덤 패널티를 거는 타이머(5단계). 연출 레이어가 penalty_manager.suppressed 를 켜고 끈다.
var penalty_manager := PenaltyManager.new()

# ── 6단계: 스킬트리·자동화·특수 기능 상태 ──────────────────
## 스마트 베팅 전략(M6). KEEP 이면 스마트 베팅이 꺼진 것과 같다(내 구성 유지).
var smart_betting_strategy: int = SmartBettingStrategy.KEEP
var auto_upgrade_enabled: bool = false
## 오토 업그레이드가 쓸 수 있는 예산(보유 칩 대비 비율).
var auto_upgrade_ratio: float = 0.5
## 오토 업그레이드가 구슬 재질도 자동 구매할지(M7 토글).
var auto_upgrade_include_marble: bool = true
## 채무 관리인(M13): true 면 자동 상환율 50%, false 면 기본 25%.
var debt_auto_repay_boosted: bool = false
## 황금 폭풍(Y12) 발동 시 이번 스핀을 포함해 남은 "모든 포켓이 황금" 스핀 수.
var golden_storm_spins_left: int = 0
## 황금 저금통(E13): 현재 창의 누적 순이익과 경과 스핀 수.
var piggy_bank_net: float = 0.0
var piggy_bank_spins: int = 0
## 투자 수익(E5) 10초 타이머.
var investment_timer: float = 0.0
## 피버 타임(Y5) 발동까지 남은 스핀 수 카운터(0부터 누적, 주기에 닿으면 발동 후 리셋).
var fever_spin_count: int = 0
## 운명의 휠(Y14) 등장까지 남은 시간(초). Y14 를 처음 사면 주기로 채워진다.
var wheel_of_fortune_timer: float = -1.0


func _ready() -> void:
	modifiers.source_expired.connect(_on_modifier_source_expired)
	reset()


func _process(delta: float) -> void:
	stats[STAT_PLAY_TIME] = float(stats.get(STAT_PLAY_TIME, 0.0)) + delta
	modifiers.tick(delta)
	penalty_manager.process(delta)
	_tick_investment(delta)
	_tick_wheel_of_fortune(delta)
	emergency_fund_cooldown = maxf(0.0, emergency_fund_cooldown - delta)


## 투자 수익(E5): INVESTMENT_INTERVAL 초마다 보유 칩 대비 이자(상한 max_bet×INVESTMENT_CAP_BET_MULT).
func _tick_investment(delta: float) -> void:
	var rate := get_stat(StatModifiers.INVESTMENT_RATE, 0.0)
	if rate <= 0.0:
		investment_timer = 0.0
		return
	investment_timer += delta
	while investment_timer >= Economy.INVESTMENT_INTERVAL:
		investment_timer -= Economy.INVESTMENT_INTERVAL
		var amount := minf(chips * rate, max_bet() * Economy.INVESTMENT_CAP_BET_MULT)
		if amount > 0.0:
			add_chips(amount)


## 운명의 휠(Y14): 주기가 되면 wheel_of_fortune_ready 를 한 번만 발행하고 Main 이 소비할 때까지 기다린다.
func _tick_wheel_of_fortune(delta: float) -> void:
	if not SkillService.has_feature("wheel_of_fortune"):
		return
	if wheel_of_fortune_timer < 0.0:
		wheel_of_fortune_timer = Economy.WHEEL_OF_FORTUNE_INTERVAL
		return
	if wheel_of_fortune_timer == 0.0:
		return
	wheel_of_fortune_timer = maxf(0.0, wheel_of_fortune_timer - delta)
	if wheel_of_fortune_timer == 0.0:
		EventBus.wheel_of_fortune_ready.emit()


## Main 이 운명의 휠 팝업을 다 보여준 뒤 호출: 다음 주기를 다시 시작한다.
func wheel_of_fortune_consumed() -> void:
	wheel_of_fortune_timer = Economy.WHEEL_OF_FORTUNE_INTERVAL


func wheel_of_fortune_progress() -> float:
	if wheel_of_fortune_timer < 0.0:
		return 0.0
	return 1.0 - wheel_of_fortune_timer / Economy.WHEEL_OF_FORTUNE_INTERVAL


## 오토 스핀 스킬(M1)을 보유했는가. 그 전에는 오프라인 수익이 항상 "팁" 모드다.
func auto_spin_unlocked() -> bool:
	return SkillService.has_feature("auto_spin")


## 새 게임 상태로 되돌린다.
func reset() -> void:
	chips = Economy.STARTING_CHIPS
	clovers = 0
	floor_index = 0
	upgrade_levels = {}
	skill_levels = {}
	marble_tier = 0
	polish_level = 0
	current_bets = []
	last_bets = []
	chip_size_mode = Economy.ChipSize.MAX
	debts = []
	pending_baron_event = {}
	win_streak = 0
	result_history = []
	number_frequency = {}
	golden_pockets = []
	highest_milestone = NumberFormat.suffix_index(chips)
	spin_in_progress = false
	pending_spin_bets = []
	pending_spin_results = []
	auto_spin_enabled = false
	last_income_per_second = 0.0
	income_tracker.reset()
	penalty_manager.reset()
	smart_betting_strategy = SmartBettingStrategy.KEEP
	auto_upgrade_enabled = false
	auto_upgrade_ratio = 0.5
	auto_upgrade_include_marble = true
	debt_auto_repay_boosted = false
	golden_storm_spins_left = 0
	piggy_bank_net = 0.0
	piggy_bank_spins = 0
	investment_timer = 0.0
	fever_spin_count = 0
	wheel_of_fortune_timer = -1.0
	emergency_fund_tracker.reset()
	emergency_fund_cooldown = 0.0
	stats = {
		STAT_TOTAL_SPINS: 0,
		STAT_TOTAL_WINS: 0,
		STAT_BIGGEST_WIN: 0.0,
		STAT_BEST_STREAK: 0,
		STAT_PLAY_TIME: 0.0,
		STAT_LOANS_TAKEN: 0,
		STAT_STRAIGHT_HITS: 0,
		STAT_TOTAL_EARNED: 0.0,
	}
	modifiers.clear()
	set_upgrade_level(UPGRADE_MARBLE_TIER, 0)
	EventBus.chips_changed.emit(chips, 0.0)
	EventBus.clovers_changed.emit(clovers, 0)
	EventBus.bets_changed.emit()


# ── 칩 ───────────────────────────────────────────────────

## 칩을 더한다. 0 이하·NaN·INF 는 거부하고 false.
## count_as_earned: 누적 획득 통계에 넣을지(대출금 등은 false).
func add_chips(amount: float, count_as_earned: bool = true) -> bool:
	if not _is_valid_amount(amount, "add_chips"):
		return false
	if amount == 0.0:
		return true
	chips += amount
	if count_as_earned:
		stats[STAT_TOTAL_EARNED] = float(stats.get(STAT_TOTAL_EARNED, 0.0)) + amount
	EventBus.chips_changed.emit(chips, amount)
	_check_milestones()
	return true


## 칩을 쓴다. 0 이하·NaN·INF·잔액 부족이면 아무것도 바꾸지 않고 false.
func spend_chips(amount: float) -> bool:
	if not _is_valid_amount(amount, "spend_chips"):
		return false
	if amount > chips:
		return false
	if amount == 0.0:
		return true
	chips -= amount
	EventBus.chips_changed.emit(chips, -amount)
	return true


func can_afford(amount: float) -> bool:
	return amount >= 0.0 and not is_nan(amount) and amount <= chips


func _is_valid_amount(amount: float, where: String) -> bool:
	if is_nan(amount) or is_inf(amount):
		push_warning("GameState.%s: 비정상 값 거부 (%s)" % [where, amount])
		return false
	if amount < 0.0:
		push_warning("GameState.%s: 음수 거부 (%s)" % [where, amount])
		return false
	return true


func _check_milestones() -> void:
	var index := NumberFormat.suffix_index(chips)
	var bonus := int(get_stat(StatModifiers.MILESTONE_CLOVER_BONUS, 0.0))
	while highest_milestone < index:
		highest_milestone += 1
		EventBus.milestone_reached.emit(highest_milestone)
		add_clovers(Economy.CLOVER_PER_MILESTONE + bonus)


# ── 클로버 ───────────────────────────────────────────────

## 클로버 획득. clover_gain_mult 가 적용되고 내림한다. 실제로 얻은 개수를 돌려준다.
## 배율이 0 보다 크면(예: 클로버 수수료 패널티 ×0.5) 원래 수량이 있었는데 내림으로 0 이 되는 일은 없다(최소 1).
func add_clovers(amount: int) -> int:
	if amount <= 0:
		return 0
	var mult := get_stat(StatModifiers.CLOVER_GAIN_MULT, StatModifiers.IDENTITY_MULT)
	var gained := floori(amount * mult)
	if gained <= 0 and mult > 0.0:
		gained = 1
	if gained <= 0:
		return 0
	var bonus_chance := get_stat(StatModifiers.CLOVER_BONUS_CHANCE, 0.0)
	if bonus_chance > 0.0 and RngService.randf_misc() < bonus_chance:
		gained += 1
	clovers += gained
	EventBus.clovers_changed.emit(clovers, gained)
	consume_penalty_charge(PENALTY_ID_CLOVER_FEE)
	return gained


func spend_clovers(amount: int) -> bool:
	if amount < 0 or amount > clovers:
		return false
	if amount == 0:
		return true
	clovers -= amount
	EventBus.clovers_changed.emit(clovers, -amount)
	return true


# ── 스탯 ─────────────────────────────────────────────────

func get_stat(stat: String, base: float) -> float:
	return modifiers.get_stat(stat, base)


func current_floor() -> FloorDef:
	return GameData.floor_def(floor_index)


func current_marble() -> MarbleDef:
	return GameData.marble(marble_tier)


func max_bet() -> float:
	var floor_def := current_floor()
	var floor_bet_mult := floor_def.bet_mult if floor_def != null else StatModifiers.IDENTITY_MULT
	return Economy.max_bet(floor_bet_mult, get_stat(StatModifiers.MAX_BET_MULT, StatModifiers.IDENTITY_MULT))


func min_bet() -> float:
	return Economy.min_bet(max_bet())


## 현재 칩 크기 설정의 구슬당 베팅액(보유 칩과 무관).
func chip_amount() -> float:
	return Economy.chip_amount(max_bet(), chip_size_mode)


## 보유 구슬 수(패널티로 잠긴 구슬 제외).
func marble_slots() -> int:
	var slots := Economy.marble_slots(get_stat(StatModifiers.MARBLE_SLOTS_BONUS, StatModifiers.IDENTITY_ADD))
	var locked := int(get_stat(StatModifiers.LOCKED_MARBLES, StatModifiers.IDENTITY_ADD))
	return maxi(Economy.STARTING_MARBLES, slots - locked)


func ball_count() -> int:
	return Economy.BASE_BALLS + maxi(0, int(get_stat(StatModifiers.EXTRA_BALLS, StatModifiers.IDENTITY_ADD)))


func spin_duration() -> float:
	var min_duration := get_stat(StatModifiers.MIN_SPIN_DURATION, Economy.MIN_SPIN_DURATION)
	return Economy.spin_duration(get_stat(StatModifiers.SPIN_DURATION_MULT, StatModifiers.IDENTITY_MULT), min_duration)


## 구슬 배율. 재질(upgrade:marble_tier) × 광택(upgrade:marble_polish) × 그 외 수정자.
func marble_mult() -> float:
	return get_stat(StatModifiers.MARBLE_MULT, StatModifiers.IDENTITY_MULT)


func floor_mult() -> float:
	var floor_def := current_floor()
	var base := floor_def.payout_mult if floor_def != null else StatModifiers.IDENTITY_MULT
	return get_stat(StatModifiers.FLOOR_MULT, base)


func golden_pocket_count() -> int:
	return clampi(int(get_stat(StatModifiers.GOLDEN_POCKET_COUNT, StatModifiers.IDENTITY_ADD)), 0, Economy.GOLDEN_POCKET_MAX)


func build_spin_context() -> SpinContext:
	var context := SpinContext.new()
	context.marble_mult = marble_mult()
	var streak_bonus := _streak_payout_bonus()
	context.floor_mult = floor_mult()
	context.payout_mult_all = get_stat(StatModifiers.PAYOUT_MULT_ALL, StatModifiers.IDENTITY_MULT) * (1.0 + streak_bonus) * _compound_interest_bonus()
	context.payout_mult_color = get_stat(StatModifiers.PAYOUT_MULT_COLOR, StatModifiers.IDENTITY_MULT)
	context.payout_mult_parity = get_stat(StatModifiers.PAYOUT_MULT_PARITY, StatModifiers.IDENTITY_MULT)
	context.straight_payout_bonus = get_stat(StatModifiers.STRAIGHT_PAYOUT_BONUS, StatModifiers.IDENTITY_ADD)
	context.golden_pockets = golden_pockets.duplicate() if golden_storm_spins_left <= 0 else _all_pockets()
	context.golden_pocket_mult = get_stat(StatModifiers.GOLDEN_POCKET_MULT, Economy.GOLDEN_POCKET_MULT)
	context.zero_guard = SkillService.has_feature("zero_guard")
	var hot_mult := get_stat(StatModifiers.HOT_NUMBER_STRAIGHT_MULT, StatModifiers.IDENTITY_MULT)
	if hot_mult > StatModifiers.IDENTITY_MULT:
		context.hot_numbers = hot_numbers()
		context.hot_number_straight_mult = hot_mult
	context.lucky_seven_mult = get_stat(StatModifiers.LUCKY_SEVEN_MULT, StatModifiers.IDENTITY_MULT)
	context.zero_straight_mult = get_stat(StatModifiers.ZERO_STRAIGHT_MULT, StatModifiers.IDENTITY_MULT)
	context.multi_hit_bonus = get_stat(StatModifiers.MULTI_HIT_BONUS, StatModifiers.IDENTITY_ADD)
	context.cashback_rate = get_stat(StatModifiers.CASHBACK_RATE, StatModifiers.IDENTITY_ADD)
	return context


## 연승 보너스(F5): 연승 1회당 배당 +streak_bonus_per_win, F11(끝없는 연승)이 반영 상한을 늘린다.
func _streak_payout_bonus() -> float:
	var per_win := get_stat(StatModifiers.STREAK_BONUS_PER_WIN, 0.0)
	if per_win <= 0.0:
		return 0.0
	var cap := get_stat(StatModifiers.STREAK_BONUS_CAP, Economy.STREAK_BONUS_CAP_BASE)
	return mini(win_streak, int(cap)) * per_win


## 복리의 마법(E14): 보유 칩 자릿수(log10)마다 배당 +compound_interest_per_digit.
func _compound_interest_bonus() -> float:
	var per_digit := get_stat(StatModifiers.COMPOUND_INTEREST_PER_DIGIT, 0.0)
	if per_digit <= 0.0 or chips < 1.0:
		return 1.0
	var digits := floori(log(chips) / log(10.0))
	return 1.0 + maxi(digits, 0) * per_digit


func _all_pockets() -> Array[int]:
	var out: Array[int] = []
	for number in RouletteRules.POCKET_COUNT:
		out.append(number)
	return out


## 핫 넘버(F6): 최근 20스핀에서 가장 많이 나온 숫자 3개(동률 → 최근 것 우선).
func hot_numbers() -> Array[int]:
	var window := Economy.HOT_NUMBER_WINDOW
	var recent := result_history.slice(maxi(0, result_history.size() - window), result_history.size())
	var counts: Dictionary = {}
	var last_seen: Dictionary = {}
	for i in recent.size():
		var number: int = recent[i]
		counts[number] = int(counts.get(number, 0)) + 1
		last_seen[number] = i
	var numbers: Array = counts.keys()
	numbers.sort_custom(func(a: int, b: int) -> bool:
		var ca: int = counts[a]
		var cb: int = counts[b]
		if ca != cb:
			return ca > cb
		return int(last_seen[a]) > int(last_seen[b]))
	var out: Array[int] = []
	for i in mini(Economy.HOT_NUMBER_COUNT, numbers.size()):
		out.append(int(numbers[i]))
	return out


func is_bankrupt() -> bool:
	return Economy.is_bankrupt(chips, min_bet(), spin_in_progress)


## 파산이면 즉시 대출을 받고(거절 없음) bankrupt 를 발행한 뒤 true.
## 대출 수치는 이 함수 안에서 바로 반영된다 — bankrupt 를 받는 쪽(Main)은 이미 채워진 pending_baron_event 로
## 남작 컷신에 쓸 정보(대출액·상환액·합산 여부)를 읽으면 된다.
func check_bankruptcy() -> bool:
	if not is_bankrupt():
		return false
	_try_emergency_fund()
	if not is_bankrupt():
		return false
	_take_emergency_loan()
	EventBus.bankrupt.emit()
	return true


## 비상금(E4): 대출보다 먼저 시도한다. 쿨다운 중이거나 미보유면 아무 일도 하지 않는다.
## 지급해도 여전히 파산 상태면(비상금이 최소 베팅보다 적으면) 이어서 대출로 넘어간다.
func _try_emergency_fund() -> void:
	var level := SkillService.feature_level("emergency_fund")
	if level <= 0 or emergency_fund_cooldown > 0.0:
		return
	var amount := maxf(0.0, emergency_fund_tracker.per_second(get_stat_value(STAT_PLAY_TIME)) * Economy.EMERGENCY_FUND_WINDOW)
	var index := clampi(level - 1, 0, Economy.EMERGENCY_FUND_COOLDOWN_BY_LEVEL.size() - 1)
	emergency_fund_cooldown = Economy.EMERGENCY_FUND_COOLDOWN_BY_LEVEL[index]
	if amount <= 0.0:
		return
	add_chips(amount, false)
	EventBus.toast_requested.emit(tr("TOAST_EMERGENCY_FUND") % NumberFormat.format(amount), "chip")


func _take_emergency_loan() -> void:
	var avg_income := income_tracker.per_second(get_stat_value(STAT_PLAY_TIME))
	var repay_mult := get_stat(StatModifiers.DEBT_REPAY_MULT, Economy.DEBT_REPAY_FACTOR)
	var result := DebtService.take_loan(debts, avg_income, min_bet(), repay_mult)
	debts = result["debts"]
	add_chips(float(result["principal"]), false)
	increment_stat(STAT_LOANS_TAKEN)
	pending_baron_event = {"type": "loan", "principal": result["principal"], "repay": result["repay"], "merged": result["merged"]}
	EventBus.debt_changed.emit()


# ── 빚(5단계) ────────────────────────────────────────────

func debt_total() -> float:
	return DebtService.total(debts)


func has_debt() -> bool:
	return not debts.is_empty()


## 당첨금 중 Economy.DEBT_AUTO_REPAY_RATE 를 오래된 빚부터 자동 상환한다(SpinController 가 정산 직후 호출).
## 총 빚이 이번에 0 이 되면 클로버 +2 와 완납 컷신을 예약한다. 실제 상환액을 돌려준다.
func auto_repay_debt(payout: float) -> float:
	if debts.is_empty() or payout <= 0.0:
		return 0.0
	var rate := Economy.DEBT_AUTO_REPAY_RATE
	if debt_auto_repay_boosted and SkillService.has_feature("debt_manager"):
		rate = Economy.DEBT_AUTO_REPAY_RATE_HIGH
	var result := DebtService.apply_auto_repay(debts, payout, rate)
	var repaid := float(result["repaid"])
	if repaid <= 0.0 or not spend_chips(repaid):
		return 0.0
	debts = result["debts"]
	if debts.is_empty():
		_on_debt_fully_paid()
	EventBus.debt_changed.emit()
	return repaid


## index 번째 빚 전액을 상환한다(가용 칩이 모자라면 아무 일도 하지 않고 0.0). 실제 상환액을 돌려준다.
func repay_all(index: int) -> float:
	if index < 0 or index >= debts.size():
		return 0.0
	return _repay_debt(index, float(debts[index]["remaining"]))


## index 번째 빚의 남은 금액 절반을 상환한다(가용 칩이 모자라면 아무 일도 하지 않고 0.0).
func repay_half(index: int) -> float:
	if index < 0 or index >= debts.size():
		return 0.0
	return _repay_debt(index, float(debts[index]["remaining"]) * 0.5)


## 운명의 휠 "빚 탕감": 상환(칩 소모) 없이 모든 빚의 잔액을 ratio 만큼 줄인다. 총 탕감액을 돌려준다.
func forgive_debt(ratio: float) -> float:
	if debts.is_empty() or ratio <= 0.0:
		return 0.0
	var result := DebtService.forgive_ratio(debts, ratio)
	debts = result["debts"]
	if debts.is_empty():
		_on_debt_fully_paid()
	EventBus.debt_changed.emit()
	return float(result["forgiven"])


func _repay_debt(index: int, amount: float) -> float:
	if amount <= 0.0 or not spend_chips(amount):
		return 0.0
	var result := DebtService.repay_at(debts, index, amount)
	debts = result["debts"]
	if debts.is_empty():
		_on_debt_fully_paid()
	EventBus.debt_changed.emit()
	return float(result["repaid"])


## 총 빚이 0이 됐을 때 공통으로 할 일: 완납 클로버, 남작 완납 컷신 예약, 모든 패널티 즉시 해제(GDD 9장 "빚이 있을 때만").
func _on_debt_fully_paid() -> void:
	var bonus := int(get_stat(StatModifiers.DEBT_PAID_CLOVER_BONUS, 0.0))
	add_clovers(Economy.CLOVER_PER_DEBT_PAID + bonus)
	pending_baron_event = {"type": "debt_paid"}
	_clear_all_penalties()


func _clear_all_penalties() -> void:
	var sources: Array[String] = []
	for modifier in modifiers.get_modifiers():
		if modifier.source_id.begins_with(PENALTY_SOURCE_PREFIX) and not sources.has(modifier.source_id):
			sources.append(modifier.source_id)
	for source_id in sources:
		if modifiers.remove_source(source_id) > 0:
			EventBus.buff_ended.emit(source_id.trim_prefix(PENALTY_SOURCE_PREFIX))


# ── 업그레이드·버프 ─────────────────────────────────────

func get_upgrade_level(id: String) -> int:
	return int(upgrade_levels.get(id, 0))


## 업그레이드 레벨을 정하고 수정자를 다시 건다. 구매 규칙(비용·상한·광택 초기화)은 UpgradeService 가 맡는다.
## 구슬 재질(MARBLE_TIER)은 레벨 0(나무)도 수정자를 건다(값 = 재질 배율).
func set_upgrade_level(id: String, level: int) -> void:
	var def := GameData.upgrade(id)
	if def == null:
		push_error("GameState.set_upgrade_level: 없는 업그레이드 '%s'" % id)
		return
	if def.max_level != UpgradeDef.UNLIMITED:
		level = mini(level, def.max_level)
	level = maxi(level, 0)
	upgrade_levels[id] = level
	match def.kind:
		UpgradeDef.Kind.MARBLE_TIER:
			marble_tier = level
		UpgradeDef.Kind.MARBLE_POLISH:
			polish_level = level
	modifiers.remove_source(def.source_id())
	if (level > 0 or def.kind == UpgradeDef.Kind.MARBLE_TIER) and def.effect_stat != "":
		modifiers.add_modifier(def.source_id(), def.effect_stat, def.effect_op, def.effect_value(level))
	if def.effect_stat == StatModifiers.GOLDEN_POCKET_COUNT:
		refresh_golden_pockets()


## 모든 업그레이드 수정자를 upgrade_levels 로부터 다시 만든다(불러오기 후 호출).
func rebuild_upgrade_modifiers() -> void:
	for id: String in upgrade_levels.keys():
		set_upgrade_level(id, int(upgrade_levels[id]))


## 스킬 레벨을 정하고 수정자를 다시 건다(구매 규칙은 SkillService). 한 노드가 여러 스탯을 가지면 전부 다시 건다.
func set_skill_level(id: String, level: int) -> void:
	var def := GameData.skill(id)
	if def == null:
		push_error("GameState.set_skill_level: 없는 스킬 '%s'" % id)
		return
	level = clampi(level, 0, def.max_level())
	skill_levels[id] = level
	modifiers.remove_source(def.source_id())
	if level > 0:
		for effect: Dictionary in def.effects:
			var stat := String(effect.get("stat", ""))
			if stat == "":
				continue
			var op: StatModifiers.Op = int(effect.get("op", StatModifiers.Op.ADD))
			modifiers.add_modifier(def.source_id(), stat, op, def.effect_value(effect, level))
			if stat == StatModifiers.GOLDEN_POCKET_COUNT:
				refresh_golden_pockets()


## 모든 스킬 수정자를 skill_levels 로부터 다시 만든다(불러오기 후 호출).
func rebuild_skill_modifiers() -> void:
	for id: String in skill_levels.keys():
		set_skill_level(id, int(skill_levels[id]))


## 황금 포켓 개수를 스탯에 맞춘다. 늘면 아직 황금이 아닌 포켓 중 무작위로 추가(golden_pockets_added 발행), 줄면 뒤에서 제거.
func refresh_golden_pockets() -> void:
	var target := golden_pocket_count()
	while golden_pockets.size() > target:
		golden_pockets.pop_back()
	var added: Array[int] = []
	while golden_pockets.size() < target:
		var candidates: Array[int] = []
		for number in RouletteRules.POCKET_COUNT:
			if not golden_pockets.has(number):
				candidates.append(number)
		var picked := candidates[RngService.randi_range_misc(0, candidates.size() - 1)]
		golden_pockets.append(picked)
		added.append(picked)
	if not added.is_empty():
		EventBus.golden_pockets_added.emit(added)


## 시간제 버프(또는 패널티). buff_started 를 발행하고, 만료되면 buff_ended 가 발행된다.
## charges 를 주면 시간과 별개로 "횟수"로도 소모된다(6단계 잭팟 체인처럼 "다음 N 스핀" 형 버프).
## duration 에는 skill:BUFF_DURATION_MULT(Y13)가 곱해진다(0 이하·PERMANENT 는 그대로).
func add_buff(id: String, stat: String, op: StatModifiers.Op, value: float, duration: float, charges: int = -1) -> void:
	var scaled_duration := duration
	if duration > 0.0:
		scaled_duration = duration * get_stat(StatModifiers.BUFF_DURATION_MULT, StatModifiers.IDENTITY_MULT)
	modifiers.add_modifier(BUFF_SOURCE_PREFIX + id, stat, op, value, scaled_duration, charges)
	EventBus.buff_started.emit(id, scaled_duration)


## id 버프의 소모형(charges) 남은 횟수. 없으면 -1.
func buff_charges_left(id: String) -> int:
	return modifiers.charges_remaining(BUFF_SOURCE_PREFIX + id)


func remove_buff(id: String) -> void:
	if modifiers.remove_source(BUFF_SOURCE_PREFIX + id) > 0:
		EventBus.buff_ended.emit(id)


## 시간제 패널티(감시하는 부하·흐려진 구슬 등). buff_started/buff_ended 를 buff 와 함께 쓴다(GDD EventBus 표: "시간제
## 버프·패널티"). PenaltyManager 가 건다.
func add_penalty_timed(id: String, stat: String, op: StatModifiers.Op, value: float, duration: float) -> void:
	modifiers.add_modifier(PENALTY_SOURCE_PREFIX + id, stat, op, value, duration)
	EventBus.buff_started.emit(id, duration)


## 소모형(횟수제) 패널티(압류·클로버 수수료). 시간이 아니라 consume_penalty_charge() 호출로 사라진다.
func add_penalty_charge(id: String, stat: String, op: StatModifiers.Op, value: float, charges: int) -> void:
	modifiers.add_modifier(PENALTY_SOURCE_PREFIX + id, stat, op, value, StatModifiers.PERMANENT, charges)
	EventBus.buff_started.emit(id, 0.0)


func remove_penalty(id: String) -> void:
	if modifiers.remove_source(PENALTY_SOURCE_PREFIX + id) > 0:
		EventBus.buff_ended.emit(id)


## 소모형 패널티를 1회 소모한다(없으면 false). 다 소모되면 buff_ended 가 발행된다(_on_modifier_source_expired 경유).
func consume_penalty_charge(id: String) -> bool:
	return modifiers.consume_charges(PENALTY_SOURCE_PREFIX + id)


func _on_modifier_source_expired(source_id: String) -> void:
	if source_id.begins_with(BUFF_SOURCE_PREFIX):
		EventBus.buff_ended.emit(source_id.trim_prefix(BUFF_SOURCE_PREFIX))
	elif source_id.begins_with(PENALTY_SOURCE_PREFIX):
		EventBus.buff_ended.emit(source_id.trim_prefix(PENALTY_SOURCE_PREFIX))


# ── 베팅 ─────────────────────────────────────────────────

## 베팅(구슬 1개)을 놓는다. 구슬이 모자라거나 잘못된 베팅이면 false.
func add_bet(bet: Bet) -> bool:
	if bet == null or not bet.is_valid():
		return false
	if current_bets.size() >= marble_slots():
		return false
	current_bets.append(bet)
	EventBus.bets_changed.emit()
	return true


func remove_bet_at(index: int) -> bool:
	if index < 0 or index >= current_bets.size():
		return false
	current_bets.remove_at(index)
	EventBus.bets_changed.emit()
	return true


## index 의 베팅을 다른 칸으로 옮긴다(드래그 앤 드롭). 구슬 수는 그대로.
func replace_bet_at(index: int, bet: Bet) -> bool:
	if index < 0 or index >= current_bets.size() or bet == null or not bet.is_valid():
		return false
	current_bets[index] = bet
	EventBus.bets_changed.emit()
	return true


## 직전 스핀의 베팅을 다시 건다(금액은 스핀 때 다시 정한다). 구슬 수를 넘는 것은 버린다.
func restore_last_bets() -> bool:
	if last_bets.is_empty():
		return false
	current_bets.clear()
	for bet in last_bets:
		if current_bets.size() >= marble_slots():
			break
		current_bets.append(Bet.new(bet.type, bet.number))
	EventBus.bets_changed.emit()
	return true


func clear_bets() -> void:
	if current_bets.is_empty():
		return
	current_bets.clear()
	EventBus.bets_changed.emit()


func set_chip_size_mode(mode: int) -> void:
	if not Economy.CHIP_SIZE_RATIOS.has(mode):
		push_warning("GameState.set_chip_size_mode: 없는 모드 %d" % mode)
		return
	chip_size_mode = mode
	EventBus.bets_changed.emit()


# ── 기록 ─────────────────────────────────────────────────

func push_results(results: Array[int]) -> void:
	for result in results:
		result_history.append(result)
		number_frequency[result] = int(number_frequency.get(result, 0)) + 1
	while result_history.size() > Economy.HISTORY_SIZE:
		result_history.pop_front()


## 지금까지 가장 많이 나온 포켓 번호. 아직 하나도 없으면 -1.
func most_frequent_number() -> int:
	var best_number := -1
	var best_count := 0
	for number: int in number_frequency.keys():
		var count := int(number_frequency[number])
		if count > best_count:
			best_count = count
			best_number = number
	return best_number


func get_stat_value(key: String) -> float:
	return float(stats.get(key, 0.0))


func increment_stat(key: String, amount: float = 1.0) -> void:
	stats[key] = float(stats.get(key, 0.0)) + amount


func max_stat(key: String, value: float) -> void:
	stats[key] = maxf(float(stats.get(key, 0.0)), value)


# ── 저장(4단계) ──────────────────────────────────────────

## SaveManager 가 저장하는 GameState 전체(RngService 상태는 별도로 SaveManager 가 덧붙인다).
func to_dict() -> Dictionary:
	return {
		"chips": chips,
		"clovers": clovers,
		"floor_index": floor_index,
		"upgrade_levels": upgrade_levels.duplicate(),
		"skill_levels": skill_levels.duplicate(),
		"current_bets": _bets_to_array(current_bets),
		"last_bets": _bets_to_array(last_bets),
		"chip_size_mode": chip_size_mode,
		"debts": debts.duplicate(true),
		"pending_baron_event": pending_baron_event.duplicate(),
		"win_streak": win_streak,
		"result_history": result_history.duplicate(),
		"number_frequency": number_frequency.duplicate(),
		"golden_pockets": golden_pockets.duplicate(),
		"highest_milestone": highest_milestone,
		"spin_in_progress": spin_in_progress,
		"pending_spin_bets": _bets_to_array(pending_spin_bets),
		"pending_spin_results": pending_spin_results.duplicate(),
		"auto_spin_enabled": auto_spin_enabled,
		"stats": stats.duplicate(),
		"buffs": _export_buffs(),
		"income_per_second_at_save": income_tracker.per_second(get_stat_value(STAT_PLAY_TIME)),
		"smart_betting_strategy": smart_betting_strategy,
		"auto_upgrade_enabled": auto_upgrade_enabled,
		"auto_upgrade_ratio": auto_upgrade_ratio,
		"auto_upgrade_include_marble": auto_upgrade_include_marble,
		"debt_auto_repay_boosted": debt_auto_repay_boosted,
		"golden_storm_spins_left": golden_storm_spins_left,
		"piggy_bank_net": piggy_bank_net,
		"piggy_bank_spins": piggy_bank_spins,
		"fever_spin_count": fever_spin_count,
		"wheel_of_fortune_timer": wheel_of_fortune_timer,
		"emergency_fund_cooldown": emergency_fund_cooldown,
	}


## data 로 상태를 되돌린다. 업그레이드·스킬 수정자는 다시 걸지 않으므로(rebuild_upgrade_modifiers 를 호출할 것),
## 호출 뒤 GameState.rebuild_upgrade_modifiers() 를 반드시 부른다.
func from_dict(data: Dictionary) -> void:
	reset()
	chips = float(data.get("chips", Economy.STARTING_CHIPS))
	clovers = int(data.get("clovers", 0))
	floor_index = int(data.get("floor_index", 0))
	upgrade_levels = (data.get("upgrade_levels", {}) as Dictionary).duplicate()
	skill_levels = (data.get("skill_levels", {}) as Dictionary).duplicate()
	current_bets = _array_to_bets(data.get("current_bets", []))
	last_bets = _array_to_bets(data.get("last_bets", []))
	chip_size_mode = int(data.get("chip_size_mode", Economy.ChipSize.MAX))
	debts = []
	for entry in data.get("debts", []):
		debts.append((entry as Dictionary).duplicate())
	pending_baron_event = (data.get("pending_baron_event", {}) as Dictionary).duplicate()
	win_streak = int(data.get("win_streak", 0))
	result_history = []
	for value in data.get("result_history", []):
		result_history.append(int(value))
	number_frequency = {}
	var loaded_frequency: Dictionary = data.get("number_frequency", {})
	for key in loaded_frequency.keys():
		number_frequency[int(key)] = int(loaded_frequency[key])
	golden_pockets = []
	for value in data.get("golden_pockets", []):
		golden_pockets.append(int(value))
	highest_milestone = int(data.get("highest_milestone", NumberFormat.suffix_index(chips)))
	spin_in_progress = bool(data.get("spin_in_progress", false))
	pending_spin_bets = _array_to_bets(data.get("pending_spin_bets", []))
	pending_spin_results = []
	for value in data.get("pending_spin_results", []):
		pending_spin_results.append(int(value))
	auto_spin_enabled = bool(data.get("auto_spin_enabled", false))
	var loaded_stats: Dictionary = data.get("stats", {})
	for key in stats.keys():
		if loaded_stats.has(key):
			stats[key] = loaded_stats[key]
	_import_buffs(data.get("buffs", []))
	last_income_per_second = float(data.get("income_per_second_at_save", 0.0))
	smart_betting_strategy = int(data.get("smart_betting_strategy", SmartBettingStrategy.KEEP))
	auto_upgrade_enabled = bool(data.get("auto_upgrade_enabled", false))
	auto_upgrade_ratio = float(data.get("auto_upgrade_ratio", 0.5))
	auto_upgrade_include_marble = bool(data.get("auto_upgrade_include_marble", true))
	debt_auto_repay_boosted = bool(data.get("debt_auto_repay_boosted", false))
	golden_storm_spins_left = int(data.get("golden_storm_spins_left", 0))
	piggy_bank_net = float(data.get("piggy_bank_net", 0.0))
	piggy_bank_spins = int(data.get("piggy_bank_spins", 0))
	fever_spin_count = int(data.get("fever_spin_count", 0))
	wheel_of_fortune_timer = float(data.get("wheel_of_fortune_timer", -1.0))
	emergency_fund_cooldown = float(data.get("emergency_fund_cooldown", 0.0))
	EventBus.chips_changed.emit(chips, 0.0)
	EventBus.clovers_changed.emit(clovers, 0)
	EventBus.bets_changed.emit()


func _bets_to_array(list: Array[Bet]) -> Array:
	var out: Array = []
	for bet in list:
		out.append(bet.to_dict())
	return out


func _array_to_bets(list: Array) -> Array[Bet]:
	var out: Array[Bet] = []
	for entry in list:
		out.append(Bet.from_dict(entry))
	return out


## 시간제(buff:)·패널티(penalty:) 수정자만 내보낸다. 영구 수정자는 upgrade_levels/skill_levels 에서
## rebuild_upgrade_modifiers() 로 다시 만든다.
func _export_buffs() -> Array:
	var out: Array = []
	for modifier in modifiers.get_modifiers():
		if modifier.source_id.begins_with(BUFF_SOURCE_PREFIX) or modifier.source_id.begins_with(PENALTY_SOURCE_PREFIX):
			out.append(modifier.to_dict())
	return out


## 시간제는 remaining(남은 초)이 있을 때만, 소모형(charges ≥ 0)은 charges 가 남아있을 때만 되살린다.
func _import_buffs(list: Array) -> void:
	for entry in list:
		var d: Dictionary = entry
		var remaining := float(d.get("remaining", 0.0))
		var charges := int(d.get("charges", -1))
		if charges >= 0:
			if charges <= 0:
				continue
		elif remaining <= 0.0:
			continue
		var op: StatModifiers.Op = int(d.get("op", StatModifiers.Op.ADD))
		modifiers.add_modifier(String(d.get("source_id", "")), String(d.get("stat", "")), op, float(d.get("value", 0.0)), remaining, charges)
