extends "res://tests/lib/test_case.gd"

var controller: SpinController


func before_each() -> void:
	super.before_each()
	controller = SpinController.new()
	controller.instant_resolve = true


func test_rejects_without_bets() -> void:
	check_eq(controller.start_spin(), SpinController.SpinError.NO_BETS, "베팅 없음")
	check_eq(GameState.chips, 100.0, "칩 그대로")


func test_full_spin_flow_matches_peeked_result() -> void:
	GameState.add_bet(Bet.red())
	var predicted: int = RngService.peek_next(1)[0]
	var started := watch(EventBus.spin_started)
	var resolved := watch(EventBus.spin_resolved)
	check_eq(controller.start_spin(), SpinController.SpinError.OK, "스핀 성공")
	check_eq(started.size(), 1, "spin_started")
	check_eq(started[0][0], [predicted] as Array[int], "미리 본 결과가 그대로 나옴")
	check_eq(started[0][1], 6.0, "스핀 시간 6초")
	check_eq(resolved.size(), 1, "spin_resolved")
	var outcome: SpinOutcome = resolved[0][0]
	check_eq(outcome.total_bet, 10.0, "MAX 칩 = 최대 베팅 10")
	var expected_chips := 90.0 + (20.0 if RouletteRules.is_red(predicted) else 0.0)
	check_eq(GameState.chips, expected_chips, "정산 반영")
	check(controller.is_idle(), "IDLE 복귀")
	check(not GameState.spin_in_progress, "스핀 종료")
	check_eq(GameState.result_history, [predicted] as Array[int], "기록")
	check_eq(GameState.get_stat_value(GameState.STAT_TOTAL_SPINS), 1.0, "총 스핀")
	check_eq(GameState.last_bets.size(), 1, "직전 베팅 저장")
	check_eq(GameState.current_bets.size(), 1, "베팅은 유지(반복 베팅)")


func test_manual_finish_state_machine() -> void:
	controller.instant_resolve = false
	var states := watch(controller.state_changed)
	GameState.add_bet(Bet.straight(5))
	check_eq(controller.start_spin(), SpinController.SpinError.OK, "시작")
	check_eq(controller.state, SpinController.State.SPINNING, "SPINNING")
	check(GameState.spin_in_progress, "스핀 중")
	check_eq(controller.start_spin(), SpinController.SpinError.BUSY, "중복 스핀 거부")
	GameState.chips = 0.0
	check(not GameState.is_bankrupt(), "스핀 중에는 파산 아님")
	GameState.chips = 90.0
	check(controller.finish_spin() != null, "정산")
	check_eq(states.size(), 3, "SPINNING → RESOLVING → IDLE")
	check_eq(states[1][0], SpinController.State.RESOLVING, "RESOLVING 거침")
	print("    (다음 경고 로그 1줄은 IDLE 상태 finish_spin 방어 테스트의 정상 출력)")
	check(controller.finish_spin() == null, "IDLE 에서 finish 는 무시")


func test_seeded_spins_are_deterministic() -> void:
	var run := func() -> Array:
		GameState.reset()
		RngService.set_seed(777)
		GameState.add_bet(Bet.red())
		var out: Array = []
		for i in 20:
			if controller.start_spin() != SpinController.SpinError.OK:
				break
			out.append(GameState.result_history[-1])
		return out
	var first: Array = run.call()
	var second: Array = run.call()
	check_eq(first.size(), 20, "20스핀")
	check_eq(first, second, "같은 시드 = 같은 결과")


func test_amount_scales_down_when_short() -> void:
	GameState.set_upgrade_level("marble_count", 3)  # 구슬 4개
	for i in 4:
		GameState.add_bet(Bet.red())
	GameState.chips = 20.0  # MAX 10 × 4 = 40 필요
	check_eq(SpinController.affordable_amount(10.0, 20.0, 4, 1.0), 5.0, "20 ÷ 4 = 5")
	check_eq(controller.start_spin(), SpinController.SpinError.OK, "줄여서 스핀")
	check_eq(controller.last_outcome.total_bet, 20.0, "보유 칩 전부")
	check_eq(SpinController.affordable_amount(10.0, 3.0, 4, 1.0), 0.0, "최소 베팅 미만이면 불가")


func test_not_enough_chips_and_bankrupt() -> void:
	GameState.add_bet(Bet.red())
	GameState.chips = 0.5
	check_eq(controller.start_spin(), SpinController.SpinError.NOT_ENOUGH_CHIPS, "칩 부족")
	check(GameState.is_bankrupt(), "파산 상태")
	var bankrupt := watch(EventBus.bankrupt)
	GameState.chips = 1.0  # 최소 베팅 1 → 스핀 가능, 지면 파산
	RngService.set_seed(1)
	var found_loss := false
	for i in 50:
		GameState.chips = 1.0
		var result: int = RngService.peek_next(1)[0]
		controller.start_spin()
		if not RouletteRules.is_red(result):
			found_loss = true
			break
	check(found_loss, "패배 발생")
	check(bankrupt.size() >= 1, "패배 후 bankrupt 발행")


func test_straight_hit_awards_clover_and_streak() -> void:
	# 결과를 미리 보고 그 숫자에 걸어 적중시킨다.
	var target: int = RngService.peek_next(1)[0]
	GameState.add_bet(Bet.straight(target))
	controller.start_spin()
	check_eq(GameState.clovers, 1, "개별숫자 적중 +1")
	check_eq(GameState.get_stat_value(GameState.STAT_STRAIGHT_HITS), 1.0, "적중 통계")
	check_eq(controller.last_outcome.tier, SpinOutcome.Tier.BIG, "BIG")


func test_win_streak_awards_clover_every_five() -> void:
	GameState.add_chips(1e9)  # 마일스톤 보상을 먼저 받아 두고 이후 클로버만 센다
	var clovers_before := GameState.clovers
	var wins := 0
	var guard := 0
	# 매 스핀 결과를 미리 보고 맞는 색에 걸어 연승을 만든다.
	while wins < 10 and guard < 100:
		guard += 1
		var result: int = RngService.peek_next(1)[0]
		GameState.clear_bets()
		if result == 0:
			GameState.add_bet(Bet.straight(0))
		else:
			GameState.add_bet(Bet.red() if RouletteRules.is_red(result) else Bet.black())
		controller.start_spin()
		wins += 1
	check_eq(GameState.win_streak, 10, "10연승")
	var straight_clovers := int(GameState.get_stat_value(GameState.STAT_STRAIGHT_HITS))
	check_eq(GameState.clovers - clovers_before - straight_clovers, 2, "5연승마다 +1 (2회)")
	check_eq(GameState.get_stat_value(GameState.STAT_BEST_STREAK), 10.0, "최대 연승")
	GameState.clear_bets()
	var loss: int = RngService.peek_next(1)[0]
	GameState.add_bet(Bet.straight((loss + 1) % 37))
	controller.start_spin()
	check_eq(GameState.win_streak, 0, "패배 시 연승 초기화")


func test_multi_ball_costs_once() -> void:
	GameState.modifiers.add_modifier("skill:double_ball", StatModifiers.EXTRA_BALLS, StatModifiers.Op.ADD, 1.0)
	GameState.add_bet(Bet.red())
	var started := watch(EventBus.spin_started)
	controller.start_spin()
	check_eq((started[0][0] as Array).size(), 2, "공 2개")
	check_eq(controller.last_outcome.total_bet, 10.0, "비용은 한 번")
	check_eq(GameState.result_history.size(), 2, "기록 2개")


func test_payout_uses_modifiers() -> void:
	GameState.set_upgrade_level("marble_tier", 1)  # 돌 ×1.5
	GameState.modifiers.add_modifier("buff:x", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT, 2.0)
	var result: int = RngService.peek_next(1)[0]
	GameState.add_bet(Bet.straight(result))
	controller.start_spin()
	check_near(controller.last_outcome.total_return, 10.0 * 36.0 * 1.5 * 2.0, 1e-9, "배율 반영")
