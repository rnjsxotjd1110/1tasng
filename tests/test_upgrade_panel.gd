extends "res://tests/lib/test_case.gd"
## 업그레이드창 통합: 카드 순서·구매 반응·MAX 수량 표시·잠금/최대·연속 구매·탭 빨간 점·패널 슬라이드·
## 승급 연출 건너뛰기·새 슬롯·황금 포켓, 그리고 ko/en 텍스트 넘침.

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const STEP := 0.05

var main: Main
var panel: UpgradePanel


func before_each() -> void:
	super.before_each()
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	panel = main.upgrade_panel


func after_each() -> void:
	TranslationServer.set_locale("ko")
	main.free()
	main = null


func _give(amount: float) -> void:
	GameState.add_chips(amount)


func test_cards_in_spec_order() -> void:
	var ids: Array[String] = []
	for card in panel.cards:
		ids.append(card.def.id)
	check_eq(ids, ["marble_tier", "marble_polish", "bet_limit", "marble_count", "spin_speed", "golden_pocket"], "카드 순서")
	check(panel.cards[0].is_marble and panel.cards[0].size.y > panel.cards[1].size.y, "재질 카드가 가장 크다")
	check(panel.cards[0].marble_view != null, "재질 카드는 24px 회전 미리보기")
	check_eq(panel.cards[2].size, Vector2(UpgradeCard.CARD_W, UpgradeCard.CARD_H), "카드 200×44")
	check(panel.max_scroll() > 0.0, "카드가 넘쳐 스크롤")


func test_buy_through_panel() -> void:
	_give(100.0)
	var card := panel.card("bet_limit")
	var bought := watch(EventBus.upgrade_purchased)
	var chips := GameState.chips
	check_eq(panel.buy(card), 1, "베팅 한도 1레벨")
	check_eq(GameState.get_upgrade_level("bet_limit"), 1, "레벨 1")
	check_near(chips - GameState.chips, 20.0, 1e-9, "비용 20")
	check_eq(bought.size(), 1, "upgrade_purchased")
	check(card._flash_frames > 0, "흰 플래시")
	check(card._hop_time >= 0.0, "아이콘 튐")
	check_eq(card.level_label.text, tr("LABEL_LEVEL") % "1", "Lv.1 표시")
	GameState.spend_chips(GameState.chips)
	check_eq(panel.buy(card), 0, "칩 없으면 실패")
	check_eq(String(card.button.theme_type_variation), "ButtonStone", "못 사면 stone 버튼")


func test_max_mode_shows_real_quantity() -> void:
	_give(5000.0)
	panel.set_mode(UpgradeService.BuyMode.MAX)
	var card := panel.card("bet_limit")
	var expected := UpgradeService.max_affordable(card.def, 0, GameState.chips, -1)
	check_eq(card.qty_label.text, "×" + NumberFormat.format(expected), "버튼에 실제 수량")
	check_eq(card.cost_label.text, NumberFormat.format(UpgradeService.cost_for(card.def, 0, expected)), "합계 비용")
	check_eq(String(card.button.theme_type_variation), "ButtonGold", "살 수 있으면 금색")
	panel.set_mode(UpgradeService.BuyMode.TEN)
	check_eq(panel.card("marble_count").qty_label.text, "×7", "×10 은 남은 7레벨")


func test_locked_and_max_cards() -> void:
	var polish := panel.card("marble_polish")
	check(not polish.button.visible, "나무 구슬은 광택 잠김")
	check(polish.lock_label.visible and polish.lock_label.text != "", "잠금 조건 문구")
	check(polish._lock_icon.visible, "자물쇠")
	check_eq(String(polish.bg.theme_type_variation), "CardLocked", "잠긴 카드")
	var golden := panel.card("golden_pocket")
	check(golden.lock_label.text.contains("2F"), "황금 포켓은 2F")
	GameState.set_upgrade_level("marble_count", 7)
	panel.refresh()
	var count := panel.card("marble_count")
	check(count._stamp.visible, "MAX 스탬프")
	check_eq(String(count.bg.theme_type_variation), "CardMax", "금색 테두리")
	check(not count.button.visible, "최대 레벨은 버튼 없음")


func test_hold_to_buy_accelerates() -> void:
	main.switch_panel(TopBar.TAB_UPGRADE)
	main._finish_slide()
	_give(1e9)
	var card := panel.card("bet_limit")
	card._on_button_down()
	check_eq(GameState.get_upgrade_level("bet_limit"), 1, "누르는 순간 1회")
	var elapsed := 0.0
	while elapsed < UpgradeCard.HOLD_DELAY - 0.01:
		card._process(0.01)
		elapsed += 0.01
	check_eq(GameState.get_upgrade_level("bet_limit"), 1, "0.4초 전에는 추가 구매 없음")
	for i in 150:
		card._process(0.01)
	var after := GameState.get_upgrade_level("bet_limit")
	check(after >= 8, "0.4초 뒤부터 연속 구매(%d)" % after)
	card._on_button_up()
	for i in 50:
		card._process(0.01)
	check_eq(GameState.get_upgrade_level("bet_limit"), after, "떼면 멈춤")
	check(card._hold_interval < UpgradeCard.HOLD_START_INTERVAL, "점점 빨라짐")


func test_tab_dot_and_slide() -> void:
	GameState.spend_chips(GameState.chips)
	main.top_bar.refresh_upgrade_dot()
	check(not main.top_bar.upgrade_dot_visible(), "살 것이 없으면 점 없음")
	_give(20.0)
	check(main.top_bar.upgrade_dot_visible(), "살 수 있으면 빨간 점")
	main.switch_panel(TopBar.TAB_UPGRADE)
	check(not main.top_bar.upgrade_dot_visible(), "업그레이드창을 열면 점 숨김")
	check(main.is_sliding(), "슬라이드 중")
	check(main.bet_panel.visible and main.upgrade_panel.visible, "전환 중에는 둘 다 보임")
	check(main.right_clip.clip_contents, "전환 중에는 잘라 냄")
	main._finish_slide()
	check(not main.bet_panel.visible and main.upgrade_panel.visible, "전환 끝")
	check_eq(main.upgrade_panel.position, Vector2.ZERO, "제자리")
	check(not main.right_clip.clip_contents, "평소에는 자르지 않음(진 구슬 비행)")
	main.switch_panel(TopBar.TAB_BET)
	main._finish_slide()
	check(main.top_bar.upgrade_dot_visible(), "베팅창으로 돌아오면 다시 점")


func test_promotion_and_skip() -> void:
	_give(100.0)
	check_eq(MarbleSprite.shared_tier(), 0, "나무")
	UpgradeService.purchase("marble_tier")
	check(main.promotion.is_playing(), "승급 연출 시작")
	check_eq(MarbleSprite.shared_tier(), 0, "연출 중에는 아직 이전 재질")
	main.promotion.skip()
	check_eq(MarbleSprite.shared_tier(), 1, "건너뛰면 즉시 새 재질(모든 구슬)")
	for i in 10:
		main.promotion._process(STEP)
	check(not main.promotion.is_playing(), "연출 끝")


func test_promotion_runs_to_arrival() -> void:
	_give(100.0)
	UpgradeService.purchase("marble_tier")
	var t := 0.0
	while main.promotion.is_playing() and t < 4.0:
		main.promotion._process(STEP)
		t += STEP
	check(t >= 1.5 and t <= 2.6, "1.5~2.5초 연출(%.2f초)" % t)
	check_eq(MarbleSprite.shared_tier(), 1, "도착하면 새 재질")


func test_new_slot_animation() -> void:
	_give(1000.0)
	var board := main.bet_panel.board
	UpgradeService.purchase("marble_count")
	check_eq(board.pending_slot_count(), 1, "새 슬롯 연출 대기")
	check_eq(board.tray_count(), 1, "굴러오는 구슬은 아직 트레이에 없음")
	for i in 30:
		board._process(STEP)
	check_eq(board.pending_slot_count(), 0, "연출 끝")
	check_eq(board.tray_count(), 2, "구슬 2개")


func test_golden_pocket_beam_and_badge() -> void:
	GameState.floor_index = 2
	_give(1e6)
	UpgradeService.purchase("golden_pocket")
	var number: int = GameState.golden_pockets[0]
	check(not main.wheel.visible_golden().has(number), "빛줄기가 닿기 전에는 원래 색")
	check(main.wheel.is_beam_playing(), "빛줄기")
	for i in 30:
		main.wheel._process(STEP)
	check(main.wheel.visible_golden().has(number), "빛줄기가 닿으면 금색")
	var outcome := SpinOutcome.new()
	outcome.results = [number]
	outcome.golden_hit = true
	outcome.tier = SpinOutcome.Tier.LOSS
	outcome.net = -10.0
	main.play_tier_effects(outcome, [])
	check(main.golden_badge.visible, "GOLDEN 배지")
	check(main.golden_badge.text().contains(NumberFormat.format_mult(3.0)), "×3")


## 카드 글자가 카드·버튼 폭을 넘지 않는다(ko/en, 초반·후반 숫자).
func test_card_text_fits_ko_en() -> void:
	var states: Array[Dictionary] = [
		{"chips": 140.0, "floor": 0, "levels": {}},
		{"chips": 4.2e33, "floor": 4, "levels": {"marble_tier": 13, "marble_polish": 5, "bet_limit": 60, "marble_count": 7, "spin_speed": 13, "golden_pocket": 3}},
		{"chips": 1e60, "floor": 4, "levels": {"marble_tier": 14, "marble_polish": 5, "bet_limit": 110, "golden_pocket": 5}},
		{"chips": 1e5, "floor": 0, "levels": {"marble_tier": 3}},
	]
	for locale: String in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		for state in states:
			GameState.reset()
			GameState.floor_index = int(state["floor"])
			for id: String in (state["levels"] as Dictionary).keys():
				GameState.set_upgrade_level(id, int(state["levels"][id]))
			GameState.add_chips(float(state["chips"]))
			for mode: UpgradeService.BuyMode in [UpgradeService.BuyMode.ONE, UpgradeService.BuyMode.MAX]:
				panel.set_mode(mode)
				for card in panel.cards:
					_check_card_fits(card, "%s %s" % [locale, card.def.id])


func _right_limit(card: UpgradeCard) -> float:
	var rect := UpgradeCard.MARBLE_BUTTON_RECT if card.is_marble else UpgradeCard.BUTTON_RECT
	return rect.position.x - 1.0


func _end_x(label: Control) -> float:
	return label.position.x + label.get_minimum_size().x


func _check_card_fits(card: UpgradeCard, what: String) -> void:
	var limit := _right_limit(card)
	var name_limit := card.size.x - 4.0 if card.is_marble else limit
	check(_end_x(card.name_label) <= name_limit, "%s 이름 폭(%s)" % [what, card.name_label.text])
	if card.level_label.visible:
		check(_end_x(card.level_label) <= name_limit, "%s Lv 폭(%s)" % [what, card.level_label.text])
	if card.per_level_label.visible:
		check(_end_x(card.per_level_label) <= limit, "%s 레벨당 효과 폭(%s)" % [what, card.per_level_label.text])
	if card.next_label.visible:
		check(_end_x(card.next_label) <= limit, "%s 효과 변화 폭(%s → %s)" % [what, card.now_label.text, card.next_label.text])
	elif card.now_label.visible:
		check(_end_x(card.now_label) <= limit, "%s 효과 폭" % what)
	if card.lock_label.visible:
		check(card.lock_label.get_minimum_size().x <= card.lock_label.size.x or card.lock_label.get_theme_font("font").get_string_size(card.lock_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, card.lock_label.get_theme_font_size("font_size")).x <= card.lock_label.size.x,
			"%s 잠금 문구 폭(%s)" % [what, card.lock_label.text])
	if card.button.visible:
		check(card.cost_label.position.x + card.cost_label.get_minimum_size().x <= card.button.size.x - 2, "%s 비용 폭(%s)" % [what, card.cost_label.text])
		check(card.qty_label.position.x + card.qty_label.get_minimum_size().x <= card.button.size.x - 2, "%s 수량 폭" % what)
