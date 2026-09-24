class_name BackgroundPH
extends Node2D
## PH 펜트하우스 배경(ART_BIBLE 12장): 흰 대리석·금 기둥·벨벳 커튼·거대한 샹들리에·
## 구름 위의 달(벽에 그려짐)·뒤쪽 높은 의자에 마담 벨벳 실루엣(가끔 와인잔을 드는 동작).

const WALL := preload("res://assets/sprites/bg/ph/wall.png")
const TABLE := preload("res://assets/sprites/bg/ph/table.png")
const CHANDELIER := preload("res://assets/sprites/bg/ph/chandelier.png")
const CONE := preload("res://assets/sprites/bg/ph/lamp_cone.png")
const POOL := preload("res://assets/sprites/bg/ph/light_pool.png")
const MADAME := preload("res://assets/sprites/bg/ph/madame_silhouette.png")
const VIGNETTE := preload("res://assets/shaders/vignette.gdshader")

const SCREEN := Vector2(640, 360)
const CHANDELIER_POS := Vector2(262, 4)
const CONE_TOP := 8.0
const POOL_CENTER := Vector2(262, 196)
const MADAME_POS := Vector2(596, 300)
const MADAME_FRAME_SIZE := Vector2(22, 40)
const GLASS_RAISE_PERIOD := 9.0
const GLASS_RAISE_DURATION := 2.4

var _clock: float = 0.0
var _madame: Sprite2D
var _glass_timer: float = 5.0


func _ready() -> void:
	_sprite(WALL, Vector2.ZERO)
	_sprite(TABLE, Vector2.ZERO)
	var cone := _sprite(CONE, Vector2(CHANDELIER_POS.x - CONE.get_width() * 0.5, CONE_TOP))
	cone.material = _additive()
	var pool := _sprite(POOL, POOL_CENTER - POOL.get_size() * 0.5)
	pool.material = _additive()
	_sprite(CHANDELIER, CHANDELIER_POS - Vector2(CHANDELIER.get_width() * 0.5, 0.0))
	_madame = Sprite2D.new()
	_madame.texture = MADAME
	_madame.centered = false
	_madame.region_enabled = true
	_madame.region_rect = Rect2(Vector2.ZERO, MADAME_FRAME_SIZE)
	_madame.position = MADAME_POS
	add_child(_madame)
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
	_glass_timer -= delta
	if _glass_timer <= 0.0:
		var raising := _madame.region_rect.position.x <= 0.0
		_madame.region_rect = Rect2(Vector2(0 if raising else MADAME_FRAME_SIZE.x, 0), MADAME_FRAME_SIZE)
		_glass_timer = GLASS_RAISE_DURATION if raising else (GLASS_RAISE_PERIOD - GLASS_RAISE_DURATION)
