class_name DialogueData
extends RefCounted
## data/dialogue/*.json 를 읽어 캐시한다(GameData 와 같은 정적 로더 패턴).
## JSON 은 구조·화자·표정·순서만 갖고, 실제 문장은 번역 키(translations/strings.csv)다.
## 각 키는 변형(variant) 배열이다: {"speaker": 번역키, "portrait": 표정id, "lines": [번역키...]}

const DIR := "res://data/dialogue"

static var _sets: Dictionary = {}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_sets.clear()
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		var clean := file_name.trim_suffix(".remap")
		if not clean.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(DIR.path_join(clean))
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("DialogueData: JSON 파싱 실패 (%s)" % clean)
			continue
		for key: String in (parsed as Dictionary).keys():
			_sets[key] = parsed[key]


static func reload() -> void:
	_loaded = false
	ensure_loaded()


static func has(key: String) -> bool:
	ensure_loaded()
	return _sets.has(key)


## key 에 등록된 변형 중 하나를 무작위로 고른다(RngService misc 스트림). 없으면 빈 Dictionary.
static func pick(key: String) -> Dictionary:
	ensure_loaded()
	if not _sets.has(key):
		push_error("DialogueData.pick: 없는 키 '%s'" % key)
		return {}
	var variants: Array = _sets[key]
	if variants.is_empty():
		return {}
	var index := RngService.randi_range_misc(0, variants.size() - 1)
	return variants[index]


static func variant_count(key: String) -> int:
	ensure_loaded()
	return (_sets[key] as Array).size() if _sets.has(key) else 0
