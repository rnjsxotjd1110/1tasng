"""7단계 에셋: 업적 아이콘 30종(24px, data/achievements.json 의 icon 필드와 1:1) +
숨김 업적 공용 "?" 아이콘 1종. gen_skills.py 와 같은 좌상단 광원 원형 배지 + 중앙 글리프
조합 방식으로 그리고, 글리프 함수도 gen_skills.py 것을 그대로 재사용한다.

  python3 tools/art/gen_achievements.py

목록 화면(달성 못한 업적)은 gen_skills.silhouette() 로 만든 `_locked` 실루엣을 보여주고,
숨김 업적은 잠긴 동안 실루엣 대신 icon_hidden.png("?") 로 대신한다.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas  # noqa: E402
import gen_skills as gs  # noqa: E402

OUT = "assets/sprites/ui/achievements"
SIZE = 24

# 분류별 [outline, shadow, base, light, shine] — gen_skills.py BRANCH_RAMP 와 같은 형식.
CATEGORY_RAMP: dict[str, list[str]] = {
    "basic": ["gold_d", "gold", "gold_l", "gold_hl", "gold_shine"],
    "debt": ["red_d", "red", "red_l", "red_hl", "ivory"],
    "progress": ["night", "water", "sky", "neon_cyan", "ivory"],
    "collection": ["felt_d", "felt", "felt_l", "clover", "ivory"],
    "feature": ["void", "purple_d", "neon_purple", "neon_pink", "ivory"],
    "cumulative": ["wood_d", "wood", "wood_l", "amber", "gold_shine"],
    "hidden": ["void", "night", "shadow", "ink", "mist"],
}


def badge(size: int, ramp: list[str]) -> Canvas:
    """gen_skills.badge() 와 동일한 좌상단 광원 원형 배지. 갈래 이름 대신 램프를 직접 받는다."""
    c = Canvas(size, size)
    outline, shadow, base, light, _shine = ramp
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
            lam = dx * gs.LIGHT[0] + dy * gs.LIGHT[1]
            c.px(x, y, light if lam > 0.32 else base if lam > -0.15 else shadow)
    sx, sy = int(cx - r * 0.5), int(cy - r * 0.55)
    c.px(sx, sy, _shine)
    return c


def g_question(c: Canvas, color: str) -> None:
    gs.g_pattern(c, [
        ".ooo.",
        "o...o",
        "...o.",
        "..o..",
        "..o..",
    ], {"o": color})


# ── 업적 icon id → (분류, 글리프 함수) ───────────────────────────────
ACHIEVEMENT_GLYPHS: dict[str, tuple[str, callable]] = {
    # basic(금 배지)
    "first_spin": ("basic", lambda c: gs.g_wheel8(c, ["night", "ivory"])),
    "first_straight": ("basic", lambda c: gs.g_dice(c, [(0, 0), (2, 2)], "ivory")),
    "zero_hit": ("basic", lambda c: gs.g_digit(c, "0", "night")),
    "win_streak_10": ("basic", lambda c: gs.g_flame(c, "night", "ivory")),
    # debt(빨강 배지)
    "first_loan": ("debt", lambda c: gs.g_briefcase(c, "night", "ivory")),
    "debt_paid_first": ("debt", lambda c: gs.g_key(c, "ivory")),
    "triple_loans": ("debt", lambda c: gs.g_dice(c, [(0, 0), (-2, -2), (2, 2)], "ivory")),
    # progress(청록 배지)
    "floor_2f": ("progress", lambda c: gs.g_digit(c, "2", "ivory")),
    "floor_3f": ("progress", lambda c: gs.g_digit(c, "3", "ivory")),
    "floor_ph": ("progress", lambda c: gs.g_star(c, "ivory", "gold_shine")),
    "ending": ("progress", lambda c: gs.g_infinity(c, "ivory")),
    # collection(초록 배지)
    "marble_gold": ("collection", lambda c: gs.g_ball_pair(c, "gold_hl", "gold_shine")),
    "marble_diamond": ("collection", lambda c: gs.g_crystal(c, "neon_cyan", "ivory")),
    "marble_cosmic": ("collection", lambda c: gs.g_storm(c, "neon_pink")),
    "marbles_12": ("collection", lambda c: gs.g_dice(c, [(-2, -2), (2, -2), (0, 0), (-2, 2), (2, 2)], "ivory")),
    "skill_half": ("collection", lambda c: gs.g_gear(c, "ivory", "night")),
    "skill_full": ("collection", lambda c: gs.g_star(c, "gold_shine", "ivory")),
    # feature(보라 배지)
    "first_fever": ("feature", lambda c: gs.g_flame(c, "neon_pink", "ivory")),
    "lucky_seven": ("feature", lambda c: gs.g_digit(c, "7", "ivory")),
    "jackpot_shown": ("feature", lambda c: gs.g_lightning(c, "ivory")),
    "destiny_flip": ("feature", lambda c: gs.g_mirror(c, "ivory", "night")),
    "double_ball": ("feature", lambda c: gs.g_ball_pair(c, "ivory", "neon_pink")),
    "golden_pocket_hit": ("feature", lambda c: gs.g_star(c, "gold_shine", "ivory")),
    # cumulative(호박 배지)
    "offline_8h": ("cumulative", lambda c: gs.g_moon(c, "ivory")),
    "no_bankrupt_1h": ("cumulative", lambda c: gs.g_shield(c, "ivory", "night")),
    "total_spins_1000": ("cumulative", lambda c: gs.g_wheel8(c, ["ivory", "night"])),
    "total_spins_10000": ("cumulative", lambda c: gs.g_wheel8(c, ["gold_shine", "ivory", "night"])),
    "total_chips_1qa": ("cumulative", lambda c: gs.g_coin_stack(c, ["night", "wood_d", "ivory"])),
    # hidden(어두운 배지) — 실제 아이콘은 달성 후에만 보인다.
    "velvet_all_lines": ("hidden", lambda c: gs.g_eye(c, "neon_pink")),
    "same_number_3": ("hidden", lambda c: gs.g_dice(c, [(0, -2), (0, 0), (0, 2)], "mist")),
}


def build_icon(icon_id: str, size: int = SIZE) -> Canvas:
    category, glyph_fn = ACHIEVEMENT_GLYPHS[icon_id]
    c = badge(size, CATEGORY_RAMP[category])
    glyph_fn(c)
    return c


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for icon_id in ACHIEVEMENT_GLYPHS:
        icon = build_icon(icon_id)
        icon.save(f"{OUT}/icon_{icon_id}.png")
        gs.silhouette(icon).save(f"{OUT}/icon_{icon_id}_locked.png")
    hidden = badge(SIZE, CATEGORY_RAMP["hidden"])
    g_question(hidden, "mist")
    hidden.save(f"{OUT}/icon_hidden.png")
    print("achievement icons ok: %d" % (len(ACHIEVEMENT_GLYPHS) + 1))


if __name__ == "__main__":
    main()
