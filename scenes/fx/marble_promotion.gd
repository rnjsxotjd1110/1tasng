class_name MarblePromotion
extends Control
## 구슬 재질 승급 연출(ART_BIBLE 9-3, 약 2.4초, 클릭으로 건너뛰기).
##   1 화면이 어두워진다 → 2 이전 구슬이 48px(24px × 2)로 중앙에 떠오른다 → 3 빛이 모이며 흔들린다
##   → 4 흰 섬광과 함께 새 재질로 변신 → 5 재질 색 파티클 폭발 → 6 배너 "금 구슬 획득!" · "당첨 배율 ×900 → ×8K"
##   → 7 구슬이 트레이(또는 카드)로 날아가며 48 → 24 → 10px 로 작아지고, 닿는 순간 모든 구슬이 새 재질로 바뀐다(arrived)
## 재질이 높을수록 징글이 웅장하다(promote_jingle_1~3).

## 새 재질을 화면 전체에 적용할 때(구슬이 목적지에 닿음 또는 건너뛰기).
signal arrived(tier: int)
signal finished()

const CENTER := Vector2(320, 150)
const T_DIM := 0.25
const T_RISE_START := 0.1
const T_RISE_END := 0.45
const T_CHARGE_END := 1.15
const T_BANNER := 1.25
const T_FLY_START := 1.95
const T_FLY_END := 2.35
const T_END := 2.5
const RISE_PX := 16
const DIM_ALPHA := 0.72
const FLASH_ALPHA := 0.9
const FLASH_FADE := 0.25
const CHARGE_RATE := 70.0
const CHARGE_RADIUS_MIN := 44.0
const CHARGE_RADIUS_MAX := 72.0
const BURST_COUNT := 72
const BURST_SPEED_MIN := 50.0
const BURST_SPEED_MAX := 170.0
const BURST_LIFE := 0.9
const BURST_DRAG := 2.2
const RING_TIME := 0.55
const RING_MAX := 90.0
const FLY_ARC := 34.0
const BANNER_Y := 196.0
const BANNER_SLIDE := 8
const SKIP_FADE := 0.15
const RAY_COUNT := 12
const RAY_OUTER := 96.0
const RAY_INNER := 30.0
const RAY_LENGTH := 26.0
const RAY_SPIN := 0.8
const HALO_RADIUS := 29.0
const PLATE_PAD := Vector2(12, 5)
## 징글 단계: 이 tier 이상이면 2·3단계 징글.
const JINGLE_TIERS: Array[int] = [5, 10]

var playing: bool = false
var old_tier: int = 0
var new_tier: int = 0
## 날아갈 목적지(전역). 날기 시작할 때 부른다.
var target_provider: Callable = Callable()

var _time: float = 0.0
var _dim: ColorRect
var _flash: ColorRect
var _view: MarbleView
var _plate: Panel
var _banner: Label
var _sub: Label
var _skip: Label
var _particles: Array[Dictionary] = []
var _charge_accum: float = 0.0
var _swapped: bool = false
var _arrived: bool = false
var _fly_from := Vector2.ZERO
var _fly_to := Vector2.ZERO
var _queue: Array[Vector2i] = []
var _fading: float = -1.0


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.size = size
	_dim.color = Palette.with_alpha(Palette.VOID, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_view = MarbleView.new(0, MarbleSprite.SIZE_CARD, 2)
	_view.size = Vector2(64, 64)
	_view.spin = 1.0
	add_child(_view)
	_plate = Panel.new()
	_plate.theme_type_variation = "PanelPlain"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_banner = _label("LabelTitle", BANNER_Y)
	_sub = _label("LabelGold", BANNER_Y + 20)
	_skip = _label("LabelSmallMuted", 330)
	_skip.text = "PROMOTE_SKIP"
	_flash = ColorRect.new()
	_flash.size = size
	_flash.color = Palette.with_alpha(Palette.IVORY, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _label(variation: String, y: float) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, y)
	label.size = Vector2(640, 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## 승급 연출 시작. 이미 재생 중이면 끝난 뒤 이어서 재생한다.
func play(p_old: int, p_new: int) -> void:
	if playing:
		_queue.append(Vector2i(p_old, p_new))
		return
	old_tier = p_old
	new_tier = p_new
	playing = true
	visible = true
	_time = 0.0
	_fading = -1.0
	_swapped = false
	_arrived = false
	_particles.clear()
	_charge_accum = 0.0
	_view.tier = old_tier
	_set_view_size(MarbleSprite.SIZE_CARD, 2)
	_view.modulate.a = 0.0
	_view.visible = true
	var old_def := GameData.marble(old_tier)
	var new_def := GameData.marble(new_tier)
	_banner.text = tr("PROMOTE_BANNER") % tr(new_def.name_key)
	_sub.text = tr("PROMOTE_MULT") % [NumberFormat.format_mult(old_def.mult), NumberFormat.format_mult(new_def.mult)]
	for label: Label in [_banner, _sub]:
		label.modulate.a = 0.0
	var text_w := maxf(_banner.get_minimum_size().x, _sub.get_minimum_size().x)
	_plate.size = Vector2(text_w, 36) + PLATE_PAD * 2.0
	_plate.modulate.a = 0.0
	_skip.modulate.a = 0.0
	AudioManager.play_sfx("promote_charge")
	_update(0.0)


## 클릭·Space: 남은 연출을 건너뛰고 새 재질을 바로 적용한다.
func skip() -> void:
	if not playing or _fading >= 0.0:
		return
	if not _arrived:
		_arrived = true
		arrived.emit(new_tier)
	_fading = 0.0


func is_playing() -> bool:
	return playing


## 연출이 모두 끝났을 때의 재질(대기열 포함). 연출 중이 아니면 -1.
func pending_target() -> int:
	if not _queue.is_empty():
		return _queue[-1].y
	return new_tier if playing else -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip()
		accept_event()


func _set_view_size(template_size: int, pixel_scale: int) -> void:
	_view.template_size = template_size
	_view.pixel_scale = pixel_scale
	_view.queue_redraw_all()


func _view_center() -> Vector2:
	return _view.position + _view.size * 0.5


func _place_view(center: Vector2) -> void:
	_view.position = (center - _view.size * 0.5).round()


func _process(delta: float) -> void:
	if not playing:
		return
	if _fading >= 0.0:
		_fading += delta
		var u := clampf(_fading / SKIP_FADE, 0.0, 1.0)
		modulate.a = 1.0 - u
		if u >= 1.0:
			_finish()
		return
	_time += delta
	_update(delta)


func _update(delta: float) -> void:
	var t := _time
	_dim.color = Palette.with_alpha(Palette.VOID, DIM_ALPHA * clampf(t / T_DIM, 0.0, 1.0) * _end_fade(t))
	# 2) 떠오르기
	var rise := clampf((t - T_RISE_START) / (T_RISE_END - T_RISE_START), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - rise, 3.0)
	if t < T_FLY_START:
		var center := CENTER + Vector2(0, roundf(RISE_PX * (1.0 - eased)))
		# 3) 흔들림: 모일수록 빨라지는 정수 1px 흔들림
		if t >= T_RISE_END and t < T_CHARGE_END:
			var charge := (t - T_RISE_END) / (T_CHARGE_END - T_RISE_END)
			var rate := lerpf(10.0, 40.0, charge)
			var shake := 1 if charge > 0.4 else 0
			if charge > 0.8:
				shake = 2
			center += Vector2(shake if int(t * rate) % 2 == 0 else -shake, 0)
		_place_view(center)
		_view.modulate.a = eased
	# 빛이 모인다
	if t >= T_RISE_END and t < T_CHARGE_END:
		_charge_accum += CHARGE_RATE * delta
		while _charge_accum >= 1.0:
			_charge_accum -= 1.0
			_spawn_charge()
	# 4) 섬광 + 변신 + 5) 폭발
	if not _swapped and t >= T_CHARGE_END:
		_swapped = true
		_view.tier = new_tier
		_burst()
		AudioManager.play_sfx("promote_flash")
		AudioManager.play_sfx(_jingle())
	var flash_u := (t - T_CHARGE_END) / FLASH_FADE
	var flash_alpha := VisualSettings.flash_alpha(FLASH_ALPHA) * (1.0 - clampf(flash_u, 0.0, 1.0)) if flash_u >= 0.0 else 0.0
	_flash.color = Palette.with_alpha(Palette.IVORY, flash_alpha)
	# 6) 배너
	var banner_u := clampf((t - T_BANNER) / 0.2, 0.0, 1.0)
	var banner_alpha := banner_u * _end_fade(t)
	_banner.modulate.a = banner_alpha
	_sub.modulate.a = banner_alpha
	_plate.modulate.a = banner_alpha * 0.9
	_plate.position = Vector2(roundf(320 - _plate.size.x * 0.5), BANNER_Y - PLATE_PAD.y + roundf(BANNER_SLIDE * (1.0 - banner_u)))
	_skip.modulate.a = 0.8 * clampf(t / T_DIM, 0.0, 1.0) * _end_fade(t)
	_banner.position.y = BANNER_Y + roundf(BANNER_SLIDE * (1.0 - banner_u))
	_sub.position.y = BANNER_Y + 20 + roundf(BANNER_SLIDE * (1.0 - banner_u))
	# 7) 날아가기
	if t >= T_FLY_START:
		if _fly_to == Vector2.ZERO:
			_fly_from = _view_center()
			_fly_to = target_provider.call() if target_provider.is_valid() else CENTER
		var fly := clampf((t - T_FLY_START) / (T_FLY_END - T_FLY_START), 0.0, 1.0)
		if fly < 0.3:
			_set_view_size(MarbleSprite.SIZE_CARD, 2)
		elif fly < 0.65:
			_set_view_size(MarbleSprite.SIZE_CARD, 1)
		else:
			_set_view_size(MarbleSprite.SIZE_BOARD, 1)
		var e := fly * fly * (3.0 - 2.0 * fly)
		var pos := _fly_from.lerp(_fly_to, e) - Vector2(0, FLY_ARC * 4.0 * fly * (1.0 - fly))
		_place_view(pos)
		if fly >= 1.0 and not _arrived:
			_arrived = true
			_view.visible = false
			arrived.emit(new_tier)
	if t >= T_END:
		_finish()
	_update_particles(delta)
	queue_redraw()


func _end_fade(t: float) -> float:
	return 1.0 - clampf((t - T_FLY_START) / (T_END - T_FLY_START), 0.0, 1.0)


func _jingle() -> String:
	if new_tier >= JINGLE_TIERS[1]:
		return "promote_jingle_3"
	if new_tier >= JINGLE_TIERS[0]:
		return "promote_jingle_2"
	return "promote_jingle_1"


func _spawn_charge() -> void:
	var marble := GameData.marble(new_tier)
	var a := RngService.randf_range_misc(0.0, TAU)
	var r := RngService.randf_range_misc(CHARGE_RADIUS_MIN, CHARGE_RADIUS_MAX)
	var colors: Array[Color] = [marble.color_light, marble.color_shine, Palette.GOLD_SHINE, Palette.IVORY]
	_particles.append({"pos": CENTER + Vector2(cos(a), sin(a)) * r, "vel": Vector2.ZERO, "life": 0.5, "max": 0.5,
		"color": colors[RngService.randi_range_misc(0, colors.size() - 1)], "charge": true})


func _burst() -> void:
	var colors := GameData.marble(new_tier).palette_colors()
	for i in BURST_COUNT:
		var a := RngService.randf_range_misc(0.0, TAU)
		var speed := RngService.randf_range_misc(BURST_SPEED_MIN, BURST_SPEED_MAX)
		_particles.append({"pos": CENTER, "vel": Vector2(cos(a), sin(a)) * speed, "life": BURST_LIFE, "max": BURST_LIFE,
			"color": colors[1 + i % (colors.size() - 1)], "charge": false, "big": i % 4 == 0})


func _update_particles(delta: float) -> void:
	for p in _particles:
		p["life"] = float(p["life"]) - delta
		if bool(p["charge"]):
			var to_center := CENTER - Vector2(p["pos"])
			var u := 1.0 - float(p["life"]) / float(p["max"])
			p["pos"] = Vector2(p["pos"]) + to_center * minf(1.0, delta * (3.0 + 10.0 * u))
		else:
			p["vel"] = Vector2(p["vel"]) * exp(-BURST_DRAG * delta)
			p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)


func _draw() -> void:
	if _time >= T_RISE_END and _time < T_CHARGE_END:
		# 빛이 모인다: 안쪽으로 줄어드는 광선 + 점점 밝아지는 고리
		var charge := (_time - T_RISE_END) / (T_CHARGE_END - T_RISE_END)
		var marble := GameData.marble(new_tier)
		for i in RAY_COUNT:
			var a := TAU * i / RAY_COUNT + _time * RAY_SPIN
			var dir := Vector2(cos(a), sin(a))
			var phase := fmod(charge * 2.0 + float(i % 3) / 3.0, 1.0)
			var outer := lerpf(RAY_OUTER, RAY_INNER, phase)
			var inner := maxf(RAY_INNER * 0.8, outer - RAY_LENGTH)
			var color := marble.color_light if i % 2 == 0 else marble.color_shine
			draw_line((CENTER + dir * outer).round(), (CENTER + dir * inner).round(), Palette.with_alpha(color, 0.25 + 0.6 * phase * charge), -1.0)
		var pulse := 0.5 + 0.5 * sin(_time * lerpf(8.0, 30.0, charge))
		draw_arc(CENTER, HALO_RADIUS, 0.0, TAU, 48, Palette.with_alpha(marble.color_shine, charge * (0.3 + 0.5 * pulse)), -1.0)
		draw_arc(CENTER, HALO_RADIUS + 2.0, 0.0, TAU, 48, Palette.with_alpha(marble.color_light, charge * 0.3 * pulse), -1.0)
	for p in _particles:
		var u := float(p["life"]) / float(p["max"])
		var side := 2 if bool(p.get("big", false)) and u > 0.4 else 1
		draw_rect(Rect2(Vector2(p["pos"]).floor(), Vector2(side, side)), Palette.with_alpha(p["color"], clampf(u * 1.4, 0.0, 1.0)))
	if _swapped:
		var ring_u := clampf((_time - T_CHARGE_END) / RING_TIME, 0.0, 1.0)
		if ring_u < 1.0:
			var color := GameData.marble(new_tier).color_light
			draw_arc(CENTER, lerpf(12.0, RING_MAX, ring_u), 0.0, TAU, 48, Palette.with_alpha(color, 0.9 * (1.0 - ring_u)), -1.0)
			draw_arc(CENTER, lerpf(8.0, RING_MAX * 0.7, ring_u), 0.0, TAU, 40, Palette.with_alpha(Palette.IVORY, 0.6 * (1.0 - ring_u)), -1.0)


func _finish() -> void:
	playing = false
	visible = false
	modulate.a = 1.0
	_fly_to = Vector2.ZERO
	_particles.clear()
	finished.emit()
	if not _queue.is_empty():
		var next: Vector2i = _queue.pop_front()
		play(next.x, next.y)
