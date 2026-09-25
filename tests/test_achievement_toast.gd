extends "res://tests/lib/test_case.gd"
## AchievementToast: EventBus.achievement_unlocked 로 큐에 쌓임, 슬라이드인→유지→슬라이드아웃, 여러 개는 순서대로.

const STEP := 0.05

var toast: AchievementToast


func before_each() -> void:
	super.before_each()
	toast = AchievementToast.new()
	tree.root.add_child(toast)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	toast.free()
	toast = null


func test_unlock_queues_and_shows_panel() -> void:
	EventBus.achievement_unlocked.emit("first_spin")
	toast._process(STEP)
	check_eq(toast._phase, AchievementToast.Phase.IN, "슬라이드인 시작")
	check(toast._panel.visible, "패널 보임")
	check_eq(toast._label.text, tr("ACH_FIRST_SPIN_NAME"), "이름 표시")


func test_slide_in_reaches_target_position() -> void:
	EventBus.achievement_unlocked.emit("first_spin")
	for i in 20:
		toast._process(STEP)
	check_eq(toast._phase, AchievementToast.Phase.HOLD, "유지 단계 진입")
	check_near(toast._panel.modulate.a, 1.0, 0.01, "완전히 나타남")


func test_hides_after_hold_and_fade_out() -> void:
	EventBus.achievement_unlocked.emit("first_spin")
	var elapsed := 0.0
	while elapsed < AchievementToast.SLIDE_TIME + AchievementToast.HOLD_TIME + AchievementToast.FADE_OUT_TIME + 0.2:
		toast._process(STEP)
		elapsed += STEP
	check_eq(toast._phase, AchievementToast.Phase.IDLE, "다시 대기 상태")
	check(not toast._panel.visible, "패널 숨김")


func test_multiple_unlocks_show_one_at_a_time() -> void:
	EventBus.achievement_unlocked.emit("first_spin")
	toast._process(STEP)  # 첫 업적이 큐에서 빠져나와 표시 시작
	EventBus.achievement_unlocked.emit("zero_hit")
	check_eq(toast._queue.size(), 1, "두 번째는 큐에 대기")
	var elapsed := 0.0
	while elapsed < AchievementToast.SLIDE_TIME + AchievementToast.HOLD_TIME + AchievementToast.FADE_OUT_TIME + 0.2:
		toast._process(STEP)
		elapsed += STEP
	check_eq(toast._phase, AchievementToast.Phase.IN, "다음 업적이 이어서 나타남")
	check_eq(toast._label.text, tr("ACH_ZERO_HIT_NAME"), "두 번째 이름 표시")
