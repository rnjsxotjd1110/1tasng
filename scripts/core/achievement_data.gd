class_name AchievementData
extends RefCounted
## data/achievements.json 를 읽어 캐시한다(GameData·DialogueData 와 같은 정적 로더 패턴).
## 조건 판정은 AchievementManager 가 코드로 하고, 여기는 표시용 메타데이터(이름·설명·아이콘·카테고리·숨김)만 담는다.

const PATH := "res://data/achievements.json"

static var _all: Array[Dictionary] = []
static var _by_id: Dictionary = {}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_all.clear()
	_by_id.clear()
	if not FileAccess.file_exists(PATH):
		push_error("AchievementData: 파일 없음 %s" % PATH)
		return
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("AchievementData: JSON 파싱 실패")
		return
	for entry: Dictionary in parsed:
		_all.append(entry)
		_by_id[String(entry.get("id", ""))] = entry


static func reload() -> void:
	_loaded = false
	ensure_loaded()


static func all() -> Array[Dictionary]:
	ensure_loaded()
	return _all


static func has(id: String) -> bool:
	ensure_loaded()
	return _by_id.has(id)


static func get_def(id: String) -> Dictionary:
	ensure_loaded()
	return _by_id.get(id, {})


static func category_of(id: String) -> String:
	return String(get_def(id).get("category", ""))


static func is_hidden(id: String) -> bool:
	return bool(get_def(id).get("hidden", false))
