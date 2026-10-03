"""A film for selftest.sh --full: a caption replaced with no rest(), but only after its narration.

Rendered at half voice speed, the first line takes longer to say than to read. say() waits for
it before putting the next caption up, so nothing was cut short and no caption_cut is due.
"""

from manim import *

from explainer_kit import *


class Slow(Explainer):
    def construct(self):
        self.say("At half speed this line takes far longer to say than to read.")
        self.say("Then this.")
        self.rest()
        self.end()
