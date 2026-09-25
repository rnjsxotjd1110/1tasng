class_name Background1F
extends Node2D
## 1F 다운타운 카지노 배경(ART_BIBLE 12장): 붉은 카펫·금 기둥·슬롯머신 줄(순차 점멸)·
## 크리스털 샹들리에·가끔 지나가는 손님 실루엣(위쪽 빈 띠를 지나간다).

const WALL := preload("res://assets/sprites/bg/1f/wall.png")
const TABLE := preload("res://assets/sprites/bg/1f/table.png")
const CHANDELIER := preload("res://assets/sprites/bg/1f/chandelier.png")
const CONE := preload("res://assets/sprites/bg/1f/lamp_cone.png")
const POOL := preload("res://assets/sprites/bg/1f/light_pool.png")
const GUEST := preload("res://assets/sprites/bg/1f/guest_silhouette.png")
const VIGNETTE := preload("res://assets/shaders/vignette.gdshader")

const SCREEN := Vector2(640, 360)
const CHANDELIER_POS := Vector2(262, 8)
const CONE_TOP := 10.0
const POOL_CENTER := Vector2(262, 196)

## _slot_machine() 이 구운 좌표와 맞춰야 한다(tools/art/gen_bg.py SLOT_POSITIONS_1F).
const SLOT_POSITIONS: Array[Vector2] = [Vector2(18, 40), Vector2(330, 40), Vector2(598, 40)]
const SLOT_LIGHT_COLORS: Array[Color] = [Palette.RED_HL, Palette.GOLD_HL, Palette.CLOVER]
const SLOT_BLINK_PERIOD := 0.9

const GUEST_Y := 58.0
const GUEST_PERIOD := 13.0
const GUEST_DURATION := 5.0

var _clock: float = 0.0
var _lights: Node2D
var _guest: Sprite2D
var _guest_timer: float = 4.0


func _ready() -> void:
	_sprite(WALL, Vector2.ZERO)
	_sprite(TABLE, Vector2.ZERO)
	var cone := _sprite(CONE, Vector2(CHANDELIER_POS.x - CONE.get_width() * 0.5, CONE_TOP))
	cone.material = _additive()
	var pool := _sprite(POOL, POOL_CENTER - POOL.get_size() * 0.5)
	pool.material = _additive()
	_sprite(CHANDELIER, CHANDELIER_POS - Vector2(CHANDELIER.get_width() * 0.5, 0.0))
	_lights = Node2D.new()
	_lights.draw.connect(_draw_lights)
	add_child(_lights)
	_guest = Sprite2D.new()
	_guest.texture = GUEST
	_guest.centered = false
	_guest.visible = false
	add_child(_guest)
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
	_lights.queue_redraw()
	_guest_timer -= delta
	if _guest_timer <= 0.0:
		if _guest.visible:
			_guest.visible = false
			_guest_timer = GUEST_PERIOD
		else:
			_guest.visible = true
			_guest_timer = GUEST_DURATION
	if _guest.visible:
		var u := 1.0 - _guest_timer / GUEST_DURATION
		_guest.position = Vector2(roundf(lerpf(-14.0, SCREEN.x + 4.0, u)), GUEST_Y)


## 슬롯머신 3대의 불빛이 순서대로(칸마다 0.33주기 어긋나게) 깜빡인다.
func _draw_lights() -> void:
	for m in SLOT_POSITIONS.size():
		var pos: Vector2 = SLOT_POSITIONS[m]
		var phase := fposmod(_clock / SLOT_BLINK_PERIOD - m * 0.3, 1.0)
		for i in 3:
			if fposmod(phase - i * 0.33, 1.0) >= 0.4:
				continue
			_lights.draw_rect(Rect2(pos + Vector2(4 + i * 6, 30), Vector2(4, 3)), SLOT_LIGHT_COLORS[i])
