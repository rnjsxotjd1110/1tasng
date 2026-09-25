extends "res://tests/lib/test_case.gd"
## UpgradeService: 비용·MAX 구매·잠금·광택 초기화·재질 배율 반영·구슬 개수 상한.


func _give(amount: float) -> void:
	GameState.add_chips(amount)


func test_data_matches_spec() -> void:
	var bet := GameData.upgrade("bet_limit")
	check_eq(bet.base_cost, 20.0, "베팅 한도 20")
	check_eq(bet.growth, 3.0, "×3.0(9단계 튜닝: 효과 1.35 보다 낮으면 폭주해 3.0으로 올림, GDD 5장)")
	check_eq(bet.max_level, UpgradeDef.UNLIMITED, "무제한")
	var count := GameData.upgrade("marble_count")
	check_eq(count.base_cost, 300.0, "구슬 300")
	check_eq(count.growth, 22.0, "×22")
	var speed := GameData.upgrade("spin_speed")
	check_eq([speed.base_cost, speed.growth, speed.max_level], [150.0, 3.2, 13], "휠 속도 150·3.2·13")
	var golden := GameData.upgrade("golden_pocket")
	check_eq([golden.base_cost, golden.growth, golden.max_level, golden.required_floor], [5e4, 800.0, 5, 2], "황금 50K·800·5·2F")
	var polish := GameData.upgrade("marble_polish")
	check_eq(polish.growth, Economy.POLISH_COST_GROWTH, "광택 증가율 = Economy")
	check_eq(polish.max_level, Economy.POLISH_MAX_LEVEL, "광택 0~5")
	for marble in GameData.marbles():
		if marble.tier > 0:
			check_rel(marble.polish_base_cost, marble.cost * 0.08, 1e-5, "%s 광택 기본 비용 = 재질 × 0.08" % marble.id)


func test_costs_follow_formulas() -> void:
	var count := GameData.upgrade("marble_count")
	check_eq(UpgradeService.cost_at(count, 0), 300.0, "구슬 2개째 300")
	check_rel(UpgradeService.cost_at(count, 2), 300.0 * 22.0 * 22.0, 1e-12, "구슬 4개째 = 300 × 22^2")
	var tier := GameData.upgrade("marble_tier")
	check_eq(UpgradeService.cost_at(tier, 0), GameData.marble(1).cost, "재질 비용 = 다음 marble_def.cost")
	check_eq(UpgradeService.cost_at(tier, 4), GameData.marble(5).cost, "금 구슬 비용")
	GameState.set_upgrade_level("marble_tier", 3)
	var polish := GameData.upgrade("marble_polish")
	check_rel(UpgradeService.cost_at(polish, 2), GameData.marble(3).cost * 0.08 * pow(1.7, 2), 1e-12, "광택 = 현재 재질 비용 × 0.08 × 1.7^레벨")


func test_cost_mult_stat_applies() -> void:
	var bet := GameData.upgrade("bet_limit")
	var before := UpgradeService.cost_at(bet, 3)
	GameState.modifiers.add_modifier("skill:discount", StatModifiers.UPGRADE_COST_MULT, StatModifiers.Op.MULT, 0.5)
	check_rel(UpgradeService.cost_at(bet, 3), before * 0.5, 1e-12, "upgrade_cost_mult 0.5")
	check_rel(UpgradeService.cost_at(GameData.upgrade("marble_tier"), 0), 25.0, 1e-12, "재질에도 적용(50 × 0.5)")
	check_rel(UpgradeService.cost_for(bet, 3, 5), (before * 0.5) * (pow(bet.growth, 5) - 1.0) / (bet.growth - 1.0), 1e-9, "합계에도 적용")
	_give(1000.0)
	var chips_before := GameState.chips
	var plan := UpgradeService.plan("bet_limit", UpgradeService.BuyMode.ONE)
	check_eq(UpgradeService.purchase("bet_limit"), 1, "구매")
	check_rel(chips_before - GameState.chips, float(plan["cost"]), 1e-12, "할인된 비용만 빠짐")
	check_rel(float(plan["cost"]), 20.0 * 0.5, 1e-12, "20 × 0.5")


func test_geometric_sum_matches_loop() -> void:
	for id: String in ["bet_limit", "marble_count", "spin_speed", "golden_pocket"]:
		var def := GameData.upgrade(id)
		for from_level: int in [0, 1, 3]:
			for n: int in [1, 2, 5]:
				var loop := 0.0
				for i in n:
					loop += UpgradeService.cost_at(def, from_level + i)
				check_rel(UpgradeService.cost_for(def, from_level, n), loop, 1e-9, "%s L%d n%d 닫힌 식 = 반복 합" % [id, from_level, n])


func test_max_affordable_is_exact() -> void:
	var def := GameData.upgrade("bet_limit")
	var budgets: Array[float] = [19.0, 20.0, 44.0, 45.0, 1234.5, 1e6, 1e15, 1e33, 1e60]
	for from_level: int in [0, 7, 120]:
		for budget in budgets:
			var n := UpgradeService.max_affordable(def, from_level, budget, -1)
			if n > 0:
				check(UpgradeService.cost_for(def, from_level, n) <= budget * (1.0 + 1e-9), "L%d 예산 %s: %d개 살 수 있음" % [from_level, budget, n])
			check(UpgradeService.cost_for(def, from_level, n + 1) > budget, "L%d 예산 %s: %d개째는 못 삼" % [from_level, budget, n + 1])
	# 경계: 딱 맞는 예산(20 + 60 = 80 → 2개)
	check_eq(UpgradeService.max_affordable(def, 0, 80.0, -1), 2, "딱 맞으면 산다")
	check_eq(UpgradeService.max_affordable(def, 0, 79.99, -1), 1, "모자라면 1개")
	check_eq(UpgradeService.max_affordable(def, 0, 1e60, 5), 5, "limit")


func test_max_purchase_through_plan() -> void:
	_give(2_000_000.0)
	var plan := UpgradeService.plan("bet_limit", UpgradeService.BuyMode.MAX)
	var expected := UpgradeService.max_affordable(GameData.upgrade("bet_limit"), 0, GameState.chips, -1)
	check_eq(int(plan["count"]), expected, "MAX 수량 = 최대 구매 가능 수")
	check(expected > 10, "2M 으로 10레벨 넘게(%d)" % expected)
	check(bool(plan["affordable"]), "살 수 있음")
	check_eq(UpgradeService.purchase("bet_limit", UpgradeService.BuyMode.MAX), expected, "MAX 구매")
	check_eq(GameState.get_upgrade_level("bet_limit"), expected, "레벨")
	check(GameState.chips < UpgradeService.cost_at(GameData.upgrade("bet_limit"), expected), "남은 칩으로는 다음 레벨 불가")
	check(GameState.chips >= 0.0, "음수 아님")
	# 살 수 없으면 MAX 는 1레벨 비용을 보여 준다
	var next := UpgradeService.plan("bet_limit", UpgradeService.BuyMode.MAX)
	check_eq(int(next["count"]), 1, "못 사면 ×1 표시")
	check(not bool(next["affordable"]), "구매 불가")
	check_eq(UpgradeService.purchase("bet_limit", UpgradeService.BuyMode.MAX), 0, "실패하면 0")


func test_ten_and_max_respect_level_cap() -> void:
	_give(1e30)
	var ten := UpgradeService.plan("marble_count", UpgradeService.BuyMode.TEN)
	check_eq(int(ten["count"]), 7, "남은 레벨이 7이면 ×10 은 7")
	check_eq(UpgradeService.purchase("marble_count", UpgradeService.BuyMode.MAX), 7, "MAX 7")
	check_eq(GameState.marble_slots(), Economy.MAX_MARBLES_FROM_UPGRADES, "구슬 8개")
	check_eq(UpgradeService.lock_status(GameData.upgrade("marble_count")), UpgradeService.Status.MAX_LEVEL, "최대 레벨")
	check_eq(UpgradeService.purchase("marble_count"), 0, "9개째 구매 불가")
	check_eq(GameState.marble_slots(), 8, "여전히 8개")
	check_eq(UpgradeService.purchase("spin_speed", UpgradeService.BuyMode.MAX), 13, "휠 속도 13레벨까지")
	check_near(GameState.spin_duration(), maxf(1.5, 6.0 * pow(0.9, 13)), 1e-9, "스핀 시간 하한 1.5초")


func test_marble_tier_polish_reset_and_cap() -> void:
	var polish := GameData.upgrade("marble_polish")
	check_eq(UpgradeService.lock_status(polish), UpgradeService.Status.LOCKED_MARBLE, "나무는 광택 불가")
	_give(1e7)
	check_eq(UpgradeService.purchase("marble_tier", UpgradeService.BuyMode.MAX), 1, "재질은 MAX 여도 한 단계")
	check_eq(GameState.marble_tier, 1, "돌")
	check_eq(UpgradeService.purchase("marble_polish", UpgradeService.BuyMode.TEN), 5, "광택 5단계(×10 은 남은 5)")
	check_near(GameState.marble_mult(), 1.5 * pow(1.25, 5), 1e-9, "돌 × 광택 5")
	check_eq(UpgradeService.lock_status(polish), UpgradeService.Status.MAX_LEVEL, "광택 MAX")
	UpgradeService.purchase("marble_tier")
	check_eq(GameState.marble_tier, 2, "구리")
	check_eq(GameState.polish_level, 0, "재질이 오르면 광택 0")
	check_eq(GameState.get_upgrade_level("marble_polish"), 0, "광택 레벨 0")
	check_near(GameState.marble_mult(), 12.0, 1e-9, "구리 ×12, 광택 없음")
	UpgradeService.purchase("marble_tier")
	check_eq(GameState.marble_tier, 3, "철")
	var tier := GameData.upgrade("marble_tier")
	check_eq(UpgradeService.lock_status(tier), UpgradeService.Status.CAPPED_BY_FLOOR, "B1 상한 = 철")
	check_eq(UpgradeService.floor_for_marble_tier(4), 1, "은 구슬은 1F")
	GameState.floor_index = 1
	check_eq(UpgradeService.lock_status(tier), UpgradeService.Status.OK, "1F 에서는 은 구슬 가능")


func test_marble_mult_reaches_payout() -> void:
	_give(100.0)
	check_eq(UpgradeService.purchase("marble_tier"), 1, "돌 구매")
	var controller := SpinController.new()
	controller.instant_resolve = true
	var result: int = RngService.peek_next(1)[0]
	GameState.add_bet(Bet.straight(result))
	controller.start_spin()
	check_near(controller.last_outcome.total_return, 10.0 * 36.0 * 1.5, 1e-9, "돌 ×1.5 가 당첨금에 반영")
	GameState.set_upgrade_level("marble_polish", 2)
	result = RngService.peek_next(1)[0]
	GameState.clear_bets()
	GameState.add_bet(Bet.straight(result))
	controller.start_spin()
	check_near(controller.last_outcome.total_return, 10.0 * 36.0 * 1.5 * 1.25 * 1.25, 1e-9, "광택도 반영")


func test_golden_pocket_requires_floor() -> void:
	_give(1e9)
	var def := GameData.upgrade("golden_pocket")
	check_eq(UpgradeService.lock_status(def), UpgradeService.Status.LOCKED_FLOOR, "2F 전에는 잠김")
	check_eq(UpgradeService.purchase("golden_pocket"), 0, "잠겨 있으면 구매 불가")
	GameState.floor_index = 2
	var added := watch(EventBus.golden_pockets_added)
	var bought := watch(EventBus.upgrade_purchased)
	check_eq(UpgradeService.purchase("golden_pocket"), 1, "2F 에서 구매")
	check_eq(GameState.golden_pockets.size(), 1, "황금 포켓 1개")
	check_eq(added.size(), 1, "golden_pockets_added 발행")
	if added.size() == 1:
		check_eq(added[0][0], GameState.golden_pockets, "새 포켓 번호")
	check_eq(bought.size(), 1, "upgrade_purchased 1회")
	if bought.size() == 1:
		check_eq([bought[0][0], bought[0][1]], ["golden_pocket", 1], "upgrade_purchased(id, 레벨)")


func test_not_enough_chips_changes_nothing() -> void:
	var chips := GameState.chips
	check_eq(UpgradeService.purchase("marble_count"), 0, "300 칩 없음")
	check_eq(GameState.chips, chips, "칩 그대로")
	check_eq(GameState.get_upgrade_level("marble_count"), 0, "레벨 그대로")
	check_eq(UpgradeService.plan("marble_count", UpgradeService.BuyMode.ONE)["status"], UpgradeService.Status.NOT_ENOUGH_CHIPS, "칩 부족 상태")


func test_any_affordable() -> void:
	GameState.spend_chips(GameState.chips)
	check(not UpgradeService.any_affordable(), "0 칩")
	_give(20.0)
	check(UpgradeService.any_affordable(), "베팅 한도 20")


func test_display_values() -> void:
	var tier := GameData.upgrade("marble_tier")
	check_eq(UpgradeService.format_value(tier, UpgradeService.display_value(tier, 4)), "×900", "은 ×900")
	check_eq(UpgradeService.format_value(tier, UpgradeService.display_value(tier, 5)), "×8.00K", "금 ×8.00K")
	var speed := GameData.upgrade("spin_speed")
	check_eq(UpgradeService.format_value(speed, UpgradeService.display_value(speed, 1)), "5.4s", "휠 속도 5.4초")
	var count := GameData.upgrade("marble_count")
	check_eq(UpgradeService.format_value(count, UpgradeService.display_value(count, 2)), "3", "구슬 3개")
