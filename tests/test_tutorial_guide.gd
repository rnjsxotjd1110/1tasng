extends "res://tests/lib/test_case.gd"
## TutorialGuide(8단계 2/N): 6단계 진행 조건, 저장 재개, 다시 보기, 1회성 신규 기능 팁.
## Main 을 실제로 띄워서 검사한다(하이라이트 대상이 실제 bet_panel/spin_controls/top_bar/upgrade_panel
## 노드의 global_rect 이기 때문 — test_main_scene.gd 와 같은 구성).

const MAIN_SCENE := "res://scenes/main/Main.tscn"

var main: Main


func before_each() -> void:
	super.before_each()
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	main.free()
	main = null


func test_new_game_starts_at_place_bet_step() -> void:
	check(main.tutorial.is_active_at(TutorialGuide.Step.PLACE_BET), "새 게임은 첫 단계(구슬 놓기)로 시작")
	check(main.tutorial.visible, "튜토리얼 오버레이가 보임")


func test_placing_bet_advances_to_spin() -> void:
	GameState.add_bet(Bet.red())
	check(main.tutorial.is_active_at(TutorialGuide.Step.SPIN), "베팅하면 SPIN 단계로")


func test_spin_resolved_advances_to_result() -> void:
	GameState.add_bet(Bet.red())
	RngService.force_next([1])
	main.controller.instant_resolve = true
	main.controller.start_spin()
	check(main.tutorial.is_active_at(TutorialGuide.Step.RESULT), "정산되면 결과 설명 단계로")


func test_dismissing_result_dialogue_advances_to_upgrade_tab() -> void:
	GameState.add_bet(Bet.red())
	RngService.force_next([1])
	main.controller.instant_resolve = true
	main.controller.start_spin()
	check(main._npc_dialogue.is_open(), "결과 설명 대사가 열림")
	while main._npc_dialogue.is_open():
		main._npc_dialogue.advance()
	check(main.tutorial.is_active_at(TutorialGuide.Step.UPGRADE_TAB), "대사를 닫으면 업그레이드 탭 강조 단계로")


func _advance_to_upgrade_tab() -> void:
	GameState.tutorial_step = TutorialGuide.Step.UPGRADE_TAB
	main.top_bar.tab_pressed.emit(TopBar.TAB_UPGRADE)


func test_pressing_upgrade_tab_advances_to_upgrade_buy() -> void:
	_advance_to_upgrade_tab()
	check(main.tutorial.is_active_at(TutorialGuide.Step.UPGRADE_BUY), "업그레이드 탭을 누르면 구매 안내 단계로")


func test_buying_stone_marble_advances_to_clover() -> void:
	_advance_to_upgrade_tab()
	check_eq(UpgradeService.purchase("marble_tier"), 1, "돌 구슬 구매 성공(시작 칩 100 ≥ 비용 50, 1레벨 구매)")
	check(main.tutorial.is_active_at(TutorialGuide.Step.CLOVER), "재질 구매(레벨 1)가 클로버 설명 단계로 넘김")


func test_other_upgrade_purchase_does_not_advance_upgrade_buy() -> void:
	_advance_to_upgrade_tab()
	GameState.add_chips(1000.0)
	UpgradeService.purchase("bet_limit")
	check(main.tutorial.is_active_at(TutorialGuide.Step.UPGRADE_BUY), "marble_tier 가 아닌 구매는 넘기지 않음")


func test_first_clover_advances_to_skilltree_and_suppresses_generic_line() -> void:
	GameState.tutorial_step = TutorialGuide.Step.CLOVER
	main.tutorial._active = true
	EventBus.first_clover_earned.emit()
	check(main.tutorial.is_active_at(TutorialGuide.Step.SKILLTREE), "첫 클로버로 스킬트리 안내 단계로")
	check_eq(main._npc_dialogue._name_label.text, tr("NPC_LUCY"), "루시가 말함")


func test_dismissing_skilltree_dialogue_finishes_tutorial() -> void:
	GameState.tutorial_step = TutorialGuide.Step.SKILLTREE
	main.tutorial._active = true
	main.tutorial._goto_step(TutorialGuide.Step.SKILLTREE)
	while main._npc_dialogue.is_open():
		main._npc_dialogue.advance()
	check_eq(GameState.tutorial_step, TutorialGuide.Step.DONE, "완료되면 GameState.tutorial_step 이 DONE")
	check(not main.tutorial.visible, "오버레이가 사라짐")


func test_resumes_from_saved_step() -> void:
	main.free()
	GameState.reset()
	GameState.tutorial_step = TutorialGuide.Step.UPGRADE_BUY
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	check(main.tutorial.is_active_at(TutorialGuide.Step.UPGRADE_BUY), "불러온 단계에서 이어서 시작")


func test_disabled_in_settings_never_starts() -> void:
	SettingsManager.tutorial_enabled = false
	main.free()
	GameState.reset()
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	check(not main.tutorial.visible, "설정에서 껐으면 시작하지 않음")
	SettingsManager.tutorial_enabled = true


func test_completed_tutorial_does_not_restart_on_load() -> void:
	main.free()
	GameState.reset()
	GameState.tutorial_step = TutorialGuide.Step.DONE
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	check(not main.tutorial.visible, "완료된 튜토리얼은 다시 뜨지 않음")


func test_replay_restarts_from_place_bet() -> void:
	GameState.tutorial_step = TutorialGuide.Step.DONE
	main.tutorial._active = false
	main.tutorial.visible = false
	EventBus.tutorial_reset_requested.emit()
	check(main.tutorial.is_active_at(TutorialGuide.Step.PLACE_BET), "다시 보기는 첫 단계부터")
	check(main.tutorial.visible, "오버레이가 다시 보임")


# ── 1회성 신규 기능 팁 ────────────────────────────────────────

func test_first_loan_shows_tip_once() -> void:
	var toasts := watch(EventBus.toast_requested)
	GameState.increment_stat(GameState.STAT_LOANS_TAKEN, 1.0)
	EventBus.debt_changed.emit()
	EventBus.debt_changed.emit()
	check_eq(toasts.size(), 1, "첫 대출 팁은 한 번만")
	check(GameState.tutorial_tips_seen.has("first_loan"), "본 팁으로 기록됨")


func test_first_floor_move_shows_tip() -> void:
	var toasts := watch(EventBus.toast_requested)
	EventBus.floor_changed.emit(1)
	check_eq(toasts.size(), 1, "첫 층 이동 팁")
	EventBus.floor_changed.emit(1)
	check_eq(toasts.size(), 1, "두 번째부터는 뜨지 않음")


func test_floor_2_shows_golden_pocket_unlock_tip() -> void:
	var toasts := watch(EventBus.toast_requested)
	EventBus.floor_changed.emit(2)
	check(toasts.size() >= 1, "2F 도달 시 황금 포켓 해금 팁")
	check(GameState.tutorial_tips_seen.has("golden_pocket_unlocked"), "본 팁으로 기록됨")


func test_tips_disabled_when_tutorial_setting_off() -> void:
	SettingsManager.tutorial_enabled = false
	var toasts := watch(EventBus.toast_requested)
	EventBus.floor_changed.emit(1)
	check_eq(toasts.size(), 0, "설정을 끄면 팁도 안 뜸")
	SettingsManager.tutorial_enabled = true
