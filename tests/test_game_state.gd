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
	check_eq(GameState.clovers, 1, "클로버 +1(9단계 후속: CLOVER_PER_MILESTONE 3→1)")
	GameState.spend_chips(500.0)
	GameState.add_chips(500.0)
	check_eq(milestones.size(), 1, "같은 단위 재도달은 보상 없음")
	GameState.add_chips(5e9)  # M 과 B 를 한 번에
	check_eq(milestones.size(), 3, "M, B 동시 도달")
	check_eq(GameState.clovers, 3, "클로버 +2(9단계 후속: 단가 인하)")
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


# ── 빚(5단계) ────────────────────────────────────────────

func test_bankruptcy_grants_loan_immediately() -> void:
	GameState.chips = 0.0
	var debt_changes := watch(EventBus.debt_changed)
	var bankrupt := watch(EventBus.bankrupt)
	check(GameState.check_bankruptcy(), "파산 판정")
	check(GameState.has_debt(), "대출로 빚 생김")
	check(GameState.chips > 0.0, "대출금이 칩으로 지급됨")
	check_eq(GameState.get_stat_value(GameState.STAT_TOTAL_EARNED), 0.0, "대출금은 누적 획득에 안 들어감")
	check_eq(GameState.get_stat_value(GameState.STAT_LOANS_TAKEN), 1.0, "대출 횟수 +1")
	check_eq(GameState.pending_baron_event.get("type"), "loan", "컷신 예약")
	check_eq(debt_changes.size(), 1, "debt_changed")
	check_eq(bankrupt.size(), 1, "bankrupt")
	check(not GameState.is_bankrupt(), "대출 후에는 파산 아님")


func test_fourth_bankruptcy_merges_into_biggest_debt() -> void:
	for i in Economy.MAX_LOANS:
		GameState.chips = 0.0
		GameState.check_bankruptcy()
	check_eq(GameState.debts.size(), Economy.MAX_LOANS, "3건까지만")
	GameState.chips = 0.0
	GameState.check_bankruptcy()
	check_eq(GameState.debts.size(), Economy.MAX_LOANS, "4번째는 합산, 건수 그대로")
	check_eq(GameState.pending_baron_event.get("merged"), true, "합산 표시")


func test_repay_all_pays_full_remaining() -> void:
	GameState.chips = 1000.0
	GameState.debts = [{"principal": 50.0, "remaining": 80.0}]
	var repaid := GameState.repay_all(0)
	check_eq(repaid, 80.0, "전액 상환")
	check(GameState.debts.is_empty(), "빚 없음")
	check_eq(GameState.chips, 920.0, "칩 차감")


func test_repay_half_pays_half_remaining() -> void:
	GameState.chips = 1000.0
	GameState.debts = [{"principal": 50.0, "remaining": 80.0}]
	var repaid := GameState.repay_half(0)
	check_eq(repaid, 40.0, "절반 상환")
	check_near(float(GameState.debts[0]["remaining"]), 40.0, 1e-9, "남은 절반")


func test_repay_all_does_nothing_when_not_affordable() -> void:
	GameState.chips = 10.0
	GameState.debts = [{"principal": 50.0, "remaining": 80.0}]
	var repaid := GameState.repay_all(0)
	check_eq(repaid, 0.0, "칩 부족이면 상환 없음")
	check_eq(GameState.chips, 10.0, "칩 그대로")
	check_near(float(GameState.debts[0]["remaining"]), 80.0, 1e-9, "빚 그대로")


func test_paying_off_all_debt_awards_clover_and_baron_event() -> void:
	GameState.chips = 1000.0
	GameState.debts = [{"principal": 50.0, "remaining": 30.0}]
	var before := GameState.clovers
	GameState.repay_all(0)
	check_eq(GameState.clovers - before, Economy.CLOVER_PER_DEBT_PAID, "완납 클로버")
	check_eq(GameState.pending_baron_event.get("type"), "debt_paid", "완납 컷신 예약")


func test_paying_off_one_of_several_debts_does_not_trigger_payoff_event() -> void:
	GameState.chips = 1000.0
	GameState.debts = [{"principal": 50.0, "remaining": 30.0}, {"principal": 50.0, "remaining": 40.0}]
	GameState.pending_baron_event = {}
	GameState.repay_all(0)
	check_eq(GameState.pending_baron_event, {}, "총 빚이 남아있으면 완납 연출 없음")


func test_auto_repay_debt_pays_oldest_first() -> void:
	GameState.chips = 1000.0
	GameState.debts = [{"principal": 10.0, "remaining": 10.0}, {"principal": 10.0, "remaining": 100.0}]
	var repaid := GameState.auto_repay_debt(100.0)
	check_near(repaid, 25.0, 1e-9, "당첨금 100의 25% 자동 상환")
	check_eq(GameState.debts.size(), 1, "첫 빚(10)은 완전히 갚여 제거됨")
	check_near(float(GameState.debts[0]["remaining"]), 85.0, 1e-9, "남은 15가 둘째 빚에 적용(100-15)")
	check_near(GameState.chips, 975.0, 1e-9, "칩에서 상환액 25 차감")


func test_paying_off_debt_clears_active_penalties() -> void:
	GameState.chips = 1000.0
	GameState.debts = [{"principal": 50.0, "remaining": 30.0}]
	GameState.add_penalty_timed("watcher", StatModifiers.SPIN_DURATION_MULT, StatModifiers.Op.MULT, 2.0, 30.0)
	GameState.add_penalty_charge(GameState.PENALTY_ID_SEIZE_MARBLE, StatModifiers.LOCKED_MARBLES, StatModifiers.Op.ADD, 1.0, 1)
	var ended := watch(EventBus.buff_ended)
	GameState.repay_all(0)
	check(not GameState.modifiers.has_source("penalty:watcher"), "시간제 패널티 해제")
	check(not GameState.modifiers.has_source("penalty:seize_marble"), "소모형 패널티도 해제")
	check(ended.size() >= 2, "buff_ended 발행(연출 쪽 정리용)")


func test_debt_total_and_has_debt() -> void:
	check(not GameState.has_debt(), "초기 빚 없음")
	check_eq(GameState.debt_total(), 0.0, "0")
	GameState.debts = [{"principal": 10.0, "remaining": 5.0}, {"principal": 10.0, "remaining": 7.0}]
	check(GameState.has_debt(), "빚 있음")
	check_eq(GameState.debt_total(), 12.0, "합계")
