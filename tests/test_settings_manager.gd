extends "res://tests/lib/test_case.gd"
## SettingsManager: 저장(save.json)과 별도 파일, 기본값, 적용·저장 왕복, 화면 배율 필터, 연출 속도 배율.

func before_each() -> void:
	super.before_each()
	if FileAccess.file_exists(SettingsManager.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsManager.SETTINGS_PATH)


func after_each() -> void:
	super.after_each()
	if FileAccess.file_exists(SettingsManager.SETTINGS_PATH):
		DirAccess.remove_absolute(SettingsManager.SETTINGS_PATH)
	SettingsManager.reset_to_defaults()
	TranslationServer.set_locale("ko")
	SettingsManager.apply_all()


func test_defaults_when_no_file() -> void:
	SettingsManager.load_settings()
	check_eq(SettingsManager.master_volume, 1.0, "마스터 볼륨 기본값")
	check_eq(SettingsManager.language, "ko", "언어 기본값")
	check_eq(SettingsManager.window_scale, 3, "창 배율 기본값")
	check(SettingsManager.vsync, "VSync 기본 켜짐")


func test_save_and_load_round_trip() -> void:
	SettingsManager.master_volume = 0.4
	SettingsManager.music_volume = 0.2
	SettingsManager.fullscreen = true
	SettingsManager.window_scale = 2
	SettingsManager.max_fps = 30
	SettingsManager.language = "en"
	SettingsManager.scientific_notation = true
	SettingsManager.spin_visual_speed = SettingsManager.SpinVisualSpeed.FAST
	SettingsManager.colorblind_assist = true
	SettingsManager.tooltip_delay = 0.6
	SettingsManager.save_settings()
	# 필드를 흩트린 뒤 다시 읽어 전부 돌아오는지 확인.
	SettingsManager.master_volume = 1.0
	SettingsManager.language = "ko"
	SettingsManager.load_settings()
	check_eq(SettingsManager.master_volume, 0.4, "마스터 볼륨 왕복")
	check_eq(SettingsManager.music_volume, 0.2, "음악 볼륨 왕복")
	check_eq(SettingsManager.fullscreen, true, "전체화면 왕복")
	check_eq(SettingsManager.window_scale, 2, "창 배율 왕복")
	check_eq(SettingsManager.max_fps, 30, "최대 FPS 왕복")
	check_eq(SettingsManager.language, "en", "언어 왕복")
	check_eq(SettingsManager.scientific_notation, true, "과학적 표기 왕복")
	check_eq(SettingsManager.spin_visual_speed, SettingsManager.SpinVisualSpeed.FAST, "스핀 속도 왕복")
	check_eq(SettingsManager.colorblind_assist, true, "색약 보조 왕복")
	check_eq(SettingsManager.tooltip_delay, 0.6, "툴팁 지연 왕복")


func test_commit_applies_and_saves() -> void:
	SettingsManager.language = "en"
	SettingsManager.commit()
	check_eq(TranslationServer.get_locale(), "en", "commit 이 즉시 locale 을 바꿈")
	check(FileAccess.file_exists(SettingsManager.SETTINGS_PATH), "commit 이 파일에도 저장")
	SettingsManager.language = "ko"
	SettingsManager.load_settings()
	check_eq(SettingsManager.language, "en", "저장된 값 확인")


func test_available_window_scales_excludes_too_large() -> void:
	var scales := SettingsManager.available_window_scales()
	check(not scales.is_empty(), "최소 하나는 항상 있음")
	for scale in scales:
		check(SettingsManager.WINDOW_SCALES.has(scale), "후보 중 하나")


func test_spin_visual_speed_mult() -> void:
	check_eq(SettingsManager.SPIN_SPEED_MULT[SettingsManager.SpinVisualSpeed.NORMAL], 1.0, "보통 ×1")
	SettingsManager.spin_visual_speed = SettingsManager.SpinVisualSpeed.FASTEST
	check_eq(SettingsManager.spin_visual_speed_mult(), 2.0, "최고속 ×2")
	SettingsManager.spin_visual_speed = SettingsManager.SpinVisualSpeed.NORMAL


func test_background_focus_reduces_and_restores_fps() -> void:
	SettingsManager.max_fps = 60
	SettingsManager._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check_eq(Engine.max_fps, SettingsManager.BACKGROUND_FPS, "창이 배경으로 가면 프레임을 크게 줄인다(최소화 포함)")
	SettingsManager._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check_eq(Engine.max_fps, 60, "다시 포커스를 받으면 설정값으로 복귀")


func test_visual_settings_full_effects() -> void:
	VisualSettings.big_win_effect_full = true
	VisualSettings.auto_spin_effects_reduced = true
	check(VisualSettings.full_effects(SpinOutcome.Tier.BIG, false), "일반 플레이는 항상 전체 연출")
	check(not VisualSettings.full_effects(SpinOutcome.Tier.NORMAL, true), "오토 스핀 중 NORMAL 은 간략")
	check(VisualSettings.full_effects(SpinOutcome.Tier.BIG, true), "오토 스핀 중이어도 BIG 이상은 전체")
	VisualSettings.big_win_effect_full = false
	check(not VisualSettings.full_effects(SpinOutcome.Tier.JACKPOT, false), "큰 당첨 연출 간략 설정이면 JACKPOT 도 간략")
	VisualSettings.big_win_effect_full = true
	VisualSettings.auto_spin_effects_reduced = true
