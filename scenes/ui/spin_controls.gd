class_name SpinControls
extends Control
## 휠 아래 버튼 영역(y 316~352).
##   [SPIN] 큰 빨간 카지노 버튼: 준비되면 은은히 숨 쉬는 빛(가산), 누르면 눌림 프레임. Space 로도 동작(main 이 처리)
##   [AUTO] 토글: 스킬트리에서 해금 전까지 잠김(자물쇠 아이콘, 툴팁)

signal spin_pressed()
signal auto_pressed()

const AREA_SIZE := Vector2(316, 36)
const SPIN_SIZE := Vector2(80, 30)
const SPIN_POS := Vector2(118, 2)
const GLOW_OFFSET := Vector2(-6, -6)
const AUTO_SIZE := Vector2(52, 20)
const AUTO_POS := Vector2(206, 7)
const BREATH_PERIOD := 2.2
const BREATH_MIN := 0.15
const BREATH_MAX := 0.6
const LOCK_SHAKE_TIME := 0.3
## 오토 스핀 켜짐 틴트·다음 스핀 게이지(6단계).
const AUTO_ON_TINT := Color(0.72, 1.35, 0.82)
const AUTO_UNLOCK_FLASH := Color(1.6, 1.4, 0.6)
const AUTO_UNLOCK_TIME := 1.0
const AUTO_GAUGE_HEIGHT := 2.0

const GLOW := preload("res://assets/ui/spin_glow.png")
const LOCK := preload("res://assets/sprites/ui/icon_lock.png")

var spin_button: Button
var auto_button: Button
## 스킬트리에서 해금되면 false(6단계).
var auto_locked: bool = true
var ready_to_spin: bool = true

var _glow: TextureRect
var _clock: float = 0.0
var _lock_shake: float = 0.0
var _auto_toggled: bool = false
var _auto_unlock_time: float = -1.0
var _auto_gauge_bg: ColorRect
var _auto_gauge: ColorRect


func _ready() -> void:
	size = AREA_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = TextureRect.new()
	_glow.texture = GLOW
	_glow.position = SPIN_POS + GLOW_OFFSET
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	add_child(_glow)
	spin_button = Button.new()
	spin_button.text = "BUTTON_SPIN"
	spin_button.theme_type_variation = "SpinButton"
	spin_button.position = SPIN_POS
	spin_button.size = SPIN_SIZE
	spin_button.focus_mode = Control.FOCUS_NONE
	spin_button.pressed.connect(func() -> void: spin_pressed.emit())
	add_child(spin_button)
	auto_button = Button.new()
	auto_button.text = "BUTTON_AUTO"
	auto_button.icon = LOCK
	auto_button.theme_type_variation = "ButtonDark"
	auto_button.position = AUTO_POS
	auto_button.size = AUTO_SIZE
	auto_button.focus_mode = Control.FOCUS_NONE
	auto_button.pressed.connect(_on_auto)
	auto_button.mouse_entered.connect(_on_auto_hover)
	auto_button.mouse_exited.connect(func() -> void: TooltipLayer.hide_tip(auto_button))
	add_child(auto_button)
	_auto_gauge_bg = ColorRect.new()
	_auto_gauge_bg.color = Palette.with_alpha(Palette.VOID, 0.6)
	_auto_gauge_bg.position = AUTO_POS + Vector2(0, AUTO_SIZE.y + 1)
	_auto_gauge_bg.size = Vector2(AUTO_SIZE.x, AUTO_GAUGE_HEIGHT)
	_auto_gauge_bg.visible = false
	_auto_gauge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_auto_gauge_bg)
	_auto_gauge = ColorRect.new()
	_auto_gauge.color = Palette.CLOVER
	_auto_gauge.position = _auto_gauge_bg.position
	_auto_gauge.size = Vector2(0, AUTO_GAUGE_HEIGHT)
	_auto_gauge.visible = false
	_auto_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_auto_gauge)


## SPIN 가능 여부(칩 부족이면 비활성).
func set_spin_enabled(enabled: bool) -> void:
	spin_button.disabled = not enabled


func _on_auto() -> void:
	if auto_locked:
		_lock_shake = LOCK_SHAKE_TIME
		AudioManager.play_sfx("deny")
		_on_auto_hover()
		return
	auto_pressed.emit()


func _on_auto_hover() -> void:
	if auto_locked:
		TooltipLayer.show_tip(auto_button, tr("AUTO_LOCKED_TIP"), auto_button.get_global_rect())


## 스킬(M1)로 해금됐다. 자물쇠가 사라지고(불러오기 등 이미 해금된 상태를 조용히 맞출 땐 play_effects=false
## 로 소리·반짝임 없이) 버튼이 잠깐 금색으로 빛난다(TopBar 자물쇠 해제와 같은 연출).
func set_auto_locked(locked: bool, play_effects: bool = true) -> void:
	if auto_locked == locked:
		return
	auto_locked = locked
	if not locked:
		auto_button.icon = null
		if play_effects:
			_auto_unlock_time = 0.0
			AudioManager.play_sfx("lock_break")


## 오토 스핀 온/오프: 버튼이 초록으로 물들고 다음 스핀까지 남은 시간 게이지가 나타난다.
func set_auto_toggled(on: bool) -> void:
	_auto_toggled = on
	auto_button.modulate = AUTO_ON_TINT if on else Color.WHITE
	_auto_gauge_bg.visible = on
	_auto_gauge.visible = on
	if not on:
		_auto_gauge.size.x = 0.0


## ratio 0~1: 다음 오토 스핀까지 남은 시간의 진행도.
func set_auto_progress(ratio: float) -> void:
	if not _auto_toggled:
		return
	_auto_gauge.size.x = roundf(AUTO_SIZE.x * clampf(ratio, 0.0, 1.0))


func _process(delta: float) -> void:
	_clock += delta
	var breathing := not spin_button.disabled and ready_to_spin
	if breathing:
		var u := 0.5 + 0.5 * sin(_clock * TAU / BREATH_PERIOD)
		_glow.modulate.a = lerpf(BREATH_MIN, BREATH_MAX, u)
	else:
		_glow.modulate.a = 0.0
	if _lock_shake > 0.0:
		_lock_shake -= delta
		var step := int(_lock_shake / 0.04) % 2
		auto_button.position = AUTO_POS + Vector2(1 if step == 0 else -1, 0) if _lock_shake > 0.0 else AUTO_POS
	if _auto_unlock_time >= 0.0:
		_auto_unlock_time += delta
		var t := _auto_unlock_time / AUTO_UNLOCK_TIME
		if t >= 1.0:
			_auto_unlock_time = -1.0
			auto_button.modulate = AUTO_ON_TINT if _auto_toggled else Color.WHITE
		else:
			auto_button.modulate = AUTO_UNLOCK_FLASH.lerp(Color.WHITE, t)
