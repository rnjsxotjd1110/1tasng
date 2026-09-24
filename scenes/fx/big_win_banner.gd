class_name BigWinBanner
extends Control
## "BIG WIN!" 네온 배너. 글자가 하나씩 켜지듯 깜빡이며 등장하고, 잠시 뒤 사라진다.

const NEON := preload("res://assets/sprites/fx/neon_pink.png")
const CENTER := Vector2(262, 200)
const PLATE_PAD := Vector2(8, 4)
const SHOW_TIME := 1.9
const FADE_TIME := 0.25

var _neon: NeonText
var _plate: Panel
var _time: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_plate = Panel.new()
	_plate.theme_type_variation = "PanelPlain"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_neon = NeonText.new()
	_neon.atlas = NEON
	_neon.text_value = "BIG WIN!"
	add_child(_neon)
	_layout()


func _layout() -> void:
	var neon_size := Vector2(_neon.text_width(), 26)
	var top_left := (CENTER - neon_size * 0.5).round()
	_neon.position = top_left
	_plate.position = top_left - PLATE_PAD
	_plate.size = neon_size + PLATE_PAD * 2.0


func play() -> void:
	visible = true
	modulate.a = 1.0
	_time = 0.0
	_neon.flicker_on(0.06)
	AudioManager.play_sfx("neon_flicker")


func _process(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	if _time > SHOW_TIME:
		modulate.a = clampf(1.0 - (_time - SHOW_TIME) / FADE_TIME, 0.0, 1.0)
		if _time > SHOW_TIME + FADE_TIME:
			visible = false
			_time = -1.0
