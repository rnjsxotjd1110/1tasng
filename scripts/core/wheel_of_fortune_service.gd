class_name WheelOfFortuneService
extends RefCounted
## 운명의 휠(Y14) 8칸 보너스(GDD 6장). roll() 은 misc 스트림으로 칸을 고르고, apply() 는 실제로 지급한다.
## 8칸: 100스핀분 칩 / 클로버+5 / 구슬 재질 임시 상승(5분) / 즉시 피버 / 황금 폭풍 / 빚 50% 탕감(빚 없으면 10분 수익) / 클로버+2 / 잭팟 체인.

enum Slice {
	CHIPS_100_SPINS, CLOVER_5, MARBLE_TIER_UP_TEMP, INSTANT_FEVER,
	GOLDEN_STORM, DEBT_RELIEF, CLOVER_2, JACKPOT_CHAIN,
}

const SLICES: Array[Slice] = [
	Slice.CHIPS_100_SPINS, Slice.CLOVER_5, Slice.MARBLE_TIER_UP_TEMP, Slice.INSTANT_FEVER,
	Slice.GOLDEN_STORM, Slice.DEBT_RELIEF, Slice.CLOVER_2, Slice.JACKPOT_CHAIN,
]
const NAME_KEYS: Dictionary = {
	Slice.CHIPS_100_SPINS: "WHEEL_SLICE_CHIPS",
	Slice.CLOVER_5: "WHEEL_SLICE_CLOVER_5",
	Slice.MARBLE_TIER_UP_TEMP: "WHEEL_SLICE_MARBLE_UP",
	Slice.INSTANT_FEVER: "WHEEL_SLICE_FEVER",
	Slice.GOLDEN_STORM: "WHEEL_SLICE_GOLDEN_STORM",
	Slice.DEBT_RELIEF: "WHEEL_SLICE_DEBT_RELIEF",
	Slice.CLOVER_2: "WHEEL_SLICE_CLOVER_2",
	Slice.JACKPOT_CHAIN: "WHEEL_SLICE_JACKPOT_CHAIN",
}
## 임시 재질 상승 지속시간(초).
const MARBLE_UP_DURATION := 300.0
## 빚이 없을 때 대신 지급하는 "10분 수익"에 쓰는 초.
const NO_DEBT_INCOME_SECONDS := 600.0
## 빚 탕감 비율.
const DEBT_RELIEF_RATIO := 0.5


static func roll() -> Slice:
	return SLICES[RngService.randi_range_misc(0, SLICES.size() - 1)]


static func name_key(slice: Slice) -> String:
	return String(NAME_KEYS.get(slice, ""))


## 칸의 효과를 실제로 지급한다. {"kind":Slice,"amount":float} 를 돌려준다(팝업 표시용, amount 는 칩·클로버 등).
static func apply(slice: Slice) -> Dictionary:
	match slice:
		Slice.CHIPS_100_SPINS:
			var amount := GameState.max_bet() * 100.0
			GameState.add_chips(amount, false)
			return {"kind": slice, "amount": amount}
		Slice.CLOVER_5:
			GameState.add_clovers(5)
			return {"kind": slice, "amount": 5.0}
		Slice.MARBLE_TIER_UP_TEMP:
			var current := GameState.current_marble()
			var next_tier := GameState.marble_tier + 1
			if current != null and next_tier < GameData.marbles().size():
				var next_marble := GameData.marble(next_tier)
				var ratio := next_marble.mult / current.mult if current.mult > 0.0 else next_marble.mult
				GameState.add_buff("wheel_marble_up", StatModifiers.MARBLE_MULT, StatModifiers.Op.MULT, ratio, MARBLE_UP_DURATION)
			return {"kind": slice, "amount": 0.0}
		Slice.INSTANT_FEVER:
			var duration := Economy.FEVER_DURATION + GameState.get_stat(StatModifiers.FEVER_DURATION_BONUS, 0.0)
			GameState.add_buff("fever", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT, Economy.FEVER_MULT, duration)
			return {"kind": slice, "amount": 0.0}
		Slice.GOLDEN_STORM:
			GameState.golden_storm_spins_left = maxi(GameState.golden_storm_spins_left, 1)
			EventBus.golden_storm_triggered.emit(1)
			return {"kind": slice, "amount": 0.0}
		Slice.DEBT_RELIEF:
			if GameState.has_debt():
				var forgiven := GameState.forgive_debt(DEBT_RELIEF_RATIO)
				return {"kind": slice, "amount": forgiven}
			var income := maxf(0.0, GameState.income_tracker.per_second(GameState.get_stat_value(GameState.STAT_PLAY_TIME)) * NO_DEBT_INCOME_SECONDS)
			GameState.add_chips(income, false)
			return {"kind": slice, "amount": income}
		Slice.CLOVER_2:
			GameState.add_clovers(2)
			return {"kind": slice, "amount": 2.0}
		Slice.JACKPOT_CHAIN:
			GameState.add_buff("jackpot_chain", StatModifiers.PAYOUT_MULT_ALL, StatModifiers.Op.MULT,
				Economy.JACKPOT_CHAIN_MULT, StatModifiers.PERMANENT, Economy.JACKPOT_CHAIN_SPINS)
			return {"kind": slice, "amount": 0.0}
	return {"kind": slice, "amount": 0.0}
