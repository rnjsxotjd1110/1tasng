class_name Bet
extends RefCounted
## 구슬 1개 = 베팅 1개.
## amount 는 스핀 시작 시 SpinController 가 칩 크기 설정으로 채운다(구슬당 베팅액은 모두 같다).

enum Type { RED, BLACK, ODD, EVEN, STRAIGHT }

const NO_NUMBER := -1

var type: Type = Type.RED
## STRAIGHT 일 때만 0~36, 나머지는 NO_NUMBER.
var number: int = NO_NUMBER
var amount: float = 0.0


func _init(p_type: Type = Type.RED, p_number: int = NO_NUMBER, p_amount: float = 0.0) -> void:
	type = p_type
	number = p_number if p_type == Type.STRAIGHT else NO_NUMBER
	amount = p_amount


static func red(p_amount: float = 0.0) -> Bet:
	return Bet.new(Type.RED, NO_NUMBER, p_amount)


static func black(p_amount: float = 0.0) -> Bet:
	return Bet.new(Type.BLACK, NO_NUMBER, p_amount)


static func odd(p_amount: float = 0.0) -> Bet:
	return Bet.new(Type.ODD, NO_NUMBER, p_amount)


static func even(p_amount: float = 0.0) -> Bet:
	return Bet.new(Type.EVEN, NO_NUMBER, p_amount)


static func straight(p_number: int, p_amount: float = 0.0) -> Bet:
	return Bet.new(Type.STRAIGHT, p_number, p_amount)


## 외부 베팅(RED/BLACK/ODD/EVEN). 0이 나오면 진다.
func is_outside() -> bool:
	return type != Type.STRAIGHT


func is_color() -> bool:
	return type == Type.RED or type == Type.BLACK


func is_parity() -> bool:
	return type == Type.ODD or type == Type.EVEN


func is_valid() -> bool:
	if type == Type.STRAIGHT:
		return number >= 0 and number < RouletteRules.POCKET_COUNT
	return number == NO_NUMBER


## 같은 칸(종류+숫자)인지. 금액은 비교하지 않는다.
func same_spot(other: Bet) -> bool:
	return other != null and type == other.type and number == other.number


func copy() -> Bet:
	return Bet.new(type, number, amount)


## 번역 키. STRAIGHT 는 tr(key) % number 로 쓴다.
func label_key() -> String:
	match type:
		Type.RED:
			return "BET_RED"
		Type.BLACK:
			return "BET_BLACK"
		Type.ODD:
			return "BET_ODD"
		Type.EVEN:
			return "BET_EVEN"
		_:
			return "BET_STRAIGHT"


func to_dict() -> Dictionary:
	return {"type": int(type), "number": number, "amount": amount}


static func from_dict(data: Dictionary) -> Bet:
	var bet_type: int = clampi(int(data.get("type", Type.RED)), Type.RED, Type.STRAIGHT)
	return Bet.new(bet_type as Type, int(data.get("number", NO_NUMBER)), float(data.get("amount", 0.0)))


func _to_string() -> String:
	var type_name: String = Type.keys()[type]
	if type == Type.STRAIGHT:
		return "%s %d (%s)" % [type_name, number, NumberFormat.format(amount)]
	return "%s (%s)" % [type_name, NumberFormat.format(amount)]
