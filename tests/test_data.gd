extends "res://tests/lib/test_case.gd"

const CSV_PATH := "res://translations/strings.csv"


func test_marbles() -> void:
	var marbles := GameData.marbles()
	check_eq(marbles.size(), 15, "구슬 15종")
	var expected_mults: Array[float] = [1.0, 1.5, 12.0, 100.0, 900.0, 8e3, 7e4, 8e5, 1.2e9, 1.5e10, 2e11, 3e12, 5e13, 8e14, 1.5e16]
	for tier in marbles.size():
		var marble := marbles[tier]
		check_eq(marble.tier, tier, "tier 순서")
		check_eq(marble.mult, expected_mults[tier], "%s 배율" % marble.id)
		for color in marble.palette_colors():
			check(Palette.is_palette_color(color), "%s 색 %s 은 팔레트 색" % [marble.id, color.to_html(false)])
		if tier > 0:
			check(marble.cost > marbles[tier - 1].cost, "%s 비용 증가" % marble.id)
	check_eq(marbles[0].cost, 0.0, "나무는 무료")
	check_eq(marbles[1].cost, 50.0, "돌 50")


func test_floors() -> void:
	var floors := GameData.floors()
	check_eq(floors.size(), 5, "층 5개")
	var costs: Array[float] = [0.0, 1e6, 1e12, 1e21, 1e30]
	for i in floors.size():
		check_eq(floors[i].index, i, "index")
		check_eq(floors[i].cost, costs[i], "%s 비용" % floors[i].id)
		if i > 0:
			check(floors[i].payout_mult > floors[i - 1].payout_mult, "배율 상승")
			check_eq(floors[i].clover_reward, Economy.CLOVER_PER_FLOOR, "층 이동 클로버 +10")
	check_eq(floors[-1].marble_tier_cap, GameData.marbles().size() - 1, "PH 에서 모든 구슬")


func test_upgrades() -> void:
	for id: String in ["bet_limit", "marble_count", "wheel_speed", "golden_pocket"]:
		var def := GameData.upgrade(id)
		check(def != null, "%s 존재" % id)
		if def != null:
			check(StatModifiers.ALL_STATS.has(def.effect_stat), "%s 스탯 키 유효" % id)
	check_eq(1 + GameData.upgrade("marble_count").max_level, Economy.MAX_MARBLES_FROM_UPGRADES, "구슬 업그레이드 상한 = 8개")
	check_eq(GameData.upgrade("golden_pocket").max_level, Economy.GOLDEN_POCKET_MAX, "황금 포켓 5개")


func test_translation_keys() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	check(file != null, "CSV 열기")
	if file == null:
		return
	var header := file.get_csv_line()
	check_eq(Array(header), ["keys", "ko", "en"], "헤더")
	var keys := {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		check_eq(row.size(), 3, "열 3개: %s" % row[0])
		if row.size() >= 3:
			check(not keys.has(row[0]), "키 중복 없음: %s" % row[0])
			check(row[1] != "" and row[2] != "", "ko/en 모두 있음: %s" % row[0])
			keys[row[0]] = true
	var used: Array[String] = []
	for marble in GameData.marbles():
		used.append(marble.name_key)
	for floor_def in GameData.floors():
		used.append_array([floor_def.name_key, floor_def.desc_key])
	for upgrade in GameData.upgrades():
		used.append_array([upgrade.name_key, upgrade.desc_key])
	for bet: Bet in [Bet.red(), Bet.black(), Bet.odd(), Bet.even(), Bet.straight(1)]:
		used.append(bet.label_key())
	for key in used:
		check(keys.has(key), "데이터가 쓰는 번역 키 존재: %s" % key)


func test_translation_loaded() -> void:
	TranslationServer.set_locale("ko")
	check_eq(String(TranslationServer.translate("MARBLE_WOOD")), "나무 구슬", "ko")
	TranslationServer.set_locale("en")
	check_eq(String(TranslationServer.translate("MARBLE_WOOD")), "Wood Marble", "en")


func test_palette_has_36_colors() -> void:
	check_eq(Palette.ALL.size(), 36, "36색")
	var unique := {}
	for color: Color in Palette.ALL.values():
		unique[color.to_html(false)] = true
	check_eq(unique.size(), 36, "중복 없음")
