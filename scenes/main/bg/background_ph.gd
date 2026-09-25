class_name BackgroundPH
extends Node2D
## PH 펜트하우스 배경(ART_BIBLE 12장): 흰 대리석·금 기둥·벨벳 커튼·거대한 샹들리에·구름 위의 달(벽에 그려짐).
## 마담 벨벳 본인은 7단계부터 배경이 아니라 실제 월드 액터(MadameVelvet, Main 이 world 에 둔다)로 나온다.

const WALL := preload("res://assets/sprites/bg/ph/wall.png")
const TABLE := preload("res://assets/sprites/bg/ph/table.png")
const CHANDELIER := preload("res://assets/sprites/bg/ph/chandelier.png")
const CONE := preload("res://assets/sprites/bg/ph/lamp_cone.png")
const POOL := preload("res://assets/sprites/bg/ph/light_pool.png")
const VIGNETTE := preload("res://assets/shaders/vignette.gdshader")

const SCREEN := Vector2(640, 360)
const CHANDELIER_POS := Vector2(262, 4)
const CONE_TOP := 8.0
const POOL_CENTER := Vector2(262, 196)


func _ready() -> void:
	_sprite(WALL, Vector2.ZERO)
	_sprite(TABLE, Vector2.ZERO)
	var cone := _sprite(CONE, Vector2(CHANDELIER_POS.x - CONE.get_width() * 0.5, CONE_TOP))
	cone.material = _additive()
	var pool := _sprite(POOL, POOL_CENTER - POOL.get_size() * 0.5)
	pool.material = _additive()
	_sprite(CHANDELIER, CHANDELIER_POS - Vector2(CHANDELIER.get_width() * 0.5, 0.0))
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
