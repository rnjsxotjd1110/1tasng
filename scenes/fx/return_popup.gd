class_name ReturnPopup
extends Control
## 복귀 팝업(4단계). 오프라인 수익을 카운트업으로 보여주고 [받기]를 누르면 칩에 더한다.
## 딜러 루시 초상화가 나오면(6단계, assets/sprites/npc/lucy_portrait.png, 64×64×7프레임 중 기본 표정)
## 자동으로 그걸 쓰고, 없으면 금고 아이콘.

signal claimed()

const SIZE := Vector2(272, 150)
const PORTRAIT_PATH := "res://assets/sprites/npc/lucy_portrait.png"
const PORTRAIT_FRAME_SIZE := 64
const VAULT_ICON := preload("res://assets/sprites/ui/icon_vault.png")
const PORTRAIT_POS := Vector2(14, 14)
const PORTRAIT_SIZE := Vector2(32, 32)
const COUNT_DURATION := 1.5
const TICK_INTERVAL_START := 0.16
const TICK_INTERVAL_END := 0.03

var _income_label: CountLabel
var _elapsed_label: Label
var _debt_row: HBoxContainer
var _debt_label: Label
var _clover_row: HBoxContainer
var _clover_label: Label
var _claim_button: Button

var _ticking: bool = false
var _tick_elapsed: float = 0.0
var _tick_next: float = 0.0
var _pending_income: float = 0.0
## 휴식 보상(M9): 이번 복귀에 함께 지급될 클로버.
var _pending_clovers: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.theme_type_variation = "PanelFelt"
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var portrait := TextureRect.new()
	if ResourceLoader.exists(PORTRAIT_PATH):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(PORTRAIT_PATH)
		atlas.region = Rect2(0, 0, PORTRAIT_FRAME_SIZE, PORTRAIT_FRAME_SIZE)
		portrait.texture = atlas
	else:
		portrait.texture = VAULT_ICON
	portrait.position = PORTRAIT_POS
	portrait.size = PORTRAIT_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	var text_x := PORTRAIT_POS.x + PORTRAIT_SIZE.x + 12.0
	var greeting := Label.new()
	greeting.text = "RETURN_GREETING"
	greeting.theme_type_variation = "LabelBold"
	greeting.position = Vector2(text_x, 14)
	greeting.size = Vector2(SIZE.x - text_x - 12.0, 32)
	greeting.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(greeting)
	_elapsed_label = Label.new()
	_elapsed_label.theme_type_variation = "LabelMuted"
	_elapsed_label.auto_translate = false
	_elapsed_label.position = Vector2(text_x, 46)
	_elapsed_label.size = Vector2(SIZE.x - text_x - 12.0, 28)
	_elapsed_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_elapsed_label)
	var income_row := HBoxContainer.new()
	income_row.position = Vector2(text_x, 76)
	income_row.add_theme_constant_override("separation", 4)
	add_child(income_row)
	var chip_icon := TextureRect.new()
	chip_icon.texture = preload("res://assets/sprites/ui/icon_chip.png")
	chip_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	income_row.add_child(chip_icon)
	_income_label = CountLabel.new()
	_income_label.theme_type_variation = "Num14Gold"
	_income_label.style = CountLabel.Style.SIGNED
	income_row.add_child(_income_label)
	_debt_row = HBoxContainer.new()
	_debt_row.position = Vector2(text_x, 94)
	_debt_row.visible = false
	add_child(_debt_row)
	_debt_label = Label.new()
	_debt_label.theme_type_variation = "LabelSmallMuted"
	_debt_label.auto_translate = false
	_debt_row.add_child(_debt_label)
	_clover_row = HBoxContainer.new()
	_clover_row.position = Vector2(text_x, 108)
	_clover_row.add_theme_constant_override("separation", 4)
	_clover_row.visible = false
	add_child(_clover_row)
	var clover_icon := TextureRect.new()
	clover_icon.texture = preload("res://assets/sprites/ui/icon_clover.png")
	clover_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_clover_row.add_child(clover_icon)
	_clover_label = Label.new()
	_clover_label.theme_type_variation = "LabelSmallMuted"
	_clover_label.auto_translate = false
	_clover_row.add_child(_clover_label)
	_claim_button = Button.new()
	_claim_button.theme_type_variation = "ButtonGold"
	_claim_button.text = "RETURN_CLAIM"
	_claim_button.size = Vector2(80, 24)
	_claim_button.position = Vector2((SIZE.x - 80.0) * 0.5, SIZE.y - 34)
	FocusStyle.apply(_claim_button)
	_claim_button.pressed.connect(_on_claim_pressed)
	add_child(_claim_button)


## offline 는 OfflineIncome.compute() 의 결과(eligible 인 경우에만 호출할 것). debt_repaid > 0 이면 빚 자동상환 내역도 보여준다.
func open(offline: OfflineIncome, debt_repaid: float = 0.0) -> void:
	_pending_income = offline.income
	_pending_clovers = offline.clover_bonus
	_clover_row.visible = offline.clover_bonus > 0
	if _clover_row.visible:
		_clover_label.text = tr("RETURN_REST_BONUS") % NumberFormat.format(float(offline.clover_bonus))
	# 머리글은 실제 경과 시간("3시간 12분"), 상한이 적용됐으면 뒤에 "(최대 N시간 적용)"만 덧붙인다(요청 명세 예시).
	var hours := int(offline.elapsed_seconds) / 3600
	var minutes := (int(offline.elapsed_seconds) / 60) % 60
	var text := tr("DURATION_HOURS_MINUTES") % [NumberFormat.format(float(hours)), NumberFormat.format(float(minutes))]
	if offline.elapsed_seconds > offline.capped_seconds + 1.0:
		var cap_hours := offline.capped_seconds / 3600.0
		text += " " + tr("RETURN_CAP_APPLIED") % NumberFormat.format_decimal(cap_hours)
	_elapsed_label.text = text
	_debt_row.visible = debt_repaid > 0.0
	if _debt_row.visible:
		_debt_label.text = tr("RETURN_DEBT_REPAID") % NumberFormat.format(debt_repaid)
	_income_label.set_value(0.0, 0.0)
	_ticking = true
	_tick_elapsed = 0.0
	_tick_next = 0.0
	_income_label.set_value(offline.income, COUNT_DURATION)
	PanelTransition.open(self)


func _process(delta: float) -> void:
	if not _ticking:
		return
	_tick_elapsed += delta
	if _tick_elapsed >= _tick_next:
		var progress := clampf(_tick_elapsed / COUNT_DURATION, 0.0, 1.0)
		AudioManager.play_sfx("chip_click", 1.0 + progress * 0.6)
		_tick_next = _tick_elapsed + lerpf(TICK_INTERVAL_START, TICK_INTERVAL_END, progress)
	if _tick_elapsed >= COUNT_DURATION:
		_ticking = false


func _on_claim_pressed() -> void:
	_ticking = false
	_income_label.set_value(_pending_income, 0.0)
	GameState.add_chips(_pending_income, false)
	if _pending_clovers > 0:
		GameState.add_clovers(_pending_clovers)
	AudioManager.play_sfx("buy_coin")
	claimed.emit()
	PanelTransition.close(self)
