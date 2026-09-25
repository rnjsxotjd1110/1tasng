extends "res://tests/lib/test_case.gd"
## AudioManager(8단계 3/N, 마무리에서 실제 배경음악 9곡 반입): 음악 크로스페이드·duck·피버 레이어·
## 오토 스핀 감쇠. 실제 음원 파일(assets/audio/music/*.mp3)이 이제 있으므로 "정상 재생"과 "존재하지 않는
## id 는 안전하게 무시" 둘 다 검사한다. 헤드리스에서는 AudioManager.enabled 가 false 라 실제 재생
## (player.play())에 의존하는 부분(예: play_sfx 의 volume_db)은 그때만 enabled 를 잠깐 켜서 본다.

func after_each() -> void:
	super.after_each()
	AudioManager.enabled = false
	AudioManager.stop_all()


func test_play_music_missing_file_is_safe_noop() -> void:
	AudioManager.play_music("bgm_does_not_exist")
	check_eq(AudioManager._music_id, "", "존재하지 않는 id 면 _music_id 가 바뀌지 않는다")


func test_play_music_existing_file_sets_music_id() -> void:
	AudioManager.play_music("bgm_b1")
	check_eq(AudioManager._music_id, "bgm_b1", "실제 파일이 있으면 재생 상태로 바뀐다")


func test_duck_music_sets_offset_in_headless() -> void:
	AudioManager.duck_music(-6.0, 0.1, 0.4, 0.8)
	check_eq(AudioManager._music_duck_offset_db, -6.0, "헤드리스에서도 duck 오프셋 값 자체는 즉시 반영")


func test_music_target_volume_reflects_auto_spin() -> void:
	GameState.auto_spin_enabled = false
	var base := AudioManager._music_target_volume_db()
	GameState.auto_spin_enabled = true
	var during_auto := AudioManager._music_target_volume_db()
	check_eq(base, AudioManager.MUSIC_BASE_VOLUME_DB, "기본값은 -12dB 기준")
	check_eq(during_auto, AudioManager.MUSIC_BASE_VOLUME_DB + AudioManager.AUTO_SPIN_MUSIC_ATTEN_DB,
			"오토 스핀 중에는 추가로 낮아짐")
	GameState.auto_spin_enabled = false


func test_play_sfx_common_sound_quieter_during_auto_spin() -> void:
	AudioManager.enabled = true
	GameState.auto_spin_enabled = false
	AudioManager.play_sfx("ui_click", 1.0, 0.0)
	var normal_player := _find_active_player("ui_click")
	check(normal_player != null, "일반 재생은 플레이어를 얻어야 한다")
	var normal_db := normal_player.volume_db if normal_player != null else 0.0
	if normal_player != null:
		normal_player.stop()
	GameState.auto_spin_enabled = true
	AudioManager.play_sfx("ui_click", 1.0, 0.0)
	var auto_player := _find_active_player("ui_click")
	check(auto_player != null, "오토 스핀 중 재생도 플레이어를 얻어야 한다")
	if auto_player != null:
		check_eq(auto_player.volume_db, normal_db + AudioManager.AUTO_SPIN_SFX_ATTEN_DB,
				"반복음(jitter=true)은 오토 스핀 중 추가로 낮아진다")
	GameState.auto_spin_enabled = false


func _find_active_player(id: String) -> AudioStreamPlayer:
	var actives: Array = AudioManager._active.get(id, [])
	return actives.back() if not actives.is_empty() else null


func test_set_fever_layer_activates_when_file_exists() -> void:
	AudioManager.set_fever_layer(true)
	check_eq(AudioManager._fever_active, true, "피버 레이어 음원(bgm_fever_layer)이 있으면 활성화된다")


func test_stop_all_resets_music_state() -> void:
	AudioManager.duck_music(-6.0, 0.0, 0.0, 0.0)
	AudioManager.stop_all()
	check_eq(AudioManager._music_id, "", "stop_all 뒤에는 현재 곡 id 가 비워진다")
	check_eq(AudioManager._music_duck_offset_db, 0.0, "stop_all 뒤에는 duck 오프셋도 초기화")
