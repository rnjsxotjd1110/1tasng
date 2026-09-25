class_name SpinController
extends RefCounted
## 스핀 상태 머신. 연출과 분리돼 있다.
##   IDLE → start_spin() → SPINNING → finish_spin() → RESOLVING → IDLE
## 연출 레이어는 EventBus.spin_started 를 받아 공을 굴리고, 끝나면 finish_spin() 을 호출한다.
## instant_resolve 가 true 면(헤드리스·테스트 기본값) start_spin() 안에서 바로 정산한다.

signal state_changed(new_state: State)

enum State { IDLE, SPINNING, RESOLVING }
enum SpinError { OK, BUSY, NO_BETS, TOO_MANY_BETS, INVALID_BET, NOT_ENOUGH_CHIPS }

const HEADLESS_DISPLAY := "headless"

var state: State = State.IDLE
var instant_resolve: bool = DisplayServer.get_name() == HEADLESS_DISPLAY
## 진행 중인 스핀의 베팅(금액이 채워진 복사본)과 결과.
var active_bets: Array[Bet] = []
var active_results: Array[int] = []
var active_duration: float = 0.0
var last_outcome: SpinOutcome = null
## 이번 정산에서 자동 상환된 금액(빚이 없었으면 0). Main 이 당첨 텍스트 둘째 줄에 쓴다.
var last_debt_repaid: float = 0.0


func is_idle() -> bool:
	return state == State.IDLE


## 베팅 1개당 이번 스핀에 걸 금액.
## 칩 크기 설정 금액을 쓰되, 보유 칩이 모자라면 (보유 칩 ÷ 베팅 수)로 줄인다.
## 최소 베팅액보다 작아지면 0(스핀 불가).
static func affordable_amount(desired: float, chips: float, bet_count: int, min_bet: float) -> float:
	if bet_count <= 0:
		return 0.0
	var amount := minf(desired, chips / bet_count)
	if amount < min_bet * (1.0 - Economy.BET_EPSILON):
		return 0.0
	return amount


## 현재 GameState 의 베팅으로 스핀을 시작할 수 있는지.
func validate() -> SpinError:
	if state != State.IDLE:
		return SpinError.BUSY
	var bets := GameState.current_bets
	if bets.is_empty():
		return SpinError.NO_BETS
	if bets.size() > GameState.marble_slots():
		return SpinError.TOO_MANY_BETS
	for bet in bets:
		if not bet.is_valid():
			return SpinError.INVALID_BET
	if affordable_amount(GameState.chip_amount(), GameState.chips, bets.size(), GameState.min_bet()) <= 0.0:
		return SpinError.NOT_ENOUGH_CHIPS
	return SpinError.OK


## 베팅 검증 → 칩 차감 → 결과 결정 → spin_started 발행.
func start_spin() -> SpinError:
	var error := validate()
	if error != SpinError.OK:
		return error
	var bets := GameState.current_bets
	var amount := affordable_amount(GameState.chip_amount(), GameState.chips, bets.size(), GameState.min_bet())
	active_bets = []
	for bet in bets:
		var placed := bet.copy()
		placed.amount = amount
		active_bets.append(placed)
	GameState.spin_in_progress = true
	if not GameState.spend_chips(amount * active_bets.size()):
		GameState.spin_in_progress = false
		active_bets = []
		return SpinError.NOT_ENOUGH_CHIPS
	GameState.consume_penalty_charge(GameState.PENALTY_ID_SEIZE_MARBLE)
	active_results = []
	for i in GameState.ball_count():
		active_results.append(RngService.consume_next())
	active_duration = GameState.spin_duration()
	# 스핀 도중 저장되면(GameState.spin_in_progress 가 true) 이 스냅샷으로 불러오기 즉시 정산한다.
	GameState.pending_spin_bets = active_bets
	GameState.pending_spin_results = active_results
	_set_state(State.SPINNING)
	EventBus.spin_started.emit(active_results.duplicate(), active_duration)
	if instant_resolve:
		finish_spin()
	return SpinError.OK


## 연출이 끝났을 때 호출한다. 정산하고 GameState 에 반영한 뒤 spin_resolved 를 발행한다.
func finish_spin() -> SpinOutcome:
	if state != State.SPINNING:
		push_warning("SpinController.finish_spin: 스핀 중이 아님")
		return null
	_set_state(State.RESOLVING)
	var outcome := _resolve_with_specials(active_bets, active_results, GameState.build_spin_context())
	_apply_outcome(outcome)
	last_outcome = outcome
	GameState.last_bets = active_bets
	active_bets = []
	GameState.pending_spin_bets = []
	GameState.pending_spin_results = []
	GameState.spin_in_progress = false
	_set_state(State.IDLE)
	EventBus.spin_resolved.emit(outcome)
	GameState.check_bankruptcy()
	return outcome


## 불러오기 직후 호출. GameState.spin_in_progress 이면(스핀 도중 저장) 연출 없이 즉시 정산한다.
func settle_pending_spin() -> SpinOutcome:
	if not GameState.spin_in_progress or GameState.pending_spin_bets.is_empty():
		GameState.spin_in_progress = false
		GameState.pending_spin_bets = []
		GameState.pending_spin_results = []
		return null
	var outcome := _resolve_with_specials(GameState.pending_spin_bets, GameState.pending_spin_results, GameState.build_spin_context())
	_apply_outcome(outcome)
	last_outcome = outcome
	GameState.last_bets = GameState.pending_spin_bets
	GameState.pending_spin_bets = []
	GameState.pending_spin_results = []
	GameState.spin_in_progress = false
	_set_state(State.IDLE)
	EventBus.spin_resolved.emit(outcome)
	GameState.check_bankruptcy()
	return outcome


func _apply_outcome(outcome: SpinOutcome) -> void:
	last_debt_repaid = 0.0
	_consume_golden_storm()
	if outcome.total_return > 0.0:
		GameState.add_chips(outcome.total_return)
		last_debt_repaid = GameState.auto_repay_debt(outcome.total_return)
	GameState.push_results(outcome.results)
	GameState.increment_stat(GameState.STAT_TOTAL_SPINS)
	GameState.max_stat(GameState.STAT_BIGGEST_WIN, outcome.total_return)
	GameState.income_tracker.add(GameState.get_stat_value(GameState.STAT_PLAY_TIME), outcome.net)
	GameState.emergency_fund_tracker.add(GameState.get_stat_value(GameState.STAT_PLAY_TIME), outcome.net)
	var straight_hits := outcome.hit_straights.size()
	if straight_hits > 0:
		GameState.increment_stat(GameState.STAT_STRAIGHT_HITS, straight_hits)
		GameState.add_clovers(straight_hits * Economy.CLOVER_PER_STRAIGHT_HIT)
		if outcome.hit_straights.has(RouletteRules.ZERO) and SkillService.has_feature("zero_blessing"):
			GameState.add_clovers(Economy.ZERO_BLESSING_CLOVER_BONUS)
		var bonus_chip_rate := GameState.get_stat(StatModifiers.BONUS_CHIP_PER_HIT, 0.0)
		if bonus_chip_rate > 0.0:
			GameState.add_chips(straight_hits * GameState.max_bet() * bonus_chip_rate)
	if outcome.any_win():
		GameState.increment_stat(GameState.STAT_TOTAL_WINS)
		GameState.win_streak += 1
		GameState.max_stat(GameState.STAT_BEST_STREAK, GameState.win_streak)
		if GameState.win_streak % Economy.STREAK_LENGTH == 0:
			GameState.add_clovers(Economy.CLOVER_PER_STREAK)
			EventBus.streak_clover_earned.emit(Economy.CLOVER_PER_STREAK)
	else:
		GameState.win_streak = 0
	_apply_vip_comp()
	_apply_jackpot_chain(straight_hits)
	_apply_golden_storm_trigger(outcome)
	_apply_fever()
	_apply_piggy_bank(outcome)


## 결과가 이미 정해진 뒤(RNG 소비 후) 특수 스킬 효과를 적용해 최종 SpinOutcome 을 만든다.
## RouletteRules.resolve() 자체는 순수 함수로 유지하고, RNG 가 필요한 재판정(운명 뒤집기)·확률형
## 후처리(미러)는 여기(오케스트레이션 계층)에서 misc 스트림으로 처리한다.
func _resolve_with_specials(bets: Array[Bet], results: Array[int], context: SpinContext) -> SpinOutcome:
	var final_results := results
	var flip_from := -1
	var flip_to := -1
	var flip_chance := GameState.get_stat(StatModifiers.DESTINY_FLIP_CHANCE, 0.0)
	if flip_chance > 0.0 and not results.is_empty():
		var tentative := RouletteRules.resolve(bets, results, context)
		if not tentative.any_win() and RngService.randf_misc() < flip_chance:
			var candidate := results.duplicate()
			var original := int(candidate[0])
			var options := RouletteRules.neighbors(original)
			if not options.is_empty():
				var picked: int = options[RngService.randi_range_misc(0, options.size() - 1)]
				candidate[0] = picked
				var alternative := RouletteRules.resolve(bets, candidate, context)
				# "유리할 때만" — 대안이 더 나을 때만 채택한다(원래보다 불리해지는 일은 없다).
				if alternative.total_return > tentative.total_return:
					final_results = candidate
					flip_from = original
					flip_to = picked
	var outcome := RouletteRules.resolve(bets, final_results, context)
	_apply_mirror(outcome)
	if flip_from >= 0:
		outcome.destiny_flip_from = flip_from
		EventBus.destiny_flip.emit(flip_from, flip_to)
	return outcome


## 미러(Y3): 진 베팅마다 확률적으로 무승부(원금 반환)로 바꾼다. resolve() 이후(순수 함수 밖)에서 처리한다.
func _apply_mirror(outcome: SpinOutcome) -> void:
	var chance := GameState.get_stat(StatModifiers.MIRROR_CHANCE, 0.0)
	if chance <= 0.0:
		return
	var extra_refund := 0.0
	for bet_result: SpinOutcome.BetResult in outcome.bet_results:
		if bet_result.won() or bet_result.pushed():
			continue
		if RngService.randf_misc() < chance:
			bet_result.refunded += bet_result.bet.amount
			extra_refund += bet_result.bet.amount
	if extra_refund > 0.0:
		outcome.total_return += extra_refund
		outcome.net = outcome.total_return - outcome.total_bet


## 황금 폭풍(Y12): 지난 스핀에 무장된 "모든 포켓 황금" 을 이번 스핀에 다 썼으니 소모한다(다음 컨텍스트부터 정상).
func _consume_golden_storm() -> void:
	if GameState.golden_storm_spins_left > 0:
		GameState.golden_storm_spins_left -= 1


## VIP 컴프(E3): 스핀마다 최대 베팅액의 일정 비율을 무조건 지급한다(누적 획득 통계에는 안 넣는다).
func _apply_vip_comp() -> void:
	var rate := GameState.get_stat(StatModifiers.VIP_COMP_RATE, 0.0)
	if rate > 0.0:
		GameState.add_chips(GameState.max_bet() * rate, false)


## 잭팟 체인(F14): 이번 스핀에 남아있던 충전을 먼저 소모(자기 스핀은 자기 효과를 못 받는다) →
## 개별숫자 적중이면 다음 JACKPOT_CHAIN_SPINS 스핀 동안 모든 배당 ×JACKPOT_CHAIN_MULT 로 갱신.
func _apply_jackpot_chain(straight_hits: int) -> void:
	# 운명의 휠(Y14)도 같은 버프를 걸 수 있으므로, 소모는 F14 보유 여부와 무관하게 버프가 있으면 항상 진행한다.
	if GameState.modifiers.has_source("buff:jackpot_chain"):
		GameState.modifiers.consume_charges("buff:jackpot_chain", 1)
	if straight_hits > 0 and SkillService.has_feature("jackpot_chain"):
		GameState.add_buff("jackpot_chain", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT,
			Economy.JACKPOT_CHAIN_MULT, StatModifiers.PERMANENT, Economy.JACKPOT_CHAIN_SPINS)


## 황금 폭풍(Y12) 발동 판정: 황금 포켓 적중 시 확률적으로 다음 스핀을 통째로 황금 포켓으로 만든다.
func _apply_golden_storm_trigger(outcome: SpinOutcome) -> void:
	var chance := GameState.get_stat(StatModifiers.GOLDEN_STORM_CHANCE, 0.0)
	if chance <= 0.0 or not outcome.golden_hit:
		return
	if RngService.randf_misc() < chance:
		GameState.golden_storm_spins_left = 1
		EventBus.golden_storm_triggered.emit(1)


## 피버 타임(Y5): 일정 스핀마다 한동안 모든 배당을 크게 올린다. Y11 이 주기·지속시간을 조정한다.
func _apply_fever() -> void:
	if not SkillService.has_feature("fever_time"):
		return
	GameState.fever_spin_count += 1
	var period := maxf(10.0, Economy.FEVER_PERIOD_SPINS - GameState.get_stat(StatModifiers.FEVER_PERIOD_REDUCTION, 0.0))
	if float(GameState.fever_spin_count) < period:
		return
	GameState.fever_spin_count = 0
	var duration := Economy.FEVER_DURATION + GameState.get_stat(StatModifiers.FEVER_DURATION_BONUS, 0.0)
	GameState.add_buff("fever", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT, Economy.FEVER_MULT, duration)


## 황금 저금통(E13): 순이익을 누적하다 100스핀마다 정산해 지급한다(음수 누적이면 지급 없이 초기화).
func _apply_piggy_bank(outcome: SpinOutcome) -> void:
	var rate := GameState.get_stat(StatModifiers.PIGGY_BANK_RATE, 0.0)
	if rate <= 0.0:
		return
	GameState.piggy_bank_net += outcome.net
	GameState.piggy_bank_spins += 1
	if GameState.piggy_bank_spins < Economy.PIGGY_BANK_INTERVAL_SPINS:
		return
	var payout := maxf(0.0, GameState.piggy_bank_net) * rate
	GameState.piggy_bank_net = 0.0
	GameState.piggy_bank_spins = 0
	if payout > 0.0:
		GameState.add_chips(payout)
	EventBus.piggy_bank_broken.emit(payout)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)
