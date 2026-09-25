class_name PiggyBankWidget
extends Control
## 황금 저금통(6단계, E13): 베팅창 구석에서 이번 창의 순이익이 차오르는 걸 보여주다 100스핀마다
## 깨져 칩을 쏟는다(EventBus.piggy_bank_broken). 새 스프라이트 없이 팔레트 색 도형으로 그린다.

const SIZE := Vector2(16, 14)
const BREAK_FLASH_TIME := 0.5

var _break_flash: float = -1.0


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: TooltipLayer.show_tip(self, tr("PIGGY_BANK_TOOLTIP"), get_global_rect()))
	mouse_exited.connect(func() -> void: TooltipLayer.hide_tip(self))
	EventBus.piggy_bank_broken.connect(func(_amount: float) -> void:
		_break_flash = 0.0
		AudioManager.play_sfx("piggy_break"))


func _process(delta: float) -> void:
	# E13 는 별도 feature_id 없이 PIGGY_BANK_RATE 스탯만 준다(_apply_piggy_bank() 도 같은 조건으로 켠다).
	visible = GameState.get_stat(StatModifiers.PIGGY_BANK_RATE, 0.0) > 0.0
	if not visible:
		return
	if _break_flash >= 0.0:
		_break_flash += delta
		if _break_flash >= BREAK_FLASH_TIME:
			_break_flash = -1.0
	queue_redraw()


func _draw() -> void:
	var ratio := clampf(float(GameState.piggy_bank_spins) / float(Economy.PIGGY_BANK_INTERVAL_SPINS), 0.0, 1.0)
	var body_top := 2.0
	var body_bottom := 12.0
	var fill_y := lerpf(body_bottom, body_top, ratio)
	draw_circle(Vector2(8, 7), 6.0, Palette.with_alpha(Palette.RED_D, 0.9))
	if ratio > 0.0:
		draw_rect(Rect2(2, fill_y, 12, body_bottom - fill_y), Palette.GOLD_L, true)
		draw_circle(Vector2(8, 7), 6.0, Palette.RED, false, 1.0)
	draw_circle(Vector2(11, 4), 1.0, Palette.RED_L)
	draw_circle(Vector2(12, 7), 0.8, Palette.NIGHT)
	if _break_flash >= 0.0:
		var burst := 1.0 - _break_flash / BREAK_FLASH_TIME
		draw_circle(Vector2(8, 7), 10.0 * burst, Palette.with_alpha(Palette.GOLD_HL, burst * 0.55))
