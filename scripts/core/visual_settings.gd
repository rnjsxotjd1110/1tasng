class_name VisualSettings
extends RefCounted
## 연출 접근성 옵션(ART_BIBLE 7장). 4단계 설정 화면이 바꾸고 저장한다. 연출 코드는 여기만 본다.

## false 면 화면 흔들림 0px.
static var screen_shake: bool = true
## true 면 플래시 알파를 크게 줄이고 네온 깜빡임을 약하게 한다.
static var reduce_flashing: bool = false
## 번쩍임 줄이기일 때 플래시 알파 배율.
const REDUCED_FLASH_SCALE := 0.2


static func shake_amount(px: int) -> int:
	return px if screen_shake else 0


static func flash_alpha(alpha: float) -> float:
	return alpha * REDUCED_FLASH_SCALE if reduce_flashing else alpha
