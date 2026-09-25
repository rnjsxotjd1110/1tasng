class_name FlyingChips
extends Control
## 칩(또는 클로버) 아이콘이 곡선을 그리며 목적지(상단 칩 카운터)로 날아간다.
## 하나 도착할 때마다 arrived(index) 를 발행한다(카운터 1px 튐 + '딸깍').

signal arrived(batch_id: int, index: int, count: int)
signal finished(batch_id: int)

const CHIP := preload("res://assets/sprites/ui/icon_chip_small.png")
const CLOVER := preload("res://assets/sprites/ui/particle_clover.png")
const FLIGHT_TIME := 0.55
const STAGGER := 0.045
const ARC := 50.0
const SIDE_JITTER := 24.0

enum Icon { CHIP, CLOVER }

var _flights: Array[Dictionary] = []
var _batches: Dictionary = {}
var _next_batch: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 360)


## sources(전역 좌표) 에서 번갈아 출발해 target 으로 count 개를 날린다. batch id 를 돌려준다.
func launch(sources: Array[Vector2], target: Vector2, count: int, icon: Icon = Icon.CHIP) -> int:
	var batch := _next_batch
	_next_batch += 1
	_batches[batch] = count
	for i in count:
		var from: Vector2 = sources[i % sources.size()] if not sources.is_empty() else target
		from += Vector2(RngService.randf_range_misc(-6.0, 6.0), RngService.randf_range_misc(-3.0, 3.0))
		var mid := from.lerp(target, 0.5) + Vector2(RngService.randf_range_misc(-SIDE_JITTER, SIDE_JITTER), -ARC)
		_flights.append({"batch": batch, "index": i, "count": count, "from": from, "mid": mid, "to": target,
			"t": -i * STAGGER, "icon": icon})
	return batch


func _process(delta: float) -> void:
	if _flights.is_empty():
		return
	var done: Array[Dictionary] = []
	for flight in _flights:
		flight["t"] = float(flight["t"]) + delta
		if float(flight["t"]) >= FLIGHT_TIME:
			done.append(flight)
	for flight in done:
		_flights.erase(flight)
		var batch := int(flight["batch"])
		arrived.emit(batch, int(flight["index"]), int(flight["count"]))
		_batches[batch] = int(_batches[batch]) - 1
		if int(_batches[batch]) <= 0:
			_batches.erase(batch)
			finished.emit(batch)
	queue_redraw()


func _draw() -> void:
	for flight in _flights:
		var t := float(flight["t"])
		if t < 0.0:
			continue
		var u := t / FLIGHT_TIME
		var e := u * u * (3.0 - 2.0 * u)
		var a: Vector2 = flight["from"]
		var b: Vector2 = flight["mid"]
		var c: Vector2 = flight["to"]
		var pos := a.lerp(b, e).lerp(b.lerp(c, e), e)
		var texture: Texture2D = CHIP if int(flight["icon"]) == Icon.CHIP else CLOVER
		draw_texture(texture, (pos - texture.get_size() * 0.5).round())
