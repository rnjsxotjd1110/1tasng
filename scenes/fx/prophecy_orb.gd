class_name ProphecyOrb
extends Control
## 예지(6단계, Y2 "prophecy"/Y9 "clairvoyance"): 휠 위 작은 수정구가 다음 결과의 색을 살짝 보여준다.
## RngService.peek_next(1)[0] 로 다음 결과를 미리 보되 실제 값은 절대 노출하지 않고, ProphecyService 로
## 정확도만큼만 맞는 색 힌트를 만든다. 스핀이 하나 끝날 때 딱 한 번만 refresh() 한다(매 프레임 다시 뽑으면
## 힌트가 안 맞아도 misc 스트림을 계속 소모해 깜빡이게 된다).

const SIZE := Vector2(16, 16)
const PULSE_SPEED := 2.0
const COLOR_BY_POCKET := {
	RouletteRules.PocketColor.RED: Palette.RED_L,
	RouletteRules.PocketColor.BLACK: Palette.POCKET_K_L,
	RouletteRules.PocketColor.GREEN: Palette.FELT_L,
}

var _hint_color: Color = Palette.MIST
var _pulse: float = 0.0


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: TooltipLayer.show_tip(self, tr("PROPHECY_TOOLTIP"), get_global_rect()))
	mouse_exited.connect(func() -> void: TooltipLayer.hide_tip(self))
	refresh()


## 다음 스핀의 힌트를 새로 계산한다. 기능이 없으면 숨긴다.
func refresh() -> void:
	visible = SkillService.has_feature("prophecy")
	if not visible:
		return
	var accuracy := ProphecyService.accuracy_for_level(SkillService.feature_level("prophecy"))
	var next_result := RngService.peek_next(1)[0]
	var hinted := ProphecyService.color_hint(next_result, accuracy)
	_hint_color = COLOR_BY_POCKET.get(hinted, Palette.MIST)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var center := SIZE * 0.5
	var glow := 0.7 + 0.3 * sin(_pulse * PULSE_SPEED)
	draw_circle(center, 7.0, Palette.with_alpha(Palette.NIGHT, 0.9))
	draw_circle(center, 5.5, Palette.with_alpha(_hint_color, 0.55 * glow))
	draw_arc(center, 7.0, 0.0, TAU, 24, Palette.with_alpha(Palette.NEON_PURPLE, 0.85), 1.0)
	draw_circle(center + Vector2(-1.5, -1.5), 1.2, Palette.with_alpha(Palette.IVORY, 0.6))
