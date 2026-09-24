"""UI 9-슬라이스 프레임·버튼·아이콘을 만든다.

  python3 tools/art/gen_ui.py

출력은 assets/ui/ (프레임) 와 assets/sprites/ui/ (아이콘·토큰). 파일 목록은 ART_BIBLE 8-1.
9-슬라이스 여백은 scripts 쪽 theme 빌더(tools/art/build_theme.gd)의 상수와 같아야 한다.
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, disc_mask, seeded  # noqa: E402

UI = "assets/ui"
ICONS = "assets/sprites/ui"


# ── 패널 ─────────────────────────────────────────────────

def rivets(c: Canvas, inset: int) -> None:
    for x, y in [(inset, inset), (c.w - inset - 2, inset), (inset, c.h - inset - 2), (c.w - inset - 2, c.h - inset - 2)]:
        c.px(x, y, "gold_hl")
        c.px(x + 1, y, "gold_l")
        c.px(x, y + 1, "gold_l")
        c.px(x + 1, y + 1, "gold_d")


def bevel_box(c: Canvas, x: int, y: int, w: int, h: int, outline: str, body: str, hi: str, lo: str) -> None:
    c.rect(x, y, w, h, outline)
    c.rect(x + 1, y + 1, w - 2, h - 2, body)
    c.hline(x + 1, x + w - 2, y + 1, hi)
    c.vline(x + 1, y + 1, y + h - 2, hi)
    c.hline(x + 2, x + w - 2, y + h - 2, lo)
    c.vline(x + w - 2, y + 2, y + h - 2, lo)


def panel(name: str, body: str, hi: str, lo: str, outline: str = "void", trim: str | None = "gold_d") -> None:
    """16×16, 9-슬라이스 여백 6. 외곽선 → 금 테(선택) → 베벨 → 몸통, 모서리 리벳."""
    c = Canvas(16, 16)
    c.rect(0, 0, 16, 16, outline)
    if trim:
        c.rect(1, 1, 14, 14, trim)
        c.hline(1, 14, 1, "gold")
        c.vline(1, 1, 14, "gold")
        bevel_box(c, 2, 2, 12, 12, outline, body, hi, lo)
        rivets(c, 3)
    else:
        bevel_box(c, 0, 0, 16, 16, outline, body, hi, lo)
        rivets(c, 2)
    c.save(f"{UI}/{name}.png")


def plain_frame(name: str, body: str, outline: str, hi: str | None = None, size: int = 8) -> None:
    c = Canvas(size, size)
    c.rect(0, 0, size, size, outline)
    c.rect(1, 1, size - 2, size - 2, body)
    if hi:
        c.hline(1, size - 2, 1, hi)
        c.vline(1, 1, size - 2, hi)
    c.save(f"{UI}/{name}.png")


# ── 버튼 ─────────────────────────────────────────────────
# 14×16, 여백 좌우 4 / 위 4 / 아래 5. 아래 2줄은 '두께'(눌리면 사라지고 내용이 1px 내려간다).

BTN_W = 14
BTN_H = 16


def button(name: str, outline: str, body: str, hi: str, depth: str, pressed: bool = False, shine: str | None = None) -> None:
    c = Canvas(BTN_W, BTN_H)
    top = 1 if pressed else 0
    # 외곽선(모서리 1px 깎기)
    c.rect(1, top, BTN_W - 2, BTN_H - top, outline)
    c.rect(0, top + 1, BTN_W, BTN_H - top - 2, outline)
    face_bottom = BTN_H - 2 if pressed else BTN_H - 3
    c.rect(1, top + 1, BTN_W - 2, face_bottom - top, body)
    if not pressed:
        c.rect(1, face_bottom + 1, BTN_W - 2, 1, depth)
    c.hline(2, BTN_W - 3, top + 1, hi)
    c.vline(1, top + 2, face_bottom - 1, hi)
    if shine:
        c.px(2, top + 1, shine)
    c.save(f"{UI}/{name}.png")


def button_set(prefix: str, normal: tuple, hover: tuple, pressed: tuple, disabled: tuple) -> None:
    button(f"{prefix}_normal", *normal)
    button(f"{prefix}_hover", *hover)
    button(f"{prefix}_pressed", *pressed, pressed=True)
    button(f"{prefix}_disabled", *disabled)


def tab(name: str, outline: str, body: str, hi: str, underline: str | None) -> None:
    """탭 12×16, 여백 4/4/4/4. 선택 탭은 아래 금색 선."""
    c = Canvas(12, 16)
    c.rect(1, 0, 10, 16, outline)
    c.rect(0, 1, 12, 14, outline)
    c.rect(1, 1, 10, 14, body)
    c.hline(2, 9, 1, hi)
    c.vline(1, 2, 13, hi)
    if underline:
        c.hline(1, 10, 14, underline)
        c.hline(2, 9, 13, underline)
    c.save(f"{UI}/{name}.png")


def spin_button() -> None:
    """큰 빨간 카지노 버튼 80×30. 금 테두리, 위쪽 반사광, 아래 두께 3px."""
    w, h = 80, 30

    def make(name: str, rim: str, rim_hi: str, face: str, face_hi: str, face_lo: str, pressed: bool, depth: str) -> None:
        c = Canvas(w, h)
        top = 2 if pressed else 0
        bottom_face = h - 4
        # 둥근 알약 모양 마스크
        def pill(x0: int, y0: int, x1: int, y1: int, color: str) -> None:
            r = (y1 - y0) / 2.0
            for y in range(y0, y1):
                for x in range(x0, x1):
                    cx = min(max(x + 0.5, x0 + r), x1 - r)
                    cy = (y0 + y1) / 2.0
                    if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                        c.px(x, y, color)
        if not pressed:
            pill(0, 3, w, h, "red_d")          # 두께(그림자 면)
            pill(1, 3, w - 1, h - 1, depth)
        pill(0, top, w, bottom_face + top + (1 if pressed else 0), "gold_d")
        pill(1, top + 1, w - 1, bottom_face + top - 1 + (1 if pressed else 0), rim)
        # 테두리 윗부분 밝게
        for x in range(4, w - 4):
            if c.get(x, top + 1)[3] and c.get(x, top + 1)[:3] != (0, 0, 0):
                c.px(x, top + 1, rim_hi)
        pill(3, top + 3, w - 3, bottom_face + top - 3 + (1 if pressed else 0), "red_d")
        pill(4, top + 4, w - 4, bottom_face + top - 4 + (1 if pressed else 0), face)
        # 아래쪽 면 어둡게
        for y in range(top + 4, bottom_face + top - 4 + (1 if pressed else 0)):
            for x in range(4, w - 4):
                if y >= top + (bottom_face - 4) * 0.72 and c.get(x, y)[:3] == tuple(int(PAL[face][i:i + 2], 16) for i in (1, 3, 5)):
                    c.px(x, y, face_lo)
        # 위쪽 반사 띠(알약 안쪽 좁은 띠)
        for x in range(12, w - 12):
            c.px(x, top + 6, face_hi)
        for x in range(9, 12):
            c.px(x, top + 7, face_hi)
        c.px(10, top + 8, face_hi)
        c.save(f"{UI}/{name}.png")

    make("spin_normal", "gold_l", "gold_hl", "red_l", "red_hl", "red", False, "red")
    make("spin_hover", "gold_hl", "gold_shine", "red_hl", "ivory", "red_l", False, "red")
    make("spin_pressed", "gold", "gold_l", "red", "red_l", "red_d", True, "red")
    make("spin_disabled", "stone", "mist", "ink", "stone", "shadow", False, "night")
    # 숨쉬는 빛(가산 합성용): 알약 둘레 번짐
    g = Canvas(w + 12, h + 12)
    for y in range(g.h):
        for x in range(g.w):
            dx = max(abs(x + 0.5 - g.w / 2) - (w / 2 - h / 2), 0)
            dy = abs(y + 0.5 - (g.h / 2 - 1))
            d = math.hypot(dx, dy) - (h / 2 - 2)
            if 0 <= d < 6:
                g.px(x, y, "red_hl", int(150 * (1 - d / 6) ** 2) + 10)
    g.save(f"{UI}/spin_glow.png")


# ── 기타 컨트롤 ──────────────────────────────────────────

def tooltip() -> None:
    c = Canvas(8, 8)
    c.rect(0, 0, 8, 8, "gold_d")
    c.rect(1, 1, 6, 6, "void")
    c.hline(1, 6, 1, "dusk")
    c.save(f"{UI}/tooltip.png")


def scrollbar() -> None:
    t = Canvas(6, 8)
    t.rect(0, 0, 6, 8, "void")
    t.rect(1, 0, 4, 8, "night")
    t.save(f"{UI}/scroll_track.png")
    for name, body, hi in [("scroll_grabber", "wood_l", "wood_hl"), ("scroll_grabber_hover", "wood_hl", "gold_l"), ("scroll_grabber_pressed", "gold", "gold_l")]:
        g = Canvas(6, 8)
        g.rect(1, 0, 4, 8, "wood_d")
        g.rect(0, 1, 6, 6, "wood_d")
        g.rect(1, 1, 4, 6, body)
        g.vline(1, 1, 6, hi)
        g.save(f"{UI}/{name}.png")


def slider() -> None:
    t = Canvas(8, 6)
    t.rect(0, 0, 8, 6, "void")
    t.rect(1, 1, 6, 4, "night")
    t.hline(1, 6, 4, "dusk")
    t.save(f"{UI}/slider_track.png")
    f = Canvas(8, 6)
    f.rect(0, 0, 8, 6, "gold_d")
    f.rect(1, 1, 6, 4, "gold")
    f.hline(1, 6, 1, "gold_l")
    f.save(f"{UI}/slider_fill.png")
    for name, body, hi in [("slider_grabber", "gold_l", "gold_hl"), ("slider_grabber_hover", "gold_hl", "gold_shine")]:
        g = Canvas(7, 11)
        g.pattern(0, 0, [
            ".ooooo.",
            "ohhhhbo",
            "ohbbbbo",
            "ohbbbbo",
            "ohbbbbo",
            "ohbbbbo",
            "ohbbbbo",
            "obbbbdo",
            ".obbdo.",
            "..odo..",
            "...o...",
        ], {"o": "gold_d", "h": hi, "b": body, "d": "gold"})
        g.save(f"{ICONS}/{name}.png")


def checkbox() -> None:
    base = [
        "ooooooooo",
        "ohhhhhhho",
        "oh.....bo",
        "oh.....bo",
        "oh.....bo",
        "oh.....bo",
        "oh.....bo",
        "obbbbbbbo",
        "ooooooooo",
    ]
    off = Canvas(9, 9)
    off.pattern(0, 0, base, {"o": "void", "h": "shadow", "b": "dusk", ".": "night"})
    off.rect(2, 2, 5, 5, "night")
    off.save(f"{ICONS}/check_off.png")
    on = Canvas(9, 9)
    on.pattern(0, 0, base, {"o": "gold_d", "h": "gold_l", "b": "gold", ".": "night"})
    on.rect(2, 2, 5, 5, "night")
    on.pattern(2, 2, [
        "....g",
        "...gg",
        "g.gg.",
        "ggg..",
        ".g...",
    ], {"g": "gold_hl"})
    on.save(f"{ICONS}/check_on.png")


# ── 아이콘 ───────────────────────────────────────────────

def chip_icon() -> None:
    """금 칩 13×13. 가장자리 홈(ivory), 안쪽 링, 가운데 무늬."""
    n = 13
    c = Canvas(n, n)
    cx = cy = n / 2
    for y in range(n):
        for x in range(n):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            ang = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
            if d <= 6.5:
                light = -math.cos(ang + math.pi / 4)  # 좌상단 밝게
                if d > 5.4:
                    c.px(x, y, "gold_d")
                elif d > 4.2:
                    notch = int(((ang + math.pi) / (2 * math.pi)) * 8 + 0.5) % 2 == 0
                    c.px(x, y, "ivory" if notch else ("gold_l" if light > 0 else "gold"))
                elif d > 3.2:
                    c.px(x, y, "gold")
                else:
                    c.px(x, y, "gold_hl" if light > -0.2 else "gold_l")
    c.px(5, 5, "gold_shine")
    c.px(6, 5, "gold_shine")
    c.px(5, 6, "gold_shine")
    c.save(f"{ICONS}/icon_chip.png")
    # 작은 칩(날아가는 칩) 7×7
    s = Canvas(7, 7)
    s.pattern(0, 0, [
        ".ooooo.",
        "oihhhio",
        "ohggghо".replace("о", "o"),
        "ohgsgho",
        "ohggghо".replace("о", "o"),
        "oihhhio",
        ".ooooo.",
    ], {"o": "gold_d", "i": "ivory", "h": "gold_l", "g": "gold_hl", "s": "gold_shine"})
    s.save(f"{ICONS}/icon_chip_small.png")


def sparkle_frames() -> None:
    """반짝임 4프레임, 각 5×5 → 20×5."""
    c = Canvas(20, 5)
    frames = [
        [".....", ".....", "..s..", ".....", "....."],
        [".....", "..s..", ".sSs.", "..s..", "....."],
        ["..s..", "..S..", "sSSSs", "..S..", "..s.."],
        [".....", "..s..", ".s.s.", "..s..", "....."],
    ]
    for i, f in enumerate(frames):
        c.pattern(i * 5, 0, f, {"s": "gold_hl", "S": "gold_shine"})
    c.save(f"{ICONS}/sparkle.png")
    w = Canvas(20, 5)
    for i, f in enumerate(frames):
        w.pattern(i * 5, 0, f, {"s": "mist", "S": "ivory"})
    w.save(f"{ICONS}/sparkle_white.png")


def clover_icon() -> None:
    """네 잎 클로버 11×11: 하트 모양 잎 4장 + 줄기. 좌상단 잎이 가장 밝다."""
    c = Canvas(11, 11)
    c.pattern(0, 0, [
        ".ooo.ooo...",
        "oLLLoLCCo..",
        "oLLHoLCCo..",
        "oLLLLCCCo..",
        ".oooLCooo..",
        "oLLLCCCCo..",
        "oLLCoCCCo..",
        "oLCCoCCdo..",
        ".ooo.oooso.",
        ".......os..",
        "........o..",
    ], {"o": "felt_d", "L": "clover", "H": "ivory", "C": "clover_d", "d": "felt", "s": "clover_d"})
    c.save(f"{ICONS}/icon_clover.png")


def small_icons() -> None:
    flame = Canvas(7, 8)
    flame.pattern(0, 0, [
        "...o...",
        "..oao..",
        ".oaao..",
        ".oayao.",
        "oayyyao",
        "oaygyao",
        "oayyyao",
        ".ooooo.",
    ], {"o": "red", "a": "amber", "y": "gold_hl", "g": "gold_shine"})
    flame.save(f"{ICONS}/icon_flame.png")
    snow = Canvas(7, 7)
    snow.pattern(0, 0, [
        "c..c..c",
        ".c.c.c.",
        "..iii..",
        "cciIicc",
        "..iii..",
        ".c.c.c.",
        "c..c..c",
    ], {"c": "neon_cyan", "i": "mist", "I": "ivory"})
    snow.save(f"{ICONS}/icon_snow.png")
    lock = Canvas(7, 9)
    lock.pattern(0, 0, [
        ".ooooo.",
        "om...mo",
        "om...mo",
        "ooooooo",
        "oggggdo",
        "oggkgdo",
        "ogdkddo",
        "oddddd0".replace("0", "o"),
        "ooooooo",
    ], {"o": "gold_d", "m": "mist", "g": "gold_l", "d": "gold", "k": "wood_d"})
    lock.save(f"{ICONS}/icon_lock.png")
    gear = Canvas(11, 11)
    gear.pattern(0, 0, [
        "....oo.....",
        ".o..mo..o..",
        "omoommoomo.",
        ".ommmmmmo..",
        "..mmo.omm..",
        "ommo...omo.",
        "..mmo.omm..",
        ".ommmmmmo..",
        "omoommoomo.",
        ".o..mo..o..",
        "....oo.....",
    ], {"o": "ink", "m": "mist"})
    gear = Canvas(11, 11)
    gear.pattern(0, 0, [
        "....ooo....",
        ".oo.omo.oo.",
        ".ommmmmmmo.",
        ".omiioimmo.",
        "ooio...omoo",
        "omio...ommo",
        "ooio...omoo",
        ".ommoooimo.",
        ".ommmmmmmo.",
        ".oo.omo.oo.",
        "....ooo....",
    ], {"o": "ink", "m": "mist", "i": "ivory"})
    gear.save(f"{ICONS}/icon_gear.png")
    close = Canvas(7, 7)
    close.pattern(0, 0, [
        "mm...mm",
        "mmm.mmm",
        ".mmmmm.",
        "..mmm..",
        ".mmmmm.",
        "mmm.mmm",
        "mm...mm",
    ], {"m": "mist"})
    close.save(f"{ICONS}/icon_close.png")
    # 외부 베팅 아이콘 7×7: 빨강·검정 다이아몬드, 홀(점 1개)·짝(점 2개)
    for name, fill, hi, out in [("icon_red", "red_l", "red_hl", "red_d"), ("icon_black", "pocket_k_l", "stone", "void")]:
        d = Canvas(7, 9)
        d.pattern(0, 0, [
            "...o...",
            "..ofo..",
            ".ohffo.",
            "ohfffffo"[:7],
            "offffffo"[:7],
            ".offfo.",
            "..ofo..",
            "...o...",
            ".......",
        ], {"o": out, "f": fill, "h": hi})
        d.save(f"{ICONS}/{name}.png")
    odd = Canvas(7, 7)
    odd.pattern(0, 0, [
        ".ooooo.",
        "o.....o",
        "o..g..o",
        "o.ggg.o",
        "o..g..o",
        "o.....o",
        ".ooooo.",
    ], {"o": "mist", "g": "gold_hl"})
    odd.save(f"{ICONS}/icon_odd.png")
    even = Canvas(7, 7)
    even.pattern(0, 0, [
        ".ooooo.",
        "o.....o",
        "o.g.g.o",
        "oggggg" + "o",
        "o.g.g.o",
        "o.....o",
        ".ooooo.",
    ], {"o": "mist", "g": "gold_hl"})
    even = Canvas(7, 7)
    even.pattern(0, 0, [
        ".ooooo.",
        "o.....o",
        "o.g.g.o",
        "o.....o",
        "o.g.g.o",
        "o.....o",
        ".ooooo.",
    ], {"o": "mist", "g": "gold_hl"})
    even.save(f"{ICONS}/icon_even.png")
    # 금고(복귀 팝업: 딜러 루시 초상화가 아직 없을 때의 자리, 4단계)
    vault = Canvas(16, 16)
    bevel_box(vault, 0, 0, 16, 16, "wood_d", "ink", "stone", "void")
    rivets(vault, 2)
    vault.pattern(6, 6, [
        "oyo",
        "ygy",
        "oyo",
    ], {"o": "gold_d", "y": "gold_l", "g": "gold_hl"})
    for x, y in [(8, 4), (8, 11), (4, 8), (11, 8)]:
        vault.px(x, y, "gold")
    vault.save(f"{ICONS}/icon_vault.png")
    # 경고(저장 손상 복구 토스트, 4단계)
    warn = Canvas(9, 9)
    warn.pattern(0, 0, [
        "....o....",
        "...ooo...",
        "..oaaao..",
        ".oa.k.ao.",
        ".oa.k.ao.",
        ".oa.k.ao.",
        ".oa...ao.",
        ".oa.k.ao.",
        "..ooooo..",
    ], {"o": "red_d", "a": "amber", "k": "void"})
    warn.save(f"{ICONS}/icon_warning.png")


def marble_template() -> None:
    """7×7 구슬. 나무 구슬 색으로 그린다. 게임은 wood_d/wood/wood_l/wood_hl/ivory 를
    구슬 팔레트(outline/shadow/base/light/shine)로 바꿔 쓴다."""
    c = Canvas(7, 7)
    c.pattern(0, 0, [
        "..ooo..",
        ".oLLBo.",
        "oLSLBBo",
        "oLLBBDo",
        "oBBBDDo",
        ".oBDDo.",
        "..ooo..",
    ], {"o": "wood_d", "S": "ivory", "L": "wood_hl", "B": "wood_l", "D": "wood"})
    c.save(f"{ICONS}/marble.png")


def token(name: str, size: int, rim: str, body: str, hi: str, lo: str, ring: str | None = None) -> None:
    """색 원형 토큰. 좌상단 하이라이트, 우하단 그림자(셀 셰이딩). ring 이 있으면 금 테."""
    c = Canvas(size, size)
    r = size / 2
    ring_w = 2.3 if ring else 0.0
    for y in range(size):
        for x in range(size):
            dx = x + 0.5 - r
            dy = y + 0.5 - r
            d = math.hypot(dx, dy)
            if d > r:
                continue
            light = -(dx + dy) / (max(d, 0.01) * 1.4142)
            if d > r - 1.0:
                c.px(x, y, "gold_d" if ring else rim)
            elif ring and d > r - 1.0 - ring_w:
                c.px(x, y, "gold_hl" if light > 0.35 else ("gold" if light < -0.35 else "gold_l"))
            elif ring and d > r - 2.0 - ring_w:
                c.px(x, y, rim)
            else:
                inner = r - (2.0 + ring_w if ring else 1.0)
                if d > inner - 1.0 and light > 0.3:
                    c.px(x, y, hi)
                elif d > inner - 1.0 and light < -0.3:
                    c.px(x, y, lo)
                else:
                    c.px(x, y, body)
    c.save(f"{ICONS}/{name}.png")


def tokens() -> None:
    specs = {
        "red": ("red_d", "red_l", "red_hl", "red"),
        "black": ("ink", "pocket_k_l", "stone", "pocket_k"),
        "green": ("felt_d", "felt_l", "felt_hl", "felt"),
        "gold": ("gold_d", "gold_l", "gold_hl", "gold"),
    }
    for color, (rim, body, hi, lo) in specs.items():
        token(f"token_{color}", 11, rim, body, hi, lo)
        token(f"badge_{color}", 27, rim, body, hi, lo, ring="gold_hl")
        token(f"badge_pop_{color}", 33, rim, body, hi, lo, ring="gold_hl")


def particles() -> None:
    p2 = Canvas(2, 2)
    p2.pattern(0, 0, ["hg", "gd"], {"h": "gold_shine", "g": "gold_hl", "d": "gold_l"})
    p2.save(f"{ICONS}/particle_chip2.png")
    p3 = Canvas(3, 3)
    p3.pattern(0, 0, ["hgg", "ggl", "gld"], {"h": "gold_shine", "g": "gold_hl", "l": "gold_l", "d": "gold"})
    p3.save(f"{ICONS}/particle_chip3.png")
    # 코인 4프레임(회전) 7×7 → 28×7
    coin = Canvas(28, 7)
    frames = [
        [".ooo..." , "ohhgo..", "ohggo..", "oggdo..", "ogddo..", ".ooo...", "......."],
    ]
    frames = [
        ["..ooo..", ".ohhgo.", "ohgggdo", "ohgsgdo", "oggggdo", ".ogddo.", "..ooo.."],
        ["...o...", "..ohg..", "..ogg..", "..ogs..", "..ogd..", "..ogd..", "...o..."],
        ["...o...", "...o...", "...o...", "...o...", "...o...", "...o...", "...o..."],
        ["...o...", "..ghd..", "..ggd..", "..sgd..", "..ggd..", "..gdd..", "...o..."],
    ]
    for i, f in enumerate(frames):
        coin.pattern(i * 7, 0, f, {"o": "gold_d", "h": "gold_shine", "g": "gold_hl", "s": "gold_shine", "d": "gold"})
    coin.save(f"{ICONS}/coin.png")
    clover_p = Canvas(3, 3)
    clover_p.pattern(0, 0, [".c.", "cCc", ".c."], {"c": "clover", "C": "clover_d"})
    clover_p.save(f"{ICONS}/particle_clover.png")


def felt_panel() -> None:
    """베팅창 바탕 216×328: felt 에 미세한 노이즈, 금색 선 테두리."""
    w, h = 216, 328
    c = Canvas(w, h, "felt")
    rnd = seeded(7)
    for y in range(h):
        for x in range(w):
            v = rnd.random()
            if v < 0.06:
                c.px(x, y, "felt_d")
            elif v < 0.085:
                c.px(x, y, "felt_l")
    # 테두리: void 외곽선, 나무 테(3px), 금색 선
    c.outline_rect(0, 0, w, h, "void")
    for i, col in enumerate(["wood_d", "wood", "wood_l"]):
        c.outline_rect(1 + i, 1 + i, w - 2 - 2 * i, h - 2 - 2 * i, col)
    c.hline(2, w - 3, 2, "wood_hl")
    c.vline(2, 2, h - 3, "wood_hl")
    c.outline_rect(4, 4, w - 8, h - 8, "wood_d")
    c.outline_rect(6, 6, w - 12, h - 12, "gold")
    c.hline(6, w - 7, 6, "gold_l")
    c.vline(6, 6, h - 7, "gold_l")
    rivets(c, 2)
    c.save(f"{UI}/panel_felt.png")


PAL = {}


def main() -> None:
    from pixlib import PALETTE
    PAL.update(PALETTE)
    panel("panel_dark", "night", "dusk", "void")
    panel("panel_plain", "night", "dusk", "void", trim=None)
    panel("panel_bar", "dusk", "shadow", "night", trim=None)
    plain_frame("frame_inset", "void", "night", "void")
    plain_frame("frame_cell", "felt", "felt_d", "felt_l")
    button_set(
        "button",
        ("wood_d", "wood_l", "wood_hl", "wood"),
        ("wood_d", "wood_hl", "gold_l", "wood_l", False, "gold_hl"),
        ("wood_d", "wood", "wood_l", "wood_d"),
        ("void", "ink", "stone", "shadow"),
    )
    button_set(
        "button_gold",
        ("gold_d", "gold", "gold_l", "gold_d"),
        ("gold_d", "gold_l", "gold_hl", "gold", False, "gold_shine"),
        ("gold_d", "gold_d", "gold", "wood_d"),
        ("void", "ink", "stone", "shadow"),
    )
    button_set(
        "button_dark",
        ("void", "dusk", "shadow", "night"),
        ("void", "shadow", "stone", "dusk", False, "mist"),
        ("void", "night", "dusk", "void"),
        ("void", "night", "dusk", "void"),
    )
    button_set(
        "button_stone",
        ("void", "ink", "stone", "shadow"),
        ("void", "stone", "mist", "ink", False, "mist"),
        ("void", "shadow", "ink", "void"),
        ("void", "night", "dusk", "void"),
    )
    tab("tab_normal", "void", "dusk", "shadow", None)
    tab("tab_hover", "void", "shadow", "stone", None)
    tab("tab_selected", "gold_d", "wood", "wood_l", "gold_l")
    spin_button()
    tooltip()
    scrollbar()
    slider()
    checkbox()
    chip_icon()
    sparkle_frames()
    clover_icon()
    small_icons()
    marble_template()
    tokens()
    particles()
    felt_panel()
    print("ui ok")


if __name__ == "__main__":
    main()
