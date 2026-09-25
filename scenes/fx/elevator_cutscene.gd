class_name ElevatorCutscene
extends Control
## 층 이동 전환 컷신(7단계, ART_BIBLE 12장, 3~4초, 스킵 가능). Main 이 소유하고 play(from_id, to_id) 로 시작한다.
## 수치(칩 소모·floor_index·클로버)는 FloorService.move_to_next() 가 컷신 시작 "전"에 이미 끝내 둔다
## (5단계 남작 컷신과 같은 원칙 — 컷신은 결과를 보여주기만 한다).
## 흐름: 문 닫힘(가운데 빛샘) → 층 표시등 딸깍 → '띵' + 문 열림 → 타이틀 카드 좌→우 → clover_moment.

## 문이 다 닫혔다: Main 이 이 순간 FloorService.move_to_next() 를 불러 배경·휠 스킨을 문 뒤에서 바꾼다.
signal doors_closed()
signal clover_moment()
signal finished()

enum Phase { CLOSE, TICK, OPEN, TITLE, HOLD, DONE }

const DOOR_CLOSE_TIME := 0.6
const TICK_TIME := 0.8
const TICK_COUNT := 3
const DOOR_OPEN_TIME := 0.6
const TITLE_TIME := 0.6
const HOLD_TIME := 0.7
const DOOR_COLOR := Palette.INK
const DOOR_SEAM := Palette.GOLD_HL

var _from_id: String = "b1"
var _to_id: String = ""
var _to_name_key: String = ""
var _phase: Phase = Phase.DONE
var _phase_time: float = 0.0
var _tick_index: int = 0
var _left_door: ColorRect
var _right_door: ColorRect
var _seam: ColorRect
var _doors_closed_emitted: bool = false
var _clover_emitted: bool = false
var _floor_label: Label
var _title_label: Label
var _title_clip: Control
var _title_width: float = 0.0


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var backdrop := ColorRect.new()
	backdrop.size = size
	backdrop.color = Palette.VOID
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_left_door = ColorRect.new()
	_left_door.color = DOOR_COLOR
	_left_door.size = Vector2(320, 360)
	_left_door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left_door)
	_right_door = ColorRect.new()
	_right_door.color = DOOR_COLOR
	_right_door.size = Vector2(320, 360)
	_right_door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right_door)
	_seam = ColorRect.new()
	_seam.color = DOOR_SEAM
	_seam.size = Vector2(2, 360)
	_seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_seam)
	_floor_label = Label.new()
	_floor_label.theme_type_variation = "Num14Gold"
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_floor_label.size = size
	_floor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_label.visible = false
	add_child(_floor_label)
	_title_clip = Control.new()
	_title_clip.clip_contents = true
	_title_clip.position = Vector2(0, 168)
	_title_clip.size = Vector2(0, 24)
	_title_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_clip)
	_title_label = Label.new()
	_title_label.theme_type_variation = "LabelTitle"
	_title_clip.add_child(_title_label)


func play(from_id: String, to_id: String, to_name_key: String) -> void:
	_from_id = from_id
	_to_id = to_id
	_to_name_key = to_name_key
	visible = true
	_left_door.position = Vector2(-320, 0)
	_right_door.position = Vector2(640, 0)
	_seam.position = Vector2(319, 0)
	_seam.visible = false
	_floor_label.visible = false
	_title_label.text = tr(to_name_key)
	_title_width = _title_label.get_minimum_size().x
	_title_clip.position.x = roundf((size.x - _title_width) * 0.5)
	_title_clip.size.x = 0
	_tick_index = 0
	_doors_closed_emitted = false
	_clover_emitted = false
	_set_phase(Phase.CLOSE)


func is_playing() -> bool:
	return visible


## 클릭·Space 로 즉시 끝낸다(스킵). 아직 안 낸 신호(문 닫힘·클로버)는 순서대로 한 번에 낸 뒤 끝낸다
## (FloorService.move_to_next() 호출이 doors_closed 에 달려 있으므로 스킵해도 반드시 나가야 한다).
func skip() -> void:
	if not visible:
		return
	if not _doors_closed_emitted:
		_doors_closed_emitted = true
		doors_closed.emit()
	if not _clover_emitted:
		_clover_emitted = true
		clover_moment.emit()
	_finish()


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_phase_time += delta
	match _phase:
		Phase.CLOSE:
			var u := clampf(_phase_time / DOOR_CLOSE_TIME, 0.0, 1.0)
			_left_door.position.x = roundf(lerpf(-320.0, 0.0, u))
			_right_door.position.x = roundf(lerpf(640.0, 320.0, u))
			_seam.visible = u < 1.0
			_seam.position.x = roundf(lerpf(-1.0, 319.0, u))
			if u >= 1.0:
				_floor_label.visible = true
				_floor_label.text = _from_id.to_upper()
				AudioManager.play_sfx("panel_close")
				_doors_closed_emitted = true
				doors_closed.emit()
				_set_phase(Phase.TICK)
		Phase.TICK:
			if _phase_time >= TICK_TIME / TICK_COUNT:
				_phase_time = 0.0
				_tick_index += 1
				AudioManager.play_sfx("chip_click")
				if _tick_index >= TICK_COUNT:
					_floor_label.text = _to_id.to_upper()
					_set_phase(Phase.OPEN)
				else:
					_floor_label.visible = _tick_index % 2 == 0
		Phase.OPEN:
			if _phase_time < delta * 1.5:
				AudioManager.play_sfx("clover_get")
			var u := clampf(_phase_time / DOOR_OPEN_TIME, 0.0, 1.0)
			_left_door.position.x = roundf(lerpf(0.0, -320.0, u))
			_right_door.position.x = roundf(lerpf(320.0, 640.0, u))
			if u >= 1.0:
				_floor_label.visible = false
				_set_phase(Phase.TITLE)
		Phase.TITLE:
			var u := clampf(_phase_time / TITLE_TIME, 0.0, 1.0)
			_title_clip.size.x = roundf(_title_width * u)
			if u >= 1.0:
				_clover_emitted = true
				clover_moment.emit()
				_set_phase(Phase.HOLD)
		Phase.HOLD:
			if _phase_time >= HOLD_TIME:
				_finish()
		_:
			pass


func _finish() -> void:
	visible = false
	_set_phase(Phase.DONE)
	finished.emit()
