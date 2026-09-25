"""앱 아이콘(8단계 5/N, ART_BIBLE 17장). 타이틀의 미니 룰렛 휠(gen_title.py)과 같은 그림을 재사용해
16×16 원본을 정수 16배(256px)로 키운다 — 소수 배율 금지 규칙을 아이콘에도 그대로 적용.

  python3 tools/art/gen_app_icon.py

  assets/icon.png        256×256, project.godot 의 application/config/icon
  assets/icon.ico        16/32/48/256px 다중 해상도, 윈도우 내보내기 아이콘(docs/STEAM.md)
"""
from __future__ import annotations

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import ROOT  # noqa: E402
from gen_title import _wheel_frame  # noqa: E402

OUT = "assets"
SCALE = 16
ICO_SIZES = [16, 32, 48, 64, 128, 256]


def main() -> None:
    frame = _wheel_frame(0.0)
    img = Image.fromarray(frame.a, "RGBA")
    big = img.resize((frame.w * SCALE, frame.h * SCALE), Image.NEAREST)
    png_path = os.path.join(ROOT, OUT, "icon.png")
    big.save(png_path)
    ico_path = os.path.join(ROOT, OUT, "icon.ico")
    big.save(ico_path, sizes=[(s, s) for s in ICO_SIZES])
    print("saved", png_path, "and", ico_path)


if __name__ == "__main__":
    main()
