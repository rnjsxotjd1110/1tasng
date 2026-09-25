extends "res://tests/lib/test_case.gd"
## FloorService: 다음 층 판정·진행률·이동(비용·배율·클로버·리셋 없음).


func test_next_floor_and_max() -> void:
	check_eq(GameState.floor_index, 0, "시작은 B1")
	check(FloorService.next_floor_def() != null, "다음 층 있음")
	check_eq(FloorService.next_floor_def().id, "1f", "다음 층 = 1F")
	check(not FloorService.is_max_floor(), "B1 은 최고층 아님")
	GameState.floor_index = 4
	check(FloorService.is_max_floor(), "PH 는 최고층")
	check_eq(FloorService.next_floor_def(), null, "PH 다음 층 없음")


func test_progress() -> void:
	GameState.spend_chips(GameState.chips)
	check_eq(FloorService.progress(), 0.0, "칩 0 → 진행률 0")
	GameState.add_chips(5e5)
	check_near(FloorService.progress(), 0.5, 1e-9, "1M 의 절반")
	GameState.add_chips(2e6)
	check_eq(FloorService.progress(), 1.0, "상한 1.0")
	GameState.floor_index = 4
	check_eq(FloorService.progress(), 1.0, "최고층은 항상 1.0")


func test_can_move_requires_cost() -> void:
	check(not FloorService.can_move(), "칩 부족")
	GameState.add_chips(1e6)
	check(FloorService.can_move(), "비용 충분")


func test_move_to_next_spends_chips_and_grants_clover() -> void:
	GameState.add_chips(1e6)
	var changed := watch(EventBus.floor_changed)
	var before_clovers := GameState.clovers
	check(FloorService.move_to_next(), "이동 성공")
	check_eq(GameState.floor_index, 1, "1F 로 이동")
	check_near(GameState.chips, Economy.STARTING_CHIPS, 1e-6, "비용 차감(시작 칩만 남음)")
	check_eq(GameState.clovers, before_clovers + Economy.CLOVER_PER_FLOOR, "클로버 +10")
	check_eq(changed.size(), 1, "floor_changed 1회 발행")
	if changed.size() == 1:
		check_eq(changed[0][0], 1, "새 floor_index 전달")


func test_move_fails_without_enough_chips() -> void:
	check(not FloorService.move_to_next(), "칩 부족 시 실패")
	check_eq(GameState.floor_index, 0, "층 그대로")


func test_move_fails_at_max_floor() -> void:
	GameState.floor_index = 4
	GameState.add_chips(1e30)
	check(not FloorService.move_to_next(), "최고층에서는 이동 불가")


func test_move_does_not_reset_upgrades() -> void:
	GameState.add_chips(1e6 + 100.0)
	UpgradeService.purchase("marble_tier")
	var tier_before := GameState.marble_tier
	FloorService.move_to_next()
	check_eq(GameState.marble_tier, tier_before, "이동해도 구슬 재질 유지(리셋 없음)")
