class_name ContractPopup
extends Control
## 대출 계약서 팝업(ART_BIBLE 11-4). 양피지가 위에서 펼쳐지고 [서명한다] → 서명 → 도장.
## 칩 자루 토스는 Main(오케스트레이터)이 signed() 를 받은 뒤 FlyingChips 로 처리한다(top_bar 참조가 필요해서).

signal signed()

const SIZE := Vector2(260, 180)
const UNROLL_TIME := 0.4
const SIGN_TIME := 0.5
const STAMP_SHAKE_TIME := 0.2
const STAMP_SHAKE_PX := 1
const SIGN_LINE_Y := 150.0
const SIGN_LINE_X0 := 30.0
const SIGN_LINE_X1 := 160.0
const STAMP_ICON := preload("res://assets/sprites/fx/seizure_stamp.png")
const STAMP_POS := Vector2(190, 132)

var _clip: Control
var _parchment: Control
var _title: Label
var _principal_label: Label
var _repay_label: Label
var _method_label: Label
var _sign_button: Button
var _stamp: TextureRect
var _quill_seed: int = 0

var _signing: bool = false
var _sign_time: float = 0.0
var _shake_time: float = -1.0
var _shake_base := Vector2.ZERO


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	_clip.size = Vector2(SIZE.x, 0)
	add_child(_clip)
	_parchment = Control.new()
	_parchment.size = SIZE
	_parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parchment.draw.connect(_on_draw_parchment)
	_clip.add_child(_parchment)
	_title = _label("LabelTitle", Vector2(0, 10), SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	_title.text = tr("CONTRACT_TITLE")
	_title.add_theme_color_override("font_color", Palette.WOOD_D)
	_clip.add_child(_title)
	_principal_label = _label("LabelBold", Vector2(20, 46), SIZE.x - 40, HORIZONTAL_ALIGNMENT_LEFT)
	_principal_label.add_theme_color_override("font_color", Palette.WOOD_D)
	_clip.add_child(_principal_label)
	_repay_label = _label("LabelBold", Vector2(20, 64), SIZE.x - 40, HORIZONTAL_ALIGNMENT_LEFT)
	_repay_label.add_theme_color_override("font_color", Palette.RED_D)
	_clip.add_child(_repay_label)
	_method_label = _label("LabelSmall", Vector2(20, 86), SIZE.x - 40, HORIZONTAL_ALIGNMENT_LEFT)
	_method_label.add_theme_color_override("font_color", Palette.INK)
	_method_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_clip.add_child(_method_label)
	_sign_button = Button.new()
	_sign_button.theme_type_variation = "ButtonGold"
	_sign_button.text = tr("CONTRACT_SIGN_BUTTON")
	_sign_button.size = Vector2(96, 22)
	_sign_button.position = Vector2((SIZE.x - 96) * 0.5, SIZE.y - 30)
	_sign_button.pressed.connect(_on_sign_pressed)
	_clip.add_child(_sign_button)
	_stamp = TextureRect.new()
	_stamp.texture = STAMP_ICON
	_stamp.position = STAMP_POS
	_stamp.scale = Vector2(1.5, 1.5)
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.visible = false
	_clip.add_child(_stamp)


func _label(variation: String, pos: Vector2, width: float, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.position = pos
	label.size = Vector2(width, 16)
	label.horizontal_alignment = align
	return label


## principal(대출액)·repay(상환액)를 보여주며 열린다.
func open(principal: float, repay: float) -> void:
	_title.text = tr("CONTRACT_TITLE")
	_principal_label.text = tr("CONTRACT_PRINCIPAL") % NumberFormat.format_full(principal)
	_repay_label.text = tr("CONTRACT_REPAY") % NumberFormat.format_full(repay)
	_method_label.text = tr("CONTRACT_METHOD")
	_open_common()


## 대출과 다른 문구(7단계 엔딩의 카지노 양도 증서)로 연다. 서명·도장 메커니즘은 open() 과 같다.
func open_custom(title: String, line1: String, line2: String, line3: String) -> void:
	_title.text = title
	_principal_label.text = line1
	_repay_label.text = line2
	_repay_label.remove_theme_color_override("font_color")
	_method_label.text = line3
	_open_common()


func _open_common() -> void:
	_sign_button.disabled = false
	_sign_button.visible = true
	_stamp.visible = false
	_signing = false
	_shake_time = -1.0
	_quill_seed = randi()
	visible = true
	_clip.size = Vector2(SIZE.x, 0)
	AudioManager.play_sfx("contract_unroll")
	var tween := create_tween()
	tween.tween_method(func(h: float) -> void: _clip.size = Vector2(SIZE.x, roundf(h)), 0.0, SIZE.y, UNROLL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	visible = false


func _on_sign_pressed() -> void:
	_sign_button.disabled = true
	_signing = true
	_sign_time = 0.0
	AudioManager.play_sfx("quill_sign")


func _on_draw_parchment() -> void:
	_parchment.draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.WOOD_L)
	_parchment.draw_rect(Rect2(Vector2(3, 3), SIZE - Vector2(6, 6)), Palette.IVORY)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 14:
		var pos := Vector2(rng.randf_range(6, SIZE.x - 6), rng.randf_range(6, SIZE.y - 6))
		_parchment.draw_rect(Rect2(pos.floor(), Vector2(1, 1)), Palette.WOOD)
	_parchment.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0), false, 1.0)
	if _signing or _sign_time > 0.0 or _stamp.visible:
		_draw_signature()


func _draw_signature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _quill_seed
	var progress := clampf(_sign_time / SIGN_TIME, 0.0, 1.0)
	var full_len := SIGN_LINE_X1 - SIGN_LINE_X0
	var shown_len := full_len * progress
	var steps := int(shown_len / 4.0) + 1
	var prev := Vector2(SIGN_LINE_X0, SIGN_LINE_Y)
	for i in steps:
		var x: float = minf(SIGN_LINE_X0 + (i + 1) * 4.0, SIGN_LINE_X0 + shown_len)
		var y: float = SIGN_LINE_Y + rng.randf_range(-3.0, 3.0)
		var point := Vector2(x, y)
		_parchment.draw_line(prev, point, Palette.NIGHT, 1.0)
		prev = point


func _process(delta: float) -> void:
	if not visible:
		return
	if _signing:
		_sign_time += delta
		_parchment.queue_redraw()
		if _sign_time >= SIGN_TIME:
			_signing = false
			_do_stamp()
	if _shake_time >= 0.0:
		_shake_time += delta
		if _shake_time >= STAMP_SHAKE_TIME:
			_shake_time = -1.0
			position = _shake_base
		else:
			var step := int(_shake_time / 0.05) % 2
			position = _shake_base + Vector2(STAMP_SHAKE_PX if step == 0 else -STAMP_SHAKE_PX, 0)


func _do_stamp() -> void:
	_stamp.visible = true
	_sign_button.visible = false
	_shake_base = position
	_shake_time = 0.0
	AudioManager.play_sfx("stamp_thud")
	signed.emit()
