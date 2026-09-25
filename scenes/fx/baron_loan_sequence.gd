class_name BaronLoanSequence
extends Control
## 파산→대출 컷신 오케스트레이터(GDD 9장, ART_BIBLE 11장). Main 이 소유하고 play(event) 로 시작한다.
## 흐름: 화면 어둡게+저음 → 남작 walk-in → 대사(대출 횟수별) → 계약서 펼침 → 서명·도장 →
##       signed 신호(Main 이 이 시점에 칩 비행을 처리) → 남작 tip_hat → walk-out → finished.
## event = GameState.pending_baron_event: {"type":"loan","principal":float,"repay":float,"merged":bool}.

signal signed(principal: float, repay: float)
signal finished()

enum Phase { IDLE, DIM_IN, WALK_IN, DIALOGUE, CONTRACT, SIGNED_WAIT, TIP_HAT, TIP_WAIT, WALK_OUT, DIM_OUT }

const BARON_ENTER_X := 680.0
const BARON_STAND_X := 500.0
## 발 위치. DialogueBox 가 y 268~352 를 차지하므로 그 위(64px 스프라이트 + 여유 10px)에 서게 한다.
const BARON_Y := 258.0
const CONTRACT_POS := Vector2(190, 90)
const DIM_TIME := 0.5
const DIM_ALPHA := 0.45
const AFTER_STAMP_DELAY := 0.6
const AFTER_TIP_DELAY := 0.3

var baron: BaronRatchet
var dialogue: DialogueBox
var contract: ContractPopup

var _dim: ColorRect
var _event: Dictionary = {}
var _phase: Phase = Phase.IDLE
var _phase_time: float = 0.0


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_dim = ColorRect.new()
	_dim.size = size
	_dim.color = Palette.with_alpha(Palette.VOID, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	baron = BaronRatchet.new()
	baron.arrived.connect(_on_baron_arrived)
	baron.gesture_finished.connect(_on_gesture_finished)
	add_child(baron)
	dialogue = DialogueBox.new()
	dialogue.finished.connect(_on_dialogue_finished)
	add_child(dialogue)
	contract = ContractPopup.new()
	contract.position = CONTRACT_POS
	contract.signed.connect(_on_contract_signed)
	add_child(contract)


func play(event: Dictionary) -> void:
	_event = event
	visible = true
	baron.position = Vector2(BARON_ENTER_X, BARON_Y)
	baron.play(BaronRatchet.Anim.IDLE)
	AudioManager.play_sfx("bass_drop")
	AudioManager.duck_music(AudioManager.MUSIC_DUCK_BANKRUPT_DB, AudioManager.MUSIC_DUCK_BANKRUPT_ATTACK,
			AudioManager.MUSIC_DUCK_BANKRUPT_HOLD, AudioManager.MUSIC_DUCK_BANKRUPT_RELEASE)
	_set_phase(Phase.DIM_IN)


func is_playing() -> bool:
	return visible


## 대화 진행 중 클릭/Space 를 넘겨받는다(Main._unhandled_input 이 호출).
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
	match _phase:
		Phase.DIM_IN:
			var u := clampf(_phase_time / DIM_TIME, 0.0, 1.0)
			_dim.color = Palette.with_alpha(Palette.VOID, DIM_ALPHA * u)
			if u >= 1.0:
				baron.walk_to(BARON_STAND_X)
				_set_phase(Phase.WALK_IN)
		Phase.SIGNED_WAIT:
			if _phase_time >= AFTER_STAMP_DELAY:
				contract.close()
				baron.play(BaronRatchet.Anim.TIP_HAT, false)
				_set_phase(Phase.TIP_HAT)
		Phase.TIP_WAIT:
			if _phase_time >= AFTER_TIP_DELAY:
				baron.walk_to(BARON_ENTER_X)
				_set_phase(Phase.WALK_OUT)
		Phase.DIM_OUT:
			var u2 := clampf(_phase_time / DIM_TIME, 0.0, 1.0)
			_dim.color = Palette.with_alpha(Palette.VOID, DIM_ALPHA * (1.0 - u2))
			if u2 >= 1.0:
				visible = false
				finished.emit()
		_:
			pass  # WALK_IN/DIALOGUE/CONTRACT/TIP_HAT/WALK_OUT 는 하위 신호로 넘어간다(아래 핸들러)


func _on_baron_arrived() -> void:
	match _phase:
		Phase.WALK_IN:
			_set_phase(Phase.DIALOGUE)
			dialogue.say(_pick_line())
		Phase.WALK_OUT:
			_set_phase(Phase.DIM_OUT)


## 대출 횟수·합산 여부에 따라 대사 세트를 고른다(GDD 9장: 2·3번째 전용 대사, 4번째+ 합산 전용).
func _pick_line() -> Dictionary:
	var loans := GameState.get_stat_value(GameState.STAT_LOANS_TAKEN)
	if bool(_event.get("merged", false)):
		return DialogueData.pick("loan_overflow")
	if loans <= 1.0:
		return DialogueData.pick("loan_intro")
	if loans <= 2.0:
		return DialogueData.pick("loan_repeat_2nd")
	return DialogueData.pick("loan_repeat_3rd")


func _on_dialogue_finished() -> void:
	_set_phase(Phase.CONTRACT)
	contract.open(float(_event.get("principal", 0.0)), float(_event.get("repay", 0.0)))


func _on_contract_signed() -> void:
	signed.emit(float(_event.get("principal", 0.0)), float(_event.get("repay", 0.0)))
	_set_phase(Phase.SIGNED_WAIT)


func _on_gesture_finished() -> void:
	if _phase == Phase.TIP_HAT:
		_set_phase(Phase.TIP_WAIT)
