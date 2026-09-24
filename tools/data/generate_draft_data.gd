extends SceneTree
## 1단계 초안 데이터(.tres)를 생성하는 1회성 스크립트.
## 이미 있는 파일은 덮어쓰지 않는다(--force 를 주면 덮어씀). 생성 후에는 .tres 가 원본이다.
## 실행: godot --headless -s tools/data/generate_draft_data.gd [-- --force]

const MARBLE_COST_START := 50.0
const MARBLE_COST_STEP := 80.0
const POLISH_BASE_RATIO := 0.5
const WOOD_POLISH_BASE := 10.0

## [id, 배율, outline, shadow, base, light, shine, fx_id]
const MARBLES: Array = [
	["wood", 1.0, "wood_d", "wood", "wood_l", "wood_hl", "ivory", ""],
	["stone", 1.5, "shadow", "ink", "stone", "mist", "ivory", ""],
	["copper", 12.0, "wood_d", "wood_l", "wood_hl", "amber", "gold_shine", "glint"],
	["iron", 100.0, "void", "night", "ink", "stone", "mist", "glint"],
	["silver", 900.0, "ink", "stone", "mist", "ivory", "ivory", "glint"],
	["gold", 8e3, "gold_d", "gold", "gold_l", "gold_hl", "gold_shine", "sparkle"],
	["jade", 7e4, "felt_d", "felt", "felt_l", "felt_hl", "mist", "sparkle"],
	["ruby", 8e5, "red_d", "red", "red_l", "red_hl", "ivory", "sparkle"],
	["sapphire", 1.2e9, "night", "water", "sky", "neon_cyan", "ivory", "sparkle"],
	["emerald", 1.5e10, "felt_d", "felt", "clover_d", "clover", "ivory", "sparkle"],
	["diamond", 2e11, "water", "sky", "mist", "ivory", "neon_cyan", "prism"],
	["obsidian", 3e12, "void", "night", "shadow", "ink", "neon_purple", "prism"],
	["starlight", 5e13, "dusk", "purple_d", "sky", "gold_hl", "gold_shine", "stars"],
	["void", 8e14, "void", "purple_d", "neon_purple", "neon_pink", "ivory", "void_swirl"],
	["cosmic", 1.5e16, "purple_d", "neon_purple", "neon_pink", "neon_cyan", "gold_shine", "cosmic_swirl"],
]

## [id, cost, payout_mult, bet_mult, clover_reward, marble_tier_cap, target_minutes]
const FLOORS: Array = [
	["b1", 0.0, 1.0, 1.0, 0, 3, 0.0],
	["1f", 1e6, 2.0, 1e2, 10, 6, 30.0],
	["2f", 1e12, 4.0, 1e4, 10, 9, 90.0],
	["3f", 1e21, 8.0, 1e6, 10, 12, 165.0],
	["ph", 1e30, 16.0, 1e8, 10, 14, 240.0],
]

## [id, base_cost, growth, max_level, stat, op, per_level, required_floor]
const UPGRADES: Array = [
	["bet_limit", 25.0, 1.55, -1, "max_bet_mult", StatModifiers.Op.MULT, 1.35, 0],
	["marble_count", 100.0, 12.0, 7, "marble_slots_bonus", StatModifiers.Op.ADD, 1.0, 0],
	["wheel_speed", 40.0, 2.2, 13, "spin_duration_mult", StatModifiers.Op.MULT, 0.9, 0],
	["golden_pocket", 5000.0, 40.0, 5, "golden_pocket_count", StatModifiers.Op.ADD, 1.0, 1],
]


func _initialize() -> void:
	var force := OS.get_cmdline_user_args().has("--force")
	var written := 0
	for tier in MARBLES.size():
		written += _save(_make_marble(tier), "res://data/marbles/marble_%02d_%s.tres" % [tier, MARBLES[tier][0]], force)
	for index in FLOORS.size():
		written += _save(_make_floor(index), "res://data/floors/floor_%d_%s.tres" % [index, FLOORS[index][0]], force)
	for row: Array in UPGRADES:
		written += _save(_make_upgrade(row), "res://data/upgrades/%s.tres" % row[0], force)
	print("generate_draft_data: %d개 파일 작성" % written)
	quit(0)


func _make_marble(tier: int) -> MarbleDef:
	var row: Array = MARBLES[tier]
	var def := MarbleDef.new()
	def.tier = tier
	def.id = row[0]
	def.name_key = "MARBLE_%s" % String(row[0]).to_upper()
	def.mult = row[1]
	def.cost = 0.0 if tier == 0 else MARBLE_COST_START * pow(MARBLE_COST_STEP, tier - 1)
	def.polish_base_cost = WOOD_POLISH_BASE if tier == 0 else def.cost * POLISH_BASE_RATIO
	def.color_outline = Palette.ALL[row[2]]
	def.color_shadow = Palette.ALL[row[3]]
	def.color_base = Palette.ALL[row[4]]
	def.color_light = Palette.ALL[row[5]]
	def.color_shine = Palette.ALL[row[6]]
	def.fx_id = row[7]
	return def


func _make_floor(index: int) -> FloorDef:
	var row: Array = FLOORS[index]
	var def := FloorDef.new()
	def.index = index
	def.id = row[0]
	def.name_key = "FLOOR_%s" % String(row[0]).to_upper()
	def.desc_key = "FLOOR_%s_DESC" % String(row[0]).to_upper()
	def.cost = row[1]
	def.payout_mult = row[2]
	def.bet_mult = row[3]
	def.clover_reward = row[4]
	def.marble_tier_cap = row[5]
	def.target_minutes = row[6]
	return def


func _make_upgrade(row: Array) -> UpgradeDef:
	var def := UpgradeDef.new()
	def.id = row[0]
	def.name_key = "UPGRADE_%s" % String(row[0]).to_upper()
	def.desc_key = "UPGRADE_%s_DESC" % String(row[0]).to_upper()
	def.base_cost = row[1]
	def.growth = row[2]
	def.max_level = row[3]
	def.effect_stat = row[4]
	def.effect_op = row[5]
	def.effect_per_level = row[6]
	def.required_floor = row[7]
	return def


func _save(resource: Resource, path: String, force: bool) -> int:
	if FileAccess.file_exists(path) and not force:
		print("  건너뜀(이미 있음): ", path)
		return 0
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("저장 실패 %s (%d)" % [path, error])
		return 0
	print("  작성: ", path)
	return 1
