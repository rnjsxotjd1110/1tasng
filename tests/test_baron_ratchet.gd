extends "res://tests/lib/test_case.gd"

const STEP := 0.05

var baron: BaronRatchet


func before_each() -> void:
	super.before_each()
	baron = BaronRatchet.new()
	tree.root.add_child(baron)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	baron.free()
	baron = null


func test_walk_to_moves_and_arrives() -> void:
	baron.position.x = 700.0
	var arrived := watch(baron.arrived)
	baron.walk_to(500.0)
	check(baron.is_walking(), "걷는 중")
	check(baron.facing_left, "왼쪽으로 걷는 방향")
	var t := 0.0
	while baron.is_walking() and t < 10.0:
		baron._process(STEP)
		t += STEP
	check_eq(baron.position.x, 500.0, "목표 지점 정확히 도착")
	check_eq(arrived.size(), 1, "arrived 발행")
	check_eq(baron.anim, BaronRatchet.Anim.IDLE, "도착 후 대기")


func test_walk_right_faces_right() -> void:
	baron.position.x = 100.0
	baron.walk_to(300.0)
	check(not baron.facing_left, "오른쪽으로 걸으면 반전 안 함")


func test_looping_animation_cycles_frames() -> void:
	baron.play(BaronRatchet.Anim.IDLE, true)
	var seen: Dictionary = {}
	for i in 40:
		baron._process(STEP)
		seen[baron._frame] = true
	check(seen.size() > 1, "여러 프레임을 순환")
	check(seen.keys().all(func(f: int) -> bool: return f < BaronRatchet.FRAME_COUNT[BaronRatchet.Anim.IDLE]), "범위 안")


func test_non_looping_gesture_holds_last_frame_and_signals() -> void:
	var finished := watch(baron.gesture_finished)
	baron.play(BaronRatchet.Anim.TIP_HAT, false)
	for i in 30:
		baron._process(STEP)
	check_eq(finished.size(), 1, "gesture_finished 1회")
	check_eq(baron._frame, BaronRatchet.FRAME_COUNT[BaronRatchet.Anim.TIP_HAT] - 1, "마지막 프레임 유지")
	var frame_before := baron._frame
	baron._process(1.0)
	check_eq(baron._frame, frame_before, "더 진행하지 않음")
