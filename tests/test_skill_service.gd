extends "res://tests/lib/test_case.gd"
## SkillService: 데이터 무결성(57개·총비용 269)·선행조건(ALL/ANY)·구매·효과 적용·feature_id 조회.


func _give_clovers(amount: int) -> void:
	GameState.clovers += amount


func test_57_nodes_and_total_cost_269() -> void:
	var skills := GameData.skills()
	check_eq(skills.size(), 57, "노드 57개")
	var total := 0
	var branch_counts: Dictionary = {}
	for def: SkillNodeDef in skills:
		total += def.total_cost()
		branch_counts[def.branch] = int(branch_counts.get(def.branch, 0)) + 1
	check_eq(total, 269, "총비용 269")
	check_eq(int(branch_counts.get(SkillNodeDef.Branch.CORE, 0)), 1, "HEART 1개")
	for branch in [SkillNodeDef.Branch.FORTUNE, SkillNodeDef.Branch.MACHINE, SkillNodeDef.Branch.ECONOMY, SkillNodeDef.Branch.MYSTIC]:
		check_eq(int(branch_counts.get(branch, 0)), 14, "갈래당 14개(궁극기 포함)")


func test_heart_always_owned_and_free() -> void:
	var heart := GameData.skill(GameState.SKILL_HEART_ID)
	check(heart != null, "heart 존재")
	check(heart.is_heart(), "costs 비어있음")
	check_eq(SkillService.level(GameState.SKILL_HEART_ID), 1, "항상 레벨 1")
	check_eq(SkillService.lock_status(heart), SkillService.Status.IS_HEART, "HEART 상태")
	check_eq(SkillService.purchase(GameState.SKILL_HEART_ID), -1, "HEART 는 구매 불가")


func test_ring_distribution_per_branch() -> void:
	for branch in [SkillNodeDef.Branch.FORTUNE, SkillNodeDef.Branch.MACHINE, SkillNodeDef.Branch.ECONOMY, SkillNodeDef.Branch.MYSTIC]:
		var by_ring: Dictionary = {}
		for def: SkillNodeDef in GameData.skills():
			if def.branch == branch:
				by_ring[def.ring] = int(by_ring.get(def.ring, 0)) + 1
		check_eq([by_ring.get(1, 0), by_ring.get(2, 0), by_ring.get(3, 0), by_ring.get(4, 0)], [4, 5, 4, 1],
			"갈래 %d 고리 분포 4/5/4/1" % branch)


func test_all_prerequisites_reference_existing_ids() -> void:
	var ids: Dictionary = {}
	for def: SkillNodeDef in GameData.skills():
		ids[def.id] = true
	for def: SkillNodeDef in GameData.skills():
		for prereq in def.prerequisites:
			check(ids.has(prereq), "%s 의 선행조건 %s 존재" % [def.id, prereq])
		if not def.is_heart() and def.branch != SkillNodeDef.Branch.CORE:
			check(not def.prerequisites.is_empty(), "%s 는 선행조건이 있어야 함" % def.id)


func test_prerequisite_any_mode() -> void:
	var f5 := GameData.skill("f5")
	check_eq(f5.prerequisite_mode, SkillNodeDef.PrereqMode.ANY, "F5 는 ANY(F1|F2)")
	check(not SkillService.prerequisites_met(f5), "아직 F1·F2 없음")
	_give_clovers(10)
	check_eq(SkillService.purchase("f1"), 1, "F1 구매")
	check(SkillService.prerequisites_met(f5), "F1 만 있어도 충족(ANY)")


func test_prerequisite_all_mode() -> void:
	var f14 := GameData.skill("f14")
	check_eq(f14.prerequisite_mode, SkillNodeDef.PrereqMode.ALL, "F14 는 ALL(F10&F12)")
	_give_clovers(300)
	for id in ["f1", "f2", "f3", "f4"]:
		SkillService.purchase(id)
	SkillService.purchase("f6")
	SkillService.purchase("f7")
	check_eq(SkillService.purchase("f10"), 1, "F10 구매(F6|F7 중 하나만 있어도 됨)")
	check(not SkillService.prerequisites_met(f14), "F12 없어서 아직 F14 불가(ALL)")
	SkillService.purchase("f8")
	SkillService.purchase("f8")
	check_eq(SkillService.purchase("f12"), 1, "F12 구매(F8 필요)")
	check(SkillService.prerequisites_met(f14), "F10·F12 모두 있어야 F14(ALL) 충족")


func test_purchase_deducts_clovers_and_applies_effect() -> void:
	_give_clovers(5)
	var before := GameState.get_stat(StatModifiers.PAYOUT_MULT_COLOR, StatModifiers.IDENTITY_MULT)
	check_eq(SkillService.purchase("f1"), 1, "F1 Lv1 구매")
	check_eq(GameState.clovers, 4, "클로버 1 차감")
	check_near(GameState.get_stat(StatModifiers.PAYOUT_MULT_COLOR, StatModifiers.IDENTITY_MULT), before * 1.15, 1e-9, "×1.15 적용")
	check_eq(SkillService.purchase("f1"), 2, "F1 Lv2 구매")
	check_near(GameState.get_stat(StatModifiers.PAYOUT_MULT_COLOR, StatModifiers.IDENTITY_MULT), before * 1.15 * 1.15, 1e-9, "Lv2 는 ×1.15^2(복리)")


func test_purchase_fails_without_enough_clovers() -> void:
	GameState.clovers = 0
	check_eq(SkillService.purchase("f1"), -1, "클로버 없음")
	check_eq(SkillService.level("f1"), 0, "레벨 그대로")


func test_purchase_respects_max_level() -> void:
	_give_clovers(100)
	var f9 := GameData.skill("f9")
	_give_clovers(4)
	SkillService.purchase("f4")
	check_eq(SkillService.purchase("f9"), 1, "F9 Lv1(최대)")
	check_eq(SkillService.lock_status(f9), SkillService.Status.MAX_LEVEL, "F9 는 Lv1 이 최대")
	check_eq(SkillService.purchase("f9"), -1, "더 못 삼")


func test_locked_without_prerequisite() -> void:
	var f5 := GameData.skill("f5")
	check(SkillService.is_locked(f5), "F1·F2 없이는 잠김")
	_give_clovers(50)
	check_eq(SkillService.purchase("f5"), -1, "잠긴 상태에서 구매 시도 실패")


func test_feature_level_and_has_feature() -> void:
	check_eq(SkillService.feature_level("auto_spin"), 0, "미보유")
	check(not SkillService.has_feature("auto_spin"), "미보유")
	_give_clovers(1)
	SkillService.purchase("m1")
	check_eq(SkillService.feature_level("auto_spin"), 1, "M1 보유")
	check(SkillService.has_feature("auto_spin"), "보유")
	check(GameState.auto_spin_unlocked(), "GameState 도 연동")


func test_dual_effect_node_applies_both_stats() -> void:
	_give_clovers(3)
	var before_delay := GameState.get_stat(StatModifiers.SPIN_DELAY, Economy.AUTO_SPIN_DELAY)
	var before_dur := GameState.get_stat(StatModifiers.SPIN_DURATION_MULT, StatModifiers.IDENTITY_MULT)
	SkillService.purchase("m2")
	check_near(GameState.get_stat(StatModifiers.SPIN_DELAY, Economy.AUTO_SPIN_DELAY), before_delay - 0.25, 1e-9, "대기시간 -0.25")
	check_near(GameState.get_stat(StatModifiers.SPIN_DURATION_MULT, StatModifiers.IDENTITY_MULT), before_dur * 0.95, 1e-9, "스핀시간 ×0.95")


func test_invested_total_and_grand_total() -> void:
	check_eq(SkillService.grand_total(), 269, "전체 총비용")
	check_eq(SkillService.invested_total(), 0, "아직 투자 없음")
	_give_clovers(3)
	SkillService.purchase("f1")
	SkillService.purchase("f1")
	check_eq(SkillService.invested_total(), 2, "F1 Lv2 = 1+1")


func test_any_affordable() -> void:
	GameState.clovers = 0
	check(not SkillService.any_affordable(), "0 클로버")
	_give_clovers(1)
	check(SkillService.any_affordable(), "1 클로버로 Lv1 스킬 구매 가능")


func test_save_load_roundtrip_rebuilds_skill_modifiers() -> void:
	_give_clovers(10)
	SkillService.purchase("f1")
	SkillService.purchase("f1")
	SkillService.purchase("y10")
	var extra_balls_before := GameState.get_stat(StatModifiers.EXTRA_BALLS, 0.0)
	var data := GameState.to_dict()
	GameState.reset()
	check_eq(GameState.get_stat(StatModifiers.EXTRA_BALLS, 0.0), 0.0, "리셋 후 효과 없음")
	GameState.from_dict(data)
	GameState.rebuild_skill_modifiers()
	check_eq(SkillService.level("f1"), 2, "레벨 복원")
	check_eq(GameState.get_stat(StatModifiers.EXTRA_BALLS, 0.0), extra_balls_before, "효과도 복원")
