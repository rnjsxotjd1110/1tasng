# HOUSE EDGE — 진행 상황

> 각 단계의 마지막에 갱신한다: 한 일, 파일 목록, 남은 이슈, 다음 단계가 알아야 할 것.
> 다음 채팅은 이 문서의 "다음 단계가 알아야 할 것"을 반드시 읽고 시작한다.

## 단계별 체크리스트

### 1단계 — 기반·규칙 엔진 ✅
- [x] project.godot (640×360, viewport/keep/integer, Nearest, 픽셀 스냅, gl_compatibility, 입력 맵, 오토로드, 번역)
- [x] 폴더 구조, .gitignore
- [x] CLAUDE.md, docs/GDD.md, docs/ART_BIBLE.md, docs/PROGRESS.md
- [x] EventBus, GameState, Economy, RngService, SaveManager(틀), AudioManager(틀)
- [x] RouletteRules, Bet, SpinContext, SpinOutcome, SpinController, NumberFormat, StatModifiers, GameData, Palette
- [x] Resource 클래스(UpgradeDef, SkillNodeDef, FloorDef, MarbleDef) + 초안 .tres(구슬 15, 층 5, 업그레이드 4)
- [x] translations/strings.csv (ko, en)
- [x] 헤드리스 테스트 전부 통과
- [x] 디버그 씬 scenes/debug/DebugLogic.tscn

### 2단계 — 메인 화면·룰렛 휠·스핀 애니메이션·베팅창·당첨 연출
- [ ] tools/capture 스크린샷 도구(씬·언어 지정, 640×360 원본 + 4배 확대본을 build/ 에 저장)
- [ ] Galmuri 9/11/14 폰트 도입(OFL 파일 포함), 비트맵 숫자 폰트
- [ ] 공용 Theme(버튼 4상태·호버/클릭음 훅, 패널 9-slice) — 기본 테마 완전 제거
- [ ] 공용 UI 컴포넌트: 카운트업 라벨, 패널 전환(0.18초), 떠오르는 텍스트, 토스트
- [ ] 메인 씬(scenes/main): 상단 바, 기록 패널, 휠, 버튼 영역, 오른쪽 패널(ART_BIBLE 좌표)
- [ ] 룰렛 휠(반지름 규격대로), 공 스핀 애니메이션 → results 포켓 안착 → finish_spin()
- [ ] 베팅창(RED/BLACK/ODD/EVEN/숫자 37칸, 구슬 배치 표시, 칩 크기 1/10·1/2·MAX)
- [ ] 당첨 연출 5등급, 흔들림 끄기/번쩍임 줄이기 옵션 훅
- [ ] 입력: spin(Space), switch_panel(Tab), toggle_fullscreen(F11/Alt+Enter), pause(Esc)
- [ ] DebugLogic 씬 삭제, 메인 씬 교체

### 3단계 — 업그레이드·구슬 재질
- [ ] UpgradeService(구매·비용·레벨 상한·층 요구), upgrade_purchased 발행
- [ ] 구슬 재질 교체(층별 상한), 광택 0~5(재질 변경 시 0), 황금 포켓 표시
- [ ] 업그레이드창 UI(오른쪽 패널), 구슬 스프라이트 15종(tools/art)
- [ ] 비용 곡선 1차 조정

### 4단계 — 저장·오프라인 수익·설정
- [ ] SaveManager: 원자적 저장, 백업, 버전 마이그레이션, 자동 저장
- [ ] GameState.to_dict()/from_dict(), RngService 상태, 수정자 재구성
- [ ] 오프라인 수익(offline_efficiency, offline_cap_hours)
- [ ] 설정: 언어, 볼륨, 전체화면, 과학적 표기, 흔들림 끄기, 번쩍임 줄이기

### 5단계 — 빚·래칫 남작
- [ ] 파산 → 대출(공식), 2배 상환, 자동 상환 25%, 최대 3건
- [ ] 패널티 6종(StatModifiers penalty:*), 래칫 남작 NPC·대사
- [ ] debt_changed, 빚 완납 클로버 +2

### 6단계 — 스킬트리·클로버·자동화
- [ ] 스킬 57개 데이터(총 269 클로버), 4갈래·고리 3개·궁극기
- [ ] 스킬트리 오버레이 UI(K), 자동 스핀(A), 예지, 더블 볼, 딜러 고용

### 7단계 — 층 진행·엔딩·업적
- [ ] 층 이동(비용, 배율, 클로버 +10, 층별 배경), floor_changed
- [ ] 엔딩: 1Dc → 마담 벨벳 최후의 스핀 → 크레딧·통계 → 무한 모드
- [ ] 업적(스팀 업적 연동 준비)

### 8단계 — 타이틀·튜토리얼·사운드·폴리시·출시 준비
- [ ] 타이틀 화면, 루시 튜토리얼, 효과음·음악(AudioManager)
- [ ] 폴리시 패스, 내보내기 프리셋(Windows), 스팀 빌드 준비

### 9단계 — 밸런스 시뮬레이션·최종 QA
- [ ] tools/sim 헤드리스 시뮬레이터로 목표 도달 시간(1F 0:30, 2F 1:30, 3F 2:45, PH 4:00, 엔딩 5:00) 맞추기
- [ ] 클로버 약 230개 획득 확인, 최종 QA

---

## 완료 기록

### 1단계 (2026-09-24) — 기반·규칙 엔진

**한 일**
- Godot 4.3 프로젝트 설정: 이름·창 제목 "HOUSE EDGE", 640×360 기준 / 1920×1080 창, stretch viewport·keep·integer, Nearest 필터, 2D 픽셀 스냅(transform·vertex), gl_compatibility, 입력 맵 6개(spin, toggle_auto, switch_panel, open_skilltree, pause, toggle_fullscreen = F11 / Alt+Enter), 오토로드 6개, 번역 등록(fallback en).
- 문서 4개 작성(CLAUDE.md, GDD, ART_BIBLE, PROGRESS).
- 규칙 엔진: 유럽식 룰렛 규칙·포켓 각도·이웃, 베팅 5종 정산, 공 여러 개 정산(비용 1회), 배율 체계(SpinContext), 황금 포켓, 연출 등급·아깝다 판정.
- 경제: Economy 상수·공식(최대/최소 베팅, 칩 크기, 업그레이드 비용, 스핀 시간, 광택, 구슬 수, 파산, 대출). 빚·오프라인 상수도 미리 정의.
- StatModifiers: ADD/MULT, 캐시·무효화, 같은 source+stat 교체, 시간제 만료(source_expired → buff_ended), source 일괄 제거.
- GameState: 칩/클로버 방어 API, 마일스톤(새 단위마다 클로버 +3), 베팅 관리, 기록 100개, 통계 7종, 업그레이드 레벨 → 수정자, 황금 포켓, 버프.
- SpinController: IDLE → SPINNING → RESOLVING → IDLE, 검증·차감·결과·정산·클로버·연승·파산.
- RngService: 결과/기타 스트림 분리, peek_next/consume_next, 상태 저장.
- NumberFormat: 유효숫자 3자리, 단위 Vg 까지, 경계 자리올림, 과학적 표기, format_full, format_signed, suffix_index.
- 초안 데이터 24개(.tres) — `tools/data/generate_draft_data.gd` 로 생성(이미 있는 파일은 덮어쓰지 않음).
- 테스트 72개 / 검사 849개 전부 통과(기대값: 나무 빨강 0.973±0.005, 돌 1.46±0.01 을 시드 고정 100만 스핀으로 검증).
- 디버그 씬: 베팅 버튼·스핀·×100 스핀·칩 추가·구슬/재질/한도/황금 +1·리셋, 결과 로그. Xvfb 스크린샷으로 동작 확인.

**파일**
- `project.godot`, `.gitignore`, `CLAUDE.md`, `docs/GDD.md`, `docs/ART_BIBLE.md`, `docs/PROGRESS.md`
- `scripts/autoload/`: event_bus.gd, economy.gd, rng_service.gd, game_state.gd, save_manager.gd, audio_manager.gd
- `scripts/core/`: roulette_rules.gd, bet.gd, spin_context.gd, spin_outcome.gd, spin_controller.gd, number_format.gd, stat_modifiers.gd, game_data.gd, palette.gd
- `scripts/data/`: upgrade_def.gd, skill_node_def.gd, floor_def.gd, marble_def.gd
- `data/marbles/marble_00_wood.tres` ~ `marble_14_cosmic.tres`, `data/floors/floor_0_b1.tres` ~ `floor_4_ph.tres`, `data/upgrades/{bet_limit,marble_count,wheel_speed,golden_pocket}.tres`
- `translations/strings.csv` (+ 임포트 생성물 `.import`, `strings.ko.translation`, `strings.en.translation`)
- `tests/run_tests.gd`, `tests/lib/test_case.gd`, `tests/test_{roulette_rules,resolve,expected_value,number_format,economy,stat_modifiers,game_state,spin_controller,data,debug_scene}.gd`
- `scenes/debug/DebugLogic.tscn`, `scenes/debug/debug_logic.gd`
- `tools/data/generate_draft_data.gd`, `tools/setup_godot.sh`

**남은 이슈**
- 사용자 Windows PC 의 Godot 경로 미확인 → CLAUDE.md 표에 기록 필요(1단계는 클라우드 Linux 컨테이너에서 진행).
- 층 배율·베팅 배율·업그레이드 비용·구슬 비용·광택 비용은 전부 초안. 목표 시간표는 9단계 시뮬레이션으로 맞춘다.
- 구슬 비용 곡선(×80)과 층 이동 비용·구슬 상한이 아직 서로 맞물리지 않는다(예: 공허·코스믹 구슬 비용 < PH 이동 비용). 3단계에서 1차 조정.
- 빚 자동 상환 훅은 `SpinController._apply_outcome` 에 주석으로만 표시(5단계).
- 압류(1스핀)·클로버 수수료(1회)처럼 "횟수제" 수정자는 아직 없다. StatModifiers 는 시간제·영구만 지원 → 5단계에서 소모형(charges) 추가 필요.
- 기대값 테스트가 약 20초 걸린다(100만 스핀 × 2). 필요하면 `-- 파일이름` 필터로 나눠 실행.

**다음 단계(2단계)가 알아야 할 것**
- 연출 레이어 계약: `EventBus.spin_started(results, duration)` 를 받으면 duration 동안 공을 results[0] 포켓으로 보내고, 끝나면 **`SpinController.finish_spin()` 을 반드시 호출**한다. 메인 씬에서 `SpinController.new()` 를 만들고 `instant_resolve = false` 로 둔다(헤드리스에서는 기본 true).
- 포켓 화면 각도 = 휠 회전각 + `RouletteRules.pocket_angle(n)`. 공 궤도 97px → 안착 68px(ART_BIBLE 2장).
- 당첨 연출은 `SpinOutcome.tier`, `near_miss`, `golden_hit`, `hit_straights`, `bet_results[i].won()` 만 보고 결정한다.
- 베팅창은 `GameState.add_bet(Bet.xxx())`, `remove_bet_at`, `clear_bets`, `set_chip_size_mode` 를 쓰고 `bets_changed` 로 갱신한다. 베팅은 스핀 후에도 유지된다.
- 숫자 표시는 `NumberFormat.format()`, 툴팁은 `format_full()`. 색은 `Palette.*` 상수만.
- 새 UI 문자열 키는 strings.csv 에 ko/en 동시 추가 → `godot --headless --import` 로 .translation 재생성 → 커밋.
- 디버그 씬(scenes/debug/)과 `tests/test_debug_scene.gd` 를 삭제하고 `run/main_scene` 을 메인 씬으로 바꾼다.
- 클라우드 컨테이너에서 화면 확인: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 -s <캡처 스크립트>` 가 동작함(Mesa llvmpipe). 루트 뷰포트 텍스처는 640×360.
- Godot 4.3 주의: `@warning_ignore_start` 없음(4.4+) → 시그널마다 `@warning_ignore("unused_signal")`. `-s` 스크립트 본문은 오토로드 이름을 컴파일 시점에 모르므로 `root.get_node("GameState")` 로 접근하고, 오토로드 `_ready` 는 첫 프레임 전에 끝나지 않으므로 첫 `process_frame` 에서 실행한다.
