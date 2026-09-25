"""HOUSE EDGE 픽셀 에셋 생성 공용 라이브러리.

- 팔레트는 ART_BIBLE.md 3장 / scripts/core/palette.gd 와 같은 36색이다.
- Canvas 는 RGBA numpy 배열이다. 저장할 때 팔레트 밖 색(알파 0 제외)이 있으면 실패한다.
- 모든 스크립트는 저장과 함께 build/art_preview/ 에 4배 확대 미리보기를 남긴다(커밋하지 않음).
"""
from __future__ import annotations

import math
import os
import random
from typing import Iterable

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PREVIEW_DIR = os.path.join(ROOT, "build", "art_preview")
PREVIEW_SCALE = 4

PALETTE: dict[str, str] = {
    "void": "#0b0a14", "night": "#16142a", "dusk": "#221e3d", "shadow": "#2f2a52",
    "ink": "#3e3a4f", "stone": "#6e6882", "mist": "#b8b2c4", "ivory": "#f4f0e8",
    "felt_d": "#0f3d2e", "felt": "#16573f", "felt_l": "#1f7552", "felt_hl": "#2c9468",
    "wood_d": "#3b2218", "wood": "#5c3524", "wood_l": "#83502f", "wood_hl": "#a8703f",
    "gold_d": "#6b4a12", "gold": "#a8781c", "gold_l": "#e0ac2c", "gold_hl": "#ffd95a", "gold_shine": "#fff2b0",
    "red_d": "#4a0f1a", "red": "#8a1a2b", "red_l": "#c9303c", "red_hl": "#f25a5a",
    "pocket_k": "#121016", "pocket_k_l": "#26222e",
    "neon_pink": "#ff4fa3", "neon_cyan": "#3fe0ff", "neon_purple": "#7b3fe0", "purple_d": "#3d1f73",
    "clover": "#5ee06b", "clover_d": "#2a9e3a",
    "sky": "#2b4a8f", "water": "#1b3a5c", "amber": "#ff9a3c",
}


def rgb(name: str) -> tuple[int, int, int]:
    value = PALETTE[name].lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


PALETTE_RGB = {name: rgb(name) for name in PALETTE}
_PALETTE_SET = set(PALETTE_RGB.values())
assert len(PALETTE) == 36 and len(_PALETTE_SET) == 36, "팔레트는 중복 없는 36색"


class Canvas:
    """RGBA 캔버스. 좌표는 (x, y), 원점 좌상단."""

    def __init__(self, width: int, height: int, fill: str | None = None, alpha: int = 255):
        self.w = width
        self.h = height
        self.a = np.zeros((height, width, 4), dtype=np.uint8)
        if fill is not None:
            self.a[:, :, :3] = rgb(fill)
            self.a[:, :, 3] = alpha

    # ── 기본 ─────────────────────────────────────────────
    def inside(self, x: int, y: int) -> bool:
        return 0 <= x < self.w and 0 <= y < self.h

    def px(self, x: int, y: int, name: str, alpha: int = 255) -> None:
        x = int(x)
        y = int(y)
        if self.inside(x, y):
            self.a[y, x, :3] = rgb(name)
            self.a[y, x, 3] = alpha

    def get(self, x: int, y: int) -> tuple[int, int, int, int]:
        return tuple(int(v) for v in self.a[y, x])

    def is_set(self, x: int, y: int) -> bool:
        return self.inside(x, y) and self.a[y, x, 3] > 0

    def clear_px(self, x: int, y: int) -> None:
        if self.inside(x, y):
            self.a[y, x] = 0

    def rect(self, x: int, y: int, w: int, h: int, name: str, alpha: int = 255) -> None:
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.w, x + w), min(self.h, y + h)
        if x1 <= x0 or y1 <= y0:
            return
        self.a[y0:y1, x0:x1, :3] = rgb(name)
        self.a[y0:y1, x0:x1, 3] = alpha

    def hline(self, x0: int, x1: int, y: int, name: str, alpha: int = 255) -> None:
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.px(x, y, name, alpha)

    def vline(self, x: int, y0: int, y1: int, name: str, alpha: int = 255) -> None:
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.px(x, y, name, alpha)

    def outline_rect(self, x: int, y: int, w: int, h: int, name: str) -> None:
        self.hline(x, x + w - 1, y, name)
        self.hline(x, x + w - 1, y + h - 1, name)
        self.vline(x, y, y + h - 1, name)
        self.vline(x + w - 1, y, y + h - 1, name)

    def blit(self, other: "Canvas", x: int, y: int) -> None:
        """알파 0 이 아닌 픽셀만 덮어쓴다(합성하지 않음)."""
        for yy in range(other.h):
            for xx in range(other.w):
                if other.a[yy, xx, 3] > 0 and self.inside(x + xx, y + yy):
                    self.a[y + yy, x + xx] = other.a[yy, xx]

    def pattern(self, x: int, y: int, rows: list[str], colors: dict[str, str]) -> None:
        """문자 패턴을 그린다. '.' 와 ' ' 는 건너뛴다."""
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch in colors:
                    self.px(x + dx, y + dy, colors[ch])

    def mask(self) -> np.ndarray:
        return self.a[:, :, 3] > 0

    def outline(self, name: str, diagonal: bool = False) -> None:
        """불투명 픽셀 둘레(4방향, diagonal 이면 8방향)에 외곽선을 두른다."""
        m = self.mask()
        padded = np.pad(m, 1)
        out = np.zeros_like(m)
        shifts = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            shifts += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        for dx, dy in shifts:
            out |= padded[1 + dy:1 + dy + self.h, 1 + dx:1 + dx + self.w]
        out &= ~m
        self.a[out, :3] = rgb(name)
        self.a[out, 3] = 255

    # ── 저장 ─────────────────────────────────────────────
    def validate(self, label: str) -> None:
        opaque = self.a[:, :, 3] > 0
        colors = {tuple(int(c) for c in v) for v in self.a[opaque][:, :3]}
        bad = colors - _PALETTE_SET
        if bad:
            sample = ", ".join("#%02x%02x%02x" % c for c in list(bad)[:5])
            raise ValueError(f"{label}: 팔레트 밖 색 {len(bad)}개 ({sample})")

    def save(self, rel_path: str, preview: bool = True) -> str:
        path = os.path.join(ROOT, rel_path)
        self.validate(rel_path)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        Image.fromarray(self.a, "RGBA").save(path, optimize=True)
        if preview:
            save_preview(self, rel_path)
        return path


def save_preview(canvas: Canvas, rel_path: str) -> None:
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    bg = np.zeros((canvas.h, canvas.w, 4), dtype=np.uint8)
    # 투명 부분은 체커로 보이게
    for y in range(canvas.h):
        for x in range(canvas.w):
            bg[y, x] = (40, 40, 48, 255) if (x // 4 + y // 4) % 2 == 0 else (56, 56, 64, 255)
    img = Image.alpha_composite(Image.fromarray(bg, "RGBA"), Image.fromarray(canvas.a, "RGBA"))
    img = img.resize((canvas.w * PREVIEW_SCALE, canvas.h * PREVIEW_SCALE), Image.NEAREST)
    name = rel_path.replace("/", "__")
    img.save(os.path.join(PREVIEW_DIR, name))


# ── 도형 도우미 ──────────────────────────────────────────

def disc_mask(radius: float, cx: float, cy: float, w: int, h: int) -> np.ndarray:
    """픽셀 중심 (x+0.5, y+0.5) 가 원 안에 있으면 True."""
    ys, xs = np.mgrid[0:h, 0:w]
    return (xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2 <= radius * radius


def polar(w: int, h: int, cx: float, cy: float) -> tuple[np.ndarray, np.ndarray]:
    """각 픽셀 중심의 (반지름, 각도[라디안, -pi..pi, 화면 좌표])."""
    ys, xs = np.mgrid[0:h, 0:w]
    dx = xs + 0.5 - cx
    dy = ys + 0.5 - cy
    return np.sqrt(dx * dx + dy * dy), np.arctan2(dy, dx)


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 + 1.0 / 32.0


def dither_pick(value: float, x: int, y: int, ramp: list[str]) -> str:
    """0..1 값을 ramp 색 단계로 4×4 Bayer 디더링해 고른다."""
    value = min(max(value, 0.0), 1.0) * (len(ramp) - 1)
    base = int(math.floor(value))
    frac = value - base
    if base >= len(ramp) - 1:
        return ramp[-1]
    return ramp[base + 1] if frac > BAYER4[y % 4, x % 4] else ramp[base]


def band_pick(value: float, ramp: list[str]) -> str:
    """디더링 없이 단계로 나눈다(셀 셰이딩)."""
    value = min(max(value, 0.0), 0.9999)
    return ramp[int(value * len(ramp))]


def seeded(seed: int) -> random.Random:
    return random.Random(seed)


def fill_polygon(canvas: Canvas, points: Iterable[tuple[float, float]], name: str, alpha: int = 255) -> None:
    pts = list(points)
    for y in range(canvas.h):
        cy = y + 0.5
        xs: list[float] = []
        for i in range(len(pts)):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % len(pts)]
            if (y0 <= cy < y1) or (y1 <= cy < y0):
                xs.append(x0 + (cy - y0) * (x1 - x0) / (y1 - y0))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            for x in range(int(math.ceil(xs[i] - 0.5)), int(math.floor(xs[i + 1] - 0.5)) + 1):
                canvas.px(x, y, name, alpha)
