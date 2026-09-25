extends RefCounted
## 9단계 밸런스 시뮬레이터의 실제 재생 로직. res://tools/sim/balance_sim.gd(SceneTree 진입 스크립트)가
## 런타임에 load().new() 로 불러와 실행한다. 진입 스크립트 자신이 오토로드(GameState 등)나 프로젝트
## class_name 클래스를 정적으로 직접 참조하면 오토로드가 준비되기 전에 컴파일되는 문제가 있어(8단계
## 마무리 레터박싱 작업에서 실측, tools/capture/capture.gd 도 같은 이유로 경로 문자열 + load() 를 쓴다) —
## tests/run_tests.gd 가 tests/test_*.gd 를 동적으로 불러오는 것과 같은 패턴으로 이 파일을 분리했다.
## 이 파일은 test_*.gd 처럼 런타임에 불려서 실행되므로 GameState·GameData 등을 자유롭게 정적 타입으로 쓴다.
##
## 정책(현실적으로 성실히 플레이하는 유저 한 명을 대표하는 기준선):
##   - 안정 베팅(빨강/검정/홀/짝 순환, SmartBettingService.STABLE)으로 감당할 수 있는 만큼 구슬을 걸고
##     (베팅 한도가 자산보다 빨리 크면 구슬 수를 줄인다), 항상 MAX 칩으로 건다.
##   - 스핀마다 다음 층 비용을 여유 있게(_safe_to_move_floor) 낼 수 있으면 그 즉시 올라간다(진행이 최우선).
##   - 그렇지 않으면 남는 칩의 upgrade_ratio(기본 0.25 — balance_sim.gd 기본값, 아래 "9단계 튜닝 기록" 참고)
##     만큼을 예산으로 가장 싼 업그레이드 1개만 산다(UpgradeService.cheapest_affordable_id, 실제 오토
##     업그레이드(M7)와 같은 규칙 — 단, 한 스핀에 여러 레벨을 몰아 사지는 않는다. 아래 참고).
##   - 스킬트리는 사지 않는다 — 클로버 "획득량" 자체의 기준선을 재는 게 목적이라 스킬 보너스를 섞지 않는다.
## RNG 는 매 실행 GameState.reset()+RngService.set_seed() 로 초기화해 재현 가능하다.
##
## 9단계 튜닝 기록(2026-09-25, docs/PROGRESS.md 에 상세):
##   - `data/upgrades/bet_limit.tres` 의 growth 를 1.2 → 3.0 으로 고쳤다. 효과(1.35^레벨)보다 비용 증가율이
##     낮은 유일한 배율형 업그레이드라 무제한으로 폭주했다(다른 배율형은 전부 비용 증가율 > 효과, 예:
##     marble_polish 1.7 vs 1.25). GDD 5장 표도 같이 고쳤다.
##   - 이 시뮬레이터로 확인한 구조적 한계: B1→1F 는 upgrade_ratio 로 목표(30분)에 맞출 수 있었지만,
##     1F 를 넘는 순간부터 층별 payout_mult·bet_mult 도약(×10~×100, ×100~×10000)이 그때까지 쌓인 구슬
##     배율과 겹겹이 곱해져 2F~엔딩을 몇 스핀 안에 다 지나가 버린다(재현: upgrade_ratio 를 0.15~0.5 사이로
##     바꿔도 이 뒷부분 압축은 거의 그대로다 — 플레이어 행동 가정이 아니라 배율 표 자체의 구조적 결과).
##     즉 층 배율 표(GDD 7장)를 다시 설계하지 않는 한 뒤쪽 목표 시간은 이 도구만으로는 못 맞춘다.

## 업그레이드를 사고도 항상 남겨 두는 최소 칩(min_bet 의 배수) — 다음 스핀이 항상 가능하게 하는 안전 여유분.
const RESERVE_MULT := 1.0
## GDD 7장 "층/Floors" 표의 엔딩 목표(약 5시간). FloorDef.target_minutes 는 B1~PH 까지만 있어 여기 상수로 둔다.
const ENDING_TARGET_MINUTES := 300.0
## 스핀 1회당 최대 업그레이드 구매 횟수. 한 스핀의 큰 승리 직후 예산 전부를 그 자리에서 재투자해 버리면
## (재질→베팅 한도→재질→…) 층 이동 직후 배율이 겹겹이 쌓여 몇 스핀 만에 게임이 끝나 버린다(직접 실측 —
## 층 하나 지나는 데 1~2스핀도 안 걸림). 실제 플레이어(또는 오토 업그레이드)도 한 순간에 그렇게까지
## 몰아서 사지는 않는다고 보고, 스핀당 1회로 제한해 여윳돈이 다음 층 비용으로도 쌓이게 한다.
const MAX_PURCHASES_PER_SPIN := 1
## 층 이동 뒤 최소 베팅 배수만큼은 남을 때만 올라간다. 층은 bet_mult 가 즉시 확 뛰어(×100 등) 층 비용을
## 딱 맞춰 올라가면 새 층의 최소 베팅조차 못 낼 수 있다 — 그러면 check_bankruptcy() 는 스핀이 "끝나야"
## 도는데 스핀을 아예 시작 못 해 구제도 못 받는다(직접 실측으로 발견). 실제 플레이어라면 이럴 땐 비용보다
## 여유 있게 모은 뒤에 올라간다.
const FLOOR_MOVE_SAFETY_MULT := 1.5


## 한 판을 처음(B1, 칩 100)부터 엔딩(또는 max_hours 초과)까지 재생한다.
## strategy 는 GameState.SmartBettingStrategy 값(정수) — 진입 스크립트가 오토로드 열거형을 직접 못 써서 정수로 받는다.
func run(seed_value: int, upgrade_ratio: float, max_hours: float, strategy: int) -> Dictionary:
	GameState.reset()
	RngService.set_seed(seed_value)
	GameState.set_chip_size_mode(Economy.ChipSize.MAX)
	var spin_controller := SpinController.new()
	var floor_defs := GameData.floors()
	var floor_minutes: Array[float] = []
	floor_minutes.resize(floor_defs.size())
	for i in floor_defs.size():
		floor_minutes[i] = -1.0
	floor_minutes[0] = 0.0
	var ending_minutes := -1.0
	var max_seconds := max_hours * 3600.0
	while GameState.get_stat_value(GameState.STAT_PLAY_TIME) < max_seconds:
		GameState.clear_bets()
		# 구슬 수만큼 늘 다 걸면 베팅 한도가 자산보다 빨리 오를 때 "최소 베팅 1개는 되지만 N개는 안 되는"
		# 상태에서 멈춘다(is_bankrupt() 는 구슬 1개 최소 베팅 기준이라 파산 처리가 안 됨) — 실제 플레이어라면
		# 이럴 때 거는 구슬 수를 줄인다. 감당할 수 있는 만큼만 건다(최소 1개).
		var slots := GameState.marble_slots()
		var affordable_slots := clampi(int(GameState.chips / GameState.min_bet()), 1, slots)
		var bets := SmartBettingService.compute_bets(strategy, affordable_slots, [], Bet.Type.RED)
		for bet in bets:
			GameState.add_bet(bet)
		if spin_controller.start_spin() != SpinController.SpinError.OK:
			break
		GameState._process(spin_controller.active_duration)
		while FloorService.can_move() and _safe_to_move_floor():
			FloorService.move_to_next()
			if floor_minutes[GameState.floor_index] < 0.0:
				floor_minutes[GameState.floor_index] = GameState.get_stat_value(GameState.STAT_PLAY_TIME) / 60.0
		# 층 비용은 이미 감당하는데 새 층 최소 베팅 여유(_safe_to_move_floor)가 아직 안 되면, 업그레이드를
		# 더 사서 그 여유를 갉아먹지 말고 이번 스핀은 그냥 모아 둔다(다음 스핀에 다시 올라갈 수 있는지 본다).
		if not FloorService.can_move():
			_spend_on_upgrades(upgrade_ratio)
		if EndingService.can_trigger():
			EndingService.trigger()
			ending_minutes = GameState.get_stat_value(GameState.STAT_PLAY_TIME) / 60.0
			break
	var floors_report: Array[Dictionary] = []
	for i in floor_defs.size():
		var def: FloorDef = floor_defs[i]
		floors_report.append({"id": def.id, "target_minutes": def.target_minutes, "actual_minutes": floor_minutes[i]})
	return {
		"seed": seed_value,
		"spins": int(GameState.get_stat_value(GameState.STAT_TOTAL_SPINS)),
		"clovers": GameState.clovers,
		"chips": GameState.chips,
		"loans_taken": int(GameState.get_stat_value(GameState.STAT_LOANS_TAKEN)),
		"floor_index": GameState.floor_index,
		"finished": ending_minutes >= 0.0,
		"ending_minutes": ending_minutes,
		"ending_target_minutes": ENDING_TARGET_MINUTES,
		"floors": floors_report,
	}


## 층 비용을 내고도 새 층의 최소 베팅을 여유 있게(FLOOR_MOVE_SAFETY_MULT 배) 낼 수 있을 때만 올라간다.
func _safe_to_move_floor() -> bool:
	var next_def := FloorService.next_floor_def()
	if next_def == null:
		return false
	var remaining := GameState.chips - next_def.cost
	var next_max_bet := Economy.max_bet(next_def.bet_mult, GameState.get_stat(StatModifiers.MAX_BET_MULT, StatModifiers.IDENTITY_MULT))
	var next_min_bet := Economy.min_bet(next_max_bet)
	return remaining >= next_min_bet * FLOOR_MOVE_SAFETY_MULT


## 예산(보유 칩 × ratio, 항상 min_bet 은 남긴다) 안에서 가장 싼 업그레이드부터 산다(오토 업그레이드 M7과 같은 규칙).
func _spend_on_upgrades(ratio: float) -> void:
	var guard := 0
	while guard < MAX_PURCHASES_PER_SPIN:
		guard += 1
		var reserve := GameState.min_bet() * RESERVE_MULT
		var budget := minf(GameState.chips * ratio, GameState.chips - reserve)
		if budget <= 0.0:
			return
		var id := UpgradeService.cheapest_affordable_id(budget, true)
		if id == "":
			return
		var chips_before := GameState.chips
		var level_before := GameState.get_upgrade_level(id)
		UpgradeService.purchase(id, UpgradeService.BuyMode.ONE)
		# 베팅 한도(bet_limit) 업그레이드는 min_bet 자체를 즉시 올린다 — 사고 나니 최소 베팅 1개도 못 낼
		# 정도로 자산이 쪼그라들면(reserve 는 구매 "전" min_bet 기준이라 못 막는다) 되돌린다. 실제 플레이어라면
		# 안 살 구매이고, GameState.chips 를 직접 되돌리는 건 이 시뮬레이터 안에서만 쓰는 되돌리기다.
		if GameState.chips < GameState.min_bet():
			GameState.chips = chips_before
			GameState.set_upgrade_level(id, level_before)
			return
