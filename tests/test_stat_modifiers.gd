extends "res://tests/lib/test_case.gd"

var mods: StatModifiers


func before_each() -> void:
	super.before_each()
	mods = StatModifiers.new()


func test_base_without_modifiers() -> void:
	check_eq(mods.get_stat(StatModifiers.PAYOUT_MULT_ALL, 1.0), 1.0, "수정자 없음")
	check_eq(mods.get_stat(StatModifiers.MARBLE_MULT, 1.5), 1.5, "base 그대로")


func test_add_then_mult() -> void:
	mods.add_modifier("a", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.ADD, 0.5)
	mods.add_modifier("b", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.ADD, 0.25)
	mods.add_modifier("c", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT, 2.0)
	mods.add_modifier("d", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT, 3.0)
	check_eq(mods.get_stat(StatModifiers.PAYOUT_MULT_ALL, 1.0), (1.0 + 0.5 + 0.25) * 2.0 * 3.0, "(base + ADD 합) × MULT 곱")
	check_eq(mods.get_stat(StatModifiers.FLOOR_MULT, 4.0), 4.0, "다른 스탯에는 영향 없음")


func test_same_source_and_stat_replaces() -> void:
	mods.add_modifier("upgrade:x", StatModifiers.MAX_BET_MULT, StatModifiers.Op.MULT, 1.35)
	mods.add_modifier("upgrade:x", StatModifiers.MAX_BET_MULT, StatModifiers.Op.MULT, 1.35 * 1.35)
	check_eq(mods.count(), 1, "교체")
	check_near(mods.get_stat(StatModifiers.MAX_BET_MULT, 1.0), 1.35 * 1.35, 1e-12, "새 값")


func test_cache_invalidation() -> void:
	mods.add_modifier("a", StatModifiers.MARBLE_MULT, StatModifiers.Op.MULT, 2.0)
	check_eq(mods.get_stat(StatModifiers.MARBLE_MULT, 1.0), 2.0, "첫 계산")
	mods.add_modifier("b", StatModifiers.MARBLE_MULT, StatModifiers.Op.MULT, 0.9)
	check_near(mods.get_stat(StatModifiers.MARBLE_MULT, 1.0), 1.8, 1e-12, "추가 후 갱신")
	mods.remove_source("a")
	check_near(mods.get_stat(StatModifiers.MARBLE_MULT, 1.0), 0.9, 1e-12, "제거 후 갱신")


func test_remove_by_source() -> void:
	mods.add_modifier("skill:lucky", StatModifiers.PAYOUT_MULT_COLOR, StatModifiers.Op.MULT, 2.0)
	mods.add_modifier("skill:lucky", StatModifiers.PAYOUT_MULT_PARITY, StatModifiers.Op.MULT, 2.0)
	mods.add_modifier("skill:other", StatModifiers.PAYOUT_MULT_COLOR, StatModifiers.Op.MULT, 1.5)
	check_eq(mods.remove_source("skill:lucky"), 2, "2개 제거")
	check(not mods.has_source("skill:lucky"), "없음")
	check_eq(mods.get_stat(StatModifiers.PAYOUT_MULT_COLOR, 1.0), 1.5, "남은 수정자")
	check_eq(mods.get_stat(StatModifiers.PAYOUT_MULT_PARITY, 1.0), 1.0, "홀짝 원래대로")


func test_timed_modifiers_expire() -> void:
	var expired := watch(mods.source_expired)
	mods.add_modifier("buff:hot", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT, 2.0, 10.0)
	mods.add_modifier("buff:hot", StatModifiers.SPIN_DURATION_MULT, StatModifiers.Op.MULT, 0.5, 5.0)
	mods.add_modifier("perm", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT, 1.5)
	mods.tick(4.0)
	check_eq(mods.get_stat(StatModifiers.PAYOUT_MULT_ALL, 1.0), 3.0, "4초 후 유지")
	check_near(mods.remaining_time("buff:hot"), 6.0, 1e-9, "남은 시간")
	mods.tick(1.5)
	check_eq(mods.get_stat(StatModifiers.SPIN_DURATION_MULT, 1.0), 1.0, "5초짜리 만료")
	check_eq(expired.size(), 0, "source 에 수정자가 남아 있으면 만료 알림 없음")
	var ended := mods.tick(5.0)
	check_eq(mods.get_stat(StatModifiers.PAYOUT_MULT_ALL, 1.0), 1.5, "10초짜리 만료, 영구는 유지")
	check_eq(ended, ["buff:hot"] as Array[String], "만료 목록")
	check_eq(expired.size(), 1, "만료 알림 1회")
	mods.tick(1000.0)
	check_eq(mods.count(), 1, "영구 수정자는 남음")


func test_game_state_buff_emits_events() -> void:
	var started := watch(EventBus.buff_started)
	var ended := watch(EventBus.buff_ended)
	GameState.add_buff("lucky_hour", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT, 2.0, 3.0)
	check_eq(started.size(), 1, "buff_started")
	check_eq(started[0][0], "lucky_hour", "id")
	check_eq(GameState.get_stat(StatModifiers.PAYOUT_MULT_ALL, 1.0), 2.0, "적용")
	GameState.modifiers.tick(3.5)
	check_eq(ended.size(), 1, "만료 시 buff_ended")
	check_eq(ended[0][0], "lucky_hour", "id")
	check_eq(GameState.get_stat(StatModifiers.PAYOUT_MULT_ALL, 1.0), 1.0, "해제")


func test_rejects_invalid_values() -> void:
	print("    (다음 에러 로그 1줄은 NaN 방어 테스트의 정상 출력)")
	check(mods.add_modifier("bad", StatModifiers.MARBLE_MULT, StatModifiers.Op.MULT, NAN) == null, "NaN 거부")
	check_eq(mods.count(), 0, "추가 안 됨")


func test_upgrade_effect_values() -> void:
	var bet_limit := GameData.upgrade("bet_limit")
	check_near(bet_limit.effect_value(3), pow(Economy.BET_LIMIT_GROWTH, 3), 1e-12, "bet_limit 데이터 = Economy.BET_LIMIT_GROWTH")
	var wheel := GameData.upgrade("spin_speed")
	check_near(wheel.effect_value(2), pow(Economy.SPIN_SPEED_FACTOR, 2), 1e-12, "spin_speed 데이터 = Economy.SPIN_SPEED_FACTOR")
	check_eq(GameData.upgrade("marble_count").effect_value(3), 3.0, "ADD")
