"""딜러 루시 캐릭터 시트 생성(6단계, ART_BIBLE 12장 예정).

  python3 tools/art/gen_lucy.py

출력(팔레트 36색):
  assets/sprites/npc/lucy_world.png     40×56 프레임, 4행(idle4 / spin_launch4 / clap4 / point3)
  assets/sprites/npc/lucy_portrait.png  64×64 × 7(기본/웃음/윙크/놀람/만족 + 입벙긋 2)

흑발 단발, 어두운 카지노 조끼, 빨강 나비넥타이, 금 명찰. 사람이 그린 그림으로 바꿀 때는
프레임 규격·발바닥 기준선(피벗)만 유지하면 코드 수정이 필요 없다. 캐릭터는 오른쪽을 본다
(왼쪽을 볼 때는 게임에서 좌우 반전).
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas  # noqa: E402

OUT = "assets/sprites/npc"
FRAME_W, FRAME_H = 40, 56
PORTRAIT = 64

SKIN = ["wood_d", "wood", "wood_l", "wood_hl"]  # outline, shadow, base, light
HAIR = ["void", "night", "ink"]  # outline, base, highlight
VEST = ["void", "night", "shadow"]
BOWTIE = ["red_d", "red", "red_l"]

WORLD_ANIMS: list[tuple[str, int]] = [("idle", 4), ("spin_launch", 4), ("clap", 4), ("point", 3)]
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


def _hair_back(c: Canvas, cx: float, cy: float, r: float) -> None:
    """정수리 실루엣(뒷레이어). 얼굴 타원을 그리기 전에 그려서 얼굴이 앞을 덮게 한다."""
    _ellipse(c, cx, cy - r * 0.08, r * 1.08, r * 1.05, HAIR[1])
    _ellipse_arc_bottom(c, cx, cy - r * 0.08, r * 1.08, r * 1.05, HAIR[0])


def _hair_front(c: Canvas, cx: float, cy: float, r: float, flip: bool = False) -> None:
    """옆머리(턱 옆)·짧은 앞머리(눈썹 위에서 멈춤). 이목구비를 다 그린 뒤 마지막에 불러
    표정을 가리지 않는다(이전 버전은 이마 노출용 살빛 타원이 눈·눈썹·입까지 덮어써 지워버리는
    버그가 있었다: 캐릭터 표정이 다 비슷해 보이고 머리카락도 살구빛으로 보였던 원인)."""
    del flip
    # 옆머리(턱 옆까지 내려오는 단발)
    c.rect(round(cx - r * 1.05), round(cy - r * 0.1), round(r * 0.4), round(r * 1.15), HAIR[1])
    c.rect(round(cx + r * 0.68), round(cy - r * 0.1), round(r * 0.42), round(r * 1.15), HAIR[1])
    c.hline(round(cx - r * 1.05), round(cx - r * 0.68), round(cy + r * 0.95), HAIR[0])
    c.hline(round(cx + r * 0.68), round(cx + r * 1.08), round(cy + r * 0.95), HAIR[0])
    # 앞머리(이마 위 짧은 뱅). 눈썹과 같은 HAIR[1] 색이라 겹치면 안 보이므로, 가장 높이 올라가는
    # "wide" 눈썹(cy-0.37r-1.2)보다 확실히 위에서 멈춘다(여유 2px 이상).
    top = cy - r * 1.06
    bottom = cy - r * 0.65
    steps = max(1, int(math.ceil(bottom - top)))
    for i in range(steps + 1):
        t = i / steps
        y = top + (bottom - top) * t
        half_w = r * (1.0 - 0.18 * t)
        c.hline(round(cx - half_w), round(cx + half_w), round(y), HAIR[1])
    c.hline(round(cx - r * 0.95), round(cx + r * 0.95), round(top), HAIR[0])
    c.px(round(cx - r * 0.3), round(bottom - 1), HAIR[2])
    c.px(round(cx + r * 0.15), round(bottom - 2), HAIR[2])


def _lucy_head(c: Canvas, cx: float, cy: float, r: float, *, mouth: str, brow: str, wink: bool = False) -> None:
    _hair_back(c, cx, cy, r)
    _ellipse(c, cx, cy, r * 0.82, r, SKIN[2])
    _ellipse_arc_bottom(c, cx, cy + r * 0.25, r * 0.78, r * 0.7, SKIN[1])
    # 눈
    ex = r * 0.34
    ey = -r * 0.05
    for side in (-1, 1):
        if wink and side == 1:
            _line(c, cx + side * ex - 2, cy + ey, cx + side * ex + 2, cy + ey, "night", 1)
            continue
        _ellipse(c, cx + side * ex, cy + ey, 2.0, 1.6, "ivory")
        c.px(round(cx + side * ex), round(cy + ey), "night")
    # 입
    mx, my = cx, cy + r * 0.5
    if mouth == "closed":
        _line(c, mx - 2, my, mx + 2, my, "red_d", 1)
    elif mouth == "smile":
        _line(c, mx - 3, my - 1, mx, my + 1, "red_d", 1)
        _line(c, mx, my + 1, mx + 3, my - 1, "red_d", 1)
    elif mouth == "talk_open":
        c.rect(round(mx - 2), round(my - 1), 4, 3, "red_d")
        c.px(round(mx - 1), round(my), "ivory")
    elif mouth == "laugh":
        c.rect(round(mx - 3), round(my - 1), 6, 4, "red_d")
        c.hline(round(mx - 2), round(mx + 2), round(my - 1), "ivory")
    _hair_front(c, cx, cy, r)
    # 눈썹(앞머리보다 나중에 그려 뱅 아랫단 반올림 오차에도 항상 보이게 한다)
    lift = {"normal": 0.0, "up": -0.7, "wide": -1.2, "soft": 0.6}.get(brow, 0.0)
    for side in (-1, 1):
        by = cy + ey - r * 0.32 + lift
        _line(c, cx + side * ex - 2, by + 0.6, cx + side * ex + 2, by - 0.6, HAIR[1], 1)
    c.px(round(cx - r * 0.5), round(cy + r * 0.3), "amber", 90)
    c.px(round(cx + r * 0.5), round(cy + r * 0.3), "amber", 90)


def _vest_and_tie(c: Canvas, cx: float, top: float, w: float) -> None:
    c.rect(round(cx - w * 0.5), round(top), round(w), 14, VEST[1])
    c.hline(round(cx - w * 0.5), round(cx + w * 0.5) - 1, round(top), VEST[2])
    # 흰 셔츠 칼라
    c.rect(round(cx - 3), round(top), 6, 4, "ivory")
    # 나비넥타이
    c.rect(round(cx - 3), round(top + 1), 2, 2, BOWTIE[1])
    c.rect(round(cx + 1), round(top + 1), 2, 2, BOWTIE[1])
    c.px(round(cx), round(top + 2), BOWTIE[0])
    # 금 명찰
    c.rect(round(cx - w * 0.32), round(top + 5), 4, 2, "gold_l")


PORTRAIT_FRAMES: list[dict] = [
    dict(mouth="smile", brow="normal"),       # 0 기본
    dict(mouth="laugh", brow="normal"),       # 1 웃음
    dict(mouth="smile", brow="soft", wink=True),  # 2 윙크(교활한 미소 자리)
    dict(mouth="talk_open", brow="wide"),     # 3 놀람
    dict(mouth="closed", brow="soft"),        # 4 만족
    dict(mouth="talk_open", brow="normal"),   # 5 입벙긋: 열림
    dict(mouth="closed", brow="normal"),      # 6 입벙긋: 닫힘
]


def lucy_portrait() -> None:
    c = Canvas(PORTRAIT * len(PORTRAIT_FRAMES), PORTRAIT)
    r = 8.0 * 1.7
    for i, spec in enumerate(PORTRAIT_FRAMES):
        ox = i * PORTRAIT
        cx, cy = ox + PORTRAIT * 0.5, PORTRAIT * 0.44
        _lucy_head(c, cx, cy, r, mouth=spec["mouth"], brow=spec["brow"], wink=spec.get("wink", False))
        _vest_and_tie(c, cx, cy + r * 0.95, r * 1.7)
    c.save(f"{OUT}/lucy_portrait.png")


# ── 월드 스프라이트(40×56) ───────────────────────────────

def draw_lucy(c: Canvas, ox: int, oy: int, *, arm: float = 0.0, bob: float = 0.0, mouth: str = "smile",
        pose: str = "idle") -> None:
    """발바닥 기준 y = oy + FRAME_H - 4."""
    foot_y = oy + FRAME_H - 4
    cx = ox + FRAME_W * 0.5
    hip_y = foot_y - 20 + bob
    shoulder_y = hip_y - 16
    head_cy = shoulder_y - 8
    r = 6.5
    # 다리
    for side in (-1, 1):
        c.rect(round(cx + side * 2 - 1), round(hip_y), 2, round(foot_y - hip_y), VEST[1])
        c.px(round(cx + side * 2 - 1), round(foot_y), "night")
    # 몸통(조끼)
    c.rect(round(cx - 6), round(shoulder_y), 12, round(hip_y - shoulder_y), VEST[1])
    c.hline(round(cx - 6), round(cx + 5), round(shoulder_y), VEST[2])
    c.rect(round(cx - 2), round(shoulder_y), 4, 5, "ivory")
    c.rect(round(cx - 2), round(shoulder_y + 1), 1, 1, BOWTIE[1])
    c.rect(round(cx + 1), round(shoulder_y + 1), 1, 1, BOWTIE[1])
    c.rect(round(cx - 5), round(shoulder_y + 4), 3, 2, "gold_l")
    # 팔(포즈별)
    if pose == "spin_launch":
        swing = arm
        hand = (cx + 9 + swing * 4, shoulder_y + 2 - swing * 6)
        _line(c, cx + 5, shoulder_y + 2, hand[0], hand[1], VEST[1], 2)
        c.px(round(hand[0]), round(hand[1]), SKIN[2])
        if swing > 0.6:
            c.px(round(hand[0] + 2), round(hand[1] - 2), "ivory")  # 던진 공(구슬)
    elif pose == "clap":
        spread = 3.0 - abs(arm) * 3.0
        _line(c, cx - 5, shoulder_y + 2, cx - spread, shoulder_y + 6, VEST[1], 2)
        _line(c, cx + 5, shoulder_y + 2, cx + spread, shoulder_y + 6, VEST[1], 2)
        c.px(round(cx - spread), round(shoulder_y + 6), SKIN[2])
        c.px(round(cx + spread), round(shoulder_y + 6), SKIN[2])
    elif pose == "point":
        _line(c, cx - 5, shoulder_y + 2, cx - 11, shoulder_y - 2 + arm * 3, VEST[1], 2)
        c.px(round(cx - 11), round(shoulder_y - 2 + arm * 3), SKIN[2])
        _line(c, cx + 5, shoulder_y + 2, cx + 3, shoulder_y + 8, VEST[1], 2)
    else:
        _line(c, cx - 5, shoulder_y + 2, cx - 6, shoulder_y + 10, VEST[1], 2)
        _line(c, cx + 5, shoulder_y + 2, cx + 6, shoulder_y + 10, VEST[1], 2)
    # 머리
    _lucy_head(c, cx, head_cy, r, mouth=mouth, brow="normal")


def _idle_pose(i: int, n: int) -> dict:
    phase = i / n
    return dict(bob=math.sin(phase * math.tau) * 0.6, mouth="smile", pose="idle")


def _spin_launch_pose(i: int, n: int) -> dict:
    return dict(arm=i / (n - 1), mouth="closed", pose="spin_launch")


def _clap_pose(i: int, n: int) -> dict:
    return dict(arm=math.sin(i / n * math.tau), mouth="laugh", pose="clap")


def _point_pose(i: int, n: int) -> dict:
    return dict(arm=[0.0, 1.0, 0.5][i % 3], mouth="smile", pose="point")


POSE_FUNCS = {"idle": _idle_pose, "spin_launch": _spin_launch_pose, "clap": _clap_pose, "point": _point_pose}


def lucy_world() -> None:
    w, h = FRAME_W * MAX_COLS, FRAME_H * len(WORLD_ANIMS)
    c = Canvas(w, h)
    for row, (anim, n) in enumerate(WORLD_ANIMS):
        for col in range(n):
            pose = POSE_FUNCS[anim](col, n)
            draw_lucy(c, col * FRAME_W, row * FRAME_H, **pose)
    c.save(f"{OUT}/lucy_world.png")


def main() -> None:
    lucy_portrait()
    lucy_world()
    print("lucy ok")


if __name__ == "__main__":
    main()
