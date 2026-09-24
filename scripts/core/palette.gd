class_name Palette
extends RefCounted
## ART_BIBLE.md 의 고정 36색 팔레트.
## 게임 화면에는 이 색만 쓴다(알파 변화만 허용). 새 색이 필요하면 ART_BIBLE.md 를 먼저 고친다.

# 배경
const VOID := Color("#0b0a14")
const NIGHT := Color("#16142a")
const DUSK := Color("#221e3d")
const SHADOW := Color("#2f2a52")
# 무채색
const INK := Color("#3e3a4f")
const STONE := Color("#6e6882")
const MIST := Color("#b8b2c4")
const IVORY := Color("#f4f0e8")
# 펠트
const FELT_D := Color("#0f3d2e")
const FELT := Color("#16573f")
const FELT_L := Color("#1f7552")
const FELT_HL := Color("#2c9468")
# 나무
const WOOD_D := Color("#3b2218")
const WOOD := Color("#5c3524")
const WOOD_L := Color("#83502f")
const WOOD_HL := Color("#a8703f")
# 금
const GOLD_D := Color("#6b4a12")
const GOLD := Color("#a8781c")
const GOLD_L := Color("#e0ac2c")
const GOLD_HL := Color("#ffd95a")
const GOLD_SHINE := Color("#fff2b0")
# 빨강
const RED_D := Color("#4a0f1a")
const RED := Color("#8a1a2b")
const RED_L := Color("#c9303c")
const RED_HL := Color("#f25a5a")
# 검정 포켓
const POCKET_K := Color("#121016")
const POCKET_K_L := Color("#26222e")
# 네온
const NEON_PINK := Color("#ff4fa3")
const NEON_CYAN := Color("#3fe0ff")
const NEON_PURPLE := Color("#7b3fe0")
const PURPLE_D := Color("#3d1f73")
# 클로버
const CLOVER := Color("#5ee06b")
const CLOVER_D := Color("#2a9e3a")
# 기타
const SKY := Color("#2b4a8f")
const WATER := Color("#1b3a5c")
const AMBER := Color("#ff9a3c")

# 의미 색
const SEM_CHIP := GOLD_HL
const SEM_CLOVER := CLOVER
const SEM_WARNING := RED_HL
const SEM_DISABLED := STONE
const SEM_FOCUS := NEON_CYAN

## 이름 → 색. ART_BIBLE.md 표와 순서·이름이 같다.
const ALL: Dictionary = {
	"void": VOID, "night": NIGHT, "dusk": DUSK, "shadow": SHADOW,
	"ink": INK, "stone": STONE, "mist": MIST, "ivory": IVORY,
	"felt_d": FELT_D, "felt": FELT, "felt_l": FELT_L, "felt_hl": FELT_HL,
	"wood_d": WOOD_D, "wood": WOOD, "wood_l": WOOD_L, "wood_hl": WOOD_HL,
	"gold_d": GOLD_D, "gold": GOLD, "gold_l": GOLD_L, "gold_hl": GOLD_HL, "gold_shine": GOLD_SHINE,
	"red_d": RED_D, "red": RED, "red_l": RED_L, "red_hl": RED_HL,
	"pocket_k": POCKET_K, "pocket_k_l": POCKET_K_L,
	"neon_pink": NEON_PINK, "neon_cyan": NEON_CYAN, "neon_purple": NEON_PURPLE, "purple_d": PURPLE_D,
	"clover": CLOVER, "clover_d": CLOVER_D,
	"sky": SKY, "water": WATER, "amber": AMBER,
}


## 알파를 무시하고 팔레트 색인지 검사한다.
static func is_palette_color(color: Color) -> bool:
	var opaque := Color(color.r, color.g, color.b, 1.0)
	for value: Color in ALL.values():
		if value.is_equal_approx(opaque):
			return true
	return false


## 팔레트 색에 알파만 바꾼 색.
static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
