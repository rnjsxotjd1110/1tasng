"""래칫 남작 · 부하 쥐 캐릭터 시트 생성(ART_BIBLE 12장).

  python3 tools/art/gen_baron.py

출력(팔레트 36색, 4배 미리보기는 build/art_preview/):
  assets/sprites/npc/baron_world.png     48×64 프레임, 7행 × 최대 6열
                                          (walk6 / idle4 / talk4 / tip_hat5 / laugh4 / angry3 / counting_money4)
  assets/sprites/npc/baron_portrait.png  64×64 × 7 (기본/웃음/교활한 미소/놀람/만족-모자벗음 + 입벙긋 2)
  assets/sprites/npc/underling_rat.png   32×40 × 6 (lean 2 + walk 4)

캐릭터는 오른쪽을 보고 서 있다(왼쪽으로 걸어 들어올 때는 게임 쪽에서 좌우 반전해서 쓴다).
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas  # noqa: E402

OUT = "assets/sprites/npc"
FRAME_W, FRAME_H = 48, 64
UNDER_W, UNDER_H = 32, 40
PORTRAIT = 64

WORLD_ANIMS: list[tuple[str, int]] = [
    ("walk", 6), ("idle", 4), ("talk", 4), ("tip_hat", 5), ("laugh", 4), ("angry", 3), ("counting_money", 4),
]
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
    """타원의 아래쪽 절반만(그림자 밴드용)."""
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
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        if width <= 1:
            c.px(round(x), round(y), name)
        else:
            for dx in range(width):
                c.px(round(x) + dx - width // 2, round(y), name)


# ── 래칫 남작 ────────────────────────────────────────────

def draw_baron(c: Canvas, ox: int, oy: int, *,
                leg: float = 0.0, arm: float = 0.0, tail: float = 0.0,
                hat_lift: float = 0.0, hat_tilt: float = 0.0,
                mouth: str = "closed", brow: str = "normal",
                bob: float = 0.0, lean: float = 0.0,
                hands: str = "cigar", cane: bool = False) -> None:
    """ox,oy: 프레임 왼쪽 위. 48×64 안에 그린다. 오른쪽을 본다."""
    cx = ox + 20.0 + lean
    foot_y = oy + 60.0 - bob
    hip_y = foot_y - 13.0
    belly_cy = hip_y - 9.0
    head_cx, head_cy, head_r = cx + 2.0, belly_cy - 17.0, 9.0

    # 꼬리(배 안쪽에서 시작해 뒤로 빠져나오게 — 몸에 가려 자연스럽게 이어 보인다)
    tail_base = (cx - 6.0, belly_cy + 5.0)
    sway = math.sin(tail * math.tau) * 4.0
    tail_mid = (tail_base[0] - 7.0, tail_base[1] - 4.0 + sway * 0.4)
    tail_tip = (tail_base[0] - 5.0, tail_base[1] - 12.0 + sway)
    _line(c, tail_base[0], tail_base[1], tail_mid[0], tail_mid[1], "neon_pink", 2)
    _line(c, tail_mid[0], tail_mid[1], tail_tip[0], tail_tip[1], "neon_pink", 2)

    # 뒷다리(먼 쪽, 몸에 살짝 가려짐)
    back_leg = math.sin((leg + 0.5) * math.tau) * 3.0
    _leg(c, cx - 3.0, hip_y, foot_y, back_leg, "ink")

    # 지팡이(짚는 손, 몸 뒤쪽에 먼저)
    if cane:
        cane_x = cx - 11.0
        _line(c, cane_x, hip_y - 6.0, cane_x, foot_y + 1.0, "wood_d", 1)
        c.px(round(cane_x), round(hip_y - 7.0), "gold")
        c.px(round(cane_x) - 1, round(hip_y - 6.0), "gold_l")

    # 코트(배) — 어깨는 좁고 아래로 갈수록 둥글게 퍼지는 실루엣
    _ellipse(c, cx, belly_cy, 9.5, 10.0, "purple_d")
    _ellipse_arc_bottom(c, cx, belly_cy + 2.5, 9.0, 7.0, "night")
    _ellipse(c, cx - 2.0, belly_cy - 7.0, 4.5, 3.5, "neon_purple")
    # 핀스트라이프(코트 실루엣 안쪽에만, 세로줄)
    for sx in range(int(cx - 8), int(cx + 9), 3):
        for y in range(int(belly_cy - 9), int(belly_cy + 9)):
            if c.is_set(sx, y):
                c.px(sx, y, "mist", 70)
    # 코트 밑단(살짝 들쭉날쭉)
    for i in range(-8, 9, 3):
        c.px(round(cx + i), round(hip_y), "night")
    # 회중시계 줄(금), 코트 앞판 위에 그려 잘 보이게
    _line(c, cx + 3, belly_cy - 6, cx + 8, belly_cy - 1, "gold", 1)
    c.px(round(cx + 8), round(belly_cy), "gold_l")

    # 앞다리
    front_leg = math.sin(leg * math.tau) * 3.0
    _leg(c, cx + 2.0, hip_y, foot_y, front_leg, "stone")

    # 머리 + 모자(모자는 머리 반지름 기준으로 딱 맞물리게)
    _head(c, head_cx, head_cy, mouth=mouth, brow=brow)
    hat_cx = head_cx + hat_tilt * 3.0
    hat_cy = head_cy - head_r * 0.55 - hat_lift
    _hat(c, hat_cx, hat_cy, head_r)

    # 어깨·앞팔(머리 위에 그려 시가·돈다발이 얼굴에 가려지지 않게)
    shoulder = (head_cx + 5.0, head_cy + head_r + 2.0)
    _draw_arm(c, shoulder, hands, arm, mouth, (head_cx, head_cy, head_r))


def rgb_of(c: Canvas, name: str) -> tuple:
    from pixlib import PALETTE_RGB
    return PALETTE_RGB[name]


def _leg(c: Canvas, x: float, hip_y: float, foot_y: float, swing: float, name: str) -> None:
    knee = (x + swing, (hip_y + foot_y) / 2.0)
    foot = (x + swing * 1.6, foot_y)
    _line(c, x, hip_y, knee[0], knee[1], name, 3)
    _line(c, knee[0], knee[1], foot[0], foot[1], name, 3)
    _ellipse(c, foot[0], foot[1], 3.0, 1.6, "night")


def _draw_arm(c: Canvas, shoulder: tuple, hands: str, arm: float, mouth: str, head: tuple) -> None:
    sx, sy = shoulder
    head_cx, head_cy, head_r = head
    if hands == "cigar":
        hand = (head_cx + head_r * 1.05, head_cy + head_r * 0.55 + math.sin(arm * math.tau) * 1.0)
    elif hands == "swing":
        hand = (sx + math.sin(arm * math.tau) * 5.0, sy + 10.0 + math.cos(arm * math.tau) * 2.0)
    elif hands == "hat":
        hand = (sx - 2.0, sy - 10.0 - arm * 4.0)
    elif hands == "money":
        hand = (sx - 1.0, sy + 5.0)
    elif hands == "fist":
        hand = (sx + 4.0, sy + 2.0 - arm * 2.0)
    elif hands == "belly":
        hand = (sx - 4.0, sy + 9.0)
    else:
        hand = (sx + 2.0, sy + 9.0)
    elbow = ((sx + hand[0]) / 2.0 + 2.0, (sy + hand[1]) / 2.0)
    _line(c, sx, sy, elbow[0], elbow[1], "purple_d", 3)
    _line(c, elbow[0], elbow[1], hand[0], hand[1], "stone", 2)
    if hands == "cigar":
        tip = (hand[0] + 3.0, hand[1] - 3.0)
        _line(c, hand[0], hand[1], tip[0], tip[1], "wood", 2)
        c.px(round(tip[0]), round(tip[1]), "wood_l")
        for dx, dy, a in ((1, 0, 255), (2, -1, 200), (1, -1, 140)):
            c.px(round(tip[0]) + dx, round(tip[1]) + dy, "amber", a)
        if mouth in ("talk_open", "laugh"):
            for i in range(3):
                c.px(round(tip[0]) + 2 + i, round(tip[1]) - 2 - i, "mist", 140 - i * 30)
    elif hands == "money":
        c.rect(round(hand[0]) - 3, round(hand[1]) - 4, 6, 5, "ivory")
        c.hline(round(hand[0]) - 3, round(hand[0]) + 2, round(hand[1]) - 2, "clover")
        c.outline_rect(round(hand[0]) - 3, round(hand[1]) - 4, 6, 5, "gold_d")
    elif hands == "hat" or hands == "fist":
        c.px(round(hand[0]), round(hand[1]), "stone")


def _head(c: Canvas, cx: float, cy: float, *, mouth: str, brow: str, big: bool = False) -> None:
    scale = 1.7 if big else 1.0
    r = 8.0 * scale
    # 귀(머리보다 먼저 그려 머리에 자연스럽게 붙게)
    ear_l = (cx - r * 0.6, cy - r * 0.75)
    ear_r = (cx + r * 0.25, cy - r * 0.95)
    _ellipse(c, ear_l[0], ear_l[1], r * 0.34, r * 0.36, "stone")
    _ellipse(c, ear_r[0], ear_r[1], r * 0.3, r * 0.32, "stone")
    _ellipse(c, ear_l[0], ear_l[1], r * 0.17, r * 0.19, "ink")
    _ellipse(c, ear_r[0], ear_r[1], r * 0.15, r * 0.17, "ink")
    # 두상
    _ellipse(c, cx, cy, r, r * 0.92, "stone")
    _ellipse_arc_bottom(c, cx, cy + r * 0.15, r * 0.96, r * 0.75, "ink")
    _line(c, cx - r * 0.6, cy - r * 0.5, cx - r * 0.1, cy - r * 0.75, "mist", 1)
    # 주둥이
    snout_cx, snout_cy = cx + r * 0.95, cy + r * 0.2
    _ellipse(c, snout_cx, snout_cy, r * 0.55, r * 0.4, "stone")
    _ellipse_arc_bottom(c, snout_cx, snout_cy + r * 0.05, r * 0.5, r * 0.28, "ink")
    c.px(round(snout_cx + r * 0.48), round(snout_cy - 1), "night")
    c.px(round(snout_cx + r * 0.48), round(snout_cy), "night")
    c.px(round(snout_cx + r * 0.42), round(snout_cy - 1), "night")
    # 수염(주둥이 옆에서만 짧게, 프레임 밖으로 넘치지 않게)
    for dy in (-2, 0, 2):
        _line(c, snout_cx - r * 0.1, snout_cy + dy * 0.4, snout_cx + r * 0.55, snout_cy + dy * 0.9, "mist", 1)
    # 눈 + 외알 안경(금테, 반사 1px)
    eye = (cx + r * 0.3, cy - r * 0.02)
    if brow == "up":
        _line(c, eye[0] - r * 0.4, eye[1] - r * 0.5, eye[0] + r * 0.2, eye[1] - r * 0.68, "night", 2)
    elif brow == "angry":
        _line(c, eye[0] - r * 0.45, eye[1] - r * 0.15, eye[0] + r * 0.25, eye[1] - r * 0.55, "night", 2)
    eye_r = r * (0.34 if brow == "wide" else 0.24)
    c.px(round(eye[0]), round(eye[1]), "night")
    if brow == "wide":
        c.px(round(eye[0]) + 1, round(eye[1]), "ivory")
    ring_r = eye_r + r * 0.22
    _ellipse(c, eye[0], eye[1], ring_r, ring_r, "gold_d")
    _ellipse(c, eye[0], eye[1], ring_r - max(1.0, r * 0.12), ring_r - max(1.0, r * 0.12), "stone")
    c.px(round(eye[0] + ring_r * 0.55), round(eye[1] - ring_r * 0.55), "ivory")
    # 입
    mx, my = snout_cx - r * 0.12, snout_cy + r * 0.58
    if mouth == "closed":
        _line(c, mx - r * 0.22, my, mx + r * 0.22, my - r * 0.1, "night", 1)
    elif mouth == "talk_open":
        c.rect(round(mx - r * 0.12), round(my - r * 0.14), max(2, round(r * 0.3)), max(2, round(r * 0.22)), "void")
    elif mouth == "laugh":
        c.rect(round(mx - r * 0.32), round(my - r * 0.24), max(3, round(r * 0.55)), max(3, round(r * 0.3)), "void")
        c.hline(round(mx - r * 0.2), round(mx + r * 0.15), round(my - r * 0.22), "ivory")
    elif mouth == "angry":
        _line(c, mx - r * 0.22, my - r * 0.1, mx + r * 0.12, my + r * 0.12, "night", 1)
        c.px(round(mx + r * 0.12), round(my), "ivory")
    elif mouth == "smile":
        _line(c, mx - r * 0.32, my - r * 0.1, mx, my + r * 0.12, "night", 1)
        _line(c, mx, my + r * 0.12, mx + r * 0.2, my - r * 0.1, "night", 1)


def _hat(c: Canvas, cx: float, cy: float, head_r: float = 9.0) -> None:
    """cy = 머리 반지름 기준으로 이마 언저리(챙이 여기서 시작해 머리와 자연스럽게 겹친다)."""
    scale = head_r / 9.0
    brim_ry = 2.6 * scale
    crown_w, crown_h = 12.0 * scale, 7.0 * scale
    _ellipse(c, cx, cy, 11.0 * scale, brim_ry, "night")
    c.rect(round(cx - crown_w / 2), round(cy - crown_h), round(crown_w), round(crown_h) + 1, "ink")
    _ellipse(c, cx, cy - crown_h, crown_w * 0.5, brim_ry * 0.9, "ink")
    c.hline(round(cx - crown_w / 2), round(cx + crown_w / 2 - 1), round(cy - crown_h * 0.28), "gold")
    _ellipse(c, cx - crown_w * 0.18, cy - crown_h * 0.85, crown_w * 0.22, brim_ry * 0.5, "stone")


def draw_underling(c: Canvas, ox: int, oy: int, *, leg: float = 0.0, lean_angle: float = 0.0, arm: float = 0.0) -> None:
    cx = ox + 15.0 + lean_angle * 4.0
    foot_y = oy + 37.0
    hip_y = foot_y - 9.0
    belly_cy = hip_y - 8.0

    back_leg = math.sin((leg + 0.5) * math.tau) * 2.2
    _leg_small(c, cx - 2.0, hip_y, foot_y, back_leg)

    _ellipse(c, cx, belly_cy, 6.5, 7.5, "night")
    _ellipse_arc_bottom(c, cx, belly_cy + 2.0, 6.0, 5.0, "void")
    c.vline(round(cx), round(belly_cy - 6), round(belly_cy + 6), "ink")

    front_leg = math.sin(leg * math.tau) * 2.2
    _leg_small(c, cx + 1.5, hip_y, foot_y, front_leg)

    shoulder = (cx + 4.0, belly_cy - 6.0)
    hand = (shoulder[0] + 1.5, shoulder[1] + 6.0 + arm * 2.0)
    _line(c, shoulder[0], shoulder[1], hand[0], hand[1], "night", 2)

    head_cx, head_cy = cx + 2.0, belly_cy - 10.0
    r = 5.5
    _ellipse(c, head_cx, head_cy, r, r * 0.9, "stone")
    _ellipse_arc_bottom(c, head_cx, head_cy + r * 0.2, r * 0.9, r * 0.6, "ink")
    _ellipse(c, head_cx - r * 0.55, head_cy - r * 0.8, r * 0.28, r * 0.28, "stone")
    _ellipse(c, head_cx + r * 0.4, head_cy - r * 0.9, r * 0.26, r * 0.26, "stone")
    snout_cx = head_cx + r * 0.95
    _ellipse(c, snout_cx, head_cy + r * 0.15, r * 0.4, r * 0.32, "stone")
    c.px(round(snout_cx + r * 0.35), round(head_cy + r * 0.1), "night")
    # 선글라스(위 눈썹 줄만 밝게, 렌즈는 통짜 검정)
    c.rect(round(head_cx - 3), round(head_cy - 1), 6, 2, "void")
    c.hline(round(head_cx - 3), round(head_cx + 2), round(head_cy - 2), "mist")
    c.px(round(head_cx - 2), round(head_cy - 1), "stone", 160)


def _leg_small(c: Canvas, x: float, hip_y: float, foot_y: float, swing: float) -> None:
    knee = (x + swing, (hip_y + foot_y) / 2.0)
    foot = (x + swing * 1.4, foot_y)
    _line(c, x, hip_y, knee[0], knee[1], "night", 2)
    _line(c, knee[0], knee[1], foot[0], foot[1], "night", 2)
    c.px(round(foot[0]), round(foot[1]), "void")


# ── 시트 조립 ────────────────────────────────────────────

def _walk_pose(i: int, n: int) -> dict:
    phase = i / n
    return dict(leg=phase, arm=phase, tail=phase * 0.3, bob=abs(math.sin(phase * math.tau)) * 1.5,
                hands="swing", cane=True, mouth="closed", brow="normal")


def _idle_pose(i: int, n: int) -> dict:
    phase = i / n
    return dict(tail=phase, bob=math.sin(phase * math.tau) * 0.6, hands="cigar", cane=True,
                mouth="closed", brow="normal")


def _talk_pose(i: int, n: int) -> dict:
    open_mouth = i % 2 == 1
    return dict(tail=i / n * 0.5, hands="cigar", mouth="talk_open" if open_mouth else "closed", brow="normal",
                arm=i / n)


def _tip_hat_pose(i: int, n: int) -> dict:
    lift = [0.0, 3.0, 7.0, 7.0, 0.0][min(i, 4)]
    tilt = [0.0, 0.3, 0.6, 0.6, 0.0][min(i, 4)]
    lean = [0.0, 0.5, 1.0, 0.5, 0.0][min(i, 4)]
    return dict(hat_lift=lift, hat_tilt=tilt, lean=lean, hands="hat", arm=lift / 7.0, mouth="smile", brow="normal")


def _laugh_pose(i: int, n: int) -> dict:
    bob = [0.0, 2.0, 0.0, 2.0][i % 4]
    return dict(bob=bob, hands="belly", mouth="laugh", brow="normal", tail=i / n)


def _angry_pose(i: int, n: int) -> dict:
    lean = [0.0, 1.5, 0.0][i % 3]
    return dict(lean=lean, hands="fist", arm=i / n, mouth="angry", brow="angry")


def _counting_pose(i: int, n: int) -> dict:
    bob = math.sin(i / n * math.tau) * 0.8
    return dict(bob=bob, hands="money", mouth="smile", brow="normal", tail=i / n * 0.4)


POSE_FUNCS = {
    "walk": _walk_pose, "idle": _idle_pose, "talk": _talk_pose, "tip_hat": _tip_hat_pose,
    "laugh": _laugh_pose, "angry": _angry_pose, "counting_money": _counting_pose,
}


def baron_world() -> None:
    w, h = FRAME_W * MAX_COLS, FRAME_H * len(WORLD_ANIMS)
    c = Canvas(w, h)
    for row, (anim, n) in enumerate(WORLD_ANIMS):
        for col in range(n):
            pose = POSE_FUNCS[anim](col, n)
            draw_baron(c, col * FRAME_W, row * FRAME_H, **pose)
    c.save(f"{OUT}/baron_world.png")


PORTRAIT_FRAMES: list[dict] = [
    dict(mouth="smile", brow="normal", hat=True),      # 0 기본
    dict(mouth="laugh", brow="normal", hat=True),       # 1 웃음
    dict(mouth="smile", brow="up", hat=True),           # 2 교활한 미소
    dict(mouth="talk_open", brow="wide", hat=True),     # 3 놀람
    dict(mouth="closed", brow="normal", hat=False),     # 4 만족(모자 벗음)
    dict(mouth="talk_open", brow="normal", hat=True),   # 5 입벙긋: 열림
    dict(mouth="closed", brow="normal", hat=True),      # 6 입벙긋: 닫힘
]


def baron_portrait() -> None:
    c = Canvas(PORTRAIT * len(PORTRAIT_FRAMES), PORTRAIT)
    head_r = 8.0 * 1.7
    for i, spec in enumerate(PORTRAIT_FRAMES):
        ox = i * PORTRAIT
        cx, cy = ox + PORTRAIT * 0.40, PORTRAIT * 0.56
        _head(c, cx, cy, mouth=spec["mouth"], brow=spec["brow"], big=True)
        if spec["hat"]:
            _hat(c, cx, cy - head_r * 0.55, head_r)
    c.save(f"{OUT}/baron_portrait.png")


UNDERLING_ANIMS: list[tuple[str, int]] = [("lean", 2), ("walk", 4)]


def underling_rat() -> None:
    total = sum(n for _, n in UNDERLING_ANIMS)
    c = Canvas(UNDER_W * total, UNDER_H)
    col = 0
    for anim, n in UNDERLING_ANIMS:
        for i in range(n):
            if anim == "lean":
                draw_underling(c, col * UNDER_W, 0, leg=0.0, lean_angle=0.3 if i == 0 else 0.35, arm=0.2)
            else:
                phase = i / n
                draw_underling(c, col * UNDER_W, 0, leg=phase, arm=phase)
            col += 1
    c.save(f"{OUT}/underling_rat.png")


def seizure_stamp() -> None:
    """빨간 쥐 발바닥 도장 16×16(압류 패널티, 계약서 서명 공용 — ART_BIBLE 11-6)."""
    c = Canvas(16, 16)
    _ellipse(c, 8, 10, 5.0, 4.0, "red")
    _ellipse(c, 6.7, 8.7, 2.2, 1.7, "red_hl")
    for dx, dy in ((-4, -6), (-1.5, -8), (1.5, -8), (4, -6)):
        _ellipse(c, 8 + dx, 10 + dy, 1.6, 2.0, "red")
    c.outline("red_d")
    c.save("assets/sprites/fx/seizure_stamp.png")


def icon_baron_mini() -> None:
    """패널티 토스트용 남작 미니 초상 16×16."""
    c = Canvas(16, 16)
    _head(c, 8.0, 10.0, mouth="smile", brow="up", big=False)
    _hat(c, 8.0, 10.0 - 8.0 * 0.55, 8.0)
    c.save("assets/sprites/ui/icon_baron_mini.png")


def icon_debt() -> None:
    """빚 두루마리 아이콘 13×13(상단 바)."""
    c = Canvas(13, 13)
    c.rect(2, 2, 9, 9, "red")
    c.rect(2, 2, 9, 1, "red_hl")
    c.rect(2, 10, 9, 1, "red_hl")
    _ellipse(c, 2.5, 6.5, 1.5, 5.0, "red_l")
    _ellipse(c, 10.5, 6.5, 1.5, 5.0, "red_l")
    for y in range(4, 10, 2):
        c.hline(4, 9, y, "red_d", 140)
    c.outline("red_d")
    c.save("assets/sprites/ui/icon_debt.png")


def _penalty_icon_canvas() -> Canvas:
    return Canvas(12, 12)


def icon_penalty_watcher() -> None:
    c = _penalty_icon_canvas()
    _ellipse(c, 6, 6, 5, 3, "ink")
    _ellipse(c, 6, 6, 3, 2, "mist")
    _ellipse(c, 6, 6, 1.3, 1.3, "night")
    c.px(5, 5, "ivory")
    c.save("assets/sprites/ui/icon_penalty_watcher.png")


def icon_penalty_pickpocket() -> None:
    """뻗은 손이 칩을 낚아채는 모양."""
    c = _penalty_icon_canvas()
    c.pattern(1, 1, [
        "....sss.",
        "...sssss",
        "..sssssm",
        ".ss.ssss",
        "sss..sss",
        ".ss..ss.",
        "..ss.s..",
        "...ss...",
    ], {"s": "stone", "m": "mist"})
    c.outline("ink")
    c.save("assets/sprites/ui/icon_penalty_pickpocket.png")


def icon_penalty_smoke() -> None:
    c = _penalty_icon_canvas()
    _ellipse(c, 5, 8, 3.2, 2.6, "stone", 200)
    _ellipse(c, 7, 5, 2.6, 2.2, "mist", 170)
    _ellipse(c, 5, 3, 1.8, 1.5, "mist", 130)
    c.save("assets/sprites/ui/icon_penalty_smoke.png")


def icon_penalty_blur() -> None:
    c = _penalty_icon_canvas()
    _ellipse(c, 6, 6, 4.5, 4.5, "stone", 160)
    for y in (4, 6, 8):
        c.hline(2, 10, y, "mist", 120)
    c.save("assets/sprites/ui/icon_penalty_blur.png")


def icon_penalty_seize() -> None:
    c = _penalty_icon_canvas()
    c.rect(3, 5, 6, 6, "night")
    c.outline_rect(3, 5, 6, 6, "red_d")
    _ellipse(c, 6, 4, 2.5, 2.5, "red")
    c.rect(4, 3, 4, 2, "night")
    c.px(6, 8, "red_hl")
    c.save("assets/sprites/ui/icon_penalty_seize.png")


def main() -> None:
    baron_world()
    baron_portrait()
    underling_rat()
    seizure_stamp()
    icon_baron_mini()
    icon_debt()
    icon_penalty_watcher()
    icon_penalty_pickpocket()
    icon_penalty_smoke()
    icon_penalty_blur()
    icon_penalty_seize()
    print("baron ok:", sorted(os.listdir(os.path.join(os.path.dirname(__file__), "..", "..", OUT))))


if __name__ == "__main__":
    main()
