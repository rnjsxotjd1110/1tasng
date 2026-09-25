class_name FloorTheme
extends RefCounted
## 층별 강조색(GDD 7장, ART_BIBLE 12장). 순수 표시용 — 게임 로직에는 영향 없다.
## UI 패널 프레임(오른쪽 패널 테두리·엘리베이터 확인 팝업)과 엘리베이터 컷신 타이틀 카드에 쓴다.

const ACCENTS: Dictionary = {
	"b1": [Palette.GOLD, Palette.WOOD_HL],
	"1f": [Palette.RED_HL, Palette.GOLD_HL],
	"2f": [Palette.AMBER, Palette.WOOD_HL],
	"3f": [Palette.NEON_CYAN, Palette.NEON_PURPLE],
	"ph": [Palette.GOLD_HL, Palette.NEON_PURPLE],
}


static func primary(floor_id: String) -> Color:
	var pair: Array = ACCENTS.get(floor_id, ACCENTS["b1"])
	return pair[0]


static func secondary(floor_id: String) -> Color:
	var pair: Array = ACCENTS.get(floor_id, ACCENTS["b1"])
	return pair[1]
