class_name StatModifiers
extends RefCounted
## 모든 업그레이드·스킬·패널티·버프는 수정자로 이 시스템에 붙는다.
## 최종값 = (base + ADD 합) × MULT 곱
## base 는 호출하는 쪽(Economy 상수·데이터)이 넘긴다. 이 클래스는 밸런스 수치를 갖지 않는다.

signal changed(stat: String)
## 시간제 수정자가 만료되어 source_id 의 수정자가 하나도 남지 않았을 때.
signal source_expired(source_id: String)

enum Op { ADD, MULT }

## 영구 수정자의 duration 값.
const PERMANENT := -1.0
const IDENTITY_ADD := 0.0
const IDENTITY_MULT := 1.0

# ── 스탯 키 ──────────────────────────────────────────────
# 배당
const PAYOUT_MULT_ALL := "payout_mult_all"          ## 모든 당첨 배율 (base 1)
const PAYOUT_MULT_COLOR := "payout_mult_color"      ## RED/BLACK 당첨 배율 (base 1)
const PAYOUT_MULT_PARITY := "payout_mult_parity"    ## ODD/EVEN 당첨 배율 (base 1)
const STRAIGHT_PAYOUT_BONUS := "straight_payout_bonus"  ## 개별숫자 당첨 ×(1+값) (base 0)
const MARBLE_MULT := "marble_mult"                  ## 구슬 배율 (base 재질×광택)
const FLOOR_MULT := "floor_mult"                    ## 층 배율 (base 층 payout_mult)
const GOLDEN_POCKET_COUNT := "golden_pocket_count"  ## 황금 포켓 개수 (base 0)
const GOLDEN_POCKET_MULT := "golden_pocket_mult"    ## 황금 포켓 배율 (base Economy.GOLDEN_POCKET_MULT)
# 베팅·스핀
const MAX_BET_MULT := "max_bet_mult"                ## 구슬당 최대 베팅액 배율 (base 1)
const MARBLE_SLOTS_BONUS := "marble_slots_bonus"    ## 추가 구슬 수 (base 0)
const LOCKED_MARBLES := "locked_marbles"            ## 사용 불가 구슬 수, 압류 패널티 (base 0)
const EXTRA_BALLS := "extra_balls"                  ## 추가 공 수, 더블 볼 (base 0)
const SPIN_DURATION_MULT := "spin_duration_mult"    ## 스핀 시간 배율 (base 1)
const SPIN_DELAY := "spin_delay"                    ## 자동 스핀 간 대기 초 (base Economy.AUTO_SPIN_DELAY)
# 경제
const UPGRADE_COST_MULT := "upgrade_cost_mult"      ## 업그레이드 비용 배율 (base 1)
const CASHBACK_RATE := "cashback_rate"              ## 패배 베팅 환급 비율 (base 0)
const OFFLINE_EFFICIENCY := "offline_efficiency"    ## 오프라인 수익 효율 (base Economy.OFFLINE_EFFICIENCY)
const OFFLINE_CAP_HOURS := "offline_cap_hours"      ## 오프라인 수익 최대 시간 (base Economy.OFFLINE_CAP_HOURS)
const CLOVER_GAIN_MULT := "clover_gain_mult"        ## 클로버 획득 배율 (base 1)
# 빚
const DEBT_REPAY_MULT := "debt_repay_mult"          ## 상환액 배율 (base Economy.DEBT_REPAY_FACTOR)
const PENALTY_INTERVAL_MULT := "penalty_interval_mult"  ## 패널티 간격 배율 (base 1)
const DEBT_PAID_CLOVER_BONUS := "debt_paid_clover_bonus"  ## 빚 완납 클로버 추가분 (base 0, E11)

# ── 6단계: 스킬트리·클로버·자동화·특수 기능 ──────────────────
# 배당(FORTUNE 조건부 효과 — 스탯값은 "레벨당 배율"이고 실제 적용은 조건이 맞을 때만 코드가 곱한다)
const CLOVER_BONUS_CHANCE := "clover_bonus_chance"          ## F4: 클로버 획득 시 추가 +1 확률 (base 0)
const STREAK_BONUS_PER_WIN := "streak_bonus_per_win"        ## F5: 연승 1회당 배당 보너스 (base 0)
const STREAK_BONUS_CAP := "streak_bonus_cap"                ## F11: 연승 보너스 최대 반영 연승 수 (base Economy.STREAK_BONUS_CAP_BASE)
const HOT_NUMBER_STRAIGHT_MULT := "hot_number_straight_mult"  ## F6: 핫 넘버 스트레이트 배당 배율 (base 1)
const MULTI_HIT_BONUS := "multi_hit_bonus"                  ## F8: 한 스핀 2개 이상 적중 시 총 당첨 보너스 (base 0)
const LUCKY_SEVEN_MULT := "lucky_seven_mult"                ## F9: 7·17·27 결과 전체 배당 배율 (base 1)
const MILESTONE_CLOVER_BONUS := "milestone_clover_bonus"    ## F13: 마일스톤 클로버 추가분 (base 0)
# 자동화(MACHINE)
const SMART_BETTING_BONUS := "smart_betting_bonus"          ## M12: 스마트 베팅 사용 중 배당 보너스 (base 0)
const MIN_SPIN_DURATION := "min_spin_duration_stat"         ## M10: 스핀 시간 최소값(초) 오버라이드 (base Economy.MIN_SPIN_DURATION)
# 경제(ECONOMY)
const VIP_COMP_RATE := "vip_comp_rate"                      ## E3: 스핀마다 최대 베팅액 대비 지급 비율 (base 0)
const INVESTMENT_RATE := "investment_rate"                  ## E5: 10초마다 보유 칩 대비 이자율 (base 0)
const MARBLE_COST_MULT := "marble_cost_mult"                ## E8: 구슬 재질 비용 배율 (base 1)
const BONUS_CHIP_PER_HIT := "bonus_chip_per_hit"            ## E9: 개별숫자 적중 시 최대 베팅×N 추가 (base 0)
const UPGRADE_GROWTH_MULT := "upgrade_growth_mult"          ## E12: 업그레이드 비용 증가율 배율 (base 1)
const PIGGY_BANK_RATE := "piggy_bank_rate"                  ## E13: 100스핀마다 누적 순이익 대비 보너스 비율 (base 0)
const COMPOUND_INTEREST_PER_DIGIT := "compound_interest_per_digit"  ## E14: 보유 칩 자릿수당 배당 보너스 (base 0)
# 특수 기능(MYSTIC)
const MIRROR_CHANCE := "mirror_chance"                      ## Y3: 진 베팅 무승부(반환) 확률 (base 0)
const ZERO_STRAIGHT_MULT := "zero_straight_mult"            ## Y7: 0 스트레이트 적중 배율 (base 1)
const DESTINY_FLIP_CHANCE := "destiny_flip_chance"          ## Y8: 전패 시 재판정 확률 (base 0)
const FEVER_PERIOD_REDUCTION := "fever_period_reduction"    ## Y11: 피버 주기 감소(스핀 수) (base 0)
const FEVER_DURATION_BONUS := "fever_duration_bonus"        ## Y11: 피버 지속시간 추가(초) (base 0)
const GOLDEN_STORM_CHANCE := "golden_storm_chance"          ## Y12: 황금 포켓 적중 시 황금 폭풍 확률 (base 0)
const BUFF_DURATION_MULT := "buff_duration_mult"            ## Y13: 시간제 버프 지속시간 배율 (base 1)

const ALL_STATS: Array[String] = [
	PAYOUT_MULT_ALL, PAYOUT_MULT_COLOR, PAYOUT_MULT_PARITY, STRAIGHT_PAYOUT_BONUS,
	MARBLE_MULT, FLOOR_MULT, GOLDEN_POCKET_COUNT, GOLDEN_POCKET_MULT,
	MAX_BET_MULT, MARBLE_SLOTS_BONUS, LOCKED_MARBLES, EXTRA_BALLS, SPIN_DURATION_MULT, SPIN_DELAY,
	UPGRADE_COST_MULT, CASHBACK_RATE, OFFLINE_EFFICIENCY, OFFLINE_CAP_HOURS, CLOVER_GAIN_MULT,
	DEBT_REPAY_MULT, PENALTY_INTERVAL_MULT, DEBT_PAID_CLOVER_BONUS,
	CLOVER_BONUS_CHANCE, STREAK_BONUS_PER_WIN, STREAK_BONUS_CAP, HOT_NUMBER_STRAIGHT_MULT,
	MULTI_HIT_BONUS, LUCKY_SEVEN_MULT, MILESTONE_CLOVER_BONUS, SMART_BETTING_BONUS, MIN_SPIN_DURATION,
	VIP_COMP_RATE, INVESTMENT_RATE, MARBLE_COST_MULT, BONUS_CHIP_PER_HIT, UPGRADE_GROWTH_MULT,
	PIGGY_BANK_RATE, COMPOUND_INTEREST_PER_DIGIT, MIRROR_CHANCE, ZERO_STRAIGHT_MULT, DESTINY_FLIP_CHANCE,
	FEVER_PERIOD_REDUCTION, FEVER_DURATION_BONUS, GOLDEN_STORM_CHANCE, BUFF_DURATION_MULT,
]


class Modifier:
	extends RefCounted
	var source_id: String
	var stat: String
	var op: Op
	var value: float
	## 전체 지속 시간. PERMANENT 면 영구.
	var duration: float
	var remaining: float
	## 소모형(횟수제) 수정자의 남은 횟수. -1 이면 소모형이 아님(시간제·영구는 이 값과 무관).
	var charges: int = -1

	func is_timed() -> bool:
		return duration >= 0.0

	func is_charge_based() -> bool:
		return charges >= 0

	func to_dict() -> Dictionary:
		return {"source_id": source_id, "stat": stat, "op": int(op), "value": value,
			"duration": duration, "remaining": remaining, "charges": charges}


var _modifiers: Array[Modifier] = []
## stat → [add 합, mult 곱]. 수정자가 바뀌면 해당 stat 만 무효화한다.
var _cache: Dictionary = {}


## 수정자를 추가한다. 같은 source_id + stat 이 이미 있으면 교체(갱신)한다.
## 업그레이드 레벨이 오르면 같은 source 로 다시 add 하면 된다.
## charges: 소모형(횟수제)이면 남은 횟수(예: 1). -1 이면 소모형이 아니다(시간제·영구는 duration 으로만 관리).
func add_modifier(source_id: String, stat: String, op: Op, value: float, duration: float = PERMANENT, charges: int = -1) -> Modifier:
	if not ALL_STATS.has(stat):
		push_warning("StatModifiers: 정의되지 않은 스탯 키 '%s'" % stat)
	if is_nan(value) or is_inf(value):
		push_error("StatModifiers: '%s' 의 값이 비정상(%s)" % [source_id, value])
		return null
	_remove_where(func(m: Modifier) -> bool: return m.source_id == source_id and m.stat == stat)
	var modifier := Modifier.new()
	modifier.source_id = source_id
	modifier.stat = stat
	modifier.op = op
	modifier.value = value
	modifier.duration = duration
	modifier.remaining = duration
	modifier.charges = charges
	_modifiers.append(modifier)
	_invalidate(stat)
	return modifier


## source_id 의 수정자를 전부 제거하고 제거한 개수를 돌려준다.
func remove_source(source_id: String) -> int:
	return _remove_where(func(m: Modifier) -> bool: return m.source_id == source_id)


## 소모형(횟수제) 수정자를 amount 만큼 소모한다(예: 압류 패널티가 스핀 1회에 소모).
## charges 가 0 이하가 된 수정자는 즉시 제거된다. source_id 에 소모형 수정자가 없으면 아무 일도 하지 않고 false.
## 소모로 source_id 의 수정자가 모두 사라지면 source_expired 를 발행한다(시간제 만료와 동일하게 처리).
func consume_charges(source_id: String, amount: int = 1) -> bool:
	var consumed := false
	var to_remove: Array[Modifier] = []
	for modifier in _modifiers:
		if modifier.source_id != source_id or not modifier.is_charge_based():
			continue
		modifier.charges -= amount
		consumed = true
		_invalidate(modifier.stat)
		if modifier.charges <= 0:
			to_remove.append(modifier)
	if not consumed:
		return false
	for modifier in to_remove:
		_modifiers.erase(modifier)
	if not to_remove.is_empty() and not has_source(source_id):
		source_expired.emit(source_id)
	return true


## source_id 의 소모형 수정자 중 남은 횟수(여러 개면 최댓값). 소모형이 없으면 -1.
func charges_remaining(source_id: String) -> int:
	var best := -1
	for modifier in _modifiers:
		if modifier.source_id == source_id and modifier.is_charge_based():
			best = maxi(best, modifier.charges)
	return best


func has_source(source_id: String) -> bool:
	for modifier in _modifiers:
		if modifier.source_id == source_id:
			return true
	return false


## source_id 의 시간제 수정자 중 가장 긴 남은 시간. 없으면 0.
func remaining_time(source_id: String) -> float:
	var best := 0.0
	for modifier in _modifiers:
		if modifier.source_id == source_id and modifier.is_timed():
			best = maxf(best, modifier.remaining)
	return best


func clear() -> void:
	var stats: Array[String] = []
	for modifier in _modifiers:
		if not stats.has(modifier.stat):
			stats.append(modifier.stat)
	_modifiers.clear()
	_cache.clear()
	for stat in stats:
		changed.emit(stat)


## (base + ADD 합) × MULT 곱.
func get_stat(stat: String, base: float) -> float:
	var entry: Array = _cache.get(stat, [])
	if entry.is_empty():
		var add_sum := IDENTITY_ADD
		var mult_product := IDENTITY_MULT
		for modifier in _modifiers:
			if modifier.stat != stat:
				continue
			if modifier.op == Op.ADD:
				add_sum += modifier.value
			else:
				mult_product *= modifier.value
		entry = [add_sum, mult_product]
		_cache[stat] = entry
	return (base + float(entry[0])) * float(entry[1])


## 시간제 수정자를 진행시키고 만료된 것을 제거한다.
## 만료로 수정자가 모두 사라진 source_id 목록을 돌려주고 source_expired 를 발행한다.
func tick(delta: float) -> Array[String]:
	var expired_sources: Array[String] = []
	var expired: Array[Modifier] = []
	for modifier in _modifiers:
		if not modifier.is_timed():
			continue
		modifier.remaining -= delta
		if modifier.remaining <= 0.0:
			expired.append(modifier)
	if expired.is_empty():
		return expired_sources
	for modifier in expired:
		_modifiers.erase(modifier)
		_invalidate(modifier.stat)
	for modifier in expired:
		if not expired_sources.has(modifier.source_id) and not has_source(modifier.source_id):
			expired_sources.append(modifier.source_id)
	for source_id in expired_sources:
		source_expired.emit(source_id)
	return expired_sources


func count() -> int:
	return _modifiers.size()


func get_modifiers() -> Array[Modifier]:
	return _modifiers.duplicate()


func _remove_where(predicate: Callable) -> int:
	var removed: Array[Modifier] = []
	for modifier in _modifiers:
		if predicate.call(modifier):
			removed.append(modifier)
	for modifier in removed:
		_modifiers.erase(modifier)
		_invalidate(modifier.stat)
	return removed.size()


func _invalidate(stat: String) -> void:
	_cache.erase(stat)
	changed.emit(stat)
