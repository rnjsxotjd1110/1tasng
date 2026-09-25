class_name CreditsScreen
extends Control
## 크레딧 화면(8단계 1/N 초안, 타이틀 메뉴 전용). 스팀 출시 준비(5/N)에서 폰트·엔진·음원 출처를 마저 채운다.

signal close_requested()

const SIZE := Vector2(640, 336)
const LIST_POS := Vector2(0, 60)
const LIST_WIDTH := 480.0
const ROW_HEIGHT := 22.0


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.theme_type_variation = "PanelPlain"
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := Label.new()
	title.text = "CREDITS_TITLE"
	title.theme_type_variation = "LabelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(SIZE.x, 16)
	add_child(title)
	var close := Button.new()
	close.theme_type_variation = "ButtonDark"
	close.icon = preload("res://assets/sprites/ui/icon_close.png")
	close.size = Vector2(18, 18)
	close.position = Vector2(SIZE.x - 26, 6)
	FocusStyle.apply(close)
	close.pressed.connect(func() -> void: close_requested.emit())
	add_child(close)
	var y := LIST_POS.y
	y = _row("CREDITS_DEVELOPER", [Economy.STUDIO_NAME], y)
	y = _row("CREDITS_ENGINE", [], y)
	y = _row("CREDITS_FONT", [], y)
	y += ROW_HEIGHT * 0.5
	y = _row("CREDITS_MUSIC_PENDING", [], y)


func _row(key: String, args: Array, y: float) -> float:
	var label := Label.new()
	label.text = (tr(key) % args) if not args.is_empty() else key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.position = Vector2((SIZE.x - LIST_WIDTH) * 0.5, y)
	label.size = Vector2(LIST_WIDTH, ROW_HEIGHT)
	add_child(label)
	return y + ROW_HEIGHT
