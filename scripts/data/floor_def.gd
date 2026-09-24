class_name FloorDef
extends Resource
## 카지노 층. 이동하면 칩을 지불하고(리셋 없음) 배율이 오르며 클로버를 받는다.

@export var index: int = 0
@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
## 이 층으로 올라가는 비용. 시작 층은 0.
@export var cost: float = 0.0
## 당첨 배율(StatModifiers FLOOR_MULT 의 base).
@export var payout_mult: float = 1.0
## 구슬당 최대 베팅액 배율.
@export var bet_mult: float = 1.0
## 이 층에 도착했을 때 받는 클로버.
@export var clover_reward: int = 0
## 이 층에서 살 수 있는 최고 구슬 재질 tier.
@export var marble_tier_cap: int = 0
## 목표 도달 시간(분). 밸런스 시뮬레이션(9단계) 기준값.
@export var target_minutes: float = 0.0
