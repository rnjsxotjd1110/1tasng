extends SceneTree
## 자동 스크린샷 검수 도구. 창 모드로 메인 씬을 띄우고, 지정한 상태를 강제로 만든 뒤
## 뷰포트(640×360 원본)와 3배 확대본을 tools/capture/out/ 에 저장한다.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 -s tools/capture/capture.gd -- scenario=all lang=ko
##   (Windows: Godot_v4.3-stable_win64_console.exe -s tools/capture/capture.gd -- scenario=idle lang=en)
##
## 인자: scenario=<이름|all|쉼표 목록>  lang=ko|en|both  out=<폴더>
## 시나리오: idle, betting, tooltip, spin_03, spin_06, spin_085, normal, good, big, jackpot, loss, near_miss,
##           no_chips, upgrade_tab, skilltree, multi_ball, golden, golden_idle, marbles12
##   3단계: upgrade_early, upgrade_mid, upgrade_late, upgrade_tooltip, upgrade_locked_tip, promote_charge, promote_flash,
##          promote_banner, promote_fly, golden_beam, golden_wheel, slot_open, trail_gold, trail_cosmic, trail_void,
##          numbers_1e3, numbers_1e15, numbers_1e33, numbers_1e60, debug_panel, tab_slide, tab_dot
##   4단계: settings_audio, settings_display, settings_game, settings_accessibility, settings_data,
##          pause_menu, stats_screen, return_popup, toast_recovered, colorblind
##   5단계: baron_appear, dialogue_baron, contract, stamp, penalty_watcher, penalty_pickpocket, penalty_smoke,
##          penalty_blur, penalty_seize, penalty_clover_fee, debt_panel, debt_paid
##   7단계: floor_b1, floor_1f, floor_2f, floor_3f, floor_ph, elevator_ready, elevator_confirm,
##          elevator_cutscene_close, elevator_cutscene_tick, elevator_cutscene_title,
##          achievement_toast, achievement_screen, velvet_intro, acquisition_button, ending_last_hand,
##          ending_final_spin, ending_signing, ending_epilogue, ending_credits
##   8단계: splash, title, title_continue, title_new_game_confirm, title_settings, title_achievements,
##          title_credits, intro_alley, intro_marble, intro_door (Main.tscn 이 아니라 부팅 흐름을 찍는다),
##          tutorial_place_bet, tutorial_spin, tutorial_upgrade_tab, tutorial_upgrade_buy, tutorial_clover
## 인자 tier=<n>: betting·spin_* 시나리오에서 구슬 재질을 강제로 바꾼다.

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const DEFAULT_OUT := "res://tools/capture/out"
const UPSCALE := 3
const SEED := 20260924
const SCENARIOS: Array[String] = [
	"idle", "betting", "tooltip", "spin_03", "spin_06", "spin_085", "normal", "good", "big", "jackpot",
	"loss", "near_miss", "no_chips", "upgrade_tab", "skilltree", "multi_ball", "golden", "golden_idle", "marbles12",
	"upgrade_early", "upgrade_mid", "upgrade_late", "upgrade_tooltip", "upgrade_locked_tip",
	"promote_charge", "promote_flash", "promote_banner", "promote_fly", "golden_beam", "golden_wheel", "slot_open",
	"trail_gold", "trail_cosmic", "trail_void", "numbers_1e3", "numbers_1e15", "numbers_1e33", "numbers_1e60",
	"debug_panel", "tab_slide", "tab_dot",
	"settings_audio", "settings_display", "settings_game", "settings_accessibility", "settings_data",
	"pause_menu", "stats_screen", "return_popup", "toast_recovered", "colorblind",
	"baron_appear", "dialogue_baron", "contract", "stamp",
	"penalty_watcher", "penalty_pickpocket", "penalty_smoke", "penalty_blur", "penalty_seize", "penalty_clover_fee",
	"debt_panel", "debt_paid",
	"floor_b1", "floor_1f", "floor_2f", "floor_3f", "floor_ph",
	"elevator_ready", "elevator_confirm", "elevator_cutscene_close", "elevator_cutscene_tick", "elevator_cutscene_title",
	"achievement_toast", "achievement_screen",
	"velvet_intro", "acquisition_button", "ending_last_hand", "ending_final_spin", "ending_signing",
	"ending_epilogue", "ending_credits",
	"splash", "title", "title_continue", "title_new_game_confirm", "title_settings", "title_achievements",
	"title_credits", "intro_alley", "intro_marble", "intro_door",
	"tutorial_place_bet", "tutorial_spin", "tutorial_upgrade_tab", "tutorial_upgrade_buy", "tutorial_clover",
]
const UPGRADE_SERVICE := "res://scripts/core/upgrade_service.gd"
## 8단계: Main.tscn 이 아니라 부팅 흐름(스플래시·타이틀·인트로 컷신)을 찍는 시나리오.
const TITLE_SCENARIOS: Array[String] = [
	"splash", "title", "title_continue", "title_new_game_confirm", "title_settings", "title_achievements",
	"title_credits", "intro_alley", "intro_marble", "intro_door",
]

var game_state: Node
var rng_service: Node
var save_manager: Node
var main: Node
var out_dir: String = DEFAULT_OUT
## tier=<n> 인자: 캡처 전에 구슬 재질을 강제로 바꾼다(-1 이면 그대로).
var _tier_arg: int = -1


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _args() -> Dictionary:
	var args := {"scenario": "all", "lang": "ko", "out": DEFAULT_OUT}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	return args


func _run() -> void:
	game_state = root.get_node("GameState")
	rng_service = root.get_node("RngService")
	save_manager = root.get_node("SaveManager")
	var args := _args()
	out_dir = String(args["out"])
	_tier_arg = int(args.get("tier", "-1"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var names: Array[String] = []
	if args["scenario"] == "all":
		names = SCENARIOS
	else:
		for n in String(args["scenario"]).split(","):
			names.append(n.strip_edges())
	var langs: Array[String] = []
	if args["lang"] == "both":
		langs.assign(["ko", "en"])
	else:
		langs.append(String(args["lang"]))
	for lang in langs:
		TranslationServer.set_locale(lang)
		for scenario in names:
			await _capture(scenario, lang)
	if main != null:
		main.free()
		main = null
	root.get_node("AudioManager").call("stop_all")
	await process_frame
	print("capture done: ", names.size() * langs.size(), " images → ", ProjectSettings.globalize_path(out_dir))
	quit(0)


func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _fresh() -> void:
	if main != null:
		main.queue_free()
		await process_frame
	game_state.call("reset")
	rng_service.call("set_seed", SEED)
	# 컨테이너에 실제 save.json 이 남아있으면(이전 시나리오가 debt_changed 등으로 자동 저장했거나,
	# 이 도구를 오래 전에 한 번 돌린 적이 있으면) Main._ready() 의 load_game() 이 그걸 그대로 불러와
	# 복귀 팝업·미완료 남작 컷신이 엉뚱하게 겹쳐 보인다(tests/lib/test_case.gd 와 같은 이유로 방어).
	for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	main = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait_frames(3)


## 8단계: 스플래시/타이틀/인트로 컷신을 찍을 때는 Main.tscn 이 아니라 scene_path 를 띄운다.
## keep_save 가 false 면 기존 저장을 지운다(타이틀의 "이어하기" 비활성 상태를 보고 싶을 때).
func _fresh_title(scene_path: String, keep_save: bool = false) -> void:
	if main != null:
		main.queue_free()
		await process_frame
	game_state.call("reset")
	rng_service.call("set_seed", SEED)
	if not keep_save:
		for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	main = load(scene_path).instantiate()
	root.add_child(main)
	await _wait_frames(3)


func _bets(keys: Array) -> void:
	var board: Object = main.get("bet_panel").get("board")
	for key: String in keys:
		board.call("place", key)


func _force(results: Array[int]) -> void:
	rng_service.call("force_next", results)


func _wheel() -> Node:
	return main.get("wheel")


func _levels(levels: Dictionary) -> void:
	for id: String in levels.keys():
		game_state.call("set_upgrade_level", id, int(levels[id]))


func _set_chips(value: float) -> void:
	game_state.call("spend_chips", float(game_state.get("chips")))
	game_state.call("add_chips", value, false)


func _set_debts(entries: Array[Dictionary]) -> void:
	game_state.set("debts", entries)
	root.get_node("EventBus").emit_signal("debt_changed")


func _advance_dialogue(seq: Object) -> void:
	seq.call("advance_input")
	await _wait_seconds(0.1)
	seq.call("advance_input")
	await _wait_seconds(0.1)


func _set_floor(index: int) -> void:
	game_state.set("floor_index", index)
	root.get_node("EventBus").emit_signal("floor_changed", index)


func _start_elevator_cutscene() -> void:
	var next_def: Object = (load("res://scripts/core/floor_service.gd") as GDScript).call("next_floor_def")
	main.get("elevator_cutscene").call("play", game_state.call("current_floor").get("id"), next_def.get("id"), next_def.get("name_key"))


func _buy(id: String) -> int:
	return int((load(UPGRADE_SERVICE) as GDScript).call("purchase", id, 0))


## 재질·광택을 바꾸고 모든 구슬 표시를 맞춘다(연출 없이).
func _tier(tier: int) -> void:
	_levels({"marble_tier": tier})
	_wheel().call("refresh_marble")
	main.get("bet_panel").get("board").call("refresh_marble")


func _upgrade_panel(mode: int) -> void:
	main.call("switch_panel", "upgrade")
	var panel: Object = main.get("upgrade_panel")
	panel.call("set_mode", mode)
	await _wait_seconds(0.35)


func _hover_card(id: String) -> void:
	var panel: Object = main.get("upgrade_panel")
	var card: Control = panel.call("card", id)
	var rect: Rect2 = card.get_global_rect()
	Input.warp_mouse(Vector2(rect.position.x + 60, rect.position.y + 20) * 3.0)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(rect.position.x + 60, rect.position.y + 20)
	motion.global_position = motion.position
	root.push_input(motion)
	# VisualSettings.tooltip_delay(기본 0.3초) + 페이드(0.1초) 이후까지 넉넉히 기다린다.
	await _wait_seconds(0.5)


func _promote(from_tier: int, to_tier: int, wait: float) -> void:
	_set_floor(GameData_floor_for(to_tier))
	_tier(from_tier)
	_levels({"marble_count": 3})
	_bets(["S17", "R"])
	_set_chips(float(root.get_node("GameState").call("current_marble").get("cost")) * 1e4 + 1e12)
	await _wait_seconds(0.3)
	_buy("marble_tier")
	await _wait_seconds(wait)


static func GameData_floor_for(tier: int) -> int:
	for index in 5:
		var floor_def: Resource = load("res://data/floors/%s" % ["floor_0_b1.tres", "floor_1_1f.tres", "floor_2_2f.tres", "floor_3_3f.tres", "floor_4_ph.tres"][index])
		if int(floor_def.get("marble_tier_cap")) >= tier:
			return index
	return 4


func _numbers(value: float) -> void:
	_set_floor(4)
	_levels({"marble_tier": 14, "marble_polish": 5, "bet_limit": 60, "marble_count": 7, "spin_speed": 13, "golden_pocket": 5})
	_tier(14)
	_set_chips(value)
	await _upgrade_panel(2)
	await _hover_card("bet_limit")


func _spin_and_seek(fraction: float) -> void:
	main.call("request_spin")
	await _wait_frames(2)
	var wheel := _wheel()
	wheel.set("paused", true)
	var choreo: Object = wheel.get("choreo")
	wheel.call("seek", float(choreo.get("duration")) * fraction)
	await _wait_frames(2)


func _spin_to_result(wait_after: float) -> void:
	main.call("request_spin")
	await _wait_frames(2)
	var wheel := _wheel()
	var choreo: Object = wheel.get("choreo")
	wheel.call("seek", float(choreo.get("duration")) - 0.02)
	await _wait_seconds(wait_after + 0.05)


func _capture(scenario: String, lang: String) -> void:
	if TITLE_SCENARIOS.has(scenario):
		await _capture_title_flow(scenario, lang)
		return
	await _fresh()
	match scenario:
		"idle":
			await _wait_seconds(0.6)
		"tutorial_place_bet":
			await _wait_seconds(0.3)
		"tutorial_spin":
			_bets(["R"])
			await _wait_seconds(0.3)
		"tutorial_upgrade_tab":
			# TutorialGuide.Step 을 이름으로 쓰지 않고 정수(3=UPGRADE_TAB)로 쓴다: -s 진입 스크립트가
			# 클래스 이름을 참조하면 컴파일 시점에 그 스크립트를 앞당겨 읽어버려(오토로드가 아직 없는
			# 시점) "Identifier not found: EventBus" 같은 오류가 난다(CLAUDE.md 의 -s 스크립트 주의사항과
			# 같은 원인). 문자열 기반 `root.get_node()` 접근과 같은 이유로 정수 리터럴을 쓴다.
			game_state.set("tutorial_step", 3)
			main.get("tutorial").call("_goto_step", 3)
			await _wait_seconds(0.3)
		"tutorial_upgrade_buy":
			game_state.set("tutorial_step", 3)
			main.get("tutorial").call("_goto_step", 3)
			main.get("top_bar").emit_signal("tab_pressed", "upgrade")
			await _wait_seconds(0.3)
		"tutorial_clover":
			game_state.set("tutorial_step", 5)
			main.get("tutorial").call("_goto_step", 5)
			await _wait_seconds(0.3)
		"betting":
			game_state.call("set_upgrade_level", "marble_count", 5)
			if _tier_arg >= 0:
				game_state.call("set_upgrade_level", "marble_tier", _tier_arg)
				main.get("wheel").call("refresh_marble")
			game_state.call("add_chips", 5000.0)
			_bets(["S17", "S17", "R", "S32", "E"])
			await _wait_seconds(0.8)
		"tooltip":
			game_state.call("add_chips", 900.0)
			_bets(["S17"])
			await _wait_seconds(0.4)
			var board: Control = main.get("bet_panel").get("board")
			board.call("_set_hover", "S17")
			await _wait_seconds(0.5)
		"spin_03", "spin_06", "spin_085":
			game_state.call("set_upgrade_level", "marble_count", 2)
			if _tier_arg >= 0:
				game_state.call("set_upgrade_level", "marble_tier", _tier_arg)
				main.get("wheel").call("refresh_marble")
			_bets(["R", "S19", "O"])
			await _wait_seconds(0.5)
			_force([19])
			var fraction := {"spin_03": 0.3, "spin_06": 0.6, "spin_085": 0.85}[scenario] as float
			await _spin_and_seek(fraction)
		"normal":
			_bets(["R"])
			await _wait_seconds(0.4)
			_force([3])
			await _spin_to_result(0.35)
		"good":
			game_state.call("set_upgrade_level", "marble_count", 1)
			game_state.call("set_upgrade_level", "marble_tier", 2)
			_bets(["R", "B"])
			await _wait_seconds(0.4)
			_force([7])
			await _spin_to_result(0.3)
		"big":
			_bets(["S17"])
			await _wait_seconds(0.4)
			_force([17])
			await _spin_to_result(0.45)
		"jackpot":
			game_state.call("set_upgrade_level", "marble_count", 2)
			_bets(["S0", "S0", "R"])
			await _wait_seconds(0.4)
			_force([0])
			await _spin_to_result(1.1)
		"loss":
			_bets(["R"])
			await _wait_seconds(0.4)
			_force([2])
			await _spin_to_result(0.3)
		"near_miss":
			_bets(["S15"])
			await _wait_seconds(0.4)
			_force([32])
			await _spin_to_result(0.3)
		"no_chips":
			_bets(["R"])
			await _wait_seconds(0.4)
			game_state.call("spend_chips", 99.5)
			await _wait_seconds(0.15)
			main.call("request_spin")
			await _wait_seconds(0.12)
		"upgrade_tab":
			main.call("switch_panel", "upgrade")
			await _wait_seconds(0.4)
		"skilltree":
			main.call("_toggle_overlay", main.get("skill_overlay"))
			await _wait_seconds(0.4)
		"multi_ball":
			game_state.get("modifiers").call("add_modifier", "skill:double_ball", "extra_balls", 0, 1.0)
			_bets(["R"])
			await _wait_seconds(0.4)
			_force([5, 24])
			await _spin_to_result(0.3)
		"golden":
			game_state.call("set_upgrade_level", "golden_pocket", 3)
			var golden: Array = game_state.get("golden_pockets")
			_bets(["S%d" % int(golden[0])])
			await _wait_seconds(0.4)
			_force([int(golden[0])])
			await _spin_to_result(0.5)
		"golden_idle":
			game_state.call("set_upgrade_level", "golden_pocket", 4)
			await _wait_seconds(0.5)
		"marbles12":
			game_state.call("set_upgrade_level", "marble_count", 7)
			game_state.get("modifiers").call("add_modifier", "skill:extra_marbles", "marble_slots_bonus", 0, 4.0)
			game_state.call("add_chips", 100000.0)
			_bets(["S7", "S7", "S7", "S7", "S7", "R", "B", "O", "S0", "S36", "S22"])
			await _wait_seconds(0.9)
		"upgrade_early":
			_set_chips(140.0)
			await _upgrade_panel(0)
		"upgrade_mid":
			_set_floor(1)
			_levels({"marble_tier": 5, "marble_polish": 2, "bet_limit": 38, "marble_count": 4, "spin_speed": 6})
			_tier(5)
			_set_chips(3.4e9)
			await _upgrade_panel(2)
		"upgrade_late":
			_set_floor(4)
			_levels({"marble_tier": 13, "marble_polish": 5, "bet_limit": 412, "marble_count": 7, "spin_speed": 13, "golden_pocket": 3})
			_tier(13)
			_set_chips(4.2e33)
			await _upgrade_panel(1)
			var late_panel: Object = main.get("upgrade_panel")
			late_panel.call("scroll_to", 40.0, true)
			await _wait_seconds(0.1)
		"upgrade_tooltip":
			_set_chips(3200.0)
			_levels({"marble_tier": 1, "bet_limit": 4})
			_tier(1)
			await _upgrade_panel(2)
			await _hover_card("bet_limit")
		"upgrade_locked_tip":
			_set_chips(500.0)
			await _upgrade_panel(0)
			var locked_panel: Object = main.get("upgrade_panel")
			locked_panel.call("scroll_to", 100.0, true)
			await _wait_seconds(0.1)
			await _hover_card("golden_pocket")
		"promote_charge":
			await _promote(4, 5, 0.85)
		"promote_flash":
			await _promote(4, 5, 1.22)
		"promote_banner":
			await _promote(9, 10, 1.6)
		"promote_fly":
			await _promote(12, 13, 2.15)
		"golden_beam":
			_set_floor(2)
			_set_chips(1e6)
			await _wait_seconds(0.3)
			_buy("golden_pocket")
			await _wait_seconds(0.3)
		"golden_wheel":
			_set_floor(2)
			_levels({"golden_pocket": 4})
			_set_chips(1e6)
			await _wait_seconds(1.3)
		"slot_open":
			_set_chips(1000.0)
			await _wait_seconds(0.3)
			_buy("marble_count")
			await _wait_seconds(0.42)
		"trail_gold", "trail_cosmic", "trail_void":
			_tier({"trail_gold": 5, "trail_cosmic": 14, "trail_void": 13}[scenario] as int)
			_bets(["R"])
			await _wait_seconds(0.4)
			_force([19])
			main.call("request_spin")
			await _wait_seconds(1.35)
		"numbers_1e3":
			await _numbers(1e3)
		"numbers_1e15":
			await _numbers(1e15)
		"numbers_1e33":
			await _numbers(1e33)
		"numbers_1e60":
			await _numbers(1e60)
		"debug_panel":
			var input := InputEventKey.new()
			input.keycode = KEY_F9
			input.pressed = true
			root.push_input(input)
			await _wait_seconds(0.3)
		"tab_slide":
			_set_chips(900.0)
			main.call("switch_panel", "upgrade")
			await _wait_seconds(0.07)
		"tab_dot":
			_set_chips(900.0)
			await _wait_seconds(0.5)
		"settings_audio", "settings_display", "settings_game", "settings_accessibility", "settings_data":
			main.call("_toggle_overlay", main.get("settings_overlay"))
			var tab: String = {
				"settings_audio": "audio", "settings_display": "screen", "settings_game": "game",
				"settings_accessibility": "accessibility", "settings_data": "data",
			}[scenario]
			main.get("settings_overlay").call("select_tab", tab)
			await _wait_seconds(0.35)
		"pause_menu":
			main.call("_open_pause_menu")
			await _wait_seconds(0.3)
		"stats_screen":
			game_state.call("increment_stat", "total_spins", 128.0)
			game_state.call("increment_stat", "total_wins", 54.0)
			game_state.call("max_stat", "biggest_win", 48200.0)
			game_state.call("max_stat", "best_streak", 9.0)
			game_state.call("increment_stat", "straight_hits", 3.0)
			game_state.call("increment_stat", "loans_taken", 2.0)
			game_state.call("increment_stat", "total_earned", 96400.0)
			game_state.call("increment_stat", "play_time", 3.0 * 3600.0 + 12.0 * 60.0)
			var stats_results: Array[int] = [7, 7, 7, 22, 5]
			game_state.call("push_results", stats_results)
			main.call("_open_stats_screen")
			await _wait_seconds(1.7)
		"return_popup":
			var offline: Object = (load("res://scripts/core/offline_income.gd") as GDScript).new()
			offline.set("income", 2400.0)
			offline.set("elapsed_seconds", 3.0 * 3600.0 + 12.0 * 60.0)
			offline.set("capped_seconds", 2.0 * 3600.0)
			offline.set("eligible", true)
			offline.set("mode", 2)
			main.get("return_popup").call("open", offline)
			await _wait_seconds(1.7)
		"toast_recovered":
			root.get_node("EventBus").emit_signal("toast_requested", tr("TOAST_SAVE_RECOVERED"), "warning")
			await _wait_seconds(0.3)
		"colorblind":
			var cb_settings := root.get_node("SettingsManager")
			cb_settings.set("colorblind_assist", true)
			cb_settings.call("apply_all")
			game_state.call("set_upgrade_level", "marble_count", 1)
			_bets(["R", "S32"])
			await _wait_seconds(0.6)
		"baron_appear":
			_set_chips(0.0)
			game_state.call("check_bankruptcy")
			await _wait_seconds(3.2)
		"dialogue_baron":
			_set_chips(0.0)
			game_state.call("check_bankruptcy")
			await _wait_seconds(3.8)
		"contract":
			_set_chips(0.0)
			game_state.call("check_bankruptcy")
			await _wait_seconds(3.2)
			await _advance_dialogue(main.get("baron_loan_seq"))
			await _wait_seconds(0.6)
		"stamp":
			_set_chips(0.0)
			game_state.call("check_bankruptcy")
			await _wait_seconds(3.2)
			var stamp_seq: Object = main.get("baron_loan_seq")
			await _advance_dialogue(stamp_seq)
			await _wait_seconds(0.6)
			stamp_seq.get("contract").call("_on_sign_pressed")
			await _wait_seconds(0.55)
		# 아래 6종은 PenaltyManager.Kind(0 watcher·1 pickpocket·2 smoke·3 blur·4 seize·5 clover_fee) 를
		# 정수로 넘긴다(클래스 이름을 이 파일 안에서 직접 쓰면 -s 진입 스크립트 컴파일 시점에 autoload 가
		# 아직 없어 "GameState 를 찾을 수 없음" 오류가 남는다 — .call() 리플렉션으로 우회).
		"penalty_watcher":
			_set_chips(1e6)
			_set_debts([{"principal": 100.0, "remaining": 200.0}])
			game_state.get("penalty_manager").call("_apply", 0, 25.0)
			await _wait_seconds(3.0)
		"penalty_pickpocket":
			_set_chips(1e6)
			_set_debts([{"principal": 100.0, "remaining": 200.0}])
			game_state.get("penalty_manager").call("_apply", 1, 3.0)
			await _wait_seconds(0.2)
		"penalty_smoke":
			_set_chips(1e6)
			_set_debts([{"principal": 100.0, "remaining": 200.0}])
			game_state.get("penalty_manager").call("_apply", 2, 25.0)
			await _wait_seconds(1.0)
		"penalty_blur":
			_set_chips(1e6)
			_levels({"marble_count": 3})
			_bets(["S17", "R", "B"])
			_set_debts([{"principal": 100.0, "remaining": 200.0}])
			game_state.get("penalty_manager").call("_apply", 3, 25.0)
			await _wait_seconds(0.6)
		"penalty_seize":
			_set_chips(1e6)
			_levels({"marble_count": 3})
			_bets(["R", "B"])
			_set_debts([{"principal": 100.0, "remaining": 200.0}])
			game_state.get("penalty_manager").call("_apply", 4, 0.0)
			await _wait_seconds(0.3)
		"penalty_clover_fee":
			_set_chips(1e6)
			_set_debts([{"principal": 100.0, "remaining": 200.0}])
			game_state.get("penalty_manager").call("_apply", 5, 0.0)
			await _wait_seconds(0.3)
		"debt_panel":
			_set_chips(50000.0)
			_set_debts([{"principal": 1000.0, "remaining": 1500.0}, {"principal": 500.0, "remaining": 300.0}])
			await _wait_seconds(0.3)
			main.get("debt_panel").call("open")
			await _wait_seconds(0.3)
		"debt_paid":
			_set_chips(1e6)
			_set_debts([{"principal": 10.0, "remaining": 10.0}])
			game_state.call("repay_all", 0)
			await _wait_seconds(3.5)
		"floor_b1":
			await _wait_seconds(0.6)
		"floor_1f":
			_set_floor(1)
			await _wait_seconds(0.6)
		"floor_2f":
			_set_floor(2)
			await _wait_seconds(0.6)
		"floor_3f":
			_set_floor(3)
			await _wait_seconds(0.6)
		"floor_ph":
			_set_floor(4)
			await _wait_seconds(0.6)
		"elevator_ready":
			_set_chips(1e6)
			await _wait_seconds(0.6)
		"elevator_confirm":
			_set_chips(1e6)
			await _wait_frames(1)
			main.get("floor_confirm_popup").call("open")
			await _wait_seconds(0.3)
		"elevator_cutscene_close":
			_start_elevator_cutscene()
			await _wait_seconds(0.3)
		"elevator_cutscene_tick":
			_start_elevator_cutscene()
			await _wait_seconds(0.9)
		"elevator_cutscene_title":
			_start_elevator_cutscene()
			await _wait_seconds(2.3)
		"achievement_toast":
			root.get_node("EventBus").emit_signal("achievement_unlocked", "marble_gold")
			await _wait_seconds(0.5)
		"achievement_screen":
			var unlocked: Array[String] = ["first_spin", "first_straight", "zero_hit", "win_streak_10", "first_loan", "floor_reached_2f", "marble_gold", "first_fever", "offline_8h", "velvet_all_lines"]
			game_state.set("unlocked_achievements", unlocked)
			main.call("_open_achievement_screen")
			await _wait_seconds(0.3)
		"velvet_intro":
			_set_floor(4)
			await _wait_seconds(1.0)
		"acquisition_button":
			_set_floor(4)
			_set_chips(1e34)
			await _wait_seconds(0.6)
		"ending_last_hand":
			_set_floor(4)
			_set_chips(1e34)
			main.call("_on_acquisition_pressed")
			await _wait_seconds(0.8)
		"ending_final_spin":
			_set_floor(4)
			_set_chips(1e34)
			main.call("_on_acquisition_pressed")
			await _wait_seconds(0.7)  # DIM_IN(0.6초)이 끝나 대사창이 열릴 때까지 기다린다
			await _advance_dialogue(main.get("ending_sequence"))
			await _wait_seconds(2.5)
		"ending_signing":
			_set_floor(4)
			_set_chips(1e34)
			main.call("_on_acquisition_pressed")
			await _wait_seconds(0.7)  # DIM_IN(0.6초)이 끝나 대사창이 열릴 때까지 기다린다
			await _advance_dialogue(main.get("ending_sequence"))
			await _wait_seconds(11.5)
		"ending_epilogue":
			_set_floor(4)
			_set_chips(1e34)
			main.call("_on_acquisition_pressed")
			await _wait_seconds(0.7)  # DIM_IN(0.6초)이 끝나 대사창이 열릴 때까지 기다린다
			await _advance_dialogue(main.get("ending_sequence"))
			await _wait_seconds(11.5)
			main.get("ending_sequence").get("contract").call("_on_sign_pressed")
			await _wait_seconds(1.4)
		"ending_credits":
			_set_floor(4)
			_set_chips(1e34)
			main.call("_on_acquisition_pressed")
			await _wait_seconds(0.7)  # DIM_IN(0.6초)이 끝나 대사창이 열릴 때까지 기다린다
			await _advance_dialogue(main.get("ending_sequence"))
			await _wait_seconds(11.5)
			var deed: Object = main.get("ending_sequence").get("contract")
			deed.call("_on_sign_pressed")
			await _wait_seconds(1.4)
			for i in 3:
				await _advance_dialogue(main.get("ending_sequence"))
			await _wait_seconds(2.5)
		_:
			push_error("capture: 모르는 시나리오 %s" % scenario)
	await _save_shot(scenario, lang)


## 뷰포트를 640×360 원본 + 3배 확대본으로 저장한다(모든 시나리오 공용, 8단계에서 분리).
func _save_shot(scenario: String, lang: String) -> void:
	await _wait_frames(1)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var base := "%s/%s_%s" % [out_dir, scenario, lang]
	image.save_png(base + ".png")
	var big := image.duplicate() as Image
	big.resize(image.get_width() * UPSCALE, image.get_height() * UPSCALE, Image.INTERPOLATE_NEAREST)
	big.save_png(base + "_x3.png")
	print("captured ", base)


## 8단계: 스플래시·타이틀·인트로 컷신 시나리오(Main.tscn 을 쓰지 않는다).
func _capture_title_flow(scenario: String, lang: String) -> void:
	match scenario:
		"splash":
			await _fresh_title("res://scenes/main/SplashScreen.tscn")
			await _wait_seconds(0.3)
		"title":
			await _fresh_title("res://scenes/main/TitleScreen.tscn")
			await _wait_seconds(1.3)
		"title_continue":
			game_state.call("reset")
			game_state.set("floor_index", 1)
			game_state.call("add_chips", 5000.0)
			save_manager.call("save_game")
			await _fresh_title("res://scenes/main/TitleScreen.tscn", true)
			await _wait_seconds(1.3)
		"title_new_game_confirm":
			game_state.call("reset")
			save_manager.call("save_game")
			await _fresh_title("res://scenes/main/TitleScreen.tscn", true)
			await _wait_seconds(1.3)
			main.call("_on_new_game_pressed")
			await _wait_seconds(0.2)
		"title_settings":
			await _fresh_title("res://scenes/main/TitleScreen.tscn")
			main.call("_toggle_overlay", main.get("_settings_overlay"))
			await _wait_seconds(0.3)
		"title_achievements":
			await _fresh_title("res://scenes/main/TitleScreen.tscn")
			main.call("_toggle_overlay", main.get("_achievement_overlay"))
			await _wait_seconds(0.3)
		"title_credits":
			await _fresh_title("res://scenes/main/TitleScreen.tscn")
			main.call("_toggle_overlay", main.get("_credits_overlay"))
			await _wait_seconds(0.3)
		"intro_alley":
			await _fresh_title("res://scenes/main/TitleScreen.tscn")
			main.call("_on_new_game_pressed")
			await _wait_seconds(0.6)
		"intro_marble":
			await _fresh_title("res://scenes/main/TitleScreen.tscn")
			main.call("_on_new_game_pressed")
			await _wait_seconds(4.4)
		"intro_door":
			await _fresh_title("res://scenes/main/TitleScreen.tscn")
			main.call("_on_new_game_pressed")
			await _wait_seconds(8.2)
		_:
			push_error("capture: 모르는 타이틀 시나리오 %s" % scenario)
	await _save_shot(scenario, lang)
