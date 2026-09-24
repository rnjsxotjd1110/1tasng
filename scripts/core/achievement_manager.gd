class_name AchievementManager
extends RefCounted
## 업적 조건 판정(GDD 10-3장). GameState 가 소유하고 _ready() 에서 attach() 를 한 번 부른다(PenaltyManager 와 동형).
## 목록·이름·설명·아이콘·숨김 여부는 data/achievements.json(AchievementData). 조건 판정은 EventBus 를 듣고 여기서 코드로 한다.
## 해금되면 GameState.unlocked_achievements 에 추가하고 EventBus.achievement_unlocked(id) 를 발행한다.

## 파산 없이 지난 시간(초). 파산 시 0 으로 돌아간다. 불러오기 뒤에는 다시 처음부터 잰다(PenaltyManager.time_left 와 같은 수준의 단순화).
var no_bankrupt_timer: float = 0.0
var _attached: bool = false


func reset() -> void:
	no_bankrupt_timer = 0.0


func attach() -> void:
	if _attached:
		return
	_attached = true
	EventBus.spin_resolved.connect(_on_spin_resolved)
	EventBus.debt_changed.connect(_on_debt_changed)
	EventBus.floor_changed.connect(_on_floor_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.skill_purchased.connect(_on_skill_purchased)
	EventBus.buff_started.connect(_on_buff_started)
	EventBus.chips_changed.connect(_on_chips_changed)
	EventBus.bankrupt.connect(_on_bankrupt)
	EventBus.ending_triggered.connect(func() -> void: _unlock("ending_reached"))


func process(delta: float) -> void:
	no_bankrupt_timer += delta
	if no_bankrupt_timer >= Economy.ACHIEVEMENT_NO_BANKRUPT_SECONDS:
		_unlock("no_bankrupt_1h")


func _on_bankrupt() -> void:
	no_bankrupt_timer = 0.0


func _on_spin_resolved(outcome: SpinOutcome) -> void:
	_unlock("first_spin")
	if not outcome.hit_straights.is_empty():
		_unlock("first_straight")
	if outcome.results.has(RouletteRules.ZERO):
		_unlock("zero_hit")
	if GameState.win_streak >= 10:
		_unlock("win_streak_10")
	if outcome.tier == SpinOutcome.Tier.JACKPOT:
		_unlock("jackpot_shown")
	if outcome.destiny_flip_from >= 0:
		_unlock("destiny_flip_hit")
	if outcome.golden_hit:
		_unlock("golden_pocket_hit")
	for number in RouletteRules.LUCKY_SEVEN_NUMBERS:
		if outcome.hit_straights.has(number):
			_unlock("lucky_seven")
			break
	if outcome.results.size() >= 2:
		var all_hit := true
		for number in outcome.results:
			if not _result_has_win(outcome, number):
				all_hit = false
				break
		if all_hit:
			_unlock("double_ball_both_hit")
	var history := GameState.result_history
	var n := history.size()
	if n >= 3 and history[n - 1] == history[n - 2] and history[n - 2] == history[n - 3]:
		_unlock("same_number_3")
	if GameState.get_stat_value(GameState.STAT_TOTAL_SPINS) >= Economy.ACHIEVEMENT_TOTAL_SPINS_LOW:
		_unlock("total_spins_1000")
	if GameState.get_stat_value(GameState.STAT_TOTAL_SPINS) >= Economy.ACHIEVEMENT_TOTAL_SPINS_HIGH:
		_unlock("total_spins_10000")


## number 하나만으로(다른 공 결과와 무관하게) 이기는 베팅이 있는가. hit_count 는 공 두 개를 합산해 버려서
## 공별로 못 나누므로, 순수 함수 RouletteRules.bet_wins() 를 그 결과 하나로 다시 계산한다.
static func _result_has_win(outcome: SpinOutcome, number: int) -> bool:
	for bet_result: SpinOutcome.BetResult in outcome.bet_results:
		if RouletteRules.bet_wins(bet_result.bet, number):
			return true
	return false


func _on_debt_changed() -> void:
	if GameState.get_stat_value(GameState.STAT_LOANS_TAKEN) >= 1.0:
		_unlock("first_loan")
	if GameState.debts.size() >= Economy.MAX_LOANS:
		_unlock("triple_loans")
	if String(GameState.pending_baron_event.get("type", "")) == "debt_paid":
		_unlock("debt_paid_first")


func _on_floor_changed(floor_index: int) -> void:
	if floor_index >= 2:
		_unlock("floor_reached_2f")
	if floor_index >= 3:
		_unlock("floor_reached_3f")
	if floor_index >= GameData.floors().size() - 1:
		_unlock("floor_reached_ph")


func _on_upgrade_purchased(id: String, level: int) -> void:
	if id == GameState.UPGRADE_MARBLE_TIER:
		if level >= 5:
			_unlock("marble_gold")
		if level >= 10:
			_unlock("marble_diamond")
		if level >= 14:
			_unlock("marble_cosmic")
	_check_marble_slots()


func _on_skill_purchased(_id: String, _level: int) -> void:
	_check_marble_slots()
	var total := SkillService.grand_total()
	if total <= 0:
		return
	var invested := SkillService.invested_total()
	if invested >= total:
		_unlock("skill_full")
	elif invested * 2 >= total:
		_unlock("skill_half")


func _check_marble_slots() -> void:
	if GameState.marble_slots() >= 12:
		_unlock("marbles_12")


func _on_buff_started(id: String, _duration: float) -> void:
	if id == "fever":
		_unlock("first_fever")


func _on_chips_changed(_new_value: float, _delta: float) -> void:
	if GameState.get_stat_value(GameState.STAT_TOTAL_EARNED) >= Economy.ACHIEVEMENT_TOTAL_CHIPS:
		_unlock("total_chips_1qa")


## SaveManager.load_game() 이 오프라인 수익을 계산한 뒤 호출한다(elapsed_seconds, eligible 인 경우에만).
func check_offline_hours(elapsed_seconds: float) -> void:
	if elapsed_seconds >= Economy.ACHIEVEMENT_OFFLINE_HOURS * 3600.0:
		_unlock("offline_8h")


## 마담 벨벳(7단계 3/N) 대사가 재생될 때마다 호출: key 의 모든 변형을 다 봤으면 숨김 업적 해금.
func mark_dialogue_seen(dialogue_key: String, variant_index: int) -> void:
	var seen: Dictionary = GameState.achievement_dialogue_seen.get(dialogue_key, {})
	seen[variant_index] = true
	GameState.achievement_dialogue_seen[dialogue_key] = seen
	if seen.size() >= DialogueData.variant_count(dialogue_key):
		_unlock("velvet_all_lines")


func _unlock(id: String) -> void:
	if GameState.unlocked_achievements.has(id):
		return
	if not AchievementData.has(id):
		push_error("AchievementManager: 없는 업적 id '%s'" % id)
		return
	GameState.unlocked_achievements.append(id)
	EventBus.achievement_unlocked.emit(id)
