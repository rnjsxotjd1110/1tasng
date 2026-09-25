class_name HistoryStats
extends RefCounted
## 결과 기록(GameState.result_history)으로 기록 패널 통계를 계산한다. 순수 계산.

const HOT_COLD_COUNT := 3
const RECENT_TOKENS := 12

var total: int = 0
var red: int = 0
var black: int = 0
var green: int = 0
var odd: int = 0
var even: int = 0
## 많이 나온 숫자(동률이면 최근에 나온 것 우선).
var hot: Array[int] = []
## 적게 나온 숫자(0회 포함, 동률이면 가장 오래 안 나온 것 우선).
var cold: Array[int] = []


static func from_history(history: Array[int]) -> HistoryStats:
	var stats := HistoryStats.new()
	stats._compute(history)
	return stats


## 최근 결과 count 개(최신이 앞).
static func recent(history: Array[int], count: int = RECENT_TOKENS) -> Array[int]:
	var out: Array[int] = []
	var index := history.size() - 1
	while index >= 0 and out.size() < count:
		out.append(history[index])
		index -= 1
	return out


func ratio(part: int) -> float:
	return float(part) / total if total > 0 else 0.0


func _compute(history: Array[int]) -> void:
	total = history.size()
	var counts: Array[int] = []
	var last_seen: Array[int] = []
	counts.resize(RouletteRules.POCKET_COUNT)
	last_seen.resize(RouletteRules.POCKET_COUNT)
	counts.fill(0)
	last_seen.fill(-1)
	for i in history.size():
		var n := history[i]
		if not RouletteRules.is_valid_number(n):
			continue
		counts[n] += 1
		last_seen[n] = i
		match RouletteRules.color_of(n):
			RouletteRules.PocketColor.RED:
				red += 1
			RouletteRules.PocketColor.BLACK:
				black += 1
			_:
				green += 1
		if RouletteRules.is_odd(n):
			odd += 1
		elif RouletteRules.is_even(n):
			even += 1
	if total == 0:
		return
	var numbers: Array[int] = []
	for n in RouletteRules.POCKET_COUNT:
		numbers.append(n)
	var by_hot := numbers.duplicate()
	by_hot.sort_custom(func(a: int, b: int) -> bool:
		if counts[a] != counts[b]:
			return counts[a] > counts[b]
		return last_seen[a] > last_seen[b])
	for i in HOT_COLD_COUNT:
		if counts[by_hot[i]] > 0:
			hot.append(by_hot[i])
	var by_cold := numbers.duplicate()
	by_cold.sort_custom(func(a: int, b: int) -> bool:
		if counts[a] != counts[b]:
			return counts[a] < counts[b]
		if last_seen[a] != last_seen[b]:
			return last_seen[a] < last_seen[b]
		return a < b)
	for i in HOT_COLD_COUNT:
		cold.append(by_cold[i])
