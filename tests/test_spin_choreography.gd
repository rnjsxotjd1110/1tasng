extends "res://tests/lib/test_case.gd"
## 스핀 연출 궤적(SpinChoreography): 착지 정확도, 단계, 튕김 규칙, 연속성.

const LANDING_TOLERANCE_DEG := 0.5
const LANDING_TRIALS := 1000


func _landing_error(choreo: SpinChoreography, index: int, t: float) -> float:
	var ball := choreo.balls[index]
	var expected := choreo.wheel_angle(t) + RouletteRules.pocket_angle(ball.result)
	return absf(SpinChoreography.angle_difference(choreo.ball_angle(index, t), expected))


func test_landing_accuracy_1000_random() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var worst := 0.0
	var worst_end := 0.0
	for trial in LANDING_TRIALS:
		var result := rng.randi_range(0, RouletteRules.POCKET_COUNT - 1)
		var duration := rng.randf_range(Economy.MIN_SPIN_DURATION, Economy.BASE_SPIN_DURATION)
		var start := rng.randf_range(-720.0, 720.0)
		var choreo := SpinChoreography.create([result] as Array[int], duration, start, rng.randi())
		var ball := choreo.balls[0]
		worst = maxf(worst, _landing_error(choreo, 0, ball.t_land))
		worst_end = maxf(worst_end, _landing_error(choreo, 0, choreo.duration))
		# 착지 순간 반지름은 포켓 반지름
		if trial < 50:
			check_near(choreo.ball_radius(0, ball.t_land), SpinChoreography.R_POCKET, 0.01, "착지 반지름")
	check(worst <= LANDING_TOLERANCE_DEG, "착지 오차 최대 %.4f도 ≤ 0.5도" % worst)
	check(worst_end <= LANDING_TOLERANCE_DEG, "끝 시점 오차 최대 %.4f도" % worst_end)


func test_ball_lands_in_pocket_by_number_lookup() -> void:
	for result in RouletteRules.POCKET_COUNT:
		var choreo := SpinChoreography.create([result] as Array[int], 4.0, 37.0 * result, result * 11)
		var relative := choreo.ball_angle(0, choreo.duration) - choreo.wheel_angle(choreo.duration)
		check_eq(RouletteRules.number_at_angle(relative), result, "상대각 → 포켓 %d" % result)


func test_phase_timing() -> void:
	var choreo := SpinChoreography.create([17] as Array[int], 6.0, 0.0, 1)
	check_near(choreo.launch_time, 0.3, 1e-9, "발사 0.3초")
	check_near(choreo.orbit_end, 3.3, 1e-9, "궤도 끝 0.55T")
	check_near(choreo.balls[0].t_land, 4.8, 1e-9, "착지 0.8T")
	check_near(choreo.balls[0].t_settled, 5.4, 1e-9, "안착 0.9T")
	check_eq(choreo.phase_of(0, 0.1), SpinChoreography.Phase.LAUNCH, "A")
	check_eq(choreo.phase_of(0, 1.0), SpinChoreography.Phase.ORBIT, "B")
	check_eq(choreo.phase_of(0, 4.0), SpinChoreography.Phase.DROP, "C")
	check_eq(choreo.phase_of(0, 5.0), SpinChoreography.Phase.SETTLE, "D")
	check_eq(choreo.phase_of(0, 5.8), SpinChoreography.Phase.RIDE, "E")
	check_near(choreo.ball_radius(0, 1.5), SpinChoreography.R_TRACK, 1e-9, "궤도 반지름 97")
	var short := SpinChoreography.create([17] as Array[int], 1.5, 0.0, 1)
	check(short.launch_time < 0.3, "짧은 스핀은 발사 단축")


func test_wheel_decelerates_and_stops() -> void:
	var choreo := SpinChoreography.create([5] as Array[int], 5.0, 10.0, 3)
	check_eq(choreo.wheel_angle(0.0), 10.0, "시작 각도")
	check_near(choreo.wheel_speed(choreo.duration - 0.0001), 0.0, 1.0, "끝에서 거의 정지")
	var prev := choreo.wheel_angle(0.0)
	var monotonic := true
	for k in range(1, 501):
		var angle := choreo.wheel_angle(choreo.duration * k / 500.0)
		if angle > prev + 1e-9:
			monotonic = false
		prev = angle
	check(monotonic, "휠은 반시계로만 돈다")
	check_eq(choreo.wheel_angle(choreo.duration + 1.0), choreo.wheel_angle(choreo.duration), "정지 후 고정")
	# 발사 구간과 이후 구간 사이 각도 연속
	var ta := choreo.launch_time
	check_near(choreo.wheel_angle(ta - 1e-6), choreo.wheel_angle(ta + 1e-6), 0.01, "ta 연속")


func test_bounce_count_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var seen := {}
	for i in 200:
		var long := SpinChoreography.create([rng.randi_range(0, 36)] as Array[int], rng.randf_range(2.5, 6.0), 0.0, rng.randi())
		var n := long.balls[0].bounces.size()
		check(n >= SpinChoreography.BOUNCE_MIN and n <= SpinChoreography.BOUNCE_MAX, "튕김 1~3회 (%d)" % n)
		seen[n] = true
		var short := SpinChoreography.create([rng.randi_range(0, 36)] as Array[int], rng.randf_range(1.5, 2.49), 0.0, rng.randi())
		check_eq(short.balls[0].bounces.size(), 1, "짧은 스핀은 1회")
		check_eq(short.balls[0].hops.size(), 1, "짧은 스핀 안착 홉 1회")
	check_eq(seen.size(), 3, "1·2·3회가 모두 나온다")


func test_bounces_happen_in_drop_phase_and_emit_events() -> void:
	var choreo := SpinChoreography.create([30] as Array[int], 6.0, 0.0, 77)
	var ball := choreo.balls[0]
	var bounce_events := 0
	var land_events := 0
	for event in choreo.events:
		if event.kind == SpinChoreography.EventKind.BOUNCE:
			bounce_events += 1
			check(event.time >= choreo.orbit_end and event.time < ball.t_land, "튕김은 C 구간")
		elif event.kind == SpinChoreography.EventKind.LAND:
			land_events += 1
			check_near(event.time, ball.t_land, 1e-9, "착지 이벤트 시각")
	check_eq(bounce_events, ball.bounces.size(), "튕김마다 이벤트")
	check_eq(land_events, 1, "착지 이벤트 1개")
	for i in range(1, choreo.events.size()):
		check(choreo.events[i - 1].time <= choreo.events[i].time, "이벤트 시간순")


func test_multi_ball_each_lands_on_own_result() -> void:
	var results: Array[int] = [7, 26, 0]
	var choreo := SpinChoreography.create(results, 5.0, 123.0, 5)
	check_eq(choreo.balls.size(), 3, "공 3개")
	for i in results.size():
		var ball := choreo.balls[i]
		check(_landing_error(choreo, i, ball.t_land) <= LANDING_TOLERANCE_DEG, "공 %d 착지" % i)
		check(_landing_error(choreo, i, choreo.duration) <= LANDING_TOLERANCE_DEG, "공 %d 끝" % i)
	check(choreo.balls[1].t_land < choreo.balls[0].t_land, "공마다 착지 시각이 다르다")
	check(choreo.balls[0].launch_deg != choreo.balls[1].launch_deg, "발사 각도가 다르다")
	check(choreo.all_settled_time() <= choreo.duration, "모두 T 안에 안착")


func test_trajectory_is_continuous() -> void:
	# 순간이동이 없어야 한다: 240fps 한 스텝의 이동량이 바로 앞 스텝 이동량 + 2px 를 넘지 않는다.
	for duration: float in [1.5, 3.0, 6.0]:
		var choreo := SpinChoreography.create([19] as Array[int], duration, 45.0, 8)
		var dt := 1.0 / 240.0
		var prev_pos := choreo.ball_offset(0, 0.0)
		var prev_step := -1.0
		var worst_growth := 0.0
		var t := dt
		while t <= choreo.duration:
			var pos := choreo.ball_offset(0, t)
			var step := pos.distance_to(prev_pos)
			if prev_step >= 0.0:
				worst_growth = maxf(worst_growth, step - prev_step)
			prev_step = step
			prev_pos = pos
			t += dt
		check(worst_growth < 2.0, "T=%.1f 궤적 연속 (스텝 증가 최대 %.2fpx)" % [duration, worst_growth])


func test_same_seed_is_deterministic() -> void:
	var a := SpinChoreography.create([12] as Array[int], 4.2, 0.0, 999)
	var b := SpinChoreography.create([12] as Array[int], 4.2, 0.0, 999)
	for k in 20:
		var t := 4.2 * k / 20.0
		check_eq(a.ball_offset(0, t), b.ball_offset(0, t), "같은 씨앗 = 같은 궤적")
	check_eq(a.events.size(), b.events.size(), "같은 이벤트")


func test_ball_speed_decays() -> void:
	var choreo := SpinChoreography.create([3] as Array[int], 6.0, 0.0, 4)
	var early := choreo.ball_speed(0, choreo.launch_time + 0.05)
	var late := choreo.ball_speed(0, choreo.orbit_end - 0.05)
	check(early > late, "B 구간에서 감속 (%.0f → %.0f)" % [early, late])
	check_eq(choreo.ball_speed(0, choreo.balls[0].t_land + 0.1), 0.0, "안착 후 0")
