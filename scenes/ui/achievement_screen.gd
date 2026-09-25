class_name AchievementScreen
extends Control
## 업적 목록 화면(7단계). 일시정지 메뉴에서만 연다(640×336, 통계 화면과 같은 자리).
## data/achievements.json 카테고리 순서대로 묶어서 아이콘 그리드로 보여준다.

signal close_requested()

const SIZE := Vector2(640, 336)
const GRID_COLUMNS := 10
const GRID_SEPARATION := 4
const LIST_MARGIN := Vector2(16, 40)
const LIST_SIZE := Vector2(608, 280)

const CATEGORY_ORDER: Array[String] = ["basic", "debt", "progress", "collection", "feature", "cumulative", "hidden"]
const CATEGORY_LABEL_KEYS := {
	"basic": "ACH_CATEGORY_BASIC",
	"debt": "ACH_CATEGORY_DEBT",
	"progress": "ACH_CATEGORY_PROGRESS",
	"collection": "ACH_CATEGORY_COLLECTION",
	"feature": "ACH_CATEGORY_FEATURE",
	"cumulative": "ACH_CATEGORY_CUMULATIVE",
	"hidden": "ACH_CATEGORY_HIDDEN",
}

var _progress_label: Label
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
	title.text = "ACH_SCREEN_TITLE"
	title.theme_type_variation = "LabelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(SIZE.x, 16)
	add_child(title)
	_progress_label = Label.new()
	_progress_label.theme_type_variation = "LabelGold"
	_progress_label.position = Vector2(16, 10)
	add_child(_progress_label)
	var line := HSeparator.new()
	line.position = Vector2(12, 27)
	line.size = Vector2(SIZE.x - 24, 4)
	add_child(line)
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
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)


func _build_categories() -> void:
	var by_category: Dictionary = {}
	for def: Dictionary in AchievementData.all():
		var category := String(def.get("category", ""))
		var list: Array = by_category.get(category, [])
		list.append(def)
		by_category[category] = list
	for category in CATEGORY_ORDER:
		if not by_category.has(category):
			continue
		var header := Label.new()
		header.theme_type_variation = "LabelBold"
		header.text = String(CATEGORY_LABEL_KEYS[category])
		_list.add_child(header)
		var grid := GridContainer.new()
		grid.columns = GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
		grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
		_list.add_child(grid)
		for def: Dictionary in by_category[category]:
			var slot := AchievementSlot.new()
			grid.add_child(slot)
			slot.setup(def, GameState.unlocked_achievements.has(String(def.get("id", ""))))


## 열 때마다 호출: 해금 상태가 바뀌었을 수 있어 슬롯을 다시 채운다.
func refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	_build_categories()
	var total := AchievementData.all().size()
	var unlocked := GameState.unlocked_achievements.size()
	_progress_label.text = "%s / %s" % [NumberFormat.format(float(unlocked)), NumberFormat.format(float(total))]
