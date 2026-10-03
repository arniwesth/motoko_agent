"""Geometry checks on a scene's picture, for an author who cannot look at the frames.

Everything here is computed from Manim's own geometry at a pose (rest() calls check()). It finds
ink that left the frame, text printed over other text, and anything in the caption's way. It
does not judge balance, crowding, colour, or whether an arrow points at the right thing.

What counts as ink: every mobject's own outline, not only its leaves (an Arrow's shaft is the
parent of its tip); a stroke's thickness, foreground or background, not only its path; the
pixels of an image that are not transparent; and text, which is the kit's T() and code() lines
or a plain Manim Text.

Text keeps its identity when Manim takes it apart. Removing one glyph from a scene replaces the
text's group by its remaining glyphs, so every glyph carries a reference to its text's record,
and glyphs found loose are put back together by it.
"""

from __future__ import annotations

import numpy as np
from manim import MarkupText, Text, VMobject, config
from manim.mobject.types.image_mobject import AbstractImageMobject

OVERLAP = 0.04  # two pieces of text overlap when they share more than this in both directions
TOUCH = 0.02  # a shape is in the caption when it shares more than this with it
MARGIN = 0.12  # text closer than this to the frame edge is "near the edge"
SMALL = 13  # text below this size is hard to read at 1080p
STROKE = 0.01  # scene units per unit of stroke_width, as the Cairo camera draws it
STEP = 0.05  # an unfilled outline is tested at points this far apart
TEXT_KINDS = ("text", "code", "caption", "header", "source")


def tag(mob, kind, text, size, ink=None):
    """Mark a mobject as one piece of text. `ink` is the submobject holding its glyphs."""
    mob.explainer_tag = {"kind": kind, "text": text, "size": size, "ink": ink,
                         "h0": mob.height or 1.0}
    _mark(mob if ink is None else mob[ink], mob.explainer_tag)


def _mark(ink, record):
    """Give each glyph its text's record, and its own size now, to measure later scaling by."""
    for glyph in ink.get_family():
        glyph.explainer_part = record
        glyph.explainer_extent = max(glyph.width, glyph.height)


def mark_plain_text(mob):
    """Give every plain Manim Text under a mobject a record its glyphs can be regrouped by."""
    for m in mob.get_family():
        if isinstance(m, (Text, MarkupText)) and not hasattr(m, "explainer_plain"):
            if getattr(m, "explainer_part", None) is not None:
                continue  # the Text inside a kit T(): its group is the text
            m.explainer_plain = {"kind": "text", "size": m.font_size, "scale": 1,
                                 "text": getattr(m, "original_text", None) or m.text}
            _mark(m, m.explainer_plain)


def _image_pixels(m):
    """(centres of an image's visible pixels as N x 2 scene points, half a pixel's box).

    The half box is (x, y): what one pixel covers along each axis once the image has been
    stretched or turned. A pixel of a stretched image is far from square, and a turned one
    reaches further along an axis than half its side.
    """
    rows, cols = m.pixel_array.shape[:2]
    seen = m.pixel_array[:, :, 3] > 5 if m.pixel_array.shape[2] == 4 else np.ones((rows, cols),
                                                                                bool)
    r, c = np.nonzero(seen)
    top_left, top_right, bottom_left = m.points[0], m.points[1], m.points[2]
    across, down = (top_right - top_left) / cols, (bottom_left - top_left) / rows
    centres = top_left + np.outer(c + 0.5, across) + np.outer(r + 0.5, down)
    half = (np.abs(across) + np.abs(down))[:2] / 2
    return centres[:, :2], half


def _image_box(m):
    """The box of an image's visible pixels, or None if every pixel is transparent."""
    centres, half = _image_pixels(m)
    if len(centres) == 0:
        return None
    return (centres[:, 0].min() - half[0], centres[:, 1].min() - half[1],
            centres[:, 0].max() + half[0], centres[:, 1].max() + half[1])


def _half_stroke(m):
    """Half the thickness of the widest visible stroke, foreground or background."""
    widths = [m.get_stroke_width(background) for background in (False, True)
              if m.get_stroke_opacity(background) > 0.02 and m.get_stroke_width(background) > 0]
    return max(widths) * STROKE / 2 if widths else 0.0


def _own(m):
    """A mobject's own ink as (box, filled, half stroke), ignoring its children; None if none."""
    if isinstance(m, AbstractImageMobject):
        box = _image_box(m) if len(m.points) else None
        return (box, True, 0.0) if box else None
    if not isinstance(m, VMobject) or len(m.points) == 0:
        return None
    filled = m.get_fill_opacity() > 0.02
    half = _half_stroke(m)
    stroked = half > 0
    xs, ys = m.points[:, 0], m.points[:, 1]
    if not stroked and (not filled or (np.ptp(xs) < 1e-6 and np.ptp(ys) < 1e-6)):
        return None  # invisible, or one of the zero-size glyphs Text keeps for whitespace
    return (xs.min() - half, ys.min() - half, xs.max() + half, ys.max() + half), filled, half


def _union(mob):
    """Bounding box of all the ink under a mobject, or None if there is none."""
    boxes = [own[0] for own in map(_own, mob.get_family()) if own]
    if not boxes:
        return None
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def _walk(mobs, loose):
    """Whole texts and separate shapes; glyphs found outside their text are put in `loose`."""
    for mob in mobs:
        info = getattr(mob, "explainer_tag", None)
        if info is not None:
            box = _union(mob if info["ink"] is None else mob[info["ink"]])
            if box:
                yield {"info": dict(info, scale=mob.height / info["h0"]), "box": box}
        elif isinstance(mob, (Text, MarkupText)):
            box = _union(mob)
            if box:
                plain = getattr(mob, "explainer_plain", None) or {
                    "kind": "text", "scale": 1,
                    "text": getattr(mob, "original_text", None) or mob.text}
                yield {"info": dict(plain, size=mob.font_size), "box": box}
        elif getattr(mob, "explainer_part", None) is not None:
            own = _own(mob)
            if own:
                part = mob.explainer_part
                was = getattr(mob, "explainer_extent", 0)
                grown = max(mob.width, mob.height) / was if was > 1e-6 else None
                boxes, scales = loose.setdefault(id(part), (part, [], []))[1:]
                boxes.append(own[0])
                if grown:
                    scales.append(grown)
            yield from _walk(mob.submobjects, loose)  # whatever else was hung on the glyph
        else:
            own = _own(mob)
            if own:
                yield {"info": None, "box": own[0], "filled": own[1], "half": own[2], "mob": mob}
            yield from _walk(mob.submobjects, loose)


def _pieces(mobs):
    """Every piece of ink in the picture: text as a whole, everything else per mobject."""
    loose = {}
    yield from _walk(mobs, loose)
    # What is left of a text some of whose glyphs were removed. Its scale is how far its glyphs
    # have grown or shrunk since they were marked.
    for part, boxes, scales in loose.values():
        box = (min(b[0] for b in boxes), min(b[1] for b in boxes),
               max(b[2] for b in boxes), max(b[3] for b in boxes))
        yield {"info": dict(part, scale=float(np.median(scales)) if scales else 1), "box": box}


def _shared(a, b):
    return min(a[2], b[2]) - max(a[0], b[0]), min(a[3], b[3]) - max(a[1], b[1])


def _outline(mob):
    """Points along a VMobject's path, close enough together that a caption cannot slip between."""
    points = []
    for curve in mob.get_cubic_bezier_tuples():
        length = sum(np.linalg.norm(curve[i + 1] - curve[i]) for i in range(3))
        t = np.linspace(0, 1, max(2, int(length / STEP) + 2))[:, None]
        points.append((1 - t) ** 3 * curve[0] + 3 * (1 - t) ** 2 * t * curve[1]
                      + 3 * (1 - t) * t ** 2 * curve[2] + t ** 3 * curve[3])
    return np.concatenate(points)[:, :2]


def _reaches(piece, box):
    """Whether a shape's ink is inside a text box: its area if filled, else its stroke."""
    dx, dy = _shared(piece["box"], box)
    if dx <= TOUCH or dy <= TOUCH:
        return False
    if isinstance(piece["mob"], AbstractImageMobject):  # its visible pixels, not its rectangle
        pts, half = _image_pixels(piece["mob"])
    elif piece["filled"]:
        return True
    else:
        pts, half = _outline(piece["mob"]), (piece["half"], piece["half"])
    inside = ((pts[:, 0] > box[0] - half[0] + TOUCH) & (pts[:, 0] < box[2] + half[0] - TOUCH)
              & (pts[:, 1] > box[1] - half[1] + TOUCH) & (pts[:, 1] < box[3] + half[1] - TOUCH))
    return bool(inside.any())


def _name(info):
    return info["text"] if len(info["text"]) <= 60 else info["text"][:57] + "..."


def check(scene):
    """Findings for the scene's current picture: (kind, severity, detail, [text, ...])."""
    half_w, half_h = config.frame_width / 2, config.frame_height / 2
    pieces = list(_pieces(scene.mobjects))
    texts = [p for p in pieces if p["info"] and p["info"]["kind"] in TEXT_KINDS]
    shapes = [p for p in pieces if p["info"] is None]
    found = []

    for piece in pieces:
        info, box = piece["info"], piece["box"]
        over = max(-half_w - box[0], box[2] - half_w, -half_h - box[1], box[3] - half_h)
        if over > 0.02:
            found.append(("off_frame", "error",
                          f"{'text' if info else 'a shape'} extends {over:.2f} past the frame",
                          [_name(info)] if info else []))
        elif info and info["kind"] in ("text", "code") and over > -MARGIN:
            found.append(("near_edge", "warning",
                          f"text is {-over:.2f} from the frame edge", [_name(info)]))

    for i, a in enumerate(texts):
        size = a["info"]["size"] * a["info"]["scale"]
        if size < SMALL and a["info"]["kind"] != "source":
            found.append(("small_text", "warning", f"set at size {size:.0f}, below {SMALL}",
                          [_name(a["info"])]))
        for b in texts[i + 1:]:
            dx, dy = _shared(a["box"], b["box"])
            if dx > OVERLAP and dy > OVERLAP:
                found.append(("text_overlap", "error",
                              f"two pieces of text overlap by {dx:.2f} x {dy:.2f}",
                              [_name(a["info"]), _name(b["info"])]))

    for caption in (t for t in texts if t["info"]["kind"] == "caption"):
        if any(_reaches(shape, caption["box"]) for shape in shapes):
            found.append(("caption_overlap", "error", "a shape reaches into the caption",
                          [_name(caption["info"])]))
    return found
