class_name SpinOutcome
extends RefCounted
## RouletteRules.resolve() 의 결과. 연출 레이어는 이 객체만 보고 연출을 고른다.

## 연출 등급(ART_BIBLE.md "당첨 연출 등급").
enum Tier { LOSS, NORMAL, GOOD, BIG, JACKPOT }

## GOOD 은 배율(순이익 ÷ 총 베팅액)로 정한다.
const GOOD_RATIO := 5.0
## BIG·JACKPOT 은 배율이 아니라 "한 번호에 구슬을 몰아 걸어서 다 같이 맞혔는지"로 정한다(같은 개별숫자에
## 건 구슬 수의 최댓값 — RouletteRules.resolve() 가 계산). 예전엔 배율 임계값(20배/100배)이었는데, 층
## 배율이 커질수록 색·홀짝 베팅도 쉽게 그 배율을 넘어 버려 BIG/JACKPOT 이 너무 자주 나온다는 피드백으로
## 바꿨다(9단계). 이제 색·홀짝 베팅은 배율이 아무리 커도 GOOD 까지만 간다.
const BIG_SAME_NUMBER_BETS := 2
const JACKPOT_SAME_NUMBER_BETS := 3


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
	## 제로 가드(Y1)·미러(Y3)로 무승부 처리되어 돌려받은 원금(당첨은 아님 — win_count 에 안 들어간다).
	var refunded: float = 0.0

	func won() -> bool:
		return hit_count > 0

	func pushed() -> bool:
		return not won() and refunded > 0.0


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
## 운명 뒤집기(Y8)로 공이 튕겨 온 원래 포켓(없으면 -1).
var destiny_flip_from: int = -1


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


## same_number_bets: 이번에 이긴 개별숫자 중, 같은 번호에 건 구슬(베팅) 수의 최댓값(RouletteRules.resolve 계산).
static func classify(any_won: bool, net_value: float, total_bet_value: float, same_number_bets: int) -> Tier:
	if not any_won:
		return Tier.LOSS
	if same_number_bets >= JACKPOT_SAME_NUMBER_BETS:
		return Tier.JACKPOT
	if same_number_bets >= BIG_SAME_NUMBER_BETS:
		return Tier.BIG
	var value_ratio := net_value / total_bet_value if total_bet_value > 0.0 else 0.0
	if value_ratio >= GOOD_RATIO:
		return Tier.GOOD
	return Tier.NORMAL


func _to_string() -> String:
	return "SpinOutcome(results=%s bet=%s return=%s net=%s tier=%s)" % [
		results, NumberFormat.format(total_bet), NumberFormat.format(total_return),
		NumberFormat.format(net), Tier.keys()[tier]]
