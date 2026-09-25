extends Control
## F9 개발용 디버그 패널(개발 빌드 전용 — Main 이 OS.is_debug_build() 일 때만 동적으로 붙인다).
## scenes/debug/ 는 tr()·품질 기준 예외. 숫자 표기 점검(K~Vg)과 업그레이드 검수를 빠르게 하려고 만든다.
##   칩을 1e3 / 1e15 / 1e33 / 1e60 으로 설정 · 클로버 추가 · 시간 가속 · 층 이동 · 재질 바꾸기

const PANEL_POS := Vector2(108, 28)
const CHIP_PRESETS: Array[float] = [1e3, 1e15, 1e33, 1e60]
const CLOVER_STEPS: Array[int] = [10, 100]
const SPEEDS: Array[float] = [1.0, 4.0, 10.0]

## Main 이 넣어 준다(재질 표시 갱신용).
var main: Node

var _panel: PanelContainer
var _info: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 360)
	_panel = PanelContainer.new()
	_panel.position = PANEL_POS
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "DEBUG (F9)"
	title.theme_type_variation = "LabelGold"
	box.add_child(title)
	_row(box, "Chips", CHIP_PRESETS.map(func(v: float) -> Array: return [NumberFormat.format(v), func() -> void: set_chips(v)]))
	_row(box, "Clover", CLOVER_STEPS.map(func(v: int) -> Array: return ["+%d" % v, func() -> void: GameState.add_clovers(v)]))
	_row(box, "Speed", SPEEDS.map(func(v: float) -> Array: return ["x%d" % int(v), func() -> void: Engine.time_scale = v]))
	_row(box, "Floor", [["-1", func() -> void: set_floor(GameState.floor_index - 1)], ["+1", func() -> void: set_floor(GameState.floor_index + 1)]])
	_row(box, "Marble", [["-1", func() -> void: set_tier(GameState.marble_tier - 1)], ["+1", func() -> void: set_tier(GameState.marble_tier + 1)]])
	_row(box, "Upgr", [["all +10", _all_plus_ten], ["reset", _reset]])
	_info = Label.new()
	_info.theme_type_variation = "LabelSmallMuted"
	box.add_child(_info)
	visible = false


func _row(box: VBoxContainer, caption: String, buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	box.add_child(row)
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = "LabelSmall"
	label.custom_minimum_size = Vector2(40, 0)
	row.add_child(label)
	for entry: Array in buttons:
		var button := Button.new()
		button.text = String(entry[0])
		button.theme_type_variation = "ButtonDark"
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		row.add_child(button)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F9:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_info.text = "chips %s  floor %d  tier %d  x%s" % [NumberFormat.format_full(GameState.chips), GameState.floor_index, GameState.marble_tier, str(Engine.time_scale)]


static func set_chips(value: float) -> void:
	GameState.spend_chips(GameState.chips)
	GameState.add_chips(value, false)


static func set_floor(index: int) -> void:
	GameState.floor_index = clampi(index, 0, GameData.floors().size() - 1)
	EventBus.floor_changed.emit(GameState.floor_index)


func set_tier(tier: int) -> void:
	GameState.set_upgrade_level(GameState.UPGRADE_MARBLE_TIER, clampi(tier, 0, GameData.marbles().size() - 1))
	GameState.set_upgrade_level(GameState.UPGRADE_MARBLE_POLISH, 0)
	EventBus.upgrade_purchased.emit(GameState.UPGRADE_MARBLE_TIER, GameState.marble_tier)


func _reset() -> void:
	GameState.reset()
	if main != null:
		main.call("_on_promotion_arrived", GameState.marble_tier)


func _all_plus_ten() -> void:
	for def in GameData.upgrades():
		if def.kind == UpgradeDef.Kind.STANDARD:
			GameState.set_upgrade_level(def.id, GameState.get_upgrade_level(def.id) + 10)
			EventBus.upgrade_purchased.emit(def.id, GameState.get_upgrade_level(def.id))
