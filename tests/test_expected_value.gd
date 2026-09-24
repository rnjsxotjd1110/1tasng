extends "res://tests/lib/test_case.gd"
## 시드 고정 100만 스핀 기대값. 이론값: 나무 18/37×2 = 0.9730, 돌 ×1.5 = 1.4595

const SPINS := 1_000_000
const SEED := 20260924


func _simulate(marble_mult: float) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var context := SpinContext.new()
	context.marble_mult = marble_mult
	var bets: Array[Bet] = [Bet.red(1.0)]
	var results: Array[int] = [0]
	var total_bet := 0.0
	var total_return := 0.0
	for i in SPINS:
		results[0] = rng.randi_range(0, RouletteRules.POCKET_COUNT - 1)
		var outcome := RouletteRules.resolve(bets, results, context)
		total_bet += outcome.total_bet
		total_return += outcome.total_return
	return total_return / total_bet


func test_wood_red_expected_value() -> void:
	var marble := GameData.marble(0)
	check_near(_simulate(marble.mult), 0.973, 0.005, "나무 구슬 빨강 기대값")


func test_stone_red_expected_value() -> void:
	var marble := GameData.marble(1)
	check_near(_simulate(marble.mult), 1.46, 0.01, "돌 구슬 빨강 기대값")


func test_rng_service_distribution() -> void:
	RngService.set_seed(SEED)
	var counts: Array[int] = []
	counts.resize(RouletteRules.POCKET_COUNT)
	var rolls := 370_000
	for i in rolls:
		counts[RngService.consume_next()] += 1
	var expected := float(rolls) / RouletteRules.POCKET_COUNT
	for number in RouletteRules.POCKET_COUNT:
		check_near(counts[number], expected, expected * 0.05, "포켓 %d 빈도" % number)
