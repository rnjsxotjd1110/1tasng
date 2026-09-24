class_name PixelDigits
extends RefCounted
## 3×5 픽셀 숫자(assets/sprites/ui/digits_3x5.png, 숫자마다 3px 가로로 이어 붙임)를 그린다.
## 휠 숫자 링·기록 토큰·베팅 칸이 같은 글꼴을 쓴다. 위치는 정수 픽셀로 맞춘다.

const DIGIT_W := 3
const DIGIT_H := 5
const GAP := 1


static func width_of(number: int) -> int:
	var count := str(absi(number)).length()
	return count * DIGIT_W + (count - 1) * GAP


## center 를 중심으로 number 를 그린다.
static func draw(canvas: CanvasItem, texture: Texture2D, number: int, center: Vector2, modulate: Color = Color.WHITE) -> void:
	var text := str(absi(number))
	var width := width_of(number)
	var top_left := (center - Vector2(width * 0.5, DIGIT_H * 0.5)).round()
	for i in text.length():
		var digit := text.unicode_at(i) - 48
		canvas.draw_texture_rect_region(texture, Rect2(top_left + Vector2(i * (DIGIT_W + GAP), 0), Vector2(DIGIT_W, DIGIT_H)),
			Rect2(digit * DIGIT_W, 0, DIGIT_W, DIGIT_H), modulate)
