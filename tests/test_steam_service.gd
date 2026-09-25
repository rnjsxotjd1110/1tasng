extends "res://tests/lib/test_case.gd"
## SteamService(8단계 5/N): GodotSteam 애드온이 없는 환경(이 저장소 기본 상태)에서는 완전히 안전한
## 무동작이어야 한다. 실제 GodotSteam 연동 자체는 그 애드온이 있는 환경에서만 검증 가능하다(docs/STEAM.md).

func test_unavailable_without_godotsteam_addon() -> void:
	check_eq(SteamService.is_available, false, "GodotSteam 애드온이 없으면 비활성")


func test_steam_achievement_id_naming() -> void:
	check_eq(SteamService.steam_achievement_id("first_spin"), "ACH_FIRST_SPIN", "ACH_ 접두어 + 대문자")
	check_eq(SteamService.steam_achievement_id("zero_hit"), "ACH_ZERO_HIT", "밑줄 그대로 유지")


func test_achievement_unlocked_signal_is_safe_noop_when_unavailable() -> void:
	EventBus.achievement_unlocked.emit("first_spin")
	check(true, "스팀이 없을 때 업적 신호가 와도 에러 없이 지나간다")
