# LEG-P0 — the baseline (PLAN-001 §2)

You are a delegate of the 037 orchestrator (pane `w8:p1`). You own exactly this task. You do not
implement any other part, you do not edit the ADR or the plan, you do not write the dagr run file,
and you do not touch other panes, tabs or worktrees.

## What this is

`P0` in `PLAN-001-implement-adr-001.md` §2. Run every gate ADR A7 names and record, for each,
whether it is green or red and the first lines of its failure. **Nothing is changed.** The output
is the baseline every later pin move is checked against: a gate red before may not gain a failure.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §0 standing rules, §2 (this part).
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — §2 acceptance item **A7** (the gate list).
3. `Makefile:697` — `DST_KNOWN_RED` (expected: `driver_plus_herdr` is known-red).

## Grounding

Branch `feat/skills-extension` in worktree `/workspaces/motoko_agent-skills`, HEAD `7bc7b48e`
(documents-only on top of `main` at `cf54dff9`; `src/`, `packages/`, `scripts/`, `tools/`,
`Makefile` byte-identical to `cf54dff9`). AILANG v0.47.2, extension ABI 8.0. Verify before you
start: `git rev-parse HEAD`, `ailang --version`, and confirm `git status --short` shows no
modification to `src/`, `packages/`, `scripts/`, `tools/` or `Makefile` beyond what is already
recorded as other sessions' (the tools/code-graph change, `Makefile`, `ailang.lock` — leave all
of those alone, do not commit anything).

## The gates (16 total)

In CI (`.github/workflows/verify-extensions.yml:99`, `:164`): `check_core`, `profile_definition`,
`driver_only`, `profile_coverage`, `conformance`, `ext_call_inventory`, `ext_call_inventory_selftest`,
`test_coverage`.

Outside CI: `registry_gen_check`, `registry_multiplicity`, `ext_hook_scope`, `ext_ambient_inventory`,
`declared_vs_performed`, `driver_plus_no_ops`, `driver_plus_compose`, `driver_plus_herdr`.

Run each as `make <gate>` from the repo root. Expected but unverified (record, do not fix):
`driver_plus_herdr` is in `DST_KNOWN_RED`; `ext_hook_scope` may exit 1 on `test_dummy`'s
registration shape; the profile count pins may be stale by one because `ailang_tools` is in none
of the four omitted lists.

## Rules that bind you

- **Read-only.** Do not edit any file in the tree. No commits.
- **Heavy runs one at a time.** The DST targets are slow and the machine is shared; run gates
  serially, never two heavy targets in parallel.
- Do not touch the shared checkout at `/workspaces/motoko_agent`, the worktree
  `/workspaces/motoko_agent-fix3`, or any other session's panes.

## Output

Report back to the orchestrator (pane `w8:p1`) with a typed result envelope: per gate, the exit
status and the first failure lines. Do NOT write the evidence files yourself — the orchestrator
writes `evidence/baseline/BASELINE.tsv` (gate, result, first failure line, commit) and the raw
logs beside it from your envelope, so that the record's authorship stays with the session that
checked it.

## Exit checks

Every gate has a row: green with its passing output, or red with the first lines of its failure.
`driver_plus_herdr`'s red (if red) is the baseline, not a failure of this task.
