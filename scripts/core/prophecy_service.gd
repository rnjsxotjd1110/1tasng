class_name ProphecyService
extends RefCounted
## 예지(Y2)·천리안(Y9) 순수 로직. RngService.peek_next(1)[0] 로 미리 본 실제 결과를 받아,
## 정확도만큼만 맞는 힌트를 만든다(오답도 misc 스트림으로 섞는다 — 결과 스트림은 건드리지 않는다).
## 호출 쪽(UI)은 "이번 스핀의 힌트"를 한 번만 계산해 캐싱해야 한다(매 프레임 다시 뽑으면 안 됨).

## 레벨(1~3) → 정확도(GDD: 60/67/75%).
const ACCURACY_BY_LEVEL: Array[float] = [0.60, 0.67, 0.75]
const CLAIRVOYANCE_INCLUDE_CHANCE := 0.5
const CLAIRVOYANCE_COUNT := 3


static func accuracy_for_level(level: int) -> float:
	if level <= 0:
		return 0.0
	var index := clampi(level - 1, 0, ACCURACY_BY_LEVEL.size() - 1)
	return ACCURACY_BY_LEVEL[index]


## 다음 결과의 색 힌트. accuracy 확률로 진짜 색, 아니면 나머지 두 색 중 하나(misc 스트림).
static func color_hint(true_result: int, accuracy: float) -> RouletteRules.PocketColor:
	var true_color := RouletteRules.color_of(true_result)
	if RngService.randf_misc() < accuracy:
		return true_color
	var wrong: Array[RouletteRules.PocketColor] = [RouletteRules.PocketColor.RED, RouletteRules.PocketColor.BLACK, RouletteRules.PocketColor.GREEN]
	wrong.erase(true_color)
	return wrong[RngService.randi_range_misc(0, wrong.size() - 1)]


## 천리안(Y9): 개별숫자 후보 3개(정답 포함 확률 CLAIRVOYANCE_INCLUDE_CHANCE, 순서는 섞임).
static func straight_candidates(true_result: int) -> Array[int]:
	var include := RngService.randf_misc() < CLAIRVOYANCE_INCLUDE_CHANCE
	var pool: Array[int] = []
	for n in RouletteRules.POCKET_COUNT:
		if n != true_result:
			pool.append(n)
	var picks: Array[int] = []
	var decoy_count := CLAIRVOYANCE_COUNT - (1 if include else 0)
	for i in decoy_count:
		var index := RngService.randi_range_misc(0, pool.size() - 1)
		picks.append(pool[index])
		pool.remove_at(index)
	if include:
		picks.append(true_result)
	for i in range(picks.size() - 1, 0, -1):
		var j := RngService.randi_range_misc(0, i)
		var tmp := picks[i]
		picks[i] = picks[j]
		picks[j] = tmp
	return picks
