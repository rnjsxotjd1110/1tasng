extends Node
## 설정(user://settings.cfg, ConfigFile). 세이브(user://save.json)와 완전히 별도 파일.
## 설정 화면은 이 오토로드의 필드를 직접 바꾼 뒤 commit() 을 불러 "즉시 적용 + 저장"한다.

const SETTINGS_PATH := "user://settings.cfg"
const WINDOW_SCALES: Array[int] = [2, 3, 4]
const BASE_WINDOW_SIZE := Vector2i(640, 360)
## 0 = 무제한.
const MAX_FPS_OPTIONS: Array[int] = [30, 60, 120, 0]
## 창이 최소화·비활성 상태일 때(8단계 4/N, GDD 20장): 배터리·CPU 절약을 위해 프레임을 크게 줄인다.
const BACKGROUND_FPS := 10

enum SpinVisualSpeed { NORMAL, FAST, FASTEST }
const SPIN_SPEED_MULT: Dictionary = {SpinVisualSpeed.NORMAL: 1.0, SpinVisualSpeed.FAST: 1.5, SpinVisualSpeed.FASTEST: 2.0}

# ── 오디오 ───────────────────────────────────────────────
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 1.0

# ── 화면 ─────────────────────────────────────────────────
var fullscreen: bool = false
var window_scale: int = 3
var vsync: bool = true
## MAX_FPS_OPTIONS 중 하나(0 = 무제한).
var max_fps: int = 60

# ── 게임 ─────────────────────────────────────────────────
var language: String = "ko"
var scientific_notation: bool = false
var spin_visual_speed: SpinVisualSpeed = SpinVisualSpeed.NORMAL
var big_win_effect_full: bool = true
## 오토 스핀 중에는 BIG 이상만 연출(GDD).
var auto_spin_effects_reduced: bool = true
## 루시 튜토리얼(8단계 2/N)을 보여줄지. 꺼도 GameState.tutorial_step 은 그대로 유지된다(다시 켜면 이어서 진행).
var tutorial_enabled: bool = true

# ── 접근성 ───────────────────────────────────────────────
var screen_shake: bool = true
var reduce_flashing: bool = false
var colorblind_assist: bool = false
var tooltip_delay: float = 0.3

# ── 일시정지 메뉴 옵션(설정 탭에는 없지만 재실행해도 기억한다) ──
var pause_time_flows: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


## 코드상의 기본값으로 되돌린다(파일은 만지지 않음). 테스트가 서로 오염되지 않게 쓴다.
func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 1.0
	ui_volume = 1.0
	fullscreen = false
	window_scale = 3
	vsync = true
	max_fps = 60
	language = "ko"
	scientific_notation = false
	spin_visual_speed = SpinVisualSpeed.NORMAL
	big_win_effect_full = true
	auto_spin_effects_reduced = true
	tutorial_enabled = true
	screen_shake = true
	reduce_flashing = false
	colorblind_assist = false
	tooltip_delay = 0.3
	pause_time_flows = true


func has_settings_file() -> bool:
	return FileAccess.file_exists(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	ui_volume = clampf(float(cfg.get_value("audio", "ui", ui_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("screen", "fullscreen", fullscreen))
	window_scale = int(cfg.get_value("screen", "window_scale", window_scale))
	vsync = bool(cfg.get_value("screen", "vsync", vsync))
	max_fps = int(cfg.get_value("screen", "max_fps", max_fps))
	language = String(cfg.get_value("game", "language", language))
	scientific_notation = bool(cfg.get_value("game", "scientific_notation", scientific_notation))
	spin_visual_speed = clampi(int(cfg.get_value("game", "spin_visual_speed", spin_visual_speed)), 0, SpinVisualSpeed.FASTEST) as SpinVisualSpeed
	big_win_effect_full = bool(cfg.get_value("game", "big_win_effect_full", big_win_effect_full))
	auto_spin_effects_reduced = bool(cfg.get_value("game", "auto_spin_effects_reduced", auto_spin_effects_reduced))
	tutorial_enabled = bool(cfg.get_value("game", "tutorial_enabled", tutorial_enabled))
	screen_shake = bool(cfg.get_value("accessibility", "screen_shake", screen_shake))
	reduce_flashing = bool(cfg.get_value("accessibility", "reduce_flashing", reduce_flashing))
	colorblind_assist = bool(cfg.get_value("accessibility", "colorblind_assist", colorblind_assist))
	tooltip_delay = float(cfg.get_value("accessibility", "tooltip_delay", tooltip_delay))
	pause_time_flows = bool(cfg.get_value("pause", "time_flows", pause_time_flows))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ui", ui_volume)
	cfg.set_value("screen", "fullscreen", fullscreen)
	cfg.set_value("screen", "window_scale", window_scale)
	cfg.set_value("screen", "vsync", vsync)
	cfg.set_value("screen", "max_fps", max_fps)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "scientific_notation", scientific_notation)
	cfg.set_value("game", "spin_visual_speed", int(spin_visual_speed))
	cfg.set_value("game", "big_win_effect_full", big_win_effect_full)
	cfg.set_value("game", "auto_spin_effects_reduced", auto_spin_effects_reduced)
	cfg.set_value("game", "tutorial_enabled", tutorial_enabled)
	cfg.set_value("accessibility", "screen_shake", screen_shake)
	cfg.set_value("accessibility", "reduce_flashing", reduce_flashing)
	cfg.set_value("accessibility", "colorblind_assist", colorblind_assist)
	cfg.set_value("accessibility", "tooltip_delay", tooltip_delay)
	cfg.set_value("pause", "time_flows", pause_time_flows)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager.save_settings: 저장 실패 (%s)" % error_string(err))


## 현재 필드 값을 실제 시스템(오디오 버스·화면·언어·VisualSettings·NumberFormat)에 반영한다.
func apply_all() -> void:
	AudioManager.set_bus_volume("Master", master_volume)
	AudioManager.set_bus_volume("Music", music_volume)
	AudioManager.set_bus_volume("SFX", sfx_volume)
	AudioManager.set_bus_volume("UI", ui_volume)
	TranslationServer.set_locale(language)
	NumberFormat.scientific_mode = scientific_notation
	VisualSettings.screen_shake = screen_shake
	VisualSettings.reduce_flashing = reduce_flashing
	VisualSettings.colorblind_assist = colorblind_assist
	VisualSettings.big_win_effect_full = big_win_effect_full
	VisualSettings.auto_spin_effects_reduced = auto_spin_effects_reduced
	VisualSettings.tooltip_delay = tooltip_delay
	_apply_display()


## 설정 화면이 필드를 직접 바꾼 뒤 호출: 즉시 적용 + 저장.
func commit() -> void:
	apply_all()
	save_settings()


func spin_visual_speed_mult() -> float:
	return float(SPIN_SPEED_MULT.get(spin_visual_speed, 1.0))


## window_scale 후보 중 모니터에 들어가는 것만.
func available_window_scales() -> Array[int]:
	var screen_size := DisplayServer.screen_get_size()
	var out: Array[int] = []
	for scale in WINDOW_SCALES:
		if BASE_WINDOW_SIZE.x * scale <= screen_size.x and BASE_WINDOW_SIZE.y * scale <= screen_size.y:
			out.append(scale)
	if out.is_empty():
		out.append(WINDOW_SCALES[0])
	return out


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		DisplayServer.window_set_size(BASE_WINDOW_SIZE * window_scale)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if not _backgrounded:
		Engine.max_fps = max_fps


## 창이 최소화되거나(포커스를 잃어도 같은 신호) 배경으로 밀려나면 BACKGROUND_FPS 로, 돌아오면
## 설정값으로 복귀한다. 헤드리스(테스트)에는 창이 없어 이 알림이 오지 않는다.
var _backgrounded: bool = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_backgrounded = true
			Engine.max_fps = BACKGROUND_FPS
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_backgrounded = false
			Engine.max_fps = max_fps
