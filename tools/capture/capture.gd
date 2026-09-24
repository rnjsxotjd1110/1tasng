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
]
const UPGRADE_SERVICE := "res://scripts/core/upgrade_service.gd"

var game_state: Node
var rng_service: Node
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
	main = load(MAIN_SCENE).instantiate()
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


func _set_floor(index: int) -> void:
	game_state.set("floor_index", index)
	root.get_node("EventBus").emit_signal("floor_changed", index)


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
	await _wait_seconds(0.3)


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
	await _fresh()
	match scenario:
		"idle":
			await _wait_seconds(0.6)
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
			await _wait_seconds(0.3)
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
		_:
			push_error("capture: 모르는 시나리오 %s" % scenario)
	await _wait_frames(1)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var base := "%s/%s_%s" % [out_dir, scenario, lang]
	image.save_png(base + ".png")
	var big := image.duplicate() as Image
	big.resize(image.get_width() * UPSCALE, image.get_height() * UPSCALE, Image.INTERPOLATE_NEAREST)
	big.save_png(base + "_x3.png")
	print("captured ", base)
