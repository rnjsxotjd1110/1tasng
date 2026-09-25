extends "res://tests/lib/test_case.gd"
## TitleScreen: 이어하기 활성/요약, 새 게임 확인 팝업, 오버레이 전환, 칩 커서 위치.
## 주의: get_tree().change_scene_to_file() 을 실제로 부르는 경로(이어하기 클릭, 새 게임 인트로가
## 끝까지 재생돼 finished 가 발행되는 경우)는 이 파일에서 절대 실행하지 않는다 — 헤드리스 테스트가
## 공유하는 SceneTree 에 실제 씬 전환이 섞이면 이후 테스트가 전부 오염된다. 그 경로는 캡처 스크린샷과
## 실제 실행으로 확인한다.

var screen: TitleScreen


func before_each() -> void:
	super.before_each()
	screen = TitleScreen.new()
	tree.root.add_child(screen)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	screen.free()
	screen = null


func test_continue_disabled_without_save() -> void:
	check(not SaveManager.has_save(), "저장 없음")
	check(screen._continue_button.disabled, "이어하기 비활성")
	check_eq(screen._continue_summary.text, "", "요약 문구 없음")


func test_continue_enabled_with_summary_when_save_exists() -> void:
	GameState.floor_index = 1
	GameState.add_chips(999.0)
	check(SaveManager.save_game(), "저장")
	var screen2 := TitleScreen.new()
	tree.root.add_child(screen2)
	check(not screen2._continue_button.disabled, "이어하기 활성")
	check(screen2._continue_summary.text != "", "요약 문구 있음")
	check(screen2._continue_summary.text.contains(tr("FLOOR_1F")), "층 이름 포함")
	screen2.free()


func test_new_game_without_save_resets_state_and_plays_intro() -> void:
	GameState.add_chips(500.0)
	check(not SaveManager.has_save(), "저장 없음")
	screen._on_new_game_pressed()
	check(not screen._new_game_confirm.visible, "확인 팝업 없이 바로 시작")
	check_rel(GameState.chips, Economy.STARTING_CHIPS, 1e-9, "GameState 가 새 게임으로 리셋됨")
	check(screen._intro != null and screen._intro.visible, "인트로 컷신이 재생 중")


func test_new_game_with_existing_save_shows_confirm() -> void:
	check(SaveManager.save_game(), "저장")
	screen._on_new_game_pressed()
	check(screen._new_game_confirm.visible, "기존 저장이 있으면 확인 팝업부터")
	check(screen._intro == null, "확인 전에는 컷신을 시작하지 않음")


func test_settings_overlay_toggles() -> void:
	check(not screen._settings_overlay.visible, "처음엔 닫힘")
	screen._toggle_overlay(screen._settings_overlay)
	check(screen._settings_overlay.visible, "설정 버튼으로 열림")


func test_achievement_overlay_toggles() -> void:
	screen._toggle_overlay(screen._achievement_overlay)
	check(screen._achievement_overlay.visible, "업적 버튼으로 열림")


func test_credits_overlay_shows_studio_name() -> void:
	screen._toggle_overlay(screen._credits_overlay)
	check(screen._credits_overlay.visible, "크레딧 버튼으로 열림")
	check(tr("CREDITS_DEVELOPER") % [Economy.STUDIO_NAME] != "", "스튜디오 이름 문구 구성 가능")


func test_chip_cursor_moves_to_focused_button() -> void:
	var target_button := screen._menu_buttons[2]
	screen._move_cursor_to(target_button, true)
	var parent := target_button.get_parent() as Control
	var expected: Vector2 = (parent.position + target_button.position
			+ Vector2(-TitleScreen.CHIP_CURSOR_GAP - TitleScreen.CHIP_CURSOR_SIZE.x, (TitleScreen.MENU_BUTTON_SIZE.y - TitleScreen.CHIP_CURSOR_SIZE.y) * 0.5)).round()
	check_eq(screen._chip_cursor.position, expected, "칩 커서가 버튼 왼쪽에 정확히 붙음")
