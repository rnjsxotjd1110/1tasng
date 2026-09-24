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
