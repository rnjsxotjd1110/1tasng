# HOUSE EDGE — 프로젝트 규칙 (모든 채팅이 가장 먼저 읽는 파일)

**한 줄 요약**: Godot 4.3(GDScript)으로 만드는 스팀 출시 품질의 1인용 방치형 픽셀아트 룰렛 게임. 나무 구슬 하나뿐인 도박꾼이 카지노 5개 층을 올라가 약 5시간 뒤 카지노를 인수해 '하우스'가 된다.

## 작업 시작 시 반드시

1. `docs/GDD.md`(게임 설계), `docs/ART_BIBLE.md`(아트 규칙), `docs/PROGRESS.md`(진행 상황·이전 단계 인수인계)를 **전부** 읽는다.
2. 헤드리스 테스트를 한 번 돌려 현재 상태가 초록인지 확인한다.
3. 이번 단계 범위(아래 로드맵)만 작업한다. 설계를 바꿔야 하면 GDD/ART_BIBLE 을 먼저 고치고 PROGRESS 에 이유를 남긴다.

## Godot 실행

요구 버전: **Godot 4.3 stable 이상**(표준판, .NET 아님). 렌더러 gl_compatibility.

| 환경 | 실행 파일 |
|---|---|
| 클라우드 컨테이너(Linux, Claude Code on the web) | `/opt/godot/Godot_v4.3-stable_linux.x86_64` (`godot` 로 심볼릭 링크). 컨테이너가 새로 뜨면 없으므로 `bash tools/setup_godot.sh` 로 설치 |
| 사용자 Windows PC (`C:\Users\user\code rulet`) | **아직 확인 안 됨.** 로컬에서 작업하는 채팅은 PATH(`godot`, `godot4`), `C:\Program Files\Godot\`, `%LOCALAPPDATA%\Programs\Godot\`, Steam(`C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\`), scoop(`%USERPROFILE%\scoop\apps\godot\`) 을 찾아보고, 못 찾으면 사용자에게 경로를 물어 이 표에 기록한다 |

아래 명령의 `godot` 은 위 실행 파일 경로로 바꿔 쓴다(Windows 는 `Godot_v4.x-stable_win64_console.exe` 를 쓰면 콘솔 출력이 보인다).

```bash
godot --headless --import                 # 새로 클론한 뒤 1회: 클래스 캐시(.godot/)·번역 임포트
godot -e                                  # 에디터
godot                                     # 게임 실행(현재 메인 씬: scenes/debug/DebugLogic.tscn, 2단계에서 교체)
godot --headless -s tests/run_tests.gd    # 헤드리스 테스트 전체(약 20초, 기대값 100만 스핀 포함)
godot --headless -s tests/run_tests.gd -- number   # 파일 이름에 'number' 가 들어간 테스트만
```

- 테스트 출력에 섞이는 `WARNING/ERROR` 중 테스트가 "정상 출력"이라고 미리 알린 줄은 방어 코드 검증용이다. 마지막 줄 `N tests, M checks, 0 failures` 와 종료 코드 0 이 통과 기준.
- 클라우드에서 화면을 찍을 때: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 ...` (스크린샷 도구 `tools/capture` 는 2단계에서 제작).

## 폴더 구조

```
res://
  CLAUDE.md                  ← 이 파일
  project.godot
  docs/        GDD.md, ART_BIBLE.md, PROGRESS.md
  scripts/
    autoload/  event_bus.gd, game_state.gd, economy.gd, rng_service.gd, save_manager.gd(틀), audio_manager.gd(틀)
    core/      roulette_rules.gd, bet.gd, spin_outcome.gd, spin_context.gd, number_format.gd,
               stat_modifiers.gd, spin_controller.gd, game_data.gd, palette.gd      ← 순수 로직, 연출 없음
    data/      upgrade_def.gd, skill_node_def.gd, floor_def.gd, marble_def.gd  (Resource 클래스)
  data/        upgrades/ skills/ floors/ marbles/ dialogue/   ← 밸런스 수치(.tres)
  scenes/      main/ roulette/ ui/ skilltree/ npc/ fx/ debug/  ← 연출·화면
  assets/      sprites/ ui/ fonts/ audio/sfx/ audio/music/ shaders/
  translations/strings.csv   (keys,ko,en)
  tests/       run_tests.gd, lib/test_case.gd, test_*.gd
  tools/       art/ audio/ sim/ capture/ data/, setup_godot.sh
```

오토로드 순서(project.godot): EventBus → Economy → RngService → GameState → SaveManager → AudioManager.
오토로드 스크립트에는 `class_name` 을 달지 않는다(싱글톤 이름과 충돌).

## 코드 규칙

- **GDScript 정적 타입 필수.** 변수·인자·반환 타입을 모두 적는다(`:=` 추론 허용). 배열은 `Array[T]`.
- 파일·함수·변수는 `snake_case`, 클래스는 `PascalCase`, 상수는 `UPPER_SNAKE_CASE`. 씬 파일은 `PascalCase.tscn`.
- **매직 넘버 금지.** 밸런스 수치는 전부 `data/*.tres` 또는 `Economy` 상수에 둔다. 연출 수치(타이밍·픽셀)는 ART_BIBLE 값을 파일 상단 상수로 둔다.
- **로직(`scripts/core`)과 연출(`scenes`)을 분리한다.** core 는 노드·트윈·사운드를 모른다. 연출은 core 의 결과(`SpinOutcome` 등)를 받아 보여주기만 한다.
- **시스템 간 통신은 `EventBus` 시그널로 한다.** 새 시그널은 타입을 명시하고 GDD "EventBus" 표에 추가한다.
- 칩은 `GameState.add_chips()/spend_chips()`, 클로버는 `add_clovers()/spend_clovers()` 로만 바꾼다.
- 업그레이드·스킬·패널티·버프의 효과는 전부 `StatModifiers` 수정자로 붙인다(source_id 규칙: `upgrade:<id>`, `skill:<id>`, `buff:<id>`, `penalty:<id>`). 새 스탯은 `StatModifiers` 상수와 `ALL_STATS` 에 추가한다.
- 난수는 `RngService` 만 쓴다. 스핀 결과는 `consume_next()`, 연출·패널티 등은 `*_misc()`.
- **모든 UI 문자열은 `tr("KEY")`** 로 쓰고, `translations/strings.csv` 에 ko·en 을 함께 추가한다(`test_data.gd` 가 누락을 잡는다).
- **숫자 표시는 반드시 `NumberFormat`** (`format`, `format_signed`, `format_full`)을 쓴다.
- 새 로직에는 `tests/test_*.gd` 테스트를 함께 추가한다. 테스트는 `extends "res://tests/lib/test_case.gd"`, 함수 이름은 `test_` 로 시작.
- 예외: `scenes/debug/` 는 개발용이라 tr()·품질 기준 예외. 게임 코드에서 참조 금지.

## 품질 기준 (Quality Bar) — 스팀 출시 품질이 목표

- Godot 기본 테마(회색 버튼, 기본 폰트)가 화면에 **절대** 보이면 안 된다.
- 모든 버튼은 normal/hover/pressed/disabled 상태와 호버·클릭 사운드를 가진다.
- 모든 숫자 변화는 카운트업 트윈으로 보여준다.
- 모든 패널은 0.15~0.25초 전환 애니메이션으로 열리고 닫힌다(즉시 등장 금지).
- 픽셀 퍼펙트: 픽셀아트는 정수 배율로만 확대하고 위치는 정수 픽셀에 스냅한다. 팝·흔들림 연출은 정수 픽셀 이동, 프레임 교체, 색·알파 변화로 표현한다(소수 배율 스케일 금지).
- 텍스트 넘침·잘림 금지(ko/en 모두 확인).
- 60fps 유지.
- 각 단계 종료 시 `tools/capture` 로 스크린샷을 찍어 **직접 보고** 검수한다(도구는 2단계에서 제작).

## 단계 종료 루틴

1. `godot --headless -s tests/run_tests.gd` 전부 통과
2. 스크린샷 검수(ko/en, 주요 화면)
3. `docs/PROGRESS.md` 갱신: 한 일, 파일 목록, 남은 이슈, 다음 단계가 알아야 할 것
4. `git commit` (메시지에 단계 번호)

## 9단계 로드맵

| 단계 | 내용 |
|---|---|
| 1 | 기반·규칙 엔진 (project.godot, 문서, 룰렛 규칙, 정산, 경제 공식, 숫자 표기, 스탯 수정자, 테스트) |
| 2 | 메인 화면·룰렛 휠·스핀 애니메이션·베팅창·당첨 연출 |
| 3 | 업그레이드·구슬 재질 |
| 4 | 저장·오프라인 수익·설정 |
| 5 | 빚·래칫 남작 |
| 6 | 스킬트리·클로버·자동화 |
| 7 | 층 진행·엔딩·업적 |
| 8 | 타이틀·튜토리얼·사운드·폴리시·출시 준비 |
| 9 | 밸런스 시뮬레이션·최종 QA |
