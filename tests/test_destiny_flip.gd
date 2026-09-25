extends "res://tests/lib/test_case.gd"
## 운명 뒤집기(6단계, Y8): 전패했을 때만 옆 포켓으로 재판정을 시도하고, 재판정한 결과가 원래보다
## 나쁘면 절대 채택하지 않는다("유리할 때만" 재판정, spin_controller.gd _resolve_with_specials 참고).

var controller: SpinController


func before_each() -> void:
	super.before_each()
	controller = SpinController.new()
	GameState.modifiers.add_modifier("skill:y8", StatModifiers.DESTINY_FLIP_CHANCE, StatModifiers.Op.ADD, 1.0)


func after_each() -> void:
	GameState.reset()
	super.after_each()


## 완전히 이긴 스핀은 애초에 재판정 대상이 아니다(tentative.any_win() 이 true).
func test_winning_spin_is_never_flipped() -> void:
	var bets: Array[Bet] = [Bet.straight(7, 10.0)]
	var results: Array[int] = [7]
	var outcome := controller._resolve_with_specials(bets, results, SpinContext.new())
	check_eq(outcome.destiny_flip_from, -1, "이미 이겼으면 뒤집지 않는다")
	check_eq(outcome.results, [7] as Array[int], "결과도 그대로")


## 전패 스핀 다수를 재판정했을 때, 최종 반환액이 원래(뒤집기 없는) 반환액보다 작아지는 일이 없어야 한다.
func test_flip_never_reduces_return_across_many_losses() -> void:
	var trials := 500
	for i in trials:
		var number := i % RouletteRules.POCKET_COUNT
		var losing_result := (number + 18) % RouletteRules.POCKET_COUNT  # 항상 number 와 다른 칸(전패 보장)
		var bets: Array[Bet] = [Bet.straight(number, 10.0)]
		var results: Array[int] = [losing_result]
		var context := SpinContext.new()
		var original_return := RouletteRules.resolve(bets, results, context).total_return
		var outcome := controller._resolve_with_specials(bets, results, context)
		check(outcome.total_return >= original_return, "시행 %d: 재판정 후 반환액(%.1f) >= 원래(%.1f)" % [i, outcome.total_return, original_return])


## destiny_flip_from 이 설정됐으면 반드시 원래 포켓의 이웃으로만 바뀐다.
func test_flip_target_is_always_a_neighbor() -> void:
	var flips := 0
	for i in 300:
		var number := i % RouletteRules.POCKET_COUNT
		var losing_result := (number + 18) % RouletteRules.POCKET_COUNT
		var bets: Array[Bet] = [Bet.straight(number, 10.0)]
		var results: Array[int] = [losing_result]
		var outcome := controller._resolve_with_specials(bets, results, SpinContext.new())
		if outcome.destiny_flip_from >= 0:
			flips += 1
			var neighbors := RouletteRules.neighbors(outcome.destiny_flip_from)
			check(neighbors.has(outcome.results[0]), "뒤집힌 결과는 원래 포켓의 이웃이어야 한다")
	check(flips > 0, "500회 중 최소 한 번은 뒤집기가 실제로 일어나야 통계적으로 의미 있다")


func test_zero_chance_never_flips() -> void:
	GameState.modifiers.remove_source("skill:y8")
	var bets: Array[Bet] = [Bet.straight(7, 10.0)]
	var results: Array[int] = [12]
	var outcome := controller._resolve_with_specials(bets, results, SpinContext.new())
	check_eq(outcome.destiny_flip_from, -1, "확률 0이면 절대 뒤집지 않는다")
