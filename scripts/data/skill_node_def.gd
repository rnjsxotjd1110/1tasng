class_name SkillNodeDef
extends Resource
## 스킬트리 노드. 세부 설계와 57개 데이터는 6단계에서 만든다.
## 효과는 StatModifiers 수정자(source "skill:<id>")로 적용된다. 효과가 스탯이 아닌 기능 해금이면 feature_id 를 쓴다.

enum Branch { CORE, FORTUNE, MACHINE, ECONOMY, MYSTIC }

@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
@export_file("*.png") var icon_path: String = ""
@export var branch: Branch = Branch.CORE
## 0 = 중앙, 1~3 = 고리, 4 = 궁극기.
@export var ring: int = 0
## 스킬트리 화면 좌표(중앙 기준, 픽셀).
@export var position: Vector2i = Vector2i.ZERO
## 레벨별 클로버 비용. 길이 = 최대 레벨.
@export var costs: Array[int] = [1]
## 모두 1레벨 이상이어야 구매 가능.
@export var prerequisites: Array[String] = []
@export var effect_stat: String = ""
@export var effect_op: StatModifiers.Op = StatModifiers.Op.ADD
@export var effect_per_level: float = 0.0
## 기능 해금형 스킬 id(예: "hire_dealer", "auto_spin"). 없으면 빈 문자열.
@export var feature_id: String = ""
@export var is_ultimate: bool = false


func source_id() -> String:
	return "skill:" + id


func max_level() -> int:
	return costs.size()


func total_cost() -> int:
	var total := 0
	for value in costs:
		total += value
	return total


func effect_value(level: int) -> float:
	if effect_op == StatModifiers.Op.MULT:
		return pow(effect_per_level, level)
	return effect_per_level * level
