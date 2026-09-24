class_name Main
extends Control
## 메인 화면. 레이아웃은 ART_BIBLE 1장.
##   World(흔들림 대상): 배경 · 룰렛 휠
##   UI 레이어: 상단 바 · 기록 패널 · 오른쪽 패널(베팅창 ↔ 업그레이드, 0.18초 슬라이드) · 휠 아래 버튼 · 결과 배지
##   FX 레이어: 떠오르는 텍스트 · 파티클 · 날아가는 칩 · BIG WIN 배너 · 플래시 · JACKPOT · 구슬 승급 · 오버레이 · 토스트 · 툴팁
##   개발 빌드에서만: F9 디버그 패널(scenes/debug/, 동적 로드)
## 흐름: SPIN → SpinController.start_spin() → EventBus.spin_started → 휠 연출 → finish_spin() → EventBus.spin_resolved → 연출

const WHEEL_CENTER := Vector2(262, 192)
const HISTORY_POS := Vector2(4, 28)
const RIGHT_PANEL_POS := Vector2(420, 28)
const RIGHT_PANEL_SIZE := Vector2(216, 328)
const SPIN_AREA_POS := Vector2(104, 316)
## 스킬트리·설정·통계처럼 상단 바 아래 전체를 덮는 오버레이의 공통 위치(640×336).
const FULL_OVERLAY_POS := Vector2(0, 24)
const TEXT_ANCHOR := Vector2(262, 150)
const NEAR_MISS_OFFSET := Vector2(0, 16)
const WHEEL_CLICK_RADIUS := 118.0
## 오른쪽 패널 전환(ART_BIBLE 6장 0.18초): 현재 패널이 밀려나고 새 패널이 들어온다(정수 픽셀).
const PANEL_SLIDE_TIME := 0.18
const GOLDEN_BADGE_Y := 72.0
const GOLDEN_PARTICLES := 26
const DEBUG_PANEL_PATH := "res://scenes/debug/debug_panel.gd"

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

var world: Node2D
var background: Node2D
var wheel: RouletteWheel
var ui_layer: CanvasLayer
var fx_layer: CanvasLayer
var top_bar: TopBar
var history_panel: HistoryPanel
var bet_panel: BetPanel
var right_clip: Control
var upgrade_panel: UpgradePanel
var promotion: MarblePromotion
var golden_badge: GoldenBadge
var spin_controls: SpinControls
var result_badge: ResultBadge
var float_layer: Control
var flying_chips: FlyingChips
var big_win: BigWinBanner
var flash: ScreenFlash
var jackpot: JackpotOverlay
var skill_overlay: PlaceholderScreen
var settings_overlay: SettingsScreen
var stats_screen: StatsScreen
var pause_menu: PauseMenu
var return_popup: ReturnPopup
var toasts: ToastLayer
var tooltip_layer: TooltipLayer
var shaker: ScreenShake

var current_tab: String = TopBar.TAB_BET
var _payout_batch: int = -1
var _payout_step: float = 0.0
var _last_affordable: bool = true
var _slide_tween: Tween
var _slide_from: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	controller.instant_resolve = false
	_load_game()
	_build_world()
	_build_ui()
	_build_fx()
	EventBus.spin_started.connect(_on_spin_started)
	EventBus.spin_resolved.connect(_on_spin_resolved)
	EventBus.bets_changed.connect(_refresh_spin_state)
	EventBus.chips_changed.connect(func(_v: float, _d: float) -> void: _refresh_spin_state())
	EventBus.milestone_reached.connect(_on_milestone)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.golden_pockets_added.connect(_on_golden_pockets_added)
	wheel.spin_finished.connect(_on_wheel_finished)
	_refresh_spin_state()
	_attach_debug_panel()
	_show_return_popup_if_needed()


## 저장 불러오기(있으면). 스핀 도중 저장된 것이 있으면 연출 없이 즉시 정산한다. UI 를 만들기 전에 해서
## 처음 그려지는 화면이 이미 불러온 값을 보여주게 한다.
func _load_game() -> void:
	SaveManager.load_game()
	controller.settle_pending_spin()


func _show_return_popup_if_needed() -> void:
	var offline := SaveManager.last_load_offline
	if offline == null or not offline.eligible:
		return
	return_popup.position = ((Vector2(640, 360) - ReturnPopup.SIZE) * 0.5).round()
	return_popup.open(offline)


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
	# 오른쪽 패널 둘은 같은 자리(right_clip)에 겹쳐 두고, 전환하는 동안만 잘라 낸다
	right_clip = Control.new()
	right_clip.name = "RightPanel"
	right_clip.position = RIGHT_PANEL_POS
	right_clip.size = RIGHT_PANEL_SIZE
	right_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right_clip)
	bet_panel = BetPanelScene.instantiate()
	right_clip.add_child(bet_panel)
	bet_panel.board.wheel_center_global = WHEEL_CENTER
	upgrade_panel = UpgradePanel.new()
	upgrade_panel.visible = false
	right_clip.add_child(upgrade_panel)
	spin_controls = SpinControlsScene.instantiate()
	spin_controls.position = SPIN_AREA_POS
	root.add_child(spin_controls)
	spin_controls.spin_pressed.connect(request_spin)
	result_badge = ResultBadgeScene.instantiate()
	root.add_child(result_badge)
	golden_badge = GoldenBadge.new()
	golden_badge.center = Vector2(WHEEL_CENTER.x, GOLDEN_BADGE_Y)
	root.add_child(golden_badge)


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
	promotion = MarblePromotion.new()
	promotion.target_provider = _promotion_target
	promotion.arrived.connect(_on_promotion_arrived)
	root.add_child(promotion)
	skill_overlay = PlaceholderScreen.new()
	skill_overlay.setup(Vector2(640, 336), "SKILLTREE_TITLE", true, "PanelPlain")
	skill_overlay.position = FULL_OVERLAY_POS
	skill_overlay.visible = false
	skill_overlay.close_requested.connect(func() -> void: _close_overlay(skill_overlay))
	root.add_child(skill_overlay)
	settings_overlay = SettingsScreen.new()
	settings_overlay.position = FULL_OVERLAY_POS
	settings_overlay.visible = false
	settings_overlay.close_requested.connect(func() -> void: _close_overlay(settings_overlay))
	root.add_child(settings_overlay)
	stats_screen = StatsScreen.new()
	stats_screen.position = FULL_OVERLAY_POS
	stats_screen.visible = false
	stats_screen.close_requested.connect(_close_stats_screen)
	root.add_child(stats_screen)
	return_popup = ReturnPopup.new()
	return_popup.visible = false
	return_popup.claimed.connect(func() -> void: EventBus.toast_requested.emit(tr("TOAST_OFFLINE_CLAIMED"), "chip"))
	root.add_child(return_popup)
	tooltip_layer = TooltipLayer.new()
	root.add_child(tooltip_layer)
	pause_menu = PauseMenu.new()
	pause_menu.visible = false
	pause_menu.resume_requested.connect(_close_pause_menu)
	pause_menu.settings_requested.connect(func() -> void:
		_close_pause_menu()
		_toggle_overlay(settings_overlay))
	pause_menu.stats_requested.connect(func() -> void:
		_close_pause_menu()
		_open_stats_screen())
	root.add_child(pause_menu)
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
	golden_badge.hide_badge()
	bet_panel.set_locked(true)
	spin_controls.ready_to_spin = false
	# "스핀 연출 속도" 설정은 연출(휠 애니메이션)만 빠르게 한다. GameState.spin_duration() 자체(경제 공식)는 그대로.
	wheel.play_spin(results, duration * SettingsManager.spin_visual_speed_mult())
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


## 등급별 당첨 연출(ART_BIBLE 7장). full 이 false 면(오토 스핀 중 BIG 미만, 또는 "간략" 설정) 파티클·배너·
## 플래시·흔들림을 생략하고 떠오르는 텍스트·소리만 남긴다(VisualSettings.full_effects).
func play_tier_effects(outcome: SpinOutcome, winners: Array[String]) -> void:
	var anchor := TEXT_ANCHOR
	var full := VisualSettings.full_effects(outcome.tier, GameState.auto_spin_enabled)
	if outcome.golden_hit:
		# 황금 포켓 적중: "황금 ×3" 배지 + 결과 포켓에서 금색 파티클
		golden_badge.show_badge(GameState.get_stat(StatModifiers.GOLDEN_POCKET_MULT, Economy.GOLDEN_POCKET_MULT))
		if full:
			for number in outcome.results:
				if GameState.golden_pockets.has(number):
					ParticleBurst.spawn(float_layer, ParticleBurst.Kind.COINS, wheel.pocket_global_position(number), GOLDEN_PARTICLES)
		AudioManager.play_sfx("golden_beam", 1.2, -6.0)
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
			if full:
				ParticleBurst.spawn(float_layer, ParticleBurst.Kind.CHIPS, anchor, NORMAL_SPARKLE)
			AudioManager.play_sfx("win_normal")
		SpinOutcome.Tier.GOOD:
			if full:
				ParticleBurst.spawn(float_layer, ParticleBurst.Kind.CHIPS, anchor, GOOD_PARTICLES)
				shaker.shake(GOOD_SHAKE, GOOD_SHAKE_TIME)
			AudioManager.play_sfx("win_good")
		SpinOutcome.Tier.BIG:
			_big_effects(outcome, full)
			AudioManager.play_sfx("win_big")
		SpinOutcome.Tier.JACKPOT:
			_big_effects(outcome, full, false)
			if full:
				shaker.shake(JACKPOT_SHAKE, JACKPOT_SHAKE_TIME)
			jackpot.open(outcome.net, GameState.auto_spin_enabled)


func _big_effects(outcome: SpinOutcome, full: bool, banner: bool = true) -> void:
	if full:
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
	EventBus.toast_requested.emit(tr("MILESTONE_REACHED") % suffix + "  " + tr("TOAST_CLOVERS") % NumberFormat.format(Economy.CLOVER_PER_MILESTONE), "clover")


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


## 오른쪽 패널 전환(베팅창 ↔ 업그레이드). 0.18초 동안 현재 패널이 밀려나고 새 패널이 들어온다.
## 업그레이드는 베팅의 오른쪽에 있는 것처럼 움직인다. 룰렛·스핀은 그대로 계속된다.
func switch_panel(tab_id: String) -> void:
	if tab_id == current_tab:
		return
	var from: Control = bet_panel if current_tab == TopBar.TAB_BET else upgrade_panel
	var to: Control = bet_panel if tab_id == TopBar.TAB_BET else upgrade_panel
	var dir := -1.0 if tab_id == TopBar.TAB_UPGRADE else 1.0
	current_tab = tab_id
	top_bar.select_tab(tab_id)
	top_bar.set_upgrade_tab_open(tab_id == TopBar.TAB_UPGRADE)
	TooltipLayer.hide_tip(bet_panel.board)
	_finish_slide()
	_slide_from = from
	right_clip.clip_contents = true
	to.visible = true
	var width := RIGHT_PANEL_SIZE.x
	AudioManager.play_sfx("panel_open")
	_slide_tween = create_tween()
	_slide_tween.tween_method(func(u: float) -> void:
		from.position.x = roundf(dir * width * u)
		to.position.x = roundf(-dir * width * (1.0 - u)), 0.0, 1.0, PANEL_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_callback(_finish_slide)


## 진행 중인 전환을 끝 상태로 맞춘다.
func _finish_slide() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = null
	if _slide_from != null:
		_slide_from.visible = false
	_slide_from = null
	bet_panel.position = Vector2.ZERO
	upgrade_panel.position = Vector2.ZERO
	right_clip.clip_contents = false


func is_sliding() -> bool:
	return _slide_tween != null


# ── 업그레이드 연출 ─────────────────────────────────────

func _on_upgrade_purchased(id: String, level: int) -> void:
	match id:
		GameState.UPGRADE_MARBLE_TIER:
			var from_tier := promotion.pending_target() if promotion.is_playing() else MarbleSprite.shared_tier()
			if level > from_tier:
				promotion.play(from_tier, level)
			else:
				_on_promotion_arrived(level)
		"marble_count":
			EventBus.toast_requested.emit(tr("TOAST_NEW_MARBLE"), "marble")
	_refresh_spin_state()


## 승급한 구슬이 날아갈 곳: 베팅창이 보이면 트레이, 아니면 재질 카드의 미리보기.
func _promotion_target() -> Vector2:
	if bet_panel.visible and not is_sliding():
		return bet_panel.board.tray_target_global()
	var marble_card := upgrade_panel.card(GameState.UPGRADE_MARBLE_TIER)
	if marble_card != null and marble_card.marble_view != null:
		return marble_card.marble_view.get_global_rect().get_center()
	return WHEEL_CENTER


## 승급 구슬이 닿았다: 모든 구슬(휠·트레이·베팅칸·카드)을 새 재질로 바꾼다.
func _on_promotion_arrived(tier: int) -> void:
	wheel.refresh_marble(tier)
	bet_panel.board.refresh_marble()
	ParticleBurst.spawn(float_layer, ParticleBurst.Kind.CHIPS, _promotion_target(), 10)
	AudioManager.play_sfx("marble_place", 1.3)


func _on_golden_pockets_added(numbers: Array[int]) -> void:
	wheel.play_golden_beam(numbers)
	for number in numbers:
		EventBus.toast_requested.emit(tr("TOAST_GOLDEN_POCKET") % NumberFormat.format(number), "chip")


func _attach_debug_panel() -> void:
	if not OS.is_debug_build() or not ResourceLoader.exists(DEBUG_PANEL_PATH):
		return
	var script: GDScript = load(DEBUG_PANEL_PATH)
	var panel: Node = script.new()
	panel.set("main", self)
	_layer_root(fx_layer).add_child(panel)


func _toggle_overlay(overlay: Control) -> void:
	if overlay.visible:
		_close_overlay(overlay)
	else:
		for other: Control in [skill_overlay, settings_overlay, stats_screen]:
			if other != overlay and other.visible:
				_close_overlay(other)
		PanelTransition.open(overlay)


func _close_overlay(overlay: Control) -> void:
	if overlay.visible:
		PanelTransition.close(overlay)


# ── 일시정지·통계(4단계) ─────────────────────────────────

func _open_pause_menu() -> void:
	for other: Control in [skill_overlay, settings_overlay, stats_screen]:
		_close_overlay(other)
	PanelTransition.open(pause_menu)
	pause_menu.refresh_time_flows_checkbox()
	pause_menu.focus_first()
	_update_pause_freeze()


func _close_pause_menu() -> void:
	if not pause_menu.visible:
		return
	PanelTransition.close(pause_menu).tween_callback(_update_pause_freeze)


func _open_stats_screen() -> void:
	stats_screen.refresh()
	for other: Control in [skill_overlay, settings_overlay]:
		_close_overlay(other)
	PanelTransition.open(stats_screen)
	_update_pause_freeze()


func _close_stats_screen() -> void:
	if not stats_screen.visible:
		return
	PanelTransition.close(stats_screen).tween_callback(_update_pause_freeze)


## 일시정지 메뉴·통계 화면이 열려 있고 "메뉴 중 게임 진행"이 꺼져 있으면 게임 시간을 멈춘다(기본은 흐름).
func _update_pause_freeze() -> void:
	get_tree().paused = (pause_menu.visible or stats_screen.visible) and not SettingsManager.pause_time_flows


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spin"):
		if promotion.is_playing():
			promotion.skip()
		elif jackpot.is_open:
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
		# pause_menu 가 열려 있을 때 닫는 것은 PauseMenu 자신의 _unhandled_input 이 맡는다
		# (PROCESS_MODE_ALWAYS 라 "메뉴 중 진행 끄기" 로 tree 가 paused 여도 동작해야 하기 때문).
		if stats_screen.visible:
			_close_stats_screen()
			get_viewport().set_input_as_handled()
		elif settings_overlay.visible:
			_close_overlay(settings_overlay)
			get_viewport().set_input_as_handled()
		elif skill_overlay.visible:
			_close_overlay(skill_overlay)
			get_viewport().set_input_as_handled()
		elif not pause_menu.visible:
			_open_pause_menu()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_auto"):
		spin_controls.auto_button.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fullscreen"):
		SettingsManager.fullscreen = not SettingsManager.fullscreen
		SettingsManager.commit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT and wheel.spinning:
			if button.position.distance_to(WHEEL_CENTER) <= WHEEL_CLICK_RADIUS:
				wheel.skip()
				get_viewport().set_input_as_handled()
