class_name FloorService
extends RefCounted
## 층 이동 규칙(GDD 7장). 상태는 GameState 에 있고 여기는 조건 판정·이동만 한다(연출 없음).
## `UpgradeService`/`DebtService` 와 같은 형태: static, 상태 없음.
## 이동이 끝나면 EventBus.floor_changed(새 floor_index) 를 발행한다.

## 다음 층 정의. 이미 최고층(PH)이면 null.
static func next_floor_def() -> FloorDef:
	var floors := GameData.floors()
	var next_index := GameState.floor_index + 1
	if next_index >= floors.size():
		return null
	return floors[next_index]


static func is_max_floor() -> bool:
	return next_floor_def() == null


## 다음 층 비용 대비 진행률(0~1). 이미 최고층이면 1(상단 바 진행률 바용).
static func progress() -> float:
	var next_def := next_floor_def()
	if next_def == null or next_def.cost <= 0.0:
		return 1.0
	return clampf(GameState.chips / next_def.cost, 0.0, 1.0)


static func can_move() -> bool:
	var next_def := next_floor_def()
	return next_def != null and GameState.chips >= next_def.cost


## 다음 층으로 이동한다. 칩을 낸 뒤 배율이 오르고 클로버를 받는다(리셋 없음). 이동했으면 true.
static func move_to_next() -> bool:
	var next_def := next_floor_def()
	if next_def == null or not GameState.spend_chips(next_def.cost):
		return false
	GameState.floor_index = next_def.index
	GameState.add_clovers(next_def.clover_reward)
	EventBus.floor_changed.emit(GameState.floor_index)
	return true
