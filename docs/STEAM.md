# 스팀 출시 준비 (8단계 5/N)

이 문서는 "무엇을 만들었는지"와 "실제로 스팀에 올리려면 사용자(제작자)가 무엇을 직접 해야 하는지"를 나눠
적는다. 코드/에셋 쪽은 이 저장소에 전부 있고, Steamworks 계정·앱 등록·실제 Windows 머신에서의 최종 확인은
이 클라우드 컨테이너가 대신할 수 없는 부분이다.

## 1. SteamService — GodotSteam 없이도 완전히 동작한다

- `scripts/autoload/steam_service.gd`(오토로드, `project.godot` 순서상 맨 끝): `Engine.has_singleton("Steam")`
  로 GodotSteam 애드온이 있는지 확인하고, **없으면(지금 이 저장소 상태) `is_available=false` 로 모든 기능이
  조용히 무동작**한다. 이 게임은 스팀 없이도(itch.io 등) 완전히 동작해야 하므로 GodotSteam 을 필수 의존성으로
  두지 않았다.
- 있으면: `_ready()` 에서 `Steam.steamInit()` 한 번, 이후 `EventBus.achievement_unlocked(id)` 가 올 때마다
  `Steam.setAchievement(steam_id)` + `Steam.storeStats()` 를 부른다.
- 업적 id → 스팀 API 이름 규칙: `"ACH_" + id.to_upper()` (예: `first_spin` → `ACH_FIRST_SPIN`).
  `data/achievements.json` 의 30개 id 를 전부 이 규칙으로 변환하면 Steamworks 앱 관리 페이지의
  "통계 및 성취도" 에서 만들어야 할 API 이름 30개가 나온다(id 목록은 그 파일을 그대로 보면 된다).

### 사용자가 할 일(스팀에 실제로 연동하려면)

1. Steamworks 파트너 사이트에서 앱을 등록하고 App ID 를 받는다.
2. [GodotSteam](https://godotsteam.com/) 애드온(GDExtension 판, Godot 4.3 용)을 내려받아 프로젝트에 넣는다
   (`addons/godotsteam/` 등 — 애드온이 자체 설치 안내를 제공한다). 이 저장소에는 애드온을 포함하지 않았다
   (수십~수백 MB 바이너리라 라이선스·배포 방식이 이 저장소와 다르다).
3. 실행 파일과 같은 폴더에 `steam_appid.txt`(App ID 숫자 한 줄)를 두거나, 스팀 클라이언트를 통해서만
   실행되게 한다.
4. Steamworks 의 "통계 및 성취도" 페이지에 위 30개 `ACH_*` API 이름으로 업적을 만들고(표시 이름·설명·아이콘은
   자유롭게), 각각 `data/achievements.json` 의 같은 id 항목과 같은 의미가 되게 맞춘다.
5. 클라우드 저장·리치 프레즌스 등은 이번 단계 범위에 없다(필요해지면 `SteamService` 에 같은 방식으로
   추가하면 된다 — `is_available` 가드만 지키면 스팀 없는 실행에 영향이 없다).

## 2. Windows 내보내기 프리셋

`export_presets.cfg`(저장소 루트, 신규) — **이 컨테이너에서 실제로 내보내 실행 파일이 나오는 것까지
확인했다**(아래 "확인한 것" 참고).

| 항목 | 값 |
|---|---|
| 아이콘 | `assets/icon.ico`(16/32/48/64/128/256px, `tools/art/gen_app_icon.py`) |
| 회사명 | `HOUSE EDGE`(=`Economy.STUDIO_NAME`, 가제 — 정식 이름이 정해지면 여기·`tools/art/gen_title.py`·
  `Economy.STUDIO_NAME` 셋을 같이 바꾸고 아이콘을 재생성) |
| 제품명 | `HOUSE EDGE` |
| 콘솔 창 | `debug/export_console_wrapper=1`(디버그 빌드만 콘솔 표시, 릴리스는 콘솔 없음 — 요청 명세 그대로) |
| F9 디버그 패널 | 이미 `OS.is_debug_build()` 로 감싸져 있어(1~7단계부터) 릴리스 빌드에는 자동으로 빠진다.
  추가 조치 필요 없었다 |

### 확인한 것 (이 컨테이너에서)

- Godot 4.3 stable 용 공식 내보내기 템플릿을 GitHub 릴리스에서 받아 설치했다(`~/.local/share/godot/
  export_templates/4.3.stable/`, 약 1GB — 이 세션의 네트워크 정책이 `github.com` 릴리스 다운로드는 막지
  않아서 가능했다. CC0 음원 사이트와는 다른 취급이다).
- `godot --headless --export-release "Windows Desktop" "build/windows/HOUSE EDGE.exe"` 로 실제 PE32+
  실행 파일(84MB)이 만들어지는 것을 확인했다(`file` 명령으로 포맷 확인).
- `godot --headless --export-debug "Windows Desktop" ...` 도 확인했다 — 디버그는 별도 `.console.exe`
  래퍼가 함께 나오고(콘솔 있음), 릴리스는 안 나온다(콘솔 없음) — `debug/export_console_wrapper=1` 설정이
  의도대로 동작함을 실제 산출물로 확인.
- 아이콘·제품명 등을 실제 `.exe` 리소스에 심는 `rcedit` 도구가 이 리눅스 컨테이너에는 없어서(원래
  윈도우 전용 도구), "Could not start rcedit executable" 경고가 남는다 — **`.exe` 자체는 정상 생성되지만
  아이콘이 실제로 파일 탐색기에 보이려면 rcedit 이 있는 환경(보통 Windows, 또는 에디터 설정에 rcedit 경로를
  넣은 환경)에서 내보내야 한다.** Godot 에디터 설정(Editor Settings → Export → Windows → rcedit) 에서
  경로를 지정하거나, Godot 가 자동으로 찾게 두면 된다(표준 Godot 워크플로, 이 프로젝트만의 특별한 절차는
  아니다).
- `build/`(내보내기 산출물)는 `.gitignore` 에 있어 저장소에 커밋되지 않는다 — 실제 배포용 빌드는 CI 나
  사용자 머신에서 새로 뽑아야 한다.

### 사용자가 할 일

- 실제 배포 전에 **진짜 Windows 머신(또는 rcedit 이 연결된 환경)에서 다시 내보내** 아이콘·제품 정보가
  탐색기에 정상적으로 보이는지 확인할 것(이 컨테이너에서는 rcedit 부재로 확인 불가).
- `export_presets.cfg` 의 `application/file_version`/`product_version` 을 실제 출시 버전에 맞게 올릴 것
  (지금은 `0.1.0.0` 자리표시자).
- 스팀에 올리려면 GodotSteam 애드온을 넣은 뒤(위 1절) 다시 내보내야 한다(지금 이 프리셋은 GodotSteam
  없이도 동작하는 상태 기준으로 만들어졌다 — 애드온을 넣어도 이 프리셋 자체는 그대로 쓸 수 있다).

## 3. 스토어 에셋

`tools/capture/store_assets/`(신규 폴더, `.gitignore` 에 추가 — 스크린샷은 이 프로젝트 관례상 저장소에
커밋하지 않는다, `tools/capture/out/` 과 동일 취급)에 아래를 만들어 뒀다. 다시 만들려면:

```bash
xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 -s tools/capture/capture.gd -- \
  scenario=title,idle,betting,big,jackpot,upgrade_late,skilltree,floor_ph,achievement_screen,ending_credits \
  lang=ko out=res://tools/capture/store_assets
xvfb-run -a -s "-screen 0 640x360x24" godot --rendering-driver opengl3 -s tools/capture/gen_store_logo.gd
```

- **스크린샷 10장**(1920×1080, `_x3` 접미사 파일 — 원본 640×360 파일도 같이 나오지만 스토어용은 `_x3` 를
  쓴다): 타이틀, 기본 플레이(휠+베팅판), 베팅 중, 빅윈, 잭팟, 업그레이드 화면, 스킬트리, 펜트하우스 층,
  업적 화면, 엔딩 크레딧. 전부 한국어로 찍었다 — 영어 스토어 페이지용은 `lang=en` 으로 다시 찍으면 된다.
- **투명 배경 로고**(`logo_transparent.png`, 960×204): 타이틀 화면과 같은 `NeonText` 컴포넌트를 투명
  배경 `SubViewport` 에 그려서 뽑았다(파이썬으로 네온 발광을 다시 만들지 않고 실제 엔진 렌더링을 재사용 —
  `tools/capture/gen_store_logo.gd`). **`assets/` 밖에 둔 이유**: 네온 발광 가장자리가 반투명 혼합색이라
  `test_ui_assets.gd` 의 "36색 팔레트만 쓰는지" 검사에 걸린다 — 이 파일은 게임이 실제로 불러오는 에셋이
  아니라 마케팅 전용이라 검사 대상 밖(`tools/capture/`)에 두는 게 맞다고 판단했다.
- **캡처 회귀 하나 발견·수정**: 8단계 2/N 에서 튜토리얼을 추가한 뒤로 `tools/capture/capture.gd` 의 모든
  "새 게임" 시나리오(약 90개 전부)가 화면에 튜토리얼 스포트라이트·대사를 겹쳐 보여주고 있었다(새 게임은
  항상 튜토리얼이 자동 시작되므로). `_fresh(keep_tutorial: bool = false)` 로 고쳐 `tutorial_*` 시나리오만
  튜토리얼을 켜 두고 나머지는 원래처럼 깨끗하게 나오게 했다(GDD 22장).
- **남은 흠 하나**: `jackpot` 스크린샷에 "클로버 하나로 문을 여셨네요..." 대사가 같이 뜬다 — 이 시나리오의
  설정(칩 강제 지급 + 골든 넘버 강제 적중)이 부수적으로 "첫 클로버 획득"도 함께 발동시켜서다(튜토리얼과
  무관한, 6단계부터 있던 동작). 더 깨끗한 스크린샷이 필요하면 캡처 전에 `game_state.call("add_clovers", 1)`
  로 클로버를 미리 만들어두고 다시 찍을 것.

## 4. 크레딧

`scenes/ui/credits_screen.gd`(1/N 작성)가 이미 개발사명(`Economy.STUDIO_NAME`)·Godot 엔진(MIT)·Galmuri
폰트(SIL OFL 1.1) 줄을 보여준다. 음악·효과음 출처 줄(`CREDITS_MUSIC_PENDING`)은 아직 "다음 업데이트에서
추가됩니다" 상태다 — 실제 CC0/라이선스 음원이 승인·추가되면(3/N 참고, 현재 네트워크 허용 대기 중) 그때
`translations/strings.csv` 의 이 키를 실제 곡명·저작자·라이선스로 바꿔야 한다. SFX(48종)는 전부
`tools/audio/gen_sfx.py` 로 직접 합성한 것이라 별도 크레딧이 필요 없다.

## 5. 크래시 안전성

GDScript 에는 try/catch 가 없어 "예외를 잡아서 저장"이라는 개념 자체가 다른 언어와 다르게 적용된다. 대신:

- **로그**: `project.godot` 에 `debug/file_logging/enable_file_logging=true` 를 켰다 — 이제 모든 실행이
  `user://logs/godot.log` (최근 10개 롤링, `file_logging/max_log_files=10`)에 콘솔 출력을 그대로 남긴다.
  플레이어가 크래시를 신고하면 이 로그를 받아서 원인을 찾을 수 있다.
- **저장**: GDScript 예외 대신 "언제든 죽어도 손해가 적게" 전략을 이미 4~7단계에서 갖췄다 — 업그레이드·
  스킬 구매, 층 이동, 빚 관련 이벤트, 운명의 휠, 창 닫기(`NOTIFICATION_WM_CLOSE_REQUEST`), 창 포커스
  잃음(`NOTIFICATION_APPLICATION_FOCUS_OUT`) 등 여러 시점마다 `SaveManager.save_game()` 을 이미 부르고
  있다(`scripts/autoload/save_manager.gd`). 정상 종료든 강제 종료든 대부분 몇 초 안의 진행만 잃는다.
- 진짜 엔진 크래시(세그폴트 등)는 스크립트 레벨에서 가로챌 수 없다 — Godot 자체의 크래시 핸들러(활성화 시
  `user://` 에 crash 로그를 남기는 플랫폼별 기능)에 맡긴다. 이번 단계에서 추가로 손댈 것은 없었다.

## 6. 스팀 페이지에 아직 없는 것 (사용자가 준비할 목록)

- Steamworks App ID, 스토어 페이지 문구(설명·태그·시스템 요구사항).
- 정식 스튜디오/개발자 이름(지금은 가제 "HOUSE EDGE" — 정해지면 `Economy.STUDIO_NAME` 등 3곳을 함께 바꿀 것,
  1단계 기록 참고).
- CC0/라이선스 배경음악 승인(3/N, 네트워크 허용 대기 중).
- 영어 스토어 자산(스크린샷 10장은 `lang=en` 으로 다시 찍기만 하면 됨).
