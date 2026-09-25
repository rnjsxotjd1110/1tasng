class_name DebtPanel
extends Control
## 빚 상세 패널(ART_BIBLE 11-5). TopBar 의 빚 표시를 클릭하면 드롭다운으로 열린다.
## 건별 원금·잔액·진행률 바 + [전액 상환][절반 상환].

const SIZE := Vector2(200, 148)
const ROW_HEIGHT := 40.0
const BAR_HEIGHT := 3.0

var _rows_container: VBoxContainer


func _ready() -> void:
	size = SIZE
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.theme_type_variation = "PanelPlain"
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := Label.new()
	title.theme_type_variation = "LabelBold"
	title.text = tr("DEBT_PANEL_TITLE")
	title.position = Vector2(8, 4)
	add_child(title)
	_rows_container = VBoxContainer.new()
	_rows_container.position = Vector2(6, 20)
	_rows_container.size = Vector2(SIZE.x - 12, SIZE.y - 26)
	_rows_container.add_theme_constant_override("separation", 4)
	add_child(_rows_container)
	EventBus.debt_changed.connect(_refresh)
	EventBus.chips_changed.connect(_on_chips_changed)


func open() -> void:
	_refresh()
	if not GameState.has_debt():
		return
	PanelTransition.open(self, Vector2(0, -6))


func close() -> void:
	if visible:
		PanelTransition.close(self, Vector2(0, -6))


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _on_chips_changed(_new_value: float, _delta: float) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	for i in GameState.debts.size():
		_rows_container.add_child(_build_row(i))
	if GameState.debts.is_empty() and visible:
		close()


func _build_row(index: int) -> Control:
	var entry: Dictionary = GameState.debts[index]
	var principal := float(entry["principal"])
	var remaining := float(entry["remaining"])
	var repay_mult := GameState.get_stat(StatModifiers.DEBT_REPAY_MULT, Economy.DEBT_REPAY_FACTOR)
	var ratio := DebtService.progress_ratio([entry], repay_mult)
	var row := VBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var label := Label.new()
	label.theme_type_variation = "LabelSmallMuted"
	label.text = "%s  %s" % [tr("DEBT_PRINCIPAL") % NumberFormat.format(principal), tr("DEBT_REMAINING") % NumberFormat.format(remaining)]
	row.add_child(label)
	var bar_row := Control.new()
	bar_row.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	var bar_bg := ColorRect.new()
	bar_bg.color = Palette.with_alpha(Palette.VOID, 0.6)
	bar_bg.size = Vector2(SIZE.x - 12, BAR_HEIGHT)
	bar_row.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = Palette.SEM_WARNING
	bar.size = Vector2(roundf((SIZE.x - 12) * ratio), BAR_HEIGHT)
	bar_row.add_child(bar)
	row.add_child(bar_row)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	var full_button := Button.new()
	full_button.theme_type_variation = "ButtonGold"
	full_button.text = tr("BUTTON_REPAY_ALL")
	full_button.custom_minimum_size = Vector2(88, 18)
	full_button.disabled = not GameState.can_afford(remaining)
	full_button.pressed.connect(func() -> void: GameState.repay_all(index))
	buttons.add_child(full_button)
	var half_button := Button.new()
	half_button.theme_type_variation = "ButtonGold"
	half_button.text = tr("BUTTON_REPAY_HALF")
	half_button.custom_minimum_size = Vector2(88, 18)
	half_button.disabled = not GameState.can_afford(remaining * 0.5)
	half_button.pressed.connect(func() -> void: GameState.repay_half(index))
	buttons.add_child(half_button)
	row.add_child(buttons)
	return row
