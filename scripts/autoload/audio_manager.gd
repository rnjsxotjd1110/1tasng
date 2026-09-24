extends Node
## 효과음·음악 재생.
## - 버스: Master / Music / SFX / UI (res://default_bus_layout.tres, 없으면 실행 중에 만든다)
## - 효과음은 버스별 AudioStreamPlayer 풀에서 재생하고, 같은 소리의 동시 재생 수를 제한한다(가장 오래된 것을 끊음).
## - 재생할 때마다 피치를 ±PITCH_JITTER 로 흔들어 반복감을 줄인다.
## - 루프음(굴러가는 소리 등)은 play_loop/set_loop/stop_loop 로 피치·볼륨을 실시간 조절한다.
## - 화면에 추가되는 모든 BaseButton 에 호버·클릭음을 자동으로 붙인다(meta "silent_button" 이 true 면 제외).

const SFX_DIR := "res://assets/audio/sfx/"
const BUSES: Array[String] = ["Music", "SFX", "UI"]
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const POOL_SIZE: Dictionary = {"SFX": 16, "UI": 6}
const PITCH_JITTER := 0.05
const DEFAULT_MAX_INSTANCES := 3
const LOOP_FADE_SECONDS := 0.15
const SILENT_META := "silent_button"
const HOOKED_META := "audio_hooked"
const HOVER_SOUND := "ui_hover"
const CLICK_SOUND := "ui_click"

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
	_music.bus = "Music"
	add_child(_music)
	get_tree().node_added.connect(_on_node_added)


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
				if player != _music:
					player.free()
	_loops.clear()
	_active.clear()
	_streams.clear()


func _is_pooled(player: AudioStreamPlayer) -> bool:
	for pool: Array in _pools.values():
		if pool.has(player):
			return true
	return player == _music


## 8단계에서 음악 크로스페이드 구현.
func play_music(_id: String, _fade_seconds: float = 0.0) -> void:
	pass


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
