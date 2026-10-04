---
repo: arniwesth/motoko_agent
pr: 215
branch: arniwesth/008-plan-structure-in-dagr
ticket: null
title: "docs(008): ADR-001 — plan structure lives in a committed dagr document, Linear is retired"
---

## Summary

Adds the decision record for leaving Linear and making dagr the single source of truth for plan
structure. The structure of planned work is written in three places today (Linear, `PLAN-*.md`
prose, and gitignored `.dagr/` files) and none is authoritative; the ADR gives each plan one
committed `PLAN-NNN.dagr.json` and keeps run state local.

This PR adds the document only. Nothing it decides is executed here: the Linear coupling in
`tools/pr`, `.mcp.json` and the devcontainer is still in the tree.

## Changes

- docs(008): ADR-001 — plan structure lives in a committed dagr document, Linear is retired

1 file changed.

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

The operator closed the four forks on 2026-10-04, each as recommended. One thing is still owed
from that ruling: which of the 24 open Linear issues are still wanted (Appendix A).

## Governing docs

- `.agent/projects/008_docs_system/ADR-001-plan-structure-in-dagr-and-retiring-linear.md`
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

## Test evidence

No code changed, so there is nothing to build. What was checked while writing:

- `dagr check --strict` (0.3.1) on structure-only projections of the seven existing plan files:
  clean on the 28-task and 40-task plans once `generated_at` is present; W100 without it.
- Same check with a top-level `plan` block and per-task `refs` added: clean.
- Same check with `state` omitted from every task: 28 errors on 28 tasks.
- Same check with a dependency on a task in another document: 1 error.
- Every repo path the ADR cites was resolved against the tree at `cf54dff9`: 48 checked, none
  missing.
- Linear was read through its MCP server on 2026-10-04: 137 issues, 24 not closed.

Not done:

- [ ] `make verify_dagr_producer` was not re-run
- [ ] The fork's `dagr apply` command was not built or exercised; its description comes from the
      021 design note
- [ ] Three of the four checks the ADR names (§6) do not exist yet
- [ ] Only MOT-136 and MOT-134 of the 24 open Linear issues were compared with the tree
- [ ] The probe scripts are not in the tree

🤖 Generated with [Claude Code](https://claude.com/claude-code)
