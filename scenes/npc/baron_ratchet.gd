class_name BaronRatchet
extends Node2D
## 래칫 남작 월드 액터(ART_BIBLE 11-1). 걷기·대기·인사 등을 재생한다. 로직 없음 — 연출 전용.
## 좌표는 World 2D 공간(640×360) 기준, 피벗은 발바닥 중앙.

signal arrived()
signal gesture_finished()

enum Anim { WALK, IDLE, TALK, TIP_HAT, LAUGH, ANGRY, COUNTING_MONEY }

const ROW := {
	Anim.WALK: 0, Anim.IDLE: 1, Anim.TALK: 2, Anim.TIP_HAT: 3,
	Anim.LAUGH: 4, Anim.ANGRY: 5, Anim.COUNTING_MONEY: 6,
}
const FRAME_COUNT := {
	Anim.WALK: 6, Anim.IDLE: 4, Anim.TALK: 4, Anim.TIP_HAT: 5,
	Anim.LAUGH: 4, Anim.ANGRY: 3, Anim.COUNTING_MONEY: 4,
}
const FRAME_W := 48
const FRAME_H := 64
const SHEET := preload("res://assets/sprites/npc/baron_world.png")
const FRAME_TIME := 0.12
const WALK_SPEED := 70.0
const FOOTSTEP_INTERVAL := 0.34

var anim: Anim = Anim.IDLE
var facing_left: bool = true

var _sprite: Sprite2D
var _frame: int = 0
var _frame_timer: float = 0.0
var _looping: bool = true
var _gesture_done: bool = false
var _walk_active: bool = false
var _walk_target_x: float = 0.0
var _footstep_timer: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.position = Vector2(-FRAME_W / 2.0, -float(FRAME_H))
	add_child(_sprite)
	_update_region()


## looping=false 인 애니메이션(예: tip_hat)은 마지막 프레임에서 멈추고 gesture_finished 를 낸다.
func play(new_anim: Anim, looping: bool = true) -> void:
	anim = new_anim
	_frame = 0
	_frame_timer = 0.0
	_looping = looping
	_gesture_done = false
	_update_region()


## target_x(로컬 x, World 기준)까지 걸어간다. 도착하면 IDLE 로 바뀌고 arrived() 를 낸다.
func walk_to(target_x: float) -> void:
	facing_left = target_x < position.x
	_walk_target_x = target_x
	_walk_active = true
	_footstep_timer = 0.0
	play(Anim.WALK, true)


func is_walking() -> bool:
	return _walk_active


func _process(delta: float) -> void:
	if not _gesture_done:
		_frame_timer += delta
		var count: int = FRAME_COUNT[anim]
		while _frame_timer >= FRAME_TIME:
			_frame_timer -= FRAME_TIME
			_frame += 1
			if _frame >= count:
				if _looping:
					_frame = 0
				else:
					_frame = count - 1
					_gesture_done = true
					gesture_finished.emit()
					break
		_update_region()
	if _walk_active:
		var dir := signf(_walk_target_x - position.x)
		position.x += dir * WALK_SPEED * delta
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = FOOTSTEP_INTERVAL
			AudioManager.play_sfx("baron_footstep", randf_range(0.92, 1.08))
			AudioManager.play_sfx("baron_cane_tap", randf_range(0.92, 1.08), -4.0)
		var reached := (dir >= 0.0 and position.x >= _walk_target_x) or (dir < 0.0 and position.x <= _walk_target_x)
		if reached:
			position.x = _walk_target_x
			_walk_active = false
			play(Anim.IDLE, true)
			arrived.emit()


func _update_region() -> void:
	var row: int = ROW[anim]
	_sprite.region_rect = Rect2(_frame * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
	_sprite.flip_h = facing_left
