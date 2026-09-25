class_name LetterboxFit
extends RefCounted
## 창 크기와 무관하게 640×360 콘텐츠를 정수 배율로 중앙 정렬하고, 남는 여백을 검은 바 대신 어두운
## 테이블 무늬로 채운다(8단계 마무리, GDD 22장). `window/stretch/mode="disabled"` 와 짝을 이룬다 — 그
## 설정에서는 루트 뷰포트가 실제 창 크기와 같아지므로, 이 헬퍼가 대신 정수 배율 스케일링·중앙 정렬을
## 맡는다. `viewport` 스트레치가 자동으로 채우던 여백은 디스플레이 서버의 블릿 단계라 스크립트가 손댈 수
## 없었지만(직접 실측 확인, GDD 21장), 이 방식은 여백이 SceneTree 안의 실제 노드라 자유롭게 그릴 수 있다.
##
## 주의: `CanvasLayer` 는 부모 Control 의 scale·position 을 상속하지 않는다(직접 실측 확인) — `content`
## 아래에 CanvasLayer 를 쓰는 씬(Main 의 ui_layer/fx_layer 등)은 `extra_layers` 로 같이 넘겨야 화면이
## 맞게 나온다.

const BASE_SIZE := Vector2(640, 360)
const CELL := 16
const SPECKLE_SEED := 20260925

## 창 크기에서 정수 배율·중앙 정렬 오프셋을 계산한다(순수 함수 — 헤드리스 테스트에서 실제 창 없이도 검증).
static func compute(window_size: Vector2) -> Dictionary:
	var factor := maxf(1.0, floorf(minf(window_size.x / BASE_SIZE.x, window_size.y / BASE_SIZE.y)))
	var offset := ((window_size - BASE_SIZE * factor) * 0.5).floor()
	return {"scale": factor, "offset": offset}


## content: 640×360 기준으로 그려진 실제 화면 루트(Control, 아직 트리에 들어가 있어야 함).
## extra_layers: content 의 자식 중 CanvasLayer 가 있으면 여기 나열 — 같은 배율·오프셋을 transform 으로 맞춘다.
static func apply(content: Control, extra_layers: Array[CanvasLayer] = []) -> void:
	var bg := _Background.new()
	var parent := content.get_parent()
	parent.add_child(bg)
	parent.move_child(bg, 0)
	var updater := _Updater.new()
	updater.content = content
	updater.bg = bg
	updater.extra_layers = extra_layers
	content.add_child(updater)


class _Updater extends Node:
	var content: Control
	var bg: Control
	var extra_layers: Array[CanvasLayer] = []

	func _ready() -> void:
		get_tree().root.size_changed.connect(refresh)
		refresh()

	func refresh() -> void:
		if content == null or not is_instance_valid(content):
			return
		# DisplayServer.window_get_size() 는 --resolution 커맨드라인 인자로 띄운 창에서 project.godot
		# 기본값을 그대로 돌려주는 걸 실측으로 확인했다(버그로 보임) — 실제 창 크기가 맞게 반영되는
		# get_tree().root.size(Window 노드 자체의 크기)를 쓴다.
		var window_size := Vector2(get_tree().root.size)
		var fit := LetterboxFit.compute(window_size)
		var factor: float = fit["scale"]
		var offset: Vector2 = fit["offset"]
		content.scale = Vector2(factor, factor)
		content.position = offset
		var xform := Transform2D.IDENTITY.scaled(Vector2(factor, factor))
		xform.origin = offset
		for layer in extra_layers:
			if is_instance_valid(layer):
				layer.transform = xform
		if bg != null and is_instance_valid(bg):
			bg.size = window_size
			bg.queue_redraw()


## 검은 바 대신 채우는 어두운 테이블 무늬(펠트 바탕 + 성긴 스펙클, felt_panel() 노이즈와 같은 결).
class _Background extends Control:
	var _dots: Array[Vector2i] = []
	var _dot_size: Vector2i = Vector2i.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = -100

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.FELT_D)
		if _dot_size != Vector2i(size):
			_rebuild_dots()
		for pos in _dots:
			draw_rect(Rect2(pos, Vector2(LetterboxFit.CELL, LetterboxFit.CELL)), Palette.WOOD_D)

	func _rebuild_dots() -> void:
		_dot_size = Vector2i(size)
		_dots.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = LetterboxFit.SPECKLE_SEED
		var cols := int(size.x / LetterboxFit.CELL) + 1
		var rows := int(size.y / LetterboxFit.CELL) + 1
		for row in rows:
			for col in cols:
				if rng.randf() < 0.05:
					_dots.append(Vector2i(col * LetterboxFit.CELL, row * LetterboxFit.CELL))
