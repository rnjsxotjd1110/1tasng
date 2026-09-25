class_name BaronPayoffSequence
extends Control
## 빚 완납 컷신(GDD 9장 6번, ART_BIBLE 11장). Main 이 소유하고 play() 로 시작한다.
## 흐름: 남작 walk-in → 대사(랜덤) → tip_hat → clover_moment 신호(Main 이 클로버 비행 처리) → walk-out → finished.
## 통계·패널티 해제·클로버 +2 지급은 이미 GameState._on_debt_fully_paid() 에서 즉시 끝나 있다 — 여기는 연출만.

signal clover_moment()
signal finished()

enum Phase { IDLE, WALK_IN, DIALOGUE, TIP_HAT, CLOVER_WAIT, WALK_OUT, DONE }

const BARON_ENTER_X := 680.0
const BARON_STAND_X := 500.0
## 발 위치. DialogueBox 가 y 268~352 를 차지하므로 그 위(64px 스프라이트 + 여유 10px)에 서게 한다.
const BARON_Y := 258.0
const AFTER_CLOVER_DELAY := 0.4

var baron: BaronRatchet
var dialogue: DialogueBox

var _phase: Phase = Phase.IDLE
var _phase_time: float = 0.0


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	baron = BaronRatchet.new()
	baron.arrived.connect(_on_baron_arrived)
	baron.gesture_finished.connect(_on_gesture_finished)
	add_child(baron)
	dialogue = DialogueBox.new()
	dialogue.finished.connect(_on_dialogue_finished)
	add_child(dialogue)


func play() -> void:
	visible = true
	baron.position = Vector2(BARON_ENTER_X, BARON_Y)
	baron.walk_to(BARON_STAND_X)
	_set_phase(Phase.WALK_IN)


func is_playing() -> bool:
	return visible


func advance_input() -> void:
	if dialogue.is_open():
		dialogue.advance()


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_phase_time += delta
	if _phase == Phase.CLOVER_WAIT and _phase_time >= AFTER_CLOVER_DELAY:
		baron.walk_to(BARON_ENTER_X)
		_set_phase(Phase.WALK_OUT)


func _on_baron_arrived() -> void:
	match _phase:
		Phase.WALK_IN:
			_set_phase(Phase.DIALOGUE)
			dialogue.say(DialogueData.pick("debt_paid"))
		Phase.WALK_OUT:
			visible = false
			_set_phase(Phase.DONE)
			finished.emit()


func _on_dialogue_finished() -> void:
	_set_phase(Phase.TIP_HAT)
	baron.play(BaronRatchet.Anim.TIP_HAT, false)


func _on_gesture_finished() -> void:
	if _phase == Phase.TIP_HAT:
		clover_moment.emit()
		_set_phase(Phase.CLOVER_WAIT)
