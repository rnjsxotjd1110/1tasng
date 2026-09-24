class_name ScreenFlash
extends ColorRect
## 흰(ivory) 플래시: 지정 알파로 몇 프레임 켰다가 끈다(ART_BIBLE 7장: 알파 0.25, 2프레임). 번쩍임 줄이기 설정을 따른다.

const DEFAULT_ALPHA := 0.25
const DEFAULT_FRAMES := 2

var _frames_left: int = 0


func _ready() -> void:
	color = Palette.with_alpha(Palette.IVORY, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 360)
	visible = false


func flash(alpha: float = DEFAULT_ALPHA, frames: int = DEFAULT_FRAMES) -> void:
	var value := VisualSettings.flash_alpha(alpha)
	if value <= 0.0:
		return
	color = Palette.with_alpha(Palette.IVORY, value)
	visible = true
	_frames_left = frames


func _process(_delta: float) -> void:
	if _frames_left > 0:
		_frames_left -= 1
		if _frames_left == 0:
			visible = false
