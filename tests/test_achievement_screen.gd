extends "res://tests/lib/test_case.gd"
## AchievementScreen: refresh() 가 카테고리별로 슬롯을 만들고, 해금 여부에 따라 아이콘·툴팁이 갈린다.

var screen: AchievementScreen


func before_each() -> void:
	super.before_each()
	screen = AchievementScreen.new()
	tree.root.add_child(screen)


func after_each() -> void:
	super.after_each()
	screen.free()
	screen = null


func _all_slots() -> Array[AchievementSlot]:
	var slots: Array[AchievementSlot] = []
	for grid in screen._list.get_children():
		if grid is GridContainer:
			for child in grid.get_children():
				slots.append(child as AchievementSlot)
	return slots


func _find_slot(id: String) -> AchievementSlot:
	for slot in _all_slots():
		if slot._id == id:
			return slot
	return null


func test_refresh_builds_one_slot_per_achievement() -> void:
	screen.refresh()
	check_eq(_all_slots().size(), AchievementData.all().size(), "전체 업적 수만큼 슬롯 생성")


func test_refresh_replaces_previous_slots() -> void:
	screen.refresh()
	screen.refresh()
	check_eq(_all_slots().size(), AchievementData.all().size(), "다시 열어도 중복 생성 안 함")


func test_progress_label_counts_unlocked() -> void:
	var total := AchievementData.all().size()
	screen.refresh()
	check_eq(screen._progress_label.text, "%s / %s" % [NumberFormat.format(0.0), NumberFormat.format(float(total))], "0개 달성")
	GameState.unlocked_achievements.append("first_spin")
	screen.refresh()
	check_eq(screen._progress_label.text, "%s / %s" % [NumberFormat.format(1.0), NumberFormat.format(float(total))], "1개 달성")


func test_unlocked_achievement_shows_real_icon_and_tooltip() -> void:
	GameState.unlocked_achievements.append("first_spin")
	screen.refresh()
	var slot := _find_slot("first_spin")
	check(slot != null and slot._unlocked, "해금된 업적 슬롯")
	check_eq(slot._tooltip_text(), "%s\n%s" % [tr("ACH_FIRST_SPIN_NAME"), tr("ACH_FIRST_SPIN_DESC")], "실제 이름·설명 표시")


func test_locked_non_hidden_shows_real_name_but_silhouette() -> void:
	screen.refresh()
	var slot := _find_slot("zero_hit")
	check(slot != null and not slot._unlocked and not slot._hidden, "미달성 일반 업적 슬롯")
	check_eq(slot._tooltip_text(), "%s\n%s" % [tr("ACH_ZERO_HIT_NAME"), tr("ACH_ZERO_HIT_DESC")], "이름·설명은 공개")


func test_hidden_locked_achievement_hides_name_and_desc() -> void:
	screen.refresh()
	var slot := _find_slot("same_number_3")
	check(slot != null and slot._hidden and not slot._unlocked, "숨김 미달성 슬롯")
	check_eq(slot._tooltip_text(), "%s\n%s" % [tr("ACH_HIDDEN_NAME"), tr("ACH_HIDDEN_DESC")], "??? 로 대체")


func test_hidden_achievement_reveals_after_unlock() -> void:
	GameState.unlocked_achievements.append("same_number_3")
	screen.refresh()
	var slot := _find_slot("same_number_3")
	check_eq(slot._tooltip_text(), "%s\n%s" % [tr("ACH_SAME_NUMBER_3_NAME"), tr("ACH_SAME_NUMBER_3_DESC")], "해금 후에는 실제 내용 공개")
