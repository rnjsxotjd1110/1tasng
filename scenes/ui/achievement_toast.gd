class_name AchievementToast
extends Control
## 업적 해금 토스트(7단계, GDD 10-3): 화면 우하단에 아이콘+이름을 금색 패널(BadgeGolden)로
## 0.3초 슬라이드인, 4초 유지 후 슬라이드아웃. 한 프레임에 여러 개가 풀리면 큐에 쌓아 하나씩 보여준다.

const SCREEN := Vector2(640, 360)
const MARGIN := Vector2(8, 8)
const ICON_SIZE := 24
const SLIDE_TIME := 0.3
const HOLD_TIME := 4.0
const FADE_OUT_TIME := 0.2

enum Phase { IDLE, IN, HOLD, OUT }

var _queue: Array[String] = []
var _panel: PanelContainer
var _icon: TextureRect
var _label: Label
var _phase: Phase = Phase.IDLE
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "BadgeGolden"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_panel.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(_icon)
	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	row.add_child(text_col)
	var title := Label.new()
	title.theme_type_variation = "LabelSmallMuted"
	title.text = "ACH_TOAST_TITLE"
	text_col.add_child(title)
	_label = Label.new()
	_label.theme_type_variation = "LabelBold"
	text_col.add_child(_label)
	EventBus.achievement_unlocked.connect(_on_unlocked)


func _on_unlocked(id: String) -> void:
	_queue.append(id)


func _process(delta: float) -> void:
	match _phase:
		Phase.IDLE:
			if not _queue.is_empty():
				_start_next()
		Phase.IN:
			_time += delta
			var u := clampf(_time / SLIDE_TIME, 0.0, 1.0)
			_layout(1.0 - pow(1.0 - u, 3.0))
			if u >= 1.0:
				_phase = Phase.HOLD
				_time = 0.0
		Phase.HOLD:
			_time += delta
			if _time >= HOLD_TIME:
				_phase = Phase.OUT
				_time = 0.0
		Phase.OUT:
			_time += delta
			var u_out := clampf(_time / FADE_OUT_TIME, 0.0, 1.0)
			_layout(1.0 - u_out)
			if u_out >= 1.0:
				_panel.visible = false
				_phase = Phase.IDLE


func _start_next() -> void:
	var id: String = _queue.pop_front()
	var def := AchievementData.get_def(id)
	var icon_id := String(def.get("icon", id))
	var icon_path := "res://assets/sprites/ui/achievements/icon_%s.png" % icon_id
	_icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	_label.text = tr(String(def.get("name_key", "")))
	_panel.reset_size()
	_panel.size = _panel.get_combined_minimum_size()
	_panel.visible = true
	AudioManager.play_sfx("achievement_unlock")
	_phase = Phase.IN
	_time = 0.0
	_layout(0.0)


## u: 0=화면 밖(오른쪽), 1=고정 위치.
func _layout(u: float) -> void:
	var target_x := SCREEN.x - MARGIN.x - _panel.size.x
	var x := lerpf(SCREEN.x, target_x, u)
	_panel.position = Vector2(roundf(x), roundf(SCREEN.y - MARGIN.y - _panel.size.y))
	_panel.modulate.a = u
