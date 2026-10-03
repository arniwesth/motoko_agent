# explainer

Renders a narrated explainer video, in the style of a 3Blue1Brown film, from a Python file of
[Manim](https://www.manim.community/) scenes, and checks the result without anyone having to
watch it. Every caption is spoken by a local speech model; the picture waits for the voice.

It was extracted from `.agent/projects/034_ambiguous_tool_outcomes/video/`, which is the worked
example. That film renders through this tool identically to the hand-built pipeline it replaced:
7,534 frames with infinite PSNR and the same audio samples.

## Quick start

```sh
tools/explainer/setup.sh                                   # once: about 1.5 GB, no root
tools/explainer/explainer lint   examples/minimal.py       # seconds: timeline and geometry
tools/explainer/explainer render examples/minimal.py --draft
tools/explainer/explainer render examples/minimal.py       # 1080p, beside the film file
```

## Writing a film

A film is one Python file. Each class deriving from `Explainer` is a scene, and they play in the
order they appear. Start from `examples/minimal.py`.

```python
from manim import *
from explainer_kit import *

OUTPUT = "my-film.mp4"                       # optional; default is <file>.mp4
SAY = [(r"\bstderr\b", "standard error")]    # optional; respellings for the voice

class Idea(Explainer):
    def construct(self):
        self.header("The idea", "one line that says what this scene is for")
        self.source("where the claims on screen come from")
        box = node("harness", BLUE)
        self.say("The caption is what is said.", "A second line, if it needs one.")
        self.play(FadeIn(box, shift=0.2 * UP), run_time=0.6)
        self.rest()      # holds until the caption has been read and its clip has ended
        self.end()       # fade everything out
```

| On the scene | What it does |
|---|---|
| `say(*lines)` | Swaps the caption and starts its narration. Arguments must be string literals. |
| `rest(extra=0)` | Checks the picture, then waits until the caption is read and said. |
| `speak(text)` | Narration with no caption, for a title card. Follow it with `hush()`. |
| `header(kicker, title)`, `source(text)` | The line at the top, and the small sources line at the bottom left. |
| `end()` | Fades the scene out. |
| `lint_now()` | Runs the geometry checks on a pose that `rest()` does not see. |

| Helper | What it makes |
|---|---|
| `T(markup, size=28, color=WHITE)` | One line of serif text with a fixed line box. |
| `code(lines)`, `card(lines, w=, h=)` | Monospaced lines as one layout; the same in a dark panel (`.lines`, `.bg`). |
| `pill(markup, color, dashed=False)`, `node(label, color)` | A labelled outline; a named actor. |
| `arrow(a, b)`, `check()`, `cross()`, `neq(color)` | An arrow with a sane tip, and marks the fonts lack. |

**Inline markup.** `{cy|effects: unknown}` is code font (`c`) in yellow (`y`); `i` is italic. The
colour letters are in `TAGS` (g y t b r p m o w), and a film may add its own.

**Layout.** The frame is 14.2 × 8 units. Captions sit at y = -3.1 and the sources line under
them, so keep a scene's content above y = -2.6 and the header's row (y = 3.5) clear.

**Voice.** Captions are written to be read. Where the voice would stumble (`exit_code`, `P1`,
`65,536`), add a `(pattern, said)` pair to `SAY`; `explainer say` shows the result with phonemes.

## Commands

| Command | What it does | Time for the 034 film |
|---|---|---|
| `lint FILM` | Runs every scene's timeline without drawing it; reports durations and geometry findings. | 27 s |
| `render FILM` | Makes missing narration clips, renders scenes in parallel, joins them, mixes and levels the voice, then checks. Writes the film beside its file. | 2.5 min |
| `render FILM --draft` | The same at 854×480, 15 fps, kept in scratch. | under a minute |
| `check FILM` | Re-runs the checks on the last successful render. Refuses (exit 1) if a scene failed, the film is gone, it does not decode to exactly the frames the render made, or the scratch directory holds another film's render. | seconds |
| `say FILM` | Prints each spoken line and how it will be pronounced. | seconds |
| `sheet FILM` | Contact sheets of the last render, for an author who can look. | seconds |
| `doctor` | Says what is installed and what is missing. | |

Flags: `--scenes A B` limits a command to some scenes: no joined film is written, and each scene
is narrated into its own file in scratch and checked there for sync and loudness. `--no-voice`
renders captions only; `--transcribe` adds the speech-to-text check; `--json` prints the report
alone; `-o` names the output; `--media` moves the scratch directory. Progress goes to stderr, so
stdout is only ever the report. The first render of a film synthesizes its clips at about five
seconds a line; after that only changed lines are re-made.

**Exit status:** 0 clean, 1 could not render, 2 rendered but a check failed.

## What is checked

The report (`--json`, also written to the scratch directory as `report-<mode>.json`) has the
scenes with their lengths, `lint` findings, and under `voice` the sync, loudness and, on request,
transcription results. `ok` is false if any error-level finding or sync failure is present.

| Check | Level | What it catches |
|---|---|---|
| `off_frame` | error | Any ink past the frame: shapes with their stroke thickness (foreground or background), arrows, the visible pixels of an image, text. |
| `text_overlap` | error | Two pieces of text printed over each other: the kit's text, plain Manim `Text`, or two lines of one caption. A text stays one text, at the size it now has, after Manim takes it apart to remove a glyph. |
| `caption_overlap` | error | A filled shape, the visible pixels of an image, or a stroke reaching into the caption. An empty outline around it, or the transparent part of an image over it, is fine. |
| `narration_cut` | error | A scene ending while its last line is still being said. |
| `unspeakable` | error | A `say()` or `speak()` in a rendered scene whose text is built at run time, so no clip can be made for it. |
| `near_edge` | warning | Text within 0.12 units of the frame edge. |
| `small_text` | warning | Text set below size 13. |
| `caption_cut` | warning | A caption replaced before it could be read (a missing `rest()`). |
| sync | error | Each clip's first sound in the finished file against where its scene put it (80 ms), read by the file's own timestamps, so a track muxed late fails. |
| overlaps | error | Two clips speaking at once. |
| loudness | reported | Integrated LUFS and true peak of the finished track. |
| transcription | reported | Whisper's reading of each clip against its line. Homophones and digits for spelt-out numbers are expected differences. |

`selftest.sh` holds the checks to account. `examples/defects.py` has a scene for each seeded
defect, and the test fails unless each is flagged as its own kind and the clean scenes stay
clean. `tests/units.py` covers what is not geometry: which lines a scene can reach, a damaged
clip cache, a late audio track, a render that never finished or belongs to another film, a
movie whose picture was cut off. `setup.sh`'s download and completeness checks are run against a
web server of the test's own. That much draws nothing and takes about fifteen seconds.
`selftest.sh --full` also renders small narrated films and checks what only a real render shows;
about a minute in all.

`tests/mutate.py` holds the tests to account in turn: it reverts each fix a review found, one at
a time in a copy of the tool, and the self-test must go red. Run it after changing a check or a
test; it takes about a quarter of an hour.

**What the checks do not see.** They work from geometry at the poses where a scene rests. They
do not judge balance, crowding, colour, or whether an arrow points at the right thing, and they
see nothing in the middle of an animation. Text is text to them when it is the kit's or a Manim
`Text` or `MarkupText`; `Tex`, and words inside an image, are shapes. A shape over ordinary text
is not flagged, because that is what a label in a box looks like; only the caption is protected.
Of the three layout defects the 034 film
actually had while it was being made, lint flags two when they are put back (a label printed
over another, a stamp past the right edge). The third was a row moved in from the edge for
comfort at 0.16 units, which no threshold here separates from a layout that is fine. Cramped
line spacing and a top-heavy frame, both fixed by eye, are invisible to it. The transcription
check shows the words are intelligible and correct, not that the delivery sounds natural.

## Known limits

Found in the fourth round of review and not fixed. The reviewer was content to see these
recorded and not hold a merge for them.

- **Reachability goes by names.** A local variable named like a module-level helper counts as a
  call to it, and a lambda's body is always entered. Either can report a line as unspeakable in
  a scene that never says it.
- **`sheet` on a very short scene** (shorter than half the sampling interval) prints a path and
  exits 0 without writing a file.
- **A regrouped text's size includes what is attached to its glyphs**, so a glyph with an offset
  child can hide a small-text warning.
- **`tests/mutate.py` does not cover** `Base.method(self)` resolution or the checksum check on a
  freshly downloaded file; reverting either leaves the self-test green.

## How it works

- **Narration first.** `film.py` reads the film's source for the `say(...)` and `speak(...)`
  literals each scene can reach: from its `construct()`, through the methods it would actually
  get (its own, a base class's or a mixin's in the same file, in Python's lookup order; `super()`
  to the next one up) and the module-level or nested functions it names. An overridden method, a
  nested function nobody names, and a helper nothing calls belong to no scene. Narration reached
  through another file is not seen, so it has to live in the film file. `voice.py` synthesizes
  one Kokoro clip per line, cached by text, voice and speed, written whole or not at all, and
  re-made if the cached file is damaged. A scene times itself by the clip's length, which is why
  a spoken line cannot be built at run time.
- **One Manim process per scene**, in parallel, each in a directory of its own so that their
  text caches cannot collide, and each with the kit imported before the film is. Each writes a
  small report: its length, when each clip starts, and what `lint` found.
- **One track.** The clips are laid at the recorded times, levelled at +6 dB under a limiter
  (about -17 LUFS), and muxed onto the concatenated picture. Manim's own audio path is not used.
- **`lint` uses Manim's last-frame mode**, in which animations jump to their ends and time still
  advances, so it reports the same findings and nearly the same lengths as a render.
- **Text** is Pango `Text` in Computer Modern (CMU Serif and CMU Typewriter Text, in
  `explainer_kit/fonts/` under the SIL Open Font License). There is no LaTeX. It is set four
  times too large and scaled down, because Pango kerns badly at small sizes, and under a lifted
  pixel width, because `Text` otherwise wraps at the frame's pixel width and a draft would break
  lines that the final render does not.

## Setup and limits

`setup.sh` installs everything unprivileged under `~/.local/share/manim-env-root`: micromamba, a
conda-forge environment with Manim and ffmpeg, `kokoro-onnx`, and 340 MB of Kokoro model files
(Apache-2.0). `--with-whisper` adds `faster-whisper` and its `small.en` model (464 MB) for
`--transcribe`. Each download goes to a temporary name and takes its place only once verified
(the Kokoro files by checksum), so an interrupted run cannot leave a broken file that a later
run trusts.

All network use is in `setup.sh`. Rendering and checking, `--transcribe` included, load their
models from disk with downloads disabled. `EXPLAINER_ENV`, `KOKORO_MODELS`, `WHISPER_MODELS` and
`EXPLAINER_MEDIA` relocate the environment, the models and the scratch directory;
`EXPLAINER_VOICE` picks another Kokoro voice (default `af_heart`; `am_*` are US male, `bm_*` and
`bf_*` British).

A render takes minutes. Under Motoko's `BashExec`, whose wall is 30 seconds unless the profile
sets `tools.process_timeout`, only `lint`, `say`, `check` and `doctor` fit without a raised
timeout.
