class_name RouletteRules
extends RefCounted
## 유럽식 싱글 제로 룰렛 규칙. 전부 static, 상태 없음, 연출과 무관.

enum PocketColor { GREEN, RED, BLACK }

const POCKET_COUNT := 37
const ZERO := 0
## 휠 배열 순서. 인덱스 0 이 0번 포켓이고, 인덱스가 커지는 방향이 각도가 커지는 방향이다.
const WHEEL_ORDER: Array[int] = [
	0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
	5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
]
const RED_NUMBERS: Array[int] = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
## 럭키 세븐(F9)이 반응하는 결과 숫자.
const LUCKY_SEVEN_NUMBERS: Array[int] = [7, 17, 27]
const DEGREES_PER_POCKET := 360.0 / POCKET_COUNT

## 배당(원금 제외). 반환액 = 베팅액 × (배당+1).
const PAYOUT_EVEN_MONEY := 1
const PAYOUT_STRAIGHT := 35


static func is_valid_number(number: int) -> bool:
	return number >= 0 and number < POCKET_COUNT


static func is_red(number: int) -> bool:
	return RED_NUMBERS.has(number)


static func is_black(number: int) -> bool:
	return number != ZERO and is_valid_number(number) and not is_red(number)


static func color_of(number: int) -> PocketColor:
	if is_red(number):
		return PocketColor.RED
	if is_black(number):
		return PocketColor.BLACK
	return PocketColor.GREEN


## 0 은 홀도 짝도 아니다.
static func is_odd(number: int) -> bool:
	return number != ZERO and is_valid_number(number) and number % 2 == 1


static func is_even(number: int) -> bool:
	return number != ZERO and is_valid_number(number) and number % 2 == 0


static func wheel_index(number: int) -> int:
	return WHEEL_ORDER.find(number)


## 휠 기준 포켓 중심 각도(도). 0번 포켓이 0도, WHEEL_ORDER 순서대로 360/37 도씩 증가한다.
## Godot 2D 는 y 가 아래라서 양의 각도는 화면상 시계 방향이다.
static func pocket_angle(number: int) -> float:
	var index := wheel_index(number)
	if index < 0:
		push_error("RouletteRules.pocket_angle: 잘못된 숫자 %d" % number)
		return 0.0
	return index * DEGREES_PER_POCKET


## 각도(도, 휠 기준)에 해당하는 포켓 숫자. pocket_angle 의 역함수.
static func number_at_angle(degrees: float) -> int:
	var index := roundi(fposmod(degrees, 360.0) / DEGREES_PER_POCKET) % POCKET_COUNT
	return WHEEL_ORDER[index]


## 휠에서 양옆으로 distance 칸 이내의 숫자들(자기 자신 제외).
static func neighbors(number: int, distance: int = 1) -> Array[int]:
	var out: Array[int] = []
	var index := wheel_index(number)
	if index < 0:
		return out
	for offset in range(1, distance + 1):
		out.append(WHEEL_ORDER[posmod(index - offset, POCKET_COUNT)])
		out.append(WHEEL_ORDER[posmod(index + offset, POCKET_COUNT)])
	return out


static func are_neighbors(a: int, b: int) -> bool:
	return neighbors(a).has(b)


static func payout_ratio(bet_type: Bet.Type) -> int:
	return PAYOUT_STRAIGHT if bet_type == Bet.Type.STRAIGHT else PAYOUT_EVEN_MONEY


static func bet_wins(bet: Bet, result: int) -> bool:
	match bet.type:
		Bet.Type.RED:
			return is_red(result)
		Bet.Type.BLACK:
			return is_black(result)
		Bet.Type.ODD:
			return is_odd(result)
		Bet.Type.EVEN:
			return is_even(result)
		Bet.Type.STRAIGHT:
			return bet.number == result
	return false


## 당첨에만 붙는 배율(베팅 종류와 결과에 따라 다름).
static func win_multiplier(bet: Bet, result: int, context: SpinContext) -> float:
	var mult := context.marble_mult * context.floor_mult * context.payout_mult_all
	if bet.is_color():
		mult *= context.payout_mult_color
	elif bet.is_parity():
		mult *= context.payout_mult_parity
	else:
		mult *= 1.0 + context.straight_payout_bonus
		if context.hot_numbers.has(result):
			mult *= context.hot_number_straight_mult
		if result == ZERO:
			mult *= context.zero_straight_mult
	if context.is_golden(result):
		mult *= context.golden_pocket_mult
	if context.is_lucky_seven(result):
		mult *= context.lucky_seven_mult
	return mult


## 공 1개 결과에 대한 베팅 1개의 반환액(원금 포함). 지면 0.
static func bet_return(bet: Bet, result: int, context: SpinContext) -> float:
	if not bet_wins(bet, result):
		return 0.0
	return bet.amount * (payout_ratio(bet.type) + 1) * win_multiplier(bet, result, context)


## 베팅 목록과 결과 배열(공 개수만큼)을 정산한다.
## 비용(total_bet)은 공 개수와 무관하게 한 번만 센다.
static func resolve(bets: Array[Bet], results: Array[int], context: SpinContext = null) -> SpinOutcome:
	if context == null:
		context = SpinContext.new()
	var outcome := SpinOutcome.new()
	outcome.results = results.duplicate()
	for result in results:
		if context.is_golden(result):
			outcome.golden_hit = true
	for bet in bets:
		var bet_result := SpinOutcome.BetResult.new()
		bet_result.bet = bet
		outcome.total_bet += bet.amount
		for result in results:
			var value := bet_return(bet, result, context)
			if value > 0.0:
				bet_result.hit_count += 1
				bet_result.payout += value
				if bet.type == Bet.Type.STRAIGHT:
					outcome.hit_straights.append(bet.number)
			elif context.zero_guard and bet.is_outside() and result == ZERO:
				# 제로 가드(Y1): 0이 나오면 색·홀짝 베팅은 잃지 않고 원금만 돌려받는다(당첨은 아님).
				bet_result.refunded += bet.amount
		if not bet_result.won() and bet_result.refunded <= 0.0 and context.cashback_rate > 0.0:
			# 캐시백(E2): 완전히 진 베팅만 대상(제로 가드로 이미 반환받은 베팅은 제외).
			bet_result.refunded += bet.amount * context.cashback_rate
		if bet.type == Bet.Type.STRAIGHT and not bet_result.won():
			for result in results:
				if are_neighbors(bet.number, result):
					bet_result.near_miss = true
					outcome.near_miss = true
		outcome.bet_results.append(bet_result)
	# 이중 적중(F8): 한 스핀에 2개 이상 당첨되면 각 당첨(원금 포함, 반환은 제외)에 보너스가 곱해진다.
	if context.multi_hit_bonus > 0.0 and outcome.win_count() >= 2:
		var bonus_mult := 1.0 + context.multi_hit_bonus
		for bet_result in outcome.bet_results:
			bet_result.payout *= bonus_mult
	for bet_result in outcome.bet_results:
		outcome.total_return += bet_result.payout + bet_result.refunded
	outcome.net = outcome.total_return - outcome.total_bet
	outcome.tier = SpinOutcome.classify(outcome.any_win(), outcome.net, outcome.total_bet, outcome.hit_straights.size())
	return outcome
