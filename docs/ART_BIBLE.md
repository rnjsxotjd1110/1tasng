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

### 2-1. 휠 레이어와 스핀 연출 (2단계)

| 순서(아래 → 위) | 내용 | 그리는 방법 |
|---|---|---|
| 1 | 드롭 섀도(휠 오른쪽 아래 4·6px) | `wheel_shadow.png` |
| 2 | 바깥 림·공 트랙·디플렉터(22.5°+45°k)·숫자 링 바탕 | `wheel_base.png` |
| 3 | 회전 링: 포켓 37(가장자리 red/pocket_k/felt, 안쪽 red_l/pocket_k_l/felt_l), 금 칸막이, 3×5 숫자(똑바로 선 방향), 황금 포켓(gold + 반짝임) | `_draw()` · `draw_colored_polygon`(AA 없음) |
| 4 | 포켓 경계 금선·중앙 콘 | `wheel_top.png` |
| 5 | 회전 터렛(금 십자 + 손잡이 구슬), 콘 위 금 점 8개, 허브, 4~6초마다 허브를 스치는 빛 | `_draw()` + `wheel_hub/knob.png` |
| 6 | 고정 곡선 반사광 | `wheel_highlight.png` |
| 7 | 공(구슬 재질 5색 + 스페큘러), 그림자, 1px gold_shine 테두리 빛(알파 0.35) | `marble.png` 재질 색 치환 |
| 8 | 디플렉터 불꽃(1px, 0.28초), 결과 포켓 빛 링 | `_draw()` |

- 모션 블러: 휠 각속도 200/330/450°/s 초과 시 1/180초 간격 이전 각도를 알파 0.45/0.3/0.2 로 겹쳐 그린다(3개면 포켓 색이 섞인 띠). 공은 260°/s 초과 시 잔상 2개(알파 0.4/0.18).
- 스핀 단계(`SpinChoreography`): A 발사 0~0.3초(T×0.12 이하) · B 궤도 ~0.55T · C 낙하 ~0.8T(반지름 97→92→68, 디플렉터 1~3회 튕김, T<2.5초면 1회) · D 안착 ~0.9T(홉 1~2회) · E 동행 ~T. 휠 최대 540°/s, 감속 ω=W(1-x)^1.2.
- 결과: 포켓 흰색/금색 3회 점멸(0.24초 주기) + 퍼지는 빛 링 0.7초, 이후 은은한 링 유지. 스킵은 남은 연출을 0.3초로 감는다.

### 2-2. 화면 요소 좌표 (2단계 확정)

| 요소 | 좌표·크기 |
|---|---|
| 상단 바 | 칩 아이콘 (5,5) 13px, 칩 숫자 (21,1) 14px 폰트, 초당 수익 (22,15) 7px 폰트, 층 이름 x 중심 262, 오른쪽 탭 끝 x 636 |
| 결과 배지 | 중심 x 262, y 30~57(27px), 부제 y+28. 공이 여러 개면 66px 간격 |
| SPIN | (222,318) 80×30, 뒤에 숨쉬는 빛(가산). AUTO (310,323) 52×20 |
| BIG WIN 배너 | 중심 (262,200) |
| 떠오르는 텍스트(순이익) | 중심 (262,150) |
| 토스트 | 중심 x 262, y 286 위로 쌓임 |
| 베팅창 내부 | 보드 (12,26) 192×224: 0 칸 13px, 숫자판 64×13 × 3×12, 외부 95×15 2×2, 트레이 y 210. 칩 크기 y 253, 금액 y 271·283, 버튼 y 297 |
| 기록 패널 내부 | 결과 테이프 (6,24) 88×162(행 13px, 빨강 x24 / 0 x50 / 검정 x76), 비율 막대 y 204·236, 핫 y 258, 콜드 y 276, 스핀·연승 y 298 |

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

fx_id 의미: glint = 가끔 1px 하이라이트가 스쳐 지나감, sparkle = 반짝이 픽셀 2~3개, prism = 무지개 하이라이트 순환, stars = 내부 별 점멸, void_swirl/cosmic_swirl = 내부 소용돌이. **3단계에서 재질별 표면 디테일·부가 효과로 구체화했다(9-1).**

---

## 4. 픽셀아트 규칙

- **광원은 좌상단.** 명암은 3~4단계 셀 셰이딩(그라데이션 금지).
- **외곽선은 순수 검정 대신** 해당 색의 가장 어두운 톤(예: 나무 → wood_d, 금 → gold_d).
- **수동 AA** 는 곡선 외곽에만(중간 톤 1픽셀).
- **디더링**은 배경 그라데이션에만 제한적으로.
- 배경은 채도·명도를 낮추고(void/night/dusk/shadow/felt_d 위주), **휠과 구슬이 화면에서 가장 밝고 선명한 요소**가 되게 한다.
- 텍스처 필터는 Nearest(프로젝트 기본값). 밉맵 끔.
- 5색에 더해 재질 강조색(다이아 무지개 red_hl·gold_hl·clover·neon_purple, 흑요석 neon_purple·purple_d, 코스믹 purple_d·neon_purple·neon_pink·neon_cyan)을 셰이더가 쓴다(`MarbleSprite.ACCENTS`).
- 모든 스프라이트는 정수 좌표에 배치(프로젝트에 2D 픽셀 스냅 켜져 있음). 회전하는 요소(휠)는 저해상도 SubViewport 나 사전 렌더 프레임으로 픽셀 느낌을 유지한다.

---

## 5. 폰트

- **Galmuri 9 / 11 / 11 Bold / 14** (SIL OFL 1.1, https://github.com/quiple/galmuri). 한글·영문 모두 지원. 권장 크기 9→10px, 11→12px, 14→15px.
  - 9: 작은 라벨·툴팁, 11: 본문·버튼, 14: 제목·강조
  - **안티앨리어싱 끔**(FontFile antialiasing = None, hinting None, subpixel positioning Disabled), 폰트 크기는 원래 픽셀 크기의 정수배만.
  - `assets/fonts/` 에 두고 OFL 라이선스 파일을 함께 넣는다(2단계).
- 큰 금액은 **전용 비트맵 숫자 폰트**: `num14_*`(Galmuri11 Bold 모양 + 금색 그라데이션·외곽선·그림자, 줄 높이 14) 와 `num7_*`(3×5 직접 디자인 + 외곽선, 줄 높이 7). 색 5종 gold/ivory/red/stone/clover. 숫자는 고정폭이라 카운트업 중 흔들리지 않는다. 테마 변형 `Num14Gold` 등으로 쓰고 글꼴 색은 흰색(곱하기 1)이다. 3단계: num14 의 0 가운데에 점(단위 Oc·Ocd 의 O 와 구분), num7 에 `L`·`v`(Lv 표기)를 더했다.

---

## 6. 애니메이션 타이밍

| 항목 | 값 |
|---|---|
| UI 전환(패널 열기·닫기) | 0.18초 ease-out (허용 범위 0.15~0.25) |
| 버튼 눌림 | 내용(텍스트·아이콘)이 1px 아래로 |
| 카운트업 | 기본 0.4초, 큰 금액 1.5~2초 |
| 떠오르는 텍스트 | 0.8초 동안 16px 상승, 마지막 0.3초 페이드 |
| 흔들림 | 정수 1~3px |
| 구슬 놓기 비행 | 0.26초, 포물선 높이 14px, 착지 2px 튐 0.16초 |
| 진 구슬 | 0.45초 동안 어두워지며 휠 중심으로, 0.9초 뒤 칸에 다시 나타남(0.25초) |
| 날아가는 칩 | 0.55초 곡선, 0.045초 간격, 도착마다 카운터 1px 튐 + 딸깍 |
| 결과 기록 토큰 | 0.32초 낙하(끝에 작게 튐), 나머지는 0.2초에 한 칸 밀림 |

- 스케일 팝은 쓰지 않는다(소수 배율 금지). 대신 1~2px 이동, 프레임 교체, 색·알파 변화.

| 항목(3단계) | 값 |
|---|---|
| 오른쪽 패널 전환 | 0.18초 ease-out cubic, 현재 패널이 216px 밀려나고 새 패널이 들어옴(업그레이드는 베팅의 오른쪽). 전환 중에만 잘라 냄 |
| 업그레이드 구매 반응 | 카드 흰(ivory 0.85) 플래시 2프레임 → 아이콘 2px 튐(0.05초) → 1px(0.05초) → 0 · 코인음 피치 +0.05/연속 구매(최대 1.7, 0.9초 쉬면 처음으로) · 칩 카운터 0.25초 감소 |
| 연속 구매 | 0.4초 뒤부터, 간격 0.18초 × 0.85^n (최소 0.04초) |
| 탭 빨간 점 | 5×5, 알파 0.45~1.0 맥동(3.2 rad/s) |
| 카드 스크롤 | 휠 한 칸 22px, 지수 감쇠(18/s) 후 정수 픽셀로 반올림, 3px 레일 드래그 가능 |
| 새 슬롯 | 홈이 3프레임(2px → 6px → 12px)으로 0.2초에 열림('딸깍') → 구슬이 오른쪽 끝에서 0.5초 굴러 들어옴(2.5바퀴, ease-out) |
| 황금 포켓 빛줄기 | 1.1초: 0.46초 동안 위에서 내려와 포켓에 닿음 → 포켓 금색 + 불꽃 14개 + 빛 링, 나머지 시간 페이드 |

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
- 4단계: 설정의 **"큰 당첨 연출 간략"** 이면 BIG·JACKPOT 도 배너·플래시·흔들림을 생략(떠오르는 텍스트·소리·클로버 비행은 유지). **"오토 스핀 중 연출 줄이기"** 는 오토 스핀 중일 때만 BIG 미만(NORMAL·GOOD)의 파티클·흔들림을 생략한다(`VisualSettings.full_effects`).

---

## 9. 업그레이드·구슬 재질 (3단계)

### 9-1. 구슬 재질 15종

- **크기 3종**: 휠 7px(`ui/marble.png`) · 베팅칸·트레이 10px(`marbles/marble_10.png`) · 카드·연출 24px(`marbles/marble_24.png`). 승급 연출의 48px 는 24px 의 2배 정수 확대. 템플릿은 나무 구슬 5색으로 그린 **음영 인덱스 맵**(wood_d 외곽선 · wood 그림자 · wood_l 바탕 · wood_hl 밝은 면 · ivory 광택)이다.
- **셰이더** `assets/shaders/marble.gdshader`: 인덱스를 재질 5색으로 바꾸고, 텍셀 좌표로 구의 법선을 계산해 **텍셀 단위**로 표면 디테일을 얹는다(출력은 항상 팔레트 색 → 픽셀 퍼펙트). 그리기 색(modulate)이 인스턴스 값: r 밝기(진 구슬이 어두워짐 = void 로 덮기), g 굴림 위상, b 회전 속도(미리보기 1, 정지 0), a 알파.
- 모든 구슬 CanvasItem 은 `MarbleSprite.shared_material()` 하나를 공유한다 → 재질이 바뀌면 `sync_shared()` 한 번으로 휠·트레이·베팅칸·카드가 함께 바뀐다. 고정 재질이 필요한 곳(비교 시트, 승급 연출의 이전 구슬)은 `material_for(tier)`.
- 그림자·테두리 빛·부가 효과는 셰이더 없는 CanvasItem(`MarbleFx`)이 그린다. 구슬 뒤: 흑요석 테두리 광, 코스믹 성운 빛, 공허 고리 / 구슬 앞: 반짝임 별, 보석 반짝이, 다이아 무지개, 별빛 궤도 별, 공허 빨려드는 입자, 코스믹 별가루.

| tier | 재질 | 표면 디테일(셰이더) | 부가 효과(MarbleFx) | 휠 궤적 |
|---|---|---|---|---|
| 0 | 나무 | 굴러가는 나뭇결 줄 + 옹이(24px) | — | 잔상만 |
| 1 | 돌 | 어두운·밝은 반점 | — | 잔상만 |
| 2 | 구리 | 환경 반사 띠 + 가로 금속 결, glint | — | 1px 금속 불티 |
| 3 | 철 | 어두운 반사 띠 + 긁힌 자국 + 반점, glint | — | 1px 금속 불티 |
| 4 | 은 | 크롬 반사(밝은 하늘·어두운 수평선), glint | — | 1px 금속 불티 |
| 5 | 금 | 한 단계 밝은 금 + 수평선 반사 띠 + 아래 반사광, 빠른 glint | 주기적 4방향 별 | 금 반짝이 + 잔상 1 |
| 6 | 옥 | 은은한 면(8) + 우윳빛 구름 | 반짝이 2~3개, 별 | 재질색 + 모양 + 잔상 1 |
| 7 | 루비 | 면 12개, 면 경계선 | 〃 | 〃 |
| 8 | 사파이어 | 면 16개 | 〃 | 〃 |
| 9 | 에메랄드 | 세로로 긴 면 10개(스텝 컷) | 〃 | 〃 |
| 10 | 다이아몬드 | 면 24개, 흰 얼음빛 대비, 면 중심의 무지개 스파클 | 무지개 스파클 + 반짝이 + 별 | 무지개 + 잔상 1 |
| 11 | 흑요석 | 검은 유리 + 조개껍질 물결 + 보라 반사 줄, 외곽선이 보라로 맥동 | 보라빛 테두리 광 + 별 | 보라 잔상 공 + 잔상 2 |
| 12 | 별빛 | 밤하늘(하늘색·보라) + 점멸하는 1px 별 | 둘레를 도는 별 + 꼬리 | 별 입자 + 잔상 2 |
| 13 | 공허 | 가운데 검은 구멍 + 빨려드는 소용돌이 팔 + 사건의 지평선 | 어두운 고리 + 빨려드는 입자, **주변 화면 왜곡**(`void_lens.gdshader`) | 빨려드는 입자 + 잔상 2 |
| 14 | 코스믹 | 흐르는 4색 성운 + 별가루 | 성운 빛 + 궤도 별가루 | 여러 색 별가루(0.8초) + 잔상 3 |

- 금속·금·보석은 주기적으로 대각선 빛(glint)이 스친다(금 2.4초, 나머지 3.2초). 보석(옥~다이아)과 별빛 이후는 정지 상태에서도 천천히 돈다(면 반사가 회전).
- 공허 왜곡: 구슬 주변 원(휠 9px, 보드 8px) 안의 화면을 정수 픽셀 단위로 소용돌이치며 안쪽으로 당겨 다시 읽는다(BackBufferCopy + 화면 텍스처). 새 색을 만들지 않는다.
- 검수: `tools/capture/marble_sheet.gd` 로 15종 비교 시트(48·24·10·7px)를 찍는다.

### 9-2. 업그레이드창 (오른쪽 패널 216×328)

| 요소 | 좌표·크기 |
|---|---|
| 제목 | y 8, LabelTitle |
| 구매 수량 | 라벨 (12, 29), 토글 ×1/×10/MAX 34×16 × 3 (오른쪽 끝 x 204), ChipButton |
| 카드 영역 | (7, 47) 200×274, 잘라 냄. 카드 간격 3px, 레일 x 208 3px(void 바탕, 금 손잡이) |
| 일반 카드 200×44 | 아이콘 칸 (4,12) 20×20 + 16×16 아이콘 · 이름 (28,3) LabelBold · 효과 (28,22) Num7("×1.35 → ×1.82", 다음 값 clover) · 셋째 줄 (28,33) "Lv.12"(Num7Gold) + 레벨당 효과(Num7Stone) · 구매 버튼 (130,5) 66×28 · 부족분 바 버튼 아래 3px |
| 재질 카드 200×68 | 미리보기 칸 (4,4) 34×34 + 24px 회전 구슬 · 재질 이름 + "6/15" (42,3) · "당첨 배율" (42,18) · 배율 변화 (42,30) · 버튼 (130,19) · 수집 띠 15종 7px (6,57) 8px 간격(없는 재질은 ink 실루엣) |
| 구매 버튼 | 살 수 있으면 ButtonGold, 아니면 ButtonStone. 안에 수량 "×37"(Num7, 좌상단) + 칩 아이콘 + 비용(Num14). 누르면 내용 1px 아래로 |
| 잠김 | CardLocked, 실루엣 아이콘(`*_locked.png`), 이름 LabelMuted, 해금 조건 문구(LabelSmallMuted), 오른쪽 끝 자물쇠 9×11 |
| 최대 레벨 | CardMax(금 테두리) + MAX 스탬프 30×14(버튼 자리), 효과값 Num7Gold |
| 카드 배경 | CardNormal(ink 테) · CardHover(stone 테) · CardReady(살 수 있음, 금 테) · CardMax · CardLocked · CardMarble(purple_d 벨벳 + 금 테) |
| 툴팁 | 이름 — 설명 / 현재 → 다음(format_full) / 비용 전체 숫자 (×수량) / 공식 / 비용 배율 / 부족분 또는 "누르고 있으면 연속 구매" |

### 9-3. 재질 승급 연출 (MarblePromotion, 약 2.4초)

| 시각(초) | 내용 |
|---|---|
| 0 ~ 0.25 | 화면 void 알파 0 → 0.72 |
| 0.1 ~ 0.45 | 이전 구슬 48px 가 화면 중앙(320,150)으로 16px 떠오름(알파 0 → 1, 정수 픽셀) |
| 0.45 ~ 1.15 | 빛이 모임: 새 재질 밝은 색 입자 70/초가 안쪽으로, 광선 12개가 줄어들며 모임, 고리 맥동. 구슬 흔들림 0 → 1 → 2px(점점 빨라짐). promote_charge |
| 1.15 | 흰 섬광(ivory 0.9 → 0, 0.25초, 번쩍임 줄이기 따름) + 새 재질로 변신 + 재질 5색 입자 72개 폭발 + 빛 링 2개. promote_flash + 징글(tier 1~4: 1, 5~9: 2, 10~14: 3단계 — 높을수록 길고 화음·반짝임이 많다) |
| 1.25 ~ | 배너 "금 구슬 획득!"(LabelTitle) + "당첨 배율 ×900 → ×8.00K"(LabelGold)를 PanelPlain 판 위에 8px 아래에서 올리며 표시 |
| 1.95 ~ 2.35 | 구슬이 트레이(베팅창) 또는 재질 카드로 포물선(34px) 비행, 48 → 24 → 10px 로 템플릿 교체. 닿으면 모든 구슬이 새 재질 |
| ~ 2.5 | 어둠·배너 페이드 아웃. 클릭·Space 는 즉시 적용 후 0.15초 페이드 |

### 9-4. 황금 포켓

- 구매: 금빛 빛줄기(11px, `golden_beam.png` 세로로 늘림)가 휠 위에서 무작위 포켓으로 떨어지고, 닿는 순간 포켓이 금색(gold/gold_l + 반짝임), 베팅창 해당 숫자 칸에 금 테두리(gold_hl + gold_l 맥동)와 은은한 금빛.
- 결과가 황금 포켓: 결과 배지 아래 (262, 72) 에 "황금 ×3"(BadgeGolden 금 패널 + LabelBold, 6px 떨어지며 등장, 모서리 반짝임) + 포켓에서 금 코인 파티클 26개. 다음 스핀에 사라짐.

## 8. 에셋 제작 방식

- 픽셀 에셋은 `tools/art/*.py`(Python + Pillow)로 **팔레트를 고정해 픽셀 단위로 그리는 스크립트**로 만들거나, Godot 에서 저해상도로 절차적으로 그린다.
- 스크립트는 `Palette` 와 같은 36색 표를 쓰고, 팔레트 밖 색이 나오면 실패하게 만든다.
- 생성 후 반드시 **4배 확대 미리보기 PNG** 를 직접 보고 수정을 반복한다(미리보기는 커밋하지 않아도 됨: `build/art_preview/` 에 저장).
- 재생성 순서: `python3 tools/art/gen_ui.py && python3 tools/art/gen_fonts.py && python3 tools/art/gen_wheel.py && python3 tools/art/gen_bg.py && python3 tools/art/gen_fx.py && python3 tools/art/gen_upgrades.py && python3 tools/audio/gen_sfx.py` → `godot --headless --import` → `godot --headless -s tools/art/build_theme.gd`.
- 테스트 `test_ui_assets.gd` 가 `assets/sprites`·`assets/ui`·`assets/fonts` 의 모든 PNG 에 팔레트 밖 색이 없는지 검사한다.
- 모든 에셋의 파일명·크기·용도를 아래 "에셋 목록"에 기록해, 나중에 사람이 그린 그림으로 교체할 수 있게 한다. 교체 시 크기·피벗·프레임 배치를 유지하면 코드 수정이 필요 없어야 한다.

### 8-1. 에셋 목록

| 파일 | 크기(px) | 프레임 | 용도 | 생성 방법 | 단계 |
|---|---|---|---|---|---|
| `assets/fonts/num14_clover.png` | 256×59 | 1 | 큰 숫자 비트맵 폰트 14px (clover) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/fonts/num14_gold.png` | 256×59 | 1 | 큰 숫자 비트맵 폰트 14px (gold) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/fonts/num14_ivory.png` | 256×59 | 1 | 큰 숫자 비트맵 폰트 14px (ivory) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/fonts/num14_red.png` | 256×59 | 1 | 큰 숫자 비트맵 폰트 14px (red) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/fonts/num14_stone.png` | 256×59 | 1 | 큰 숫자 비트맵 폰트 14px (stone) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/fonts/num7_clover.png` | 256×7 | 1 | 작은 숫자 비트맵 폰트 7px (clover) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/fonts/num7_gold.png` | 256×7 | 1 | 작은 숫자 비트맵 폰트 7px (gold) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/fonts/num7_ivory.png` | 256×7 | 1 | 작은 숫자 비트맵 폰트 7px (ivory) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/fonts/num7_red.png` | 256×7 | 1 | 작은 숫자 비트맵 폰트 7px (red) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/fonts/num7_stone.png` | 256×7 | 1 | 작은 숫자 비트맵 폰트 7px (stone) + .fnt | tools/art/gen_fonts.py | 2 |
| `assets/sprites/bg/b1/lamp.png` | 33×16 | 1 | 천장 램프 갓 | tools/art/gen_bg.py | 2 |
| `assets/sprites/bg/b1/lamp_cone.png` | 220×250 | 1 | 램프 빛 원뿔(가산) | tools/art/gen_bg.py | 2 |
| `assets/sprites/bg/b1/light_pool.png` | 320×250 | 1 | 휠 주변 빛 웅덩이(가산) | tools/art/gen_bg.py | 2 |
| `assets/sprites/bg/b1/poster.png` | 40×52 | 1 | 현상수배 포스터(래칫 복선) | tools/art/gen_bg.py | 2 |
| `assets/sprites/bg/b1/smoke.png` | 24×16 | 1 | 연기 입자 | tools/art/gen_bg.py | 2 |
| `assets/sprites/bg/b1/table.png` | 640×360 | 1 | B1 나무 레일 + 펠트 테이블 | tools/art/gen_bg.py | 2 |
| `assets/sprites/bg/b1/wall.png` | 640×360 | 1 | B1 벽돌 벽·파이프·얼룩 | tools/art/gen_bg.py | 2 |
| `assets/sprites/fx/jackpot_letters.png` | 196×35 | 1 | JACKPOT 금 글자(Galmuri Bold ×3) | tools/art/gen_fx.py | 2 |
| `assets/sprites/fx/neon_cyan.png` | 450×52 | 2(켬/끔) | 네온 글자 아틀라스(청록) | tools/art/gen_fx.py | 2 |
| `assets/sprites/fx/neon_pink.png` | 450×52 | 2(켬/끔) | 네온 글자 아틀라스(윗줄 켜짐/아랫줄 꺼짐) | tools/art/gen_fx.py | 2 |
| `assets/sprites/ui/badge_black.png` | 27×27 | 1 | 결과 배지(black) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/badge_gold.png` | 27×27 | 1 | 결과 배지(gold) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/badge_green.png` | 27×27 | 1 | 결과 배지(green) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/badge_pop_black.png` | 33×33 | 1 | 결과 배지 등장 1프레임(큰 크기) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/badge_pop_gold.png` | 33×33 | 1 | 결과 배지 등장 1프레임(큰 크기) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/badge_pop_green.png` | 33×33 | 1 | 결과 배지 등장 1프레임(큰 크기) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/badge_pop_red.png` | 33×33 | 1 | 결과 배지 등장 1프레임(큰 크기) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/badge_red.png` | 27×27 | 1 | 결과 배지(red) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/check_off.png` | 9×9 | 1 | 체크박스 끔 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/check_on.png` | 9×9 | 1 | 체크박스 켬 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/coin.png` | 28×7 | 4 | 회전 코인 4프레임 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/digits_3x5.png` | 30×5 | 1 | 3×5 숫자 10개(휠·토큰·베팅 칸) | tools/art/gen_fonts.py | 2 |
| `assets/sprites/ui/icon_black.png` | 7×9 | 1 | 검정 베팅 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_chip.png` | 13×13 | 1 | 금 칩 아이콘 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_chip_small.png` | 7×7 | 1 | 날아가는 칩 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_close.png` | 7×7 | 1 | 닫기 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_clover.png` | 11×11 | 1 | 클로버 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_even.png` | 7×7 | 1 | 짝 베팅 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_flame.png` | 7×8 | 1 | 핫 넘버 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_gear.png` | 11×11 | 1 | 설정 탭 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_lock.png` | 7×9 | 1 | 자물쇠 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_odd.png` | 7×7 | 1 | 홀 베팅 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_red.png` | 7×9 | 1 | 빨강 베팅 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/icon_snow.png` | 7×7 | 1 | 콜드 넘버 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/marble.png` | 7×7 | 1 | 구슬 템플릿 7px(휠), 나무 5색 인덱스 → marble.gdshader 가 재질로 치환 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/particle_chip2.png` | 2×2 | 1 | 칩 파티클 2×2 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/particle_chip3.png` | 3×3 | 1 | 칩 파티클 3×3 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/particle_clover.png` | 3×3 | 1 | 클로버 파티클 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/slider_grabber.png` | 7×11 | 1 | 슬라이더 손잡이 | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/slider_grabber_hover.png` | 7×11 | 1 | 슬라이더 손잡이(호버) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/sparkle.png` | 20×5 | 4 | 반짝임 4프레임(금) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/sparkle_white.png` | 20×5 | 4 | 반짝임 4프레임(흰) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/token_black.png` | 11×11 | 1 | 기록·베팅 칸 숫자 토큰(black) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/token_gold.png` | 11×11 | 1 | 기록·베팅 칸 숫자 토큰(gold) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/token_green.png` | 11×11 | 1 | 기록·베팅 칸 숫자 토큰(green) | tools/art/gen_ui.py | 2 |
| `assets/sprites/ui/token_red.png` | 11×11 | 1 | 기록·베팅 칸 숫자 토큰(red) | tools/art/gen_ui.py | 2 |
| `assets/sprites/wheel/wheel_base.png` | 240×240 | 1 | 휠 바깥 림·공 트랙·디플렉터 8·볼트 8·숫자 링 바탕 | tools/art/gen_wheel.py | 2 |
| `assets/sprites/wheel/wheel_highlight.png` | 240×240 | 1 | 고정 곡선 반사광(ivory 알파) | tools/art/gen_wheel.py | 2 |
| `assets/sprites/wheel/wheel_hub.png` | 16×16 | 1 | 터렛 허브(회전 팔 위) | tools/art/gen_wheel.py | 2 |
| `assets/sprites/wheel/wheel_knob.png` | 5×5 | 1 | 터렛 손잡이 끝 구슬 | tools/art/gen_wheel.py | 2 |
| `assets/sprites/wheel/wheel_shadow.png` | 240×240 | 1 | 휠 드롭 섀도(알파) | tools/art/gen_wheel.py | 2 |
| `assets/sprites/wheel/wheel_top.png` | 240×240 | 1 | 포켓 경계 금선(76·60)·중앙 콘 | tools/art/gen_wheel.py | 2 |
| `assets/ui/button_dark_disabled.png` | 14×16 | 1 | 버튼 상태 dark_disabled (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_dark_hover.png` | 14×16 | 1 | 버튼 상태 dark_hover (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_dark_normal.png` | 14×16 | 1 | 버튼 상태 dark_normal (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_dark_pressed.png` | 14×16 | 1 | 버튼 상태 dark_pressed (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_disabled.png` | 14×16 | 1 | 버튼 상태 disabled (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_gold_disabled.png` | 14×16 | 1 | 버튼 상태 gold_disabled (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_gold_hover.png` | 14×16 | 1 | 버튼 상태 gold_hover (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_gold_normal.png` | 14×16 | 1 | 버튼 상태 gold_normal (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_gold_pressed.png` | 14×16 | 1 | 버튼 상태 gold_pressed (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_hover.png` | 14×16 | 1 | 버튼 상태 hover (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_normal.png` | 14×16 | 1 | 버튼 상태 normal (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/button_pressed.png` | 14×16 | 1 | 버튼 상태 pressed (9-slice 3) | tools/art/gen_ui.py | 2 |
| `assets/ui/frame_cell.png` | 8×8 | 1 | 펠트 칸, 9-slice 2 | tools/art/gen_ui.py | 2 |
| `assets/ui/frame_inset.png` | 8×8 | 1 | 움푹 들어간 칸, 9-slice 2 | tools/art/gen_ui.py | 2 |
| `assets/ui/panel_bar.png` | 16×16 | 1 | 상단 바, 9-slice 5 | tools/art/gen_ui.py | 2 |
| `assets/ui/panel_dark.png` | 16×16 | 1 | 기본 패널(금 테·리벳), 9-slice 6 | tools/art/gen_ui.py | 2 |
| `assets/ui/panel_felt.png` | 216×328 | 1 | 베팅창 바탕(펠트 노이즈·금선) | tools/art/gen_ui.py | 2 |
| `assets/ui/panel_plain.png` | 16×16 | 1 | 테 없는 패널, 9-slice 5 | tools/art/gen_ui.py | 2 |
| `assets/ui/scroll_grabber.png` | 6×8 | 1 | 스크롤 손잡이 | tools/art/gen_ui.py | 2 |
| `assets/ui/scroll_grabber_hover.png` | 6×8 | 1 | 스크롤 손잡이 | tools/art/gen_ui.py | 2 |
| `assets/ui/scroll_grabber_pressed.png` | 6×8 | 1 | 스크롤 손잡이 | tools/art/gen_ui.py | 2 |
| `assets/ui/scroll_track.png` | 6×8 | 1 | 스크롤 트랙 | tools/art/gen_ui.py | 2 |
| `assets/ui/slider_fill.png` | 8×6 | 1 | 슬라이더 채움 | tools/art/gen_ui.py | 2 |
| `assets/ui/slider_track.png` | 8×6 | 1 | 슬라이더 트랙 | tools/art/gen_ui.py | 2 |
| `assets/ui/spin_disabled.png` | 80×30 | 1 | SPIN 버튼 disabled | tools/art/gen_ui.py | 2 |
| `assets/ui/spin_glow.png` | 92×42 | 1 | SPIN 숨쉬는 빛(가산) | tools/art/gen_ui.py | 2 |
| `assets/ui/spin_hover.png` | 80×30 | 1 | SPIN 버튼 hover | tools/art/gen_ui.py | 2 |
| `assets/ui/spin_normal.png` | 80×30 | 1 | SPIN 버튼 normal | tools/art/gen_ui.py | 2 |
| `assets/ui/spin_pressed.png` | 80×30 | 1 | SPIN 버튼 pressed | tools/art/gen_ui.py | 2 |
| `assets/ui/tab_hover.png` | 12×16 | 1 | 탭 hover (9-slice 4) | tools/art/gen_ui.py | 2 |
| `assets/ui/tab_normal.png` | 12×16 | 1 | 탭 normal (9-slice 4) | tools/art/gen_ui.py | 2 |
| `assets/ui/tab_selected.png` | 12×16 | 1 | 탭 selected (9-slice 4) | tools/art/gen_ui.py | 2 |
| `assets/ui/tooltip.png` | 8×8 | 1 | 툴팁, 9-slice 2 | tools/art/gen_ui.py | 2 |
| `assets/audio/sfx/ball_roll_loop.wav` | 1.00초 | — | 효과음 `ball_roll_loop` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/chip_click.wav` | 0.12초 | — | 효과음 `chip_click` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/clover_get.wav` | 0.53초 | — | 효과음 `clover_get` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/coin_drop.wav` | 0.32초 | — | 효과음 `coin_drop` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/deflector_hit.wav` | 0.27초 | — | 효과음 `deflector_hit` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/deny.wav` | 0.32초 | — | 효과음 `deny` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/lose.wav` | 0.61초 | — | 효과음 `lose` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/marble_place.wav` | 0.24초 | — | 효과음 `marble_place` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/marble_remove.wav` | 0.19초 | — | 효과음 `marble_remove` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/near_miss.wav` | 0.70초 | — | 효과음 `near_miss` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/neon_flicker.wav` | 0.34초 | — | 효과음 `neon_flicker` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/panel_close.wav` | 0.26초 | — | 효과음 `panel_close` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/panel_open.wav` | 0.26초 | — | 효과음 `panel_open` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/pocket_land.wav` | 0.43초 | — | 효과음 `pocket_land` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/spin_start.wav` | 0.55초 | — | 효과음 `spin_start` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/ui_click.wav` | 0.15초 | — | 효과음 `ui_click` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/ui_hover.wav` | 0.03초 | — | 효과음 `ui_hover` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/win_big.wav` | 1.46초 | — | 효과음 `win_big` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/win_good.wav` | 0.67초 | — | 효과음 `win_good` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/win_jackpot.wav` | 2.46초 | — | 효과음 `win_jackpot` | tools/audio/gen_sfx.py | 2 |
| `assets/audio/sfx/win_normal.wav` | 0.49초 | — | 효과음 `win_normal` | tools/audio/gen_sfx.py | 2 |
| `assets/fonts/Galmuri9.ttf` `Galmuri11.ttf` `Galmuri11-Bold.ttf` `Galmuri14.ttf` | 10·12·12·15px | — | 본문 글꼴(OFL, `assets/fonts/OFL.txt`) | quiple/galmuri dist | 2 |
| `assets/ui/theme_main.tres` | — | — | 프로젝트 기본 테마(모든 UI) | tools/art/build_theme.gd | 2 |
| `assets/shaders/vignette.gdshader` `rays.gdshader` | — | — | 배경 비네트, JACKPOT 회전 광선(팔레트 색 + 알파만) | 손으로 작성 | 2 |
| `assets/sprites/marbles/marble_10.png` | 10×10 | 1 | 구슬 템플릿 10px(베팅칸·트레이), 나무 5색 인덱스 | tools/art/gen_upgrades.py | 3 |
| `assets/sprites/marbles/marble_24.png` | 24×24 | 1 | 구슬 템플릿 24px(카드·연출, 48px 는 ×2) | tools/art/gen_upgrades.py | 3 |
| `assets/sprites/ui/upgrades/icon_{marble_tier,marble_polish,bet_limit,marble_count,spin_speed,golden_pocket}.png` | 16×16 | 1 | 업그레이드 아이콘 6종 | tools/art/gen_upgrades.py | 3 |
| `assets/sprites/ui/upgrades/icon_*_locked.png` | 16×16 | 1 | 잠긴 카드 실루엣(ink + shadow 테) | tools/art/gen_upgrades.py | 3 |
| `assets/ui/card_{normal,hover,ready,max,locked,marble}.png` | 12×12 | 1 | 업그레이드 카드 배경, 9-slice 4 | tools/art/gen_upgrades.py | 3 |
| `assets/ui/card_slot.png` | 8×8 | 1 | 카드 아이콘 칸(움푹), 9-slice 2 | tools/art/gen_upgrades.py | 3 |
| `assets/ui/button_stone_{normal,hover,pressed,disabled}.png` | 14×16 | 1 | 살 수 없는 구매 버튼(stone 톤), 9-slice 3 | tools/art/gen_ui.py | 3 |
| `assets/ui/badge_golden.png` | 10×12 | 1 | "황금 ×3" 배지 바탕, 9-slice 4 | tools/art/gen_upgrades.py | 3 |
| `assets/sprites/ui/stamp_max.png` | 30×14 | 1 | 최대 레벨 MAX 스탬프 | tools/art/gen_upgrades.py | 3 |
| `assets/sprites/ui/notify_dot.png` | 5×5 | 1 | 탭 빨간 점 | tools/art/gen_upgrades.py | 3 |
| `assets/sprites/ui/arrow_right.png` | 7×5 | 1 | 효과 변화 화살표 | tools/art/gen_upgrades.py | 3 |
| `assets/sprites/ui/golden_beam.png` | 11×64 | 1 | 황금 포켓 빛줄기(세로로 늘려 씀, 알파) | tools/art/gen_upgrades.py | 3 |
| `assets/sprites/ui/icon_lock_big.png` | 9×11 | 1 | 잠긴 카드 자물쇠 | tools/art/gen_upgrades.py | 3 |
| `assets/shaders/marble.gdshader` `void_lens.gdshader` | — | — | 구슬 재질(팔레트 치환 + 표면 디테일), 공허 주변 왜곡 | 손으로 작성 | 3 |
| `assets/audio/sfx/buy_coin.wav` | 0.36초 | — | 업그레이드 구매 코인음(연속 구매 시 피치 상승) | tools/audio/gen_sfx.py | 3 |
| `assets/audio/sfx/slot_open.wav` | 0.24초 | — | 트레이 새 홈 '딸깍' | tools/audio/gen_sfx.py | 3 |
| `assets/audio/sfx/marble_roll.wav` | 0.60초 | — | 새 구슬이 굴러 들어옴 | tools/audio/gen_sfx.py | 3 |
| `assets/audio/sfx/golden_beam.wav` | 1.62초 | — | 황금 포켓 빛줄기 | tools/audio/gen_sfx.py | 3 |
| `assets/audio/sfx/promote_charge.wav` | 0.95초 | — | 승급: 빛이 모임 | tools/audio/gen_sfx.py | 3 |
| `assets/audio/sfx/promote_flash.wav` | 1.20초 | — | 승급: 섬광·폭발 | tools/audio/gen_sfx.py | 3 |
| `assets/audio/sfx/promote_jingle_{1,2,3}.wav` | 0.89·1.73·2.82초 | — | 승급 징글(재질이 높을수록 웅장) | tools/audio/gen_sfx.py | 3 |
| `assets/sprites/ui/icon_vault.png` | 16×16 | 1 | 금고(복귀 팝업, 딜러 루시 초상화 나오기 전 자리) | tools/art/gen_ui.py | 4 |
| `assets/sprites/ui/icon_warning.png` | 9×9 | 1 | 경고(저장 손상 복구 토스트) | tools/art/gen_ui.py | 4 |
| `assets/shaders/dither_dim.gdshader` | — | — | 일시정지 오버레이(화면 전체 4×4 Bayer 디더, vignette.gdshader 와 같은 기법·반지름 감쇠 없음) | 손으로 작성 | 4 |
| `assets/sprites/npc/baron_world.png` | 48×64 | 7행×최대6열(12장 참고) | 래칫 남작 월드 스프라이트(걷기·대기·말하기·인사·웃음·화남·돈세기) | tools/art/gen_baron.py | 5 |
| `assets/sprites/npc/baron_portrait.png` | 64×64 | 7(12장 참고) | 래칫 남작 초상화(표정 5 + 입벙긋 2) | tools/art/gen_baron.py | 5 |
| `assets/sprites/npc/underling_rat.png` | 32×40 | 6(lean2+walk4) | 부하 쥐(선글라스·검은 양복) | tools/art/gen_baron.py | 5 |
| `assets/sprites/ui/icon_debt.png` | 13×13 | 1 | 빚 두루마리 아이콘(상단 바) | tools/art/gen_baron.py | 5 |
| `assets/sprites/ui/icon_baron_mini.png` | 16×16 | 1 | 패널티 토스트용 남작 미니 초상 | tools/art/gen_baron.py | 5 |
| `assets/sprites/fx/seizure_stamp.png` | 16×16 | 1 | 압류 패널티: 빨간 발바닥 도장(계약서 서명 도장과 공용) | tools/art/gen_baron.py | 5 |
| `assets/sprites/ui/icon_penalty_watcher.png` | 12×12 | 1 | 패널티 토스트: 감시하는 부하 | tools/art/gen_baron.py | 5 |
| `assets/sprites/ui/icon_penalty_pickpocket.png` | 12×12 | 1 | 패널티 토스트: 소매치기 | tools/art/gen_baron.py | 5 |
| `assets/sprites/ui/icon_penalty_smoke.png` | 12×12 | 1 | 패널티 토스트: 시가 연기 | tools/art/gen_baron.py | 5 |
| `assets/sprites/ui/icon_penalty_blur.png` | 12×12 | 1 | 패널티 토스트: 흐려진 구슬 | tools/art/gen_baron.py | 5 |
| `assets/sprites/ui/icon_penalty_seize.png` | 12×12 | 1 | 패널티 토스트: 압류 | tools/art/gen_baron.py | 5 |
| `assets/audio/sfx/dialogue_blip_baron.wav` | 0.05초 | — | 대사 타자기 목소리 '삑'(낮은 톤, 피치 랜덤) | tools/audio/gen_sfx.py | 5 |
| `assets/audio/sfx/baron_footstep.wav` | 0.18초 | — | 남작 발소리 | tools/audio/gen_sfx.py | 5 |
| `assets/audio/sfx/baron_cane_tap.wav` | 0.14초 | — | 지팡이 소리 | tools/audio/gen_sfx.py | 5 |
| `assets/audio/sfx/bass_drop.wav` | 0.9초 | — | 파산 시 저음 콘트라베이스 한 번 | tools/audio/gen_sfx.py | 5 |
| `assets/audio/sfx/contract_unroll.wav` | 0.6초 | — | 계약서 양피지 펼침 | tools/audio/gen_sfx.py | 5 |
| `assets/audio/sfx/quill_sign.wav` | 0.8초 | — | 깃펜 서명 | tools/audio/gen_sfx.py | 5 |
| `assets/audio/sfx/stamp_thud.wav` | 0.3초 | — | 도장 '쾅' | tools/audio/gen_sfx.py | 5 |
| `assets/audio/sfx/chip_bag_toss.wav` | 0.5초 | — | 칩 자루 토스 | tools/audio/gen_sfx.py | 5 |
| `assets/audio/sfx/pickpocket_squeak.wav` | 0.3초 | — | 소매치기 "찍!" | tools/audio/gen_sfx.py | 5 |
| `assets/sprites/wheel/{b1,1f,2f,3f,ph}/wheel_shadow.png` | 240×240 | 1 | 휠 드롭 섀도(알파, 층 공용 형태) | tools/art/gen_wheel.py | 7 |
| `assets/sprites/wheel/{b1,1f,2f,3f,ph}/wheel_base.png` | 240×240 | 1 | 휠 바깥 림·트랙·디플렉터·숫자 링 바탕(층별 재질 테마) | tools/art/gen_wheel.py | 7 |
| `assets/sprites/wheel/{b1,1f,2f,3f,ph}/wheel_top.png` | 240×240 | 1 | 포켓 경계·중앙 콘(층별 재질 테마) | tools/art/gen_wheel.py | 7 |
| `assets/sprites/wheel/{b1,1f,2f,3f,ph}/wheel_highlight.png` | 240×240 | 1 | 고정 곡선 반사광(1F 는 gloss 배율 ↑) | tools/art/gen_wheel.py | 7 |
| `assets/sprites/wheel/{b1,1f,2f,3f,ph}/wheel_hub.png` | 16×16 | 1 | 터렛 허브(층별 금속 톤) | tools/art/gen_wheel.py | 7 |
| `assets/sprites/wheel/{b1,1f,2f,3f,ph}/wheel_knob.png` | 5×5 | 1 | 터렛 손잡이 끝 구슬(층별 금속 톤) | tools/art/gen_wheel.py | 7 |
| `assets/sprites/bg/1f/wall.png` | 640×360 | 1 | 1F 붉은 카펫 벽지·금 기둥 2개·슬롯머신 3대(불빛은 코드가 덧그림) | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/1f/chandelier.png` | 64×28 | 1 | 1F·PH 공용 크리스털 샹들리에 | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/1f/guest_silhouette.png` | 10×22 | 1 | 가끔 지나가는 손님 실루엣 | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/2f/wall.png` | 640×360 | 1 | 2F 나무 선실 벽판·둥근 창 2개(투명 구멍) | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/2f/river.png` | 360×60 | 1 | 창 뒤로 스크롤하는 달빛 강(region_rect 슬라이딩) | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/2f/lantern.png` | 12×18 | 1 | 흔들리는 선상 등불 | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/3f/wall.png` | 640×360 | 1 | 3F 밤 스카이라인(별·창 불빛 일부는 코드가 무작위 점멸) | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/3f/bar.png` | 58×34 | 1 | 칵테일 바 실루엣 | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/ph/wall.png` | 640×360 | 1 | PH 대리석 벽·금 기둥·벨벳 커튼·구름과 달 | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/ph/madame_silhouette.png` | 44×40 | 2(idle·와인잔) | 마담 벨벳 뒤태 실루엣(3/N 실제 캐릭터 전 복선) | tools/art/gen_bg.py | 7 |
| `assets/sprites/bg/{1f,2f,3f,ph}/table.png` | 640×360 | 1 | B1 `table.png` 그대로 복사(게임 판은 층과 무관) | tools/art/gen_bg.py(복사) | 7 |
| `assets/sprites/bg/{1f,2f,3f,ph}/lamp_cone.png` `light_pool.png` | 220×250 / 320×250 | 1 | 층별 색(gold_shine·amber·neon_cyan·neon_purple·ivory)으로 다시 구운 조명 웅덩이 | tools/art/gen_bg.py | 7 |
| `assets/sprites/title/dev_logo.png` | 220×40 | 1 | 스플래시 개발사 워드마크(가제) + 칩 글리프 | tools/art/gen_title.py | 8 |
| `assets/sprites/title/bg_wall.png` | 640×360 | 1 | 타이틀 배경(비 내리는 밤거리·카지노 정면, 정적) | tools/art/gen_title.py | 8 |
| `assets/sprites/title/wheel_icon.png` | 16×16 | 8(회전) | 타이틀 로고 아래 미니 룰렛 아이콘 | tools/art/gen_title.py | 8 |

---

## 10. 저장·설정·일시정지·통계 화면 (4단계)

### 10-1. 설정 / 통계 화면

- 스킬트리와 같은 자리: 640×336, 상단 바 아래 전체(`(0, 24)`), `PanelPlain`.
- 설정: 왼쪽에 탭 5개(오디오/화면/게임/접근성/데이터, 세로 목록, `TabButton`), 오른쪽에 탭별 컨트롤 목록. 슬라이더·체크박스·선택 버튼 그룹(2~4단계에서 이미 준비된 `HSlider`/`CheckBox`/`Button` 테마를 그대로 쓴다 — 새 자산 없음).
- 통계: 두 단 목록, 숫자는 `CountLabel` 카운트업.
- 포커스 테두리: `FocusStyle`(`scenes/ui/focus_style.gd`) 가 `neon_cyan`(`Palette.SEM_FOCUS`) 1px 테두리 스타일박스를 개별 컨트롤에 override 한다(전역 테마는 그대로 — 다른 화면 버튼은 여전히 포커스 표시 없음).
- 열기·닫기: 기존 `PanelTransition`(0.18초)을 그대로 쓴다.

### 10-2. 일시정지 메뉴

- 화면 전체(640×360, 상단 바 포함)를 `dither_dim.gdshader` 로 어둡게 덮고, 가운데 150×190 `PanelFelt` 메뉴.
- 버튼 5개(세로, 120×20): 계속하기 / 설정 / 통계 / 저장 후 타이틀로(비활성, 잠금 툴팁) / 게임 종료. 아래에 "메뉴 중 게임 진행" 체크박스.
- `PauseMenu` 는 `process_mode = PROCESS_MODE_ALWAYS` 라 `get_tree().paused` 여도 계속 그려지고 입력을 받는다.

### 10-3. 복귀 팝업

- 272×150 `PanelFelt`, 좌상단 32×32 초상화 자리(`icon_vault.png` ×2 정수 확대, 8단계에 루시 초상화가 생기면 자동 교체), 우측에 인사말·경과 시간·수익 카운트업(1.5초, `CountLabel.Style.SIGNED`)·[받기] 버튼.
- 카운트업 동안 "chip_click" 효과음을 간격을 0.16초 → 0.03초로 줄여가며 재생(가속 느낌). [받기] 를 누르면 `GameState.add_chips()` 로 실제 지급.

---

## 11. 래칫 남작 · 부하 쥐 · 빚 UI (5단계)

### 11-1. 래칫 남작 캐릭터 시트

- `tools/art/gen_baron.py` 가 절차적으로 그린다(팔레트 36색, `pixlib.Canvas` + 타원/직선 도우미). 사람이 그린 그림으로 바꿀 때는
  아래 프레임 규격·피벗만 유지하면 코드 수정이 필요 없다.
- 팔레트 배정: 정장 `purple_d`(기본)/`night`(그림자)/`neon_purple`(하이라이트) + 핀스트라이프 `mist`, 회중시계 줄 `gold`/`gold_l`,
  모자(중절모) `ink`/`night` + 금 밴드 `gold`, 외알 안경 `gold_d` 테 + `ivory` 반사 1px, 시가 `wood`/`wood_l` + 팁 `amber`(연기 `mist` 알파),
  털 `stone`(기본)/`ink`(그림자)/`mist`(하이라이트), 꼬리 `neon_pink`, 지팡이 `wood_d` + `gold` 손잡이.
- `assets/sprites/npc/baron_world.png`(48×64, 캐릭터는 오른쪽을 본다 — 왼쪽으로 걸어 들어올 때는 게임에서 좌우 반전해 쓴다):
  행(위→아래) walk 6 / idle 4 / talk 4 / tip_hat 5 / laugh 4 / angry 3 / counting_money 4, 열은 각 행의 프레임 순서(왼→오),
  행마다 남는 칸은 투명. 발바닥 기준선은 프레임 바닥에서 4px 위(y=60).
- `assets/sprites/npc/baron_portrait.png`(64×64 × 7): 0 기본 · 1 웃음 · 2 교활한 미소(눈썹 올라감) · 3 놀람(입 벌어짐+눈 커짐) ·
  4 만족(모자 벗음, 귀 노출) · 5·6 입벙긋(열림/닫힘 — `DialogueBox` 가 타자기 진행 중에만 5·6을 번갈아 보여주고, 멈추면 대사에 지정된 기본 표정으로 돌아간다).
- `draw_baron()` 포즈 매개변수(교체용 그림이 아니라 이 스크립트를 계속 쓸 경우의 손잡이): `leg`(0~1 보행 위상), `arm`(팔 흔들림 위상),
  `tail`(꼬리 흔들림 위상), `hat_lift`/`hat_tilt`(인사), `mouth`(closed/talk_open/laugh/angry/smile), `brow`(normal/up/angry/wide),
  `bob`/`lean`(몸 상하·좌우), `hands`(cigar/swing/hat/money/fist/belly), `cane`(지팡이 유무).

### 11-2. 부하 쥐

- `assets/sprites/npc/underling_rat.png`(32×40 × 6, `draw_underling()`): lean 2(테이블에 기댐, 팔 아래로) + walk 4.
- 팔레트: 양복 `night`(기본)/`void`(그림자)/`ink`(옷깃 줄), 털은 남작과 같은 3색, 선글라스는 `void` 통짜 렌즈 + `mist` 눈썹 줄 1px.

### 11-3. 대화창 (DialogueBox, 재사용 가능)

- 화면 하단, `(12, 268)` 616×84 `PanelFelt`. 왼쪽 64×64 초상화(`baron_portrait.png` 프레임, 말하는 동안 5·6 번갈아 겹쳐 그림),
  오른쪽에 이름표(y+10, 화자 색 — 남작은 `gold_l`)와 본문(y+26, 520×50, `LabelBody`, 자동 줄바꿈).
- 타자기: 초당 30자, 쉼표·마침표에서 0.12초/0.25초 정지. 글자 2자마다(공백 제외) `dialogue_blip_<화자>` 재생, 피치 `randf_range(0.85,1.15)`.
- 완료되면 우하단에 튀는 `▼`(0.5초 주기, 2px 상하). 클릭·Space: 타이핑 중이면 즉시 완성, 완성 상태면 다음 줄(또는 선택지면 무시).
- 선택지: 본문 아래 세로 버튼 목록(범용 기능 — 5단계 자체 대사는 분기가 없다, GDD 9장 "거절 없음").
- 열기·닫기는 `PanelTransition`(아래에서 위로, offset (0,10)).
- 대화창이 열리는 컷신(`BaronLoanSequence`/`BaronPayoffSequence`)에서 남작의 발 위치 `BARON_Y` 는 268 이 아니라 **258**(64px
  스프라이트가 y=194~258 을 차지, DialogueBox 상단 y=268 과 10px 여유) — 340 처럼 DialogueBox 영역(268~352) 안으로 들어오면
  스프라이트와 대화 텍스트가 겹쳐 보인다(캡처 검수로 발견해 수정).

### 11-4. 계약서 팝업 (ContractPopup)

- 260×180, 화면 중앙 `((640-260)/2, (360-180)/2)` = `(190, 90)`. 양피지는 별도 이미지 자산이 아니라
  `ContractPopup._on_draw_parchment()` 가 `_draw()` 로 매 프레임 그린다(`ivory` 바탕 + `wood_l` 테두리 + `mist` 얼룩 점 몇 개) —
  9-slice 로 늘어나는 텍스처가 필요 없을 만큼 단순한 모양이라 절차적으로 그리는 쪽을 택했다.
- 펼침 연출(0.4초): 세로 스케일 대신 **위쪽에서부터 정수 픽셀 단위로 높이가 자라나며 아래 내용이 순서대로 드러나는** 마스크(`clip_contents` 를
  높이만 애니메이션) 방식 — 소수 배율 스케일 금지 규칙을 지킨다.
- 내용: 제목("대출 계약서") · 대출액/상환액/상환 방식(당첨금 25% 자동) 3줄(`format_full`) · 서명란 · [서명한다] 버튼(`ButtonGold`).
- 서명: 깃펜이 서명란을 따라 지그재그로 0.5초간 그려짐(quill_sign 재생) → 빨간 발바닥 도장(`seizure_stamp.png` 와 별도, 서명용은 같은
  16×16 모양을 `red_hl` 톤으로) 이 쾅 찍히며 1px 흔들림 2회(stamp_thud) → 칩 자루가 상단 바로 토스(`FlyingChips`, `top_bar.chip_target()`).

### 11-5. 빚 UI

- 상단 바 `debt_box`(이미 자리 있음, TopBar 오른쪽): `icon_debt.png` 13×13 + `Num14Red` 금액. 빚이 있을 때만 보이고
  알파 0.7~1.0 로 은은히 맥동(주기 2.4초). 바로 아래 y=24 에 1px 상환 진행 바(전체 원금 대비 남은 비율, `red_d`→`red_hl`).
- 클릭하면 `DebtPanel`(신규): `(420, 26)` 200×148 드롭다운(`PanelPlain`, `PanelTransition` offset (0,-6)). 빚 건별로
  원금·잔액·진행률 바 한 줄씩, 오른쪽에 [전액][절반] 버튼(칩 부족하면 `ButtonStone` disabled).
- 당첨 텍스트: 자동 상환이 있었던 스핀은 순이익 텍스트(`Num14Gold`, 기존 `TEXT_ANCHOR`) 아래 8px 에 작게 "−N 상환"(`Num7Red`) 을
  추가로 띄운다. 상환분은 `FlyingChips` 2개가 별도 자산 없이 `TopBar.debt_target()`(살아있는 빚 아이콘·금액의 현재 위치)으로 날아간다
  (칩이 도착할 무렵엔 위 상환으로 금액이 이미 줄어 있는 채라 두루마리 전용 스프라이트가 따로 필요 없었다).

### 11-6. 패널티 토스트 (PenaltyToast)

- 상단 바 아래 중앙(x=262 기준 가운데 정렬, y=28), 160×24 `PanelPlain`. 왼쪽 `icon_baron_mini.png` 16×16, 가운데 패널티 이름(`LabelSmall`),
  아래 2px 진행바(남은 시간 비율 — 즉시·소모형 패널티는 고정 3초 표시), 오른쪽에 패널티 아이콘(효과별).
- 구현 주의: 진행바(배경+전경 ColorRect 2장)는 패널(`PanelContainer`)의 자식으로 넣지 않는다 — Container 는 직계 자식을 전부 같은
  콘텐츠 영역에 맞춰 늘리므로(1개 자식만 쓰는 게 정상 용법) 얇은 바가 패널 전체 크기로 늘어나 버린다. `PenaltyToast`(plain Control) 의
  자식으로 두고 패널 위치를 따라가게 매 프레임 수동 배치한다(`TopBar._debt_bar` 가 `debt_box` 를 따라가는 것과 같은 방식).
- `EventBus.penalty_triggered(id, duration)` 로 뜨고 `EventBus.buff_ended(id)` 로 즉시 닫힌다(시간제는 자연 만료, 압류·클로버
  수수료는 소모 시). 여러 개가 겹치면 세로로 쌓인다(`ToastLayer` 와 같은 슬라이드 방식).
- 압류 전용: 베팅창 트레이 마지막 칸에 `seizure_stamp.png` 가 0.2초 동안 1px 흔들리며 나타났다 사라진다("찰싹").
- 흐려진 구슬 전용: 구슬 셰이더 `desaturate` 값이 0→1 로 즉시 올라가고(패널티 종료 시 0으로), 활성 중에는 `MarbleFx` 의
  반짝임(glint/sparkle 등) 스폰을 건너뛴다.
- 시가 연기 전용: `assets/sprites/bg/b1/smoke.png` 입자가 기록 패널(x4~103)과 휠 왼쪽 절반 위로 알파 0.35 안팎으로 흘러간다
  (포켓 색이 비쳐 보여야 하므로 알파를 낮게 유지 — 결과 가독성 유지, GDD 9장). 이 텍스처 자체가 배경 장식용이라 알파가 이미
  낮게(최대 약 0.27) 그려져 있어, `SmokeOverlay.MAX_ALPHA` 는 1.0 을 넘겨(1.3) 곱해야 화면에서 실제로 "0.35 안팎"으로 보인다
  (그래도 텍스처 자체 알파가 상한이라 완전히 불투명해지진 않는다) — 배경용 텍스처를 패널티 연출에 재사용할 때 겪은 함정.

---

## 12. 층 진행·엘리베이터·휠 스킨 (7단계)

### 12-1. 층별 강조색

| 층 | 강조색 1(주) | 강조색 2(보조) | 상수 |
|---|---|---|---|
| B1 | gold | wood_hl | `FloorTheme.ACCENTS["b1"]` |
| 1F | red_hl | gold_hl | `FloorTheme.ACCENTS["1f"]` |
| 2F | amber | wood_hl | `FloorTheme.ACCENTS["2f"]` |
| 3F | neon_cyan | neon_purple | `FloorTheme.ACCENTS["3f"]` |
| PH | gold_hl | neon_purple | `FloorTheme.ACCENTS["ph"]` |

`scripts/core/floor_theme.gd`(순수 표시용, 로직에 영향 없음)이 표를 코드로 갖는다. 엘리베이터 확인 팝업의 썸네일(단색
스와치, 48×48)에 쓴다 — 층 전체를 그린 축소 일러스트 대신 강조색만 보여주는 것으로 범위를 줄였다(아래 12-4 참고).

### 12-2. 층별 배경

- 레이어 구성은 B1(2단계)과 같다: 벽(wall, 640×360) → 게임 판(table, 640×360, **B1 것을 그대로 복사** — 판 자체는
  층과 무관하게 항상 같아야 가독성이 유지된다) → 조명(가산 블렌딩) → [층별 특수 요소] → 비네트.
- **1F 다운타운 카지노**: 붉은 바둑판 벽지 + 금 기둥 2개, 슬롯머신 3대(불빛 3개는 `Background1F._draw_lights()` 가
  칸마다 0.33주기씩 어긋나게 순차 점멸), 크리스털 샹들리에(반짝임은 정적 텍스처, 애니메이션 생략), 가끔(13초 주기,
  5초간) 위쪽 빈 띠(y 58)를 가로지르는 손님 실루엣.
- **2F 리버보트 카지노**: 나무 판벽 + 둥근 창 2개(벽 텍스처에 뚫린 투명 구멍), 창 뒤에 `river.png`(360×60)를
  `Sprite2D.region_rect.position.x` 를 매 프레임 슬라이딩해 스크롤(달빛 기둥 포함), 흔들리는 등불 2개(B1 램프와 같은
  사인파 흔들림), **배경 루트 전체**(World 가 아니라 Background2F 안의 컨테이너만)가 5.5초 주기로 1px 좌우로 흔들린다.
- **3F 스카이 라운지**: 스카이라인 실루엣(건물 높이 무작위, 일부 창은 텍스처에 이미 켜진 채로 구움) + `_draw_flicker()`
  가 창 16개를 각자 다른 주기(2.5~7초)로 추가 점멸, 별, 비행기 점멸등(26초 주기 중 16초 동안 화면을 가로지르며
  0.6초 간격으로 깜빡), 네온 시안·퍼플 웅덩이 2개(고정 조명 기구 없이 벽 자체가 은은히 빛나는 것으로 표현), 칵테일 바.
- **PH 펜트하우스**: 대리석 벽(가는 곡선 결 5가닥 — 처음엔 2D 사인 필드로 시도했더니 체크무늬/물방울무늬처럼 보여
  실패, 가늘게 휘는 줄 5개를 직접 그리는 방식으로 교체), 금 기둥 2개, 양옆 벨벳 커튼, 구름과 달(위쪽 띠에 고정),
  1F 것을 재사용한 대형 샹들리에. 마담 벨벳 본인은 배경에 박아넣은 실루엣이 아니라 실제 월드 액터(`MadameVelvet`,
  13-1)로 나온다 — 2/N 초안에서 임시로 쓰던 `madame_silhouette.png` 2프레임 자리는 3/N 에서 진짜 캐릭터로 교체하며
  뺐다(배경 스크립트에서 관련 코드 전부 제거).
- 배경 스왑은 `Main._background_for_floor(index)`(층 id → 클래스, B1 만 기존 `.tscn`) + `EventBus.floor_changed` 로
  일어난다. 층별 배경 클래스는 `scenes/main/bg/background_{1f,2f,3f,ph}.gd`(B1 과 달리 `.tscn` 없이 전부 `_ready()`
  에서 코드로 짓는다 — 스킬트리·일시정지 메뉴 등 6단계 화면들과 같은 패턴).

### 12-3. 층별 휠 스킨

- "림·트랙·터렛만 교체"(요청 명세) — **포켓 링(빨강/검정/초록)과 숫자는 층과 무관하게 고정**이다(결과 판독성을 위해
  절대 안 바꾼다). `tools/art/gen_wheel.py` 가 5개 테마(`THEMES` 딕셔너리, "wood" 4색 램프 + "gold" 5색 램프 +
  `cone_center` + `gloss`(반사 세기) + `grain_accent`(결 강조색) + `rivets`(리벳 점 유무))로 기존 기하(반지름·볼트·
  디플렉터 배치)를 그대로 재사용해 `assets/sprites/wheel/<층 id>/` 에 6개 파일을 굽는다. B1 은 기존 하드코딩 색과
  바이트 단위로 동일하게 나오는지 확인했다(`cmp` 로 검증 후 기존 루트 파일 삭제).
  - B1 낡은 나무 + 금(기존).
  - 1F 는 같은 나무 램프에 `grain_accent="red_d"`(마호가니 결 강조)와 `gloss=1.7`(광택 반사 세기)만 다르다 —
    팔레트에 마호가니 갈색이 따로 없어 "광택"(밝기·반사)으로 차별화했다(GDD 17장과 같은 원칙: 팔레트 제약은
    수치·강도로 우회).
  - 2F 는 "wood" 슬롯에 금색 램프를, "gold" 슬롯에 나무색 램프를 넣어 황동 몸체 + 어두운 목재/리벳 트림으로 뒤집었다.
    `_draw_rivets()` 가 림 안쪽을 따라 못대가리 점 48개를 찍는다.
  - 3F 는 회색조(ink/stone/mist/ivory) 몸체 + 청록 반짝임(gold 슬롯의 4번째 자리를 neon_cyan 으로). 회전하지 않는
    청록 빛이 림을 따라 도는 것은 `RouletteWheel._draw_neon_sweep()`(고정 반지름 118, 4초 주기, 50° 호 + 꼬리
    5단계)이 매 프레임 그린다(정적 텍스처가 아니라 런타임 효과).
  - PH 는 금→아이보리 몸체 + 보라·금 장식. "보석 8개 순차 반짝임"은 `RouletteWheel._draw_gem_twinkle()`(볼트와 같은
    반지름 111, 8개 위치, 3.2초 주기로 한 번에 하나씩 보라→금색으로 밝아졌다 사라짐).
- `RouletteWheel.set_floor_skin(index)`: Shadow/Base/Top/Highlight 스프라이트 텍스처와 허브·손잡이 텍스처(더 이상
  `const` 프리로드가 아니라 `load()` 로 동적 로드)를 교체한다. `_ready()` 에서 한 번, `EventBus.floor_changed` 로
  그때그때 호출된다. 없는 파일이면 B1 로 대체(`_load_skin_texture` 의 방어적 fallback).

### 12-4. 층 이동 UI·엘리베이터 컷신

- **진행률 바**: `TopBar` 층 이름 라벨 바로 아래(y=24, `FLOOR_BAR_HEIGHT`=1px) — 빚 상환 바(11-5)와 완전히 같은
  수동 배치 패턴(Container 밖에 두고 매 프레임 위치·크기 갱신). 채움 비율은 `FloorService.progress()`. 90%
  이상이면(`FLOOR_BAR_GLOW_THRESHOLD`) `Palette.SEM_CHIP` ↔ `GOLD_SHINE` 을 4Hz 로 오갠다. 최고층(PH)이면 숨김.
- **엘리베이터 버튼**(`ElevatorButton`, 새 스프라이트 없이 `_draw()`): 휠 오른쪽 위 틈(`ELEVATOR_BUTTON_POS` =
  (341, 41), 기록 패널·오른쪽 패널 사이의 열린 자리 — ART_BIBLE 2-2 참고), 28×28, 금 화살표 + 맥동하는 원(2.6초
  주기). `FloorService.can_move()` 가 true 로 "막 바뀌는 순간"만(이전엔 false 였다가) 루시가 `elevator_ready` 대사
  한 줄을 한다(`DialogueBox` 재사용, 6단계 "살면서 처음 클로버" 와 같은 컴포넌트).
- **확인 팝업**(`FloorConfirmPopup`, 220×150 `PanelPlain`, 화면 중앙): 다음 층 이름 + 강조색 스와치(48×48, 12-1) +
  비용(`format`) + 배율(`format_mult`) + 클로버 +10. [취소]/[이동]. **주의**: 숫자·문자가 섞인 줄은 `Num7*`(3×5
  숫자 전용 비트맵 폰트)로 쓰면 한글이 렌더링되지 않는다(두부 모양 빈 칸) — `LabelGold`/`LabelSmall`/`LabelClover`
  (일반 Galmuri 폰트 변형)를 써야 한다. 캡처로 실제로 두부가 뜨는 것을 보고서야 발견해 고쳤다.
- **전환 컷신**(`ElevatorCutscene`, 3.4초, 스킵 가능): 문 닫힘(0.6초, `INK` 두 짝이 화면 가장자리에서 만나고
  `GOLD_HL` 1px 이음매가 좁아지다 사라짐) → 층 표시등(0.8초, 딸깍 3회 — `chip_click` 재생, 마지막에 새 층 id 로
  확정) → '띵'(`clover_get` 재사용) + 문 열림(0.6초, 반대로 슬라이드) → 타이틀 카드(0.6초, "1F 다운타운 카지노"가
  **왼쪽부터 자기 폭만큼** 드러남 — 처음엔 화면 전체 폭(640px)을 기준으로 클립을 키웠더니 가운데 정렬된 글자가
  중간부터 뜬금없이 나타나는 문제가 있어, 대사 텍스트의 실제 렌더 폭(`get_minimum_size().x`)을 재서 그 폭만큼만
  클립을 화면 중앙에 두고 키우도록 고쳤다) → 클로버 +10 비행(`FlyingChips`, 휠 중심 → `TopBar.clover_target()`,
  3개) → 0.7초 유지 → 종료.
  - **수치와 연출의 분리**(5단계 남작 컷신과 같은 원칙): `FloorService.move_to_next()`(칩 소모·`floor_index`·클로버)는
    "문이 다 닫힌 순간"(`doors_closed` 신호)에 실행된다 — 그래야 배경·휠 스킨이 바뀌는 순간이 문 뒤에 가려진다.
    스킵(`skip()`)해도 아직 안 낸 `doors_closed`/`clover_moment` 신호를 순서대로 한 번에 내고 끝나므로, 아무리
    빨리 스킵해도 층 이동 자체는 항상 적용된다.
- 스핀 버튼은 컷신 재생 중 눌러도(마우스 필터가 `IGNORE`라 클릭 자체는 통과한다) `Main.request_spin()` 가드가
  막는다(잭팟·남작 컷신과 같은 가드 목록에 추가). 오토 스핀도 같은 조건으로 멈춘다.

### 12-5. AudioManager 층별 슬롯

- `FloorDef.music_id`/`ambience_id`(문자열, 데이터에 이미 있음: `bgm_b1`~`bgm_ph`, `ambience_b1`~`ambience_ph`).
  `Main._play_floor_music()` 가 `floor_changed` 마다 `AudioManager.play_music(music_id)` 를 부른다.
  `play_music()` 자체는 8단계 전까지 `pass`(주석: "8단계에서 음악 크로스페이드 구현")라 지금은 아무 소리도 안
  나지만, 8단계가 크로스페이드를 구현하면 이 호출만으로 층별 음악이 바뀐다. 앰비언스(외륜 소리 등)는 슬롯만 두고
  아직 호출부가 없다(8단계에서 재생 방식이 정해지면 연결).

## 13. 마담 벨벳·엔딩·업적 UI (7단계 3/N)

### 13-1. 마담 벨벳

- `tools/art/gen_velvet.py` 가 `gen_lucy.py` 와 같은 골격(타원 얼굴·`_line()` 헬퍼·배지 없는 캐릭터 직접 드로잉)으로
  그린다. 은발 올림머리(뒤 번+옆 잔머리, `HAIR=[ink,stone,mist]`), 짙은 빨강 벨벳 드레스(`DRESS=[red_d,red,red_l]`,
  이름 그대로), 진주 목걸이(ivory 점), 금 귀걸이.
- **초상화**(`velvet_portrait.png`, 64×64×7): 기본/웃음/교활함/놀람/만족 5종 + 입벙긋(열림/닫힘) 2종. 눈매를 살짝
  치켜뜨고 아이라인 꼬리를 그려 루시보다 성숙하고 도도한 인상을 준다. `DialogueBox.VELVET_PORTRAIT_FRAME_INDEX`.
- **월드 스프라이트**(`velvet_world.png`, 48×72×4행): idle(4)/wine(3, 와인잔을 들었다 내림)/gesture(4, 손짓)/
  clap(4, 박수). 롱드레스라 다리가 안 보이고 치맛단만 퍼진다. **팔은 드레스와 다른 색(검은 오페라 장갑,
  `HAIR[0]`)으로 그린다** — 처음 드레스와 같은 색으로 그렸더니 팔이 몸통에 묻혀 안 보이는 문제가 있었다(스크린샷
  검수로 발견, GDD 17장에 기록).
- `MadameVelvet`(`scenes/npc/madame_velvet.gd`)은 `LucyDealer`/`BaronRatchet` 과 동형인 순수 연출 클래스
  (`play(anim, looping)`, 제스처는 마지막 프레임에서 자동으로 idle 로 돌아간다 — 루시와 같은 방식, 남작처럼
  `gesture_finished` 신호를 기다리지 않는다). PH 배경 안 `VELVET_POSITION`(596, 300)에 선다.

### 13-2. 엔딩 시퀀스 연출

- **최후의 스핀**: 화면 전체가 어두워진 상태(`Palette.VOID` 알파 0.6, 0.6초 페이드)에서 기존 `RouletteWheel` 을
  그대로 8초간 돌린다(새 휠 그래픽 없음). 멈추면 화면 흔들림(3px, 0.4초, `ScreenShake`)·흰 플래시(`ScreenFlash`)·
  금 코인 파티클 5줄기(`ParticleBurst.Kind.COINS` 재사용)가 한 번에 터진다.
  - **골드 웨이브**: 새 텍스처 없이 `Node2D._draw()` 로 휠 중심(262, 192) 반지름 83(=`R_NUMBERS`, 12-3)에 금색
    원호(`draw_arc`, 두께 4 + 반투명 1px 하이라이트 겹줄)를 1.2초 동안 0°→360° 로 키운다.
  - **네온 간판**: 기존 "LUCKY" 간판 컴포넌트(`NeonText`)를 문자열만 바꿔 그대로 재사용. `assets/sprites/fx/
    neon_letters.json` 아틀라스에 없던 H·S·D 3글자를 `tools/art/gen_fx.py`(`NEON_CHARS`)에 추가해 "HOUSE EDGE" 를
    표현한다(트루타입 폰트에서 뽑는 방식이라 새 손그림 불필요). 다른 단계와 섞이지 않게 `NEON_SIGN` 단계 전까지는
    꺼진 유리관조차 아예 숨겨 둔다(반전 효과 — 처음엔 계속 보이게 했다가 스크린샷 검수로 "김 빠진다"고 판단해 고침).
- **양도 증서**: 5단계 `ContractPopup`(양피지·서명·도장)을 그대로 재사용(`open_custom()`, GDD 17장). 매도인/매수인/
  이전 문구 3줄 + [서명한다]. 서명·도장 뒤에는 대출 계약서와 같은 간격(0.7초)을 두고 스스로 닫힌 뒤 에필로그로
  넘어간다.
- **에필로그**: 벨벳(환영 인사) → 루시(축하) → 남작(빚 탕감 언급) 순서로 같은 대사창을 이어 쓴다.
- 화면 배치·스킵 유무·"스크롤링 크레딧" 생략 등 세부 결정은 GDD 17장 참고.

### 13-3. 업적 아이콘·토스트·목록 화면

- **아이콘**(`tools/art/gen_achievements.py`, 24px, 30종+숨김 1종): `gen_skills.py` 의 "좌상단 광원 원형 배지 +
  중앙 글리프" 조합과 글리프 함수 라이브러리(주사위·번개·달·방패·저울 등)를 그대로 재사용한다(새 글리프 없음).
  카테고리별 5색 램프(기본=금, 빚=빨강, 진행=청록, 수집=초록, 특수=보라, 누적=호박, 숨김=먹색)로 30개를 7갈래로
  묶어 구분한다. 미달성(일반)은 `gen_skills.silhouette()`(먹색 실루엣, 스킬 잠김 아이콘과 같은 함수) 버전을,
  숨김+미달성은 전용 "?" 아이콘(`icon_hidden.png`) 하나를 공용으로 쓴다.
- **토스트**(`AchievementToast`, 화면 우하단): `GoldenBadge`(2단계, 황금 포켓 적중 배지)와 같은 `BadgeGolden`
  패널 스타일을 재사용해 시각적 일관성을 준다. 아이콘(24px, 원본 크기) + "업적 달성" 라벨 + 이름을 가로로 배치,
  0.3초 슬라이드인(오른쪽에서, 이징 `1-(1-u)³`) → 4초 유지 → 0.2초 슬라이드아웃. 여러 개가 한 프레임에 풀리면
  큐에 쌓아 하나씩 순서대로 보여준다.
- **목록 화면**(`AchievementScreen`, 일시정지 메뉴 전용, `StatsScreen` 과 같은 640×336 자리): 카테고리 헤더 +
  `GridContainer`(10열) 아이콘 그리드. **`AchievementSlot`(그리드 칸)은 반드시 `custom_minimum_size` 를 둬야
  한다** — 처음엔 `size` 만 지정했더니 `GridContainer` 가 모든 칸을 0×0 으로 접어 아이콘이 전부 같은 자리에
  겹쳐 보이는 버그가 있었다(스크린샷 검수로 발견, Container 자식은 `custom_minimum_size` 로만 자리를 예약한다는
  일반 규칙).

## 14. 부팅·타이틀·인트로 컷신 (8단계 1/N)

### 14-1. 스플래시

- `assets/sprites/title/dev_logo.png`(220×40, `tools/art/gen_title.py`): `STUDIO_NAME`(가제 "HOUSE EDGE")을
  Galmuri11 Bold 에서 뽑아 금색 램프(gold_hl→gold_l→gold)로 칠하고 `gold_d` 외곽선을 두른 워드마크 + 왼쪽에
  작은 칩(스페이드 대신 원형 칩) 글리프. 화면 중앙, 0.4초 페이드인 → 1.1초 유지 → 0.35초 페이드아웃 → 타이틀로
  전환. 클릭·아무 키나 누르면 즉시 건너뛴다.

### 14-2. 타이틀 화면 레이아웃 (640×360)

| 요소 | 좌표·크기 |
|---|---|
| 배경 | `assets/sprites/title/bg_wall.png`(640×360, 정적) — 비 내리는 밤거리, 좌우 건물(창문 점등), 중앙 카지노
  정면(간판 지지대 x 226~414 y 96~130, 캐노피, 양쪽 여닫이 문, 문 밑 golden 빛줄기), 가로등 1개, 젖은 보도(y 302~360,
  창문·간판 색이 아래로 옅어지는 세로 반사 얼룩) |
| 빗줄기 | `TitleScreen._RainLayer`(내부 클래스, 새 텍스처 없이 `_draw()`): 90개, 낙하 속도 220~340px/s, 살짝 왼쪽으로
  흐름(바람), `mist` 알파 0.35, 화면 밖으로 나가면 위로 재배치 |
| 번개 | 화면 전체 `ivory` 알파 플래시(6~15초 무작위 주기, 이중 깜빡임). `VisualSettings.flash_alpha()` 따름(번쩍임
  줄이기 설정 적용) |
| 네온 로고 "HOUSE EDGE" | 간판 지지대 안, `NeonText`(7단계 엔딩과 같은 컴포넌트·아틀라스 재사용 — H·O·U·S·E·D·G
  글자가 이미 있다) 폭의 절반만큼 왼쪽으로 옮겨 가운데 정렬. `flicker_on()` 으로 등장, 이후 `idle_flicker=true` |
| 미니 룰렛 아이콘 | 로고 아래(320,150), `assets/sprites/title/wheel_icon.png`(16×16×8프레임, `tools/art/gen_title.py`).
  8프레임이 45°/8 씩 돌아간 상태라 한 바퀴(45°, 8쐐기 대칭이라 이게 곧 360°와 같은 무늬) 순환이 이음매 없이
  반복된다. 0.16초마다 프레임 교체(연속 회전 금지 규칙 — ART_BIBLE 4장) |
| 메뉴 패널 | `PanelFelt`, (456, 92) 150×192. 버튼 6개(세로, 120×20, `ButtonDark`): 이어하기(저장 없으면 비활성 +
  요약 문구 없음, 있으면 층 이름·칩·플레이 시간 두 줄 요약)/새 게임/설정/업적/크레딧/종료 |
| 칩 커서 | `assets/ui/coin.png`, 포커스·호버된 버튼의 왼쪽(간격 4px)으로 0.22초 큐빅 이즈 이동. 새 스프라이트 없음 |
| 새 게임 확인 팝업 | `PanelPlain`, 화면 중앙 220×100. 기존 저장이 있을 때만 뜬다 |

### 14-3. 인트로 컷신 (`IntroCutscene`, 새 게임 전용)

- 골목(4초, 뒷모습 실루엣이 왼쪽에서 걸어 들어옴) → 구슬(3.2초, 나무 구슬 24px 아이콘이 화면 중앙에 떠오름) →
  문(0.6초, 화면이 살짝 밝아짐) → 대사(루시, `data/dialogue/lucy.json` 의 `intro_greeting`, 4줄) → 종료.
  전부 `_process(delta)` 누적으로 진행하고(GDD 18장), 우상단 "건너뛰기" 버튼으로 언제든 즉시 끝낼 수 있다.
- **뒷모습 실루엣**(`_WalkingFigure`, 절차적, 16×40): 머리(원)·몸통(사각형) 모두 `ink` 바탕 + `mist` 1px 테두리.
  처음에는 `void` 하나로 채웠더니 화면 디밍(알파 0.75) 위에서 거의 안 보였다 — 밝은 테두리로 바꿔 해결(캡처로
  발견, GDD 18장).
- 문 단계부터는 `LucyDealer`(6단계, idle 애니메이션)가 문 틈(300, 306)에 서고, 기존 `DialogueBox` 를 그대로 쓴다.

## 15. 튜토리얼 스포트라이트 (8단계 2/N)

- `TutorialGuide`(640×360 전체를 덮는 `Control`): 대상 사각형(`bet_panel.board`/`spin_controls.spin_button`/
  `top_bar` 의 업그레이드·스킬트리 탭/`upgrade_panel` 중 하나) 둘레만 남기고 위/아래/좌/우 4조각 `ColorRect` 로
  전부 덮는다. 색은 `Palette.VOID`, **알파는 1.0(완전 불투명)** — 반투명(0.85 까지도 포함)으로 하면 이 프로젝트
  렌더러 조합에서 world(휠·배경) 위에는 전혀 합성되지 않는 버그가 있어(GDD 19장, 픽셀 비교로 확인) 완전 불투명으로
  우회했다. 이후 화면 전체를 덮는 반투명 오버레이를 새로 만들 때는 이 문제를 먼저 의심하고 확인할 것.
- 대상 둘레에 1px `Palette.GOLD_HL` 테두리 4조각을 두른다.
- 손가락 포인터(`_Pointer`, 절차적, 12×12, `wood_hl`+`wood_d` 테두리): 대상 위에 공간이 있으면 위에서 아래로,
  없으면 아래에서 위로 가리키며 0.7초 주기로 정수 2px 상하 bob(소수 배율 금지 규칙 그대로 따름).
- CLOVER 단계처럼 강조할 대상이 없는 "설명만" 하는 단계는 디밍·테두리·포인터 전부 끄고 대사만 보여준다.

## 16. 커스텀 마우스 커서 3종 (8단계 4/N)

- `assets/sprites/ui/cursor_normal.png`(24×24, `tools/art/gen_cursor.py`): 기본 화살표 대체. `ivory` 채움 +
  `ink` 1px 외곽선의 대각선 삼각형, 원점(0,0)이 뾰족한 끝(핫스팟).
- `cursor_pointer.png`(24×24): 버튼처럼 상호작용 가능한 곳 위(`Control.CURSOR_POINTING_HAND` 대체) — 금색
  칩(`gold`/`gold_hl` 테두리) + 우상단 `gold_shine` 반짝임 십자. 핫스팟은 칩 중심 (12,12).
- `cursor_forbidden.png`(24×24): 비활성 버튼 위(`Control.CURSOR_FORBIDDEN` 대체) — 회색조 칩(`ink`/`stone`) 위에
  굵은 `red_hl` 대각선 금지 띠. 핫스팟 (12,12).
- **커서 크기는 뷰포트 정수 배율을 따라가지 않는다** — `Input.set_custom_mouse_cursor()` 는 OS 커서라 640×360
  기준 픽셀아트처럼 자동으로 확대되지 않는다(엔진이 별도로 스케일하지 않음). 그래서 16px 급 아이콘보다 일부러
  크게(24px) 그려 1배 창에서도 또렷하다 — 완벽한 정수 배율 추종(창 크기가 바뀔 때마다 다시 그려 갈아 끼우기)은
  이번 단계 범위에서 뺐다(비용 대비 효과가 작다고 판단, `CursorTheme` 에 근거 기록).
- `CursorTheme.apply(tree)`(`scenes/fx/cursor_theme.gd`, `SplashScreen._ready()` 에서 1회 호출)가 세 커서를
  각각 `CURSOR_ARROW`/`CURSOR_POINTING_HAND`/`CURSOR_FORBIDDEN` 에 등록하고, 이후 새로 추가되는 모든
  `BaseButton` 에 `disabled` 여부에 따라 손가락/금지 커서를 자동으로 붙인다(이미 다른 모양을 정한 버튼은
  그대로 둔다).
