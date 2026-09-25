class_name AchievementSlot
extends Control
## 업적 목록 화면(7단계)의 아이콘 한 칸. 달성 = 원색 아이콘, 미달성(일반) = 실루엣,
## 미달성(숨김) = icon_hidden("?"). 마우스오버 시 TooltipLayer 로 이름·설명을 보여준다
## (숨김이고 미달성이면 이름·설명도 "???").

const SIZE := Vector2(30, 30)
const ICON_DIR := "res://assets/sprites/ui/achievements/"

var _panel: PanelContainer
var _icon: TextureRect
var _id: String = ""
var _unlocked: bool = false
var _hidden: bool = false
var _name_key: String = ""
var _desc_key: String = ""


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "PanelInset"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.size = SIZE
	add_child(_panel)
	_icon = TextureRect.new()
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.size = SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	mouse_entered.connect(func() -> void: TooltipLayer.show_tip(self, _tooltip_text(), get_global_rect()))
	mouse_exited.connect(func() -> void: TooltipLayer.hide_tip(self))


func setup(def: Dictionary, unlocked: bool) -> void:
	_id = String(def.get("id", ""))
	_unlocked = unlocked
	_hidden = bool(def.get("hidden", false))
	_name_key = String(def.get("name_key", ""))
	_desc_key = String(def.get("desc_key", ""))
	var icon_id := String(def.get("icon", def.get("id", "")))
	var texture_path: String
	if _unlocked:
		texture_path = "%sicon_%s.png" % [ICON_DIR, icon_id]
		modulate = Color.WHITE
	elif _hidden:
		texture_path = "%sicon_hidden.png" % ICON_DIR
		modulate = Color(1.0, 1.0, 1.0, 0.85)
	else:
		texture_path = "%sicon_%s_locked.png" % [ICON_DIR, icon_id]
		modulate = Color(1.0, 1.0, 1.0, 0.7)
	_icon.texture = load(texture_path) if ResourceLoader.exists(texture_path) else null


func _tooltip_text() -> String:
	if _hidden and not _unlocked:
		return "%s\n%s" % [tr("ACH_HIDDEN_NAME"), tr("ACH_HIDDEN_DESC")]
	return "%s\n%s" % [tr(_name_key), tr(_desc_key)]
