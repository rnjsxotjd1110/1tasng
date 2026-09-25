class_name MarbleSheet
extends Control
## 구슬 재질 15종 비교 시트(검수 도구 tools/capture 전용). 칸마다 48px(24×2) · 24px · 10px · 7px 와 이름·배율.

const COLS := 5
const CELL := Vector2(128, 111)
const ORIGIN := Vector2(0, 24)

var dark: bool = true


func _ready() -> void:
	size = Vector2(640, 360)
	var bg := ColorRect.new()
	bg.color = Palette.NIGHT if dark else Palette.FELT_D
	bg.size = size
	add_child(bg)
	var title := Label.new()
	title.theme_type_variation = "LabelTitle"
	title.text = "%s ×15" % tr("UPGRADE_MARBLE_TIER")
	title.position = Vector2(8, 4)
	title.size = Vector2(300, 16)
	add_child(title)
	for tier in GameData.marbles().size():
		var marble := GameData.marble(tier)
		var cell := ORIGIN + Vector2(tier % COLS, tier / COLS) * CELL
		var frame := ColorRect.new()
		frame.color = Palette.DUSK if dark else Palette.FELT
		frame.position = cell + Vector2(3, 2)
		frame.size = CELL - Vector2(6, 4)
		add_child(frame)
		var big := MarbleView.new(tier, MarbleSprite.SIZE_CARD, 2)
		big.position = cell + Vector2(6, 6)
		big.size = Vector2(60, 60)
		add_child(big)
		var mid := MarbleView.new(tier, MarbleSprite.SIZE_CARD, 1)
		mid.position = cell + Vector2(70, 8)
		mid.size = Vector2(36, 32)
		add_child(mid)
		var small := MarbleView.new(tier, MarbleSprite.SIZE_BOARD, 1)
		small.spin = 0.0
		small.position = cell + Vector2(72, 44)
		small.size = Vector2(16, 16)
		add_child(small)
		var tiny := MarbleView.new(tier, MarbleSprite.SIZE_WHEEL, 1)
		tiny.spin = 0.0
		tiny.position = cell + Vector2(94, 46)
		tiny.size = Vector2(12, 12)
		add_child(tiny)
		var name_label := Label.new()
		name_label.theme_type_variation = "LabelBold"
		name_label.text = tr(marble.name_key)
		name_label.position = cell + Vector2(6, 68)
		name_label.size = Vector2(CELL.x - 12, 14)
		add_child(name_label)
		var mult := Label.new()
		mult.theme_type_variation = "Num7Gold"
		mult.text = NumberFormat.format_mult(marble.mult)
		mult.position = cell + Vector2(8, 86)
		add_child(mult)
		var tier_label := Label.new()
		tier_label.theme_type_variation = "Num7Stone"
		tier_label.text = "%s/%s" % [NumberFormat.format(tier + 1), NumberFormat.format(GameData.marbles().size())]
		tier_label.position = cell + Vector2(CELL.x - 34, 86)
		add_child(tier_label)
