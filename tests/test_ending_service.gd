extends "res://tests/lib/test_case.gd"
## EndingService: 엔딩 트리거 조건·전이, 무한 모드(오너 모드) 배율.


func test_can_trigger_requires_max_floor_and_cost() -> void:
	check(not EndingService.can_trigger(), "B1 에서는 칩이 있어도 불가")
	GameState.add_chips(Economy.ENDING_COST)
	check(not EndingService.can_trigger(), "칩은 충분해도 PH 가 아니면 불가")
	GameState.floor_index = 4
	GameState.spend_chips(GameState.chips)
	check(not EndingService.can_trigger(), "PH 여도 칩 부족이면 불가")
	GameState.add_chips(Economy.ENDING_COST)
	check(EndingService.can_trigger(), "PH + 1Dc 면 가능")


func test_trigger_spends_chips_and_marks_ending() -> void:
	GameState.floor_index = 4
	GameState.add_chips(Economy.ENDING_COST)
	var triggered := watch(EventBus.ending_triggered)
	check(EndingService.trigger(), "성공")
	check(GameState.ending_reached, "ending_reached = true")
	# 1e33 규모에서는 시작 칩 100 이 부동소수 정밀도 밖이라 반올림으로 사라진다(정상).
	check(GameState.chips < 1.0, "1Dc 차감")
	check_eq(triggered.size(), 1, "ending_triggered 1회 발행")
	check(not EndingService.can_trigger(), "다시 트리거 불가(이미 봄)")


func test_trigger_forgives_remaining_debt() -> void:
	GameState.floor_index = 4
	GameState.add_chips(Economy.ENDING_COST)
	GameState.debts = [{"principal": 100.0, "remaining": 250.0}] as Array[Dictionary]
	check(EndingService.trigger(), "성공")
	check(GameState.debts.is_empty(), "새 주인이 되며 남은 빚이 전부 탕감된다")


func test_trigger_fails_when_not_eligible() -> void:
	check(not EndingService.trigger(), "조건 미달 시 실패")
	check(not GameState.ending_reached, "상태 그대로")


func test_infinite_mode_doubles_payout() -> void:
	var base := GameState.get_stat(StatModifiers.PAYOUT_MULT_ALL, StatModifiers.IDENTITY_MULT)
	var started := watch(EventBus.infinite_mode_started)
	EndingService.enter_infinite_mode()
	check(GameState.infinite_mode, "infinite_mode = true")
	check_near(GameState.get_stat(StatModifiers.PAYOUT_MULT_ALL, StatModifiers.IDENTITY_MULT), base * Economy.OWNER_MODE_PAYOUT_MULT, 1e-9, "수익 ×2")
	check_eq(started.size(), 1, "infinite_mode_started 1회 발행")
	EndingService.enter_infinite_mode()
	check_eq(started.size(), 1, "두 번째 호출은 아무 일도 안 함(중복 발행 없음)")


func test_rebuild_ending_modifiers_after_load() -> void:
	GameState.infinite_mode = true
	var base := StatModifiers.IDENTITY_MULT
	GameState.rebuild_ending_modifiers()
	check_near(GameState.get_stat(StatModifiers.PAYOUT_MULT_ALL, base), base * Economy.OWNER_MODE_PAYOUT_MULT, 1e-9, "불러오기 후에도 오너 모드 배율 재적용")
	GameState.infinite_mode = false
	GameState.rebuild_ending_modifiers()
	check_near(GameState.get_stat(StatModifiers.PAYOUT_MULT_ALL, base), base, 1e-9, "꺼지면 배율도 제거")
