class_name MarbleView
extends Control
## 구슬 하나를 보여 주는 UI 부품(카드 미리보기·승급 연출·비교 시트).
## 크기는 템플릿(7/10/24px) × 정수 배율(pixel_scale). 재질 셰이더로 그리고, 재질별 부가 효과(MarbleFx)를 둘레에 그린다.
## tier < 0 이면 플레이어의 현재 재질(공용 머티리얼)을 따른다.

var tier: int = -1:
	set(value):
		tier = value
		_apply_material()
var template_size: int = MarbleSprite.SIZE_CARD
var pixel_scale: int = 1
## 1 = 천천히 회전(미리보기), 0 = 정지(재질 고유 회전만).
var spin: float = 1.0
var roll: float = 0.0
var brightness: float = 1.0
var show_shadow: bool = true
var show_aura: bool = true
## 부가 효과 시간(MarbleFx). 캡처·테스트용으로 고정할 수 있다.
var fx_time: float = 0.0

var _body: Control
var _aura: Control


func _init(p_tier: int = -1, p_size: int = MarbleSprite.SIZE_CARD, p_scale: int = 1) -> void:
	template_size = p_size
	pixel_scale = p_scale
	tier = p_tier


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := template_size * pixel_scale
	if size == Vector2.ZERO:
		size = Vector2(side, side)
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	add_child(_body)
	_aura = Control.new()
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura.draw.connect(_draw_aura)
	add_child(_aura)
	_apply_material()


func _apply_material() -> void:
	if _body == null:
		return
	_body.material = MarbleSprite.shared_material() if tier < 0 else MarbleSprite.material_for(tier)
	queue_redraw_all()


func effective_tier() -> int:
	return tier if tier >= 0 else MarbleSprite.shared_tier()


func marble_rect() -> Rect2:
	var side := Vector2(template_size, template_size) * pixel_scale
	return Rect2(((size - side) * 0.5).round(), side)


func queue_redraw_all() -> void:
	queue_redraw()
	if _body != null:
		_body.queue_redraw()
	if _aura != null:
		_aura.queue_redraw()


func _process(delta: float) -> void:
	fx_time += delta
	if show_aura:
		queue_redraw()
		if _aura != null:
			_aura.queue_redraw()


func _draw() -> void:
	var rect := marble_rect()
	if show_aura:
		MarbleFx.draw_aura_back(self, effective_tier(), rect.get_center(), template_size, pixel_scale, fx_time)
	if not show_shadow:
		return
	var offset := Vector2(pixel_scale, pixel_scale) * (2 if template_size >= MarbleSprite.SIZE_CARD else 1)
	draw_texture_rect(MarbleSprite.shadow_texture(template_size), Rect2(rect.position + offset, rect.size), false, Color(1, 1, 1, 0.45 * modulate.a))


func _draw_body() -> void:
	var rect := marble_rect()
	_body.draw_texture_rect(MarbleSprite.template(template_size), rect, false, MarbleSprite.instance_color(1.0, roll, spin, brightness))


func _draw_aura() -> void:
	if not show_aura:
		return
	var rect := marble_rect()
	MarbleFx.draw_aura(_aura, effective_tier(), rect.get_center(), template_size, pixel_scale, fx_time)
