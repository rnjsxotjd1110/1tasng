class_name CursorTheme
extends RefCounted
## 커스텀 마우스 커서 3종(8단계 4/N, ART_BIBLE 16장). 게임 시작 시 한 번만 등록하면 이후 전부
## 자동 적용된다(Input 이 CursorShape 별로 텍스처를 기억한다 — 씬이 바뀌어도 다시 부를 필요 없음).
## 새로 추가되는 모든 BaseButton 에 activated/disabled 에 맞는 커서 모양(POINTING_HAND/FORBIDDEN)도
## 자동으로 붙인다(AudioManager 의 호버·클릭음 자동 연결과 같은 목적의 별도 리스너 — 오디오와 커서는
## 관심사가 달라 한 파일에 섞지 않았다).

const DIR := "res://assets/sprites/ui/"
const HOTSPOT_TIP := Vector2(1, 1)
const HOTSPOT_CENTER := Vector2(12, 12)
const HOOKED_META := "cursor_hooked"


static func apply(tree: SceneTree) -> void:
	Input.set_custom_mouse_cursor(load(DIR + "cursor_normal.png"), Input.CURSOR_ARROW, HOTSPOT_TIP)
	Input.set_custom_mouse_cursor(load(DIR + "cursor_pointer.png"), Input.CURSOR_POINTING_HAND, HOTSPOT_CENTER)
	Input.set_custom_mouse_cursor(load(DIR + "cursor_forbidden.png"), Input.CURSOR_FORBIDDEN, HOTSPOT_CENTER)
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


static func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(HOOKED_META):
		var button := node as BaseButton
		button.set_meta(HOOKED_META, true)
		if button.mouse_default_cursor_shape == Control.CURSOR_ARROW:
			button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if button.disabled else Control.CURSOR_POINTING_HAND
