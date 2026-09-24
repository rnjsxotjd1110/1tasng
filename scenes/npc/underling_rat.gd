class_name UnderlingRat
extends Node2D
## 부하 쥐(ART_BIBLE 11-2). "감시하는 부하" 패널티 동안 걸어 들어와 테이블에 기댄다.

signal arrived()

enum Anim { LEAN, WALK }

const ROW := {Anim.LEAN: 0, Anim.WALK: 1}
const FRAME_COUNT := {Anim.LEAN: 2, Anim.WALK: 4}
const FRAME_W := 32
const FRAME_H := 40
const SHEET := preload("res://assets/sprites/npc/underling_rat.png")
const FRAME_TIME := 0.18
const WALK_SPEED := 55.0

var anim: Anim = Anim.LEAN
var facing_left: bool = true

var _sprite: Sprite2D
var _frame: int = 0
var _timer: float = 0.0
var _walk_active: bool = false
var _walk_target_x: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.position = Vector2(-FRAME_W / 2.0, -float(FRAME_H))
	add_child(_sprite)
	_update_region()


func walk_to(target_x: float) -> void:
	facing_left = target_x < position.x
	_walk_target_x = target_x
	_walk_active = true
	anim = Anim.WALK
	_frame = 0
	_timer = 0.0
	_update_region()


func lean() -> void:
	anim = Anim.LEAN
	_frame = 0
	_timer = 0.0
	_walk_active = false
	_update_region()


func is_walking() -> bool:
	return _walk_active


func _process(delta: float) -> void:
	_timer += delta
	var count: int = FRAME_COUNT[anim]
	while _timer >= FRAME_TIME:
		_timer -= FRAME_TIME
		_frame = (_frame + 1) % count
	_update_region()
	if _walk_active:
		var dir := signf(_walk_target_x - position.x)
		position.x += dir * WALK_SPEED * delta
		var reached := (dir >= 0.0 and position.x >= _walk_target_x) or (dir < 0.0 and position.x <= _walk_target_x)
		if reached:
			position.x = _walk_target_x
			_walk_active = false
			arrived.emit()


func _update_region() -> void:
	var row: int = ROW[anim]
	_sprite.region_rect = Rect2(_frame * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
	_sprite.flip_h = facing_left
