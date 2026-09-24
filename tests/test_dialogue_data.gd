extends "res://tests/lib/test_case.gd"


func before_each() -> void:
	super.before_each()
	DialogueData.reload()


func test_loan_intro_has_at_least_five_variants() -> void:
	check(DialogueData.variant_count("loan_intro") >= 5, "요청 명세: 변형 5개 이상")


func test_repeat_and_overflow_keys_exist() -> void:
	for key in ["loan_repeat_2nd", "loan_repeat_3rd", "loan_overflow", "debt_paid"]:
		check(DialogueData.has(key), "키 존재: %s" % key)


func test_pick_returns_valid_structure() -> void:
	var line := DialogueData.pick("loan_intro")
	check(line.has("speaker"), "화자 필드")
	check(line.has("portrait"), "표정 필드")
	check((line.get("lines", []) as Array).size() > 0, "본문 최소 1줄")


func test_pick_is_randomized_across_variants() -> void:
	var seen: Dictionary = {}
	for i in 60:
		var line := DialogueData.pick("loan_intro")
		seen[(line["lines"] as Array)[0]] = true
	check(seen.size() > 1, "60회 뽑으면 최소 2가지 변형은 나옴")


func test_unknown_key_errors_and_returns_empty() -> void:
	print("    (다음 에러 로그 1줄은 없는 키 방어 테스트의 정상 출력)")
	check_eq(DialogueData.pick("no_such_key"), {}, "빈 Dictionary")


func test_all_referenced_translation_keys_exist() -> void:
	DialogueData.ensure_loaded()
	var csv := FileAccess.open("res://translations/strings.csv", FileAccess.READ)
	var known: Dictionary = {}
	csv.get_line()  # 헤더
	while not csv.eof_reached():
		var line := csv.get_line()
		if line == "":
			continue
		known[line.split(",")[0]] = true
	csv.close()
	for key in ["loan_intro", "loan_repeat_2nd", "loan_repeat_3rd", "loan_overflow", "debt_paid", "skilltree_unlock", "elevator_ready"]:
		for variant: Dictionary in (DialogueData._sets[key] as Array):
			check(known.has(String(variant.get("speaker", ""))), "화자 키 등록됨: %s" % variant.get("speaker"))
			for line_key in variant.get("lines", []):
				check(known.has(String(line_key)), "본문 키 등록됨: %s" % line_key)
