class_name JackpotOverlay
extends Control
## JACKPOT 전체 화면 연출: 배경 어둡게 · 회전 금빛 광선 · "JACKPOT" 글자 낙하 · 코인 비 · 2초 카운트업 · 클릭으로 닫기.
## 오토 스핀 중이면 AUTO_CLOSE 초 뒤 스스로 닫힌다.

signal closed()

const LETTERS := preload("res://assets/sprites/fx/jackpot_letters.png")
const INFO_PATH := "res://assets/sprites/fx/jackpot_letters.json"
const RAYS := preload("res://assets/shaders/rays.gdshader")
const SCREEN := Vector2(640, 360)
const LETTER_Y := 100.0
const LETTER_DROP := 150.0
const LETTER_STAGGER := 0.09
const LETTER_FALL := 0.32
const LETTER_GAP := 2
const AMOUNT_Y := 146.0
const HINT_Y := 178.0
const DIM_ALPHA := 0.85
const FADE_IN := 0.25
const FADE_OUT := 0.2
const COUNT_TIME := 2.0
const CLICK_DELAY := 0.8
const AUTO_CLOSE := 3.0
const COIN_RAIN_AMOUNT := 70

var is_open: bool = false
var auto_close: bool = false

var _time: float = 0.0
var _dim: ColorRect
var _rays: ColorRect
var _letters: Control
var _amount: CountLabel
var _hint: Label
var _rain: CPUParticles2D
var _cell := Vector2i.ZERO
var _chars: Dictionary = {}
var _word := "JACKPOT"
var _closing: bool = false


func _ready() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var info: Dictionary = JSON.parse_string(FileAccess.open(INFO_PATH, FileAccess.READ).get_as_text())
	_cell = Vector2i(int(info["cell"][0]), int(info["cell"][1]))
	_chars = info["chars"]
	_dim = ColorRect.new()
	_dim.color = Palette.with_alpha(Palette.VOID, DIM_ALPHA)
	_dim.size = SCREEN
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_rays = ColorRect.new()
	_rays.size = SCREEN
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = RAYS
	_rays.material = material
	add_child(_rays)
	_rain = CPUParticles2D.new()
	_rain.texture = preload("res://assets/sprites/ui/coin.png")
	var coin_material := CanvasItemMaterial.new()
	coin_material.particles_animation = true
	coin_material.particles_anim_h_frames = 4
	coin_material.particles_anim_v_frames = 1
	coin_material.particles_anim_loop = true
	_rain.material = coin_material
	_rain.anim_speed_min = 1.0
	_rain.anim_speed_max = 2.5
	_rain.amount = COIN_RAIN_AMOUNT
	_rain.lifetime = 3.0
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(SCREEN.x * 0.5, 4)
	_rain.position = Vector2(SCREEN.x * 0.5, -8)
	_rain.direction = Vector2(0, 1)
	_rain.spread = 10.0
	_rain.initial_velocity_min = 40.0
	_rain.initial_velocity_max = 90.0
	_rain.gravity = Vector2(0, 90)
	_rain.emitting = false
	add_child(_rain)
	_letters = Control.new()
	_letters.size = SCREEN
	_letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letters.draw.connect(_draw_letters)
	add_child(_letters)
	_amount = CountLabel.new()
	_amount.theme_type_variation = "Num14Gold"
	_amount.style = CountLabel.Style.SIGNED
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount.position = Vector2(0, AMOUNT_Y)
	_amount.size = Vector2(SCREEN.x, 14)
	add_child(_amount)
	_hint = Label.new()
	_hint.text = "JACKPOT_CONTINUE"
	_hint.theme_type_variation = "LabelSmall"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, HINT_Y)
	_hint.size = Vector2(SCREEN.x, 12)
	add_child(_hint)


func open(amount: float, p_auto_close: bool = false) -> void:
	is_open = true
	_closing = false
	auto_close = p_auto_close
	visible = true
	modulate.a = 1.0
	_time = 0.0
	_amount.set_value(0.0, 0.0)
	_amount.set_value(amount, COUNT_TIME)
	_rain.emitting = true
	_hint.modulate.a = 0.0
	AudioManager.play_sfx("win_jackpot")


func close() -> void:
	if not is_open or _closing:
		return
	_closing = true
	_rain.emitting = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(func() -> void:
		visible = false
		is_open = false
		closed.emit())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		if _time >= CLICK_DELAY:
			close()


func _process(delta: float) -> void:
	if not is_open:
		return
	_time += delta
	_dim.modulate.a = clampf(_time / FADE_IN, 0.0, 1.0)
	_rays.modulate.a = clampf(_time / FADE_IN, 0.0, 1.0)
	if _time > COUNT_TIME * 0.5:
		_hint.modulate.a = 0.55 + 0.45 * sin(_time * 5.0)
	if auto_close and _time >= AUTO_CLOSE:
		close()
	_letters.queue_redraw()


func _word_width() -> int:
	var width := 0
	for i in _word.length():
		width += int(_chars[_word[i]][1]) + LETTER_GAP
	return width - LETTER_GAP


func _draw_letters() -> void:
	var x := roundf((SCREEN.x - _word_width()) * 0.5)
	for i in _word.length():
		var ch := _word[i]
		var start := i * LETTER_STAGGER
		var u := clampf((_time - start) / LETTER_FALL, 0.0, 1.0)
		if _time >= start:
			var y := LETTER_Y - LETTER_DROP * (1.0 - _drop_ease(u))
			_letters.draw_texture_rect_region(LETTERS, Rect2(x - 1, roundf(y), _cell.x, _cell.y),
				Rect2(int(_chars[ch][0]), 0, _cell.x, _cell.y))
		x += int(_chars[ch][1]) + LETTER_GAP


func _drop_ease(u: float) -> float:
	# 떨어져서 한 번 튄다
	if u < 0.75:
		var a := u / 0.75
		return a * a
	var b := (u - 0.75) / 0.25
	return 1.0 - 0.08 * sin(b * PI)
