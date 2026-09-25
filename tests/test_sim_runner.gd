extends "res://tests/lib/test_case.gd"
## 9단계 밸런스 시뮬레이터(tools/sim/sim_runner.gd)의 재생 로직. 시뮬레이터 자체는 tools/ 아래라 게임
## 코드는 아니지만, 실제 GameState/UpgradeService/FloorService 를 직접 조작하는 로직이라 회귀를 잡아야
## 한다(CLAUDE.md "새 로직에는 테스트를 함께 추가한다"). class_name 이 없어(res://tools/sim/balance_sim.gd
## 머리말 참고) load().new() 로 불러온다.

const RUNNER_PATH := "res://tools/sim/sim_runner.gd"
const SEED := 20260925


func _runner() -> RefCounted:
	return load(RUNNER_PATH).new()


func test_run_returns_expected_shape() -> void:
	var result: Dictionary = _runner().run(SEED, 0.25, 0.02, GameState.SmartBettingStrategy.STABLE)
	for key in ["seed", "spins", "clovers", "chips", "loans_taken", "floor_index", "finished", "ending_minutes", "ending_target_minutes", "floors"]:
		check(result.has(key), "결과에 %s 키가 있다" % key)
	check_eq(int(result["seed"]), SEED, "시드 그대로 반환")
	check(int(result["spins"]) > 0, "스핀이 1회 이상 진행됨")
	var floors: Array = result["floors"]
	check_eq(floors.size(), GameData.floors().size(), "층 수만큼 보고")
	var b1: Dictionary = floors[0]
	check_eq(String(b1["id"]), "b1", "0번째는 B1")
	check_eq(float(b1["actual_minutes"]), 0.0, "B1 은 시작이라 0분")


func test_max_hours_safety_stop_is_reported_unfinished() -> void:
	# 0.001시간(3.6초)이면 몇 스핀 만에 안전장치(max_hours)에 걸려 엔딩을 못 본다 — 무한 루프 없이 끝나는지 확인.
	var result: Dictionary = _runner().run(SEED, 0.25, 0.001, GameState.SmartBettingStrategy.STABLE)
	check(not bool(result["finished"]), "이렇게 짧으면 엔딩까지 못 감")
	check_eq(float(result["ending_minutes"]), -1.0, "엔딩 미도달 표시")


func test_same_seed_is_deterministic() -> void:
	var a: Dictionary = _runner().run(SEED, 0.25, 0.02, GameState.SmartBettingStrategy.STABLE)
	var b: Dictionary = _runner().run(SEED, 0.25, 0.02, GameState.SmartBettingStrategy.STABLE)
	check_eq(int(a["spins"]), int(b["spins"]), "같은 시드면 스핀 수도 같다")
	check_eq(int(a["clovers"]), int(b["clovers"]), "같은 시드면 클로버도 같다")
	check_rel(float(a["chips"]), float(b["chips"]), 1e-9, "같은 시드면 칩도 같다")


func test_survives_bet_limit_soft_lock_regression() -> void:
	# 직접 발견한 막힘(GDD 24장): 업그레이드(특히 bet_limit)를 사고 나서 min_bet 조차 못 내는 상태가 되면
	# check_bankruptcy() 는 스핀이 "끝나야" 도는데 스핀을 아예 시작 못 해 구제도 못 받는다 — 수정 전에는
	# 이 시나리오에서 20~30스핀 만에 멈췄다. 3분(0.05시간) 동안 그보다 훨씬 많이 진행되는지로 회귀를 잡는다.
	var result: Dictionary = _runner().run(SEED, 0.5, 0.05, GameState.SmartBettingStrategy.STABLE)
	check(int(result["spins"]) > 15, "3분 동안 15스핀보다 훨씬 많이 진행됨(실제 %d)" % int(result["spins"]))
