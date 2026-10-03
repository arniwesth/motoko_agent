"""Scenes with one seeded defect each. selftest.sh checks that lint reports exactly these.

A check that has never been seen to fail is not evidence, so every check has a scene here that
it must flag, and the Clean scenes are the ones none of them may flag. The expected finding for
each scene is in selftest.sh.
"""

import numpy as np
from manim import *

from explainer_kit import *


class Clean(Explainer):
    def construct(self):
        self.say("Nothing is wrong with this picture.")
        self.play(FadeIn(node("fine", BLUE)), run_time=0.4)
        self.rest()
        self.end()


class OffFrame(Explainer):
    def construct(self):
        self.say("A label has slid off the right-hand side.")
        self.play(FadeIn(pill("PermissionDenied", YELLOW).move_to([6.9, 0, 0])), run_time=0.4)
        self.rest()
        self.end()


class NearEdge(Explainer):
    def construct(self):
        self.say("A label is inside the frame, but only just.")
        self.play(FadeIn(T("close to the edge").to_edge(RIGHT, buff=0.05)), run_time=0.4)
        self.rest()
        self.end()


class TextOverlap(Explainer):
    def construct(self):
        self.say("Two labels were given the same place.")
        first = T("exec returned").move_to([0, 1, 0])
        second = T("Err(SpawnFailed)").move_to([0.9, 1, 0])
        self.play(FadeIn(first), FadeIn(second), run_time=0.4)
        self.rest()
        self.end()


class CaptionOverlap(Explainer):
    def construct(self):
        self.say("A panel has grown down into the caption.")
        panel = Rectangle(width=4, height=3, stroke_color=TEAL).move_to([0, -1.9, 0])
        self.play(FadeIn(panel), run_time=0.4)
        self.rest()
        self.end()


class SmallText(Explainer):
    def construct(self):
        self.say("A footnote is too small to read.")
        self.play(FadeIn(T("eleven point", size=11)), run_time=0.4)
        self.rest()
        self.end()


class CaptionCut(Explainer):
    def construct(self):
        self.say("This caption is replaced before anyone could read it.")
        self.say("This one is given its time.")
        self.rest()
        self.end()


# The scenes below came out of the review of PR #211: ink the first version did not see.


class ArrowOffFrame(Explainer):
    """An arrow's shaft belongs to the arrow itself; only its tip is a child."""

    def construct(self):
        self.say("An arrow starts outside the picture.")
        self.play(FadeIn(arrow([-8, 1, 0], [0, 1, 0])), run_time=0.4)
        self.rest()
        self.end()


class ThickLineInCaption(Explainer):
    """A horizontal line has no height of its own; its stroke does."""

    def construct(self):
        self.say("A heavy rule runs through this caption.")
        rule = Line([-3, CAP_Y, 0], [3, CAP_Y, 0], stroke_width=20, color=RED)
        self.play(FadeIn(rule), run_time=0.4)
        self.rest()
        self.end()


class PlainTextOverlap(Explainer):
    """Text made with Manim's own Text, not the kit's T()."""

    def construct(self):
        self.say("Two plain labels were given the same place.")
        first = Text("exec returned", font_size=28).move_to([0, 1, 0])
        second = Text("Err(SpawnFailed)", font_size=28).move_to([0.9, 1, 0])
        self.play(FadeIn(first), FadeIn(second), run_time=0.4)
        self.rest()
        self.end()


class PlainSmallText(Explainer):
    def construct(self):
        self.say("A plain footnote is too small to read.")
        self.play(FadeIn(Text("eight point", font_size=8)), run_time=0.4)
        self.rest()
        self.end()


class ImageOffFrame(Explainer):
    def construct(self):
        self.say("A picture has slid off the right-hand side.")
        image = ImageMobject(np.uint8([[255, 80], [80, 255]])).scale_to_fit_width(2)
        self.play(FadeIn(image.move_to([7.5, 0, 0])), run_time=0.4)
        self.rest()
        self.end()


class CaptionLinesCollide(Explainer):
    def construct(self):
        self.say("The second line of this caption", "has been moved onto the first.")
        self.cap[1].move_to(self.cap[0])
        self.rest()
        self.end()


class CleanOutline(Explainer):
    """An empty frame around the caption touches none of its text."""

    def construct(self):
        self.say("This caption sits inside an empty frame.")
        frame = Rectangle(width=10, height=1.4, stroke_color=TEAL).move_to([0, CAP_Y, 0])
        self.play(FadeIn(frame), run_time=0.4)
        self.rest()
        self.end()
