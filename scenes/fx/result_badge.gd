class_name ResultBadge
extends Control
## 휠 위쪽 결과 배지: 색 원형 배지에 큰 숫자 + "빨강 · 홀수" 부제.
## 등장: 1프레임 큰 스프라이트 → 원래 크기, 정수 픽셀 바운스. 공이 여러 개면 나란히.

const CENTER_X := 262.0
const TOP_Y := 30.0
const BADGE := 27
const POP := 33
const SPACING := 66.0
const POP_FRAMES := 2
const BOUNCE: Array[int] = [-3, -1, 1, 0]
const BOUNCE_STEP := 0.05
const SUBTITLE_Y := 28.0
const FADE := 0.15

const BADGES := {
	RouletteRules.PocketColor.RED: preload("res://assets/sprites/ui/badge_red.png"),
	RouletteRules.PocketColor.BLACK: preload("res://assets/sprites/ui/badge_black.png"),
	RouletteRules.PocketColor.GREEN: preload("res://assets/sprites/ui/badge_green.png"),
}
const POPS := {
	RouletteRules.PocketColor.RED: preload("res://assets/sprites/ui/badge_pop_red.png"),
	RouletteRules.PocketColor.BLACK: preload("res://assets/sprites/ui/badge_pop_black.png"),
	RouletteRules.PocketColor.GREEN: preload("res://assets/sprites/ui/badge_pop_green.png"),
}

var _results: Array[int] = []
var _numbers: Array[Label] = []
var _subtitles: Array[Label] = []
var _frames: int = 0
var _time: float = 0.0
var _canvas: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 80)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = size
	_canvas.draw.connect(_draw_badges)
	add_child(_canvas)
	visible = false


func show_results(results: Array[int]) -> void:
	_results = results.duplicate()
	for label in _numbers:
		label.queue_free()
	for label in _subtitles:
		label.queue_free()
	_numbers.clear()
	_subtitles.clear()
	for i in _results.size():
		var number := _results[i]
		var label := Label.new()
		label.theme_type_variation = "Num14Ivory"
		label.text = str(number)
		label.auto_translate = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_numbers.append(label)
		var sub := Label.new()
		sub.theme_type_variation = "LabelSmall"
		sub.text = subtitle_for(number)
		sub.auto_translate = false
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sub)
		_subtitles.append(sub)
	_frames = 0
	_time = 0.0
	visible = true
	modulate.a = 1.0
	_layout(0)


func hide_badge() -> void:
	if not visible:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void: visible = false)


## "빨강 · 홀수" / "0" 은 "제로".
static func subtitle_for(number: int) -> String:
	if number == RouletteRules.ZERO:
		return TranslationServer.translate("RESULT_ZERO")
	var color_key := "COLOR_RED" if RouletteRules.is_red(number) else "COLOR_BLACK"
	var parity_key := "PARITY_ODD" if RouletteRules.is_odd(number) else "PARITY_EVEN"
	return "%s · %s" % [TranslationServer.translate(color_key), TranslationServer.translate(parity_key)]


func _center(i: int) -> Vector2:
	var offset := (i - (_results.size() - 1) * 0.5) * SPACING
	return Vector2(roundf(CENTER_X + offset), TOP_Y + BADGE * 0.5)


func _bounce_offset() -> int:
	var step := int(_time / BOUNCE_STEP)
	return BOUNCE[step] if step < BOUNCE.size() else 0


func _layout(dy: int) -> void:
	for i in _numbers.size():
		var center := _center(i) + Vector2(0, dy)
		var label := _numbers[i]
		label.reset_size()
		var label_size := label.get_combined_minimum_size()
		label.position = (center - label_size * 0.5 + Vector2(0, 1)).round()
		label.visible = _frames >= POP_FRAMES
		var sub := _subtitles[i]
		sub.size = Vector2(SPACING - 2, 12)
		sub.position = Vector2(roundf(center.x - sub.size.x * 0.5), center.y - BADGE * 0.5 + SUBTITLE_Y)


func _process(delta: float) -> void:
	if not visible:
		return
	_frames += 1
	if _frames > POP_FRAMES:
		_time += delta
	_layout(_bounce_offset())
	_canvas.queue_redraw()


func _draw_badges() -> void:
	for i in _results.size():
		var number := _results[i]
		var color := RouletteRules.color_of(number)
		var center := _center(i) + Vector2(0, _bounce_offset())
		if _frames < POP_FRAMES:
			_canvas.draw_texture(POPS[color], (center - Vector2(POP, POP) * 0.5).round())
		else:
			_canvas.draw_texture(BADGES[color], (center - Vector2(BADGE, BADGE) * 0.5).round())
