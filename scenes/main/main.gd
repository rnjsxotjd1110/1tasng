class_name Main
extends Control
## 메인 화면. 레이아웃은 ART_BIBLE 1장.
##   World(흔들림 대상): 배경 · 룰렛 휠
##   UI 레이어: 상단 바 · 기록 패널 · 오른쪽 패널(베팅창 ↔ 업그레이드) · 휠 아래 버튼 · 결과 배지
##   FX 레이어: 떠오르는 텍스트 · 파티클 · 날아가는 칩 · BIG WIN 배너 · 플래시 · JACKPOT · 오버레이 · 토스트 · 툴팁
## 흐름: SPIN → SpinController.start_spin() → EventBus.spin_started → 휠 연출 → finish_spin() → EventBus.spin_resolved → 연출

const WHEEL_CENTER := Vector2(262, 192)
const HISTORY_POS := Vector2(4, 28)
const RIGHT_PANEL_POS := Vector2(420, 28)
const RIGHT_PANEL_SIZE := Vector2(216, 328)
const SPIN_AREA_POS := Vector2(104, 316)
const SETTINGS_SIZE := Vector2(240, 150)
const TEXT_ANCHOR := Vector2(262, 150)
const NEAR_MISS_OFFSET := Vector2(0, 16)
const GOLDEN_TEXT_OFFSET := Vector2(0, -14)
const WHEEL_CLICK_RADIUS := 118.0

## 등급별 날아가는 칩 개수.
const CHIP_FLIGHTS := {
	SpinOutcome.Tier.NORMAL: 5,
	SpinOutcome.Tier.GOOD: 10,
	SpinOutcome.Tier.BIG: 16,
	SpinOutcome.Tier.JACKPOT: 24,
}
const GOOD_PARTICLES := 20
const BIG_COINS := 60
const GOOD_SHAKE := 1
const GOOD_SHAKE_TIME := 0.15
const BIG_SHAKE := 2
const BIG_SHAKE_TIME := 0.3
const JACKPOT_SHAKE := 3
const JACKPOT_SHAKE_TIME := 0.4
const NORMAL_SPARKLE := 6

const TopBarScene := preload("res://scenes/ui/TopBar.tscn")
const HistoryPanelScene := preload("res://scenes/ui/HistoryPanel.tscn")
const BetPanelScene := preload("res://scenes/ui/BetPanel.tscn")
const SpinControlsScene := preload("res://scenes/ui/SpinControls.tscn")
const WheelScene := preload("res://scenes/roulette/RouletteWheel.tscn")
const BackgroundScene := preload("res://scenes/main/bg/BackgroundB1.tscn")
const ResultBadgeScene := preload("res://scenes/fx/ResultBadge.tscn")
const BigWinScene := preload("res://scenes/fx/BigWinBanner.tscn")
const JackpotScene := preload("res://scenes/fx/JackpotOverlay.tscn")
const FlyingChipsScene := preload("res://scenes/fx/FlyingChips.tscn")
const FlashScene := preload("res://scenes/fx/ScreenFlash.tscn")
const ToastScene := preload("res://scenes/fx/ToastLayer.tscn")

var controller := SpinController.new()
## 6단계 자동 스핀. 지금은 항상 false(잭팟 자동 닫힘 훅).
var auto_spin: bool = false

var world: Node2D
var background: Node2D
var wheel: RouletteWheel
var ui_layer: CanvasLayer
var fx_layer: CanvasLayer
var top_bar: TopBar
var history_panel: HistoryPanel
var bet_panel: BetPanel
var upgrade_panel: PlaceholderScreen
var spin_controls: SpinControls
var result_badge: ResultBadge
var float_layer: Control
var flying_chips: FlyingChips
var big_win: BigWinBanner
var flash: ScreenFlash
var jackpot: JackpotOverlay
var skill_overlay: PlaceholderScreen
var settings_overlay: PlaceholderScreen
var toasts: ToastLayer
var tooltip_layer: TooltipLayer
var shaker: ScreenShake

var current_tab: String = TopBar.TAB_BET
var _payout_batch: int = -1
var _payout_step: float = 0.0
var _last_affordable: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	controller.instant_resolve = false
	_build_world()
	_build_ui()
	_build_fx()
	EventBus.spin_started.connect(_on_spin_started)
	EventBus.spin_resolved.connect(_on_spin_resolved)
	EventBus.bets_changed.connect(_refresh_spin_state)
	EventBus.chips_changed.connect(func(_v: float, _d: float) -> void: _refresh_spin_state())
	EventBus.milestone_reached.connect(_on_milestone)
	wheel.spin_finished.connect(_on_wheel_finished)
	_refresh_spin_state()


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	background = BackgroundScene.instantiate()
	world.add_child(background)
	wheel = WheelScene.instantiate()
	wheel.position = WHEEL_CENTER
	world.add_child(wheel)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 1
	add_child(ui_layer)
	var root := _layer_root(ui_layer)
	top_bar = TopBarScene.instantiate()
	root.add_child(top_bar)
	top_bar.tab_pressed.connect(_on_tab_pressed)
	history_panel = HistoryPanelScene.instantiate()
	history_panel.position = HISTORY_POS
	root.add_child(history_panel)
	bet_panel = BetPanelScene.instantiate()
	bet_panel.position = RIGHT_PANEL_POS
	root.add_child(bet_panel)
	bet_panel.board.wheel_center_global = WHEEL_CENTER
	upgrade_panel = PlaceholderScreen.new()
	upgrade_panel.setup(RIGHT_PANEL_SIZE, "UPGRADE_PANEL_TITLE", false)
	upgrade_panel.position = RIGHT_PANEL_POS
	upgrade_panel.visible = false
	root.add_child(upgrade_panel)
	spin_controls = SpinControlsScene.instantiate()
	spin_controls.position = SPIN_AREA_POS
	root.add_child(spin_controls)
	spin_controls.spin_pressed.connect(request_spin)
	result_badge = ResultBadgeScene.instantiate()
	root.add_child(result_badge)


func _build_fx() -> void:
	fx_layer = CanvasLayer.new()
	fx_layer.name = "Fx"
	fx_layer.layer = 2
	add_child(fx_layer)
	var root := _layer_root(fx_layer)
	float_layer = Control.new()
	float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_layer.size = Vector2(640, 360)
	root.add_child(float_layer)
	flying_chips = FlyingChipsScene.instantiate()
	root.add_child(flying_chips)
	flying_chips.arrived.connect(_on_chip_arrived)
	flying_chips.finished.connect(_on_chips_finished)
	big_win = BigWinScene.instantiate()
	root.add_child(big_win)
	flash = FlashScene.instantiate()
	root.add_child(flash)
	toasts = ToastScene.instantiate()
	root.add_child(toasts)
	jackpot = JackpotScene.instantiate()
	root.add_child(jackpot)
	skill_overlay = PlaceholderScreen.new()
	skill_overlay.setup(Vector2(640, 336), "SKILLTREE_TITLE", true, "PanelPlain")
	skill_overlay.position = Vector2(0, 24)
	skill_overlay.visible = false
	skill_overlay.close_requested.connect(func() -> void: _close_overlay(skill_overlay))
	root.add_child(skill_overlay)
	settings_overlay = PlaceholderScreen.new()
	settings_overlay.setup(SETTINGS_SIZE, "SETTINGS_TITLE", true)
	settings_overlay.position = ((Vector2(640, 360) - SETTINGS_SIZE) * 0.5).round()
	settings_overlay.visible = false
	settings_overlay.close_requested.connect(func() -> void: _close_overlay(settings_overlay))
	root.add_child(settings_overlay)
	tooltip_layer = TooltipLayer.new()
	root.add_child(tooltip_layer)
	shaker = ScreenShake.new()
	shaker.targets = [world, ui_layer]
	add_child(shaker)


func _layer_root(layer: CanvasLayer) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(640, 360)
	layer.add_child(root)
	return root


# ── 스핀 ─────────────────────────────────────────────────

## SPIN 버튼·Space. 스핀 중이면 남은 연출을 감는다(스킵). 연출 중에도 다음 스핀을 바로 시작할 수 있다.
func request_spin() -> void:
	if jackpot.is_open:
		return
	if wheel.spinning:
		wheel.skip()
		return
	if GameState.current_bets.is_empty():
		bet_panel.board.hint_no_bets()
		return
	var error := controller.start_spin()
	match error:
		SpinController.SpinError.NOT_ENOUGH_CHIPS:
			top_bar.shake_chips()
		SpinController.SpinError.OK:
			pass
		_:
			AudioManager.play_sfx("deny")


func _on_spin_started(results: Array[int], duration: float) -> void:
	result_badge.hide_badge()
	bet_panel.set_locked(true)
	spin_controls.ready_to_spin = false
	wheel.play_spin(results, duration)
	_refresh_spin_state()


func _on_wheel_finished() -> void:
	if controller.state == SpinController.State.SPINNING:
		controller.finish_spin()


func _on_spin_resolved(outcome: SpinOutcome) -> void:
	bet_panel.set_locked(false)
	spin_controls.ready_to_spin = true
	wheel.flash_result(outcome.results, outcome.golden_hit)
	result_badge.show_results(outcome.results)
	var winners := bet_panel.board.show_outcome(outcome)
	play_tier_effects(outcome, winners)
	_refresh_spin_state()


## 등급별 당첨 연출(ART_BIBLE 7장).
func play_tier_effects(outcome: SpinOutcome, winners: Array[String]) -> void:
	var anchor := TEXT_ANCHOR
	if outcome.golden_hit:
		for number in outcome.results:
			FloatingText.spawn(float_layer, "×%s" % NumberFormat.format(Economy.GOLDEN_POCKET_MULT), "Num14Gold",
				wheel.pocket_global_position(number) + GOLDEN_TEXT_OFFSET)
	if outcome.tier == SpinOutcome.Tier.LOSS:
		FloatingText.spawn(float_layer, NumberFormat.format(outcome.net), "Num14Stone", anchor)
		if outcome.near_miss:
			FloatingText.spawn(float_layer, tr("NEAR_MISS"), "LabelBold", anchor + NEAR_MISS_OFFSET)
			AudioManager.play_sfx("near_miss")
		else:
			AudioManager.play_sfx("lose")
		return
	FloatingText.spawn(float_layer, NumberFormat.format_signed(outcome.net), "Num14Gold", anchor)
	_fly_payout(outcome, winners)
	match outcome.tier:
		SpinOutcome.Tier.NORMAL:
			ParticleBurst.spawn(float_layer, ParticleBurst.Kind.CHIPS, anchor, NORMAL_SPARKLE)
			AudioManager.play_sfx("win_normal")
		SpinOutcome.Tier.GOOD:
			ParticleBurst.spawn(float_layer, ParticleBurst.Kind.CHIPS, anchor, GOOD_PARTICLES)
			shaker.shake(GOOD_SHAKE, GOOD_SHAKE_TIME)
			AudioManager.play_sfx("win_good")
		SpinOutcome.Tier.BIG:
			_big_effects(outcome)
			AudioManager.play_sfx("win_big")
		SpinOutcome.Tier.JACKPOT:
			_big_effects(outcome, false)
			shaker.shake(JACKPOT_SHAKE, JACKPOT_SHAKE_TIME)
			jackpot.open(outcome.net, auto_spin)


func _big_effects(outcome: SpinOutcome, banner: bool = true) -> void:
	if banner:
		big_win.play()
	flash.flash()
	ParticleBurst.spawn(float_layer, ParticleBurst.Kind.COINS, WHEEL_CENTER, BIG_COINS)
	shaker.shake(BIG_SHAKE, BIG_SHAKE_TIME)
	if not outcome.hit_straights.is_empty():
		var sources: Array[Vector2] = []
		for number in outcome.results:
			sources.append(wheel.pocket_global_position(number))
		flying_chips.launch(sources, top_bar.clover_target(), outcome.hit_straights.size(), FlyingChips.Icon.CLOVER)
		AudioManager.play_sfx("clover_get")


func _fly_payout(outcome: SpinOutcome, winners: Array[String]) -> void:
	var count: int = CHIP_FLIGHTS.get(outcome.tier, CHIP_FLIGHTS[SpinOutcome.Tier.NORMAL])
	var sources: Array[Vector2] = []
	for key in winners:
		sources.append(bet_panel.board.spot_global_rect(key).get_center())
	if sources.is_empty():
		sources.append(WHEEL_CENTER)
	top_bar.hold_payout()
	_payout_step = outcome.total_return / count
	_payout_batch = flying_chips.launch(sources, top_bar.chip_target(), count)


func _on_chip_arrived(batch_id: int, _index: int, _count: int) -> void:
	if batch_id == _payout_batch:
		top_bar.add_payout_step(_payout_step)
		AudioManager.play_sfx("chip_click")


func _on_chips_finished(batch_id: int) -> void:
	if batch_id == _payout_batch:
		_payout_batch = -1
		top_bar.release_payout()


func _on_milestone(suffix_index: int) -> void:
	var suffix: String = NumberFormat.SUFFIXES[suffix_index] if suffix_index < NumberFormat.SUFFIXES.size() else "?"
	EventBus.toast_requested.emit(tr("MILESTONE_REACHED") % suffix + "  " + tr("TOAST_CLOVERS") % Economy.CLOVER_PER_MILESTONE, "clover")


func _refresh_spin_state() -> void:
	var affordable := bet_panel.is_affordable()
	var idle := controller.is_idle() and not wheel.spinning
	spin_controls.set_spin_enabled(affordable or not idle)
	if _last_affordable and not affordable and idle and not GameState.current_bets.is_empty():
		top_bar.shake_chips()
	_last_affordable = affordable


# ── 탭·오버레이 ─────────────────────────────────────────

func _on_tab_pressed(tab_id: String) -> void:
	match tab_id:
		TopBar.TAB_BET, TopBar.TAB_UPGRADE:
			switch_panel(tab_id)
		TopBar.TAB_SKILLS:
			_toggle_overlay(skill_overlay)
		TopBar.TAB_SETTINGS:
			_toggle_overlay(settings_overlay)


## 오른쪽 패널 전환(베팅창 ↔ 업그레이드).
func switch_panel(tab_id: String) -> void:
	if tab_id == current_tab:
		return
	var from: Control = bet_panel if current_tab == TopBar.TAB_BET else upgrade_panel
	var to: Control = bet_panel if tab_id == TopBar.TAB_BET else upgrade_panel
	current_tab = tab_id
	top_bar.select_tab(tab_id)
	TooltipLayer.hide_tip(bet_panel.board)
	PanelTransition.close(from, Vector2(8, 0), false)
	PanelTransition.open(to, Vector2(-8, 0))


func _toggle_overlay(overlay: Control) -> void:
	if overlay.visible:
		_close_overlay(overlay)
	else:
		for other: Control in [skill_overlay, settings_overlay]:
			if other != overlay and other.visible:
				_close_overlay(other)
		PanelTransition.open(overlay)


func _close_overlay(overlay: Control) -> void:
	if overlay.visible:
		PanelTransition.close(overlay)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spin"):
		if jackpot.is_open:
			jackpot.close()
		else:
			request_spin()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_panel"):
		switch_panel(TopBar.TAB_UPGRADE if current_tab == TopBar.TAB_BET else TopBar.TAB_BET)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_skilltree"):
		_toggle_overlay(skill_overlay)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if skill_overlay.visible:
			_close_overlay(skill_overlay)
		else:
			_toggle_overlay(settings_overlay)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_auto"):
		spin_controls.auto_button.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT and wheel.spinning:
			if button.position.distance_to(WHEEL_CENTER) <= WHEEL_CLICK_RADIUS:
				wheel.skip()
				get_viewport().set_input_as_handled()
