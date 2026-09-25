extends "res://tests/lib/test_case.gd"
## CreditsScreen(8단계 1/N 초안): 닫기 신호, 스튜디오 이름·라이선스 고지 표시.

var screen: CreditsScreen


func before_each() -> void:
	super.before_each()
	screen = CreditsScreen.new()
	tree.root.add_child(screen)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	screen.free()
	screen = null


func test_close_button_emits_signal() -> void:
	var emitted := watch(screen.close_requested)
	var close_button := _find_close_button(screen)
	check(close_button != null, "닫기 버튼 존재")
	if close_button != null:
		close_button.pressed.emit()
	check_eq(emitted.size(), 1, "닫기 신호 발행")


func test_shows_studio_name_and_licenses() -> void:
	var texts := _collect_label_texts(screen)
	var joined := "\n".join(texts)
	check(joined.contains(Economy.STUDIO_NAME), "스튜디오 이름(가제) 표시")
	check(joined.contains("Godot"), "Godot 라이선스 고지")
	check(joined.contains("Galmuri"), "Galmuri 폰트 고지")


func _find_close_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child in node.get_children():
		var found := _find_close_button(child)
		if found != null:
			return found
	return null


## Label.text 는 번역 전 원본 키를 그대로 담고 있을 수 있다(Godot 이 그리는 시점에만 자동 번역).
## 서식 있는 줄(예: 스튜디오 이름)은 이미 tr() 로 완성된 문자열이라 여기서 다시 tr() 해도 그대로 돌아온다.
func _collect_label_texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append(tr(String((node as Label).text)))
	for child in node.get_children():
		out.append_array(_collect_label_texts(child))
	return out
