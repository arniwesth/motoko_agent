---
repo: arniwesth/motoko_agent
pr: 222
branch: docs/uncommitted-notes-and-research
ticket: null
title: "docs: land the notes, research and drafts that were uncommitted on main"
---

## Summary

The shared `main` checkout had collected documents that were never committed: a new project's ADR,
three research notes, an addendum to an existing note, two explainer scripts, the retrospective and
blog drafts, and two issue records. This PR lands all of them in one commit so the checkout can be
cleaned. No document was edited on the way in; they are as they were written.

The two rendered explainer videos (about 30 MB) are left out, and `.gitignore` now ignores
`.agent/projects/**/video/*.mp4`. Each video folder keeps its script and a README that says how to
render it.

## Changes

- docs: land the notes, research and drafts that were sitting uncommitted on main

29 files changed: 27 added, 2 modified.

| Area | Files |
|---|---|
| 034 ambiguous tool outcomes (new) | `ADR-001-effect-disclosure-for-tool-faults.md`, `NOTE-scope-effect-unknown-tool-faults.md`, `mmd/` (three diagrams, source and SVG), `evidence/exec_probe.sh`, `video/explainer.py` and its README |
| 030 harness playbook | §8, the 2026-10-01 re-grounding addendum, added to `RESEARCH-harness-playbook-implications.md` |
| 035 antithesis-inspired testing (new) | the research note and `REVIEW-001-claude-fable-5.1.md` |
| 036 chDB memory (new) | `RESEARCH-chdb-memory-for-motoko.md` |
| 007 DST consolidation | `video/dst.py` and its README |
| `docs/` (new) | six-month retrospective scope, its review and the handoff; the frontier-of-abstraction draft (`.md` and `.html`) and note; the 2026-10-04 DST demo run and its evidence file |
| Issue records | `.agent/issues/two-ailang-binaries-the-vendored-one-is-undeclared-and-stale.md`; `.agent/github/issues/origin-203/body.md` |
| `.gitignore` | ignore rendered explainer videos |

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md`
- `.agent/projects/034_ambiguous_tool_outcomes/NOTE-scope-effect-unknown-tool-faults.md`
- `.agent/projects/030_harness_playbook/RESEARCH-harness-playbook-implications.md`
- `.agent/projects/035_antithesis_testing/RESEARCH-antithesis-inspired-testing.md`
- `.agent/projects/035_antithesis_testing/REVIEW-001-claude-fable-5.1.md`
- `.agent/projects/036_chdb_memory/RESEARCH-chdb-memory-for-motoko.md`
- `.agent/projects/007_dst_consolidation/video/README.md`
- `.agent/projects/034_ambiguous_tool_outcomes/video/README.md`
- `.agent/projects/034_ambiguous_tool_outcomes/mmd/README.md`

## Predicted outcome

- After this merges, the shared checkout's untracked list no longer contains these documents, and
  the 030 note's §8.3 reference to the 034 note resolves on `main`.
- The mp4s stay on disk beside their scripts and stop appearing in `git status`.
- No behaviour changes: nothing under `src/`, `packages/`, `tools/` or `scripts/` is touched.

Known loose ends, left as written:

- The two video READMEs describe the mp4 as present in the folder; it is now a local render.
- The two-AILANG-binaries issue cites `tmp/ISOLATION-FINDINGS.md` and `tmp/ISOLATION-REVIEW.md`,
  which are not tracked.
- `docs/motoko-blogpost-handoff.md` is a session handoff, and says it is not authorization to
  publish the blog.

## Test evidence

Documents only; no gate was run.

- [x] **No mp4 is in the commit.** `git ls-tree -r --name-only HEAD | grep -c '\.mp4$'` prints 0.
- [x] **The ignore rule matches the renders.** `git check-ignore -v` on
  `.agent/projects/034_ambiguous_tool_outcomes/video/effect-disclosure-explainer.mp4` names the new
  `.gitignore` line.
- [x] **Nothing outside `.agent/`, `docs/` and `.gitignore` changed.** `git diff --stat origin/main
  HEAD` over every other path is empty.
- [ ] The contents of the documents were not reviewed or re-checked against the tree for this PR.
