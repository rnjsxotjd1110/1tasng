extends "res://tests/lib/test_case.gd"
## LetterboxFit(8단계 마무리, GDD 22장): 창 크기 → 정수 배율·중앙 정렬 오프셋 계산.
## 실제 창 크기 반응(size_changed)·배경 그리기는 헤드리스에서 의미 있게 검증할 수 없어(창이 없음)
## 순수 계산 함수(compute)만 검사한다 — 실제 스케일·레터박스는 이번 세션에서 xwd 로 직접 캡처해 확인했다
## (GDD 22장에 기록).

func test_exact_multiple_has_no_margin() -> void:
	var fit := LetterboxFit.compute(Vector2(1920, 1080))
	check_eq(fit["scale"], 3.0, "1920x1080 은 640x360 의 정확히 3배")
	check_eq(fit["offset"], Vector2.ZERO, "정확히 맞아떨어지면 여백 없음")


func test_pillarbox_when_wider_than_content() -> void:
	# 3440x1440: x 배율 5.375, y 배율 4.0 → 더 작은 4배를 쓰고 좌우에 여백(필러박스)이 생긴다.
	var fit := LetterboxFit.compute(Vector2(3440, 1440))
	check_eq(fit["scale"], 4.0, "더 작은 축(세로) 기준으로 정수 배율")
	var offset: Vector2 = fit["offset"]
	check(offset.x > 0.0, "좌우 여백(필러박스) 발생")
	check_eq(offset.y, 0.0, "세로는 꽉 채움")


func test_letterbox_when_taller_than_content() -> void:
	# 1280x1200: x 배율 정확히 2.0, y 배율 3.33 → 가로 기준 2배를 쓰고 위아래에 여백(레터박스)이 생긴다.
	var fit := LetterboxFit.compute(Vector2(1280, 1200))
	check_eq(fit["scale"], 2.0, "더 작은 축(가로) 기준으로 정수 배율")
	var offset: Vector2 = fit["offset"]
	check_eq(offset.x, 0.0, "가로는 꽉 채움(정확히 2배로 맞아떨어짐)")
	check(offset.y > 0.0, "위아래 여백(레터박스) 발생")


func test_never_scales_below_one() -> void:
	var fit := LetterboxFit.compute(Vector2(320, 180))
	check_eq(fit["scale"], 1.0, "창이 640x360 보다 작아도 최소 1배는 유지")


func test_content_stays_centered() -> void:
	var fit := LetterboxFit.compute(Vector2(2000, 1100))
	var factor: float = fit["scale"]
	var offset: Vector2 = fit["offset"]
	var content_size := LetterboxFit.BASE_SIZE * factor
	var right_margin := 2000.0 - (offset.x + content_size.x)
	var bottom_margin := 1100.0 - (offset.y + content_size.y)
	check(absf(offset.x - right_margin) <= 1.0, "좌우 여백이 거의 같음(중앙 정렬)")
	check(absf(offset.y - bottom_margin) <= 1.0, "위아래 여백이 거의 같음(중앙 정렬)")


func test_apply_is_safe_headless() -> void:
	var root := Control.new()
	tree.root.add_child(root)
	var content := Control.new()
	root.add_child(content)
	LetterboxFit.apply(content)
	check(content.get_child_count() >= 1, "업데이터 노드가 content 아래에 붙는다")
	root.free()
