class_name TitleScreen
extends Control
## 타이틀 화면(8단계 1/N). 비 내리는 밤의 카지노 외관 + 네온 로고 + 메뉴.
## "이어하기" 는 SaveManager.load_game() 을 부르지 않는다 — Main._ready() 가 이미 항상 부르므로
## 여기서는 씬만 바꾼다(이중 로드 방지). "새 게임" 은 기존 저장을 지우고 GameState 를 리셋한 뒤
## 인트로 컷신을 보여주고 넘어간다(그래야 Main 이 지운 상태를 다시 불러오지 않는다).

const SCREEN := Vector2(640, 360)
const BG := preload("res://assets/sprites/title/bg_wall.png")
const WHEEL_ICON_SHEET := preload("res://assets/sprites/title/wheel_icon.png")
const WHEEL_ICON_FRAME := 16
const WHEEL_ICON_FRAMES := 8
const WHEEL_ICON_FRAME_TIME := 0.16
const WHEEL_ICON_CENTER := Vector2(320, 150)
const SIGNBOARD_CENTER_X := 320.0
const SIGNBOARD_Y := 100.0
const MENU_PANEL_POS := Vector2(456, 92)
const MENU_PANEL_SIZE := Vector2(150, 192)
const MENU_BUTTON_SIZE := Vector2(120, 20)
const MENU_BUTTON_GAP := 4
const CHIP_CURSOR_SIZE := Vector2(13, 13)
const CHIP_CURSOR_GAP := 4.0
const CHIP_CURSOR_MOVE_TIME := 0.22
const CHIP_CURSOR_ROLL_FRAME_TIME := 0.05
const CONFIRM_SIZE := Vector2(220, 100)
const RAIN_COUNT := 90
const RAIN_AREA := Rect2(-20, -20, 680, 380)
const RAIN_SPEED_MIN := 220.0
const RAIN_SPEED_MAX := 340.0
const RAIN_DRIFT := -24.0
const RAIN_LENGTH_MIN := 6.0
const RAIN_LENGTH_MAX := 12.0
const LIGHTNING_MIN := 6.0
const LIGHTNING_MAX := 15.0
const LIGHTNING_FLASH_ALPHA := 0.5
const MAIN_SCENE := "res://scenes/main/Main.tscn"

var _continue_button: Button
var _new_game_button: Button
var _continue_summary: Label
var _menu_buttons: Array[Button] = []
var _chip_cursor: TextureRect
var _chip_cursor_tween: Tween
var _chip_cursor_roll_time: float = 0.0
var _chip_cursor_frame: int = 0
var _new_game_confirm: Panel
var _rain: _RainLayer
var _lightning: ColorRect
var _lightning_timer: float
var _wheel_icon: TextureRect
var _wheel_icon_time: float = 0.0
var _wheel_icon_frame: int = 0
var _neon_logo: NeonText
var _settings_overlay: SettingsScreen
var _achievement_overlay: AchievementScreen
var _credits_overlay: CreditsScreen
var _intro: IntroCutscene


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_lightning_timer = randf_range(LIGHTNING_MIN, LIGHTNING_MAX)
	_build_background()
	_build_marquee()
	_build_menu()
	_build_overlays()
	AudioManager.play_music("bgm_title")


func _build_background() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Palette.VOID
	backdrop.size = SCREEN
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var wall := TextureRect.new()
	wall.texture = BG
	wall.size = SCREEN
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall)
	_rain = _RainLayer.new()
	add_child(_rain)
	_lightning = ColorRect.new()
	_lightning.color = Palette.IVORY
	_lightning.size = SCREEN
	_lightning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightning.modulate.a = 0.0
	add_child(_lightning)


func _build_marquee() -> void:
	_neon_logo = NeonText.new()
	_neon_logo.atlas = load("res://assets/sprites/fx/neon_pink.png")
	add_child(_neon_logo)  # _glow 자식은 NeonText._ready() 가 만든다 — set_text_value() 보다 먼저 트리에 넣어야 한다.
	_neon_logo.set_text_value("HOUSE EDGE", false)
	_neon_logo.position = Vector2(roundf(SIGNBOARD_CENTER_X - _neon_logo.text_width() / 2.0), SIGNBOARD_Y)
	_neon_logo.flicker_on()
	_neon_logo.idle_flicker = true
	_wheel_icon = TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = WHEEL_ICON_SHEET
	atlas.region = Rect2(0, 0, WHEEL_ICON_FRAME, WHEEL_ICON_FRAME)
	_wheel_icon.texture = atlas
	_wheel_icon.size = Vector2(WHEEL_ICON_FRAME, WHEEL_ICON_FRAME)
	_wheel_icon.position = (WHEEL_ICON_CENTER - _wheel_icon.size / 2.0).round()
	_wheel_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wheel_icon)


func _build_menu() -> void:
	var panel := Panel.new()
	panel.theme_type_variation = "PanelFelt"
	panel.position = MENU_PANEL_POS
	panel.size = MENU_PANEL_SIZE
	add_child(panel)
	var y := 8.0
	var has_save := SaveManager.has_save()
	_continue_button = _menu_button(panel, "TITLE_CONTINUE", y, _on_continue_pressed)
	_continue_button.disabled = not has_save
	y += MENU_BUTTON_SIZE.y
	_continue_summary = Label.new()
	_continue_summary.theme_type_variation = "LabelSmallMuted"
	_continue_summary.position = Vector2(6, y)
	_continue_summary.size = Vector2(MENU_PANEL_SIZE.x - 12, 20)
	_continue_summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	_continue_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_summary.text = _summary_text() if has_save else ""
	panel.add_child(_continue_summary)
	y += 22.0 + MENU_BUTTON_GAP
	_new_game_button = _menu_button(panel, "TITLE_NEW_GAME", y, _on_new_game_pressed)
	y += MENU_BUTTON_SIZE.y + MENU_BUTTON_GAP
	_menu_button(panel, "TITLE_SETTINGS", y, func() -> void: _toggle_overlay(_settings_overlay))
	y += MENU_BUTTON_SIZE.y + MENU_BUTTON_GAP
	_menu_button(panel, "TITLE_ACHIEVEMENTS", y, func() -> void: _toggle_overlay(_achievement_overlay))
	y += MENU_BUTTON_SIZE.y + MENU_BUTTON_GAP
	_menu_button(panel, "TITLE_CREDITS", y, func() -> void: _toggle_overlay(_credits_overlay))
	y += MENU_BUTTON_SIZE.y + MENU_BUTTON_GAP
	_menu_button(panel, "TITLE_QUIT", y, func() -> void: get_tree().quit())
	_chip_cursor = TextureRect.new()
	_chip_cursor.texture = preload("res://assets/sprites/ui/coin.png")
	_chip_cursor.size = CHIP_CURSOR_SIZE
	_chip_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chip_cursor)
	_move_cursor_to(_continue_button if has_save else _new_game_button, true)
	(_continue_button if has_save else _new_game_button).grab_focus()
	_build_new_game_confirm()


func _menu_button(parent: Control, label_key: String, y: float, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = "ButtonDark"
	button.text = label_key
	button.position = Vector2((MENU_PANEL_SIZE.x - MENU_BUTTON_SIZE.x) * 0.5, y).round()
	button.size = MENU_BUTTON_SIZE
	FocusStyle.apply(button)
	button.pressed.connect(on_pressed)
	button.focus_entered.connect(_move_cursor_to.bind(button, false))
	button.mouse_entered.connect(_move_cursor_to.bind(button, false))
	parent.add_child(button)
	_menu_buttons.append(button)
	return button


func _summary_text() -> String:
	var summary := SaveManager.peek_summary()
	if summary.is_empty():
		return ""
	var floor_def := GameData.floor_def(int(summary.get("floor_index", 0)))
	var floor_name := tr(floor_def.name_key) if floor_def != null else ""
	var chips := float(summary.get("chips", 0.0))
	var play_time := float(summary.get("play_time", 0.0))
	var hours := int(play_time) / 3600
	var minutes := (int(play_time) / 60) % 60
	var duration := tr("DURATION_HOURS_MINUTES") % [NumberFormat.format(float(hours)), NumberFormat.format(float(minutes))]
	return tr("TITLE_CONTINUE_SUMMARY") % [floor_name, NumberFormat.format(chips), tr("CURRENCY_CHIPS"), duration]


func _move_cursor_to(button: Button, instant: bool) -> void:
	var parent := button.get_parent() as Control
	var target := parent.position + button.position + Vector2(-CHIP_CURSOR_GAP - CHIP_CURSOR_SIZE.x, (MENU_BUTTON_SIZE.y - CHIP_CURSOR_SIZE.y) * 0.5)
	if instant:
		_chip_cursor.position = target.round()
		return
	if _chip_cursor_tween != null and _chip_cursor_tween.is_valid():
		_chip_cursor_tween.kill()
	_chip_cursor_tween = create_tween()
	_chip_cursor_tween.tween_property(_chip_cursor, "position", target.round(), CHIP_CURSOR_MOVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_new_game_confirm() -> void:
	_new_game_confirm = Panel.new()
	_new_game_confirm.theme_type_variation = "PanelPlain"
	_new_game_confirm.size = CONFIRM_SIZE
	_new_game_confirm.position = ((SCREEN - CONFIRM_SIZE) * 0.5).round()
	_new_game_confirm.visible = false
	add_child(_new_game_confirm)
	var title := Label.new()
	title.theme_type_variation = "LabelBold"
	title.text = "TITLE_NEW_GAME_CONFIRM_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(8, 10)
	title.size = Vector2(CONFIRM_SIZE.x - 16, 14)
	_new_game_confirm.add_child(title)
	var body := Label.new()
	body.theme_type_variation = "LabelSmallMuted"
	body.text = "TITLE_NEW_GAME_CONFIRM_BODY"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.position = Vector2(8, 30)
	body.size = Vector2(CONFIRM_SIZE.x - 16, 30)
	_new_game_confirm.add_child(body)
	var yes := Button.new()
	yes.theme_type_variation = "ButtonGold"
	yes.text = "TITLE_NEW_GAME_CONFIRM_YES"
	yes.size = Vector2(90, 22)
	yes.position = Vector2(14, CONFIRM_SIZE.y - 30)
	FocusStyle.apply(yes)
	yes.pressed.connect(_start_new_game)
	_new_game_confirm.add_child(yes)
	var no := Button.new()
	no.theme_type_variation = "ButtonDark"
	no.text = "TITLE_NEW_GAME_CONFIRM_NO"
	no.size = Vector2(90, 22)
	no.position = Vector2(CONFIRM_SIZE.x - 104, CONFIRM_SIZE.y - 30)
	FocusStyle.apply(no)
	no.pressed.connect(func() -> void: _new_game_confirm.visible = false)
	_new_game_confirm.add_child(no)


func _build_overlays() -> void:
	_settings_overlay = SettingsScreen.new()
	_settings_overlay.position = Vector2(0, 24)
	_settings_overlay.visible = false
	_settings_overlay.close_requested.connect(func() -> void: _settings_overlay.visible = false)
	add_child(_settings_overlay)
	_achievement_overlay = AchievementScreen.new()
	_achievement_overlay.position = Vector2(0, 24)
	_achievement_overlay.visible = false
	_achievement_overlay.close_requested.connect(func() -> void: _achievement_overlay.visible = false)
	add_child(_achievement_overlay)
	_credits_overlay = CreditsScreen.new()
	_credits_overlay.position = Vector2(0, 24)
	_credits_overlay.visible = false
	_credits_overlay.close_requested.connect(func() -> void: _credits_overlay.visible = false)
	add_child(_credits_overlay)
	add_child(TooltipLayer.new())


func _toggle_overlay(overlay: Control) -> void:
	overlay.visible = true
	if overlay.has_method("refresh"):
		overlay.call("refresh")


func _on_continue_pressed() -> void:
	if not SaveManager.has_save():
		return
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		_new_game_confirm.visible = true
		return
	_start_new_game()


func _start_new_game() -> void:
	_new_game_confirm.visible = false
	SaveManager.delete_save()
	GameState.reset()
	_intro = IntroCutscene.new()
	_intro.finished.connect(func() -> void: get_tree().change_scene_to_file(MAIN_SCENE))
	add_child(_intro)
	_intro.play()


func _process(delta: float) -> void:
	_wheel_icon_time += delta
	while _wheel_icon_time >= WHEEL_ICON_FRAME_TIME:
		_wheel_icon_time -= WHEEL_ICON_FRAME_TIME
		_wheel_icon_frame = (_wheel_icon_frame + 1) % WHEEL_ICON_FRAMES
		(_wheel_icon.texture as AtlasTexture).region = Rect2(_wheel_icon_frame * WHEEL_ICON_FRAME, 0, WHEEL_ICON_FRAME, WHEEL_ICON_FRAME)
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(LIGHTNING_MIN, LIGHTNING_MAX)
		_strike_lightning()


func _strike_lightning() -> void:
	var alpha := VisualSettings.flash_alpha(LIGHTNING_FLASH_ALPHA)
	var tween := create_tween()
	tween.tween_property(_lightning, "modulate:a", alpha, 0.03)
	tween.tween_property(_lightning, "modulate:a", 0.0, 0.09)
	tween.tween_interval(0.06)
	tween.tween_property(_lightning, "modulate:a", alpha * 0.6, 0.02)
	tween.tween_property(_lightning, "modulate:a", 0.0, 0.12)


## 비 내리는 배경(순수 연출, 절차적 — 텍스처 없이 짧은 세로 선을 그린다).
class _RainLayer extends Node2D:
	var _drops: Array[Dictionary] = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in RAIN_COUNT:
			_drops.append({
				"pos": Vector2(rng.randf_range(RAIN_AREA.position.x, RAIN_AREA.end.x), rng.randf_range(RAIN_AREA.position.y, RAIN_AREA.end.y)),
				"speed": rng.randf_range(RAIN_SPEED_MIN, RAIN_SPEED_MAX),
				"len": rng.randf_range(RAIN_LENGTH_MIN, RAIN_LENGTH_MAX),
			})

	func _process(delta: float) -> void:
		for drop in _drops:
			var pos: Vector2 = drop["pos"]
			pos.y += float(drop["speed"]) * delta
			pos.x += RAIN_DRIFT * delta
			if pos.y > RAIN_AREA.end.y:
				pos.y = RAIN_AREA.position.y
				pos.x = randf_range(RAIN_AREA.position.x, RAIN_AREA.end.x)
			drop["pos"] = pos
		queue_redraw()

	func _draw() -> void:
		for drop in _drops:
			var pos: Vector2 = drop["pos"]
			var length: float = drop["len"]
			var tail := pos + Vector2(RAIN_DRIFT * 0.05, -length)
			draw_line(pos.round(), tail.round(), Palette.with_alpha(Palette.MIST, 0.35), 1.0)
