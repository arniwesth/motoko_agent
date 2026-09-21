# LEG-P1.6r-a2 — follow-up: the DST driver scripts the migration left half-done (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). This is a **follow-up on P1.6r** (scripts onto
8.0, `6d668fdd`, accepted), for breakage the `R-G` checklist does not cover and a full `make dst DST_JOBS=1`
sweep did. You do not edit the ADR or the plan, you do not write the dagr run file, and you do not touch
other panes or worktrees.

## What is red, and why

The orchestrator's full sweep at `4571c21f` (`evidence/R-G/sweep2/make-dst-summary.txt`; the full log is
`.ailang/dst-last.log` until the next sweep) — **9 NEW reds**; at SWEEP (`75fefdcb`) the only reds were
`profile_definition`/`driver_only`, now green:

| target | first error |
|---|---|
| `corpus_pr` | `scripts/dst/corpus_pr_dst.ail:339` record field mismatch: expected 10 fields, got 9 |
| `corpus_rotating` | `corpus_rotating_dst.ail:197` expected 10 fields `{budget, compact, config, describe, intercept, judge, policy, prompt, provide, tools}` |
| `latency_pair` | `latency_pair_dst.ail:158` same |
| `seeded_generator` | `seeded_generator_dst.ail:303` same |
| `strict_replay` | `strict_replay_dst.ail:284` same |
| `discovery` | `discovery_dst.ail:464` return type: expected 9 fields, **got 10** |
| `driver_plus_compose` | `driver_plus_compose_dst.ail:653` field `registry`: expected `{caps, id}` |
| `park_wake` | in-process fixtures exit 1; every frame missing |
| `depth_canary` | seeds 7, 11, 23 "exited 1 without RT_REC_003 — unrelated failure" |

**Why nobody owned them:** P1.1's inventory gave each file **one** owner. These files carry a manifest ABI
pin, so they were filed under P1.5r, which moved the pin — and the 8.0 type break in the same file fell
between owners. The shape is P1.6r's exactly: `FixtureOverrides`/fixture literals missing `config`, entries
missing config, 7.4 registry shapes.

## What you do

Bring every file behind these 9 targets onto 8.0, changing only what 8.0 requires and keeping every
assertion — the same way P1.6r did its 13 (`git show 6d668fdd -- scripts/`) and batch D its masked files
(`git show a3a82311 -- scripts/`). `discovery`'s "expected 9, got 10" runs the other way: find which side
is stale before changing either. For `park_wake` and `depth_canary`, find the first real error (likely a
file above that no longer compiles) before touching the canary's pins — its header says a red pin means a
new depth result **or** an unrelated failure; this is the second.

## Exit checks

1. Each of the 9 targets **green** in the primary checkout at your commit (you are the only delegate
   running; nothing else writes). If one stays red, say exactly on what and whose.
2. Then run **`make dst DST_JOBS=1`** yourself, alone (heavy: nothing else heavy may run; about 35 minutes),
   and report its summary. The expected result is **0 NEW reds**; the register's two entries
   (`driver_plus_herdr`, `herdr_graded`) pass and are not yours to edit.
3. mutgate from a fresh clone, spec under `evidence/P1.6r-a2/`: one row per changed file (revert its 8.0 change
   → its target or check → red). Traps as in every brief: lock-free workspaces for checks that compile
   against packages; `cmd | grep -q X` → exit 141; rows assert your own files' results.

Last act: commit `ADR-001 (031) P1.6r: follow-up — the DST driver scripts onto 8.0 (full sweep green)`, then
print `RESULT P1.6r-a2` with the sweep's summary. Scope: `scripts/` only (not `src/`, `packages/`, `tools/`);
stage only your paths; never `git stash`; do not edit the plan/ADR/`.dagr/`; do not touch pane `w3:p1`, tab
`w3:t1`, pane `w3:pZ` or `/workspaces/motoko_agent-eval`.
