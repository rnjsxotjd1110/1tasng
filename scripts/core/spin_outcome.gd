class_name SpinOutcome
extends RefCounted
## RouletteRules.resolve() 의 결과. 연출 레이어는 이 객체만 보고 연출을 고른다.

## 연출 등급(ART_BIBLE.md "당첨 연출 등급").
enum Tier { LOSS, NORMAL, GOOD, BIG, JACKPOT }

## 등급 기준. 배율 = 순이익 ÷ 총 베팅액.
const GOOD_RATIO := 5.0
const BIG_RATIO := 20.0
const JACKPOT_RATIO := 100.0
## 개별숫자 적중이 이 개수 이상이면 BIG, JACKPOT.
const BIG_STRAIGHT_HITS := 1
const JACKPOT_STRAIGHT_HITS := 2


## 베팅 1개의 정산 결과. 공이 여러 개면 공마다 판정한 값을 합친다.
class BetResult:
	extends RefCounted
	var bet: Bet
	## 이 베팅을 맞힌 공의 수.
	var hit_count: int = 0
	## 원금 포함 반환액(모든 공 합계).
	var payout: float = 0.0
	## 개별숫자 베팅이 빗나갔지만 결과의 바로 옆 포켓이었다.
	var near_miss: bool = false

	func won() -> bool:
		return hit_count > 0


## 공마다 하나씩. 더블 볼이면 2개.
var results: Array[int] = []
var bet_results: Array[BetResult] = []
var total_bet: float = 0.0
var total_return: float = 0.0
var net: float = 0.0
## 적중한 개별숫자(베팅 1개 × 공 1개당 1개 항목). 클로버 보상 개수와 같다.
var hit_straights: Array[int] = []
var near_miss: bool = false
var golden_hit: bool = false
var tier: Tier = Tier.LOSS


func any_win() -> bool:
	for bet_result: BetResult in bet_results:
		if bet_result.won():
			return true
	return false


func win_count() -> int:
	var count := 0
	for bet_result: BetResult in bet_results:
		if bet_result.won():
			count += 1
	return count


## 순이익 ÷ 총 베팅액. 베팅이 없으면 0.
func ratio() -> float:
	if total_bet <= 0.0:
		return 0.0
	return net / total_bet


static func classify(any_won: bool, net_value: float, total_bet_value: float, straight_hits: int) -> Tier:
	if not any_won:
		return Tier.LOSS
	var value_ratio := net_value / total_bet_value if total_bet_value > 0.0 else 0.0
	if value_ratio >= JACKPOT_RATIO or straight_hits >= JACKPOT_STRAIGHT_HITS:
		return Tier.JACKPOT
	if value_ratio >= BIG_RATIO or straight_hits >= BIG_STRAIGHT_HITS:
		return Tier.BIG
	if value_ratio >= GOOD_RATIO:
		return Tier.GOOD
	return Tier.NORMAL


func _to_string() -> String:
	return "SpinOutcome(results=%s bet=%s return=%s net=%s tier=%s)" % [
		results, NumberFormat.format(total_bet), NumberFormat.format(total_return),
		NumberFormat.format(net), Tier.keys()[tier]]
