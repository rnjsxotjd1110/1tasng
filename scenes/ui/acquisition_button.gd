class_name AcquisitionButton
extends Button
## 하우스 인수 버튼(7단계, GDD 10장). 펜트하우스에서 EndingService.can_trigger() 가 켜지면
## 엘리베이터 버튼과 같은 자리(최고층이라 엘리베이터 버튼은 이미 숨어 있다)에 나타나 왕관이 맥동한다.

const SIZE := Vector2(28, 28)
const PULSE_SPEED := 2.2
const RING_RADIUS := 13.0

var _clock: float = 0.0


func _ready() -> void:
	size = SIZE
	focus_mode = Control.FOCUS_NONE
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = tr("ACQUISITION_BUTTON_TIP")


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(_clock * PULSE_SPEED)
	var bright := 1.15 if is_hovered() else 1.0
	var offset := Vector2(0, 1) if button_pressed else Vector2.ZERO
	var center := (size * 0.5).round() + offset
	draw_arc(center, RING_RADIUS, 0.0, TAU, 28, Palette.with_alpha(Palette.GOLD_HL, 0.35 * pulse * bright), 2.0)
	_draw_crown(center, bright)
	draw_rect(Rect2(center + Vector2(-9, -9), Vector2(18, 18)), Palette.with_alpha(Palette.GOLD_D, 0.5), false, 1.0)


func _draw_crown(center: Vector2, bright: float) -> void:
	var color := Palette.with_alpha(Palette.GOLD_HL, bright)
	var base := center + Vector2(-7, 4)
	draw_rect(Rect2(base, Vector2(14, 3)), color)
	draw_colored_polygon(PackedVector2Array([base + Vector2(0, 0), base + Vector2(-1, -7), base + Vector2(3, -2)]), color)
	draw_colored_polygon(PackedVector2Array([base + Vector2(6, 0), base + Vector2(7, -9), base + Vector2(8, 0)]), color)
	draw_colored_polygon(PackedVector2Array([base + Vector2(14, 0), base + Vector2(15, -7), base + Vector2(11, -2)]), color)
	draw_rect(Rect2(base + Vector2(6, -9), Vector2(2, 2)), Palette.with_alpha(Palette.RED_L, bright))
