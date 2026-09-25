extends Node
## 스팀(GodotSteam, 선택 애드온) 연동을 감싼다(8단계 5/N, docs/STEAM.md).
## GodotSteam 이 프로젝트에 없거나 스팀 밖에서 실행 중이면(`is_available=false`) 모든 함수가 조용히
## 아무 일도 하지 않는다 — 이 게임은 스팀 없이도 완전히 동작해야 한다(GodotSteam 을 필수 의존성으로 두지 않음).
## 업적 id → 스팀 API 이름 규칙: "ACH_" + id 를 대문자로(예: first_spin → ACH_FIRST_SPIN). 표는 docs/STEAM.md.

var is_available: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_available = Engine.has_singleton("Steam")
	if not is_available:
		return
	var steam: Object = Engine.get_singleton("Steam")
	steam.steamInit()
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)


func steam_achievement_id(id: String) -> String:
	return "ACH_" + id.to_upper()


func _on_achievement_unlocked(id: String) -> void:
	if not is_available:
		return
	var steam: Object = Engine.get_singleton("Steam")
	steam.setAchievement(steam_achievement_id(id))
	steam.storeStats()
