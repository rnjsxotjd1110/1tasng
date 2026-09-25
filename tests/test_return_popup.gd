extends "res://tests/lib/test_case.gd"
## ReturnPopup: 열기·카운트업 목표값·[받기] 시 칩 지급과 claimed 신호, 빚 상환 내역 표시.

var popup: ReturnPopup


func before_each() -> void:
	super.before_each()
	popup = ReturnPopup.new()
	tree.root.add_child(popup)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	popup.free()
	popup = null


func _offline(income: float, elapsed: float, capped: float) -> OfflineIncome:
	var o := OfflineIncome.new()
	o.income = income
	o.elapsed_seconds = elapsed
	o.capped_seconds = capped
	o.eligible = true
	o.mode = OfflineIncome.Mode.FULL
	return o


func test_open_sets_pending_income_and_hides_debt_row_by_default() -> void:
	popup.open(_offline(500.0, 3600.0, 3600.0))
	check_eq(popup._pending_income, 500.0, "받을 금액 저장")
	check(not popup._debt_row.visible, "빚 상환 내역 없으면 숨김")


func test_claim_adds_chips_and_emits_signal() -> void:
	var before := GameState.chips
	popup.open(_offline(250.0, 200.0, 200.0))
	var emitted := watch(popup.claimed)
	popup._on_claim_pressed()
	check_eq(GameState.chips, before + 250.0, "칩 지급")
	check_eq(emitted.size(), 1, "claimed 신호 발행")


func test_cap_note_shown_when_elapsed_exceeds_cap() -> void:
	popup.open(_offline(100.0, 5.0 * 3600.0, 2.0 * 3600.0))
	check(popup._elapsed_label.text.contains(tr("RETURN_CAP_APPLIED") % NumberFormat.format_decimal(2.0)), "상한 적용 안내 포함")


func test_no_cap_note_when_within_cap() -> void:
	popup.open(_offline(100.0, 1800.0, 1800.0))
	check(not popup._elapsed_label.text.contains("%"), "치환 실패 잔재 없음")


func test_debt_row_shown_when_repaid() -> void:
	popup.open(_offline(100.0, 600.0, 600.0), 50.0)
	check(popup._debt_row.visible, "빚 상환 내역 표시")
	check(popup._debt_label.text.contains(NumberFormat.format(50.0)), "상환액 포함")
