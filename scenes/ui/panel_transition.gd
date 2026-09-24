class_name PanelTransition
extends RefCounted
## 패널 열기·닫기 전환(ART_BIBLE 6장: 0.18초 ease-out). 위치는 매 단계 정수 픽셀로 반올림한다.
## 컨테이너 안이 아닌(직접 배치한) Control 에 쓴다.

const DURATION := 0.18
const OFFSET := Vector2(0, 6)
const HOME_META := "transition_home"


static func open(control: Control, offset: Vector2 = OFFSET, sound: bool = true) -> Tween:
	var home := _home(control)
	control.visible = true
	control.modulate.a = 0.0
	control.position = home + offset
	if sound:
		AudioManager.play_sfx("panel_open")
	var tween := control.create_tween()
	tween.tween_method(func(u: float) -> void:
		control.position = (home + offset * (1.0 - u)).round()
		control.modulate.a = u, 0.0, 1.0, DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween


static func close(control: Control, offset: Vector2 = OFFSET, sound: bool = true) -> Tween:
	var home := _home(control)
	if sound:
		AudioManager.play_sfx("panel_close")
	var tween := control.create_tween()
	tween.tween_method(func(u: float) -> void:
		control.position = (home + offset * u).round()
		control.modulate.a = 1.0 - u, 0.0, 1.0, DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		control.visible = false
		control.position = home)
	return tween


static func _home(control: Control) -> Vector2:
	if not control.has_meta(HOME_META):
		control.set_meta(HOME_META, control.position)
	return control.get_meta(HOME_META)
