"""타이틀 화면 에셋(8단계 1/N): 스플래시 개발사 로고, 비 내리는 밤거리 배경, 작은 회전 룰렛 아이콘.

  python3 tools/art/gen_title.py

출력(팔레트 36색):
  assets/sprites/title/dev_logo.png   스플래시용 개발사 워드마크(가제. 문자열은 STUDIO_NAME 상수 하나 —
                                       scripts/autoload/economy.gd 의 Economy.STUDIO_NAME 과 반드시 같아야 한다)
  assets/sprites/title/bg_wall.png    640×360, 비 내리는 밤의 카지노 거리(정적 배경).
                                       빗줄기·번개·네온 로고·회전 아이콘·칩 커서는 title_screen.gd 가 동적으로 그린다.
  assets/sprites/title/wheel_icon.png 16×16 × 8프레임 가로 스트립. 로고 아래 미니 룰렛 아이콘(정수 프레임 교체로
                                       "회전"을 표현 — 연속 회전 금지 규칙, ART_BIBLE 4장).
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, ROOT, band_pick, disc_mask, polar  # noqa: E402

OUT = "assets/sprites/title"
FONT = os.path.join(ROOT, "assets", "fonts", "Galmuri11-Bold.ttf")
## scripts/autoload/economy.gd 의 Economy.STUDIO_NAME 과 같은 문자열(가제). 정식 이름이 정해지면
## 두 곳을 함께 바꾸고 이 스크립트를 다시 돌린다.
STUDIO_NAME = "HOUSE EDGE"


# ── 스플래시 개발사 로고 ─────────────────────────────────────

def _text_mask(text: str, size: int) -> np.ndarray:
    font = ImageFont.truetype(FONT, size)
    img = Image.new("L", (size * len(text) * 2, size * 2), 0)
    ImageDraw.Draw(img).text((2, 0), text, font=font, fill=255)
    arr = np.array(img) > 127
    rows = np.where(arr.any(axis=1))[0]
    cols = np.where(arr.any(axis=0))[0]
    return arr[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]


def _chip_glyph(c: Canvas, cx: int, cy: int, r: int) -> None:
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d2 = dx * dx + dy * dy
            if d2 <= r * r:
                c.px(cx + dx, cy + dy, "red" if d2 > (r - 2) * (r - 2) else "red_l")
    for dy in range(-(r - 3), r - 2):
        for dx in range(-(r - 3), r - 2):
            if dx * dx + dy * dy <= (r - 3) * (r - 3):
                c.px(cx + dx, cy + dy, "ivory")
    c.outline("red_d")


def dev_logo() -> None:
    scale = 2
    mask = _text_mask(STUDIO_NAME, 15)
    big = np.kron(mask, np.ones((scale, scale), dtype=bool))
    text_h, text_w = big.shape
    icon_r = 9
    icon_gap = 6
    pad = 6
    left_pad = pad + icon_r * 2 + icon_gap
    c = Canvas(left_pad + text_w + pad, max(text_h, icon_r * 2) + pad * 2)
    for y in range(text_h):
        for x in range(text_w):
            if big[y, x]:
                t = y / max(1, text_h - 1)
                color = "gold_hl" if t < 0.4 else ("gold_l" if t < 0.75 else "gold")
                c.px(left_pad + x, pad + y, color)
    c.outline("gold_d")
    _chip_glyph(c, pad + icon_r, pad + text_h // 2, icon_r)
    c.save(f"{OUT}/dev_logo.png")


# ── 미니 룰렛 아이콘(8프레임) ────────────────────────────────

def _wheel_frame(offset_deg: float) -> Canvas:
    size = 16
    cx = cy = size / 2.0
    fc = Canvas(size, size)
    r_arr, theta_arr = polar(size, size, cx, cy)
    for y in range(size):
        for x in range(size):
            r = float(r_arr[y, x])
            if r > 7.6:
                continue
            if r > 6.3:
                fc.px(x, y, "wood_l" if r > 7.0 else "wood")
            elif r > 2.2:
                ang = (math.degrees(float(theta_arr[y, x])) - offset_deg) % 45.0
                fc.px(x, y, "red" if ang < 22.5 else "pocket_k")
            else:
                fc.px(x, y, "gold_l" if r > 1.1 else "gold_hl")
    fc.outline("wood_d")
    return fc


def wheel_icon() -> None:
    n = 8
    size = 16
    c = Canvas(size * n, size)
    for i in range(n):
        c.blit(_wheel_frame(i * (45.0 / n)), i * size, 0)
    c.save(f"{OUT}/wheel_icon.png")


# ── 타이틀 배경(640×360, 정적) ────────────────────────────────

W, H = 640, 360
SKY_BOTTOM = 90
GROUND_TOP = 302


def _building(c: Canvas, x: int, y: int, w: int, wall: str, windows: list[tuple[int, int]], lit: str) -> None:
    c.rect(x, y, w, GROUND_TOP - y, wall)
    c.vline(x, y, GROUND_TOP - 1, "void")
    for wx, wy in windows:
        c.rect(x + wx, y + wy, 4, 6, lit)
        c.outline_rect(x + wx - 1, y + wy - 1, 6, 8, "void")


def title_bg() -> None:
    c = Canvas(W, H, fill="void")
    # 하늘: void → night → dusk 밴딩(디더링 그라데이션, ART_BIBLE 4장에서 허용).
    sky_ramp = ["void", "night", "dusk"]
    for y in range(SKY_BOTTOM):
        color = band_pick(y / SKY_BOTTOM, sky_ramp)
        c.hline(0, W - 1, y, color)
    # 젖은 보도(건물·문보다 먼저 그려야 문 밑 빛줄기·가로등이 나중에 덮이지 않는다).
    c.rect(0, GROUND_TOP, W, H - GROUND_TOP, "void")
    for y in range(GROUND_TOP, H):
        if (y - GROUND_TOP) % 3 == 0:
            c.hline(0, W - 1, y, "night")
    # 좌우 건물은 화면 끝까지(캔버스 가장자리에 빈틈이 남지 않게).
    _building(c, 0, 118, 190, "shadow", [(20, 24), (56, 24), (150, 24), (20, 56), (92, 56), (150, 60), (20, 88), (56, 96)], "amber")
    _building(c, 450, 108, 190, "shadow", [(20, 30), (60, 30), (100, 30), (150, 40), (30, 66), (80, 66), (130, 70), (40, 100)], "gold_l")
    # 카지노 정면 건물(중앙, 좌우 건물보다 한 걸음 앞으로 — 더 밝은 톤).
    _building(c, 190, 70, 260, "ink", [(20, 20), (220, 20), (20, 46), (220, 46)], "gold_hl")
    # 카지노 간판 지지대(네온 로고는 title_screen.gd 가 그 위에 겹쳐 그린다).
    c.rect(226, 96, 188, 34, "night")
    c.outline_rect(226, 96, 188, 34, "void")
    for bulb_x in range(230, 410, 12):
        c.px(bulb_x, 94, "gold_d")
    # 차양(캐노피).
    c.rect(232, 214, 176, 8, "red_d")
    c.rect(232, 222, 176, 3, "gold_d")
    for tx in range(238, 400, 16):
        c.rect(tx, 214, 8, 8, "red")
    # 정문(양쪽으로 열리는 문) + 문 밑 새어나오는 빛.
    c.rect(272, 236, 96, 66, "wood_d")
    c.vline(320, 236, 301, "gold_d")
    for door_x in (280, 328):
        c.rect(door_x, 244, 40, 50, "wood")
        c.outline_rect(door_x, 244, 40, 50, "wood_d")
        c.rect(door_x + 34, 264, 2, 6, "gold_l")
    c.hline(272, 367, 302, "gold_hl")
    # 가로등(왼쪽).
    lamp_x = 18
    c.vline(lamp_x, 210, GROUND_TOP - 1, "ink")
    c.rect(lamp_x - 4, 196, 9, 14, "ink")
    c.rect(lamp_x - 2, 199, 5, 8, "gold_l")
    # (가로등 빛 웅덩이는 생략 — 비·네온이 이미 화면 분위기를 채운다.)
    # 물웅덩이 반사: 위쪽 불빛색이 아래로 갈수록 옅어지는 세로 얼룩(정확한 좌우반전 대신 분위기용).
    reflections = [
        (95, "amber", 24), (450, "gold_l", 20),
        (296, "neon_pink", 40), (300, "neon_cyan", 34), (344, "amber", 26),
    ]
    for x, name, length in reflections:
        for i in range(length):
            alpha = int(150 * (1.0 - i / length))
            if alpha <= 0 or i % 4 == 3:
                continue
            c.px(x, GROUND_TOP + 4 + i, name, alpha)
            c.px(x + 1, GROUND_TOP + 4 + i, name, alpha)
    c.save(f"{OUT}/bg_wall.png")


def main() -> None:
    dev_logo()
    wheel_icon()
    title_bg()
    print("title ok")


if __name__ == "__main__":
    main()
