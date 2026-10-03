#!/usr/bin/env python3
"""Regenerate src/tui/src/banner-pixels.ts from the header image.

Usage: python3 src/tui/scripts/gen-banner.py   (needs Pillow and numpy)

Bakes the `halfblock` look of termimg.py: the square source is cropped to a
16:9 band around the face, then run through termimg's preprocessing (background
blurred and dimmed, light blur). The TUI area-averages these pixels down to the
terminal width at startup.
"""
import base64
from pathlib import Path

import numpy as np
from PIL import Image

import termimg

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "assets" / "53575e1e-4826-4bd9-b953-f3d8f8d2a83f.png"
OUT = ROOT / "src" / "tui" / "src" / "banner-pixels.ts"

# Top of the 16:9 crop band, as a fraction of the source height.
CROP_TOP = 0.207
SIZE = (640, 360)
BG = (18, 18, 24)
# 0 = no pixel is treated as blank; the banner is drawn edge to edge.
DARK_THRESHOLD = 0


def main() -> None:
    o = termimg.parse([str(SOURCE), "--crop-aspect", "16:9", "--crop-top", str(CROP_TOP)])
    im = termimg.load(o).resize(SIZE, Image.LANCZOS)
    rgb = termimg.preprocess(np.asarray(im, dtype=np.float32), o)
    data = np.clip(np.round(rgb), 0, 255).astype(np.uint8).tobytes()
    b64 = base64.b64encode(data).decode("ascii")
    rel = SOURCE.relative_to(ROOT)
    OUT.write_text(
        f"// Auto-generated from {rel} by src/tui/scripts/gen-banner.py.\n"
        "// Regenerate: python3 src/tui/scripts/gen-banner.py\n"
        f"export const BANNER_SOURCE_WIDTH = {SIZE[0]};\n"
        f"export const BANNER_SOURCE_HEIGHT = {SIZE[1]};\n"
        f"export const BANNER_BG = {{ r: {BG[0]}, g: {BG[1]}, b: {BG[2]} }} as const;\n"
        f"export const BANNER_DARK_THRESHOLD = {DARK_THRESHOLD};\n"
        f'export const BANNER_PIXELS_RGB_BASE64 = "{b64}";\n'
    )
    print(f"wrote {OUT.relative_to(ROOT)} ({SIZE[0]}x{SIZE[1]})")


if __name__ == "__main__":
    main()
