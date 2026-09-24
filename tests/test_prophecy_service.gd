extends "res://tests/lib/test_case.gd"
## 예지(6단계, Y2/Y9) 통계 테스트: color_hint() 가 레벨별 정확도(60/67/75%)에 실제로 수렴하는지
## 10,000회 표본으로 확인한다. misc 스트림만 쓰므로 스핀 결과 스트림과는 독립이다.

const TRIALS := 10000
const TOLERANCE := 0.02


func test_color_hint_accuracy_matches_level_over_many_runs() -> void:
	for level in [1, 2, 3]:
		var accuracy := ProphecyService.accuracy_for_level(level)
		var hits := 0
		for i in TRIALS:
			var true_result := i % RouletteRules.POCKET_COUNT
			var hinted := ProphecyService.color_hint(true_result, accuracy)
			if hinted == RouletteRules.color_of(true_result):
				hits += 1
		var observed := float(hits) / TRIALS
		check_near(observed, accuracy, TOLERANCE, "레벨 %d: 기대 정확도 %.2f, 관측 %.3f" % [level, accuracy, observed])


func test_accuracy_for_level_zero_or_negative_is_zero() -> void:
	check_eq(ProphecyService.accuracy_for_level(0), 0.0, "레벨 0은 정확도 0")
	check_eq(ProphecyService.accuracy_for_level(-1), 0.0, "음수 레벨도 0")


func test_accuracy_for_level_clamps_above_max() -> void:
	check_eq(ProphecyService.accuracy_for_level(99), ProphecyService.ACCURACY_BY_LEVEL[-1], "최대 레벨 정확도로 고정")


func test_color_hint_never_returns_invalid_color() -> void:
	for i in 200:
		var hinted := ProphecyService.color_hint(i % RouletteRules.POCKET_COUNT, 0.5)
		check(hinted == RouletteRules.PocketColor.RED or hinted == RouletteRules.PocketColor.BLACK or hinted == RouletteRules.PocketColor.GREEN, "유효한 색만 반환")


func test_straight_candidates_include_true_result_roughly_half_the_time() -> void:
	var include_count := 0
	var trials := 2000
	for i in trials:
		var true_result := i % RouletteRules.POCKET_COUNT
		var candidates := ProphecyService.straight_candidates(true_result)
		check_eq(candidates.size(), ProphecyService.CLAIRVOYANCE_COUNT, "후보 개수 고정")
		if candidates.has(true_result):
			include_count += 1
	var ratio := float(include_count) / trials
	check_near(ratio, ProphecyService.CLAIRVOYANCE_INCLUDE_CHANCE, 0.05, "정답 포함 확률 50%% 근접(관측 %.3f)" % ratio)


func test_straight_candidates_has_no_duplicates() -> void:
	for i in 100:
		var candidates := ProphecyService.straight_candidates(i % RouletteRules.POCKET_COUNT)
		var seen: Dictionary = {}
		for n in candidates:
			check(not seen.has(n), "후보 중복 없음")
			seen[n] = true
