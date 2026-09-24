class_name BuffBar
extends Control
## 버프 바(6단계): 상단 바 바로 아래 한 줄에 켜져 있는 시간제/횟수제 효과를 아이콘 + 원형 게이지로 보여준다.
## 새 스프라이트를 만들지 않고 팔레트 색으로 직접 그린다(글리프 하나 + 링 하나, ART_BIBLE 규칙 "9-slice 아닌 것은
## 직접 좌표 배치"). 항목을 손으로 추가할 때는 ENTRIES 에 한 줄만 더하면 된다.

const POS := Vector2(4, 25)
const ICON_SIZE := 12.0
const GAP := 3.0

## source_id → {color, glyph, desc}. glyph 는 draw_* 로 그릴 아주 단순한 모양 id.
const ENTRIES: Array[Dictionary] = [
	{"source": "buff:fever", "glyph": "star", "desc": "BUFF_FEVER_DESC"},
	{"source": "buff:jackpot_chain", "glyph": "bolt", "desc": "BUFF_JACKPOT_CHAIN_DESC"},
	{"source": "buff:golden_storm", "glyph": "circle", "desc": "BUFF_GOLDEN_STORM_DESC"},
	{"source": "buff:wheel_marble_up", "glyph": "gem", "desc": "BUFF_MARBLE_BOOST_DESC"},
]

var _hover_index: int = -1


func _ready() -> void:
	position = POS
	size = Vector2(200, ICON_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)
	GameState.modifiers.changed.connect(func(_stat: String) -> void: queue_redraw())
	EventBus.buff_started.connect(func(_id: String, _d: float) -> void: queue_redraw())
	EventBus.buff_ended.connect(func(_id: String) -> void: queue_redraw())


func _process(_delta: float) -> void:
	if _active_entries().size() > 0:
		queue_redraw()


func _active_entries() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for entry in ENTRIES:
		var source := String(entry["source"])
		if source == "buff:golden_storm":
			if GameState.golden_storm_spins_left > 0:
				active.append(entry)
			continue
		if GameState.modifiers.has_source(source):
			active.append(entry)
	return active


func _draw() -> void:
	var active := _active_entries()
	for i in active.size():
		var entry := active[i]
		var cx := i * (ICON_SIZE + GAP) + ICON_SIZE * 0.5
		var center := Vector2(cx, ICON_SIZE * 0.5)
		var source := String(entry["source"])
		draw_circle(center, ICON_SIZE * 0.5, Palette.with_alpha(Palette.VOID, 0.85))
		_draw_glyph(center, String(entry["glyph"]))
		var ratio := _progress_ratio(source)
		if ratio >= 0.0:
			draw_arc(center, ICON_SIZE * 0.5 - 0.5, -PI * 0.5, -PI * 0.5 + TAU * ratio, 20, Palette.CLOVER, 1.5)


func _draw_glyph(center: Vector2, glyph: String) -> void:
	match glyph:
		"star":
			var hue := fmod(Time.get_ticks_msec() / 600.0, 1.0)
			draw_circle(center, 3.5, Color.from_hsv(hue, 0.8, 1.0))
		"bolt":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(1, -4), center + Vector2(-2, 0.5), center + Vector2(0, 0.5),
				center + Vector2(-1, 4), center + Vector2(2, -0.5), center + Vector2(0, -0.5),
			]), Palette.GOLD_HL)
		"circle":
			draw_circle(center, 3.5, Palette.GOLD_HL)
		"gem":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -4), center + Vector2(3, 0), center + Vector2(0, 4), center + Vector2(-3, 0),
			]), Palette.NEON_CYAN)


## source 의 진행도(0=막 시작, 1=곧 끝). 시간제면 remaining/duration, 횟수제면 알 수 없어 -1(게이지 생략).
func _progress_ratio(source: String) -> float:
	if source == "buff:golden_storm":
		return -1.0
	for modifier in GameState.modifiers.get_modifiers():
		if modifier.source_id == source and modifier.is_timed():
			return clampf(modifier.remaining / modifier.duration, 0.0, 1.0)
	return -1.0


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var active := _active_entries()
	var index := int((event as InputEventMouseMotion).position.x / (ICON_SIZE + GAP))
	if index < 0 or index >= active.size():
		if _hover_index != -1:
			_hover_index = -1
			TooltipLayer.hide_tip(self)
		return
	if index != _hover_index:
		_hover_index = index
		var cx := index * (ICON_SIZE + GAP)
		var rect := Rect2(global_position + Vector2(cx, 0), Vector2(ICON_SIZE, ICON_SIZE))
		TooltipLayer.show_tip(self, tr(String(active[index]["desc"])), rect)


func _on_mouse_exited() -> void:
	TooltipLayer.hide_tip(self)
