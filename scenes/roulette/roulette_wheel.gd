class_name RouletteWheel
extends Node2D
## 룰렛 휠 연출. 레이어(아래 → 위):
##   Shadow(스프라이트) → Base(림·트랙·디플렉터·숫자 링 바탕) → Ring(회전 링, _draw) → Top(포켓 경계·콘)
##   → Turret(회전 터렛, _draw) → Highlight(고정 반사광) → Balls(공, _draw) → Fx(불꽃·빛 링, _draw)
## 궤적 계산은 SpinChoreography(scripts/core)가 하고, 이 노드는 시간을 흘리며 그리기·소리만 한다.
## 노드 위치(휠 중심)는 정수 픽셀이어야 한다.

signal spin_finished()
## 공 하나가 포켓에 닿았다(소리·흔들림 등 연출용).
signal ball_landed(index: int)

# ── 반지름(ART_BIBLE 2장) ────────────────────────────────
const R_NUMBER_RING_OUT := 90.0
const R_NUMBER_RING_IN := 76.0
const R_NUMBERS := 83.0
const R_POCKET_OUT := 76.0
const R_POCKET_IN := 60.0
const R_POCKET_FILL_OUT := 74.5
const R_POCKET_FILL_IN := 61.5
const R_SPOKES := 50.0
const R_TURRET_IN := 7.0
const R_TURRET_OUT := 25.0
const R_KNOB := 27.0
const POCKET_SEGMENTS := 3
const POCKET_INSET_PX := 1.3
const IDLE_START_ANGLE := -90.0

# ── 모션 블러 ────────────────────────────────────────────
## |휠 각속도|(도/초) 가 이 값들을 넘으면 잔상 1·2·3개.
const GHOST_THRESHOLDS: Array[float] = [200.0, 330.0, 450.0]
const GHOST_ALPHAS: Array[float] = [0.45, 0.3, 0.2]
## 잔상 간격(초). 1/3 프레임.
const GHOST_DT := 1.0 / 180.0
const BALL_TRAIL_SPEED := 260.0
const BALL_TRAIL_DT := 1.0 / 60.0
const BALL_TRAIL_ALPHAS: Array[float] = [0.4, 0.18]

# ── 연출 타이밍 ──────────────────────────────────────────
const SKIP_SECONDS := 0.3
const GLINT_MIN := 4.0
const GLINT_MAX := 6.0
const GLINT_DURATION := 0.45
const FLASH_BLINKS := 3
const FLASH_PERIOD := 0.24
const FLASH_RING_DURATION := 0.7
const RESULT_GLOW_ALPHA := 0.35
const SPARK_COUNT_MIN := 2
const SPARK_COUNT_MAX := 3
const SPARK_LIFE := 0.28
const SPARK_SPEED := 70.0
const GOLDEN_TWINKLE_PERIOD := 0.9
const BALL_SHADOW_ALPHA := 0.7
const BALL_HALO_ALPHA := 0.35
const ROLL_SPEED_REF := 900.0
const ROLL_PITCH_MIN := 0.7
const ROLL_PITCH_MAX := 1.35
const ROLL_VOLUME_MIN_DB := -16.0

const DIGITS_TEXTURE := preload("res://assets/sprites/ui/digits_3x5.png")
const KNOB_TEXTURE := preload("res://assets/sprites/wheel/wheel_knob.png")
const HUB_TEXTURE := preload("res://assets/sprites/wheel/wheel_hub.png")
const SPARKLE_TEXTURE := preload("res://assets/sprites/ui/sparkle.png")
const DIGIT_W := 3
const DIGIT_H := 5
const SPARKLE_FRAMES := 4
const SPARKLE_SIZE := 5

## 좌상단 광원 방향(화면).
const LIGHT_DIR := Vector2(-0.7071, -0.7071)

var wheel_angle: float = IDLE_START_ANGLE
## 대기 중 공이 머무는 포켓(마지막 결과). 비어 있으면 공을 그리지 않는다.
var idle_results: Array[int] = []
var choreo: SpinChoreography = null
var spinning: bool = false
## 캡처·테스트용: true 면 시간이 흐르지 않는다.
var paused: bool = false

var _time: float = 0.0
var _time_scale: float = 1.0
var _skipping: bool = false
var _event_index: int = 0
var _landed: Array[bool] = []
var _sparks: Array[Dictionary] = []
var _flash_numbers: Array[int] = []
var _flash_time: float = -1.0
var _flash_golden: bool = false
var _glint_timer: float = GLINT_MIN
var _glint_time: float = -1.0
var _clock: float = 0.0
var _ball_texture: Texture2D
var _shadow_texture: Texture2D
var _halo_texture: Texture2D

@onready var ring: Node2D = $Ring
@onready var turret: Node2D = $Turret
@onready var balls_layer: Node2D = $Balls
@onready var fx_layer: Node2D = $Fx


func _ready() -> void:
	ring.draw.connect(_draw_ring)
	turret.draw.connect(_draw_turret)
	balls_layer.draw.connect(_draw_balls)
	fx_layer.draw.connect(_draw_fx)
	_shadow_texture = MarbleSprite.shadow_texture()
	_halo_texture = MarbleSprite.halo_texture()
	refresh_marble()
	_glint_timer = RngService.randf_range_misc(GLINT_MIN, GLINT_MAX)
	if idle_results.is_empty():
		idle_results = [GameState.result_history[-1] if not GameState.result_history.is_empty() else RouletteRules.ZERO]


## 구슬 재질이 바뀌면 호출(3단계 업그레이드).
func refresh_marble() -> void:
	_ball_texture = MarbleSprite.current()


# ── 스핀 ─────────────────────────────────────────────────

## 결과가 이미 정해진 스핀을 재생한다. 끝나면 spin_finished.
func play_spin(results: Array[int], duration: float) -> void:
	var seed_value := RngService.randi_range_misc(0, 0x7fffffff)
	choreo = SpinChoreography.create(results, duration, wheel_angle, seed_value)
	spinning = true
	_time = 0.0
	_time_scale = 1.0
	_skipping = false
	_event_index = 0
	_landed = []
	for i in results.size():
		_landed.append(false)
	_flash_numbers = []
	_flash_time = -1.0
	AudioManager.play_sfx("spin_start")
	_update_sound()
	_redraw_all()


## 남은 연출을 SKIP_SECONDS 로 감는다.
func skip() -> void:
	if not spinning or _skipping:
		return
	var remaining := choreo.duration - _time
	if remaining <= SKIP_SECONDS:
		return
	_skipping = true
	_time_scale = remaining / SKIP_SECONDS


func is_skipping() -> bool:
	return _skipping


## 캡처·테스트용: 스핀 시각을 직접 정한다(이벤트는 소리 없이 소비).
func seek(t: float) -> void:
	if choreo == null:
		return
	_time = clampf(t, 0.0, choreo.duration)
	while _event_index < choreo.events.size() and choreo.events[_event_index].time <= _time:
		_event_index += 1
	wheel_angle = choreo.wheel_angle(_time)
	_redraw_all()


func spin_time() -> float:
	return _time


## 결과 포켓 점멸(흰색/금색 3회) + 빛 링.
func flash_result(results: Array[int], golden: bool) -> void:
	_flash_numbers = results.duplicate()
	_flash_time = 0.0
	_flash_golden = golden


## 포켓 중심의 전역 좌표(연출 위치용).
func pocket_global_position(number: int) -> Vector2:
	var a := deg_to_rad(wheel_angle + RouletteRules.pocket_angle(number))
	return global_position + Vector2(cos(a), sin(a)) * SpinChoreography.R_POCKET


func _process(delta: float) -> void:
	_clock += delta
	if spinning and not paused:
		_time += delta * _time_scale
		if _time >= choreo.duration:
			_time = choreo.duration
		wheel_angle = choreo.wheel_angle(_time)
		_fire_events()
		_update_sound()
		if _time >= choreo.duration:
			_finish()
	_update_sparks(delta)
	if _flash_time >= 0.0:
		_flash_time += delta
	_update_glint(delta)
	_redraw_all()


func _finish() -> void:
	spinning = false
	idle_results = []
	for ball in choreo.balls:
		idle_results.append(ball.result)
	AudioManager.stop_loop("ball_roll_loop")
	spin_finished.emit()


func _fire_events() -> void:
	while _event_index < choreo.events.size() and choreo.events[_event_index].time <= _time:
		var event := choreo.events[_event_index]
		_event_index += 1
		match event.kind:
			SpinChoreography.EventKind.BOUNCE:
				_spawn_sparks(event.angle)
				if not _skipping:
					AudioManager.play_sfx("deflector_hit")
			SpinChoreography.EventKind.LAND:
				_landed[event.ball] = true
				AudioManager.play_sfx("pocket_land")
				ball_landed.emit(event.ball)
			SpinChoreography.EventKind.HOP:
				if not _skipping:
					AudioManager.play_sfx("pocket_land", 1.25, -8.0)
			_:
				pass


func _update_sound() -> void:
	if not spinning or _skipping:
		AudioManager.stop_loop("ball_roll_loop")
		return
	var rolling := false
	var speed := 0.0
	for i in choreo.balls.size():
		if not _landed[i] and _time >= choreo.launch_time * 0.5:
			rolling = true
			speed = maxf(speed, choreo.ball_speed(i, _time))
	if not rolling:
		AudioManager.stop_loop("ball_roll_loop")
		return
	var k := clampf(speed / ROLL_SPEED_REF, 0.0, 1.0)
	AudioManager.play_loop("ball_roll_loop", lerpf(ROLL_PITCH_MIN, ROLL_PITCH_MAX, k), lerpf(ROLL_VOLUME_MIN_DB, 0.0, k))


func _update_glint(delta: float) -> void:
	if _glint_time >= 0.0:
		_glint_time += delta
		if _glint_time > GLINT_DURATION:
			_glint_time = -1.0
			_glint_timer = RngService.randf_range_misc(GLINT_MIN, GLINT_MAX)
		return
	if spinning:
		return
	_glint_timer -= delta
	if _glint_timer <= 0.0:
		_glint_time = 0.0


func _redraw_all() -> void:
	ring.queue_redraw()
	turret.queue_redraw()
	balls_layer.queue_redraw()
	fx_layer.queue_redraw()


func _current_wheel_speed() -> float:
	if spinning and choreo != null:
		return choreo.wheel_speed(_time)
	return 0.0


# ── 회전 링 ──────────────────────────────────────────────

func _draw_ring() -> void:
	var speed := absf(_current_wheel_speed())
	_draw_ring_at(wheel_angle, 1.0, true)
	for k in GHOST_THRESHOLDS.size():
		if speed < GHOST_THRESHOLDS[k]:
			break
		var ghost_angle := choreo.wheel_angle(maxf(_time - GHOST_DT * (k + 1), 0.0))
		_draw_ring_at(ghost_angle, GHOST_ALPHAS[k], false)


func _draw_ring_at(angle: float, alpha: float, full: bool) -> void:
	var step := RouletteRules.DEGREES_PER_POCKET
	var half := step * 0.5
	var golden := GameState.golden_pockets
	for index in RouletteRules.POCKET_COUNT:
		var number: int = RouletteRules.WHEEL_ORDER[index]
		var center := angle + index * step
		var colors := _pocket_colors(number, golden.has(number))
		var edge: Color = colors[0]
		var fill: Color = colors[1]
		ring.draw_colored_polygon(_sector(center - half, center + half, R_POCKET_IN, R_POCKET_OUT), Palette.with_alpha(edge, alpha))
		var inset_out := rad_to_deg(POCKET_INSET_PX / R_POCKET_FILL_OUT)
		var inset_in := rad_to_deg(POCKET_INSET_PX / R_POCKET_FILL_IN)
		var inner := _sector_inset(center, half, inset_out, inset_in)
		ring.draw_colored_polygon(inner, Palette.with_alpha(fill, alpha))
		# 칸막이(fret)
		var a0 := deg_to_rad(center - half)
		var dir0 := Vector2(cos(a0), sin(a0))
		var fret_color := Palette.GOLD_L if dir0.dot(LIGHT_DIR) > -0.2 else Palette.GOLD
		ring.draw_line(dir0 * R_POCKET_IN, dir0 * R_POCKET_OUT, Palette.with_alpha(fret_color, alpha), -1.0)
		# 숫자 링 칸 구분선
		ring.draw_line(dir0 * (R_NUMBER_RING_IN + 1.0), dir0 * (R_NUMBER_RING_OUT - 1.0), Palette.with_alpha(Palette.WOOD, alpha), -1.0)
		# 숫자(똑바로 선 방향)
		_draw_number_at(center, number, alpha)
		if full and golden.has(number):
			_draw_golden_twinkle(center, number)


## [가장자리 색, 안쪽 색]
func _pocket_colors(number: int, golden: bool) -> PackedColorArray:
	if _flash_time >= 0.0 and _flash_numbers.has(number):
		var blink := int(_flash_time / (FLASH_PERIOD * 0.5))
		if blink < FLASH_BLINKS * 2:
			if blink % 2 == 0:
				if (blink / 2) % 2 == 0:
					return PackedColorArray([Palette.GOLD_HL, Palette.IVORY])
				return PackedColorArray([Palette.GOLD, Palette.GOLD_HL])
		elif _flash_golden or golden:
			return PackedColorArray([Palette.GOLD, Palette.GOLD_L])
	if golden:
		return PackedColorArray([Palette.GOLD, Palette.GOLD_L])
	return _base_pocket_colors(number)


func _base_pocket_colors(number: int) -> PackedColorArray:
	match RouletteRules.color_of(number):
		RouletteRules.PocketColor.RED:
			return PackedColorArray([Palette.RED, Palette.RED_L])
		RouletteRules.PocketColor.BLACK:
			return PackedColorArray([Palette.POCKET_K, Palette.POCKET_K_L])
	return PackedColorArray([Palette.FELT, Palette.FELT_L])


func _sector(from_deg: float, to_deg: float, r_in: float, r_out: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for s in POCKET_SEGMENTS + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(s) / POCKET_SEGMENTS))
		points.append(Vector2(cos(a), sin(a)) * r_out)
	for s in range(POCKET_SEGMENTS, -1, -1):
		var a2 := deg_to_rad(lerpf(from_deg, to_deg, float(s) / POCKET_SEGMENTS))
		points.append(Vector2(cos(a2), sin(a2)) * r_in)
	return points


func _sector_inset(center: float, half: float, inset_out: float, inset_in: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for s in POCKET_SEGMENTS + 1:
		var a := deg_to_rad(lerpf(center - half + inset_out, center + half - inset_out, float(s) / POCKET_SEGMENTS))
		points.append(Vector2(cos(a), sin(a)) * R_POCKET_FILL_OUT)
	for s in range(POCKET_SEGMENTS, -1, -1):
		var a2 := deg_to_rad(lerpf(center - half + inset_in, center + half - inset_in, float(s) / POCKET_SEGMENTS))
		points.append(Vector2(cos(a2), sin(a2)) * R_POCKET_FILL_IN)
	return points


func _draw_number_at(angle_deg: float, number: int, alpha: float) -> void:
	var a := deg_to_rad(angle_deg)
	var center := Vector2(cos(a), sin(a)) * R_NUMBERS
	PixelDigits.draw(ring, DIGITS_TEXTURE, number, center, Color(1, 1, 1, alpha))


func _draw_golden_twinkle(angle_deg: float, number: int) -> void:
	var phase := fposmod(_clock / GOLDEN_TWINKLE_PERIOD + number * 0.37, 1.0)
	var frame := int(phase * SPARKLE_FRAMES * 2)
	if frame >= SPARKLE_FRAMES:
		return
	var a := deg_to_rad(angle_deg + (phase - 0.5) * 4.0)
	var pos := (Vector2(cos(a), sin(a)) * (SpinChoreography.R_POCKET + 3.0)).round() - Vector2(2, 2)
	ring.draw_texture_rect_region(SPARKLE_TEXTURE, Rect2(pos, Vector2(SPARKLE_SIZE, SPARKLE_SIZE)),
		Rect2(frame * SPARKLE_SIZE, 0, SPARKLE_SIZE, SPARKLE_SIZE))


# ── 터렛 ─────────────────────────────────────────────────

func _draw_turret() -> void:
	# 콘 위 금 점 8개(회전이 보이게)
	for k in 8:
		var a := deg_to_rad(wheel_angle + 22.5 + k * 45.0)
		var p := (Vector2(cos(a), sin(a)) * R_SPOKES).floor()
		turret.draw_rect(Rect2(p, Vector2(2, 2)), Palette.GOLD_D)
		turret.draw_rect(Rect2(p, Vector2(1, 1)), Palette.GOLD_HL)
	# 십자 손잡이
	for k in 4:
		var a2 := deg_to_rad(wheel_angle + k * 90.0)
		var dir := Vector2(cos(a2), sin(a2))
		var normal := Vector2(-dir.y, dir.x)
		var base := dir * R_TURRET_IN
		var tip := dir * R_TURRET_OUT
		turret.draw_colored_polygon(PackedVector2Array([
			base + normal * 3.2, tip + normal * 2.2, tip - normal * 2.2, base - normal * 3.2]), Palette.GOLD_D)
		turret.draw_colored_polygon(PackedVector2Array([
			base + normal * 2.0, tip + normal * 1.1, tip - normal * 1.1, base - normal * 2.0]), Palette.GOLD_L)
		var lit_side := normal if normal.dot(LIGHT_DIR) > 0.0 else -normal
		turret.draw_line(base + lit_side * 1.4, tip + lit_side * 0.6, Palette.GOLD_HL, -1.0)
		var knob_pos := (dir * R_KNOB).round() - Vector2(2, 2)
		turret.draw_texture(KNOB_TEXTURE, knob_pos)
		if _glint_time >= 0.0 and k == 2:
			var frame := int(_glint_time / GLINT_DURATION * SPARKLE_FRAMES)
			turret.draw_texture_rect_region(SPARKLE_TEXTURE, Rect2(knob_pos - Vector2(0, 0), Vector2(SPARKLE_SIZE, SPARKLE_SIZE)),
				Rect2(clampi(frame, 0, SPARKLE_FRAMES - 1) * SPARKLE_SIZE, 0, SPARKLE_SIZE, SPARKLE_SIZE))
	turret.draw_texture(HUB_TEXTURE, Vector2(-8, -8))
	if _glint_time >= 0.0:
		_draw_glint()


## 허브를 대각선으로 스치는 빛 띠.
func _draw_glint() -> void:
	var u := _glint_time / GLINT_DURATION
	var band := lerpf(-18.0, 18.0, u)
	for y in range(-8, 8):
		for x in range(-8, 8):
			var cx := x + 0.5
			var cy := y + 0.5
			if cx * cx + cy * cy > 49.0:
				continue
			var d := absf(cx + cy - band)
			if d < 1.0:
				turret.draw_rect(Rect2(x, y, 1, 1), Palette.with_alpha(Palette.IVORY, 0.9))
			elif d < 2.0:
				turret.draw_rect(Rect2(x, y, 1, 1), Palette.with_alpha(Palette.GOLD_SHINE, 0.5))


# ── 공 ───────────────────────────────────────────────────

func _draw_balls() -> void:
	if spinning and choreo != null:
		for i in choreo.balls.size():
			if choreo.ball_speed(i, _time) > BALL_TRAIL_SPEED:
				for k in BALL_TRAIL_ALPHAS.size():
					var tt := _time - BALL_TRAIL_DT * (k + 1)
					if tt > 0.0:
						_draw_ball(choreo.ball_offset(i, tt), choreo.ball_height(i, tt), BALL_TRAIL_ALPHAS[k], false)
			var appear := clampf(_time / (choreo.launch_time * 0.3), 0.0, 1.0)
			_draw_ball(choreo.ball_offset(i, _time), choreo.ball_height(i, _time), appear, true)
	else:
		for number in idle_results:
			var a := deg_to_rad(wheel_angle + RouletteRules.pocket_angle(number))
			_draw_ball(Vector2(cos(a), sin(a)) * SpinChoreography.R_POCKET, 0.0, 1.0, true)


func _draw_ball(offset: Vector2, height: float, alpha: float, with_shadow: bool) -> void:
	var half := MarbleSprite.SIZE * 0.5
	var top_left := (offset - Vector2(half, half)).round()
	if with_shadow:
		var lift := roundf(height)
		balls_layer.draw_texture(_shadow_texture, top_left + Vector2(1, 1) + Vector2(lift * 0.5, lift * 0.5).round(),
			Color(1, 1, 1, BALL_SHADOW_ALPHA * alpha))
	var ball_pos := top_left - Vector2(0, roundf(height))
	if with_shadow:
		# 어두운 트랙·포켓 위에서도 공이 먼저 보이도록 1px 테두리 빛(알파만)
		for dir: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			balls_layer.draw_texture(_halo_texture, ball_pos + dir, Color(1, 1, 1, BALL_HALO_ALPHA * alpha))
	balls_layer.draw_texture(_ball_texture, ball_pos, Color(1, 1, 1, alpha))


# ── 불꽃·빛 링 ───────────────────────────────────────────

func _spawn_sparks(angle_deg: float) -> void:
	var a := deg_to_rad(angle_deg)
	var origin := Vector2(cos(a), sin(a)) * SpinChoreography.R_DEFLECTOR
	var count := RngService.randi_range_misc(SPARK_COUNT_MIN, SPARK_COUNT_MAX)
	for i in count:
		var spread := RngService.randf_range_misc(-1.2, 1.2)
		var dir := Vector2(cos(a + PI + spread), sin(a + PI + spread))
		_sparks.append({"pos": origin, "vel": dir * SPARK_SPEED * RngService.randf_range_misc(0.6, 1.2), "life": SPARK_LIFE})


func _update_sparks(delta: float) -> void:
	for spark in _sparks:
		spark["pos"] = Vector2(spark["pos"]) + Vector2(spark["vel"]) * delta
		spark["life"] = float(spark["life"]) - delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["life"]) > 0.0)


func _draw_fx() -> void:
	for spark in _sparks:
		var life := float(spark["life"]) / SPARK_LIFE
		var color := Palette.GOLD_SHINE if life > 0.6 else (Palette.GOLD_HL if life > 0.3 else Palette.GOLD)
		fx_layer.draw_rect(Rect2(Vector2(spark["pos"]).floor(), Vector2(1, 1)), color)
	if _flash_time >= 0.0 and not spinning:
		for number in _flash_numbers:
			var a := deg_to_rad(wheel_angle + RouletteRules.pocket_angle(number))
			var center := (Vector2(cos(a), sin(a)) * SpinChoreography.R_POCKET).round()
			var u := clampf(_flash_time / FLASH_RING_DURATION, 0.0, 1.0)
			var color := Palette.GOLD_HL if _flash_golden else Palette.IVORY
			if u < 1.0:
				fx_layer.draw_arc(center, lerpf(6.0, 16.0, u), 0.0, TAU, 24, Palette.with_alpha(color, 0.8 * (1.0 - u)), -1.0)
				fx_layer.draw_arc(center, lerpf(4.0, 11.0, u), 0.0, TAU, 20, Palette.with_alpha(Palette.GOLD_HL, 0.5 * (1.0 - u)), -1.0)
			# 결과 포켓 주변에 은은히 남는 빛
			fx_layer.draw_arc(center, 8.0, 0.0, TAU, 20, Palette.with_alpha(Palette.GOLD_HL, RESULT_GLOW_ALPHA * (0.6 + 0.4 * sin(_clock * 4.0))), -1.0)
