class_name SpinContext
extends RefCounted
## 정산에 필요한 배율 묶음. GameState.build_spin_context() 가 StatModifiers 를 거쳐 채운다.
## 기본값은 전부 항등(배율 1, 보너스 0, 황금 포켓 없음)이라 테스트에서 new() 만 해도 된다.
##
## 당첨 반환액 = 베팅액 × (배당+1) × marble_mult × floor_mult × payout_mult_all
##              × (색 → payout_mult_color | 홀짝 → payout_mult_parity | 개별숫자 → 1+straight_payout_bonus)
##              × (결과가 황금 포켓이면 golden_pocket_mult)

## 구슬 재질 배율 × 광택 배율 × 구슬 관련 수정자.
var marble_mult: float = 1.0
var floor_mult: float = 1.0
var payout_mult_all: float = 1.0
var payout_mult_color: float = 1.0
var payout_mult_parity: float = 1.0
## 개별숫자 당첨에 곱해지는 추가 비율(0.5 → ×1.5).
var straight_payout_bonus: float = 0.0
var golden_pockets: Array[int] = []
var golden_pocket_mult: float = 1.0

# ── 6단계: 스킬트리 조건부 효과(전부 결정론적 — RNG 는 SpinController 가 맡는다) ──
## 제로 가드(Y1): 0이 나오면 색·홀짝 베팅을 무승부(원금 반환)로 만든다.
var zero_guard: bool = false
## 핫 넘버(F6): 최근 20스핀 최다 숫자 3개. 이 숫자에 스트레이트가 적중하면 hot_number_straight_mult 가 곱해진다.
var hot_numbers: Array[int] = []
var hot_number_straight_mult: float = 1.0
## 럭키 세븐(F9): 결과가 RouletteRules.LUCKY_SEVEN_NUMBERS 중 하나면 그 결과에 대한 모든 당첨에 곱해진다.
var lucky_seven_mult: float = 1.0
## 제로의 축복(Y7): 0 스트레이트 적중 시 곱해진다.
var zero_straight_mult: float = 1.0
## 이중 적중(F8): 한 스핀에 2개 이상 당첨되면 총 당첨(원금 포함)에 (1+값) 이 곱해진다.
var multi_hit_bonus: float = 0.0
## 캐시백(E2): 완전히 진 베팅(제로 가드로 이미 반환받지 않은)의 원금 중 이 비율을 돌려준다.
var cashback_rate: float = 0.0


func is_golden(result: int) -> bool:
	return golden_pockets.has(result)


func is_lucky_seven(result: int) -> bool:
	return RouletteRules.LUCKY_SEVEN_NUMBERS.has(result)
