"""A film for selftest.sh --full: a caption that was given its rest(), at draft frame rate.

A wait is rounded down to whole frames, so at 15 fps rest() can end up to a fifteenth of a
second early. The first caption is seventeen characters, which makes that shortfall 62 ms: more
than a fixed 50 ms allowance, less than a frame. It was rested, so it was not cut.
"""

from manim import *

from explainer_kit import *


class Rested(Explainer):
    def construct(self):
        self.say("A caption to read")
        self.rest()
        self.say("Then another one.")
        self.rest()
        self.end()
