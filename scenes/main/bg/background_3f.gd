class_name Background3F
extends Node2D
## 3F 스카이 라운지 배경(ART_BIBLE 12장): 통유리 밖 스카이라인(창 불빛 무작위 점멸)·
## 비행기 점멸등이 천천히 지나감·네온 청록 간접조명(고정 조명 없이 은은한 벽 빛)·칵테일 바.

const WALL := preload("res://assets/sprites/bg/3f/wall.png")
const TABLE := preload("res://assets/sprites/bg/3f/table.png")
const BAR := preload("res://assets/sprites/bg/3f/bar.png")
## gen_bg.py gen_3f(): light_pool.png 는 neon_purple, lamp_cone.png 는 neon_cyan 으로 굽는다.
const POOL_PURPLE := preload("res://assets/sprites/bg/3f/light_pool.png")
const POOL_CYAN := preload("res://assets/sprites/bg/3f/lamp_cone.png")
const VIGNETTE := preload("res://assets/shaders/vignette.gdshader")

const SCREEN := Vector2(640, 360)
const BAR_POS := Vector2(576, 90)
const HORIZON_Y := 200
const FLICKER_COUNT := 16
const FLICKER_PERIOD_MIN := 2.5
const FLICKER_PERIOD_MAX := 7.0
const PLANE_Y := 30.0
const PLANE_PERIOD := 26.0
const PLANE_FLY_TIME := 16.0
const PLANE_BLINK_PERIOD := 0.6

var _clock: float = 0.0
var _flicker: Node2D
var _flicker_windows: Array[Dictionary] = []
var _plane: Node2D
var _plane_timer: float = 6.0


func _ready() -> void:
	_sprite(WALL, Vector2.ZERO)
	_sprite(TABLE, Vector2.ZERO)
	var glow_left := _sprite(POOL_CYAN, Vector2(-POOL_CYAN.get_width() * 0.35, -POOL_CYAN.get_height() * 0.55))
	glow_left.material = _additive()
	glow_left.modulate.a = 0.6
	var glow_right := _sprite(POOL_PURPLE, Vector2(SCREEN.x - POOL_PURPLE.get_width() * 0.65, -POOL_PURPLE.get_height() * 0.55))
	glow_right.material = _additive()
	glow_right.modulate.a = 0.55
	_sprite(BAR, BAR_POS)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 305
	for i in FLICKER_COUNT:
		_flicker_windows.append({
			"pos": Vector2(rnd.randi_range(6, int(SCREEN.x) - 6), rnd.randi_range(20, HORIZON_Y - 10)),
			"period": rnd.randf_range(FLICKER_PERIOD_MIN, FLICKER_PERIOD_MAX),
			"phase": rnd.randf_range(0.0, 1.0),
		})
	_flicker = Node2D.new()
	_flicker.draw.connect(_draw_flicker)
	add_child(_flicker)
	_plane = Node2D.new()
	_plane.draw.connect(_draw_plane)
	_plane.visible = false
	add_child(_plane)
	var vignette := ColorRect.new()
	vignette.size = SCREEN
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = VIGNETTE
	vignette.material = material
	add_child(vignette)


func _sprite(texture: Texture2D, pos: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = pos
	add_child(sprite)
	return sprite


func _additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _process(delta: float) -> void:
	_clock += delta
	_flicker.queue_redraw()
	_plane_timer -= delta
	if _plane_timer <= 0.0:
		if _plane.visible:
			_plane.visible = false
			_plane_timer = PLANE_PERIOD - PLANE_FLY_TIME
		else:
			_plane.visible = true
			_plane_timer = PLANE_FLY_TIME
	if _plane.visible:
		_plane.queue_redraw()


## 창 불빛이 각자 다른 주기로 켜졌다 꺼진다(사각파, 절반은 켜짐).
func _draw_flicker() -> void:
	for w: Dictionary in _flicker_windows:
		var phase := fposmod(_clock / float(w["period"]) + float(w["phase"]), 1.0)
		if phase < 0.5:
			_flicker.draw_rect(Rect2(Vector2(w["pos"]), Vector2(2, 2)), Palette.GOLD_HL)


func _draw_plane() -> void:
	var u := 1.0 - _plane_timer / PLANE_FLY_TIME
	var x := lerpf(-6.0, SCREEN.x + 6.0, u)
	var blink := fposmod(_clock, PLANE_BLINK_PERIOD) < PLANE_BLINK_PERIOD * 0.5
	var color := Palette.RED_HL if blink else Palette.IVORY
	_plane.draw_rect(Rect2(Vector2(roundf(x), PLANE_Y), Vector2(1, 1)), color)
