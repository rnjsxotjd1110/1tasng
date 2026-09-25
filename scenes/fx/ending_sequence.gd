class_name EndingSequence
extends Control
## 엔딩 시퀀스(7단계, GDD 10장): 벨벳의 "마지막 한 판" 대사 → 최후의 스핀(8초) → 골드 웨이브·
## 화면 흔들림·코인비 → 양도 증서 서명 → 에필로그(벨벳·루시·남작) → 네온 간판 점등 → credits_ready.
## wheel·shaker·flash 는 Main 이 소유한 화면 전체 요소라 직접 참조를 주입받는다(다른 컷신은 신호로
## Main 에 넘기지만, 이 연출은 사실상 화면 전체를 쓰는 이펙트라 직접 참조가 더 단순하다).

signal credits_ready()

enum Phase {
	IDLE, DIM_IN, LAST_HAND, FINAL_SPIN, LANDING, GOLD_WAVE, AFTER_WAVE,
	SIGNING, SIGNED_WAIT, EPILOGUE_VELVET, EPILOGUE_LUCY, EPILOGUE_BARON, NEON_SIGN, NEON_HOLD,
}

const SCREEN := Vector2(640, 360)
const WHEEL_CENTER := Vector2(262, 192)
const WAVE_RADIUS := 83.0
const DIM_TIME := 0.6
const DIM_ALPHA := 0.6
const FINAL_SPIN_DURATION := 8.0
const LANDING_PAUSE_TIME := 1.0
const GOLD_WAVE_TIME := 1.2
const AFTER_WAVE_DELAY := 0.6
const NEON_HOLD_TIME := 2.0
const SHAKE_PX := 3
const SHAKE_TIME := 0.4
const COIN_BURSTS := 5
const AFTER_STAMP_DELAY := 0.7

var wheel: RouletteWheel
var shaker: ScreenShake
var flash: ScreenFlash

var dialogue: DialogueBox
var contract: ContractPopup
var velvet: MadameVelvet

var _dim: ColorRect
var _wave: Node2D
var _neon: NeonText

var _phase: Phase = Phase.IDLE
var _phase_time: float = 0.0


func _ready() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_dim = ColorRect.new()
	_dim.size = SCREEN
	_dim.color = Palette.with_alpha(Palette.VOID, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_wave = Node2D.new()
	_wave.draw.connect(_draw_wave)
	add_child(_wave)
	dialogue = DialogueBox.new()
	dialogue.finished.connect(_on_dialogue_finished)
	add_child(dialogue)
	contract = ContractPopup.new()
	contract.position = ((SCREEN - ContractPopup.SIZE) * 0.5).round()
	contract.signed.connect(_on_contract_signed)
	add_child(contract)
	_neon = NeonText.new()
	_neon.atlas = load("res://assets/sprites/fx/neon_pink.png")
	add_child(_neon)  # _ready() 가 여기서 돌며 _chars/_cell 을 채운다(그 전에는 text_width() 가 0).
	_neon.set_text_value("HOUSE EDGE", false)
	_neon.position = ((SCREEN - _neon.size) * 0.5).round()
	_neon.visible = false  # NEON_SIGN 단계 전까지는 꺼진 유리관조차 미리 보이지 않게 숨긴다(반전 효과).


func play() -> void:
	visible = true
	_dim.color = Palette.with_alpha(Palette.VOID, 0.0)
	AudioManager.play_sfx("bass_drop")
	AudioManager.play_music("bgm_ending")
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
				_set_phase(Phase.LAST_HAND)
				dialogue.say(DialogueData.pick("velvet_last_hand"))
		Phase.FINAL_SPIN:
			if wheel == null or not wheel.spinning:
				_set_phase(Phase.LANDING)
		Phase.LANDING:
			if _phase_time >= LANDING_PAUSE_TIME:
				_on_landing()
				_set_phase(Phase.GOLD_WAVE)
		Phase.GOLD_WAVE:
			_wave.queue_redraw()
			if _phase_time >= GOLD_WAVE_TIME:
				_set_phase(Phase.AFTER_WAVE)
		Phase.AFTER_WAVE:
			if _phase_time >= AFTER_WAVE_DELAY:
				_set_phase(Phase.SIGNING)
				contract.open_custom(tr("ENDING_DEED_TITLE"), tr("ENDING_DEED_LINE1"), tr("ENDING_DEED_LINE2"), tr("ENDING_DEED_LINE3"))
		Phase.SIGNED_WAIT:
			if _phase_time >= AFTER_STAMP_DELAY:
				contract.close()
				_set_phase(Phase.EPILOGUE_VELVET)
				dialogue.say(DialogueData.pick("velvet_epilogue"))
		Phase.NEON_SIGN:
			_neon.visible = true
			_neon.flicker_on()
			_set_phase(Phase.NEON_HOLD)
		Phase.NEON_HOLD:
			if _phase_time >= NEON_HOLD_TIME:
				visible = false
				credits_ready.emit()
		_:
			pass  # LAST_HAND/SIGNING/EPILOGUE_* 는 하위 신호로 넘어간다(아래 핸들러)


func _on_dialogue_finished() -> void:
	match _phase:
		Phase.LAST_HAND:
			_start_final_spin()
		Phase.EPILOGUE_VELVET:
			_set_phase(Phase.EPILOGUE_LUCY)
			dialogue.say(DialogueData.pick("epilogue_lucy"))
		Phase.EPILOGUE_LUCY:
			_set_phase(Phase.EPILOGUE_BARON)
			dialogue.say(DialogueData.pick("epilogue_baron"))
		Phase.EPILOGUE_BARON:
			_set_phase(Phase.NEON_SIGN)


func _start_final_spin() -> void:
	_set_phase(Phase.FINAL_SPIN)
	if wheel != null:
		var result := RngService.randi_range_misc(0, RouletteRules.POCKET_COUNT - 1)
		wheel.play_spin([result] as Array[int], FINAL_SPIN_DURATION)
	if velvet != null:
		velvet.play_gesture()


func _on_landing() -> void:
	if shaker != null:
		shaker.shake(SHAKE_PX, SHAKE_TIME)
	if flash != null:
		flash.flash()
	AudioManager.play_sfx("win_jackpot")
	for i in COIN_BURSTS:
		var pos := WHEEL_CENTER + Vector2(RngService.randf_range_misc(-60.0, 60.0), RngService.randf_range_misc(-30.0, 10.0))
		ParticleBurst.spawn(self, ParticleBurst.Kind.COINS, pos, 10)


func _draw_wave() -> void:
	var u := clampf(_phase_time / GOLD_WAVE_TIME, 0.0, 1.0)
	_wave.draw_arc(WHEEL_CENTER, WAVE_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * u, 64, Palette.GOLD_HL, 4.0)
	_wave.draw_arc(WHEEL_CENTER, WAVE_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * u, 64, Palette.with_alpha(Palette.GOLD_SHINE, 0.6), 1.0)


func _on_contract_signed() -> void:
	AudioManager.play_sfx("clover_get")
	_set_phase(Phase.SIGNED_WAIT)
