class_name BetPanel
extends Control
## 오른쪽 베팅창(216×328, ART_BIBLE 1장 오른쪽 패널).
## 위 → 아래: 제목 · 0 칸 · 1~36 숫자판(3×12) · 외부 베팅 2×2 · 구슬 트레이 · 칩 크기 · 구슬당/총 베팅액 · [초기화][다시 걸기]
## 칸·구슬·트레이는 BetBoard 가 그린다.

const PANEL_SIZE := Vector2(216, 328)
const BOARD_POS := Vector2(12, 26)
const TITLE_Y := 8.0
const CHIP_ROW_Y := 253.0
const CHIP_BUTTON_X := 76.0
const CHIP_BUTTON_W := 42.0
const CHIP_BUTTON_H := 16.0
const CHIP_BUTTON_GAP := 1.0
const AMOUNT_Y := 271.0
const AMOUNT_ROW_H := 12.0
const BUTTON_Y := 297.0
const BUTTON_H := 18.0
const BUTTON_W := 94.0
const CONTENT_X := 12.0
const CONTENT_W := 192.0

const FELT := preload("res://assets/ui/panel_felt.png")

var board: BetBoard
var chip_buttons: Dictionary = {}
var per_marble_label: CountLabel
var total_label: CountLabel
var clear_button: Button
var rebet_button: Button


func _ready() -> void:
	size = PANEL_SIZE
	var bg := TextureRect.new()
	bg.texture = FELT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var title := Label.new()
	title.text = "BET_PANEL_TITLE"
	title.theme_type_variation = "LabelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, TITLE_Y)
	title.size = Vector2(PANEL_SIZE.x, 16)
	add_child(title)
	board = BetBoard.new()
	board.position = BOARD_POS
	add_child(board)
	board.tooltip_requested.connect(func(text: String, rect: Rect2) -> void: TooltipLayer.show_tip(board, text, rect))
	board.tooltip_cleared.connect(func() -> void: TooltipLayer.hide_tip(board))
	_build_chip_row()
	_build_amounts()
	_build_buttons()
	EventBus.bets_changed.connect(_refresh)
	EventBus.chips_changed.connect(func(_v: float, _d: float) -> void: _refresh())
	_refresh()


func _build_chip_row() -> void:
	var label := Label.new()
	label.text = "LABEL_CHIP_SIZE"
	label.theme_type_variation = "LabelSmallMuted"
	label.position = Vector2(CONTENT_X, CHIP_ROW_Y + 2)
	label.size = Vector2(CHIP_BUTTON_X - CONTENT_X, 12)
	add_child(label)
	var group := ButtonGroup.new()
	var modes: Array = [[Economy.ChipSize.TENTH, "CHIP_SIZE_TENTH"], [Economy.ChipSize.HALF, "CHIP_SIZE_HALF"], [Economy.ChipSize.MAX, "CHIP_SIZE_MAX"]]
	for i in modes.size():
		var mode: int = modes[i][0]
		var button := Button.new()
		button.text = String(modes[i][1])
		button.theme_type_variation = "ChipButton"
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(CHIP_BUTTON_X + i * (CHIP_BUTTON_W + CHIP_BUTTON_GAP), CHIP_ROW_Y)
		button.size = Vector2(CHIP_BUTTON_W, CHIP_BUTTON_H)
		button.pressed.connect(func() -> void: GameState.set_chip_size_mode(mode))
		add_child(button)
		chip_buttons[mode] = button


func _build_amounts() -> void:
	for row: Array in [["LABEL_PER_MARBLE", 0], ["LABEL_TOTAL_BET", 1]]:
		var label := Label.new()
		label.text = String(row[0])
		label.theme_type_variation = "LabelSmallMuted"
		label.position = Vector2(CONTENT_X, AMOUNT_Y + int(row[1]) * AMOUNT_ROW_H - 2)
		label.size = Vector2(100, 12)
		add_child(label)
	per_marble_label = CountLabel.new()
	total_label = CountLabel.new()
	for i in 2:
		var value := per_marble_label if i == 0 else total_label
		value.theme_type_variation = "Num7Gold"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.position = Vector2(CONTENT_X + 92, AMOUNT_Y + i * AMOUNT_ROW_H + 2)
		value.size = Vector2(100, 7)
		add_child(value)


func _build_buttons() -> void:
	clear_button = Button.new()
	clear_button.text = "BUTTON_CLEAR_BETS"
	clear_button.position = Vector2(CONTENT_X, BUTTON_Y)
	clear_button.size = Vector2(BUTTON_W, BUTTON_H)
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.pressed.connect(_on_clear)
	add_child(clear_button)
	rebet_button = Button.new()
	rebet_button.text = "BUTTON_REPEAT_BETS"
	rebet_button.position = Vector2(CONTENT_X + CONTENT_W - BUTTON_W, BUTTON_Y)
	rebet_button.size = Vector2(BUTTON_W, BUTTON_H)
	rebet_button.focus_mode = Control.FOCUS_NONE
	rebet_button.pressed.connect(_on_rebet)
	add_child(rebet_button)


## 스핀 중에는 베팅을 잠근다.
func set_locked(value: bool) -> void:
	board.locked = value
	_refresh()


func _on_clear() -> void:
	if board.locked:
		AudioManager.play_sfx("deny")
		return
	GameState.clear_bets()


func _on_rebet() -> void:
	if board.locked:
		AudioManager.play_sfx("deny")
		return
	GameState.restore_last_bets()


## 구슬당 실제 베팅액(칩이 모자라면 자동 축소된 값).
func per_marble_amount() -> float:
	var count := maxi(GameState.current_bets.size(), 1)
	var amount := SpinController.affordable_amount(GameState.chip_amount(), GameState.chips, count, GameState.min_bet())
	return amount if amount > 0.0 else GameState.chip_amount()


func is_affordable() -> bool:
	var count := maxi(GameState.current_bets.size(), 1)
	return SpinController.affordable_amount(GameState.chip_amount(), GameState.chips, count, GameState.min_bet()) > 0.0


func _refresh() -> void:
	(chip_buttons[GameState.chip_size_mode] as Button).set_pressed_no_signal(true)
	var per := per_marble_amount()
	var count := GameState.current_bets.size()
	var affordable := is_affordable()
	per_marble_label.theme_type_variation = "Num7Gold" if affordable else "Num7Red"
	total_label.theme_type_variation = "Num7Gold" if affordable else "Num7Red"
	per_marble_label.set_value(per)
	total_label.set_value(per * count)
	clear_button.disabled = count == 0 or board.locked
	rebet_button.disabled = GameState.last_bets.is_empty() or board.locked or _same_as_last()


func _same_as_last() -> bool:
	var last := GameState.last_bets
	var current := GameState.current_bets
	if last.size() != current.size():
		return false
	for i in last.size():
		if not last[i].same_spot(current[i]):
			return false
	return true
