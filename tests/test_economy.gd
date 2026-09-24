extends "res://tests/lib/test_case.gd"


func test_max_bet_formula() -> void:
	check_eq(Economy.max_bet(1.0, 1.0), 10.0, "기본 10")
	check_rel(Economy.max_bet(100.0, Economy.bet_limit_mult(5) * 2.0), 10.0 * pow(1.35, 5) * 100.0 * 2.0, 1e-12, "공식")
	check_eq(Economy.min_bet(250.0), 25.0, "최소 = 최대 × 0.1")


func test_max_bet_through_game_state() -> void:
	check_eq(GameState.max_bet(), 10.0, "B1 레벨 0")
	GameState.set_upgrade_level("bet_limit", 7)
	check_rel(GameState.max_bet(), 10.0 * pow(1.35, 7), 1e-12, "베팅 한도 7레벨")
	GameState.modifiers.add_modifier("test", StatModifiers.MAX_BET_MULT, StatModifiers.Op.MULT, 2.0)
	check_rel(GameState.max_bet(), 10.0 * pow(1.35, 7) * 2.0, 1e-12, "max_bet_mult")
	GameState.floor_index = 2
	check_rel(GameState.max_bet(), 10.0 * pow(1.35, 7) * 2.0 * GameData.floor_def(2).bet_mult, 1e-12, "층 배율")
	check_rel(GameState.min_bet(), GameState.max_bet() * 0.1, 1e-12, "최소 베팅")


func test_chip_sizes() -> void:
	check_eq(Economy.chip_amount(200.0, Economy.ChipSize.TENTH), 20.0, "1/10")
	check_eq(Economy.chip_amount(200.0, Economy.ChipSize.HALF), 100.0, "1/2")
	check_eq(Economy.chip_amount(200.0, Economy.ChipSize.MAX), 200.0, "MAX")
	GameState.set_chip_size_mode(Economy.ChipSize.HALF)
	check_eq(GameState.chip_amount(), 5.0, "GameState 1/2")


func test_upgrade_cost_formula() -> void:
	check_eq(Economy.upgrade_cost(100.0, 1.5, 0), 100.0, "레벨 0")
	check_rel(Economy.upgrade_cost(100.0, 1.5, 10), 100.0 * pow(1.5, 10), 1e-12, "레벨 10")
	check_rel(Economy.upgrade_cost(100.0, 1.5, 10, 0.8), 100.0 * pow(1.5, 10) * 0.8, 1e-12, "비용 배율")
	check_rel(Economy.polish_cost(10.0, 3), 10.0 * pow(Economy.POLISH_COST_GROWTH, 3), 1e-12, "광택 비용")


func test_spin_duration() -> void:
	check_eq(Economy.spin_duration(1.0), 6.0, "기본 6초")
	GameState.set_upgrade_level("wheel_speed", 5)
	check_near(GameState.spin_duration(), 6.0 * pow(0.9, 5), 1e-9, "0.9^5")
	check_eq(Economy.spin_duration(0.01), 1.5, "최소 1.5초")


func test_polish_and_marble_mult() -> void:
	check_eq(Economy.polish_mult(0), 1.0, "광택 0")
	check_near(Economy.polish_mult(5), pow(1.25, 5), 1e-12, "광택 5")
	check_near(Economy.polish_mult(9), pow(1.25, 5), 1e-12, "광택 상한")
	GameState.marble_tier = 2
	GameState.polish_level = 2
	check_near(GameState.marble_mult(), 12.0 * 1.25 * 1.25, 1e-9, "구리 + 광택 2")


func test_marble_slots() -> void:
	check_eq(GameState.marble_slots(), 1, "초기 1개")
	GameState.set_upgrade_level("marble_count", 99)
	check_eq(GameState.get_upgrade_level("marble_count"), 7, "업그레이드 상한 7레벨")
	check_eq(GameState.marble_slots(), Economy.MAX_MARBLES_FROM_UPGRADES, "업그레이드로 8개")
	GameState.modifiers.add_modifier("skill:test", StatModifiers.MARBLE_SLOTS_BONUS, StatModifiers.Op.ADD, 10.0)
	check_eq(GameState.marble_slots(), Economy.MAX_MARBLES_TOTAL, "전체 상한 12개")
	GameState.modifiers.add_modifier("penalty:seize", StatModifiers.LOCKED_MARBLES, StatModifiers.Op.ADD, 1.0)
	check_eq(GameState.marble_slots(), 11, "압류로 1개 잠김")


func test_golden_pockets() -> void:
	GameState.set_upgrade_level("golden_pocket", 3)
	check_eq(GameState.golden_pockets.size(), 3, "3개")
	var unique := {}
	for number in GameState.golden_pockets:
		unique[number] = true
	check_eq(unique.size(), 3, "중복 없음")
	GameState.set_upgrade_level("golden_pocket", 1)
	check_eq(GameState.golden_pockets.size(), 1, "줄이면 제거")
	check_eq(GameState.build_spin_context().golden_pocket_mult, 3.0, "황금 배율 ×3")


func test_bankruptcy_rule() -> void:
	check(Economy.is_bankrupt(0.5, 1.0, false), "칩 < 최소 베팅")
	check(not Economy.is_bankrupt(0.5, 1.0, true), "스핀 중에는 파산 아님")
	check(not Economy.is_bankrupt(1.0, 1.0, false), "같으면 파산 아님")


func test_loan_formula() -> void:
	check_eq(Economy.loan_amount(10.0, 0.0), 200.0, "최소 베팅 × 20")
	check_eq(Economy.loan_amount(10.0, 1.0), 600.0, "초당 순수익 × 600")
	check_eq(Economy.debt_repay_amount(600.0), 1200.0, "2배 상환")
