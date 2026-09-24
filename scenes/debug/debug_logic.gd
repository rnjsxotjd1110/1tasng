extends Control
## ⚠ 2단계에서 삭제 예정 ⚠
## 그래픽 없이 규칙 엔진을 눈으로 확인하는 디버그 화면.
## 디버그 전용이라 tr()·품질 기준(기본 테마 금지 등)의 예외다. 게임 코드에서 이 씬을 참조하지 말 것.

const DEBUG_FONT_SIZE := 8
const MARGIN := 4
const LOG_MAX_LINES := 200
const DEBUG_CHIPS := 1000.0
const BULK_SPINS := 100
const MAX_NUMBER := 36

var controller := SpinController.new()
## 테스트가 버튼을 누르기 위해 이름 → Button 으로 보관한다.
var buttons: Dictionary = {}
var status_label: Label
var bets_label: Label
var log_view: RichTextLabel
var number_input: SpinBox
var _log_lines: Array[String] = []


func _ready() -> void:
	controller.instant_resolve = true
	_build_ui()
	EventBus.chips_changed.connect(func(_v: float, _d: float) -> void: _refresh())
	EventBus.clovers_changed.connect(_on_clovers_changed)
	EventBus.bets_changed.connect(_refresh)
	EventBus.spin_resolved.connect(_on_spin_resolved)
	EventBus.milestone_reached.connect(_on_milestone)
	EventBus.bankrupt.connect(_on_bankrupt)
	_log("[color=yellow]DEBUG LOGIC — 2단계에서 삭제 예정[/color]  시드 %d" % RngService.get_seed())
	_refresh()


func _build_ui() -> void:
	var theme_override := Theme.new()
	theme_override.default_font_size = DEBUG_FONT_SIZE
	theme = theme_override
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_box := HBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_box.offset_left = MARGIN
	root_box.offset_top = MARGIN
	root_box.offset_right = -MARGIN
	root_box.offset_bottom = -MARGIN
	add_child(root_box)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(left)
	var title := Label.new()
	title.text = "DEBUG LOGIC (2단계에서 삭제 예정)"
	left.add_child(title)
	status_label = Label.new()
	left.add_child(status_label)
	bets_label = Label.new()
	bets_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(bets_label)

	var grid := GridContainer.new()
	grid.columns = 4
	left.add_child(grid)
	_add_button(grid, "red", "RED", func() -> void: _place(Bet.red()))
	_add_button(grid, "black", "BLACK", func() -> void: _place(Bet.black()))
	_add_button(grid, "odd", "ODD", func() -> void: _place(Bet.odd()))
	_add_button(grid, "even", "EVEN", func() -> void: _place(Bet.even()))
	number_input = SpinBox.new()
	number_input.min_value = 0
	number_input.max_value = MAX_NUMBER
	grid.add_child(number_input)
	_add_button(grid, "straight", "STRAIGHT", func() -> void: _place(Bet.straight(int(number_input.value))))
	_add_button(grid, "clear", "베팅 지우기", GameState.clear_bets)
	_add_button(grid, "chip_size", "칩 크기", _cycle_chip_size)
	_add_button(grid, "spin", "SPIN", _spin_once)
	_add_button(grid, "spin_bulk", "SPIN ×%d" % BULK_SPINS, _spin_bulk)
	_add_button(grid, "add_chips", "+%s 칩" % NumberFormat.format(DEBUG_CHIPS), func() -> void: GameState.add_chips(DEBUG_CHIPS, false))
	_add_button(grid, "marble_slot", "구슬 +1", _add_marble_slot)
	_add_button(grid, "marble_tier", "재질 +1", _next_marble)
	_add_button(grid, "bet_limit", "한도 +1", func() -> void: _bump_upgrade("bet_limit"))
	_add_button(grid, "golden", "황금 +1", func() -> void: _bump_upgrade("golden_pocket"))
	_add_button(grid, "reset", "리셋", _reset)

	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(log_view)


func _add_button(parent: Control, id: String, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	buttons[id] = button


func _place(bet: Bet) -> void:
	if not GameState.add_bet(bet):
		_log("[color=gray]구슬이 부족하다 (%d/%d)[/color]" % [GameState.current_bets.size(), GameState.marble_slots()])


func _cycle_chip_size() -> void:
	var modes: Array = Economy.CHIP_SIZE_RATIOS.keys()
	var next_index := (modes.find(GameState.chip_size_mode) + 1) % modes.size()
	GameState.set_chip_size_mode(modes[next_index])


func _spin_once() -> void:
	var error := controller.start_spin()
	if error != SpinController.SpinError.OK:
		_log("[color=gray]스핀 불가: %s[/color]" % SpinController.SpinError.keys()[error])


func _spin_bulk() -> void:
	var before := GameState.chips
	var done := 0
	for i in BULK_SPINS:
		if controller.start_spin() != SpinController.SpinError.OK:
			break
		done += 1
	_log("[b]%d스핀 완료[/b] 칩 %s → %s" % [done, NumberFormat.format(before), NumberFormat.format(GameState.chips)])


func _add_marble_slot() -> void:
	_bump_upgrade("marble_count")


func _bump_upgrade(id: String) -> void:
	GameState.set_upgrade_level(id, GameState.get_upgrade_level(id) + 1)
	_log("업그레이드 %s → %d" % [id, GameState.get_upgrade_level(id)])
	_refresh()


func _next_marble() -> void:
	GameState.marble_tier = mini(GameState.marble_tier + 1, GameData.marbles().size() - 1)
	GameState.polish_level = 0
	_log("구슬 재질 → %s (×%s)" % [GameState.current_marble().id, NumberFormat.format(GameState.current_marble().mult)])
	_refresh()


func _reset() -> void:
	GameState.reset()
	_log("[color=yellow]리셋[/color]")


func _refresh() -> void:
	if status_label == null:
		return
	status_label.text = "칩 %s  클로버 %d  연승 %d\n베팅 %s (최소 %s / 최대 %s, %s)\n구슬 %s ×%s  스핀 %.2f초  황금 %s" % [
		NumberFormat.format(GameState.chips), GameState.clovers, GameState.win_streak,
		NumberFormat.format(GameState.chip_amount()), NumberFormat.format(GameState.min_bet()),
		NumberFormat.format(GameState.max_bet()), Economy.ChipSize.keys()[GameState.chip_size_mode],
		GameState.current_marble().id, NumberFormat.format(GameState.marble_mult()),
		GameState.spin_duration(), GameState.golden_pockets]
	var bet_texts: PackedStringArray = []
	for bet in GameState.current_bets:
		bet_texts.append(bet.label_key().trim_prefix("BET_") + (" %d" % bet.number if bet.type == Bet.Type.STRAIGHT else ""))
	bets_label.text = "구슬 %d/%d: %s" % [GameState.current_bets.size(), GameState.marble_slots(), ", ".join(bet_texts)]


func _on_spin_resolved(outcome: SpinOutcome) -> void:
	var colors := {RouletteRules.PocketColor.RED: "red", RouletteRules.PocketColor.BLACK: "silver", RouletteRules.PocketColor.GREEN: "green"}
	var result_texts: PackedStringArray = []
	for result in outcome.results:
		result_texts.append("[color=%s]%d[/color]" % [colors[RouletteRules.color_of(result)], result])
	var extra := ""
	if outcome.golden_hit:
		extra += " [color=gold]황금![/color]"
	if outcome.tier == SpinOutcome.Tier.LOSS and outcome.near_miss:
		extra += " 아깝다!"
	_log("결과 %s  베팅 %s  반환 %s  순이익 %s  [%s]%s" % [
		" ".join(result_texts), NumberFormat.format(outcome.total_bet), NumberFormat.format(outcome.total_return),
		NumberFormat.format_signed(outcome.net), SpinOutcome.Tier.keys()[outcome.tier], extra])


func _on_clovers_changed(value: int, delta: int) -> void:
	if delta > 0:
		_log("[color=lime]클로버 +%d (보유 %d)[/color]" % [delta, value])
	_refresh()


func _on_milestone(index: int) -> void:
	_log("[color=gold]새 단위 도달: %s[/color]" % NumberFormat.SUFFIXES[index])


func _on_bankrupt() -> void:
	_log("[color=red]파산! (칩 %s < 최소 베팅 %s)[/color]" % [NumberFormat.format(GameState.chips), NumberFormat.format(GameState.min_bet())])


func _log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > LOG_MAX_LINES:
		_log_lines.pop_front()
	if log_view != null:
		log_view.text = "\n".join(_log_lines)


## 테스트용: 지금까지의 로그(bbcode 포함).
func get_log_text() -> String:
	return "\n".join(_log_lines)
