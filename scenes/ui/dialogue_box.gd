class_name DialogueBox
extends Control
## 재사용 가능한 대사창(하단 중앙, ART_BIBLE 11-3). 루시·벨벳(8단계 이후)도 같은 컴포넌트를 쓴다.
## 사용: say(entry) 로 한 화자의 대사를(여러 줄이면 순서대로), ask(entry, choice_keys) 로 마지막에 선택지를 보여준다.
## entry = DialogueData.pick() 의 결과 {"speaker": 번역키, "portrait": 표정id, "lines": [번역키...]}.
## 클릭·Space 는 advance() 로 받는다(Main 이 입력을 넘겨준다).

signal finished()
signal choice_made(index: int)

const SIZE := Vector2(616, 84)
const POS := Vector2(12, 268)
const PORTRAIT_SIZE := Vector2(64, 64)
const PORTRAIT_POS := Vector2(8, 8)
const TEXT_POS := Vector2(80, 24)
const TEXT_SIZE := Vector2(520, 50)
const NAME_POS := Vector2(80, 8)
const CHARS_PER_SECOND := 30.0
const PAUSE_COMMA := 0.12
const PAUSE_STOP := 0.25
const BLIP_EVERY_CHARS := 2
const BLIP_PITCH_MIN := 0.85
const BLIP_PITCH_MAX := 1.15
const ARROW_BOB_PERIOD := 0.5
const ARROW_BOB_PX := 2
const COMMA_CHARS := [",", "，"]
const STOP_CHARS := [".", "!", "?", "…"]

## 초상화 프레임 순서(ART_BIBLE 11-1/11-3): 0 기본 1 웃음 2 교활한 미소/윙크 3 놀람 4 만족 5·6 입벙긋.
const PORTRAIT_FRAME_INDEX := {"neutral": 0, "smile": 0, "laugh": 1, "sly": 2, "surprised": 3, "satisfied": 4}
const LUCY_PORTRAIT_FRAME_INDEX := {"neutral": 0, "smile": 0, "laugh": 1, "wink": 2, "surprised": 3, "satisfied": 4}
const TALK_FRAMES := [5, 6]
const PORTRAIT_FRAME_SIZE := 64
## 화자 번역 키 → (초상화 시트, 프레임 순서, 목소리 '삑' 효과음 id). 새 화자를 추가할 때 여기에 등록한다.
const SPEAKERS := {
	"NPC_RATCHET": {"sheet": "res://assets/sprites/npc/baron_portrait.png", "frames": PORTRAIT_FRAME_INDEX, "voice": "dialogue_blip_baron"},
	"NPC_LUCY": {"sheet": "res://assets/sprites/npc/lucy_portrait.png", "frames": LUCY_PORTRAIT_FRAME_INDEX, "voice": "dialogue_blip_lucy"},
}

var _panel: Panel
var _portrait: TextureRect
var _portrait_atlas: AtlasTexture
var _name_label: Label
var _text_label: Label
var _arrow: Label
var _choice_box: VBoxContainer

var _lines: Array[String] = []
var _line_index: int = -1
var _portrait_frame: int = 0
var _voice_id: String = ""
var _pending_choices: Array[String] = []
var _typing: bool = false
var _waiting_for_choice: bool = false
var _char_accum: float = 0.0
var _pause_left: float = 0.0
var _talk_toggle: bool = false
var _arrow_time: float = 0.0
var _sheet_cache: Dictionary = {}


func _ready() -> void:
	position = POS
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel = Panel.new()
	_panel.theme_type_variation = "PanelFelt"
	_panel.size = SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_portrait_atlas = AtlasTexture.new()
	_portrait = TextureRect.new()
	_portrait.texture = _portrait_atlas
	_portrait.position = PORTRAIT_POS
	_portrait.size = PORTRAIT_SIZE
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	_name_label = Label.new()
	_name_label.theme_type_variation = "LabelBold"
	_name_label.position = NAME_POS
	_name_label.size = Vector2(TEXT_SIZE.x, 14)
	add_child(_name_label)
	_text_label = Label.new()
	_text_label.position = TEXT_POS
	_text_label.size = TEXT_SIZE
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text_label.visible_characters = 0
	add_child(_text_label)
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.theme_type_variation = "LabelGold"
	_arrow.position = Vector2(SIZE.x - 20, SIZE.y - 16)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	add_child(_arrow)
	_choice_box = VBoxContainer.new()
	_choice_box.position = Vector2(TEXT_POS.x, TEXT_POS.y + 8)
	_choice_box.add_theme_constant_override("separation", 2)
	_choice_box.visible = false
	add_child(_choice_box)


## entry 의 대사를 순서대로 보여주고 끝나면 finished() 를 발행한다.
func say(entry: Dictionary) -> void:
	ask(entry, [])


## entry 의 대사가 끝난 뒤 choice_keys(번역 키)로 선택지를 보여준다. 고르면 choice_made(index) 후 finished().
func ask(entry: Dictionary, choice_keys: Array[String]) -> void:
	var speaker_key := String(entry.get("speaker", ""))
	var info: Dictionary = SPEAKERS.get(speaker_key, SPEAKERS["NPC_RATCHET"])
	_portrait_atlas.atlas = _load_sheet(String(info["sheet"]))
	_portrait_frame = (info["frames"] as Dictionary).get(String(entry.get("portrait", "neutral")), 0)
	_voice_id = String(info["voice"])
	_lines = []
	for key in entry.get("lines", []):
		_lines.append(tr(String(key)))
	_name_label.text = tr(speaker_key)
	_pending_choices = choice_keys
	_line_index = -1
	_waiting_for_choice = false
	visible = true
	_next_line()


## 클릭·Space. 타이핑 중이면 즉시 완성, 완성 상태면 다음 줄(또는 선택지 중이면 무시 — 버튼으로 고른다).
func advance() -> void:
	if not visible or _waiting_for_choice:
		return
	if _typing:
		_text_label.visible_characters = _text_label.text.length()
		_typing = false
		_arrow.visible = true
		_set_portrait_frame(_portrait_frame)
	else:
		_next_line()


func is_open() -> bool:
	return visible


func _load_sheet(path: String) -> Texture2D:
	if not _sheet_cache.has(path):
		_sheet_cache[path] = load(path)
	return _sheet_cache[path]


func _next_line() -> void:
	_line_index += 1
	_arrow.visible = false
	if _line_index >= _lines.size():
		if not _pending_choices.is_empty():
			_show_choices()
		else:
			_finish()
		return
	_text_label.text = _lines[_line_index]
	_text_label.visible_characters = 0
	_char_accum = 0.0
	_pause_left = 0.0
	_talk_toggle = false
	_typing = true
	_set_portrait_frame(TALK_FRAMES[0])


func _show_choices() -> void:
	_waiting_for_choice = true
	for child in _choice_box.get_children():
		child.queue_free()
	for i in _pending_choices.size():
		var button := Button.new()
		button.theme_type_variation = "ButtonGold"
		button.custom_minimum_size = Vector2(160, 18)
		button.text = tr(_pending_choices[i])
		button.pressed.connect(_on_choice_pressed.bind(i))
		_choice_box.add_child(button)
	_choice_box.visible = true


func _on_choice_pressed(index: int) -> void:
	_choice_box.visible = false
	_waiting_for_choice = false
	choice_made.emit(index)
	_finish()


func _finish() -> void:
	visible = false
	finished.emit()


func _set_portrait_frame(frame: int) -> void:
	_portrait_atlas.region = Rect2(frame * PORTRAIT_FRAME_SIZE, 0, PORTRAIT_FRAME_SIZE, PORTRAIT_FRAME_SIZE)


func _process(delta: float) -> void:
	if not visible:
		return
	if _arrow.visible:
		_arrow.position.y = SIZE.y - 16 + roundf(sin(_arrow_time * TAU / ARROW_BOB_PERIOD) * ARROW_BOB_PX)
		_arrow_time += delta
	if not _typing:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	_char_accum += delta * CHARS_PER_SECOND
	var full := _text_label.text
	var shown := _text_label.visible_characters
	while shown < full.length() and _char_accum >= 1.0:
		_char_accum -= 1.0
		shown += 1
		var revealed := full[shown - 1]
		if revealed != " ":
			if shown % BLIP_EVERY_CHARS == 0 and _voice_id != "":
				AudioManager.play_sfx(_voice_id, randf_range(BLIP_PITCH_MIN, BLIP_PITCH_MAX))
			_talk_toggle = not _talk_toggle
			_set_portrait_frame(TALK_FRAMES[1] if _talk_toggle else TALK_FRAMES[0])
		if COMMA_CHARS.has(revealed):
			_pause_left = PAUSE_COMMA
		elif STOP_CHARS.has(revealed):
			_pause_left = PAUSE_STOP
	_text_label.visible_characters = shown
	if shown >= full.length():
		_typing = false
		_arrow.visible = true
		_arrow_time = 0.0
		_set_portrait_frame(_portrait_frame)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		advance()
		accept_event()
