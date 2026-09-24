extends SceneTree
## 자동 스크린샷 검수 도구. 창 모드로 메인 씬을 띄우고, 지정한 상태를 강제로 만든 뒤
## 뷰포트(640×360 원본)와 3배 확대본을 tools/capture/out/ 에 저장한다.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 -s tools/capture/capture.gd -- scenario=all lang=ko
##   (Windows: Godot_v4.3-stable_win64_console.exe -s tools/capture/capture.gd -- scenario=idle lang=en)
##
## 인자: scenario=<이름|all|쉼표 목록>  lang=ko|en|both  out=<폴더>
## 시나리오: idle, betting, tooltip, spin_03, spin_06, spin_085, normal, good, big, jackpot, loss, near_miss,
##           no_chips, upgrade_tab, skilltree, multi_ball

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const DEFAULT_OUT := "res://tools/capture/out"
const UPSCALE := 3
const SEED := 20260924
const SCENARIOS: Array[String] = [
	"idle", "betting", "tooltip", "spin_03", "spin_06", "spin_085", "normal", "good", "big", "jackpot",
	"loss", "near_miss", "no_chips", "upgrade_tab", "skilltree", "multi_ball", "golden", "golden_idle", "marbles12",
]

var game_state: Node
var rng_service: Node
var main: Node
var out_dir: String = DEFAULT_OUT


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
			game_state.set("marble_tier", 2)
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
