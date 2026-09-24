class_name StatsScreen
extends Control
## 통계 화면(4단계). 일시정지 메뉴에서만 연다(640×336, 스킬트리와 같은 자리). 숫자는 카운트업으로 보여준다.

signal close_requested()

const SIZE := Vector2(640, 336)
const LIST_POS := Vector2(64, 40)
const LABEL_WIDTH := 220.0
const ROW_SEPARATION := 14

var _play_time_label: Label
var _win_rate_label: Label
var _most_frequent_label: Label
var _count_labels: Dictionary = {}


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.theme_type_variation = "PanelPlain"
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := Label.new()
	title.text = "STATS_TITLE"
	title.theme_type_variation = "LabelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(SIZE.x, 16)
	add_child(title)
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

	var list := VBoxContainer.new()
	list.position = LIST_POS
	list.add_theme_constant_override("separation", ROW_SEPARATION)
	add_child(list)

	_play_time_label = _plain_row(list, "STATS_PLAY_TIME")
	_add_count_row(list, "STATS_TOTAL_SPINS")
	_win_rate_label = _plain_row(list, "STATS_WIN_RATE")
	_add_count_row(list, "STATS_BIGGEST_WIN")
	_add_count_row(list, "STATS_BEST_STREAK")
	_add_count_row(list, "STATS_STRAIGHT_HITS")
	_add_count_row(list, "STATS_LOANS_TAKEN")
	_most_frequent_label = _plain_row(list, "STATS_MOST_FREQUENT")
	_add_count_row(list, "STATS_TOTAL_EARNED")
	refresh()


func _add_count_row(parent: VBoxContainer, label_key: String) -> CountLabel:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.theme_type_variation = "LabelBold"
	label.text = label_key
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(label)
	var value := CountLabel.new()
	value.theme_type_variation = "LabelGold"
	row.add_child(value)
	parent.add_child(row)
	_count_labels[label_key] = value
	return value


func _plain_row(parent: VBoxContainer, label_key: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.theme_type_variation = "LabelBold"
	label.text = label_key
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(label)
	var value := Label.new()
	value.theme_type_variation = "LabelGold"
	value.auto_translate = false
	row.add_child(value)
	parent.add_child(row)
	return value


## 현재 GameState 값으로 다시 채우고 카운트업을 다시 튼다. 열 때마다 호출한다.
func refresh() -> void:
	(_count_labels["STATS_TOTAL_SPINS"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_TOTAL_SPINS))
	(_count_labels["STATS_BIGGEST_WIN"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_BIGGEST_WIN))
	(_count_labels["STATS_BEST_STREAK"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_BEST_STREAK))
	(_count_labels["STATS_STRAIGHT_HITS"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_STRAIGHT_HITS))
	(_count_labels["STATS_LOANS_TAKEN"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_LOANS_TAKEN))
	(_count_labels["STATS_TOTAL_EARNED"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_TOTAL_EARNED))
	var spins := GameState.get_stat_value(GameState.STAT_TOTAL_SPINS)
	var wins := GameState.get_stat_value(GameState.STAT_TOTAL_WINS)
	_win_rate_label.text = NumberFormat.format_percent(wins / spins) if spins > 0.0 else "-"
	var most_frequent := GameState.most_frequent_number()
	_most_frequent_label.text = NumberFormat.format(float(most_frequent)) if most_frequent >= 0 else "-"
	var total_seconds := GameState.get_stat_value(GameState.STAT_PLAY_TIME)
	var hours := int(total_seconds) / 3600
	var minutes := (int(total_seconds) / 60) % 60
	_play_time_label.text = tr("DURATION_HOURS_MINUTES") % [NumberFormat.format(float(hours)), NumberFormat.format(float(minutes))]
