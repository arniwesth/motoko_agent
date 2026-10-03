"""Geometry checks on a scene's picture, for an author who cannot look at the frames.

Everything here is computed from Manim's own bounding boxes at a pose (rest() calls check()).
It finds text that left the frame, text printed over other text, and anything in the caption's
way. It does not judge balance, crowding, colour, or whether an arrow points at the right thing.
"""

from __future__ import annotations

from manim import VMobject, config

OVERLAP = 0.04  # two boxes overlap when they share more than this in both directions
MARGIN = 0.12  # text closer than this to the frame edge is "near the edge"
SMALL = 13  # text below this size is hard to read at 1080p
TEXT_KINDS = ("text", "code", "caption", "header", "source")


def tag(mob, kind, text, size, ink=None):
    """Mark a mobject as one piece of text. `ink` is the submobject holding its glyphs."""
    mob.explainer_tag = {"kind": kind, "text": text, "size": size, "ink": ink,
                         "h0": mob.height or 1.0}


def _visible(m):
    if not isinstance(m, VMobject) or len(m.points) == 0:
        return False
    if m.width < 1e-6 and m.height < 1e-6:
        return False
    return m.get_fill_opacity() > 0.02 or (m.get_stroke_opacity() > 0.02
                                           and m.get_stroke_width() > 0)


def _box(mob):
    """Bounding box of the visible ink under a mobject, or None if there is none."""
    parts = [m for m in mob.get_family() if _visible(m)]
    if not parts:
        return None
    return (min(m.get_left()[0] for m in parts), min(m.get_bottom()[1] for m in parts),
            max(m.get_right()[0] for m in parts), max(m.get_top()[1] for m in parts))


def _pieces(mobs):
    """Tagged text as (tag, box), everything else as (None, box) per visible leaf."""
    for mob in mobs:
        info = getattr(mob, "explainer_tag", None)
        if info is not None:
            ink = mob if info["ink"] is None else mob[info["ink"]]
            box = _box(ink)
            if box:
                yield dict(info, scale=mob.height / info["h0"]), box
        elif mob.submobjects:
            yield from _pieces(mob.submobjects)
        elif _visible(mob):
            yield None, _box(mob)


def _shared(a, b):
    return min(a[2], b[2]) - max(a[0], b[0]), min(a[3], b[3]) - max(a[1], b[1])


def _name(info):
    return info["text"] if len(info["text"]) <= 60 else info["text"][:57] + "..."


def check(scene):
    """Findings for the scene's current picture: (kind, severity, detail, [text, ...])."""
    half_w, half_h = config.frame_width / 2, config.frame_height / 2
    pieces = list(_pieces(scene.mobjects))
    texts = [(info, box) for info, box in pieces if info and info["kind"] in TEXT_KINDS]
    shapes = [box for info, box in pieces if info is None]
    found = []

    for info, box in pieces:
        over = max(-half_w - box[0], box[2] - half_w, -half_h - box[1], box[3] - half_h)
        if over > 0.02:
            what = [_name(info)] if info else []
            found.append(("off_frame", "error",
                          f"{'text' if info else 'a shape'} extends {over:.2f} past the frame",
                          what))
        elif info and info["kind"] in ("text", "code") and over > -MARGIN:
            found.append(("near_edge", "warning",
                          f"text is {-over:.2f} from the frame edge", [_name(info)]))

    for i, (a, box_a) in enumerate(texts):
        if a["size"] * a["scale"] < SMALL and a["kind"] != "source":
            found.append(("small_text", "warning",
                          f"set at size {a['size'] * a['scale']:.0f}, below {SMALL}",
                          [_name(a)]))
        for b, box_b in texts[i + 1:]:
            if a["kind"] == b["kind"] == "caption":
                continue
            dx, dy = _shared(box_a, box_b)
            if dx > OVERLAP and dy > OVERLAP:
                found.append(("text_overlap", "error",
                              f"two pieces of text overlap by {dx:.2f} x {dy:.2f}",
                              [_name(a), _name(b)]))

    for info, box in texts:
        if info["kind"] != "caption":
            continue
        for shape in shapes:
            dx, dy = _shared(box, shape)
            if dx > 0.02 and dy > 0.02:
                found.append(("caption_overlap", "error",
                              "a shape reaches into the caption", [_name(info)]))
                break
    return found
