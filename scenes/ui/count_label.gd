class_name CountLabel
extends Label
## 숫자가 바뀌면 카운트업 트윈으로 보여 주는 라벨(ART_BIBLE 6장: 기본 0.4초, 큰 금액 1.5~2초).
## 글꼴은 theme_type_variation(Num14Gold 등)으로 정한다. 표시는 항상 NumberFormat.

enum Style { PLAIN, SIGNED, PER_SECOND }

const DEFAULT_DURATION := 0.4
const BIG_DURATION := 1.6
## 변화량이 기존 값의 이 배수 이상이면 큰 금액으로 본다.
const BIG_RATIO := 10.0
const BUMP_PX := 1
const BUMP_TIME := 0.06

@export var style: Style = Style.PLAIN
@export var prefix: String = ""

var value: float = 0.0
var shown: float = 0.0
var _tween: Tween
var _bump_tween: Tween
var _home_y: float = 0.0
var _home_set: bool = false


func _ready() -> void:
	_render(shown)


## 목표 값으로 카운트업. duration < 0 이면 크기에 따라 자동, 0 이면 즉시.
func set_value(new_value: float, duration: float = -1.0) -> void:
	value = new_value
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration < 0.0:
		var base := maxf(absf(shown), 1.0)
		duration = BIG_DURATION if absf(new_value - shown) >= base * BIG_RATIO and absf(new_value) >= 1000.0 else DEFAULT_DURATION
	if duration == 0.0 or not is_inside_tree():
		shown = new_value
		_render(shown)
		return
	_tween = create_tween()
	_tween.tween_method(_on_step, shown, new_value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_step(current: float) -> void:
	shown = current
	_render(current)


func _render(current: float) -> void:
	match style:
		Style.SIGNED:
			text = prefix + NumberFormat.format_signed(current)
		Style.PER_SECOND:
			text = prefix + NumberFormat.format_signed(current) + "/s"
		_:
			text = prefix + NumberFormat.format(current)


## 1px 위로 튀었다가 돌아온다(정수 픽셀).
func bump() -> void:
	if not _home_set:
		_home_y = position.y
		_home_set = true
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	position.y = _home_y - BUMP_PX
	_bump_tween = create_tween()
	_bump_tween.tween_interval(BUMP_TIME)
	_bump_tween.tween_callback(func() -> void: position.y = _home_y)
