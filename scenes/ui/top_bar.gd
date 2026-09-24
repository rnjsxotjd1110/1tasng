class_name TopBar
extends Control
## 상단 바(y 0~23, ART_BIBLE 1장).
##   왼쪽: 금 칩 아이콘(가장자리 반짝임) · 보유 칩(큰 숫자, 카운트업) · 초당 수익(최근 60초 이동평균)
##   가운데: 층 이름
##   오른쪽: 클로버 · 빚(5단계, 숨김) · 탭 [베팅][업그레이드][스킬트리][⚙]
## 당첨 연출 중에는 hold_payout() 으로 칩 표시를 멈추고, 칩 아이콘이 날아올 때마다 add_payout_step() 으로 올린다.

signal tab_pressed(tab_id: String)
signal debt_clicked()

const TAB_BET := "bet"
const TAB_UPGRADE := "upgrade"
const TAB_SKILLS := "skills"
const TAB_SETTINGS := "settings"

const BAR_SIZE := Vector2(640, 24)
const CHIP_ICON_POS := Vector2(5, 5)
const CHIP_LABEL_POS := Vector2(21, 1)
const INCOME_LABEL_POS := Vector2(22, 15)
const FLOOR_CENTER_X := 262.0
const FLOOR_LABEL_Y := 5.0
const FLOOR_LABEL_WIDTH := 180.0
const RIGHT_BOX_RIGHT := 636.0
const RIGHT_BOX_Y := 3.0
const RIGHT_BOX_HEIGHT := 18.0
const INCOME_REFRESH := 0.5
const SPARKLE_INTERVAL := 2.6
const SPARKLE_FRAME_TIME := 0.07
const SPARKLE_FRAMES := 4
const SHAKE_TIME := 0.35
const SHAKE_PX := 2
const SPEND_DURATION := 0.25
## 저장 중 표시(4단계): 구석에 칩 아이콘이 0.8초 동안 돈다.
const SAVE_ICON_POS := Vector2(BAR_SIZE.x - 11.0, 2.0)
const SAVE_ICON_DURATION := 0.8
const SAVE_ICON_SPIN_SPEED := TAU * 3.0

const CHIP_ICON := preload("res://assets/sprites/ui/icon_chip.png")
const CLOVER_ICON := preload("res://assets/sprites/ui/icon_clover.png")
const DEBT_ICON := preload("res://assets/sprites/ui/icon_debt.png")
const DEBT_PULSE_SPEED := 2.6
const DEBT_BAR_HEIGHT := 1.0
const GEAR_ICON := preload("res://assets/sprites/ui/icon_gear.png")
const LOCK_ICON := preload("res://assets/sprites/ui/icon_lock.png")
const NOTIFY_DOT := preload("res://assets/sprites/ui/notify_dot.png")
## 스킬트리 탭 자물쇠 해제 연출(6단계): 버튼이 금색으로 잠깐 밝아진다.
const SKILL_LOCK_GLOW_TIME := 1.0
const SKILL_LOCK_GLOW_COLOR := Color(1.6, 1.4, 0.6)
## 업그레이드 탭 빨간 점: 탭 오른쪽 위 모서리, 은은한 맥동(알파만).
const DOT_OFFSET := Vector2(-6, 1)
const DOT_PULSE_SPEED := 3.2
const DOT_ALPHA_MIN := 0.45
const SPARKLE := preload("res://assets/sprites/ui/sparkle.png")

var chips_label: CountLabel
var income_label: CountLabel
var clover_label: CountLabel
var floor_label: Label
var debt_box: HBoxContainer
var tab_buttons: Dictionary = {}

var _income := IncomeTracker.new()
var _income_timer: float = 0.0
var _holding: bool = false
var _sparkle_timer: float = 1.0
var _sparkle_frame: int = -1
var _sparkle_pos := Vector2.ZERO
var _chip_icon: TextureRect
var _sparkle_node: Control
var _shake_left: float = 0.0
var _chips_home := CHIP_LABEL_POS
var _dot: TextureRect
var _dot_time: float = 0.0
var _upgrade_open: bool = false
var _save_icon: TextureRect
var _save_icon_time: float = -1.0
var _debt_label: Label
var _debt_pulse_time: float = 0.0
var _debt_bar_bg: ColorRect
var _debt_bar: ColorRect
var _skill_lock: TextureRect
var _skill_lock_glow_time: float = -1.0
var _wof_ring: Control


func _ready() -> void:
	size = BAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.theme_type_variation = "PanelBar"
	bg.size = BAR_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_chip_icon = TextureRect.new()
	_chip_icon.texture = CHIP_ICON
	_chip_icon.position = CHIP_ICON_POS
	_chip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chip_icon)
	_sparkle_node = Control.new()
	_sparkle_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkle_node.draw.connect(_draw_sparkle)
	add_child(_sparkle_node)
	chips_label = CountLabel.new()
	chips_label.theme_type_variation = "Num14Gold"
	chips_label.position = CHIP_LABEL_POS
	add_child(chips_label)
	income_label = CountLabel.new()
	income_label.theme_type_variation = "Num7Stone"
	income_label.style = CountLabel.Style.PER_SECOND
	income_label.position = INCOME_LABEL_POS
	add_child(income_label)
	floor_label = Label.new()
	floor_label.theme_type_variation = "LabelBold"
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.position = Vector2(FLOOR_CENTER_X - FLOOR_LABEL_WIDTH * 0.5, FLOOR_LABEL_Y)
	floor_label.size = Vector2(FLOOR_LABEL_WIDTH, 14)
	add_child(floor_label)
	_save_icon = TextureRect.new()
	_save_icon.texture = CHIP_ICON
	_save_icon.position = SAVE_ICON_POS
	_save_icon.pivot_offset = CHIP_ICON.get_size() * 0.5
	_save_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_icon.visible = false
	add_child(_save_icon)
	_build_right()
	_debt_bar_bg = ColorRect.new()
	_debt_bar_bg.color = Palette.with_alpha(Palette.VOID, 0.6)
	_debt_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debt_bar_bg.visible = false
	add_child(_debt_bar_bg)
	_debt_bar = ColorRect.new()
	_debt_bar.color = Palette.SEM_WARNING
	_debt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debt_bar.visible = false
	add_child(_debt_bar)
	chips_label.set_value(GameState.chips, 0.0)
	clover_label.set_value(GameState.clovers, 0.0)
	income_label.set_value(0.0, 0.0)
	_refresh_floor()
	_refresh_debt()
	EventBus.chips_changed.connect(_on_chips_changed)
	EventBus.clovers_changed.connect(_on_clovers_changed)
	EventBus.spin_resolved.connect(_on_spin_resolved)
	EventBus.debt_changed.connect(_refresh_debt)
	EventBus.floor_changed.connect(func(_i: int) -> void:
		_refresh_floor()
		refresh_upgrade_dot())
	EventBus.upgrade_purchased.connect(func(_id: String, _l: int) -> void: refresh_upgrade_dot())
	EventBus.save_started.connect(_on_save_started)
	EventBus.first_clover_earned.connect(break_skill_lock)
	refresh_upgrade_dot()


## 첫 클로버 해금(6단계): 자물쇠가 사라지고 스킬트리 탭이 잠깐 금색으로 빛난다.
func break_skill_lock() -> void:
	if _skill_lock == null or not _skill_lock.visible:
		return
	_skill_lock.visible = false
	_skill_lock_glow_time = 0.0
	AudioManager.play_sfx("lock_break")


func _on_save_started() -> void:
	_save_icon_time = 0.0
	_save_icon.visible = true
	_save_icon.rotation = 0.0


func _build_right() -> void:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	box.size = Vector2(300, RIGHT_BOX_HEIGHT)
	box.position = Vector2(RIGHT_BOX_RIGHT - 300, RIGHT_BOX_Y)
	add_child(box)
	var clover_icon := TextureRect.new()
	clover_icon.texture = CLOVER_ICON
	clover_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	clover_icon.custom_minimum_size = Vector2(11, RIGHT_BOX_HEIGHT)
	box.add_child(clover_icon)
	_wof_ring = Control.new()
	_wof_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wof_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wof_ring.draw.connect(_draw_wof_ring)
	clover_icon.add_child(_wof_ring)
	clover_label = CountLabel.new()
	clover_label.theme_type_variation = "Num14Clover"
	clover_label.custom_minimum_size = Vector2(0, RIGHT_BOX_HEIGHT)
	clover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(clover_label)
	# 빚 표시(5단계): 빨간 두루마리 아이콘 + 남은 금액, 빚이 있을 때만 보이고 은은히 맥동한다.
	debt_box = HBoxContainer.new()
	debt_box.add_theme_constant_override("separation", 2)
	debt_box.mouse_filter = Control.MOUSE_FILTER_STOP
	debt_box.custom_minimum_size = Vector2(0, RIGHT_BOX_HEIGHT)
	debt_box.gui_input.connect(_on_debt_box_input)
	debt_box.visible = false
	var debt_icon := TextureRect.new()
	debt_icon.texture = DEBT_ICON
	debt_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	debt_box.add_child(debt_icon)
	_debt_label = Label.new()
	_debt_label.theme_type_variation = "Num7Red"
	_debt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debt_box.add_child(_debt_label)
	box.add_child(debt_box)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(6, 0)
	box.add_child(spacer)
	var group := ButtonGroup.new()
	for tab: Array in [[TAB_BET, "TAB_BET"], [TAB_UPGRADE, "TAB_UPGRADE"], [TAB_SKILLS, "TAB_SKILLS"], [TAB_SETTINGS, ""]]:
		var button := Button.new()
		button.theme_type_variation = "TabButton"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, RIGHT_BOX_HEIGHT)
		var id := String(tab[0])
		if id == TAB_SETTINGS:
			button.icon = GEAR_ICON
			button.tooltip_text = ""
			button.custom_minimum_size = Vector2(20, RIGHT_BOX_HEIGHT)
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			button.text = String(tab[1])
		if id == TAB_BET or id == TAB_UPGRADE:
			button.toggle_mode = true
			button.button_group = group
		button.pressed.connect(func() -> void: tab_pressed.emit(id))
		box.add_child(button)
		tab_buttons[id] = button
		if id == TAB_SKILLS:
			_skill_lock = TextureRect.new()
			_skill_lock.texture = LOCK_ICON
			_skill_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_skill_lock.visible = not GameState.first_clover_seen
			button.add_child(_skill_lock)
	(tab_buttons[TAB_BET] as Button).set_pressed_no_signal(true)
	_dot = TextureRect.new()
	_dot.texture = NOTIFY_DOT
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = false
	(tab_buttons[TAB_UPGRADE] as Button).add_child(_dot)


## 업그레이드창이 열려 있으면 빨간 점을 숨긴다.
func set_upgrade_tab_open(open: bool) -> void:
	_upgrade_open = open
	refresh_upgrade_dot()


## 살 수 있는 업그레이드가 있으면 업그레이드 탭에 빨간 점.
func refresh_upgrade_dot() -> void:
	if _dot != null:
		_dot.visible = not _upgrade_open and UpgradeService.any_affordable()


func upgrade_dot_visible() -> bool:
	return _dot != null and _dot.visible


func select_tab(id: String) -> void:
	if not tab_buttons.has(id) or not (tab_buttons[id] as Button).toggle_mode:
		return
	# set_pressed_no_signal 은 ButtonGroup 의 다른 버튼을 풀지 않으므로 직접 맞춘다.
	for other_id: String in tab_buttons.keys():
		var button := tab_buttons[other_id] as Button
		if button.toggle_mode:
			button.set_pressed_no_signal(other_id == id)


func _refresh_floor() -> void:
	var floor_def := GameState.current_floor()
	floor_label.text = tr(floor_def.name_key) if floor_def != null else ""


# ── 칩 ───────────────────────────────────────────────────

## 칩 아이콘 중심(전역 좌표). 날아오는 칩의 목적지.
func chip_target() -> Vector2:
	return global_position + CHIP_ICON_POS + Vector2(6, 6)


func clover_target() -> Vector2:
	return clover_label.get_global_rect().get_center() - Vector2(12, 0)


## 두루마리(빚) 아이콘 중심(전역). 상환분이 날아가는 목적지.
func debt_target() -> Vector2:
	return debt_box.get_global_rect().position + Vector2(6, RIGHT_BOX_HEIGHT * 0.5)


## 운명의 휠(6단계, Y14) 등장까지 남은 시간: 클로버 아이콘 둘레에 얇은 링으로 채워진다.
func _draw_wof_ring() -> void:
	if not SkillService.has_feature("wheel_of_fortune"):
		return
	var progress := GameState.wheel_of_fortune_progress()
	var center := (_wof_ring.size * 0.5).round()
	_wof_ring.draw_arc(center, 6.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 20, Palette.NEON_PURPLE, 1.0)


func _refresh_debt() -> void:
	var total := GameState.debt_total()
	debt_box.visible = total > 0.0
	if debt_box.visible:
		_debt_label.text = NumberFormat.format(total)


func _on_debt_box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		debt_clicked.emit()


## 당첨 칩이 날아오는 동안 칩 증가를 표시하지 않는다.
func hold_payout() -> void:
	_holding = true


## 날아온 칩 하나만큼 표시를 올리고 1px 튄다.
func add_payout_step(amount: float) -> void:
	chips_label.set_value(minf(chips_label.value + amount, GameState.chips), CountLabel.DEFAULT_DURATION)
	chips_label.bump()


## 붙잡아 둔 표시를 실제 값으로 맞춘다.
func release_payout(duration: float = -1.0) -> void:
	_holding = false
	chips_label.set_value(GameState.chips, duration)


## 칩 부족: 빨갛게 1회 흔들림.
func shake_chips() -> void:
	_shake_left = SHAKE_TIME
	chips_label.theme_type_variation = "Num14Red"
	AudioManager.play_sfx("deny")


func _on_chips_changed(new_value: float, delta: float) -> void:
	refresh_upgrade_dot()
	if delta < 0.0:
		chips_label.set_value(chips_label.value + delta if _holding else new_value, SPEND_DURATION)
	elif not _holding:
		chips_label.set_value(new_value)


func _on_clovers_changed(new_value: int, delta: int) -> void:
	clover_label.set_value(new_value)
	if delta > 0:
		clover_label.bump()


func _on_spin_resolved(outcome: SpinOutcome) -> void:
	_income.add(_now(), outcome.net)
	_refresh_income()


func _refresh_income() -> void:
	var per_second := _income.per_second(_now())
	income_label.theme_type_variation = "Num7Gold" if per_second > 0.0 else "Num7Stone"
	income_label.set_value(per_second)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	if debt_box.visible:
		_debt_pulse_time += delta
		debt_box.modulate.a = 0.75 + 0.25 * sin(_debt_pulse_time * DEBT_PULSE_SPEED)
		# debt_box 는 box(HBoxContainer) 의 자식이라 get_rect() 는 box 기준 로컬 좌표라 그대로 쓰면
		# self(TopBar) 기준으로 잘못된 위치에 그려진다 — 전역 좌표 차이로 self 로컬 좌표를 구한다
		# (Control 은 Node2D 가 아니라 to_local() 이 없다 — 회전·스케일 없는 UI 이므로 뺄셈으로 충분하다).
		var local_x := debt_box.get_global_rect().position.x - get_global_rect().position.x
		var rect := Rect2(Vector2(local_x, 0.0), debt_box.get_rect().size)
		var ratio := DebtService.progress_ratio(GameState.debts, GameState.get_stat(StatModifiers.DEBT_REPAY_MULT, Economy.DEBT_REPAY_FACTOR))
		_debt_bar_bg.position = Vector2(rect.position.x, BAR_SIZE.y)
		_debt_bar_bg.size = Vector2(rect.size.x, DEBT_BAR_HEIGHT)
		_debt_bar_bg.visible = true
		_debt_bar.position = _debt_bar_bg.position
		_debt_bar.size = Vector2(roundf(rect.size.x * ratio), DEBT_BAR_HEIGHT)
		_debt_bar.visible = true
	else:
		_debt_bar_bg.visible = false
		_debt_bar.visible = false
	if _save_icon_time >= 0.0:
		_save_icon_time += delta
		_save_icon.rotation += SAVE_ICON_SPIN_SPEED * delta
		if _save_icon_time >= SAVE_ICON_DURATION:
			_save_icon_time = -1.0
			_save_icon.visible = false
	if _dot != null and _dot.visible:
		_dot_time += delta
		var button := tab_buttons[TAB_UPGRADE] as Button
		_dot.position = Vector2(button.size.x, 0) + DOT_OFFSET
		_dot.modulate.a = lerpf(DOT_ALPHA_MIN, 1.0, 0.5 + 0.5 * sin(_dot_time * DOT_PULSE_SPEED))
	if _skill_lock != null:
		var skill_button := tab_buttons[TAB_SKILLS] as Button
		_skill_lock.position = ((skill_button.size - _skill_lock.texture.get_size()) * 0.5).round()
		if _skill_lock_glow_time >= 0.0:
			_skill_lock_glow_time += delta
			var t := _skill_lock_glow_time / SKILL_LOCK_GLOW_TIME
			if t >= 1.0:
				_skill_lock_glow_time = -1.0
				skill_button.modulate = Color.WHITE
			else:
				skill_button.modulate = SKILL_LOCK_GLOW_COLOR.lerp(Color.WHITE, t)
	if _wof_ring != null and SkillService.has_feature("wheel_of_fortune"):
		_wof_ring.queue_redraw()
	_income_timer += delta
	if _income_timer >= INCOME_REFRESH:
		_income_timer = 0.0
		_refresh_income()
	if _shake_left > 0.0:
		_shake_left -= delta
		if _shake_left <= 0.0:
			chips_label.position = _chips_home
			chips_label.theme_type_variation = "Num14Gold"
		else:
			var step := int(_shake_left / 0.05) % 2
			chips_label.position = _chips_home + Vector2(SHAKE_PX if step == 0 else -SHAKE_PX, 0)
	_sparkle_timer -= delta
	if _sparkle_timer <= 0.0:
		if _sparkle_frame < 0:
			_sparkle_frame = 0
			var angle := RngService.randf_range_misc(-PI, 0.0)
			_sparkle_pos = (CHIP_ICON_POS + Vector2(6, 6) + Vector2(cos(angle), sin(angle)) * 6.0 - Vector2(2, 2)).round()
		else:
			_sparkle_frame += 1
		_sparkle_timer = SPARKLE_FRAME_TIME
		if _sparkle_frame >= SPARKLE_FRAMES:
			_sparkle_frame = -1
			_sparkle_timer = SPARKLE_INTERVAL
		_sparkle_node.queue_redraw()


func _draw_sparkle() -> void:
	if _sparkle_frame >= 0:
		_sparkle_node.draw_texture_rect_region(SPARKLE, Rect2(_sparkle_pos, Vector2(5, 5)), Rect2(_sparkle_frame * 5, 0, 5, 5))
