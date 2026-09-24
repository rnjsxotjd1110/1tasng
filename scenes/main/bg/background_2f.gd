class_name Background2F
extends Node2D
## 2F 리버보트 카지노 배경(ART_BIBLE 12장): 나무 선실·둥근 창 밖 달빛 강(스크롤)·
## 흔들리는 등불 2개·배 흔들림에 맞춰 배경 전체가 1px 느리게 흔들린다.

const WALL := preload("res://assets/sprites/bg/2f/wall.png")
const TABLE := preload("res://assets/sprites/bg/2f/table.png")
const RIVER := preload("res://assets/sprites/bg/2f/river.png")
const LANTERN := preload("res://assets/sprites/bg/2f/lantern.png")
const CONE := preload("res://assets/sprites/bg/2f/lamp_cone.png")
const POOL := preload("res://assets/sprites/bg/2f/light_pool.png")
const VIGNETTE := preload("res://assets/shaders/vignette.gdshader")

const SCREEN := Vector2(640, 360)
## tools/art/gen_bg.py PORTHOLE_CENTERS_2F 와 같은 좌표.
const PORTHOLE_CENTERS: Array[Vector2] = [Vector2(122, 46), Vector2(402, 46)]
const PORTHOLE_WINDOW := 46
const RIVER_SCROLL_SPEED := 6.0
const LANTERN_POS: Array[Vector2] = [Vector2(60, 16), Vector2(560, 16)]
const LANTERN_SWAY_PX := 1.0
const LANTERN_PERIOD := 3.4
const HULL_SWAY_PX := 1.0
const HULL_SWAY_PERIOD := 5.5
const POOL_CENTER := Vector2(262, 200)

var _clock: float = 0.0
var _rivers: Array[Sprite2D] = []
var _lanterns: Array[Node2D] = []
var _world: Node2D


func _ready() -> void:
	_world = Node2D.new()
	add_child(_world)
	for center in PORTHOLE_CENTERS:
		var river := Sprite2D.new()
		river.texture = RIVER
		river.centered = false
		river.region_enabled = true
		river.region_rect = Rect2(0, 0, PORTHOLE_WINDOW, RIVER.get_height())
		river.position = (center - Vector2(PORTHOLE_WINDOW * 0.5, RIVER.get_height() * 0.5)).round()
		_world.add_child(river)
		_rivers.append(river)
	_sprite(_world, WALL, Vector2.ZERO)
	_sprite(_world, TABLE, Vector2.ZERO)
	var cone := _sprite(_world, CONE, Vector2(SCREEN.x * 0.5 - CONE.get_width() * 0.5, 10.0))
	cone.material = _additive()
	var pool := _sprite(_world, POOL, POOL_CENTER - POOL.get_size() * 0.5)
	pool.material = _additive()
	for lantern_pos in LANTERN_POS:
		var root := Node2D.new()
		root.position = lantern_pos
		_world.add_child(root)
		_sprite(root, LANTERN, Vector2(-LANTERN.get_width() * 0.5, 0.0))
		_lanterns.append(root)
	var vignette := ColorRect.new()
	vignette.size = SCREEN
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = VIGNETTE
	vignette.material = material
	add_child(vignette)


func _sprite(parent: Node, texture: Texture2D, pos: Vector2) -> Sprite2D:
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
	for river in _rivers:
		var max_offset := RIVER.get_width() - PORTHOLE_WINDOW
		var offset := fposmod(_clock * RIVER_SCROLL_SPEED, float(max_offset))
		var rect := river.region_rect
		rect.position.x = floorf(offset)
		river.region_rect = rect
	for i in _lanterns.size():
		var sway := roundi(LANTERN_SWAY_PX * sin(_clock * TAU / LANTERN_PERIOD + i * 0.7))
		_lanterns[i].position.x = LANTERN_POS[i].x + sway
	var hull_sway := roundi(HULL_SWAY_PX * sin(_clock * TAU / HULL_SWAY_PERIOD))
	_world.position = Vector2(hull_sway, 0)
