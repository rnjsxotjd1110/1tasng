"""큰 숫자용 비트맵 폰트(7px·14px, 색 5종)와 휠·토큰용 3×5 숫자 아틀라스를 만든다.

  python3 tools/art/gen_fonts.py

- 14px: Galmuri11 Bold(OFL) 글리프 모양을 가져와 그라데이션·외곽선·그림자를 입힌다.
- 7px : 3×5 픽셀 글리프를 이 파일에서 직접 디자인한다(본체 5줄 + 외곽선).
- 출력: assets/fonts/num{7,14}_{variant}.png + .fnt (BMFont 텍스트 형식, Godot 가 FontFile 로 임포트)
        assets/sprites/ui/digits_3x5.png (ivory, 휠 숫자 링·기록 토큰·베팅 칸)
- 숫자 0~9 는 모두 같은 폭(고정폭)이라 카운트업 중에 글자가 흔들리지 않는다.
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import ROOT, Canvas  # noqa: E402

GALMURI_BOLD = os.path.join(ROOT, "assets", "fonts", "Galmuri11-Bold.ttf")
GALMURI_BOLD_SIZE = 12
# Galmuri11 Bold 12px 에서 본체가 차지하는 줄(렌더 y=0 기준)
BODY_TOP = 1
BODY_ROWS = 10
DESC_ROWS = 2

BIG_CHARS = [chr(c) for c in range(33, 127)] + ["×", "−"]
SMALL_GLYPHS: dict[str, list[str]] = {
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"],
    "3": ["###", "..#", ".##", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "###"],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "v": ["...", "...", "#.#", "#.#", ".#."],
    "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "Q": [".##.", "#..#", "#..#", "#.#.", ".#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "O": [".##.", "#..#", "#..#", "#..#", ".##."],
    "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "a": ["...", ".##", "#.#", "#.#", ".##"],
    "i": ["#", ".", "#", "#", "#"],
    "x": ["...", "...", "#.#", ".#.", "#.#"],
    "p": ["...", "##.", "#.#", "##.", "#.."],
    "c": ["..", "..", ".#", "#.", ".#"],
    "o": ["...", "...", ".#.", "#.#", ".#."],
    "d": ["..#", "..#", ".##", "#.#", ".##"],
    "g": [".##", "#.#", ".##", "..#", "##."],
    "e": ["...", ".#.", "###", "#..", ".##"],
    "s": ["..", ".#", "#.", ".#", "#."],
    "+": ["...", ".#.", "###", ".#.", "..."],
    "-": ["...", "...", "###", "...", "..."],
    "−": ["...", "...", "###", "...", "..."],
    ".": [".", ".", ".", ".", "#"],
    ",": [".", ".", ".", "#", "#"],
    "/": ["..#", "..#", ".#.", "#..", "#.."],
    "×": ["...", "#.#", ".#.", "#.#", "..."],
    "%": ["#.#", "..#", ".#.", "#..", "#.#"],
    ":": [".", "#", ".", "#", "."],
    "!": ["#", "#", "#", ".", "#"],
}

# 변형: (본체 위→아래 색 목록 14px용 10줄, 7px용 5줄, 외곽선, 그림자)
VARIANTS: dict[str, dict] = {
    "gold": {
        "big": ["gold_shine", "gold_hl", "gold_hl", "gold_hl", "gold_l", "gold_l", "gold_l", "gold", "gold", "gold"],
        "small": ["gold_shine", "gold_hl", "gold_hl", "gold_l", "gold"],
        "outline": "gold_d", "shadow": "void",
    },
    "ivory": {
        "big": ["ivory"] * 5 + ["mist"] * 5,
        "small": ["ivory", "ivory", "ivory", "mist", "mist"],
        "outline": "ink", "shadow": "void",
    },
    "red": {
        "big": ["red_hl"] * 4 + ["red_l"] * 4 + ["red"] * 2,
        "small": ["red_hl", "red_hl", "red_l", "red_l", "red"],
        "outline": "red_d", "shadow": "void",
    },
    "stone": {
        "big": ["mist"] * 4 + ["stone"] * 6,
        "small": ["mist", "mist", "stone", "stone", "stone"],
        "outline": "ink", "shadow": "void",
    },
    "clover": {
        "big": ["clover"] * 5 + ["clover_d"] * 5,
        "small": ["clover", "clover", "clover", "clover_d", "clover_d"],
        "outline": "felt_d", "shadow": "void",
    },
}

BIG_LINE = 14
BIG_BASE = 12  # 외곽선(1) + 본체(10) + 외곽선(1)
SMALL_LINE = 7
SMALL_BASE = 7
DIGITS = "0123456789"


def galmuri_masks() -> dict[str, np.ndarray]:
    font = ImageFont.truetype(GALMURI_BOLD, GALMURI_BOLD_SIZE)
    masks: dict[str, np.ndarray] = {}
    for ch in BIG_CHARS:
        src = "-" if ch == "−" else ch
        img = Image.new("L", (24, 20), 0)
        ImageDraw.Draw(img).text((2, 0), src, font=font, fill=255)
        arr = np.array(img)[BODY_TOP:BODY_TOP + BODY_ROWS + DESC_ROWS] > 127
        cols = np.where(arr.any(axis=0))[0]
        if len(cols) == 0:
            continue
        masks[ch] = arr[:, cols[0]:cols[-1] + 1]
    # 0 과 O(단위 Oc·Ocd)를 구분하려고 0 가운데에 점을 찍는다(3단계 숫자 표기 점검).
    zero = masks["0"].copy()
    rows = np.where(zero.any(axis=1))[0]
    mid_row = (rows[0] + rows[-1]) // 2
    mid_col = zero.shape[1] // 2
    zero[mid_row:mid_row + 2, mid_col - (1 if zero.shape[1] % 2 == 0 else 0):mid_col + 1] = True
    masks["0"] = zero
    return masks


def small_masks() -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    for ch, rows in SMALL_GLYPHS.items():
        width = max(len(r) for r in rows)
        arr = np.zeros((5, width), dtype=bool)
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                arr[y, x] = c == "#"
        out[ch] = arr
    return out


def pad_digits(masks: dict[str, np.ndarray]) -> None:
    """숫자는 가장 넓은 숫자 폭으로 가운데 정렬해 고정폭으로 만든다."""
    width = max(masks[d].shape[1] for d in DIGITS)
    for d in DIGITS:
        m = masks[d]
        if m.shape[1] < width:
            left = (width - m.shape[1]) // 2
            padded = np.zeros((m.shape[0], width), dtype=bool)
            padded[:, left:left + m.shape[1]] = m
            masks[d] = padded


def render_glyph(mask: np.ndarray, ramp: list[str], outline: str, shadow: str | None, line: int) -> Canvas:
    rows, width = mask.shape
    canvas = Canvas(width + 2, line)
    for y in range(rows):
        for x in range(width):
            if mask[y, x] and y + 1 < line:
                canvas.px(x + 1, y + 1, ramp[min(y, len(ramp) - 1)])
    body = canvas.mask().copy()
    canvas.outline(outline)
    if shadow is not None:
        full = canvas.mask().copy()
        for y in range(line - 1, 0, -1):
            for x in range(canvas.w):
                if full[y - 1, x] and not full[y, x]:
                    canvas.px(x, y, shadow)
    del body
    return canvas


def build_font(name: str, masks: dict[str, np.ndarray], variant: dict, big: bool) -> None:
    line = BIG_LINE if big else SMALL_LINE
    base = BIG_BASE if big else SMALL_BASE
    ramp = variant["big"] if big else variant["small"]
    ramp = ramp + [ramp[-1]] * DESC_ROWS
    glyphs: dict[str, Canvas] = {}
    for ch, mask in masks.items():
        glyphs[ch] = render_glyph(mask, ramp, variant["outline"], variant["shadow"] if big else None, line)
    # 아틀라스: 한 줄 폭 256 에 차례로 배치(1px 간격)
    atlas_w = 256
    x = y = 0
    placed: dict[str, tuple[int, int]] = {}
    for ch, g in glyphs.items():
        if x + g.w > atlas_w:
            x = 0
            y += line + 1
        placed[ch] = (x, y)
        x += g.w + 1
    atlas_h = y + line
    atlas = Canvas(atlas_w, atlas_h)
    for ch, g in glyphs.items():
        atlas.blit(g, *placed[ch])
    png_rel = f"assets/fonts/{name}.png"
    atlas.save(png_rel)
    space_adv = 4 if big else 2
    lines = [
        f'info face="{name}" size={line} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight={line} base={base} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(glyphs) + 1}",
        f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={space_adv} page=0 chnl=15",
    ]
    for ch, g in glyphs.items():
        gx, gy = placed[ch]
        lines.append(
            f"char id={ord(ch)} x={gx} y={gy} width={g.w} height={g.h} xoffset=0 yoffset=0 xadvance={g.w - 1} page=0 chnl=15")
    with open(os.path.join(ROOT, "assets", "fonts", f"{name}.fnt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def build_digit_atlas(masks: dict[str, np.ndarray]) -> None:
    """3×5 숫자 10개를 가로로(각 3px, 간격 없음) 놓은 ivory 아틀라스. 코드가 digit × 3 으로 자른다."""
    atlas = Canvas(30, 5)
    for i, d in enumerate(DIGITS):
        m = masks[d]
        for y in range(5):
            for x in range(3):
                if m[y, x]:
                    atlas.px(i * 3 + x, y, "ivory")
    atlas.save("assets/sprites/ui/digits_3x5.png")


def main() -> None:
    big = galmuri_masks()
    pad_digits(big)
    small = small_masks()
    for vname, variant in VARIANTS.items():
        build_font(f"num14_{vname}", big, variant, True)
        build_font(f"num7_{vname}", small, variant, False)
    build_digit_atlas(small)
    print("fonts ok")


if __name__ == "__main__":
    main()
