class_name EndingCredits
extends Control
## 엔딩 크레딧(7단계, GDD 10장). 최후의 스핀·서명·에필로그 뒤에 통계 카드를 보여주고,
## [계속하기] 를 누르면 EndingService.enter_infinite_mode() 로 이어진다(Main 이 호출).
## StatsScreen 과 같은 자리(640×336)를 쓰지만 독립 화면이다(닫기 대신 계속하기만 있다).

signal continue_pressed()

const SIZE := Vector2(640, 336)
const LIST_POS := Vector2(64, 56)
const LABEL_WIDTH := 220.0
const ROW_SEPARATION := 14

var _play_time_label: Label
var _most_frequent_label: Label
var _final_marble_label: Label
var _count_labels: Dictionary = {}
var _continue_button: Button


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.theme_type_variation = "PanelPlain"
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := Label.new()
	title.text = "ENDING_CREDITS_TITLE"
	title.theme_type_variation = "LabelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(SIZE.x, 16)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ENDING_CREDITS_SUBTITLE"
	subtitle.theme_type_variation = "LabelGold"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 30)
	subtitle.size = Vector2(SIZE.x, 16)
	add_child(subtitle)

	var list := VBoxContainer.new()
	list.position = LIST_POS
	list.add_theme_constant_override("separation", ROW_SEPARATION)
	add_child(list)
	_play_time_label = _plain_row(list, "STATS_PLAY_TIME")
	_add_count_row(list, "STATS_TOTAL_SPINS")
	_add_count_row(list, "STATS_BIGGEST_WIN")
	_add_count_row(list, "STATS_BEST_STREAK")
	_add_count_row(list, "STATS_LOANS_TAKEN")
	_most_frequent_label = _plain_row(list, "STATS_MOST_FREQUENT")
	_final_marble_label = _plain_row(list, "ENDING_CREDITS_FINAL_MARBLE")

	_continue_button = Button.new()
	_continue_button.theme_type_variation = "ButtonGold"
	_continue_button.text = "ENDING_CONTINUE"
	_continue_button.size = Vector2(140, 24)
	_continue_button.position = Vector2((SIZE.x - 140) * 0.5, SIZE.y - 40)
	FocusStyle.apply(_continue_button)
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	add_child(_continue_button)


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


## 열 때마다 호출: 현재 GameState 값으로 채운다(카운트업 트윈 포함).
func refresh() -> void:
	(_count_labels["STATS_TOTAL_SPINS"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_TOTAL_SPINS))
	(_count_labels["STATS_BIGGEST_WIN"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_BIGGEST_WIN))
	(_count_labels["STATS_BEST_STREAK"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_BEST_STREAK))
	(_count_labels["STATS_LOANS_TAKEN"] as CountLabel).set_value(GameState.get_stat_value(GameState.STAT_LOANS_TAKEN))
	var most_frequent := GameState.most_frequent_number()
	_most_frequent_label.text = NumberFormat.format(float(most_frequent)) if most_frequent >= 0 else "-"
	var total_seconds := GameState.get_stat_value(GameState.STAT_PLAY_TIME)
	var hours := int(total_seconds) / 3600
	var minutes := (int(total_seconds) / 60) % 60
	_play_time_label.text = tr("DURATION_HOURS_MINUTES") % [NumberFormat.format(float(hours)), NumberFormat.format(float(minutes))]
	var marble := GameState.current_marble()
	_final_marble_label.text = tr(marble.name_key) if marble != null else "-"


func focus_continue() -> void:
	_continue_button.grab_focus()
