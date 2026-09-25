extends "res://tests/lib/test_case.gd"
## EndingSequence: 벨벳 대사 → 최후의 스핀 → 골드 웨이브 → 서명 → 에필로그 → 네온 → credits_ready 전체 흐름.
## wheel 없이(=null) 진행하면 FINAL_SPIN 을 즉시 건너뛴다(대부분의 테스트는 그걸로 충분).

const STEP := 0.05
const MAX_TIME := 30.0
const WheelScene := preload("res://scenes/roulette/RouletteWheel.tscn")

var seq: EndingSequence


func before_each() -> void:
	super.before_each()
	seq = EndingSequence.new()
	tree.root.add_child(seq)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	seq.free()
	seq = null


func _tick(dt: float = STEP) -> void:
	seq._process(dt)
	seq.dialogue._process(dt)
	seq.contract._process(dt)
	if seq.wheel != null:
		seq.wheel._process(dt)


func _run_until(condition: Callable) -> float:
	var t := 0.0
	while not condition.call() and t < MAX_TIME:
		if seq.dialogue.is_open() and not seq.dialogue._typing:
			seq.advance_input()
		_tick()
		t += STEP
	return t


func test_play_starts_dim_in_then_last_hand_dialogue() -> void:
	seq.play()
	check(seq.is_playing(), "시작")
	_run_until(func() -> bool: return seq.dialogue.is_open())
	check_eq(seq._phase, EndingSequence.Phase.LAST_HAND, "벨벳의 마지막 대사 단계")
	check_eq(seq.dialogue._name_label.text, tr("NPC_VELVET"), "화자는 벨벳")


func test_flow_without_wheel_reaches_signing() -> void:
	seq.play()
	_run_until(func() -> bool: return seq.contract.visible)
	check_eq(seq._phase, EndingSequence.Phase.SIGNING, "휠 없이도 서명 단계까지 도달")


func test_final_spin_waits_for_wheel_to_stop() -> void:
	seq.wheel = WheelScene.instantiate()
	tree.root.add_child(seq.wheel)
	seq.play()
	_run_until(func() -> bool: return seq._phase == EndingSequence.Phase.FINAL_SPIN)
	check(seq.wheel.spinning, "휠이 실제로 돈다")
	_run_until(func() -> bool: return not seq.wheel.spinning)
	_tick()
	check(seq._phase != EndingSequence.Phase.FINAL_SPIN, "휠이 멈추면 다음 단계로")
	seq.wheel.free()


func test_signing_leads_to_epilogue_chain_and_neon() -> void:
	seq.play()
	_run_until(func() -> bool: return seq.contract.visible)
	seq.contract._on_sign_pressed()
	_run_until(func() -> bool: return seq._phase == EndingSequence.Phase.EPILOGUE_VELVET and seq.dialogue.is_open())
	check_eq(seq.dialogue._name_label.text, tr("NPC_VELVET"), "벨벳 에필로그")
	_run_until(func() -> bool: return seq._phase == EndingSequence.Phase.EPILOGUE_LUCY and seq.dialogue.is_open())
	check_eq(seq.dialogue._name_label.text, tr("NPC_LUCY"), "루시 에필로그")
	_run_until(func() -> bool: return seq._phase == EndingSequence.Phase.EPILOGUE_BARON and seq.dialogue.is_open())
	check_eq(seq.dialogue._name_label.text, tr("NPC_RATCHET"), "남작 에필로그")


func test_full_flow_emits_credits_ready_and_closes() -> void:
	var ready := watch(seq.credits_ready)
	seq.play()
	_run_until(func() -> bool: return seq.contract.visible)
	seq.contract._on_sign_pressed()
	_run_until(func() -> bool: return ready.size() > 0)
	check_eq(ready.size(), 1, "credits_ready 1회 발행")
	check(not seq.is_playing(), "시퀀스 자체는 닫힘")


func test_landing_is_safe_without_shaker_or_flash() -> void:
	seq.shaker = null
	seq.flash = null
	seq.play()
	_run_until(func() -> bool: return seq.contract.visible)
	check_eq(seq._phase, EndingSequence.Phase.SIGNING, "shaker·flash 가 없어도 죽지 않고 진행")
