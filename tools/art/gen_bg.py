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
from pixlib import BAYER4, Canvas, dither_pick, seeded  # noqa: E402

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


def main() -> None:
    wall()
    table()
    lamp()
    lamp_cone()
    light_pool()
    smoke()
    poster()
    print("bg ok")


if __name__ == "__main__":
    main()
