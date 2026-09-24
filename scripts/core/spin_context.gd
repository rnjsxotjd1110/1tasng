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


func is_golden(result: int) -> bool:
	return golden_pockets.has(result)
