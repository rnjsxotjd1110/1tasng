class_name FocusStyle
extends RefCounted
## 키보드·게임패드 포커스 테두리(ART_BIBLE: neon_cyan, SEM_FOCUS). 게임 버튼은 대부분 focus_mode 를
## FOCUS_NONE 으로 꺼 두지만(마우스 전용), 설정·일시정지·통계 화면은 포커스 이동이 필요하므로 여기서 켠다.

const BORDER_WIDTH := 1


static func apply(control: Control) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.add_theme_stylebox_override("focus", box())


static func box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Palette.SEM_FOCUS
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(0)
	style.set_expand_margin_all(1.0)
	return style
