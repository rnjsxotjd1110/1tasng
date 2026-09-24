extends "res://tests/lib/test_case.gd"


func test_moving_average() -> void:
	var tracker := IncomeTracker.new(60.0)
	check_eq(tracker.per_second(0.0), 0.0, "기록 없음")
	tracker.add(0.0, 100.0)
	check_near(tracker.per_second(5.0), 10.0, 1e-9, "초반은 최소 10초로 나눔")
	tracker.add(30.0, 200.0)
	check_near(tracker.per_second(30.0), 10.0, 1e-9, "300 / 30초")
	check_near(tracker.per_second(60.0), 5.0, 1e-9, "300 / 60초")
	check_near(tracker.per_second(70.0), 200.0 / 60.0, 1e-9, "60초 지난 기록은 빠짐")
	tracker.add(80.0, -500.0)
	check(tracker.per_second(80.0) < 0.0, "손실이면 음수")
	tracker.reset()
	check_eq(tracker.per_second(100.0), 0.0, "초기화")
