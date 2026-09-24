class_name FloorConfirmPopup
extends Control
## 엘리베이터 확인 팝업(7단계, ART_BIBLE 12장): 다음 층 썸네일(강조색 스와치)·비용·얻는 것(배율·클로버 +10·새 기능).

signal confirmed()

const SIZE := Vector2(220, 150)
const SWATCH_SIZE := Vector2(48, 48)
const SWATCH_POS := Vector2(12, 30)

var _title: Label
var _swatch: ColorRect
var _swatch_border: ColorRect
var _cost_label: Label
var _reward_label: Label
var _feature_label: Label
var _confirm_button: Button


func _ready() -> void:
	size = SIZE
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.theme_type_variation = "PanelPlain"
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_title = Label.new()
	_title.theme_type_variation = "LabelTitle"
	_title.position = Vector2(0, 6)
	_title.size = Vector2(SIZE.x, 16)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_swatch_border = ColorRect.new()
	_swatch_border.position = SWATCH_POS - Vector2(2, 2)
	_swatch_border.size = SWATCH_SIZE + Vector2(4, 4)
	add_child(_swatch_border)
	_swatch = ColorRect.new()
	_swatch.position = SWATCH_POS
	_swatch.size = SWATCH_SIZE
	add_child(_swatch)
	var info := VBoxContainer.new()
	info.position = Vector2(70, 30)
	info.size = Vector2(SIZE.x - 78, 90)
	info.add_theme_constant_override("separation", 4)
	add_child(info)
	_cost_label = _row(info, "LabelGold")
	_reward_label = _row(info, "LabelSmall")
	_feature_label = _row(info, "LabelClover")
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(0, SIZE.y - 28)
	buttons.size = Vector2(SIZE.x, 22)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	add_child(buttons)
	var cancel := Button.new()
	cancel.theme_type_variation = "ButtonDark"
	cancel.text = tr("BUTTON_CANCEL")
	cancel.custom_minimum_size = Vector2(80, 20)
	FocusStyle.apply(cancel)
	cancel.pressed.connect(close)
	buttons.add_child(cancel)
	_confirm_button = Button.new()
	_confirm_button.theme_type_variation = "ButtonGold"
	_confirm_button.text = tr("BUTTON_MOVE_UP")
	_confirm_button.custom_minimum_size = Vector2(80, 20)
	FocusStyle.apply(_confirm_button)
	_confirm_button.pressed.connect(_on_confirm)
	buttons.add_child(_confirm_button)


func _row(parent: VBoxContainer, variation: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(label)
	return label


func open() -> void:
	var next_def := FloorService.next_floor_def()
	if next_def == null:
		return
	_title.text = tr(next_def.name_key)
	var accent := FloorTheme.primary(next_def.id)
	_swatch.color = accent
	_swatch_border.color = Palette.with_alpha(accent, 0.5)
	_cost_label.text = tr("FLOOR_CONFIRM_COST") % NumberFormat.format(next_def.cost)
	_reward_label.text = tr("FLOOR_CONFIRM_PAYOUT") % NumberFormat.format_mult(next_def.payout_mult)
	_feature_label.text = tr("FLOOR_CONFIRM_CLOVER") % NumberFormat.format(float(next_def.clover_reward))
	_confirm_button.disabled = not FloorService.can_move()
	PanelTransition.open(self)


func close() -> void:
	if visible:
		PanelTransition.close(self)


func _on_confirm() -> void:
	if not FloorService.can_move():
		return
	close()
	confirmed.emit()
