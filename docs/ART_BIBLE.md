# HOUSE EDGE — 아트 바이블

> 화면에 보이는 모든 것은 이 문서를 따른다. 새 규칙이 필요하면 먼저 이 문서를 고친다.
> 좌표·크기는 전부 **기준 해상도 640×360** 픽셀 기준이다(실제 창은 정수 배율로 확대).

---

## 1. 레이아웃 (640×360)

```
 0                                                              639
 ┌──────────────────────── 상단 바 y 0~23 ────────────────────────┐
 │                                                                 │
 │┌기록 패널┐        ┌──── 휠 ────┐            ┌─ 오른쪽 패널 ──┐ │
 ││x 4~103  │        │ 중심        │            │ x 420~635      │ │
 ││y 28~355 │        │ (262,192)   │            │ y 28~355       │ │
 ││         │        │ 림 반지름118│            │ 216×328        │ │
 ││         │        └─────────────┘            │ 베팅창 /       │ │
 ││         │     [ 버튼 영역 y 316~352 ]        │ 업그레이드창   │ │
 │└─────────┘                                    └────────────────┘ │
 └─────────────────────────────────────────────────────────────────┘
```

| 영역 | 좌표 |
|---|---|
| 상단 바 | y 0~23 (전체 폭). 칩·클로버·빚·층 표시 |
| 왼쪽 기록 패널 | x 4~103, y 28~355 (100×328). 최근 결과·통계 |
| 휠 | 중심 (262, 192), 바깥 림 반지름 118 → x 144~380, y 74~310 |
| 휠 아래 버튼 영역 | y 316~352 (스핀·자동·칩 크기 등) |
| 오른쪽 패널 | x 420~635, y 28~355 (216×328). 베팅창 ↔ 업그레이드창 (Tab 으로 전환) |
| 스킬트리 | 전체 화면 오버레이(K) |

---

## 2. 휠 반지름 규격 (중심 기준, 픽셀)

| 링 | 반지름 | 내용 |
|---|---|---|
| 바깥 나무 림 | 118 ~ 104 | 나무 톤, 금 장식 |
| 공 트랙 | 104 ~ 90 | 공 궤도 반지름 **97**, 디플렉터 8개 반지름 **91** |
| 숫자 링 | 90 ~ 76 | 숫자는 반지름 **83** 에 **똑바로 선 방향**으로 표시(회전시키지 않음 — 픽셀 선명도를 위한 의도된 스타일) |
| 포켓 링 | 76 ~ 60 | 빨강/검정/초록 포켓, 공 안착 반지름 **68** |
| 중앙 콘·터렛 | 60 ~ 0 | 금속 콘, 중앙 터렛 |

- 휠은 **반시계**, 공은 **시계** 방향으로 돈다.
- 포켓 각도는 `RouletteRules.pocket_angle(n)` (0번 = 0도, WHEEL_ORDER 순서로 360/37 도씩, 화면상 시계 방향 증가). 휠 회전각을 더해 화면 각도를 얻는다.

---

## 3. 팔레트 — 아래 36색만 사용 (알파 변화만 허용)

코드에서는 `Palette.<NAME>` 상수(`scripts/core/palette.gd`)로 쓴다. 이 표와 코드가 항상 같아야 한다(`test_data.gd` 가 36색·중복 없음을 검사).

| 그룹 | 이름 | HEX | 이름 | HEX | 이름 | HEX |
|---|---|---|---|---|---|---|
| 배경 | void | `#0b0a14` | night | `#16142a` | dusk | `#221e3d` |
| 배경 | shadow | `#2f2a52` | | | | |
| 무채색 | ink | `#3e3a4f` | stone | `#6e6882` | mist | `#b8b2c4` |
| 무채색 | ivory | `#f4f0e8` | | | | |
| 펠트 | felt_d | `#0f3d2e` | felt | `#16573f` | felt_l | `#1f7552` |
| 펠트 | felt_hl | `#2c9468` | | | | |
| 나무 | wood_d | `#3b2218` | wood | `#5c3524` | wood_l | `#83502f` |
| 나무 | wood_hl | `#a8703f` | | | | |
| 금 | gold_d | `#6b4a12` | gold | `#a8781c` | gold_l | `#e0ac2c` |
| 금 | gold_hl | `#ffd95a` | gold_shine | `#fff2b0` | | |
| 빨강 | red_d | `#4a0f1a` | red | `#8a1a2b` | red_l | `#c9303c` |
| 빨강 | red_hl | `#f25a5a` | | | | |
| 검정 포켓 | pocket_k | `#121016` | pocket_k_l | `#26222e` | | |
| 네온 | neon_pink | `#ff4fa3` | neon_cyan | `#3fe0ff` | neon_purple | `#7b3fe0` |
| 네온 | purple_d | `#3d1f73` | | | | |
| 클로버 | clover | `#5ee06b` | clover_d | `#2a9e3a` | | |
| 기타 | sky | `#2b4a8f` | water | `#1b3a5c` | amber | `#ff9a3c` |

### 3-1. 의미 색

| 의미 | 색 | 상수 |
|---|---|---|
| 칩 | gold_hl | `Palette.SEM_CHIP` |
| 클로버 | clover | `Palette.SEM_CLOVER` |
| 빚·경고 | red_hl | `Palette.SEM_WARNING` |
| 비활성 | stone | `Palette.SEM_DISABLED` |
| 포커스 | neon_cyan | `Palette.SEM_FOCUS` |

### 3-2. 구슬 팔레트 (MarbleDef 5색: outline / shadow / base / light / shine)

| tier | 재질 | outline | shadow | base | light | shine | fx_id |
|---|---|---|---|---|---|---|---|
| 0 | 나무 | wood_d | wood | wood_l | wood_hl | ivory | — |
| 1 | 돌 | shadow | ink | stone | mist | ivory | — |
| 2 | 구리 | wood_d | wood_l | wood_hl | amber | gold_shine | glint |
| 3 | 철 | void | night | ink | stone | mist | glint |
| 4 | 은 | ink | stone | mist | ivory | ivory | glint |
| 5 | 금 | gold_d | gold | gold_l | gold_hl | gold_shine | sparkle |
| 6 | 옥 | felt_d | felt | felt_l | felt_hl | mist | sparkle |
| 7 | 루비 | red_d | red | red_l | red_hl | ivory | sparkle |
| 8 | 사파이어 | night | water | sky | neon_cyan | ivory | sparkle |
| 9 | 에메랄드 | felt_d | felt | clover_d | clover | ivory | sparkle |
| 10 | 다이아몬드 | water | sky | mist | ivory | neon_cyan | prism |
| 11 | 흑요석 | void | night | shadow | ink | neon_purple | prism |
| 12 | 별빛 | dusk | purple_d | sky | gold_hl | gold_shine | stars |
| 13 | 공허 | void | purple_d | neon_purple | neon_pink | ivory | void_swirl |
| 14 | 코스믹 | purple_d | neon_purple | neon_pink | neon_cyan | gold_shine | cosmic_swirl |

fx_id 의미(2·3단계에서 구현): glint = 가끔 1px 하이라이트가 스쳐 지나감, sparkle = 반짝이 픽셀 2~3개, prism = 무지개 하이라이트 순환, stars = 내부 별 점멸, void_swirl/cosmic_swirl = 내부 소용돌이 프레임 애니메이션.

---

## 4. 픽셀아트 규칙

- **광원은 좌상단.** 명암은 3~4단계 셀 셰이딩(그라데이션 금지).
- **외곽선은 순수 검정 대신** 해당 색의 가장 어두운 톤(예: 나무 → wood_d, 금 → gold_d).
- **수동 AA** 는 곡선 외곽에만(중간 톤 1픽셀).
- **디더링**은 배경 그라데이션에만 제한적으로.
- 배경은 채도·명도를 낮추고(void/night/dusk/shadow/felt_d 위주), **휠과 구슬이 화면에서 가장 밝고 선명한 요소**가 되게 한다.
- 텍스처 필터는 Nearest(프로젝트 기본값). 밉맵 끔.
- 모든 스프라이트는 정수 좌표에 배치(프로젝트에 2D 픽셀 스냅 켜져 있음). 회전하는 요소(휠)는 저해상도 SubViewport 나 사전 렌더 프레임으로 픽셀 느낌을 유지한다.

---

## 5. 폰트

- **Galmuri 9 / 11 / 14** (SIL OFL 1.1, https://github.com/quiple/galmuri). 한글·영문 모두 지원.
  - 9: 작은 라벨·툴팁, 11: 본문·버튼, 14: 제목·강조
  - **안티앨리어싱 끔**(FontFile antialiasing = None, hinting None, subpixel positioning Disabled), 폰트 크기는 원래 픽셀 크기의 정수배만.
  - `assets/fonts/` 에 두고 OFL 라이선스 파일을 함께 넣는다(2단계).
- 큰 금액은 **전용 비트맵 숫자 폰트**(0-9, 소수점, 단위 문자, +/-, e)를 2단계에서 제작한다.

---

## 6. 애니메이션 타이밍

| 항목 | 값 |
|---|---|
| UI 전환(패널 열기·닫기) | 0.18초 ease-out (허용 범위 0.15~0.25) |
| 버튼 눌림 | 내용(텍스트·아이콘)이 1px 아래로 |
| 카운트업 | 기본 0.4초, 큰 금액 1.5~2초 |
| 떠오르는 텍스트 | 0.8초 동안 16px 상승, 마지막 0.3초 페이드 |
| 흔들림 | 정수 1~3px |

- 스케일 팝은 쓰지 않는다(소수 배율 금지). 대신 1~2px 이동, 프레임 교체, 색·알파 변화.

---

## 7. 당첨 연출 등급

배율 = 순이익 ÷ 총 베팅액. 판정은 `SpinOutcome.tier`(GDD 4-2).

| 등급 | 조건 | 연출 |
|---|---|---|
| LOSS | 당첨 없음 | 회색(stone) "-1.2K", 진 구슬이 어두워짐. **벌주는 연출은 없다.** 개별숫자 베팅이 바로 옆 포켓이면(`near_miss`) "아깝다!" |
| NORMAL | 0~5배 | 금색(gold_hl) 떠오르는 텍스트, 작은 반짝임, 코인음 |
| GOOD | 5~20배 | NORMAL + 칩 파티클 20개, 1px 흔들림 0.15초 |
| BIG | 20배 이상 또는 개별숫자 적중 | "BIG WIN!" 네온 배너, 흰(ivory) 플래시(알파 0.25, 2프레임), 코인 분수 60개, 2px 흔들림 0.3초, 클로버가 상단 바로 비행 |
| JACKPOT | 100배 이상 또는 개별숫자 2개 이상 동시 적중 | 전체 화면: 배경 어둡게, 회전 금빛 광선, "JACKPOT" 글자 낙하, 코인 비, 2초 카운트업, 클릭으로 닫기 |

- 모든 연출은 설정의 **"흔들림 끄기"** 와 **"번쩍임 줄이기"** 를 따른다(흔들림 0px, 플래시 알파 0 또는 크게 감소).
- 황금 포켓 적중(`golden_hit`) 시 결과 포켓이 금색으로 번쩍이고 "×3" 표시.

---

## 8. 에셋 제작 방식

- 픽셀 에셋은 `tools/art/*.py`(Python + Pillow)로 **팔레트를 고정해 픽셀 단위로 그리는 스크립트**로 만들거나, Godot 에서 저해상도로 절차적으로 그린다.
- 스크립트는 `Palette` 와 같은 36색 표를 쓰고, 팔레트 밖 색이 나오면 실패하게 만든다.
- 생성 후 반드시 **4배 확대 미리보기 PNG** 를 직접 보고 수정을 반복한다(미리보기는 커밋하지 않아도 됨: `build/` 에 저장).
- 모든 에셋의 파일명·크기·용도를 아래 "에셋 목록"에 기록해, 나중에 사람이 그린 그림으로 교체할 수 있게 한다. 교체 시 크기·피벗·프레임 배치를 유지하면 코드 수정이 필요 없어야 한다.

### 8-1. 에셋 목록

| 파일 | 크기(px) | 프레임 | 용도 | 생성 방법 | 단계 |
|---|---|---|---|---|---|
| _(아직 없음 — 2단계부터 추가)_ | | | | | |
