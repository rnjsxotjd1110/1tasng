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
## 패널티가 새로 발동했다(PenaltyManager, 5단계). duration 은 토스트에 보여줄 표시 시간
## (시간제 패널티는 실제 지속시간, 즉시·소모형 패널티는 짧은 고정값). buff_started 도 함께 발행된다.
@warning_ignore("unused_signal")
signal penalty_triggered(id: String, duration: float)
## 화면 구석 알림. text 는 이미 tr() 된 문자열, icon 은 아이콘 id.
@warning_ignore("unused_signal")
signal toast_requested(text: String, icon: String)
## 저장 시작(4단계). TopBar 가 회전 칩 아이콘을 0.8초 보여준다.
@warning_ignore("unused_signal")
signal save_started()
## 저장 끝(성공 여부와 무관하게 바로 발행. 저장은 동기 처리라 시작과 거의 동시).
@warning_ignore("unused_signal")
signal save_finished(ok: bool)

# ── 6단계: 스킬트리·자동화·특수 기능 ─────────────────────────
## 황금 저금통(E13)이 100스핀마다 깨지며 칩을 지급했다.
@warning_ignore("unused_signal")
signal piggy_bank_broken(amount: float)
## 운명의 휠(Y14)이 등장할 시각이 됐다(팝업을 띄울 차례). GameState.wheel_of_fortune_consumed() 로 다음 주기를 시작한다.
@warning_ignore("unused_signal")
signal wheel_of_fortune_ready()
## 황금 폭풍(Y12) 발동: 다음 스핀(들) 동안 모든 포켓이 황금이 된다.
@warning_ignore("unused_signal")
signal golden_storm_triggered(spins: int)
## 운명 뒤집기(Y8): 공이 from_number 에서 to_number 로 튕겨 재판정됐다.
@warning_ignore("unused_signal")
signal destiny_flip(from_number: int, to_number: int)
## 오토 스핀이 자동으로 꺼졌다(칩 부족·베팅 없음 등). reason 은 토스트 문자열 키.
@warning_ignore("unused_signal")
signal auto_spin_stopped(reason: String)
## 연승 보너스로 클로버를 얻었다(GDD 6-1 "5연승 +1"). count 는 이번에 얻은 개수.
@warning_ignore("unused_signal")
signal streak_clover_earned(count: int)
## 살면서 처음으로 클로버를 얻었다. 스킬트리 버튼 자물쇠 해제 연출 + 루시 대사 트리거용.
@warning_ignore("unused_signal")
signal first_clover_earned()
