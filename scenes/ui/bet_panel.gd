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
var strategy_dropdown: OptionButton

var _title_label: Label

## 스마트 베팅(M6) 전략 목록과 각 항목의 표시 키. 드롭다운 순서 = 이 배열 순서.
const STRATEGY_ORDER: Array[int] = [
	GameState.SmartBettingStrategy.KEEP, GameState.SmartBettingStrategy.STABLE,
	GameState.SmartBettingStrategy.AGGRESSIVE, GameState.SmartBettingStrategy.HOT_NUMBERS,
	GameState.SmartBettingStrategy.MARTINGALE,
]
const STRATEGY_LABEL_KEY := {
	GameState.SmartBettingStrategy.KEEP: "STRATEGY_KEEP",
	GameState.SmartBettingStrategy.STABLE: "STRATEGY_STABLE",
	GameState.SmartBettingStrategy.AGGRESSIVE: "STRATEGY_AGGRESSIVE",
	GameState.SmartBettingStrategy.HOT_NUMBERS: "STRATEGY_HOT_NUMBERS",
	GameState.SmartBettingStrategy.MARTINGALE: "STRATEGY_MARTINGALE",
}


func _ready() -> void:
	size = PANEL_SIZE
	var bg := TextureRect.new()
	bg.texture = FELT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_title_label = Label.new()
	_title_label.text = "BET_PANEL_TITLE"
	_title_label.theme_type_variation = "LabelTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, TITLE_Y)
	_title_label.size = Vector2(PANEL_SIZE.x, 16)
	add_child(_title_label)
	strategy_dropdown = OptionButton.new()
	strategy_dropdown.theme_type_variation = "ButtonDark"
	strategy_dropdown.position = Vector2(CONTENT_X, TITLE_Y - 2)
	strategy_dropdown.size = Vector2(CONTENT_W, 18)
	strategy_dropdown.focus_mode = Control.FOCUS_NONE
	strategy_dropdown.visible = false
	for strategy: int in STRATEGY_ORDER:
		strategy_dropdown.add_item(tr(STRATEGY_LABEL_KEY[strategy]))
	strategy_dropdown.item_selected.connect(_on_strategy_selected)
	add_child(strategy_dropdown)
	var piggy_bank := PiggyBankWidget.new()
	piggy_bank.position = Vector2(PANEL_SIZE.x - 24.0, 6.0)
	add_child(piggy_bank)
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
	EventBus.skill_purchased.connect(func(_id: String, _l: int) -> void: refresh_smart_betting_unlock())
	refresh_smart_betting_unlock()
	_refresh()


## 스마트 베팅(M6) 해금 여부에 따라 제목 대신 전략 드롭다운을 보여준다.
func refresh_smart_betting_unlock() -> void:
	var unlocked := SkillService.has_feature("smart_betting")
	strategy_dropdown.visible = unlocked
	_title_label.visible = not unlocked
	if unlocked:
		strategy_dropdown.select(STRATEGY_ORDER.find(GameState.smart_betting_strategy))


func _on_strategy_selected(index: int) -> void:
	GameState.smart_betting_strategy = STRATEGY_ORDER[index]


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
