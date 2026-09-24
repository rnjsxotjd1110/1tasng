extends RefCounted
## 테스트 파일의 기반. tests/test_*.gd 는 이 파일을 extends 하고 test_ 로 시작하는 함수를 만든다.
## 외부 애드온 없이 동작한다. 실패는 기록만 하고 다음 검사로 계속 진행한다.

var tree: SceneTree
var failures: Array[String] = []
var checks: int = 0
var current_test: String = ""
var _connections: Array[Array] = []


## 각 테스트 전에 호출. 기본값: 게임 상태와 난수를 초기화한다.
func before_each() -> void:
	GameState.reset()
	RngService.set_seed(12345)


func after_each() -> void:
	pass


func check(condition: bool, message: String = "") -> bool:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [current_test, message if message != "" else "조건이 거짓"])
	return condition


func check_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	checks += 1
	var same: bool = typeof(actual) == typeof(expected) and actual == expected
	if not same and (typeof(actual) in [TYPE_INT, TYPE_FLOAT]) and (typeof(expected) in [TYPE_INT, TYPE_FLOAT]):
		same = float(actual) == float(expected)
	if not same:
		failures.append("%s: %s 기대값 <%s> 실제값 <%s>" % [current_test, message, expected, actual])
	return same


func check_near(actual: float, expected: float, tolerance: float, message: String = "") -> bool:
	checks += 1
	var ok := absf(actual - expected) <= tolerance
	if not ok:
		failures.append("%s: %s 기대값 %s±%s 실제값 %s" % [current_test, message, expected, tolerance, actual])
	return ok


## 상대 오차 비교(큰 수용).
func check_rel(actual: float, expected: float, rel_tolerance: float = 1e-9, message: String = "") -> bool:
	return check_near(actual, expected, absf(expected) * rel_tolerance, message)


## 시그널 발행을 기록한다. 반환 배열에 발행마다 인자 배열이 쌓인다. 테스트가 끝나면 자동으로 연결 해제.
func watch(sig: Signal) -> Array:
	var emitted: Array = []
	var callable := func(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
		var args: Array = []
		for value: Variant in [a, b, c, d]:
			args.append(value)
		emitted.append(args)
	sig.connect(callable)
	_connections.append([sig, callable])
	return emitted


func _disconnect_all() -> void:
	for pair: Array in _connections:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	_connections.clear()
