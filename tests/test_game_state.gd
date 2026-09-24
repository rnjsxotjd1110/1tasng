extends "res://tests/lib/test_case.gd"


func test_starting_state() -> void:
	check_eq(GameState.chips, 100.0, "시작 칩 100")
	check_eq(GameState.clovers, 0, "클로버 0")
	check_eq(GameState.marble_tier, 0, "나무 구슬")
	check_eq(GameState.current_bets.size(), 0, "베팅 없음")


func test_add_and_spend_chips() -> void:
	var changes := watch(EventBus.chips_changed)
	check(GameState.add_chips(50.0), "추가 성공")
	check_eq(GameState.chips, 150.0, "150")
	check_eq(changes[0], [150.0, 50.0, null, null], "시그널 인자")
	check(GameState.spend_chips(30.0), "사용 성공")
	check_eq(GameState.chips, 120.0, "120")
	check_eq(changes[1][1], -30.0, "음수 delta")
	check_eq(GameState.get_stat_value(GameState.STAT_TOTAL_EARNED), 50.0, "누적 획득")
	check(GameState.add_chips(10.0, false), "통계 제외 추가")
	check_eq(GameState.get_stat_value(GameState.STAT_TOTAL_EARNED), 50.0, "누적 획득 그대로")


func test_chip_defense() -> void:
	print("    (다음 경고 로그 6줄은 음수·NaN·INF 방어 테스트의 정상 출력)")
	var changes := watch(EventBus.chips_changed)
	check(not GameState.add_chips(-5.0), "음수 추가 거부")
	check(not GameState.add_chips(NAN), "NaN 추가 거부")
	check(not GameState.add_chips(INF), "INF 추가 거부")
	check(not GameState.spend_chips(-5.0), "음수 사용 거부")
	check(not GameState.spend_chips(NAN), "NaN 사용 거부")
	check(not GameState.spend_chips(INF), "INF 사용 거부")
	check(not GameState.spend_chips(100.01), "잔액 부족 거부")
	check_eq(GameState.chips, 100.0, "칩 변화 없음")
	check_eq(changes.size(), 0, "시그널 없음")
	check(GameState.spend_chips(100.0), "전액 사용 가능")
	check_eq(GameState.chips, 0.0, "0")


func test_milestones_award_clovers() -> void:
	var milestones := watch(EventBus.milestone_reached)
	GameState.add_chips(900.0)  # 1000 = K
	check_eq(milestones.size(), 1, "K 도달")
	check_eq(milestones[0][0], 1, "suffix_index 1")
	check_eq(GameState.clovers, 3, "클로버 +3")
	GameState.spend_chips(500.0)
	GameState.add_chips(500.0)
	check_eq(milestones.size(), 1, "같은 단위 재도달은 보상 없음")
	GameState.add_chips(5e9)  # M 과 B 를 한 번에
	check_eq(milestones.size(), 3, "M, B 동시 도달")
	check_eq(GameState.clovers, 9, "클로버 +6")
	check_eq(GameState.highest_milestone, 3, "최고 단위 B")


func test_clovers() -> void:
	var changes := watch(EventBus.clovers_changed)
	check_eq(GameState.add_clovers(5), 5, "획득")
	check(GameState.spend_clovers(3), "사용")
	check(not GameState.spend_clovers(3), "부족")
	check(not GameState.spend_clovers(-1), "음수 거부")
	check_eq(GameState.clovers, 2, "잔액")
	check_eq(changes.size(), 2, "시그널 2회")
	GameState.modifiers.add_modifier("penalty:fee", StatModifiers.CLOVER_GAIN_MULT, StatModifiers.Op.MULT, Economy.PENALTY_CLOVER_FEE_MULT)
	check_eq(GameState.add_clovers(10), 5, "수수료 절반")


func test_bets_respect_marble_slots() -> void:
	var changes := watch(EventBus.bets_changed)
	check(GameState.add_bet(Bet.red()), "첫 구슬")
	check(not GameState.add_bet(Bet.black()), "구슬 1개뿐")
	check(not GameState.add_bet(Bet.straight(40)), "잘못된 베팅")
	GameState.set_upgrade_level("marble_count", 2)
	check(GameState.add_bet(Bet.red()), "같은 칸 여러 개 가능")
	check(GameState.add_bet(Bet.straight(7)), "세 번째")
	check_eq(GameState.current_bets.size(), 3, "3개")
	check(GameState.remove_bet_at(0), "제거")
	check(not GameState.remove_bet_at(5), "없는 인덱스")
	GameState.clear_bets()
	check_eq(GameState.current_bets.size(), 0, "전부 제거")
	check_eq(changes.size(), 5, "bets_changed 5회")


func test_result_history_capped() -> void:
	for i in 150:
		GameState.push_results([i % 37] as Array[int])
	check_eq(GameState.result_history.size(), Economy.HISTORY_SIZE, "최근 100개")
	check_eq(GameState.result_history[-1], 149 % 37, "최신이 끝")


func test_reset_clears_modifiers() -> void:
	GameState.set_upgrade_level("bet_limit", 3)
	GameState.add_chips(1e6)
	GameState.reset()
	check_eq(GameState.max_bet(), 10.0, "수정자 제거")
	check_eq(GameState.chips, 100.0, "칩 초기화")
	check_eq(GameState.highest_milestone, 0, "마일스톤 초기화")
