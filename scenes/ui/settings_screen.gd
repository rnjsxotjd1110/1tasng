class_name SettingsScreen
extends Control
## 설정 화면(4단계). 스킬트리와 같은 자리(640×336, 상단 바 아래 전체)에 여는 오버레이.
## 탭 5개(오디오/화면/게임/접근성/데이터). SettingsManager 의 필드를 직접 읽고 쓴 뒤 commit() 으로 적용+저장한다.

signal close_requested()

const SIZE := Vector2(640, 336)
const TAB_LIST_POS := Vector2(12, 34)
const TAB_LIST_SIZE := Vector2(104, 26)
const TAB_GAP := 2
const CONTENT_POS := Vector2(128, 34)
const CONTENT_SIZE := Vector2(498, 288)
const ROW_SEPARATION := 10
const LABEL_WIDTH := 168.0
const CHOICE_BUTTON_MIN := Vector2(46, 20)
const RESET_HOLD_DURATION := 3.0
const RESET_CONFIRM_WORD := "RESET"
const MAX_TOOLTIP_DELAY := 1.0

const TAB_AUDIO := "audio"
const TAB_SCREEN := "screen"
const TAB_GAME := "game"
const TAB_ACCESSIBILITY := "accessibility"
const TAB_DATA := "data"
const TAB_ORDER: Array[String] = [TAB_AUDIO, TAB_SCREEN, TAB_GAME, TAB_ACCESSIBILITY, TAB_DATA]
const TAB_LABEL_KEYS: Dictionary = {
	TAB_AUDIO: "SETTINGS_TAB_AUDIO", TAB_SCREEN: "SETTINGS_TAB_SCREEN", TAB_GAME: "SETTINGS_TAB_GAME",
	TAB_ACCESSIBILITY: "SETTINGS_TAB_ACCESSIBILITY", TAB_DATA: "SETTINGS_TAB_DATA",
}

var _tab_buttons: Dictionary = {}
var _tab_contents: Dictionary = {}
var _current_tab: String = TAB_AUDIO

var _reset_line_edit: LineEdit
var _reset_button: Button
var _reset_progress: ProgressBar
var _reset_holding: bool = false
var _reset_hold_time: float = 0.0


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.theme_type_variation = "PanelPlain"
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := Label.new()
	title.text = "SETTINGS_TITLE"
	title.theme_type_variation = "LabelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(SIZE.x, 16)
	add_child(title)
	var line := HSeparator.new()
	line.position = Vector2(12, 27)
	line.size = Vector2(SIZE.x - 24, 4)
	add_child(line)
	var close := Button.new()
	close.theme_type_variation = "ButtonDark"
	close.icon = preload("res://assets/sprites/ui/icon_close.png")
	close.size = Vector2(18, 18)
	close.position = Vector2(SIZE.x - 26, 6)
	FocusStyle.apply(close)
	close.pressed.connect(func() -> void: close_requested.emit())
	add_child(close)
	_build_tab_list()
	_build_tabs()
	select_tab(TAB_AUDIO)


func _build_tab_list() -> void:
	var group := ButtonGroup.new()
	for i in TAB_ORDER.size():
		var tab_id: String = TAB_ORDER[i]
		var button := Button.new()
		button.theme_type_variation = "TabButton"
		button.text = String(TAB_LABEL_KEYS[tab_id])
		button.toggle_mode = true
		button.button_group = group
		button.position = TAB_LIST_POS + Vector2(0, i * (TAB_LIST_SIZE.y + TAB_GAP))
		button.size = TAB_LIST_SIZE
		FocusStyle.apply(button)
		button.pressed.connect(func() -> void: select_tab(tab_id))
		add_child(button)
		_tab_buttons[tab_id] = button


func select_tab(tab_id: String) -> void:
	_current_tab = tab_id
	for id: String in _tab_contents.keys():
		(_tab_contents[id] as Control).visible = id == tab_id
	# set_pressed_no_signal 은 ButtonGroup 의 다른 버튼을 풀지 않으므로 직접 맞춘다(TopBar.select_tab 과 같은 이유).
	for id: String in _tab_buttons.keys():
		(_tab_buttons[id] as Button).set_pressed_no_signal(id == tab_id)


func focus_first() -> void:
	if _tab_buttons.has(TAB_AUDIO):
		(_tab_buttons[TAB_AUDIO] as Button).grab_focus()


# ── 탭 컨텐츠 ────────────────────────────────────────────

func _build_tabs() -> void:
	_tab_contents[TAB_AUDIO] = _build_audio_tab()
	_tab_contents[TAB_SCREEN] = _build_screen_tab()
	_tab_contents[TAB_GAME] = _build_game_tab()
	_tab_contents[TAB_ACCESSIBILITY] = _build_accessibility_tab()
	_tab_contents[TAB_DATA] = _build_data_tab()
	for content: Control in _tab_contents.values():
		content.position = CONTENT_POS
		content.size = CONTENT_SIZE
		content.visible = false
		add_child(content)


func _new_list() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_SEPARATION)
	return box


func _add_row(parent: VBoxContainer, label_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.theme_type_variation = "LabelBold"
	label.text = label_key
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	parent.add_child(row)
	return row


func _slider_row(parent: VBoxContainer, label_key: String, initial: float, on_change: Callable,
		on_preview: Callable = Callable(), format_fn: Callable = Callable()) -> HSlider:
	if not format_fn.is_valid():
		format_fn = NumberFormat.format_percent
	var row := _add_row(parent, label_key)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	slider.custom_minimum_size = Vector2(180, 16)
	FocusStyle.apply(slider)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.theme_type_variation = "LabelSmallMuted"
	value_label.custom_minimum_size = Vector2(36, 0)
	value_label.text = String(format_fn.call(initial))
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		value_label.text = String(format_fn.call(v))
		if on_preview.is_valid():
			on_preview.call())
	return slider


func _checkbox_row(parent: VBoxContainer, label_key: String, initial: bool, on_change: Callable) -> CheckBox:
	var row := _add_row(parent, label_key)
	var box := CheckBox.new()
	box.button_pressed = initial
	FocusStyle.apply(box)
	box.toggled.connect(func(v: bool) -> void: on_change.call(v))
	row.add_child(box)
	return box


## options: [[값, 표시_키, 사용가능(bool)], ...]
func _choice_row(parent: VBoxContainer, label_key: String, options: Array, current: Variant, on_change: Callable) -> HBoxContainer:
	var row := _add_row(parent, label_key)
	var group := ButtonGroup.new()
	for option: Array in options:
		var value: Variant = option[0]
		var button := Button.new()
		button.theme_type_variation = "ButtonDark"
		button.text = String(option[1])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = CHOICE_BUTTON_MIN
		button.disabled = option.size() > 2 and not bool(option[2])
		FocusStyle.apply(button)
		button.set_pressed_no_signal(value == current)
		button.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				on_change.call(value))
		row.add_child(button)
	return row


# ── 오디오 ───────────────────────────────────────────────

func _build_audio_tab() -> VBoxContainer:
	var list := _new_list()
	_slider_row(list, "SETTINGS_AUDIO_MASTER", SettingsManager.master_volume,
		func(v: float) -> void: SettingsManager.master_volume = v; SettingsManager.commit(),
		func() -> void: AudioManager.play_sfx("chip_click"))
	_slider_row(list, "SETTINGS_AUDIO_MUSIC", SettingsManager.music_volume,
		func(v: float) -> void: SettingsManager.music_volume = v; SettingsManager.commit())
	_slider_row(list, "SETTINGS_AUDIO_SFX", SettingsManager.sfx_volume,
		func(v: float) -> void: SettingsManager.sfx_volume = v; SettingsManager.commit(),
		func() -> void: AudioManager.play_sfx("chip_click"))
	_slider_row(list, "SETTINGS_AUDIO_UI", SettingsManager.ui_volume,
		func(v: float) -> void: SettingsManager.ui_volume = v; SettingsManager.commit(),
		func() -> void: AudioManager.play_sfx("ui_click"))
	return list


# ── 화면 ─────────────────────────────────────────────────

func _build_screen_tab() -> VBoxContainer:
	var list := _new_list()
	_choice_row(list, "SETTINGS_SCREEN_MODE", [
		[false, "SETTINGS_SCREEN_WINDOWED"], [true, "SETTINGS_SCREEN_FULLSCREEN"],
	], SettingsManager.fullscreen, func(v: bool) -> void: SettingsManager.fullscreen = v; SettingsManager.commit())
	var available := SettingsManager.available_window_scales()
	var scale_options: Array = []
	for scale in SettingsManager.WINDOW_SCALES:
		scale_options.append([scale, NumberFormat.format_mult(float(scale)), available.has(scale)])
	_choice_row(list, "SETTINGS_SCREEN_SCALE", scale_options, SettingsManager.window_scale,
		func(v: int) -> void: SettingsManager.window_scale = v; SettingsManager.commit())
	_checkbox_row(list, "SETTINGS_SCREEN_VSYNC", SettingsManager.vsync,
		func(v: bool) -> void: SettingsManager.vsync = v; SettingsManager.commit())
	var fps_options: Array = []
	for fps in SettingsManager.MAX_FPS_OPTIONS:
		fps_options.append([fps, ("SETTINGS_FPS_UNLIMITED" if fps == 0 else NumberFormat.format(float(fps)))])
	_choice_row(list, "SETTINGS_SCREEN_MAX_FPS", fps_options, SettingsManager.max_fps,
		func(v: int) -> void: SettingsManager.max_fps = v; SettingsManager.commit())
	return list


# ── 게임 ─────────────────────────────────────────────────

func _build_game_tab() -> VBoxContainer:
	var list := _new_list()
	_choice_row(list, "SETTINGS_GAME_LANGUAGE", [
		["ko", "SETTINGS_LANGUAGE_KO"], ["en", "SETTINGS_LANGUAGE_EN"],
	], SettingsManager.language, func(v: String) -> void: SettingsManager.language = v; SettingsManager.commit())
	_choice_row(list, "SETTINGS_GAME_NUMBER_FORMAT", [
		[false, "SETTINGS_NUMBER_ABBREVIATED"], [true, "SETTINGS_NUMBER_SCIENTIFIC"],
	], SettingsManager.scientific_notation, func(v: bool) -> void: SettingsManager.scientific_notation = v; SettingsManager.commit())
	_choice_row(list, "SETTINGS_GAME_SPIN_SPEED", [
		[SettingsManager.SpinVisualSpeed.NORMAL, "SETTINGS_SPEED_NORMAL"],
		[SettingsManager.SpinVisualSpeed.FAST, "SETTINGS_SPEED_FAST"],
		[SettingsManager.SpinVisualSpeed.FASTEST, "SETTINGS_SPEED_FASTEST"],
	], SettingsManager.spin_visual_speed, func(v: int) -> void: SettingsManager.spin_visual_speed = v; SettingsManager.commit())
	_choice_row(list, "SETTINGS_GAME_BIG_WIN", [
		[true, "SETTINGS_BIG_WIN_FULL"], [false, "SETTINGS_BIG_WIN_SIMPLE"],
	], SettingsManager.big_win_effect_full, func(v: bool) -> void: SettingsManager.big_win_effect_full = v; SettingsManager.commit())
	_checkbox_row(list, "SETTINGS_GAME_AUTO_EFFECTS", SettingsManager.auto_spin_effects_reduced,
		func(v: bool) -> void: SettingsManager.auto_spin_effects_reduced = v; SettingsManager.commit())
	return list


# ── 접근성 ───────────────────────────────────────────────

func _build_accessibility_tab() -> VBoxContainer:
	var list := _new_list()
	_checkbox_row(list, "SETTINGS_A11Y_SCREEN_SHAKE_OFF", not SettingsManager.screen_shake,
		func(v: bool) -> void: SettingsManager.screen_shake = not v; SettingsManager.commit())
	_checkbox_row(list, "SETTINGS_A11Y_REDUCE_FLASHING", SettingsManager.reduce_flashing,
		func(v: bool) -> void: SettingsManager.reduce_flashing = v; SettingsManager.commit())
	_checkbox_row(list, "SETTINGS_A11Y_COLORBLIND", SettingsManager.colorblind_assist,
		func(v: bool) -> void: SettingsManager.colorblind_assist = v; SettingsManager.commit())
	_slider_row(list, "SETTINGS_A11Y_TOOLTIP_DELAY", SettingsManager.tooltip_delay / MAX_TOOLTIP_DELAY,
		func(v: float) -> void: SettingsManager.tooltip_delay = v * MAX_TOOLTIP_DELAY; SettingsManager.commit(),
		Callable(), func(ratio: float) -> String: return NumberFormat.format_seconds(ratio * MAX_TOOLTIP_DELAY))
	return list


# ── 데이터 ───────────────────────────────────────────────

func _build_data_tab() -> VBoxContainer:
	var list := _new_list()
	var open_row := _add_row(list, "SETTINGS_DATA_OPEN_FOLDER")
	var open_button := Button.new()
	open_button.theme_type_variation = "ButtonDark"
	open_button.text = "SETTINGS_DATA_OPEN_FOLDER_BUTTON"
	FocusStyle.apply(open_button)
	open_button.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path("user://")))
	open_row.add_child(open_button)

	var reset_label := Label.new()
	reset_label.theme_type_variation = "LabelBold"
	reset_label.text = "SETTINGS_DATA_RESET"
	list.add_child(reset_label)
	var reset_hint := Label.new()
	reset_hint.theme_type_variation = "LabelSmallMuted"
	reset_hint.auto_translate = false
	reset_hint.text = tr("SETTINGS_DATA_RESET_HINT") % RESET_CONFIRM_WORD
	list.add_child(reset_hint)
	var reset_row := HBoxContainer.new()
	reset_row.add_theme_constant_override("separation", 8)
	_reset_line_edit = LineEdit.new()
	_reset_line_edit.placeholder_text = RESET_CONFIRM_WORD
	_reset_line_edit.custom_minimum_size = Vector2(100, 20)
	FocusStyle.apply(_reset_line_edit)
	_reset_line_edit.text_changed.connect(func(_t: String) -> void: _refresh_reset_enabled())
	reset_row.add_child(_reset_line_edit)
	_reset_button = Button.new()
	_reset_button.theme_type_variation = "ButtonDark"
	_reset_button.text = "SETTINGS_DATA_RESET_BUTTON"
	_reset_button.disabled = true
	FocusStyle.apply(_reset_button)
	_reset_button.button_down.connect(_on_reset_button_down)
	_reset_button.button_up.connect(_on_reset_button_up)
	reset_row.add_child(_reset_button)
	list.add_child(reset_row)
	_reset_progress = ProgressBar.new()
	_reset_progress.min_value = 0.0
	_reset_progress.max_value = 1.0
	_reset_progress.value = 0.0
	_reset_progress.show_percentage = false
	_reset_progress.custom_minimum_size = Vector2(200, 8)
	list.add_child(_reset_progress)
	return list


func _refresh_reset_enabled() -> void:
	if _reset_button != null and _reset_line_edit != null:
		_reset_button.disabled = _reset_line_edit.text != RESET_CONFIRM_WORD


func _on_reset_button_down() -> void:
	if _reset_button.disabled:
		return
	_reset_holding = true
	_reset_hold_time = 0.0


func _on_reset_button_up() -> void:
	_reset_holding = false
	_reset_hold_time = 0.0
	if _reset_progress != null:
		_reset_progress.value = 0.0


func _process(delta: float) -> void:
	if not _reset_holding:
		return
	_reset_hold_time += delta
	_reset_progress.value = clampf(_reset_hold_time / RESET_HOLD_DURATION, 0.0, 1.0)
	if _reset_hold_time >= RESET_HOLD_DURATION:
		_reset_holding = false
		_reset_progress.value = 0.0
		_perform_reset()


func _perform_reset() -> void:
	for path in [SaveManager.SAVE_PATH, SaveManager.TMP_PATH, SaveManager.BAK_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	GameState.reset()
	RngService.randomize_seed()
	_reset_line_edit.text = ""
	_refresh_reset_enabled()
	EventBus.toast_requested.emit(tr("TOAST_DATA_RESET"), "warning")
	close_requested.emit()
