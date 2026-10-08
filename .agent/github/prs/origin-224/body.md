---
repo: arniwesth/motoko_agent
pr: 224
branch: docs/013-eval-matrix-explainer
ticket: null
title: "docs(013): explainer film for `make eval_matrix` — scenes and README"
---

## Summary

Adds a narrated explainer film of `make eval_matrix` to project 013, made with `tools/explainer`:
what the target runs, what it compares, what its output means and what it is for. It is for a
reader who knows the repository but not project 013. Seven scenes, 4 min 46 s at 1080p.

The branch carries the scenes file and a README. The rendered `.mp4` is git-ignored
(`.agent/projects/**/video/*.mp4`) and is rendered again from the scenes file.

Documents only. No source, gate or `Makefile` change.

## Changes

- docs(013): explainer film for `make eval_matrix` — scenes and README

2 files changed.

## Governing docs

- `.agent/projects/013_core_architecture_for_dst/video/README.md`

The film describes `.agent/projects/013_core_architecture_for_dst/PLAN-004-implement-adr-004.md`
§0.8 and §3 "The D8 P1 matrix", and `ADR-004-journal-as-evaluation-source.md` D3 and D8, as
`scripts/eval/candidate.py` implements them at `59d5cbb9`. It changes none of them.

## What the film says

| Scene | Length | What it shows |
|---|---|---|
| `S1_Question` | 38 s | The evaluator of ADR-004, its verdicts, and the table of 621 known cases that checks them. |
| `S2_Row` | 40 s | One row of `MATRIX.expected.tsv`, then the table by `expected_verdict`. |
| `S3_Run` | 45 s | The 27 files rows name plus one gate, run one at a time; `MATRIX.tsv` gets observed fields only. |
| `S4_Join` | 43 s | The join on `case_id`, its statuses and the exit rule. |
| `S5_Tiers` | 38 s | The record tier and the assertion tier; the clean run of 17 September. |
| `S6_Red` | 45 s | The run at `59d5cbb9`, red on 3 of 28 suites, and why it is read as a difference. |
| `S7_Not` | 37 s | Not in `make dst`, not in CI, not a run on a real session, not an evaluation of a change. |

## What the source showed that was not expected

Each is recorded in the README with its file.

- **The exit status.** `candidate.py matrix` returns 0 or 1. The 2 in the run records is `make`'s
  status for a failed recipe.
- **28 suites, 27 named by rows.** `scripts/eval/test_mem_guard.py` is named by no row and runs
  last as a gate.
- **The September output joins clean.** The 011 spike note's Part 6 says the operator's last
  matrix output has one failing row. That file is still in the main checkout, untracked, with the
  sha256 PLAN-004 §6 records. Joined to the expected table it gives 185 equal, 425 credited and 11
  inapplicable. Its one `fail` is `M7.crosscheck_detects_short_span`, whose row expects `fail`.
- **The run at `59d5cbb9` matches the one at `259265b5`** in every count: 621 rows, 419 credited,
  129 equal, 29 failed, 33 missing, 11 inapplicable, the same three suites red.

## Predicted outcome

A reader can learn what `make eval_matrix` is from a five-minute film and a README, without
reading `candidate.py` first. Nothing that runs changes.

The film is dated. Scenes 5 and 6 show the counts of two runs and will be out of date once the
three red suites are fixed or the expected table gains rows. The README says which constants and
captions to change for a later run.

Checked by rendering it: `tools/explainer/explainer render` on the scenes file exits 0 and writes
the film beside it.

## Test evidence

- [x] **`tools/explainer/explainer render eval_matrix.py --transcribe`** at full quality: exit 0,
  7 scenes, 4 min 46 s, 1920×1080 at 30 fps. Lint 0 errors, 0 warnings.
- [x] **`tools/explainer/explainer check eval_matrix.py`**: exit 0.
- [x] **Voice**: 35 clips, 216 s of speech, no overlaps, worst sync 27 ms, -17.2 LUFS.
- [x] **Transcription**: 21 of 35 clips word for word. Thirteen differ by digits, initialisms,
  punctuation or homophones. One is a mishearing, below.
- [x] **Layout checked by eye** on contact sheets of two drafts and on full-size frames of the
  final render.
- [x] **Every number on screen was read from a file**, and the README lists them. The run at
  `59d5cbb9` is the 011 plan's baseline run of 2026-10-06 on a clean worktree of `origin/main`.
- [x] **The status colours were validated** against the film's background with the dataviz
  skill's palette validator: all checks pass.

Not done:

- [ ] The voice was never listened to. A transcription shows the words are right, not that the
  delivery is natural.
- [ ] The film's first line, "Make eval matrix", is heard by Whisper as "Make a vowel matrix".
  Four other spellings did no better. The title is on screen as it is said.
- [ ] `make eval_matrix` was not run for this PR. The film reads another session's run.
- [ ] No gate was run on this branch. It changes documents only.
- [ ] The cause of the parser cross-check failure in `tools/eval_protected/selftest.py` is not
  known. The film says only that it fails.
- [ ] The run's `MATRIX.tsv` and suite logs are not committed. They are in
  `tmp/plan-011-baseline-2026-10-06/` of the main checkout; the README gives their hashes.
- [ ] The `.mp4` is not committed. A copy is in `tmp/eval-matrix-explainer/` of the main checkout.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
