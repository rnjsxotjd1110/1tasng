class_name VoidLens
extends Node2D
## 공허 구슬 주변 왜곡(void_lens.gdshader). centers(이 노드 좌표) 마다 반지름 radius 원 안의 화면을 소용돌이로 다시 그린다.
## 바로 앞에 BackBufferCopy 를 두어 휠·보드가 그려진 뒤의 화면을 읽게 한다(create_with_copy).

const SHADER := preload("res://assets/shaders/void_lens.gdshader")

var centers: Array[Vector2] = []
var radius: float = 10.0:
	set(value):
		radius = value
		if material != null:
			(material as ShaderMaterial).set_shader_parameter("radius", radius)

static var _white: Texture2D = null


## parent 의 before 자식 앞(before 가 없으면 끝)에 BackBufferCopy + VoidLens 를 넣고 렌즈를 돌려준다.
static func create_with_copy(parent: Node, before: Node = null) -> VoidLens:
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	var lens := VoidLens.new()
	parent.add_child(copy)
	parent.add_child(lens)
	if before != null:
		parent.move_child(copy, before.get_index())
		parent.move_child(lens, before.get_index())
	return lens


func _ready() -> void:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("radius", radius)
	material = shader_material
	if _white == null:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)


func set_centers(points: Array[Vector2]) -> void:
	centers = points
	queue_redraw()


func _draw() -> void:
	for center in centers:
		var side := Vector2(radius, radius) * 2.0
		draw_texture_rect(_white, Rect2((center - side * 0.5).round(), side), false)
