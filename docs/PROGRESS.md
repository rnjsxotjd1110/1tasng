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

### 2단계 — 메인 화면·룰렛 휠·스핀 애니메이션·베팅창·당첨 연출 ✅
- [x] tools/capture 스크린샷 도구(시나리오·언어 지정, 640×360 원본 + 3배 확대본을 tools/capture/out/ 에 저장)
- [x] Galmuri 9/11/11 Bold/14 폰트 도입(OFL 파일 포함), 비트맵 숫자 폰트 7px·14px × 5색
- [x] 공용 Theme(버튼 4상태, 탭, 칩 토글, SPIN, 패널 9-slice, 툴팁, 스크롤바, 슬라이더, 체크박스) — 프로젝트 기본 테마
- [x] 공용 UI 컴포넌트: 카운트업 라벨, 패널 전환(0.18초), 떠오르는 텍스트, 토스트, 툴팁, 정수 흔들림
- [x] 메인 씬(scenes/main): 상단 바, 기록 패널, 휠, 버튼 영역, 오른쪽 패널(ART_BIBLE 좌표), B1 배경
- [x] 룰렛 휠(반지름 규격대로), 공 스핀 애니메이션 → results 포켓 안착 → finish_spin(), 착지 테스트 1000회
- [x] 베팅창(RED/BLACK/ODD/EVEN/숫자 37칸, 구슬 비행·쌓기·드래그·우클릭, 칩 크기 1/10·1/2·MAX, 툴팁)
- [x] 당첨 연출 5등급, 흔들림 끄기/번쩍임 줄이기 옵션 훅(VisualSettings)
- [x] 입력: spin(Space), switch_panel(Tab), open_skilltree(K), pause(Esc), toggle_auto(A, 잠김), toggle_fullscreen(F11/Alt+Enter)
- [x] 효과음 21종(합성) + AudioManager(버스·풀·동시 재생 제한·피치 ±5%·루프)
- [x] DebugLogic 씬 삭제, 메인 씬 교체

### 3단계 — 업그레이드·구슬 재질 ✅
- [x] UpgradeService(구매·비용·레벨 상한·층/재질 조건·재질 상한·×1/×10/MAX), upgrade_purchased·golden_pockets_added 발행
- [x] 업그레이드 6종 데이터(marble_tier, marble_polish, bet_limit, marble_count, spin_speed, golden_pocket), 효과는 전부 upgrade:<id> 수정자
- [x] 구슬 재질 교체(층별 상한), 광택 0~5(재질 변경 시 0), 황금 포켓 빛줄기·금 테두리·GOLDEN 배지
- [x] 업그레이드창 UI(오른쪽 패널, 카드 6장, 스크롤, 연속 구매, 툴팁), 탭 빨간 점, 0.18초 슬라이드 전환
- [x] 구슬 재질 15종 비주얼(셰이더 + 부가 효과 + 휠 궤적), 크기 3종(7/10/24px), 공허 왜곡
- [x] 재질 승급 연출, 새 슬롯 연출, 효과음 9종
- [x] 숫자 표기 전수 점검 + F9 디버그 패널
- [ ] 비용 곡선 1차 조정 → 요청에 따라 9단계로(아래 남은 이슈)

### 4단계 — 저장·오프라인 수익·설정·일시정지·통계 ✅
- [x] SaveManager: 원자적 저장(tmp→검증→교체), .bak 백업, 체크섬(sha256), 버전 마이그레이션 틀, 자동 저장 6종, 종료 시 저장
- [x] GameState.to_dict()/from_dict(), RngService 상태, 업그레이드 수정자 재구성, 스핀 도중 저장 즉시 정산
- [x] 오프라인 수익(OfflineIncome: 팁/없음/전체 분기, 상한·효율, 시계 조작 방어, 60초 미만 무시), 복귀 팝업
- [x] SettingsManager(user://settings.cfg): 오디오·화면·게임·접근성, 설정 화면(탭 5개), 포커스 테두리
- [x] 일시정지 메뉴(Esc, 디더 오버레이, 시간 흐름 옵션), 통계 화면(카운트업)
- [x] 색약 보조(휠·베팅판 점 무늬, 프로시저럴)

### 5단계 — 빚·래칫 남작 ✅
- [x] 파산 → 대출(공식), 2배 상환, 자동 상환 25%, 최대 3건(4번째는 합산)
- [x] 패널티 6종(StatModifiers penalty:*), 래칫 남작 NPC·대사, 대화 시스템(DialogueBox)
- [x] debt_changed, 빚 완납 클로버 +2

### 6단계 — 스킬트리·클로버·자동화 (기능 구현 완료 — 아래 "진행 상황" 의 남은 이슈 참고)
- [x] 로직 기반: StatModifiers 신규 스탯, SkillNodeDef 재설계(효과 배열+선행조건 ALL/ANY), SkillService
- [x] RouletteRules/SpinContext/SpinController 확장(제로가드·미러·핫넘버·럭키세븐·이중적중·황금폭풍·잭팟체인·운명뒤집기·피버·저금통·비상금·투자수익)
- [x] 스킬 57개 데이터 생성 + 총비용 269 코드 검증 + 회귀 테스트
- [x] 클로버 획득 연출(날아가는 클로버) + 첫 클로버 해금 연출(자물쇠 파괴+루시 대사)
- [x] 스킬트리 오버레이 UI(K, 아이리스 와이프, 노드맵, 팬/줌, 툴팁, 홀드 구매)
- [x] 자동화 3종 UI: 오토 스핀(A), 스마트 베팅 드롭다운, 오토 업그레이드 토글
- [x] 특수 기능 8종 UI/연출: 예지 수정구, 핫넘버 불꽃, 피버 배너·셰이더, 잭팟체인 번개, 운명뒤집기 텍스트, 더블볼 보라 궤적, 황금저금통 돼지, 운명의 휠 팝업, 버프 표시줄
- [x] 딜러 루시 스프라이트·초상화·연출(월드 액터·대사·복귀 팝업 초상화)
- [x] 캡처 검수(스킬트리·자동화·루시 확인), 최종 커밋 — 일부 시나리오는 아래 "남은 이슈" 참고

### 7단계 — 층 진행·엔딩·업적 (진행 중)
- [x] 층 이동 로직(비용·배율·클로버 +10, `FloorService`), `floor_changed` 발행 지점 — 층별 배경은 2/N
- [x] 엔딩 로직(1Dc → `EndingService`, `ending_reached`/`infinite_mode` 저장) — 최후의 스핀·크레딧·벨벳 연출은 3/N
- [x] 업적 로직 30개(`AchievementManager`+`data/achievements.json`, 저장/불러오기) — 토스트·목록 화면은 3/N
- [x] 층별 배경 4종·휠 스킨 5종·엘리베이터 UI·컷신 (2/N)
- [x] 마담 벨벳·최후의 스핀·크레딧·업적 토스트/목록 화면 (3/N)

### 8단계 — 타이틀·튜토리얼·사운드·폴리시·출시 준비 (진행 중)
- [x] 부팅 순서(스플래시→타이틀→인트로 컷신→메인), 이어하기/새 게임, "저장 후 타이틀로" 활성화 (1/N)
- [x] 루시 튜토리얼(6단계 안내, 저장 재개, 설정 끄기/다시 보기, 1회성 신규 기능 팁 3종) (2/N)
- [ ] 효과음·음악(AudioManager)
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

### 2단계 (2026-09-24) — 메인 화면·룰렛 휠·스핀 애니메이션·베팅창·당첨 연출

**한 일**
- **스크린샷 도구** `tools/capture/capture.gd`: 메인 씬을 띄워 상태를 강제로 만든 뒤 저장. 시나리오 19개(idle, betting, tooltip, spin_03/06/085, normal, good, big, jackpot, loss, near_miss, no_chips, upgrade_tab, skilltree, multi_ball, golden, golden_idle, marbles12) × ko/en. "캡처 → 검토 → 개선"을 4회 반복했다(아래 "검수 기록").
- **아트 파이프라인**(Python + Pillow, 36색 강제): `tools/art/pixlib.py`(공용: 팔레트 검사, 원·다각형, 디더링, 4배 미리보기) + `gen_ui.py`(9-slice 프레임·버튼 4상태·탭·SPIN·아이콘·토큰·배지·파티클·펠트 패널), `gen_fonts.py`(비트맵 숫자 폰트, 3×5 숫자), `gen_wheel.py`(휠 고정 레이어), `gen_bg.py`(B1 배경), `gen_fx.py`(네온·JACKPOT 글자), `build_theme.gd`(theme_main.tres).
- **룰렛 휠**: 고정 스프라이트 4장 + `_draw()` 회전 링(포켓 37·칸막이·숫자·황금 포켓)·터렛·공·불꽃. 모션 블러(링 잔상 3단계, 공 잔상 2개), 대기 중 허브 빛(4~6초), 결과 포켓 3회 점멸 + 빛 링, 공 테두리 빛.
- **스핀 궤적** `SpinChoreography`(순수 계산): 휠 각도 닫힌 식 → 공 상대각 누적 적분 테이블 + 보정(속도 배율 흡수 후 B 구간 창 분산) → 착지 오차 0(부동소수 수준). 디플렉터를 실제로 지나는 순간에 튕김·불꽃·소리, 공 여러 개(착지 시각·발사 각도·튕김 패턴 다름), 짧은 스핀 규칙, 스킵(0.3초).
- **메인 화면**: 상단 바(칩·초당 수익·층·클로버·빚 자리·탭), 기록 패널(전광판식 3열 토큰·비율 막대·핫/콜드·스핀/연승), 베팅창(216×328), SPIN/AUTO, 결과 배지, 업그레이드·스킬트리·설정 빈 화면(완성 디자인 + "준비 중").
- **당첨 연출**(scenes/fx): 떠오르는 텍스트, 칩 파티클, 코인 분수, 플래시, 정수 흔들림, BIG WIN 네온 배너, JACKPOT 전체 화면(회전 광선 셰이더·글자 낙하·코인 비·2초 카운트업·클릭 닫기), 날아가는 칩(도착마다 카운터 1px 튐 + 딸깍), 진 구슬 빨려 들어감·재등장, 황금 포켓 ×3.
- **배경 B1**: 벽돌 벽·파이프·얼룩·곰팡이, 현상수배 포스터(래칫 남작 복선), 네온 "LUCKY"(글자별 불규칙 깜빡임, 가산), 흔들리는 램프 + 빛 원뿔·빛 웅덩이(가산), 연기, 비네트 셰이더.
- **사운드**: `tools/audio/gen_sfx.py`(오실레이터·엔벨로프·슬라이드 + 저역 필터 + Schroeder 리버브) 21종, `AudioManager` 구현(버스 Master/Music/SFX/UI, 버스별 풀, 소리별 동시 재생 제한, 피치 ±5%, 속도 연동 루프, 모든 버튼 호버·클릭음 자동 연결).
- 테스트 102개 / 검사 1959개 전부 통과(추가: 착지 1000회 등 궤적 10개, 기록 통계 4개, 초당 수익 1개, 메인 씬 통합 12개, UI 품질 4개 — 팔레트 밖 픽셀·테마 변형 누락·코드 번역 키 누락·효과음 파일).

**검수 기록(캡처 → 검토 → 개선)**
1. 첫 캡처: LUCKY 네온이 비네트에 묻힘, 클로버 아이콘이 "×"로 보임, 베팅창 금액 줄이 겹침, 검정 토큰이 어두운 테이프에서 안 보임, BIG WIN 배너가 순이익 텍스트를 가림, 토스트가 베팅창 제목을 가림, 연기가 원형 얼룩으로 보임, 나무 구슬이 나무 트랙에서 안 보임, 잭팟 광선이 너무 굵고 글자가 작음, 결과 점멸 코드 타입 오류 → 전부 수정(발광 요소를 비네트 위로, 클로버 재디자인, 트랙을 더 어둡게 + 공 테두리 빛, 잭팟 글자 ×3 등).
2. 두 번째: 영어 화면 확인. 토스트가 LUCKY 간판을 가림, 공 2개 결과 배지 부제 겹침, 한국어 "아직 기록이 없습니다" 넘침 → 토스트를 SPIN 위로, 배지 간격 66px, "기록 없음".
3. 세 번째: 업그레이드 탭을 눌러도 베팅 탭이 선택된 채 남음(ButtonGroup + set_pressed_no_signal), 구슬 12개면 트레이가 넘침, 토스트가 잭팟 화면 위에 그려짐 → 수정.
4. 네 번째: 황금 포켓·구슬 12개·공 2개·칩 부족 확인, ko/en 전체 재촬영.

**파일**
- 도구: `tools/capture/capture.gd`, `tools/art/{pixlib,gen_ui,gen_fonts,gen_wheel,gen_bg,gen_fx}.py`, `tools/art/build_theme.gd`, `tools/audio/gen_sfx.py`
- 로직: `scripts/core/{spin_choreography,history_stats,income_tracker,visual_settings}.gd`, `scripts/autoload/audio_manager.gd`(구현), `game_state.gd`(+replace_bet_at, restore_last_bets), `rng_service.gd`(+force_next, 도구 전용)
- 씬: `scenes/main/{Main.tscn,main.gd}`, `scenes/main/bg/{BackgroundB1.tscn,background_b1.gd}`, `scenes/roulette/{RouletteWheel.tscn,roulette_wheel.gd,marble_sprite.gd}`, `scenes/ui/{TopBar,HistoryPanel,BetPanel,SpinControls}.tscn` + `top_bar.gd, history_panel.gd, bet_panel.gd, bet_board.gd, spin_controls.gd, count_label.gd, panel_transition.gd, tooltip_layer.gd, pixel_digits.gd, placeholder_screen.gd`, `scenes/fx/{FloatingText,ParticleBurst,ScreenFlash,BigWinBanner,JackpotOverlay,ResultBadge,FlyingChips,ToastLayer}.tscn` + 스크립트, `neon_text.gd`, `screen_shake.gd`
- 에셋: `assets/fonts/`(Galmuri 4종 + OFL.txt + num7/num14 × 5색), `assets/ui/`(프레임·버튼·theme_main.tres), `assets/sprites/{ui,wheel,bg/b1,fx}/`, `assets/audio/sfx/*.wav`(21), `assets/shaders/{vignette,rays}.gdshader`, `default_bus_layout.tres`
- 테스트: `tests/test_{spin_choreography,history_stats,income_tracker,main_scene,ui_assets}.gd` (삭제: test_debug_scene.gd, scenes/debug/)
- 문서: ART_BIBLE(휠 레이어·좌표·타이밍·에셋 목록 116항목), GDD 13장(2단계 세부 규칙), CLAUDE.md(폴더·캡처·에셋 재생성)

**남은 이슈**
- 파산하면 아직 되돌릴 방법이 없다(대출은 5단계). 2단계 빌드를 직접 플레이하다 칩이 바닥나면 새로 시작해야 한다.
- 60fps: Xvfb + llvmpipe(소프트웨어 렌더러)에서만 확인해 실제 GPU 프레임 측정은 못 했다. 휠은 프레임마다 다각형 약 150개 × (1 + 잔상 3)을 그리므로 부담은 작을 것으로 본다. 8단계 폴리시에서 실기 측정.
- 효과음은 합성 임시 음원이다. 컨테이너에 오디오 출력이 없어 **귀로 들어 보지 못했다** — 파형 길이·루프 이음매만 검증. 로컬 PC 에서 볼륨 균형 확인 필요(8단계에서 교체).
- 드래그 앤 드롭·호버는 코드 경로 테스트와 캡처(호버 툴팁)로만 확인했고, 실제 마우스 조작은 로컬에서 한 번 확인할 것.
- 사용자 Windows PC 의 Godot 경로는 여전히 미확인(CLAUDE.md 표).
- 업그레이드·스킬트리·설정 화면은 디자인된 빈 화면("준비 중")이다.

**다음 단계(3단계)가 알아야 할 것**
- 구슬 재질이 바뀌면 `main.wheel.refresh_marble()` 과 `main.bet_panel.board.refresh_marble()` 을 부른다(`MarbleSprite` 가 재질별 텍스처를 캐시).
- 황금 포켓은 `GameState.golden_pockets` 를 휠이 매 프레임 읽어 금색 + 반짝임으로 그린다. 적중 시 `outcome.golden_hit` → 결과 포켓 금색 + "×3" 떠오르는 텍스트까지 이미 연결됨.
- 업그레이드창은 `Main.upgrade_panel`(지금 `PlaceholderScreen`) 자리에 216×328 로 넣고 `switch_panel()` 전환을 그대로 쓴다.
- 새 버튼은 테마 변형(`Button`, `ButtonGold`, `ButtonDark`, `ChipButton`, `TabButton`)만 쓰면 호버·클릭음까지 자동이다. 새 문자열은 strings.csv 에 ko/en 추가 후 `godot --headless --import`.
- 휠 속도 업그레이드로 스핀 시간이 1.5초까지 줄어도 `SpinChoreography` 가 단계 비율을 자동 조정한다(T<2.5초면 튕김 1회).
- 화면 검수는 `tools/capture/capture.gd` 에 시나리오를 추가해서 한다(3단계: 업그레이드창, 구슬 재질별 공).

### 3단계 (2026-09-24) — 업그레이드 시스템 · 구슬 재질 15종 · 업그레이드 화면

**시작 전 정리**: 작업 브랜치(`claude/brave-mendel-ondxic`)에는 1단계 커밋만 있었고, 2단계는 `claude/tender-wozniak-0c8ada` 에만 있었다. 2단계 커밋을 fast-forward 로 가져온 뒤 3단계를 올렸다.

**한 일**
- **로직** `scripts/core/upgrade_service.gd`: 종류별 비용(등비 / 다음 재질 가격 / 재질 가격 × 0.08 × 1.7^레벨) × upgrade_cost_mult, 잠금 상태 6종(OK·칩 부족·MAX·층·재질·재질 상한), ×1/×10/MAX(등비수열 합의 역 + ±1 보정), 구매·광택 초기화, 표시용 효과값. `UpgradeDef.kind`(STANDARD/MARBLE_TIER/MARBLE_POLISH)·`sort_order`·`required_marble_tier` 추가. 재질·광택도 `upgrade:marble_tier` / `upgrade:marble_polish` 수정자로 바꿨다(GameState.marble_tier/polish_level 은 사본).
- **데이터**: 업그레이드 6종 .tres(`wheel_speed` → `spin_speed`), 재질 광택 기본 비용을 재질 비용 × 0.08 로(`tools/data/generate_draft_data.gd` 갱신 후 재생성).
- **구슬 비주얼**: `assets/shaders/marble.gdshader`(나무 5색 인덱스 템플릿 → 재질 5색 + 강조색, 텍셀 단위 표면 디테일 15종, glint, 보석 면 회전, 다이아 무지개, 흑요석 테두리 맥동, 별 점멸, 공허 소용돌이, 코스믹 성운), `void_lens.gdshader`(공허 주변 화면 왜곡), `MarbleSprite`(템플릿·공용 머티리얼·그림자·테두리 빛), `MarbleFx`(구슬 뒤/앞 부가 효과, 궤적 설정), `MarbleView`(UI 부품), `VoidLens`. 휠은 재질별 궤적 입자·추가 잔상, 베팅판·트레이 구슬은 10px 로 키움.
- **업그레이드창** `scenes/ui/upgrade_panel.gd`·`upgrade_card.gd`: 수량 토글, 정수 픽셀 부드러운 스크롤 + 드래그 레일, 카드(아이콘·이름·Lv·효과 변화·레벨당 효과·금/stone 구매 버튼·수량·비용·부족분 바), 재질 카드(24px 회전 미리보기·수집 띠 15종), 잠김(실루엣·자물쇠·조건)·MAX(금 테두리·스탬프), 구매 반응(흰 플래시 2프레임 → 아이콘 2px 튐 → 코인음 피치 상승 → 칩 카운터 감소), 누르고 있으면 0.4초 뒤부터 가속 연속 구매, 툴팁(format_full·공식).
- **Main**: 오른쪽 패널 슬라이드 전환(0.18초, 전환 중만 잘라 냄), 탭 빨간 점(TopBar), 재질 승급 연출 `scenes/fx/marble_promotion.gd`(7단계, 클릭·Space 스킵, 대기열), 새 슬롯 연출(BetBoard), 황금 포켓 빛줄기(휠)·베팅칸 금 테두리·`GoldenBadge`("황금 ×3" + 금 코인).
- **숫자 표기 전수 점검**: grep 으로 `str()`·`%d` 표시를 찾아 NumberFormat 으로(결과 배지, 기록 %, 베팅 개수 배지, 툴팁·토스트 번역 문자열 %d → %s). `format_mult`·`format_decimal`·`format_seconds`·`format_percent` 추가. num14 의 0 에 가운데 점(Oc·Ocd 의 O 와 구분), num7 에 L·v. 재발 방지 테스트(`test_numbers_go_through_number_format`).
- **F9 디버그 패널** `scenes/debug/debug_panel.gd`(개발 빌드에서만 Main 이 동적 로드): 칩 1e3/1e15/1e33/1e60, 클로버 +10/+100, 시간 ×1/×4/×10, 층 ±1, 재질 ±1, 업그레이드 +10, 리셋.
- **아트·사운드**: `tools/art/gen_upgrades.py`(구슬 템플릿 10·24px, 아이콘 6종 + 실루엣, 카드 프레임 6종 + 칸, MAX 스탬프, 알림 점, 화살표, 빛줄기, GOLDEN 배지, 큰 자물쇠), gen_ui.py(stone 버튼), build_theme.gd(ButtonStone·Card*·CardSlot·BadgeGolden), gen_sfx.py(buy_coin, slot_open, marble_roll, golden_beam, promote_charge/flash/jingle_1~3).
- **캡처 도구**: capture.gd 에 3단계 시나리오 22개(upgrade_early/mid/late, 툴팁, 승급 4시점, 황금 포켓 3, 새 슬롯, 궤적 3, 숫자 1e3~1e60, 탭 슬라이드·점, 디버그 패널) + `tier=` 인자, `tools/capture/marble_sheet.gd`(15종 비교 시트).
- 테스트 129개 / 검사 3006개 전부 통과(추가: test_upgrade_service 13개, test_upgrade_panel 11개, NumberFormat 2개, 숫자 표기 검사 1개).

**검수 기록(캡처 → 검토 → 개선)**
1. 첫 비교 시트: 흑요석·코스믹이 보라 덩어리 → 테두리 광이 구슬 위에 그려지고 있었다. 구슬 뒤/앞 효과로 나눔.
2. 모든 구슬이 칙칙함 → canvas fragment 의 COLOR 에 텍스처 색이 곱해져 밝기 값이 틀렸다. 인스턴스 값을 vertex 에서 varying 으로 받음. 렌더된 구슬 픽셀이 전부 팔레트 색인지 확인(그림자 알파 제외 0개).
3. 보석이 흰 뚜껑처럼 보임·금이 겨자색·다이아가 파란 지구 같음 → 광택은 빛을 정면으로 받는 좁은 면만, 금은 한 단계 밝게 + 어두운 반사 띠, 다이아는 흰 얼음빛 + 면 중심 무지개 한 점, 별은 1px, 옥은 우윳빛 구름, 코스믹 성운은 크게.
4. 업그레이드창: 부족분 바가 카드 배경에 가려짐 → 앞 층으로. 영어 긴 이름 + Lv 가 버튼을 침범 → Lv 를 셋째 줄로, 재질 카드는 버튼을 아래로(카드 68px). 잠금 문구가 MAX 스탬프 밑으로 넘침 → 자물쇠를 오른쪽 끝으로, 문구 폭 확대, 재질 MAX 는 문구 대신 스탬프·수집 띠. 이 규칙을 ko/en × 4상태 × 2수량 텍스트 폭 테스트로 고정.
5. 숫자 1e60: "823Ocd" 가 "8230cd" 로 읽힘 → 0 에 점. bet_limit 9999레벨은 1.35^L 이 inf → 방어 코드가 막음(실제 게임에서는 도달 불가, 아래 남은 이슈).
6. 승급 연출: 빛 모으기가 약함 → 줄어드는 광선 12개 + 맥동 고리, 배너 뒤 PanelPlain 판.

**파일**
- 로직·데이터: `scripts/core/upgrade_service.gd`(신규), `scripts/data/upgrade_def.gd`, `scripts/autoload/{game_state,economy,event_bus,audio_manager}.gd`, `scripts/core/number_format.gd`, `data/upgrades/{marble_tier,marble_polish,bet_limit,marble_count,spin_speed,golden_pocket}.tres`(wheel_speed 삭제), `data/marbles/*.tres`(광택 비용), `tools/data/generate_draft_data.gd`
- 구슬: `assets/shaders/{marble,void_lens}.gdshader`, `scenes/roulette/{marble_sprite,marble_view,marble_fx,void_lens,roulette_wheel}.gd`
- UI·연출: `scenes/ui/{upgrade_panel,upgrade_card,bet_board,top_bar,history_panel,pixel_digits}.gd`, `scenes/fx/{marble_promotion,golden_badge,result_badge}.gd`, `scenes/main/main.gd`, `scenes/debug/debug_panel.gd`
- 에셋: `assets/sprites/marbles/`, `assets/sprites/ui/upgrades/`, `assets/sprites/ui/{stamp_max,notify_dot,arrow_right,golden_beam,icon_lock_big}.png`, `assets/ui/{card_*,button_stone_*,badge_golden}.png`, `assets/ui/theme_main.tres`, `assets/fonts/num*`, `assets/audio/sfx/`(9개)
- 도구: `tools/art/{gen_upgrades.py(신규),gen_ui.py,gen_fonts.py,build_theme.gd}`, `tools/audio/gen_sfx.py`, `tools/capture/{capture.gd,marble_sheet.gd,marble_sheet_view.gd}`
- 테스트: `tests/test_{upgrade_service,upgrade_panel}.gd`(신규), `test_{data,economy,number_format,stat_modifiers,main_scene,spin_controller,ui_assets}.gd`
- 문서: GDD 5장·14장·EventBus, ART_BIBLE 6장·9장·에셋 목록, CLAUDE.md, 스크린샷 `docs/screenshots/stage3/`(32장: 업그레이드창 초반·중반·후반 ko/en, 툴팁, 승급 4시점, 황금 포켓, 새 슬롯, 궤적, 숫자 구간, 슬라이드·점, 15종 비교 시트 + 확대본)

**남은 이슈**
- **구슬 비용 곡선과 층 이동 비용이 아직 맞물리지 않는다**(1단계부터 남은 이슈): 3F 상한 별빛(42.9Sx)과 PH 이동(1No) 사이가 멀고, 공허(3.44Sp)·코스믹(275Sp)은 PH 이동 비용보다 싸서 PH 도착 즉시 둘 다 살 수 있다. 요청대로 수치 조정은 9단계 시뮬레이션에서.
- 업그레이드 비용·효과 수치는 전부 요청 명세의 초안이다(9단계 조정).
- 베팅 한도는 무제한이라 1.35^L 이 약 2,360레벨에서 double 을 넘는다(비용 20·1.2^L 이 먼저 1e188 이 되어 실제로는 도달 불가). 방어 코드가 inf 를 막고 "∞" 로 표시한다.
- 구매 수량 설정(×1/×10/MAX)은 아직 저장하지 않는다(4단계 저장에서 같이).
- 공허 왜곡(화면 텍스처 읽기)과 구슬 셰이더는 Mesa llvmpipe 에서만 확인했다. 실제 GPU 에서 60fps·모양을 확인할 것(8단계 폴리시).
- 효과음은 여전히 합성 임시음이고 귀로 들어 보지 못했다(8단계 교체).
- 황금 포켓 빛줄기는 불러오기(4단계)에서 이미 있는 포켓에는 나오지 않지만, 레벨을 다시 걸 때 개수가 늘면 나온다 — 4단계에서 `rebuild_upgrade_modifiers` 호출 순서를 확인할 것.

**다음 단계(4단계)가 알아야 할 것**
- 저장할 상태: `GameState.upgrade_levels`(재질·광택 포함 — marble_tier/polish_level 은 사본), `golden_pockets`(위치), `UpgradePanel.mode`(선택). 불러온 뒤 `GameState.rebuild_upgrade_modifiers()` → `MarbleSprite.sync_shared()`(또는 Main 의 `_on_promotion_arrived(tier)`) 로 화면 구슬을 맞춘다. 광택 초기화는 `UpgradeService.purchase` 에만 있어서 레벨을 다시 걸어도 광택이 지워지지 않는다.
- 설정 화면: `VisualSettings.reduce_flashing` 은 승급 섬광·빛줄기에도 적용된다. `NumberFormat.scientific_mode` 는 `format_mult` 에도 적용된다(1000 이상).
- 새 UI 문자열은 숫자 자리를 `%s` + NumberFormat 으로(`%d` 는 테스트가 막는다).
- 구슬을 새로 그리는 곳은 `MarbleView`(UI) 또는 CanvasItem 에 `MarbleSprite.shared_material()` + 템플릿 그리기 + `MarbleFx.draw_aura_back/draw_aura` 를 쓴다.
- F9 디버그 패널로 칩·층·재질을 바로 바꿀 수 있다(개발 빌드만).

### 4단계 (2026-09-24) — 저장·오프라인 수익·설정·일시정지·통계

**시작 전 정리**: 작업 브랜치(`claude/beautiful-franklin-nc1a2i`)가 1단계 시점에서 분기돼 있었고, 실제 최신 상태(1~3단계)는 `claude/brave-mendel-ondxic`(PR 없음)에 있었다. 그 브랜치 기준으로 재설정한 뒤 4단계를 올렸다.

**한 일**
- **SaveManager**: `user://save.json` = `{"version","saved_at","checksum","data"}`, `data` 는 `JSON.stringify()` 한 문자열을 한 번 더 담는다(이유: Godot JSON 숫자 파서가 1e250 급 큰 실수를 다시 읽을 때 마지막 비트가 흔들려, 객체로 두면 체크섬이 정상 파일을 오검출할 수 있음을 실측 확인 — `check_rel` 1e-9 로 테스트). `save.tmp` 에 쓰고 다시 읽어 검증 → `save.json`→`save.bak` 교체 → `save.tmp`→`save.json` 교체(`DirAccess.rename_absolute`). 체크섬 불일치·손상 시 `.bak` 복구 + 토스트, 실패하면 새 게임처럼. 마이그레이션은 `match from_version` 틀만(지금은 v1 뿐). 자동 저장: 30초 타이머, 업그레이드·스킬·층 이동·대출, 포커스 상실, `NOTIFICATION_WM_CLOSE_REQUEST`(저장 후 종료). 저장 중 TopBar 구석에 칩 회전 아이콘 0.8초(`EventBus.save_started/save_finished`).
- **GameState**: `to_dict()/from_dict()`(모든 필드 + 시간제 버프만), `pending_spin_bets/results`(스핀 도중 저장 스냅샷), `auto_spin_enabled`(`Main.auto_spin` 에서 옮김)·`auto_spin_unlocked()`(6단계까지 항상 false), `income_tracker`(5분 창, 오프라인·5단계 대출액 공용), `number_frequency`+`most_frequent_number()`, `stats.total_wins`(승률용). `SpinController.settle_pending_spin()`: 불러온 뒤 스핀 도중 저장분을 연출 없이 즉시 정산.
- **오프라인 수익**: `Economy.offline_income()`(상한×효율) + `OfflineIncome.compute()`(팁 5%/없음/전체 30%(초안 0.25→요청 명세 0.3) 분기, 시계 조작·60초 미만 방어). `ReturnPopup`(딜러 루시 초상화 없으면 `icon_vault.png`, 경과시간 "N시간 M분(최대 적용)", 수익 1.5초 카운트업 + 가속 코인음, [받기]로 지급).
- **SettingsManager**(신규 오토로드, `user://settings.cfg`): 오디오 4·화면 4·게임 5·접근성 4 필드, `commit()`(적용+저장) 하나로 개별 setter 없이 처리. `SettingsScreen`(640×336, 탭 5개, 기존 슬라이더/체크박스 테마 재사용, `FocusStyle` neon_cyan 포커스, 데이터 탭 RESET 3초 홀드+문구 입력).
- **PauseMenu**(Esc): 화면 전체 `dither_dim.gdshader`(4×4 Bayer, vignette 와 같은 기법) + 계속하기/설정/통계/저장후타이틀(비활성)/게임종료 + 시간 흐름 체크박스. `PROCESS_MODE_ALWAYS` 라 `get_tree().paused` 여도 자기 자신은 동작. 옵션 꺼짐(기본)이면 파산 없이 항상 흐름, 켜면 일시정지·통계 화면이 열린 동안만 멈춤.
- **StatsScreen**: 한 줄 목록(처음엔 두 단으로 만들었다가 겹침 발견 → 한 단으로 재설계, 아래 검수 기록), `CountLabel` 카운트업.
- **색약 보조**: 새 텍스처 없이 프로시저럴 점 2개 — 휠(`RouletteWheel._draw_colorblind_dots`, 포켓 채우기 위 `draw_circle`), 베팅판(`BetBoard._draw_colorblind_dots`, 숫자 토큰·바깥 R 칸).
- **스핀 연출 속도**: `Main._on_spin_started` 가 `wheel.play_spin` 의 duration 에만 곱한다(Economy·GameState 는 그대로).
- **큰 당첨/오토 연출 간략화**: `VisualSettings.full_effects(tier, is_auto_spin)`, `Main.play_tier_effects`/`_big_effects` 에 적용.
- **툴팁 지연**: `TooltipLayer` 에 지연 타이머 추가(취소 토큰 방식 — `SceneTreeTimer` 자체는 취소할 수 없어서).
- 신규 아이콘 2개(`icon_vault`, `icon_warning`, 기존 `gen_ui.py` 파이프라인), 신규 셰이더(`dither_dim.gdshader`).
- 테스트 65개 신규(save_manager 8·offline_income 8·settings_manager 6·settings_screen 4·pause_menu 5·stats_screen 3·return_popup 5, 기존 파일 보강) / 전체 168개·검사 3413개 통과.

**검수 기록(캡처 → 검토 → 개선)**
1. 설정 탭 버튼 2개가 동시에 "눌림" 상태로 보임 → `SettingsScreen.select_tab()` 이 대상 탭만 누르고 나머지를 풀지 않았던 버그(`set_pressed_no_signal` 은 ButtonGroup 의 다른 버튼을 풀지 않음 — TopBar 에 있던 것과 같은 주의사항인데 놓침). 전부 명시적으로 다시 맞추게 수정.
2. 통계 화면 두 단 배치가 "3시간 12분"처럼 넓은 값에서 오른쪽 단 라벨과 겹치고, 오른쪽 단 값은 화면 오른쪽으로 잘림 → 애초에 640px 안에 두 단 라벨+값이 들어갈 공간이 없었다. 한 단짜리 세로 목록으로 재설계(9줄이 세로 공간은 충분히 남았음).
3. 복귀 팝업이 "경과 시간" 자리에 상한이 적용된 시간(예: "2시간 0분")을 보여주고 있었음 → 요청 명세 예시("3시간 12분 (최대 2시간 적용)")는 실제 경과 시간이 머리글이어야 함. `elapsed_seconds` 로 수정.
4. `Main._ready()` 가 `SaveManager.load_game()` 을 부르게 되면서, 컨테이너에 남아있던 실제 `save.json`(이전 테스트가 만든 것)을 `test_main_scene` 이 그대로 불러와 칩이 9억대로 나오는 등 테스트가 깨짐 → `tests/lib/test_case.gd` 공용 `before_each()` 에서 저장 파일을 먼저 지우게 수정(모든 테스트에 적용).
5. `SettingsManager`/`VisualSettings` 필드를 바꾸는 테스트가 자기 값을 원래대로 되돌리지 않아 다른 테스트 파일에 새어나감(예: `scientific_mode=true` 가 남아 업그레이드 카드 숫자가 과학적 표기로 보임) → `SettingsManager.reset_to_defaults()` 를 추가하고 관련 테스트의 `after_each()` 에서 호출.
6. `TooltipLayer` 에 표시 지연을 넣은 뒤 캡처 스크립트의 기존 대기 시간(0.3초)이 지연(0.3초)+페이드(0.1초)보다 짧아져 툴팁이 안 보임 → `_hover_card()`·"tooltip" 시나리오의 대기를 0.5초로.
7. 색약 보조 점이 실제로 그려지는지 확대해서 확인(휠·베팅판 모두 빨강에만 아이보리 점 2개, 검정엔 없음 — 정상).
8. 나머지(설정 5탭 ko/en, 일시정지, 통계, 복귀 팝업, 손상 복구 토스트, 기존 베팅/당첨 연출 회귀)는 이상 없음.

**파일**
- 신규: `scripts/autoload/settings_manager.gd`, `scripts/core/offline_income.gd`, `scenes/ui/{settings_screen,pause_menu,stats_screen,focus_style}.gd`, `scenes/fx/return_popup.gd`, `assets/shaders/dither_dim.gdshader`, `assets/sprites/ui/{icon_vault,icon_warning}.png`
- 수정: `scripts/autoload/{game_state,save_manager,economy,event_bus}.gd`, `scripts/core/{spin_controller,visual_settings}.gd`, `scenes/main/main.gd`, `scenes/ui/{top_bar,tooltip_layer,bet_board}.gd`, `scenes/roulette/roulette_wheel.gd`, `scenes/fx/toast_layer.gd`, `tools/art/gen_ui.py`, `tools/capture/capture.gd`, `project.godot`, `tests/lib/test_case.gd`
- 신규 테스트: `tests/test_{save_manager,offline_income,settings_manager,settings_screen,pause_menu,stats_screen,return_popup}.gd`
- 문서: GDD 15장, ART_BIBLE 10장(신규 화면 레이아웃)·7장(연출 간략화)·에셋 목록, CLAUDE.md(오토로드 순서·폴더 구조·pip 안내)

**남은 이슈**
- `UpgradePanel.mode`(업그레이드창의 STANDARD/MARBLE 탭 선택)는 저장하지 않는다 — 불러오면 항상 기본 탭으로 열린다(요청 명세에 없던 3단계 핸드오프 노트였고, 이번 범위에서는 생략).
- `auto_spin_unlocked()`/`GameState.auto_spin_enabled` 는 자리만 만들어 뒀다 — 6단계가 실제 스킬 해금 조건과 오토 스핀 루프를 연결해야 오프라인 "전체 수익" 모드가 실제로 나온다. 지금은 항상 "팁" 모드만 관찰 가능.
- 설정의 "RESET 입력" 안내처럼 `tr(key) % arg` 로 미리 조합해 둔 라벨(`auto_translate=false`)은 화면을 연 채로 언어를 바꿔도 그 자리에서 다시 조합되지 않는다(화면을 닫고 다시 열면 반영). 대부분의 다른 텍스트는 Godot 기본 번역 갱신으로 즉시 바뀐다.
- 복귀 팝업의 "쏟아진다" 연출은 카운트업 + 코인음까지만 구현했고, 스핀 당첨처럼 상단 바로 날아가는 칩 애니메이션(`FlyingChips`)은 붙이지 않았다(Main 과의 결합을 늘리는 대신 범위를 좁힘). 8단계 폴리시에서 원하면 추가.
- 오디오 미리듣기는 Master/SFX/UI 슬라이더에서만 소리가 난다 — Music 슬라이더는 미리들을 음악 트랙이 아직 없다(8단계에서 음악 자산이 생기면 추가).
- 효과음·셰이더는 여전히 Mesa llvmpipe·더미 오디오 드라이버로만 확인했다(기존 이슈, 이번 단계도 동일 제약).

**다음 단계(5단계)가 알아야 할 것**
- 대출액 공식이 필요로 하는 "최근 5분 평균 초당 순수익"은 이미 `GameState.income_tracker.per_second(GameState.get_stat_value(GameState.STAT_PLAY_TIME))` 로 바로 쓸 수 있다(오프라인 수익과 공용, 새로 만들 필요 없음).
- 빚 자동 상환이 생기면 `ReturnPopup.open(offline, debt_repaid)` 의 둘째 인자에 상환액을 넘기면 "오프라인 중 빚 상환" 문구가 자동으로 뜬다(이미 만들어 둠, 지금은 항상 0).
- 패널티(시간제 StatModifiers 수정자)는 `GameState.add_buff()` 로 걸면 저장·불러오기가 이미 지원한다(`buff:` 소스만 시간제로 왕복). "횟수제"(압류 1스핀, 클로버 수수료 1회) 소모형은 여전히 없음 — 1단계부터 남은 이슈 그대로.
- `debt_changed` 시그널이 발행되면 SaveManager 가 자동 저장한다(이미 연결돼 있음, 5단계는 그냥 발행만 하면 됨).

### 5단계 (2026-09-24) — 빚·래칫 남작·대화 시스템·패널티

**시작 전 정리**: 작업 브랜치(`claude/vibrant-brahmagupta-a6rzeq`)가 1단계 시점에서 분기돼 있어 2~4단계가 빠진 상태였다. GitHub 를 조사해
다른 세션이 1→2→3→4단계를 순서대로 쌓은 `claude/beautiful-franklin-nc1a2i` 브랜치(커밋 `7374674`)를 찾았고, `merge-base
--is-ancestor` 로 내 브랜치에 고유 커밋이 없음을 확인한 뒤 그 지점으로 안전하게 재설정(fast-forward 라 작업 손실 없음)했다.
`bash tools/setup_godot.sh` 로 Godot 4.3 을 설치·재임포트해 **168 tests / 3413 checks, 0 failures** 로 4단계가 정상 종료 상태임을
확인한 뒤 이 문서의 계획대로 5단계를 올렸다.

**한 일**
- **StatModifiers**: `Modifier` 에 `charges`(소모형, -1=무제한) 축 추가, `consume_charges(source_id, amount)`. 압류·클로버 수수료처럼
  "횟수"로 끝나는 효과를 1단계부터 남아 있던 이슈 없이 표현.
- **DebtService**(신규, 순수 로직): `take_loan`(공식 계산 + 3건이면 잔액 최대 빚에 합산), `apply_auto_repay`(오래된 순), `repay_at`,
  `total`, `progress_ratio`.
- **GameState**: `pending_baron_event`(컷신 재개용), `debt_total/has_debt/auto_repay_debt/repay_all/repay_half`, 패널티
  API(`add_penalty_timed/charge`, `remove_penalty`, `consume_penalty_charge`), `penalty_manager` 소유·매 프레임 tick, `add_clovers()`
  최소 1 보정, `check_bankruptcy()` → 즉시 대출 확정 + `pending_baron_event` 채움 → `debt_changed` → `bankrupt` 순서 고정.
- **PenaltyManager**(신규): 6종(WATCHER/PICKPOCKET/SMOKE/BLUR/SEIZE/CLOVER_FEE), 대출 건수별 간격(60~120/45~90/30~60초),
  연속 금지, 구슬 1개면 압류 제외, `EventBus.penalty_triggered` 발행. 소매치기만 `min_bet×3` 바닥 직접 방어(파산 유발 불가 검증).
- **SpinController**: 압류 소모(`start_spin`), 자동 상환(`_apply_outcome` → `last_debt_repaid`).
- **캐릭터 에셋**(`tools/art/gen_baron.py`, 신규): 래칫 남작 월드시트(48×64×7행), 초상화(64×64×7), 부하 쥐(32×40×6), 도장·아이콘
  7종. 4배 미리보기로 4회 반복 수정(아래 검수 기록).
- **대화 시스템**: `data/dialogue/baron.json` + `DialogueData`(로더·변형 랜덤) + `DialogueBox`(초상화·이름표·타자기 30자/초·피치
  블립·즉시완성·▼·선택지 지원, 재사용 가능한 범용 컴포넌트).
- **파산→대출 컷신**: `BaronRatchet`(걷기·인사 등 프레임 재생) + `ContractPopup`(양피지 펼침·서명·도장·칩 토스) +
  `BaronLoanSequence`(오케스트레이터, 대출 횟수별 대사 분기) + `BaronPayoffSequence`(완납 컷신, 클로버 비행).
  `pending_baron_event` 가 남아 있으면 로드 직후 처음부터 재생.
- **패널티 시각효과**: `UnderlingRat` 등장/퇴장, `pickpocket_dash`(그림자 스침), `SmokeOverlay`(연기 오버레이), 구슬 셰이더
  `desaturate`/`suppress_glint` uniform, `BetBoard.play_seizure_stamp()`, `PenaltyToast`(아이콘+이름+진행바+남작 미니 초상).
- **빚 UI**: `TopBar` 두루마리 아이콘+금액(맥동)+상환 진행 바, `DebtPanel`(건별 원금/잔액/진행률 + 전액/절반 상환), 당첨 텍스트
  2줄 분리("+N" 금색 / "−N 상환" 빨강) + 상환분 칩이 `TopBar.debt_target()` 로 비행.
- 신규 효과음 9종(`tools/audio/gen_sfx.py`): 대사 블립, 발소리, 지팡이, 베이스 드롭, 계약서 펼침, 깃펜 서명, 도장, 칩 자루, 소매치기.
- 테스트 86개 신규(핵심 로직 + 연출 컴포넌트 전부) / 전체 **254 tests, 3997 checks, 0 failures**.

**검수 기록(캡처 → 검토 → 개선)** — `tools/capture/capture.gd` 에 5단계 시나리오 12개(남작 등장·대화·계약서·도장·패널티 6종·빚
패널·완납) 추가 후 ko/en 3배 확대본을 직접 본 결과, 실제 버그 5개를 발견해 수정했다:
1. `gen_baron.py` 반복 수정 4회: 모자가 머리 위에 붕 뜸(머리 기하와 무관한 좌표 → 머리 중심·반지름 기준으로 재계산) →
   시가가 안 보임(팔을 머리보다 먼저 그려 입 주변이 덮임 → 머리 그린 뒤 팔을 그리도록 순서 교체) → 외알 안경 "사슬" 장식선이
   지저분함(삭제) → 꼬리가 두 색이라 어깨 쪽이 끊어져 보임(단일 톤으로 통일) → 부하 쥐 선글라스가 시트 전체를 가로지르는 흰 줄로
   보임(`hline` 인자 순서 실수 — 두 번째 인자가 x1 이 아니라 y 값이었음. 수정).
2. 캡처 배치 실행 중 이전 세션이 남긴 `user://save.json` 을 `Main._ready()` 가 그대로 불러와, 파산 컷신 캡처에 오프라인 복귀
   팝업이 겹쳐 뜨고 이전 시나리오의 `pending_baron_event` 가 잘못 재생됨 → `tests/lib/test_case.gd` 와 같은 저장 파일 삭제 로직을
   `capture.gd._fresh()` 에도 추가.
3. 남작 월드 스프라이트(`BARON_Y=340`, 64px)가 `DialogueBox`(y 268~352) 영역 안에 거의 다 들어가 스프라이트와 대사 텍스트가
   겹쳐 보임 → `BARON_Y` 를 258 로 낮춰 대화창 위 10px 여유를 둠(`baron_loan_sequence.gd`/`baron_payoff_sequence.gd` 둘 다).
4. `PenaltyToast` 의 남은시간 진행바가 토스트 전체를 덮는 거대한 단색 사각형으로 보임 → `bar_bg`/`bar`(ColorRect) 를
   `PanelContainer` 의 자식으로 넣은 게 원인(Container 는 직계 자식을 전부 같은 콘텐츠 영역에 맞춰 늘린다 — 1개 자식만 쓰는 게
   정상 용법). `self`(plain Control)의 자식으로 옮기고 패널 위치를 따라가게 수동 배치(`TopBar._debt_bar` 와 같은 방식)해 해결.
5. "시가 연기" 패널티가 화면에서 거의 안 보임 → `smoke.png` 자체가 배경 장식용이라 알파가 이미 낮은데(최대 약 0.27)
   `SmokeOverlay.MAX_ALPHA=0.3` 을 또 곱해 최종 알파가 약 0.08 까지 떨어졌던 것. `MAX_ALPHA` 를 1.3 으로 올려 ART_BIBLE 이 원래
   의도한 "0.35 안팎"에 맞춤(텍스처 자체 알파가 상한이라 여전히 반투명).
6. (이 과정에서 함께 발견) 빚 상환 진행 바가 상단 바 왼쪽(칩 카운터 아래)에 엉뚱하게 그려짐 → `TopBar._process()` 가
   `debt_box.get_rect()`(부모 `box` 기준 로컬 좌표)를 `self` 기준으로 잘못 사용한 것. `Control` 은 `Node2D` 가 아니라
   `to_local()` 이 없어, 전역 좌표 차이(`get_global_rect().position` 뺄셈)로 바꿔 해결.
7. 위 5건을 고치고 254 tests / 3997 checks 로 회귀 없음을 재확인한 뒤 12개 시나리오를 ko/en 다시 캡처 — 계약서·도장·패널티
   6종·빚 패널·완납 모두 텍스트 넘침/잘림 없이 정상, 부하 쥐·압류 도장·흐려진 구슬(그레이 필터)도 확대해 확인 완료.

**파일**
- 신규 core: `scripts/core/{debt_service,penalty_manager,dialogue_data}.gd`
- 신규 scenes: `scenes/ui/{dialogue_box,contract_popup,debt_panel,penalty_toast}.gd`, `scenes/npc/{baron_ratchet,underling_rat}.gd`,
  `scenes/fx/{baron_loan_sequence,baron_payoff_sequence,pickpocket_dash,smoke_overlay}.gd`
- 신규 데이터·에셋: `data/dialogue/baron.json`, `tools/art/gen_baron.py`, `assets/sprites/npc/{baron_world,baron_portrait,
  underling_rat}.png`, `assets/sprites/ui/icon_{debt,baron_mini,penalty_watcher,penalty_pickpocket,penalty_smoke,penalty_blur,
  penalty_seize}.png`, `assets/sprites/fx/seizure_stamp.png`, 신규 sfx 9종(`assets/audio/sfx/*.wav`)
- 수정: `scripts/core/{stat_modifiers,spin_controller}.gd`, `scripts/autoload/{game_state,economy,event_bus,audio_manager}.gd`,
  `scripts/roulette/marble_sprite.gd`, `assets/shaders/marble.gdshader`, `scenes/ui/{bet_board,top_bar}.gd`, `scenes/main/main.gd`,
  `tools/audio/gen_sfx.py`, `tools/capture/capture.gd`, `translations/strings.csv`
- 신규 테스트: `tests/test_{debt_service,penalty_manager,dialogue_data,dialogue_box,baron_ratchet,contract_popup,
  baron_loan_sequence,baron_payoff_sequence,penalty_toast,debt_panel}.gd`
- 수정 테스트: `tests/test_{stat_modifiers,game_state,spin_controller,save_manager}.gd`
- 문서: GDD 9장 확정 + 16장(신규), ART_BIBLE 11장(신규) + 에셋 목록(패널티 아이콘 5종 누락분 포함 정정), PROGRESS(이 항목)

**남은 이슈**
- BIG 이상 당첨 연출·오토스핀 중 패널티 억제는 넣지 않았다(대화창·계약서 팝업 동안만 `PenaltyManager.suppressed` 를 세움) —
  발생 빈도가 낮아 이번 범위에서 제외(GDD 16장에 명시).
- 남작 컷신 중 음악 볼륨 덕킹은 스킵했다 — 음악 시스템 자체가 아직 없음(8단계 예정). 대신 `bass_drop` 효과음으로 파산 순간을 표현.
- `ContractPopup` 의 양피지는 별도 이미지 자산이 아니라 `_draw()` 로 그린다(ART_BIBLE 에 이미 정정 반영) — 너무 단순한 모양이라
  9-slice 텍스처보다 절차적 드로잉이 더 간단했다.
- 효과음·셰이더는 여전히 Mesa llvmpipe·더미 오디오 드라이버로만 확인했다(기존 이슈, 이번 단계도 동일 제약).

**다음 단계(6단계)가 알아야 할 것**
- 소모형(charges) 수정자가 이제 있다(`StatModifiers.add_modifier(..., charges=N)` / `consume_charges()`) — 스킬트리의 "1회성"
  효과(있다면)에 바로 쓸 수 있다.
- 패널티는 `penalty:` 접두어 시간제/소모형 수정자 + `buff_started`/`buff_ended`/`penalty_triggered` 조합으로 구현했다 — 스킬
  버프도 같은 패턴(`buff:` 접두어)을 그대로 따르면 저장/복원·UI 토스트까지 자동으로 맞는다.
- `GameState.penalty_manager`(RefCounted, `process(delta)` 소유) 처럼 매 프레임 로직이 필요한 새 시스템은 오토로드를 늘리지
  않고 GameState 가 소유해 tick 하는 기존 패턴(income_tracker·modifiers 와 동일)을 계속 따르면 된다.
- **Container 함정**: `PanelContainer`/`HBoxContainer` 등 Container 계열에 자식을 2개 이상 직접 넣으면 전부 같은 콘텐츠
  영역에 맞춰 강제로 늘어난다(정상 용법은 자식 1개). 진행바처럼 수동으로 위치·크기를 제어해야 하는 요소는 Container 밖에
  두거나 plain `Control` 로 한 번 감싸야 한다(이번 단계에서 `PenaltyToast` 가 이 함정에 걸렸다).
- **`Control` 은 `to_local()`/`to_global()` 이 없다**(그건 `Node2D` 전용). Control 트리에서 어떤 자손의 위치를 다른 조상
  기준 로컬 좌표로 바꾸려면 `get_global_rect().position` 끼리 빼면 된다(회전·스케일이 없는 UI 한정 — 이 프로젝트의 모든
  UI 가 여기 해당).
- `debt_target()`/`chip_target()` 처럼 "살아있는 UI 요소의 현재 위치"를 비행 목적지로 쓰는 패턴(`TopBar` 참고)은 별도
  스프라이트 자산을 안 만들어도 되므로, 스킬트리의 클로버 비행 등에도 그대로 재사용할 수 있다.

### 6단계 진행 중 (2026-09-24) — 1/N: 로직 기반·스킬 데이터 57개

**시작 전 정리**: 작업 브랜치(`claude/friendly-meitner-1ay0i9`)에는 1단계 커밋만 있었다. GitHub 를 조사해 다른 세션이
1→2→3→4→5단계를 순서대로 쌓은 `claude/vibrant-brahmagupta-a6rzeq` 브랜치(커밋 `1a801a9`)를 찾았고, 고유 커밋이 없음을
확인한 뒤 그 지점으로 안전하게 재설정했다. `bash tools/setup_godot.sh` 로 Godot 4.3 설치 후 **254 tests, 3997 checks,
0 failures** 로 5단계가 정상 종료 상태임을 확인한 뒤 이 문서의 계획대로 6단계를 시작했다. 작업량이 매우 많아 하위
작업 단위로 커밋을 나눈다(이 커밋은 1번째: 눈에 보이는 연출 없이 로직·데이터만).

**한 일**
- **StatModifiers**: 6단계 스탯 21종 추가(GDD 11-4 표 참고). 새 조회 함수 `charges_remaining(source_id)`.
- **SkillNodeDef 재설계**: `effect_stat/op/per_level`(단일) → `effects: Array[Dictionary]`(노드 하나가 여러 스탯 동시
  적용 가능, 예: M2 는 spin_delay ADD + spin_duration_mult MULT). `prerequisites`+`prerequisite_mode`(ALL/ANY) 로
  "A|B"·"A&B" 표기를 표현. `is_heart()`(costs 비어있음=처음부터 보유), `cumulative_cost()`.
- **SkillService**(신규, `UpgradeService` 와 동형): `level/is_owned/feature_level/has_feature`, `prerequisites_met`,
  `lock_status`, `purchase`(클로버 차감 → `GameState.set_skill_level` → `skill_purchased` 발행), `invested_total/
  grand_total`, `any_affordable`.
- **GameState**: `set_skill_level`/`rebuild_skill_modifiers`(업그레이드와 동일 패턴, 저장/불러오기 후 SaveManager 가
  호출), `auto_spin_unlocked()` 가 이제 `SkillService.has_feature("auto_spin")` 을 본다. `add_buff()` 에 `charges` 인자와
  `Y13(buff_duration_mult)` 자동 반영 추가. `build_spin_context()` 확장: 제로 가드·핫넘버·럭키세븐·제로축복·이중적중·
  캐시백·연승 보너스(F5+F11)·복리의 마법(E14, 현재 상태 비례라 매 스핀 재계산)·황금 폭풍(golden_pockets 를 37개로
  덮어씀). `hot_numbers()`(최근 20스핀 최다 3개, 동률은 최근 것). 새 필드: 스마트 베팅 전략, 오토 업그레이드 설정,
  채무 관리인 토글, 황금 폭풍/저금통/피버/비상금/운명의 휠 상태(전부 to_dict/from_dict 에 포함).
- **RouletteRules**: `win_multiplier` 에 핫넘버·럭키세븐(7·17·27)·제로의 축복 곱연산 추가. `resolve()` 에 제로 가드·
  캐시백(결정론적이라 순수 함수 안에서 처리) 과 이중 적중 보너스(승리 개수 확정 후 일괄 곱) 추가. `SpinOutcome.
  BetResult.refunded/pushed()`(무승부 표시, 당첨은 아님).
- **SpinController**: `_resolve_with_specials()`(운명 뒤집기 Y8 — 전패 시 misc RNG 로 재판정하되 "유리할 때만" 채택,
  RouletteRules 는 순수하게 유지) → `_apply_mirror()`(미러 Y3, 확률적 무승부) 순서로 오케스트레이션. `_apply_outcome`
  뒤에 잭팟 체인(F14, 소모는 보유 여부와 무관하게 버프가 있으면 항상 진행 — 운명의 휠도 같은 버프를 걸 수 있어서)·
  VIP 컴프·피버 타임(스핀 카운터)·황금 폭풍 발동 판정·황금 저금통(100스핀 정산) 을 붙였다.
- **UpgradeService**: `growth_of(def)`(도매가 E12 가 곱하는 성장률), 재질 비용에 `marble_cost_mult`(E8), 오토
  업그레이드용 `cheapest_affordable_id(budget, include_marble)`.
- **DebtService**: `forgive_ratio()`(운명의 휠 "빚 탕감" — 상환과 달리 칩을 안 쓴다), `apply_auto_repay` 에 `rate`
  인자(채무 관리인 M13 의 25%/50% 선택).
- **OfflineIncome**: 휴식 보상(M9) 클로버 계산(`clover_hours_per_unit`), `ReturnPopup` 에 클로버 줄 추가.
- **신규 core 서비스**: `ProphecyService`(예지 Y2 색 힌트 정확도 60/67/75%, 천리안 Y9 후보 3개 — 전부 misc RNG,
  통계 테스트 가능), `SmartBettingService`(M6 전략 4종의 베팅 구성 + 마틴게일 칩 크기 단계), `WheelOfFortuneService`
  (Y14 8칸 굴리기·지급).
- **데이터**: `tools/data/generate_skill_data.gd`(신규) 로 노드 57개 생성 — 위치는 갈래 중심각 ±40° 안에서 고리별
  균등 분포로 계산(수동 좌표 없음). 스크립트 자체가 총비용 269 를 검증하고 어긋나면 `push_error`.
- **번역**: `SKILL_*`(이름+설명 57×2), 운명의 휠 8칸, 비상금·휴식 보상 토스트 키 추가.
- 테스트: `tests/test_skill_service.gd`(신규, 15개 — 데이터 무결성·선행조건 ALL/ANY·구매·효과 적용(복리 검증)·
  feature_level·저장/불러오기 왕복). `test_data.gd` 의 황금 포켓 상한 검사를 `GOLDEN_POCKET_UPGRADE_MAX_LEVEL`(5, 스킬
  Y4 포함 전체 상한은 `GOLDEN_POCKET_MAX`=8) 기준으로 수정.
- 전체 **269 tests, 4565 checks, 0 failures**(기존 254개 전부 그대로 통과 + 신규 15개).

**설계 결정(GDD 6장·6-1·6-2 에 반영)**
- 효과 수치 표기(+%/×N/절대값) → ADD/MULT 변환 규칙을 표로 확정(GDD 6-1). 예외 1건(E7 패널티 빈도, 간격의
  역수라서 MULT 로 환산)만 주석으로 표시.
- 고리는 "선행조건 단계"가 아니라 "시각적 반지름"이다 — 갈래마다 1링4·2링5·3링4·궁극기1 로 고정하고, 같은 링 안의
  노드가 서로 선행조건인 경우도 허용한다(예: Y13 은 같은 3링인 Y11 이 선행조건).
- 잭팟 체인 버프는 F14 전용이 아니라 `buff:jackpot_chain` 공용 버프로 만들어 운명의 휠(Y14) 이 재사용한다(스킬
  보유와 무관하게 버프가 있으면 소모된다).

**남은 이슈**
- 이번 커밋에는 화면 요소가 전혀 없다(GDD·테스트로만 검증). 다음 커밋부터 클로버 연출 → 스킬트리 화면 →
  자동화 UI → 특수 기능 연출 → 딜러 루시 순서로 눈에 보이는 부분을 만든다.
- 스마트 베팅·오토 업그레이드·비상금·운명의 휠 타이머는 로직만 있고 아직 아무도 호출하지 않는다(Main 이 다음
  커밋에서 연결). 지금 스킬을 사도 화면에는 아무 변화가 없다(수정자는 정상 적용됨 — 테스트로 확인됨).
- 구슬 재질 임시 상승(운명의 휠)은 수치(marble_mult 배율)만 구현했고, 휠·베팅판의 "보이는" 재질 색까지 5분간
  바꾸는 것은 시각 자산 작업 때 추가로 검토한다(MarbleSprite 공유 머티리얼이 전역이라 임시 오버레이가 더 필요).

**다음 작업이 알아야 할 것**
- `SkillService.purchase(id)` 하나로 구매가 끝난다(클로버 차감+효과 적용+이벤트 발행까지). UI 는 `lock_status`/
  `can_purchase`/`is_locked`/`is_maxed` 로 버튼 상태만 그리면 된다.
- `GameData.skills()`/`GameData.skill(id)` 로 57개 노드에 접근(이미 `data/skills/*.tres` 로 저장돼 있음).
- 스킬트리 화면은 `Main.skill_overlay`(현재 `PlaceholderScreen`)를 실제 화면으로 교체하면 된다. 여는 방식만
  `PanelTransition` 대신 아이리스 와이프로 바꿔야 한다(`Main._toggle_overlay` 에서 skill_overlay 만 분기).
- 오토 스핀은 `Main` 에 `_process` 가 없으므로 새로 추가해야 한다(`GameState.get_stat(SPIN_DELAY, ...)` 로 대기
  시간을 재고, `controller.start_spin()` 을 직접 부른다 — `request_spin()` 의 스킵 로직은 오토에는 안 맞는다).

### 6단계 진행 중 (2026-09-24) — 2/N: 화면·연출·자동화·특수 기능·루시 (기능 완료)

**한 일**
- **에셋**: `tools/art/gen_skills.py`(스킬 아이콘 57개+heart, 배지+글리프, 고대비 재검수 완료), `tools/art/gen_lucy.py`
  (루시 초상화 64×64×7·월드 40×56), `tools/audio/gen_sfx.py` 9종 추가, `assets/shaders/iris_wipe.gdshader`.
- **딜러 루시 그림 버그 수정**: 원래 코드가 "이마 노출" 타원을 이목구비보다 나중에, 그것도 이목구비 전체를 덮을
  만큼 크게 그려서 눈·눈썹·입을 살빛으로 지워버렸다(머리카락이 살구색으로 보이고 7개 표정이 다 비슷해 보인 원인).
  머리를 뒤(얼굴보다 먼저)/앞(이목구비보다 나중, 눈썹보다 위에서 멈춤) 두 레이어로 나누고, 눈썹은 앞머리보다도
  더 나중에 그려 반올림 경계에서 같은 색으로 겹쳐 안 보이는 문제까지 잡았다. 4× 확대로 재검수 완료.
- **스킬트리 화면**(`scenes/skilltree/skill_tree_view.gd`+`skill_tree_screen.gd`, 신규): 팬(관성)·휠 줌 1×/2×·
  노드 4상태·점선/실선+에너지 점 연결선·0.4초 홀드 구매(폭발+차임+연쇄 반짝임)·키보드/패드 포커스 이동은 뷰가,
  헤더(클로버 보유/투자·중앙 버튼)·색깔 있는 커스텀 툴팁(RichTextLabel, 효과는 초록·미충족 선행조건은 빨강)·
  구석 미니 알림(뒤에서 계속되는 스핀 결과)·아이리스 와이프 열기/닫기는 화면이 맡는다.
  **중대 버그와 수정**: `CanvasGroup` 에 셰이더를 걸고 `TEXTURE`/`UV`(또는 사전 채워진 `COLOR`) 로 합성 결과를
  읽으면 흰 화면만 나온다 — CanvasGroup 은 자기 텍스처가 없어 그 내장 변수들이 채워지지 않는다. 올바른 방법은
  `uniform sampler2D x : hint_screen_texture` + `SCREEN_UV` 로 읽는 것(진단용 최소 재현 스크립트로 확인 후 수정).
  또한 `SkillTreeView._draw_background()` 가 불투명 배경을 안 그려서(별가루·광원 고리만 그림) 뒤쪽 휠·베팅판이
  비쳐 보였다 — 맨 처음에 `Palette.NIGHT` 불투명 사각형을 추가해 고쳤다. 스크린샷으로 직접 확인.
  `Main._toggle_overlay/_close_overlay` 는 `skill_overlay` 일 때만 아이리스 와이프로 분기한다.
- **클로버 연출**: `EventBus.streak_clover_earned`/`first_clover_earned` 신규 시그널. 스트레이트 적중(기존)·5연승·
  칩 마일스톤(+3) 전부 `FlyingChips`(곡선 비행+카운터 1px 튐+"딩")로 상단 클로버로 날아간다. `GameState.
  first_clover_seen`(저장됨) 이 처음 true 가 되는 순간 `TopBar` 자물쇠가 사라지며 금색 플래시(`SpinControls` 의
  오토 스핀 해금과 같은 패턴) + 루시가 `data/dialogue/lucy.json`("skilltree_unlock" 3변형) 으로 한 마디 한다.
- **딜러 루시 통합**: `scenes/npc/lucy_dealer.gd`(월드 액터, BaronRatchet 과 동형: idle/spin_launch/clap/point).
  `DialogueBox` 를 화자별(`SPEAKERS` 맵: 시트+표정 프레임+목소리)로 일반화해 루시도 같은 컴포넌트를 쓴다.
  **주의**: 실제 해금 조건은 처음에 "dealer_lucy" 로 추측해 틀렸었다 — 실제 데이터는 M14(마스터 오토메이션
  궁극기)의 `feature_id`가 `"dealer_hired"`("루시가 테이블을 운영한다")였다. `SkillService.has_feature()` 문자열은
  항상 `tools/data/generate_skill_data.gd` 원본과 대조 확인해야 한다(피버·잭팟체인 등 8개는 처음부터 맞았음).
  스핀 시작마다 공 던지는 시늉, BIG/JACKPOT 에 박수. `ReturnPopup` 의 "임시 아이콘"은 이미 루시 초상화 경로를
  보고 있었지만 7프레임 시트를 통째로 눌러 담아 깨져 보이는 버그가 있어 `AtlasTexture` 로 첫 프레임만 잘라 쓰게
  고쳤다. **point 포즈는 아직 아무 데도 안 걸었다**(스프라이트는 있음, 트리거 없음 — 후속 다듬기 과제).
- **자동화 3종**: 오토 스핀(`SpinControls` 자물쇠·초록 색조·다음 스핀 게이지, `RouletteWheel.set_auto_indicator`
  초록 링, `Main._process` 루프, `EventBus.auto_spin_stopped` 사유별 토스트) / 스마트 베팅(`BetPanel` 제목 자리에
  전략 드롭다운, 매 오토 스핀 전 `SmartBettingService.compute_bets()` 로 판을 다시 짜 `GameState.clear_bets/add_bet`
  만 호출해도 `BetBoard._on_bets_changed()` 가 알아서 배치 애니메이션을 재생 — 별도 연출 코드 불필요) / 오토
  업그레이드(`UpgradePanel` 제목 자리에 토글+슬라이더, `UpgradeService.cheapest_affordable_id()` + 기존
  `UpgradePanel.buy()` 재사용으로 카드 플래시·소리까지 공짜로 따라옴).
- **특수 기능 8종**: 예지(`ProphecyOrb`, 휠 위 작은 구슬, RngService.peek_next 는 스핀 정산마다 딱 한 번만 캐싱)
  / 핫넘버(`BetBoard` 에 불꽃 아이콘, 좌우로 살짝 흔들림) / 피버(상단바 아래 무지개 예열 게이지 + "FEVER!" 배너 +
  휠 포켓 색 실시간 무지개 순환(값 보간으로 부드럽게 복귀)) / 잭팟체인(휠 테두리 번개 + 남은 스핀 수 라벨) /
  운명뒤집기(EventBus 시그널을 받아 "운명 역전!" 텍스트+효과음 — 포켓 사이로 튀는 애니메이션까지는 못 만들었다,
  최종 결과가 이미 정답이라 시각적으로는 텍스트/사운드만으로도 의미는 전달됨) / 더블볼(두 번째 공만 보라 궤적으로
  구분 — 결과 2개 정산·배지 2개 나란히는 스테이지 2 인프라가 이미 다 하고 있었다, `ball_count()`↔`EXTRA_BALLS`
  연결도 이미 있었음) / 황금저금통(`PiggyBankWidget`, 베팅창 구석, 100스핀 진행도 채워지다 깨지는 순간 골드 파열)
  / 운명의 휠(`WheelOfFortunePopup` 8칸 회전판, `TopBar` 클로버 아이콘 둘레 보라 링으로 10분 타이머 표시, 클릭 또는
  오토 모드면 5초 뒤 자동 회전) / 버프 바(`BuffBar`, 상단바 아래, 활성 buff:* 소스를 원형 게이지+호버 설명으로).
  새 스프라이트 없이 팔레트 색 직접 그리기로 시간 절약(피기뱅크·버프 아이콘·예지 구슬·번개 전부 `draw_*`).
- **버그 두 건 더**: `PiggyBankWidget` 도 "piggy_bank" 라는 존재하지 않는 feature 문자열을 체크하고 있었다 — E13 은
  feature_id 없이 `PIGGY_BANK_RATE` 스탯만 주므로 그 값(>0)으로 게이트하도록 수정. `SpinControls.set_auto_locked()`
  를 메서드로 안 부르고 필드(`auto_locked = ...`)를 직접 대입한 곳이 있어(불러오기 등으로 이미 해금된 상태를 처음
  맞출 때) 자물쇠 아이콘이 안 지워지는 버그 — `play_effects` 매개변수를 추가해(불러오기는 소리 없이 조용히 갱신)
  메서드 호출로 통일.
- **테스트 신규**: `tests/test_prophecy_service.gd`(레벨별 정확도 60/67/75% 를 10,000회로 통계 검증, 천리안 후보
  포함 확률 50%), `tests/test_double_ball.gd`(공 여러 개 판정 시 적중마다 배당 누적·베팅액은 한 번만, `ball_count()`
  가 `extra_balls` 반영, `SpinController.start_spin()` 이 공 개수만큼 결과 생성), `tests/test_destiny_flip.gd`
  (이미 이겼으면 절대 재판정 안 함, **500회 반복으로 재판정 후 반환액이 원래보다 작아지는 일이 절대 없음을 확인**,
  뒤집힌 결과는 항상 이웃 포켓, 확률 0이면 재판정 없음). `test_dialogue_data.gd` 에 "skilltree_unlock" 키 검증 추가.
  전체 **285 tests, 7889 checks, 0 failures**.
- 번역 키 약 40개 추가(자동화·특수 기능 토스트/툴팁/전략 이름·브랜치 이름·스킬트리 헤더 등).

**남은 이슈(후속 다듬기 과제로 남김)**
- 루시 "point" 포즈: 스프라이트는 있으나 아무 이벤트에도 연결 안 함(핫넘버 적중 등에 걸면 자연스러움).
- 피버 타임의 "추가 빠른 드럼 레이어" 는 만들지 않음(배너·무지개 셰이더·게이지·복귀는 구현).
- 운명 뒤집기의 "포켓 사이로 튀는" 물리적 바운스 애니메이션은 생략(텍스트+효과음으로 대체) — 실제 결과는 이미
  최종값이라 휠이 정확한 포켓에 착지하므로 게임플레이엔 영향 없음, 순수 디테일 폴리시 항목.
- 캡처 스크린샷: `tools/capture/capture.gd` 의 기존 "skilltree"/"multi_ball" 시나리오로 정상 렌더링을 확인했지만,
  이번에 추가한 8개 특수 기능(피버 발동 순간·잭팟체인 번개·운명의 휠 팝업·버프 바 등)은 시나리오를 새로 안 만들고
  임시 진단 스크립트(스크립트는 저장 안 함)로 정적 상태(스킬 레벨을 직접 주입)만 확인했다 — **애니메이션 타이밍**
  (피버 배너 등장, 번개 지속시간, 팝업 스핀-랜딩)은 코드 리뷰로만 검증했고 실제 재생은 보지 못했다. 다음 세션에서
  `capture.gd` 에 시나리오를 추가해 직접 재생 검수를 권장.
- 위에서 발견한 "feature 문자열은 반드시 `generate_skill_data.gd` 원본과 대조" 교훈은 스탯 이름(`StatModifiers.*`)
  에도 동일하게 적용된다 — 이번엔 문제 없었지만 다음 단계에서도 같은 방식으로 재확인할 것.

**다음 작업이 알아야 할 것**
- 스테이지 6은 기능적으로 완료됐다(테스트 285개 전부 통과, 핵심 화면인 스킬트리는 스크린샷으로 직접 확인). 남은
  건 위 "남은 이슈" 의 폴리시 항목뿐이라 7단계(층 진행·엔딩·업적)로 넘어가도 안전하다.
- 새 UI 요소(BuffBar/ProphecyOrb/FeverGauge/PiggyBankWidget)는 전부 절차적 드로잉(`draw_*`)이라 스프라이트 자산이
  없다 — ART_BIBLE 관점에서 "정식 아이콘"으로 다듬고 싶다면 `tools/art/gen_skills.py` 패턴(배지+글리프)을
  재사용해 8단계 폴리시 패스 때 교체하면 된다.

### 7단계 진행 중 (2026-09-24) — 1/N: 층 이동·엔딩·업적 로직 기반

**시작 전 정리**: 이번 세션이 배정받은 작업 브랜치(`claude/tender-goldberg-scqis9`)에는 1단계 커밋만 있었다(6단계까지
쌓은 다른 세션들의 브랜치가 여럿 있었지만 전부 별도 브랜치였고, GitHub 에 병합된 PR 은 없었다). GitHub 브랜치를 조사해
1→2→3→4→5→6(3커밋)단계를 순서대로 쌓은 `claude/friendly-meitner-1ay0i9`(커밋 `22728e9`)를 찾았고, 이 세션 브랜치에는
그 지점 이후로 고유 커밋이 없음을 확인한 뒤 그 지점으로 안전하게 재설정했다. `godot --headless -s tests/run_tests.gd` 로
**285 tests, 7889 checks, 0 failures** 를 확인한 뒤(6단계가 정상 종료 상태) 이 문서의 계획대로 7단계를 시작했다.
작업량이 매우 많아 6단계처럼 하위 작업 단위로 커밋을 나눈다(이 커밋은 1번째: 화면 없이 로직·데이터만).

**층 데이터 재조정**: 이번 요청 명세(당첨 배율 ×1/×10/×1K/×100K/×10M, 1F/2F/3F 구슬 상한 금/루비/흑요석)가 1단계
초안(GDD 7장, ×1/×2/×4/×8/×16, 상한 옥/에메랄드/별빛)과 달라서 요청 명세로 교체했다(둘 다 "초안 — 9단계에서 조정"
이라 명시돼 있었다). 이동 비용(1M/1T/1Sx/1No)·베팅 배율(×100/×10K/×1M/×100M)·클로버 보상(+10)·PH 상한(코스믹)·
`golden_pocket` 업그레이드의 `required_floor=2`(2F 해금)는 1단계 값이 요청과 이미 일치해 그대로 뒀다. `GDD.md` 5·7·10·
11·17장, `data/floors/*.tres` 4개를 갱신했다. `test_data.gd::test_floors()` 는 배율 단조증가·PH 전체 재질만 검사해서
영향받지 않았고, `UpgradeCard._lock_text()`("다음 층에서 해금")는 이미 3단계에 구현돼 있어 손대지 않았다.

**한 일**
- **`FloorService`**(신규, `UpgradeService` 와 동형인 static 클래스): `next_floor_def/is_max_floor/progress/can_move/
  move_to_next`. `move_to_next()` 가 `spend_chips`→`floor_index` 갱신→`add_clovers`→`EventBus.floor_changed` 순서로
  처리(리셋 없음). `progress()` 는 상단 바 진행률 바용(2/N).
- **`EndingService`**(신규): `can_trigger()`(PH+1Dc+아직 안 봄) / `trigger()`(칩 소모 → `GameState.ending_reached=true`
  → `EventBus.ending_triggered`) / `enter_infinite_mode()`(`GameState.infinite_mode=true` → `payout_mult_all` 영구
  ×2 수정자 `ending:owner_mode`, 멱등). `GameState.rebuild_ending_modifiers()`(`rebuild_upgrade_modifiers` 와 동형)를
  `SaveManager.load_game()` 이 불러오기 뒤 호출해 재적용한다.
- **`AchievementManager`**(신규, `GameState.achievement_manager` 가 소유, `PenaltyManager` 와 동형): `attach()` 로
  `EventBus`(`spin_resolved/debt_changed/floor_changed/upgrade_purchased/skill_purchased/buff_started/chips_changed/
  bankrupt/ending_triggered`) 를 구독해 조건을 코드로 판정하고 `process(delta)` 로 "1시간 무파산" 만 시간으로 잰다.
  `data/achievements.json`(신규, `DialogueData` 와 동형 로더 `AchievementData`)은 표시용 메타(id·category·name_key·
  desc_key·icon·hidden)만 담고, 조건은 전부 `AchievementManager` 코드에 있다.
- **업적 30개**: 요청 명세를 항목별로 세면 27개라("누적 스핀 1000/10000"을 2개로 세어도), 진행·기능 카테고리에
  "2F 도달"·"3F 도달"·"첫 황금 포켓 적중" 3개를 더해 30개를 맞췄다(GDD 10-3, 새 시스템 의존 없이 구현 가능).
  더블 볼 "둘 다 적중"은 `SpinOutcome.BetResult.hit_count` 가 공 두 개를 합산해 버려 공별로 못 나누므로, 결과 배열의
  두 숫자 각각에 순수 함수 `RouletteRules.bet_wins(bet, number)` 를 다시 적용해 판정했다(새 상태 없이 기존 함수 재사용).
  숨김 업적 "벨벳 대사 전부 보기"는 `AchievementManager.mark_dialogue_seen(key, index)` 인터페이스만 만들었다(호출부는
  마담 벨벳 화면이 있는 3/N) — 테스트는 기존 대사 키(`debt_paid`, 3변형)를 빌려 직접 호출로 검증했다.
- **`GameState`**: `unlocked_achievements`(Array[String])·`achievement_dialogue_seen`(Dictionary)·`ending_reached`·
  `infinite_mode` 필드 + `to_dict()/from_dict()` 왕복, `achievement_manager.attach()`(_ready)·`process()`(_process).
- **`SaveManager`**: `load_game()` 뒤 `rebuild_ending_modifiers()` 추가 호출. 오프라인 복귀 시(`last_load_offline.
  eligible`) `GameState.achievement_manager.check_offline_hours(elapsed_seconds)` 호출("오프라인 8시간" 업적).
  `ending_triggered`/`infinite_mode_started` 도 즉시 저장 트리거 목록에 추가(업그레이드·스킬·층 이동·빚 변화와 동일).
- **`Economy`**: `OWNER_MODE_PAYOUT_MULT`(2.0), `ACHIEVEMENT_*` 상수 5개(무파산 시간·오프라인 시간·누적 칩·누적 스핀
  2종) 추가.
- **`EventBus`**: `achievement_unlocked(id)`·`ending_triggered()`·`infinite_mode_started()` 신규 시그널.
- **테스트 신규**: `tests/test_floor_service.gd`(7)·`tests/test_ending_service.gd`(5)·`tests/test_achievement_manager.gd`
  (18, 데이터 무결성 30개 전수 검사 + 조건 30종 대부분을 직접 `EventBus` 신호를 발행해 검증 — 스킬 50/100% 는 실제
  57개 노드를 하나씩 최대로 올리며 문턱을 직접 넘겨 데이터 값에 의존하지 않게 짰다). 전체 **315 tests, 8321 checks,
  0 failures**.
- 번역 키 60개 추가(업적 이름·설명 30×2). `godot --headless --import` 로 클래스 캐시·번역 재생성(새 `class_name`
  스크립트 4개가 캐시에 없으면 파싱 에러가 나므로 파일 추가 뒤 반드시 다시 돌려야 했다).

**남은 이슈**
- 이번 커밋에는 화면 요소가 전혀 없다(로직·데이터·테스트로만 검증). 다음 커밋(2/N)부터 층별 배경 4종·휠 스킨 5종·
  엘리베이터 UI·컷신을 만들고, 3/N 에서 마담 벨벳·최후의 스핀·크레딧·업적 토스트/목록 화면을 붙인다.
- `EndingService.trigger()`·`FloorService.move_to_next()`는 로직만 있고 아무 화면도 아직 호출하지 않는다(지금 PH 에서
  1Dc 를 채워도 화면엔 아무 버튼도 없다 — 3/N 이 연결).
- 업적 아이콘(24px)은 `data/achievements.json` 에 id 문자열만 있고 실제 스프라이트는 없다(3/N 에서 `tools/art/
  gen_skills.py` 패턴(배지+글리프)으로 30종 생성 예정).
- "1시간 무파산" 타이머는 `PenaltyManager.time_left` 와 같은 수준으로 단순화했다 — 불러오기 뒤에는 처음부터 다시
  잰다(저장하지 않음). 정밀하게 이어가려면 GameState.to_dict 에 타이머 값도 저장해야 하지만, 파산 방지 업적 하나를
  위해 저장 포맷을 늘리는 비용이 커 보류했다.

**다음 작업(2/N)이 알아야 할 것**
- `FloorService.progress()`(0~1)를 `TopBar` 의 층 이름 라벨 아래 진행률 바에 쓰면 된다(빚 진행 바와 같은 수동 배치
  패턴 — `TopBar._debt_bar_bg/_debt_bar` 참고). 90% 이상이면 빛나는 연출은 화면 쪽에서 새로 만들어야 한다.
- 엘리베이터 버튼(휠 오른쪽 위, 맥동)은 `FloorService.can_move()` 로 표시 여부를 정하고, 눌리면 확인 팝업 → 컷신 →
  `FloorService.move_to_next()` 순서로 호출하면 수치는 끝난다(연출만 새로 만들면 됨).
- 휠 스킨은 `scenes/roulette/roulette_wheel.gd` 의 Shadow/Base/Top/Highlight/Hub/Knob 이 `tools/art/gen_wheel.py` 가
  만든 단일 텍스처 세트를 쓰고 있고, 포켓 링·터렛은 `Palette` 색을 코드에서 직접 읽어 `_draw()` 한다 — 층별 스킨은
  (1) `gen_wheel.py` 를 층별 팔레트로 파라미터화해 텍스처 세트를 층 수만큼 만들고 (2) `RouletteWheel` 에 그 텍스처를
  스왑하는 `set_floor_skin(floor_index)` 를 추가하고 포켓 링 색도 층별로 바꿀 방법이 필요하다(현재는 `Palette` 상수
  고정 참조).
- 배경은 `scenes/main/bg/background_b1.gd` + `tools/art/gen_bg.py` 가 이미 있는 구성(벽·테이블·램프·빛 웅덩이·연기·
  비네트, 레이어형 Node2D + 가산 블렌딩 스프라이트)을 그대로 복제해 층별로 채색·소재만 바꾸면 된다(파일 헤더 주석에
  "층마다 같은 파일 구성을 따르면 7단계에서 배경 씬만 바꿔 끼울 수 있다" 고 이미 적혀 있었다).
- AudioManager 는 `play_music()` 가 8단계용 스텁(`pass`) 이라 실제 음원·크로스페이드는 없다 — 2/N 에서는 "층별 BGM
  id 슬롯"만 연결(예: `FloorDef` 에 `music_id` 필드 추가하고 `floor_changed` 때 `AudioManager.play_music(id)` 호출)
  하고, 실제로 들리는 재생은 8단계 몫이다.

### 7단계 진행 중 (2026-09-24) — 2/N: 층별 배경·휠 스킨·엘리베이터 UI·컷신

**한 일**
- **휠 스킨 5종**: `tools/art/gen_wheel.py` 를 `THEMES` 딕셔너리(층 id → "wood" 4색 램프·"gold" 5색 램프·
  `cone_center`·`gloss`·`grain_accent`·`rivets`)로 다시 짜서 기존 기하(반지름·볼트·디플렉터 위치)는 그대로 두고
  색만 바꿔 5테마를 한 번에 굽는다. B1 출력이 기존 파일과 바이트 단위로 같은지 `cmp` 로 확인한 뒤에야 루트의
  `assets/sprites/wheel/wheel_*.png` 를 지우고 `assets/sprites/wheel/<층 id>/` 로 옮겼다. 포켓 링·숫자는 손대지
  않음("림·트랙·터렛만 교체" 요청 명세 그대로, 결과 판독성 유지). `RouletteWheel`: Shadow/Base/Top/Highlight 를
  `@onready` 로 잡고 허브·손잡이를 `const` 프리로드에서 `set_floor_skin(index)` 의 동적 `load()` 로 바꿨다(없으면
  B1 로 폴백). 3F 청록 테두리 스윕·PH 보석 8개 순차 반짝임은 정적 텍스처가 아니라 `_draw_fx()` 런타임 효과로
  추가(`_draw_neon_sweep`/`_draw_gem_twinkle`).
- **층별 배경 4종**(`tools/art/gen_bg.py` 확장 + `scenes/main/bg/background_{1f,2f,3f,ph}.gd` 신규, B1 과 달리
  `.tscn` 없이 코드로 조립): 1F 붉은 바둑판 벽지·금 기둥·슬롯머신 3대(불빛 순차 점멸)·샹들리에·가끔 지나가는 손님
  실루엣 / 2F 나무 판벽·둥근 창 뒤로 스크롤하는 달빛 강(`region_rect` 슬라이딩)·흔들리는 등불·배경 전체 1px 좌우
  흔들림 / 3F 스카이라인(별·창 불빛 무작위 점멸·비행기 점멸등)·네온 시안·퍼플 웅덩이·칵테일 바 / PH 대리석·금
  기둥·벨벳 커튼·구름과 달·대형 샹들리에·마담 벨벳 실루엣(9초 주기 와인잔 자세, 실제 캐릭터는 3/N). `table.png`
  (게임 판)는 층마다 새로 안 그리고 B1 것을 그대로 복사 — 판독성 유지가 방(wall) 차별화보다 우선.
- **UI 패널 테마**: 층별 대리석/황동/크롬/금 텍스처 풀세트 재생성 대신, `scripts/core/floor_theme.gd`(순수 표시용
  강조색 표)를 만들어 엘리베이터 확인 팝업의 썸네일 스와치에만 적용했다(범위 축소, GDD 17장에 사유 기록 예정).
- **층 이동 UI**: `TopBar` 에 층 진행률 바 추가(빚 상환 바와 같은 수동 배치 패턴, 90% 이상 금색 맥동). `ElevatorButton`
  (신규, 새 스프라이트 없이 `_draw()`)이 `FloorService.can_move()` 일 때 휠 오른쪽 위 틈에 나타나고, 처음 나타나는
  순간만 루시가 대사 한 줄(`elevator_ready`, `data/dialogue/lucy.json` 신규 키). `FloorConfirmPopup`(신규)이 다음
  층 이름·강조색 스와치·비용·배율·클로버를 보여준다.
- **전환 컷신**(`ElevatorCutscene`, 신규, 3.4초 스킵 가능): 문 닫힘 → 층 표시등 딸깍 3회 → '띵' + 문 열림 → 타이틀
  카드 좌→우 → 클로버 비행. **수치 적용 시점**은 "문이 다 닫힌 순간"(`doors_closed` 신호)으로 맞춰 배경·휠 스킨
  교체가 문 뒤에 가려지게 했다(5단계 남작 컷신과 같은 "연출은 결과만 보여준다" 원칙). 스킵해도 아직 안 낸 신호를
  순서대로 한 번에 내므로 층 이동은 항상 적용된다.
- `Main`: 층별 배경 스왑(`_background_for_floor`/`_on_floor_changed_background`), 엘리베이터 신호 배선(눌림→팝업
  →컷신→`FloorService.move_to_next()`→클로버 비행), `request_spin()`·오토 스핀 가드에 컷신 재생 중 추가, `_show_lucy_line()`
  으로 리팩터링(첫 클로버·엘리베이터 두 곳이 같은 패턴을 쓰던 것을 하나로 합침), 층별 BGM id 슬롯(`FloorDef.music_id`
  /`ambience_id`, `AudioManager.play_music()` 는 8단계 스텁이라 아직 무음).

**버그 두 건(캡처로 발견)**
1. 확인 팝업 숫자·문구 라벨에 `Num7Gold`/`Num7Stone`/`Num7Clover`(3×5 숫자 전용 비트맵 폰트)를 썼더니 한글이 전부
   두부(빈 네모)로 보임 — 이 폰트들은 숫자 10개+기호만 있어 한글을 못 그린다(ART_BIBLE 5장에 이미 "숫자 폰트"라
   명시돼 있었는데 놓쳤다). `LabelGold`/`LabelSmall`/`LabelClover`(일반 Galmuri 변형)로 교체.
2. 타이틀 카드가 화면 전체 폭(640px)을 기준으로 클립을 키웠더니, 가운데 정렬된 글자가 "왼쪽부터"가 아니라 "화면
   가운데 어딘가부터" 나타나는 것처럼 보임(글자 시작 위치와 클립의 왼쪽 기준이 안 맞음) — 대사 텍스트의 실제 렌더
   폭(`Label.get_minimum_size().x`)을 재서 그 폭만큼만 클립을 화면 중앙에 두고 키우도록 고쳐 진짜 "글자 자신의
   왼쪽부터" 드러나게 만들었다. 캡처로 직접 보지 않았다면 못 잡았을 문제.
- 그 외: `Background3F` 의 `POOL_CYAN`/`POOL_PURPLE` 상수가 실제로는 서로 반대 파일을 가리키고 있던 사소한 이름
  버그(동작에는 영향 없음, 코드 읽을 때 헷갈려서 발견 즉시 수정).
- 테스트 신규: `tests/test_main_scene.gd` 에 엘리베이터 통합 테스트 5개(버튼 가시성·팝업 정보·문 닫힌 뒤에만 층
  이동·스킵해도 상태 적용·컷신 중 스핀 차단). 전체 **320 tests, 8444 checks, 0 failures**.
- 캡처: `tools/capture/capture.gd` 에 시나리오 10개 추가(`floor_b1/1f/2f/3f/ph`, `elevator_ready`, `elevator_confirm`,
  `elevator_cutscene_close/tick/title`) — 5개 층 대기 화면과 컷신 3시점을 직접 보고 검수했다(위 버그 2건 발견).

**남은 이슈**
- UI 패널 프레임 테마는 "5색 텍스처 세트"가 아니라 강조색 표(`FloorTheme`)로 범위를 줄였다 — 오른쪽 패널(베팅·
  업그레이드창)의 큰 펠트 텍스처(216×328)는 여전히 B1 톤 그대로다. 층 구분은 배경·휠이 이미 강하게 해 주므로
  이번 단계에서는 필수로 보지 않았지만, 8단계 폴리시 패스에서 원하면 `FloorTheme` 표를 그대로 재사용해 4장 더
  구울 수 있다.
- 2F 앰비언스(외륜 소리) 는 슬롯(`ambience_id`)만 있고 호출부가 없다(음원 자체가 8단계 몫).
- 1F 슬롯머신 불빛·3F 창 불빛 점멸은 정적으로 구운 텍스처 위에 코드가 덧그리는 방식이라, 두 레이어의 좌표가
  살짝 어긋나도(현재는 맞춰뒀다) 눈에 잘 안 띈다 — 다음에 이 패턴을 또 쓰면 좌표 상수를 배경 스크립트 쪽에 한
  곳으로 모아두는 게 더 안전하다(지금은 `tools/art/gen_bg.py` 와 `background_1f.gd` 양쪽에 같은 좌표를 따로 적음).

**다음 작업(3/N)이 알아야 할 것**
- `background_ph.gd` 의 `MADAME` 실루엣은 진짜 캐릭터가 아니다 — 3/N 에서 마담 벨벳 초상화·전신을 만들면 이 실루엣
  대신(또는 앞에 겹쳐) 실제 대화 가능한 NPC 를 배치하면 된다. 대사창은 기존 `DialogueBox`(`NPC_LUCY`/`NPC_RATCHET`
  과 같은 `SPEAKERS` 맵에 `NPC_VELVET` 추가)를 그대로 재사용할 수 있다.
- `AchievementManager.mark_dialogue_seen(key, index)` 훅이 1/N 에 이미 있다 — 벨벳 대사를 재생하는 곳에서 이 함수만
  불러주면 숨김 업적 "벨벳의 모든 말"이 자동으로 작동한다.
- `EndingService.trigger()`/`enter_infinite_mode()` 도 1/N 에 로직만 있다 — PH 화면에 "하우스 인수" 버튼을 추가하고
  `EndingService.can_trigger()` 로 표시 여부를 정한 뒤, 눌리면 벨벳 대화 → 최후의 스핀 연출 → `trigger()` 호출
  순서로 엮으면 된다(엘리베이터 컷신처럼 "수치는 적절한 시점에, 연출은 그 결과만" 원칙을 유지할 것).
- 업적 토스트·목록 화면은 `StatsScreen`(`scenes/ui/stats_screen.gd`)과 거의 같은 틀(640×336 `PanelPlain`, 일시정지
  메뉴에서 연다)을 재사용할 수 있다. `EventBus.achievement_unlocked(id)` 를 구독해 우측 하단 토스트(0.3초 슬라이드
  인, 4초 유지)를 띄우고, `AchievementData.all()` 로 30개 목록(미획득 실루엣, 숨김은 "???")을 그리면 된다.
- 엔딩 크레딧 화면은 새로운 화면이라 기존 오버레이 패턴(스킬트리 아이리스 와이프처럼)을 그대로 따를 필요는 없다 —
  대신 엘리베이터 컷신처럼 전체 화면을 덮는 `Control` + phase enum 상태 기계 패턴을 재사용하는 편이 이번 2/N 의
  `ElevatorCutscene` 과 톤이 맞을 것이다.

### 7단계 진행 중 (2026-09-25) — 3/N: 마담 벨벳·엔딩 시퀀스·업적 토스트/목록 화면

**한 일**
- **업적 아이콘 30종+숨김 1종**(`tools/art/gen_achievements.py`, 24px): `gen_skills.py` 의 배지+글리프 조합·글리프
  라이브러리를 재사용(새 글리프 없음), 카테고리 7갈래(기본/빚/진행/수집/특수/누적/숨김)를 각자 5색 램프로 구분.
  미달성은 `gen_skills.silhouette()`, 숨김+미달성은 전용 "?" 아이콘 하나로 통일.
- **업적 토스트**(`AchievementToast`, 신규): 화면 우하단, `BadgeGolden` 패널(황금 포켓 배지와 같은 스타일) +
  아이콘 + "업적 달성" + 이름. 0.3초 슬라이드인 → 4초 유지 → 0.2초 슬라이드아웃, 여러 개는 큐잉. 새 효과음
  `achievement_unlock`(`tools/audio/gen_sfx.py`) 재생.
- **업적 목록 화면**(`AchievementScreen`+`AchievementSlot`, 신규, 일시정지 메뉴 새 버튼): `StatsScreen` 과 같은
  640×336 자리, 카테고리 헤더 + 10열 그리드. 달성=원색 아이콘/이름·설명 공개, 미달성(일반)=실루엣이지만 이름·설명은
  공개, 미달성(숨김)=전용 "?" 아이콘 + 이름·설명도 "???". `PauseMenu` 패널 높이를 190→222 로 늘려 버튼 한 줄 추가.
- **마담 벨벳**: `tools/art/gen_velvet.py`(신규, `gen_lucy.py` 골격 재사용) 로 초상화(64×64×7)·월드 스프라이트
  (48×72×4: idle/wine/gesture/clap) 생성. `MadameVelvet`(신규, 루시와 동형인 순수 연출 클래스). PH 배경의 옛
  플레이스홀더 실루엣(`madame_silhouette.png` 관련 코드)을 `background_ph.gd` 에서 완전히 제거하고 실제 월드
  액터로 교체. `DialogueBox.SPEAKERS` 에 `NPC_VELVET` 추가(전용 목소리 '삑' 효과음 `dialogue_blip_velvet` 포함).
  도착 인사(`ph_first_visit`, `GameState.velvet_intro_seen` 로 1회만)·5~8분 주기 대사(`ph_periodic`, 변형 4개,
  숨김 업적 "벨벳의 모든 말" 판정에 이 키를 쓴다)·엔딩 전용 대사(`velvet_last_hand`, `velvet_epilogue`) 4개
  키를 `data/dialogue/velvet.json` 에 정의. 루시 전용이던 `Main._lucy_dialogue`/`_show_lucy_line()` 을 화자
  무관 공용 이름(`_npc_dialogue`/`_show_npc_line()`)으로 리팩터링해 두 NPC가 한 대사창을 공유한다.
- **엔딩 시퀀스**(`EndingSequence`, 신규, `Main` 이 `wheel`/`shaker`/`flash` 참조를 직접 주입): 하우스 인수 버튼
  (`AcquisitionButton`, 엘리베이터 버튼과 같은 자리·같은 절차적 `_draw()` 패턴, 왕관 아이콘) → 화면 어둡게(0.6초)
  → 벨벳 "마지막 한 판" 대사 → 최후의 스핀(`wheel.play_spin()` 을 결과만 misc RNG 로 뽑아 직접 호출, `SpinController`
  완전히 우회 — 승패 없는 순수 연출) → 착지 효과(화면 흔들림·플래시·코인 파티클 5줄기, 전부 기존 컴포넌트 재사용)
  → 골드 웨이브(새 텍스처 없이 `draw_arc()` 로 휠 위에 금색 원호가 도는 것을 그린다) → 양도 증서 서명(5단계
  `ContractPopup` 에 `open_custom()` 을 추가해 대출 계약서와 같은 서명·도장 메커니즘 재사용) → 에필로그(벨벳→루시
  →남작, 남작이 빚 탕감 언급 — `EndingService.trigger()` 가 `GameState.forgive_debt(1.0)` 을 실제로 부른다) → 네온
  간판 "HOUSE EDGE" 점등(기존 `NeonText`/"LUCKY" 아틀라스에 `gen_fx.py` 로 H·S·D 3글자만 추가해 재사용) →
  `EndingCredits`(신규, `StatsScreen` 과 같은 틀에 플레이 시간·총 스핀·최대 당첨금·최대 연승·대출 횟수·최다 출현
  숫자·최종 구슬 7개 통계 카드 + [계속하기]) → `EndingService.enter_infinite_mode()`(오너 모드 ×2, `TopBar` 에
  절차적으로 그린 작은 금색 왕관 아이콘).
- `request_spin()`·오토 스핀·`_unhandled_input` 가드에 `ending_sequence.is_playing()` 추가(다른 컷신들과 같은
  목록). 새 저장 필드 `velvet_intro_seen`.

**버그 네 건(스크린샷 검수로 발견, 전부 수정)**
1. `AchievementSlot`(목록 화면 그리드 칸)에 `custom_minimum_size` 를 안 두고 `size` 만 지정했더니 `GridContainer`
   가 모든 칸을 0×0 으로 접어 한 카테고리의 아이콘 여러 개가 전부 같은 자리에 겹쳐 보임(마지막에 그려진 것만
   보여 "카테고리당 아이콘 1개"처럼 보였다) — Container 의 자식은 `custom_minimum_size` 로만 자리를 예약한다는
   일반 규칙을 놓침. `AchievementSlot._ready()` 에 `custom_minimum_size = SIZE` 추가로 해결.
2. 벨벳 월드 스프라이트 초안에서 팔을 드레스와 같은 색(`DRESS[1]`)으로 그렸더니 몸통에 묻혀 거의 안 보임(치맛단도
   너무 넓어 종 모양처럼 보임) — 팔을 검은 오페라 장갑(`HAIR[0]`, 대비색)으로 바꾸고 치맛단 폭도 줄였다.
3. PH 도착 인사 대사(`_npc_dialogue`, Main 소유)가 열려 있는 상태에서 바로 하우스 인수 버튼을 누르면, 엔딩 전용
   대사창(`EndingSequence.dialogue`, 별도 인스턴스)과 같은 화면 자리(하단 고정)에 두 대사창이 겹쳐, 나중에 추가된
   `_npc_dialogue` 가 엔딩 전체를 가려버림(캡처 스크린샷에서 "엔딩이 시작됐는데 화면이 전혀 안 어두워 보인다"로
   나타나 처음엔 디밍 버그로 오인했다가, 실제로는 알파값이 정확했고 위에 다른 패널이 덮고 있던 것이었다) —
   `_on_acquisition_pressed()` 에서 엔딩 시작 전에 `_npc_dialogue.visible = false` 로 먼저 치우도록 수정.
4. 계약서 서명 뒤 `contract.close()` 를 빼먹어서, 서명 완료 뒤 에필로그·네온 간판·크레딧 내내 양도 증서 팝업이
   화면에 계속 남아 있었다 — 대출 계약서(`BaronLoanSequence`)의 `SIGNED_WAIT`(도장 뒤 0.7초 대기 후 `close()`)
   패턴을 그대로 가져와 `EndingSequence` 에도 같은 단계를 추가.
- 그 외(사소): 네온 간판을 엔딩 시작부터 계속 보이게(꺼진 유리관 상태로) 뒀더니 나중 "점등" 반전 효과가 약해져,
  `NEON_SIGN` 단계 전까지는 아예 `visible=false` 로 숨기도록 조정(기능 버그는 아니고 연출 임팩트 문제).
- 테스트 신규: `test_achievement_screen.gd`(7)·`test_achievement_toast.gd`(4)·`test_madame_velvet.gd`(3)·
  `test_ending_sequence.gd`(6)·`test_ending_credits.gd`(2) + `test_main_scene.gd`/`test_pause_menu.gd`/
  `test_ending_service.gd` 에 통합 테스트 추가(하우스 인수 버튼 가시성·스핀 차단·대사창 충돌 방지·빚 탕감 등).
  전체 **348 tests, 8713 checks, 0 failures**.
- 캡처: `velvet_intro`, `acquisition_button`, `ending_last_hand`, `ending_final_spin`, `ending_signing`,
  `ending_epilogue`, `ending_credits`, `achievement_toast`, `achievement_screen` 9개 시나리오 신규(ko/en) —
  위 버그 1·3·4 를 전부 이 캡처들로 발견했다.

**남은 이슈**
- 엔딩 컷신은 스킵을 지원하지 않는다(대사만 클릭으로 넘길 수 있고, 최후의 스핀 8초는 그대로 기다려야 한다) —
  의도적 범위 축소(GDD 17장). 9단계에서 QA 중 불편하면 추가.
- `tools/capture/capture.gd -s zzz_dim_check.gd` 류의 임시 디버그 스크립트로 dim 알파를 직접 검증했었다(알파값
  자체는 정상이었고 실제 원인은 버그 3) — 검증에 썼던 파일은 커밋 전 삭제했다. 비슷한 "화면이 이상한데 원인을
  못 찾겠다" 상황에서는 연출 파라미터 값을 직접 print 하는 임시 테스트를 만들어 논리 버그와 z-order/겹침 버그를
  먼저 구분하는 게 효율적이었다.
- 캡처 도구 종료 시 가끔("floor_ph" 등 일부 시나리오에서 3회 중 1회꼴) `ObjectDB instances leaked`/`resources
  still in use` 경고가 뜬다 — 재현이 간헐적이고 헤드리스 테스트 스위트(`tests/run_tests.gd`)에서는 전혀 나타나지
  않아, 캡처 도구가 리소스를 빠르게 로드/해제하며 `quit()` 하는 타이밍 문제로 추정된다(실제 게임 플레이에 영향
  없음). 9단계 최종 QA 때 재확인.

**다음 작업(4/N — 검수·문서화)이 알아야 할 것**
- 헤드리스 테스트 전부 통과, 문서(GDD 10/17장, ART_BIBLE 12-2/13장, 이 파일) 갱신 완료. 남은 건 최종 스크린샷
  전수 재확인(ko/en)과 커밋·푸시뿐이다.
- 8단계(타이틀·튜토리얼·사운드·폴리시)에서 참고할 것: `AudioManager.play_music()` 가 아직 스텁이라 엔딩의 "bass_drop"
  같은 SFX 는 나지만 배경음악 크로스페이드는 안 들린다. PH 층 BGM(`bgm_ph`)이 연결되면 엔딩 시퀀스 중에는 음악을
  낮추거나 멈추는 처리가 있으면 더 극적일 것(지금은 손대지 않음).

### 8단계 진행 중 (2026-09-25) — 1/N: 부팅·타이틀·인트로 컷신

**작업 브랜치 관련 참고**: 이 단계를 시작한 세션은 원래 1단계 커밋에서 갈라진 빈 브랜치에서 출발했다(2~7단계가
전혀 없는 상태). 원격에 이미 1~7단계가 순서대로 쌓인 브랜치(`claude/tender-goldberg-scqis9`, 348 tests 전부
통과)가 있어 그 지점으로 브랜치를 다시 맞추고(안전한 fast-forward, 기존 커밋 손실 없음) 여기서부터 이어간다.

**한 일**
- `run/main_scene` 을 `Main.tscn` → `SplashScreen.tscn` 으로 변경. 부팅 순서: 스플래시(개발사 로고, 스킵 가능)
  → `TitleScreen.tscn`(이어하기/새 게임/설정/업적/크레딧/종료) → (새 게임이면 `IntroCutscene`) → `Main.tscn`.
  `Main._ready()` 의 기존 `SaveManager.load_game()` 호출은 그대로 둬서 기존 348개 테스트와 완전히 호환된다(GDD 18장).
- `SaveManager` 에 `delete_save()`(새 게임용)·`peek_summary()`(GameState 를 안 건드리고 저장 요약만 읽기) 추가.
- `TitleScreen`(신규): 비 내리는 밤거리 배경(`bg_wall.png`, 정적) + 절차적 빗줄기(`_RainLayer`, 90개)·번개 플래시
  + 네온 로고(7단계 엔딩과 같은 `NeonText` 재사용, `flicker_on()`+`idle_flicker`) + 미니 회전 룰렛 아이콘(8프레임)
  + 메뉴 패널(칩 커서가 포커스·호버된 버튼 옆으로 이동) + 새 게임 확인 팝업(기존 저장 있을 때만).
- `SplashScreen`(신규): 개발사 워드마크 페이드인·유지·페이드아웃(가제 `Economy.STUDIO_NAME = "HOUSE EDGE"`,
  `tools/art/gen_title.py` 의 같은 이름 상수와 반드시 맞춰야 한다 — 정식 이름이 정해지면 두 곳만 바꾸고 재생성).
- `IntroCutscene`(신규, `scenes/fx/`): 골목(뒷모습 실루엣)→구슬(나무 구슬 아이콘)→문→루시 대사(`intro_greeting`,
  4줄) 4단계, 전부 `_process(delta)` 누적으로 전이(트윈 콜백에 걸지 않음 — 7단계 EndingSequence 와 같은 이유,
  헤드리스 테스트가 `_process(dt)` 를 직접 여러 번 불러 진행 상황을 재현해야 한다). 우상단 "건너뛰기"로 언제든 종료.
- `PauseMenu.title_requested` 신호 추가, "저장 후 타이틀로" 버튼을 잠금 해제(`Main._on_title_requested()` 가
  저장 후 타이틀로 전환. 이미 저장된 상태라 확인 팝업 불필요).
- `CreditsScreen`(신규, 초안): 스튜디오 이름·Godot·Galmuri 라이선스 고지. 음원 출처는 3/N 이후 채운다.
- `tools/art/gen_title.py`(신규): 스플래시 로고, 타이틀 배경, 미니 휠 아이콘 8프레임 절차적 생성.
- `tools/capture/capture.gd` 에 8단계 전용 경로(`TITLE_SCENARIOS`, `_fresh_title()`, `_capture_title_flow()`)
  추가 — 기존 90여 개 시나리오(전부 `Main.tscn` 기준)는 손대지 않고 완전히 분리했다.
- 테스트 신규: `test_splash_screen.gd`·`test_title_screen.gd`·`test_intro_cutscene.gd`·`test_credits_screen.gd`,
  `test_save_manager.gd`(delete_save/peek_summary)·`test_pause_menu.gd`(잠금 해제 확인)에 추가. **주의**: 실제
  `get_tree().change_scene_to_file()` 로 이어지는 경로(이어하기 클릭, 인트로 완주)는 어떤 테스트도 실행하지
  않는다 — 헤드리스 테스트가 공유하는 SceneTree 에서 실제 씬 전환이 한 번이라도 일어나면 그 씬 전체가 트리에
  남아 이후 테스트를 오염시키기 때문(GDD 18장에 기록). 그 경로는 캡처 스크린샷과 수동 실행으로만 검증했다.
- `tests/test_main_scene.gd::test_main_is_project_main_scene` 을 `test_main_is_reachable_from_boot_chain` 으로
  교체(더 이상 `Main.tscn` 이 `run/main_scene` 자체가 아니므로).
- 전체 **370 tests, 8877 checks, 0 failures**.
- 캡처(ko/en): `splash`, `title`, `title_continue`, `title_new_game_confirm`, `title_settings`,
  `title_achievements`, `title_credits`, `intro_alley`, `intro_marble`, `intro_door` — 직접 보고 확인.

**버그 한 건(캡처로 발견, 수정)**
- 인트로 골목 단계의 뒷모습 실루엣을 처음엔 `void` 한 색으로만 채웠더니 화면 디밍(알파 0.75) 위에서 거의 안
  보였다(둘 다 어두운 보라 계열이라 대비가 없음) — `ink` 바탕 + `mist` 1px 테두리로 바꿔 또렷한 실루엣이 되게
  했다(ART_BIBLE 14-3).

**남은 이슈**
- 개발사 이름이 가제("HOUSE EDGE")다. 정식 이름이 정해지면 `Economy.STUDIO_NAME` 과
  `tools/art/gen_title.py::STUDIO_NAME` 을 함께 바꾸고 스플래시 로고를 재생성해야 한다.
  Windows 내보내기 회사명(5단계)에도 같은 값을 쓸 것.
- 크레딧 화면은 초안이다 — 음원 출처는 3/N(음악·사운드) 뒤에 채운다.
- 타이틀 화면의 "이어하기" 요약 두 번째 줄("칩 · 0시간 0분")이 좁은 패널 폭 때문에 살짝 어색하게 줄바꿈된다
  (예: "5.10K\n칩" 처럼 숫자와 단위가 나뉨) — 4/N 폴리시 패스에서 문구를 다듬거나 패널을 넓힐지 검토.
- 새 게임 확인 팝업이 타이틀 네온 간판 아래쪽과 픽셀 단위로 딱 붙어 있다(겹치지는 않음) — 4/N 에서 여유를 더
  줄지 검토.

**다음 작업(2/N — 튜토리얼)이 알아야 할 것**
- 튜토리얼은 게임플레이 화면(Main) 안에서 진행되므로 이 사분기의 부팅 흐름과는 독립적이다. 다만 "설정에서
  튜토리얼 끄기/다시보기"가 필요하므로 `SettingsManager` 에 새 필드를 추가할 때 이 파일의 설정 화면(4단계,
  탭 "게임")과 저장 방식을 그대로 따르면 된다.
- 인트로 컷신 종료 시점(`IntroCutscene.finished`)이 곧 튜토리얼 시작 시점과 자연스럽게 이어질 수 있다 — 새
  게임으로 `Main.tscn` 에 처음 진입했을 때만 튜토리얼을 시작하는 조건(예: `GameState` 에 "튜토리얼을 본 적
  있는가" 플래그)이 필요할 것이다(저장 파일에 포함해야 다시 시작해도 튜토리얼이 반복되지 않는다).

### 8단계 진행 중 (2026-09-25) — 2/N: 튜토리얼

**한 일**
- `scenes/fx/tutorial_guide.gd`(신규, `TutorialGuide`): `enum Step { PLACE_BET, SPIN, RESULT, UPGRADE_TAB,
  UPGRADE_BUY, CLOVER, SKILLTREE, DONE }` 6단계를 실제 `EventBus` 이벤트로만 전진(GDD 19장). 대상 UI 만 밝히고
  나머지는 어둡게 하되 입력은 막지 않는다(대사를 안 닫고도 실제 칸 클릭·탭 누르기 가능). `Main` 의 fx 레이어에
  상주하며 `_build_fx()` 에서 생성, `Main._ready()` 맨 마지막 줄에서 `tutorial.start(self, GameState.tutorial_step)`
  호출(다른 초기화가 전부 끝난 뒤여야 대상 UI 의 `get_global_rect()` 가 유효하다).
- `GameState` 에 `tutorial_step: int`(저장됨, 이어서 진행)·`tutorial_tips_seen: Array[String]`(저장됨) 추가.
  `SettingsManager.tutorial_enabled`(bool, 기본 true) 로 전체 on/off. 설정 화면(4단계 탭 "게임")에 체크박스 +
  "다시 보기" 버튼 추가 — 누르면 `EventBus.tutorial_reset_requested` 발행, `TutorialGuide.restart()` 가 받는다.
- 1회성 신규 기능 팁(첫 대출·첫 층 이동·황금 포켓 해금): 튜토리얼 활성 여부와 무관하게 항상 검사하고
  `tutorial_tips_seen` 으로 한 번만 토스트. `SettingsManager.tutorial_enabled` 로만 껐다 켰다 한다.
- `data/dialogue/lucy.json` 에 6단계 대사 키(`tutorial_place_bet`~`tutorial_skilltree`) 추가, `translations/strings.csv`
  에 ko/en 함께.
- `tools/capture/capture.gd` 에 `tutorial_place_bet`/`tutorial_spin`/`tutorial_upgrade_tab`/`tutorial_upgrade_buy`/
  `tutorial_clover` 5개 시나리오 추가. **주의**: `-s` 진입 스크립트 안에서 `TutorialGuide.Step.X` 처럼 클래스 이름을
  직접 쓰면 컴파일 시점에 그 클래스를 앞당겨 읽어(오토로드가 아직 없는 시점) "Identifier not found: EventBus" 오류가
  난다(CLAUDE.md 의 기존 `-s` 스크립트 주의사항과 같은 원인) — 정수 리터럴(3=UPGRADE_TAB, 5=CLOVER)을 썼다.
- 테스트 신규: `test_tutorial_guide.gd`(17개 — 6단계 진행 조건 전부·저장 재개·다시 보기·1회성 팁 4종).
- 전체 **387 tests, 8951 checks, 0 failures**.
- 캡처(ko/en, 총 10장): `tutorial_place_bet`/`tutorial_spin`/`tutorial_upgrade_tab`/`tutorial_upgrade_buy`/
  `tutorial_clover` — 직접 보고 확인.

**버그 두 건(둘 다 캡처로 발견, 수정) — 둘 다 "테스트는 통과하는데 스크린샷이 이상하다" 유형**

1. **디밍이 world(휠·배경) 위에서 전혀 안 보임**. `DIM_ALPHA` 를 처음엔 `JackpotOverlay` 와 같은 0.85 로 맞췄고,
   논리 상태(`_dim_rects` 의 visible/position/size/color, `GameState.tutorial_step`)는 전부 정확했는데도 캡처
   스크린샷에서 대상 UI 를 뺀 나머지 중 "휠·배경" 부분만 전혀 안 어두워졌다(UI 패널 부분은 정상적으로 어두워짐).
   임시 진단 스크립트로 idle 스크린샷과 픽셀 값을 직접 비교해(휠 위 좌표는 완전히 동일값, UI 패널 위 좌표는
   `blend(alpha=0.85)` 계산과 정확히 일치) "world(Node2D, 휠·배경) 위에서는 반투명 `ColorRect` 가 알파값과 무관하게
   전혀 합성되지 않는다"는 렌더러 조합(gl_compatibility·소프트웨어 Mesa) 특성임을 확인했다. 완전 불투명 사각형은
   같은 좌표를 정확히 덮는 것으로 검증(알파=1.0 이면 블렌딩이 필요 없어 문제를 우회한다) — `DIM_ALPHA := 1.0` 으로
   변경해 해결(ART_BIBLE 15장). **기존 `JackpotOverlay`(DIM_ALPHA=0.85)도 같은 방식으로 재현 확인**(잭팟이 터져도
   휠 자체는 안 어두워짐) — 이번 단계 범위 밖이라 직접 고치지 않고 `spawn_task` 로 별도 작업 제안을 남겼다.
2. **이전 단계 대사가 안 지워짐**. `Main._say_npc_entry()` 가 "대사창이 이미 열려 있으면 새 요청을 무시"하는데,
   튜토리얼은 플레이어가 대사를 안 닫고 바로 다음 행동(베팅·탭 클릭)을 할 수 있게 설계했으므로, 예를 들어
   PLACE_BET 대사를 안 닫은 채로 베팅하면 내부 상태는 SPIN 으로 정확히 넘어갔는데도 화면엔 PLACE_BET 문구가
   그대로 남아 있었다(스크린샷에서 SPIN 강조(스핀 버튼 금테)인데 문구는 "판 위의 칸을 하나"인 것으로 발견).
   `_say_npc_entry(entry, force: bool = false)` 로 매개변수를 추가하고 `TutorialGuide._show_step_line()` 만
   `force=true` 로 불러, 튜토리얼 문구는 항상 즉시 교체되게 했다(다른 호출자는 기존 동작 그대로 유지).

**남은 이슈**
- SPIN 단계에서 대사창(`DialogueBox`, y 268~352)이 스핀 버튼(전역 y 318~352)을 완전히 가린다 — 이는 대사가 떠
  있을 때 항상 그런 기존 레이아웃이라 튜토리얼만의 문제는 아니며, 대사를 한 번 닫으면 버튼과 스포트라이트가
  정상적으로 드러난다. 4/N 폴리시 패스에서 재배치가 필요할지 재검토.
- `JackpotOverlay` 의 world-위-디밍 버그는 고치지 않고 `spawn_task` 로 남겨뒀다(task 카드로 사용자에게 제안됨).
- 대사 타이핑 효과 도중 캡처하면(대기 0.3초) 스크린샷에 문장이 중간까지만 보인다 — 실제 텍스트 잘림이 아니라
  타이핑 애니메이션을 캡처 시점에 멈춰 찍은 것뿐이니 혼동하지 말 것(전체 문구는 `translations/strings.csv` 로 확인).

**다음 작업(3/N — 음악·사운드)이 알아야 할 것**
- `AudioManager.play_music()` 는 아직 스텁(`pass`)이다. 사용자가 CC0/무료 음원 제안 방식을 선택했으므로,
  실제 음원 파일을 넣기 전에 후보 트랙을 라이선스와 함께 먼저 제시하고 승인받아야 한다(라이선스 불명확한 음원을
  임의로 추가하지 말 것).
- 튜토리얼 대사가 열려 있는 동안은 `_stop_auto_spin("AUTO_STOP_DIALOGUE")` 가 이미 자동 스핀을 멈춘다 — 음악
  페이드/덕킹을 붙일 때 대사 시작·종료 시점(`_npc_dialogue` 의 열림/닫힘)을 참고할 수 있다.
