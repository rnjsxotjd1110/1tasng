class_name SkillService
extends RefCounted
## 스킬트리 구매 규칙(GDD 6장). 상태는 GameState.skill_levels 에 있고 여기는 계산·구매만 한다(연출 없음).
##   - 비용: SkillNodeDef.costs[level] (클로버, 노드별 고정 배열 — 업그레이드처럼 등비가 아니다)
##   - 잠금: 선행조건(prerequisites, ALL=전부 필요/ANY=하나만 있으면 됨)
##   - HEART(SkillNodeDef.is_heart())는 항상 레벨 1(구매 불가)
## 구매가 끝나면 EventBus.skill_purchased(id, 새 레벨) 을 발행한다.
## 기능 해금형 스킬(오토 스핀·딜러 고용 등)은 feature_id 로 표시되고, 다른 시스템은 feature_level()/has_feature() 로 조회한다.

enum Status {
	OK,               ## 살 수 있다(클로버는 별도 확인)
	NOT_ENOUGH_CLOVERS,
	MAX_LEVEL,
	LOCKED_PREREQ,
	IS_HEART,
	UNKNOWN,
}


static func level(id: String) -> int:
	if id == GameState.SKILL_HEART_ID:
		return 1
	return int(GameState.skill_levels.get(id, 0))


static func is_owned(id: String) -> bool:
	return level(id) > 0


## feature_id 를 가진 스킬(보유했다면)의 레벨. 없거나 미보유면 0.
static func feature_level(feature_id: String) -> int:
	if feature_id == "":
		return 0
	for def: SkillNodeDef in GameData.skills():
		if def.feature_id == feature_id:
			var lv := level(def.id)
			if lv > 0:
				return lv
	return 0


static func has_feature(feature_id: String) -> bool:
	return feature_level(feature_id) > 0


static func prerequisites_met(def: SkillNodeDef) -> bool:
	if def.prerequisites.is_empty():
		return true
	if def.prerequisite_mode == SkillNodeDef.PrereqMode.ANY:
		for id: String in def.prerequisites:
			if is_owned(id):
				return true
		return false
	for id: String in def.prerequisites:
		if not is_owned(id):
			return false
	return true


## 잠금 상태만 본다(클로버 보유량은 안 본다 — can_purchase 가 합쳐서 본다).
static func lock_status(def: SkillNodeDef) -> Status:
	if def.is_heart():
		return Status.IS_HEART
	if level(def.id) >= def.max_level():
		return Status.MAX_LEVEL
	if not prerequisites_met(def):
		return Status.LOCKED_PREREQ
	return Status.OK


## 다음 레벨 비용(클로버). 살 수 없는 상태(최대·HEART)면 -1.
static func cost_for_next(def: SkillNodeDef) -> int:
	if lock_status(def) not in [Status.OK, Status.LOCKED_PREREQ]:
		return -1
	return def.cost_at(level(def.id))


static func can_purchase(def: SkillNodeDef) -> bool:
	if lock_status(def) != Status.OK:
		return false
	var cost := def.cost_at(level(def.id))
	return cost >= 0 and GameState.clovers >= cost


## 구매한다. 성공하면 새 레벨을 돌려준다(1 이상). 실패(잠김·비용 부족)면 -1이고 아무것도 바뀌지 않는다.
static func purchase(id: String) -> int:
	var def := GameData.skill(id)
	if def == null or not can_purchase(def):
		return -1
	var cost := def.cost_at(level(id))
	if not GameState.spend_clovers(cost):
		return -1
	var new_level := level(id) + 1
	GameState.set_skill_level(id, new_level)
	EventBus.skill_purchased.emit(id, new_level)
	return new_level


## 지금 1레벨이라도 살 수 있는 스킬이 있는가(스킬트리 버튼 알림 등에 쓸 수 있다).
static func any_affordable() -> bool:
	for def: SkillNodeDef in GameData.skills():
		if can_purchase(def):
			return true
	return false


## 투자한 클로버(구매에 쓴 총액) / 전체 스킬트리 총비용.
static func invested_total() -> int:
	var total := 0
	for def: SkillNodeDef in GameData.skills():
		if def.is_heart():
			continue
		total += def.cumulative_cost(level(def.id))
	return total


static func grand_total() -> int:
	var total := 0
	for def: SkillNodeDef in GameData.skills():
		total += def.total_cost()
	return total


## 노드가 화면에서 잠긴 것으로 보여야 하는지(선행조건 미충족). MAX/HEART 는 잠김이 아니다.
static func is_locked(def: SkillNodeDef) -> bool:
	return lock_status(def) == Status.LOCKED_PREREQ


static func is_maxed(def: SkillNodeDef) -> bool:
	return not def.is_heart() and level(def.id) >= def.max_level()
