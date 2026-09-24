"""3단계 에셋: 구슬 템플릿(10·24px), 업그레이드 아이콘 16×16 6종(+실루엣), 카드 프레임, MAX 스탬프, 알림 점,
구매 버튼(stone 톤), 황금 포켓 빛줄기, GOLDEN 배지.

  python3 tools/art/gen_upgrades.py

구슬 템플릿은 나무 구슬 5색(wood_d/wood/wood_l/wood_hl/ivory = outline/shadow/base/light/shine 인덱스)으로 그린다.
게임은 assets/shaders/marble.gdshader 가 이 인덱스를 구슬 재질 5색으로 바꾸고 재질별 표면 디테일을 얹는다.
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, fill_polygon  # noqa: E402

UI = "assets/ui"
ICONS = "assets/sprites/ui"
UPGRADE_ICONS = "assets/sprites/ui/upgrades"
MARBLES = "assets/sprites/marbles"

IDX = ["wood_d", "wood", "wood_l", "wood_hl", "ivory"]  # outline, shadow, base, light, shine


# ── 구슬 템플릿 ──────────────────────────────────────────

MARBLE_10 = [
    "...oooo...",
    ".ooLLBBoo.",
    ".oLSSLBBo.",
    "oLLSLBBBDo",
    "oLLLBBBBDo",
    "oLBBBBBDDo",
    "oBBBBBDDDo",
    ".oBBBDDDo.",
    ".ooDDDDoo.",
    "...oooo...",
]


def marble_10() -> None:
    c = Canvas(10, 10)
    c.pattern(0, 0, MARBLE_10, {"o": IDX[0], "D": IDX[1], "B": IDX[2], "L": IDX[3], "S": IDX[4]})
    c.save(f"{MARBLES}/marble_10.png")


def marble_24() -> None:
    """24px 구. 좌상단 광원 셀 셰이딩 4단계 + 우하단 반사광 1줄 + 좌상단 광택 점."""
    size = 24
    c = Canvas(size, size)
    cx = cy = size / 2
    radius = 11.7
    light = np.array([-0.55, -0.62, 0.56])
    light /= np.linalg.norm(light)
    inside = np.zeros((size, size), dtype=bool)
    for y in range(size):
        for x in range(size):
            dx = (x + 0.5 - cx) / radius
            dy = (y + 0.5 - cy) / radius
            inside[y, x] = dx * dx + dy * dy <= 1.0
    for y in range(size):
        for x in range(size):
            if not inside[y, x]:
                continue
            dx = (x + 0.5 - cx) / radius
            dy = (y + 0.5 - cy) / radius
            dz = math.sqrt(max(0.0, 1.0 - dx * dx - dy * dy))
            lam = dx * light[0] + dy * light[1] + dz * light[2]
            edge = any(not (0 <= x + ox < size and 0 <= y + oy < size and inside[y + oy, x + ox])
                       for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                name = IDX[0]
            elif lam > 0.72:
                name = IDX[3]
            elif lam > 0.28:
                name = IDX[2]
            else:
                name = IDX[1]
            c.px(x, y, name)
    # 우하단 반사광: 외곽선 바로 안쪽 그림자 줄을 base 로
    for y in range(size):
        for x in range(size):
            if c.get(x, y)[:3] != tuple(int(IDX_RGB[1][i]) for i in range(3)):
                continue
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r > radius - 2.2 and dx + dy > 6.0:
                c.px(x, y, IDX[2])
    # 광택 점(shine): 좌상단 작은 덩어리 + 옆 1px
    for x, y in [(7, 6), (8, 6), (7, 7), (10, 5)]:
        c.px(x, y, IDX[4])
    c.save(f"{MARBLES}/marble_24.png")


# ── 업그레이드 아이콘 16×16 ──────────────────────────────

def disc(c: Canvas, cx: float, cy: float, r: float, ramp: list[str], outline: str) -> None:
    """좌상단 광원 작은 구. ramp = [shadow, base, light, shine]."""
    pts = []
    for y in range(c.h):
        for x in range(c.w):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            if dx * dx + dy * dy <= r * r:
                pts.append((x, y, dx / r, dy / r))
    inside = {(x, y) for x, y, _, _ in pts}
    for x, y, nx, ny in pts:
        edge = any((x + ox, y + oy) not in inside for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            c.px(x, y, outline)
            continue
        lam = -0.6 * nx - 0.7 * ny + 0.4
        c.px(x, y, ramp[2] if lam > 0.55 else ramp[1] if lam > -0.05 else ramp[0])
    # 광택
    sx, sy = int(cx - r * 0.45), int(cy - r * 0.5)
    c.px(sx, sy, ramp[3])


UP_ARROW = [
    "...o...",
    "..oco..",
    ".occco.",
    "occccco",
    "oooCooo",
    "..oCo..",
    "..ooo..",
]


def up_arrow(c: Canvas, x: int, y: int) -> None:
    c.pattern(x, y, UP_ARROW, {"o": "felt_d", "c": "clover", "C": "clover_d"})


def icon_marble_tier() -> Canvas:
    c = Canvas(16, 16)
    # 뒤: 작은 돌 구슬, 앞: 금 구슬 + 위 화살표
    disc(c, 4.5, 11.5, 3.6, ["ink", "stone", "mist", "ivory"], "shadow")
    disc(c, 10.0, 9.5, 5.6, ["gold", "gold_l", "gold_hl", "gold_shine"], "gold_d")
    up_arrow(c, 0, 0)
    return c


def icon_marble_polish() -> Canvas:
    c = Canvas(16, 16)
    disc(c, 7.0, 9.0, 6.0, ["stone", "mist", "ivory", "ivory"], "ink")
    # 반사 줄 2개
    for i in range(3):
        c.px(4 + i, 8 - i, "ivory")
    c.px(5, 10, "ivory")
    c.px(6, 9, "ivory")
    # 오른쪽 위 4방향 반짝임
    c.pattern(10, 0, [
        "..s..",
        "..s..",
        "sswss",
        "..s..",
        "..s..",
    ], {"s": "gold_hl", "w": "gold_shine"})
    c.px(14, 6, "gold_l")
    c.px(15, 7, "gold_hl")
    return c


COIN = [
    ".oHHHHHHo.",
    "oHLLLLLLHo",
    "oDBrBBrBDo",
    ".oooooooo.",
]


def icon_bet_limit() -> Canvas:
    c = Canvas(16, 16)
    # 칩 더미 4개(아래부터 위로 3px 씩)
    for i, y in enumerate([12, 9, 6, 3]):
        c.pattern(0, y, COIN, {"o": "gold_d", "H": "gold_hl", "L": "gold_l", "B": "gold", "D": "gold_d", "r": "red_l"})
    c.pattern(0, 3, [".oHHHHHHo.", "oHLLSLLLHo"], {"o": "gold_d", "H": "gold_hl", "L": "gold_l", "S": "gold_shine"})
    up_arrow(c, 9, 0)
    return c


def icon_marble_count() -> Canvas:
    c = Canvas(16, 16)
    disc(c, 8.0, 4.8, 4.2, ["wood", "wood_l", "wood_hl", "ivory"], "wood_d")
    disc(c, 4.2, 11.2, 4.2, ["ink", "stone", "mist", "ivory"], "shadow")
    disc(c, 11.8, 11.2, 4.2, ["wood_l", "wood_hl", "amber", "gold_shine"], "wood_d")
    return c


def icon_spin_speed() -> Canvas:
    c = Canvas(16, 16)
    cx, cy, r = 9.5, 8.0, 6.3
    for y in range(16):
        for x in range(16):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            if d > r - 1.2:
                c.px(x, y, "wood_d")
            elif d > r - 2.2:
                c.px(x, y, "wood_l" if dx + dy < 0 else "wood")
            elif d > 2.2:
                seg = int((math.atan2(dy, dx) + math.pi) / (2 * math.pi) * 8) % 2
                c.px(x, y, "red_l" if seg == 0 else "pocket_k_l")
            else:
                c.px(x, y, "gold_l")
    c.px(9, 7, "gold_hl")
    # 속도선
    for y, x0, x1 in [(4, 0, 3), (8, 0, 2), (12, 0, 3)]:
        c.hline(x0, x1, y, "neon_cyan")
    c.px(1, 6, "mist")
    c.px(1, 10, "mist")
    return c


def icon_golden_pocket() -> Canvas:
    c = Canvas(16, 16)
    # 휠 테두리 조각: 빨강 | 금 | 검정 포켓 3칸(바깥 호가 위)
    cx, cy = 8.0, 22.0
    r_out, r_in = 19.5, 11.5
    for y in range(16):
        for x in range(16):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r > r_out or r < r_in:
                continue
            a = math.degrees(math.atan2(dx, -dy))
            if abs(a) > 42:
                continue
            if r > r_out - 1.0 or r < r_in + 1.0 or abs(a) > 40.5:
                c.px(x, y, "wood_d")
                continue
            if abs(abs(a) - 12.0) < 1.5:
                c.px(x, y, "gold_d")
                continue
            if a < -12.0:
                c.px(x, y, "red_l" if r > r_in + 3 else "red")
            elif a > 12.0:
                c.px(x, y, "pocket_k_l" if r > r_in + 3 else "pocket_k")
            else:
                c.px(x, y, "gold_hl" if r > r_out - 3 else "gold_l" if r > r_in + 2.5 else "gold")
    # 금 포켓 안의 구슬
    disc(c, 8.0, 7.0, 2.6, ["gold", "gold_hl", "gold_shine", "ivory"], "gold_d")
    # 반짝임
    c.pattern(11, 0, [
        ".w.",
        "wsw",
        ".w.",
    ], {"w": "gold_hl", "s": "ivory"})
    c.px(3, 1, "gold_shine")
    return c


def silhouette(c: Canvas) -> Canvas:
    out = Canvas(c.w, c.h)
    m = c.mask()
    out.a[m, :3] = [int(v) for v in bytes.fromhex("3e3a4f")]
    out.a[m, 3] = 255
    # 테두리는 한 톤 어둡게
    padded = np.pad(m, 1)
    edge = m & ~(padded[:-2, 1:-1] & padded[2:, 1:-1] & padded[1:-1, :-2] & padded[1:-1, 2:])
    out.a[edge, :3] = [int(v) for v in bytes.fromhex("2f2a52")]
    return out


ICON_BUILDERS = {
    "marble_tier": icon_marble_tier,
    "marble_polish": icon_marble_polish,
    "bet_limit": icon_bet_limit,
    "marble_count": icon_marble_count,
    "spin_speed": icon_spin_speed,
    "golden_pocket": icon_golden_pocket,
}


def upgrade_icons() -> None:
    for name, builder in ICON_BUILDERS.items():
        icon = builder()
        icon.save(f"{UPGRADE_ICONS}/icon_{name}.png")
        silhouette(icon).save(f"{UPGRADE_ICONS}/icon_{name}_locked.png")


# ── 카드·버튼·기타 UI ────────────────────────────────────

def card_frame(name: str, outline: str, body: str, hi: str, lo: str, trim: str, trim_hi: str) -> None:
    """카드 배경 12×12, 9-슬라이스 여백 4. 외곽선 → 테(trim, 위·왼쪽 trim_hi) → 몸통(위 1줄 hi, 아래 1줄 lo)."""
    c = Canvas(12, 12)
    c.rect(1, 0, 10, 12, outline)
    c.rect(0, 1, 12, 10, outline)
    c.rect(1, 1, 10, 10, trim)
    c.hline(2, 9, 1, trim_hi)
    c.vline(1, 2, 9, trim_hi)
    c.rect(2, 2, 8, 8, body)
    c.hline(2, 9, 2, hi)
    c.hline(2, 9, 9, lo)
    c.save(f"{UI}/{name}.png")


def cards() -> None:
    card_frame("card_normal", "void", "night", "dusk", "void", "ink", "shadow")
    card_frame("card_hover", "void", "dusk", "shadow", "night", "stone", "mist")
    card_frame("card_ready", "void", "night", "dusk", "void", "gold_d", "gold")
    card_frame("card_max", "gold_d", "dusk", "shadow", "night", "gold_l", "gold_hl")
    card_frame("card_locked", "void", "void", "night", "void", "night", "dusk")
    card_frame("card_marble", "void", "purple_d", "neon_purple", "night", "gold_d", "gold_l")
    # 아이콘 칸(움푹): 20×20, 9-슬라이스 3
    c = Canvas(8, 8)
    c.rect(0, 0, 8, 8, "void")
    c.rect(1, 1, 6, 6, "night")
    c.hline(1, 6, 6, "dusk")
    c.vline(6, 1, 6, "dusk")
    c.save(f"{UI}/card_slot.png")


def max_stamp() -> None:
    """MAX 스탬프 30×14: 금 테두리, 빨간 바탕, 흰 글자(3×5 굵게), 살짝 닳은 모서리."""
    c = Canvas(30, 14)
    c.rect(1, 0, 28, 14, "gold_d")
    c.rect(0, 1, 30, 12, "gold_d")
    c.rect(1, 1, 28, 12, "gold_hl")
    c.rect(2, 2, 26, 10, "red_d")
    c.rect(3, 3, 24, 8, "red")
    c.hline(3, 26, 3, "red_l")
    letters = {
        "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
        "A": [".###.", "#...#", "#####", "#...#", "#...#"],
        "X": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    }
    x = 5
    for ch in "MAX":
        rows = letters[ch]
        for dy, row in enumerate(rows):
            for dx, v in enumerate(row):
                if v == "#":
                    c.px(x + dx, 5 + dy, "gold_shine")
                    c.px(x + dx, 6 + dy, "red_d") if not (dy + 1 < 5 and rows[dy + 1][dx] == "#") else None
        x += 7
    # 닳은 자국
    for px, py in [(4, 10), (20, 3), (25, 9)]:
        c.px(px, py, "red_l")
    c.save(f"{ICONS}/stamp_max.png")


def notify_dot() -> None:
    c = Canvas(5, 5)
    c.pattern(0, 0, [
        ".ooo.",
        "ohro.",
        "orrro",
        "orrdo",
        ".ooo.",
    ], {"o": "red_d", "h": "red_hl", "r": "red_l", "d": "red"})
    c.px(4, 1, "red_d")
    c.save(f"{ICONS}/notify_dot.png")


def arrow() -> None:
    """효과 변화 사이 화살표 7×5(stone)."""
    c = Canvas(7, 5)
    c.pattern(0, 0, [
        "....o..",
        "....so.",
        "sssssso",
        "....so.",
        "....o..",
    ], {"s": "mist", "o": "ink"})
    c.save(f"{ICONS}/arrow_right.png")


def golden_beam() -> None:
    """황금 포켓 빛줄기 11×64(세로로 늘려 쓴다). 가운데가 가장 밝은 알파 띠."""
    c = Canvas(11, 64)
    cols = [(0, 60), (1, 110), (2, 170), (3, 220), (4, 255), (5, 255), (6, 255), (7, 220), (8, 170), (9, 110), (10, 60)]
    for x, alpha in cols:
        name = "gold_shine" if 3 <= x <= 7 else "gold_hl"
        for y in range(64):
            c.px(x, y, name, alpha)
    c.save(f"{ICONS}/golden_beam.png")


def golden_badge() -> None:
    """GOLDEN 배지 바탕 9-슬라이스 10×12(여백 4): 금 테, 어두운 금 몸통."""
    c = Canvas(10, 12)
    c.rect(1, 0, 8, 12, "gold_d")
    c.rect(0, 1, 10, 10, "gold_d")
    c.rect(1, 1, 8, 10, "gold_hl")
    c.rect(2, 2, 6, 8, "gold")
    c.hline(2, 7, 2, "gold_l")
    c.hline(2, 7, 9, "gold_d")
    c.save(f"{UI}/badge_golden.png")


def lock_big() -> None:
    """잠긴 카드용 자물쇠 9×11."""
    c = Canvas(9, 11)
    c.pattern(0, 0, [
        "..ooooo..",
        ".o.....o.",
        ".o.....o.",
        ".o.....o.",
        "ooooooooo",
        "oLLLLLLBo",
        "oLBBoBBBo",
        "oBBBoBBDo",
        "oBBBBBBDo",
        "oBDDDDDDo",
        "ooooooooo",
    ], {"o": "ink", "L": "mist", "B": "stone", "D": "shadow"})
    for x, y in [(2, 1), (3, 1), (4, 1), (5, 1), (6, 1)]:
        pass
    c.px(2, 1, "stone")
    c.px(6, 1, "stone")
    c.save(f"{ICONS}/icon_lock_big.png")


# 구슬 템플릿 색(IDX) RGB — 반사광 계산용
from pixlib import rgb  # noqa: E402

IDX_RGB = [rgb(n) for n in IDX]


def main() -> None:
    marble_10()
    marble_24()
    upgrade_icons()
    cards()
    max_stamp()
    notify_dot()
    arrow()
    golden_beam()
    golden_badge()
    lock_big()
    print("upgrades ok")


if __name__ == "__main__":
    main()
