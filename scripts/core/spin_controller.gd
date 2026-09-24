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
	var outcome := RouletteRules.resolve(active_bets, active_results, GameState.build_spin_context())
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
	var outcome := RouletteRules.resolve(GameState.pending_spin_bets, GameState.pending_spin_results, GameState.build_spin_context())
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
	# 5단계: 빚이 있으면 여기서 당첨금의 DEBT_AUTO_REPAY_RATE 를 자동 상환한다.
	if outcome.total_return > 0.0:
		GameState.add_chips(outcome.total_return)
	GameState.push_results(outcome.results)
	GameState.increment_stat(GameState.STAT_TOTAL_SPINS)
	GameState.max_stat(GameState.STAT_BIGGEST_WIN, outcome.total_return)
	GameState.income_tracker.add(GameState.get_stat_value(GameState.STAT_PLAY_TIME), outcome.net)
	var straight_hits := outcome.hit_straights.size()
	if straight_hits > 0:
		GameState.increment_stat(GameState.STAT_STRAIGHT_HITS, straight_hits)
		GameState.add_clovers(straight_hits * Economy.CLOVER_PER_STRAIGHT_HIT)
	if outcome.any_win():
		GameState.increment_stat(GameState.STAT_TOTAL_WINS)
		GameState.win_streak += 1
		GameState.max_stat(GameState.STAT_BEST_STREAK, GameState.win_streak)
		if GameState.win_streak % Economy.STREAK_LENGTH == 0:
			GameState.add_clovers(Economy.CLOVER_PER_STREAK)
	else:
		GameState.win_streak = 0


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)
