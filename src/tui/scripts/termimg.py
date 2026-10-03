#!/usr/bin/env python3
"""Prototype terminal image renderer: Braille / quadrant / half-block / ASCII.

Usage:
  python3 src/tui/scripts/termimg.py IMAGE --mode braille-color --width 100
  python3 src/tui/scripts/termimg.py IMAGE --compare            # all modes, stacked
  python3 src/tui/scripts/termimg.py IMAGE --mode braille --png out.png

Needs Pillow and numpy. Blur radii are in Braille-dot units (half a cell wide),
so the same settings behave the same at every --width.
"""
import argparse
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

MODES = ["current", "ascii", "halfblock", "quadrant", "braille", "braille-color"]
TERM_BG = (18, 18, 24)
ASCII_RAMP = " .:-=+*#%@"
# Quadrant glyph per 4-bit mask: bit0 = top-left, bit1 = top-right,
# bit2 = bottom-left, bit3 = bottom-right.
QUADRANTS = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"
# Unicode numbers Braille dots down the left column (1,2,3,7) then down the
# right (4,5,6,8), so the bit for (row, col) is not row-major. U+2800 + bits.
BRAILLE_BITS = np.array([[0x01, 0x08], [0x02, 0x10], [0x04, 0x20], [0x40, 0x80]])
# Working image is this many pixels per Braille dot, before area-downsampling.
SUPERSAMPLE = 2


# ---------------------------------------------------------------- preprocessing

def luminance(rgb):
    return (rgb @ np.array([0.2126, 0.7152, 0.0722])) / 255.0


def brightness(rgb, value_mix):
    """Luma under-rates saturated blue and magenta, which is exactly the rim
    lighting here, so blend it with the HSV value (max channel)."""
    return (1 - value_mix) * luminance(rgb) + value_mix * rgb.max(axis=-1) / 255.0


def gaussian(rgb, sigma):
    if sigma <= 0:
        return rgb
    im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(sigma)), dtype=np.float32)


def bilateral(rgb, sigma_space, sigma_color=28.0):
    """Edge-preserving smoothing: flattens texture, keeps strong colour edges."""
    if sigma_space <= 0:
        return rgb
    r = max(1, int(round(sigma_space * 2)))
    acc = np.zeros_like(rgb)
    wsum = np.zeros(rgb.shape[:2], dtype=np.float32)
    pad = np.pad(rgb, ((r, r), (r, r), (0, 0)), mode="edge")
    h, w = rgb.shape[:2]
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            shifted = pad[r + dy:r + dy + h, r + dx:r + dx + w]
            dist = np.sum((shifted - rgb) ** 2, axis=2)
            wgt = np.exp(-(dx * dx + dy * dy) / (2 * sigma_space ** 2)
                         - dist / (2 * sigma_color ** 2 * 3))
            acc += shifted * wgt[..., None]
            wsum += wgt
    return acc / wsum[..., None]


def subject_mask(h, w, spec, feather):
    """Soft elliptical mask, 1 inside the subject and 0 in the background."""
    cx, cy, rx, ry = spec
    ys, xs = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xs / w - cx) / rx) ** 2 + ((ys / h - cy) / ry) ** 2)
    return np.clip((1.0 - d) / max(feather, 1e-6) + 0.5, 0.0, 1.0).astype(np.float32)


def preprocess(rgb, o):
    """rgb: float32 HxWx3 at SUPERSAMPLE px per Braille dot."""
    s = SUPERSAMPLE
    if o.contrast != 1.0:
        rgb = np.clip((rgb - 128.0) * o.contrast + 128.0, 0, 255)
    rgb = bilateral(rgb, o.smooth * s)
    if o.background_detail < 1.0 or o.background_dim < 1.0:
        mask = subject_mask(rgb.shape[0], rgb.shape[1], o.subject, o.feather)[..., None]
        bg = gaussian(rgb, (1.0 - o.background_detail) * 6.0 * s) * o.background_dim
        rgb = rgb * mask + bg * (1.0 - mask)
    rgb = gaussian(rgb, o.blur * s)
    if o.colors > 0:
        im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
        im = im.quantize(o.colors, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
        rgb = np.asarray(im, dtype=np.float32)
    if o.posterize > 1:
        lum = luminance(rgb)
        target = np.round(lum * (o.posterize - 1)) / (o.posterize - 1)
        rgb = np.clip(rgb * (target / np.maximum(lum, 1e-3))[..., None], 0, 255)
    return rgb


def load(o):
    im = Image.open(o.image).convert("RGB")
    if o.crop_aspect:
        aw, ah = (float(v) for v in o.crop_aspect.split(":"))
        ch = min(im.height, round(im.width * ah / aw))
        top = min(im.height - ch, round(im.height * o.crop_top))
        im = im.crop((0, top, im.width, top + ch))
    return im


def grid(rgb, cols, rows, per_x, per_y):
    """Area-average the working image down to cols*per_x by rows*per_y."""
    im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    im = im.resize((cols * per_x, rows * per_y), Image.BOX)
    return np.asarray(im, dtype=np.float32)


def cells(a, per_y, per_x):
    """HxW[xC] -> rows x cols x per_y x per_x [x C]."""
    h, w = a.shape[:2]
    a = a.reshape(h // per_y, per_y, w // per_x, per_x, *a.shape[2:])
    return a.swapaxes(1, 2)


# ------------------------------------------------------------------- rendering

class Line:
    """One output row; emits an SGR sequence only when a colour changes."""

    def __init__(self):
        self.out, self.fg, self.bg = [], None, None

    def put(self, ch, fg=None, bg=None):
        if ch == " " and bg is None and self.bg is None:
            self.out.append(" ")  # blank on the default background: no escapes
            return
        if bg != self.bg:
            self.out.append("\x1b[49m" if bg is None else "\x1b[48;2;%d;%d;%dm" % bg)
            self.bg = bg
        if fg is not None and fg != self.fg:
            self.out.append("\x1b[38;2;%d;%d;%dm" % fg)
            self.fg = fg
        self.out.append(ch)

    def text(self):
        s = "".join(self.out).rstrip(" ")
        return s + "\x1b[0m" if "\x1b" in s else s


def rgb_t(v):
    return tuple(int(c) for c in np.clip(np.round(v), 0, 255))


def despeckle(on, min_neighbours):
    """Drop lit dots with fewer than min_neighbours lit dots around them."""
    if min_neighbours <= 0:
        return on
    p = np.pad(on.astype(np.int8), 1)
    h, w = on.shape
    count = sum(p[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    return on & (count >= min_neighbours)


def dot_mask(lum, o):
    """lum: HxW in 0..1 at Braille-dot resolution -> boolean dots."""
    if o.normalize:
        lo, hi = np.percentile(lum, [2, 98])
        lum = np.clip((lum - lo) / max(hi - lo, 1e-6), 0, 1)
    if o.threshold_mode == "fixed":
        on = lum > o.threshold
        if o.detail > 0:
            # Carve dark features (eyes, visor frame) back out of lit areas:
            # drop dots that sit well below their small-neighbourhood mean.
            im = Image.fromarray((lum * 255).astype(np.uint8))
            local = np.asarray(im.filter(ImageFilter.GaussianBlur(o.detail_radius)),
                               dtype=np.float32) / 255.0
            on &= lum > local * (1.0 - o.detail)
        return despeckle(on, o.despeckle)
    if o.threshold_mode == "adaptive":
        im = Image.fromarray((lum * 255).astype(np.uint8))
        local = np.asarray(im.filter(ImageFilter.GaussianBlur(o.adaptive_radius)),
                           dtype=np.float32) / 255.0
        return lum > (1 - o.adaptive_mix) * o.threshold + o.adaptive_mix * local
    # "cell": split each cell at its own mean so edges are traced; cells with
    # no real contrast fall back to the fixed threshold (all on or all off).
    c = cells(lum, 4, 2)
    mean = c.mean(axis=(2, 3), keepdims=True)
    flat = (c.max(axis=(2, 3), keepdims=True) - c.min(axis=(2, 3), keepdims=True)) < o.cell_contrast
    on = np.where(flat, mean > o.threshold, (c > mean) & (c > o.threshold * 0.5))
    return on.swapaxes(1, 2).reshape(lum.shape)


def vivid(color, amount):
    """Push a colour toward full brightness; dot density carries the tone."""
    peak = max(color.max(), 1.0)
    return color * ((1 - amount) + amount * 255.0 / peak)


def render_braille(rgb, cols, rows, o, color):
    g = grid(rgb, cols, rows, 2, 4)
    on = cells(dot_mask(brightness(g, o.value_mix), o), 4, 2)
    gc = cells(g, 4, 2)
    bits = (on * BRAILLE_BITS).sum(axis=(2, 3))
    lines = []
    for y in range(rows):
        line = Line()
        for x in range(cols):
            if not bits[y, x]:
                line.put(" ")
                continue
            fg = None
            if color:
                fg = rgb_t(vivid(gc[y, x][on[y, x]].mean(axis=0), o.vivid))
                if o.color_step > 1:
                    fg = tuple(min(255, c // o.color_step * o.color_step + o.color_step // 2) for c in fg)
            line.put(chr(0x2800 + int(bits[y, x])), fg)
        lines.append(line.text())
    return lines


def render_quadrant(rgb, cols, rows, o):
    g = grid(rgb, cols, rows, 2, 2)
    gc, lc = cells(g, 2, 2), cells(luminance(g), 2, 2)
    weights = np.array([[1, 2], [4, 8]])
    lines = []
    for y in range(rows):
        line = Line()
        for x in range(cols):
            px, lum = gc[y, x], lc[y, x]
            hi = lum > lum.mean()
            if lum.max() - lum.min() < 0.04 or not hi.any() or hi.all():
                line.put(" ", bg=rgb_t(px.mean(axis=(0, 1))))
                continue
            line.put(QUADRANTS[int((hi * weights).sum())],
                     rgb_t(px[hi].mean(axis=0)), rgb_t(px[~hi].mean(axis=0)))
        lines.append(line.text())
    return lines


def render_halfblock(rgb, cols, rows, o):
    g = grid(rgb, cols, rows, 1, 2)
    lines = []
    for y in range(rows):
        line = Line()
        for x in range(cols):
            line.put("▀", rgb_t(g[2 * y, x]), rgb_t(g[2 * y + 1, x]))
        lines.append(line.text())
    return lines


def render_ascii(rgb, cols, rows, o):
    lum = luminance(grid(rgb, cols, rows, 1, 1))
    lo, hi = np.percentile(lum, [2, 98])
    lum = np.clip((lum - lo) / max(hi - lo, 1e-6), 0, 1)
    idx = np.minimum((lum * len(ASCII_RAMP)).astype(int), len(ASCII_RAMP) - 1)
    return ["".join(ASCII_RAMP[i] for i in row).rstrip() for row in idx]


def render_current(im, cols, rows):
    """Port of src/tui/src/banner-runtime.ts: nearest-neighbour half-blocks."""
    src = np.asarray(im.resize((640, round(640 * im.height / im.width)), Image.LANCZOS))
    sh, sw = src.shape[:2]
    lines = []
    for y in range(rows):
        line = Line()
        for x in range(cols):
            sx = min(sw - 1, int((x + 0.5) * sw / cols))
            top = src[min(sh - 1, int((2 * y + 0.5) * sh / (rows * 2))), sx]
            bot = src[min(sh - 1, int((2 * y + 1.5) * sh / (rows * 2))), sx]
            dt, db = top.max() < 20, bot.max() < 20
            if dt and db:
                line.put(" ", bg=TERM_BG)
            elif dt:
                line.put("▄", rgb_t(bot), TERM_BG)
            elif db:
                line.put("▀", rgb_t(top), TERM_BG)
            else:
                line.put("▀", rgb_t(top), rgb_t(bot))
        lines.append(line.text())
    return lines


def render(o, mode):
    im = load(o)
    cols = o.width
    rows = max(1, round(cols * im.height / im.width * o.cell_aspect))
    if mode == "current":
        return render_current(im, cols, rows)
    work = im.resize((cols * 2 * SUPERSAMPLE, rows * 4 * SUPERSAMPLE), Image.LANCZOS)
    rgb = preprocess(np.asarray(work, dtype=np.float32), o)
    if mode == "ascii":
        return render_ascii(rgb, cols, rows, o)
    if mode == "halfblock":
        return render_halfblock(rgb, cols, rows, o)
    if mode == "quadrant":
        return render_quadrant(rgb, cols, rows, o)
    return render_braille(rgb, cols, rows, o, color=(mode == "braille-color"))


# --------------------------------------------------------------------- preview

SGR = re.compile(r"\x1b\[([0-9;]*)m")


def to_png(lines, path, cell=(10, 20)):
    """Rasterise ANSI output roughly as a terminal would, for inspection."""
    cw, ch = cell
    cols = max(len(SGR.sub("", l)) for l in lines)
    img = Image.new("RGB", (cols * cw, len(lines) * ch), TERM_BG)
    d = ImageDraw.Draw(img)
    font = None
    default_fg = (200, 200, 210)
    for y, text in enumerate(lines):
        fg, bg, x, pos = default_fg, None, 0, 0
        while pos < len(text):
            m = SGR.match(text, pos)
            if m:
                p = [int(v) for v in m.group(1).split(";") if v]
                if p[:2] == [38, 2]:
                    fg = tuple(p[2:5])
                elif p[:2] == [48, 2]:
                    bg = tuple(p[2:5])
                elif p == [49]:
                    bg = None
                elif p in ([0], []):
                    fg, bg = default_fg, None
                pos = m.end()
                continue
            c, x0, y0 = text[pos], x * cw, y * ch
            pos, x = pos + 1, x + 1
            if bg:
                d.rectangle([x0, y0, x0 + cw - 1, y0 + ch - 1], fill=bg)
            code = ord(c)
            if 0x2800 <= code <= 0x28FF:
                r = cw * 0.19
                for row in range(4):
                    for col in range(2):
                        if (code - 0x2800) & int(BRAILLE_BITS[row, col]):
                            px, py = x0 + cw * (0.25 + 0.5 * col), y0 + ch * (0.125 + 0.25 * row)
                            d.ellipse([px - r, py - r, px + r, py + r], fill=fg)
            elif c in QUADRANTS and c != " ":
                q = QUADRANTS.index(c)
                for bit, (qx, qy) in enumerate([(0, 0), (1, 0), (0, 1), (1, 1)]):
                    if q >> bit & 1:
                        d.rectangle([x0 + qx * cw // 2, y0 + qy * ch // 2,
                                     x0 + (qx + 1) * cw // 2 - 1 if qx == 0 else x0 + cw - 1,
                                     y0 + (qy + 1) * ch // 2 - 1 if qy == 0 else y0 + ch - 1], fill=fg)
            elif c != " ":
                font = font or ImageFont.truetype("DejaVuSansMono.ttf", int(ch * 0.8))
                d.text((x0, y0), c, fill=fg, font=font)
    img.save(path)


# ------------------------------------------------------------------------- cli

def parse(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("image")
    p.add_argument("--mode", choices=MODES, default="braille-color")
    p.add_argument("--compare", action="store_true", help="render every mode, stacked with labels")
    p.add_argument("--width", type=int, default=100, help="output width in terminal columns")
    p.add_argument("--cell-aspect", type=float, default=0.5, help="terminal cell width / height")
    p.add_argument("--crop-aspect", default="", help="crop to W:H before rendering, e.g. 16:9")
    p.add_argument("--crop-top", type=float, default=0.0, help="top of the crop, as a fraction of image height")
    p.add_argument("--threshold", type=float, default=0.45, help="dot-on luminance threshold, 0..1")
    p.add_argument("--threshold-mode", choices=["fixed", "adaptive", "cell"], default="fixed")
    p.add_argument("--value-mix", type=float, default=1.0,
                   help="dot brightness: 0 = luma, 1 = max channel (keeps saturated neon)")
    p.add_argument("--detail", type=float, default=0.2,
                   help="fixed mode: drop dots this fraction below the local mean (0 = off)")
    p.add_argument("--detail-radius", type=float, default=4.0, help="local-mean radius for --detail, in dots")
    p.add_argument("--despeckle", type=int, default=3,
                   help="fixed mode: drop dots with fewer lit neighbours than this (0 = off)")
    p.add_argument("--adaptive-radius", type=float, default=8.0, help="local-mean radius in dots")
    p.add_argument("--adaptive-mix", type=float, default=0.5, help="0 = fixed threshold, 1 = pure local mean")
    p.add_argument("--cell-contrast", type=float, default=0.12, help="cell mode: range below which a cell is flat")
    p.add_argument("--no-normalize", dest="normalize", action="store_false",
                   help="threshold raw luminance instead of stretching it to the 2..98 percentile range")
    p.add_argument("--blur", type=float, default=0.5, help="Gaussian blur sigma, in dots")
    p.add_argument("--smooth", type=float, default=0.0, help="edge-preserving (bilateral) smoothing sigma, in dots")
    p.add_argument("--contrast", type=float, default=1.1)
    p.add_argument("--colors", type=int, default=0, help="quantise to N colours (0 = off)")
    p.add_argument("--posterize", type=int, default=0, help="quantise luminance to N levels (0 = off)")
    p.add_argument("--background-detail", type=float, default=0.2, help="1 = keep background, 0 = blur it away")
    p.add_argument("--background-dim", type=float, default=0.5, help="multiply background brightness")
    p.add_argument("--subject", type=lambda s: tuple(float(v) for v in s.split(",")),
                   default=(0.5, 0.5, 0.36, 0.62), help="subject ellipse cx,cy,rx,ry as image fractions")
    p.add_argument("--feather", type=float, default=0.35, help="softness of the subject ellipse edge")
    p.add_argument("--vivid", type=float, default=0.6, help="0 = source colour, 1 = full-brightness hue")
    p.add_argument("--color-step", type=int, default=8, help="round colours to this step to cut escape codes")
    p.add_argument("--png", default="", help="also rasterise the output to this PNG")
    return p.parse_args(argv)


def main():
    o = parse()
    lines = []
    for mode in (MODES if o.compare else [o.mode]):
        if o.compare:
            lines += ["", "== %s ==" % mode]
        lines += render(o, mode)
    sys.stdout.write("\n".join(lines) + "\n")
    if o.png:
        to_png(lines, o.png)


if __name__ == "__main__":
    main()
