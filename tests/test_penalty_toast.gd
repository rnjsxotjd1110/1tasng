extends "res://tests/lib/test_case.gd"

const STEP := 0.05

var toast: PenaltyToast


func before_each() -> void:
	super.before_each()
	toast = PenaltyToast.new()
	tree.root.add_child(toast)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	toast.free()
	toast = null


func test_triggered_creates_active_entry() -> void:
	EventBus.penalty_triggered.emit("watcher", 20.0)
	check(toast.active_ids().has("watcher"), "활성 등록")


func test_buff_ended_removes_entry() -> void:
	EventBus.penalty_triggered.emit("blur", 20.0)
	EventBus.buff_ended.emit("blur")
	check(not toast.active_ids().has("blur"), "해제됨")


func test_auto_expires_after_duration_without_buff_ended() -> void:
	EventBus.penalty_triggered.emit("pickpocket", 0.3)
	for i in 10:
		toast._process(STEP)
	check(not toast.active_ids().has("pickpocket"), "buff_ended 없이도 표시 시간 지나면 사라짐")


func test_retrigger_replaces_existing() -> void:
	EventBus.penalty_triggered.emit("seize_marble", 20.0)
	var first: Control = toast._active["seize_marble"]["node"]
	EventBus.penalty_triggered.emit("seize_marble", 20.0)
	var second: Control = toast._active["seize_marble"]["node"]
	check(first != second, "새 알림으로 교체")


func test_progress_bar_shrinks_over_time() -> void:
	EventBus.penalty_triggered.emit("watcher", 1.0)
	toast._process(0.5)
	var bar: ColorRect = toast._active["watcher"]["bar"]
	check(bar.size.x < PenaltyToast.SIZE.x, "진행바가 줄어듦")
