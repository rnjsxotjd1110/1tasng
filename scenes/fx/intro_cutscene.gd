class_name IntroCutscene
extends Control
## 새 게임 인트로 컷신(8단계 1/N, 스킵 가능): 비 내리는 골목 → 나무 구슬을 꺼낸다 → 카지노 문이 열리고
## 루시가 맞이한다. 수치를 바꾸지 않는 순수 연출(GameState.reset() 은 TitleScreen 이 먼저 끝내 둔다).

signal finished()

enum Phase { ALLEY, MARBLE, DOOR, DIALOGUE, DONE }

const SCREEN := Vector2(640, 360)
const ALLEY_DURATION := 4.0
const MARBLE_DURATION := 3.2
const DOOR_FADE := 0.6
const FIGURE_START_X := 40.0
const FIGURE_END_X := 300.0
const FIGURE_Y := 300.0
const LUCY_POSITION := Vector2(300, 306)
const MARBLE_ICON := preload("res://assets/sprites/marbles/marble_24.png")

var _phase: Phase = Phase.ALLEY
var _phase_time: float = 0.0
var _dim: ColorRect
var _figure: _WalkingFigure
var _caption: Label
var _marble_icon: TextureRect
var _lucy: LucyDealer
var _dialogue: DialogueBox
var _skip_button: Button
var _done: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Palette.VOID
	_dim.size = SCREEN
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.modulate.a = 0.0
	add_child(_dim)
	_figure = _WalkingFigure.new()
	_figure.position = Vector2(FIGURE_START_X, FIGURE_Y)
	_figure.visible = false
	add_child(_figure)
	_marble_icon = TextureRect.new()
	_marble_icon.texture = MARBLE_ICON
	_marble_icon.size = MARBLE_ICON.get_size()
	_marble_icon.position = ((SCREEN - _marble_icon.size) * 0.5).round()
	_marble_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marble_icon.visible = false
	_marble_icon.modulate.a = 0.0
	add_child(_marble_icon)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	_caption.position = Vector2(60, 300)
	_caption.size = Vector2(SCREEN.x - 120, 40)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_lucy = LucyDealer.new()
	_lucy.position = LUCY_POSITION
	_lucy.visible = false
	add_child(_lucy)
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(_on_dialogue_finished)
	_skip_button = Button.new()
	_skip_button.theme_type_variation = "ButtonDark"
	_skip_button.text = "INTRO_SKIP"
	_skip_button.size = Vector2(64, 18)
	_skip_button.position = Vector2(SCREEN.x - 72, 6)
	FocusStyle.apply(_skip_button)
	_skip_button.pressed.connect(skip)
	add_child(_skip_button)


func play() -> void:
	visible = true
	_done = false
	_phase = Phase.ALLEY
	_phase_time = 0.0
	_dim.modulate.a = 0.75
	_figure.visible = true
	_figure.position.x = FIGURE_START_X
	_caption.modulate.a = 1.0
	_caption.text = "INTRO_CAPTION_ALLEY"
	_skip_button.grab_focus()


## 나머지 연출을 건너뛰고 바로 끝낸다(대사창이 열려 있으면 함께 닫는다).
func skip() -> void:
	if _done:
		return
	_dialogue.visible = false
	_finish()


## 상태 전이는 전부 델타 누적(_phase_time)으로만 결정한다(트윈 콜백에 걸지 않는다) — 헤드리스
## 테스트에서 _process(dt) 를 직접 여러 번 불러 진행 상황을 그대로 재현할 수 있어야 하기 때문이다
## (7단계 EndingSequence/ElevatorCutscene 과 같은 원칙). 코스메틱 페이드는 create_tween() 을 써도 되지만,
## 페이드가 끝나야만 다음 단계로 넘어가는 흐름 제어에는 쓰지 않는다.
func _process(delta: float) -> void:
	if _done or not visible:
		return
	_phase_time += delta
	match _phase:
		Phase.ALLEY:
			var t: float = clampf(_phase_time / ALLEY_DURATION, 0.0, 1.0)
			_figure.position.x = roundf(lerpf(FIGURE_START_X, FIGURE_END_X, t))
			if _phase_time >= ALLEY_DURATION:
				_enter_marble_phase()
		Phase.MARBLE:
			if _phase_time >= MARBLE_DURATION:
				_enter_door_phase()
		Phase.DOOR:
			if _phase_time >= DOOR_FADE:
				_enter_dialogue_phase()
		Phase.DIALOGUE:
			pass


func _enter_marble_phase() -> void:
	_phase = Phase.MARBLE
	_phase_time = 0.0
	_caption.text = "INTRO_CAPTION_MARBLE"
	_marble_icon.visible = true
	_marble_icon.modulate.a = 1.0


func _enter_door_phase() -> void:
	_phase = Phase.DOOR
	_phase_time = 0.0
	_figure.visible = false
	_marble_icon.visible = false
	_caption.text = "INTRO_CAPTION_DOOR"
	create_tween().tween_property(_dim, "modulate:a", 0.35, DOOR_FADE)


func _enter_dialogue_phase() -> void:
	_phase = Phase.DIALOGUE
	_caption.modulate.a = 0.0
	_lucy.visible = true
	_dialogue.say(DialogueData.pick("intro_greeting"))


func _on_dialogue_finished() -> void:
	if _phase == Phase.DIALOGUE:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	visible = false
	finished.emit()


## 뒷모습 실루엣(절차적 — 새 스프라이트 없이 간단한 도형으로 표현).
class _WalkingFigure extends Control:
	var _bob: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(16, 40)

	func _process(delta: float) -> void:
		_bob += delta * 6.0
		queue_redraw()

	## 화면이 어두워도(_dim 알파 0.75) 또렷이 보이도록 ink 바탕 + mist 테두리(빗물에 젖어 반짝이는
	## 느낌)로 그린다 — void 하나만 쓰면 어두운 배경에 완전히 묻혀 버린다(캡처로 발견).
	func _draw() -> void:
		var hop := roundf(sin(_bob) * 1.0)
		var body := Rect2(2, 10 + hop, 12, 26)
		draw_rect(body, Palette.INK)
		draw_rect(body, Palette.MIST, false, 1.0)
		draw_circle(Vector2(8, 6 + hop), 6.0, Palette.INK)
		draw_arc(Vector2(8, 6 + hop), 6.0, 0.0, TAU, 16, Palette.MIST, 1.0)
