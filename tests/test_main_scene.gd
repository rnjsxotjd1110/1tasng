extends "res://tests/lib/test_case.gd"
## 메인 씬 통합: 베팅 조작 → 스핀 → 휠 연출 → 정산 → 연출, 탭 전환, 스킵, 칩 부족.
## 헤드리스라 프레임이 흐르지 않으므로 휠의 _process 를 직접 부른다.

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const STEP := 0.05

var main: Main


func before_each() -> void:
	super.before_each()
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)


func after_each() -> void:
	main.free()
	main = null


func _run_wheel_to_end(max_seconds: float = 10.0) -> void:
	var elapsed := 0.0
	while main.wheel.spinning and elapsed < max_seconds:
		main.wheel._process(STEP)
		elapsed += STEP


func test_main_is_project_main_scene() -> void:
	check_eq(ProjectSettings.get_setting("application/run/main_scene"), MAIN_SCENE, "메인 씬")
	check(not ResourceLoader.exists("res://scenes/debug/DebugLogic.tscn"), "1단계 디버그 씬 삭제")
	check(main.controller != null and not main.controller.instant_resolve, "연출이 finish_spin 을 부른다")


func test_place_and_retrieve_bets() -> void:
	var board := main.bet_panel.board
	check(board.place("S17"), "17 에 구슬")
	check_eq(GameState.current_bets.size(), 1, "베팅 1개")
	check(not board.place("R"), "구슬 1개뿐이라 두 번째는 실패")
	GameState.set_upgrade_level("marble_count", 2)
	check(board.place("S17"), "같은 칸 두 번째 구슬")
	check(board.place("R"), "빨강")
	check_eq(GameState.current_bets.size(), 3, "베팅 3개")
	check(board.retrieve("S17"), "17 회수")
	check_eq(GameState.current_bets.size(), 2, "베팅 2개")
	check(GameState.replace_bet_at(0, Bet.even()), "드래그 이동 = 칸 교체")
	check_eq(BetBoard.key_of(GameState.current_bets[0]), "E", "짝으로 이동")
	main.bet_panel._on_clear()
	check(GameState.current_bets.is_empty(), "초기화")


func test_spot_keys_round_trip() -> void:
	for bet: Bet in [Bet.red(), Bet.black(), Bet.odd(), Bet.even(), Bet.straight(0), Bet.straight(36)]:
		check(BetBoard.bet_of(BetBoard.key_of(bet)).same_spot(bet), "키 왕복 %s" % BetBoard.key_of(bet))
	var board := main.bet_panel.board
	check_eq(board.all_keys().size(), 41, "칸 41개(0~36 + 외부 4)")
	check_eq(board.key_at(board.spot_rect("S5").get_center()), "S5", "좌표 → 칸")


func test_full_spin_through_wheel() -> void:
	main.bet_panel.board.place("R")
	var result: int = RngService.peek_next(1)[0]
	main.request_spin()
	check(main.wheel.spinning, "휠 연출 시작")
	check(main.bet_panel.board.locked, "스핀 중 베팅 잠금")
	check(not main.bet_panel.board.place("B"), "잠긴 동안 베팅 불가")
	check_eq(GameState.chips, 90.0, "베팅액 차감")
	_run_wheel_to_end()
	check(not main.wheel.spinning, "연출 끝")
	check(main.controller.is_idle(), "정산 완료")
	check_eq(GameState.result_history, [result] as Array[int], "기록")
	check_eq(main.wheel.idle_results, [result] as Array[int], "공이 결과 포켓에 머묾")
	var relative := main.wheel.wheel_angle + RouletteRules.pocket_angle(result)
	var ball_angle := main.wheel.choreo.ball_angle(0, main.wheel.choreo.duration)
	check(absf(SpinChoreography.angle_difference(ball_angle, relative)) < 0.5, "공이 결과 포켓 위에 있다")
	check(not main.bet_panel.board.locked, "잠금 해제")
	check_eq(main.result_badge.visible, true, "결과 배지")
	var expected := 90.0 + (20.0 if RouletteRules.is_red(result) else 0.0)
	check_eq(GameState.chips, expected, "정산 반영")


func test_skip_finishes_in_skip_time() -> void:
	main.bet_panel.board.place("R")
	main.request_spin()
	main.wheel._process(0.5)
	main.request_spin()  # 스핀 중 SPIN = 스킵
	check(main.wheel.is_skipping(), "스킵 중")
	var elapsed := 0.0
	while main.wheel.spinning and elapsed < 2.0:
		main.wheel._process(0.01)
		elapsed += 0.01
	check(elapsed <= RouletteWheel.SKIP_SECONDS + 0.02, "0.3초 안에 결과 (%.2f초)" % elapsed)
	check(main.controller.is_idle(), "정산됨")


func test_no_bets_and_not_enough_chips() -> void:
	main.request_spin()
	check(not main.wheel.spinning, "베팅 없으면 시작 안 함")
	main.bet_panel.board.place("R")
	GameState.spend_chips(GameState.chips - 0.5)
	check(not main.bet_panel.is_affordable(), "칩 부족")
	check(main.spin_controls.spin_button.disabled, "SPIN 비활성")
	main.request_spin()
	check(not main.wheel.spinning, "칩 부족이면 시작 안 함")


func test_tooltip_uses_real_payout() -> void:
	GameState.set_upgrade_level("marble_tier", 1)  # 돌 ×1.5
	var text := main.bet_panel.board.tooltip_text("S17")
	check(text.contains("17"), "숫자")
	check(text.contains("35:1"), "배당")
	check(text.contains(NumberFormat.format(10.0 * 36.0 * 1.5)), "배율 반영 예상 당첨금 540")
	var red := main.bet_panel.board.tooltip_text("R")
	check(red.contains(NumberFormat.format(10.0 * 2.0 * 1.5)), "빨강 30")


func test_chip_size_buttons() -> void:
	(main.bet_panel.chip_buttons[Economy.ChipSize.TENTH] as Button).pressed.emit()
	check_eq(GameState.chip_size_mode, Economy.ChipSize.TENTH, "1/10")
	main.bet_panel.board.place("R")
	check_eq(main.bet_panel.per_marble_amount(), 1.0, "구슬당 1")


func test_tabs_switch_right_panel() -> void:
	main.switch_panel(TopBar.TAB_UPGRADE)
	check_eq(main.current_tab, TopBar.TAB_UPGRADE, "업그레이드 탭")
	check(main.upgrade_panel.visible, "업그레이드 화면 보임")
	check((main.top_bar.tab_buttons[TopBar.TAB_UPGRADE] as Button).button_pressed, "탭 선택")
	check(not (main.top_bar.tab_buttons[TopBar.TAB_BET] as Button).button_pressed, "베팅 탭 해제")
	main.switch_panel(TopBar.TAB_BET)
	check_eq(main.current_tab, TopBar.TAB_BET, "베팅 탭")


func test_tier_effects_run_for_every_tier() -> void:
	for tier in SpinOutcome.Tier.values():
		var outcome := SpinOutcome.new()
		outcome.results = [17] as Array[int]
		outcome.tier = tier
		outcome.total_bet = 10.0
		outcome.total_return = 0.0 if tier == SpinOutcome.Tier.LOSS else 10000.0
		outcome.net = outcome.total_return - outcome.total_bet
		if tier >= SpinOutcome.Tier.BIG:
			outcome.hit_straights = [17] as Array[int]
		main.play_tier_effects(outcome, ["S17"] as Array[String])
	check(main.jackpot.is_open, "JACKPOT 오버레이 열림")
	main.jackpot.close()
	check(main.float_layer.get_child_count() > 0, "떠오르는 텍스트")


func test_history_panel_updates() -> void:
	main.bet_panel.board.place("R")
	main.request_spin()
	_run_wheel_to_end()
	check_eq(main.history_panel._recent.size(), 1, "기록 토큰 1개")


func test_result_badge_subtitle() -> void:
	TranslationServer.set_locale("ko")
	check_eq(ResultBadge.subtitle_for(17), "검정 · 홀수", "17")
	check_eq(ResultBadge.subtitle_for(0), "제로", "0")
	TranslationServer.set_locale("en")
	check_eq(ResultBadge.subtitle_for(32), "Red · Even", "32")


# ── 층 이동·엘리베이터(7단계) ─────────────────────────────

func _run_elevator_to(phase: ElevatorCutscene.Phase, max_seconds: float = 6.0) -> void:
	var elapsed := 0.0
	while main.elevator_cutscene._phase != phase and main.elevator_cutscene.is_playing() and elapsed < max_seconds:
		main.elevator_cutscene._process(STEP)
		elapsed += STEP


func test_elevator_button_visible_only_when_affordable_and_not_max_floor() -> void:
	check(not main.elevator_button.visible, "칩 부족이면 안 보임")
	GameState.add_chips(1e6)
	check(main.elevator_button.visible, "비용을 채우면 보임")
	GameState.floor_index = 4
	EventBus.floor_changed.emit(4)
	check(not main.elevator_button.visible, "최고층이면 안 보임")


func test_floor_confirm_popup_shows_next_floor_info() -> void:
	GameState.add_chips(1e6)
	main.floor_confirm_popup.open()
	check(main.floor_confirm_popup.visible, "팝업 열림")
	check(main.floor_confirm_popup._cost_label.text.contains(NumberFormat.format(1e6)), "비용 표시")
	check(main.floor_confirm_popup._feature_label.text.contains("10"), "클로버 +10 표시")


func test_elevator_cutscene_moves_floor_only_after_doors_closed() -> void:
	GameState.add_chips(1e6)
	main._on_floor_confirmed()
	check(main.elevator_cutscene.is_playing(), "컷신 시작")
	check_eq(GameState.floor_index, 0, "문이 닫히기 전에는 층이 안 바뀐다")
	_run_elevator_to(ElevatorCutscene.Phase.TICK)
	check_eq(GameState.floor_index, 1, "문이 닫힌 순간 1F 로 이동")


func test_elevator_cutscene_skip_still_applies_state() -> void:
	GameState.add_chips(1e6)
	var before_clovers := GameState.clovers
	main._on_floor_confirmed()
	main.elevator_cutscene.skip()
	check(not main.elevator_cutscene.is_playing(), "스킵하면 즉시 끝남")
	check_eq(GameState.floor_index, 1, "스킵해도 층 이동은 적용됨")
	check_eq(GameState.clovers, before_clovers + Economy.CLOVER_PER_FLOOR, "스킵해도 클로버 +10")


func test_request_spin_blocked_during_elevator_cutscene() -> void:
	main.bet_panel.board.place("R")
	GameState.add_chips(1e6)
	main._on_floor_confirmed()
	main.request_spin()
	check(not main.wheel.spinning, "컷신 중에는 스핀 시작 안 함")
	main.elevator_cutscene.skip()
