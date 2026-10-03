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
| `check FILM` | Re-runs the checks on the last render. | seconds |
| `say FILM` | Prints each spoken line and how it will be pronounced. | seconds |
| `sheet FILM` | Contact sheets of the last render, for an author who can look. | seconds |
| `doctor` | Says what is installed and what is missing. | |

Flags: `--scenes A B` limits a command to some scenes (no joined film is written); `--no-voice`
renders captions only; `--transcribe` adds the speech-to-text check; `--json` prints the report
alone; `-o` names the output; `--media` moves the scratch directory. The first render of a film
synthesizes its clips at about five seconds a line; after that only changed lines are re-made.

**Exit status:** 0 clean, 1 could not render, 2 rendered but a check failed.

## What is checked

The report (`--json`, also written to the scratch directory as `report-<mode>.json`) has the
scenes with their lengths, `lint` findings, and under `voice` the sync, loudness and, on request,
transcription results. `ok` is false if any error-level finding or sync failure is present.

| Check | Level | What it catches |
|---|---|---|
| `off_frame` | error | Any visible shape or text extending past the frame. |
| `text_overlap` | error | Two pieces of text printed over each other. |
| `caption_overlap` | error | A shape reaching into the caption. |
| `narration_cut` | error | A scene ending while its last line is still being said. |
| `unspeakable` | error | A `say()` whose text is built at run time, so no clip can be made for it. |
| `near_edge` | warning | Text within 0.12 units of the frame edge. |
| `small_text` | warning | Text set below size 13. |
| `caption_cut` | warning | A caption replaced before it could be read (a missing `rest()`). |
| sync | error | Each clip's first sound in the finished file against where its scene put it (80 ms). |
| overlaps | error | Two clips speaking at once. |
| loudness | reported | Integrated LUFS and true peak of the finished track. |
| transcription | reported | Whisper's reading of each clip against its line. Homophones and digits for spelt-out numbers are expected differences. |

`selftest.sh` holds each geometry check to account: `examples/defects.py` has one scene per
check with that defect seeded, and the test fails unless each is flagged as its own kind and the
clean scenes stay clean. It draws nothing and takes about eight seconds.

**What the checks do not see.** They work from bounding boxes at the poses where a scene rests.
They do not judge balance, crowding, colour, or whether an arrow points at the right thing, and
they see nothing in the middle of an animation. Of the three layout defects the 034 film
actually had while it was being made, lint flags two when they are put back (a label printed
over another, a stamp past the right edge). The third was a row moved in from the edge for
comfort at 0.16 units, which no threshold here separates from a layout that is fine. Cramped
line spacing and a top-heavy frame, both fixed by eye, are invisible to it. The transcription
check shows the words are intelligible and correct, not that the delivery sounds natural.

## How it works

- **Narration first.** `film.py` reads the film's source for `say(...)` and `speak(...)` literals
  and `voice.py` synthesizes one Kokoro clip per line, cached by text, voice and speed. A scene
  times itself by the clip's length, which is why a spoken line cannot be built at run time.
- **One Manim process per scene**, in parallel. Each writes a small report: its length, when each
  clip starts, and what `lint` found.
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
(Apache-2.0). `--with-whisper` adds `faster-whisper` for `--transcribe`. Nothing leaves the
machine at render time. `EXPLAINER_ENV`, `KOKORO_MODELS` and `EXPLAINER_MEDIA` relocate the
environment, the models and the scratch directory; `EXPLAINER_VOICE` picks another Kokoro voice
(default `af_heart`; `am_*` are US male, `bm_*` and `bf_*` British).

A render takes minutes. Under Motoko's `BashExec`, whose wall is 30 seconds unless the profile
sets `tools.process_timeout`, only `lint`, `say`, `check` and `doctor` fit without a raised
timeout.
