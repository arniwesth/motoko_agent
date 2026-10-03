---
repo: arniwesth/motoko_agent
pr: 211
branch: feat/explainer-tool
ticket: null
title: "feat(tools): explainer — narrated Manim films with machine checks"
---

## Summary

Adds `tools/explainer`, which renders a narrated explainer video (in the style of a 3Blue1Brown
film) from a Python file of Manim scenes, and checks the result without anyone having to watch it.

It was extracted from the pipeline built by hand for the 034 effect-disclosure explainer. The
point of the checks is that an author who cannot look at frames, which includes a model in a
Motoko session, gets `explainer lint FILM` in place of looking.

## Changes

- feat(tools): explainer, narrated Manim films with machine checks
- fix(tools): explainer — address the review of PR #211
- fix(tools): explainer — address the reviewer's re-check of PR #211
- fix(tools): explainer — address the third round of review on PR #211
- fix(tools): explainer — fix the four findings the reviewer would hold the merge for
- docs(tools): explainer — record the fourth review round's open findings as known limits
- chore(github) commits recording this PR

24 files under `tools/explainer/`:

- **`explainer_kit/`**: the scene kit (`say()` puts a caption up and speaks it, `rest()` waits
  for both), Kokoro narration cached per caption, geometry lints from Manim's own geometry, and
  the CLI.
- **`explainer`**: the launcher. Commands: `lint` (draws nothing), `render`, `check`, `say`,
  `sheet`, `doctor`. Exit 0 clean, 1 could not render, 2 rendered but a check failed. The report
  goes to stdout and progress to stderr, so `--json` is always valid JSON.
- **`setup.sh`**: installs Manim, ffmpeg and Kokoro without root, via micromamba, under
  `~/.local/share/manim-env-root` (about 1.5 GB). Downloads are verified before they take their
  place.
- **`selftest.sh`**, **`examples/`**, **`tests/`**: seeded defects for every geometry check, unit
  checks for the rest, `setup.sh`'s checks against a local web server, and with `--full` small
  narrated renders. `tests/mutate.py` reverts each fix in turn and requires the self-test to go
  red.
- **Seven Computer Modern fonts** (3.6 MB of binary files) with their SIL Open Font License.
  There is no LaTeX; all text is Pango `Text`.

Nothing outside `tools/explainer/` changes, apart from this PR's own record. The tool is not
wired into the Makefile, CI, the TUI or Motoko's runtime, and there is no extension exposing it
to a session yet.

### Review

An independent, read-only review by Codex (`gpt-6.1-sol`) ran twice.

**First round: 18 defects**, 16 reproduced and two inferred. The second commit addresses all of
them; the table below says how.

**Second round: the re-check.** It found 8 of the 18 fully fixed (1, 3, 8, 9, 13, 14, 15, 17).
For the other ten the original reproduction passed but a nearby input still triggered the
defect, and it listed 14 open items, including two regression tests that passed with their fix
reverted. The third commit addresses all 14; the second table says how.

**Third round.** The reviewer re-checked that commit: 10 of the 14 fixed (1, 3, 5, 6, 8, 10, 11,
12, 13, 14) and 4 not (2, 4, 7, 9), leaving 13 of the original 18 fully fixed. It listed 11
remaining findings, one severe, one of them a regression from the third commit (`explainer sheet`
crashed), and two fixes that could be reverted with the self-test still green. The fourth commit
addresses all 11; the third table says how.

**Fourth round.** The reviewer re-checked that commit: 6 of the 11 fixed (2, 5, 6, 8, 9, 11) and
5 not (1, 3, 4, 7, 10). It listed 8 remaining findings and said which it would hold the merge
for. Those four are fixed in the last fix commit, which the reviewer has not re-checked:

1. `check` passed a movie with no decodable frames when the expected film was under 0.2 s. It
   now counts decoded frames and requires exactly the number the render made
2. stretched or rotated images were measured wrongly. Each pixel is now a box of its own shape
3. method lookup was depth-first, so diamond inheritance followed the wrong method. It now
   follows Python's own order
4. a nested function calling another nested function lost its narration. A nested function now
   sees the functions defined around it

The four it was content to see recorded are not fixed and are listed in the tool's README under
"Known limits": name-based reachability (a shadowing local, an uncalled lambda), `sheet` on a
very short scene, a glyph with an offset child hiding a small-text warning, and two fixes
`tests/mutate.py` does not cover.

Each round found fewer and less severe problems (18, 14, 11, 8), but none came back clean, and
the review was stopped here.

First round:

| # | Finding | Fix |
|---|---|---|
| 1 | Sync ignored audio timestamps: a track muxed one second late passed | Audio is placed by each frame's timestamp before onsets are measured |
| 2 | `check` passed a missing film and a render in which a scene crashed | `render` writes a manifest only when it finishes; `check` and `sheet` refuse without it, or if a file it names is gone |
| 3 | Arrow shafts were never linted | A mobject's own outline is ink, not only its children |
| 4 | Stroke thickness was ignored | Boxes include half the stroke; a heavy rule through a caption or past the frame is flagged |
| 5 | Plain Manim `Text` bypassed the text checks | `Text` and `MarkupText` are text, with their effective size |
| 6 | Images were invisible to lint | Images are ink |
| 7 | `render --scenes` reported voice as fine on files with no audio | Each selected scene is narrated into its own file and sync-checked |
| 8 | A `say()` in a base-class method was not collected | Lines are collected from the whole file; a scene's are its own, its bases' and the module's |
| 9 | `speak(text=...)` was skipped silently | The keyword form is extracted |
| 10 | A bad `say()` in an unselected scene blocked the rest | Problems belong to a scene and are filtered by the selection |
| 11 | Synthesis logs broke `--json` on a first render | Progress goes to stderr |
| 12 | A zero-byte cached clip was trusted, then crashed | Cached clips are validated; clips are written to a temporary name and renamed |
| 13 | A caption inside an empty outline was flagged | An unfilled shape is tested by its stroke, not its bounding box |
| 14 | Overlapping caption lines were exempt | They are checked like any other text |
| 15 | `setup.sh` could save an HTTP error page as a binary or model | `curl --fail` into a temporary name; micromamba must run, model files must match their checksum |
| 16 | The first `--transcribe` downloaded a model at render time | `setup.sh --with-whisper` provisions it; it is loaded from disk with downloads disabled |
| 17 | `caption_cut` fired before the wait that kept the caption up | It is judged after that wait |
| 18 | `say --scenes` printed the wrong scene beside each line | The listing and the phonemes come from the same filtered records |

Second round:

| # | Still open after the first fixes | Fix |
|---|---|---|
| 1 | A manifest did not say which film it belonged to: `check` passed on another film's render in a shared scratch directory | The manifest names its film; `check` refuses a mismatch |
| 2 | Fading one character made Manim split a text into glyphs, which lint took for shapes; overlaps passed | Every glyph carries its text's record and loose glyphs are regrouped by it, for the kit's text, code lines and plain `Text` |
| 3 | Background strokes were invisible to lint | Foreground and background strokes both count |
| 4 | A captions-only `check` accepted a file that was not a movie | Every output is opened: a video stream, the length the render made, audio if narrated |
| 5 | A Whisper model missing its tokenizer passed the readiness check, then downloaded one | All four model files are required; transcription runs with `HF_HUB_OFFLINE` set |
| 6 | A clip with a valid header and truncated samples was trusted | A cached clip must hold every sample its header promises |
| 7 | Every module-level helper counted for every scene | A scene's lines are those reachable from its `construct()`, through its methods and the functions it names |
| 8 | `check --transcribe --json` printed a log line before the JSON | Commands write through one function; anything else printed goes to stderr |
| 9 | Transparent images, and transparent padding, were flagged as ink | An image is the box of its non-transparent pixels |
| 10 | `render --scenes` reported no loudness | Loudness is measured for each scene file |
| 11 | A quote in the install path broke Whisper provisioning | The path is passed as an argument, not written into source |
| 12 | The joined film was decoded once per scene | Expected starts are grouped by file; one decode |
| 13 | The late-audio test passed on any non-zero exit | It requires exit 2 and `sync.ok` false; the other end-to-end checks require their exact exit code |
| 14 | The cache test never ran synthesis against a damaged clip | It does, with a stand-in engine, and checks the clip is whole afterwards |

One more defect turned up while reverting fixes in a copy of the tool to test the tests: run from
the original's folder, the copy imported the original's code, because `python -m` puts the
current directory first on the import path. The launcher and the per-scene processes now run
with `-P`.

Third round:

| # | Remaining after the second fixes | Fix |
|---|---|---|
| 1 | `check` read a movie's headers without decoding it: a file with its video data cut off passed | Every frame is decoded and the decoded length compared with what the render made |
| 2 | A surviving glyph with a child was not regrouped into its text | A glyph is regrouped whether or not it has children |
| 3 | Narration in a same-file mixin was not collected | Every class in the file is catalogued, not only those derived from `Explainer` |
| 4 | Reachability included code that cannot run: overridden methods, uncalled nested functions | The method a scene would actually get is followed; `super()` goes one up; a nested function is entered only if named |
| 5 | Parallel scene processes shared Manim's text cache and deleted each other's files | Each scene's process works in a directory of its own |
| 6 | `sheet` crashed: a local variable shadowed the output function | Renamed; the name is used for the function alone |
| 7 | An image with a transparent middle around a caption was flagged | An image reaches into a caption only where its pixels are visible |
| 8 | `setup.sh` checked two of the four Whisper files before skipping | It checks all four, the same four the tool requires |
| 9 | A file named `explainer_kit.py` beside the film shadowed the tool | The kit is imported before Manim imports the film |
| 10 | Text scaled and then taken apart kept its original size | Each glyph remembers its size when marked; a regrouped text is scaled by how its glyphs have changed |
| 11 | Two fixes could be reverted with the self-test green | Per-scene loudness and Whisper completeness are asserted; `tests/mutate.py` now reverts 39 fixes |

`tests/mutate.py` itself found two more tests that did not hold their fix to account (the
movie-length check and the stdout guard); both were strengthened.

## Governing docs

None. No ADR governs this tool. It came out of an experiment in
`.agent/projects/034_ambiguous_tool_outcomes/video/`, and that project folder is not on `main`,
so the README's pointer to the worked example dangles until 034 lands.

Exposing the tool to a Motoko session is a separate piece of work and does want a design note
first: a render takes minutes against `BashExec`'s 30-second wall, and Motoko drops image parts
at the `Msg` seam, which is why the checks here are numeric.

## Predicted outcome

- A narrated film is one command: `tools/explainer/explainer render FILM`.
- `explainer lint FILM` reports ink past the frame, overlapping text, anything in the caption and
  unread captions in seconds, without drawing anything.
- No effect on anything that exists: nothing imports the tool.

Checked by `tools/explainer/selftest.sh`. The first real test of the install path is running
`setup.sh` on a machine that does not already have the environment.

## Test evidence

- [x] `tools/explainer/selftest.sh --full`, about a minute:
  `geometry: ok, 20 seeded defects each flagged as its own kind, 7 clean scenes clean`,
  `units: ok, 28 of 28 passed`,
  `setup: ok, a failed download leaves nothing, checksums and model completeness hold`,
  `full: ok, fresh --json, a directory per scene, sheet, narrated and measured --scenes, late
  audio fails on sync, transcription as JSON, a shadowing file, slow narration, missing film,
  crashed scene`
- [x] `tests/mutate.py`: 44 fixes reverted one at a time in a copy of the tool; the self-test
  goes red for all 44. Not covered, because nothing can observe them: that a clip is written
  under a temporary name, and that `curl` retries. Not listed, per the reviewer: explicit
  `Base.method(self)` resolution and the checksum check on a fresh download
- [x] The reviewer's probe films from the first three rounds, and its fourth-round probes for
  the four held findings, against the fixed tool: each now behaves as its finding asked. Its
  two probes that are still flagged, a thin rule and a narrow circle through the caption's
  words, are real overlaps
- [x] The 034 film (not in this PR) rendered through the fixed tool: 8 scenes, 4 min 11 s, lint
  clean under the stronger checks, all 38 clips within 25 ms of their scheduled starts,
  -17.3 LUFS, peak -0.9 dBFS; `sheet` and `check` (which now decodes all 7,534 frames) pass
- [x] That render against the one from before each round of fixes, and against the hand-built
  pipeline's last output: 7,534 frames at infinite PSNR and every audio sample equal
- [x] `render --transcribe` with `HF_HUB_OFFLINE=1`: 2 of 2 clips word for word, nothing fetched.
  Earlier, on the 034 film's 38 clips: 28 word for word, the rest homophones or digits for
  spelt-out numbers
- [x] `setup.sh --with-whisper` on the existing install: verifies the Kokoro checksums, skips
  what is there, provisions the Whisper model. A download of a missing file exits 1 and leaves
  nothing behind
- [ ] The fixes for the four held findings have not been re-checked by the reviewer; the other
  four findings of that round are open and recorded as known limits
- [ ] `setup.sh` has not been run from a clean machine
- [ ] Not run on x86_64; this box is aarch64
- [ ] The narration has not been listened to by its author, only transcribed
- [ ] The lints see geometry at rest poses only: not balance, crowding, or anything mid-animation

🤖 Generated with [Claude Code](https://claude.com/claude-code)
