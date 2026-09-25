"""B1 뒷골목 도박장 배경 레이어.

  python3 tools/art/gen_bg.py

층마다 같은 파일 구성(assets/sprites/bg/<floor>/)을 따르면 7단계에서 배경 씬만 바꿔 끼울 수 있다.
  wall.png        640×360  벽돌 벽(dusk/shadow), 벽돌마다 색 차이, 얼룩, 파이프
  table.png       640×360  나무 레일 + 초록 펠트 테이블(위쪽 투명)
  lamp.png        33×16    천장 전구 램프 갓
  lamp_cone.png   220×250  램프 빛 원뿔(가산, 낮은 알파)
  light_pool.png  320×250  휠 주변 빛 웅덩이(가산)
  smoke.png       24×16    연기 입자
  poster.png      40×52    빛바랜 현상수배 포스터(래칫 남작 복선)
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import BAYER4, Canvas, dither_pick, disc_mask, seeded  # noqa: E402

OUT = "assets/sprites/bg/b1"
W, H = 640, 360
RAIL_Y = 98
LAMP_X = 262


def wall() -> None:
    c = Canvas(W, H, "night")
    rnd = seeded(11)
    brick_w, brick_h = 16, 8
    for row in range(H // brick_h + 1):
        y0 = row * brick_h
        offset = (brick_w // 2) if row % 2 else 0
        for col in range(-1, W // brick_w + 2):
            x0 = col * brick_w + offset
            # 램프 쪽(가운데 위)이 조금 밝다
            cx = x0 + brick_w / 2 - LAMP_X
            cy = y0 + brick_h / 2 - 40
            dist = math.hypot(cx / 260.0, cy / 150.0)
            light = max(0.0, 1.0 - dist)
            roll = rnd.random()
            base = ["night", "night", "night", "dusk", "dusk", "dusk", "dusk", "shadow"][min(7, int(roll * 8))]
            if light < 0.35 and base == "shadow":
                base = "dusk"
            if light < 0.12:
                base = "night" if roll < 0.6 else "dusk"
            for y in range(y0, y0 + brick_h - 1):
                for x in range(x0, x0 + brick_w - 1):
                    if not (0 <= x < W and 0 <= y < H):
                        continue
                    col_name = base
                    # 벽돌 윗면 하이라이트, 아랫면 그늘
                    if y == y0 and base != "night" and light > 0.2:
                        col_name = "shadow" if base == "dusk" else base
                    if y == y0 + brick_h - 2 or x == x0 + brick_w - 2:
                        col_name = "night" if base != "night" else "void"
                    # 벽돌 표면 얼룩(성긴 점)
                    n = rnd.random()
                    if n < 0.05:
                        col_name = "night" if col_name != "night" else "void"
                    elif n < 0.07 and light > 0.3:
                        col_name = "shadow"
                    c.px(x, y, col_name)
            # 줄눈(void)은 night 바탕 그대로 두되 가장자리를 더 어둡게
    # 줄눈
    for row in range(H // brick_h + 1):
        y = row * brick_h + brick_h - 1
        c.hline(0, W - 1, y, "void")
    # 물 얼룩: 위에서 흘러내린 어두운 줄
    for _ in range(26):
        x = rnd.randrange(0, W)
        length = rnd.randrange(20, 90)
        width = rnd.choice([1, 1, 2, 3])
        y0 = rnd.randrange(24, 60)
        for y in range(y0, min(H, y0 + length)):
            fade = 1 - (y - y0) / length
            for dx in range(width):
                if rnd.random() < 0.55 * fade + 0.2:
                    xx = x + dx + (1 if rnd.random() < 0.08 else 0)
                    if 0 <= xx < W:
                        r, g, b, _a = c.get(xx, y)
                        c.px(xx, y, "void" if (r, g, b) == (22, 20, 42) else "night")
    # 곰팡이(felt_d 점무리)
    for _ in range(9):
        cx = rnd.randrange(0, W)
        cy = rnd.randrange(30, 100)
        for _k in range(60):
            dx = int(rnd.gauss(0, 5))
            dy = int(rnd.gauss(0, 3))
            if rnd.random() < 0.5:
                c.px(cx + dx, cy + dy, "felt_d")
    # 천장 쪽 파이프(y 25~30)
    for x in range(W):
        c.px(x, 25, "void")
        c.px(x, 26, "stone" if (x // 3) % 7 else "mist")
        c.px(x, 27, "ink")
        c.px(x, 28, "ink")
        c.px(x, 29, "shadow")
        c.px(x, 30, "void")
    for bx in range(20, W, 64):
        c.rect(bx, 24, 4, 8, "void")
        c.rect(bx + 1, 25, 2, 6, "stone")
        c.px(bx + 1, 25, "mist")
    # 위쪽을 어둡게(천장 그늘) — 디더링
    for y in range(31, 48):
        v = (y - 31) / 17.0
        for x in range(W):
            if v < BAYER4[y % 4, x % 4]:
                r, g, b, _a = c.get(x, y)
                if (r, g, b) != (11, 10, 20):
                    c.px(x, y, "night" if (r, g, b) != (22, 20, 42) else "void")
    c.save(f"{OUT}/wall.png")


def table() -> None:
    c = Canvas(W, H)
    rnd = seeded(5)
    # 펠트: 램프 아래(휠 주변)가 felt, 가장자리로 갈수록 felt_d → night 로 디더링
    for y in range(RAIL_Y + 10, H):
        for x in range(W):
            dx = (x - LAMP_X) / 230.0
            dy = (y - 200) / 190.0
            v = 1.0 - math.hypot(dx, dy)
            name = dither_pick(v * 1.25, x, y, ["void", "night", "felt_d", "felt_d", "felt"])
            if rnd.random() < 0.04 and name in ("felt", "felt_d"):
                name = "felt_d" if name == "felt" else "night"
            c.px(x, y, name)
    # 레일: 나무 몸통(위 윗면 + 앞면) y RAIL_Y..RAIL_Y+9
    for x in range(W):
        grain = math.sin(x * 0.31) + math.sin(x * 0.083 + 1.3)
        c.px(x, RAIL_Y, "void")
        c.px(x, RAIL_Y + 1, "wood_l")
        c.px(x, RAIL_Y + 2, "wood_hl" if grain > 0.9 else "wood_l")
        c.px(x, RAIL_Y + 3, "wood_l" if grain > -0.6 else "wood")
        c.px(x, RAIL_Y + 4, "wood")
        c.px(x, RAIL_Y + 5, "wood" if grain < 1.2 else "wood_l")
        c.px(x, RAIL_Y + 6, "gold_d")
        c.px(x, RAIL_Y + 7, "gold" if (x % 24) < 20 else "gold_l")
        c.px(x, RAIL_Y + 8, "wood_d")
        c.px(x, RAIL_Y + 9, "void")
    # 레일 가장자리 어둡게(램프에서 먼 곳)
    for y in range(RAIL_Y + 1, RAIL_Y + 9):
        for x in range(W):
            d = abs(x - LAMP_X) / 320.0
            if d > 0.45 and (BAYER4[y % 4, x % 4] < (d - 0.45) * 2.2):
                r, g, b, _a = c.get(x, y)
                c.px(x, y, "wood_d" if (r, g, b) != (11, 10, 20) else "void")
    c.save(f"{OUT}/table.png")


def lamp() -> None:
    c = Canvas(33, 16)
    rows = [
        "..............ooooo..............",
        "............oommmmmoo............",
        "..........oommsssssiioo..........",
        "........oomsssssssssiiioo........",
        "......oommsssssssssssiiiioo......",
        ".....omsssssssssssssssiiiiio.....",
        "....omssssssssssssssssssiiiio....",
        "...omsssssssssssssssssssiiiiio...",
        "..omsssssssssssssssssssssiiiiio..",
        ".oggggggggggggggggggggggggggggdo.",
        "ogllllllllllllllllllllllllllllldo",
        ".ooooooyyyyyyyyyyyyyyyyyyyooooo..",
        ".......oyyywwwwwwwwwwwyyyo.......",
        "........ooyyywwwwwyyyoo..........",
        "..........ooooyyyoooo............",
        ".................................",
    ]
    c.pattern(0, 0, rows, {"o": "void", "m": "stone", "s": "ink", "i": "shadow", "g": "gold_l", "l": "gold", "d": "gold_d",
                           "y": "gold_hl", "w": "gold_shine"})
    c.save(f"{OUT}/lamp.png")


def lamp_cone() -> None:
    w, h = 220, 250
    c = Canvas(w, h)
    top_half = 10.0
    for y in range(h):
        v = y / h
        half = top_half + (w / 2 - top_half) * v
        for x in range(w):
            d = abs(x + 0.5 - w / 2) / half
            if d > 1.0:
                continue
            edge = 1.0 - d
            a = (0.35 + 0.65 * (1 - v)) * min(1.0, edge * 3.0)
            # 4단계로 양자화(픽셀아트 느낌)
            level = int(a * 4.0 + BAYER4[y % 4, x % 4] * 0.9)
            if level <= 0:
                continue
            c.px(x, y, "gold_shine", [0, 7, 12, 17, 22][min(level, 4)])
    c.save(f"{OUT}/lamp_cone.png")


def light_pool() -> None:
    w, h = 320, 250
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            d = math.hypot((x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2))
            if d > 1.0:
                continue
            v = 1.0 - d
            level = int(v * 3.0 + BAYER4[y % 4, x % 4] * 0.9)
            if level <= 0:
                continue
            c.px(x, y, "gold_hl", [0, 8, 14, 20][min(level, 3)])
    c.save(f"{OUT}/light_pool.png")


def smoke() -> None:
    w, h = 24, 16
    c = Canvas(w, h)
    rnd = seeded(3)
    for y in range(h):
        for x in range(w):
            d = math.hypot((x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2))
            d += rnd.uniform(-0.15, 0.15)
            if d < 0.55:
                c.px(x, y, "mist", 70)
            elif d < 0.85 and (x + y) % 2 == 0:
                c.px(x, y, "mist", 45)
            elif d < 1.0 and (x % 2 == 0 and y % 2 == 0):
                c.px(x, y, "mist", 30)
    c.save(f"{OUT}/smoke.png")


def poster() -> None:
    """빛바랜 현상수배 포스터 40×52: 쥐 실루엣 + 'WANTED' 줄무늬. 어둡게(배경이므로)."""
    w, h = 40, 52
    c = Canvas(w, h, "wood_d")
    rnd = seeded(9)
    c.outline_rect(0, 0, w, h, "void")
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            r = rnd.random()
            if r < 0.12:
                c.px(x, y, "wood")
            elif r < 0.16:
                c.px(x, y, "night")
    # 제목 줄(글자 대신 굵은 줄)
    for x in range(5, w - 5):
        if x % 5 != 4:
            c.px(x, 4, "void")
            c.px(x, 5, "void")
            c.px(x, 6, "void")
    # 쥐 머리 실루엣 + 중절모
    c.pattern(9, 10, [
        "......dddddddd......",
        "......dddddddd......",
        "......dddddddd......",
        "...dddddddddddddd...",
        "....dddddddddddd....",
        ".dd..dddddddddd..dd.",
        "dddd.dddddddddd.dddd",
        "ddddddddddddddddddd.",
        ".ddddddddddgdddddd..",
        "...ddddddddgddddd...",
        "....dddddddddddd....",
        ".....dddddddddd.....",
        "......dddddddd......",
        ".......dddddd.......",
        "........dddd........",
        ".........dd.........",
    ], {"d": "void", "g": "gold_d"})
    # 아래 줄글
    for yy in (32, 36, 40, 44):
        for x in range(5, w - 5 - (yy % 7)):
            if rnd.random() < 0.7:
                c.px(x, yy, "night")
    # 찢어진 귀퉁이, 압정
    c.clear_px(w - 1, h - 1)
    c.clear_px(w - 2, h - 1)
    c.clear_px(w - 1, h - 2)
    c.px(w // 2, 1, "stone")
    c.px(w // 2, 2, "mist")
    c.save(f"{OUT}/poster.png")


# ── 공용(층별 배경, 7단계, ART_BIBLE 12장) ──────────────────
# 게임 화면(휠 반지름 118·기록 패널 x4~103·오른쪽 패널 x420~635)이 배경 대부분을 가리므로, B1 처럼
# 전체 640×360 을 절차적으로 채우되 실제로 보이는 틈(위쪽 띠·휠 좌우 틈)에 특징 요소를 둔다.
# table.png(펠트+레일, 게임 판)은 층마다 다시 그리지 않고 B1 것을 그대로 복사한다 — 방(wall)·조명만
# 층을 구분하고, 게임 판 자체는 항상 같아야 가독성이 유지된다(ART_BIBLE 4장 "휠과 구슬이 가장 선명").
DIR_1F = "assets/sprites/bg/1f"
DIR_2F = "assets/sprites/bg/2f"
DIR_3F = "assets/sprites/bg/3f"
DIR_PH = "assets/sprites/bg/ph"


def _light_cone(out_path: str, color: str) -> None:
    w, h = 220, 250
    c = Canvas(w, h)
    top_half = 10.0
    for y in range(h):
        v = y / h
        half = top_half + (w / 2 - top_half) * v
        for x in range(w):
            d = abs(x + 0.5 - w / 2) / half
            if d > 1.0:
                continue
            edge = 1.0 - d
            a = (0.35 + 0.65 * (1 - v)) * min(1.0, edge * 3.0)
            level = int(a * 4.0 + BAYER4[y % 4, x % 4] * 0.9)
            if level <= 0:
                continue
            c.px(x, y, color, [0, 7, 12, 17, 22][min(level, 4)])
    c.save(out_path)


def _light_pool(out_path: str, color: str) -> None:
    w, h = 320, 250
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            d = math.hypot((x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2))
            if d > 1.0:
                continue
            v = 1.0 - d
            level = int(v * 3.0 + BAYER4[y % 4, x % 4] * 0.9)
            if level <= 0:
                continue
            c.px(x, y, color, [0, 8, 14, 20][min(level, 3)])
    c.save(out_path)


def _copy_table(out_dir: str) -> None:
    import shutil
    shutil.copyfile(f"{OUT}/table.png", f"{out_dir}/table.png")


def _pillar(c: Canvas, cx: int, y0: int, y1: int, ramp: list[str]) -> None:
    """세로 금속/석재 기둥. ramp = [어둡다(테두리), 그림자, 밝다, 하이라이트]."""
    w = 18
    for y in range(y0, y1):
        for dx in range(-w // 2, w // 2):
            x = cx + dx
            edge = abs(dx) / (w / 2)
            name = ramp[3] if edge < 0.15 else (ramp[2] if edge < 0.5 else (ramp[1] if edge < 0.85 else ramp[0]))
            c.px(x, y, name)
    c.vline(cx - w // 2, y0, y1 - 1, ramp[0])
    c.vline(cx + w // 2 - 1, y0, y1 - 1, ramp[0])
    c.rect(cx - w // 2 - 3, y0 - 4, w + 6, 5, ramp[0])
    c.rect(cx - w // 2 - 2, y0 - 3, w + 4, 3, ramp[2])


# ── 1F 다운타운 카지노(red/gold) ─────────────────────────

SLOT_POSITIONS_1F = [(18, 40), (330, 40), (598, 40)]


def wall_1f() -> None:
    c = Canvas(W, H, "red_d")
    for y in range(H):
        for x in range(W):
            c.px(x, y, "red_d" if (x // 20 + y // 20) % 2 == 0 else "red")
    for x in range(0, W, 20):
        c.vline(x, 0, H - 1, "gold_d")
    for cx in (122, 402):
        _pillar(c, cx, 20, H - 20, ["gold_d", "gold", "gold_l", "gold_hl"])
    for (x0, y0) in SLOT_POSITIONS_1F:
        _slot_machine(c, x0, y0)
    c.save(f"{DIR_1F}/wall.png")


def _slot_machine(c: Canvas, x0: int, y0: int) -> None:
    w, h = 26, 40
    c.rect(x0, y0, w, h, "ink")
    c.outline_rect(x0, y0, w, h, "void")
    c.rect(x0 + 3, y0 + 4, w - 6, 13, "night")
    c.outline_rect(x0 + 3, y0 + 4, w - 6, 13, "void")
    c.rect(x0 + 2, y0 + 19, w - 4, 3, "gold_d")
    # 불빛 자리(어두운 상태로 구워 둠 — 켜짐은 background_1f.gd 가 덧그린다)
    for i in range(3):
        c.rect(x0 + 4 + i * 6, y0 + 30, 4, 3, "shadow")
    c.rect(x0 + 2, y0 + h - 6, w - 4, 4, "void")


def chandelier_1f() -> None:
    """샹들리에(64×28): 금 뼈대 + 크리스털(ivory) 방울 8개."""
    c = Canvas(64, 28)
    c.rect(30, 0, 4, 6, "gold_d")
    for k in range(6):
        x = 6 + k * 10
        c.px(x, 6, "gold_l")
        c.vline(x, 7, 11, "gold")
        c.px(x - 1, 12, "ivory")
        c.px(x, 12, "gold_shine")
        c.px(x + 1, 12, "ivory")
        c.px(x, 13, "gold_hl", 200)
    c.hline(4, 59, 5, "gold_l")
    c.save(f"{DIR_1F}/chandelier.png")


def guest_silhouette_1f() -> None:
    """가끔 지나가는 손님 실루엣(10×22)."""
    c = Canvas(10, 22)
    c.pattern(0, 0, [
        "...dd...",
        "..dddd..",
        "..dddd..",
        "...dd...",
        "..dddd..",
        ".dddddd.",
        ".dddddd.",
        ".dddddd.",
        "..d..d..",
        "..d..d..",
        "..d..d..",
        ".dd..dd.",
    ], {"d": "void"})
    c.save(f"{DIR_1F}/guest_silhouette.png")


def gen_1f() -> None:
    wall_1f()
    _copy_table(DIR_1F)
    chandelier_1f()
    _light_cone(f"{DIR_1F}/lamp_cone.png", "gold_shine")
    _light_pool(f"{DIR_1F}/light_pool.png", "gold_hl")
    guest_silhouette_1f()


# ── 2F 리버보트 카지노(wood/amber/water) ─────────────────

PORTHOLE_CENTERS_2F = [(122, 46), (402, 46)]
PORTHOLE_R = 22


def wall_2f() -> None:
    c = Canvas(W, H, "wood_d")
    for y in range(H):
        row = y // 6
        for x in range(W):
            base = "wood" if (row + x // 40) % 2 == 0 else "wood_d"
            c.px(x, y, base)
        if y % 6 == 0:
            c.hline(0, W - 1, y, "wood_d")
    for x in range(0, W, 40):
        c.vline(x, 0, H - 1, "wood_d")
        c.vline(x + 1, 0, H - 1, "wood_l")
    for (cx, cy) in PORTHOLE_CENTERS_2F:
        _porthole_frame(c, cx, cy, PORTHOLE_R)
    c.save(f"{DIR_2F}/wall.png")


def _porthole_frame(c: Canvas, cx: int, cy: int, r: int) -> None:
    mask_out = disc_mask(r, cx, cy, W, H)
    mask_in = disc_mask(r - 3, cx, cy, W, H)
    for y in range(max(0, cy - r - 1), min(H, cy + r + 2)):
        for x in range(max(0, cx - r - 1), min(W, cx + r + 2)):
            if mask_out[y, x] and not mask_in[y, x]:
                c.px(x, y, "gold_l")
            elif mask_in[y, x]:
                c.clear_px(x, y)
    for y in range(max(0, cy - r - 1), min(H, cy + r + 2)):
        for x in range(max(0, cx - r - 1), min(W, cx + r + 2)):
            if mask_out[y, x] and not mask_in[y, x] and (x - cx) + (y - cy) < -r * 0.6:
                c.px(x, y, "gold_hl")


def river_2f() -> None:
    """창 뒤로 스크롤할 강 스트립. 폭을 넉넉히 잡아 이어 붙여도 이음매가 안 보이게 잔물결을 주기함수로."""
    w, h = 360, 60
    c = Canvas(w, h, "water")
    rnd = seeded(41)
    for y in range(h):
        for x in range(w):
            wave = math.sin(x * 0.15 + y * 0.4) + math.sin(x * 0.05)
            if wave > 1.15:
                c.px(x, y, "sky")
            elif wave > 0.7 and rnd.random() < 0.5:
                c.px(x, y, "amber", 120)
    # 달빛 기둥
    for x in range(w // 2 - 6, w // 2 + 6):
        d = abs(x - w // 2) / 6.0
        for y in range(h):
            if rnd.random() < 0.5 - d * 0.4:
                c.px(x, y, "gold_hl", int(120 * (1 - d)))
    c.save(f"{DIR_2F}/river.png")


def lantern_2f() -> None:
    c = Canvas(12, 18)
    c.rect(4, 0, 4, 3, "gold_d")
    c.pattern(2, 3, [
        "dgggd",
        "gaaag",
        "gaaag",
        "dgggd",
    ], {"d": "gold_d", "g": "gold", "a": "amber"})
    c.rect(4, 12, 4, 3, "gold_d")
    c.px(5, 13, "gold_shine")
    c.save(f"{DIR_2F}/lantern.png")


def gen_2f() -> None:
    wall_2f()
    _copy_table(DIR_2F)
    river_2f()
    lantern_2f()
    _light_cone(f"{DIR_2F}/lamp_cone.png", "amber")
    _light_pool(f"{DIR_2F}/light_pool.png", "amber")


# ── 3F 스카이 라운지(neon_cyan/purple) ───────────────────

def wall_3f() -> None:
    c = Canvas(W, H, "void")
    rnd = seeded(53)
    horizon = 200
    for y in range(horizon):
        for x in range(W):
            c.px(x, y, "night" if y < horizon - 4 else "dusk")
    # 별
    for _ in range(40):
        x = rnd.randrange(0, W)
        y = rnd.randrange(0, horizon - 30)
        c.px(x, y, "ivory" if rnd.random() < 0.3 else "mist")
    # 스카이라인(건물 실루엣, 높이 다양)
    x = 0
    while x < W:
        bw = rnd.randrange(18, 40)
        bh = rnd.randrange(40, 150)
        by = horizon - bh
        c.rect(x, by, bw, bh, "shadow" if rnd.random() < 0.5 else "dusk")
        # 창문 불빛(일부만, 나머지는 background_3f.gd 가 무작위로 깜빡임)
        for wy in range(by + 4, horizon - 4, 6):
            for wx in range(x + 2, x + bw - 2, 5):
                if rnd.random() < 0.35:
                    c.px(wx, wy, "gold_hl", 180)
        x += bw + rnd.randrange(2, 8)
    for y in range(horizon, H):
        c.px(0, y, "void")
    c.rect(0, horizon, W, H - horizon, "void")
    c.save(f"{DIR_3F}/wall.png")


def bar_3f() -> None:
    """칵테일 바 실루엣(58×34, 화면 오른쪽 낮은 구석에 배치할 장식)."""
    c = Canvas(58, 34)
    c.rect(0, 20, 58, 14, "ink")
    c.outline_rect(0, 20, 58, 14, "void")
    c.rect(4, 0, 2, 20, "night")
    c.rect(50, 0, 2, 20, "night")
    for i in range(6):
        bx = 6 + i * 8
        c.rect(bx, 4, 3, 16, "felt_d" if i % 2 == 0 else "purple_d")
        c.px(bx, 3, "ivory")
    c.save(f"{DIR_3F}/bar.png")


def gen_3f() -> None:
    wall_3f()
    _copy_table(DIR_3F)
    bar_3f()
    _light_cone(f"{DIR_3F}/lamp_cone.png", "neon_cyan")
    _light_pool(f"{DIR_3F}/light_pool.png", "neon_purple")


# ── PH 펜트하우스(gold/ivory/purple) ─────────────────────

def wall_ph() -> None:
    c = Canvas(W, H, "ivory")
    rnd = seeded(77)
    for y in range(H):
        for x in range(W):
            if rnd.random() < 0.02:
                c.px(x, y, "stone")
    # 대리석 결: 가늘고 완만하게 휘는 줄 5가닥(자연스러운 곡선을 위해 두 주파수를 섞는다)
    for k in range(5):
        phase = k * 1.7
        y0 = rnd.randrange(-40, H)
        for x in range(W):
            y = y0 + int(30 * math.sin(x * 0.012 + phase) + 10 * math.sin(x * 0.04 + phase * 2.0))
            for dy, name in ((0, "mist"), (1, "ivory")):
                yy = y + dy
                if 0 <= yy < H:
                    c.px(x, yy, name)
    # 창밖 구름+달(위쪽 띠)
    for y in range(0, 46):
        for x in range(W):
            c.px(x, y, "dusk")
    for _ in range(10):
        cx = rnd.randrange(20, W - 20)
        cy = rnd.randrange(6, 34)
        for dx in range(-8, 9):
            for dy in range(-3, 4):
                if dx * dx * 0.5 + dy * dy * 2.5 < 20 and rnd.random() < 0.8:
                    c.px(cx + dx, cy + dy, "ivory", 90)
    c.rect(300, 10, 10, 10, "gold_hl")
    c.rect(302, 12, 6, 6, "gold_shine")
    for cx in (122, 402):
        _pillar(c, cx, 46, H - 20, ["gold_d", "gold", "gold_l", "ivory"])
    # 벨벳 커튼 양옆
    _curtain(c, 4, 46, H - 20)
    _curtain(c, W - 4, 46, H - 20, flip=True)
    c.save(f"{DIR_PH}/wall.png")


def _curtain(c: Canvas, x_edge: int, y0: int, y1: int, flip: bool = False) -> None:
    width = 26
    for i in range(width):
        fold = math.sin(i * 0.7)
        name = "purple_d" if fold > 0.3 else ("neon_purple" if fold > -0.3 else "purple_d")
        x = x_edge + (i if not flip else -i)
        for y in range(y0, y1):
            shade = "gold_l" if (y % 40) < 2 else name
            c.px(x, y, shade)


def madame_silhouette_ph() -> None:
    """마담 벨벳 뒤태 실루엣(높은 의자, 22×40 × 2프레임 가로) — 7단계 3/N 에 실제 캐릭터가 들어오기 전 복선.
    프레임 0 idle, 프레임 1 와인잔을 든 손(팔이 위로, 작은 잔)."""
    c = Canvas(44, 40)
    for frame in range(2):
        ox = frame * 22
        c.rect(ox + 6, 24, 10, 16, "purple_d")  # 의자 등받이
        c.outline_rect(ox + 6, 24, 10, 16, "void")
        c.pattern(ox + 7, 4, [
            "..dddd..",
            ".dddddd.",
            "dddddddd",
            "dddddddd",
            ".dddddd.",
            "..dddd..",
            "..d..d..",
            ".dd..dd.",
            "dd....dd",
            "d......d",
            "d......d",
            "d......d",
            "d......d",
            "dd....dd",
        ], {"d": "purple_d"})
        if frame == 1:
            # 오른팔이 잔을 들어 올린 자세(어깨~머리 옆까지)
            c.vline(ox + 16, 10, 17, "purple_d")
            c.px(ox + 16, 9, "gold_l")
            c.px(ox + 17, 9, "ivory")
            c.px(ox + 17, 8, "gold_hl")
    c.save(f"{DIR_PH}/madame_silhouette.png")


def gen_ph() -> None:
    wall_ph()
    _copy_table(DIR_PH)
    chandelier_1f()  # 1F 것을 만든 뒤
    import shutil
    shutil.copyfile(f"{DIR_1F}/chandelier.png", f"{DIR_PH}/chandelier.png")  # PH 도 재사용(같은 샹들리에)
    madame_silhouette_ph()
    _light_cone(f"{DIR_PH}/lamp_cone.png", "gold_shine")
    _light_pool(f"{DIR_PH}/light_pool.png", "ivory")


def main() -> None:
    wall()
    table()
    lamp()
    lamp_cone()
    light_pool()
    smoke()
    poster()
    gen_1f()
    gen_2f()
    gen_3f()
    gen_ph()
    print("bg ok")


if __name__ == "__main__":
    main()
