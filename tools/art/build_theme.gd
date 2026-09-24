extends SceneTree
## assets/ui/theme_main.tres 를 만든다(프로젝트 기본 테마, project.godot gui/theme/custom).
##   python3 tools/art/gen_ui.py && python3 tools/art/gen_fonts.py
##   godot --headless --import
##   godot --headless -s tools/art/build_theme.gd
## 9-슬라이스 여백은 tools/art/gen_ui.py 의 그림과 맞춰야 한다.

const OUT := "res://assets/ui/theme_main.tres"
const UI := "res://assets/ui/"
const ICONS := "res://assets/sprites/ui/"
const FONTS := "res://assets/fonts/"

const IVORY := Color("#f4f0e8")
const MIST := Color("#b8b2c4")
const STONE := Color("#6e6882")
const GOLD_HL := Color("#ffd95a")
const GOLD_SHINE := Color("#fff2b0")
const VOID := Color("#0b0a14")
const RED_D := Color("#4a0f1a")
const CLOVER := Color("#5ee06b")
## 비트맵 숫자 폰트는 색이 텍스처에 들어 있어 흰색(곱하기 1)으로 그린다.
const NO_TINT := Color(1, 1, 1, 1)

## Galmuri 권장 픽셀 크기(README): 9 → 10px, 11 → 12px, 14 → 15px
const SIZE_SMALL := 10
const SIZE_BODY := 12
const SIZE_TITLE := 15

var theme := Theme.new()


func _initialize() -> void:
	var font_small: Font = load(FONTS + "Galmuri9.ttf")
	var font_body: Font = load(FONTS + "Galmuri11.ttf")
	var font_bold: Font = load(FONTS + "Galmuri11-Bold.ttf")
	var font_title: Font = load(FONTS + "Galmuri14.ttf")
	theme.default_font = font_body
	theme.default_font_size = SIZE_BODY

	# ── Label ────────────────────────────────────────────
	theme.set_color("font_color", "Label", IVORY)
	theme.set_color("font_shadow_color", "Label", Color(VOID, 0.85))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_constant("line_spacing", "Label", 1)
	_label_variation("LabelSmall", font_small, SIZE_SMALL, IVORY)
	_label_variation("LabelSmallMuted", font_small, SIZE_SMALL, MIST)
	_label_variation("LabelMuted", font_body, SIZE_BODY, MIST)
	_label_variation("LabelBold", font_bold, SIZE_BODY, IVORY)
	_label_variation("LabelTitle", font_title, SIZE_TITLE, GOLD_HL)
	_label_variation("LabelGold", font_body, SIZE_BODY, GOLD_HL)
	_label_variation("LabelClover", font_body, SIZE_BODY, CLOVER)
	for variant: String in ["gold", "ivory", "red", "stone", "clover"]:
		for size: int in [7, 14]:
			var type_name := "Num%d%s" % [size, variant.capitalize()]
			theme.set_type_variation(type_name, "Label")
			theme.set_font("font", type_name, load(FONTS + "num%d_%s.fnt" % [size, variant]))
			theme.set_font_size("font_size", type_name, size)
			theme.set_color("font_color", type_name, NO_TINT)
			theme.set_color("font_shadow_color", type_name, Color(0, 0, 0, 0))
			theme.set_constant("line_spacing", type_name, 0)

	# ── Button ───────────────────────────────────────────
	_button_type("Button", "button", IVORY, GOLD_SHINE, GOLD_HL, STONE)
	_button_type("ButtonGold", "button_gold", Color("#3b2218"), Color("#3b2218"), Color("#3b2218"), STONE, true)
	_button_type("ButtonDark", "button_dark", MIST, IVORY, GOLD_HL, STONE, true)
	theme.set_font("font", "ButtonGold", font_bold)
	# 살 수 없는 구매 버튼(stone 톤, 3단계)
	_button_type("ButtonStone", "button_stone", MIST, IVORY, GOLD_HL, STONE, true)
	# 탭: 선택(pressed) 상태가 금색 밑줄
	theme.set_type_variation("TabButton", "Button")
	var tab_normal := _box(UI + "tab_normal.png", 4, 4, 4, 4, 5, 3, 5, 3)
	var tab_hover := _box(UI + "tab_hover.png", 4, 4, 4, 4, 5, 3, 5, 3)
	var tab_selected := _box(UI + "tab_selected.png", 4, 4, 4, 4, 5, 3, 5, 3)
	for state_name: String in ["normal", "disabled"]:
		theme.set_stylebox(state_name, "TabButton", tab_normal)
	theme.set_stylebox("hover", "TabButton", tab_hover)
	theme.set_stylebox("pressed", "TabButton", tab_selected)
	theme.set_stylebox("hover_pressed", "TabButton", tab_selected)
	theme.set_stylebox("focus", "TabButton", StyleBoxEmpty.new())
	theme.set_font("font", "TabButton", font_small)
	theme.set_font_size("font_size", "TabButton", SIZE_SMALL)
	theme.set_color("font_color", "TabButton", MIST)
	theme.set_color("font_hover_color", "TabButton", IVORY)
	theme.set_color("font_pressed_color", "TabButton", GOLD_HL)
	theme.set_color("font_hover_pressed_color", "TabButton", GOLD_SHINE)
	theme.set_color("font_focus_color", "TabButton", MIST)
	theme.set_color("icon_normal_color", "TabButton", NO_TINT)
	theme.set_color("icon_hover_color", "TabButton", NO_TINT)
	theme.set_color("icon_pressed_color", "TabButton", NO_TINT)
	theme.set_color("icon_hover_pressed_color", "TabButton", NO_TINT)
	theme.set_color("icon_focus_color", "TabButton", NO_TINT)
	# 칩 크기 토글: 어두운 버튼, 선택되면 금 버튼
	theme.set_type_variation("ChipButton", "Button")
	theme.set_stylebox("normal", "ChipButton", _button_box("button_dark_normal", false))
	theme.set_stylebox("hover", "ChipButton", _button_box("button_dark_hover", false))
	theme.set_stylebox("pressed", "ChipButton", _button_box("button_gold_pressed", true))
	theme.set_stylebox("hover_pressed", "ChipButton", _button_box("button_gold_pressed", true))
	theme.set_stylebox("disabled", "ChipButton", _button_box("button_dark_disabled", false))
	theme.set_stylebox("focus", "ChipButton", StyleBoxEmpty.new())
	theme.set_font("font", "ChipButton", font_small)
	theme.set_font_size("font_size", "ChipButton", SIZE_SMALL)
	theme.set_color("font_color", "ChipButton", MIST)
	theme.set_color("font_hover_color", "ChipButton", IVORY)
	theme.set_color("font_pressed_color", "ChipButton", GOLD_SHINE)
	theme.set_color("font_hover_pressed_color", "ChipButton", GOLD_SHINE)
	theme.set_color("font_focus_color", "ChipButton", MIST)
	theme.set_color("font_disabled_color", "ChipButton", STONE)
	# SPIN: 큰 빨간 카지노 버튼(80×30 그림을 늘리지 않고 그대로 쓴다)
	theme.set_type_variation("SpinButton", "Button")
	for pair: Array in [["normal", "spin_normal", 0], ["hover", "spin_hover", 0], ["pressed", "spin_pressed", 2],
			["hover_pressed", "spin_pressed", 2], ["disabled", "spin_disabled", 0]]:
		var box := _box(UI + String(pair[1]) + ".png", 12, 12, 12, 12, 8, 6 + int(pair[2]), 8, 10 - int(pair[2]))
		theme.set_stylebox(String(pair[0]), "SpinButton", box)
	theme.set_stylebox("focus", "SpinButton", StyleBoxEmpty.new())
	theme.set_font("font", "SpinButton", font_title)
	theme.set_font_size("font_size", "SpinButton", SIZE_TITLE)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "SpinButton", IVORY)
	theme.set_color("font_disabled_color", "SpinButton", STONE)
	theme.set_color("font_outline_color", "SpinButton", RED_D)
	theme.set_constant("outline_size", "SpinButton", 0)

	# ── Panel ────────────────────────────────────────────
	var panel := _box(UI + "panel_dark.png", 6, 6, 6, 6, 7, 7, 7, 7)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	_panel_variation("PanelPlain", _box(UI + "panel_plain.png", 5, 5, 5, 5, 5, 5, 5, 5))
	_panel_variation("PanelBar", _box(UI + "panel_bar.png", 5, 5, 5, 5, 4, 2, 4, 2))
	_panel_variation("PanelInset", _box(UI + "frame_inset.png", 2, 2, 2, 2, 3, 2, 3, 2))
	_panel_variation("PanelFelt", _box(UI + "panel_felt.png", 10, 10, 10, 10, 10, 10, 10, 10))
	# 업그레이드 카드(3단계): 12×12, 9-슬라이스 여백 4
	for card: Array in [["CardNormal", "card_normal"], ["CardHover", "card_hover"], ["CardReady", "card_ready"],
			["CardMax", "card_max"], ["CardLocked", "card_locked"], ["CardMarble", "card_marble"]]:
		_panel_variation(String(card[0]), _box(UI + String(card[1]) + ".png", 4, 4, 4, 4, 4, 4, 4, 4))
	_panel_variation("CardSlot", _box(UI + "card_slot.png", 2, 2, 2, 2, 2, 2, 2, 2))
	_panel_variation("BadgeGolden", _box(UI + "badge_golden.png", 4, 4, 4, 4, 5, 2, 5, 2))
	theme.set_stylebox("panel", "TooltipPanel", _box(UI + "tooltip.png", 2, 2, 2, 2, 4, 3, 4, 3))
	theme.set_font("font", "TooltipLabel", font_small)
	theme.set_font_size("font_size", "TooltipLabel", SIZE_SMALL)
	theme.set_color("font_color", "TooltipLabel", IVORY)
	theme.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))
	theme.set_stylebox("panel", "PopupPanel", panel)
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_stylebox("hover", "PopupMenu", _box(UI + "button_gold_normal.png", 3, 3, 3, 3, 2, 1, 2, 1))
	theme.set_color("font_color", "PopupMenu", IVORY)
	theme.set_color("font_hover_color", "PopupMenu", Color("#3b2218"))

	# ── 구분선 ───────────────────────────────────────────
	var sep := StyleBoxLine.new()
	sep.color = Color("#6b4a12")
	sep.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep)
	theme.set_constant("separation", "HSeparator", 3)
	var vsep := StyleBoxLine.new()
	vsep.color = Color("#6b4a12")
	vsep.thickness = 1
	vsep.vertical = true
	theme.set_stylebox("separator", "VSeparator", vsep)

	# ── 스크롤바·슬라이더·체크박스·진행 막대·입력 ───────
	for bar: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, _box(UI + "scroll_track.png", 2, 2, 2, 2, 0, 0, 0, 0))
		theme.set_stylebox("scroll_focus", bar, _box(UI + "scroll_track.png", 2, 2, 2, 2, 0, 0, 0, 0))
		theme.set_stylebox("grabber", bar, _box(UI + "scroll_grabber.png", 2, 2, 2, 2, 0, 0, 0, 0))
		theme.set_stylebox("grabber_highlight", bar, _box(UI + "scroll_grabber_hover.png", 2, 2, 2, 2, 0, 0, 0, 0))
		theme.set_stylebox("grabber_pressed", bar, _box(UI + "scroll_grabber_pressed.png", 2, 2, 2, 2, 0, 0, 0, 0))
		for icon_name: String in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			theme.set_icon(icon_name, bar, _empty_icon())
	for slider: String in ["HSlider"]:
		theme.set_stylebox("slider", slider, _box(UI + "slider_track.png", 2, 2, 2, 2, 0, 2, 0, 2))
		theme.set_stylebox("grabber_area", slider, _box(UI + "slider_fill.png", 2, 2, 2, 2, 0, 2, 0, 2))
		theme.set_stylebox("grabber_area_highlight", slider, _box(UI + "slider_fill.png", 2, 2, 2, 2, 0, 2, 0, 2))
		theme.set_icon("grabber", slider, load(ICONS + "slider_grabber.png"))
		theme.set_icon("grabber_highlight", slider, load(ICONS + "slider_grabber_hover.png"))
		theme.set_icon("grabber_disabled", slider, load(ICONS + "slider_grabber.png"))
		theme.set_icon("tick", slider, _empty_icon())
		theme.set_constant("center_grabber", slider, 0)
		theme.set_constant("grabber_offset", slider, 0)
	for check: String in ["CheckBox", "CheckButton"]:
		theme.set_icon("checked", check, load(ICONS + "check_on.png"))
		theme.set_icon("unchecked", check, load(ICONS + "check_off.png"))
		theme.set_icon("checked_disabled", check, load(ICONS + "check_on.png"))
		theme.set_icon("unchecked_disabled", check, load(ICONS + "check_off.png"))
		theme.set_icon("checked_mirrored", check, load(ICONS + "check_on.png"))
		theme.set_icon("unchecked_mirrored", check, load(ICONS + "check_off.png"))
		for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			theme.set_stylebox(state_name, check, StyleBoxEmpty.new())
		theme.set_color("font_color", check, IVORY)
		theme.set_color("font_hover_color", check, GOLD_SHINE)
		theme.set_color("font_pressed_color", check, IVORY)
		theme.set_color("font_hover_pressed_color", check, GOLD_SHINE)
		theme.set_color("font_focus_color", check, IVORY)
		theme.set_constant("h_separation", check, 4)
	theme.set_stylebox("background", "ProgressBar", _box(UI + "frame_inset.png", 2, 2, 2, 2, 0, 0, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(UI + "slider_fill.png", 2, 2, 2, 2, 0, 0, 0, 0))
	theme.set_color("font_color", "ProgressBar", IVORY)
	theme.set_stylebox("normal", "LineEdit", _box(UI + "frame_inset.png", 2, 2, 2, 2, 3, 2, 3, 2))
	theme.set_stylebox("focus", "LineEdit", _box(UI + "frame_inset.png", 2, 2, 2, 2, 3, 2, 3, 2))
	theme.set_color("font_color", "LineEdit", IVORY)
	theme.set_color("caret_color", "LineEdit", GOLD_HL)

	var err := ResourceSaver.save(theme, OUT)
	print("theme saved: ", OUT, " err=", err)
	quit(0 if err == OK else 1)


func _box(path: String, ml: int, mt: int, mr: int, mb: int, cl: int, ct: int, cr: int, cb: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.texture_margin_left = ml
	box.texture_margin_top = mt
	box.texture_margin_right = mr
	box.texture_margin_bottom = mb
	box.content_margin_left = cl
	box.content_margin_top = ct
	box.content_margin_right = cr
	box.content_margin_bottom = cb
	return box


## 14×16 버튼 그림. 눌림 그림은 내용이 1px 아래로.
func _button_box(image: String, pressed: bool) -> StyleBoxTexture:
	return _box(UI + image + ".png", 3, 3, 3, 3, 6, 4 if pressed else 3, 6, 2 if pressed else 3)


func _button_type(type_name: String, prefix: String, normal: Color, hover: Color, pressed: Color, disabled: Color, variation: bool = false) -> void:
	if variation:
		theme.set_type_variation(type_name, "Button")
	theme.set_stylebox("normal", type_name, _button_box(prefix + "_normal", false))
	theme.set_stylebox("hover", type_name, _button_box(prefix + "_hover", false))
	theme.set_stylebox("pressed", type_name, _button_box(prefix + "_pressed", true))
	theme.set_stylebox("hover_pressed", type_name, _button_box(prefix + "_pressed", true))
	theme.set_stylebox("disabled", type_name, _button_box(prefix + "_disabled", false))
	theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	theme.set_color("font_color", type_name, normal)
	theme.set_color("font_hover_color", type_name, hover)
	theme.set_color("font_pressed_color", type_name, pressed)
	theme.set_color("font_hover_pressed_color", type_name, pressed)
	theme.set_color("font_focus_color", type_name, normal)
	theme.set_color("font_disabled_color", type_name, disabled)
	for icon_color: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		theme.set_color(icon_color, type_name, NO_TINT)
	theme.set_color("icon_disabled_color", type_name, Color(1, 1, 1, 0.5))
	theme.set_constant("h_separation", type_name, 3)


func _label_variation(type_name: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_font("font", type_name, font)
	theme.set_font_size("font_size", type_name, size)
	theme.set_color("font_color", type_name, color)


func _panel_variation(type_name: String, box: StyleBox) -> void:
	theme.set_type_variation(type_name, "PanelContainer")
	theme.set_stylebox("panel", type_name, box)


func _empty_icon() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)
