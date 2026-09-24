extends "res://tests/lib/test_case.gd"


func _one(bet: Bet, result: int, context: SpinContext = null) -> SpinOutcome:
	var bets: Array[Bet] = [bet]
	var results: Array[int] = [result]
	return RouletteRules.resolve(bets, results, context)


func test_outside_bets_pay_1_to_1() -> void:
	check_eq(_one(Bet.red(10.0), 1).total_return, 20.0, "RED 적중")
	check_eq(_one(Bet.red(10.0), 2).total_return, 0.0, "RED 실패")
	check_eq(_one(Bet.black(10.0), 2).total_return, 20.0, "BLACK 적중")
	check_eq(_one(Bet.black(10.0), 1).total_return, 0.0, "BLACK 실패")
	check_eq(_one(Bet.odd(10.0), 7).total_return, 20.0, "ODD 적중")
	check_eq(_one(Bet.odd(10.0), 8).total_return, 0.0, "ODD 실패")
	check_eq(_one(Bet.even(10.0), 8).total_return, 20.0, "EVEN 적중")
	check_eq(_one(Bet.even(10.0), 7).total_return, 0.0, "EVEN 실패")


func test_straight_pays_35_to_1() -> void:
	var outcome := _one(Bet.straight(17, 10.0), 17)
	check_eq(outcome.total_return, 360.0, "36배 반환")
	check_eq(outcome.net, 350.0, "순이익")
	check_eq(outcome.hit_straights, [17] as Array[int], "적중 숫자 목록")
	check_eq(_one(Bet.straight(17, 10.0), 18).total_return, 0.0, "빗나감")
	check_eq(_one(Bet.straight(0, 1.0), 0).total_return, 36.0, "0 개별숫자")


func test_zero_loses_all_outside_bets() -> void:
	for bet: Bet in [Bet.red(1.0), Bet.black(1.0), Bet.odd(1.0), Bet.even(1.0)]:
		var outcome := _one(bet, 0)
		check_eq(outcome.total_return, 0.0, "0에서 %s 패배" % bet)
		check_eq(outcome.tier, SpinOutcome.Tier.LOSS, "등급 LOSS")


func test_multiple_bets_same_spot() -> void:
	var bets: Array[Bet] = [Bet.red(5.0), Bet.red(5.0), Bet.straight(3, 5.0)]
	var results: Array[int] = [3]
	var outcome := RouletteRules.resolve(bets, results)
	check_eq(outcome.total_bet, 15.0, "총 베팅")
	check_eq(outcome.total_return, 10.0 + 10.0 + 180.0, "총 반환")
	check_eq(outcome.win_count(), 3, "당첨 베팅 수")


func test_two_balls_cost_once_payout_summed() -> void:
	var bets: Array[Bet] = [Bet.red(10.0), Bet.straight(2, 10.0)]
	var results: Array[int] = [1, 2]  # 1 = 빨강, 2 = 검정
	var outcome := RouletteRules.resolve(bets, results)
	check_eq(outcome.total_bet, 20.0, "비용은 한 번만")
	check_eq(outcome.bet_results[0].hit_count, 1, "RED 는 공 1개만 맞음")
	check_eq(outcome.bet_results[0].payout, 20.0, "RED 반환")
	check_eq(outcome.bet_results[1].payout, 360.0, "STRAIGHT 반환")
	check_eq(outcome.total_return, 380.0, "합산")
	var double_red: Array[int] = [1, 3]
	var both := RouletteRules.resolve([Bet.red(10.0)] as Array[Bet], double_red)
	check_eq(both.bet_results[0].hit_count, 2, "공 2개 모두 적중")
	check_eq(both.total_return, 40.0, "두 번 지급")
	check_eq(both.total_bet, 10.0, "비용 한 번")


func test_multipliers_apply_to_wins_only() -> void:
	var context := SpinContext.new()
	context.marble_mult = 1.5
	context.floor_mult = 2.0
	context.payout_mult_all = 1.1
	context.payout_mult_color = 3.0
	context.payout_mult_parity = 5.0
	context.straight_payout_bonus = 0.5
	check_near(_one(Bet.red(10.0), 1, context).total_return, 20.0 * 1.5 * 2.0 * 1.1 * 3.0, 1e-9, "색")
	check_near(_one(Bet.odd(10.0), 1, context).total_return, 20.0 * 1.5 * 2.0 * 1.1 * 5.0, 1e-9, "홀짝")
	check_near(_one(Bet.straight(1, 10.0), 1, context).total_return, 360.0 * 1.5 * 2.0 * 1.1 * 1.5, 1e-9, "개별숫자")
	var lost := _one(Bet.red(10.0), 2, context)
	check_eq(lost.total_bet, 10.0, "비용은 배율 없음")
	check_eq(lost.net, -10.0, "패배 순손실")


func test_golden_pocket_triples_all_wins() -> void:
	var context := SpinContext.new()
	context.golden_pockets = [7] as Array[int]
	context.golden_pocket_mult = 3.0
	var bets: Array[Bet] = [Bet.red(10.0), Bet.odd(10.0), Bet.straight(7, 10.0), Bet.black(10.0)]
	var outcome := RouletteRules.resolve(bets, [7] as Array[int], context)
	check(outcome.golden_hit, "황금 포켓 적중")
	check_eq(outcome.total_return, (20.0 + 20.0 + 360.0) * 3.0, "모든 당첨 ×3")
	var normal := RouletteRules.resolve(bets, [9] as Array[int], context)
	check(not normal.golden_hit, "일반 포켓")
	check_eq(normal.total_return, 40.0, "배율 없음")


func test_near_miss() -> void:
	var outcome := _one(Bet.straight(32, 1.0), 0)
	check(outcome.near_miss, "0 옆의 32")
	check(not _one(Bet.straight(5, 1.0), 0).near_miss, "먼 숫자")
	check(not _one(Bet.straight(0, 1.0), 0).near_miss, "적중은 아깝다가 아님")


func test_tier_classification() -> void:
	check_eq(_one(Bet.red(1.0), 2).tier, SpinOutcome.Tier.LOSS, "LOSS")
	check_eq(_one(Bet.red(1.0), 1).tier, SpinOutcome.Tier.NORMAL, "NORMAL")
	var context := SpinContext.new()
	context.marble_mult = 5.0  # 반환 10, 순이익 9 → 9배
	check_eq(_one(Bet.red(1.0), 1, context).tier, SpinOutcome.Tier.GOOD, "GOOD")
	context.marble_mult = 15.0  # 순이익 29배
	check_eq(_one(Bet.red(1.0), 1, context).tier, SpinOutcome.Tier.BIG, "BIG 배율")
	context.marble_mult = 60.0  # 순이익 119배
	check_eq(_one(Bet.red(1.0), 1, context).tier, SpinOutcome.Tier.JACKPOT, "JACKPOT 배율")
	check_eq(_one(Bet.straight(4, 1.0), 4).tier, SpinOutcome.Tier.BIG, "개별숫자 1개 = BIG")
	var two: Array[Bet] = [Bet.straight(4, 1.0), Bet.straight(4, 1.0)]
	check_eq(RouletteRules.resolve(two, [4] as Array[int]).tier, SpinOutcome.Tier.JACKPOT, "개별숫자 2개 = JACKPOT")
	# 일부만 이겨 순손실이어도 당첨이 있으면 NORMAL
	var mixed: Array[Bet] = [Bet.red(1.0), Bet.black(1.0), Bet.even(1.0)]
	var mixed_outcome := RouletteRules.resolve(mixed, [1] as Array[int])
	check(mixed_outcome.net < 0.0, "순손실")
	check_eq(mixed_outcome.tier, SpinOutcome.Tier.NORMAL, "부분 당첨 NORMAL")
