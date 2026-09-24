class_name PenaltyToast
extends Control
## 패널티 발동 알림(ART_BIBLE 11-6): 상단 중앙, 아이콘 + 이름 + 남은시간 바 + 남작 미니 초상화.
## EventBus.penalty_triggered(id, duration) 로 뜨고, EventBus.buff_ended(id) 로 소모·만료 시 즉시 닫힌다
## (즉시·소모형 패널티는 buff_ended 가 늦게 오거나 안 올 수 있어 duration 만큼 지나면 스스로도 닫는다).

const SIZE := Vector2(160, 24)
const CENTER_X := 262.0
const TOP := 28.0
const GAP := 3.0
const SLIDE := 0.15
const BAR_HEIGHT := 2.0

const NAME_KEYS := {
	"watcher": "PENALTY_WATCHER", "pickpocket": "PENALTY_PICKPOCKET", "smoke": "PENALTY_SMOKE",
	"blur": "PENALTY_BLUR", "seize_marble": "PENALTY_SEIZE", "clover_fee": "PENALTY_CLOVER_FEE",
}
const ICON_PATHS := {
	"watcher": "res://assets/sprites/ui/icon_penalty_watcher.png",
	"pickpocket": "res://assets/sprites/ui/icon_penalty_pickpocket.png",
	"smoke": "res://assets/sprites/ui/icon_penalty_smoke.png",
	"blur": "res://assets/sprites/ui/icon_penalty_blur.png",
	"seize_marble": "res://assets/sprites/ui/icon_penalty_seize.png",
	"clover_fee": "res://assets/sprites/ui/icon_clover.png",
}
const BARON_MINI := preload("res://assets/sprites/ui/icon_baron_mini.png")

var _active: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 360)
	EventBus.penalty_triggered.connect(_on_triggered)
	EventBus.buff_ended.connect(_on_ended)


func _on_triggered(id: String, duration: float) -> void:
	if not NAME_KEYS.has(id):
		return
	if _active.has(id):
		_remove(id)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PanelPlain"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = SIZE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)
	var baron_icon := TextureRect.new()
	baron_icon.texture = BARON_MINI
	baron_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(baron_icon)
	var name_label := Label.new()
	name_label.theme_type_variation = "LabelSmall"
	name_label.text = tr(String(NAME_KEYS[id]))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var effect_icon := TextureRect.new()
	effect_icon.texture = load(String(ICON_PATHS[id]))
	effect_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(effect_icon)
	add_child(panel)
	# bar_bg/bar 는 panel(PanelContainer) 의 자식으로 넣지 않는다 — Container 는 직계 자식을
	# 전부 같은 콘텐츠 영역에 맞춰 강제로 늘리므로(원래 한 자식만 쓰는 게 정상 용법이라, margin
	# 과 함께 넣으면 얇은 2px 바가 패널 전체 크기로 늘어나 버린다). 대신 self(plain Control)
	# 의 자식으로 두고 panel 위치를 따라가게 _process() 에서 수동으로 배치한다
	# (TopBar._debt_bar 가 debt_box 를 따라가는 것과 같은 방식).
	var bar_bg := ColorRect.new()
	bar_bg.color = Palette.with_alpha(Palette.VOID, 0.6)
	bar_bg.size = Vector2(SIZE.x, BAR_HEIGHT)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = Palette.SEM_WARNING
	bar.size = Vector2(SIZE.x, BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	panel.modulate.a = 0.0
	_active[id] = {"node": panel, "bar": bar, "bar_bg": bar_bg, "time": 0.0, "duration": maxf(duration, 0.1)}


func _on_ended(id: String) -> void:
	if _active.has(id):
		_remove(id)


func _remove(id: String) -> void:
	var entry: Dictionary = _active[id]
	(entry["node"] as Control).queue_free()
	(entry["bar"] as Control).queue_free()
	(entry["bar_bg"] as Control).queue_free()
	_active.erase(id)


func active_ids() -> Array:
	return _active.keys()


func _process(delta: float) -> void:
	var y := TOP
	var expired: Array[String] = []
	for id: String in _active.keys():
		var entry: Dictionary = _active[id]
		entry["time"] = float(entry["time"]) + delta
		var t: float = entry["time"]
		var duration: float = entry["duration"]
		var node: Control = entry["node"]
		var bar: ColorRect = entry["bar"]
		var bar_bg: ColorRect = entry["bar_bg"]
		var slide := clampf(t / SLIDE, 0.0, 1.0)
		node.position = Vector2(roundf(CENTER_X - SIZE.x * 0.5), roundf(y - (1.0 - slide) * 6.0))
		node.modulate.a = slide
		node.size = SIZE
		var bar_pos := node.position + Vector2(0, SIZE.y - BAR_HEIGHT)
		bar_bg.position = bar_pos
		bar_bg.modulate.a = slide
		bar.position = bar_pos
		bar.size.x = roundf(SIZE.x * clampf(1.0 - t / duration, 0.0, 1.0))
		bar.modulate.a = slide
		y += SIZE.y + GAP
		if t >= duration:
			expired.append(id)
	for id in expired:
		_remove(id)
