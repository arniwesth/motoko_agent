"""Scenes with one seeded defect each. selftest.sh checks that lint reports exactly these.

A check that has never been seen to fail is not evidence, so every check has a scene here that
it must flag, and Clean is the scene none of them may flag.
"""

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
