---
repo: arniwesth/motoko_agent
pr: 215
branch: arniwesth/008-plan-structure-in-dagr
ticket: null
title: "docs(008): ADR-001 — plan structure lives in a committed dagr document, Linear is retired; with the AILANG planning research"
---

## Summary

Adds the decision record for leaving Linear and making dagr the single source of truth for plan
structure. The structure of planned work is written in three places today (Linear, `PLAN-*.md`
prose, and gitignored `.dagr/` files) and none is authoritative; the ADR gives each plan one
committed `PLAN-NNN.dagr.json` and keeps run state local.

It also adds a research note on how upstream AILANG runs its planning and documentation, read
after the ADR was accepted, with the nine readers' notes filed as evidence. The note is outside
evidence for the ADR's D2 and D3: AILANG's one machine-checked planning block held, and its prose
queue did not.

The ADR was amended the same day with D8, after reading Midspiral: once a task has been started,
the terms it is judged by change only by directive. D2 and D4 together would otherwise have let an
agent loosen a task's criteria until the task could settle.

This PR adds documents and one evidence script only. Nothing the ADR decides is executed here: the Linear coupling in
`tools/pr`, `.mcp.json` and the devcontainer is still in the tree.

## Changes

- docs(008): ADR-001 — plan structure lives in a committed dagr document, Linear is retired
- docs(008): research — AILANG's planning and docs system read in full, with the readers' notes
- docs(008): amend ADR-001 with D8 — a started task's acceptance terms change only by directive
- chore(github) commits recording this PR

12 files under `.agent/projects/008_docs_system/`: the ADR, the research note, nine evidence
files (about 525 KB) under `evidence/ailang-survey/`, and `evidence/spec_edit_probe.py`.

What the ADR decides, in short:

- **D1** Linear is retired. The workspace stays read-only so existing `MOT-` ids still resolve.
- **D2** One committed dagr document per plan, with no attempts, events or pane ids.
- **D3** `PLAN-*.md` stops restating structure. New plans only.
- **D4** Run state stays local in `.dagr/`; structure flows one way from the plan into it. This
  changes the seed-once rule set in `021_herdr_delegation/DESIGN-dagr-as-delegation-view.md` §10.5.
- **D5** Pane bindings and grants move out of the plan into a local binding document.
- **D6** A task's address is `NNN/PLAN-NNN/<task id>` and replaces `MOT-N`.
- **D7** Stay on upstream dagr 0.3.1. The fork is deferred until cross-plan dependencies or a
  portfolio view are wanted in dagr.
- **D8** (amendment) Once a task has an attempt, a change to its `criteria`, `deps`, `inputs`,
  `kind` or `policy`, or cancelling it, needs a `directive` naming the task. This narrows D4.

The operator closed the four forks on 2026-10-04, each as recommended, and approved D8 the same day. One thing is still owed
from that ruling: which of the 24 open Linear issues are still wanted (Appendix A).

What the research note adds, in short:

- AILANG's queue of planned work is 749 KB of prose that a program cannot parse for open work.
  AILANG itself dropped "open queue rows" as its progress measure.
- Its decision ledger, a marked block a script validates, is the part that held up.
- Status encoded in a directory path drifts both ways there: 27 completed sprints' design docs
  still sit in `planned/`, and 51 sprint files point at a path that no longer exists.
- Thirteen candidate follow-ons for Motoko are listed in the note's §6. None is decided by this PR.
- An addendum (§9) covers Midspiral, the source of the observation behind D8. Motoko already uses
  its claimcheck technique in `packages/motoko-ext-compose/claimcheck.ail`.

## Governing docs

- `.agent/projects/008_docs_system/ADR-001-plan-structure-in-dagr-and-retiring-linear.md`
- `.agent/projects/008_docs_system/RESEARCH-ailang-planning-system-implications.md`
- `.agent/projects/021_herdr_delegation/DESIGN-dagr-as-delegation-view.md` §10 — the plan/run split
  this builds on, and the rule D4 changes
- `.agent/issues/herdr-extension-run-file-drifts-from-operator-plan-file.md` — the open issue D2,
  D4 and D5 answer
- `.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md` D4 — the PR record's
  frontmatter, which D6 changes

## Predicted outcome

Landing this changes no behaviour. It makes the decision citable from `main`, so the
implementation handoffs can be written against it.

The ADR's own predictions settle at project close, not at merge (§8): no PR record created after
the coupling is removed carries a `MOT-` id; for each plan started under the ADR, the committed
plan and the settled run agree on task ids and dependencies at close-out; and the run-file drift
issue closes. Its kill criterion: if the orchestrator makes structural edits in a `.dagr/` copy
that never reach the committed plan during the first two plans run this way, D2 has failed.

The research note makes no prediction. Its candidates become checkable only if one is taken up.

## Test evidence

No code changed, so there is nothing to build. What was checked while writing the ADR:

- `dagr check --strict` (0.3.1) on structure-only projections of the seven existing plan files:
  clean on the 28-task and 40-task plans once `generated_at` is present; W100 without it.
- Same check with a top-level `plan` block and per-task `refs` added: clean.
- Same check with `state` omitted from every task: 28 errors on 28 tasks.
- Same check with a dependency on a task in another document: 1 error.
- Every repo path the ADR cites was resolved against the tree at `cf54dff9`: 48 checked, none
  missing.
- Linear was read through its MCP server on 2026-10-04: 137 issues, 24 not closed.

What was checked while writing the research note:

- AILANG was read at `sunholo-data/ailang` `dev` `2a1f3f295` from a sparse clone.
- Twelve statements the note leans on were re-read in the AILANG source and all held. They are
  marked `[checked]` in the note.
- Counts marked `[measured]` were produced by scripts in the session.
- Every local path the note cites resolves in this branch.
- The evidence files were scanned for emails, tokens and home-directory paths: none found.

What was checked while writing the D8 amendment:

- `evidence/spec_edit_probe.py`, the smallest version of the D8 check, was run on three local pairs
  of plan files. Between `.dagr/run-plan004.json` and `.dagr/run-plan004-v2.json` (31 tasks in
  common, 13 started) it found the criteria of 2 started tasks rewritten with no directive naming
  them. On the other two pairs it found no change.
- Five Midspiral posts were fetched directly and every quoted passage was found word for word.
- Every local path the amended ADR and note cite resolves in this branch: 47 and 16 checked.

Not done:

- [ ] `make verify_dagr_producer` was not re-run
- [ ] The fork's `dagr apply` command was not built or exercised; its description comes from the
      021 design note
- [ ] Three of the four checks the ADR names (§6) do not exist yet
- [ ] Only MOT-136 and MOT-134 of the 24 open Linear issues were compared with the tree
- [ ] The probe scripts behind the ADR's §2.3 are not in the tree; the D8 probe is
- [ ] The D8 probe cannot tell whether an edit weakened a task's terms, does not cover `policy` or
      cancellation, and reads gitignored local files, so its run cannot be repeated from the tree
- [ ] D8's refusal at re-projection is not built
- [ ] Three of Midspiral's ten posts were read only as summaries and two were not read
- [ ] Most statements in the research note rest on a reader's notes and were not re-checked
- [ ] AILANG's incident numbers are its own records; none was checked against logs or CI
- [ ] The AILANG clone had no git history, so claims about change over time come from dates in
      the text
- [ ] Parts of AILANG's coordinator, messaging and docs site were not opened; the note's §7 lists
      them

🤖 Generated with [Claude Code](https://claude.com/claude-code)
