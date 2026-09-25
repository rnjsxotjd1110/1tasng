class_name EndingService
extends RefCounted
## 엔딩·무한 모드 판정(GDD 10장). 상태는 GameState 에 있고 여기는 조건 판정·전이만 한다(컷신 연출은 7단계 3/N 화면).

## PH(마지막 층)이고 칩이 ENDING_COST 이상이며 아직 엔딩을 안 봤을 때만 true(엔딩 버튼이 나타날 조건).
static func can_trigger() -> bool:
	if GameState.ending_reached:
		return false
	if not FloorService.is_max_floor():
		return false
	return GameState.chips >= Economy.ENDING_COST


## 칩을 내고 엔딩을 확정한다(연출은 호출부가 EventBus.ending_triggered 를 듣고 이어서 재생). 실패하면 false.
## 새 주인이 되며 남은 빚은 전부 탕감된다(GDD 10-2: 에필로그에서 남작이 이를 언급).
static func trigger() -> bool:
	if not can_trigger():
		return false
	if not GameState.spend_chips(Economy.ENDING_COST):
		return false
	GameState.ending_reached = true
	GameState.forgive_debt(1.0)
	EventBus.ending_triggered.emit()
	return true


## 엔딩 크레딧 뒤 "계속하기": 오너 모드 진입(수익 ×2, 상단 바 왕관 아이콘). 이미 무한 모드면 아무 일도 하지 않는다.
static func enter_infinite_mode() -> void:
	if GameState.infinite_mode:
		return
	GameState.infinite_mode = true
	GameState.rebuild_ending_modifiers()
	EventBus.infinite_mode_started.emit()
