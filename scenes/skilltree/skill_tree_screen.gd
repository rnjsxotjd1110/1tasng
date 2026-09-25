class_name SkillTreeScreen
extends Control
## 스킬트리 전체 화면(6단계, GDD 6-2). SkillTreeView(그래프)를 감싸 헤더·클로버 표시·
## 툴팁·구석 미니 알림을 더하고, 0.3초 아이리스 와이프로 열고 닫는다(CanvasGroup + iris_wipe 셰이더).
## 뒤에서 룰렛·오토 스핀은 계속 진행되며(Main 이 멈추지 않는다), 그 결과는 구석에 작게만 보여준다.

signal close_requested()

const SIZE := Vector2(640, 336)
const HEADER_HEIGHT := 24
const OPEN_CLOSE_TIME := 0.3
const MINI_NOTIFY_POS := Vector2(SIZE.x - 30, HEADER_HEIGHT + 14)
const TOOLTIP_GAP := 4
const IRIS_WIPE_SHADER := preload("res://assets/shaders/iris_wipe.gdshader")
const CLOSE_ICON := preload("res://assets/sprites/ui/icon_close.png")

const BRANCH_NAME_KEY := {
	SkillNodeDef.Branch.CORE: "BRANCH_CORE",
	SkillNodeDef.Branch.FORTUNE: "BRANCH_FORTUNE",
	SkillNodeDef.Branch.MACHINE: "BRANCH_MACHINE",
	SkillNodeDef.Branch.ECONOMY: "BRANCH_ECONOMY",
	SkillNodeDef.Branch.MYSTIC: "BRANCH_MYSTIC",
}

var view: SkillTreeView

var _canvas_group: CanvasGroup
var _shader: ShaderMaterial
var _held_label: CountLabel
var _invested_label: Label
var _tooltip_panel: PanelContainer
var _tooltip_label: RichTextLabel
var _mini_layer: Control
var _tween: Tween


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_group = CanvasGroup.new()
	add_child(_canvas_group)
	_shader = ShaderMaterial.new()
	_shader.shader = IRIS_WIPE_SHADER
	_shader.set_shader_parameter("aspect_ratio", SIZE.x / SIZE.y)
	_shader.set_shader_parameter("progress", 1.0)
	_canvas_group.material = _shader
	view = SkillTreeView.new()
	view.position = Vector2(0, HEADER_HEIGHT)
	_canvas_group.add_child(view)
	view.node_hovered.connect(_on_node_hovered)
	view.node_unhovered.connect(_on_node_unhovered)
	view.purchased.connect(_on_purchased)
	_build_header()
	_mini_layer = Control.new()
	_mini_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_layer.size = SIZE
	_canvas_group.add_child(_mini_layer)
	_build_tooltip()
	EventBus.spin_resolved.connect(_on_spin_resolved)
	EventBus.clovers_changed.connect(func(_v: int, _d: int) -> void: _refresh_header())


func _build_header() -> void:
	var bar := Panel.new()
	bar.theme_type_variation = "PanelBar"
	bar.size = Vector2(SIZE.x, HEADER_HEIGHT)
	_canvas_group.add_child(bar)
	var title := Label.new()
	title.text = "SKILLTREE_TITLE"
	title.theme_type_variation = "LabelBold"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 5)
	title.size = Vector2(SIZE.x, 14)
	_canvas_group.add_child(title)
	var center_button := Button.new()
	center_button.theme_type_variation = "ButtonDark"
	center_button.text = "BUTTON_CENTER"
	center_button.focus_mode = Control.FOCUS_NONE
	center_button.custom_minimum_size = Vector2(0, 18)
	center_button.position = Vector2(6, 3)
	center_button.pressed.connect(func() -> void: view.recenter())
	_canvas_group.add_child(center_button)
	var close_button := Button.new()
	close_button.theme_type_variation = "ButtonDark"
	close_button.icon = CLOSE_ICON
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size = Vector2(18, 18)
	close_button.position = Vector2(SIZE.x - 24, 3)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	_canvas_group.add_child(close_button)
	var clover_icon := TextureRect.new()
	clover_icon.texture = preload("res://assets/sprites/ui/icon_clover.png")
	clover_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	clover_icon.position = Vector2(SIZE.x * 0.5 + 40, 3)
	clover_icon.size = Vector2(11, 18)
	_canvas_group.add_child(clover_icon)
	_held_label = CountLabel.new()
	_held_label.theme_type_variation = "Num14Clover"
	_held_label.position = Vector2(SIZE.x * 0.5 + 52, 2)
	_canvas_group.add_child(_held_label)
	_invested_label = Label.new()
	_invested_label.theme_type_variation = "LabelMuted"
	_invested_label.position = Vector2(SIZE.x * 0.5 + 52, 14)
	_invested_label.size = Vector2(90, 10)
	_canvas_group.add_child(_invested_label)
	_held_label.set_value(GameState.clovers, 0.0)
	_refresh_header()


func _build_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.theme_type_variation = "TooltipPanel"
	_tooltip_panel.custom_minimum_size = Vector2(150, 0)
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 10
	add_child(_tooltip_panel)
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.theme_type_variation = "TooltipLabel"
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.custom_minimum_size = Vector2(150, 0)
	_tooltip_label.scroll_active = false
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(_tooltip_label)


func _refresh_header() -> void:
	if _held_label == null:
		return
	_held_label.set_value(GameState.clovers)
	_invested_label.text = tr("SKILLTREE_INVESTED") % [NumberFormat.format(SkillService.invested_total()), NumberFormat.format(SkillService.grand_total())]


# ── 열기·닫기(아이리스 와이프) ─────────────────────────────

func open() -> void:
	visible = true
	AudioManager.play_sfx("panel_open")
	_refresh_header()
	_run_wipe(0.0, 1.0)


func close() -> void:
	AudioManager.play_sfx("panel_close")
	_on_node_unhovered()
	var tween := _run_wipe(1.0, 0.0)
	tween.tween_callback(func() -> void:
		visible = false
		view.focus_release())


func _run_wipe(from: float, to: float) -> Tween:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_shader.set_shader_parameter("progress", from)
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: _shader.set_shader_parameter("progress", v), from, to, OPEN_CLOSE_TIME)
	return _tween


# ── 툴팁 ─────────────────────────────────────────────────

func _on_node_hovered(id: String, rect: Rect2) -> void:
	var def := GameData.skill(id)
	if def == null:
		return
	_tooltip_label.text = _tooltip_bbcode(def)
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()
	var above := rect.position.y - global_position.y - _tooltip_panel.size.y - TOOLTIP_GAP >= HEADER_HEIGHT
	var pos := Vector2(
		clampf(rect.get_center().x - global_position.x - _tooltip_panel.size.x * 0.5, 2.0, SIZE.x - _tooltip_panel.size.x - 2.0),
		rect.position.y - global_position.y - _tooltip_panel.size.y - TOOLTIP_GAP if above else rect.position.y - global_position.y + rect.size.y + TOOLTIP_GAP)
	_tooltip_panel.position = pos.round()


func _on_node_unhovered() -> void:
	_tooltip_panel.visible = false


func _tooltip_bbcode(def: SkillNodeDef) -> String:
	var lvl := SkillService.level(def.id)
	var maxed := SkillService.is_maxed(def)
	var locked := not SkillService.prerequisites_met(def)
	var lines: Array[String] = []
	var branch_color := SkillTreeView.BRANCH_COLOR.get(def.branch, Palette.MIST) as Color
	var branch_text := tr(BRANCH_NAME_KEY.get(def.branch, "BRANCH_CORE"))
	lines.append("[b]%s[/b]  [color=#%s]%s[/color] · Lv %d/%d" % [tr(def.name_key), branch_color.to_html(false), branch_text, lvl, def.max_level()])
	lines.append(tr(def.desc_key))
	if not def.is_heart():
		if not maxed:
			var effect_line := _effect_delta_text(def, lvl)
			if effect_line != "":
				lines.append("[color=#%s]%s[/color]" % [Palette.CLOVER.to_html(false), effect_line])
			lines.append(tr("TIP_SKILL_COST") % NumberFormat.format(SkillService.cost_for_next(def)))
		else:
			lines.append(tr("TIP_MAX_LEVEL"))
		if locked:
			var names: Array[String] = []
			for prereq_id in def.prerequisites:
				var prereq_def := GameData.skill(prereq_id)
				names.append(tr(prereq_def.name_key) if prereq_def != null else prereq_id)
			var joiner := " %s " % tr("PREREQ_OR") if def.prerequisite_mode == SkillNodeDef.PrereqMode.ANY else " %s " % tr("PREREQ_AND")
			lines.append("[color=#%s]%s[/color]" % [Palette.SEM_WARNING.to_html(false), tr("TIP_SKILL_LOCKED") % joiner.join(names)])
	return "\n".join(lines)


## 다음 레벨로 오를 때 각 효과 값이 어떻게 바뀌는지("현재 → 다음"). 효과가 여럿이면 줄바꿈으로 잇는다.
func _effect_delta_text(def: SkillNodeDef, lvl: int) -> String:
	var parts: Array[String] = []
	for effect: Dictionary in def.effects:
		var now_value := def.effect_value(effect, lvl)
		var next_value := def.effect_value(effect, lvl + 1)
		var stat_label := String(effect.get("stat", "")).capitalize()
		parts.append("%s %s → %s" % [stat_label, _fmt_effect(now_value), _fmt_effect(next_value)])
	return "\n".join(parts)


func _fmt_effect(value: float) -> String:
	return String.num(value, 1) if absf(value) < 10.0 else String.num(value, 0)


func _on_purchased(_id: String, _new_level: int) -> void:
	_refresh_header()


# ── 구석 미니 알림(뒤에서 계속되는 스핀 결과) ────────────────

func _on_spin_resolved(outcome: SpinOutcome) -> void:
	if not visible:
		return
	var variation := "Num7Gold" if outcome.net > 0.0 else "Num7Stone"
	FloatingText.spawn(_mini_layer, NumberFormat.format_signed(outcome.net), variation, MINI_NOTIFY_POS)


# ── 키보드·패드 노드 포커스 ─────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left"):
		view.focus_move(Vector2.LEFT)
	elif event.is_action_pressed("ui_right"):
		view.focus_move(Vector2.RIGHT)
	elif event.is_action_pressed("ui_up"):
		view.focus_move(Vector2.UP)
	elif event.is_action_pressed("ui_down"):
		view.focus_move(Vector2.DOWN)
	elif event.is_action_pressed("ui_accept"):
		view.focus_activate()
	elif event.is_action_released("ui_accept"):
		view.focus_release()
	else:
		return
	get_viewport().set_input_as_handled()
