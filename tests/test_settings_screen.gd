extends "res://tests/lib/test_case.gd"
## SettingsScreen: 탭 5개 생성·전환, 컨트롤이 SettingsManager 필드를 실제로 바꾸는지.

var screen: SettingsScreen


func before_each() -> void:
	super.before_each()
	screen = SettingsScreen.new()
	tree.root.add_child(screen)


func after_each() -> void:
	super.after_each()
	screen.free()
	screen = null
	SettingsManager.reset_to_defaults()
	TranslationServer.set_locale("ko")
	SettingsManager.apply_all()
	if FileAccess.file_exists(SettingsManager.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsManager.SETTINGS_PATH)


func test_builds_five_tabs_with_only_one_visible() -> void:
	check_eq(screen._tab_contents.size(), 5, "탭 5개")
	var visible_count := 0
	for content: Control in screen._tab_contents.values():
		if content.visible:
			visible_count += 1
	check_eq(visible_count, 1, "한 번에 하나만 보임")
	check((screen._tab_contents[SettingsScreen.TAB_AUDIO] as Control).visible, "기본 탭은 오디오")


func test_switching_tabs_changes_visibility() -> void:
	screen.select_tab(SettingsScreen.TAB_DATA)
	check((screen._tab_contents[SettingsScreen.TAB_DATA] as Control).visible, "데이터 탭 보임")
	check(not (screen._tab_contents[SettingsScreen.TAB_AUDIO] as Control).visible, "오디오 탭 숨김")


func test_master_volume_slider_updates_settings_manager() -> void:
	var audio_tab: VBoxContainer = screen._tab_contents[SettingsScreen.TAB_AUDIO]
	var slider := _find_slider(audio_tab)
	check(slider != null, "슬라이더 존재")
	slider.value = 0.3
	check_rel(SettingsManager.master_volume, 0.3, 1e-6, "마스터 볼륨 슬라이더가 실제 필드를 바꿈")


func test_reset_button_disabled_until_reset_typed() -> void:
	screen.select_tab(SettingsScreen.TAB_DATA)
	check(screen._reset_button.disabled, "RESET 입력 전에는 비활성")
	screen._reset_line_edit.text = "reset"
	screen._refresh_reset_enabled()
	check(screen._reset_button.disabled, "대소문자 다르면 여전히 비활성")
	screen._reset_line_edit.text = "RESET"
	screen._refresh_reset_enabled()
	check(not screen._reset_button.disabled, "정확히 입력하면 활성")


func _find_slider(node: Node) -> HSlider:
	for child in node.get_children():
		if child is HSlider:
			return child
		var found := _find_slider(child)
		if found != null:
			return found
	return null
