extends "res://tests/lib/test_case.gd"
## DebugLogic.tscn(2단계에서 삭제 예정)이 버튼으로 베팅·스핀·로그를 제대로 처리하는지 확인한다.

const SCENE_PATH := "res://scenes/debug/DebugLogic.tscn"


func test_buttons_place_bets_and_spin() -> void:
	var scene: Control = (load(SCENE_PATH) as PackedScene).instantiate()
	tree.root.add_child(scene)
	var buttons: Dictionary = scene.get("buttons")
	(buttons["red"] as Button).pressed.emit()
	check_eq(GameState.current_bets.size(), 1, "RED 버튼 → 베팅 1개")
	(buttons["black"] as Button).pressed.emit()
	check_eq(GameState.current_bets.size(), 1, "구슬 1개라 두 번째는 거부")
	(buttons["marble_slot"] as Button).pressed.emit()
	(buttons["straight"] as Button).pressed.emit()
	check_eq(GameState.current_bets.size(), 2, "구슬 +1 후 STRAIGHT")
	(buttons["spin"] as Button).pressed.emit()
	check_eq(GameState.get_stat_value(GameState.STAT_TOTAL_SPINS), 1.0, "SPIN 버튼 → 1스핀")
	var log_text: String = scene.call("get_log_text")
	check(log_text.contains("결과"), "결과 로그 출력")
	(buttons["add_chips"] as Button).pressed.emit()
	(buttons["spin_bulk"] as Button).pressed.emit()
	check(GameState.get_stat_value(GameState.STAT_TOTAL_SPINS) > 1.0, "SPIN ×100")
	check(String(scene.call("get_log_text")).contains("스핀 완료"), "일괄 스핀 로그")
	(buttons["reset"] as Button).pressed.emit()
	check_eq(GameState.chips, 100.0, "리셋")
	scene.free()
