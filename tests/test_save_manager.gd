extends "res://tests/lib/test_case.gd"
## SaveManager: 왕복 보존, 손상 복구(.bak), 체크섬 불일치 감지, 마이그레이션 틀, 스핀 도중 저장 정산.

## before_each() 의 저장 파일 정리는 test_case.gd 공용(_clear_save_files, Main._ready() 가 불러오기를
## 하므로 다른 테스트가 남긴 저장 파일이 섞이지 않게 방어).

func after_each() -> void:
	super.after_each()
	_clear_save_files()


func _fill_varied_state() -> void:
	GameState.add_chips(12345.0)
	GameState.add_clovers(7)
	GameState.floor_index = 2
	GameState.set_upgrade_level("bet_limit", 3)
	GameState.set_upgrade_level("marble_tier", 2)
	GameState.set_upgrade_level("marble_count", 1)
	GameState.add_bet(Bet.red())
	GameState.add_bet(Bet.straight(17))
	GameState.last_bets = [Bet.new(Bet.Type.BLACK, Bet.NO_NUMBER, 5.0)]
	GameState.chip_size_mode = Economy.ChipSize.HALF
	GameState.debts = [{"principal": 100.0, "remaining": 80.0}]
	GameState.win_streak = 4
	GameState.result_history = [1, 2, 3, 0, 36]
	GameState.golden_pockets = [5, 11]
	GameState.highest_milestone = 2
	GameState.increment_stat(GameState.STAT_TOTAL_SPINS, 9.0)
	GameState.max_stat(GameState.STAT_BIGGEST_WIN, 999.0)
	GameState.increment_stat(GameState.STAT_LOANS_TAKEN, 1.0)
	GameState.add_buff("test_penalty", StatModifiers.MARBLE_MULT, StatModifiers.Op.MULT, 0.9, 45.0)


func test_round_trip_preserves_fields() -> void:
	_fill_varied_state()
	var before := GameState.to_dict()
	check(SaveManager.save_game(), "저장 성공")
	GameState.reset()
	check(SaveManager.load_game(), "불러오기 성공(GameState.rebuild_upgrade_modifiers 까지 내부에서 호출됨)")
	var after := GameState.to_dict()
	for key in ["chips", "clovers", "floor_index", "upgrade_levels", "chip_size_mode", "debts",
			"win_streak", "result_history", "golden_pockets", "highest_milestone"]:
		check_eq(after[key], before[key], "필드 동일: %s" % key)
	check_eq(after["current_bets"], before["current_bets"], "current_bets 동일")
	check_eq(after["last_bets"], before["last_bets"], "last_bets 동일")
	check_eq(GameState.get_stat_value(GameState.STAT_TOTAL_SPINS), 9.0, "통계 보존")
	check_eq(GameState.get_stat_value(GameState.STAT_BIGGEST_WIN), 999.0, "통계 보존2")
	check(GameState.modifiers.remaining_time("buff:test_penalty") > 40.0, "버프 남은 시간 보존")
	check_rel(GameState.marble_mult(), 12.0 * 0.9, 1e-6, "재질 수정자 재구성(구리 ×12) × 복원된 버프(×0.9) 반영")


func test_huge_float_survives_round_trip() -> void:
	GameState.spend_chips(GameState.chips)
	GameState.add_chips(1e300, false)
	check(SaveManager.save_game(), "큰 값 저장")
	var saved_chips := GameState.chips
	GameState.reset()
	check(SaveManager.load_game(), "큰 값 불러오기")
	check_rel(GameState.chips, saved_chips, 1e-9, "1e300 급 값이 상대오차 1e-9 이내로 보존(표시 정밀도 3자리에는 영향 없음)")


func test_corrupted_save_recovers_from_backup() -> void:
	_fill_varied_state()
	GameState.floor_index = 1
	check(SaveManager.save_game(), "첫 저장(→ 이후 .bak)")
	GameState.floor_index = 3
	check(SaveManager.save_game(), "두 번째 저장")
	check(FileAccess.file_exists(SaveManager.BAK_PATH), "백업 파일 존재")
	print("    (다음 JSON 파싱 에러 로그 1줄은 손상 파일 복구 테스트의 정상 출력)")
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("이것은 손상된 저장 파일입니다 { 깨짐")
	file.close()
	GameState.reset()
	check(SaveManager.load_game(), "손상돼도 백업으로 복구")
	check(SaveManager.last_load_recovered_from_backup, "백업 복구 플래그")
	check_eq(GameState.floor_index, 1, "백업(첫 저장) 상태로 복구")


func test_checksum_mismatch_is_rejected() -> void:
	_fill_varied_state()
	check(SaveManager.save_game(), "저장")
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	var payload: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	payload["checksum"] = "0".repeat(64)
	var out := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify(payload))
	out.close()
	print("    (다음 경고 로그 1줄은 체크섬 불일치 감지 테스트의 정상 출력)")
	GameState.reset()
	var ok := SaveManager.load_game()
	check(not ok, "백업이 없으면 체크섬 불일치 저장은 거부된다")
	check_eq(GameState.clovers, 0, "거부된 저장이 반영되지 않고 초기값 유지")


func test_no_save_file_load_fails_silently() -> void:
	check(not SaveManager.has_save(), "저장 파일 없음")
	check(not SaveManager.load_game(), "불러오기 실패(정상)")
	check(not SaveManager.last_load_recovered_from_backup, "복구 플래그 false")


func test_migration_skeleton_is_noop_at_current_version() -> void:
	var data := {"chips": 123.0}
	var result := SaveManager._migrate(data, SaveManager.SAVE_VERSION)
	check_eq(result, data, "현재 버전이면 그대로")


func test_migration_skeleton_warns_on_newer_version() -> void:
	print("    (다음 경고 로그 1줄은 미래 버전 저장 파일 방어 테스트의 정상 출력)")
	var data := {"chips": 5.0}
	var result := SaveManager._migrate(data, SaveManager.SAVE_VERSION + 1)
	check_eq(result, data, "더 새 버전이어도 데이터는 그대로 돌려줌(크래시 방지)")


func test_pending_spin_settles_instantly_after_load() -> void:
	GameState.add_bet(Bet.red())
	var controller := SpinController.new()
	controller.instant_resolve = false
	RngService.force_next([1])
	controller.start_spin()
	check(GameState.spin_in_progress, "스핀 도중")
	check(not GameState.pending_spin_bets.is_empty(), "스냅샷 채워짐")
	check(SaveManager.save_game(), "스핀 도중 저장")
	var chips_before_settle := GameState.chips
	GameState.reset()
	check(SaveManager.load_game(), "불러오기")
	check(GameState.spin_in_progress, "불러온 직후엔 아직 진행중 플래그")
	var settle_controller := SpinController.new()
	var outcome := settle_controller.settle_pending_spin()
	check(outcome != null, "즉시 정산됨")
	check(not GameState.spin_in_progress, "정산 후 진행중 아님")
	check(GameState.pending_spin_bets.is_empty(), "스냅샷 비워짐")
	check(GameState.chips > chips_before_settle or outcome.total_return == 0.0, "정산 결과가 칩에 반영")
