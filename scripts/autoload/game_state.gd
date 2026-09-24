extends Node
## 게임 진행 상태의 단일 원본.
## - 칩 변경은 add_chips()/spend_chips() 로만 한다(음수·NaN·INF 방어, 시그널 발행).
## - 클로버 변경은 add_clovers()/spend_clovers() 로만 한다.
## - 스탯 계산은 modifiers(StatModifiers)를 거친다.

const STAT_TOTAL_SPINS := "total_spins"
const STAT_BIGGEST_WIN := "biggest_win"
const STAT_BEST_STREAK := "best_streak"
const STAT_PLAY_TIME := "play_time"
const STAT_LOANS_TAKEN := "loans_taken"
const STAT_STRAIGHT_HITS := "straight_hits"
const STAT_TOTAL_EARNED := "total_earned"

const MILESTONE_ICON := "chip"
const BUFF_SOURCE_PREFIX := "buff:"

var chips: float = Economy.STARTING_CHIPS
var clovers: int = 0
var floor_index: int = 0
## 업그레이드 id → 레벨.
var upgrade_levels: Dictionary = {}
## 스킬 id → 레벨.
var skill_levels: Dictionary = {}
var marble_tier: int = 0
var polish_level: int = 0
var current_bets: Array[Bet] = []
## 직전 스핀에 실제로 쓰인 베팅(금액 포함).
var last_bets: Array[Bet] = []
var chip_size_mode: int = Economy.ChipSize.MAX
## 빚 목록(5단계). 각 항목 {"principal": float, "remaining": float}
var debts: Array[Dictionary] = []
## 한 스핀에 1개 이상 당첨이 연속된 횟수.
var win_streak: int = 0
## 최근 결과(오래된 것 → 최신). 공이 여러 개면 모두 들어간다.
var result_history: Array[int] = []
var golden_pockets: Array[int] = []
## 지금까지 도달한 가장 큰 칩 단위(NumberFormat.suffix_index).
var highest_milestone: int = 0
var stats: Dictionary = {}
## SpinController 가 스핀 중에 true 로 둔다. 파산 판정에 쓴다.
var spin_in_progress: bool = false
var modifiers := StatModifiers.new()


func _ready() -> void:
	modifiers.source_expired.connect(_on_modifier_source_expired)
	reset()


func _process(delta: float) -> void:
	stats[STAT_PLAY_TIME] = float(stats.get(STAT_PLAY_TIME, 0.0)) + delta
	modifiers.tick(delta)


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
	win_streak = 0
	result_history = []
	golden_pockets = []
	highest_milestone = NumberFormat.suffix_index(chips)
	spin_in_progress = false
	stats = {
		STAT_TOTAL_SPINS: 0,
		STAT_BIGGEST_WIN: 0.0,
		STAT_BEST_STREAK: 0,
		STAT_PLAY_TIME: 0.0,
		STAT_LOANS_TAKEN: 0,
		STAT_STRAIGHT_HITS: 0,
		STAT_TOTAL_EARNED: 0.0,
	}
	modifiers.clear()
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
	while highest_milestone < index:
		highest_milestone += 1
		EventBus.milestone_reached.emit(highest_milestone)
		add_clovers(Economy.CLOVER_PER_MILESTONE)


# ── 클로버 ───────────────────────────────────────────────

## 클로버 획득. clover_gain_mult 가 적용되고 내림한다. 실제로 얻은 개수를 돌려준다.
func add_clovers(amount: int) -> int:
	if amount <= 0:
		return 0
	var gained := floori(amount * get_stat(StatModifiers.CLOVER_GAIN_MULT, StatModifiers.IDENTITY_MULT))
	if gained <= 0:
		return 0
	clovers += gained
	EventBus.clovers_changed.emit(clovers, gained)
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
	return Economy.spin_duration(get_stat(StatModifiers.SPIN_DURATION_MULT, StatModifiers.IDENTITY_MULT))


## 구슬 재질 × 광택 × 구슬 수정자.
func marble_mult() -> float:
	var marble := current_marble()
	var base := marble.mult if marble != null else StatModifiers.IDENTITY_MULT
	return get_stat(StatModifiers.MARBLE_MULT, base * Economy.polish_mult(polish_level))


func floor_mult() -> float:
	var floor_def := current_floor()
	var base := floor_def.payout_mult if floor_def != null else StatModifiers.IDENTITY_MULT
	return get_stat(StatModifiers.FLOOR_MULT, base)


func golden_pocket_count() -> int:
	return clampi(int(get_stat(StatModifiers.GOLDEN_POCKET_COUNT, StatModifiers.IDENTITY_ADD)), 0, Economy.GOLDEN_POCKET_MAX)


func build_spin_context() -> SpinContext:
	var context := SpinContext.new()
	context.marble_mult = marble_mult()
	context.floor_mult = floor_mult()
	context.payout_mult_all = get_stat(StatModifiers.PAYOUT_MULT_ALL, StatModifiers.IDENTITY_MULT)
	context.payout_mult_color = get_stat(StatModifiers.PAYOUT_MULT_COLOR, StatModifiers.IDENTITY_MULT)
	context.payout_mult_parity = get_stat(StatModifiers.PAYOUT_MULT_PARITY, StatModifiers.IDENTITY_MULT)
	context.straight_payout_bonus = get_stat(StatModifiers.STRAIGHT_PAYOUT_BONUS, StatModifiers.IDENTITY_ADD)
	context.golden_pockets = golden_pockets.duplicate()
	context.golden_pocket_mult = get_stat(StatModifiers.GOLDEN_POCKET_MULT, Economy.GOLDEN_POCKET_MULT)
	return context


func is_bankrupt() -> bool:
	return Economy.is_bankrupt(chips, min_bet(), spin_in_progress)


## 파산이면 bankrupt 를 발행하고 true.
func check_bankruptcy() -> bool:
	if is_bankrupt():
		EventBus.bankrupt.emit()
		return true
	return false


# ── 업그레이드·버프 ─────────────────────────────────────

func get_upgrade_level(id: String) -> int:
	return int(upgrade_levels.get(id, 0))


## 업그레이드 레벨을 정하고 수정자를 다시 건다(구매 처리·비용 차감은 3단계 UpgradeService 가 한다).
func set_upgrade_level(id: String, level: int) -> void:
	var def := GameData.upgrade(id)
	if def == null:
		push_error("GameState.set_upgrade_level: 없는 업그레이드 '%s'" % id)
		return
	if def.max_level != UpgradeDef.UNLIMITED:
		level = mini(level, def.max_level)
	level = maxi(level, 0)
	upgrade_levels[id] = level
	modifiers.remove_source(def.source_id())
	if level > 0 and def.effect_stat != "":
		modifiers.add_modifier(def.source_id(), def.effect_stat, def.effect_op, def.effect_value(level))
	if def.effect_stat == StatModifiers.GOLDEN_POCKET_COUNT:
		refresh_golden_pockets()


## 모든 업그레이드 수정자를 upgrade_levels 로부터 다시 만든다(불러오기 후 호출).
func rebuild_upgrade_modifiers() -> void:
	for id: String in upgrade_levels.keys():
		set_upgrade_level(id, int(upgrade_levels[id]))


## 황금 포켓 개수를 스탯에 맞춘다. 늘면 아직 황금이 아닌 포켓 중 무작위로 추가, 줄면 뒤에서 제거.
func refresh_golden_pockets() -> void:
	var target := golden_pocket_count()
	while golden_pockets.size() > target:
		golden_pockets.pop_back()
	while golden_pockets.size() < target:
		var candidates: Array[int] = []
		for number in RouletteRules.POCKET_COUNT:
			if not golden_pockets.has(number):
				candidates.append(number)
		golden_pockets.append(candidates[RngService.randi_range_misc(0, candidates.size() - 1)])


## 시간제 버프(또는 패널티). buff_started 를 발행하고, 만료되면 buff_ended 가 발행된다.
func add_buff(id: String, stat: String, op: StatModifiers.Op, value: float, duration: float) -> void:
	modifiers.add_modifier(BUFF_SOURCE_PREFIX + id, stat, op, value, duration)
	EventBus.buff_started.emit(id, duration)


func remove_buff(id: String) -> void:
	if modifiers.remove_source(BUFF_SOURCE_PREFIX + id) > 0:
		EventBus.buff_ended.emit(id)


func _on_modifier_source_expired(source_id: String) -> void:
	if source_id.begins_with(BUFF_SOURCE_PREFIX):
		EventBus.buff_ended.emit(source_id.trim_prefix(BUFF_SOURCE_PREFIX))


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
	while result_history.size() > Economy.HISTORY_SIZE:
		result_history.pop_front()


func get_stat_value(key: String) -> float:
	return float(stats.get(key, 0.0))


func increment_stat(key: String, amount: float = 1.0) -> void:
	stats[key] = float(stats.get(key, 0.0)) + amount


func max_stat(key: String, value: float) -> void:
	stats[key] = maxf(float(stats.get(key, 0.0)), value)
