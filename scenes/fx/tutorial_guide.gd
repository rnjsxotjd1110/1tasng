class_name TutorialGuide
extends Control
## 루시 튜토리얼(8단계 2/N, GDD "튜토리얼" 절). 6단계로 진행하며 각 단계는 실제 게임 이벤트(EventBus)가
## 조건을 채우면 넘어간다. 대상 UI 영역만 밝히고 나머지는 어둡게 하되, 클릭은 막지 않는다(순수 시각 안내 —
## "자연스럽게 녹인다"는 요청 명세대로 별도 입력 차단 없이 실제 UI 를 그대로 조작하게 한다).
## 신규 기능 1회성 팁(첫 대출·첫 층 이동·황금 포켓 해금)은 이 화면의 활성 여부와 무관하게 항상 검사한다
## (SettingsManager.tutorial_enabled 로만 켜고 끈다).

enum Step { PLACE_BET, SPIN, RESULT, UPGRADE_TAB, UPGRADE_BUY, CLOVER, SKILLTREE, DONE }

signal step_changed(step: Step)

const SCREEN := Vector2(640, 360)
## 완전 불투명(1.0). 이 프로젝트가 쓰는 렌더러(gl_compatibility, 소프트웨어 Mesa) 조합에서는
## CanvasLayer 의 반투명 ColorRect 가 같은 CanvasLayer/UI 위에서는 정상 합성되지만, world(Node2D,
## 휠·배경) 위에서는 알파값(0.85 까지도)과 무관하게 전혀 합성되지 않는 문제를 픽셀 비교로 실측
## 확인했다(JackpotOverlay 의 기존 DIM_ALPHA=0.85 도 휠 위에서는 같은 증상 — 8단계 2/N 에서 발견,
## 별도 이슈로 보고함). 완전 불투명이면 블렌딩 없이 덮어써서 이 문제를 피해간다.
const DIM_ALPHA := 1.0
const BORDER_WIDTH := 1.0
const POINTER_SIZE := Vector2(12, 12)
const POINTER_BOB_PX := 2
const POINTER_BOB_PERIOD := 0.7

var main: Main
var _active: bool = false
var _target_rect: Rect2 = Rect2()
var _pointer_anchor: Vector2 = Vector2.ZERO
var _pointer_dir: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0
var _pointer: Control
## 어둡게 덮는 4조각(위/아래/좌/우) + 금테 4조각. JackpotOverlay 와 같은 방식(ColorRect.color, DIM_ALPHA
## 참고)으로 통일해 렌더러 조합에 따라 낮은 알파가 안 보이는 문제(위 DIM_ALPHA 참고)를 피한다.
var _dim_rects: Array[ColorRect] = []
var _border_rects: Array[ColorRect] = []


func _ready() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	EventBus.debt_changed.connect(_on_debt_changed_tip)
	EventBus.floor_changed.connect(_on_floor_changed_tip)
	for i in 4:
		var dim := ColorRect.new()
		dim.color = Palette.with_alpha(Palette.VOID, DIM_ALPHA)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.visible = false
		add_child(dim)
		_dim_rects.append(dim)
	for i in 4:
		var border := ColorRect.new()
		border.color = Palette.GOLD_HL
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.visible = false
		add_child(border)
		_border_rects.append(border)
	_pointer = _Pointer.new()
	_pointer.visible = false
	add_child(_pointer)


## Main._ready() 뒤에서 한 번 호출한다. step 은 보통 GameState.tutorial_step(불러온 값 또는 0).
func start(main_ref: Main, step: int) -> void:
	main = main_ref
	main.top_bar.tab_pressed.connect(_on_tab_pressed)
	EventBus.bets_changed.connect(_on_bets_changed)
	EventBus.spin_resolved.connect(_on_spin_resolved)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.first_clover_earned.connect(_on_first_clover_earned)
	if not SettingsManager.tutorial_enabled or step >= Step.DONE:
		return
	_active = true
	visible = true
	_goto_step(step as Step)


## 설정 화면 "다시 보기"(EventBus.tutorial_reset_requested)에서 부른다.
func restart() -> void:
	if main == null:
		return
	_active = SettingsManager.tutorial_enabled
	visible = _active
	if _active:
		_goto_step(Step.PLACE_BET)


func is_active_at(step: Step) -> bool:
	return _active and GameState.tutorial_step == step


func _goto_step(step: Step) -> void:
	GameState.tutorial_step = step
	step_changed.emit(step)
	var rect := _highlight_rect_for(step)
	if rect.size != Vector2.ZERO:
		_highlight(rect)
	else:
		_clear_highlight()
	match step:
		Step.PLACE_BET:
			_show_step_line("tutorial_place_bet")
		Step.SPIN:
			_show_step_line("tutorial_spin")
		Step.RESULT:
			_show_step_line("tutorial_result", func() -> void: _goto_step(Step.UPGRADE_TAB))
		Step.UPGRADE_TAB:
			_show_step_line("tutorial_upgrade_tab")
		Step.UPGRADE_BUY:
			_show_step_line("tutorial_upgrade_buy")
		Step.CLOVER:
			_show_step_line("tutorial_clover")
		Step.SKILLTREE:
			_show_step_line("tutorial_skilltree", func() -> void: _goto_step(Step.DONE))
		Step.DONE:
			_finish()
			return
	# 1프레임 뒤 그 시점의 단계를 다시 측정해 하이라이트를 갱신한다: 이 단계로 막 들어온 첫 프레임에는
	# BetBoard/UpgradePanel 같은 대상의 레이아웃이 아직 자리잡지 않아 get_global_rect() 가 틀린(0 크기)
	# 값을 줄 때가 있다(캡처로 발견 — 새 게임 시작 직후의 구슬 놓기 단계에서만 스포트라이트가 안 보였다).
	# step 을 bind() 하지 않고 발동 시점의 GameState.tutorial_step 을 그대로 읽는다: bind 된 값이 다르면
	# Godot 이 "이미 연결됨" 오류를 내므로(같은 프레임 안에서 여러 단계를 연달아 넘기는 테스트에서 재현),
	# 인자 없는 같은 콜러블 하나만 걸어 두면 항상 안전하게 중복을 막을 수 있다.
	if not get_tree().process_frame.is_connected(_reapply_highlight):
		get_tree().process_frame.connect(_reapply_highlight, CONNECT_ONE_SHOT)


func _reapply_highlight() -> void:
	if not _active:
		return
	var step: Step = GameState.tutorial_step as Step
	var rect := _highlight_rect_for(step)
	if rect.size != Vector2.ZERO:
		_highlight(rect)


## 단계별 스포트라이트 대상(없으면 Rect2() — 설명만 하고 아무것도 밝히지 않는 단계).
func _highlight_rect_for(step: Step) -> Rect2:
	match step:
		Step.PLACE_BET:
			return main.bet_panel.board.get_global_rect()
		Step.SPIN:
			return main.spin_controls.spin_button.get_global_rect()
		Step.UPGRADE_TAB:
			return (main.top_bar.tab_buttons[TopBar.TAB_UPGRADE] as Control).get_global_rect()
		Step.UPGRADE_BUY:
			return main.upgrade_panel.get_global_rect()
		Step.SKILLTREE:
			return (main.top_bar.tab_buttons[TopBar.TAB_SKILLS] as Control).get_global_rect()
	return Rect2()


func _finish() -> void:
	_active = false
	visible = false
	_clear_highlight()
	GameState.tutorial_step = Step.DONE


## force=true 로 부른다: 이전 단계 대사가 아직 열려 있어도(플레이어가 안 닫고 바로 베팅·탭 클릭 등
## 다음 행동을 할 수 있으므로) 이번 단계 대사로 바로 바뀌어야 한다.
func _show_step_line(key: String, on_finished: Callable = Callable()) -> void:
	main._show_npc_line(key, true)
	if on_finished.is_valid() and main._npc_dialogue != null:
		main._npc_dialogue.finished.connect(on_finished, CONNECT_ONE_SHOT)


# ── 6단계 순서 진행 조건 ─────────────────────────────────────

func _on_bets_changed() -> void:
	if is_active_at(Step.PLACE_BET) and not GameState.current_bets.is_empty():
		_goto_step(Step.SPIN)


func _on_spin_resolved(_outcome: SpinOutcome) -> void:
	if is_active_at(Step.SPIN):
		_goto_step(Step.RESULT)


func _on_tab_pressed(id: String) -> void:
	if is_active_at(Step.UPGRADE_TAB) and id == TopBar.TAB_UPGRADE:
		_goto_step(Step.UPGRADE_BUY)


func _on_upgrade_purchased(id: String, level: int) -> void:
	if is_active_at(Step.UPGRADE_BUY) and id == GameState.UPGRADE_MARBLE_TIER and level >= 1:
		_goto_step(Step.CLOVER)


func _on_first_clover_earned() -> void:
	if is_active_at(Step.CLOVER):
		_goto_step(Step.SKILLTREE)


# ── 1회성 신규 기능 팁(활성 여부와 무관, SettingsManager.tutorial_enabled 로만 제어) ──

func _on_debt_changed_tip() -> void:
	if not SettingsManager.tutorial_enabled:
		return
	if GameState.get_stat_value(GameState.STAT_LOANS_TAKEN) >= 1.0 and GameState.mark_tutorial_tip_seen("first_loan"):
		EventBus.toast_requested.emit(tr("TUTORIAL_TIP_FIRST_LOAN"), "warning")


func _on_floor_changed_tip(index: int) -> void:
	if not SettingsManager.tutorial_enabled:
		return
	if index == 1 and GameState.mark_tutorial_tip_seen("first_floor"):
		EventBus.toast_requested.emit(tr("TUTORIAL_TIP_FIRST_FLOOR"), "chip")
	if index >= 2 and GameState.mark_tutorial_tip_seen("golden_pocket_unlocked"):
		EventBus.toast_requested.emit(tr("TUTORIAL_TIP_GOLDEN_POCKET_UNLOCKED"), "chip")


# ── 스포트라이트·손가락 포인터 연출 ───────────────────────────

func _highlight(target_global_rect: Rect2) -> void:
	_target_rect = target_global_rect
	var r := _target_rect
	for dim in _dim_rects:
		dim.visible = true
	for border in _border_rects:
		border.visible = true
	_dim_rects[0].position = Vector2(0, 0)
	_dim_rects[0].size = Vector2(SCREEN.x, r.position.y)
	_dim_rects[1].position = Vector2(0, r.end.y)
	_dim_rects[1].size = Vector2(SCREEN.x, SCREEN.y - r.end.y)
	_dim_rects[2].position = Vector2(0, r.position.y)
	_dim_rects[2].size = Vector2(r.position.x, r.size.y)
	_dim_rects[3].position = Vector2(r.end.x, r.position.y)
	_dim_rects[3].size = Vector2(SCREEN.x - r.end.x, r.size.y)
	_border_rects[0].position = r.position
	_border_rects[0].size = Vector2(r.size.x, BORDER_WIDTH)
	_border_rects[1].position = Vector2(r.position.x, r.end.y - BORDER_WIDTH)
	_border_rects[1].size = Vector2(r.size.x, BORDER_WIDTH)
	_border_rects[2].position = r.position
	_border_rects[2].size = Vector2(BORDER_WIDTH, r.size.y)
	_border_rects[3].position = Vector2(r.end.x - BORDER_WIDTH, r.position.y)
	_border_rects[3].size = Vector2(BORDER_WIDTH, r.size.y)
	# 대상 위쪽에 자리가 있으면 위에서 아래로, 없으면 아래에서 위로 가리킨다.
	if r.position.y >= POINTER_SIZE.y + 4.0:
		_pointer_anchor = Vector2(r.get_center().x - POINTER_SIZE.x / 2.0, r.position.y - POINTER_SIZE.y - 2.0)
		_pointer_dir = Vector2(0, 1)
	else:
		_pointer_anchor = Vector2(r.get_center().x - POINTER_SIZE.x / 2.0, r.end.y + 2.0)
		_pointer_dir = Vector2(0, -1)
	_pointer.position = _pointer_anchor
	_pointer.visible = true


func _clear_highlight() -> void:
	_target_rect = Rect2()
	for dim in _dim_rects:
		dim.visible = false
	for border in _border_rects:
		border.visible = false
	_pointer.visible = false


func _process(delta: float) -> void:
	if not _pointer.visible:
		return
	_bob_time += delta
	var phase := fmod(_bob_time, POINTER_BOB_PERIOD) / POINTER_BOB_PERIOD
	var bob := roundf(sin(phase * TAU) * POINTER_BOB_PX)
	_pointer.position = _pointer_anchor + _pointer_dir * bob


## 손가락 포인터(절차적, 새 스프라이트 없음): 둥근 손 + 위로 뻗은 검지.
class _Pointer extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = POINTER_SIZE

	func _draw() -> void:
		draw_rect(Rect2(2, 5, 8, 6), Palette.WOOD_HL)
		draw_rect(Rect2(2, 5, 8, 6), Palette.WOOD_D, false, 1.0)
		draw_rect(Rect2(4, 0, 3, 6), Palette.WOOD_HL)
		draw_rect(Rect2(4, 0, 3, 6), Palette.WOOD_D, false, 1.0)
