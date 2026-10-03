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

20 files changed, all under `tools/explainer/`:

- **`explainer_kit/`**: the scene kit (`say()` puts a caption up and speaks it, `rest()` waits
  for both), Kokoro narration cached per caption, geometry lints from Manim's own bounding boxes,
  and the CLI.
- **`explainer`**: the launcher. Commands: `lint` (draws nothing), `render`, `check`, `say`,
  `sheet`, `doctor`. Exit 0 clean, 1 could not render, 2 rendered but a check failed; `--json`
  prints the report alone.
- **`setup.sh`**: installs Manim, ffmpeg and Kokoro without root, via micromamba, under
  `~/.local/share/manim-env-root` (about 1.5 GB).
- **`selftest.sh`** and **`examples/`**: one scene per geometry check with that defect seeded.
- **Seven Computer Modern fonts** (3.6 MB of binary files) with their SIL Open Font License.
  There is no LaTeX; all text is Pango `Text`.

Nothing outside `tools/explainer/` changes. The tool is not wired into the Makefile, CI, the TUI
or Motoko's runtime, and there is no extension exposing it to a session yet.

## Governing docs

None. No ADR governs this tool. It came out of an experiment in
`.agent/projects/034_ambiguous_tool_outcomes/video/`, and that project folder is not on `main`,
so the README's pointer to the worked example dangles until 034 lands.

Exposing the tool to a Motoko session is a separate piece of work and does want a design note
first: a render takes minutes against `BashExec`'s 30-second wall, and Motoko drops image parts
at the `Msg` seam, which is why the checks here are numeric.

## Predicted outcome

- A narrated film is one command: `tools/explainer/explainer render FILM`.
- `explainer lint FILM` reports off-frame text, overlapping text, shapes in the caption and
  unread captions in seconds, without drawing anything.
- No effect on anything that exists: nothing imports the tool.

Checked by `tools/explainer/selftest.sh`. The first real test of the install path is running
`setup.sh` on a machine that does not already have the environment.

## Test evidence

- [x] `tools/explainer/selftest.sh`: `ok, 6 seeded defects each flagged as its own kind, 2 clean
  scenes clean`, in about eight seconds
- [x] `explainer render examples/minimal.py --draft`: exit 0, lint clean, voice sync worst 23 ms,
  -17.3 LUFS
- [x] The 034 film (not in this PR) rendered through the tool: 8 scenes, 4 min 11 s, lint clean,
  all 38 clips within 25 ms of their scheduled starts, -17.3 LUFS, peak -0.9 dBFS
- [x] That render against the hand-built pipeline's last output: 7,534 frames at infinite PSNR,
  and every audio sample equal
- [x] Lint against the three layout defects the 034 film really had while it was made: two of
  three flagged (a label over another label, a stamp past the frame). The third was a comfort
  margin that no threshold separates from a fine layout
- [x] Whisper `small.en` on the 38 narration clips, run on the pre-extraction pipeline with the
  same clips: 28 word for word, the rest homophones or digits for spelt-out numbers
- [ ] `setup.sh` has not been run from a clean machine. The environment here was built by hand
  with the same commands, and `explainer doctor` passes against it
- [ ] Not run on x86_64; this box is aarch64
- [ ] The narration has not been listened to by its author, only transcribed
- [ ] The lints see bounding boxes at rest poses only: not balance, crowding, or anything
  mid-animation

🤖 Generated with [Claude Code](https://claude.com/claude-code)
