extends "res://tests/lib/test_case.gd"
## AchievementData(데이터 무결성) + AchievementManager(조건 판정 30종).


func _load_csv_keys() -> Dictionary:
	var keys := {}
	var file := FileAccess.open("res://translations/strings.csv", FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			keys[row[0]] = true
	return keys


func test_achievement_data_structure() -> void:
	var all := AchievementData.all()
	check_eq(all.size(), 30, "업적 30개")
	var valid_categories := {"basic": true, "debt": true, "progress": true, "collection": true, "feature": true, "cumulative": true, "hidden": true}
	var csv_keys := _load_csv_keys()
	var ids := {}
	var hidden_count := 0
	for entry in all:
		var id := String(entry.get("id", ""))
		check(id != "" and not ids.has(id), "id 고유: %s" % id)
		ids[id] = true
		check(valid_categories.has(String(entry.get("category", ""))), "%s 카테고리 유효" % id)
		check(String(entry.get("icon", "")) != "", "%s 아이콘 id 존재" % id)
		var name_key := String(entry.get("name_key", ""))
		var desc_key := String(entry.get("desc_key", ""))
		check(csv_keys.has(name_key), "번역 존재: %s" % name_key)
		check(csv_keys.has(desc_key), "번역 존재: %s" % desc_key)
		if bool(entry.get("hidden", false)):
			hidden_count += 1
	check_eq(hidden_count, 2, "숨김 업적 2개(벨벳 대사·같은 숫자 3연속)")


func test_get_def_and_has() -> void:
	check(AchievementData.has("first_spin"), "존재하는 id")
	check(not AchievementData.has("no_such_id"), "없는 id")
	check_eq(AchievementData.category_of("velvet_all_lines"), "hidden", "카테고리 조회")
	check(AchievementData.is_hidden("same_number_3"), "숨김 여부 조회")
	check(not AchievementData.is_hidden("first_spin"), "일반 업적은 숨김 아님")


func _outcome(results: Array[int] = []) -> SpinOutcome:
	var outcome := SpinOutcome.new()
	outcome.results = results
	return outcome


func _unlocked(id: String) -> bool:
	return GameState.unlocked_achievements.has(id)


func test_basic_achievements() -> void:
	EventBus.spin_resolved.emit(_outcome([1]))
	check(_unlocked("first_spin"), "첫 스핀")
	var straight := _outcome([3])
	straight.hit_straights = [3]
	EventBus.spin_resolved.emit(straight)
	check(_unlocked("first_straight"), "첫 개별숫자")
	EventBus.spin_resolved.emit(_outcome([RouletteRules.ZERO]))
	check(_unlocked("zero_hit"), "0 적중")
	GameState.win_streak = 10
	EventBus.spin_resolved.emit(_outcome([1]))
	check(_unlocked("win_streak_10"), "10연승")


func test_feature_achievements() -> void:
	var jackpot := _outcome([1])
	jackpot.tier = SpinOutcome.Tier.JACKPOT
	EventBus.spin_resolved.emit(jackpot)
	check(_unlocked("jackpot_shown"), "잭팟 연출")

	var flip := _outcome([2])
	flip.destiny_flip_from = 5
	EventBus.spin_resolved.emit(flip)
	check(_unlocked("destiny_flip_hit"), "운명 역전")

	var golden := _outcome([1])
	golden.golden_hit = true
	EventBus.spin_resolved.emit(golden)
	check(_unlocked("golden_pocket_hit"), "황금 포켓 적중")

	var lucky := _outcome([7])
	lucky.hit_straights = [7]
	EventBus.spin_resolved.emit(lucky)
	check(_unlocked("lucky_seven"), "럭키 세븐")

	EventBus.buff_started.emit("fever", 10.0)
	check(_unlocked("first_fever"), "첫 피버")


func test_double_ball_both_hit_requires_each_ball_to_win() -> void:
	var both := _outcome([1, 2])
	var r1 := SpinOutcome.BetResult.new()
	r1.bet = Bet.straight(1)
	var r2 := SpinOutcome.BetResult.new()
	r2.bet = Bet.straight(2)
	both.bet_results = [r1, r2]
	EventBus.spin_resolved.emit(both)
	check(_unlocked("double_ball_both_hit"), "두 공 모두 적중")

	GameState.reset()
	var only_one := _outcome([1, 2])
	var r3 := SpinOutcome.BetResult.new()
	r3.bet = Bet.straight(1)
	only_one.bet_results = [r3]
	EventBus.spin_resolved.emit(only_one)
	check(not _unlocked("double_ball_both_hit"), "한 공만 적중이면 해금 안 됨")


func test_same_number_3_hidden() -> void:
	GameState.push_results([5])
	GameState.push_results([5])
	GameState.push_results([5])
	EventBus.spin_resolved.emit(_outcome([5]))
	check(_unlocked("same_number_3"), "같은 숫자 3연속(숨김)")


func test_cumulative_spin_and_chip_totals() -> void:
	GameState.stats[GameState.STAT_TOTAL_SPINS] = Economy.ACHIEVEMENT_TOTAL_SPINS_LOW
	EventBus.spin_resolved.emit(_outcome([1]))
	check(_unlocked("total_spins_1000"), "누적 스핀 1000")
	check(not _unlocked("total_spins_10000"), "아직 10000 은 아님")
	GameState.stats[GameState.STAT_TOTAL_SPINS] = Economy.ACHIEVEMENT_TOTAL_SPINS_HIGH
	EventBus.spin_resolved.emit(_outcome([1]))
	check(_unlocked("total_spins_10000"), "누적 스핀 10000")

	GameState.stats[GameState.STAT_TOTAL_EARNED] = Economy.ACHIEVEMENT_TOTAL_CHIPS
	EventBus.chips_changed.emit(GameState.chips, 0.0)
	check(_unlocked("total_chips_1qa"), "누적 칩 1Qa")


func test_offline_8h() -> void:
	GameState.achievement_manager.check_offline_hours(Economy.ACHIEVEMENT_OFFLINE_HOURS * 3600.0 - 1.0)
	check(not _unlocked("offline_8h"), "8시간 미만은 아직")
	GameState.achievement_manager.check_offline_hours(Economy.ACHIEVEMENT_OFFLINE_HOURS * 3600.0)
	check(_unlocked("offline_8h"), "8시간 이상 오프라인")


func test_no_bankrupt_1h_resets_on_bankrupt() -> void:
	GameState.achievement_manager.process(1800.0)
	EventBus.bankrupt.emit()
	check_eq(GameState.achievement_manager.no_bankrupt_timer, 0.0, "파산 시 타이머 리셋")
	GameState.achievement_manager.process(Economy.ACHIEVEMENT_NO_BANKRUPT_SECONDS)
	check(_unlocked("no_bankrupt_1h"), "1시간 무파산")


func test_debt_achievements() -> void:
	GameState.increment_stat(GameState.STAT_LOANS_TAKEN)
	EventBus.debt_changed.emit()
	check(_unlocked("first_loan"), "첫 대출")

	GameState.debts = [{"remaining": 1.0}, {"remaining": 1.0}, {"remaining": 1.0}]
	EventBus.debt_changed.emit()
	check(_unlocked("triple_loans"), "대출 3건 동시")

	GameState.pending_baron_event = {"type": "debt_paid"}
	EventBus.debt_changed.emit()
	check(_unlocked("debt_paid_first"), "첫 완납")


func test_floor_achievements() -> void:
	EventBus.floor_changed.emit(2)
	check(_unlocked("floor_reached_2f"), "2F 도달")
	check(not _unlocked("floor_reached_3f"), "3F 는 아직")
	EventBus.floor_changed.emit(3)
	check(_unlocked("floor_reached_3f"), "3F 도달")
	EventBus.floor_changed.emit(4)
	check(_unlocked("floor_reached_ph"), "PH 도달(층 도달 4개)")


func test_ending_achievement() -> void:
	EventBus.ending_triggered.emit()
	check(_unlocked("ending_reached"), "엔딩")


func test_marble_tier_achievements() -> void:
	EventBus.upgrade_purchased.emit(GameState.UPGRADE_MARBLE_TIER, 5)
	check(_unlocked("marble_gold"), "금 구슬")
	check(not _unlocked("marble_diamond"), "다이아는 아직")
	EventBus.upgrade_purchased.emit(GameState.UPGRADE_MARBLE_TIER, 10)
	check(_unlocked("marble_diamond"), "다이아 구슬")
	EventBus.upgrade_purchased.emit(GameState.UPGRADE_MARBLE_TIER, 14)
	check(_unlocked("marble_cosmic"), "코스믹 구슬")


func test_marbles_12_from_upgrade_or_skill() -> void:
	GameState.modifiers.add_modifier("test", StatModifiers.MARBLE_SLOTS_BONUS, StatModifiers.Op.ADD, 11.0)
	EventBus.upgrade_purchased.emit(GameState.UPGRADE_MARBLE_TIER, 1)
	check(_unlocked("marbles_12"), "구슬 12개")


## 데이터 값에 의존하지 않도록, 스킬 전부를 하나씩 최대로 올리며 50%/100% 문턱을 직접 넘겨 본다.
func test_skill_half_and_full_progress() -> void:
	var non_heart: Array[SkillNodeDef] = []
	for def: SkillNodeDef in GameData.skills():
		if not def.is_heart():
			non_heart.append(def)
	var total := SkillService.grand_total()
	var invested := 0
	var saw_half := false
	for def in non_heart:
		GameState.set_skill_level(def.id, def.max_level())
		invested += def.total_cost()
		EventBus.skill_purchased.emit(def.id, def.max_level())
		if invested * 2 >= total:
			saw_half = true
	check(saw_half, "테스트가 실제로 50% 문턱을 넘었다")
	check(_unlocked("skill_half"), "스킬 50%")
	check(_unlocked("skill_full"), "스킬 100%(전부 최대)")


func test_mark_dialogue_seen_unlocks_hidden_achievement() -> void:
	var key := "debt_paid"
	var total := DialogueData.variant_count(key)
	check(total > 1, "테스트용 대사 키에 변형이 여럿 있어야 함")
	for i in total - 1:
		GameState.achievement_manager.mark_dialogue_seen(key, i)
	check(not _unlocked("velvet_all_lines"), "아직 다 안 봄")
	GameState.achievement_manager.mark_dialogue_seen(key, total - 1)
	check(_unlocked("velvet_all_lines"), "전부 보면 해금(숨김)")


func test_unlock_is_idempotent() -> void:
	EventBus.spin_resolved.emit(_outcome([1]))
	var count_after_first := GameState.unlocked_achievements.size()
	var emitted := watch(EventBus.achievement_unlocked)
	EventBus.spin_resolved.emit(_outcome([1]))
	check_eq(GameState.unlocked_achievements.size(), count_after_first, "중복 해금 없음")
	check_eq(emitted.size(), 0, "이미 해금된 건 다시 발행 안 함")


func test_save_load_roundtrip_persists_achievements() -> void:
	EventBus.spin_resolved.emit(_outcome([1]))
	GameState.achievement_manager.mark_dialogue_seen("debt_paid", 0)
	EndingService.can_trigger()
	GameState.ending_reached = false
	GameState.infinite_mode = true
	var data := GameState.to_dict()
	GameState.reset()
	GameState.from_dict(data)
	check(_unlocked("first_spin"), "해금 목록 저장/복원")
	check_eq((GameState.achievement_dialogue_seen.get("debt_paid", {}) as Dictionary).size(), 1, "대사 시청 기록 저장/복원")
	check(GameState.infinite_mode, "무한 모드 저장/복원")
