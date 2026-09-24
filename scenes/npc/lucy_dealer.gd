class_name LucyDealer
extends Node2D
## 딜러 루시 월드 액터(6단계, ART_BIBLE 11-3 예정). 휠 왼쪽에 서서 매 스핀마다 공을 던지는 시늉을 하고,
## 큰 승리에는 박수를, 핫 넘버에는 손가락으로 가리키는 시늉을 한다. 로직 없음 — 연출 전용.
## 좌표는 World 2D 공간(640×360) 기준, 피벗은 발바닥 중앙(BaronRatchet 과 동일 규칙).

enum Anim { IDLE, SPIN_LAUNCH, CLAP, POINT }

const ROW := {Anim.IDLE: 0, Anim.SPIN_LAUNCH: 1, Anim.CLAP: 2, Anim.POINT: 3}
const FRAME_COUNT := {Anim.IDLE: 4, Anim.SPIN_LAUNCH: 4, Anim.CLAP: 4, Anim.POINT: 3}
const FRAME_W := 40
const FRAME_H := 56
const SHEET := preload("res://assets/sprites/npc/lucy_world.png")
const FRAME_TIME := 0.12
const GESTURE_FRAME_TIME := 0.09

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


## looping=false 인 제스처(던지기·박수·가리키기)는 마지막 프레임에서 멈췄다가 idle 로 돌아온다.
func play(new_anim: Anim, looping: bool = true) -> void:
	anim = new_anim
	_frame = 0
	_frame_timer = 0.0
	_looping = looping
	_gesture_done = false
	_update_region()


## 스핀 시작마다 부른다: 공을 던지는 시늉을 한 번 하고 idle 로 돌아온다.
func play_spin_launch() -> void:
	play(Anim.SPIN_LAUNCH, false)


func play_clap() -> void:
	play(Anim.CLAP, false)


func play_point() -> void:
	play(Anim.POINT, false)


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
