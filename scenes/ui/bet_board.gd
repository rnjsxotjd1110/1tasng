class_name BetBoard
extends Control
## 베팅 칸·구슬·트레이를 그리고 조작을 받는다(베팅창 안, 192×224).
##   칸 클릭: 트레이 구슬이 포물선으로 날아가 칸에 떨어지고 작게 튄다('톡')
##   우클릭: 칸의 구슬 회수 / 드래그 앤 드롭: 트레이 → 칸, 칸 → 칸, 칸 → 바깥(회수)
##   같은 칸에 여러 개면 겹쳐 쌓고 개수 배지를 단다
##   호버: 칸이 밝아지고 툴팁("스트레이트 17 · 35:1 · 예상 당첨금 1.2M")
## 베팅 상태의 원본은 GameState.current_bets 이고, 여기서는 구슬이 "보이는" 위치만 관리한다.

signal tooltip_requested(text: String, rect: Rect2)
signal tooltip_cleared()

const BOARD_SIZE := Vector2(192, 224)
const ZERO_RECT := Rect2(0, 0, 192, 13)
const GRID_TOP := 15.0
const CELL_W := 64.0
const CELL_H := 13.0
const GRID_COLS := 3
const GRID_ROWS := 12
const OUTSIDE_TOP := 174.0
const OUTSIDE_H := 15.0
const OUTSIDE_W := 95.0
const OUTSIDE_GAP := 2.0
const TRAY_Y := 210.0
const TRAY_H := 14.0
const TRAY_LABEL_W := 40.0
const TRAY_STEP := 13.0
const HOLE_SIZE := 9
const MARBLE := 7
const TOKEN := 11
const STACK_VISIBLE := 3
const STACK_STEP := Vector2(2, -1)
const DRAG_THRESHOLD := 3.0

const PLACE_TIME := 0.26
const PLACE_ARC := 14.0
const RETURN_TIME := 0.22
const SUCK_TIME := 0.45
const RESPAWN_DELAY := 0.9
const RESPAWN_TIME := 0.25
const LAND_BOUNCE_TIME := 0.16
const WIN_GLOW_TIME := 2.2
const HINT_TIME := 0.5

const KEY_RED := "R"
const KEY_BLACK := "B"
const KEY_ODD := "O"
const KEY_EVEN := "E"
const STRAIGHT_PREFIX := "S"

enum Flight { PLACE, RETURN, SUCK, RESPAWN }

const TOKENS := {
	RouletteRules.PocketColor.RED: preload("res://assets/sprites/ui/token_red.png"),
	RouletteRules.PocketColor.BLACK: preload("res://assets/sprites/ui/token_black.png"),
	RouletteRules.PocketColor.GREEN: preload("res://assets/sprites/ui/token_green.png"),
}
const DIGITS := preload("res://assets/sprites/ui/digits_3x5.png")
const ICONS := {
	"R": preload("res://assets/sprites/ui/icon_red.png"),
	"B": preload("res://assets/sprites/ui/icon_black.png"),
	"O": preload("res://assets/sprites/ui/icon_odd.png"),
	"E": preload("res://assets/sprites/ui/icon_even.png"),
}
const LABEL_KEYS := {"R": "BET_RED", "B": "BET_BLACK", "O": "BET_ODD", "E": "BET_EVEN"}
const BADGE_FONT := preload("res://assets/fonts/num7_ivory.fnt")
const BADGE_FONT_SIZE := 7

## 스핀 중에는 베팅을 바꿀 수 없다.
var locked: bool = false
## 휠 중심(전역). 진 구슬이 빨려 들어가는 곳.
var wheel_center_global := Vector2(262, 192)

var _rects: Dictionary = {}
var _visual: Dictionary = {}
var _scheduled_respawn: Dictionary = {}
var _flights: Array[Dictionary] = []
var _land_bounce: Dictionary = {}
var _win_glow: Dictionary = {}
var _hover_key: String = ""
var _press_pos := Vector2.ZERO
var _press_key: String = ""
var _press_from_tray: bool = false
var _drag: Dictionary = {}
var _hint_time: float = -1.0
var _clock: float = 0.0
var _marble_texture: Texture2D
var _small_font: Font


func _ready() -> void:
	size = BOARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_small_font = get_theme_font("font", "LabelSmall")
	_build_rects()
	_marble_texture = MarbleSprite.current()
	for key: String in _rects.keys():
		_visual[key] = 0
	_sync_counts_instant()
	EventBus.bets_changed.connect(_on_bets_changed)
	mouse_exited.connect(_on_mouse_exited)


func _build_rects() -> void:
	_rects[_straight_key(0)] = ZERO_RECT
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var number := row * GRID_COLS + col + 1
			_rects[_straight_key(number)] = Rect2(col * CELL_W, GRID_TOP + row * CELL_H, CELL_W, CELL_H)
	_rects[KEY_RED] = Rect2(0, OUTSIDE_TOP, OUTSIDE_W, OUTSIDE_H)
	_rects[KEY_BLACK] = Rect2(OUTSIDE_W + OUTSIDE_GAP, OUTSIDE_TOP, OUTSIDE_W, OUTSIDE_H)
	_rects[KEY_ODD] = Rect2(0, OUTSIDE_TOP + OUTSIDE_H + OUTSIDE_GAP, OUTSIDE_W, OUTSIDE_H)
	_rects[KEY_EVEN] = Rect2(OUTSIDE_W + OUTSIDE_GAP, OUTSIDE_TOP + OUTSIDE_H + OUTSIDE_GAP, OUTSIDE_W, OUTSIDE_H)


# ── 칸 키 ────────────────────────────────────────────────

static func _straight_key(number: int) -> String:
	return STRAIGHT_PREFIX + str(number)


static func key_of(bet: Bet) -> String:
	match bet.type:
		Bet.Type.RED:
			return KEY_RED
		Bet.Type.BLACK:
			return KEY_BLACK
		Bet.Type.ODD:
			return KEY_ODD
		Bet.Type.EVEN:
			return KEY_EVEN
	return _straight_key(bet.number)


static func bet_of(key: String) -> Bet:
	match key:
		KEY_RED:
			return Bet.red()
		KEY_BLACK:
			return Bet.black()
		KEY_ODD:
			return Bet.odd()
		KEY_EVEN:
			return Bet.even()
	return Bet.straight(int(key.substr(STRAIGHT_PREFIX.length())))


func spot_rect(key: String) -> Rect2:
	return _rects.get(key, Rect2())


func spot_global_rect(key: String) -> Rect2:
	var rect := spot_rect(key)
	return Rect2(global_position + rect.position, rect.size)


func key_at(local: Vector2) -> String:
	for key: String in _rects.keys():
		if (_rects[key] as Rect2).has_point(local):
			return key
	return ""


func all_keys() -> Array:
	return _rects.keys()


## 칸에 보이는 구슬 수(연출 반영).
func visual_count(key: String) -> int:
	return int(_visual.get(key, 0))


# ── 위치 계산 ────────────────────────────────────────────

## 칸의 k번째 구슬 좌상단(보드 좌표).
func _marble_pos(key: String, k: int) -> Vector2:
	var rect := spot_rect(key)
	var anchor: Vector2
	if key == _straight_key(0):
		anchor = Vector2(rect.position.x + rect.size.x * 0.5 + 12, rect.position.y + 3)
	elif key.begins_with(STRAIGHT_PREFIX):
		anchor = rect.position + Vector2(38, 3)
	else:
		anchor = rect.position + Vector2(rect.size.x - 24, 4)
	return anchor + STACK_STEP * mini(k, STACK_VISIBLE - 1)


## 구슬 수(최대 12)에 맞춰 홈 간격을 줄여 트레이 폭 안에 넣는다.
func _tray_step() -> float:
	var slots := maxi(GameState.marble_slots(), 1)
	return minf(TRAY_STEP, floorf((BOARD_SIZE.x - TRAY_LABEL_W) / slots))


func _tray_hole_pos(index: int) -> Vector2:
	var slots := GameState.marble_slots()
	var step := _tray_step()
	var width := slots * step
	var x0 := TRAY_LABEL_W + roundf((BOARD_SIZE.x - TRAY_LABEL_W - width) * 0.5)
	return Vector2(x0 + index * step + 2, TRAY_Y + 3)


func _returning_count() -> int:
	var count := 0
	for flight in _flights:
		if int(flight["kind"]) == Flight.RETURN:
			count += 1
	return count


## 트레이에 보이는 구슬 수.
func tray_count() -> int:
	var dragging_from_tray := 1 if (not _drag.is_empty() and String(_drag["from"]) == "") else 0
	return maxi(0, GameState.marble_slots() - GameState.current_bets.size() - _returning_count() - dragging_from_tray)


# ── 베팅 조작 ────────────────────────────────────────────

## 칸에 구슬을 놓는다(클릭과 같음). 성공하면 true.
func place(key: String) -> bool:
	if locked or not _rects.has(key):
		AudioManager.play_sfx("deny")
		return false
	var from := _tray_hole_pos(maxi(tray_count() - 1, 0))
	if not GameState.add_bet(bet_of(key)):
		hint_no_marbles()
		return false
	# reconcile 이 PLACE 비행을 만들지만, 출발점을 트레이 오른쪽 구슬로 맞춘다.
	for flight in _flights:
		if int(flight["kind"]) == Flight.PLACE and String(flight["key"]) == key and float(flight["t"]) == 0.0:
			flight["from"] = from
	return true


## 칸의 구슬 하나를 회수한다(우클릭과 같음).
func retrieve(key: String) -> bool:
	if locked:
		AudioManager.play_sfx("deny")
		return false
	var index := _last_bet_index(key)
	if index < 0:
		return false
	GameState.remove_bet_at(index)
	return true


func _last_bet_index(key: String) -> int:
	var bets := GameState.current_bets
	for i in range(bets.size() - 1, -1, -1):
		if key_of(bets[i]) == key:
			return i
	return -1


func _desired_counts() -> Dictionary:
	var counts := {}
	for bet in GameState.current_bets:
		var key := key_of(bet)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _incoming(key: String) -> int:
	var count := int(_scheduled_respawn.get(key, 0))
	for flight in _flights:
		var kind := int(flight["kind"])
		if (kind == Flight.PLACE or kind == Flight.RESPAWN) and String(flight["key"]) == key:
			count += 1
	return count


func _on_bets_changed() -> void:
	var desired := _desired_counts()
	for key: String in _rects.keys():
		var want := int(desired.get(key, 0))
		var have := int(_visual.get(key, 0)) + _incoming(key)
		if not _drag.is_empty() and String(_drag["from"]) == key:
			have += 1
		while have < want:
			_flights.append(_make_flight(Flight.PLACE, key, _tray_hole_pos(maxi(tray_count(), 0)), _marble_pos(key, int(_visual.get(key, 0)) + _incoming(key)), PLACE_TIME))
			have += 1
		while have > want:
			have -= 1
			if int(_scheduled_respawn.get(key, 0)) > 0:
				_scheduled_respawn[key] = int(_scheduled_respawn[key]) - 1
				continue
			var cancelled := false
			for i in range(_flights.size() - 1, -1, -1):
				var flight: Dictionary = _flights[i]
				if String(flight["key"]) == key and (int(flight["kind"]) == Flight.PLACE or int(flight["kind"]) == Flight.RESPAWN):
					_flights.remove_at(i)
					cancelled = true
					break
			if cancelled:
				continue
			if int(_visual.get(key, 0)) > 0:
				_visual[key] = int(_visual[key]) - 1
				var from := _marble_pos(key, int(_visual[key]))
				_flights.append(_make_flight(Flight.RETURN, key, from, _tray_hole_pos(tray_count()), RETURN_TIME))
				AudioManager.play_sfx("marble_remove")
	queue_redraw()


func _sync_counts_instant() -> void:
	var desired := _desired_counts()
	for key: String in _rects.keys():
		_visual[key] = int(desired.get(key, 0))
	_flights.clear()
	_scheduled_respawn.clear()
	queue_redraw()


## 구슬 재질이 바뀌면 호출.
func refresh_marble() -> void:
	_marble_texture = MarbleSprite.current()
	queue_redraw()


func _make_flight(kind: Flight, key: String, from: Vector2, to: Vector2, duration: float) -> Dictionary:
	return {"kind": kind, "key": key, "from": from, "to": to, "t": 0.0, "dur": duration}


# ── 결과 연출 ────────────────────────────────────────────

## 이긴 칸은 금색 테두리가 빛나고, 진 칸의 구슬은 어두워지며 휠로 빨려 들어간 뒤 다시 나타난다.
## 이긴 칸 키 목록을 돌려준다.
func show_outcome(outcome: SpinOutcome) -> Array[String]:
	var winners: Array[String] = []
	var losers: Dictionary = {}
	for bet_result in outcome.bet_results:
		var key := key_of(bet_result.bet)
		if bet_result.won():
			if not winners.has(key):
				winners.append(key)
			_win_glow[key] = WIN_GLOW_TIME
		else:
			losers[key] = int(losers.get(key, 0)) + 1
	var wheel_local := wheel_center_global - global_position
	for key: String in losers.keys():
		var lost := mini(int(losers[key]), int(_visual.get(key, 0)))
		for i in lost:
			_visual[key] = int(_visual[key]) - 1
			var flight := _make_flight(Flight.SUCK, key, _marble_pos(key, int(_visual[key])), wheel_local, SUCK_TIME)
			flight["delay"] = i * 0.06
			_flights.append(flight)
			_scheduled_respawn[key] = int(_scheduled_respawn.get(key, 0)) + 1
		var respawn_key := key
		get_tree().create_timer(RESPAWN_DELAY).timeout.connect(func() -> void: _respawn(respawn_key))
	queue_redraw()
	return winners


func _respawn(key: String) -> void:
	var count := int(_scheduled_respawn.get(key, 0))
	_scheduled_respawn[key] = 0
	for i in count:
		var to := _marble_pos(key, int(_visual.get(key, 0)) + _incoming(key))
		var flight := _make_flight(Flight.RESPAWN, key, to - Vector2(0, 5), to, RESPAWN_TIME)
		flight["delay"] = i * 0.05
		_flights.append(flight)


## 구슬이 없을 때: 트레이가 톡 튀고 안내 툴팁.
func hint_no_marbles() -> void:
	_hint_time = 0.0
	AudioManager.play_sfx("deny")
	tooltip_requested.emit(tr("HINT_NO_MARBLES"), Rect2(global_position + Vector2(0, TRAY_Y), Vector2(BOARD_SIZE.x, TRAY_H)))


## 베팅이 없을 때: 칸이 반짝이며 안내.
func hint_no_bets() -> void:
	_hint_time = 0.0
	AudioManager.play_sfx("deny")
	tooltip_requested.emit(tr("HINT_PLACE_BET"), Rect2(global_position + Vector2(0, TRAY_Y), Vector2(BOARD_SIZE.x, TRAY_H)))


# ── 입력 ─────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not _drag.is_empty():
			_drag["pos"] = motion.position
			queue_redraw()
		elif _press_key != "" or _press_from_tray:
			if motion.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_start_drag()
		_set_hover(key_at(motion.position))
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_press_pos = button.position
				_press_key = key_at(button.position)
				_press_from_tray = _tray_hit(button.position)
			else:
				if not _drag.is_empty():
					_end_drag(button.position)
				elif _press_key != "" and _press_key == key_at(button.position):
					place(_press_key)
				_press_key = ""
				_press_from_tray = false
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			var key := key_at(button.position)
			if key != "":
				retrieve(key)
			accept_event()


func _tray_hit(local: Vector2) -> bool:
	return Rect2(TRAY_LABEL_W, TRAY_Y, BOARD_SIZE.x - TRAY_LABEL_W, TRAY_H).has_point(local) and tray_count() > 0


func _start_drag() -> void:
	if locked:
		_press_key = ""
		_press_from_tray = false
		return
	if _press_from_tray:
		_drag = {"from": "", "pos": _press_pos}
	elif _press_key != "" and int(_visual.get(_press_key, 0)) > 0:
		_visual[_press_key] = int(_visual[_press_key]) - 1
		_drag = {"from": _press_key, "pos": _press_pos}
	_press_key = ""
	_press_from_tray = false
	queue_redraw()


func _end_drag(local: Vector2) -> void:
	var from := String(_drag["from"])
	var drop := Vector2(_drag["pos"])
	_drag = {}
	var target := key_at(local)
	if from == "":
		if target != "":
			_visual[target] = int(_visual.get(target, 0)) + 1
			if GameState.add_bet(bet_of(target)):
				_land(target)
			else:
				_visual[target] = int(_visual[target]) - 1
	else:
		if target == from:
			_visual[from] = int(_visual.get(from, 0)) + 1
			_land(from)
		elif target != "":
			_visual[target] = int(_visual.get(target, 0)) + 1
			var index := _last_bet_index(from)
			if index >= 0 and GameState.replace_bet_at(index, bet_of(target)):
				_land(target)
			else:
				_visual[target] = int(_visual[target]) - 1
				_visual[from] = int(_visual.get(from, 0)) + 1
		else:
			var idx := _last_bet_index(from)
			_flights.append(_make_flight(Flight.RETURN, from, drop - Vector2(3, 3), _tray_hole_pos(tray_count()), RETURN_TIME))
			if idx >= 0:
				GameState.remove_bet_at(idx)
			AudioManager.play_sfx("marble_remove")
	queue_redraw()


func _land(key: String) -> void:
	_land_bounce[key] = 0.0
	AudioManager.play_sfx("marble_place")


func _set_hover(key: String) -> void:
	if key == _hover_key:
		return
	_hover_key = key
	if key == "":
		tooltip_cleared.emit()
	else:
		tooltip_requested.emit(tooltip_text(key), spot_global_rect(key))
	queue_redraw()


func _on_mouse_exited() -> void:
	_set_hover("")


## 호버 툴팁 문장. 모든 배율을 반영한 실제 예상 당첨금(구슬 1개).
func tooltip_text(key: String) -> String:
	var bet := bet_of(key)
	var count := maxi(GameState.current_bets.size(), 1)
	bet.amount = SpinController.affordable_amount(GameState.chip_amount(), GameState.chips, count, GameState.min_bet())
	if bet.amount <= 0.0:
		bet.amount = GameState.chip_amount()
	var context := GameState.build_spin_context()
	var winning := _representative_result(bet, context)
	var payout := RouletteRules.bet_return(bet, winning, context)
	var ratio := RouletteRules.payout_ratio(bet.type)
	var name_text := tr("TIP_STRAIGHT") % bet.number if bet.type == Bet.Type.STRAIGHT else tr(bet.label_key())
	return tr("TIP_BET") % [name_text, ratio, NumberFormat.format(payout)]


## 이 베팅이 이기는 대표 결과(황금 포켓이 아닌 것 우선 — 개별숫자는 그 숫자).
static func _representative_result(bet: Bet, context: SpinContext) -> int:
	if bet.type == Bet.Type.STRAIGHT:
		return bet.number
	var fallback := -1
	for n in RouletteRules.POCKET_COUNT:
		if RouletteRules.bet_wins(bet, n):
			if not context.is_golden(n):
				return n
			fallback = n
	return fallback


# ── 갱신·그리기 ──────────────────────────────────────────

func _process(delta: float) -> void:
	_clock += delta
	var landed: Array[Dictionary] = []
	for flight in _flights:
		if flight.has("delay") and float(flight["delay"]) > 0.0:
			flight["delay"] = float(flight["delay"]) - delta
			continue
		flight["t"] = float(flight["t"]) + delta
		if float(flight["t"]) >= float(flight["dur"]):
			landed.append(flight)
	for flight in landed:
		_flights.erase(flight)
		var key := String(flight["key"])
		match int(flight["kind"]):
			Flight.PLACE:
				_visual[key] = int(_visual.get(key, 0)) + 1
				_land(key)
			Flight.RESPAWN:
				_visual[key] = int(_visual.get(key, 0)) + 1
			_:
				pass
	for key: String in _land_bounce.keys():
		_land_bounce[key] = float(_land_bounce[key]) + delta
		if float(_land_bounce[key]) > LAND_BOUNCE_TIME:
			_land_bounce.erase(key)
	for key: String in _win_glow.keys():
		_win_glow[key] = float(_win_glow[key]) - delta
		if float(_win_glow[key]) <= 0.0:
			_win_glow.erase(key)
	if _hint_time >= 0.0:
		_hint_time += delta
		if _hint_time > HINT_TIME:
			_hint_time = -1.0
	queue_redraw()


func _draw() -> void:
	_draw_grid_frame()
	for key: String in _rects.keys():
		_draw_cell(key)
	for key: String in _rects.keys():
		_draw_stack(key)
	_draw_tray()
	for flight in _flights:
		_draw_flight(flight)
	if not _drag.is_empty():
		var pos := (Vector2(_drag["pos"]) - Vector2(3, 3)).round()
		draw_texture(MarbleSprite.shadow_texture(), pos + Vector2(2, 3), Color(1, 1, 1, 0.5))
		draw_texture(_marble_texture, pos - Vector2(0, 2))


func _draw_grid_frame() -> void:
	var grid := Rect2(0, GRID_TOP, CELL_W * GRID_COLS, CELL_H * GRID_ROWS)
	draw_rect(grid.grow(1), Palette.GOLD_D, false, -1.0)
	draw_rect(ZERO_RECT.grow(1), Palette.GOLD_D, false, -1.0)


func _draw_cell(key: String) -> void:
	var rect: Rect2 = _rects[key]
	var inner := Rect2(rect.position, rect.size - Vector2(1, 1))
	var hovered := key == _hover_key and not locked
	var outside := not key.begins_with(STRAIGHT_PREFIX)
	if outside:
		draw_rect(inner, Palette.with_alpha(Palette.FELT_D, 0.7))
	if hovered:
		draw_rect(inner, Palette.with_alpha(Palette.FELT_HL, 0.45))
	var border := Palette.GOLD_D
	if hovered:
		border = Palette.GOLD_L
	draw_rect(Rect2(rect.position, rect.size), border, false, -1.0)
	if _win_glow.has(key):
		var pulse := 0.5 + 0.5 * sin(_clock * 12.0)
		var fade := clampf(float(_win_glow[key]) / 0.4, 0.0, 1.0)
		draw_rect(Rect2(rect.position, rect.size), Palette.with_alpha(Palette.GOLD_HL, fade), false, -1.0)
		draw_rect(Rect2(rect.position - Vector2(1, 1), rect.size + Vector2(2, 2)), Palette.with_alpha(Palette.GOLD_L, 0.6 * pulse * fade), false, -1.0)
		draw_rect(inner, Palette.with_alpha(Palette.GOLD_HL, 0.12 * pulse * fade))
	if outside:
		_draw_outside_label(key, rect)
	else:
		var number := int(key.substr(STRAIGHT_PREFIX.length()))
		var center := rect.position + Vector2(rect.size.x * 0.5 if number == 0 else 20.0, 6.5)
		var top_left := (center - Vector2(TOKEN * 0.5, TOKEN * 0.5)).round()
		draw_texture(TOKENS[RouletteRules.color_of(number)], top_left)
		PixelDigits.draw(self, DIGITS, number, top_left + Vector2(TOKEN * 0.5, TOKEN * 0.5))


func _draw_outside_label(key: String, rect: Rect2) -> void:
	var icon: Texture2D = ICONS[key]
	var icon_pos := rect.position + Vector2(4, roundf((rect.size.y - icon.get_height()) * 0.5))
	draw_texture(icon, icon_pos)
	var text_pos := rect.position + Vector2(14, 11)
	draw_string(_small_font, text_pos, tr(LABEL_KEYS[key]), HORIZONTAL_ALIGNMENT_LEFT, 44, 10, Palette.IVORY)
	draw_string(BADGE_FONT, rect.position + Vector2(52, 11), "1:1", HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT_SIZE, Color.WHITE)


func _draw_stack(key: String) -> void:
	var count := int(_visual.get(key, 0))
	if count <= 0:
		return
	var bounce := 0.0
	if _land_bounce.has(key):
		var u := float(_land_bounce[key]) / LAND_BOUNCE_TIME
		bounce = roundf(2.0 * sin(u * PI))
	var visible_count := mini(count, STACK_VISIBLE)
	for k in visible_count:
		var pos := _marble_pos(key, k)
		if k == visible_count - 1:
			pos.y -= bounce
		if k == 0:
			draw_texture(MarbleSprite.shadow_texture(), pos + Vector2(1, 1), Color(1, 1, 1, 0.5))
		draw_texture(_marble_texture, pos)
	if count > 1:
		var badge := "x%d" % count
		var badge_pos := _marble_pos(key, visible_count - 1) + Vector2(MARBLE + 1, 6)
		draw_string(BADGE_FONT, badge_pos, badge, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT_SIZE, Color.WHITE)


func _draw_tray() -> void:
	var slots := GameState.marble_slots()
	var filled := tray_count()
	draw_string(_small_font, Vector2(0, TRAY_Y + 10), tr("LABEL_MARBLES"), HORIZONTAL_ALIGNMENT_LEFT, TRAY_LABEL_W, 10, Palette.MIST)
	var hint_hop := 0.0
	if _hint_time >= 0.0:
		hint_hop = roundf(2.0 * absf(sin(_hint_time / HINT_TIME * PI * 2.0)))
	for i in slots:
		var pos := _tray_hole_pos(i)
		var hole := Rect2(pos - Vector2(1, 1), Vector2(HOLE_SIZE, HOLE_SIZE))
		draw_rect(hole, Palette.VOID)
		draw_rect(Rect2(hole.position + Vector2(1, 1), hole.size - Vector2(2, 2)), Palette.NIGHT)
		draw_rect(Rect2(hole.position + Vector2(1, hole.size.y - 2), Vector2(hole.size.x - 2, 1)), Palette.FELT_D)
		if i < filled:
			draw_texture(_marble_texture, pos - Vector2(0, hint_hop))


func _draw_flight(flight: Dictionary) -> void:
	if flight.has("delay") and float(flight["delay"]) > 0.0:
		if int(flight["kind"]) == Flight.SUCK:
			draw_texture(_marble_texture, Vector2(flight["from"]).round())
		return
	var u := clampf(float(flight["t"]) / float(flight["dur"]), 0.0, 1.0)
	var from := Vector2(flight["from"])
	var to := Vector2(flight["to"])
	var kind := int(flight["kind"])
	var pos: Vector2
	var alpha := 1.0
	var darkness := 0.0
	match kind:
		Flight.PLACE, Flight.RETURN:
			var e := u * u * (3.0 - 2.0 * u)
			pos = from.lerp(to, e) - Vector2(0, PLACE_ARC * 4.0 * u * (1.0 - u))
		Flight.SUCK:
			var e2 := u * u
			pos = from.lerp(to, e2)
			alpha = 1.0 - u * u
			darkness = clampf(u * 2.0, 0.0, 1.0) * 0.7
		Flight.RESPAWN:
			pos = from.lerp(to, u)
			alpha = u
	draw_texture(_marble_texture, pos.round(), Color(1, 1, 1, alpha))
	if darkness > 0.0:
		# 어두워짐: 구슬 모양 void 를 알파로 덮는다(팔레트 밖 색을 만들지 않음)
		draw_texture(MarbleSprite.shadow_texture(), pos.round(), Color(1, 1, 1, darkness * alpha))
