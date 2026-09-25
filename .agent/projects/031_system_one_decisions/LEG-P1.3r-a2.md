# LEG-P1.3r-a2 — follow-up: take the conformance harness out of production core (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). This is a **follow-up attempt on P1.3r**
(`4109827b`, accepted), for one regression found after it landed. You do not edit the ADR or the plan,
you do not write the dagr run file, and you do not touch other panes or worktrees.

## The regression

P1.3r added `src/core/ext/runtime.ail:40`:
`import pkg/sunholo/motoko_ext_conformance/harness (neutral_registration)` — used **only by tests**
(`:1738`, `:1744` at `4109827b`; re-find at HEAD, P1.4r has since edited the file). The harness module
declares its own `Scenario`, which collides on the pin (v0.33.0) with core `dst_harness.Scenario`: any
program that reaches both fails on a **cold cache**, and which side breaks depends on compile order.
Batch C found it: `evidence/P1.2c/scenario_collision_probe/min_collision.ail` (red at `4109827b`, clean at
`a7aa68a8`) and `evidence/P1.2c/README.md` §"Scenario". Production core must not import a conformance
kit for its tests. (`runtime.ail`'s **older** import of `motoko_ext_conformance/invariants`
(`validate_compactor_output`, used in production) is **not** this regression — leave it.)

## What you do

- Move the tests that use `neutral_registration` out of `runtime.ail` into a test module under
  `src/core/test/` (or wherever the repo's convention puts core tests that need the kit), keeping every
  assertion. Drop the harness import from `runtime.ail`.
- **Anchor-neutral**: `runtime.ail` carries the pinned `:199` anchor, and P1.3r placed the import "in place
  of a blank line" to hold it. Restore line-neutrality (`make anchors`, `make driver_leaf_inventory`
  byte-identical to HEAD).

## Exit checks

1. `evidence/P1.2c/scenario_collision_probe/min_collision.ail` checks **clean on a cold cache** at your
   commit (build a fresh workspace; say how you ensured the cache was cold).
2. Every tracked `src/core` module on 8.0 (`evidence/P1.1/p11_core_check.sh check <all>`; expect 71/72 or
   better — say what fails and why); `ailang test` on `runtime.ail` and the new test module: the same
   assertions pass (count them before and after).
3. `make anchors`, `make driver_leaf_inventory` neutral.
4. mutgate from a fresh clone, spec under `evidence/P1.3r-a2/` with repo-relative paths: re-add the
   harness import to `runtime.ail` → the cold-cache collision probe → red; drop one moved test → the count
   check → red. Known trap: `cmd | grep -q X` under `set -o pipefail` → exit 141.

## Last act

Commit `ADR-001 (031) P1.3r: follow-up — conformance harness out of production core (Scenario collision)`,
then print `RESULT P1.3r-a2` (head_before, commit, files_touched, tests before/after, probe result, anchors,
mutgate). Rules: `src/core` only (you are its sole writer), stage only your paths, never `git stash`, do not
edit the plan/ADR/`.dagr/`, do not touch pane `w3:p1`, tab `w3:t1`, pane `w3:pZ` or
`/workspaces/motoko_agent-eval`.
