class_name MarbleDef
extends Resource
## 구슬 재질 1단계. 배율은 당첨에만 곱해진다.
## 팔레트 5색은 반드시 Palette(ART_BIBLE.md 36색) 안의 색이어야 한다.

@export var tier: int = 0
@export var id: String = ""
@export var name_key: String = ""
## 재질 배율(나무 ×1, 돌 ×1.5 …).
@export var mult: float = 1.0
## 이 재질로 교체하는 비용. 나무(0단계)는 0.
@export var cost: float = 0.0
## 광택 0→1 단계 비용. n→n+1 단계 = polish_base_cost × Economy.POLISH_COST_GROWTH^n
@export var polish_base_cost: float = 0.0
@export var color_outline: Color = Palette.INK
@export var color_shadow: Color = Palette.STONE
@export var color_base: Color = Palette.MIST
@export var color_light: Color = Palette.IVORY
@export var color_shine: Color = Palette.IVORY
## 특수 연출 id(2·3단계 연출 레이어가 해석). 없으면 빈 문자열.
@export var fx_id: String = ""


func palette_colors() -> Array[Color]:
	return [color_outline, color_shadow, color_base, color_light, color_shine]
