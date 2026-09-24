extends "res://tests/lib/test_case.gd"


func test_empty_history() -> void:
	var stats := HistoryStats.from_history([] as Array[int])
	check_eq(stats.total, 0, "비어 있음")
	check_eq(stats.ratio(stats.red), 0.0, "비율 0")
	check(stats.hot.is_empty(), "핫 없음")
	check_eq(HistoryStats.recent([] as Array[int]).size(), 0, "최근 없음")


func test_color_and_parity_counts() -> void:
	var stats := HistoryStats.from_history([0, 1, 2, 3, 32, 15] as Array[int])
	check_eq(stats.red, 3, "빨강 1,3,32")
	check_eq(stats.black, 2, "검정 2,15")
	check_eq(stats.green, 1, "초록 0")
	check_eq(stats.odd, 3, "홀 1,3,15")
	check_eq(stats.even, 2, "짝 2,32 (0 제외)")
	check_near(stats.ratio(stats.red), 0.5, 1e-9, "빨강 50%")


func test_hot_and_cold() -> void:
	var history: Array[int] = [5, 5, 5, 9, 9, 17, 17, 1]
	var stats := HistoryStats.from_history(history)
	check_eq(stats.hot, [5, 17, 9] as Array[int], "핫: 5(3회), 17(2회, 더 최근), 9(2회)")
	check_eq(stats.cold.size(), 3, "콜드 3개")
	for n in stats.cold:
		check(not history.has(n), "콜드는 안 나온 숫자 %d" % n)
	check_eq(stats.cold, [0, 2, 3] as Array[int], "동률이면 작은 숫자부터")


func test_recent_order() -> void:
	var history: Array[int] = []
	for i in 20:
		history.append(i)
	var recent := HistoryStats.recent(history)
	check_eq(recent.size(), 12, "12개")
	check_eq(recent[0], 19, "최신이 앞")
	check_eq(recent[11], 8, "12번째")
