class_name SmokeOverlay
extends Control
## 시가 연기 패널티: 기록 패널·휠 왼쪽 위로 반투명 연기가 흐른다(GDD 9장 — 결과 가독성은 유지, 낮은 알파).

const SMOKE := preload("res://assets/sprites/bg/b1/smoke.png")
const PUFF_COUNT := 5
const AREA := Rect2(0, 24, 220, 220)
const DRIFT_SPEED := 10.0
## smoke.png 자체 알파가 이미 낮아(최대 약 0.27) ART_BIBLE 11-6 의 "알파 0.35 안팎"에 맞추려면
## 1.0 을 넘겨 곱해야 한다(그래도 텍스처 자체 알파가 상한이라 완전 불투명이 되진 않는다).
const MAX_ALPHA := 1.3

var _puffs: Array[Dictionary] = []
var _active: bool = false


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in PUFF_COUNT:
		_puffs.append({
			"pos": Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(AREA.position.y, AREA.end.y)),
			"speed": rng.randf_range(0.6, 1.4),
			"scale": rng.randf_range(1.0, 2.0),
		})


func start() -> void:
	_active = true
	visible = true


func stop() -> void:
	_active = false
	visible = false


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	for puff in _puffs:
		puff["pos"] = Vector2(puff["pos"]) + Vector2(DRIFT_SPEED * float(puff["speed"]) * delta, 0.0)
		if float(puff["pos"].x) > AREA.end.x + 30.0:
			puff["pos"].x = AREA.position.x - 30.0
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	for puff in _puffs:
		var pos: Vector2 = puff["pos"]
		var s: float = puff["scale"]
		draw_texture_rect(SMOKE, Rect2(pos.round(), SMOKE.get_size() * s), false, Palette.with_alpha(Palette.MIST, MAX_ALPHA))
