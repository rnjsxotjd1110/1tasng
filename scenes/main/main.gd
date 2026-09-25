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
const DEBT_PANEL_POS := Vector2(420, 26)
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
## 엘리베이터 버튼(7단계): 휠 오른쪽 위, 기록 패널·오른쪽 패널 사이의 열린 틈.
const ELEVATOR_BUTTON_POS := Vector2(341, 41)
const ELEVATOR_CLOVER_FLIGHTS := 3
## 5~8분(초) 사이 무작위로 벨벳이 한 마디씩 한다(PH 에 있을 때만).
const VELVET_PERIODIC_MIN := 300.0
const VELVET_PERIODIC_MAX := 480.0

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
var debt_panel: DebtPanel
var result_badge: ResultBadge
var float_layer: Control
var flying_chips: FlyingChips
var big_win: BigWinBanner
var flash: ScreenFlash
var jackpot: JackpotOverlay
var skill_overlay: SkillTreeScreen
var settings_overlay: SettingsScreen
var stats_screen: StatsScreen
var achievement_screen: AchievementScreen
var achievement_toast: AchievementToast
var pause_menu: PauseMenu
var return_popup: ReturnPopup
var baron_loan_seq: BaronLoanSequence
var baron_payoff_seq: BaronPayoffSequence
var penalty_toast: PenaltyToast
var smoke_overlay: SmokeOverlay
var _underling: UnderlingRat = null
var _underling_leaving: bool = false
var toasts: ToastLayer
var tooltip_layer: TooltipLayer
var shaker: ScreenShake
var lucy: LucyDealer = null
var velvet: MadameVelvet = null
var _npc_dialogue: DialogueBox = null
var _velvet_periodic_timer: float = -1.0
var buff_bar: BuffBar
var prophecy_orb: ProphecyOrb
var fever_gauge: FeverGauge
var jackpot_chain_label: Label
var wheel_of_fortune_popup: WheelOfFortunePopup
var elevator_button: ElevatorButton
var floor_confirm_popup: FloorConfirmPopup
var elevator_cutscene: ElevatorCutscene
var _elevator_was_visible: bool = false
var acquisition_button: AcquisitionButton
var ending_sequence: EndingSequence
var ending_credits: EndingCredits
var _acquisition_was_visible: bool = false
var tutorial: TutorialGuide

const LUCY_POSITION := Vector2(110, 306)
const VELVET_POSITION := Vector2(596, 300)

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
	EventBus.chips_changed.connect(func(_v: float, _d: float) -> void: _refresh_elevator())
	EventBus.floor_changed.connect(func(_i: int) -> void: _refresh_elevator())
	EventBus.chips_changed.connect(func(_v: float, _d: float) -> void: _refresh_acquisition())
	EventBus.floor_changed.connect(func(_i: int) -> void: _refresh_acquisition())
	EventBus.milestone_reached.connect(_on_milestone)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.golden_pockets_added.connect(_on_golden_pockets_added)
	EventBus.bankrupt.connect(_on_bankrupt)
	EventBus.debt_changed.connect(_on_debt_changed)
	EventBus.penalty_triggered.connect(_on_penalty_triggered)
	EventBus.buff_started.connect(_on_penalty_buff_started)
	EventBus.buff_ended.connect(_on_penalty_buff_ended)
	EventBus.skill_purchased.connect(func(_id: String, _level: int) -> void:
		_refresh_lucy()
		spin_controls.set_auto_locked(not SkillService.has_feature("auto_spin")))
	EventBus.first_clover_earned.connect(_on_first_clover_earned)
	EventBus.streak_clover_earned.connect(_on_streak_clover_earned)
	EventBus.auto_spin_stopped.connect(_on_auto_spin_stopped)
	wheel.spin_finished.connect(_on_wheel_finished)
	EventBus.tutorial_reset_requested.connect(func() -> void: tutorial.restart())
	_refresh_spin_state()
	_attach_debug_panel()
	_show_return_popup_if_needed()
	_resume_baron_event_if_needed()
	# 반드시 이 _ready() 의 EventBus.first_clover_earned 연결(위) 뒤에 불러야 한다: 신호 발행 시 먼저
	# 연결된 쪽부터 실행되므로, Main._on_first_clover_earned() 가 tutorial.is_active_at(CLOVER) 를
	# (아직 SKILLTREE 로 넘어가기 전 값으로) 먼저 확인한 뒤에 tutorial 자신의 처리가 이어져야 중복
	# 대사(skilltree_unlock + tutorial_skilltree)를 막을 수 있다.
	tutorial.start(self, GameState.tutorial_step)


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


# ── 빚·래칫 남작(5단계) ───────────────────────────────────

func _on_bankrupt() -> void:
	_stop_auto_spin("AUTO_STOP_BANKRUPT")
	_start_loan_sequence()


func _start_loan_sequence() -> void:
	GameState.penalty_manager.suppressed = true
	spin_controls.set_spin_enabled(false)
	baron_loan_seq.play(GameState.pending_baron_event)


func _on_loan_signed(_principal: float, _repay: float) -> void:
	var source := baron_loan_seq.contract.global_position + ContractPopup.SIZE * 0.5
	flying_chips.launch([source], top_bar.chip_target(), 3)
	AudioManager.play_sfx("chip_bag_toss")


func _on_loan_sequence_finished() -> void:
	GameState.penalty_manager.suppressed = false
	GameState.pending_baron_event = {}
	SaveManager.save_game()
	_refresh_spin_state()


## 완납은 debt_changed 로 감지한다(자동 상환·수동 상환 어느 쪽이든 총 빚이 0이 되면 GameState 가 예약해 둔다).
func _on_debt_changed() -> void:
	if String(GameState.pending_baron_event.get("type", "")) == "debt_paid" and not baron_payoff_seq.is_playing():
		_start_payoff_sequence()


func _start_payoff_sequence() -> void:
	GameState.penalty_manager.suppressed = true
	spin_controls.set_spin_enabled(false)
	baron_payoff_seq.play()


func _on_payoff_clover_moment() -> void:
	flying_chips.launch([baron_payoff_seq.baron.global_position], top_bar.clover_target(), 2, FlyingChips.Icon.CLOVER)


func _on_payoff_sequence_finished() -> void:
	GameState.penalty_manager.suppressed = false
	GameState.pending_baron_event = {}
	SaveManager.save_game()
	_refresh_spin_state()


## 남작 컷신이 안 끝난 채로 저장됐다가 불러왔으면 처음부터 다시 보여준다(수치는 이미 반영돼 있다 — 연출만 재생).
func _resume_baron_event_if_needed() -> void:
	match String(GameState.pending_baron_event.get("type", "")):
		"loan":
			_start_loan_sequence()
		"debt_paid":
			_start_payoff_sequence()


# ── 패널티 시각 효과(5단계, ART_BIBLE 11-6) ────────────────

const UNDERLING_ENTER_X := 60.0
const UNDERLING_STAND_X := 175.0
const UNDERLING_Y := 300.0

## 즉시·소모형 패널티(소매치기·압류·클로버 수수료)의 1회성 연출. 토스트는 PenaltyToast 가 스스로 처리한다.
func _on_penalty_triggered(id: String, _duration: float) -> void:
	match id:
		"pickpocket":
			PickpocketDash.spawn(_layer_root(fx_layer))
		"seize_marble":
			bet_panel.board.play_seizure_stamp()


## 시간제 패널티(감시하는 부하·흐려진 구슬·시가 연기) 시작. buff_started 는 stage 6 버프와도 공유하므로 모르는 id 는 무시한다.
func _on_penalty_buff_started(id: String, _duration: float) -> void:
	match id:
		"watcher":
			_spawn_underling()
		"blur":
			MarbleSprite.set_desaturate(1.0)
		"smoke":
			smoke_overlay.start()
		"fever":
			wheel.set_rainbow_mode(true)
			FloatingText.spawn(float_layer, tr("FEVER_BANNER"), "Num14Gold", TEXT_ANCHOR + Vector2(0, -40))
			AudioManager.play_sfx("fever_start")
			AudioManager.set_fever_layer(true)
		"jackpot_chain":
			wheel.trigger_lightning()
			_refresh_jackpot_chain_label()


func _on_penalty_buff_ended(id: String) -> void:
	match id:
		"watcher":
			_dismiss_underling()
		"blur":
			MarbleSprite.set_desaturate(0.0)
		"smoke":
			smoke_overlay.stop()
		"fever":
			wheel.set_rainbow_mode(false)
			AudioManager.play_sfx("fever_end")
			AudioManager.set_fever_layer(false)
		"jackpot_chain":
			_refresh_jackpot_chain_label()


## 잭팟 체인(6단계, F14) 남은 스핀 수를 휠 옆에 작게 보여준다.
func _refresh_jackpot_chain_label() -> void:
	var left := GameState.buff_charges_left("jackpot_chain")
	jackpot_chain_label.visible = left > 0
	if left > 0:
		jackpot_chain_label.text = "×" + NumberFormat.format(left)


func _spawn_underling() -> void:
	if _underling != null:
		return
	_underling = UnderlingRat.new()
	_underling.position = Vector2(UNDERLING_ENTER_X, UNDERLING_Y)
	_underling.arrived.connect(_on_underling_arrived)
	world.add_child(_underling)
	_underling_leaving = false
	_underling.walk_to(UNDERLING_STAND_X)


func _dismiss_underling() -> void:
	if _underling == null:
		return
	_underling_leaving = true
	_underling.walk_to(UNDERLING_ENTER_X)


func _on_underling_arrived() -> void:
	if _underling == null:
		return
	if _underling_leaving:
		_underling.queue_free()
		_underling = null
	else:
		_underling.lean()


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	background = _background_for_floor(GameState.floor_index)
	world.add_child(background)
	wheel = WheelScene.instantiate()
	wheel.position = WHEEL_CENTER
	world.add_child(wheel)
	_refresh_lucy()
	_refresh_velvet(GameState.floor_index)
	EventBus.floor_changed.connect(_on_floor_changed_background)
	_play_floor_music(GameState.floor_index)


## 층별 배경(7단계, ART_BIBLE 12장). B1 은 기존 .tscn, 나머지는 절차적 Node2D.
func _background_for_floor(index: int) -> Node2D:
	var floor_def := GameData.floor_def(index)
	match floor_def.id if floor_def != null else "b1":
		"1f":
			return Background1F.new()
		"2f":
			return Background2F.new()
		"3f":
			return Background3F.new()
		"ph":
			return BackgroundPH.new()
	return BackgroundScene.instantiate()


func _on_floor_changed_background(index: int) -> void:
	var old := background
	background = _background_for_floor(index)
	world.add_child(background)
	world.move_child(background, 0)
	old.queue_free()
	_play_floor_music(index)
	_refresh_velvet(index)


## 층별 BGM 슬롯(7단계): 실제 음원·크로스페이드는 8단계에서 AudioManager.play_music() 를 구현하면 그대로 동작한다.
func _play_floor_music(index: int) -> void:
	var floor_def := GameData.floor_def(index)
	if floor_def != null and floor_def.music_id != "":
		AudioManager.play_music(floor_def.music_id)


## 딜러 루시(6단계, M14 "dealer_hired": 루시가 테이블을 운영한다)는 스킬로 해금되면
## 휠 왼쪽에 나타나 매 스핀마다 공을 던진다.
func _refresh_lucy() -> void:
	if lucy != null or not SkillService.has_feature("dealer_hired"):
		return
	lucy = LucyDealer.new()
	lucy.position = LUCY_POSITION
	world.add_child(lucy)


## 마담 벨벳(7단계)은 펜트하우스에 있을 때만 보인다. 처음 도착하면 소개 대사를, 그 뒤로는
## 5~8분마다 한 마디씩 한다(PH 를 벗어나면 타이머를 멈춘다).
func _refresh_velvet(index: int) -> void:
	if velvet == null:
		velvet = MadameVelvet.new()
		velvet.position = VELVET_POSITION
		world.add_child(velvet)
	var at_ph := index >= GameData.floors().size() - 1
	velvet.visible = at_ph
	if not at_ph:
		_velvet_periodic_timer = -1.0
		return
	if not GameState.velvet_intro_seen:
		GameState.velvet_intro_seen = true
		_show_npc_line("ph_first_visit")
	_velvet_periodic_timer = RngService.randf_range_misc(VELVET_PERIODIC_MIN, VELVET_PERIODIC_MAX)


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
	spin_controls.auto_pressed.connect(_on_auto_pressed)
	spin_controls.set_auto_locked(not SkillService.has_feature("auto_spin"), false)
	spin_controls.set_auto_toggled(GameState.auto_spin_enabled)
	wheel.set_auto_indicator(GameState.auto_spin_enabled)
	debt_panel = DebtPanel.new()
	debt_panel.position = DEBT_PANEL_POS
	debt_panel.visible = false
	root.add_child(debt_panel)
	top_bar.debt_clicked.connect(debt_panel.toggle)
	result_badge = ResultBadgeScene.instantiate()
	root.add_child(result_badge)
	golden_badge = GoldenBadge.new()
	golden_badge.center = Vector2(WHEEL_CENTER.x, GOLDEN_BADGE_Y)
	root.add_child(golden_badge)
	jackpot_chain_label = Label.new()
	jackpot_chain_label.theme_type_variation = "Num7Gold"
	jackpot_chain_label.position = Vector2(WHEEL_CENTER.x + 96, WHEEL_CENTER.y - 6)
	jackpot_chain_label.visible = false
	jackpot_chain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(jackpot_chain_label)
	buff_bar = BuffBar.new()
	root.add_child(buff_bar)
	prophecy_orb = ProphecyOrb.new()
	prophecy_orb.position = Vector2(WHEEL_CENTER.x - 8.0, 50.0)
	root.add_child(prophecy_orb)
	fever_gauge = FeverGauge.new()
	root.add_child(fever_gauge)
	elevator_button = ElevatorButton.new()
	elevator_button.position = ELEVATOR_BUTTON_POS
	elevator_button.pressed.connect(_on_elevator_pressed)
	root.add_child(elevator_button)
	_elevator_was_visible = FloorService.can_move() and not FloorService.is_max_floor()
	elevator_button.visible = _elevator_was_visible
	acquisition_button = AcquisitionButton.new()
	acquisition_button.position = ELEVATOR_BUTTON_POS
	acquisition_button.pressed.connect(_on_acquisition_pressed)
	root.add_child(acquisition_button)
	_acquisition_was_visible = EndingService.can_trigger()
	acquisition_button.visible = _acquisition_was_visible


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
	tutorial = TutorialGuide.new()
	root.add_child(tutorial)
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
	skill_overlay = SkillTreeScreen.new()
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
	achievement_screen = AchievementScreen.new()
	achievement_screen.position = FULL_OVERLAY_POS
	achievement_screen.visible = false
	achievement_screen.close_requested.connect(_close_achievement_screen)
	root.add_child(achievement_screen)
	return_popup = ReturnPopup.new()
	return_popup.visible = false
	return_popup.claimed.connect(func() -> void: EventBus.toast_requested.emit(tr("TOAST_OFFLINE_CLAIMED"), "chip"))
	root.add_child(return_popup)
	wheel_of_fortune_popup = WheelOfFortunePopup.new()
	wheel_of_fortune_popup.position = ((Vector2(640, 360) - WheelOfFortunePopup.SIZE) * 0.5).round()
	wheel_of_fortune_popup.finished.connect(func() -> void: SaveManager.save_game())
	root.add_child(wheel_of_fortune_popup)
	EventBus.wheel_of_fortune_ready.connect(func() -> void: wheel_of_fortune_popup.open())
	baron_loan_seq = BaronLoanSequence.new()
	baron_loan_seq.signed.connect(_on_loan_signed)
	baron_loan_seq.finished.connect(_on_loan_sequence_finished)
	root.add_child(baron_loan_seq)
	baron_payoff_seq = BaronPayoffSequence.new()
	baron_payoff_seq.clover_moment.connect(_on_payoff_clover_moment)
	baron_payoff_seq.finished.connect(_on_payoff_sequence_finished)
	root.add_child(baron_payoff_seq)
	penalty_toast = PenaltyToast.new()
	root.add_child(penalty_toast)
	achievement_toast = AchievementToast.new()
	root.add_child(achievement_toast)
	smoke_overlay = SmokeOverlay.new()
	root.add_child(smoke_overlay)
	floor_confirm_popup = FloorConfirmPopup.new()
	floor_confirm_popup.position = ((Vector2(640, 360) - FloorConfirmPopup.SIZE) * 0.5).round()
	floor_confirm_popup.confirmed.connect(_on_floor_confirmed)
	root.add_child(floor_confirm_popup)
	elevator_cutscene = ElevatorCutscene.new()
	elevator_cutscene.doors_closed.connect(_on_elevator_doors_closed)
	elevator_cutscene.clover_moment.connect(_on_elevator_clover_moment)
	elevator_cutscene.finished.connect(_on_elevator_finished)
	root.add_child(elevator_cutscene)
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
	pause_menu.achievements_requested.connect(func() -> void:
		_close_pause_menu()
		_open_achievement_screen())
	pause_menu.title_requested.connect(_on_title_requested)
	root.add_child(pause_menu)
	shaker = ScreenShake.new()
	shaker.targets = [world, ui_layer]
	add_child(shaker)
	ending_sequence = EndingSequence.new()
	ending_sequence.wheel = wheel
	ending_sequence.shaker = shaker
	ending_sequence.flash = flash
	ending_sequence.velvet = velvet
	ending_sequence.credits_ready.connect(_on_ending_credits_ready)
	root.add_child(ending_sequence)
	ending_credits = EndingCredits.new()
	ending_credits.position = FULL_OVERLAY_POS
	ending_credits.visible = false
	ending_credits.continue_pressed.connect(_on_ending_continue_pressed)
	root.add_child(ending_credits)


func _layer_root(layer: CanvasLayer) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(640, 360)
	layer.add_child(root)
	return root


# ── 스핀 ─────────────────────────────────────────────────

## SPIN 버튼·Space. 스핀 중이면 남은 연출을 감는다(스킵). 연출 중에도 다음 스핀을 바로 시작할 수 있다.
func request_spin() -> void:
	if jackpot.is_open or baron_loan_seq.is_playing() or baron_payoff_seq.is_playing() or elevator_cutscene.is_playing() or ending_sequence.is_playing():
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
	if lucy != null:
		lucy.play_spin_launch()
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
	_show_debt_repay_if_any()
	if outcome.destiny_flip_from >= 0:
		FloatingText.spawn(float_layer, tr("DESTINY_FLIP_TEXT"), "LabelGold", TEXT_ANCHOR + Vector2(0, -20))
		AudioManager.play_sfx("destiny_flip")
	_refresh_jackpot_chain_label()
	prophecy_orb.refresh()
	if GameState.smart_betting_strategy == GameState.SmartBettingStrategy.MARTINGALE:
		GameState.set_chip_size_mode(SmartBettingService.next_chip_size(GameState.chip_size_mode, outcome.any_win()))
	_refresh_spin_state()


## 자동 상환이 있었던 스핀: 순이익 텍스트 아래 작게 "−N 상환" + 칩 2개가 빚 두루마리로 날아간다(GDD 9장).
func _show_debt_repay_if_any() -> void:
	var repaid := controller.last_debt_repaid
	if repaid <= 0.0:
		return
	var text := "-%s %s" % [NumberFormat.format(repaid), tr("LABEL_REPAID")]
	FloatingText.spawn(float_layer, text, "Num7Red", TEXT_ANCHOR + Vector2(0, 16))
	flying_chips.launch([top_bar.chip_target()], top_bar.debt_target(), 2)


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
			AudioManager.duck_music(AudioManager.MUSIC_DUCK_BIG_WIN_DB, AudioManager.MUSIC_DUCK_BIG_WIN_ATTACK,
					AudioManager.MUSIC_DUCK_BIG_WIN_HOLD, AudioManager.MUSIC_DUCK_BIG_WIN_RELEASE)
		SpinOutcome.Tier.JACKPOT:
			_big_effects(outcome, full, false)
			if full:
				shaker.shake(JACKPOT_SHAKE, JACKPOT_SHAKE_TIME)
			AudioManager.duck_music(AudioManager.MUSIC_DUCK_BIG_WIN_DB, AudioManager.MUSIC_DUCK_BIG_WIN_ATTACK,
					AudioManager.MUSIC_DUCK_BIG_WIN_HOLD, AudioManager.MUSIC_DUCK_BIG_WIN_RELEASE)
			jackpot.open(outcome.net, GameState.auto_spin_enabled)


func _big_effects(outcome: SpinOutcome, full: bool, banner: bool = true) -> void:
	if lucy != null:
		lucy.play_clap()
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
	flying_chips.launch([top_bar.chip_target()], top_bar.clover_target(), 1, FlyingChips.Icon.CLOVER)


## 5연승 클로버(6단계, GDD 6-1): 결과 텍스트가 뜨는 자리에서 클로버 하나가 곡선을 그리며 날아간다.
func _on_streak_clover_earned(_count: int) -> void:
	flying_chips.launch([TEXT_ANCHOR], top_bar.clover_target(), 1, FlyingChips.Icon.CLOVER)


## 살면서 처음 얻은 클로버(6단계): 스킬트리 탭 자물쇠가 깨지고(TopBar 가 스스로 처리) 루시가 한 마디 한다.
func _on_first_clover_earned() -> void:
	if tutorial.is_active_at(TutorialGuide.Step.CLOVER):
		return  # 튜토리얼이 이 시점에 자기 설명(tutorial_clover)을 이미 보여줬다 — 중복 방지.
	_show_npc_line("skilltree_unlock")


## DialogueData 키 하나를 골라 루시·벨벳이 말한다(공용 대화창 재사용, 이미 말하는 중이면 무시).
## entry 의 speaker 필드가 화자를 정하므로 이 함수 자체는 화자를 가리지 않는다.
## force 가 true 면 이미 열려 있어도 즉시 내용을 바꾼다(튜토리얼 단계 안내용 — 플레이어가 대사를
## 닫지 않고도 다음 행동(베팅·탭 클릭)을 할 수 있어 단계가 넘어갈 때 이전 대사가 그대로 남는 문제가
## 있었다. TutorialGuide 만 이 값을 쓴다).
func _show_npc_line(key: String, force: bool = false) -> void:
	var entry := DialogueData.pick(key)
	_say_npc_entry(entry, force)


func _say_npc_entry(entry: Dictionary, force: bool = false) -> void:
	if entry.is_empty() or (not force and _npc_dialogue != null and _npc_dialogue.is_open()):
		return
	if _npc_dialogue == null:
		_npc_dialogue = DialogueBox.new()
		_layer_root(fx_layer).add_child(_npc_dialogue)
		_npc_dialogue.finished.connect(func() -> void: _npc_dialogue.visible = false)
	_npc_dialogue.say(entry)
	_stop_auto_spin("AUTO_STOP_DIALOGUE")


## 벨벳의 주기 대사(7단계): 어떤 변형을 봤는지 인덱스를 기록해야 숨김 업적("벨벳의 모든 말")을 셀 수 있다.
func _show_velvet_periodic_line() -> void:
	var count := DialogueData.variant_count("ph_periodic")
	if count <= 0:
		return
	var index := RngService.randi_range_misc(0, count - 1)
	_say_npc_entry(DialogueData.variant_at("ph_periodic", index))
	GameState.achievement_manager.mark_dialogue_seen("ph_periodic", index)


## PH 에 있는 동안만 5~8분마다 벨벳이 한 마디 한다(_velvet_periodic_timer < 0 이면 PH 밖이라 꺼둔 상태).
func _process_velvet_periodic(delta: float) -> void:
	if _velvet_periodic_timer < 0.0:
		return
	_velvet_periodic_timer -= delta
	if _velvet_periodic_timer > 0.0:
		return
	_velvet_periodic_timer = RngService.randf_range_misc(VELVET_PERIODIC_MIN, VELVET_PERIODIC_MAX)
	if not ending_sequence.is_playing():
		_show_velvet_periodic_line()


# ── 층 이동·엘리베이터(7단계, ART_BIBLE 12장) ─────────────

## 다음 층 비용을 채우면(칩 변화·층 이동마다) 호출: 버튼을 보여주고, 처음 나타나는 순간만 루시가 한 마디 한다.
func _refresh_elevator() -> void:
	var visible_now := FloorService.can_move() and not FloorService.is_max_floor()
	elevator_button.visible = visible_now
	if visible_now and not _elevator_was_visible:
		_show_npc_line("elevator_ready")
	_elevator_was_visible = visible_now


func _on_elevator_pressed() -> void:
	if elevator_cutscene.is_playing():
		return
	floor_confirm_popup.open()


func _on_floor_confirmed() -> void:
	var next_def := FloorService.next_floor_def()
	if next_def == null:
		return
	elevator_cutscene.play(GameState.current_floor().id, next_def.id, next_def.name_key)


## 문이 다 닫힌 순간 실제로 층을 옮긴다(배경·휠 스킨 교체는 문 뒤에서 일어난다).
func _on_elevator_doors_closed() -> void:
	FloorService.move_to_next()


func _on_elevator_clover_moment() -> void:
	flying_chips.launch([WHEEL_CENTER], top_bar.clover_target(), ELEVATOR_CLOVER_FLIGHTS, FlyingChips.Icon.CLOVER)


func _on_elevator_finished() -> void:
	_refresh_elevator()
	_refresh_spin_state()


# ── 엔딩(7단계, GDD 10장) ──────────────────────────────

## 비용을 채우면(칩 변화·층 이동마다) 호출: PH + EndingService.can_trigger() 일 때만 버튼을 보여준다.
func _refresh_acquisition() -> void:
	acquisition_button.visible = EndingService.can_trigger()


func _on_acquisition_pressed() -> void:
	if ending_sequence.is_playing() or not EndingService.trigger():
		return
	acquisition_button.visible = false
	# 벨벳의 주변 대사(도착 인사·주기 대사)가 마침 떠 있었다면 엔딩 전용 대사창과 자리가 겹치니 치운다.
	if _npc_dialogue != null:
		_npc_dialogue.visible = false
	ending_sequence.play()


func _on_ending_credits_ready() -> void:
	ending_credits.visible = true
	ending_credits.refresh()
	ending_credits.focus_continue()
	AudioManager.play_music("bgm_credits")


func _on_ending_continue_pressed() -> void:
	ending_credits.visible = false
	EndingService.enter_infinite_mode()
	SaveManager.save_game()
	_play_floor_music(GameState.floor_index)


# ── 오토 스핀(6단계, M1) ────────────────────────────────

## 오토 스핀 간 대기(스탯으로 단축 가능, M10 등)가 다 찼는지 세는 타이머.
var _auto_spin_timer: float = 0.0


func _on_auto_pressed() -> void:
	GameState.auto_spin_enabled = not GameState.auto_spin_enabled
	_auto_spin_timer = 0.0
	spin_controls.set_auto_toggled(GameState.auto_spin_enabled)
	wheel.set_auto_indicator(GameState.auto_spin_enabled)


func _stop_auto_spin(reason_key: String) -> void:
	if not GameState.auto_spin_enabled:
		return
	GameState.auto_spin_enabled = false
	spin_controls.set_auto_toggled(false)
	wheel.set_auto_indicator(false)
	EventBus.auto_spin_stopped.emit(reason_key)


func _on_auto_spin_stopped(reason_key: String) -> void:
	EventBus.toast_requested.emit(tr(reason_key), "chip")


## 오토 업그레이드(M7)가 다음으로 무엇을 살지 살펴보는 주기.
const AUTO_UPGRADE_INTERVAL := 1.0
var _auto_upgrade_timer: float = 0.0


func _process(delta: float) -> void:
	_process_auto_upgrade(delta)
	_process_velvet_periodic(delta)
	if not GameState.auto_spin_enabled:
		return
	if not controller.is_idle() or wheel.spinning or jackpot.is_open or baron_loan_seq.is_playing() or baron_payoff_seq.is_playing() or promotion.is_playing() or wheel_of_fortune_popup.visible or elevator_cutscene.is_playing() or floor_confirm_popup.visible or ending_sequence.is_playing():
		return
	if _npc_dialogue != null and _npc_dialogue.is_open():
		return
	_apply_smart_betting()
	if GameState.current_bets.is_empty():
		_stop_auto_spin("AUTO_STOP_NO_BETS")
		return
	if not bet_panel.is_affordable():
		_stop_auto_spin("AUTO_STOP_NOT_ENOUGH_CHIPS")
		return
	var delay := GameState.get_stat(StatModifiers.SPIN_DELAY, Economy.AUTO_SPIN_DELAY)
	_auto_spin_timer += delta
	spin_controls.set_auto_progress(_auto_spin_timer / delay)
	if _auto_spin_timer >= delay:
		_auto_spin_timer = 0.0
		request_spin()


## 오토 업그레이드(M7): 예산(보유 칩 × 비율) 안에서 가장 싼 살 수 있는 업그레이드를 산다.
## 실제 구매·플래시·소리는 UpgradePanel.buy() 를 그대로 재사용한다(수동 구매와 같은 반응).
func _process_auto_upgrade(delta: float) -> void:
	if not GameState.auto_upgrade_enabled:
		return
	_auto_upgrade_timer += delta
	if _auto_upgrade_timer < AUTO_UPGRADE_INTERVAL:
		return
	_auto_upgrade_timer = 0.0
	var budget := GameState.chips * GameState.auto_upgrade_ratio
	var id := UpgradeService.cheapest_affordable_id(budget, GameState.auto_upgrade_include_marble)
	if id == "":
		return
	var target := upgrade_panel.card(id)
	if target == null:
		return
	var prev_mode := upgrade_panel.mode
	upgrade_panel.mode = UpgradeService.BuyMode.ONE
	upgrade_panel.buy(target)
	upgrade_panel.mode = prev_mode


## 스마트 베팅(M6): 전략이 KEEP 이 아니면 매 오토 스핀 전에 판을 다시 짠다(마블이 보드에 새로 놓이는 게 보인다).
func _apply_smart_betting() -> void:
	var strategy := GameState.smart_betting_strategy
	if strategy == GameState.SmartBettingStrategy.KEEP:
		return
	var bets := SmartBettingService.compute_bets(strategy, GameState.marble_slots(), GameState.hot_numbers(), Bet.Type.RED)
	GameState.clear_bets()
	for bet in bets:
		GameState.add_bet(bet)


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
		for other: Control in [skill_overlay, settings_overlay, stats_screen, achievement_screen]:
			if other != overlay and other.visible:
				_close_overlay(other)
		if overlay == skill_overlay:
			skill_overlay.open()
		else:
			PanelTransition.open(overlay)


func _close_overlay(overlay: Control) -> void:
	if not overlay.visible:
		return
	if overlay == skill_overlay:
		skill_overlay.close()
	else:
		PanelTransition.close(overlay)


# ── 일시정지·통계(4단계) ─────────────────────────────────

func _open_pause_menu() -> void:
	for other: Control in [skill_overlay, settings_overlay, stats_screen, achievement_screen]:
		_close_overlay(other)
	PanelTransition.open(pause_menu)
	pause_menu.refresh_time_flows_checkbox()
	pause_menu.focus_first()
	_update_pause_freeze()


func _close_pause_menu() -> void:
	if not pause_menu.visible:
		return
	PanelTransition.close(pause_menu).tween_callback(_update_pause_freeze)


## "저장 후 타이틀로"(8단계 1/N): 저장하고 타이틀 화면으로 돌아간다. 진행 중인 게임을 지우지 않으므로
## TitleScreen 의 "이어하기" 로 그대로 이어서 할 수 있다.
func _on_title_requested() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/main/TitleScreen.tscn")


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


func _open_achievement_screen() -> void:
	achievement_screen.refresh()
	for other: Control in [skill_overlay, settings_overlay, stats_screen]:
		_close_overlay(other)
	PanelTransition.open(achievement_screen)
	_update_pause_freeze()


func _close_achievement_screen() -> void:
	if not achievement_screen.visible:
		return
	PanelTransition.close(achievement_screen).tween_callback(_update_pause_freeze)


## 일시정지 메뉴·통계·업적 화면이 열려 있고 "메뉴 중 게임 진행"이 꺼져 있으면 게임 시간을 멈춘다(기본은 흐름).
func _update_pause_freeze() -> void:
	get_tree().paused = (pause_menu.visible or stats_screen.visible or achievement_screen.visible) and not SettingsManager.pause_time_flows


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spin"):
		if _npc_dialogue != null and _npc_dialogue.is_open():
			_npc_dialogue.advance()
		elif baron_loan_seq.is_playing():
			baron_loan_seq.advance_input()
		elif baron_payoff_seq.is_playing():
			baron_payoff_seq.advance_input()
		elif ending_sequence.is_playing():
			ending_sequence.advance_input()
		elif promotion.is_playing():
			promotion.skip()
		elif elevator_cutscene.is_playing():
			elevator_cutscene.skip()
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
		elif achievement_screen.visible:
			_close_achievement_screen()
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
