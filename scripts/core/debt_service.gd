class_name DebtService
extends RefCounted
## 빚 계산(순수 로직, 노드·연출 모름). GameState.debts 는 Array[Dictionary]({"principal","remaining"}).
## 금액 공식은 Economy.loan_amount()/debt_repay_amount() 에 맡기고, 여기서는 "몇 건을 어떻게 나눌지"만 다룬다.


## 새 대출을 만든다. Economy.MAX_LOANS 건 미만이면 새 항목을 추가하고, 이미 상한이면
## 잔액이 가장 큰 기존 빚에 원금·잔액을 합산한다(항목 수는 늘지 않음).
## 반환: {"debts", "principal", "repay", "merged", "merged_index"(합산 아니면 -1)}
static func take_loan(debts: Array[Dictionary], avg_income_per_second: float, min_bet: float, repay_mult: float) -> Dictionary:
	var principal := Economy.loan_amount(min_bet, avg_income_per_second)
	var repay := Economy.debt_repay_amount(principal, repay_mult)
	var result_debts := _duplicate(debts)
	var merged := false
	var merged_index := -1
	if result_debts.size() >= Economy.MAX_LOANS:
		merged_index = _largest_remaining_index(result_debts)
		var entry: Dictionary = result_debts[merged_index]
		entry["principal"] = float(entry["principal"]) + principal
		entry["remaining"] = float(entry["remaining"]) + repay
		merged = true
	else:
		result_debts.append({"principal": principal, "remaining": repay})
	return {"debts": result_debts, "principal": principal, "repay": repay, "merged": merged, "merged_index": merged_index}


## 당첨금 중 Economy.DEBT_AUTO_REPAY_RATE 비율을 오래된 순으로 자동 상환한다.
static func apply_auto_repay(debts: Array[Dictionary], payout: float) -> Dictionary:
	return repay_oldest_first(debts, payout * Economy.DEBT_AUTO_REPAY_RATE)


## amount 를 오래된 순(배열 인덱스 순)으로 나눠 갚는다. 초과분은 다음 빚으로 넘어간다.
## 0 이 된 항목은 제거한다. 반환: {"debts", "repaid"(실제 상환된 총액)}
static func repay_oldest_first(debts: Array[Dictionary], amount: float) -> Dictionary:
	var result_debts := _duplicate(debts)
	var left := amount
	var repaid := 0.0
	var i := 0
	while i < result_debts.size() and left > 0.0:
		var entry: Dictionary = result_debts[i]
		var remaining := float(entry["remaining"])
		var pay := minf(remaining, left)
		entry["remaining"] = remaining - pay
		left -= pay
		repaid += pay
		if entry["remaining"] <= 0.0:
			result_debts.remove_at(i)
		else:
			i += 1
	return {"debts": result_debts, "repaid": repaid}


## index 번째 빚만 amount 만큼 상환(가용 칩 제한은 호출자가 amount 를 미리 clamp 할 것). 0 되면 제거.
## 반환: {"debts", "repaid"}
static func repay_at(debts: Array[Dictionary], index: int, amount: float) -> Dictionary:
	var result_debts := _duplicate(debts)
	if index < 0 or index >= result_debts.size() or amount <= 0.0:
		return {"debts": result_debts, "repaid": 0.0}
	var entry: Dictionary = result_debts[index]
	var remaining := float(entry["remaining"])
	var pay := minf(remaining, amount)
	entry["remaining"] = remaining - pay
	if entry["remaining"] <= 0.0:
		result_debts.remove_at(index)
	return {"debts": result_debts, "repaid": pay}


static func total(debts: Array[Dictionary]) -> float:
	var sum := 0.0
	for entry in debts:
		sum += float(entry["remaining"])
	return sum


## 상환 진행률(0~1, 표시용). repay_total(=principal×상환배율)을 따로 저장하지 않으므로
## 현재 상환배율로 근사한다(빚이 진 시점 이후 배율이 안 바뀌는 한 정확하다 — 6단계 전엔 항상 그렇다).
static func progress_ratio(debts: Array[Dictionary], repay_mult: float) -> float:
	var owed := 0.0
	var remaining := 0.0
	for entry in debts:
		owed += float(entry["principal"]) * repay_mult
		remaining += float(entry["remaining"])
	if owed <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / owed, 0.0, 1.0)


static func _largest_remaining_index(debts: Array[Dictionary]) -> int:
	var best_index := 0
	var best_remaining := -1.0
	for i in debts.size():
		var remaining := float(debts[i]["remaining"])
		if remaining > best_remaining:
			best_remaining = remaining
			best_index = i
	return best_index


static func _duplicate(debts: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in debts:
		out.append((entry as Dictionary).duplicate())
	return out
