class_name UpgradeDef
extends Resource
## 레벨형 업그레이드 정의. 효과는 StatModifiers 수정자(source "upgrade:<id>")로 적용된다.
## 효과값: ADD → effect_per_level × level, MULT → effect_per_level ^ level
## 비용: Economy.upgrade_cost(base_cost, growth, level, upgrade_cost_mult)

const UNLIMITED := -1

@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
@export_file("*.png") var icon_path: String = ""
@export var base_cost: float = 10.0
@export var growth: float = 1.15
## UNLIMITED(-1) 이면 무제한.
@export var max_level: int = UNLIMITED
@export var effect_stat: String = ""
@export var effect_op: StatModifiers.Op = StatModifiers.Op.ADD
@export var effect_per_level: float = 0.0
## 이 층 인덱스 이상에서만 구매 가능.
@export var required_floor: int = 0


func source_id() -> String:
	return "upgrade:" + id


func is_max_level(level: int) -> bool:
	return max_level != UNLIMITED and level >= max_level


func effect_value(level: int) -> float:
	if effect_op == StatModifiers.Op.MULT:
		return pow(effect_per_level, level)
	return effect_per_level * level
