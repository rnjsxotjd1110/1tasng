class_name SkillNodeDef
extends Resource
## 스킬트리 노드(6단계). 효과는 StatModifiers 수정자(source "skill:<id>")로 적용된다.
## 한 노드가 여러 스탯에 동시에 영향을 줄 수 있어 effects 는 배열이다: {"stat":String,"op":StatModifiers.Op,"per_level":float}
## 조건부(스트림·핫넘버 등)·특수(오토 스핀·더블 볼 등) 효과는 feature_id 로 표시하고 실제 로직은
## GameState/SpinController/자동화 서비스가 SkillService.feature_level() 로 조회해 처리한다.
## 효과가 스탯이 아닌 기능 해금이면 feature_id 를 쓴다. HEART 는 costs 가 비어 있고 항상 레벨 1(보유)이다.

enum Branch { CORE, FORTUNE, MACHINE, ECONOMY, MYSTIC }
enum PrereqMode { ALL, ANY }

@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
@export_file("*.png") var icon_path: String = ""
@export var branch: Branch = Branch.CORE
## 0 = 중앙, 1~3 = 고리, 4 = 궁극기.
@export var ring: int = 0
## 스킬트리 화면 좌표(중앙 기준, 픽셀).
@export var position: Vector2i = Vector2i.ZERO
## 레벨별 클로버 비용. 길이 = 최대 레벨. HEART 는 비움(항상 보유).
@export var costs: Array[int] = [1]
@export var prerequisites: Array[String] = []
@export var prerequisite_mode: PrereqMode = PrereqMode.ALL
## [{"stat":String,"op":StatModifiers.Op,"per_level":float}, ...]
@export var effects: Array[Dictionary] = []
## 기능 해금형 스킬 id(예: "auto_spin", "dealer_hired"). 없으면 빈 문자열.
@export var feature_id: String = ""
@export var is_ultimate: bool = false


func source_id() -> String:
	return "skill:" + id


func is_heart() -> bool:
	return costs.is_empty()


func max_level() -> int:
	return 1 if is_heart() else costs.size()


func total_cost() -> int:
	var total := 0
	for value in costs:
		total += value
	return total


## level(1부터) 까지 사는 데 필요한 누적 비용.
func cumulative_cost(level: int) -> int:
	var total := 0
	for i in mini(level, costs.size()):
		total += costs[i]
	return total


## 레벨 0→1, 1→2 ... 로 가는 비용(0-index). 범위 밖이면 -1.
func cost_at(level: int) -> int:
	if level < 0 or level >= costs.size():
		return -1
	return costs[level]


## 이 레벨에서 각 효과의 값(스탯 → 값 누적은 SkillService 가 add_modifier 로 처리).
func effect_value(effect: Dictionary, level: int) -> float:
	var per_level := float(effect.get("per_level", 0.0))
	var op: StatModifiers.Op = int(effect.get("op", StatModifiers.Op.ADD))
	if op == StatModifiers.Op.MULT:
		return pow(per_level, level)
	return per_level * level


func _to_string() -> String:
	return "SkillNodeDef(%s Lv%d/%d)" % [id, 0, max_level()]
