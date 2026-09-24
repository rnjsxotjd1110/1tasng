"""룰렛 휠의 고정 레이어를 만든다(회전 링·터렛·공은 게임이 _draw() 로 그린다).

  python3 tools/art/gen_wheel.py

모든 텍스처는 240×240, 휠 중심이 텍스처 (120, 120) (픽셀 경계)에 온다.
게임은 텍스처 좌상단을 휠 중심 - (120, 120) 에 놓는다. 반지름 규격은 ART_BIBLE 2장.
  wheel_shadow.png    드롭 섀도(타원, 알파)
  wheel_base.png      바깥 림(118~104) + 공 트랙(104~90) + 디플렉터 8개(91) + 숫자 링 바탕(90~76) + 포켓 자리(76 안쪽)
  wheel_top.png       포켓 경계 금선(76, 60) + 중앙 콘(60 안쪽) + 허브. 회전 링 위에 덮는다.
  wheel_highlight.png 좌상단 곡선 반사광(알파). 회전하지 않는다.
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, band_pick, dither_pick, polar  # noqa: E402

SIZE = 240
C = 120.0
OUT = "assets/sprites/wheel"
LIGHT = math.radians(225.0)  # 좌상단 광원(화면 각도)

R_RIM_OUT = 118
R_RIM_IN = 104
R_TRACK_IN = 90
R_DEFLECTOR = 91
R_NUMBERS_IN = 76
R_POCKETS_IN = 60
DEFLECTOR_COUNT = 8
DEFLECTOR_OFFSET_DEG = 22.5
BOLT_COUNT = 8
R_BOLT = 111


def lightness(theta: float) -> float:
    """-1(광원 반대) ~ 1(광원 쪽)."""
    return math.cos(theta - LIGHT)


def wood_grain(r: float, theta: float) -> float:
    """원둘레를 따라 흐르는 나뭇결 잡음(-1..1)."""
    return (math.sin(r * 2.1 + math.sin(theta * 3.0) * 1.7 + math.sin(theta * 11.0) * 0.4) * 0.6
            + math.sin(r * 5.3 + theta * 2.0) * 0.4)


def shadow() -> None:
    c = Canvas(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            dx = (x + 0.5 - C) / 118.0
            dy = (y + 0.5 - C) / 116.0
            d = math.hypot(dx, dy)
            if d <= 1.0:
                c.px(x, y, "void", 150)
            elif d <= 1.03:
                if (x + y) % 2 == 0:
                    c.px(x, y, "void", 90)
    c.save(f"{OUT}/wheel_shadow.png")


def base() -> None:
    c = Canvas(SIZE, SIZE)
    rr, th = polar(SIZE, SIZE, C, C)
    for y in range(SIZE):
        for x in range(SIZE):
            r = rr[y, x]
            t = th[y, x]
            L = lightness(t)
            if r > R_RIM_OUT:
                continue
            if r > R_RIM_OUT - 1:
                c.px(x, y, "wood_d")
            elif r > R_RIM_OUT - 2:
                c.px(x, y, "gold_hl" if L > 0.5 else ("gold_l" if L > -0.3 else "gold"))
            elif r > R_RIM_OUT - 3:
                c.px(x, y, "gold_d")
            elif r > R_RIM_IN + 3:
                # 나무 림: 광원 방향 + 나뭇결
                v = 0.5 + 0.32 * L + 0.14 * wood_grain(r, t)
                # 림 단면: 바깥쪽이 둥글게 밝음
                v += 0.1 * math.sin((r - (R_RIM_IN + 3)) / (R_RIM_OUT - R_RIM_IN - 6) * math.pi)
                c.px(x, y, band_pick(v, ["wood_d", "wood", "wood_l", "wood_hl"]))
            elif r > R_RIM_IN + 2:
                c.px(x, y, "gold_d")
            elif r > R_RIM_IN + 1:
                c.px(x, y, "gold_l" if L > 0.0 else "gold")
            elif r > R_RIM_IN:
                c.px(x, y, "wood_d")
            elif r > R_TRACK_IN + 1:
                # 공 트랙: 어두운 매끈한 나무, 바깥 벽 쪽이 그늘, 광원 쪽이 은은히 밝음(디더링)
                depth = (r - R_TRACK_IN) / (R_RIM_IN - R_TRACK_IN)  # 0 안쪽 … 1 바깥
                v = 0.55 + 0.35 * L * (1.0 - depth) - 0.45 * max(0.0, depth - 0.7) / 0.3
                # 광원 반대쪽 벽 그림자(바깥 벽이 트랙에 드리운다)
                v -= 0.25 * max(0.0, -L) * depth
                c.px(x, y, dither_pick(v * 0.8, x, y, ["void", "pocket_k", "wood_d", "wood"]))
            elif r > R_TRACK_IN:
                c.px(x, y, "gold_d")
            elif r > R_NUMBERS_IN:
                c.px(x, y, "wood_d")
            else:
                c.px(x, y, "pocket_k")
    # 볼트 8개(4×4 둥근 금 볼트)
    for i in range(BOLT_COUNT):
        a = math.radians(i * 360.0 / BOLT_COUNT)
        bx = int(round(C + R_BOLT * math.cos(a))) - 2
        by = int(round(C + R_BOLT * math.sin(a))) - 2
        c.pattern(bx, by, [
            ".dd.",
            "dhld",
            "dlgd",
            ".dd.",
        ], {"d": "gold_d", "h": "gold_shine", "l": "gold_hl", "g": "gold"})
    # 디플렉터 8개: 원둘레 방향으로 긴 금 다이아몬드(7×3 정도), 1px 하이라이트
    for i in range(DEFLECTOR_COUNT):
        a = math.radians(DEFLECTOR_OFFSET_DEG + i * 360.0 / DEFLECTOR_COUNT)
        tangent = (-math.sin(a), math.cos(a))
        normal = (math.cos(a), math.sin(a))
        px0 = C + R_DEFLECTOR * math.cos(a)
        py0 = C + R_DEFLECTOR * math.sin(a)
        L = lightness(a + math.pi)  # 디플렉터 윗면은 휠 바깥을 향하지 않음 → 반대 방향 조명
        for y in range(int(py0) - 6, int(py0) + 7):
            for x in range(int(px0) - 6, int(px0) + 7):
                dx = x + 0.5 - px0
                dy = y + 0.5 - py0
                u = dx * tangent[0] + dy * tangent[1]
                v = dx * normal[0] + dy * normal[1]
                m = abs(u) / 5.2 + abs(v) / 2.6
                if m <= 1.0:
                    if m > 0.75:
                        c.px(x, y, "gold_d")
                    else:
                        # 좌상단 면이 밝게
                        side = -(dx + dy)
                        c.px(x, y, "gold_hl" if side > 0.6 else ("gold_l" if side > -0.6 else "gold"))
        hx = int(math.floor(px0 - 0.6))
        hy = int(math.floor(py0 - 0.6))
        c.px(hx, hy, "gold_shine")
        del L
    c.save(f"{OUT}/wheel_base.png")


def top() -> None:
    c = Canvas(SIZE, SIZE)
    rr, th = polar(SIZE, SIZE, C, C)
    for y in range(SIZE):
        for x in range(SIZE):
            r = rr[y, x]
            t = th[y, x]
            L = lightness(t)
            if r > R_NUMBERS_IN + 1:
                continue
            if r > R_NUMBERS_IN:
                c.px(x, y, "gold_hl" if L > 0.45 else ("gold_l" if L > -0.45 else "gold"))
            elif r > R_NUMBERS_IN - 0.9:
                c.px(x, y, "gold_d")
            elif r > R_POCKETS_IN + 0.5:
                continue  # 포켓(회전 링)이 보이는 자리
            elif r > R_POCKETS_IN - 0.5:
                c.px(x, y, "gold_d")
            elif r > R_POCKETS_IN - 1.5:
                c.px(x, y, "gold_l" if L < -0.3 else ("gold" if L < 0.4 else "gold_d"))
            elif r > 42:
                # 나무 콘: 바깥이 낮고 안쪽이 높다 → 표면이 바깥을 향함. 광원 쪽 면이 밝다.
                slope = (r - 42) / (R_POCKETS_IN - 1.5 - 42)
                v = 0.5 + 0.42 * L - 0.1 * slope + 0.08 * math.sin(t * 24.0 + r * 0.2) * 0.0
                c.px(x, y, band_pick(v, ["wood_d", "wood", "wood_l", "wood_hl"]))
            elif r > 40:
                c.px(x, y, "gold_hl" if L > 0.5 else ("gold_l" if L > -0.2 else ("gold" if L > -0.7 else "gold_d")))
            elif r > 39:
                c.px(x, y, "wood_d")
            elif r > 9:
                slope = (r - 9) / 30.0
                v = 0.45 + 0.38 * L + 0.12 * (1 - slope)
                c.px(x, y, band_pick(v, ["wood_d", "wood", "wood_l"]))
            elif r > 8:
                c.px(x, y, "gold_d")
            else:
                # 허브: 금 돔
                hx = (x + 0.5 - C) / 8.0
                hy = (y + 0.5 - C) / 8.0
                v = 0.55 - 0.45 * (hx + hy) / 1.4 - 0.25 * (hx * hx + hy * hy)
                c.px(x, y, band_pick(v, ["gold_d", "gold", "gold_l", "gold_hl"]))
    # 허브 스페큘러
    c.px(int(C) - 3, int(C) - 3, "gold_shine")
    c.px(int(C) - 2, int(C) - 3, "gold_shine")
    c.px(int(C) - 3, int(C) - 2, "gold_shine")
    c.save(f"{OUT}/wheel_top.png")


def highlight() -> None:
    """좌상단 곡선 반사광. ivory 알파만 쓴다."""
    c = Canvas(SIZE, SIZE)
    rr, th = polar(SIZE, SIZE, C, C)
    center = math.radians(222.0)
    for y in range(SIZE):
        for x in range(SIZE):
            r = rr[y, x]
            t = th[y, x]
            da = math.atan2(math.sin(t - center), math.cos(t - center))
            # 포켓 위 반사: 반지름 67~72, 각도 ±38도, 가장자리로 갈수록 얇게
            span = 1.0 - abs(da) / math.radians(38.0)
            if span > 0:
                mid = 70.0
                half = 0.6 + 2.2 * span
                if abs(r - mid) <= half:
                    c.px(x, y, "ivory", int(24 + 46 * span))
            # 숫자 링 위 얇은 반사
            span2 = 1.0 - abs(da) / math.radians(24.0)
            if span2 > 0 and abs(r - 86.5) <= 0.5 + 0.8 * span2:
                c.px(x, y, "ivory", int(18 + 30 * span2))
            # 콘 위 넓고 흐린 반사
            span3 = 1.0 - abs(da) / math.radians(30.0)
            if span3 > 0 and abs(r - 50.0) <= 1.0 + 3.0 * span3:
                c.px(x, y, "ivory", int(10 + 22 * span3))
            # 림 금선 위 강한 점 반사
            span4 = 1.0 - abs(da) / math.radians(14.0)
            if span4 > 0 and abs(r - 112.0) <= 0.5 + 1.5 * span4:
                c.px(x, y, "ivory", int(20 + 50 * span4))
    c.save(f"{OUT}/wheel_highlight.png")


def hub_and_knob() -> None:
    """허브 16×16(터렛 팔 위에 덮음, 휠 중심에 정확히 맞도록 짝수), 손잡이 끝 구슬 5×5.
    둘 다 둥글어 회전하지 않아도 된다."""
    hub = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            dx = (x + 0.5 - 8.0) / 8.0
            dy = (y + 0.5 - 8.0) / 8.0
            d = math.hypot(dx, dy)
            if d > 1.0:
                continue
            if d > 0.86:
                hub.px(x, y, "gold_d")
            else:
                v = 0.55 - 0.45 * (dx + dy) / 1.4 - 0.2 * d * d
                hub.px(x, y, band_pick(v, ["gold", "gold_l", "gold_hl", "gold_shine"]))
    hub.px(4, 4, "ivory")
    hub.px(5, 4, "gold_shine")
    hub.save(f"{OUT}/wheel_hub.png")
    knob = Canvas(5, 5)
    knob.pattern(0, 0, [
        ".ddd.",
        "dhlgd",
        "dlggd",
        "dggdd",
        ".ddd.",
    ], {"d": "gold_d", "h": "gold_shine", "l": "gold_hl", "g": "gold_l"})
    knob.save(f"{OUT}/wheel_knob.png")


def main() -> None:
    hub_and_knob()
    shadow()
    base()
    top()
    highlight()
    print("wheel ok")


if __name__ == "__main__":
    main()
