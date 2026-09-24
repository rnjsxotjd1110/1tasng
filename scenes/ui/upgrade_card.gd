class_name UpgradeCard
extends Control
## 업그레이드 카드(ART_BIBLE 9-2). 200×44, 구슬 재질 카드만 200×64.
##   왼쪽: 16×16 아이콘(재질 카드는 회전하며 반짝이는 24px 구슬) · 이름 · Lv · 효과 변화("×1.35 → ×1.82", 다음 값은 초록) · 레벨당 효과
##   오른쪽: 구매 버튼(살 수 있으면 금색, 모자라면 stone 톤 + 아래 부족분 진행 바), 수량 "×37" 과 비용
##   잠김: 실루엣 아이콘 · 자물쇠 · 해금 조건 / 최대 레벨: 금색 테두리 + MAX 스탬프
## 버튼을 누르고 있으면 HOLD_DELAY 뒤부터 점점 빠르게 연속 구매한다. 구매 반응(흰 플래시·아이콘 튐)은 play_bought().

signal buy_requested(card: UpgradeCard)
signal hover_changed(card: UpgradeCard, hovered: bool)

const CARD_W := 200
const CARD_H := 44
const MARBLE_CARD_H := 68
const BUTTON_RECT := Rect2(130, 5, 66, 28)
const MARBLE_BUTTON_RECT := Rect2(130, 19, 66, 28)
const BAR_H := 3
const BAR_GAP := 3
const ICON_SLOT := Rect2(4, 12, 20, 20)
const MARBLE_SLOT := Rect2(4, 4, 34, 34)
const TEXT_X := 28.0
const MARBLE_TEXT_X := 42.0
const NAME_Y := 3.0
const EFFECT_Y := 22.0
const PER_LEVEL_Y := 33.0
const MARBLE_LABEL_Y := 18.0
const MARBLE_EFFECT_Y := 30.0
const STRIP_POS := Vector2(6, 57)
const STRIP_STEP := 8
## 잠김·상한 카드: 자물쇠는 오른쪽 끝, 조건 문구는 그 앞까지 넓게.
const LOCK_RIGHT := 6.0
const LOCK_TEXT_GAP := 4.0
const LEVEL_GAP := 4.0
## 레벨 뒤 레벨당 효과까지 간격.
const PER_LEVEL_GAP := 6.0
const QTY_POS := Vector2(4, 3)
const COST_Y := 12.0
const CHIP_GAP := 2.0
# 구매 반응(ART_BIBLE 6장: 흰 플래시 1프레임 → 아이콘 2px 튐)
const FLASH_FRAMES := 2
const HOP_STEPS: Array[float] = [0.05, 0.1]
const HOP_PX := 2
# 연속 구매
const HOLD_DELAY := 0.4
const HOLD_START_INTERVAL := 0.18
const HOLD_ACCEL := 0.85
const HOLD_MIN_INTERVAL := 0.04

const CHIP_ICON := preload("res://assets/sprites/ui/icon_chip_small.png")
const ARROW := preload("res://assets/sprites/ui/arrow_right.png")
const LOCK := preload("res://assets/sprites/ui/icon_lock_big.png")
const STAMP := preload("res://assets/sprites/ui/stamp_max.png")

var def: UpgradeDef
var is_marble: bool = false
## 패널이 정하는 구매 수량(×1/×10/MAX).
var mode: UpgradeService.BuyMode = UpgradeService.BuyMode.ONE
## 지금 계획(UpgradeService.plan)과 잠금 상태.
var plan: Dictionary = {}
var status: UpgradeService.Status = UpgradeService.Status.OK
## 스크롤 영역(전역). 이 밖에서는 호버를 무시한다.
var clip_rect := Rect2(0, 0, 640, 360)

var bg: Panel
var button: Button
var name_label: Label
var level_label: Label
var now_label: Label
var next_label: Label
var per_level_label: Label
var lock_label: Label
var qty_label: Label
var cost_label: Label
var marble_view: MarbleView

var _slot: Panel
var _icon: TextureRect
var _arrow: TextureRect
var _chip: TextureRect
var _lock_icon: TextureRect
var _stamp: TextureRect
var _fx: Control
var _strip: Control
var _strip_views: Array[MarbleView] = []
var _mult_caption: Label
var _hovered: bool = false
var _flash_frames: int = 0
var _hop_time: float = -1.0
var _holding: bool = false
var _hold_time: float = 0.0
var _hold_next: float = 0.0
var _hold_interval: float = HOLD_START_INTERVAL
var _button_home := Vector2.ZERO
var _icon_home := Vector2.ZERO


func setup(p_def: UpgradeDef) -> void:
	def = p_def
	is_marble = def.kind == UpgradeDef.Kind.MARBLE_TIER


func _ready() -> void:
	size = Vector2(CARD_W, MARBLE_CARD_H if is_marble else CARD_H)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_PASS
	bg = Panel.new()
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_slot = Panel.new()
	_slot.theme_type_variation = "CardSlot"
	var slot_rect := MARBLE_SLOT if is_marble else ICON_SLOT
	_slot.position = slot_rect.position
	_slot.size = slot_rect.size
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot)
	var text_x := MARBLE_TEXT_X if is_marble else TEXT_X
	if is_marble:
		marble_view = MarbleView.new(-1, MarbleSprite.SIZE_CARD, 1)
		marble_view.position = slot_rect.position
		marble_view.size = slot_rect.size
		add_child(marble_view)
		_icon_home = marble_view.position
	else:
		_icon = TextureRect.new()
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_home = slot_rect.position + (slot_rect.size - Vector2(16, 16)) * 0.5
		_icon.position = _icon_home
		add_child(_icon)
	name_label = _label("LabelBold", Vector2(text_x, NAME_Y))
	# 레벨은 재질 카드는 이름 옆, 나머지는 셋째 줄(이름 줄을 넓게 쓰려고)
	level_label = _label("Num7Gold", Vector2(text_x, NAME_Y + 5 if is_marble else PER_LEVEL_Y))
	var effect_y := MARBLE_EFFECT_Y if is_marble else EFFECT_Y
	now_label = _label("Num7Ivory", Vector2(text_x, effect_y))
	_arrow = TextureRect.new()
	_arrow.texture = ARROW
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow)
	next_label = _label("Num7Clover", Vector2(text_x, effect_y))
	per_level_label = _label("Num7Stone", Vector2(text_x, PER_LEVEL_Y))
	lock_label = _label("LabelSmallMuted", Vector2(text_x, effect_y - 3))
	lock_label.clip_text = true
	lock_label.size = Vector2(size.x - LOCK_RIGHT - LOCK.get_width() - LOCK_TEXT_GAP - text_x, 12)
	if is_marble:
		_mult_caption = _label("LabelSmallMuted", Vector2(text_x, MARBLE_LABEL_Y))
		_mult_caption.text = "LABEL_WIN_MULT"
		_build_strip()
	var rect := MARBLE_BUTTON_RECT if is_marble else BUTTON_RECT
	button = Button.new()
	button.theme_type_variation = "ButtonGold"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.position = rect.position
	button.size = rect.size
	add_child(button)
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)
	_button_home = rect.position
	qty_label = Label.new()
	qty_label.theme_type_variation = "Num7Ivory"
	qty_label.position = QTY_POS
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(qty_label)
	_chip = TextureRect.new()
	_chip.texture = CHIP_ICON
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(_chip)
	cost_label = Label.new()
	cost_label.theme_type_variation = "Num14Ivory"
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost_label)
	_lock_icon = TextureRect.new()
	_lock_icon.texture = LOCK
	_lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_icon.position = Vector2(size.x - LOCK_RIGHT - LOCK.get_width(), roundf(rect.position.y + (rect.size.y - LOCK.get_height()) * 0.5))
	add_child(_lock_icon)
	_stamp = TextureRect.new()
	_stamp.texture = STAMP
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.position = (rect.position + (rect.size - Vector2(STAMP.get_size())) * 0.5).round()
	add_child(_stamp)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.size = size
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	refresh()


func _label(variation: String, pos: Vector2) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## 재질 수집 띠: 15종 7px 구슬(가진 것은 재질 그대로, 아직 없는 것은 실루엣).
func _build_strip() -> void:
	_strip = Control.new()
	_strip.position = STRIP_POS
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.draw.connect(_draw_strip)
	add_child(_strip)
	for tier in GameData.marbles().size():
		var view := MarbleView.new(tier, MarbleSprite.SIZE_WHEEL, 1)
		view.spin = 0.0
		view.show_shadow = false
		view.show_aura = false
		view.position = Vector2(tier * STRIP_STEP, 0)
		view.size = Vector2(MarbleSprite.SIZE_WHEEL, MarbleSprite.SIZE_WHEEL)
		_strip.add_child(view)
		_strip_views.append(view)


func _draw_strip() -> void:
	var silhouette := MarbleSprite.halo_texture(MarbleSprite.SIZE_WHEEL, Palette.INK)
	for tier in _strip_views.size():
		if not _strip_views[tier].visible:
			_strip.draw_texture(silhouette, Vector2(tier * STRIP_STEP, 0))


# ── 상태 갱신 ────────────────────────────────────────────

## 칩·레벨·수량이 바뀌면 패널이 부른다.
func refresh() -> void:
	if def == null or bg == null:
		return
	var level := UpgradeService.level_of(def.id)
	status = UpgradeService.lock_status(def)
	plan = UpgradeService.plan(def.id, mode)
	var locked := status == UpgradeService.Status.LOCKED_FLOOR or status == UpgradeService.Status.LOCKED_MARBLE
	var capped := status == UpgradeService.Status.CAPPED_BY_FLOOR
	var maxed := status == UpgradeService.Status.MAX_LEVEL
	var affordable := bool(plan.get("affordable", false))
	# 배경
	if is_marble:
		bg.theme_type_variation = "CardMax" if maxed else "CardMarble"
	elif maxed:
		bg.theme_type_variation = "CardMax"
	elif locked:
		bg.theme_type_variation = "CardLocked"
	elif _hovered:
		bg.theme_type_variation = "CardHover"
	else:
		bg.theme_type_variation = "CardReady" if affordable else "CardNormal"
	# 이름·레벨
	if is_marble:
		var marble := GameState.current_marble()
		name_label.text = tr(marble.name_key) if marble != null else ""
		level_label.text = "%s/%s" % [NumberFormat.format(level + 1), NumberFormat.format(GameData.marbles().size())]
		for tier in _strip_views.size():
			_strip_views[tier].visible = tier <= level
		_strip.queue_redraw()
	else:
		name_label.text = tr(def.name_key)
		level_label.text = tr("LABEL_LEVEL") % NumberFormat.format(level)
		_icon.texture = load(def.icon_path.trim_suffix(".png") + "_locked.png") if locked else def.icon()
	name_label.theme_type_variation = "LabelMuted" if locked else "LabelBold"
	name_label.reset_size()
	level_label.reset_size()
	if is_marble:
		level_label.position.x = name_label.position.x + name_label.get_minimum_size().x + LEVEL_GAP
	level_label.visible = not locked
	# 효과 변화
	var show_effect := not locked
	now_label.visible = show_effect
	var now_value := UpgradeService.display_value(def, level)
	now_label.text = UpgradeService.format_value(def, now_value)
	now_label.theme_type_variation = "Num7Gold" if maxed else "Num7Ivory"
	var show_next := show_effect and not maxed and not capped
	_arrow.visible = show_next
	next_label.visible = show_next
	if show_next:
		var count := maxi(1, int(plan.get("count", 1)))
		next_label.text = UpgradeService.format_value(def, UpgradeService.display_value(def, level + count))
		now_label.reset_size()
		_arrow.position = Vector2(now_label.position.x + now_label.get_minimum_size().x + 2, now_label.position.y + 1)
		next_label.position = Vector2(_arrow.position.x + ARROW.get_width() + 2, now_label.position.y)
	per_level_label.visible = not is_marble and not locked and not maxed
	if per_level_label.visible:
		per_level_label.text = _per_level_text()
		per_level_label.position.x = level_label.position.x + level_label.get_minimum_size().x + PER_LEVEL_GAP
	# 잠김·상한 문구(재질 카드가 전부 모이면 MAX 스탬프와 수집 띠가 대신 말한다)
	lock_label.visible = locked or capped
	if lock_label.visible:
		lock_label.text = _lock_text()
		if is_marble:
			lock_label.position.y = MARBLE_LABEL_Y
			_mult_caption.visible = false
	elif is_marble:
		_mult_caption.visible = true
	if is_marble:
		now_label.visible = true
	# 버튼
	var buyable := not locked and not capped and not maxed
	button.visible = buyable
	_lock_icon.visible = locked or capped
	_stamp.visible = maxed
	if buyable:
		button.theme_type_variation = "ButtonGold" if affordable else "ButtonStone"
		qty_label.text = "×%s" % NumberFormat.format(int(plan.get("count", 1)))
		qty_label.theme_type_variation = "Num7Ivory" if affordable else "Num7Stone"
		cost_label.text = NumberFormat.format(float(plan.get("cost", 0.0)))
		cost_label.theme_type_variation = "Num14Ivory" if affordable else "Num14Stone"
		_layout_button()
	if _icon != null:
		_icon.modulate = Color.WHITE
	_fx.queue_redraw()
	queue_redraw()


func _layout_button() -> void:
	cost_label.reset_size()
	var cost_w := cost_label.get_minimum_size().x
	var total := CHIP_ICON.get_width() + CHIP_GAP + cost_w
	var x := roundf((button.size.x - total) * 0.5)
	var pressed_offset := 1.0 if button.button_pressed or _holding else 0.0
	_chip.position = Vector2(x, COST_Y + 4 + pressed_offset)
	cost_label.position = Vector2(x + CHIP_ICON.get_width() + CHIP_GAP, COST_Y + pressed_offset)
	qty_label.position = QTY_POS + Vector2(0, pressed_offset)


func _per_level_text() -> String:
	var per := def.effect_per_level
	if def.effect_op == StatModifiers.Op.MULT:
		return NumberFormat.format_mult(per) + "/Lv"
	return NumberFormat.format_signed(per) + "/Lv"


func _lock_text() -> String:
	match status:
		UpgradeService.Status.LOCKED_FLOOR:
			return tr("UPGRADE_LOCK_FLOOR") % _floor_name(def.required_floor)
		UpgradeService.Status.LOCKED_MARBLE:
			var marble := GameData.marble(def.required_marble_tier)
			return tr("UPGRADE_LOCK_MARBLE") % (tr(marble.name_key) if marble != null else "")
		UpgradeService.Status.CAPPED_BY_FLOOR:
			var floor_index := UpgradeService.floor_for_marble_tier(UpgradeService.level_of(def.id) + 1)
			return tr("UPGRADE_NEXT_FLOOR") % _floor_name(floor_index)
		UpgradeService.Status.MAX_LEVEL:
			return tr("UPGRADE_ALL_OWNED") if is_marble else tr("TIP_MAX_LEVEL")
	return ""


static func _floor_name(index: int) -> String:
	var floor_def := GameData.floor_def(index) if index >= 0 else null
	return floor_def.id.to_upper() if floor_def != null else "?"


## 툴팁 문장: 이름·설명 / 현재 → 다음(전체 숫자) / 비용(전체 숫자, 수량) / 공식 / 부족분.
func tooltip_text() -> String:
	var lines: Array[String] = []
	lines.append("%s — %s" % [tr(def.name_key), tr(def.desc_key)])
	var level := UpgradeService.level_of(def.id)
	if status == UpgradeService.Status.OK or status == UpgradeService.Status.NOT_ENOUGH_CHIPS:
		var count := maxi(1, int(plan.get("count", 1)))
		if def.effect_stat == StatModifiers.MAX_BET_MULT:
			var now_bet := GameState.max_bet()
			var next_bet := now_bet / def.effect_value(level) * def.effect_value(level + count)
			lines.append(tr("TIP_MAX_BET") % [NumberFormat.format_full(now_bet), NumberFormat.format_full(next_bet)])
		else:
			lines.append(tr("TIP_UPGRADE_VALUES") % [_full_value(UpgradeService.display_value(def, level)), _full_value(UpgradeService.display_value(def, level + count))])
		lines.append(tr("TIP_UPGRADE_COST") % [NumberFormat.format_full(float(plan.get("cost", 0.0))), NumberFormat.format(count)])
		lines.append(_formula_text())
		var mult := UpgradeService.cost_mult()
		if not is_equal_approx(mult, 1.0):
			lines.append(tr("TIP_COST_MULT") % NumberFormat.format_mult(mult))
		var short := float(plan.get("cost", 0.0)) - GameState.chips
		if short > 0.0:
			lines.append(tr("TIP_UPGRADE_SHORT") % NumberFormat.format_full(short))
		else:
			lines.append(tr("TIP_HOLD_TO_BUY"))
	else:
		lines.append(_lock_text())
	return "\n".join(lines)


func _full_value(value: float) -> String:
	if UpgradeService.value_style(def) == UpgradeService.ValueStyle.MULT and value >= 1000.0:
		return NumberFormat.MULT_SIGN + NumberFormat.format_full(value)
	return UpgradeService.format_value(def, value)


func _formula_text() -> String:
	match def.kind:
		UpgradeDef.Kind.MARBLE_TIER:
			return tr("TIP_FORMULA_MARBLE")
		UpgradeDef.Kind.MARBLE_POLISH:
			var marble := GameState.current_marble()
			var ratio := marble.polish_base_cost / marble.cost if marble != null and marble.cost > 0.0 else 0.0
			return tr("TIP_FORMULA_POLISH") % [NumberFormat.format_decimal(ratio), NumberFormat.format_decimal(def.growth)]
	return tr("TIP_FORMULA_GEOMETRIC") % [NumberFormat.format(def.base_cost), NumberFormat.format_decimal(def.growth)]


# ── 입력·연출 ────────────────────────────────────────────

func _on_button_down() -> void:
	_holding = true
	_hold_time = 0.0
	_hold_next = HOLD_DELAY
	_hold_interval = HOLD_START_INTERVAL
	_layout_button()
	buy_requested.emit(self)


func _on_button_up() -> void:
	_holding = false
	_layout_button()


## 연속 구매를 멈춘다(구매 실패·패널 닫힘).
func stop_hold() -> void:
	if _holding:
		_holding = false
		_layout_button()


func is_holding() -> bool:
	return _holding


## 구매 반응: 흰 플래시 1프레임 → 아이콘 2px 튐.
func play_bought() -> void:
	_flash_frames = FLASH_FRAMES
	_hop_time = 0.0
	_fx.queue_redraw()


func is_hovered() -> bool:
	return _hovered


func _process(delta: float) -> void:
	if _holding:
		if not button.visible or not is_visible_in_tree():
			_holding = false
		else:
			_hold_time += delta
			if _hold_time >= _hold_next:
				_hold_next = _hold_time + _hold_interval
				_hold_interval = maxf(HOLD_MIN_INTERVAL, _hold_interval * HOLD_ACCEL)
				buy_requested.emit(self)
	if _flash_frames > 0:
		_flash_frames -= 1
		_fx.queue_redraw()
	if _hop_time >= 0.0:
		_hop_time += delta
		var offset := 0
		if _hop_time < HOP_STEPS[0]:
			offset = HOP_PX
		elif _hop_time < HOP_STEPS[1]:
			offset = HOP_PX / 2
		else:
			_hop_time = -1.0
		var target: Control = marble_view if is_marble else _icon
		target.position = _icon_home - Vector2(0, offset)
	_update_hover()


func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	var inside := is_visible_in_tree() and get_global_rect().has_point(mouse) and clip_rect.has_point(mouse)
	if inside != _hovered:
		_hovered = inside
		hover_changed.emit(self, inside)
		refresh()


## 부족분 진행 바: 버튼 아래(보유 칩 ÷ 비용). 카드 배경 위에 그리도록 앞 층(_fx)에서 그린다.
func _draw_bar() -> void:
	if not button.visible:
		return
	var cost := float(plan.get("cost", 0.0))
	if bool(plan.get("affordable", false)) or cost <= 0.0:
		return
	var rect := MARBLE_BUTTON_RECT if is_marble else BUTTON_RECT
	var bar := Rect2(rect.position.x + 2, rect.end.y + BAR_GAP, rect.size.x - 4, BAR_H)
	_fx.draw_rect(bar, Palette.VOID)
	var fill := clampf(GameState.chips / cost, 0.0, 1.0)
	var width := floorf((bar.size.x - 2) * fill)
	if width > 0.0:
		_fx.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2(width, BAR_H - 2)), Palette.GOLD_L)


func _draw_fx() -> void:
	_draw_bar()
	if _flash_frames > 0:
		_fx.draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Palette.with_alpha(Palette.IVORY, 0.85))
