"""The smallest film: one scene, two captions. Start a new film from this."""

from manim import *

from explainer_kit import *

OUTPUT = "minimal.mp4"
# Captions are written to be read; these respell what the voice would otherwise stumble on.
SAY = [(r"\bCLI\b", "command line")]


class Hello(Explainer):
    def construct(self):
        self.header("Example", "the smallest film")
        self.source("tools/explainer/examples/minimal.py")
        film = node("a film", BLUE).move_to([-3.2, 0.6, 0])
        scene = node("a scene", TEAL).move_to([3.2, 0.6, 0])

        self.say("A film is a file of scenes, and the CLI renders them in order.")
        self.play(FadeIn(film, shift=0.2 * UP), run_time=0.6)
        self.rest()

        self.say("Each {c|say} puts a caption up and speaks it.",
                 "Each {c|rest} waits until it has been {g|read} and {g|said}.")
        link = arrow(film.get_right(), scene.get_left())
        self.play(GrowArrow(link), FadeIn(scene, shift=0.2 * UP), run_time=0.8)
        self.rest()
        self.end()
