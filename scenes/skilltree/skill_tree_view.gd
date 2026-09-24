class_name SkillTreeView
extends Control
## 스킬트리 그래프: 팬(관성)·줌(1×/2×)·노드 상태·연결선·홀드 구매·키보드/패드 포커스.
## HEART 가 원점(0,0), 다른 노드는 SkillNodeDef.position(중앙 기준 픽셀)을 그대로 world 좌표로 쓴다.
## 로직은 SkillService 만 본다(자체 상태는 화면 전용: 팬·줌·포커스·홀드·연출).

signal node_hovered(id: String, rect: Rect2)
signal node_unhovered()
signal purchased(id: String, new_level: int)

enum NodeState { LOCKED, AVAILABLE, OWNED, MAXED }

const VIEW_SIZE := Vector2(640, 312)
const NODE_RADIUS := 8.0
const ULTIMATE_RADIUS := 16.0
const ZOOM_LEVELS: Array[float] = [1.0, 2.0]
const HOLD_TIME := 0.4
const PAN_DAMPING := 6.0
const DRAG_THRESHOLD := 3.0
const STAR_COUNT := 36
const ENERGY_SPEED := 40.0
const EXPLOSION_LIFE := 0.5
const CHIME_PITCHES: Array[float] = [1.0, 1.12, 1.26]

const BRANCH_COLOR := {
	SkillNodeDef.Branch.CORE: Palette.RED_HL,
	SkillNodeDef.Branch.FORTUNE: Palette.GOLD_HL,
	SkillNodeDef.Branch.MACHINE: Palette.NEON_CYAN,
	SkillNodeDef.Branch.ECONOMY: Palette.AMBER,
	SkillNodeDef.Branch.MYSTIC: Palette.NEON_PURPLE,
}

var _world: Node2D
var _bg: Node2D
var zoom_index: int = 0
var _pan_velocity := Vector2.ZERO
var _dragging: bool = false
var _drag_moved: bool = false
var _drag_last := Vector2.ZERO
var _hover_id: String = ""
var _focused_id: String = GameState.SKILL_HEART_ID
var _press_id: String = ""
var _press_time: float = 0.0
var _holding: bool = false
var _explosions: Array[Dictionary] = []
var _energy_dots: Array[Dictionary] = []
var _stardust: Array[Dictionary] = []
var _blink_queue: Array[Dictionary] = []
var _clock: float = 0.0
var _icon_cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = VIEW_SIZE
	clip_contents = true
	_rng.seed = 20260924
	_bg = Node2D.new()
	_bg.position = VIEW_SIZE * 0.5
	add_child(_bg)
	_bg.draw.connect(_draw_background)
	_world = Node2D.new()
	_world.position = VIEW_SIZE * 0.5
	add_child(_world)
	_world.draw.connect(_draw_world)
	for i in STAR_COUNT:
		_stardust.append({
			"pos": Vector2(_rng.randf_range(-300, 300), _rng.randf_range(-260, 260)),
			"speed": _rng.randf_range(2.0, 6.0),
			"phase": _rng.randf_range(0.0, TAU),
		})
	EventBus.skill_purchased.connect(_on_skill_purchased)
	mouse_exited.connect(_on_mouse_exited_view)
	recenter()


func recenter() -> void:
	_world.position = VIEW_SIZE * 0.5
	_pan_velocity = Vector2.ZERO
	queue_redraw_all()


func set_zoom_index(index: int) -> void:
	zoom_index = clampi(index, 0, ZOOM_LEVELS.size() - 1)
	var z := ZOOM_LEVELS[zoom_index]
	_world.scale = Vector2(z, z)
	_bg.scale = Vector2(z, z)
	queue_redraw_all()


func cycle_zoom() -> void:
	set_zoom_index((zoom_index + 1) % ZOOM_LEVELS.size())
	AudioManager.play_sfx("ui_click")


func queue_redraw_all() -> void:
	_bg.queue_redraw()
	_world.queue_redraw()


# ── 상태 조회 ────────────────────────────────────────────

func _state(def: SkillNodeDef) -> NodeState:
	if def.is_heart():
		return NodeState.OWNED
	if SkillService.is_maxed(def):
		return NodeState.MAXED
	if SkillService.level(def.id) > 0:
		return NodeState.OWNED
	if SkillService.is_locked(def):
		return NodeState.LOCKED
	return NodeState.AVAILABLE


func _radius(def: SkillNodeDef) -> float:
	return ULTIMATE_RADIUS if def.is_ultimate else NODE_RADIUS


func _icon(id: String) -> Texture2D:
	if not _icon_cache.has(id):
		var path := "res://assets/sprites/ui/skills/icon_%s.png" % id
		_icon_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _icon_cache[id]


func _locked_icon(id: String) -> Texture2D:
	var key := id + "_locked"
	if not _icon_cache.has(key):
		var path := "res://assets/sprites/ui/skills/icon_%s_locked.png" % id
		_icon_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _icon_cache[key]


# ── 좌표 변환 ────────────────────────────────────────────

func _to_world(local: Vector2) -> Vector2:
	return (local - _world.position) / _world.scale.x


func _to_screen(world_pos: Vector2) -> Vector2:
	return _world.position + world_pos * _world.scale.x


func node_screen_rect(id: String) -> Rect2:
	var def := GameData.skill(id)
	if def == null:
		return Rect2()
	var r := _radius(def) * _world.scale.x
	var center := global_position + _to_screen(Vector2(def.position))
	return Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)


func _node_at(world_pos: Vector2) -> String:
	var best_id := ""
	var best_dist := INF
	for def: SkillNodeDef in GameData.skills():
		var d := Vector2(def.position).distance_to(world_pos)
		var r := _radius(def)
		if d <= r and d < best_dist:
			best_dist = d
			best_id = def.id
	return best_id


# ── 입력 ─────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_moved = false
				_drag_last = mb.position
				_pan_velocity = Vector2.ZERO
				var world_pos := _to_world(mb.position)
				var id := _node_at(world_pos)
				if id != "":
					_start_hold(id)
			else:
				_dragging = false
				if not _drag_moved:
					pass # 클릭만으로는 구매하지 않는다(오조작 방지 홀드만 유효)
				_cancel_hold()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				cycle_zoom()
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			var delta: Vector2 = mm.position - _drag_last
			if delta.length() > DRAG_THRESHOLD or _drag_moved:
				_drag_moved = true
				_world.position += delta
				_pan_velocity = delta / maxf(get_process_delta_time(), 1.0 / 60.0)
				_drag_last = mm.position
				_cancel_hold()
				queue_redraw_all()
		else:
			var world_pos := _to_world(mm.position)
			_set_hover(_node_at(world_pos))


func _start_hold(id: String) -> void:
	var def := GameData.skill(id)
	if def == null or def.is_heart():
		return
	_press_id = id
	_press_time = 0.0
	_holding = true
	_focused_id = id


func _cancel_hold() -> void:
	_press_id = ""
	_holding = false
	_press_time = 0.0


func _confirm_purchase(id: String) -> void:
	var new_level := SkillService.purchase(id)
	if new_level > 0:
		_spawn_purchase_fx(id)
		purchased.emit(id, new_level)
	else:
		AudioManager.play_sfx("deny")


func _set_hover(id: String) -> void:
	if id == _hover_id:
		return
	_hover_id = id
	if id == "":
		node_unhovered.emit()
	else:
		node_hovered.emit(id, node_screen_rect(id))
	queue_redraw_all()


func _on_mouse_exited_view() -> void:
	_set_hover("")


# ── 키보드·패드 포커스 ───────────────────────────────────

func focus_move(dir: Vector2) -> void:
	var current := GameData.skill(_focused_id)
	if current == null:
		return
	var from: Vector2 = Vector2(current.position)
	var best_id := ""
	var best_score := -INF
	for def: SkillNodeDef in GameData.skills():
		if def.id == _focused_id:
			continue
		var offset: Vector2 = Vector2(def.position) - from
		if offset.length() < 1.0:
			continue
		var score := offset.normalized().dot(dir.normalized()) * 400.0 - offset.length()
		if score > best_score:
			best_score = score
			best_id = def.id
	if best_id != "":
		_focused_id = best_id
		_set_hover(best_id)
		_ensure_visible(best_id)


func _ensure_visible(id: String) -> void:
	var def := GameData.skill(id)
	if def == null:
		return
	var screen_pos := _to_screen(Vector2(def.position))
	var margin := 24.0
	var delta := Vector2.ZERO
	if screen_pos.x < margin:
		delta.x = margin - screen_pos.x
	elif screen_pos.x > VIEW_SIZE.x - margin:
		delta.x = VIEW_SIZE.x - margin - screen_pos.x
	if screen_pos.y < margin:
		delta.y = margin - screen_pos.y
	elif screen_pos.y > VIEW_SIZE.y - margin:
		delta.y = VIEW_SIZE.y - margin - screen_pos.y
	_world.position += delta
	queue_redraw_all()


func focus_activate() -> void:
	if _focused_id == "" or _focused_id == GameState.SKILL_HEART_ID:
		return
	_start_hold(_focused_id)


func focus_release() -> void:
	_cancel_hold()


func focused_id() -> String:
	return _focused_id


# ── 프레임 갱신 ──────────────────────────────────────────

func _process(delta: float) -> void:
	_clock += delta
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
	if not _dragging and _pan_velocity.length() > 0.5:
		_world.position += _pan_velocity * delta
		_pan_velocity = _pan_velocity.lerp(Vector2.ZERO, minf(1.0, PAN_DAMPING * delta))
		queue_redraw_all()
	if _holding and _press_id != "":
		_press_time += delta
		if _press_time >= HOLD_TIME:
			var id := _press_id
			_cancel_hold()
			_confirm_purchase(id)
	_update_explosions(delta)
	_update_energy_dots(delta)
	_update_blink_queue(delta)
	if _clock < 100000.0: # 항상 참(스타더스트는 매 프레임 갱신)
		_bg.queue_redraw()
	_world.queue_redraw()


# ── 구매 연출 ────────────────────────────────────────────

func _spawn_purchase_fx(id: String) -> void:
	var def := GameData.skill(id)
	if def == null:
		return
	var pos := Vector2(def.position)
	var color: Color = BRANCH_COLOR.get(def.branch, Palette.IVORY)
	var particles: Array[Dictionary] = []
	var count := 16 if def.is_ultimate else 10
	for i in count:
		var angle := TAU * float(i) / float(count)
		particles.append({"angle": angle, "speed": _rng.randf_range(30.0, 60.0)})
	_explosions.append({"pos": pos, "t": 0.0, "color": color, "particles": particles})
	AudioManager.play_sfx("promote_flash", 1.3, -6.0)
	var chime_index := clampi(SkillService.level(id) - 1, 0, CHIME_PITCHES.size() - 1)
	AudioManager.play_sfx("clover_get", CHIME_PITCHES[chime_index])
	# 연결선이 차례로 점등되고, 새로 살 수 있게 된 자식이 순서대로 깜빡인다.
	var children: Array[String] = []
	for other: SkillNodeDef in GameData.skills():
		if other.prerequisites.has(id) and SkillService.lock_status(other) != SkillService.Status.LOCKED_PREREQ:
			children.append(other.id)
	for i in children.size():
		_blink_queue.append({"id": children[i], "delay": 0.15 * (i + 1), "t": 0.0})


func _update_explosions(delta: float) -> void:
	for explosion: Dictionary in _explosions:
		explosion["t"] = float(explosion["t"]) + delta
	_explosions = _explosions.filter(func(e: Dictionary) -> bool: return float(e["t"]) < EXPLOSION_LIFE)


func _update_energy_dots(_delta: float) -> void:
	pass # 흐르는 점은 _clock 위상으로 그리기 때만 계산한다(상태 없음)


func _update_blink_queue(delta: float) -> void:
	for entry: Dictionary in _blink_queue:
		entry["delay"] = float(entry["delay"]) - delta
		if float(entry["delay"]) <= 0.0:
			entry["t"] = float(entry["t"]) + delta
	_blink_queue = _blink_queue.filter(func(e: Dictionary) -> bool: return float(e["t"]) < 0.6)


func _on_skill_purchased(_id: String, _level: int) -> void:
	queue_redraw_all()


# ── 그리기: 배경 ─────────────────────────────────────────

func _draw_background() -> void:
	# 밤/보라 벨벳 바탕(불투명). 이게 없으면 CanvasGroup 합성 결과에 뒤쪽 화면(휠·베팅창)이 비쳐 보인다.
	_bg.draw_rect(Rect2(VIEW_SIZE * -0.5, VIEW_SIZE), Palette.NIGHT)
	for star: Dictionary in _stardust:
		var p: Vector2 = star["pos"]
		var drift := Vector2(0, fmod(_clock * float(star["speed"]), 520.0) - 260.0)
		var draw_pos := (p + drift)
		draw_pos.y = wrapf(draw_pos.y, -260.0, 260.0)
		var alpha := 0.35 + 0.25 * sin(_clock * 1.3 + float(star["phase"]))
		_bg.draw_rect(Rect2(draw_pos.round(), Vector2(1, 1)), Palette.with_alpha(Palette.MIST, clampf(alpha, 0.1, 0.6)))
	# 중앙에서 퍼지는 희미한 방사광(가산 느낌은 알파만으로 근사)
	for r in [140.0, 100.0, 60.0]:
		_bg.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Palette.with_alpha(Palette.PURPLE_D, 0.05), 3.0)


# ── 그리기: 그래프 ───────────────────────────────────────

func _draw_world() -> void:
	_draw_connections()
	for def: SkillNodeDef in GameData.skills():
		_draw_node(def)
	if _holding and _press_id != "":
		_draw_hold_gauge(_press_id)
	if _focused_id != "":
		_draw_focus_ring(_focused_id)


func _draw_connections() -> void:
	for def: SkillNodeDef in GameData.skills():
		if def.prerequisites.is_empty():
			continue
		var to: Vector2 = Vector2(def.position).round()
		var owned := SkillService.level(def.id) > 0
		for prereq_id: String in def.prerequisites:
			var parent := GameData.skill(prereq_id)
			if parent == null:
				continue
			var from: Vector2 = Vector2(parent.position).round()
			var parent_owned := SkillService.level(prereq_id) > 0
			if owned and parent_owned:
				var color: Color = BRANCH_COLOR.get(def.branch, Palette.IVORY)
				_world.draw_line(from, to, color, 1.0)
				_draw_energy_dot(from, to, color)
			else:
				_draw_dotted_line(from, to, Palette.INK)


func _draw_dotted_line(from: Vector2, to: Vector2, color: Color) -> void:
	var length := from.distance_to(to)
	var steps := maxi(1, int(length / 4.0))
	for i in steps:
		if i % 2 == 0:
			continue
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		_world.draw_line(from.lerp(to, t0), from.lerp(to, t1), color, 1.0)


func _draw_energy_dot(from: Vector2, to: Vector2, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var phase := fmod(_clock * ENERGY_SPEED / length, 1.0)
	var pos := from.lerp(to, phase).round()
	_world.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), color)


func _draw_node(def: SkillNodeDef) -> void:
	var pos: Vector2 = Vector2(def.position).round()
	var r := _radius(def)
	var state := _state(def)
	var color: Color = BRANCH_COLOR.get(def.branch, Palette.IVORY)
	match state:
		NodeState.LOCKED:
			_world.draw_circle(pos, r, Palette.with_alpha(Palette.VOID, 0.85))
			_world.draw_arc(pos, r, 0.0, TAU, 20, Palette.INK, 1.0)
			var icon := _locked_icon(def.id) if not def.is_heart() else null
			if icon != null:
				_world.draw_texture(icon, pos - Vector2(icon.get_width(), icon.get_height()) * 0.5, Color(1, 1, 1, 0.7))
		NodeState.AVAILABLE:
			var pulse := 0.6 + 0.4 * sin(_clock * 3.0)
			_world.draw_circle(pos, r, Palette.with_alpha(Palette.NIGHT, 0.9))
			_world.draw_arc(pos, r, 0.0, TAU, 24, Palette.with_alpha(color, pulse), 2.0)
			_draw_icon(def, pos)
		NodeState.OWNED:
			_world.draw_circle(pos, r, Palette.with_alpha(color, 0.28))
			_world.draw_arc(pos, r, 0.0, TAU, 24, color, 1.0)
			_draw_icon(def, pos)
		NodeState.MAXED:
			var shine := 0.5 + 0.5 * sin(_clock * 4.0)
			_world.draw_circle(pos, r, Palette.with_alpha(Palette.GOLD, 0.35))
			_world.draw_arc(pos, r + 1.0, 0.0, TAU, 24, Palette.with_alpha(Palette.GOLD_HL, shine), 2.0)
			_draw_icon(def, pos)
	for blink: Dictionary in _blink_queue:
		if String(blink["id"]) == def.id:
			var u := fmod(float(blink["t"]) * 6.0, 1.0)
			if u < 0.5:
				_world.draw_arc(pos, r + 2.0, 0.0, TAU, 20, Palette.with_alpha(Palette.IVORY, 0.8), 1.0)
	for explosion: Dictionary in _explosions:
		if Vector2(explosion["pos"]) != pos:
			continue
		var u: float = float(explosion["t"]) / EXPLOSION_LIFE
		var fade := 1.0 - u
		for particle: Dictionary in explosion["particles"]:
			var dist: float = float(particle["speed"]) * float(explosion["t"])
			var dir := Vector2(cos(float(particle["angle"])), sin(float(particle["angle"])))
			_world.draw_rect(Rect2((pos + dir * dist).round() - Vector2(1, 1), Vector2(2, 2)), Palette.with_alpha(explosion["color"], fade))
		_world.draw_arc(pos, r + u * 10.0, 0.0, TAU, 24, Palette.with_alpha(Palette.IVORY, fade * 0.8), 1.0)


func _draw_icon(def: SkillNodeDef, pos: Vector2) -> void:
	var icon := _icon(def.id)
	if icon == null:
		return
	_world.draw_texture(icon, (pos - Vector2(icon.get_width(), icon.get_height()) * 0.5).round())


func _draw_hold_gauge(id: String) -> void:
	var def := GameData.skill(id)
	if def == null:
		return
	var pos: Vector2 = Vector2(def.position).round()
	var r := _radius(def) + 4.0
	var u := clampf(_press_time / HOLD_TIME, 0.0, 1.0)
	_world.draw_arc(pos, r, -PI * 0.5, -PI * 0.5 + TAU * u, 24, Palette.GOLD_HL, 2.0)


func _draw_focus_ring(id: String) -> void:
	var def := GameData.skill(id)
	if def == null:
		return
	var pos: Vector2 = Vector2(def.position).round()
	var r := _radius(def) + 3.0
	_world.draw_arc(pos, r, 0.0, TAU, 20, Palette.with_alpha(Palette.SEM_FOCUS, 0.7 + 0.3 * sin(_clock * 5.0)), 1.0)
