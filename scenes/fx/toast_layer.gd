class_name ToastLayer
extends Control
## 화면 구석 알림(EventBus.toast_requested). 오른쪽 위(상단 바 아래)에서 미끄러져 나와 잠시 뒤 사라진다.

## 휠 아래쪽 가운데(SPIN 버튼 위)에 나온다. 위에서 미끄러져 내려온다.
const CENTER_X := 262.0
const TOP := 286.0
const WIDTH := 150.0
const HEIGHT := 22.0
const GAP := 3.0
const STAY := 2.6
const SLIDE := 0.18
const MAX_TOASTS := 3

const ICONS := {
	"chip": preload("res://assets/sprites/ui/icon_chip.png"),
	"clover": preload("res://assets/sprites/ui/icon_clover.png"),
	"lock": preload("res://assets/sprites/ui/icon_lock.png"),
}

var _toasts: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 360)
	EventBus.toast_requested.connect(show_toast)


func show_toast(text: String, icon: String) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PanelPlain"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	if ICONS.has(icon):
		var image := TextureRect.new()
		image.texture = ICONS[icon]
		image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		box.add_child(image)
	var label := Label.new()
	label.theme_type_variation = "LabelSmall"
	label.text = text
	label.auto_translate = false
	box.add_child(label)
	add_child(panel)
	panel.reset_size()
	var toast_size := panel.get_combined_minimum_size()
	panel.size = toast_size
	_toasts.push_front({"node": panel, "time": 0.0, "width": toast_size.x})
	while _toasts.size() > MAX_TOASTS:
		var old: Dictionary = _toasts.pop_back()
		(old["node"] as Control).queue_free()
	AudioManager.play_sfx("panel_open")


func _process(delta: float) -> void:
	var y := TOP
	var expired: Array[Dictionary] = []
	for toast in _toasts:
		toast["time"] = float(toast["time"]) + delta
		var panel: Control = toast["node"]
		var t := float(toast["time"])
		var slide_in := clampf(t / SLIDE, 0.0, 1.0)
		var slide_out := clampf((t - STAY) / SLIDE, 0.0, 1.0)
		var width := float(toast["width"])
		var shown := (1.0 - (1.0 - slide_in) * (1.0 - slide_in)) * (1.0 - slide_out)
		panel.position = Vector2(roundf(CENTER_X - width * 0.5), roundf(y - (1.0 - shown) * 8.0))
		panel.modulate.a = shown
		y -= panel.size.y + GAP
		if t > STAY + SLIDE:
			expired.append(toast)
	for toast in expired:
		_toasts.erase(toast)
		(toast["node"] as Control).queue_free()
