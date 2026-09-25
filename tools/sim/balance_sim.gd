extends SceneTree
## 9단계 밸런스 시뮬레이터. 실제 게임 로직(GameState/UpgradeService/FloorService/RouletteRules 등)을 그대로
## 돌려 "성실히 플레이하는 유저"를 화면 없이 순식간에 재생시키고, 층 도달 시간과 클로버 획득량이 GDD 7장의
## 목표(층별 target_minutes, 엔딩 약 5시간)에 맞는지 잰다. 실제 대기(await) 없이 동기 실행이라 스핀 수천 번이
## 실시간 몇 초 안에 끝난다(각 스핀의 "시간"은 GameState._process() 에 실제 스핀 시간만큼의 delta 를 직접
## 먹여서 흐르게 한다 — tests/test_*.gd 가 애니메이션 노드에 `_process(dt)` 를 직접 부르는 것과 같은 패턴).
##
##   godot --headless -s tools/sim/balance_sim.gd
##   godot --headless -s tools/sim/balance_sim.gd -- runs=10 upgrade_ratio=0.6 strategy=aggressive seed=1
##
## 인자: runs=<횟수, 기본 5>  seed=<정수, 생략하면 실행마다 다른 시드를 자동으로 씀>
##       upgrade_ratio=<0~1, 기본 0.25 — 9단계 튜닝으로 고른 값, sim_runner.gd 머리말 참고>
##       max_hours=<시간 초과 안전장치, 기본 20>  strategy=stable|aggressive|hot|martingale(기본 stable)
##
## 실행 로직은 res://tools/sim/sim_runner.gd 에 있다 — 이 진입 스크립트는 오토로드가 준비되기 전에 컴파일돼
## GameState 등을 정적으로 못 쓰므로(8단계 마무리에서 실측한 문제, GDD 23장), 인자 파싱과 결과 출력만 하고
## 실제 게임 로직은 첫 프레임 뒤 동적으로 불러온 스크립트 안에서만 건드린다.

const RUNNER_PATH := "res://tools/sim/sim_runner.gd"
const DEFAULT_RUNS := 5
## 9단계 튜닝으로 고른 값(0.5 는 B1→1F 만으로 5배 가까이 빨랐다) — sim_runner.gd 머리말의 "9단계 튜닝 기록" 참고.
const DEFAULT_UPGRADE_RATIO := 0.25
const DEFAULT_MAX_HOURS := 20.0
const DEFAULT_SEED_BASE := 20260925
## GameState.SmartBettingStrategy 값(KEEP=0 은 시뮬레이터에서 쓰지 않는다) — 진입 스크립트에서 그 열거형
## 자체를 참조하면 안 되므로(오토로드 GameState 소속) 정수를 그대로 옮겨 적는다.
const STRATEGY_NAMES := {
	"stable": 1, "aggressive": 2, "hot": 3, "hot_numbers": 3, "martingale": 4,
}


func _initialize() -> void:
	# _initialize 시점에는 오토로드의 _ready 가 아직 실행되지 않았다(tests/run_tests.gd 와 같은 이유). 첫 프레임에서 실행한다.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _args() -> Dictionary:
	var args := {
		"runs": DEFAULT_RUNS, "upgrade_ratio": DEFAULT_UPGRADE_RATIO, "max_hours": DEFAULT_MAX_HOURS,
		"seed": -1, "strategy": "stable",
	}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	return args


func _run() -> void:
	var args := _args()
	var runs := int(args["runs"])
	var upgrade_ratio := float(args["upgrade_ratio"])
	var max_hours := float(args["max_hours"])
	var seed_arg := int(args["seed"])
	var strategy_name := String(args["strategy"]).to_lower()
	var strategy: int = STRATEGY_NAMES.get(strategy_name, 1)
	var runner: RefCounted = load(RUNNER_PATH).new()
	var results: Array[Dictionary] = []
	for i in runs:
		var seed_value := seed_arg if seed_arg >= 0 else DEFAULT_SEED_BASE + i
		results.append(runner.call("run", seed_value, upgrade_ratio, max_hours, strategy) as Dictionary)
	_print_report(results, strategy_name, upgrade_ratio)
	var all_finished := true
	for result in results:
		if not bool(result["finished"]):
			all_finished = false
	quit(0 if all_finished else 1)


func _print_report(results: Array[Dictionary], strategy_name: String, upgrade_ratio: float) -> void:
	print("=== HOUSE EDGE 9단계 밸런스 시뮬레이션 ===")
	print("전략=%s  업그레이드 예산 비율=%.2f  실행 횟수=%d" % [strategy_name, upgrade_ratio, results.size()])
	print("")
	for result in results:
		print("seed=%d  스핀=%d  클로버=%d개  대출=%d건  최종 층 인덱스=%d" % [
			int(result["seed"]), int(result["spins"]), int(result["clovers"]),
			int(result["loans_taken"]), int(result["floor_index"])])
		var floors: Array = result["floors"]
		for entry: Dictionary in floors:
			var target := float(entry["target_minutes"])
			var actual := float(entry["actual_minutes"])
			var id := String(entry["id"])
			if id == "b1":
				continue
			if actual < 0.0:
				print("  %-3s  도달 못함(목표 %.0f분)" % [id, target])
			else:
				print("  %-3s  %7.1f분  (목표 %6.1f분, 차이 %+.1f분)" % [id, actual, target, actual - target])
		var ending: float = result["ending_minutes"]
		var ending_target: float = result["ending_target_minutes"]
		if ending < 0.0:
			print("  엔딩  도달 못함(목표 %.0f분)" % ending_target)
		else:
			print("  엔딩  %7.1f분  (목표 %6.1f분, 차이 %+.1f분)" % [ending, ending_target, ending - ending_target])
		print("")
	_print_averages(results)


func _print_averages(results: Array[Dictionary]) -> void:
	if results.is_empty():
		return
	print("--- 평균(%d회) ---" % results.size())
	var floor_count: int = (results[0]["floors"] as Array).size()
	for i in range(1, floor_count):
		var sum := 0.0
		var reached := 0
		var id := ""
		var target := 0.0
		for result in results:
			var entry: Dictionary = (result["floors"] as Array)[i]
			id = String(entry["id"])
			target = float(entry["target_minutes"])
			var actual := float(entry["actual_minutes"])
			if actual >= 0.0:
				sum += actual
				reached += 1
		if reached > 0:
			print("  %-3s  평균 %7.1f분 (%d/%d 도달, 목표 %.0f분)" % [id, sum / reached, reached, results.size(), target])
		else:
			print("  %-3s  도달한 실행 없음(목표 %.0f분)" % [id, target])
	var ending_sum := 0.0
	var ending_reached := 0
	var clover_sum := 0.0
	var ending_target := 0.0
	for result in results:
		clover_sum += float(int(result["clovers"]))
		ending_target = float(result["ending_target_minutes"])
		var ending: float = result["ending_minutes"]
		if ending >= 0.0:
			ending_sum += ending
			ending_reached += 1
	if ending_reached > 0:
		print("  엔딩  평균 %7.1f분 (%d/%d 도달, 목표 %.0f분)" % [ending_sum / ending_reached, ending_reached, results.size(), ending_target])
	else:
		print("  엔딩  도달한 실행 없음(목표 %.0f분)" % ending_target)
	print("  클로버 평균 획득량 %.1f개(목표 약 230개)" % (clover_sum / results.size()))
