class_name VisualSettings
extends RefCounted
## 연출 접근성 옵션(ART_BIBLE 7장). 4단계 설정 화면이 바꾸고 저장한다. 연출 코드는 여기만 본다.

## false 면 화면 흔들림 0px.
static var screen_shake: bool = true
## true 면 플래시 알파를 크게 줄이고 네온 깜빡임을 약하게 한다.
static var reduce_flashing: bool = false
## 번쩍임 줄이기일 때 플래시 알파 배율.
const REDUCED_FLASH_SCALE := 0.2
## 빨강 포켓·베팅칸에 점 무늬를 덧그린다(색약 보조).
static var colorblind_assist: bool = false
## false 면 BIG/JACKPOT 의 배너·플래시·화면 흔들림을 생략하고 떠오르는 텍스트·소리만 남긴다.
static var big_win_effect_full: bool = true
## 오토 스핀 중에는 BIG 미만 등급의 파티클·흔들림을 생략한다.
static var auto_spin_effects_reduced: bool = true
## 툴팁이 뜨기까지 걸리는 시간(초). TooltipLayer 가 읽는다.
static var tooltip_delay: float = 0.3


static func shake_amount(px: int) -> int:
	return px if screen_shake else 0


static func flash_alpha(alpha: float) -> float:
	return alpha * REDUCED_FLASH_SCALE if reduce_flashing else alpha


## tier(SpinOutcome.Tier) 등급의 무거운 연출(배너·화면 전체 플래시·강한 흔들림)을 온전히 보여줄지.
static func full_effects(tier: int, is_auto_spin: bool) -> bool:
	if is_auto_spin and auto_spin_effects_reduced and tier < SpinOutcome.Tier.BIG:
		return false
	if tier >= SpinOutcome.Tier.BIG and not big_win_effect_full:
		return false
	return true
