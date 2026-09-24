class_name NeonText
extends Control
## 네온 글자(assets/sprites/fx/neon_*.png + neon_letters.json). 꺼진 유리관은 보통 합성, 켜진 빛은 가산 합성으로 그린다.
## 글자마다 켜짐/꺼짐 상태가 있고, flicker_on() 은 글자가 하나씩 켜지듯 깜빡이며 등장한다.
## idle_flicker 가 true 면 가끔 한 글자씩 불규칙하게 깜빡인다(배경 간판).

const INFO_PATH := "res://assets/sprites/fx/neon_letters.json"
const SPACE_ADVANCE := 10
const LETTER_GAP := -2
const FLICKER_STEP := 0.045
const IDLE_MIN := 1.2
const IDLE_MAX := 4.5

@export var atlas: Texture2D
@export var text_value: String = ""
@export var idle_flicker: bool = false

var lit: Array[bool] = []
var _cell := Vector2i.ZERO
var _chars: Dictionary = {}
var _glow: Control
## 글자별 깜빡임 일정: [[시각, 켜짐?], ...]
var _schedule: Array = []
var _clock: float = 0.0
var _idle_timer: float = 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var file := FileAccess.open(INFO_PATH, FileAccess.READ)
	var info: Dictionary = JSON.parse_string(file.get_as_text())
	_cell = Vector2i(int(info["cell"][0]), int(info["cell"][1]))
	_chars = info["chars"]
	_glow = Control.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_glow.draw.connect(_draw_lit)
	add_child(_glow)
	set_text_value(text_value, true)


func set_text_value(value: String, on: bool) -> void:
	text_value = value
	lit = []
	_schedule = []
	for i in value.length():
		lit.append(on)
		_schedule.append([])
	size = Vector2(text_width(), _cell.y)
	_glow.size = size
	queue_redraw()
	_glow.queue_redraw()


func text_width() -> int:
	var width := 0
	for i in text_value.length():
		width += _advance(text_value[i])
	return width


func _advance(ch: String) -> int:
	if _chars.has(ch):
		return int(_chars[ch][1]) + LETTER_GAP + 2
	return SPACE_ADVANCE


## 모든 글자를 끈 뒤 앞에서부터 하나씩 깜빡이며 켠다. stagger = 글자 간 시작 간격.
func flicker_on(stagger: float = 0.07) -> void:
	for i in lit.size():
		lit[i] = false
		var start := _clock + i * stagger + RngService.randf_range_misc(0.0, 0.04)
		var toggles := RngService.randi_range_misc(2, 4)
		var steps: Array = []
		var t := start
		for k in toggles * 2:
			steps.append([t, k % 2 == 0])
			t += FLICKER_STEP * RngService.randf_range_misc(0.6, 1.6)
		steps.append([t, true])
		_schedule[i] = steps
	queue_redraw()
	_glow.queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	var changed := false
	for i in _schedule.size():
		var steps: Array = _schedule[i]
		while not steps.is_empty() and float(steps[0][0]) <= _clock:
			lit[i] = bool(steps[0][1])
			steps.pop_front()
			changed = true
	if idle_flicker:
		_idle_timer -= delta
		if _idle_timer <= 0.0 and not lit.is_empty():
			_idle_timer = RngService.randf_range_misc(IDLE_MIN, IDLE_MAX)
			var index := RngService.randi_range_misc(0, lit.size() - 1)
			var steps2: Array = []
			var t := _clock
			var long_off := RngService.randf_misc() < 0.2
			for k in RngService.randi_range_misc(1, 3):
				steps2.append([t, false])
				t += FLICKER_STEP * (6.0 if long_off and k == 0 else 1.0)
				steps2.append([t, true])
				t += FLICKER_STEP
			_schedule[index] = steps2
	if changed:
		queue_redraw()
		_glow.queue_redraw()


func _draw() -> void:
	# 꺼진 유리관(아래 줄)
	var x := 0
	for i in text_value.length():
		var ch := text_value[i]
		if _chars.has(ch) and not lit[i]:
			draw_texture_rect_region(atlas, Rect2(x, 0, _cell.x, _cell.y), Rect2(int(_chars[ch][0]), _cell.y, _cell.x, _cell.y))
		x += _advance(ch)


func _draw_lit() -> void:
	var x := 0
	var alpha := 1.0 if not VisualSettings.reduce_flashing else 0.85
	for i in text_value.length():
		var ch := text_value[i]
		if _chars.has(ch) and lit[i]:
			_glow.draw_texture_rect_region(atlas, Rect2(x, 0, _cell.x, _cell.y), Rect2(int(_chars[ch][0]), 0, _cell.x, _cell.y), Color(1, 1, 1, alpha))
		x += _advance(ch)
