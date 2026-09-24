class_name TooltipLayer
extends Control
## 게임 전용 툴팁(테마 TooltipPanel·TooltipLabel). 어느 위젯이든 TooltipLayer.show_tip() 으로 띄운다.
## 기준 사각형(전역 좌표) 위에 가운데 정렬로 띄우고, 화면 밖으로 나가지 않게 정수 픽셀로 맞춘다.

const FADE := 0.1
const GAP := 3
const SCREEN := Vector2(640, 360)
const MARGIN := 2

static var instance: TooltipLayer = null

var _panel: PanelContainer
var _label: Label
var _tween: Tween
var _owner_id: int = 0


func _ready() -> void:
	instance = self
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "TooltipPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_label = Label.new()
	_label.theme_type_variation = "TooltipLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func show_tip(owner: Object, text: String, anchor: Rect2, below: bool = false) -> void:
	if instance != null:
		instance._show(owner, text, anchor, below)


static func hide_tip(owner: Object) -> void:
	if instance != null:
		instance._hide(owner)


func current_text() -> String:
	return _label.text if _panel.visible else ""


func _show(owner: Object, text: String, anchor: Rect2, below: bool) -> void:
	var owner_id := owner.get_instance_id() if owner != null else 0
	var was_visible := _panel.visible and _owner_id == owner_id
	_owner_id = owner_id
	_label.text = text
	_panel.reset_size()
	var tip_size := _panel.get_combined_minimum_size()
	_panel.size = tip_size
	var x := anchor.position.x + anchor.size.x * 0.5 - tip_size.x * 0.5
	var y := anchor.end.y + GAP if below else anchor.position.y - tip_size.y - GAP
	if not below and y < MARGIN:
		y = anchor.end.y + GAP
	x = clampf(x, MARGIN, SCREEN.x - tip_size.x - MARGIN)
	y = clampf(y, MARGIN, SCREEN.y - tip_size.y - MARGIN)
	_panel.position = Vector2(x, y).round()
	if was_visible:
		return
	_panel.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE)


func _hide(owner: Object) -> void:
	var owner_id := owner.get_instance_id() if owner != null else 0
	if owner_id != _owner_id or not _panel.visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE)
	_tween.tween_callback(func() -> void: _panel.visible = false)
