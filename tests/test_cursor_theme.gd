extends "res://tests/lib/test_case.gd"
## CursorTheme(8단계 4/N): 커스텀 커서 3종 등록 + 새 버튼에 자동으로 커서 모양을 붙이는지.

func test_apply_is_idempotent_and_safe_headless() -> void:
	CursorTheme.apply(tree)
	CursorTheme.apply(tree)
	check(true, "헤드리스에서도 두 번 불러도 에러 없이 끝난다")


func test_new_enabled_button_gets_pointing_hand_cursor() -> void:
	CursorTheme.apply(tree)
	var button := Button.new()
	tree.root.add_child(button)
	check_eq(button.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "활성 버튼은 손가락 커서")
	button.free()


func test_new_disabled_button_gets_forbidden_cursor() -> void:
	CursorTheme.apply(tree)
	var button := Button.new()
	button.disabled = true
	tree.root.add_child(button)
	check_eq(button.mouse_default_cursor_shape, Control.CURSOR_FORBIDDEN, "비활성 버튼은 금지 커서")
	button.free()


func test_button_with_custom_shape_is_not_overridden() -> void:
	CursorTheme.apply(tree)
	var button := Button.new()
	button.mouse_default_cursor_shape = Control.CURSOR_CROSS
	tree.root.add_child(button)
	check_eq(button.mouse_default_cursor_shape, Control.CURSOR_CROSS, "이미 다른 모양을 정했으면 그대로 둔다")
	button.free()
