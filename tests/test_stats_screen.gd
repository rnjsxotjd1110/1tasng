extends "res://tests/lib/test_case.gd"
## StatsScreen: 생성, refresh() 가 GameState 통계를 그대로 반영하는지, 카운트업(즉시 값 확인은 duration=0 로).

var screen: StatsScreen


func before_each() -> void:
	super.before_each()
	screen = StatsScreen.new()
	tree.root.add_child(screen)


func after_each() -> void:
	super.after_each()
	screen.free()
	screen = null


func test_refresh_shows_current_stats() -> void:
	GameState.increment_stat(GameState.STAT_TOTAL_SPINS, 10.0)
	GameState.increment_stat(GameState.STAT_TOTAL_WINS, 4.0)
	GameState.max_stat(GameState.STAT_BIGGEST_WIN, 500.0)
	GameState.push_results([7, 7, 3])
	screen.refresh()
	var spins_label: CountLabel = screen._count_labels["STATS_TOTAL_SPINS"]
	check_eq(spins_label.value, 10.0, "총 스핀 반영")
	var win_label: CountLabel = screen._count_labels["STATS_BIGGEST_WIN"]
	check_eq(win_label.value, 500.0, "최대 당첨금 반영")
	check_eq(screen._win_rate_label.text, NumberFormat.format_percent(0.4), "승률 40%")
	check_eq(screen._most_frequent_label.text, NumberFormat.format(7.0), "최다 출현 숫자 7")


func test_win_rate_shows_dash_with_no_spins() -> void:
	screen.refresh()
	check_eq(screen._win_rate_label.text, "-", "스핀이 없으면 승률 표시 안 함")
	check_eq(screen._most_frequent_label.text, "-", "결과가 없으면 최다 출현 표시 안 함")


func test_play_time_formats_hours_minutes() -> void:
	GameState.stats[GameState.STAT_PLAY_TIME] = 3.0 * 3600.0 + 12.0 * 60.0
	screen.refresh()
	check_eq(screen._play_time_label.text, tr("DURATION_HOURS_MINUTES") % ["3", "12"], "3시간 12분")
