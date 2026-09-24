extends "res://tests/lib/test_case.gd"
## BaronLoanSequence: 파산 컷신 전체 흐름(걷기→대사→계약서→서명→인사→퇴장)이 끝까지 이어지는지 검증.

const STEP := 0.05
const MAX_TIME := 30.0

var seq: BaronLoanSequence


func before_each() -> void:
	super.before_each()
	seq = BaronLoanSequence.new()
	tree.root.add_child(seq)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	seq.free()
	seq = null


## 오케스트레이터 자신과 하위 배우(baron/dialogue/contract)를 함께 한 프레임씩 진행한다
## (실제 게임에서는 씬 트리가 전부 자동으로 처리하지만, 이 테스트는 수동으로 틱을 준다).
func _tick(dt: float = STEP) -> void:
	seq._process(dt)
	seq.baron._process(dt)
	seq.dialogue._process(dt)
	seq.contract._process(dt)


func _run_until(condition: Callable, advance_dialogue: bool = true) -> float:
	var t := 0.0
	while not condition.call() and t < MAX_TIME:
		if advance_dialogue and seq.dialogue.is_open() and not seq.dialogue._typing:
			seq.advance_input()
		_tick()
		t += STEP
	return t


func test_full_loan_flow_reaches_contract_and_signs() -> void:
	var signed := watch(seq.signed)
	seq.play({"type": "loan", "principal": 100.0, "repay": 200.0, "merged": false})
	check(seq.is_playing(), "시작")
	_run_until(func() -> bool: return seq.contract.visible)
	check_eq(seq._phase, BaronLoanSequence.Phase.CONTRACT, "계약서 단계 도달")
	check(seq.dialogue.is_open() == false, "대사창은 닫힘")
	seq.contract._on_sign_pressed()
	_run_until(func() -> bool: return signed.size() > 0)
	check_eq(signed.size(), 1, "signed 발행")
	check_near(float(signed[0][0]), 100.0, 1e-6, "대출액 전달")
	check_near(float(signed[0][1]), 200.0, 1e-6, "상환액 전달")


func test_full_loan_flow_finishes_and_walks_out() -> void:
	var finished := watch(seq.finished)
	seq.play({"type": "loan", "principal": 50.0, "repay": 100.0, "merged": false})
	_run_until(func() -> bool: return seq.contract.visible)
	seq.contract._on_sign_pressed()
	_run_until(func() -> bool: return finished.size() > 0)
	check_eq(finished.size(), 1, "finished 발행")
	check(not seq.is_playing(), "완전히 닫힘")
	check_near(seq.baron.position.x, BaronLoanSequence.BARON_ENTER_X, 1.0, "퇴장 지점까지 걸어나감")


func test_second_loan_uses_repeat_line() -> void:
	GameState.increment_stat(GameState.STAT_LOANS_TAKEN, 1.0)  # 이미 1건 대출한 상태를 흉내
	seq.play({"type": "loan", "principal": 10.0, "repay": 20.0, "merged": false})
	_run_until(func() -> bool: return seq.dialogue.is_open(), false)
	check_eq(seq.dialogue._name_label.text, tr("NPC_RATCHET"), "화자 표시")


func test_merged_loan_uses_overflow_line() -> void:
	seq.play({"type": "loan", "principal": 10.0, "repay": 20.0, "merged": true})
	_run_until(func() -> bool: return seq.dialogue.is_open(), false)
	check_eq(seq.dialogue._text_label.text, tr("BARON_LOAN_OVERFLOW"), "합산 전용 대사")
