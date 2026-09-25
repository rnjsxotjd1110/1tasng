extends "res://tests/lib/test_case.gd"
## BaronPayoffSequence: 완납 컷신(걷기→대사→인사→클로버→퇴장)이 끝까지 이어지는지 검증.

const STEP := 0.05
const MAX_TIME := 20.0

var seq: BaronPayoffSequence


func before_each() -> void:
	super.before_each()
	seq = BaronPayoffSequence.new()
	tree.root.add_child(seq)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	seq.free()
	seq = null


func _tick(dt: float = STEP) -> void:
	seq._process(dt)
	seq.baron._process(dt)
	seq.dialogue._process(dt)


func _run_until(condition: Callable) -> float:
	var t := 0.0
	while not condition.call() and t < MAX_TIME:
		if seq.dialogue.is_open() and not seq.dialogue._typing:
			seq.advance_input()
		_tick()
		t += STEP
	return t


func test_payoff_flow_reaches_clover_moment_then_finishes() -> void:
	var clover := watch(seq.clover_moment)
	var finished := watch(seq.finished)
	seq.play()
	check(seq.is_playing(), "시작")
	_run_until(func() -> bool: return clover.size() > 0)
	check_eq(clover.size(), 1, "clover_moment 발행")
	check_eq(seq.baron.anim, BaronRatchet.Anim.TIP_HAT, "인사 자세를 지나옴")
	_run_until(func() -> bool: return finished.size() > 0)
	check_eq(finished.size(), 1, "finished 발행")
	check(not seq.is_playing(), "퇴장 완료")


func test_dialogue_uses_debt_paid_key() -> void:
	seq.play()
	var t := 0.0
	while not seq.dialogue.is_open() and t < MAX_TIME:
		_tick()
		t += STEP
	check(DialogueData.has("debt_paid"), "전제: 키 존재")
	check_eq(seq.dialogue._name_label.text, tr("NPC_RATCHET"), "화자 표시")
