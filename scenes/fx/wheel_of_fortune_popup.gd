class_name WheelOfFortunePopup
extends Control
## 운명의 휠(6단계, Y14): 10분마다 뜨는 화면 중앙 8칸 보너스 팝업(GDD 6장).
## 클릭해서 돌리거나, 오토 스핀 모드면 5초 뒤 저절로 돈다. 결과는 WheelOfFortuneService 가 실제로 지급한다.

signal finished()

enum State { IDLE, SPINNING, RESULT }

const SIZE := Vector2(160, 180)
const WHEEL_RADIUS := 60.0
const AUTO_SPIN_DELAY := 5.0
const SPIN_TIME := 2.2
const SPIN_TURNS := 3.0
const RESULT_HOLD := 1.6
const SLICE_COLORS: Array[Color] = [Palette.NEON_PURPLE, Palette.GOLD]

var _state: State = State.IDLE
var _slice: WheelOfFortuneService.Slice = WheelOfFortuneService.Slice.CLOVER_2
var _timer: float = 0.0
var _auto_wait: float = -1.0
var _wheel_angle: float = 0.0
var _target_angle: float = 0.0

var _wheel_center: Vector2
var _title_label: Label
var _result_label: Label
var _hint_label: Label


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := Panel.new()
	bg.theme_type_variation = "PanelPlain"
	bg.size = SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_title_label = Label.new()
	_title_label.text = "WHEEL_OF_FORTUNE_TITLE"
	_title_label.theme_type_variation = "LabelTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 4)
	_title_label.size = Vector2(SIZE.x, 14)
	add_child(_title_label)
	_wheel_center = Vector2(SIZE.x * 0.5, 24.0 + WHEEL_RADIUS)
	_hint_label = Label.new()
	_hint_label.text = "WHEEL_OF_FORTUNE_HINT"
	_hint_label.theme_type_variation = "LabelMuted"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position = Vector2(0, SIZE.y - 14)
	_hint_label.size = Vector2(SIZE.x, 12)
	add_child(_hint_label)
	_result_label = Label.new()
	_result_label.theme_type_variation = "LabelGold"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.position = Vector2(0, SIZE.y - 14)
	_result_label.size = Vector2(SIZE.x, 12)
	_result_label.visible = false
	add_child(_result_label)
	gui_input.connect(_on_gui_input)


func open() -> void:
	visible = true
	_state = State.IDLE
	_timer = 0.0
	_result_label.visible = false
	_hint_label.visible = true
	_auto_wait = AUTO_SPIN_DELAY if GameState.auto_spin_enabled else -1.0
	AudioManager.play_sfx("wof_appear")


func _on_gui_input(event: InputEvent) -> void:
	if _state == State.IDLE and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_start_spin()


func _start_spin() -> void:
	_state = State.SPINNING
	_timer = 0.0
	_hint_label.visible = false
	_slice = WheelOfFortuneService.roll()
	var index := WheelOfFortuneService.SLICES.find(_slice)
	var slice_count := WheelOfFortuneService.SLICES.size()
	_target_angle = TAU * SPIN_TURNS + (TAU / slice_count) * index + (TAU / slice_count) * 0.5


func _process(delta: float) -> void:
	if not visible:
		return
	match _state:
		State.IDLE:
			if _auto_wait >= 0.0:
				_auto_wait -= delta
				if _auto_wait <= 0.0:
					_start_spin()
		State.SPINNING:
			_timer += delta
			var u := clampf(_timer / SPIN_TIME, 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - u, 3.0)
			_wheel_angle = lerpf(0.0, _target_angle, eased)
			if _timer < SPIN_TIME:
				var tick_every := 0.08
				if fmod(_timer, tick_every) < delta:
					AudioManager.play_sfx("wof_tick", randf_range(0.95, 1.05))
			if u >= 1.0:
				_land()
		State.RESULT:
			_timer += delta
			if _timer >= RESULT_HOLD:
				_close()
	queue_redraw()


func _land() -> void:
	_state = State.RESULT
	_timer = 0.0
	var info := WheelOfFortuneService.apply(_slice)
	_result_label.text = tr(WheelOfFortuneService.name_key(_slice))
	_result_label.visible = true
	AudioManager.play_sfx("wof_land")
	if float(info.get("amount", 0.0)) > 0.0:
		FloatingText.spawn(self, NumberFormat.format_signed(float(info["amount"])), "Num14Gold", Vector2(SIZE.x * 0.5, SIZE.y - 30))


func _close() -> void:
	visible = false
	GameState.wheel_of_fortune_consumed()
	finished.emit()


func _draw() -> void:
	var slice_count := WheelOfFortuneService.SLICES.size()
	var step := TAU / slice_count
	for i in slice_count:
		var a0 := _wheel_angle + i * step
		var points := PackedVector2Array([_wheel_center])
		for s in 5:
			points.append(_wheel_center + Vector2(cos(a0 + step * s / 4.0), sin(a0 + step * s / 4.0)) * WHEEL_RADIUS)
		draw_colored_polygon(points, SLICE_COLORS[i % SLICE_COLORS.size()])
	draw_arc(_wheel_center, WHEEL_RADIUS, 0.0, TAU, 48, Palette.IVORY, 1.5)
	draw_circle(_wheel_center, 8.0, Palette.NIGHT)
	# 위쪽 포인터
	var tip := _wheel_center + Vector2(0, -WHEEL_RADIUS - 6.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-4, -6), tip + Vector2(4, -6)]), Palette.GOLD_HL)
