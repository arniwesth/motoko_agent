---
repo: arniwesth/motoko_agent
pr: 216
branch: feat/dagr-verified-writes
ticket: null
title: "feat(ext): herdr — verified writes to dagr files: RunRecord and the dagr fork (021 ADR-002)"
---

## Summary

**Draft: documents only so far, no code.** On 2026-10-04 an orchestrator was asked to record the
operator's rulings and had no way to do it. It hand-wrote a dagr plan file with a cause type the
contract does not have, which nothing checked for nearly three hours, and it later reported a
ruling as recorded when no file had changed. The answers also never reached the dagr view, because
the view draws the extension's own run file.

ADR-002 records two operator rulings made in response: the tree moves to our fork of dagr, pinned,
for its `dagr apply` command; and the herdr extension gets a tool for operator input. It proposes
that tool, `RunRecord`, which writes an operator's answer or ruling through the extension's
existing validate-then-publish path, and refuses a quote the operator did not write. PLAN-001
sequences the work by surface.

Four questions in ADR-002 §7 are open for the operator, and nothing in the plan starts before they
are ruled. The fork ruling reverses F2 of 008's ADR (draft PR #215), which that PR's owner needs to
record.

## Changes

- docs(021): ADR-002 and PLAN-001 — verified writes to dagr files

3 files changed, all under `.agent/projects/021_herdr_delegation/`: the ADR and the plan are new,
and the design doc gains §10.7, which says the fork is adopted and points at both.

## Governing docs

- `.agent/projects/021_herdr_delegation/ADR-002-verified-writes-to-dagr-files.md`
- `.agent/projects/021_herdr_delegation/DESIGN-dagr-as-delegation-view.md`
- `.agent/projects/021_herdr_delegation/PLAN-001-implement-adr-002.md`

Also relevant, not changed here: `ADR-001-run-file-authorship-and-correspondence.md` in the same
folder (D1 and its corollary), and
`.agent/projects/008_docs_system/ADR-001-plan-structure-in-dagr-and-retiring-linear.md` on branch
`arniwesth/008-plan-structure-in-dagr` (PR #215).

## Predicted outcome

As it stands, landing this changes no behaviour: it adds two documents and one section.

When the implementation is in:

- An operator's answer to a `question` task, or a ruling, is recorded by a `RunRecord` call and
  shows in the dagr view. The call is refused if the quoted words are not in one of the operator's
  messages.
- "Recorded" can be checked: the tool result names the file, the task and what was written, and a
  claim with no such call in the journal is false.
- In orchestrator mode a hand edit under `.dagr/` is refused with text that names the tool, and an
  invalid plan file is reported at every write point.
- `dagr` in CI and in the container is built from `motoko-agent/herdr-dagr` and has `apply`, so a
  writer that is not the extension changes a dagr file with a patch that is validated and can be
  refused.

Checked by ADR-002's acceptance criteria A1 to A10, and against a baseline of the gates taken
before the first change (PLAN-001 P0).

## Test evidence

Nothing is built, and no gate was run for this PR.

- [x] **The anchors.** Every `file:line` the ADR and the plan cite was read at `b863ee20`, and the
  14 `make` targets PLAN-001 P0 names all exist in the `Makefile`.
- [x] **The failure the ADR starts from.** `dagr check --strict --json` on the hand-edited plan
  file returned four `E133` errors (*"unknown cause type \"operator_ruling\""*) and four `W203`
  warnings. After the repair it returns `[]`. The file is local (`.dagr/` is gitignored).
- [x] **The fork.** Read through the GitHub API: `apply-command` is at `ca248980`, eight commits
  ahead of `v0.3.1` and none behind; the `apply` commit touches only `src/apply.rs` (+399) and
  `src/main.rs` (+84); the fork has no releases and has Actions enabled.
- [ ] **`dagr apply` itself was not run.** There is no Rust toolchain in this container and the
  fork has no release. What it does is taken from its source and from the design doc's §10.6.
- [ ] **Implementation and A1 to A10:** not started.
