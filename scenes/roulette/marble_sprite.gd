class_name MarbleSprite
extends RefCounted
## 구슬 스프라이트(assets/sprites/ui/marble.png, 나무 구슬 색으로 그린 7×7)를 구슬 재질 팔레트로 바꿔 칠한다.
## 템플릿 색 wood_d/wood/wood_l/wood_hl/ivory → MarbleDef 의 outline/shadow/base/light/shine.
## 휠의 공과 베팅창의 구슬이 같은 텍스처를 쓴다.

const TEMPLATE_PATH := "res://assets/sprites/ui/marble.png"
const SIZE := 7

static var _cache: Dictionary = {}
static var _shadow: Texture2D = null
static var _halo: Texture2D = null


static func texture_for(marble: MarbleDef) -> Texture2D:
	var key := marble.id if marble != null else "_default"
	if _cache.has(key):
		return _cache[key]
	var image: Image = (load(TEMPLATE_PATH) as Texture2D).get_image()
	image.convert(Image.FORMAT_RGBA8)
	if marble != null:
		var mapping := {
			Palette.WOOD_D.to_html(false): marble.color_outline,
			Palette.WOOD.to_html(false): marble.color_shadow,
			Palette.WOOD_L.to_html(false): marble.color_base,
			Palette.WOOD_HL.to_html(false): marble.color_light,
			Palette.IVORY.to_html(false): marble.color_shine,
		}
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x, y)
				if color.a <= 0.0:
					continue
				var html := color.to_html(false)
				if mapping.has(html):
					image.set_pixel(x, y, mapping[html])
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## 구슬 모양 그림자(void). 알파는 그릴 때 modulate 로.
static func shadow_texture() -> Texture2D:
	if _shadow != null:
		return _shadow
	var image: Image = (load(TEMPLATE_PATH) as Texture2D).get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				image.set_pixel(x, y, Palette.VOID)
	_shadow = ImageTexture.create_from_image(image)
	return _shadow


## 구슬 모양 gold_shine(테두리 빛용).
static func halo_texture() -> Texture2D:
	if _halo != null:
		return _halo
	var image: Image = (load(TEMPLATE_PATH) as Texture2D).get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				image.set_pixel(x, y, Palette.GOLD_SHINE)
	_halo = ImageTexture.create_from_image(image)
	return _halo


## 현재 구슬 재질 텍스처.
static func current() -> Texture2D:
	return texture_for(GameState.current_marble())
