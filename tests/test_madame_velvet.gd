extends "res://tests/lib/test_case.gd"
## MadameVelvet: 반복 애니메이션 순환, 제스처(와인잔·손짓·박수)는 마지막 프레임에서 멈추고 idle 로 돌아간다.

const STEP := 0.05

var velvet: MadameVelvet


func before_each() -> void:
	super.before_each()
	velvet = MadameVelvet.new()
	tree.root.add_child(velvet)


func after_each() -> void:
	super.after_each()
	velvet.free()
	velvet = null


func test_looping_idle_cycles_frames() -> void:
	velvet.play(MadameVelvet.Anim.IDLE, true)
	var seen: Dictionary = {}
	for i in 40:
		velvet._process(STEP)
		seen[velvet._frame] = true
	check(seen.size() > 1, "여러 프레임을 순환")
	check(seen.keys().all(func(f: int) -> bool: return f < MadameVelvet.FRAME_COUNT[MadameVelvet.Anim.IDLE]), "범위 안")


func test_play_wine_returns_to_idle_after_playing_through() -> void:
	velvet.play_wine()
	check_eq(velvet.anim, MadameVelvet.Anim.WINE, "와인잔 제스처 시작")
	for i in 30:
		velvet._process(STEP)
	check_eq(velvet.anim, MadameVelvet.Anim.IDLE, "끝나면 idle 로 복귀")


## 손짓·박수는 (다른 세계 액터들과 같은 규칙으로) 모든 프레임을 재생한 뒤 스스로 idle 로 돌아간다.
func test_play_gesture_and_clap_do_not_loop_forever() -> void:
	for anim: Callable in [velvet.play_gesture, velvet.play_clap]:
		anim.call()
		for i in 30:
			velvet._process(STEP)
		check_eq(velvet.anim, MadameVelvet.Anim.IDLE, "곧 idle 로 돌아감(그 뒤로는 idle 이 계속 순환)")
