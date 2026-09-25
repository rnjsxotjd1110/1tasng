"""6단계 에셋: 스킬트리 노드 아이콘 57종(16×16, 궁극기 4종은 32×16 캔버스에 32×32 확대판도 저장) +
HEART 32×32. 갈래별 배지(원형, 좌상단 광원 4단계 셀 셰이딩) + 중앙 글리프 조합 방식으로 그린다.

  python3 tools/art/gen_skills.py

배지 색은 갈래 색(FORTUNE=금, MACHINE=청록, ECONOMY=호박, MYSTIC=보라, HEART=빨강)이고,
글리프는 노드 성격을 나타내는 작은 도형(주사위·불꽃·번개·눈·톱니 등)이다.
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, seeded  # noqa: E402

OUT = "assets/sprites/ui/skills"

# 갈래별 [outline, shadow, base, light, shine]
BRANCH_RAMP: dict[str, list[str]] = {
    "FORTUNE": ["gold_d", "gold", "gold_l", "gold_hl", "gold_shine"],
    "MACHINE": ["night", "water", "sky", "neon_cyan", "ivory"],
    "ECONOMY": ["wood_d", "wood", "wood_l", "amber", "gold_shine"],
    "MYSTIC": ["void", "purple_d", "neon_purple", "neon_pink", "ivory"],
    "HEART": ["red_d", "red", "red_l", "red_hl", "ivory"],
}
LIGHT = (-0.6, -0.7)


def badge(size: int, branch: str) -> Canvas:
    """좌상단 광원 원형 배지. 캔버스 정중앙, 반지름 = size*0.44."""
    c = Canvas(size, size)
    outline, shadow, base, light, _shine = BRANCH_RAMP[branch]
    cx = cy = size / 2.0
    r = size * 0.44
    for y in range(size):
        for x in range(size):
            dx = (x + 0.5 - cx) / r
            dy = (y + 0.5 - cy) / r
            d2 = dx * dx + dy * dy
            if d2 > 1.0:
                continue
            edge = d2 > (1.0 - 1.6 / r) ** 2
            if edge:
                c.px(x, y, outline)
                continue
            lam = dx * LIGHT[0] + dy * LIGHT[1]
            c.px(x, y, light if lam > 0.32 else base if lam > -0.15 else shadow)
    sx, sy = int(cx - r * 0.5), int(cy - r * 0.55)
    c.px(sx, sy, _shine)
    return c


def _center(c: Canvas, w: int, h: int) -> tuple[int, int]:
    return (c.w - w) // 2, (c.h - h) // 2


def g_pattern(c: Canvas, rows: list[str], colors: dict[str, str], ox: int = 0, oy: int = 0) -> None:
    w = max(len(r) for r in rows)
    x, y = _center(c, w, len(rows))
    c.pattern(x + ox, y + oy, rows, colors)


DIGITS: dict[str, list[str]] = {
    "0": [".#.", "#.#", "#.#", "#.#", ".#."],
    "2": ["##.", "..#", ".#.", "#..", "###"],
    "3": ["##.", "..#", ".#.", "..#", "##."],
    "5": ["###", "#..", "##.", "..#", "##."],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
}


def g_digit(c: Canvas, digit: str, color: str) -> None:
    g_pattern(c, DIGITS[digit], {"#": color})


def g_dice(c: Canvas, pips: list[tuple[int, int]], color: str) -> None:
    c.rect(*_center(c, 7, 7), 7, 7, "void")
    x0, y0 = _center(c, 7, 7)
    for dx, dy in pips:
        c.px(x0 + dx, y0 + dy, color)


def g_flame(c: Canvas, outer: str, inner: str) -> None:
    g_pattern(c, [
        "..o..",
        ".oOo.",
        "oOiOo",
        "oOiOo",
        ".oOo.",
        "..o..",
    ], {"o": outer, "O": outer, "i": inner})


def g_star(c: Canvas, color: str, shine: str) -> None:
    g_pattern(c, [
        "..o..",
        ".oso.",
        "ossso",
        ".oso.",
        "..o..",
    ], {"o": color, "s": shine})


def g_arrow_loop(c: Canvas, color: str) -> None:
    cx = cy = c.w / 2.0
    r = c.w * 0.28
    for deg in range(0, 300, 6):
        a = math.radians(deg - 90)
        c.px(round(cx + math.cos(a) * r), round(cy + math.sin(a) * r), color)
    tip = math.radians(300 - 90)
    tx, ty = cx + math.cos(tip) * r, cy + math.sin(tip) * r
    c.px(round(tx - 1), round(ty - 2), color)
    c.px(round(tx + 1), round(ty - 1), color)


def g_eye(c: Canvas, iris: str) -> None:
    g_pattern(c, [
        ".ooo.",
        "o###o",
        "#.i.#",
        "o###o",
        ".ooo.",
    ], {"o": "night", "#": "ivory", "i": iris})


def g_moon(c: Canvas, color: str) -> None:
    g_pattern(c, [
        "..oo.",
        ".o##.",
        ".o##.",
        ".o##.",
        "..oo.",
    ], {"o": color, "#": "void"})


def g_gear(c: Canvas, color: str, hub: str) -> None:
    g_pattern(c, [
        ".o.o.",
        "ooooo",
        ".ohh.",
        "ooooo",
        ".o.o.",
    ], {"o": color, "h": hub})


def g_shield(c: Canvas, body: str, trim: str) -> None:
    g_pattern(c, [
        "ooooo",
        "obbbo",
        "obbbo",
        ".obo.",
        "..o..",
    ], {"o": trim, "b": body})


def g_lightning(c: Canvas, color: str) -> None:
    g_pattern(c, [
        "..oo",
        ".oo.",
        "oooo",
        ".oo.",
        "oo..",
    ], {"o": color})


def g_hourglass(c: Canvas, glass: str, sand: str) -> None:
    g_pattern(c, [
        "ooooo",
        ".sss.",
        "..s..",
        ".sss.",
        "ooooo",
    ], {"o": glass, "s": sand})


def g_ball_pair(c: Canvas, a: str, b: str) -> None:
    g_pattern(c, [
        "aaa.bbb",
        "aaa.bbb",
        "aaa.bbb",
    ], {"a": a, "b": b})


def g_wave(c: Canvas, color: str) -> None:
    g_pattern(c, [
        "o..oo",
        "oo..o",
        "o..oo",
        "oo..o",
    ], {"o": color})


def g_heart_mini(c: Canvas, color: str) -> None:
    g_pattern(c, [
        ".o.o.",
        "ooooo",
        "ooooo",
        ".ooo.",
        "..o..",
    ], {"o": color})


def g_mirror(c: Canvas, glass: str, frame: str) -> None:
    g_pattern(c, [
        "ooo",
        "ogo",
        "ogo",
        "ogo",
        "ooo",
    ], {"o": frame, "g": glass})


def g_box(c: Canvas, body: str, trim: str) -> None:
    g_pattern(c, [
        "ooooo",
        "o###o",
        "ooooo",
        "o...o",
        "ooooo",
    ], {"o": trim, "#": body})


def g_tag(c: Canvas, body: str, hole: str) -> None:
    g_pattern(c, [
        "oo...",
        "ohoo.",
        "ooooo",
        ".ooo.",
        "..o..",
    ], {"o": body, "h": hole})


def g_briefcase(c: Canvas, body: str, trim: str) -> None:
    g_pattern(c, [
        ".ooo.",
        "ooooo",
        "o###o",
        "o###o",
        "ooooo",
    ], {"o": trim, "#": body})


def g_scale(c: Canvas, color: str) -> None:
    g_pattern(c, [
        "o.o.o",
        ".ooo.",
        "..o..",
        ".ooo.",
        "o...o",
    ], {"o": color})


def g_wheel8(c: Canvas, colors: list[str]) -> None:
    cx = cy = c.w / 2.0
    r = c.w * 0.32
    for i in range(8):
        a = math.radians(i * 45 - 90)
        col = colors[i % len(colors)]
        c.px(round(cx + math.cos(a) * r * 0.55), round(cy + math.sin(a) * r * 0.55), col)
        c.px(round(cx + math.cos(a) * r), round(cy + math.sin(a) * r), col)
    c.px(round(cx), round(cy), "gold_hl")


def g_storm(c: Canvas, color: str) -> None:
    cx = cy = c.w / 2.0
    for i, r in enumerate([1.0, 2.2, 3.4]):
        a = math.radians(i * 70)
        c.px(round(cx + math.cos(a) * r), round(cy + math.sin(a) * r), color)
        c.px(round(cx + math.cos(a + math.pi) * r), round(cy + math.sin(a + math.pi) * r), color)


def g_crystal(c: Canvas, glass: str, shine: str) -> None:
    g_pattern(c, [
        ".ooo.",
        "o.S.o",
        "o...o",
        ".ooo.",
        "..o..",
    ], {"o": glass, "S": shine})


def g_clover_mini(c: Canvas, color: str) -> None:
    g_pattern(c, [
        ".o.o.",
        "ooooo",
        ".ooo.",
        "..o..",
    ], {"o": color})


def g_infinity(c: Canvas, color: str) -> None:
    g_pattern(c, [
        "oo.oo",
        "o.o.o",
        "oo.oo",
    ], {"o": color})


def g_coin_stack(c: Canvas, colors: list[str]) -> None:
    x0, y0 = _center(c, 7, 6)
    for i, y in enumerate([4, 2, 0]):
        col = colors[i % len(colors)]
        c.hline(x0, x0 + 6, y0 + y, col)
        c.hline(x0 + 1, x0 + 5, y0 + y + 1, colors[-1])


def g_piggy(c: Canvas, body: str, trim: str) -> None:
    x0, y0 = _center(c, 7, 5)
    g_pattern(c, [
        ".ooooo",
        "oooooO",
        "oooooO",
        "oooooo",
        ".o.o..",
    ], {"o": body, "O": trim}, )
    c.px(x0 + 6, y0 + 1, trim)


def g_book(c: Canvas, cover: str, page: str) -> None:
    g_pattern(c, [
        "ooooo",
        "opppo",
        "opppo",
        "opppo",
        "ooooo",
    ], {"o": cover, "p": page})


def g_chain(c: Canvas, color: str) -> None:
    g_pattern(c, [
        "oo.oo",
        "o.o.o",
        "oo.oo",
        "o.o.o",
        "oo.oo",
    ], {"o": color})


def g_key(c: Canvas, color: str) -> None:
    g_pattern(c, [
        "oo...",
        "o.o..",
        "oo.oo",
        "...o.",
        "...o.",
    ], {"o": color})


def g_plus(c: Canvas, color: str) -> None:
    g_pattern(c, [
        "..o..",
        "..o..",
        "ooooo",
        "..o..",
        "..o..",
    ], {"o": color})


# ── 노드 → (갈래, 글리프 함수) ───────────────────────────────
def _b(branch: str) -> str:
    return branch


NODE_GLYPHS: dict[str, tuple[str, callable]] = {
    "heart": ("HEART", lambda c: g_heart_mini(c, "ivory")),
    # FORTUNE(금 배지) — 어두운(void/night) 주 글리프 + 소량의 원색 강조로 금색과 대비시킨다.
    "f1": ("FORTUNE", lambda c: g_dice(c, [(0, 0), (-2, -2), (2, 2)], "red_l")),
    "f2": ("FORTUNE", lambda c: g_dice(c, [(-2, -2), (2, -2), (0, 0), (-2, 2), (2, 2)], "ivory")),
    "f3": ("FORTUNE", lambda c: g_digit(c, "0", "night")),
    "f4": ("FORTUNE", lambda c: g_clover_mini(c, "clover")),
    "f5": ("FORTUNE", lambda c: g_wave(c, "night")),
    "f6": ("FORTUNE", lambda c: g_flame(c, "red_l", "ivory")),
    "f7": ("FORTUNE", lambda c: g_crystal(c, "night", "ivory")),
    "f8": ("FORTUNE", lambda c: g_ball_pair(c, "red_l", "night")),
    "f9": ("FORTUNE", lambda c: g_digit(c, "7", "night")),
    "f10": ("FORTUNE", lambda c: g_coin_stack(c, ["night", "wood_d", "ivory"])),
    "f11": ("FORTUNE", lambda c: g_infinity(c, "night")),
    "f12": ("FORTUNE", lambda c: g_wave(c, "red_l")),
    "f13": ("FORTUNE", lambda c: g_clover_mini(c, "clover_d")),
    "f14": ("FORTUNE", lambda c: g_lightning(c, "neon_pink")),
    # MACHINE(청록 배지) — 밝은(ivory) 주 글리프로 어두운 청록과 대비시킨다.
    "m1": ("MACHINE", lambda c: g_arrow_loop(c, "ivory")),
    "m2": ("MACHINE", lambda c: g_lightning(c, "ivory")),
    "m3": ("MACHINE", lambda c: g_box(c, "night", "ivory")),
    "m4": ("MACHINE", lambda c: g_plus(c, "ivory")),
    "m5": ("MACHINE", lambda c: g_coin_stack(c, ["night", "water", "ivory"])),
    "m6": ("MACHINE", lambda c: g_eye(c, "neon_cyan")),
    "m7": ("MACHINE", lambda c: g_gear(c, "ivory", "night")),
    "m8": ("MACHINE", lambda c: g_box(c, "night", "neon_cyan")),
    "m9": ("MACHINE", lambda c: g_moon(c, "ivory")),
    "m10": ("MACHINE", lambda c: g_lightning(c, "neon_pink")),
    "m11": ("MACHINE", lambda c: g_moon(c, "neon_cyan")),
    "m12": ("MACHINE", lambda c: g_book(c, "night", "ivory")),
    "m13": ("MACHINE", lambda c: g_briefcase(c, "night", "ivory")),
    "m14": ("MACHINE", lambda c: g_gear(c, "ivory", "neon_pink")),
    # ECONOMY(호박 배지) — 어두운(wood_d/night) 주 글리프로 밝은 호박색과 대비시킨다.
    "e1": ("ECONOMY", lambda c: g_scale(c, "night")),
    "e2": ("ECONOMY", lambda c: g_arrow_loop(c, "night")),
    "e3": ("ECONOMY", lambda c: g_star(c, "ivory", "gold_shine")),
    "e4": ("ECONOMY", lambda c: g_plus(c, "night")),
    "e5": ("ECONOMY", lambda c: g_wave(c, "night")),
    "e6": ("ECONOMY", lambda c: g_scale(c, "ivory")),
    "e7": ("ECONOMY", lambda c: g_tag(c, "night", "gold_shine")),
    "e8": ("ECONOMY", lambda c: g_tag(c, "wood_d", "ivory")),
    "e9": ("ECONOMY", lambda c: g_plus(c, "clover")),
    "e10": ("ECONOMY", lambda c: g_coin_stack(c, ["night", "wood_d", "ivory"])),
    "e11": ("ECONOMY", lambda c: g_box(c, "red_l", "night")),
    "e12": ("ECONOMY", lambda c: g_box(c, "night", "wood_d")),
    "e13": ("ECONOMY", lambda c: g_piggy(c, "night", "ivory")),
    "e14": ("ECONOMY", lambda c: g_infinity(c, "night")),
    # MYSTIC(보라 배지) — 밝은(ivory/gold_shine) 주 글리프로 채도 높은 보라와 대비시킨다.
    "y1": ("MYSTIC", lambda c: g_shield(c, "ivory", "night")),
    "y2": ("MYSTIC", lambda c: g_crystal(c, "ivory", "neon_pink")),
    "y3": ("MYSTIC", lambda c: g_mirror(c, "ivory", "night")),
    "y4": ("MYSTIC", lambda c: g_star(c, "gold_shine", "ivory")),
    "y5": ("MYSTIC", lambda c: g_flame(c, "neon_pink", "gold_shine")),
    "y6": ("MYSTIC", lambda c: g_crystal(c, "neon_pink", "ivory")),
    "y7": ("MYSTIC", lambda c: g_digit(c, "0", "gold_shine")),
    "y8": ("MYSTIC", lambda c: g_arrow_loop(c, "ivory")),
    "y9": ("MYSTIC", lambda c: g_eye(c, "neon_pink")),
    "y10": ("MYSTIC", lambda c: g_ball_pair(c, "ivory", "gold_shine")),
    "y11": ("MYSTIC", lambda c: g_hourglass(c, "ivory", "neon_pink")),
    "y12": ("MYSTIC", lambda c: g_storm(c, "ivory")),
    "y13": ("MYSTIC", lambda c: g_hourglass(c, "ivory", "gold_shine")),
    "y14": ("MYSTIC", lambda c: g_wheel8(c, ["red_l", "night", "gold_hl"])),
}


def silhouette(c: Canvas) -> Canvas:
    out = Canvas(c.w, c.h)
    m = c.mask()
    from pixlib import rgb
    dark = rgb("ink")
    edge_c = rgb("shadow")
    out.a[m, :3] = dark
    out.a[m, 3] = 255
    import numpy as np
    padded = np.pad(m, 1)
    edge = m & ~(padded[:-2, 1:-1] & padded[2:, 1:-1] & padded[1:-1, :-2] & padded[1:-1, 2:])
    out.a[edge, :3] = edge_c
    return out


def build_icon(node_id: str, size: int) -> Canvas:
    branch, glyph_fn = NODE_GLYPHS[node_id]
    c = badge(size, branch)
    glyph_fn(c)
    return c


def main() -> None:
    os.makedirs(os.path.join("assets", "sprites", "ui", "skills"), exist_ok=True)
    heart = build_icon("heart", 32)
    heart.save(f"{OUT}/icon_heart.png")
    for node_id, (branch, _fn) in NODE_GLYPHS.items():
        if node_id == "heart":
            continue
        is_ultimate = node_id in ("f14", "m14", "e14", "y14")
        size = 32 if is_ultimate else 16
        icon = build_icon(node_id, size)
        icon.save(f"{OUT}/icon_{node_id}.png")
        silhouette(icon).save(f"{OUT}/icon_{node_id}_locked.png")
    print("skills icons ok: %d" % len(NODE_GLYPHS))


if __name__ == "__main__":
    main()
