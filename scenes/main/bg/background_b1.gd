class_name BackgroundB1
extends Node2D
## B1 뒷골목 도박장 배경. 레이어(아래 → 위):
##   벽돌 벽 · 현상수배 포스터 · 네온 간판 "LUCKY"(글자마다 불규칙 깜빡임, 빛은 가산)
##   · 테이블(나무 레일 + 펠트) · 램프 빛 원뿔(가산) · 휠 주변 빛 웅덩이(가산) · 전선과 램프(천천히 흔들림) · 연기 · 비네트
## 7단계에서 층별 배경을 같은 구성으로 추가한다(Main 은 배경 씬만 바꿔 끼운다).

const DIR := "res://assets/sprites/bg/b1/"
const WALL := preload("res://assets/sprites/bg/b1/wall.png")
const TABLE := preload("res://assets/sprites/bg/b1/table.png")
const LAMP := preload("res://assets/sprites/bg/b1/lamp.png")
const CONE := preload("res://assets/sprites/bg/b1/lamp_cone.png")
const POOL := preload("res://assets/sprites/bg/b1/light_pool.png")
const SMOKE := preload("res://assets/sprites/bg/b1/smoke.png")
const POSTER := preload("res://assets/sprites/bg/b1/poster.png")
const NEON := preload("res://assets/sprites/fx/neon_pink.png")
const VIGNETTE := preload("res://assets/shaders/vignette.gdshader")

const SCREEN := Vector2(640, 360)
const LAMP_ANCHOR := Vector2(262, 24)
const LAMP_LENGTH := 10.0
const LAMP_SWAY_PX := 2.0
const LAMP_PERIOD := 6.5
const CONE_TOP := 12.0
const POOL_CENTER := Vector2(262, 196)
const POSTER_POS := Vector2(364, 40)
const SIGN_POS := Vector2(112, 38)
const SMOKE_AMOUNT := 10

var _clock: float = 0.0
var _lamp_root: Node2D
var _cord: Node2D
var _sway: int = 0


func _ready() -> void:
	_sprite(WALL, Vector2.ZERO)
	_sprite(POSTER, POSTER_POS)
	_sprite(TABLE, Vector2.ZERO)
	_lamp_root = Node2D.new()
	add_child(_lamp_root)
	var cone := _sprite(CONE, Vector2(-CONE.get_width() * 0.5, CONE_TOP), _lamp_root)
	cone.material = _additive()
	var pool := _sprite(POOL, POOL_CENTER - POOL.get_size() * 0.5)
	pool.material = _additive()
	_cord = Node2D.new()
	_cord.draw.connect(_draw_cord)
	add_child(_cord)
	_sprite(LAMP, Vector2(-floorf(LAMP.get_width() * 0.5), 0), _lamp_root)
	_lamp_root.position = LAMP_ANCHOR + Vector2(0, LAMP_LENGTH)
	var smoke := CPUParticles2D.new()
	smoke.texture = SMOKE
	smoke.amount = SMOKE_AMOUNT
	smoke.lifetime = 14.0
	smoke.preprocess = 14.0
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(170, 40)
	smoke.position = Vector2(262, 210)
	smoke.direction = Vector2(0.4, -1)
	smoke.spread = 30.0
	smoke.initial_velocity_min = 3.0
	smoke.initial_velocity_max = 8.0
	smoke.gravity = Vector2(1.5, -1.0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 0.35))
	ramp.add_point(0.7, Color(1, 1, 1, 0.25))
	smoke.color_ramp = ramp
	add_child(smoke)
	var vignette := ColorRect.new()
	vignette.size = SCREEN
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = VIGNETTE
	vignette.material = material
	add_child(vignette)
	# 스스로 빛나는 것(네온·램프)은 비네트 위에 둔다.
	var neon := NeonText.new()
	neon.atlas = NEON
	neon.text_value = "LUCKY"
	neon.idle_flicker = true
	neon.position = SIGN_POS
	var sign_holder := Control.new()
	sign_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sign_holder)
	sign_holder.add_child(neon)
	move_child(_cord, -1)
	move_child(_lamp_root, -1)


func _sprite(texture: Texture2D, pos: Vector2, parent: Node = self) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = pos
	parent.add_child(sprite)
	return sprite


func _additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _process(delta: float) -> void:
	_clock += delta
	var sway := roundi(LAMP_SWAY_PX * sin(_clock * TAU / LAMP_PERIOD))
	if sway != _sway:
		_sway = sway
		_lamp_root.position = LAMP_ANCHOR + Vector2(sway, LAMP_LENGTH)
		_cord.queue_redraw()


func _draw_cord() -> void:
	var top := LAMP_ANCHOR
	var bottom := _lamp_root.position
	_cord.draw_line(top, bottom, Palette.VOID, -1.0)
	_cord.draw_line(top + Vector2(1, 0), bottom + Vector2(1, 0), Palette.INK, -1.0)
