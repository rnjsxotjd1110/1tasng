class_name PauseMenu
extends Control
## 일시정지 메뉴(Esc). 화면 전체를 디더 오버레이로 어둡게 덮고 가운데 메뉴를 띄운다.
## 계속하기/설정/통계 는 신호로 알리고(Main 이 다른 화면을 연다), 게임 종료는 저장 후 직접 종료한다.
## PROCESS_MODE_ALWAYS: "메뉴 중 게임 진행"(SettingsManager.pause_time_flows) 이 꺼져 tree 가 paused 여도 동작해야 한다.

signal resume_requested()
signal settings_requested()
signal stats_requested()
signal achievements_requested()

const SCREEN := Vector2(640, 360)
const PANEL_SIZE := Vector2(150, 222)
const BUTTON_SIZE := Vector2(120, 20)
const BUTTON_GAP := 6

var _dim: ColorRect
var _resume_button: Button
var _time_flows_box: CheckBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.size = SCREEN
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/dither_dim.gdshader")
	_dim.material = material
	add_child(_dim)
	var panel := Panel.new()
	panel.theme_type_variation = "PanelFelt"
	panel.size = PANEL_SIZE
	panel.position = ((SCREEN - PANEL_SIZE) * 0.5).round()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var title := Label.new()
	title.text = "PAUSE_TITLE"
	title.theme_type_variation = "LabelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(PANEL_SIZE.x, 16)
	panel.add_child(title)
	var y := 26.0
	_resume_button = _menu_button(panel, "PAUSE_RESUME", y, func() -> void: resume_requested.emit())
	y += BUTTON_SIZE.y + BUTTON_GAP
	_menu_button(panel, "PAUSE_SETTINGS", y, func() -> void: settings_requested.emit())
	y += BUTTON_SIZE.y + BUTTON_GAP
	_menu_button(panel, "PAUSE_STATS", y, func() -> void: stats_requested.emit())
	y += BUTTON_SIZE.y + BUTTON_GAP
	_menu_button(panel, "PAUSE_ACHIEVEMENTS", y, func() -> void: achievements_requested.emit())
	y += BUTTON_SIZE.y + BUTTON_GAP
	var title_button := _menu_button(panel, "PAUSE_SAVE_AND_TITLE", y, Callable())
	title_button.disabled = true
	title_button.mouse_entered.connect(func() -> void:
		TooltipLayer.show_tip(title_button, tr("PAUSE_TITLE_LOCKED_TIP"), title_button.get_global_rect()))
	title_button.mouse_exited.connect(func() -> void: TooltipLayer.hide_tip(title_button))
	y += BUTTON_SIZE.y + BUTTON_GAP
	_menu_button(panel, "PAUSE_QUIT", y, _on_quit_pressed)
	y += BUTTON_SIZE.y + BUTTON_GAP + 4
	var flow_row := HBoxContainer.new()
	flow_row.position = Vector2(8, y)
	flow_row.add_theme_constant_override("separation", 4)
	panel.add_child(flow_row)
	_time_flows_box = CheckBox.new()
	_time_flows_box.button_pressed = SettingsManager.pause_time_flows
	FocusStyle.apply(_time_flows_box)
	_time_flows_box.toggled.connect(func(v: bool) -> void:
		SettingsManager.pause_time_flows = v
		SettingsManager.save_settings())
	flow_row.add_child(_time_flows_box)
	var flow_label := Label.new()
	flow_label.theme_type_variation = "LabelSmallMuted"
	flow_label.text = "PAUSE_TIME_FLOWS"
	flow_label.custom_minimum_size = Vector2(PANEL_SIZE.x - 30, 0)
	flow_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	flow_row.add_child(flow_label)


func _menu_button(parent: Control, label_key: String, y: float, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = "ButtonDark"
	button.text = label_key
	button.position = Vector2((PANEL_SIZE.x - BUTTON_SIZE.x) * 0.5, y).round()
	button.size = BUTTON_SIZE
	FocusStyle.apply(button)
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _on_quit_pressed() -> void:
	SaveManager.save_game()
	get_tree().quit()


func focus_first() -> void:
	if _resume_button != null:
		_resume_button.grab_focus()


func refresh_time_flows_checkbox() -> void:
	if _time_flows_box != null:
		_time_flows_box.button_pressed = SettingsManager.pause_time_flows


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
