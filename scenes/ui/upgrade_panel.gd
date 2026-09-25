class_name UpgradePanel
extends Control
## 오른쪽 업그레이드창(216×328, ART_BIBLE 9-2). 베팅창과 Tab·상단 탭으로 전환한다.
##   제목 · 구매 수량 토글(×1 / ×10 / MAX) · 카드 목록(정수 픽셀 부드러운 스크롤 + 얇은 레일)
## 구매는 UpgradeService 로만 하고, 반응(플래시·튐·코인음 피치 상승)은 여기서 연출한다.

signal purchased(id: String, count: int)

const PANEL_SIZE := Vector2(216, 328)
const TITLE_Y := 8.0
const MODE_ROW_Y := 27.0
const MODE_BUTTON_W := 34.0
const MODE_BUTTON_H := 16.0
const MODE_GAP := 1.0
const CONTENT_X := 12.0
const VIEW_RECT := Rect2(7, 47, 200, 274)
const CARD_GAP := 3
const RAIL_X := 208.0
const RAIL_W := 3.0
const WHEEL_STEP := 22.0
const SCROLL_SMOOTH := 18.0
## 연속 구매 코인음: 구매마다 피치 +PITCH_STEP, COMBO_RESET 초 쉬면 처음으로.
const PITCH_STEP := 0.05
const PITCH_MAX := 1.7
const COMBO_RESET := 0.9

var mode: UpgradeService.BuyMode = UpgradeService.BuyMode.ONE
var cards: Array[UpgradeCard] = []
var mode_buttons: Dictionary = {}
var auto_toggle: Button
var auto_slider: HSlider

var _title_label: Label
var _view: Control
var _content: Control
var _scroll: float = 0.0
var _target: float = 0.0
var _combo: int = 0
var _since_buy: float = 99.0
var _dragging_rail: bool = false
var _drag_offset: float = 0.0


func _ready() -> void:
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Panel.new()
	bg.size = PANEL_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_title_label = Label.new()
	_title_label.text = "UPGRADE_PANEL_TITLE"
	_title_label.theme_type_variation = "LabelTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, TITLE_Y)
	_title_label.size = Vector2(PANEL_SIZE.x, 16)
	add_child(_title_label)
	_build_auto_row()
	_build_mode_row()
	_view = Control.new()
	_view.position = VIEW_RECT.position
	_view.size = VIEW_RECT.size
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_view)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.add_child(_content)
	var y := 0.0
	for def in UpgradeService.sorted_defs():
		var card := UpgradeCard.new()
		card.setup(def)
		card.position = Vector2(0, y)
		_content.add_child(card)
		card.buy_requested.connect(_on_buy_requested)
		card.hover_changed.connect(_on_card_hover)
		cards.append(card)
		y += card.size.y + CARD_GAP
	_content.size = Vector2(VIEW_RECT.size.x, y - CARD_GAP)
	EventBus.chips_changed.connect(func(_v: float, _d: float) -> void: refresh())
	EventBus.upgrade_purchased.connect(func(_id: String, _l: int) -> void: refresh())
	EventBus.floor_changed.connect(func(_i: int) -> void: refresh())
	EventBus.skill_purchased.connect(func(_id: String, _l: int) -> void: refresh_auto_upgrade_unlock())
	visibility_changed.connect(_on_visibility_changed)
	refresh_auto_upgrade_unlock()


## 오토 업그레이드(M7) 해금 여부에 따라 제목 대신 토글+예산 슬라이더를 보여준다.
func _build_auto_row() -> void:
	auto_toggle = Button.new()
	auto_toggle.text = "BUTTON_AUTO"
	auto_toggle.theme_type_variation = "ButtonDark"
	auto_toggle.toggle_mode = true
	auto_toggle.focus_mode = Control.FOCUS_NONE
	auto_toggle.position = Vector2(CONTENT_X, TITLE_Y - 2)
	auto_toggle.size = Vector2(40, 18)
	auto_toggle.visible = false
	auto_toggle.toggled.connect(func(on: bool) -> void: GameState.auto_upgrade_enabled = on)
	add_child(auto_toggle)
	auto_slider = HSlider.new()
	auto_slider.min_value = 0.1
	auto_slider.max_value = 1.0
	auto_slider.step = 0.1
	auto_slider.position = Vector2(CONTENT_X + 44, TITLE_Y + 2)
	auto_slider.size = Vector2(PANEL_SIZE.x - CONTENT_X * 2 - 44, 12)
	auto_slider.visible = false
	auto_slider.value_changed.connect(func(v: float) -> void: GameState.auto_upgrade_ratio = v)
	add_child(auto_slider)


func refresh_auto_upgrade_unlock() -> void:
	var unlocked := SkillService.has_feature("auto_upgrade")
	auto_toggle.visible = unlocked
	auto_slider.visible = unlocked
	_title_label.visible = not unlocked
	if unlocked:
		auto_toggle.set_pressed_no_signal(GameState.auto_upgrade_enabled)
		auto_slider.set_value_no_signal(GameState.auto_upgrade_ratio)
	_select_mode(mode)


func _build_mode_row() -> void:
	var label := Label.new()
	label.text = "LABEL_BUY_AMOUNT"
	label.theme_type_variation = "LabelSmallMuted"
	label.position = Vector2(CONTENT_X, MODE_ROW_Y + 2)
	add_child(label)
	var group := ButtonGroup.new()
	var modes: Array = [[UpgradeService.BuyMode.ONE, "BUY_X1"], [UpgradeService.BuyMode.TEN, "BUY_X10"], [UpgradeService.BuyMode.MAX, "BUY_MAX"]]
	var x0 := PANEL_SIZE.x - CONTENT_X - modes.size() * MODE_BUTTON_W - (modes.size() - 1) * MODE_GAP
	for i in modes.size():
		var buy_mode: UpgradeService.BuyMode = modes[i][0]
		var button := Button.new()
		button.text = String(modes[i][1])
		button.theme_type_variation = "ChipButton"
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(x0 + i * (MODE_BUTTON_W + MODE_GAP), MODE_ROW_Y)
		button.size = Vector2(MODE_BUTTON_W, MODE_BUTTON_H)
		button.pressed.connect(func() -> void: _select_mode(buy_mode))
		add_child(button)
		mode_buttons[buy_mode] = button


func _select_mode(buy_mode: UpgradeService.BuyMode) -> void:
	mode = buy_mode
	(mode_buttons[mode] as Button).set_pressed_no_signal(true)
	for other: int in mode_buttons.keys():
		(mode_buttons[other] as Button).set_pressed_no_signal(other == mode)
	refresh()


## 구매 수량을 바꾼다(테스트·캡처용).
func set_mode(buy_mode: UpgradeService.BuyMode) -> void:
	_select_mode(buy_mode)


func refresh() -> void:
	var clip := Rect2(_view.global_position, _view.size) if _view != null else Rect2()
	for card in cards:
		card.mode = mode
		card.clip_rect = clip
		card.refresh()


func card(id: String) -> UpgradeCard:
	for c in cards:
		if c.def.id == id:
			return c
	return null


## 카드 하나를 산다(버튼·연속 구매). 성공하면 반응 연출.
func buy(target: UpgradeCard) -> int:
	var count := UpgradeService.purchase(target.def.id, mode)
	if count <= 0:
		target.stop_hold()
		AudioManager.play_sfx("deny")
		return 0
	_combo = _combo + 1 if _since_buy < COMBO_RESET else 0
	_since_buy = 0.0
	AudioManager.play_sfx("buy_coin", minf(PITCH_MAX, 1.0 + PITCH_STEP * _combo))
	target.play_bought()
	purchased.emit(target.def.id, count)
	if target.is_hovered():
		_show_tip(target)
	return count


func _on_buy_requested(target: UpgradeCard) -> void:
	buy(target)


func _on_card_hover(target: UpgradeCard, hovered: bool) -> void:
	if hovered:
		_show_tip(target)
	else:
		TooltipLayer.hide_tip(target)


func _show_tip(target: UpgradeCard) -> void:
	TooltipLayer.show_tip(target, target.tooltip_text(), target.get_global_rect())


func _on_visibility_changed() -> void:
	if not visible:
		for c in cards:
			c.stop_hold()
			TooltipLayer.hide_tip(c)


# ── 스크롤 ───────────────────────────────────────────────

func max_scroll() -> float:
	return maxf(0.0, _content.size.y - VIEW_RECT.size.y)


func scroll_to(value: float, instant: bool = false) -> void:
	_target = clampf(value, 0.0, max_scroll())
	if instant:
		_scroll = _target
		_apply_scroll()


func scroll_value() -> float:
	return _scroll


func _apply_scroll() -> void:
	_content.position.y = -roundf(_scroll)
	queue_redraw()
	refresh_clip()


func refresh_clip() -> void:
	var clip := Rect2(_view.global_position, _view.size)
	for c in cards:
		c.clip_rect = clip


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_to(_target + WHEEL_STEP)
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_to(_target - WHEEL_STEP)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and _rail_rect().grow(2).has_point(button.position):
				_dragging_rail = true
				var thumb := _thumb_rect()
				_drag_offset = button.position.y - thumb.position.y if thumb.has_point(button.position) else thumb.size.y * 0.5
				_drag_to(button.position.y)
				accept_event()
			elif not button.pressed:
				_dragging_rail = false
	elif event is InputEventMouseMotion and _dragging_rail:
		_drag_to((event as InputEventMouseMotion).position.y)
		accept_event()


func _drag_to(y: float) -> void:
	var rail := _rail_rect()
	var thumb := _thumb_rect()
	var travel := rail.size.y - thumb.size.y
	if travel <= 0.0:
		return
	var u := clampf((y - _drag_offset - rail.position.y) / travel, 0.0, 1.0)
	scroll_to(u * max_scroll(), true)


func _process(delta: float) -> void:
	_since_buy += delta
	if absf(_scroll - _target) > 0.01:
		_scroll = lerpf(_scroll, _target, 1.0 - exp(-SCROLL_SMOOTH * delta))
		if absf(_scroll - _target) < 0.5:
			_scroll = _target
		_apply_scroll()


func _rail_rect() -> Rect2:
	return Rect2(RAIL_X, VIEW_RECT.position.y, RAIL_W, VIEW_RECT.size.y)


func _thumb_rect() -> Rect2:
	var rail := _rail_rect()
	if max_scroll() <= 0.0:
		return rail
	var ratio := VIEW_RECT.size.y / _content.size.y
	var height := maxf(12.0, roundf(rail.size.y * ratio))
	var y := rail.position.y + roundf((rail.size.y - height) * (_scroll / max_scroll()))
	return Rect2(rail.position.x, y, rail.size.x, height)


func _draw() -> void:
	if max_scroll() <= 0.0:
		return
	var rail := _rail_rect()
	draw_rect(rail, Palette.VOID)
	var thumb := _thumb_rect()
	draw_rect(thumb, Palette.GOLD_D)
	draw_rect(Rect2(thumb.position, Vector2(thumb.size.x - 1, thumb.size.y - 1)), Palette.GOLD_L if not _dragging_rail else Palette.GOLD_HL)
