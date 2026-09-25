extends "res://tests/lib/test_case.gd"
## OfflineIncome.compute: 상한·효율 분기(팁/없음/전체)·시계 조작 방어·60초 미만 무시.

const CAP_HOURS := 2.0
const EFFICIENCY := 0.3
const TIP_EFFICIENCY := 0.05


func test_tip_mode_when_auto_not_unlocked() -> void:
	var result := OfflineIncome.compute(10.0, 0.0, 3600.0, false, false, CAP_HOURS, EFFICIENCY, TIP_EFFICIENCY)
	check_eq(result.mode, OfflineIncome.Mode.TIP, "오토 해금 전이면 항상 팁")
	check(result.eligible, "1시간 경과는 계산 대상")
	check_rel(result.income, 10.0 * 3600.0 * TIP_EFFICIENCY, 1e-9, "팁 효율 5%")


func test_full_mode_when_auto_unlocked_and_enabled() -> void:
	var result := OfflineIncome.compute(10.0, 0.0, 3600.0, true, true, CAP_HOURS, EFFICIENCY, TIP_EFFICIENCY)
	check_eq(result.mode, OfflineIncome.Mode.FULL, "해금 + 켜짐 = 전체")
	check_rel(result.income, 10.0 * 3600.0 * EFFICIENCY, 1e-9, "기본 효율 30%")


func test_none_mode_when_auto_unlocked_but_disabled() -> void:
	var result := OfflineIncome.compute(10.0, 0.0, 3600.0, true, false, CAP_HOURS, EFFICIENCY, TIP_EFFICIENCY)
	check_eq(result.mode, OfflineIncome.Mode.NONE, "해금됐지만 꺼둔 채 닫으면 수익 없음")
	check_eq(result.income, 0.0, "수익 0")
	check(result.eligible, "eligible 은 여전히 true(경과 시간 자체는 유효)")


func test_cap_hours_limits_income() -> void:
	var five_hours := 5.0 * 3600.0
	var result := OfflineIncome.compute(10.0, 0.0, five_hours, true, true, CAP_HOURS, EFFICIENCY, TIP_EFFICIENCY)
	check_rel(result.capped_seconds, CAP_HOURS * 3600.0, 1e-9, "2시간로 상한")
	check_rel(result.income, 10.0 * (CAP_HOURS * 3600.0) * EFFICIENCY, 1e-9, "상한이 적용된 시간만큼만 지급")
	check_rel(result.elapsed_seconds, five_hours, 1e-9, "elapsed_seconds 자체는 실제 경과(표시용)")


func test_negative_or_past_saved_at_is_ignored() -> void:
	# 시계를 과거로 돌린 경우(now < saved_at): 방어적으로 수익 없음.
	var result := OfflineIncome.compute(10.0, 1000.0, 500.0, true, true, CAP_HOURS, EFFICIENCY, TIP_EFFICIENCY)
	check_eq(result.mode, OfflineIncome.Mode.NONE, "시계 조작 방어")
	check_eq(result.income, 0.0, "수익 0")
	check(not result.eligible, "팝업 대상 아님")


func test_under_60_seconds_is_not_eligible() -> void:
	var result := OfflineIncome.compute(10.0, 0.0, 59.0, true, true, CAP_HOURS, EFFICIENCY, TIP_EFFICIENCY)
	check(not result.eligible, "60초 미만은 팝업 없이 넘어간다")
	check_eq(result.income, 0.0, "적용하지 않음")
	check_rel(result.elapsed_seconds, 59.0, 1e-9, "elapsed_seconds 는 기록됨")


func test_zero_income_rate_gives_zero() -> void:
	var result := OfflineIncome.compute(0.0, 0.0, 3600.0, true, true, CAP_HOURS, EFFICIENCY, TIP_EFFICIENCY)
	check_eq(result.income, 0.0, "초당 수익이 0이면 오프라인 수익도 0")


func test_negative_income_rate_gives_zero() -> void:
	var result := OfflineIncome.compute(-5.0, 0.0, 3600.0, true, true, CAP_HOURS, EFFICIENCY, TIP_EFFICIENCY)
	check_eq(result.income, 0.0, "최근 순수익이 음수면 오프라인 수익은 0(GDD: 음수면 0)")
