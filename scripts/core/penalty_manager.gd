class_name PenaltyManager
extends RefCounted
## 빚이 있는 동안 랜덤 패널티를 건다(GDD 9장). 간격은 빚 건수가 늘수록 짧아진다.
## 순수 로직 + 타이머 상태만 가진다: 실제 효과는 GameState.add_penalty_timed/charge 또는(소매치기) spend_chips 로 걸고,
## 연출은 EventBus.buff_started/buff_ended·penalty_triggered 를 듣는 쪽(scenes)이 맡는다.
## GameState 가 소유하고 매 프레임 process(delta) 를 부른다(income_tracker·modifiers 와 같은 방식).

enum Kind { WATCHER, PICKPOCKET, SMOKE, BLUR, SEIZE, CLOVER_FEE }

const IDS := {
	Kind.WATCHER: "watcher",
	Kind.PICKPOCKET: "pickpocket",
	Kind.SMOKE: "smoke",
	Kind.BLUR: "blur",
	Kind.SEIZE: "seize_marble",
	Kind.CLOVER_FEE: "clover_fee",
}
const ALL_KINDS: Array[Kind] = [Kind.WATCHER, Kind.PICKPOCKET, Kind.SMOKE, Kind.BLUR, Kind.SEIZE, Kind.CLOVER_FEE]
## 지속시간이 없는 패널티(즉시 발동·소모형)의 토스트 표시 시간.
const INSTANT_DISPLAY_DURATION := 3.0

## 다음 패널티까지 남은 시간. 음수면 아직 첫 간격이 안 정해진 것(빚이 막 생겼을 때).
var time_left: float = -1.0
## 방금 전 패널티(연속 금지용). -1 이면 없음.
var last_kind: int = -1
## Main 이 BIG 이상 연출·대화·계약서 팝업 중에 true 로 둔다. true 인 동안 타이머가 멈춘다.
var suppressed: bool = false


func reset() -> void:
	time_left = -1.0
	last_kind = -1


func process(delta: float) -> void:
	if not GameState.has_debt():
		time_left = -1.0
		return
	if time_left < 0.0:
		time_left = _next_interval()
		return
	if suppressed:
		return
	time_left -= delta
	if time_left <= 0.0:
		_trigger_random()
		time_left = _next_interval()


func _next_interval() -> float:
	var index := clampi(GameState.debts.size() - 1, 0, Economy.MAX_LOANS - 1)
	var lo: float = Economy.PENALTY_INTERVAL_MIN_BY_LOANS[index]
	var hi: float = Economy.PENALTY_INTERVAL_MAX_BY_LOANS[index]
	var base := RngService.randf_range_misc(lo, hi)
	return base * GameState.get_stat(StatModifiers.PENALTY_INTERVAL_MULT, StatModifiers.IDENTITY_MULT)


func _trigger_random() -> void:
	var kind := _pick_kind()
	last_kind = kind
	var duration := RngService.randf_range_misc(Economy.PENALTY_DURATION_MIN, Economy.PENALTY_DURATION_MAX)
	_apply(kind, duration)


## 직전 패널티는 제외(연속 금지). 구슬이 1개뿐이면 압류는 효과가 없으므로 제외(GDD 9장).
func _pick_kind() -> Kind:
	var candidates := ALL_KINDS.duplicate()
	if candidates.size() > 1 and candidates.has(last_kind):
		candidates.erase(last_kind)
	if GameState.marble_slots() <= 1:
		candidates.erase(Kind.SEIZE)
	if candidates.is_empty():
		candidates = ALL_KINDS.duplicate()
	return candidates[RngService.randi_range_misc(0, candidates.size() - 1)]


func _apply(kind: Kind, duration: float) -> void:
	var id: String = IDS[kind]
	match kind:
		Kind.WATCHER:
			GameState.add_penalty_timed(id, StatModifiers.SPIN_DURATION_MULT, StatModifiers.Op.MULT, 1.0 / Economy.PENALTY_WATCHER_SPEED, duration)
			EventBus.penalty_triggered.emit(id, duration)
		Kind.SMOKE:
			# 수치 효과는 없음(연출만). payout_mult_all ×1.0 은 항등 수정자로, 기존 시간제 만료 체계를 그대로 빌려
			# 시작·종료 신호(buff_started/buff_ended)만 얻는다.
			GameState.add_penalty_timed(id, StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT, StatModifiers.IDENTITY_MULT, duration)
			EventBus.penalty_triggered.emit(id, duration)
		Kind.BLUR:
			GameState.add_penalty_timed(id, StatModifiers.MARBLE_MULT, StatModifiers.Op.MULT, Economy.PENALTY_BLUR_MARBLE_MULT, duration)
			EventBus.penalty_triggered.emit(id, duration)
		Kind.SEIZE:
			GameState.add_penalty_charge(id, StatModifiers.LOCKED_MARBLES, StatModifiers.Op.ADD, float(Economy.PENALTY_SEIZE_MARBLES), 1)
			EventBus.penalty_triggered.emit(id, INSTANT_DISPLAY_DURATION)
		Kind.CLOVER_FEE:
			GameState.add_penalty_charge(id, StatModifiers.CLOVER_GAIN_MULT, StatModifiers.Op.MULT, Economy.PENALTY_CLOVER_FEE_MULT, 1)
			EventBus.penalty_triggered.emit(id, INSTANT_DISPLAY_DURATION)
		Kind.PICKPOCKET:
			_apply_pickpocket(id)


## 칩의 PENALTY_PICKPOCKET_RATE 를 즉시 훔친다. 최소 베팅 × PENALTY_PICKPOCKET_FLOOR_MIN_BETS 아래로는 절대 뺏지 않는다.
func _apply_pickpocket(id: String) -> void:
	var floor_amount := GameState.min_bet() * Economy.PENALTY_PICKPOCKET_FLOOR_MIN_BETS
	var available := maxf(0.0, GameState.chips - floor_amount)
	var steal := minf(GameState.chips * Economy.PENALTY_PICKPOCKET_RATE, available)
	if steal > 0.0:
		GameState.spend_chips(steal)
	EventBus.penalty_triggered.emit(id, INSTANT_DISPLAY_DURATION)
