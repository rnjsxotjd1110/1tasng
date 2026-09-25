extends "res://tests/lib/test_case.gd"
## 더블 볼(6단계, Y10): RouletteRules.resolve() 는 공 개수(results 배열 길이)만큼 한 베팅을 여러 번
## 판정해야 하고(적중마다 배당 누적, 베팅액은 한 번만 차감), GameState.ball_count()/SpinController 는
## extra_balls 스탯만큼 공을 늘려 실제로 결과를 그만큼 만들어야 한다.


func after_each() -> void:
	GameState.reset()
	super.after_each()


func test_two_results_both_hit_pays_twice() -> void:
	var bet := Bet.straight(7)
	bet.amount = 10.0
	var outcome := RouletteRules.resolve([bet], [7, 7])
	check_eq(outcome.bet_results[0].hit_count, 2, "7,7 모두 적중 시 2회 판정")
	check_near(outcome.bet_results[0].payout, 10.0 * (RouletteRules.PAYOUT_STRAIGHT + 1) * 2.0, 0.001, "적중 2회면 배당도 2배")
	check_eq(outcome.total_bet, 10.0, "베팅액은 공 개수와 무관하게 한 번만")


func test_two_results_one_hit_pays_once() -> void:
	var bet := Bet.straight(7)
	bet.amount = 10.0
	var outcome := RouletteRules.resolve([bet], [7, 12])
	check_eq(outcome.bet_results[0].hit_count, 1, "7만 적중 시 1회 판정")
	check_near(outcome.bet_results[0].payout, 10.0 * (RouletteRules.PAYOUT_STRAIGHT + 1), 0.001, "적중 1회분 배당")


func test_two_results_neither_hit_loses() -> void:
	var bet := Bet.straight(7)
	bet.amount = 10.0
	var outcome := RouletteRules.resolve([bet], [1, 2])
	check_eq(outcome.bet_results[0].hit_count, 0, "둘 다 빗나가면 0회")
	check_eq(outcome.bet_results[0].payout, 0.0, "배당 없음")


func test_hit_straights_lists_number_once_per_hit() -> void:
	var bet := Bet.straight(5)
	bet.amount = 10.0
	var outcome := RouletteRules.resolve([bet], [5, 5])
	check_eq(outcome.hit_straights.count(5), 2, "적중 배열에도 적중 횟수만큼 들어간다")


func test_ball_count_reflects_extra_balls_stat() -> void:
	check_eq(GameState.ball_count(), Economy.BASE_BALLS, "기본 공 1개")
	GameState.modifiers.add_modifier("skill:y10", StatModifiers.EXTRA_BALLS, StatModifiers.Op.ADD, 1.0)
	check_eq(GameState.ball_count(), Economy.BASE_BALLS + 1, "extra_balls +1 이면 공 2개")


func test_start_spin_produces_one_result_per_ball() -> void:
	GameState.modifiers.add_modifier("skill:y10", StatModifiers.EXTRA_BALLS, StatModifiers.Op.ADD, 1.0)
	GameState.chips = 1000.0
	check(GameState.add_bet(Bet.red()), "베팅 성공")
	var controller := SpinController.new()
	controller.instant_resolve = false
	var error := controller.start_spin()
	check_eq(error, SpinController.SpinError.OK, "정상 시작")
	check_eq(controller.active_results.size(), 2, "공 2개면 결과도 2개 생성")
