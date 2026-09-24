class_name GameData
extends RefCounted
## data/ 폴더의 .tres 정의를 읽어 캐시한다(정적). 내보내기 빌드의 .remap 도 처리한다.

const MARBLES_DIR := "res://data/marbles"
const FLOORS_DIR := "res://data/floors"
const UPGRADES_DIR := "res://data/upgrades"
const SKILLS_DIR := "res://data/skills"

static var _marbles: Array[MarbleDef] = []
static var _floors: Array[FloorDef] = []
static var _upgrades: Dictionary = {}
static var _skills: Dictionary = {}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_marbles.clear()
	for resource in _load_dir(MARBLES_DIR):
		if resource is MarbleDef:
			_marbles.append(resource)
	_marbles.sort_custom(func(a: MarbleDef, b: MarbleDef) -> bool: return a.tier < b.tier)
	_floors.clear()
	for resource in _load_dir(FLOORS_DIR):
		if resource is FloorDef:
			_floors.append(resource)
	_floors.sort_custom(func(a: FloorDef, b: FloorDef) -> bool: return a.index < b.index)
	_upgrades.clear()
	for resource in _load_dir(UPGRADES_DIR):
		if resource is UpgradeDef:
			_upgrades[resource.id] = resource
	_skills.clear()
	for resource in _load_dir(SKILLS_DIR):
		if resource is SkillNodeDef:
			_skills[resource.id] = resource


static func reload() -> void:
	_loaded = false
	ensure_loaded()


static func marbles() -> Array[MarbleDef]:
	ensure_loaded()
	return _marbles


static func marble(tier: int) -> MarbleDef:
	ensure_loaded()
	if tier < 0 or tier >= _marbles.size():
		push_error("GameData.marble: 없는 tier %d" % tier)
		return null
	return _marbles[tier]


static func floors() -> Array[FloorDef]:
	ensure_loaded()
	return _floors


static func floor_def(index: int) -> FloorDef:
	ensure_loaded()
	if index < 0 or index >= _floors.size():
		push_error("GameData.floor_def: 없는 층 %d" % index)
		return null
	return _floors[index]


static func upgrades() -> Array[UpgradeDef]:
	ensure_loaded()
	var out: Array[UpgradeDef] = []
	for value: UpgradeDef in _upgrades.values():
		out.append(value)
	return out


static func upgrade(id: String) -> UpgradeDef:
	ensure_loaded()
	return _upgrades.get(id, null)


static func skills() -> Array[SkillNodeDef]:
	ensure_loaded()
	var out: Array[SkillNodeDef] = []
	for value: SkillNodeDef in _skills.values():
		out.append(value)
	return out


static func skill(id: String) -> SkillNodeDef:
	ensure_loaded()
	return _skills.get(id, null)


static func _load_dir(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		var clean := file_name.trim_suffix(".remap")
		if not (clean.ends_with(".tres") or clean.ends_with(".res")):
			continue
		var resource := load(path.path_join(clean))
		if resource != null:
			out.append(resource)
	return out
