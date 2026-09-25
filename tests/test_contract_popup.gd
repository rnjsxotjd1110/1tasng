extends "res://tests/lib/test_case.gd"

const STEP := 0.05

var popup: ContractPopup


func before_each() -> void:
	super.before_each()
	popup = ContractPopup.new()
	tree.root.add_child(popup)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	popup.free()
	popup = null


func test_open_shows_amounts_and_starts_rolled_up() -> void:
	popup.open(100.0, 200.0)
	check(popup.visible, "열림")
	check(popup._principal_label.text.contains(NumberFormat.format_full(100.0)), "대출액 표시")
	check(popup._repay_label.text.contains(NumberFormat.format_full(200.0)), "상환액 표시")
	check_eq(popup._clip.size.y, 0.0, "펼치기 전엔 높이 0")


func test_sign_button_starts_signing_then_stamps_and_signals() -> void:
	popup.open(100.0, 200.0)
	var signed := watch(popup.signed)
	popup._on_sign_pressed()
	check(popup._signing, "서명 중")
	check(popup._sign_button.disabled, "버튼 비활성")
	for i in 20:
		popup._process(STEP)
	check(not popup._signing, "서명 끝")
	check(popup._stamp.visible, "도장 찍힘")
	check_eq(signed.size(), 1, "signed 발행")


func test_close_hides_popup() -> void:
	popup.open(100.0, 200.0)
	popup.close()
	check(not popup.visible, "닫힘")
