"""A film for selftest.sh --full: two short scenes, narration from a base class and by keyword."""

import os

from manim import *

from explainer_kit import *


class _Base(Explainer):
    def opening(self):
        self.say("Inherited line.")  # spoken by every scene that calls opening()


class A(_Base):
    def construct(self):
        self.speak(text="Title.")
        self.hush()
        self.opening()
        self.play(FadeIn(node("a", BLUE)), run_time=0.3)
        self.rest()
        self.end()


class B(_Base):
    def construct(self):
        if os.environ.get("EXPLAINER_TEST_CRASH"):
            raise RuntimeError("seeded crash")
        self.say("Second scene.")
        self.play(FadeIn(node("b", TEAL)), run_time=0.3)
        self.rest()
        self.end()
