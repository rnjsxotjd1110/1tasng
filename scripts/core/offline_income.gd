class_name OfflineIncome
extends RefCounted
## 오프라인 수익 계산(순수). 시계 조작 방어와 팁/없음/전체 분기를 결정하고, 금액 공식은 Economy.offline_income 에 맡긴다.

enum Mode { NONE, TIP, FULL }

var mode: Mode = Mode.NONE
## 실제 경과 시간(시계 조작으로 음수·과거면 0).
var elapsed_seconds: float = 0.0
## OFFLINE_MIN_ELAPSED 이상이어야 계산 대상(그 미만이면 팝업 없이 넘어간다).
var eligible: bool = false
## 상한이 적용된 뒤의 경과 시간(표시용, "3시간 12분 (최대 2시간 적용)").
var capped_seconds: float = 0.0
var income: float = 0.0


## saved_at·now 는 unix 초. auto_spin_unlocked 가 false 면 항상 TIP(오토 해금 전 초반).
## auto_spin_unlocked 인데 auto_spin_enabled 가 false 면 NONE(꺼둔 채 닫았다).
static func compute(income_per_second: float, saved_at: float, now: float, auto_spin_unlocked: bool,
		auto_spin_enabled: bool, cap_hours: float, efficiency: float, tip_efficiency: float) -> OfflineIncome:
	var result := OfflineIncome.new()
	var elapsed := now - saved_at
	if elapsed <= 0.0:
		return result
	result.elapsed_seconds = elapsed
	if elapsed < Economy.OFFLINE_MIN_ELAPSED:
		return result
	result.eligible = true
	result.capped_seconds = minf(elapsed, cap_hours * 3600.0)
	if not auto_spin_unlocked:
		result.mode = Mode.TIP
		result.income = Economy.offline_income(income_per_second, elapsed, cap_hours, tip_efficiency)
	elif auto_spin_enabled:
		result.mode = Mode.FULL
		result.income = Economy.offline_income(income_per_second, elapsed, cap_hours, efficiency)
	else:
		result.mode = Mode.NONE
		result.income = 0.0
	return result
