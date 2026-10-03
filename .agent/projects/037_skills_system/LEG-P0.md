# LEG-P0 — the baseline (PLAN-001 §2, dagr task `P0`)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this task. You do not implement any other part, you do not edit the ADR or the plan,
you do not write any dagr run file, and you do not touch other panes, tabs or worktrees.

## What this is

`P0` in `PLAN-001-implement-adr-001.md` §2. Run every gate ADR A7 names and record, for each,
whether it is green or red and the first lines of its failure. The output is the baseline
every later pin move is checked against: a gate red before may not gain a failure.

## Where you work

Worktree `/workspaces/motoko_agent-skills`, branch `feat/skills-extension`, HEAD `e483c2a8`
(documents-only on top of `main` at `cf54dff9`). Your `cwd` is that worktree root. Do not
touch the shared checkout at `/workspaces/motoko_agent`, the worktrees
`/workspaces/motoko_agent-fix3` and `/workspaces/motoko_agent-p1proto`, or any other
session's panes, tabs or paths. Push nothing.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §0 standing rules, §2 (this part).
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — §2 acceptance item **A7** (the gate list).
3. `Makefile:697` — `DST_KNOWN_RED` (expected: `driver_plus_herdr` is known-red).

## Grounding — verify before you start

- `git rev-parse HEAD` (expect `e483c2a8`; record the actual HEAD in the TSV whatever it is).
- `ailang --version` (expect v0.47.2) and the ABI line (expect 8.0).
- `git status --short` must show no modification under `src/`, `packages/`, `scripts/`,
  `tools/`, `Makefile` or `ailang.lock`. The orchestrator verified on 2026-10-03 that those
  trees are byte-identical to `main` at `cf54dff9` (`git diff cf54dff9 --stat` empty); if your
  check disagrees, stop and report — the tree moved under you.
- Re-ground don't re-cite: confirm each gate target exists (`grep -n "^<gate>:" Makefile`)
  before you run it. All 16 were present on 2026-10-03.

## The gates (16 total — the task's acceptance is one TSV row per gate)

In CI (`.github/workflows/verify-extensions.yml:99`, `:164`): `check_core`,
`profile_definition`, `driver_only`, `profile_coverage`, `conformance`, `ext_call_inventory`,
`ext_call_inventory_selftest`, `test_coverage`.

Outside CI: `registry_gen_check`, `registry_multiplicity`, `ext_hook_scope`,
`ext_ambient_inventory`, `declared_vs_performed`, `driver_plus_no_ops`, `driver_plus_compose`,
`driver_plus_herdr`.

Run each as `make <gate>` from the worktree root, serially — never two heavy targets at
once. The DST targets are slow and the machine is shared.

Expected but unverified (record, do not fix): `driver_plus_herdr` is in `DST_KNOWN_RED`;
`ext_hook_scope` may exit 1 on `test_dummy`'s registration shape; the profile count pins may
be stale by one because `ailang_tools` is in none of the four omitted lists.

Two cautions a newcomer gets wrong:

- This worktree is a fresh checkout with no installed dependencies or build output. A gate
  that is red here for want of a build is **not** a baseline red. Tell the two apart in the
  TSV: record the cause (`missing build output` vs the gate's own failure) in the
  first-failure-line column.
- ADR A7 additionally names `new_contract_policy` (it gates D2's reader, which P2 adds). It
  is outside this task's 16-gate acceptance; run it as a 17th informational row if cheap,
  and note if it could not run.

## Rules that bind you

- **Read-only outside your evidence directory.** No edits under `src/`, `packages/`,
  `scripts/`, `tools/`, `Makefile`, `ailang.lock` or `registry_generated.ail`. The only
  paths you may write are `.agent/projects/037_skills_system/evidence/baseline/`.
- Heavy runs one at a time. No credentials in any file or output.

## Output — you write and commit the evidence

- `.agent/projects/037_skills_system/evidence/baseline/BASELINE.tsv` with columns
  `gate\tresult\tfirst_failure_line\tcommit` — one row per gate, `result` is `green` or
  `red`, `commit` is the HEAD you actually ran at.
- Raw logs beside it: `evidence/baseline/logs/<gate>.log` (stdout+stderr, with the exit
  code as the log's first line, e.g. `exit=0`).
- Commit exactly those paths on `feat/skills-extension` (message
  `evidence(037): P0 baseline at <short-sha>`). Push nothing.

## Done when

Every one of the 16 gates has a TSV row: green with its passing output logged, or red with
the first lines of its failure. `driver_plus_herdr`'s red (if red) is the baseline, not a
failure of this task.

## What to send back

In your completed answer to the orchestrator (plain structured text — no pane, no typed
envelope): the per-gate table (gate, exit status, first failure lines), the commit you ran
at and committed evidence on, and anything that could not run and why.
