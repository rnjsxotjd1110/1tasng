extends "res://tests/lib/test_case.gd"


func before_each() -> void:
	NumberFormat.scientific_mode = false


func after_each() -> void:
	NumberFormat.scientific_mode = false


func test_small_values_are_integers() -> void:
	check_eq(NumberFormat.format(0.0), "0", "0")
	check_eq(NumberFormat.format(7.0), "7", "7")
	check_eq(NumberFormat.format(12.4), "12", "내림")
	check_eq(NumberFormat.format(12.6), "13", "반올림")
	check_eq(NumberFormat.format(999.0), "999", "999")
	check_eq(NumberFormat.format(999.4), "999", "999.4")


func test_three_significant_digits() -> void:
	check_eq(NumberFormat.format(1000.0), "1.00K", "1000")
	check_eq(NumberFormat.format(1234.0), "1.23K", "1234")
	check_eq(NumberFormat.format(12345.0), "12.3K", "12345")
	check_eq(NumberFormat.format(123456.0), "123K", "123456")
	check_eq(NumberFormat.format(1.5e6), "1.50M", "1.5M")
	check_eq(NumberFormat.format(2.5e9), "2.50B", "B")
	check_eq(NumberFormat.format(1e12), "1.00T", "T")
	check_eq(NumberFormat.format(4.56e15), "4.56Qa", "Qa")


func test_rounding_boundaries() -> void:
	check_eq(NumberFormat.format(999.5), "1.00K", "999.5 → 1.00K")
	check_eq(NumberFormat.format(999950.0), "1.00M", "999,950 → 1.00M (1000K 금지)")
	check_eq(NumberFormat.format(999499.0), "999K", "999,499")
	check_eq(NumberFormat.format(999949.0), "1.00M", "999,949 도 유효숫자 3자리면 1.00M")
	check_eq(NumberFormat.format(9999.0), "10.0K", "9999 → 10.0K (9.99K→10.0K 자리 변화)")
	check_eq(NumberFormat.format(99950.0), "100K", "99950 → 100K")
	check_eq(NumberFormat.format(9.9999e8), "1.00B", "M→B 경계")


func test_all_suffixes() -> void:
	for i in range(1, NumberFormat.SUFFIXES.size()):
		var value := pow(10.0, i * 3)
		check_eq(NumberFormat.format(value), "1.00" + NumberFormat.SUFFIXES[i], "1e%d" % (i * 3))
	check_eq(NumberFormat.format(1e33), "1.00Dc", "1e33 → 1.00Dc")
	check_eq(NumberFormat.format(1e63), "1.00Vg", "Vg")
	check_eq(NumberFormat.format(1.23e66), "1.23e66", "Vg 다음은 과학적 표기")
	check_eq(NumberFormat.format(9.9996e65), "1.00e66", "Vg 에서 넘어가면 과학적 표기")


func test_suffix_index() -> void:
	check_eq(NumberFormat.suffix_index(999.0), 0, "999")
	check_eq(NumberFormat.suffix_index(1000.0), 1, "K")
	check_eq(NumberFormat.suffix_index(1e6), 2, "M")
	check_eq(NumberFormat.suffix_index(999999.0), 1, "999,999 는 아직 K")
	check_eq(NumberFormat.suffix_index(1e33), 11, "Dc")


func test_negative() -> void:
	check_eq(NumberFormat.format(-1234.0), "-1.23K", "음수")
	check_eq(NumberFormat.format(-5.0), "-5", "작은 음수")
	check_eq(NumberFormat.format(-0.2), "0", "-0 표시 안 함")
	check_eq(NumberFormat.format_signed(1234.0), "+1.23K", "부호 +")
	check_eq(NumberFormat.format_signed(-50.0), "-50", "부호 -")
	check_eq(NumberFormat.format_signed(0.0), "0", "부호 0")


func test_invalid_values() -> void:
	print("    (다음 에러 로그 3줄은 NaN/INF 방어 테스트의 정상 출력)")
	check_eq(NumberFormat.format(NAN), "∞", "NaN")
	check_eq(NumberFormat.format(INF), "∞", "INF")
	check_eq(NumberFormat.format(-INF), "∞", "-INF")


func test_scientific_mode() -> void:
	NumberFormat.scientific_mode = true
	check_eq(NumberFormat.format(999.0), "999", "1000 미만은 정수")
	check_eq(NumberFormat.format(1234.0), "1.23e3", "1234")
	check_eq(NumberFormat.format(1.23e45), "1.23e45", "1.23e45")
	check_eq(NumberFormat.format(9.996e45), "1.00e46", "자리올림")
	check_eq(NumberFormat.format(-1.5e7), "-1.50e7", "음수")
	check_eq(NumberFormat.format_scientific(1e100), "1.00e100", "큰 지수")


func test_format_full() -> void:
	check_eq(NumberFormat.format_full(0.0), "0", "0")
	check_eq(NumberFormat.format_full(999.0), "999", "999")
	check_eq(NumberFormat.format_full(1234567.0), "1,234,567", "쉼표")
	check_eq(NumberFormat.format_full(-1000.0), "-1,000", "음수")
	check_eq(NumberFormat.format_full(999999999999999.0), "999,999,999,999,999", "1e15 미만")
	check_eq(NumberFormat.format_full(1e15), "1.00e15", "1e15 이상은 과학적 표기")
