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
- chore(github): record PR #211
- fix(tools): explainer — address the review of PR #211

22 files under `tools/explainer/`:

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
  checks for the rest, and with `--full` a small narrated render.
- **Seven Computer Modern fonts** (3.6 MB of binary files) with their SIL Open Font License.
  There is no LaTeX; all text is Pango `Text`.

Nothing outside `tools/explainer/` changes, apart from this PR's own record. The tool is not
wired into the Makefile, CI, the TUI or Motoko's runtime, and there is no extension exposing it
to a session yet.

### Review

An independent review by Codex (`gpt-6.1-sol`), read-only, found 18 defects; it reproduced 16
and inferred two. The third commit addresses all 18.

**The reviewer's re-check found that only 8 of them are fully fixed** (1, 3, 8, 9, 13, 14, 15,
17). For the other ten the original reproduction now passes but a nearby input still triggers the
defect, and it lists 14 open items, four of them severe: a manifest that does not say which film
it belongs to, text that loses its identity when one character is removed, background strokes,
and a captions-only `check` that accepts a file that is not a movie. Two of the new regression
tests would pass with their fix reverted. A further fix pass is in progress; until it lands, read
the table below as what was attempted, not as what holds.

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

- [x] `tools/explainer/selftest.sh --full`, about twenty seconds:
  `geometry: ok, 12 seeded defects each flagged as its own kind, 3 clean scenes clean`,
  `units: ok, 8 of 8 passed`,
  `full: ok, fresh --json, narrated --scenes, late audio, missing film, crashed scene`
- [x] The same tests against the first commit: none of the six new seeded defects is flagged,
  the clean outline is falsely flagged, and no unit test passes
- [x] The reviewer's own probe films against the fixed tool: its geometry probe goes from no
  findings to five errors and a warning, its stroke probe to two errors; inherited and keyword
  narration are collected; an unrelated bad scene no longer blocks `--scenes`
- [x] The 034 film (not in this PR) rendered through the fixed tool: 8 scenes, 4 min 11 s, lint
  clean under the stronger checks, all 38 clips within 25 ms of their scheduled starts,
  -17.3 LUFS, peak -0.9 dBFS
- [x] That render against the one from before the fixes, and against the hand-built pipeline's
  last output: 7,534 frames at infinite PSNR and every audio sample equal
- [x] `render --transcribe` with `HF_HUB_OFFLINE=1`: 2 of 2 clips word for word, nothing fetched.
  Earlier, on the 034 film's 38 clips: 28 word for word, the rest homophones or digits for
  spelt-out numbers
- [x] `setup.sh --with-whisper` on the existing install: verifies the Kokoro checksums, skips
  what is there, provisions the Whisper model. A download of a missing file exits 1 and leaves
  nothing behind
- [ ] `setup.sh` has not been run from a clean machine
- [ ] Not run on x86_64; this box is aarch64
- [ ] The narration has not been listened to by its author, only transcribed
- [ ] Re-check by the reviewer: 8 of 18 fully fixed, 10 partly, 14 open items (see Review)
- [ ] The lints see geometry at rest poses only: not balance, crowding, or anything mid-animation

🤖 Generated with [Claude Code](https://claude.com/claude-code)
