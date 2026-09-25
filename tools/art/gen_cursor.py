"""마우스 커서 3종(8단계 4/N, ART_BIBLE 16장).

  python3 tools/art/gen_cursor.py

  assets/sprites/ui/cursor_normal.png     기본(화살표 대체) — 나무 대거 모양, 끝이 좌상단 원점
  assets/sprites/ui/cursor_pointer.png    상호작용 가능(POINTING_HAND 대체) — 반짝이는 칩
  assets/sprites/ui/cursor_forbidden.png  비활성(FORBIDDEN 대체) — 금지 표시가 있는 칩

CURSOR_SIZE(24px)는 뷰포트 정수 배율과 무관하게 OS 커서로 그대로 쓰인다(엔진이 뷰포트처럼 자동으로
확대하지 않음) — 1x 창에서도 또렷하도록 일부러 16px 아이콘보다 크게 그렸다(ART_BIBLE 16장에 근거 기록).
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, disc_mask  # noqa: E402

OUT = "assets/sprites/ui"
SIZE = 24


def gen_normal() -> None:
    c = Canvas(SIZE, SIZE)
    # 대각선 화살표(끝=원점 (0,0)), 나무 자루 느낌의 단순 삼각형 + 외곽선.
    pts = []
    for y in range(15):
        width = max(1, y - 1)
        for x in range(width):
            pts.append((x, y))
    tail = [(x, y) for x, y in [(4, 10), (5, 11), (6, 12), (7, 13), (8, 14), (9, 15), (7, 14), (6, 13), (5, 12)]]
    for x, y in pts + tail:
        c.px(x, y, "ivory")
    # 외곽선: 채워진 픽셀 중 배경과 맞닿은 칸만 ink 로 덧그린다.
    filled = set(pts + tail)
    for x, y in list(filled):
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in filled and c.inside(nx, ny) and not c.is_set(nx, ny):
                c.px(nx, ny, "ink")
    c.save(f"{OUT}/cursor_normal.png")


def gen_pointer() -> None:
    c = Canvas(SIZE, SIZE)
    cx, cy, r = SIZE / 2.0, SIZE / 2.0, 8.0
    mask = disc_mask(r, cx, cy, SIZE, SIZE)
    rim = disc_mask(r, cx, cy, SIZE, SIZE) & ~disc_mask(r - 2.0, cx, cy, SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            if mask[y, x]:
                c.px(x, y, "gold_hl" if rim[y, x] else "gold")
    # 반짝임(우상단 스파클, 절차적 십자).
    sx, sy = int(cx + 6), int(cy - 7)
    for dx, dy in [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)]:
        c.px(sx + dx, sy + dy, "gold_shine")
    c.save(f"{OUT}/cursor_pointer.png")


def gen_forbidden() -> None:
    c = Canvas(SIZE, SIZE)
    cx, cy, r = SIZE / 2.0, SIZE / 2.0, 8.0
    mask = disc_mask(r, cx, cy, SIZE, SIZE)
    rim = mask & ~disc_mask(r - 2.0, cx, cy, SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            if mask[y, x]:
                c.px(x, y, "stone" if rim[y, x] else "ink")
    # 금지 표시: 굵은 대각선 띠(빨강) + 얇은 외곽선.
    for t in range(-2, 3):
        for i in range(SIZE):
            x, y = i, i + t
            if c.inside(x, y):
                c.px(x, y, "red_hl" if abs(t) <= 1 else "red_d")
    c.save(f"{OUT}/cursor_forbidden.png")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    gen_normal()
    gen_pointer()
    gen_forbidden()
    print("done")


if __name__ == "__main__":
    main()
