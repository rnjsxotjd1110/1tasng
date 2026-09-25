extends "res://tests/lib/test_case.gd"
## IntroCutscene: 골목 → 구슬 → 문 → 대사 단계 전이, 스킵. 실제 화면 전환(get_tree().change_scene_to_file)은
## 이 파일에서 부르지 않는다 — TitleScreen 은 finished() 신호에서만 그 호출을 하며, 헤드리스 테스트가
## 실제 씬 전환을 유발하면 이후 테스트들이 공유하는 SceneTree 가 오염되기 때문이다(EndingSequence 와 같은 이유로
## _process(dt) 를 직접 여러 번 불러 진행 상황만 확인한다).

const STEP := 0.1

var intro: IntroCutscene


func before_each() -> void:
	super.before_each()
	intro = IntroCutscene.new()
	tree.root.add_child(intro)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	intro.free()
	intro = null


func _tick(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		intro._process(STEP)
		intro._dialogue._process(STEP)
		t += STEP


func test_play_starts_alley_phase() -> void:
	intro.play()
	check(intro.visible, "재생 시작하면 보임")
	check_eq(intro._phase, IntroCutscene.Phase.ALLEY, "골목 단계로 시작")
	check(intro._figure.visible, "뒷모습 실루엣이 보임")


func test_alley_advances_to_marble_phase() -> void:
	intro.play()
	_tick(IntroCutscene.ALLEY_DURATION + STEP)
	check_eq(intro._phase, IntroCutscene.Phase.MARBLE, "골목 시간이 지나면 구슬 단계로")
	check(intro._marble_icon.visible, "구슬 아이콘이 보임")


func test_marble_advances_to_door_then_dialogue() -> void:
	intro.play()
	_tick(IntroCutscene.ALLEY_DURATION + IntroCutscene.MARBLE_DURATION + IntroCutscene.DOOR_FADE + STEP * 2)
	check_eq(intro._phase, IntroCutscene.Phase.DIALOGUE, "문 단계를 지나면 대사 단계")
	check(intro._lucy.visible, "루시가 보임")
	check(intro._dialogue.is_open(), "대사창이 열림")


func test_dialogue_completion_finishes_cutscene() -> void:
	var emitted := watch(intro.finished)
	intro.play()
	_tick(IntroCutscene.ALLEY_DURATION + IntroCutscene.MARBLE_DURATION + IntroCutscene.DOOR_FADE + STEP * 2)
	check(intro._dialogue.is_open(), "대사 시작됨")
	# 대사 4줄을 전부 완료할 때까지 클릭(advance)한다: 타이핑 중이면 즉시 완성, 끝났으면 다음 줄.
	var guard := 0
	while intro._dialogue.is_open() and guard < 50:
		intro._dialogue.advance()
		_tick(0.05)
		guard += 1
	check(not intro._dialogue.is_open(), "대사창이 닫힘")
	check_eq(emitted.size(), 1, "finished 신호 1회 발행")
	check(not intro.visible, "컷신이 숨겨짐")


func test_skip_finishes_immediately_from_any_phase() -> void:
	var emitted := watch(intro.finished)
	intro.play()
	_tick(STEP)
	check_eq(intro._phase, IntroCutscene.Phase.ALLEY, "아직 골목 단계")
	intro.skip()
	check_eq(emitted.size(), 1, "스킵하면 finished 신호 발행")
	check(not intro.visible, "스킵하면 즉시 숨겨짐")


func test_skip_closes_open_dialogue() -> void:
	intro.play()
	_tick(IntroCutscene.ALLEY_DURATION + IntroCutscene.MARBLE_DURATION + IntroCutscene.DOOR_FADE + STEP * 2)
	check(intro._dialogue.is_open(), "대사창이 열려 있음")
	intro.skip()
	check(not intro._dialogue.visible, "스킵하면 대사창도 닫힘")


func test_skip_twice_emits_once() -> void:
	var emitted := watch(intro.finished)
	intro.play()
	intro.skip()
	intro.skip()
	check_eq(emitted.size(), 1, "두 번 불러도 한 번만 발행")
