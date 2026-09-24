class_name IncomeTracker
extends RefCounted
## 초당 수익(순이익) 이동평균. 스핀 정산마다 add(시각, 순이익)을 넣는다. 순수 계산(시각은 호출자가 준다).
## 창(window)보다 짧게 플레이했으면 경과 시간(최소 MIN_SPAN)으로 나눠 초반에 과소평가하지 않는다.

const DEFAULT_WINDOW := 60.0
const MIN_SPAN := 10.0

var window: float = DEFAULT_WINDOW
var _times: Array[float] = []
var _values: Array[float] = []
var _start_time: float = -1.0


func _init(p_window: float = DEFAULT_WINDOW) -> void:
	window = p_window


func add(time: float, net: float) -> void:
	if _start_time < 0.0:
		_start_time = time
	_times.append(time)
	_values.append(net)
	_trim(time)


func reset() -> void:
	_times.clear()
	_values.clear()
	_start_time = -1.0


## now 기준 최근 window 초의 초당 순수익.
func per_second(now: float) -> float:
	_trim(now)
	if _start_time < 0.0:
		return 0.0
	var sum := 0.0
	for value in _values:
		sum += value
	var span := clampf(now - _start_time, MIN_SPAN, window)
	return sum / span


func _trim(now: float) -> void:
	while not _times.is_empty() and _times[0] < now - window:
		_times.pop_front()
		_values.pop_front()
