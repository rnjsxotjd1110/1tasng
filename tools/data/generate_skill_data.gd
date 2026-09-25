extends SceneTree
## 스킬트리 57개 데이터 생성(6단계, GDD 6장). 이미 있는 파일은 덮어쓰지 않는다(--force 로 덮어씀).
## 위치는 갈래 중심각(FORTUNE -90°, MACHINE 0°, ECONOMY 90°, MYSTIC 180°) 기준 ±40° 안에서
## 고리(반지름 55/105/150, 궁극기 185)마다 균등 분포로 계산한다.
## 실행: godot --headless -s tools/data/generate_skill_data.gd [-- --force]

const ICON_DIR := "res://assets/sprites/ui/skills/icon_%s.png"
const RING_RADIUS: Dictionary = {1: 55.0, 2: 105.0, 3: 150.0, 4: 185.0}
const BRANCH_ANGLE: Dictionary = {
	SkillNodeDef.Branch.FORTUNE: -90.0,
	SkillNodeDef.Branch.MACHINE: 0.0,
	SkillNodeDef.Branch.ECONOMY: 90.0,
	SkillNodeDef.Branch.MYSTIC: 180.0,
}
const SPREAD := 40.0
const ADD := StatModifiers.Op.ADD
const MULT := StatModifiers.Op.MULT
const F := SkillNodeDef.Branch.FORTUNE
const M := SkillNodeDef.Branch.MACHINE
const E := SkillNodeDef.Branch.ECONOMY
const Y := SkillNodeDef.Branch.MYSTIC
const ANY := SkillNodeDef.PrereqMode.ANY
const ALL := SkillNodeDef.PrereqMode.ALL

## 각 항목: id, branch, ring(1~3, 4=궁극기), costs, prereqs, mode, effects([[stat,op,per_level],...]), feature_id
const NODES: Array = [
	# ── FORTUNE(북, 배당) ───────────────────────────────────
	{"id": "f1", "branch": F, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.PAYOUT_MULT_COLOR, MULT, 1.15]], "feature": ""},
	{"id": "f2", "branch": F, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.PAYOUT_MULT_PARITY, MULT, 1.15]], "feature": ""},
	{"id": "f3", "branch": F, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.STRAIGHT_PAYOUT_BONUS, ADD, 2.0 / 36.0]], "feature": ""},
	{"id": "f4", "branch": F, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.CLOVER_BONUS_CHANCE, ADD, 0.20]], "feature": ""},
	{"id": "f5", "branch": F, "ring": 2, "costs": [2, 2, 2], "prereqs": ["f1", "f2"], "mode": ANY,
		"effects": [[StatModifiers.STREAK_BONUS_PER_WIN, ADD, 0.02]], "feature": ""},
	{"id": "f6", "branch": F, "ring": 2, "costs": [4], "prereqs": ["f3"], "mode": ALL,
		"effects": [[StatModifiers.HOT_NUMBER_STRAIGHT_MULT, MULT, 2.0]], "feature": "hot_numbers"},
	{"id": "f7", "branch": F, "ring": 2, "costs": [2, 2, 2], "prereqs": ["f3"], "mode": ALL,
		"effects": [[StatModifiers.GOLDEN_POCKET_MULT, ADD, 1.0]], "feature": ""},
	{"id": "f8", "branch": F, "ring": 2, "costs": [2, 2], "prereqs": ["f1", "f2"], "mode": ANY,
		"effects": [[StatModifiers.MULTI_HIT_BONUS, ADD, 0.20]], "feature": ""},
	{"id": "f9", "branch": F, "ring": 2, "costs": [4], "prereqs": ["f4"], "mode": ALL,
		"effects": [[StatModifiers.LUCKY_SEVEN_MULT, MULT, 7.0]], "feature": ""},
	{"id": "f10", "branch": F, "ring": 3, "costs": [3, 3], "prereqs": ["f6", "f7"], "mode": ANY,
		"effects": [[StatModifiers.STRAIGHT_PAYOUT_BONUS, ADD, 5.0 / 36.0]], "feature": ""},
	{"id": "f11", "branch": F, "ring": 3, "costs": [3, 3], "prereqs": ["f5"], "mode": ALL,
		"effects": [[StatModifiers.STREAK_BONUS_CAP, ADD, 10.0]], "feature": ""},
	{"id": "f12", "branch": F, "ring": 3, "costs": [3, 3, 3], "prereqs": ["f8"], "mode": ALL,
		"effects": [[StatModifiers.PAYOUT_MULT_ALL, MULT, 1.5]], "feature": ""},
	{"id": "f13", "branch": F, "ring": 3, "costs": [3, 3], "prereqs": ["f9"], "mode": ALL,
		"effects": [[StatModifiers.MILESTONE_CLOVER_BONUS, ADD, 2.0]], "feature": ""},
	{"id": "f14", "branch": F, "ring": 4, "costs": [10], "prereqs": ["f10", "f12"], "mode": ALL,
		"effects": [], "feature": "jackpot_chain"},
	# ── MACHINE(동, 자동화) ─────────────────────────────────
	{"id": "m1", "branch": M, "ring": 1, "costs": [1], "prereqs": ["heart"], "mode": ALL,
		"effects": [], "feature": "auto_spin"},
	{"id": "m2", "branch": M, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.SPIN_DELAY, ADD, -0.25], [StatModifiers.SPIN_DURATION_MULT, MULT, 0.95]], "feature": ""},
	{"id": "m3", "branch": M, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.OFFLINE_EFFICIENCY, ADD, 0.15]], "feature": ""},
	{"id": "m4", "branch": M, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.OFFLINE_CAP_HOURS, ADD, 2.0]], "feature": ""},
	{"id": "m5", "branch": M, "ring": 2, "costs": [3], "prereqs": ["m1"], "mode": ALL,
		"effects": [], "feature": "auto_bet_sizing"},
	{"id": "m6", "branch": M, "ring": 2, "costs": [5], "prereqs": ["m1"], "mode": ALL,
		"effects": [], "feature": "smart_betting"},
	{"id": "m7", "branch": M, "ring": 2, "costs": [4], "prereqs": ["m2"], "mode": ALL,
		"effects": [], "feature": "auto_upgrade"},
	{"id": "m8", "branch": M, "ring": 2, "costs": [2, 2, 2, 2], "prereqs": ["m2"], "mode": ALL,
		"effects": [[StatModifiers.MARBLE_SLOTS_BONUS, ADD, 1.0]], "feature": ""},
	{"id": "m9", "branch": M, "ring": 2, "costs": [2, 2], "prereqs": ["m3", "m4"], "mode": ANY,
		"effects": [], "feature": "offline_clover_bonus"},
	{"id": "m10", "branch": M, "ring": 3, "costs": [4], "prereqs": ["m7"], "mode": ALL,
		"effects": [[StatModifiers.MIN_SPIN_DURATION, ADD, -0.7]], "feature": "turbo_mode"},
	{"id": "m11", "branch": M, "ring": 3, "costs": [3, 3], "prereqs": ["m9"], "mode": ALL,
		"effects": [[StatModifiers.OFFLINE_EFFICIENCY, ADD, 0.10], [StatModifiers.OFFLINE_CAP_HOURS, ADD, 2.0]], "feature": ""},
	{"id": "m12", "branch": M, "ring": 3, "costs": [3, 3], "prereqs": ["m6"], "mode": ALL,
		"effects": [[StatModifiers.SMART_BETTING_BONUS, ADD, 0.10]], "feature": ""},
	{"id": "m13", "branch": M, "ring": 3, "costs": [3], "prereqs": ["m5"], "mode": ALL,
		"effects": [], "feature": "debt_manager"},
	{"id": "m14", "branch": M, "ring": 4, "costs": [10], "prereqs": ["m10", "m12"], "mode": ALL,
		"effects": [[StatModifiers.PAYOUT_MULT_ALL, MULT, 2.0], [StatModifiers.SPIN_DELAY, MULT, 0.0]], "feature": "dealer_hired"},
	# ── ECONOMY(남, 경제) ───────────────────────────────────
	{"id": "e1", "branch": E, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.UPGRADE_COST_MULT, MULT, 0.95]], "feature": ""},
	{"id": "e2", "branch": E, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.CASHBACK_RATE, ADD, 0.05]], "feature": ""},
	{"id": "e3", "branch": E, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.VIP_COMP_RATE, ADD, 0.02]], "feature": ""},
	{"id": "e4", "branch": E, "ring": 1, "costs": [1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [], "feature": "emergency_fund"},
	{"id": "e5", "branch": E, "ring": 2, "costs": [2, 2, 2], "prereqs": ["e3"], "mode": ALL,
		"effects": [[StatModifiers.INVESTMENT_RATE, ADD, 0.001]], "feature": ""},
	{"id": "e6", "branch": E, "ring": 2, "costs": [2, 2], "prereqs": ["e4"], "mode": ALL,
		"effects": [[StatModifiers.DEBT_REPAY_MULT, ADD, -0.25]], "feature": ""},
	{"id": "e7", "branch": E, "ring": 2, "costs": [2, 2], "prereqs": ["e4"], "mode": ALL,
		"effects": [[StatModifiers.PENALTY_INTERVAL_MULT, MULT, 4.0 / 3.0]], "feature": ""},
	{"id": "e8", "branch": E, "ring": 2, "costs": [2, 2, 2], "prereqs": ["e1"], "mode": ALL,
		"effects": [[StatModifiers.MARBLE_COST_MULT, MULT, 0.92]], "feature": ""},
	{"id": "e9", "branch": E, "ring": 2, "costs": [2, 2], "prereqs": ["e2"], "mode": ALL,
		"effects": [[StatModifiers.BONUS_CHIP_PER_HIT, ADD, 10.0]], "feature": ""},
	{"id": "e10", "branch": E, "ring": 3, "costs": [3, 3, 3], "prereqs": ["e5", "e8"], "mode": ANY,
		"effects": [[StatModifiers.MAX_BET_MULT, MULT, 2.0]], "feature": ""},
	{"id": "e11", "branch": E, "ring": 3, "costs": [4], "prereqs": ["e6"], "mode": ALL,
		"effects": [[StatModifiers.DEBT_REPAY_MULT, MULT, 0.8], [StatModifiers.DEBT_PAID_CLOVER_BONUS, ADD, 2.0]], "feature": ""},
	{"id": "e12", "branch": E, "ring": 3, "costs": [3, 3], "prereqs": ["e8"], "mode": ALL,
		"effects": [[StatModifiers.UPGRADE_GROWTH_MULT, MULT, 0.97]], "feature": ""},
	{"id": "e13", "branch": E, "ring": 3, "costs": [3, 3], "prereqs": ["e5"], "mode": ALL,
		"effects": [[StatModifiers.PIGGY_BANK_RATE, ADD, 0.20]], "feature": ""},
	{"id": "e14", "branch": E, "ring": 4, "costs": [10], "prereqs": ["e10", "e12"], "mode": ALL,
		"effects": [[StatModifiers.COMPOUND_INTEREST_PER_DIGIT, ADD, 0.03]], "feature": ""},
	# ── MYSTIC(서, 특수 기능) ───────────────────────────────
	{"id": "y1", "branch": Y, "ring": 1, "costs": [1], "prereqs": ["heart"], "mode": ALL,
		"effects": [], "feature": "zero_guard"},
	{"id": "y2", "branch": Y, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [], "feature": "prophecy"},
	{"id": "y3", "branch": Y, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.MIRROR_CHANCE, ADD, 0.05]], "feature": ""},
	{"id": "y4", "branch": Y, "ring": 1, "costs": [1, 1, 1], "prereqs": ["heart"], "mode": ALL,
		"effects": [[StatModifiers.GOLDEN_POCKET_COUNT, ADD, 1.0]], "feature": ""},
	{"id": "y5", "branch": Y, "ring": 2, "costs": [4], "prereqs": ["y2"], "mode": ALL,
		"effects": [], "feature": "fever_time"},
	{"id": "y6", "branch": Y, "ring": 2, "costs": [2, 2, 2], "prereqs": ["y4"], "mode": ALL,
		"effects": [[StatModifiers.MARBLE_MULT, MULT, 1.3]], "feature": ""},
	{"id": "y7", "branch": Y, "ring": 2, "costs": [3], "prereqs": ["y1"], "mode": ALL,
		"effects": [[StatModifiers.ZERO_STRAIGHT_MULT, MULT, 3.0]], "feature": "zero_blessing"},
	{"id": "y8", "branch": Y, "ring": 2, "costs": [2, 2], "prereqs": ["y3"], "mode": ALL,
		"effects": [[StatModifiers.DESTINY_FLIP_CHANCE, ADD, 0.10]], "feature": ""},
	{"id": "y9", "branch": Y, "ring": 2, "costs": [3], "prereqs": ["y2"], "mode": ALL,
		"effects": [], "feature": "clairvoyance"},
	{"id": "y10", "branch": Y, "ring": 3, "costs": [5], "prereqs": ["y6", "y8"], "mode": ANY,
		"effects": [[StatModifiers.EXTRA_BALLS, ADD, 1.0]], "feature": "double_ball"},
	{"id": "y11", "branch": Y, "ring": 3, "costs": [3, 3], "prereqs": ["y5"], "mode": ALL,
		"effects": [[StatModifiers.FEVER_PERIOD_REDUCTION, ADD, 10.0], [StatModifiers.FEVER_DURATION_BONUS, ADD, 5.0]], "feature": ""},
	{"id": "y12", "branch": Y, "ring": 3, "costs": [3, 3], "prereqs": ["y6"], "mode": ALL,
		"effects": [[StatModifiers.GOLDEN_STORM_CHANCE, ADD, 0.20]], "feature": ""},
	{"id": "y13", "branch": Y, "ring": 3, "costs": [3, 3], "prereqs": ["y11"], "mode": ALL,
		"effects": [[StatModifiers.BUFF_DURATION_MULT, MULT, 1.25]], "feature": ""},
	{"id": "y14", "branch": Y, "ring": 4, "costs": [10], "prereqs": ["y10", "y12"], "mode": ALL,
		"effects": [], "feature": "wheel_of_fortune"},
]


func _initialize() -> void:
	var force := OS.get_cmdline_user_args().has("--force")
	var written := 0
	written += _save(_make_heart(), "res://data/skills/skill_heart.tres", force)
	var ring_counts: Dictionary = {}
	for entry: Dictionary in NODES:
		var key := "%d_%d" % [int(entry["branch"]), int(entry["ring"])]
		ring_counts[key] = int(ring_counts.get(key, 0)) + 1
	var ring_index: Dictionary = {}
	for entry: Dictionary in NODES:
		var key := "%d_%d" % [int(entry["branch"]), int(entry["ring"])]
		var index := int(ring_index.get(key, 0))
		ring_index[key] = index + 1
		var def := _make_node(entry, index, int(ring_counts[key]))
		written += _save(def, "res://data/skills/skill_%s.tres" % String(entry["id"]), force)
	print("generate_skill_data: %d개 파일 작성" % written)
	_verify_total_cost()
	quit(0)


func _make_heart() -> SkillNodeDef:
	var def := SkillNodeDef.new()
	def.id = "heart"
	def.name_key = "SKILL_HEART"
	def.desc_key = "SKILL_HEART_DESC"
	def.icon_path = ICON_DIR % "heart"
	def.branch = SkillNodeDef.Branch.CORE
	def.ring = 0
	def.position = Vector2i.ZERO
	def.costs = []
	def.prerequisites = []
	def.effects = []
	def.feature_id = ""
	def.is_ultimate = false
	return def


func _make_node(entry: Dictionary, index: int, count: int) -> SkillNodeDef:
	var def := SkillNodeDef.new()
	def.id = String(entry["id"])
	def.name_key = "SKILL_%s" % def.id.to_upper()
	def.desc_key = "SKILL_%s_DESC" % def.id.to_upper()
	def.icon_path = ICON_DIR % def.id
	var branch: SkillNodeDef.Branch = entry["branch"]
	def.branch = branch
	var ring: int = int(entry["ring"])
	def.ring = ring
	def.is_ultimate = ring == 4
	def.position = _position_for(branch, ring, index, count)
	var costs: Array[int] = []
	for c in entry["costs"]:
		costs.append(int(c))
	def.costs = costs
	var prereqs: Array[String] = []
	for p in entry["prereqs"]:
		prereqs.append(String(p))
	def.prerequisites = prereqs
	def.prerequisite_mode = entry["mode"]
	var effects: Array[Dictionary] = []
	for effect: Array in entry["effects"]:
		effects.append({"stat": effect[0], "op": effect[1], "per_level": effect[2]})
	def.effects = effects
	def.feature_id = String(entry.get("feature", ""))
	return def


func _position_for(branch: SkillNodeDef.Branch, ring: int, index: int, count: int) -> Vector2i:
	var radius: float = RING_RADIUS[ring]
	var center_angle: float = BRANCH_ANGLE[branch]
	var angle := center_angle
	if count > 1:
		angle = center_angle - SPREAD + (2.0 * SPREAD) * float(index) / float(count - 1)
	var rad := deg_to_rad(angle)
	return Vector2i(roundi(cos(rad) * radius), roundi(sin(rad) * radius))


## 요청 명세: 총비용 합계가 269인지 코드로 확인한다.
func _verify_total_cost() -> void:
	var total := 0
	for entry: Dictionary in NODES:
		for cost in entry["costs"]:
			total += int(cost)
	if total != 269:
		push_error("generate_skill_data: 총비용이 269가 아님 (%d)" % total)
	else:
		print("generate_skill_data: 총비용 269 확인 완료")


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
