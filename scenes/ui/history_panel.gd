class_name HistoryPanel
extends Control
## 왼쪽 기록 패널(x 4~103, y 28~355).
##   최근 결과 12개: 빨강은 왼쪽, 0 은 가운데, 검정은 오른쪽 줄(카지노 결과 전광판 배치).
##   새 결과 토큰이 위에서 떨어지며 쌓이고 나머지는 한 칸씩 밀린다.
##   통계(최근 100스핀): 빨강/검정/0 비율 막대, 홀/짝 비율, 핫 넘버 3개(불꽃), 콜드 넘버 3개(눈송이), 총 스핀·연승.

const PANEL_SIZE := Vector2(100, 328)
const TITLE_Y := 5.0
const TAPE_RECT := Rect2(6, 24, 88, 162)
const TAPE_TOP := 27.0
const ROW_H := 13.0
const COL_X: Array[float] = [24.0, 50.0, 76.0]
const TOKEN_SIZE := 11
const STATS_LABEL_Y := 190.0
const COLOR_BAR_RECT := Rect2(8, 204, 84, 6)
const COLOR_PCT_Y := 212.0
const PARITY_LABEL_Y := 222.0
const PARITY_BAR_RECT := Rect2(8, 236, 84, 6)
const PARITY_PCT_Y := 244.0
const HOT_Y := 258.0
const COLD_Y := 276.0
const HOTCOLD_ICON_X := 10.0
const HOTCOLD_FIRST_X := 30.0
const HOTCOLD_STEP := 20.0
const FOOTER_Y := 298.0
const DROP_TIME := 0.32
const SHIFT_TIME := 0.2
const DROP_HEIGHT := 18.0

const TOKENS := {
	RouletteRules.PocketColor.RED: preload("res://assets/sprites/ui/token_red.png"),
	RouletteRules.PocketColor.BLACK: preload("res://assets/sprites/ui/token_black.png"),
	RouletteRules.PocketColor.GREEN: preload("res://assets/sprites/ui/token_green.png"),
}
const DIGITS := preload("res://assets/sprites/ui/digits_3x5.png")
const FLAME := preload("res://assets/sprites/ui/icon_flame.png")
const SNOW := preload("res://assets/sprites/ui/icon_snow.png")

var _recent: Array[int] = []
var _new_count: int = 0
var _anim: float = 1.0
var _stats := HistoryStats.new()
var _canvas: Control
var _labels: Dictionary = {}
## 다음 refresh(true) 에서 새로 떨어질 토큰 수(공 개수).
var _pending_new: int = 1


func _ready() -> void:
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.size = PANEL_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var tape := Panel.new()
	tape.theme_type_variation = "PanelInset"
	tape.position = TAPE_RECT.position
	tape.size = TAPE_RECT.size
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tape)
	_canvas = Control.new()
	_canvas.size = PANEL_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.clip_contents = false
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)
	_add_label("title", "HISTORY_TITLE", "LabelBold", Vector2(0, TITLE_Y), PANEL_SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("empty", "HISTORY_EMPTY", "LabelSmallMuted", Vector2(TAPE_RECT.position.x, TAPE_RECT.position.y + TAPE_RECT.size.y * 0.5 - 6), TAPE_RECT.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("stats", "HISTORY_RECENT_100", "LabelSmallMuted", Vector2(0, STATS_LABEL_Y), PANEL_SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("red_pct", "", "Num7Red", Vector2(8, COLOR_PCT_Y), 30, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label("green_pct", "", "Num7Clover", Vector2(35, COLOR_PCT_Y), 30, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("black_pct", "", "Num7Ivory", Vector2(62, COLOR_PCT_Y), 30, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_label("odd", "BET_ODD", "LabelSmallMuted", Vector2(8, PARITY_LABEL_Y), 40, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label("even", "BET_EVEN", "LabelSmallMuted", Vector2(52, PARITY_LABEL_Y), 40, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_label("odd_pct", "", "Num7Gold", Vector2(8, PARITY_PCT_Y), 40, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label("even_pct", "", "Num7Ivory", Vector2(52, PARITY_PCT_Y), 40, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_label("spins_title", "HISTORY_SPINS", "LabelSmallMuted", Vector2(8, FOOTER_Y), 60, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label("spins", "", "Num7Gold", Vector2(52, FOOTER_Y + 2), 40, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_label("streak_title", "HISTORY_STREAK", "LabelSmallMuted", Vector2(8, FOOTER_Y + 12), 60, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label("streak", "", "Num7Gold", Vector2(52, FOOTER_Y + 14), 40, HORIZONTAL_ALIGNMENT_RIGHT)
	EventBus.spin_resolved.connect(_on_spin_resolved)
	refresh(false)


func _add_label(key: String, text: String, variation: String, pos: Vector2, width: float, align: HorizontalAlignment) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.position = pos
	label.size = Vector2(width, 12)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_labels[key] = label


## GameState 기록으로 다시 계산한다. animate 면 새 토큰이 떨어진다.
func refresh(animate: bool) -> void:
	var history := GameState.result_history
	var total_spins := int(GameState.get_stat_value(GameState.STAT_TOTAL_SPINS))
	var latest := HistoryStats.recent(history)
	_new_count = 0
	if animate and not latest.is_empty():
		_new_count = mini(latest.size(), _pending_new)
		_anim = 0.0
	else:
		_anim = 1.0
	_recent = latest
	_stats = HistoryStats.from_history(history)
	(_labels["empty"] as Label).visible = latest.is_empty()
	(_labels["red_pct"] as Label).text = _pct(_stats.red)
	(_labels["black_pct"] as Label).text = _pct(_stats.black)
	(_labels["green_pct"] as Label).text = _pct(_stats.green)
	(_labels["odd_pct"] as Label).text = _pct(_stats.odd)
	(_labels["even_pct"] as Label).text = _pct(_stats.even)
	(_labels["spins"] as Label).text = NumberFormat.format(total_spins)
	(_labels["streak"] as Label).text = NumberFormat.format(GameState.win_streak)
	_canvas.queue_redraw()



func _pct(part: int) -> String:
	return "%d%%" % roundi(_stats.ratio(part) * 100.0)


func _on_spin_resolved(outcome: SpinOutcome) -> void:
	_pending_new = outcome.results.size()
	refresh(true)


func _process(delta: float) -> void:
	if _anim < 1.0:
		_anim = minf(1.0, _anim + delta / DROP_TIME)
		_canvas.queue_redraw()


func _draw_canvas() -> void:
	_draw_tape()
	_draw_bars()
	_draw_hot_cold()


func _column_of(number: int) -> float:
	match RouletteRules.color_of(number):
		RouletteRules.PocketColor.RED:
			return COL_X[0]
		RouletteRules.PocketColor.BLACK:
			return COL_X[2]
	return COL_X[1]


func _draw_tape() -> void:
	var shift_u := clampf(_anim * DROP_TIME / SHIFT_TIME, 0.0, 1.0)
	var shift_ease := 1.0 - (1.0 - shift_u) * (1.0 - shift_u)
	for i in _recent.size():
		var number := _recent[i]
		var row_y := TAPE_TOP + i * ROW_H
		var y := row_y
		var alpha := 1.0
		if i < _new_count:
			# 위에서 떨어져 튀며 자리 잡기
			var u := _anim
			var fall := 1.0 - _bounce(u)
			y = row_y - (DROP_HEIGHT + i * ROW_H) * fall
			alpha = clampf(u * 3.0, 0.0, 1.0)
		else:
			y = row_y - _new_count * ROW_H * (1.0 - shift_ease)
		if y < TAPE_RECT.position.y - 2.0:
			continue
		_draw_token(Vector2(_column_of(number), y + TOKEN_SIZE * 0.5), number, alpha)


func _bounce(u: float) -> float:
	# 0 → 1, 끝에 작게 한 번 튄다
	if u < 0.7:
		var a := u / 0.7
		return a * a
	var b := (u - 0.7) / 0.3
	return 1.0 - 0.12 * sin(b * PI)


func _draw_token(center: Vector2, number: int, alpha: float) -> void:
	var texture: Texture2D = TOKENS[RouletteRules.color_of(number)]
	var top_left := (center - Vector2(TOKEN_SIZE * 0.5, TOKEN_SIZE * 0.5)).round()
	_canvas.draw_texture(texture, top_left, Color(1, 1, 1, alpha))
	PixelDigits.draw(_canvas, DIGITS, number, top_left + Vector2(TOKEN_SIZE * 0.5, TOKEN_SIZE * 0.5), Color(1, 1, 1, alpha))


func _draw_bars() -> void:
	_draw_bar(COLOR_BAR_RECT, [[_stats.red, Palette.RED_L], [_stats.green, Palette.FELT_L], [_stats.black, Palette.POCKET_K_L]])
	_draw_bar(PARITY_BAR_RECT, [[_stats.odd, Palette.GOLD_L], [_stats.even, Palette.MIST]])


func _draw_bar(rect: Rect2, parts: Array) -> void:
	_canvas.draw_rect(rect.grow(1), Palette.VOID)
	_canvas.draw_rect(rect, Palette.NIGHT)
	var total := 0
	for part: Array in parts:
		total += int(part[0])
	if total <= 0:
		return
	var x := rect.position.x
	for i in parts.size():
		var part: Array = parts[i]
		var w := roundf(rect.size.x * int(part[0]) / float(total)) if i < parts.size() - 1 else rect.end.x - x
		if w <= 0.0:
			continue
		var color: Color = part[1]
		_canvas.draw_rect(Rect2(x, rect.position.y, w, rect.size.y), color)
		_canvas.draw_rect(Rect2(x, rect.position.y, w, 1), Palette.with_alpha(Palette.IVORY, 0.25))
		x += w


func _draw_hot_cold() -> void:
	_canvas.draw_texture(FLAME, Vector2(HOTCOLD_ICON_X, HOT_Y - 4))
	_canvas.draw_texture(SNOW, Vector2(HOTCOLD_ICON_X, COLD_Y - 3))
	for i in HistoryStats.HOT_COLD_COUNT:
		var x := HOTCOLD_FIRST_X + i * HOTCOLD_STEP
		if i < _stats.hot.size():
			_draw_token(Vector2(x, HOT_Y), _stats.hot[i], 1.0)
		else:
			_draw_empty_slot(Vector2(x, HOT_Y))
		if i < _stats.cold.size():
			_draw_token(Vector2(x, COLD_Y), _stats.cold[i], 1.0)
		else:
			_draw_empty_slot(Vector2(x, COLD_Y))


func _draw_empty_slot(center: Vector2) -> void:
	var top_left := (center - Vector2(TOKEN_SIZE * 0.5, TOKEN_SIZE * 0.5)).round()
	_canvas.draw_rect(Rect2(top_left + Vector2(2, 2), Vector2(TOKEN_SIZE - 4, TOKEN_SIZE - 4)), Palette.VOID)
