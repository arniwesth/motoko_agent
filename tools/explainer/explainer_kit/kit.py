"""The scene kit: text and shape helpers, and the Explainer base scene.

A film is a Python file of Explainer subclasses, one per beat. Inside construct(), say() puts a
caption up and starts its narration, rest() waits until the caption has been read and said, and
everything between them is ordinary Manim.

There is no LaTeX: all text is Pango `Text` set in Computer Modern (fonts/).
"""

from __future__ import annotations

import json
import os
import pathlib
import re
import sys

import manimpango
from manim import *

from . import lint, voice

FONTS = pathlib.Path(__file__).resolve().parent / "fonts"
for _font in sorted(FONTS.glob("*.ttf")):
    manimpango.register_font(str(_font))

SERIF = "CMU Serif"
MONO = "CMU Typewriter Text"
BG = "#0f1115"
PANEL = "#161a22"
K = 4  # set text K times too large, then scale down: Pango kerns badly at small sizes
WIDE = {"pixel_width": 40000}  # Text wraps at the frame's pixel width; lift that while setting
CAP_Y = -3.1  # captions sit here; keep a scene's own content above y = -2.6

# Inline markup: "{cy|effects: unknown}" is code font (c) in yellow (y); i is italic.
# A film may add letters to TAGS before it builds any text.
TAGS = {"g": GREEN, "y": YELLOW, "t": TEAL, "b": BLUE, "r": RED, "p": PURPLE, "m": GREY_B,
        "o": GOLD, "w": WHITE}


def parse(markup):
    """Split inline markup into plain text and (start, end, flags) spans."""
    plain, spans, last = "", [], 0
    for m in voice.MARK.finditer(markup):
        plain += markup[last:m.start()]
        start = len(plain)
        plain += m.group(2)
        spans.append((start, len(plain), m.group(1)))
        last = m.end()
    return plain + markup[last:], spans


def T(markup, size=28, color=WHITE, font=SERIF, slant=NORMAL, weight=NORMAL):
    """One line of text with a fixed line box.

    The text is set between two brackets that are then removed; their top and bottom are kept
    as invisible points, so every line of a given size has the same height and lines stacked or
    boxed by their bounding box share a baseline.
    """
    plain, spans = parse(markup)
    t2c, t2f, t2s = {}, {}, {}
    for a, b, flags in spans:
        key = f"[{a + 1}:{b + 1}]"
        for flag in flags:
            if flag == "c":
                t2f[key] = MONO
            elif flag == "i":
                t2s[key] = ITALIC
            else:
                t2c[key] = TAGS[flag]
    with tempconfig(WIDE):
        text = Text(f"[{plain}]", font=font, font_size=size * K, color=color, slant=slant,
                    weight=weight, t2c=t2c, t2f=t2f, t2s=t2s, disable_ligatures=True)
    text.scale(1 / K)
    lo, hi = text[0], text[-1]
    top = max(lo.get_top()[1], hi.get_top()[1])
    bottom = min(lo.get_bottom()[1], hi.get_bottom()[1])
    text.remove(lo, hi)
    x = text.get_center()[0]
    group = VGroup(text, VectorizedPoint([x, top, 0]), VectorizedPoint([x, bottom, 0]))
    lint.tag(group, "text", plain, size, ink=0)
    return group


def code(lines, size=20, color=GREY_A, spacing=0.8):
    """A block of code set as one Pango layout, returned as one VGroup per line."""
    plains, t2c, pos = [], {}, 0
    for line in lines:
        plain, spans = parse(line)
        for a, b, flags in spans:
            for flag in flags:
                if flag in TAGS:
                    t2c[f"[{pos + a}:{pos + b}]"] = TAGS[flag]
        plains.append(plain)
        pos += len(plain) + 1
    with tempconfig(WIDE):
        block = Text("\n".join(plains), font=MONO, font_size=size * K, color=color, t2c=t2c,
                     disable_ligatures=True, line_spacing=spacing)
    block.scale(1 / K)
    # Text keeps one submobject per character, whitespace and newlines included (zero-size).
    subs = block.submobjects
    assert len(subs) == sum(len(p) for p in plains) + len(plains) - 1, (len(subs), plains)
    out, i = VGroup(), 0
    for plain in plains:
        line = VGroup(*[subs[i + k] for k, ch in enumerate(plain) if not ch.isspace()])
        lint.tag(line, "code", plain, size)
        out.add(line)
        i += len(plain) + 1
    return out


def card(lines, size=20, w=None, h=None, pad=0.3, stroke=GREY_D, color=GREY_A):
    """A dark panel holding a code block, left-aligned. `.bg` and `.lines` reach its parts."""
    body = code(lines, size=size, color=color)
    bg = RoundedRectangle(width=w or body.width + 2 * pad, height=h or body.height + 2 * pad,
                          corner_radius=0.14, stroke_color=stroke, stroke_width=2,
                          fill_color=PANEL, fill_opacity=1)
    body.move_to(bg.get_left() + RIGHT * pad, aligned_edge=LEFT)
    if h:
        body.align_to(bg.get_top() + DOWN * pad, UP)
    group = VGroup(bg, body)
    group.bg, group.lines = bg, body
    return group


def pill(markup, color, size=20, font=SERIF, pad=0.44, fill=0.13, dashed=False, text_color=None):
    """A short label in a rounded outline. `dashed` marks something provisional."""
    label = T(markup, size=size, font=font, color=text_color or color)
    h = label.height + 0.2
    box = RoundedRectangle(width=label.width + pad, height=h, corner_radius=min(0.16, h / 2 - 0.02),
                           stroke_color=color, stroke_width=2.2, fill_color=color,
                           fill_opacity=fill)
    if dashed:
        outline = DashedVMobject(box.copy().set_fill(opacity=0),
                                 num_dashes=int(6 * (box.width + h)), dashed_ratio=0.55)
        box.set_stroke(width=0)
        group = VGroup(box, outline, label)
    else:
        group = VGroup(box, label)
    group.box, group.label = box, label
    return group


def node(label, color, w=2.4, h=1.0, size=26):
    """A named actor: a tinted rounded box with its name inside."""
    box = RoundedRectangle(width=w, height=h, corner_radius=0.18, stroke_color=color,
                           stroke_width=3, fill_color=color, fill_opacity=0.14)
    return VGroup(box, T(label, size=size))


def check(color=GREEN, size=0.3, width=6):
    mark = VMobject(stroke_color=color, stroke_width=width)
    mark.set_points_as_corners([[-0.5, 0.05, 0], [-0.12, -0.38, 0], [0.55, 0.45, 0]])
    return mark.scale(size)


def cross(color=RED, size=0.3, width=6):
    mark = VGroup(Line([-0.4, -0.4, 0], [0.4, 0.4, 0]), Line([-0.4, 0.4, 0], [0.4, -0.4, 0]))
    return mark.set_stroke(color, width).scale(size)


def neq(color, size=44):
    """Not-equal drawn as = with a stroke: the font's own glyph loses its slash in T()."""
    eq = T("=", size=size, color=color)
    slash = Line(eq.get_center() + [-0.13, -0.3, 0], eq.get_center() + [0.13, 0.3, 0],
                 color=color, stroke_width=4)
    return VGroup(eq, slash)


def arrow(start, end, color=WHITE, width=4, buff=0.1, tip=0.2):
    return Arrow(start, end, buff=buff, color=color, stroke_width=width, tip_length=tip,
                 max_tip_length_to_length_ratio=0.5, max_stroke_width_to_length_ratio=20)


class Explainer(Scene):
    """say() swaps a caption in and starts its narration; rest() waits until it is read and said.

    The scene only records when each clip starts and what the geometry checks found. The CLI
    lays the clips on one track from those times, so nothing here depends on Manim's own audio
    handling, and a render and a dry run report the same things.
    """

    def setup(self):
        self.camera.background_color = BG
        self.cap = None
        self.busy_until = 0.0  # the caption has been up long enough and its clip has ended
        self.read_until = 0.0
        self.voice_until = 0.0
        self.timeline = []
        self.captions = 0
        self.findings = []
        self._seen = set()
        self.say_table = list(getattr(sys.modules[type(self).__module__], "SAY", []))

    def tear_down(self):
        if self.voice_until > self.renderer.time + 0.02:
            self.finding("narration_cut", "error",
                         f"the scene ends {self.voice_until - self.renderer.time:.2f} s before "
                         "its last line has been said", [])
        out = os.environ.get("EXPLAINER_RUN_DIR")
        if out:
            pathlib.Path(out).mkdir(parents=True, exist_ok=True)
            report = {"scene": type(self).__name__, "seconds": round(self.renderer.time, 3),
                      "captions": self.captions, "timeline": self.timeline,
                      "lint": self.findings}
            name = pathlib.Path(out) / f"{type(self).__name__}.json"
            name.write_text(json.dumps(report, indent=1))
        super().tear_down()

    def add(self, *mobjects):
        for mob in mobjects:
            lint.mark_plain_text(mob)  # so a plain Text stays one text if Manim takes it apart
        return super().add(*mobjects)

    # -- narration and captions ---------------------------------------------------------------

    def speak(self, text, lead=0.2):
        """Start the clip for a spoken line a moment from now. Nothing happens with voice off."""
        got = voice.clip(text)
        if got is None:
            return
        path, seconds = got
        start = self.renderer.time + lead
        self.timeline.append({"t": round(start, 3), "wav": path.name, "text": text})
        self.voice_until = start + seconds

    def hush(self, pad=0.3):
        """Wait for the narration to finish."""
        left = self.voice_until + pad - self.renderer.time
        if left > 0.02:
            self.wait(left)

    def say(self, *lines, run_time=0.55):
        """Replace the caption with these lines (inline markup allowed) and speak them."""
        self.hush(0.15)  # never talk over the line before
        # A wait is rounded down to whole frames, so a caption that was given its rest() can
        # still be up to one frame short. That is not a cut; a missing rest() is seconds short.
        slack = max(0.05, 1 / config.frame_rate + 0.005)
        if self.cap is not None and self.renderer.time < self.read_until - slack:
            self.finding("caption_cut", "warning",
                         f"replaced {self.read_until - self.renderer.time:.1f} s before it "
                         "could be read: call rest() first", [self.cap_text])
        new = VGroup(*[T(line, size=28) for line in lines]).arrange(DOWN, buff=0.1)
        for line in new:
            line.explainer_tag["kind"] = "caption"
        new.move_to([0, CAP_Y, 0])
        anims = [FadeIn(new, shift=0.12 * UP)]
        if self.cap is not None:
            anims.append(FadeOut(self.cap, shift=0.12 * UP))
        self.speak(voice.spoken(lines, self.say_table))
        self.play(*anims, run_time=run_time)
        self.cap = new
        self.captions += 1
        plain = [parse(line)[0] for line in lines]
        self.cap_text = " ".join(plain)
        self.read_until = self.renderer.time + 1.0 + sum(len(line) for line in plain) / 16
        self.busy_until = max(self.read_until, self.voice_until + 0.35)

    def rest(self, extra=0.0):
        """Hold the finished picture until its caption has been read and said."""
        self.lint_now()
        self.wait(max(0.4, self.busy_until - self.renderer.time) + extra)

    # -- furniture ----------------------------------------------------------------------------

    def header(self, kicker, title):
        head = T("{b|" + kicker + "}   " + title, size=30).move_to([0, 3.5, 0])
        head.explainer_tag["kind"] = "header"
        self.play(FadeIn(head, shift=0.15 * DOWN), run_time=0.6)
        return head

    def source(self, text):
        """Where the scene's claims come from, in small type at the bottom left."""
        note = T(text, size=14, color=GREY_C).to_corner(DL, buff=0.16)
        note.explainer_tag["kind"] = "source"
        self.play(FadeIn(note), run_time=0.3)
        return note

    def end(self):
        self.play(*[FadeOut(m) for m in self.mobjects], run_time=0.7)
        self.cap = None
        self.wait(0.25)

    # -- checks -------------------------------------------------------------------------------

    def finding(self, kind, severity, detail, what):
        key = (kind, tuple(sorted(what)))
        if key in self._seen:
            return
        self._seen.add(key)
        self.findings.append({"t": round(self.renderer.time, 2), "kind": kind,
                              "severity": severity, "detail": detail, "what": list(what)})

    def lint_now(self):
        """Check the current picture's geometry. rest() does this; call it for other poses."""
        for kind, severity, detail, what in lint.check(self):
            self.finding(kind, severity, detail, what)
