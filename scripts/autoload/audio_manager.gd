extends Node
## 효과음·음악 재생.
## - 버스: Master / Music / SFX / UI (res://default_bus_layout.tres, 없으면 실행 중에 만든다)
## - 효과음은 버스별 AudioStreamPlayer 풀에서 재생하고, 같은 소리의 동시 재생 수를 제한한다(가장 오래된 것을 끊음).
## - 재생할 때마다 피치를 ±PITCH_JITTER 로 흔들어 반복감을 줄인다.
## - 루프음(굴러가는 소리 등)은 play_loop/set_loop/stop_loop 로 피치·볼륨을 실시간 조절한다.
## - 화면에 추가되는 모든 BaseButton 에 호버·클릭음을 자동으로 붙인다(meta "silent_button" 이 true 면 제외).
## - 배경음악(play_music)은 두 AudioStreamPlayer 를 번갈아 써서 크로스페이드하고, 빅윈·파산에 duck_music() 으로
##   순간적으로 낮춘다. 오토 스핀 중에는 반복음(SFX 표의 jitter=true 항목)과 음악 모두 살짝 낮춘다(8단계 3/N,
##   GDD 20장). 음원 파일이 아직 없는 id 는 경고만 남기고 조용히 무시한다(이후 파일이 생기면 그대로 동작).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const BUSES: Array[String] = ["Music", "SFX", "UI"]
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_MUSIC := "Music"
const POOL_SIZE: Dictionary = {"SFX": 16, "UI": 6}
const PITCH_JITTER := 0.05
const DEFAULT_MAX_INSTANCES := 3
const LOOP_FADE_SECONDS := 0.15
const SILENT_META := "silent_button"
const HOOKED_META := "audio_hooked"
const HOVER_SOUND := "ui_hover"
const CLICK_SOUND := "ui_click"

## 음악 믹싱(GDD 20장): 기준 볼륨 -12dB, 빅윈/파산 duck, 오토 스핀 중 은은한 감쇠.
const MUSIC_BASE_VOLUME_DB := -12.0
const MUSIC_CROSSFADE_DEFAULT := 1.5
const MUSIC_SILENCE_DB := -80.0
const MUSIC_DUCK_BIG_WIN_DB := -6.0
const MUSIC_DUCK_BIG_WIN_ATTACK := 0.1
const MUSIC_DUCK_BIG_WIN_HOLD := 0.4
const MUSIC_DUCK_BIG_WIN_RELEASE := 0.8
const MUSIC_DUCK_BANKRUPT_DB := -14.0
const MUSIC_DUCK_BANKRUPT_ATTACK := 0.2
const MUSIC_DUCK_BANKRUPT_HOLD := 1.6
const MUSIC_DUCK_BANKRUPT_RELEASE := 1.2
const FEVER_LAYER_ID := "bgm_fever_layer"
const FEVER_FADE_SECONDS := 0.6
const FEVER_LAYER_VOLUME_DB := -14.0
const AUTO_SPIN_SFX_ATTEN_DB := -4.0
const AUTO_SPIN_MUSIC_ATTEN_DB := -3.0

## id → {bus, volume_db, max(동시 재생 수), jitter(피치 흔들기 여부)}
const SFX: Dictionary = {
	"ui_hover": {"bus": "UI", "volume_db": -8.0, "max": 2},
	"ui_click": {"bus": "UI", "volume_db": -4.0, "max": 2},
	"panel_open": {"bus": "UI", "volume_db": -6.0, "max": 1},
	"panel_close": {"bus": "UI", "volume_db": -6.0, "max": 1},
	"marble_place": {"bus": "SFX", "volume_db": -3.0, "max": 4},
	"marble_remove": {"bus": "SFX", "volume_db": -4.0, "max": 3},
	"spin_start": {"bus": "SFX", "volume_db": -2.0, "max": 1},
	"ball_roll_loop": {"bus": "SFX", "volume_db": -6.0, "max": 1},
	"deflector_hit": {"bus": "SFX", "volume_db": -3.0, "max": 3},
	"pocket_land": {"bus": "SFX", "volume_db": -1.0, "max": 3},
	"chip_click": {"bus": "SFX", "volume_db": -7.0, "max": 5},
	"win_normal": {"bus": "SFX", "volume_db": -3.0, "max": 1},
	"win_good": {"bus": "SFX", "volume_db": -2.0, "max": 1},
	"win_big": {"bus": "SFX", "volume_db": 0.0, "max": 1, "jitter": false},
	"win_jackpot": {"bus": "SFX", "volume_db": 0.0, "max": 1, "jitter": false},
	"lose": {"bus": "SFX", "volume_db": -8.0, "max": 1},
	"near_miss": {"bus": "SFX", "volume_db": -5.0, "max": 1},
	"deny": {"bus": "UI", "volume_db": -4.0, "max": 1},
	"clover_get": {"bus": "SFX", "volume_db": -3.0, "max": 2},
	"neon_flicker": {"bus": "SFX", "volume_db": -10.0, "max": 2},
	"coin_drop": {"bus": "SFX", "volume_db": -9.0, "max": 4},
	"buy_coin": {"bus": "UI", "volume_db": -5.0, "max": 3, "jitter": false},
	"slot_open": {"bus": "SFX", "volume_db": -3.0, "max": 2},
	"marble_roll": {"bus": "SFX", "volume_db": -6.0, "max": 2},
	"golden_beam": {"bus": "SFX", "volume_db": -3.0, "max": 2},
	"promote_charge": {"bus": "SFX", "volume_db": -4.0, "max": 1, "jitter": false},
	"promote_flash": {"bus": "SFX", "volume_db": -2.0, "max": 1, "jitter": false},
	"promote_jingle_1": {"bus": "SFX", "volume_db": -2.0, "max": 1, "jitter": false},
	"promote_jingle_2": {"bus": "SFX", "volume_db": -1.0, "max": 1, "jitter": false},
	"promote_jingle_3": {"bus": "SFX", "volume_db": 0.0, "max": 1, "jitter": false},
	"dialogue_blip_baron": {"bus": "UI", "volume_db": -10.0, "max": 4, "jitter": false},
	"baron_footstep": {"bus": "SFX", "volume_db": -6.0, "max": 2},
	"baron_cane_tap": {"bus": "SFX", "volume_db": -5.0, "max": 2},
	"bass_drop": {"bus": "SFX", "volume_db": -2.0, "max": 1, "jitter": false},
	"contract_unroll": {"bus": "SFX", "volume_db": -4.0, "max": 1},
	"quill_sign": {"bus": "SFX", "volume_db": -5.0, "max": 1},
	"stamp_thud": {"bus": "SFX", "volume_db": -2.0, "max": 1, "jitter": false},
	"chip_bag_toss": {"bus": "SFX", "volume_db": -3.0, "max": 1},
	"pickpocket_squeak": {"bus": "SFX", "volume_db": -4.0, "max": 2},
	# 6단계: 스킬트리·자동화·특수 기능
	"dialogue_blip_lucy": {"bus": "UI", "volume_db": -10.0, "max": 4, "jitter": false},
	"dialogue_blip_velvet": {"bus": "UI", "volume_db": -10.0, "max": 4, "jitter": false},
	"lock_break": {"bus": "SFX", "volume_db": -2.0, "max": 1, "jitter": false},
	"fever_start": {"bus": "SFX", "volume_db": 0.0, "max": 1, "jitter": false},
	"fever_end": {"bus": "SFX", "volume_db": -4.0, "max": 1, "jitter": false},
	"piggy_break": {"bus": "SFX", "volume_db": -2.0, "max": 1, "jitter": false},
	"wof_appear": {"bus": "SFX", "volume_db": -2.0, "max": 1, "jitter": false},
	"wof_tick": {"bus": "UI", "volume_db": -8.0, "max": 2},
	"wof_land": {"bus": "SFX", "volume_db": -2.0, "max": 1, "jitter": false},
	"destiny_flip": {"bus": "SFX", "volume_db": -3.0, "max": 1},
	# 7단계: 업적
	"achievement_unlock": {"bus": "SFX", "volume_db": -2.0, "max": 1, "jitter": false},
}

## 헤드리스(테스트·서버)에서는 소리를 내지 않는다(출력 장치가 없고, 종료 시 재생 객체가 남는다).
var enabled: bool = DisplayServer.get_name() != "headless"
var _streams: Dictionary = {}
var _pools: Dictionary = {}
## id → 재생 중인 플레이어 목록(오래된 것부터)
var _active: Dictionary = {}
## 루프 id → 플레이어
var _loops: Dictionary = {}
var _music: AudioStreamPlayer
## 크로스페이드용 두 번째 음악 플레이어(둘을 번갈아 "현재"로 쓴다).
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _music_id: String = ""
var _music_duck_offset_db: float = 0.0
var _fever_player: AudioStreamPlayer
var _fever_active: bool = false
var _prev_auto_spin: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for bus: String in POOL_SIZE.keys():
		var pool: Array[AudioStreamPlayer] = []
		for i in int(POOL_SIZE[bus]):
			var player := AudioStreamPlayer.new()
			player.bus = bus
			add_child(player)
			pool.append(player)
		_pools[bus] = pool
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	add_child(_music)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = BUS_MUSIC
	add_child(_music_b)
	_music_current = _music
	_fever_player = AudioStreamPlayer.new()
	_fever_player.bus = BUS_MUSIC
	_fever_player.volume_db = MUSIC_SILENCE_DB
	add_child(_fever_player)
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	var auto_spin := GameState.auto_spin_enabled
	if auto_spin != _prev_auto_spin:
		_prev_auto_spin = auto_spin
		_refresh_music_volume()


# ── 효과음 ───────────────────────────────────────────────

## 효과음 재생. pitch 는 기본 피치(흔들기 전), volume_offset_db 는 표의 볼륨에 더한다.
func play_sfx(id: String, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not enabled:
		return
	var stream := _stream(id)
	if stream == null:
		return
	var info: Dictionary = SFX.get(id, {})
	var bus := String(info.get("bus", BUS_SFX))
	var player := _free_player(bus)
	if player == null:
		return
	var actives: Array = _active.get(id, [])
	actives = actives.filter(func(p: AudioStreamPlayer) -> bool: return p.playing and p.stream == stream)
	var max_count := int(info.get("max", DEFAULT_MAX_INSTANCES))
	while actives.size() >= max_count:
		var oldest: AudioStreamPlayer = actives.pop_front()
		oldest.stop()
	if bool(info.get("jitter", true)):
		pitch *= 1.0 + RngService.randf_range_misc(-PITCH_JITTER, PITCH_JITTER)
		if GameState.auto_spin_enabled:
			volume_offset_db += AUTO_SPIN_SFX_ATTEN_DB
	player.stream = stream
	player.pitch_scale = maxf(pitch, 0.01)
	player.volume_db = float(info.get("volume_db", 0.0)) + volume_offset_db
	player.play()
	actives.append(player)
	_active[id] = actives


## 루프음 시작(이미 재생 중이면 그대로).
func play_loop(id: String, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not enabled:
		return
	if _loops.has(id):
		set_loop(id, pitch, volume_offset_db)
		return
	var stream := _stream(id)
	if stream == null:
		return
	var info: Dictionary = SFX.get(id, {})
	var player := AudioStreamPlayer.new()
	player.bus = String(info.get("bus", BUS_SFX))
	player.stream = stream
	add_child(player)
	_loops[id] = player
	set_loop(id, pitch, volume_offset_db)
	player.play()


func set_loop(id: String, pitch: float, volume_offset_db: float = 0.0) -> void:
	var player: AudioStreamPlayer = _loops.get(id, null)
	if player == null:
		return
	var info: Dictionary = SFX.get(id, {})
	player.pitch_scale = maxf(pitch, 0.01)
	player.volume_db = float(info.get("volume_db", 0.0)) + volume_offset_db


func stop_loop(id: String) -> void:
	var player: AudioStreamPlayer = _loops.get(id, null)
	if player == null:
		return
	_loops.erase(id)
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -60.0, LOOP_FADE_SECONDS)
	tween.tween_callback(player.queue_free)


func is_loop_playing(id: String) -> bool:
	return _loops.has(id)


## 모든 소리를 멈춘다(종료 직전·장면 전환). 캐시도 비워 종료 시 리소스가 남지 않게 한다.
func stop_all() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			var player := child as AudioStreamPlayer
			player.stop()
			player.stream = null
			if _loops.values().has(player) or not _is_pooled(player):
				if player != _music and player != _music_b and player != _fever_player:
					player.free()
	_loops.clear()
	_active.clear()
	_streams.clear()
	_music_id = ""
	_music_current = _music
	_music_duck_offset_db = 0.0
	_fever_active = false


func _is_pooled(player: AudioStreamPlayer) -> bool:
	for pool: Array in _pools.values():
		if pool.has(player):
			return true
	return player == _music or player == _music_b or player == _fever_player


## 배경음악을 크로스페이드로 바꾼다(GDD 20장). 이미 같은 곡이 재생 중이면 아무것도 하지 않는다.
## 음원 파일(res://assets/audio/music/<id>.ogg)이 아직 없으면 경고만 남기고 현재 곡을 그대로 둔다.
func play_music(id: String, fade_seconds: float = MUSIC_CROSSFADE_DEFAULT) -> void:
	if id == _music_id and _music_current.playing:
		return
	var stream := _music_stream(id)
	if stream == null:
		return
	var outgoing := _music_current
	var incoming := _music_b if _music_current == _music else _music
	incoming.stream = stream
	incoming.volume_db = MUSIC_SILENCE_DB
	incoming.play()
	_music_current = incoming
	_music_id = id
	if enabled and outgoing.playing:
		var out_tween := create_tween()
		out_tween.tween_property(outgoing, "volume_db", MUSIC_SILENCE_DB, fade_seconds)
		out_tween.tween_callback(outgoing.stop)
	else:
		outgoing.stop()
	if enabled:
		var in_tween := create_tween()
		in_tween.tween_property(incoming, "volume_db", _music_target_volume_db(), fade_seconds)
	else:
		incoming.volume_db = _music_target_volume_db()


## 빅윈·파산 등 극적인 순간에 음악을 잠깐 낮췄다가 되돌린다.
func duck_music(amount_db: float, attack: float, hold: float, release: float) -> void:
	if not enabled:
		# 헤드리스 테스트: 트윈이 실제로 흐르지 않으므로(엔진 프레임 없음) 즉시 낮춘 상태로만 반영해
		# _music_duck_offset_db 자체는 확인할 수 있게 한다. 복귀(release)는 실제 재생 환경에서만 의미가 있다.
		_set_duck_offset(amount_db)
		return
	var tween := create_tween()
	tween.tween_method(_set_duck_offset, _music_duck_offset_db, amount_db, attack)
	tween.tween_interval(hold)
	tween.tween_method(_set_duck_offset, amount_db, 0.0, release)


func _set_duck_offset(value: float) -> void:
	_music_duck_offset_db = value
	_refresh_music_volume()


## 피버(6단계 F 계열) 동안 층 BGM 위에 겹치는 두 번째 음악 레이어. 음원이 없으면 조용히 무시.
func set_fever_layer(active: bool) -> void:
	if active == _fever_active:
		return
	_fever_active = active
	if active:
		var stream := _music_stream(FEVER_LAYER_ID)
		if stream == null:
			_fever_active = false
			return
		_fever_player.stream = stream
		_fever_player.volume_db = MUSIC_SILENCE_DB
		_fever_player.play()
		if enabled:
			var tween := create_tween()
			tween.tween_property(_fever_player, "volume_db", FEVER_LAYER_VOLUME_DB, FEVER_FADE_SECONDS)
		else:
			_fever_player.volume_db = FEVER_LAYER_VOLUME_DB
	else:
		if enabled:
			var tween := create_tween()
			tween.tween_property(_fever_player, "volume_db", MUSIC_SILENCE_DB, FEVER_FADE_SECONDS)
			tween.tween_callback(_fever_player.stop)
		else:
			_fever_player.stop()


func _music_target_volume_db() -> float:
	var v := MUSIC_BASE_VOLUME_DB + _music_duck_offset_db
	if GameState.auto_spin_enabled:
		v += AUTO_SPIN_MUSIC_ATTEN_DB
	return v


func _refresh_music_volume() -> void:
	if _music_current != null and _music_current.playing:
		_music_current.volume_db = _music_target_volume_db()


## 압축 포맷(.ogg)을 먼저 찾고, 없으면 .mp3(승인된 CC0 후보의 원본 배포 포맷)나 .wav(임시 자리표시자)로 대체한다.
func _music_stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	for ext: String in [".ogg", ".mp3", ".wav"]:
		var path: String = MUSIC_DIR + id + ext
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			_streams[id] = stream
			return stream
	push_warning("AudioManager: 없는 음악 '%s'(%s*.ogg/.mp3/.wav) — 음원 추가 전까지 무시" % [id, MUSIC_DIR + id])
	_streams[id] = null
	return null


## 버스 볼륨(0~1 선형). 4단계 설정 화면이 쓴다.
func set_bus_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))


func has_sfx(id: String) -> bool:
	return _stream(id) != null


# ── 내부 ─────────────────────────────────────────────────

func _stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := SFX_DIR + id + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: 없는 효과음 '%s'" % id)
		_streams[id] = null
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV and id.ends_with("_loop"):
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
	_streams[id] = stream
	return stream


func _free_player(bus: String) -> AudioStreamPlayer:
	var pool: Array[AudioStreamPlayer] = []
	pool.assign(_pools.get(bus, _pools.get(BUS_SFX, [])))
	if pool.is_empty():
		return null
	for player in pool:
		if not player.playing:
			return player
	# 모두 재생 중이면 가장 먼저 시작한 것(재생 위치가 가장 뒤)을 빼앗는다.
	var oldest := pool[0]
	for player in pool:
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	oldest.stop()
	return oldest


func _ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(HOOKED_META):
		var button := node as BaseButton
		button.set_meta(HOOKED_META, true)
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_hover(button: BaseButton) -> void:
	if button.disabled or bool(button.get_meta(SILENT_META, false)):
		return
	play_sfx(HOVER_SOUND)


func _on_button_pressed(button: BaseButton) -> void:
	if bool(button.get_meta(SILENT_META, false)):
		return
	play_sfx(CLICK_SOUND)
