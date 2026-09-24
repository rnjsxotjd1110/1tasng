"""룰렛 휠의 고정 레이어를 만든다(회전 링·터렛·공은 게임이 _draw() 로 그린다). 층 5개 스킨(GDD 7장·ART_BIBLE 12장).

  python3 tools/art/gen_wheel.py

모든 텍스처는 240×240, 휠 중심이 텍스처 (120, 120) (픽셀 경계)에 온다.
게임은 텍스처 좌상단을 휠 중심 - (120, 120) 에 놓는다. 반지름 규격은 ART_BIBLE 2장(층마다 동일 — "림·트랙·터렛만 교체").
층별로 assets/sprites/wheel/<층 id>/ 에 같은 파일 구성을 만든다(RouletteWheel.set_floor_skin() 이 동적으로 불러온다):
  wheel_shadow.png    드롭 섀도(타원, 알파) — 층 공용, 매번 같은 내용
  wheel_base.png      바깥 림(118~104) + 공 트랙(104~90) + 디플렉터 8개(91) + 숫자 링 바탕(90~76) + 포켓 자리(76 안쪽)
  wheel_top.png       포켓 경계 금선(76, 60) + 중앙 콘(60 안쪽) + 허브. 회전 링 위에 덮는다.
  wheel_highlight.png 좌상단 곡선 반사광(알파). 회전하지 않는다.
  wheel_hub.png        16×16 터렛 허브
  wheel_knob.png       5×5 터렛 손잡이 끝 구슬

테마는 "wood"(rim·track·cone 몸체, 어두운→밝은 4색)와 "gold"(볼트·디플렉터·허브 등 금속 장식, 어두운→밝은→shine 5색) 두
색 슬롯만 바꿔서 기존 형태(반지름·볼트·디플렉터 배치)를 그대로 재사용한다(스킨은 "재질 교체"이지 "재형태"가 아니다).
gloss 는 반사광 세기 배율(1F "광택"), grain_accent 는 결 사이에 섞는 강조색(1F "마호가니"), rivets 는 림에 못대가리 점을
찍는다(2F "리벳 선박풍").
"""
from __future__ import annotations

import math
import os
import sys

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

# ── 층별 테마(ART_BIBLE 12장) ────────────────────────────
THEMES: dict[str, dict] = {
    "b1": {  # 낡은 나무 + 녹슨 금속
        "wood": ["wood_d", "wood", "wood_l", "wood_hl"],
        "gold": ["gold_d", "gold", "gold_l", "gold_hl", "gold_shine"],
        "cone_center": "pocket_k",
        "gloss": 1.0, "grain_accent": None, "rivets": False,
    },
    "1f": {  # 광택 마호가니 + 금
        "wood": ["wood_d", "wood", "wood_l", "wood_hl"],
        "gold": ["gold_d", "gold", "gold_l", "gold_hl", "gold_shine"],
        "cone_center": "pocket_k",
        "gloss": 1.7, "grain_accent": "red_d", "rivets": False,
    },
    "2f": {  # 황동 + 리벳 선박풍
        "wood": ["gold_d", "gold", "gold_l", "gold_hl"],
        "gold": ["wood_d", "wood", "wood_l", "wood_hl", "ivory"],
        "cone_center": "wood_d",
        "gloss": 1.1, "grain_accent": None, "rivets": True,
    },
    "3f": {  # 크롬 + 네온 청록(움직이는 테두리 빛은 roulette_wheel.gd 런타임 효과)
        "wood": ["ink", "stone", "mist", "ivory"],
        "gold": ["ink", "stone", "mist", "neon_cyan", "ivory"],
        "cone_center": "void",
        "gloss": 1.4, "grain_accent": None, "rivets": False,
    },
    "ph": {  # 금과 상아(보석 8개 순차 반짝임은 roulette_wheel.gd 런타임 효과)
        "wood": ["gold_d", "gold", "gold_l", "ivory"],
        "gold": ["purple_d", "neon_purple", "gold_l", "gold_hl", "gold_shine"],
        "cone_center": "purple_d",
        "gloss": 1.5, "grain_accent": None, "rivets": False,
    },
}


def lightness(theta: float) -> float:
    """-1(광원 반대) ~ 1(광원 쪽)."""
    return math.cos(theta - LIGHT)


def wood_grain(r: float, theta: float) -> float:
    """원둘레를 따라 흐르는 나뭇결(또는 재질 결) 잡음(-1..1)."""
    return (math.sin(r * 2.1 + math.sin(theta * 3.0) * 1.7 + math.sin(theta * 11.0) * 0.4) * 0.6
            + math.sin(r * 5.3 + theta * 2.0) * 0.4)


def shadow(out_dir: str) -> None:
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
    c.save(f"{out_dir}/wheel_shadow.png")


def base(theme: dict, out_dir: str) -> None:
    wood = theme["wood"]
    gold = theme["gold"]
    grain_accent: str | None = theme["grain_accent"]
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
                c.px(x, y, wood[0])
            elif r > R_RIM_OUT - 2:
                c.px(x, y, gold[3] if L > 0.5 else (gold[2] if L > -0.3 else gold[1]))
            elif r > R_RIM_OUT - 3:
                c.px(x, y, gold[0])
            elif r > R_RIM_IN + 3:
                # 림: 광원 방향 + 결
                grain = wood_grain(r, t)
                v = 0.5 + 0.32 * L + 0.14 * grain
                # 림 단면: 바깥쪽이 둥글게 밝음
                v += 0.1 * math.sin((r - (R_RIM_IN + 3)) / (R_RIM_OUT - R_RIM_IN - 6) * math.pi)
                name = band_pick(v, wood)
                if grain_accent is not None and grain > 0.55 and name == wood[0]:
                    name = grain_accent
                c.px(x, y, name)
            elif r > R_RIM_IN + 2:
                c.px(x, y, gold[0])
            elif r > R_RIM_IN + 1:
                c.px(x, y, gold[2] if L > 0.0 else gold[1])
            elif r > R_RIM_IN:
                c.px(x, y, wood[0])
            elif r > R_TRACK_IN + 1:
                # 공 트랙: 어두운 매끈한 재질, 바깥 벽 쪽이 그늘, 광원 쪽이 은은히 밝음(디더링)
                depth = (r - R_TRACK_IN) / (R_RIM_IN - R_TRACK_IN)  # 0 안쪽 … 1 바깥
                v = 0.55 + 0.35 * L * (1.0 - depth) - 0.45 * max(0.0, depth - 0.7) / 0.3
                # 광원 반대쪽 벽 그림자(바깥 벽이 트랙에 드리운다)
                v -= 0.25 * max(0.0, -L) * depth
                c.px(x, y, dither_pick(v * 0.8, x, y, ["void", "pocket_k", wood[0], wood[1]]))
            elif r > R_TRACK_IN:
                c.px(x, y, gold[0])
            elif r > R_NUMBERS_IN:
                c.px(x, y, wood[0])
            else:
                c.px(x, y, "pocket_k")
    # 볼트 8개(4×4 둥근 금속 볼트)
    for i in range(BOLT_COUNT):
        a = math.radians(i * 360.0 / BOLT_COUNT)
        bx = int(round(C + R_BOLT * math.cos(a))) - 2
        by = int(round(C + R_BOLT * math.sin(a))) - 2
        c.pattern(bx, by, [
            ".dd.",
            "dhld",
            "dlgd",
            ".dd.",
        ], {"d": gold[0], "h": gold[4], "l": gold[3], "g": gold[1]})
    # 디플렉터 8개: 원둘레 방향으로 긴 다이아몬드(7×3 정도), 1px 하이라이트
    for i in range(DEFLECTOR_COUNT):
        a = math.radians(DEFLECTOR_OFFSET_DEG + i * 360.0 / DEFLECTOR_COUNT)
        tangent = (-math.sin(a), math.cos(a))
        normal = (math.cos(a), math.sin(a))
        px0 = C + R_DEFLECTOR * math.cos(a)
        py0 = C + R_DEFLECTOR * math.sin(a)
        for y in range(int(py0) - 6, int(py0) + 7):
            for x in range(int(px0) - 6, int(px0) + 7):
                dx = x + 0.5 - px0
                dy = y + 0.5 - py0
                u = dx * tangent[0] + dy * tangent[1]
                v = dx * normal[0] + dy * normal[1]
                m = abs(u) / 5.2 + abs(v) / 2.6
                if m <= 1.0:
                    if m > 0.75:
                        c.px(x, y, gold[0])
                    else:
                        # 좌상단 면이 밝게
                        side = -(dx + dy)
                        c.px(x, y, gold[3] if side > 0.6 else (gold[2] if side > -0.6 else gold[1]))
        hx = int(math.floor(px0 - 0.6))
        hy = int(math.floor(py0 - 0.6))
        c.px(hx, hy, gold[4])
    if theme["rivets"]:
        _draw_rivets(c, gold[0])
    c.save(f"{out_dir}/wheel_base.png")


def _draw_rivets(c: Canvas, color: str) -> None:
    """2F 리벳 선박풍: 림 안쪽 금선 자리를 따라 작은 못대가리 점을 1도씩 스치듯 찍는다."""
    count = 48
    r = (R_RIM_OUT + R_RIM_IN) / 2.0 + 4.0
    for i in range(count):
        a = math.radians(i * 360.0 / count)
        x = int(round(C + r * math.cos(a)))
        y = int(round(C + r * math.sin(a)))
        c.px(x, y, color)


def top(theme: dict, out_dir: str) -> None:
    wood = theme["wood"]
    gold = theme["gold"]
    cone_center = theme["cone_center"]
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
                c.px(x, y, gold[3] if L > 0.45 else (gold[2] if L > -0.45 else gold[1]))
            elif r > R_NUMBERS_IN - 0.9:
                c.px(x, y, gold[0])
            elif r > R_POCKETS_IN + 0.5:
                continue  # 포켓(회전 링)이 보이는 자리
            elif r > R_POCKETS_IN - 0.5:
                c.px(x, y, gold[0])
            elif r > R_POCKETS_IN - 1.5:
                c.px(x, y, gold[2] if L < -0.3 else (gold[1] if L < 0.4 else gold[0]))
            elif r > 42:
                # 콘 몸체: 바깥이 낮고 안쪽이 높다 → 표면이 바깥을 향함. 광원 쪽 면이 밝다.
                slope = (r - 42) / (R_POCKETS_IN - 1.5 - 42)
                v = 0.5 + 0.42 * L - 0.1 * slope
                c.px(x, y, band_pick(v, wood))
            elif r > 40:
                c.px(x, y, gold[3] if L > 0.5 else (gold[2] if L > -0.2 else (gold[1] if L > -0.7 else gold[0])))
            elif r > 39:
                c.px(x, y, wood[0])
            elif r > 9:
                slope = (r - 9) / 30.0
                v = 0.45 + 0.38 * L + 0.12 * (1 - slope)
                c.px(x, y, band_pick(v, wood[:3]))
            elif r > 8:
                c.px(x, y, gold[0])
            else:
                # 허브: 돔
                hx = (x + 0.5 - C) / 8.0
                hy = (y + 0.5 - C) / 8.0
                v = 0.55 - 0.45 * (hx + hy) / 1.4 - 0.25 * (hx * hx + hy * hy)
                c.px(x, y, band_pick(v, gold[:4]))
    del cone_center  # 콘 중심은 전부 pocket_k 반지름 밖(포켓 자리)이라 top() 에는 안 쓰인다(base() 참고)
    # 허브 스페큘러
    c.px(int(C) - 3, int(C) - 3, gold[4])
    c.px(int(C) - 2, int(C) - 3, gold[4])
    c.px(int(C) - 3, int(C) - 2, gold[4])
    c.save(f"{out_dir}/wheel_top.png")


def highlight(theme: dict, out_dir: str) -> None:
    """좌상단 곡선 반사광. ivory 알파만 쓴다. gloss 가 클수록 더 밝고 또렷하다(1F "광택")."""
    gloss = theme["gloss"]
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
                    c.px(x, y, "ivory", min(255, int((24 + 46 * span) * gloss)))
            # 숫자 링 위 얇은 반사
            span2 = 1.0 - abs(da) / math.radians(24.0)
            if span2 > 0 and abs(r - 86.5) <= 0.5 + 0.8 * span2:
                c.px(x, y, "ivory", min(255, int((18 + 30 * span2) * gloss)))
            # 콘 위 넓고 흐린 반사
            span3 = 1.0 - abs(da) / math.radians(30.0)
            if span3 > 0 and abs(r - 50.0) <= 1.0 + 3.0 * span3:
                c.px(x, y, "ivory", min(255, int((10 + 22 * span3) * gloss)))
            # 림 금선 위 강한 점 반사
            span4 = 1.0 - abs(da) / math.radians(14.0)
            if span4 > 0 and abs(r - 112.0) <= 0.5 + 1.5 * span4:
                c.px(x, y, "ivory", min(255, int((20 + 50 * span4) * gloss)))
    c.save(f"{out_dir}/wheel_highlight.png")


def hub_and_knob(theme: dict, out_dir: str) -> None:
    """허브 16×16(터렛 팔 위에 덮음), 손잡이 끝 구슬 5×5. 둘 다 둥글어 회전하지 않아도 된다."""
    gold = theme["gold"]
    hub = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            dx = (x + 0.5 - 8.0) / 8.0
            dy = (y + 0.5 - 8.0) / 8.0
            d = math.hypot(dx, dy)
            if d > 1.0:
                continue
            if d > 0.86:
                hub.px(x, y, gold[0])
            else:
                v = 0.55 - 0.45 * (dx + dy) / 1.4 - 0.2 * d * d
                hub.px(x, y, band_pick(v, gold[1:]))
    hub.px(4, 4, "ivory")
    hub.px(5, 4, gold[4])
    hub.save(f"{out_dir}/wheel_hub.png")
    knob = Canvas(5, 5)
    knob.pattern(0, 0, [
        ".ddd.",
        "dhlgd",
        "dlggd",
        "dggdd",
        ".ddd.",
    ], {"d": gold[0], "h": gold[4], "l": gold[3], "g": gold[2]})
    knob.save(f"{out_dir}/wheel_knob.png")


def generate(floor_id: str) -> None:
    theme = THEMES[floor_id]
    out_dir = f"{OUT}/{floor_id}"
    hub_and_knob(theme, out_dir)
    shadow(out_dir)
    base(theme, out_dir)
    top(theme, out_dir)
    highlight(theme, out_dir)


def main() -> None:
    for floor_id in THEMES:
        generate(floor_id)
    print("wheel ok (%d skins)" % len(THEMES))


if __name__ == "__main__":
    main()
