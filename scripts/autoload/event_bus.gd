extends Node
## 시스템 간 통신 전용 시그널 허브. 시스템끼리 직접 참조하지 말고 여기로 발행·구독한다.
## 시그널을 추가할 때는 타입을 명시하고 docs/GDD.md "EventBus" 표에도 적는다.

## 칩이 바뀌었다(delta 는 이번 변화량, 음수 가능).
@warning_ignore("unused_signal")
signal chips_changed(new_value: float, delta: float)
@warning_ignore("unused_signal")
signal clovers_changed(new_value: int, delta: int)
## GameState.current_bets 가 바뀌었다.
@warning_ignore("unused_signal")
signal bets_changed()
## 스핀 시작. 결과는 이미 정해져 있고 연출은 duration 동안 공을 results 로 보낸 뒤 finish_spin() 을 호출한다.
@warning_ignore("unused_signal")
signal spin_started(results: Array[int], duration: float)
## 정산 완료.
@warning_ignore("unused_signal")
signal spin_resolved(outcome: SpinOutcome)
## 보유 칩 < 최소 베팅액 이고 진행 중인 스핀이 없다.
@warning_ignore("unused_signal")
signal bankrupt()
@warning_ignore("unused_signal")
signal debt_changed()
## 업그레이드 구매 완료(level = 구매 후 레벨, 한 번에 여러 레벨을 사면 한 번만 발행).
@warning_ignore("unused_signal")
signal upgrade_purchased(id: String, level: int)
## 황금 포켓이 새로 생겼다(휠의 빛줄기·베팅창 금 테두리 연출용).
@warning_ignore("unused_signal")
signal golden_pockets_added(numbers: Array[int])
@warning_ignore("unused_signal")
signal skill_purchased(id: String, level: int)
@warning_ignore("unused_signal")
signal floor_changed(floor_index: int)
## 보유 칩이 처음으로 새 단위(1=K, 2=M …)에 도달했다.
@warning_ignore("unused_signal")
signal milestone_reached(suffix_index: int)
@warning_ignore("unused_signal")
signal buff_started(id: String, duration: float)
@warning_ignore("unused_signal")
signal buff_ended(id: String)
## 화면 구석 알림. text 는 이미 tr() 된 문자열, icon 은 아이콘 id.
@warning_ignore("unused_signal")
signal toast_requested(text: String, icon: String)
