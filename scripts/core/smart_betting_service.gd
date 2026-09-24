class_name SmartBettingService
extends RefCounted
## 스마트 베팅(M6) 전략별 베팅 구성. 순수 함수 — 실제 배치(GameState.clear_bets/add_bet)는 호출자(Main)가 한다.
## 결과를 바꾸지 않는 편의 기능이라 난수는 RngService misc 스트림만 쓴다.
## 전략은 GameState.SmartBettingStrategy 를 그대로 쓴다(KEEP=스마트 베팅 꺼짐).

const OUTSIDE_CYCLE: Array[Bet.Type] = [Bet.Type.RED, Bet.Type.BLACK, Bet.Type.ODD, Bet.Type.EVEN]


## strategy 에 맞춰 slots 개의 베팅(금액은 0 — 호출자가 스핀 시 칩 크기로 채운다)을 만든다.
## KEEP 이면 빈 배열(호출자는 이 경우 베팅을 바꾸지 않아야 한다).
static func compute_bets(strategy: int, slots: int, hot_numbers: Array[int], martingale_type: Bet.Type) -> Array[Bet]:
	var bets: Array[Bet] = []
	if slots <= 0:
		return bets
	match strategy:
		GameState.SmartBettingStrategy.STABLE:
			for i in slots:
				bets.append(_outside_bet(OUTSIDE_CYCLE[i % OUTSIDE_CYCLE.size()]))
		GameState.SmartBettingStrategy.AGGRESSIVE:
			for i in slots:
				bets.append(Bet.straight(RngService.randi_range_misc(0, RouletteRules.POCKET_COUNT - 1)))
		GameState.SmartBettingStrategy.HOT_NUMBERS:
			if hot_numbers.is_empty():
				for i in slots:
					bets.append(_outside_bet(OUTSIDE_CYCLE[i % OUTSIDE_CYCLE.size()]))
			else:
				for i in slots:
					bets.append(Bet.straight(hot_numbers[i % hot_numbers.size()]))
		GameState.SmartBettingStrategy.MARTINGALE:
			for i in slots:
				bets.append(_outside_bet(martingale_type))
		_:
			pass
	return bets


static func _outside_bet(type: Bet.Type) -> Bet:
	match type:
		Bet.Type.RED:
			return Bet.red()
		Bet.Type.BLACK:
			return Bet.black()
		Bet.Type.ODD:
			return Bet.odd()
		_:
			return Bet.even()


## 마틴게일: 졌으면 칩 크기를 한 단계 올리고(1/10→1/2→MAX), 이겼으면 1/10 으로 되돌린다.
static func next_chip_size(current_mode: int, last_spin_won: bool) -> int:
	if last_spin_won:
		return Economy.ChipSize.TENTH
	if current_mode == Economy.ChipSize.TENTH:
		return Economy.ChipSize.HALF
	return Economy.ChipSize.MAX
