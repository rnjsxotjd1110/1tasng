extends "res://tests/lib/test_case.gd"

var panel: DebtPanel


func before_each() -> void:
	super.before_each()
	panel = DebtPanel.new()
	tree.root.add_child(panel)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	panel.free()
	panel = null


func test_open_without_debt_stays_closed() -> void:
	panel.open()
	check(not panel.visible, "빚 없으면 안 열림")


func test_open_with_debt_shows_panel_and_rows() -> void:
	GameState.debts = [{"principal": 10.0, "remaining": 20.0}]
	panel.open()
	check(panel.visible, "열림")
	check_eq(panel._rows_container.get_child_count(), 1, "행 1개")


func test_rows_match_debt_count() -> void:
	GameState.debts = [
		{"principal": 10.0, "remaining": 20.0},
		{"principal": 5.0, "remaining": 8.0},
		{"principal": 3.0, "remaining": 1.0},
	]
	panel.open()
	check_eq(panel._rows_container.get_child_count(), 3, "행 3개")


func _buttons_of(row: Control) -> Array:
	for child in row.get_children():
		if child is HBoxContainer:
			return (child as HBoxContainer).get_children()
	return []


func test_repay_buttons_disabled_when_unaffordable() -> void:
	GameState.chips = 5.0
	GameState.debts = [{"principal": 10.0, "remaining": 20.0}]
	panel.open()
	var row := panel._rows_container.get_child(0) as Control
	var buttons := _buttons_of(row)
	check((buttons[0] as Button).disabled, "전액 상환 비활성(칩 부족)")
	check((buttons[1] as Button).disabled, "절반 상환도 비활성(10 > 5)")


func test_repay_buttons_enabled_when_affordable() -> void:
	GameState.chips = 1000.0
	GameState.debts = [{"principal": 10.0, "remaining": 20.0}]
	panel.open()
	var row := panel._rows_container.get_child(0) as Control
	var buttons := _buttons_of(row)
	check(not (buttons[0] as Button).disabled, "전액 상환 가능")
	check(not (buttons[1] as Button).disabled, "절반 상환 가능")


func test_full_repay_button_pays_off_debt() -> void:
	GameState.chips = 1000.0
	GameState.debts = [{"principal": 10.0, "remaining": 20.0}]
	panel.open()
	var row := panel._rows_container.get_child(0) as Control
	var buttons := _buttons_of(row)
	(buttons[0] as Button).pressed.emit()
	check(GameState.debts.is_empty(), "전액 상환으로 빚 없음")


func test_half_repay_button_reduces_remaining() -> void:
	GameState.chips = 1000.0
	GameState.debts = [{"principal": 10.0, "remaining": 20.0}]
	panel.open()
	var row := panel._rows_container.get_child(0) as Control
	var buttons := _buttons_of(row)
	(buttons[1] as Button).pressed.emit()
	check_near(float(GameState.debts[0]["remaining"]), 10.0, 1e-6, "절반 상환")


func test_refresh_adds_no_rows_when_debts_empty() -> void:
	GameState.debts = [{"principal": 10.0, "remaining": 20.0}]
	panel.open()
	# _refresh() 는 기존 행을 queue_free() 로 지운다(half/full 버튼 자신의 pressed 처리 도중에도 안전하게
	# 지우기 위해 즉시 free() 대신 지연 삭제를 쓴다) — 그래서 이 테스트에서는 지연 삭제분을 직접 정리한 뒤
	# "빚이 없으면 새 행을 만들지 않는다"만 확인한다(실제 사라짐은 다음 프레임에 일어난다).
	for child in panel._rows_container.get_children():
		child.free()
	GameState.debts = []
	panel._refresh()
	check_eq(panel._rows_container.get_child_count(), 0, "빚이 없으면 새 행 없음")
