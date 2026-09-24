class_name MarbleFx
extends RefCounted
## 구슬 재질별 부가 효과(ART_BIBLE 9장). 휠·트레이·미리보기가 같은 규칙으로 그린다.
## 셰이더 밖(구슬 둘레)에 그리는 것만 여기 있다: 반짝임 별, 보석 반짝이, 다이아 무지개 스파클, 흑요석 보라빛 테두리 광,
## 별빛 궤도 별, 공허 빨려드는 입자, 코스믹 별가루. 모든 색은 팔레트 색 + 알파, 위치는 정수 픽셀.
## 굴러갈 때의 궤적(trail)은 trail_config() 로 설정을 얻어 휠이 입자를 뿌린다.

const SPARKLE := preload("res://assets/sprites/ui/sparkle.png")
const SPARKLE_WHITE := preload("res://assets/sprites/ui/sparkle_white.png")
const SPARKLE_FRAMES := 4
const SPARKLE_SIZE := 5
const GLINT_PERIOD := 2.6
const GLINT_FRAME := 0.08

const TIER_GOLD := 5
const TIER_JADE := 6
const TIER_DIAMOND := 10
const TIER_OBSIDIAN := 11
const TIER_STARLIGHT := 12
const TIER_VOID := 13
const TIER_COSMIC := 14

const RAINBOW: Array[Color] = [Palette.RED_HL, Palette.AMBER, Palette.GOLD_HL, Palette.CLOVER, Palette.NEON_CYAN, Palette.NEON_PURPLE]
const STARDUST: Array[Color] = [Palette.NEON_CYAN, Palette.NEON_PINK, Palette.GOLD_SHINE, Palette.IVORY, Palette.NEON_PURPLE]


## 구슬 뒤(구슬보다 먼저) 그리는 효과: 흑요석 테두리 광, 코스믹 성운 빛, 공허 고리.
static func draw_aura_back(ci: CanvasItem, tier: int, center: Vector2, size: int, scale: int, t: float, alpha: float = 1.0) -> void:
	if tier < 0 or alpha <= 0.0:
		return
	var radius := size * scale * 0.5
	var px := maxi(1, scale)
	if tier == TIER_OBSIDIAN:
		_rim_glow(ci, center, size, scale, t, alpha)
	if tier == TIER_COSMIC:
		_halo(ci, center, size, scale, Palette.NEON_PURPLE, 0.3 * alpha * (0.7 + 0.3 * sin(t * 2.0)))
		if size >= MarbleSprite.SIZE_BOARD:
			_halo(ci, center, size, scale, Palette.NEON_CYAN, 0.12 * alpha, 2)
	if tier == TIER_VOID:
		_void_ring(ci, center, radius, px, t, alpha, size >= MarbleSprite.SIZE_CARD)


## 구슬 앞(구슬 다음) 그리는 효과. center: 구슬 중심, size: 템플릿 크기(7/10/24), scale: 정수 배율, t: 시간(초)
static func draw_aura(ci: CanvasItem, tier: int, center: Vector2, size: int, scale: int, t: float, alpha: float = 1.0) -> void:
	if tier < 0 or alpha <= 0.0:
		return
	var marble := GameData.marble(tier)
	if marble == null:
		return
	var radius := size * scale * 0.5
	var px := maxi(1, scale)
	var big := size >= MarbleSprite.SIZE_CARD
	if tier >= TIER_JADE and tier <= TIER_DIAMOND:
		_gem_twinkles(ci, marble, center, radius, px, t, alpha, big)
	if tier == TIER_DIAMOND:
		_rainbow(ci, center, radius, px, t, alpha, big)
	if tier == TIER_STARLIGHT:
		_orbit_stars(ci, center, radius, px, t, alpha, big)
	if tier == TIER_COSMIC:
		_stardust(ci, center, radius, px, t, alpha, big)
	if tier >= TIER_GOLD:
		_glint(ci, tier, center, radius, scale, t, alpha, size)


## 주기적인 4방향 반짝임 별(좌상단 광택 자리).
static func _glint(ci: CanvasItem, tier: int, center: Vector2, radius: float, scale: int, t: float, alpha: float, size: int) -> void:
	var phase := fmod(t + tier * 0.37, GLINT_PERIOD)
	var frame := int(phase / GLINT_FRAME)
	if frame >= SPARKLE_FRAMES:
		return
	var texture := SPARKLE if tier == TIER_GOLD or tier == TIER_STARLIGHT else SPARKLE_WHITE
	var s := SPARKLE_SIZE * maxi(1, scale if size >= MarbleSprite.SIZE_CARD else 1)
	var pos := (center + Vector2(-radius * 0.45, -radius * 0.55) - Vector2(s, s) * 0.5).round()
	ci.draw_texture_rect_region(texture, Rect2(pos, Vector2(s, s)),
		Rect2(frame * SPARKLE_SIZE, 0, SPARKLE_SIZE, SPARKLE_SIZE), Color(1, 1, 1, alpha))


## 보석: 둘레에서 천천히 도는 반짝이 2~3개(재질 밝은 색·광택 색).
static func _gem_twinkles(ci: CanvasItem, marble: MarbleDef, center: Vector2, radius: float, px: int, t: float, alpha: float, big: bool) -> void:
	var count := 3 if big else 2
	for i in count:
		var phase := fmod(t * 0.8 + i * 0.43, 1.0)
		if phase > 0.5:
			continue
		var angle := t * 0.6 + i * TAU / count
		var dist := radius + (3.0 if big else 1.5) * px
		var pos := center + Vector2(cos(angle), sin(angle)) * dist
		var color := marble.color_shine if phase < 0.25 else marble.color_light
		var fade := alpha * (1.0 - absf(phase - 0.25) * 2.0)
		if big and phase > 0.12 and phase < 0.38:
			_plus(ci, pos, px, Palette.with_alpha(color, fade))
		else:
			_dot(ci, pos, px, Palette.with_alpha(color, fade))


## 다이아: 무지개 스파클(색이 돌아간다).
static func _rainbow(ci: CanvasItem, center: Vector2, radius: float, px: int, t: float, alpha: float, big: bool) -> void:
	var count := 4 if big else 2
	for i in count:
		var phase := fmod(t * 1.3 + i * 0.29, 1.0)
		if phase > 0.4:
			continue
		var angle := -t * 0.9 + i * TAU / count + 0.4
		var dist := radius + (1.0 + 4.0 * phase) * px
		var pos := center + Vector2(cos(angle), sin(angle)) * dist
		var color := RAINBOW[(i + int(t * 6.0)) % RAINBOW.size()]
		if big:
			_plus(ci, pos, px, Palette.with_alpha(color, alpha * (1.0 - phase * 2.0)))
		else:
			_dot(ci, pos, px, Palette.with_alpha(color, alpha))


## 흑요석: 보라빛 테두리 광(맥동).
static func _rim_glow(ci: CanvasItem, center: Vector2, size: int, scale: int, t: float, alpha: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	_halo(ci, center, size, scale, Palette.NEON_PURPLE, alpha * (0.3 + 0.35 * pulse))
	if size >= MarbleSprite.SIZE_BOARD:
		_halo(ci, center, size, scale, Palette.PURPLE_D, alpha * 0.35 * pulse, 2)


## 구슬 모양을 1px(또는 dist px) 바깥으로 네 방향에 그린다(테두리 광).
static func _halo(ci: CanvasItem, center: Vector2, size: int, scale: int, color: Color, alpha: float, dist: int = 1) -> void:
	var texture := MarbleSprite.halo_texture(size, color)
	var side := Vector2(size, size) * scale
	var top_left := (center - side * 0.5).round()
	for dir: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		ci.draw_texture_rect(texture, Rect2(top_left + dir * dist * scale, side), false, Color(1, 1, 1, alpha))


## 별빛: 둘레를 도는 별 2~3개 + 짧은 꼬리.
static func _orbit_stars(ci: CanvasItem, center: Vector2, radius: float, px: int, t: float, alpha: float, big: bool) -> void:
	var count := 3 if big else 2
	var dist := radius + (4.0 if big else 2.0) * px
	for i in count:
		var angle := t * 1.4 + i * TAU / count
		for k in 3:
			var a := angle - k * 0.16
			var pos := center + Vector2(cos(a), sin(a) * 0.8) * dist
			var color := Palette.GOLD_SHINE if k == 0 else Palette.GOLD_HL
			var fade := alpha * (1.0 - k * 0.35)
			if k == 0 and big and fmod(t * 2.0 + i, 1.0) < 0.5:
				_plus(ci, pos, px, Palette.with_alpha(color, fade))
			else:
				_dot(ci, pos, px, Palette.with_alpha(color, fade))


## 공허: 어두운 고리 + 소용돌이치며 빨려 들어가는 입자.
static func _void_ring(ci: CanvasItem, center: Vector2, radius: float, px: int, t: float, alpha: float, big: bool) -> void:
	var ring := radius + px
	var steps := int(ring * 6.0)
	for s in steps:
		var a := TAU * s / steps
		var wobble := 0.5 + 0.5 * sin(a * 3.0 - t * 4.0)
		var pos := center + Vector2(cos(a), sin(a)) * (ring + wobble * px)
		_dot(ci, pos, px, Palette.with_alpha(Palette.PURPLE_D, alpha * (0.35 + 0.35 * wobble)))
	var count := 7 if big else 4
	for i in count:
		var u := fmod(t * 0.55 + float(i) / count, 1.0)
		var dist := radius + (1.0 - u) * (10.0 if big else 5.0) * px
		var a2 := i * TAU / count - u * 2.4 - t * 0.3
		var pos2 := center + Vector2(cos(a2), sin(a2)) * dist
		var color := Palette.NEON_PINK if i % 3 == 0 else (Palette.IVORY if i % 3 == 1 else Palette.NEON_PURPLE)
		_dot(ci, pos2, px, Palette.with_alpha(color, alpha * u))


## 코스믹: 타원 궤도를 도는 여러 색 별가루.
static func _stardust(ci: CanvasItem, center: Vector2, radius: float, px: int, t: float, alpha: float, big: bool) -> void:
	var count := 9 if big else 4
	for i in count:
		var speed := 0.7 + 0.25 * (i % 3)
		var a := t * speed + i * 2.1
		var dist := radius + (2.0 + (i % 3) * 2.0) * px * (1.0 if big else 0.5)
		var pos := center + Vector2(cos(a), sin(a) * 0.55) * dist
		var twinkle := fmod(t * 1.7 + i * 0.37, 1.0)
		var color := STARDUST[i % STARDUST.size()]
		_dot(ci, pos, px, Palette.with_alpha(color, alpha * (0.45 + 0.55 * absf(twinkle - 0.5) * 2.0)))


static func _dot(ci: CanvasItem, pos: Vector2, px: int, color: Color) -> void:
	ci.draw_rect(Rect2(pos.floor(), Vector2(px, px)), color)


static func _plus(ci: CanvasItem, pos: Vector2, px: int, color: Color) -> void:
	var p := pos.floor()
	ci.draw_rect(Rect2(p, Vector2(px, px)), color)
	for dir: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		ci.draw_rect(Rect2(p + dir * px, Vector2(px, px)), Palette.with_alpha(color, color.a * 0.6))


# ── 굴러갈 때의 궤적 ─────────────────────────────────────

## 재질별 궤적 설정: rate(초당 입자), life(초), colors, kind("dot"|"plus"|"ghost"), ghosts(공 잔상 수 추가)
static func trail_config(tier: int) -> Dictionary:
	var marble := GameData.marble(tier)
	if marble == null or tier <= 1:
		return {"rate": 0.0, "life": 0.0, "colors": [], "kind": "dot", "ghosts": 0}
	if tier <= 4:
		return {"rate": 26.0, "life": 0.16, "colors": [marble.color_light, marble.color_shine], "kind": "dot", "ghosts": 0}
	if tier == TIER_GOLD:
		return {"rate": 34.0, "life": 0.32, "colors": [Palette.GOLD_HL, Palette.GOLD_SHINE, Palette.GOLD_L], "kind": "dot", "ghosts": 1}
	if tier < TIER_DIAMOND:
		return {"rate": 40.0, "life": 0.36, "colors": [marble.color_light, marble.color_shine, marble.color_base], "kind": "plus", "ghosts": 1}
	if tier == TIER_DIAMOND:
		return {"rate": 52.0, "life": 0.42, "colors": RAINBOW, "kind": "plus", "ghosts": 1}
	if tier == TIER_OBSIDIAN:
		return {"rate": 36.0, "life": 0.4, "colors": [Palette.NEON_PURPLE, Palette.PURPLE_D], "kind": "ghost", "ghosts": 2}
	if tier == TIER_STARLIGHT:
		return {"rate": 44.0, "life": 0.6, "colors": [Palette.GOLD_SHINE, Palette.GOLD_HL, Palette.IVORY], "kind": "plus", "ghosts": 2}
	if tier == TIER_VOID:
		return {"rate": 50.0, "life": 0.55, "colors": [Palette.NEON_PURPLE, Palette.NEON_PINK, Palette.PURPLE_D], "kind": "suck", "ghosts": 2}
	return {"rate": 64.0, "life": 0.8, "colors": STARDUST, "kind": "plus", "ghosts": 3}
