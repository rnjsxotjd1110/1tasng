class_name MarbleSprite
extends RefCounted
## 구슬 그리기 공용(ART_BIBLE 9장).
##   - 크기 3종 템플릿: 휠 7px(ui/marble.png) · 베팅칸·트레이 10px · 카드·연출 24px(marbles/marble_10/24.png).
##     템플릿은 나무 구슬 5색으로 그린 음영 인덱스 맵이고, assets/shaders/marble.gdshader 가 재질 5색 + 표면 디테일로 바꾼다.
##   - 구슬을 그리는 CanvasItem 에는 material 을 걸고(shared_material 또는 material_for), draw_texture 의 modulate 로
##     밝기(r)·굴림 위상(g)·회전 속도(b)·알파(a)를 넘긴다(instance_color).
##   - 그림자·테두리 빛은 셰이더 없는 CanvasItem 에서 shadow_texture / halo_texture 로 그린다.

const SIZE_WHEEL := 7
const SIZE_BOARD := 10
const SIZE_CARD := 24
## 휠 공 크기(기존 코드 호환).
const SIZE := SIZE_WHEEL

const TEMPLATES := {
	7: "res://assets/sprites/ui/marble.png",
	10: "res://assets/sprites/marbles/marble_10.png",
	24: "res://assets/sprites/marbles/marble_24.png",
}
const SHADER := preload("res://assets/shaders/marble.gdshader")

## 재질 id → 셰이더 style(표면 디테일 종류). ART_BIBLE 9장 표와 같아야 한다.
const STYLES := {
	"wood": 0, "stone": 1, "copper": 2, "iron": 3, "silver": 4, "gold": 5, "jade": 6, "ruby": 7,
	"sapphire": 8, "emerald": 9, "diamond": 10, "obsidian": 11, "starlight": 12, "void": 13, "cosmic": 14,
}
## 재질별 강조색 a0~a3(다이아 무지개, 흑요석 테두리 광, 코스믹 깊은 우주). 없으면 shine 색.
const ACCENTS := {
	"diamond": [Palette.RED_HL, Palette.GOLD_HL, Palette.CLOVER, Palette.NEON_PURPLE],
	"obsidian": [Palette.NEON_PURPLE, Palette.PURPLE_D, Palette.NEON_PURPLE, Palette.PURPLE_D],
	"cosmic": [Palette.PURPLE_D, Palette.NEON_PURPLE, Palette.NEON_PINK, Palette.NEON_CYAN],
}

static var _templates: Dictionary = {}
static var _shadows: Dictionary = {}
static var _halos: Dictionary = {}
static var _materials: Dictionary = {}
static var _shared: ShaderMaterial = null
static var _shared_tier: int = -1


static func template(size: int = SIZE_WHEEL) -> Texture2D:
	if not _templates.has(size):
		_templates[size] = load(String(TEMPLATES.get(size, TEMPLATES[SIZE_WHEEL])))
	return _templates[size]


## 지금 플레이어 구슬 재질을 보여 주는 공용 머티리얼. 재질이 바뀌면 sync_shared() 한 번으로 모든 구슬이 바뀐다.
static func shared_material() -> ShaderMaterial:
	if _shared == null:
		_shared = ShaderMaterial.new()
		_shared.shader = SHADER
		_shared_tier = -1
	if _shared_tier < 0:
		sync_shared()
	return _shared


## 공용 머티리얼을 tier(음수면 GameState 현재 재질)로 맞춘다.
static func sync_shared(tier: int = -1) -> void:
	if _shared == null:
		_shared = ShaderMaterial.new()
		_shared.shader = SHADER
	var target := tier if tier >= 0 else GameState.marble_tier
	apply(_shared, GameData.marble(target))
	_shared_tier = target


static func shared_tier() -> int:
	return _shared_tier


## 5단계 "흐려진 구슬" 패널티(전역 — 휠·트레이·베팅칸·카드 구슬이 공용 머티리얼을 쓰므로 한 번에 적용된다).
static func set_desaturate(amount: float) -> void:
	shared_material().set_shader_parameter("desaturate", clampf(amount, 0.0, 1.0))
	shared_material().set_shader_parameter("suppress_glint", amount > 0.0)


## 특정 재질 고정 머티리얼(비교 시트·승급 연출의 이전 구슬 등).
static func material_for(tier: int) -> ShaderMaterial:
	if not _materials.has(tier):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		apply(material, GameData.marble(tier))
		_materials[tier] = material
	return _materials[tier]


static func apply(material: ShaderMaterial, marble: MarbleDef) -> void:
	if marble == null:
		return
	var colors := marble.palette_colors()
	for i in colors.size():
		material.set_shader_parameter("c%d" % i, colors[i])
	var accents: Array = ACCENTS.get(marble.id, [])
	for i in 4:
		var color: Color = accents[i] if i < accents.size() else marble.color_shine
		material.set_shader_parameter("a%d" % i, color)
	material.set_shader_parameter("void_color", Palette.VOID)
	material.set_shader_parameter("style", int(STYLES.get(marble.id, 0)))


## draw_texture 의 modulate 로 넘길 인스턴스 값.
static func instance_color(alpha: float = 1.0, roll: float = 0.0, spin: float = 0.0, brightness: float = 1.0) -> Color:
	return Color(clampf(brightness, 0.0, 1.0), fposmod(roll, 1.0), clampf(spin, 0.0, 1.0), clampf(alpha, 0.0, 1.0))


## 구슬 모양 그림자(void). 알파는 그릴 때 modulate 로.
static func shadow_texture(size: int = SIZE_WHEEL) -> Texture2D:
	if not _shadows.has(size):
		_shadows[size] = _solid(size, Palette.VOID)
	return _shadows[size]


## 구슬 모양 단색(테두리 빛·실루엣용). 기본 gold_shine.
static func halo_texture(size: int = SIZE_WHEEL, color: Color = Palette.GOLD_SHINE) -> Texture2D:
	var key := "%d_%s" % [size, color.to_html(false)]
	if not _halos.has(key):
		_halos[key] = _solid(size, color)
	return _halos[key]


static func _solid(size: int, color: Color) -> Texture2D:
	var image: Image = template(size).get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
