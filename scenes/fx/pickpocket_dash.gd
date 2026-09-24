class_name PickpocketDash
extends Control
## 소매치기 패널티: 작은 그림자가 상단 바를 스치듯 지나가며 칩을 낚아챈다(GDD 9장). 1회성, 끝나면 스스로 사라진다.

const DURATION := 0.45
const Y := 3.0
const SIZE := Vector2(11, 15)

var _time: float = 0.0


static func spawn(parent: Node) -> void:
	parent.add_child(PickpocketDash.new())


func _ready() -> void:
	size = Vector2(640, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioManager.play_sfx("pickpocket_squeak")


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= DURATION:
		queue_free()


func _draw() -> void:
	var u := clampf(_time / DURATION, 0.0, 1.0)
	var x := roundf(lerpf(-SIZE.x, 640.0, u))
	var alpha := sin(u * PI)
	draw_rect(Rect2(Vector2(x, Y), SIZE), Palette.with_alpha(Palette.NIGHT, 0.85 * alpha))
	draw_rect(Rect2(Vector2(x + 3, Y + 2), Vector2(3, 3)), Palette.with_alpha(Palette.RED_HL, 0.9 * alpha))
