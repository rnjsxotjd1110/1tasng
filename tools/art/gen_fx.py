"""연출용 글자 스프라이트.

  python3 tools/art/gen_fx.py

  assets/sprites/fx/neon_pink.png / neon_cyan.png + neon_letters.json
      네온 글자 아틀라스. 윗줄 = 켜짐(흰 심지 + 색 테두리 + 번짐), 아랫줄 = 꺼짐(어두운 유리관).
      json: {"cell": [w, h], "chars": {"B": [x, advance], ...}}  (x 는 셀 왼쪽, 글자는 셀 안 왼쪽 정렬)
  assets/sprites/fx/jackpot_letters.png + jackpot_letters.json
      JACKPOT 금 글자(Galmuri11 Bold ×2, 그라데이션·외곽선·그림자)
글자 모양은 Galmuri11 Bold(OFL) 에서 가져와 정수 2배로 키운다.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import ROOT, Canvas  # noqa: E402

FONT = os.path.join(ROOT, "assets", "fonts", "Galmuri11-Bold.ttf")
OUT = "assets/sprites/fx"
NEON_CHARS = "BIGWN!LUCKYOPEA"
JACKPOT_CHARS = "JACKPOT"
SCALE = 2
JACKPOT_SCALE = 3
PAD = 3


def glyph_mask(ch: str, scale: int = SCALE) -> np.ndarray:
    font = ImageFont.truetype(FONT, 12)
    img = Image.new("L", (24, 20), 0)
    ImageDraw.Draw(img).text((2, 0), ch, font=font, fill=255)
    arr = np.array(img)[1:11] > 127
    cols = np.where(arr.any(axis=0))[0]
    arr = arr[:, cols[0]:cols[-1] + 1]
    return np.kron(arr, np.ones((scale, scale), dtype=bool))


def dilate(m: np.ndarray, r: int) -> np.ndarray:
    out = m.copy()
    padded = np.pad(m, r)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= padded[r + dy:r + dy + m.shape[0], r + dx:r + dx + m.shape[1]]
    return out


def neon_atlas(color: str, dark: str, name: str) -> dict:
    masks = {ch: glyph_mask(ch) for ch in NEON_CHARS}
    cell_h = 10 * SCALE + PAD * 2
    cell_w = max(m.shape[1] for m in masks.values()) + PAD * 2
    atlas = Canvas(cell_w * len(NEON_CHARS), cell_h * 2)
    info = {"cell": [cell_w, cell_h], "chars": {}}
    for i, ch in enumerate(NEON_CHARS):
        m = masks[ch]
        full = np.zeros((cell_h, cell_w), dtype=bool)
        full[PAD:PAD + m.shape[0], PAD:PAD + m.shape[1]] = m
        inner = full & ~dilate(~full, 1)
        halo1 = dilate(full, 1) & ~full
        halo2 = dilate(full, 2) & ~dilate(full, 1)
        halo3 = dilate(full, 3) & ~dilate(full, 2)
        x0 = i * cell_w
        for y in range(cell_h):
            for x in range(cell_w):
                if inner[y, x]:
                    atlas.px(x0 + x, y, "ivory")
                    atlas.px(x0 + x, cell_h + y, dark)
                elif full[y, x]:
                    atlas.px(x0 + x, y, color)
                    atlas.px(x0 + x, cell_h + y, "void")
                elif halo1[y, x]:
                    atlas.px(x0 + x, y, color, 120)
                elif halo2[y, x]:
                    atlas.px(x0 + x, y, color, 55)
                elif halo3[y, x]:
                    atlas.px(x0 + x, y, color, 22)
        info["chars"][ch] = [x0, m.shape[1] + SCALE]
    atlas.save(f"{OUT}/{name}.png")
    return info


def jackpot() -> None:
    rows = 10 * JACKPOT_SCALE
    ramp = (["gold_shine"] * 3 + ["gold_hl"] * 8 + ["gold_l"] * 9 + ["gold"] * 7 + ["gold_d"] * 3)[:rows]
    masks = {ch: glyph_mask(ch, JACKPOT_SCALE) for ch in JACKPOT_CHARS}
    cell_h = rows + 2 + 3
    cell_w = max(m.shape[1] for m in masks.values()) + 4
    atlas = Canvas(cell_w * len(JACKPOT_CHARS), cell_h)
    info = {"cell": [cell_w, cell_h], "chars": {}}
    for i, ch in enumerate(JACKPOT_CHARS):
        m = masks[ch]
        g = Canvas(cell_w, cell_h)
        for y in range(m.shape[0]):
            for x in range(m.shape[1]):
                if m[y, x]:
                    g.px(x + 1, y + 1, ramp[y])
        # 좌상단 1px 하이라이트
        for y in range(m.shape[0]):
            for x in range(m.shape[1]):
                if m[y, x] and (y == 0 or not m[y - 1, x]):
                    g.px(x + 1, y + 1, "gold_shine")
        g.outline("wood_d")
        full = g.mask().copy()
        for y in range(cell_h - 1, 2, -1):
            for x in range(cell_w):
                if full[y - 3, x] and not g.mask()[y, x] and y >= 3:
                    g.px(x, y, "void")
        atlas.blit(g, i * cell_w, 0)
        info["chars"][ch] = [i * cell_w, m.shape[1] + 2]
    atlas.save(f"{OUT}/jackpot_letters.png")
    with open(os.path.join(ROOT, OUT, "jackpot_letters.json"), "w") as f:
        json.dump(info, f)


def main() -> None:
    info = neon_atlas("neon_pink", "purple_d", "neon_pink")
    neon_atlas("neon_cyan", "water", "neon_cyan")
    with open(os.path.join(ROOT, OUT, "neon_letters.json"), "w") as f:
        json.dump(info, f)
    jackpot()
    print("fx ok")


if __name__ == "__main__":
    main()
