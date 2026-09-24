class_name GoldenBadge
extends Control
## 황금 포켓 적중 배지 "황금 ×3"(ART_BIBLE 9-4). 결과 배지 아래에 금 패널로 떨어지듯 나타나고(정수 픽셀),
## 테두리에 반짝임이 돈다. 다음 스핀이 시작되면 사라진다.

const DROP_PX := 6
const APPEAR_TIME := 0.18
const FADE_TIME := 0.15
const SPARKLE := preload("res://assets/sprites/ui/sparkle.png")
const SPARKLE_SIZE := 5
const SPARKLE_FRAMES := 4
const SPARKLE_PERIOD := 0.6

## 배지 가운데 위쪽 기준점(부모 좌표).
var center := Vector2(262, 72)

var _panel: PanelContainer
var _label: Label
var _time: float = -1.0
var _hiding: float = -1.0
var _sparkles: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "BadgeGolden"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.theme_type_variation = "LabelBold"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_sparkles = Control.new()
	_sparkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkles.draw.connect(_draw_sparkles)
	add_child(_sparkles)
	visible = false


func show_badge(mult: float) -> void:
	_label.text = "%s %s" % [tr("RESULT_GOLDEN"), NumberFormat.format_mult(mult)]
	_panel.reset_size()
	_panel.size = _panel.get_combined_minimum_size()
	_time = 0.0
	_hiding = -1.0
	visible = true
	modulate.a = 0.0
	_layout(0.0)


func hide_badge() -> void:
	if visible and _hiding < 0.0:
		_hiding = 0.0


func text() -> String:
	return _label.text if visible else ""


func _layout(u: float) -> void:
	var top_left := Vector2(center.x - _panel.size.x * 0.5, center.y - DROP_PX * (1.0 - u)).round()
	_panel.position = top_left
	_sparkles.position = top_left
	_sparkles.size = _panel.size


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var u := clampf(_time / APPEAR_TIME, 0.0, 1.0)
	_layout(1.0 - pow(1.0 - u, 3.0))
	modulate.a = u
	if _hiding >= 0.0:
		_hiding += delta
		modulate.a = 1.0 - clampf(_hiding / FADE_TIME, 0.0, 1.0)
		if _hiding >= FADE_TIME:
			visible = false
	_sparkles.queue_redraw()


func _draw_sparkles() -> void:
	var box := _panel.size
	var corners: Array[Vector2] = [Vector2(-2, -2), Vector2(box.x - 3, -2), Vector2(box.x - 3, box.y - 3), Vector2(-2, box.y - 3)]
	var step := int(_time / SPARKLE_PERIOD) % corners.size()
	var frame := int(fmod(_time, SPARKLE_PERIOD) / SPARKLE_PERIOD * SPARKLE_FRAMES * 2)
	if frame < SPARKLE_FRAMES:
		_sparkles.draw_texture_rect_region(SPARKLE, Rect2(corners[step], Vector2(SPARKLE_SIZE, SPARKLE_SIZE)),
			Rect2(frame * SPARKLE_SIZE, 0, SPARKLE_SIZE, SPARKLE_SIZE))
