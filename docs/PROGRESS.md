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
