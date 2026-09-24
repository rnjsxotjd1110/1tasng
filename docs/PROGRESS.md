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

### 6단계 — 스킬트리·클로버·자동화 (진행 중 — 아래 "진행 상황" 참고)
- [x] 로직 기반: StatModifiers 신규 스탯, SkillNodeDef 재설계(효과 배열+선행조건 ALL/ANY), SkillService
- [x] RouletteRules/SpinContext/SpinController 확장(제로가드·미러·핫넘버·럭키세븐·이중적중·황금폭풍·잭팟체인·운명뒤집기·피버·저금통·비상금·투자수익)
- [x] 스킬 57개 데이터 생성 + 총비용 269 코드 검증 + 회귀 테스트
- [ ] 클로버 획득 연출(날아가는 클로버) + 첫 클로버 해금 연출(자물쇠 파괴+루시 대사)
- [ ] 스킬트리 오버레이 UI(K, 아이리스 와이프, 노드맵, 팬/줌, 툴팁, 홀드 구매)
- [ ] 자동화 3종 UI: 오토 스핀(A), 스마트 베팅 드롭다운, 오토 업그레이드 토글
- [ ] 특수 기능 8종 UI/연출: 예지 수정구, 핫넘버 불꽃, 피버 배너·셰이더, 잭팟체인 번개, 운명뒤집기 애니메이션, 더블볼 보라 궤적, 황금저금통 돼지, 운명의 휠 팝업, 버프 표시줄
- [ ] 딜러 루시 스프라이트·초상화·연출
- [ ] 캡처 검수, 최종 커밋

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
