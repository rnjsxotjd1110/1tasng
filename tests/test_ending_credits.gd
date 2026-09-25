extends "res://tests/lib/test_case.gd"
## EndingCredits: refresh() 가 GameState 통계·최종 구슬을 그대로 반영하는지, 계속하기 신호.

var credits: EndingCredits


func before_each() -> void:
	super.before_each()
	credits = EndingCredits.new()
	tree.root.add_child(credits)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	credits.free()
	credits = null


func test_refresh_shows_current_stats_and_marble() -> void:
	GameState.increment_stat(GameState.STAT_TOTAL_SPINS, 42.0)
	GameState.max_stat(GameState.STAT_BIGGEST_WIN, 9000.0)
	GameState.set_upgrade_level("marble_tier", 3)
	credits.refresh()
	var spins_label: CountLabel = credits._count_labels["STATS_TOTAL_SPINS"]
	check_eq(spins_label.value, 42.0, "총 스핀 반영")
	var win_label: CountLabel = credits._count_labels["STATS_BIGGEST_WIN"]
	check_eq(win_label.value, 9000.0, "최대 당첨금 반영")
	check_eq(credits._final_marble_label.text, tr(GameState.current_marble().name_key), "최종 구슬 이름")


func test_continue_pressed_signal() -> void:
	var emitted := watch(credits.continue_pressed)
	credits._continue_button.pressed.emit()
	check_eq(emitted.size(), 1, "계속하기 신호 발행")
