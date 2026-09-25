class_name FloatingText
extends Label
## 떠오르는 텍스트(ART_BIBLE 6장: 0.8초 동안 16px 상승, 마지막 0.3초 페이드). 위치는 정수 픽셀.

const SCENE_PATH := "res://scenes/fx/FloatingText.tscn"
const DURATION := 0.8
const RISE := 16.0
const FADE := 0.3

var _time: float = 0.0
var _origin := Vector2.ZERO


## parent 에 text 를 띄운다. center 는 글자 가운데(부모 좌표), variation 은 테마 글꼴(Num14Gold 등).
static func spawn(parent: Node, text_value: String, variation: String, center: Vector2) -> FloatingText:
	var label: FloatingText = load(SCENE_PATH).instantiate()
	label.text = text_value
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.auto_translate = false
	parent.add_child(label)
	label.reset_size()
	var label_size := label.get_combined_minimum_size()
	label._origin = (center - label_size * 0.5).round()
	label.position = label._origin
	return label


func _process(delta: float) -> void:
	_time += delta
	var u := clampf(_time / DURATION, 0.0, 1.0)
	position = _origin - Vector2(0, roundf(RISE * (1.0 - (1.0 - u) * (1.0 - u))))
	modulate.a = clampf((DURATION - _time) / FADE, 0.0, 1.0)
	if _time >= DURATION:
		queue_free()
