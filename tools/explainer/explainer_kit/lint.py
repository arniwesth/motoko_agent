"""Geometry checks on a scene's picture, for an author who cannot look at the frames.

Everything here is computed from Manim's own geometry at a pose (rest() calls check()). It finds
ink that left the frame, text printed over other text, and anything in the caption's way. It
does not judge balance, crowding, colour, or whether an arrow points at the right thing.

What counts as ink: every mobject's own outline, not only its leaves (an Arrow's shaft is the
parent of its tip); a stroke's thickness, not only its path; images; and text, which is the kit's
T() and code() lines or a plain Manim Text.
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


def _own(m):
    """A mobject's own ink as (box, filled, half stroke), ignoring its children; None if none."""
    if isinstance(m, AbstractImageMobject):
        if len(m.points) == 0 or getattr(m, "fill_opacity", 1) <= 0.02:
            return None
        xs, ys = m.points[:, 0], m.points[:, 1]
        return (xs.min(), ys.min(), xs.max(), ys.max()), True, 0.0
    if not isinstance(m, VMobject) or len(m.points) == 0:
        return None
    filled = m.get_fill_opacity() > 0.02
    stroked = m.get_stroke_opacity() > 0.02 and m.get_stroke_width() > 0
    half = m.get_stroke_width() * STROKE / 2 if stroked else 0.0
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


def _pieces(mobs):
    """Every piece of ink in the picture: text as a whole, everything else per mobject."""
    for mob in mobs:
        info = getattr(mob, "explainer_tag", None)
        if info is not None:
            box = _union(mob if info["ink"] is None else mob[info["ink"]])
            if box:
                yield {"info": dict(info, scale=mob.height / info["h0"]), "box": box}
        elif isinstance(mob, (Text, MarkupText)):
            box = _union(mob)
            if box:
                text = getattr(mob, "original_text", None) or getattr(mob, "text", "")
                yield {"info": {"kind": "text", "text": text, "size": mob.font_size, "scale": 1},
                       "box": box}
        else:
            own = _own(mob)
            if own:
                yield {"info": None, "box": own[0], "filled": own[1], "half": own[2], "mob": mob}
            yield from _pieces(mob.submobjects)


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
    if piece["filled"]:
        return True
    half, pts = piece["half"], _outline(piece["mob"])
    inside = ((pts[:, 0] > box[0] - half + TOUCH) & (pts[:, 0] < box[2] + half - TOUCH)
              & (pts[:, 1] > box[1] - half + TOUCH) & (pts[:, 1] < box[3] + half - TOUCH))
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
