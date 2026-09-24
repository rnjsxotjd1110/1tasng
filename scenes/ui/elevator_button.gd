class_name ElevatorButton
extends Button
## 엘리베이터 버튼(7단계, ART_BIBLE 12장): 다음 층 비용을 채우면 휠 오른쪽 위에 나타나 맥동한다.
## 새 스프라이트 없이 _draw() 로 그린다(6단계 특수 기능 위젯과 같은 절차적 패턴).

const SIZE := Vector2(28, 28)
const PULSE_SPEED := 2.6
const RING_RADIUS := 13.0

var _clock: float = 0.0


func _ready() -> void:
	size = SIZE
	focus_mode = Control.FOCUS_NONE
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = tr("ELEVATOR_BUTTON_TIP")


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(_clock * PULSE_SPEED)
	var bright := 1.15 if is_hovered() else 1.0
	var offset := Vector2(0, 1) if button_pressed else Vector2.ZERO
	var center := (size * 0.5).round() + offset
	draw_arc(center, RING_RADIUS, 0.0, TAU, 28, Palette.with_alpha(Palette.GOLD_HL, 0.35 * pulse * bright), 2.0)
	var tip := center + Vector2(0, -8)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-6, 6), tip + Vector2(6, 6)]), Palette.with_alpha(Palette.GOLD_HL, bright))
	draw_rect(Rect2(center + Vector2(-2, -1), Vector2(4, 9)), Palette.with_alpha(Palette.GOLD_HL, bright))
	draw_rect(Rect2(center + Vector2(-9, -9), Vector2(18, 18)), Palette.with_alpha(Palette.GOLD_D, 0.5), false, 1.0)
