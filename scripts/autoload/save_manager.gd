extends Node
## 저장·불러오기(4단계). user://save.json.
##   {"version":int, "saved_at":unix초, "checksum":sha256(아래 data 문자열), "data":"<GameState.to_dict()+rng 를 JSON.stringify 한 문자열>"}
## data 를 문자열로 한 번 더 감싸는 이유: Godot 의 JSON 숫자 파서는 1e250 급 극단적으로 큰 실수를 다시 읽을 때
## 마지막 몇 비트가 흔들린다(값 자체엔 게임에 영향 없는 오차지만, data 를 통짜 객체로 두면 "손상 검사용 체크섬"이
## 재직렬화 과정에서 그 흔들림 때문에 어긋나 정상 파일을 오검출할 수 있다). 문자열로 감싸면 체크섬은 항상 원문 바이트를
## 그대로 비교하므로 이 문제가 없다.
## 원자적 저장: save.tmp 에 쓰고 다시 읽어 파싱까지 확인한 뒤, 기존 save.json → save.bak 으로 옮기고 save.tmp → save.json.
## 손상·체크섬 불일치면 save.bak 으로 다시 시도하고 토스트로 알린다.

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.tmp"
const BAK_PATH := "user://save.bak"
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL := 30.0

var _autosave_timer: float = 0.0
## load_game() 이 채운다. 오프라인 수익 계산 결과(Main 이 읽어 복귀 팝업을 띄운다). 계산 대상이 아니면 null.
var last_load_offline: OfflineIncome = null
var last_load_recovered_from_backup: bool = false
var last_load_ok: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.upgrade_purchased.connect(func(_id: String, _level: int) -> void: save_game())
	EventBus.skill_purchased.connect(func(_id: String, _level: int) -> void: save_game())
	EventBus.floor_changed.connect(func(_index: int) -> void: save_game())
	EventBus.debt_changed.connect(save_game)


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## GameState + RngService 상태를 저장한다. 대출 직후·업그레이드·스킬·층 이동·포커스 상실·30초마다·창 닫기에서 호출된다.
func save_game() -> bool:
	var data := GameState.to_dict()
	data["rng"] = RngService.get_state()
	var data_json := JSON.stringify(data)
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"checksum": data_json.sha256_text(),
		"data": data_json,
	}
	EventBus.save_started.emit()
	var ok := _write_atomic(JSON.stringify(payload))
	if not ok:
		push_warning("SaveManager.save_game: 저장 실패")
	EventBus.save_finished.emit(ok)
	return ok


## GameState 를 되돌린다. 체크섬이 안 맞으면 save.bak 으로, 그것도 실패하면 false.
## 성공하면 GameState.rebuild_upgrade_modifiers() 까지 호출해 둔다(스핀 도중 저장 정산은 SpinController.settle_pending_spin 이 별도로 호출됨).
func load_game() -> bool:
	last_load_offline = null
	last_load_recovered_from_backup = false
	last_load_ok = false
	var payload := _read_and_verify(SAVE_PATH)
	if payload.is_empty() and has_save():
		payload = _read_and_verify(BAK_PATH)
		if not payload.is_empty():
			last_load_recovered_from_backup = true
			EventBus.toast_requested.emit(tr("TOAST_SAVE_RECOVERED"), "warning")
	if payload.is_empty():
		if has_save():
			EventBus.toast_requested.emit(tr("TOAST_SAVE_CORRUPTED"), "warning")
		return false
	var saved_at := float(payload.get("saved_at", 0.0))
	var data := _migrate(payload.get("data", {}), int(payload.get("version", SAVE_VERSION)))
	GameState.from_dict(data)
	GameState.rebuild_upgrade_modifiers()
	GameState.rebuild_skill_modifiers()
	var rng_state: Variant = data.get("rng")
	if typeof(rng_state) == TYPE_DICTIONARY:
		RngService.set_state(rng_state)
	var now := Time.get_unix_time_from_system()
	var rest_bonus_level := SkillService.feature_level("offline_clover_bonus")
	var clover_hours := 0.0
	if rest_bonus_level > 0 and rest_bonus_level <= Economy.OFFLINE_CLOVER_HOURS_PER_LEVEL.size():
		clover_hours = Economy.OFFLINE_CLOVER_HOURS_PER_LEVEL[rest_bonus_level - 1]
	last_load_offline = OfflineIncome.compute(
		GameState.last_income_per_second, saved_at, now,
		GameState.auto_spin_unlocked(), GameState.auto_spin_enabled,
		GameState.get_stat(StatModifiers.OFFLINE_CAP_HOURS, Economy.OFFLINE_CAP_HOURS),
		GameState.get_stat(StatModifiers.OFFLINE_EFFICIENCY, Economy.OFFLINE_EFFICIENCY),
		Economy.OFFLINE_TIP_EFFICIENCY, clover_hours)
	last_load_ok = true
	return true


## from_version → SAVE_VERSION 까지 순서대로 바꾼다. 새 버전을 추가할 때 여기에 case 를 추가한다.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var version := from_version
	if version > SAVE_VERSION:
		push_warning("SaveManager: 이 게임보다 새 버전의 저장 파일(v%d, 현재 v%d)" % [version, SAVE_VERSION])
		return data
	while version < SAVE_VERSION:
		match version:
			_:
				push_warning("SaveManager: v%d → v%d 마이그레이션이 없음" % [version, version + 1])
				return data
		version += 1
	return data


## path 를 읽어 체크섬까지 확인한 뒤 {"version", "saved_at", "data"} 로 돌려준다. 실패하면 빈 Dictionary.
func _read_and_verify(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = parsed
	var data_json: Variant = payload.get("data")
	if typeof(data_json) != TYPE_STRING:
		return {}
	if String(data_json).sha256_text() != String(payload.get("checksum", "")):
		push_warning("SaveManager: 체크섬 불일치 (%s)" % path)
		return {}
	var inner: Variant = JSON.parse_string(data_json)
	if typeof(inner) != TYPE_DICTIONARY:
		return {}
	return {"version": int(payload.get("version", SAVE_VERSION)), "saved_at": float(payload.get("saved_at", 0.0)), "data": inner}


## save.tmp 에 쓰고 다시 읽어 파싱을 확인한 뒤 save.json → save.bak, save.tmp → save.json 순서로 교체한다.
func _write_atomic(text: String) -> bool:
	var tmp := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_warning("SaveManager: 임시 파일을 열 수 없음 (%s)" % error_string(FileAccess.get_open_error()))
		return false
	tmp.store_string(text)
	tmp.close()
	var verify := FileAccess.open(TMP_PATH, FileAccess.READ)
	var verify_ok := verify != null and typeof(JSON.parse_string(verify.get_as_text())) == TYPE_DICTIONARY
	if verify != null:
		verify.close()
	if not verify_ok:
		push_warning("SaveManager: 저장 검증 실패")
		return false
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BAK_PATH):
			DirAccess.remove_absolute(BAK_PATH)
		var rename_bak := DirAccess.rename_absolute(SAVE_PATH, BAK_PATH)
		if rename_bak != OK:
			push_warning("SaveManager: 백업 교체 실패 (%s)" % error_string(rename_bak))
	var rename_final := DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if rename_final != OK:
		push_warning("SaveManager: 저장 파일 교체 실패 (%s)" % error_string(rename_final))
		return false
	return true
