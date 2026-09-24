extends "res://tests/lib/test_case.gd"
## DialogueBox: 타자기 진행, 클릭으로 즉시완성→다음 줄, 선택지, 화자 표시.

const STEP := 0.02

var box: DialogueBox


func before_each() -> void:
	super.before_each()
	box = DialogueBox.new()
	tree.root.add_child(box)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	box.free()
	box = null


func _entry(lines: Array[String] = ["NEAR_MISS"]) -> Dictionary:
	return {"speaker": "NPC_RATCHET", "portrait": "sly", "lines": lines}


func test_say_opens_box_and_sets_name() -> void:
	box.say(_entry())
	check(box.is_open(), "열림")
	check_eq(box._name_label.text, tr("NPC_RATCHET"), "화자 이름")
	check(box._typing, "타이핑 시작")
	check_eq(box._text_label.visible_characters, 0, "글자 아직 안 보임")


func test_typewriter_reveals_over_time() -> void:
	box.say(_entry(["MILESTONE_REACHED"]))
	var full_len := box._text_label.text.length()
	for i in 3:
		box._process(STEP)
	check(box._text_label.visible_characters > 0, "일부 공개")
	check(box._text_label.visible_characters < full_len, "아직 전부는 아님")


func test_advance_while_typing_completes_instantly() -> void:
	box.say(_entry(["MILESTONE_REACHED"]))
	box.advance()
	check(not box._typing, "즉시 완성")
	check_eq(box._text_label.visible_characters, box._text_label.text.length(), "전부 공개")
	check(box._arrow.visible, "다음 표시")


func test_advance_after_last_line_emits_finished() -> void:
	var finished := watch(box.finished)
	box.say(_entry())
	box.advance()  # 즉시 완성
	box.advance()  # 다음(마지막 줄이라 종료)
	check_eq(finished.size(), 1, "finished 발행")
	check(not box.is_open(), "닫힘")


func test_multiple_lines_advance_in_sequence() -> void:
	var lines: Array[String] = ["NEAR_MISS", "MILESTONE_REACHED"]
	box.say(_entry(lines))
	check_eq(box._text_label.text, tr("NEAR_MISS"), "첫 줄")
	box.advance()
	box.advance()
	check_eq(box._text_label.text, tr("MILESTONE_REACHED"), "둘째 줄(DialogueBox 는 %인자 치환 없이 raw tr() 만 보여준다)")


func test_choices_shown_after_lines_and_pick_emits() -> void:
	var choices: Array[String] = ["BUTTON_REPAY_ALL", "BUTTON_REPAY_HALF"]
	var picked := watch(box.choice_made)
	var finished := watch(box.finished)
	box.ask(_entry(), choices)
	box.advance()  # 완성
	box.advance()  # 선택지 표시
	check(box._choice_box.visible, "선택지 표시")
	check_eq(box._choice_box.get_child_count(), 2, "버튼 2개")
	(box._choice_box.get_child(1) as Button).pressed.emit()
	check_eq(picked.size(), 1, "choice_made")
	check_eq(picked[0][0], 1, "두 번째 선택")
	check_eq(finished.size(), 1, "선택 후 finished")


func test_no_advance_while_choices_pending() -> void:
	box.ask(_entry(), ["BUTTON_REPAY_ALL"])
	box.advance()
	box.advance()
	check(box._choice_box.visible, "선택지 대기 중")
	box.advance()  # 선택지 중엔 무시
	check(box._choice_box.visible, "여전히 대기")
