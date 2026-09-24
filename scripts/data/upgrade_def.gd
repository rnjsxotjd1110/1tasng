class_name UpgradeDef
extends Resource
## 레벨형 업그레이드 정의. 효과는 StatModifiers 수정자(source "upgrade:<id>")로 적용된다.
## 효과값: ADD → effect_per_level × level, MULT → effect_per_level ^ level
##         (MARBLE_TIER 는 예외: 현재 재질 MarbleDef.mult)
## 비용(UpgradeService.cost_at 이 계산, 전부 × upgrade_cost_mult):
##   STANDARD      base_cost × growth^level
##   MARBLE_TIER   다음 재질 MarbleDef.cost
##   MARBLE_POLISH 현재 재질 MarbleDef.polish_base_cost × growth^level (재질이 오르면 레벨 0)

const UNLIMITED := -1

enum Kind { STANDARD, MARBLE_TIER, MARBLE_POLISH }

@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
@export_file("*.png") var icon_path: String = ""
@export var kind: Kind = Kind.STANDARD
## 업그레이드창 카드 순서(작을수록 위).
@export var sort_order: int = 0
@export var base_cost: float = 10.0
@export var growth: float = 1.15
## UNLIMITED(-1) 이면 무제한.
@export var max_level: int = UNLIMITED
@export var effect_stat: String = ""
@export var effect_op: StatModifiers.Op = StatModifiers.Op.ADD
@export var effect_per_level: float = 0.0
## 이 층 인덱스 이상에서만 구매 가능.
@export var required_floor: int = 0
## 이 구슬 재질 tier 이상에서만 구매 가능(광택: 돌부터).
@export var required_marble_tier: int = 0


func source_id() -> String:
	return "upgrade:" + id


func is_max_level(level: int) -> bool:
	return max_level != UNLIMITED and level >= max_level


func effect_value(level: int) -> float:
	if kind == Kind.MARBLE_TIER:
		var marble := GameData.marble(level)
		return marble.mult if marble != null else StatModifiers.IDENTITY_MULT
	if effect_op == StatModifiers.Op.MULT:
		return pow(effect_per_level, level)
	return effect_per_level * level


func icon() -> Texture2D:
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D
