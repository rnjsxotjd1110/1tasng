class_name NumberFormat
extends RefCounted
## 모든 숫자 표시는 이 클래스를 거친다.
## - 1000 미만: 반올림한 정수("999")
## - 1000 이상: 유효숫자 3자리 + 단위("1.23K", "12.3K", "123K"). 반올림으로 단위가 넘어가면 다음 단위("1.00M")
## - 마지막 단위(Vg) 다음부터, 또는 scientific_mode 에서는 과학적 표기("1.23e66")
## - NaN/INF 는 "∞" + 에러 로그

const SUFFIXES: Array[String] = [
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
]
const INFINITY_TEXT := "∞"
const NEGATIVE_SIGN := "-"
const POSITIVE_SIGN := "+"
const SIG_DIGITS := 3
const GROUP_SIZE := 3
## format_full 이 쉼표 전체 표기를 쓰는 상한. 이상이면 과학적 표기.
const FULL_FORMAT_LIMIT := 1e15

const MULT_SIGN := "×"
const SECONDS_SUFFIX := "s"
const PERCENT_SIGN := "%"
## 1 미만 소수 표기의 자릿수(format_decimal).
const SMALL_DECIMALS := 2

## 설정의 "과학적 표기" 옵션. SaveManager/설정 화면이 바꾼다.
static var scientific_mode: bool = false


## 짧은 표기. 음수는 "-1.23K".
static func format(value: float) -> String:
	if is_nan(value) or is_inf(value):
		push_error("NumberFormat.format: 비정상 값 %s" % value)
		return INFINITY_TEXT
	if value < 0.0:
		var inner := format(-value)
		return inner if inner == "0" else NEGATIVE_SIGN + inner
	var rounded := roundf(value)
	if rounded < 1000.0:
		return str(int(rounded))
	var group := _group_of(value)
	if scientific_mode or group >= SUFFIXES.size():
		return format_scientific(value)
	var mantissa := value / pow(10.0, group * GROUP_SIZE)
	var parts := _round_mantissa(mantissa, 1000.0)
	if parts[1] > 0:
		group += 1
		if group >= SUFFIXES.size():
			return format_scientific(value)
	return parts[0] + SUFFIXES[group]


## 부호를 항상 붙인 표기("+1.23K", "-50", "0").
static func format_signed(value: float) -> String:
	var text := format(value)
	if value > 0.0 and text != "0" and text != INFINITY_TEXT:
		return POSITIVE_SIGN + text
	return text


## 배율 표기("×1.25", "×12.3", "×900", "×8.00K"). 1000 미만도 유효숫자 3자리(끝의 0 은 뺀다).
static func format_mult(value: float) -> String:
	return MULT_SIGN + format_decimal(value)


## 1000 미만을 정수로 반올림하지 않는 표기("1.25", "1.5", "12.3", "0.25"). 1000 이상은 format 과 같다.
static func format_decimal(value: float) -> String:
	if is_nan(value) or is_inf(value):
		push_error("NumberFormat.format_decimal: 비정상 값 %s" % value)
		return INFINITY_TEXT
	if value < 0.0:
		var inner := format_decimal(-value)
		return inner if inner == "0" else NEGATIVE_SIGN + inner
	if value >= 999.5:
		return format(value)
	var text: String
	if value < 1.0:
		text = ("%." + str(SMALL_DECIMALS) + "f") % value
	else:
		text = String(_round_mantissa(value, 1000.0)[0])
	if text.contains("."):
		text = text.rstrip("0").trim_suffix(".")
	return text


## 비율 → 백분율("48%"). 정수로 반올림.
static func format_percent(ratio: float) -> String:
	return format(ratio * 100.0) + PERCENT_SIGN


## 초 표기("5.4s"). 소수 1자리.
static func format_seconds(value: float) -> String:
	if is_nan(value) or is_inf(value):
		push_error("NumberFormat.format_seconds: 비정상 값 %s" % value)
		return INFINITY_TEXT
	if absf(value) >= 1000.0:
		return format(value) + SECONDS_SUFFIX
	return "%.1f" % value + SECONDS_SUFFIX


## 과학적 표기("1.23e45"). 1000 미만은 정수.
static func format_scientific(value: float) -> String:
	if is_nan(value) or is_inf(value):
		push_error("NumberFormat.format_scientific: 비정상 값 %s" % value)
		return INFINITY_TEXT
	if value < 0.0:
		return NEGATIVE_SIGN + format_scientific(-value)
	if roundf(value) < 1000.0:
		return str(int(roundf(value)))
	var exponent := floori(log(value) / log(10.0))
	if value >= pow(10.0, exponent + 1):
		exponent += 1
	elif value < pow(10.0, exponent):
		exponent -= 1
	var parts := _round_mantissa(value / pow(10.0, exponent), 10.0)
	exponent += parts[1]
	return "%se%d" % [parts[0], exponent]


## 툴팁용 전체 표기("1,234,567"). 1e15 이상은 과학적 표기.
static func format_full(value: float) -> String:
	if is_nan(value) or is_inf(value):
		push_error("NumberFormat.format_full: 비정상 값 %s" % value)
		return INFINITY_TEXT
	if absf(value) >= FULL_FORMAT_LIMIT:
		return format_scientific(value)
	var number := int(roundf(absf(value)))
	var digits := str(number)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % GROUP_SIZE == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	if value < 0.0 and number != 0:
		out = NEGATIVE_SIGN + out
	return out


## 보유 칩의 단위 인덱스(0="", 1=K, 2=M …). 1000 미만은 0.
## 마일스톤(단위 첫 도달) 판정에 쓴다.
static func suffix_index(value: float) -> int:
	if is_nan(value) or is_inf(value) or value < 1000.0:
		return 0
	return _group_of(value)


## value >= 1000 일 때 1000^group <= value < 1000^(group+1) 인 group.
static func _group_of(value: float) -> int:
	var group := floori(log(value) / log(1000.0))
	if value >= pow(10.0, (group + 1) * GROUP_SIZE):
		group += 1
	elif value < pow(10.0, group * GROUP_SIZE):
		group -= 1
	return maxi(group, 0)


## 가수를 유효숫자 3자리로 반올림한 문자열과 자리올림 여부를 돌려준다.
## overflow 에 도달하면(예: 999.95 → 1000) overflow 로 나눠 다음 단위로 올린다.
## 반환: [문자열, 올림 횟수(0 또는 1)]
static func _round_mantissa(mantissa: float, overflow: float) -> Array:
	var int_digits := 1
	if mantissa >= 100.0:
		int_digits = 3
	elif mantissa >= 10.0:
		int_digits = 2
	var decimals := SIG_DIGITS - int_digits
	var scale := pow(10.0, decimals)
	var rounded := roundf(mantissa * scale) / scale
	var carried := 0
	if rounded >= overflow:
		rounded /= overflow
		carried = 1
		decimals = SIG_DIGITS - 1
	elif rounded >= pow(10.0, int_digits):
		decimals -= 1
	match decimals:
		2:
			return ["%.2f" % rounded, carried]
		1:
			return ["%.1f" % rounded, carried]
		_:
			return ["%d" % int(rounded), carried]
