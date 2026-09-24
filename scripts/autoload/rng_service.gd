extends Node
## 시드 지정 가능한 난수 서비스.
## - 스핀 결과(outcome 스트림)와 연출·패널티 등 그 외(misc 스트림)를 분리해, 연출이 결과를 바꾸지 않게 한다.
## - peek_next()/consume_next(): 다음 결과를 미리 뽑아 둔다('예지' 스킬용). 미리 본 결과는 반드시 그대로 나온다.

var _outcome_rng := RandomNumberGenerator.new()
var _misc_rng := RandomNumberGenerator.new()
var _queue: Array[int] = []
var _seed: int = 0


func _ready() -> void:
	randomize_seed()


func randomize_seed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	set_seed(rng.randi())


## 두 스트림의 시드를 정하고 미리 뽑아 둔 결과를 비운다.
func set_seed(new_seed: int) -> void:
	_seed = new_seed
	_outcome_rng.seed = new_seed
	_misc_rng.seed = hash(new_seed + 1)
	_queue.clear()


func get_seed() -> int:
	return _seed


## 다음 count 개의 스핀 결과를 소비하지 않고 본다.
func peek_next(count: int = 1) -> Array[int]:
	while _queue.size() < count:
		_queue.append(_roll_pocket())
	return _queue.slice(0, count)


## 다음 스핀 결과(0~36)를 꺼낸다. 미리 본 결과가 있으면 그것부터.
func consume_next() -> int:
	if _queue.is_empty():
		return _roll_pocket()
	return _queue.pop_front()


## 연출·패널티 등 결과와 무관한 난수.
func randf_misc() -> float:
	return _misc_rng.randf()


func randf_range_misc(from: float, to: float) -> float:
	return _misc_rng.randf_range(from, to)


func randi_range_misc(from: int, to: int) -> int:
	return _misc_rng.randi_range(from, to)


## 저장용 상태. 미리 뽑아 둔 결과도 포함한다.
func get_state() -> Dictionary:
	return {"seed": _seed, "outcome_state": _outcome_rng.state, "misc_state": _misc_rng.state, "queue": _queue.duplicate()}


func set_state(data: Dictionary) -> void:
	_seed = int(data.get("seed", 0))
	_outcome_rng.seed = _seed
	_outcome_rng.state = int(data.get("outcome_state", _outcome_rng.state))
	_misc_rng.state = int(data.get("misc_state", _misc_rng.state))
	_queue.clear()
	for value in data.get("queue", []):
		_queue.append(int(value))


func _roll_pocket() -> int:
	return _outcome_rng.randi_range(0, RouletteRules.POCKET_COUNT - 1)
