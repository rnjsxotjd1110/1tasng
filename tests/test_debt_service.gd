extends "res://tests/lib/test_case.gd"


func test_take_loan_uses_min_bet_floor() -> void:
	var result := DebtService.take_loan([], 0.0, 10.0, Economy.DEBT_REPAY_FACTOR)
	check_near(result["principal"], 10.0 * Economy.LOAN_MIN_BET_MULT, 1e-9, "소득이 0이면 최소 베팅 바닥")
	check_near(result["repay"], result["principal"] * Economy.DEBT_REPAY_FACTOR, 1e-9, "상환액 = 대출액 × 배율")
	check_eq((result["debts"] as Array).size(), 1, "새 항목 1개")
	check_eq(result["merged"], false, "합산 아님")


func test_take_loan_uses_income_when_larger() -> void:
	var income := 100.0
	var result := DebtService.take_loan([], income, 1.0, Economy.DEBT_REPAY_FACTOR)
	check_near(result["principal"], income * Economy.LOAN_INCOME_SECONDS, 1e-6, "소득 기반이 더 크면 그쪽 사용")


func test_fourth_loan_merges_into_largest() -> void:
	var debts: Array[Dictionary] = [
		{"principal": 100.0, "remaining": 50.0},
		{"principal": 100.0, "remaining": 200.0},
		{"principal": 100.0, "remaining": 30.0},
	]
	check_eq(Economy.MAX_LOANS, 3, "전제: 최대 3건")
	var result := DebtService.take_loan(debts, 0.0, 10.0, Economy.DEBT_REPAY_FACTOR)
	var out: Array[Dictionary] = result["debts"]
	check_eq(out.size(), 3, "항목 수는 그대로")
	check_eq(result["merged"], true, "합산됨")
	check_eq(result["merged_index"], 1, "잔액이 가장 큰 인덱스")
	check_near(float(out[1]["remaining"]), 200.0 + float(result["repay"]), 1e-6, "잔액에 합산")
	check_near(float(out[0]["remaining"]), 50.0, 1e-9, "다른 항목은 그대로")


func test_repay_oldest_first_overflows_to_next() -> void:
	var debts: Array[Dictionary] = [
		{"principal": 10.0, "remaining": 10.0},
		{"principal": 10.0, "remaining": 20.0},
	]
	var result := DebtService.repay_oldest_first(debts, 15.0)
	var out: Array[Dictionary] = result["debts"]
	check_eq(out.size(), 1, "첫 빚은 완전히 갚아 제거됨")
	check_near(float(out[0]["remaining"]), 15.0, 1e-9, "남은 5가 둘째 빚에 적용")
	check_near(result["repaid"], 15.0, 1e-9, "총 상환액")


func test_repay_oldest_first_partial_leaves_debt() -> void:
	var debts: Array[Dictionary] = [{"principal": 10.0, "remaining": 10.0}]
	var result := DebtService.repay_oldest_first(debts, 4.0)
	var out: Array[Dictionary] = result["debts"]
	check_eq(out.size(), 1, "남아있음")
	check_near(float(out[0]["remaining"]), 6.0, 1e-9, "일부만 상환")


func test_repay_at_full_removes_entry() -> void:
	var debts: Array[Dictionary] = [
		{"principal": 10.0, "remaining": 10.0},
		{"principal": 10.0, "remaining": 20.0},
	]
	var result := DebtService.repay_at(debts, 0, 10.0)
	var out: Array[Dictionary] = result["debts"]
	check_eq(out.size(), 1, "0번 제거")
	check_near(float(out[0]["remaining"]), 20.0, 1e-9, "1번은 그대로")
	check_near(result["repaid"], 10.0, 1e-9, "상환액")


func test_repay_at_half_keeps_entry() -> void:
	var debts: Array[Dictionary] = [{"principal": 10.0, "remaining": 20.0}]
	var result := DebtService.repay_at(debts, 0, 10.0)
	var out: Array[Dictionary] = result["debts"]
	check_eq(out.size(), 1, "절반이면 남음")
	check_near(float(out[0]["remaining"]), 10.0, 1e-9, "절반 차감")


func test_repay_at_clamps_to_remaining() -> void:
	var debts: Array[Dictionary] = [{"principal": 10.0, "remaining": 5.0}]
	var result := DebtService.repay_at(debts, 0, 999.0)
	check_near(result["repaid"], 5.0, 1e-9, "잔액 이상은 못 받음")
	check_eq((result["debts"] as Array).size(), 0, "제거됨")


func test_total_sums_remaining() -> void:
	var debts: Array[Dictionary] = [
		{"principal": 10.0, "remaining": 5.0},
		{"principal": 10.0, "remaining": 7.5},
	]
	check_near(DebtService.total(debts), 12.5, 1e-9, "잔액 합")
	check_eq(DebtService.total([]), 0.0, "빈 배열은 0")


func test_progress_ratio_reflects_remaining() -> void:
	var debts: Array[Dictionary] = [{"principal": 10.0, "remaining": 20.0}]
	check_near(DebtService.progress_ratio(debts, 2.0), 0.0, 1e-9, "막 대출: 진행률 0")
	debts[0]["remaining"] = 10.0
	check_near(DebtService.progress_ratio(debts, 2.0), 0.5, 1e-9, "절반 상환")
	debts[0]["remaining"] = 0.0
	check_near(DebtService.progress_ratio(debts, 2.0), 1.0, 1e-9, "완납")


func test_progress_ratio_with_no_debts_is_full() -> void:
	check_eq(DebtService.progress_ratio([], 2.0), 1.0, "빚 없으면 100%")


func test_inputs_are_not_mutated() -> void:
	var debts: Array[Dictionary] = [{"principal": 10.0, "remaining": 10.0}]
	DebtService.repay_at(debts, 0, 10.0)
	check_near(float(debts[0]["remaining"]), 10.0, 1e-9, "원본 배열은 변하지 않음(순수 함수)")
