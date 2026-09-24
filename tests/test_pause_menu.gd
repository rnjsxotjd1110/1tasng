extends "res://tests/lib/test_case.gd"
## PauseMenu: 생성, 계속하기/설정/통계 신호, 시간 흐름 체크박스가 SettingsManager 를 바꿈.

var menu: PauseMenu


func before_each() -> void:
	super.before_each()
	menu = PauseMenu.new()
	tree.root.add_child(menu)


func after_each() -> void:
	super.after_each()
	_disconnect_all()  # menu 소유 신호를 menu.free() 전에 미리 해제(freed 객체의 is_connected 오류 방지).
	menu.free()
	menu = null
	SettingsManager.reset_to_defaults()
	if FileAccess.file_exists(SettingsManager.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsManager.SETTINGS_PATH)


func test_resume_signal() -> void:
	var emitted := watch(menu.resume_requested)
	menu._resume_button.pressed.emit()
	check_eq(emitted.size(), 1, "계속하기 신호 발행")


func test_settings_and_stats_signals() -> void:
	var settings_emitted := watch(menu.settings_requested)
	var stats_emitted := watch(menu.stats_requested)
	menu.settings_requested.emit()
	menu.stats_requested.emit()
	check_eq(settings_emitted.size(), 1, "설정 신호")
	check_eq(stats_emitted.size(), 1, "통계 신호")


func test_pause_action_emits_resume() -> void:
	var emitted := watch(menu.resume_requested)
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	menu._unhandled_input(event)
	check_eq(emitted.size(), 1, "Esc 로 계속하기 신호")


func test_time_flows_checkbox_updates_settings() -> void:
	SettingsManager.pause_time_flows = true
	menu.refresh_time_flows_checkbox()
	menu._time_flows_box.button_pressed = false
	menu._time_flows_box.toggled.emit(false)
	check_eq(SettingsManager.pause_time_flows, false, "체크박스가 설정을 바꿈")


func test_save_and_title_button_disabled() -> void:
	var found := false
	for child in menu.get_children():
		found = found or _has_disabled_title_button(child)
	check(found, "저장 후 타이틀로 버튼이 존재하고 비활성 상태")


func _has_disabled_title_button(node: Node) -> bool:
	if node is Button and (node as Button).text == "PAUSE_SAVE_AND_TITLE":
		return (node as Button).disabled
	for child in node.get_children():
		if _has_disabled_title_button(child):
			return true
	return false
