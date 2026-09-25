class_name ScreenShake
extends Node
## 정수 픽셀 화면 흔들림(ART_BIBLE 6장: 1~3px). 대상 Node2D·CanvasLayer 의 위치/오프셋을 함께 흔든다.
## 설정 "흔들림 끄기"(VisualSettings.screen_shake)를 따른다.

var targets: Array[Node] = []
var _amount: int = 0
var _time_left: float = 0.0
var _duration: float = 0.0
var _homes: Dictionary = {}


func shake(px: int, duration: float) -> void:
	px = VisualSettings.shake_amount(px)
	if px <= 0:
		return
	if px >= _amount or _time_left <= 0.0:
		_amount = px
		_duration = duration
		_time_left = duration
	for target in targets:
		if not _homes.has(target):
			_homes[target] = _get_offset(target)


func is_shaking() -> bool:
	return _time_left > 0.0


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	var strength := ceili(_amount * clampf(_time_left / _duration, 0.0, 1.0))
	for target in targets:
		var home: Vector2 = _homes.get(target, Vector2.ZERO)
		if _time_left <= 0.0 or strength <= 0:
			_set_offset(target, home)
		else:
			_set_offset(target, home + Vector2(RngService.randi_range_misc(-strength, strength), RngService.randi_range_misc(-strength, strength)))
	if _time_left <= 0.0:
		_homes.clear()


func _get_offset(target: Node) -> Vector2:
	if target is CanvasLayer:
		return (target as CanvasLayer).offset
	if target is Node2D:
		return (target as Node2D).position
	if target is Control:
		return (target as Control).position
	return Vector2.ZERO


func _set_offset(target: Node, value: Vector2) -> void:
	if target is CanvasLayer:
		(target as CanvasLayer).offset = value
	elif target is Node2D:
		(target as Node2D).position = value
	elif target is Control:
		(target as Control).position = value
