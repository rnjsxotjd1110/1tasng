extends SceneTree
## 헤드리스 테스트 러너.
##   godot --headless -s tests/run_tests.gd                 # 전체
##   godot --headless -s tests/run_tests.gd -- number      # 파일 이름에 'number' 가 들어간 것만
## tests/test_*.gd 를 찾아 test_ 로 시작하는 함수를 모두 실행한다. 실패가 있으면 종료 코드 1.

const TEST_DIR := "res://tests"
const TEST_PREFIX := "test_"


func _initialize() -> void:
	# _initialize 시점에는 오토로드의 _ready 가 아직 실행되지 않았다. 첫 프레임에서 실행한다.
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
	var filter := ""
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		filter = user_args[0]
	var total_checks := 0
	var total_tests := 0
	var all_failures: Array[String] = []
	var started := Time.get_ticks_msec()
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file_name in files:
		if not (file_name.begins_with(TEST_PREFIX) and file_name.ends_with(".gd")):
			continue
		if filter != "" and not file_name.contains(filter):
			continue
		var script: GDScript = load(TEST_DIR.path_join(file_name))
		if script == null or not script.can_instantiate():
			all_failures.append("%s: 스크립트를 불러올 수 없음" % file_name)
			continue
		var file_started := Time.get_ticks_msec()
		var case: RefCounted = script.new()
		case.set("tree", self)
		var test_count := 0
		for method: Dictionary in case.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with(TEST_PREFIX):
				continue
			test_count += 1
			case.set("current_test", "%s::%s" % [file_name.get_basename(), method_name])
			case.call("before_each")
			case.call(method_name)
			case.call("after_each")
			case.call("_disconnect_all")
		var failures: Array[String] = case.get("failures")
		total_checks += int(case.get("checks"))
		total_tests += test_count
		all_failures.append_array(failures)
		print("%s %-28s %3d tests  %5d ms" % ["FAIL" if not failures.is_empty() else " ok ", file_name, test_count, Time.get_ticks_msec() - file_started])
	root.get_node("GameState").call("reset")
	print("")
	for failure in all_failures:
		print("  ✗ ", failure)
	print("%d tests, %d checks, %d failures (%d ms)" % [total_tests, total_checks, all_failures.size(), Time.get_ticks_msec() - started])
	if total_tests == 0:
		print("테스트가 하나도 실행되지 않았다.")
		quit(1)
		return
	quit(0 if all_failures.is_empty() else 1)
