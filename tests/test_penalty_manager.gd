extends "res://tests/lib/test_case.gd"

var pm: PenaltyManager


func before_each() -> void:
	super.before_each()
	pm = PenaltyManager.new()


func test_no_debt_means_no_timer() -> void:
	pm.process(1000.0)
	check_eq(pm.time_left, -1.0, "빚이 없으면 타이머가 돌지 않음")


func test_interval_scales_with_loan_count() -> void:
	GameState.debts = [{"principal": 10.0, "remaining": 10.0}]
	for i in 30:
		var t := pm._next_interval()
		check(t >= Economy.PENALTY_INTERVAL_MIN_BY_LOANS[0] and t <= Economy.PENALTY_INTERVAL_MAX_BY_LOANS[0], "1건: 60~120")
	GameState.debts = [{"principal": 10.0, "remaining": 10.0}, {"principal": 10.0, "remaining": 10.0}]
	for i in 30:
		var t := pm._next_interval()
		check(t >= Economy.PENALTY_INTERVAL_MIN_BY_LOANS[1] and t <= Economy.PENALTY_INTERVAL_MAX_BY_LOANS[1], "2건: 45~90")
	GameState.debts = [{"principal": 10.0, "remaining": 10.0}, {"principal": 10.0, "remaining": 10.0}, {"principal": 10.0, "remaining": 10.0}]
	for i in 30:
		var t := pm._next_interval()
		check(t >= Economy.PENALTY_INTERVAL_MIN_BY_LOANS[2] and t <= Economy.PENALTY_INTERVAL_MAX_BY_LOANS[2], "3건: 30~60")


func test_interval_respects_penalty_interval_mult_stat() -> void:
	GameState.debts = [{"principal": 10.0, "remaining": 10.0}]
	GameState.modifiers.add_modifier("skill:test", StatModifiers.PENALTY_INTERVAL_MULT, StatModifiers.Op.MULT, 0.5)
	var t := pm._next_interval()
	check(t <= Economy.PENALTY_INTERVAL_MAX_BY_LOANS[0] * 0.5 + 1e-6, "배율 적용")


func test_pick_kind_excludes_last_and_repeats_are_rare() -> void:
	pm.last_kind = PenaltyManager.Kind.WATCHER
	for i in 50:
		check(pm._pick_kind() != PenaltyManager.Kind.WATCHER, "직전과 같은 패널티 금지")


func test_pick_kind_excludes_seize_with_one_marble() -> void:
	check_eq(GameState.marble_slots(), 1, "전제: 구슬 1개")
	pm.last_kind = -1
	for i in 50:
		check(pm._pick_kind() != PenaltyManager.Kind.SEIZE, "구슬 1개면 압류 제외")


func test_watcher_slows_spin_and_clears_on_expiry() -> void:
	var base := GameState.spin_duration()
	pm._apply(PenaltyManager.Kind.WATCHER, 10.0)
	check_near(GameState.spin_duration(), base / Economy.PENALTY_WATCHER_SPEED, 1e-9, "휠 속도 -15%")
	var ended := watch(EventBus.buff_ended)
	GameState.modifiers.tick(10.5)
	check_eq(ended.size(), 1, "만료 알림")
	check_eq(ended[0][0], "watcher", "id")
	check_near(GameState.spin_duration(), base, 1e-9, "해제")


func test_blur_reduces_marble_mult() -> void:
	var base := GameState.marble_mult()
	pm._apply(PenaltyManager.Kind.BLUR, 10.0)
	check_near(GameState.marble_mult(), base * Economy.PENALTY_BLUR_MARBLE_MULT, 1e-9, "구슬 배율 -10%")


func test_smoke_has_no_stat_effect_but_still_signals() -> void:
	var triggered := watch(EventBus.penalty_triggered)
	var before := GameState.get_stat(StatModifiers.PAYOUT_MULT_ALL, 1.0)
	pm._apply(PenaltyManager.Kind.SMOKE, 10.0)
	check_eq(GameState.get_stat(StatModifiers.PAYOUT_MULT_ALL, 1.0), before, "수치 효과 없음(연출만)")
	check_eq(triggered.size(), 1, "penalty_triggered 발행")
	check_eq(triggered[0][0], "smoke", "id")
	check_eq(triggered[0][1], 10.0, "표시 시간")


func test_seize_locks_one_marble_until_consumed() -> void:
	GameState.set_upgrade_level("marble_count", 2)  # 구슬 3개
	pm._apply(PenaltyManager.Kind.SEIZE, 0.0)
	check_eq(GameState.marble_slots(), 2, "1개 사용 불가")
	check(GameState.consume_penalty_charge(GameState.PENALTY_ID_SEIZE_MARBLE), "소모 성공")
	check_eq(GameState.marble_slots(), 3, "다음 스핀부터 정상")


func test_clover_fee_halves_next_gain_then_clears() -> void:
	pm._apply(PenaltyManager.Kind.CLOVER_FEE, 0.0)
	var ended := watch(EventBus.buff_ended)
	check_eq(GameState.add_clovers(10), 5, "절반")
	check_eq(GameState.add_clovers(10), 10, "1회만 적용되고 해제됨")
	check_eq(ended.size(), 1, "소모 시 buff_ended")
	check_eq(ended[0][0], "clover_fee", "id")


func test_pickpocket_never_crosses_bankruptcy_floor() -> void:
	GameState.chips = GameState.min_bet() * Economy.PENALTY_PICKPOCKET_FLOOR_MIN_BETS
	var before := GameState.chips
	pm._apply(PenaltyManager.Kind.PICKPOCKET, 0.0)
	check_eq(GameState.chips, before, "바닥 이하로는 뺏지 않음")
	check(not GameState.is_bankrupt(), "패널티로 파산하지 않음")


func test_pickpocket_steals_one_percent_above_floor() -> void:
	GameState.add_chips(100000.0)
	var before := GameState.chips
	pm._apply(PenaltyManager.Kind.PICKPOCKET, 0.0)
	check_near(GameState.chips, before * (1.0 - Economy.PENALTY_PICKPOCKET_RATE), 1e-6, "1% 차감")


func test_full_cycle_triggers_and_never_causes_bankruptcy() -> void:
	GameState.chips = GameState.min_bet() * 3.0
	GameState.debts = [{"principal": 10.0, "remaining": 10.0}]
	pm.process(0.0)
	check(pm.time_left >= 0.0, "첫 간격 설정")
	pm.process(Economy.PENALTY_INTERVAL_MAX_BY_LOANS[0] + 1.0)
	check(not GameState.is_bankrupt(), "패널티 발동으로도 파산하지 않음")


func test_suppressed_pauses_timer() -> void:
	GameState.debts = [{"principal": 10.0, "remaining": 10.0}]
	pm.process(0.0)
	var left := pm.time_left
	pm.suppressed = true
	pm.process(5.0)
	check_eq(pm.time_left, left, "억제 중에는 줄지 않음")
