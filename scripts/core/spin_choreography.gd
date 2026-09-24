class_name SpinChoreography
extends RefCounted
## 스핀 연출의 시간 → 각도·반지름 함수(순수 계산, 노드·트윈 없음).
## 결과는 스핀 시작 때 이미 정해져 있고, 이 클래스는 공이 정확히 그 포켓에 떨어지는 궤적을 만든다.
##
## 좌표: 각도는 도(degree), Godot 2D 화면 기준(0 = 오른쪽, 양수 = 시계 방향). 감지 않은(unwrapped) 값.
##   휠은 반시계(각도 감소), 공은 시계(각도 증가)로 돈다(ART_BIBLE 2장).
##   포켓 n 의 화면 각도 = wheel_angle(t) + RouletteRules.pocket_angle(n)
##
## 단계(T = 스핀 시간):
##   A 발사  0 ~ ta(0.3초, 짧은 스핀은 T×0.12)   휠 가속, 공이 트랙 바깥에서 들어온다
##   B 궤도  ta ~ 0.55T                           공 각속도 지수 감소. 착지 보정값이 이 구간에 분산된다
##   C 낙하  0.55T ~ t_land(0.8T)                 반지름 97 → 68, 디플렉터에 1~3회 튕김(T < 2.5초면 1회)
##   D 안착  t_land ~ t_land + 0.1T              포켓 칸막이 사이에서 1~2번 작게 튀고 고정
##   E 동행  ~ T                                  공이 포켓에 붙어 휠과 함께 돌고, 휠이 ease-out 으로 정지
##
## 착지 계산: 휠 각도 θw(t) 를 먼저 닫힌 식으로 정한다. 공의 휠 기준 상대각 φ(t) = φ0 + S·F(t) + δ·G(t).
##   F = 상대 각속도 모양 f 의 누적 적분, G = B 구간 창(window)에 분산된 보정 모양의 누적 적분(G(t_land) = 1).
##   δ 는 φ(t_land) ≡ pocket_angle(결과) (mod 360) 이 되도록 고른 [-180, 180) 보정값이다.

enum Phase { LAUNCH, ORBIT, DROP, SETTLE, RIDE }
enum EventKind { LAUNCH, BOUNCE, LAND, HOP, SETTLED }

# ── 단계 비율 ────────────────────────────────────────────
const LAUNCH_TIME := 0.3
const LAUNCH_RATIO_MAX := 0.12
const ORBIT_END := 0.55
const DROP_END := 0.8
const SETTLE_RATIO := 0.1
## 이보다 짧은 스핀은 튕김·안착 홉을 1회로 줄인다.
const SHORT_SPIN := 2.5
## 공이 여러 개면 뒤 공일수록 이만큼(×T) 먼저 착지한다.
const MULTI_BALL_LAND_STAGGER := 0.035

# ── 속도 ─────────────────────────────────────────────────
## 휠 최대 각속도(도/초)와 감속 곡선 지수(ω = W·(1-x)^p).
const WHEEL_MAX_SPEED := 540.0
const WHEEL_DECEL_POWER := 1.2
## 발사 직후 공의 화면 기준 각속도(도/초, 시계 방향). 공마다 ±SPEED_JITTER 비율로 흔든다.
const BALL_LAUNCH_SPEED := 900.0
const BALL_SPEED_JITTER := 0.08
## B 구간 끝의 상대 각속도 비율(지수 감소 목표).
const ORBIT_SPEED_RATIO := 0.28
## C 구간 추가 감쇠(B 의 감쇠율 대비).
const DROP_DECAY_FACTOR := 0.5
## 보정 창 가장자리(B 길이 대비) — 이 비율만큼 부드럽게 켜지고 꺼진다.
const CORRECTION_EDGE := 0.2
## 착지 보정 중 전체 속도 배율로 흡수하는 최대 비율.
const SCALE_ABSORB := 0.12
const TABLE_STEPS := 2048

# ── 반지름(ART_BIBLE 2장) ────────────────────────────────
const R_LAUNCH := 102.0
const R_TRACK := 97.0
const R_DROP_MID := 92.0
const R_POCKET := 68.0
const R_DEFLECTOR := 91.0
const DEFLECTOR_COUNT := 8
const DEFLECTOR_OFFSET := 22.5
## 공을 던지는 화면 각도(오른쪽 위, 딜러 자리).
const LAUNCH_ANGLE := -55.0
const LAUNCH_HEIGHT := 5.0
## C 구간에서 튕김이 일어날 수 있는 앞부분 비율(뒷부분은 포켓으로 떨어지는 구간).
const DROP_BOUNCE_PORTION := 0.6

# ── 튕김·안착 ────────────────────────────────────────────
const BOUNCE_MIN := 1
const BOUNCE_MAX := 3
const BOUNCE_DURATION := 0.16
const BOUNCE_DURATION_RATIO := 0.3
const BOUNCE_RADIUS_MIN := 3.0
const BOUNCE_RADIUS_MAX := 6.0
const BOUNCE_HEIGHT := 3.0
const BOUNCE_WOBBLE_DEG := 6.0
const HOP_MAX := 2
const HOP_RADIUS := 1.5
const HOP_HEIGHT := 2.0
## 포켓 안 좌우 흔들림(도). 포켓 반폭(4.86도) - 공 반지름(약 2.9도) 보다 작아야 한다.
const SETTLE_JITTER_DEG := 1.6


class Ball:
	extends RefCounted
	var result: int = 0
	var pocket_deg: float = 0.0
	## pocket_deg 와 같은 포켓(mod 360)이지만 궤적과 이어지는 감지 않은 값.
	var pocket_unwrapped: float = 0.0
	var launch_deg: float = 0.0
	var t_land: float = 0.0
	var t_settled: float = 0.0
	var t_orbit_end: float = 0.0
	var phi0: float = 0.0
	var scale: float = 0.0
	var delta: float = 0.0
	var decay: float = 0.0
	## 누적 적분 테이블(0 ~ t_land 균등 격자).
	var f_table := PackedFloat64Array()
	var g_table := PackedFloat64Array()
	## 튕김: {"t": 시작, "d": 길이, "r": 바깥으로 밀리는 반지름, "w": 각도 흔들림(도)}
	var bounces: Array[Dictionary] = []
	## 안착 홉: {"t", "d", "r", "h"}
	var hops: Array[Dictionary] = []
	var jitter_sign: float = 1.0


class Event:
	extends RefCounted
	var time: float
	var kind: EventKind
	var ball: int
	## 이벤트가 일어난 화면 각도(불꽃 위치용).
	var angle: float
	var radius: float

	func _init(p_time: float, p_kind: EventKind, p_ball: int, p_angle: float, p_radius: float) -> void:
		time = p_time
		kind = p_kind
		ball = p_ball
		angle = p_angle
		radius = p_radius


var duration: float = 0.0
var wheel_start: float = 0.0
var launch_time: float = LAUNCH_TIME
var orbit_end: float = 0.0
var balls: Array[Ball] = []
## 시간순 정렬된 이벤트(소리·불꽃).
var events: Array[Event] = []
var _wheel_after_launch: float = 0.0


## results: 공마다 결과 숫자. seed: 튕김 패턴·발사 각도의 난수 씨앗(RngService misc 에서 받는다).
static func create(results: Array[int], p_duration: float, p_wheel_start: float, seed_value: int) -> SpinChoreography:
	var choreo := SpinChoreography.new()
	choreo._build(results, p_duration, p_wheel_start, seed_value)
	return choreo


func is_short() -> bool:
	return duration < SHORT_SPIN


# ── 휠 ───────────────────────────────────────────────────

## 휠 회전각(도). 반시계로 돌기 때문에 시간이 지날수록 작아진다.
func wheel_angle(t: float) -> float:
	var ta := launch_time
	if t <= 0.0:
		return wheel_start
	if t < ta:
		var u := t / ta
		return wheel_start - WHEEL_MAX_SPEED * ta * (u * u * u - u * u * u * u * 0.5)
	var x := clampf((t - ta) / (duration - ta), 0.0, 1.0)
	var p := WHEEL_DECEL_POWER
	return _wheel_after_launch - WHEEL_MAX_SPEED * (duration - ta) * (1.0 - pow(1.0 - x, p + 1.0)) / (p + 1.0)


## 휠 각속도(도/초, 음수 = 반시계).
func wheel_speed(t: float) -> float:
	var ta := launch_time
	if t <= 0.0 or t >= duration:
		return 0.0
	if t < ta:
		var u := t / ta
		return -WHEEL_MAX_SPEED * u * u * (3.0 - 2.0 * u)
	var x := (t - ta) / (duration - ta)
	return -WHEEL_MAX_SPEED * pow(1.0 - x, WHEEL_DECEL_POWER)


# ── 공 ───────────────────────────────────────────────────

func phase_of(index: int, t: float) -> Phase:
	var ball := balls[index]
	if t < launch_time:
		return Phase.LAUNCH
	if t < orbit_end:
		return Phase.ORBIT
	if t < ball.t_land:
		return Phase.DROP
	if t < ball.t_settled:
		return Phase.SETTLE
	return Phase.RIDE


## 공의 휠 기준 상대각(도). t_land 이후에는 포켓 각도(+ 안착 흔들림).
func ball_relative_angle(index: int, t: float) -> float:
	var ball := balls[index]
	if t >= ball.t_land:
		return ball.pocket_unwrapped + _settle_jitter(ball, t)
	var base := ball.phi0 + ball.scale * _table_value(ball.f_table, ball.t_land, t) + ball.delta * _table_value(ball.g_table, ball.t_land, t)
	return base + _bounce_wobble(ball, t)


## 공의 화면 각도(도).
func ball_angle(index: int, t: float) -> float:
	return wheel_angle(t) + ball_relative_angle(index, t)


## 공의 반지름(px, 휠 중심 기준).
func ball_radius(index: int, t: float) -> float:
	var ball := balls[index]
	var r: float
	if t < launch_time:
		var u := clampf(t / launch_time, 0.0, 1.0)
		r = lerpf(R_LAUNCH, R_TRACK, 1.0 - (1.0 - u) * (1.0 - u))
	elif t < orbit_end:
		r = R_TRACK
	elif t < ball.t_land:
		var span := ball.t_land - orbit_end
		var split := orbit_end + span * DROP_BOUNCE_PORTION
		if t < split:
			var u1 := (t - orbit_end) / (split - orbit_end)
			r = lerpf(R_TRACK, R_DROP_MID, u1 * u1)
		else:
			var u2 := (t - split) / (ball.t_land - split)
			r = lerpf(R_DROP_MID, R_POCKET, u2 * u2 * (3.0 - 2.0 * u2))
		for bounce in ball.bounces:
			var s := (t - float(bounce["t"])) / float(bounce["d"])
			if s > 0.0 and s < 1.0:
				r += float(bounce["r"]) * sin(PI * s)
	else:
		r = R_POCKET
		for hop in ball.hops:
			var s2 := (t - float(hop["t"])) / float(hop["d"])
			if s2 > 0.0 and s2 < 1.0:
				r += float(hop["r"]) * sin(PI * s2)
	return r


## 공의 높이(px). 그림자와의 거리로 표현한다. 0 = 바닥에 닿음.
func ball_height(index: int, t: float) -> float:
	var ball := balls[index]
	if t < launch_time:
		var u := clampf(t / launch_time, 0.0, 1.0)
		return LAUNCH_HEIGHT * (1.0 - u) * absf(cos(u * PI * 1.5))
	var list: Array[Dictionary] = ball.bounces if t < ball.t_land else ball.hops
	var key := "h"
	for item in list:
		var s := (t - float(item["t"])) / float(item["d"])
		if s > 0.0 and s < 1.0:
			return float(item.get(key, BOUNCE_HEIGHT)) * 4.0 * s * (1.0 - s)
	return 0.0


## 공의 화면 기준 각속도 크기(도/초). 굴러가는 소리 피치·잔상에 쓴다.
func ball_speed(index: int, t: float) -> float:
	var ball := balls[index]
	if t >= ball.t_land or t <= 0.0:
		return 0.0
	var h := 1.0 / 240.0
	return absf(ball_angle(index, minf(t + h, ball.t_land)) - ball_angle(index, maxf(t - h, 0.0))) / (minf(t + h, ball.t_land) - maxf(t - h, 0.0))


## 공의 화면 위치(휠 중심 기준, px, 소수).
func ball_offset(index: int, t: float) -> Vector2:
	var a := deg_to_rad(ball_angle(index, t))
	var r := ball_radius(index, t)
	return Vector2(cos(a), sin(a)) * r


## 모든 공이 안착하는 시각(가장 늦은 t_settled).
func all_settled_time() -> float:
	var latest := 0.0
	for ball in balls:
		latest = maxf(latest, ball.t_settled)
	return latest


# ── 생성 ─────────────────────────────────────────────────

func _build(results: Array[int], p_duration: float, p_wheel_start: float, seed_value: int) -> void:
	duration = maxf(p_duration, Economy.MIN_SPIN_DURATION)
	wheel_start = p_wheel_start
	launch_time = minf(LAUNCH_TIME, duration * LAUNCH_RATIO_MAX)
	orbit_end = duration * ORBIT_END
	_wheel_after_launch = wheel_start - WHEEL_MAX_SPEED * launch_time * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	balls = []
	events = []
	var count := results.size()
	for i in count:
		var ball := Ball.new()
		ball.result = results[i]
		ball.pocket_deg = RouletteRules.pocket_angle(results[i])
		ball.launch_deg = LAUNCH_ANGLE + i * 360.0 / count + rng.randf_range(-8.0, 8.0)
		ball.t_land = duration * (DROP_END - MULTI_BALL_LAND_STAGGER * i)
		ball.t_settled = ball.t_land + duration * SETTLE_RATIO
		ball.t_orbit_end = orbit_end
		ball.jitter_sign = 1.0 if rng.randf() < 0.5 else -1.0
		_solve_ball(ball, rng)
		balls.append(ball)
		events.append(Event.new(0.0, EventKind.LAUNCH, i, ball.launch_deg, R_LAUNCH))
		_plan_bounces(i, ball, rng)
		_plan_hops(i, ball, rng)
	events.sort_custom(func(a: Event, b: Event) -> bool: return a.time < b.time)


## 상대 각속도 모양 f(t) (0 ~ t_land). f(ta) = 1.
func _shape(ball: Ball, t: float) -> float:
	var ta := launch_time
	if t < ta:
		var u := t / ta
		return u * u * (3.0 - 2.0 * u)
	if t < orbit_end:
		return exp(-ball.decay * (t - ta))
	var at_orbit_end := exp(-ball.decay * (orbit_end - ta))
	var v := clampf((t - orbit_end) / (ball.t_land - orbit_end), 0.0, 1.0)
	var ease := 1.0 - v * v * (3.0 - 2.0 * v)
	return at_orbit_end * ease * exp(-ball.decay * DROP_DECAY_FACTOR * (t - orbit_end))


## B 구간 보정 창(가장자리가 부드럽게 0 → 1 → 0).
func _correction_window(t: float) -> float:
	var span := orbit_end - launch_time
	if span <= 0.0 or t <= launch_time or t >= orbit_end:
		return 0.0
	var u := (t - launch_time) / span
	var edge := CORRECTION_EDGE
	if u < edge:
		var a := u / edge
		return a * a * (3.0 - 2.0 * a)
	if u > 1.0 - edge:
		var b := (1.0 - u) / edge
		return b * b * (3.0 - 2.0 * b)
	return 1.0


func _solve_ball(ball: Ball, rng: RandomNumberGenerator) -> void:
	var ta := launch_time
	ball.decay = -log(ORBIT_SPEED_RATIO) / maxf(orbit_end - ta, 0.01)
	var launch_speed := BALL_LAUNCH_SPEED * (1.0 + rng.randf_range(-BALL_SPEED_JITTER, BALL_SPEED_JITTER))
	# 발사 직후 화면 속도 = 휠 속도 + 상대 속도 → 상대 속도 = 공 속도 + 휠 최대 속도
	ball.scale = launch_speed + WHEEL_MAX_SPEED
	ball.phi0 = ball.launch_deg - wheel_start
	var steps := TABLE_STEPS
	var dt := ball.t_land / steps
	ball.f_table.resize(steps + 1)
	ball.g_table.resize(steps + 1)
	ball.f_table[0] = 0.0
	ball.g_table[0] = 0.0
	var prev_f := _shape(ball, 0.0)
	var prev_g := prev_f * _correction_window(0.0)
	for k in range(1, steps + 1):
		var t := k * dt
		var f := _shape(ball, t)
		var g := f * _correction_window(t)
		ball.f_table[k] = ball.f_table[k - 1] + (prev_f + f) * 0.5 * dt
		ball.g_table[k] = ball.g_table[k - 1] + (prev_g + g) * 0.5 * dt
		prev_f = f
		prev_g = g
	var g_total := ball.g_table[steps]
	if g_total > 0.0:
		for k in steps + 1:
			ball.g_table[k] /= g_total
	# 1) 보정값을 먼저 전체 속도 배율(발사 속도 차이로 보일 뿐인 ±SCALE_ABSORB)로 흡수하고
	# 2) 남은 값만 B 구간 창에 분산한다 → B 안에서 속도가 눈에 띄게 변하지 않는다.
	var total := ball.scale * ball.f_table[steps]
	var first := _wrap180(ball.pocket_deg - (ball.phi0 + total))
	ball.scale *= 1.0 + clampf(first / total, -SCALE_ABSORB, SCALE_ABSORB)
	var nominal := ball.phi0 + ball.scale * ball.f_table[steps]
	ball.delta = _wrap180(ball.pocket_deg - nominal)
	ball.pocket_unwrapped = nominal + ball.delta


func _plan_bounces(index: int, ball: Ball, rng: RandomNumberGenerator) -> void:
	var span := ball.t_land - orbit_end
	var window_end := orbit_end + span * DROP_BOUNCE_PORTION
	var bounce_duration := minf(BOUNCE_DURATION, span * BOUNCE_DURATION_RATIO)
	var count := 1 if is_short() else rng.randi_range(BOUNCE_MIN, BOUNCE_MAX)
	# 디플렉터 각도를 지나는 시각을 찾는다(튕김 없는 궤적 기준).
	var crossings: Array[float] = []
	var samples := 240
	var prev_sector := _deflector_sector(_raw_ball_angle(ball, orbit_end))
	for k in range(1, samples + 1):
		var t := lerpf(orbit_end, window_end - bounce_duration, float(k) / samples)
		var sector := _deflector_sector(_raw_ball_angle(ball, t))
		if sector != prev_sector:
			crossings.append(t)
		prev_sector = sector
	var chosen: Array[float] = []
	# 앞에서부터 간격을 두고 고른다. 모자라면 창을 균등하게 나눠 채운다.
	var min_gap := bounce_duration * 1.15
	var order: Array[float] = crossings.duplicate()
	if order.size() > count:
		# 무작위로 섞되 결정적(씨앗 고정)
		for k in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp: float = order[k]
			order[k] = order[j]
			order[j] = tmp
	for t in order:
		if chosen.size() >= count:
			break
		var ok := true
		for c in chosen:
			if absf(c - t) < min_gap:
				ok = false
				break
		if ok:
			chosen.append(t)
	var slot := 0
	while chosen.size() < count and slot < count * 4:
		var t2 := orbit_end + (window_end - bounce_duration - orbit_end) * (slot + 0.5) / (count * 2.0)
		var ok2 := true
		for c in chosen:
			if absf(c - t2) < min_gap:
				ok2 = false
				break
		if ok2:
			chosen.append(t2)
		slot += 1
	chosen.sort()
	for i in chosen.size():
		var strength := 1.0 - 0.25 * i
		var bounce := {
			"t": chosen[i],
			"d": bounce_duration * (1.0 - 0.15 * i),
			"r": rng.randf_range(BOUNCE_RADIUS_MIN, BOUNCE_RADIUS_MAX) * strength,
			"h": BOUNCE_HEIGHT * strength,
			"w": rng.randf_range(-BOUNCE_WOBBLE_DEG, BOUNCE_WOBBLE_DEG) * strength,
		}
		ball.bounces.append(bounce)
		var angle := _raw_ball_angle(ball, chosen[i])
		events.append(Event.new(chosen[i], EventKind.BOUNCE, index, _nearest_deflector(angle), R_DEFLECTOR))


func _plan_hops(index: int, ball: Ball, rng: RandomNumberGenerator) -> void:
	var settle := ball.t_settled - ball.t_land
	var count := 1 if is_short() else rng.randi_range(1, HOP_MAX)
	var start := ball.t_land
	events.append(Event.new(ball.t_land, EventKind.LAND, index, 0.0, R_POCKET))
	for i in count:
		var d := settle * (0.45 if count == 1 else (0.4 if i == 0 else 0.28))
		ball.hops.append({"t": start, "d": d, "r": HOP_RADIUS / (i + 1), "h": HOP_HEIGHT / (i + 1)})
		if i > 0:
			events.append(Event.new(start, EventKind.HOP, index, 0.0, R_POCKET))
		start += d
	events.append(Event.new(ball.t_settled, EventKind.SETTLED, index, 0.0, R_POCKET))


## 튕김 흔들림을 뺀 상대각 + 휠 각도.
func _raw_ball_angle(ball: Ball, t: float) -> float:
	return wheel_angle(t) + ball.phi0 + ball.scale * _table_value(ball.f_table, ball.t_land, t) + ball.delta * _table_value(ball.g_table, ball.t_land, t)


func _bounce_wobble(ball: Ball, t: float) -> float:
	for bounce in ball.bounces:
		var s := (t - float(bounce["t"])) / float(bounce["d"])
		if s > 0.0 and s < 1.0:
			return float(bounce["w"]) * sin(TAU * s) * (1.0 - s)
	return 0.0


func _settle_jitter(ball: Ball, t: float) -> float:
	if t >= ball.t_settled:
		return 0.0
	var s := (t - ball.t_land) / (ball.t_settled - ball.t_land)
	return ball.jitter_sign * SETTLE_JITTER_DEG * sin(TAU * 1.5 * s) * (1.0 - s) * (1.0 - s)


func _deflector_sector(angle: float) -> int:
	return floori((angle - DEFLECTOR_OFFSET) / (360.0 / DEFLECTOR_COUNT))


func _nearest_deflector(angle: float) -> float:
	var step := 360.0 / DEFLECTOR_COUNT
	return DEFLECTOR_OFFSET + roundf((angle - DEFLECTOR_OFFSET) / step) * step


static func _table_value(table: PackedFloat64Array, t_end: float, t: float) -> float:
	var steps := table.size() - 1
	if t <= 0.0:
		return table[0]
	if t >= t_end:
		return table[steps]
	var x := t / t_end * steps
	var k := floori(x)
	var frac := x - k
	return lerpf(table[k], table[k + 1], frac)


static func _wrap180(value: float) -> float:
	return fposmod(value + 180.0, 360.0) - 180.0


## 두 각도(도)의 차이를 [-180, 180) 로.
static func angle_difference(a: float, b: float) -> float:
	return _wrap180(a - b)
