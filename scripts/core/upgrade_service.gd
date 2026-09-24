class_name UpgradeService
extends RefCounted
## 업그레이드 구매 규칙(GDD 5장). 상태는 GameState 에 있고 여기는 계산·구매만 한다(연출 없음).
##   - 비용: UpgradeDef 종류별 공식 × upgrade_cost_mult
##   - 잠금: required_floor(층), required_marble_tier(광택은 돌부터), 재질 상한(현재 층 FloorDef.marble_tier_cap)
##   - 구매 수량: ×1 / ×10 / MAX(등비수열 합으로 살 수 있는 최대 레벨 수)
##   - 재질이 오르면 광택은 0 으로 돌아간다
## 구매가 끝나면 EventBus.upgrade_purchased(id, 새 레벨) 을 발행한다.

enum BuyMode { ONE, TEN, MAX }

enum Status {
	OK,               ## 살 수 있다
	NOT_ENOUGH_CHIPS, ## 칩 부족(잠금은 아님)
	MAX_LEVEL,        ## 최대 레벨
	LOCKED_FLOOR,     ## 층 조건 미달(required_floor)
	LOCKED_MARBLE,    ## 구슬 재질 조건 미달(required_marble_tier)
	CAPPED_BY_FLOOR,  ## 다음 재질이 현재 층 상한을 넘는다
	UNKNOWN,          ## 없는 업그레이드
}

const TEN := 10
## 비용 합과 예산 비교의 상대 허용 오차(등비수열 닫힌 식의 부동소수 오차 흡수).
const COST_EPSILON := 1e-9


## 카드 순서대로 정렬한 업그레이드 목록.
static func sorted_defs() -> Array[UpgradeDef]:
	var defs := GameData.upgrades()
	defs.sort_custom(func(a: UpgradeDef, b: UpgradeDef) -> bool: return a.sort_order < b.sort_order)
	return defs


static func level_of(id: String) -> int:
	return GameState.get_upgrade_level(id)


static func cost_mult() -> float:
	return GameState.get_stat(StatModifiers.UPGRADE_COST_MULT, StatModifiers.IDENTITY_MULT)


## 도매가(E12): 업그레이드 비용 증가율(growth) 자체에 곱해지는 배율.
static func growth_of(def: UpgradeDef) -> float:
	return def.growth * GameState.get_stat(StatModifiers.UPGRADE_GROWTH_MULT, StatModifiers.IDENTITY_MULT)


## 데이터상 최대 레벨(무제한이면 UpgradeDef.UNLIMITED). 재질은 구슬 수 - 1.
static func max_level(def: UpgradeDef) -> int:
	if def.kind == UpgradeDef.Kind.MARBLE_TIER:
		var last := GameData.marbles().size() - 1
		return mini(def.max_level, last) if def.max_level != UpgradeDef.UNLIMITED else last
	return def.max_level


## 지금 올릴 수 있는 레벨 상한(재질은 현재 층 상한까지). 무제한이면 UpgradeDef.UNLIMITED.
static func reachable_level(def: UpgradeDef) -> int:
	var top := max_level(def)
	if def.kind == UpgradeDef.Kind.MARBLE_TIER:
		var floor_def := GameState.current_floor()
		if floor_def != null:
			top = mini(top, floor_def.marble_tier_cap)
	return top


static func is_max(def: UpgradeDef, level: int) -> bool:
	var top := max_level(def)
	return top != UpgradeDef.UNLIMITED and level >= top


## level → level+1 비용(upgrade_cost_mult 포함).
static func cost_at(def: UpgradeDef, level: int) -> float:
	var mult := cost_mult()
	match def.kind:
		UpgradeDef.Kind.MARBLE_TIER:
			var next := GameData.marble(level + 1) if level + 1 < GameData.marbles().size() else null
			var marble_mult := GameState.get_stat(StatModifiers.MARBLE_COST_MULT, StatModifiers.IDENTITY_MULT)
			return next.cost * mult * marble_mult if next != null else INF
		UpgradeDef.Kind.MARBLE_POLISH:
			return Economy.upgrade_cost(_polish_base(), growth_of(def), level, mult)
	return Economy.upgrade_cost(def.base_cost, growth_of(def), level, mult)


## from_level 에서 count 레벨을 사는 총비용. 등비형은 닫힌 식 base·g^L·(g^n − 1)/(g − 1).
static func cost_for(def: UpgradeDef, from_level: int, count: int) -> float:
	if count <= 0:
		return 0.0
	var g := growth_of(def)
	if def.kind == UpgradeDef.Kind.MARBLE_TIER or is_equal_approx(g, 1.0):
		var total := 0.0
		for i in count:
			total += cost_at(def, from_level + i)
		return total
	return cost_at(def, from_level) * (pow(g, count) - 1.0) / (g - 1.0)


## budget 으로 from_level 부터 살 수 있는 최대 레벨 수(limit 이하). limit < 0 이면 무제한.
static func max_affordable(def: UpgradeDef, from_level: int, budget: float, limit: int) -> int:
	if limit == 0 or budget <= 0.0 or is_nan(budget):
		return 0
	var first := cost_at(def, from_level)
	if not _fits(first, budget):
		return 0
	var n := 1
	var g := growth_of(def)
	if def.kind == UpgradeDef.Kind.MARBLE_TIER or is_equal_approx(g, 1.0):
		while (limit < 0 or n < limit) and _fits(cost_for(def, from_level, n + 1), budget):
			n += 1
		return n
	# 닫힌 식의 역: n = floor(log_g(budget·(g−1)/first + 1)), 부동소수 오차는 ±1 로 맞춘다.
	var estimate := floori(log(budget * (g - 1.0) / first + 1.0) / log(g))
	n = maxi(estimate, 1)
	if limit >= 0:
		n = mini(n, limit)
	while n > 1 and not _fits(cost_for(def, from_level, n), budget):
		n -= 1
	while (limit < 0 or n < limit) and _fits(cost_for(def, from_level, n + 1), budget):
		n += 1
	return n


static func _fits(cost: float, budget: float) -> bool:
	return not is_inf(cost) and not is_nan(cost) and cost <= budget * (1.0 + COST_EPSILON)


## 잠금·최대 여부(칩은 보지 않는다).
static func lock_status(def: UpgradeDef) -> Status:
	var level := level_of(def.id)
	if is_max(def, level):
		return Status.MAX_LEVEL
	if GameState.floor_index < def.required_floor:
		return Status.LOCKED_FLOOR
	if GameState.marble_tier < def.required_marble_tier:
		return Status.LOCKED_MARBLE
	var reachable := reachable_level(def)
	if reachable != UpgradeDef.UNLIMITED and level >= reachable:
		return Status.CAPPED_BY_FLOOR
	return Status.OK


## 이 레벨 이상이 되려면 도달해야 하는 층 인덱스(재질 상한용). 없으면 -1.
static func floor_for_marble_tier(tier: int) -> int:
	for floor_def in GameData.floors():
		if floor_def.marble_tier_cap >= tier:
			return floor_def.index
	return -1


## 이번에 살 수량·비용·상태.
## 반환 {count: 살 레벨 수(살 수 없으면 다음 1레벨 또는 ×10 묶음), cost: 그 비용, status, affordable: bool}
static func plan(id: String, mode: BuyMode) -> Dictionary:
	var def := GameData.upgrade(id)
	if def == null:
		return {"count": 0, "cost": 0.0, "status": Status.UNKNOWN, "affordable": false}
	var level := level_of(id)
	var lock := lock_status(def)
	if lock != Status.OK:
		return {"count": 0, "cost": 0.0, "status": lock, "affordable": false}
	var reachable := reachable_level(def)
	var remaining := -1 if reachable == UpgradeDef.UNLIMITED else reachable - level
	# 재질은 한 번에 한 단계(승급 연출)
	if def.kind == UpgradeDef.Kind.MARBLE_TIER:
		remaining = mini(remaining, 1) if remaining >= 0 else 1
	var count := 1
	match mode:
		BuyMode.TEN:
			count = TEN if remaining < 0 else mini(TEN, remaining)
		BuyMode.MAX:
			count = maxi(1, max_affordable(def, level, GameState.chips, remaining))
	var cost := cost_for(def, level, count)
	var affordable := _fits(cost, GameState.chips)
	return {"count": count, "cost": cost, "status": Status.OK if affordable else Status.NOT_ENOUGH_CHIPS, "affordable": affordable}


## 구매한다. 산 레벨 수를 돌려준다(0 이면 실패, 아무것도 바뀌지 않음).
static func purchase(id: String, mode: BuyMode = BuyMode.ONE) -> int:
	var info := plan(id, mode)
	if not bool(info["affordable"]):
		return 0
	var cost := minf(float(info["cost"]), GameState.chips)
	if not GameState.spend_chips(cost):
		return 0
	var def := GameData.upgrade(id)
	var new_level := level_of(id) + int(info["count"])
	GameState.set_upgrade_level(id, new_level)
	if def.kind == UpgradeDef.Kind.MARBLE_TIER:
		GameState.set_upgrade_level(GameState.UPGRADE_MARBLE_POLISH, 0)
	EventBus.upgrade_purchased.emit(id, new_level)
	return int(info["count"])


## 오토 업그레이드(M7): budget(칩) 이내에서 살 수 있는 가장 싼 업그레이드 id. 없으면 "".
## include_marble 가 false 면 구슬 재질(MARBLE_TIER)은 후보에서 뺀다.
static func cheapest_affordable_id(budget: float, include_marble: bool) -> String:
	var best_id := ""
	var best_cost := INF
	for def: UpgradeDef in sorted_defs():
		if not include_marble and def.kind == UpgradeDef.Kind.MARBLE_TIER:
			continue
		var info := plan(def.id, BuyMode.ONE)
		if not bool(info["affordable"]):
			continue
		var cost := float(info["cost"])
		if cost > budget:
			continue
		if cost < best_cost:
			best_cost = cost
			best_id = def.id
	return best_id


## 지금 1레벨이라도 살 수 있는 업그레이드가 있는가(탭의 빨간 점).
static func any_affordable() -> bool:
	for def in GameData.upgrades():
		if bool(plan(def.id, BuyMode.ONE)["affordable"]):
			return true
	return false


# ── 표시용 효과값 ────────────────────────────────────────

enum ValueStyle { MULT, COUNT, SECONDS }


static func value_style(def: UpgradeDef) -> ValueStyle:
	match def.effect_stat:
		StatModifiers.MARBLE_SLOTS_BONUS, StatModifiers.GOLDEN_POCKET_COUNT:
			return ValueStyle.COUNT
		StatModifiers.SPIN_DURATION_MULT:
			return ValueStyle.SECONDS
	return ValueStyle.MULT


## 카드에 보여 줄 레벨 level 의 효과값.
##   재질: 재질 배율(광택 제외) / 광택: 광택 배율 / 베팅 한도: 한도 배율 / 구슬: 보유 구슬 수 / 휠: 스핀 시간(초) / 황금: 개수
static func display_value(def: UpgradeDef, level: int) -> float:
	match def.effect_stat:
		StatModifiers.MARBLE_SLOTS_BONUS:
			return float(Economy.STARTING_MARBLES) + def.effect_value(level)
		StatModifiers.SPIN_DURATION_MULT:
			var others := GameState.get_stat(StatModifiers.SPIN_DURATION_MULT, StatModifiers.IDENTITY_MULT) / def.effect_value(level_of(def.id))
			return Economy.spin_duration(others * def.effect_value(level))
	return def.effect_value(level)


static func format_value(def: UpgradeDef, value: float) -> String:
	match value_style(def):
		ValueStyle.COUNT:
			return NumberFormat.format(value)
		ValueStyle.SECONDS:
			return NumberFormat.format_seconds(value)
	return NumberFormat.format_mult(value)


static func _polish_base() -> float:
	var marble := GameState.current_marble()
	return marble.polish_base_cost if marble != null else 0.0
