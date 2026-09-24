extends "res://tests/lib/test_case.gd"


func test_wheel_has_37_unique_pockets() -> void:
	var order := RouletteRules.WHEEL_ORDER
	check_eq(order.size(), 37, "포켓 수")
	var seen := {}
	for number in order:
		seen[number] = true
	check_eq(seen.size(), 37, "중복 없음")
	for number in 37:
		check(seen.has(number), "%d 포함" % number)
	check_eq(order[0], 0, "0번이 첫 포켓")


func test_colors_18_red_18_black() -> void:
	var red := 0
	var black := 0
	var green := 0
	for number in 37:
		match RouletteRules.color_of(number):
			RouletteRules.PocketColor.RED:
				red += 1
			RouletteRules.PocketColor.BLACK:
				black += 1
			_:
				green += 1
	check_eq(red, 18, "빨강")
	check_eq(black, 18, "검정")
	check_eq(green, 1, "초록")
	check_eq(RouletteRules.color_of(0), RouletteRules.PocketColor.GREEN, "0은 초록")
	check(RouletteRules.is_red(32) and RouletteRules.is_black(15), "32 빨강, 15 검정")


func test_wheel_alternates_colors() -> void:
	# 실제 유럽식 휠은 0 을 제외하면 빨강·검정이 번갈아 나온다.
	var order := RouletteRules.WHEEL_ORDER
	for i in range(1, 36):
		check(RouletteRules.color_of(order[i]) != RouletteRules.color_of(order[i + 1]), "%d·%d 색 교대" % [order[i], order[i + 1]])


func test_parity() -> void:
	check(not RouletteRules.is_odd(0) and not RouletteRules.is_even(0), "0은 홀짝 아님")
	check(RouletteRules.is_odd(1) and RouletteRules.is_odd(35), "홀")
	check(RouletteRules.is_even(2) and RouletteRules.is_even(36), "짝")
	check(not RouletteRules.is_odd(37) and not RouletteRules.is_even(38), "범위 밖")


func test_pocket_angle() -> void:
	check_eq(RouletteRules.pocket_angle(0), 0.0, "0번 = 0도")
	check_near(RouletteRules.pocket_angle(32), 360.0 / 37.0, 1e-6, "32번 = 1칸")
	check_near(RouletteRules.pocket_angle(26), 36.0 * 360.0 / 37.0, 1e-6, "26번 = 마지막 칸")
	for number in 37:
		check_eq(RouletteRules.number_at_angle(RouletteRules.pocket_angle(number)), number, "각도 역변환 %d" % number)
	check_eq(RouletteRules.number_at_angle(-360.0 / 37.0), 26, "음수 각도")


func test_neighbors() -> void:
	var around_zero := RouletteRules.neighbors(0)
	check(around_zero.has(26) and around_zero.has(32) and around_zero.size() == 2, "0의 이웃 26, 32")
	check(RouletteRules.are_neighbors(17, 25) and RouletteRules.are_neighbors(17, 34), "17의 이웃")
	check(not RouletteRules.are_neighbors(17, 18), "17·18은 이웃 아님")
	check_eq(RouletteRules.neighbors(5, 2).size(), 4, "거리 2")


func test_bet_validity() -> void:
	check(Bet.red().is_valid(), "RED")
	check(Bet.straight(0).is_valid() and Bet.straight(36).is_valid(), "STRAIGHT 0/36")
	check(not Bet.straight(37).is_valid() and not Bet.straight(-1).is_valid(), "STRAIGHT 범위 밖")
	var restored := Bet.from_dict(Bet.straight(17, 5.0).to_dict())
	check(restored.same_spot(Bet.straight(17)) and restored.amount == 5.0, "직렬화 왕복")
