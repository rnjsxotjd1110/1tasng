class_name CreditsScreen
extends Control
## 크레딧 화면(8단계 1/N 초안, 스팀 준비 5/N 에서 폰트·엔진 크레딧 채움).
## 8단계 마무리: 배경음악 9곡(Kevin MacLeod, incompetech.com, CC BY 4.0) 크레딧을 추가하면서 목록이 고정
## 한 줄씩 배치로는 넘치게 돼, 업적 화면과 같은 ScrollContainer+VBoxContainer 패턴으로 바꿨다.

signal close_requested()

const SIZE := Vector2(640, 336)
const LIST_MARGIN := Vector2(16, 30)
const LIST_SIZE := Vector2(608, 298)
const ROW_SEPARATION := 6
const SECTION_GAP := 12

const MUSIC_TRACK_KEYS: Array[String] = [
	"CREDITS_MUSIC_01", "CREDITS_MUSIC_02", "CREDITS_MUSIC_03", "CREDITS_MUSIC_04",
	"CREDITS_MUSIC_05", "CREDITS_MUSIC_06", "CREDITS_MUSIC_07", "CREDITS_MUSIC_08",
	"CREDITS_MUSIC_09",
]

var _list: VBoxContainer


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

	var scroll := ScrollContainer.new()
	scroll.position = LIST_MARGIN
	scroll.size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(LIST_SIZE.x, 0)
	_list.add_theme_constant_override("separation", ROW_SEPARATION)
	scroll.add_child(_list)

	_row("CREDITS_DEVELOPER", [Economy.STUDIO_NAME])
	_row("CREDITS_ENGINE", [])
	_row("CREDITS_FONT", [])
	_spacer()
	_row("CREDITS_MUSIC_HEADER", [])
	for key in MUSIC_TRACK_KEYS:
		_row(key, [])
	_row("CREDITS_MUSIC_LICENSE", [])
	_row("CREDITS_MUSIC_LICENSE_URL", [])


func _row(key: String, args: Array) -> void:
	var label := Label.new()
	label.text = (tr(key) % args) if not args.is_empty() else key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_list.add_child(label)


func _spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, SECTION_GAP)
	_list.add_child(spacer)
