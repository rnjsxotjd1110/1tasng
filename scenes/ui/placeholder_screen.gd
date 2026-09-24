class_name PlaceholderScreen
extends Control
## 아직 없는 화면(업그레이드 3단계, 스킬트리 6단계, 설정 4단계)의 빈 화면. 제목·안내·닫기 버튼은 완성품 디자인.

signal close_requested()

var title_key: String = ""
var show_close: bool = true
var panel_variation: String = ""

var _panel: Panel


func setup(p_size: Vector2, p_title_key: String, p_show_close: bool, p_variation: String = "") -> void:
	size = p_size
	title_key = p_title_key
	show_close = p_show_close
	panel_variation = p_variation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = Panel.new()
	_panel.theme_type_variation = panel_variation
	_panel.size = size
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var title := Label.new()
	title.text = title_key
	title.theme_type_variation = "LabelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(size.x, 16)
	add_child(title)
	var line := HSeparator.new()
	line.position = Vector2(12, 26)
	line.size = Vector2(size.x - 24, 4)
	add_child(line)
	var lock := TextureRect.new()
	lock.texture = preload("res://assets/sprites/ui/icon_lock.png")
	lock.position = (Vector2(size.x * 0.5 - 3, size.y * 0.5 - 18)).round()
	add_child(lock)
	var body := Label.new()
	body.text = "COMING_SOON"
	body.theme_type_variation = "LabelMuted"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.position = Vector2(0, roundf(size.y * 0.5 - 4))
	body.size = Vector2(size.x, 14)
	add_child(body)
	if show_close:
		var close := Button.new()
		close.theme_type_variation = "ButtonDark"
		close.icon = preload("res://assets/sprites/ui/icon_close.png")
		close.focus_mode = Control.FOCUS_NONE
		close.size = Vector2(18, 18)
		close.position = Vector2(size.x - 24, 6)
		close.pressed.connect(func() -> void: close_requested.emit())
		add_child(close)
