class_name FeverGauge
extends Control
## 피버 타임(6단계, Y5) 예열 게이지: 상단 바 바로 아래 얇은 무지개색 막대가 다음 발동까지 스핀 수를 센다.
## 피버가 진행 중일 때는 이 막대 대신 BuffBar 의 원형 게이지가 남은 시간을 보여준다.

const POS := Vector2(0, 24)
const SIZE := Vector2(640, 2)


func _ready() -> void:
	position = POS
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if SkillService.has_feature("fever_time"):
		queue_redraw()


func _draw() -> void:
	if not SkillService.has_feature("fever_time") or GameState.modifiers.has_source("buff:fever"):
		return
	var period := maxf(10.0, Economy.FEVER_PERIOD_SPINS - GameState.get_stat(StatModifiers.FEVER_PERIOD_REDUCTION, 0.0))
	var ratio := clampf(float(GameState.fever_spin_count) / period, 0.0, 1.0)
	var filled_w := int(roundf(SIZE.x * ratio))
	if filled_w <= 0:
		return
	var scroll := Time.get_ticks_msec() / 1200.0
	for x in filled_w:
		var hue := fmod(x / 60.0 + scroll, 1.0)
		draw_rect(Rect2(x, 0, 1, SIZE.y), Color.from_hsv(hue, 0.8, 1.0))
