"""마담 벨벳 캐릭터 시트 생성(7단계, ART_BIBLE 13장 예정).

  python3 tools/art/gen_velvet.py

출력(팔레트 36색):
  assets/sprites/npc/velvet_world.png     48×72 프레임, 4행(idle4 / wine3 / gesture4 / clap4)
  assets/sprites/npc/velvet_portrait.png  64×64 × 7(기본/웃음/교활함/놀람/만족 + 입벙긋 2)

은발 올림머리, 짙은 빨강(벨벳) 드레스, 진주 목걸이, 금 귀걸이. 펜트하우스의 주인답게
루시·남작보다 키가 크고 자세가 곧다. gen_lucy.py 와 같은 골격(타원 얼굴·선 그리기 헬퍼)을 재사용한다.
캐릭터는 오른쪽을 본다(왼쪽을 볼 때는 게임에서 좌우 반전).
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas  # noqa: E402

OUT = "assets/sprites/npc"
FRAME_W, FRAME_H = 48, 72
PORTRAIT = 64

SKIN = ["wood_d", "wood", "wood_l", "wood_hl"]  # outline, shadow, base, light
HAIR = ["ink", "stone", "mist"]  # outline, base, highlight(은발)
DRESS = ["red_d", "red", "red_l"]  # velvet 드레스
PEARL = "ivory"
GOLD = "gold_l"

WORLD_ANIMS: list[tuple[str, int]] = [("idle", 4), ("wine", 3), ("gesture", 4), ("clap", 4)]
MAX_COLS = max(n for _, n in WORLD_ANIMS)


def _ellipse(c: Canvas, cx: float, cy: float, rx: float, ry: float, name: str, alpha: int = 255) -> None:
    if rx <= 0 or ry <= 0:
        return
    y0, y1 = int(math.floor(cy - ry)), int(math.ceil(cy + ry))
    for y in range(y0, y1 + 1):
        dy = (y + 0.5 - cy) / ry
        if abs(dy) > 1.0:
            continue
        dx = rx * math.sqrt(max(0.0, 1.0 - dy * dy))
        c.hline(int(math.floor(cx - dx)), int(math.ceil(cx + dx)), y, name, alpha)


def _ellipse_arc_bottom(c: Canvas, cx: float, cy: float, rx: float, ry: float, name: str) -> None:
    y0 = int(math.floor(cy))
    y1 = int(math.ceil(cy + ry))
    for y in range(y0, y1 + 1):
        dy = (y + 0.5 - cy) / ry
        if abs(dy) > 1.0:
            continue
        dx = rx * math.sqrt(max(0.0, 1.0 - dy * dy))
        c.hline(int(math.floor(cx - dx)), int(math.ceil(cx + dx)), y, name)


def _line(c: Canvas, x0: float, y0: float, x1: float, y1: float, name: str, width: int = 1) -> None:
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(steps + 1):
        t = i / steps
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for wy in range(width):
            for wx in range(width):
                c.px(round(x + wx - width / 2.0), round(y + wy - width / 2.0), name)


def _hair_updo_back(c: Canvas, cx: float, cy: float, r: float) -> None:
    """정수리 뒤 올림머리 실루엣(얼굴을 그리기 전에 그려 얼굴이 앞을 덮게 한다)."""
    _ellipse(c, cx, cy - r * 0.1, r * 1.02, r * 1.0, HAIR[1])
    _ellipse_arc_bottom(c, cx, cy - r * 0.1, r * 1.02, r * 1.0, HAIR[0])
    # 정수리 위 둥근 번(쪽찐 머리)
    _ellipse(c, cx, cy - r * 1.25, r * 0.48, r * 0.4, HAIR[1])
    _ellipse_arc_bottom(c, cx, cy - r * 1.25, r * 0.48, r * 0.4, HAIR[0])
    c.px(round(cx - r * 0.15), round(cy - r * 1.4), HAIR[2])


def _hair_front(c: Canvas, cx: float, cy: float, r: float) -> None:
    """이마 옆으로 살짝 넘긴 잔머리만(정수리는 뒤로 넘겨 이목구비를 가리지 않는다)."""
    c.rect(round(cx - r * 1.02), round(cy - r * 0.05), round(r * 0.3), round(r * 0.9), HAIR[1])
    c.rect(round(cx + r * 0.75), round(cy - r * 0.05), round(r * 0.32), round(r * 0.9), HAIR[1])
    c.hline(round(cx - r * 1.02), round(cx - r * 0.72), round(cy + r * 0.78), HAIR[0])
    c.hline(round(cx + r * 0.75), round(cx + r * 1.1), round(cy + r * 0.78), HAIR[0])
    top = cy - r * 0.95
    c.hline(round(cx - r * 0.55), round(cx + r * 0.4), round(top), HAIR[1])
    c.px(round(cx - r * 0.2), round(top + 1), HAIR[2])


def _earring(c: Canvas, cx: float, cy: float, r: float) -> None:
    c.px(round(cx - r * 1.0), round(cy + r * 0.45), GOLD)
    c.px(round(cx + r * 1.0), round(cy + r * 0.45), GOLD)


def _velvet_head(c: Canvas, cx: float, cy: float, r: float, *, mouth: str, brow: str) -> None:
    _hair_updo_back(c, cx, cy, r)
    _ellipse(c, cx, cy, r * 0.8, r * 0.98, SKIN[2])
    _ellipse_arc_bottom(c, cx, cy + r * 0.22, r * 0.76, r * 0.68, SKIN[1])
    # 눈(살짝 치켜뜬 눈매)
    ex = r * 0.33
    ey = -r * 0.05
    for side in (-1, 1):
        _ellipse(c, cx + side * ex, cy + ey, 1.8, 1.3, "ivory")
        c.px(round(cx + side * ex + side * 0.6), round(cy + ey), "night")
        c.px(round(cx + side * ex - side * 1.6), round(cy + ey - 1.2), HAIR[0])  # 아이라인 꼬리
    # 입술(진한 빨강)
    mx, my = cx, cy + r * 0.48
    if mouth == "closed":
        _line(c, mx - 2, my, mx + 2, my, DRESS[0], 1)
    elif mouth == "smile":
        _line(c, mx - 3, my - 1, mx, my + 1, DRESS[0], 1)
        _line(c, mx, my + 1, mx + 3, my - 1, DRESS[0], 1)
    elif mouth == "sly":
        _line(c, mx - 3, my, mx + 1, my - 2, DRESS[0], 1)
        c.px(round(mx + 2), round(my - 2), DRESS[0])
    elif mouth == "talk_open":
        c.rect(round(mx - 2), round(my - 1), 4, 3, DRESS[0])
        c.px(round(mx - 1), round(my), "ivory")
    elif mouth == "laugh":
        c.rect(round(mx - 3), round(my - 1), 6, 3, DRESS[0])
        c.hline(round(mx - 2), round(mx + 2), round(my - 1), "ivory")
    _hair_front(c, cx, cy, r)
    _earring(c, cx, cy, r)
    lift = {"normal": 0.0, "up": -0.8, "arch": -1.3, "soft": 0.5}.get(brow, 0.0)
    for side in (-1, 1):
        by = cy + ey - r * 0.34 + lift
        _line(c, cx + side * ex - 2, by + 0.6, cx + side * ex + 2, by - 0.9, HAIR[0], 1)
    c.px(round(cx - r * 0.5), round(cy + r * 0.28), "red_l", 70)
    c.px(round(cx + r * 0.5), round(cy + r * 0.28), "red_l", 70)


def _gown_and_pearls(c: Canvas, cx: float, top: float, w: float) -> None:
    c.rect(round(cx - w * 0.5), round(top), round(w), 16, DRESS[1])
    c.hline(round(cx - w * 0.5), round(cx + w * 0.5) - 1, round(top), DRESS[2])
    # 목선(브이넥)
    c.rect(round(cx - 2), round(top), 4, 3, SKIN[2])
    # 진주 목걸이
    for i in range(-2, 3):
        c.px(round(cx + i * 1.6), round(top + 3) + abs(i), PEARL)


PORTRAIT_FRAMES: list[dict] = [
    dict(mouth="closed", brow="normal"),    # 0 기본
    dict(mouth="smile", brow="soft"),       # 1 웃음
    dict(mouth="sly", brow="arch"),         # 2 교활함
    dict(mouth="talk_open", brow="up"),     # 3 놀람
    dict(mouth="smile", brow="normal"),     # 4 만족
    dict(mouth="talk_open", brow="normal"), # 5 입벙긋: 열림
    dict(mouth="closed", brow="normal"),    # 6 입벙긋: 닫힘
]


def velvet_portrait() -> None:
    c = Canvas(PORTRAIT * len(PORTRAIT_FRAMES), PORTRAIT)
    r = 8.0 * 1.7
    for i, spec in enumerate(PORTRAIT_FRAMES):
        ox = i * PORTRAIT
        cx, cy = ox + PORTRAIT * 0.5, PORTRAIT * 0.46
        _velvet_head(c, cx, cy, r, mouth=spec["mouth"], brow=spec["brow"])
        _gown_and_pearls(c, cx, cy + r * 0.92, r * 1.8)
    c.save(f"{OUT}/velvet_portrait.png")


# ── 월드 스프라이트(48×72) ───────────────────────────────

def draw_velvet(c: Canvas, ox: int, oy: int, *, arm: float = 0.0, bob: float = 0.0, mouth: str = "closed",
        pose: str = "idle") -> None:
    """발바닥 기준 y = oy + FRAME_H - 4. 롱드레스라 다리는 안 보인다(치맛단만)."""
    foot_y = oy + FRAME_H - 4
    cx = ox + FRAME_W * 0.5
    hem_y = foot_y - 2 + bob
    hip_y = hem_y - 30
    shoulder_y = hip_y - 18
    head_cy = shoulder_y - 9
    r = 7.0
    glove = HAIR[0]  # 팔꿈치까지 오는 검은 장갑(드레스와 같은 색이면 실루엣이 안 보여서 대비색으로 그린다)
    # 롱드레스(치맛단이 살짝 퍼짐, 너무 넓지 않게)
    skirt_w = 8
    for y in range(round(hip_y), round(hem_y) + 1):
        t = (y - hip_y) / max(1.0, hem_y - hip_y)
        half_w = 6 + skirt_w * t * 0.5
        c.hline(round(cx - half_w), round(cx + half_w), y, DRESS[1])
    c.hline(round(cx - 6), round(cx + 5), round(hip_y), DRESS[2])
    c.hline(round(cx - skirt_w), round(cx + skirt_w - 1), round(hem_y), DRESS[0])
    # 몸통(보디스)
    c.rect(round(cx - 6), round(shoulder_y), 12, round(hip_y - shoulder_y), DRESS[1])
    c.hline(round(cx - 6), round(cx + 5), round(shoulder_y), DRESS[2])
    c.rect(round(cx - 2), round(shoulder_y), 4, 3, SKIN[2])
    for i in range(-1, 2):
        c.px(round(cx + i * 1.6), round(shoulder_y + 2), PEARL)
    # 팔(포즈별, 검은 장갑)
    if pose == "wine":
        lift = arm
        hand = (cx + 7, shoulder_y + 3 - lift * 9)
        _line(c, cx + 4, shoulder_y + 2, hand[0], hand[1], glove, 2)
        c.px(round(hand[0] + 1), round(hand[1] - 2), "ivory", 200)  # 와인잔
        c.px(round(hand[0] + 1), round(hand[1] - 3), "red_l")
        _line(c, cx - 4, shoulder_y + 2, cx - 5, shoulder_y + 11, glove, 2)
    elif pose == "gesture":
        swing = arm
        hand = (cx - 8 - swing * 3, shoulder_y + 2 - swing * 4)
        _line(c, cx - 4, shoulder_y + 2, hand[0], hand[1], glove, 2)
        _line(c, cx + 4, shoulder_y + 2, cx + 5, shoulder_y + 11, glove, 2)
    elif pose == "clap":
        spread = 2.5 - abs(arm) * 2.5
        _line(c, cx - 4, shoulder_y + 2, cx - spread, shoulder_y + 6, glove, 2)
        _line(c, cx + 4, shoulder_y + 2, cx + spread, shoulder_y + 6, glove, 2)
    else:
        _line(c, cx - 4, shoulder_y + 2, cx - 5, shoulder_y + 11, glove, 2)
        _line(c, cx + 4, shoulder_y + 2, cx + 5, shoulder_y + 11, glove, 2)
    # 머리
    _velvet_head(c, cx, head_cy, r, mouth=mouth, brow="normal")


def _idle_pose(i: int, n: int) -> dict:
    phase = i / n
    return dict(bob=math.sin(phase * math.tau) * 0.5, mouth="closed", pose="idle")


def _wine_pose(i: int, n: int) -> dict:
    return dict(arm=[0.0, 1.0, 0.4][i % 3], mouth="smile", pose="wine")


def _gesture_pose(i: int, n: int) -> dict:
    return dict(arm=math.sin(i / n * math.tau), mouth="smile", pose="gesture")


def _clap_pose(i: int, n: int) -> dict:
    return dict(arm=math.sin(i / n * math.tau), mouth="smile", pose="clap")


POSE_FUNCS = {"idle": _idle_pose, "wine": _wine_pose, "gesture": _gesture_pose, "clap": _clap_pose}


def velvet_world() -> None:
    w, h = FRAME_W * MAX_COLS, FRAME_H * len(WORLD_ANIMS)
    c = Canvas(w, h)
    for row, (anim, n) in enumerate(WORLD_ANIMS):
        for col in range(n):
            pose = POSE_FUNCS[anim](col, n)
            draw_velvet(c, col * FRAME_W, row * FRAME_H, **pose)
    c.save(f"{OUT}/velvet_world.png")


def main() -> None:
    velvet_portrait()
    velvet_world()
    print("velvet ok")


if __name__ == "__main__":
    main()
