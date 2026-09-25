class_name MadameVelvet
extends Node2D
## 마담 벨벳 월드 액터(7단계, ART_BIBLE 13장 예정). 펜트하우스에서 항상 대기하며 와인잔을 홀짝이거나
## 손짓·박수를 보인다. 로직 없음 — 연출 전용. 좌표는 World 2D 공간(640×360) 기준, 피벗은 발바닥 중앙.

enum Anim { IDLE, WINE, GESTURE, CLAP }

const ROW := {Anim.IDLE: 0, Anim.WINE: 1, Anim.GESTURE: 2, Anim.CLAP: 3}
const FRAME_COUNT := {Anim.IDLE: 4, Anim.WINE: 3, Anim.GESTURE: 4, Anim.CLAP: 4}
const FRAME_W := 48
const FRAME_H := 72
const SHEET := preload("res://assets/sprites/npc/velvet_world.png")
const FRAME_TIME := 0.14
const GESTURE_FRAME_TIME := 0.1

var anim: Anim = Anim.IDLE

var _sprite: Sprite2D
var _frame: int = 0
var _frame_timer: float = 0.0
var _looping: bool = true
var _gesture_done: bool = false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.position = Vector2(-FRAME_W / 2.0, -float(FRAME_H))
	add_child(_sprite)
	_update_region()


## looping=false 인 제스처(와인잔·손짓·박수)는 마지막 프레임에서 멈췄다가 idle 로 돌아온다.
func play(new_anim: Anim, looping: bool = true) -> void:
	anim = new_anim
	_frame = 0
	_frame_timer = 0.0
	_looping = looping
	_gesture_done = false
	_update_region()


func play_wine() -> void:
	play(Anim.WINE, false)


func play_gesture() -> void:
	play(Anim.GESTURE, false)


func play_clap() -> void:
	play(Anim.CLAP, false)


func _process(delta: float) -> void:
	if _gesture_done:
		return
	_frame_timer += delta
	var frame_time := FRAME_TIME if _looping else GESTURE_FRAME_TIME
	var count: int = FRAME_COUNT[anim]
	while _frame_timer >= frame_time:
		_frame_timer -= frame_time
		_frame += 1
		if _frame >= count:
			if _looping:
				_frame = 0
			else:
				_frame = count - 1
				_gesture_done = true
				play(Anim.IDLE, true)
				break
	_update_region()


func _update_region() -> void:
	var row: int = ROW[anim]
	_sprite.region_rect = Rect2(_frame * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
