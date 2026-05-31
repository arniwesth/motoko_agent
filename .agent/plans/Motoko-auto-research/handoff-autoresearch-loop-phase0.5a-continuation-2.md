# Handoff: close Phase 0.5a DoD #3 (kept transfer) under a Pro-rebalanced split

This continues after the Pro split rebalance and a full 3-iteration loop. Stay in
the Polyglot lane. Do not start ARC or Terminal-Bench work, and do not use Docker.

## Current State

- Branch: `autoresearch-loop`. New commits this session:
  - `cdd1caa Rebalance Polyglot split for DeepSeek V4 Pro`
  - `96a901e Rewire Polyglot harness: candidate prompt in linked worktree`
  - (docs commit for ledger/summary/plan/this handoff)
- Worktree `/workspaces/motoko_agent_polyglot_wt` is on branch
  `autoresearch/polyglot-pro` at `cdd1caa`, prompt reverted to the minimal baseline.
- Autoresearch session: `.motoko/autoresearch_polyglot/` (segment 1, `ar_state=Done`).
- Expected unrelated dirty state (do NOT revert): `.motoko/config/default/config.json`,
  `.emsdk/`, `.motoko/ar_bench_scratch/`, `.motoko/autoresearch_polyglot/`.

## What Is Done

- **Split rebalanced for Pro** (probed ~26 exercises). Stable correctness-failures
  are rare under Pro — only `pov` and `dominoes`.
  - TRAIN: `pov, connect, alphametics, food-chain, grep, poker`
  - TEST:  `dominoes, ledger, change, minesweeper, satellite, bowling`
  - New canary GUID, `immutable.sha256` regenerated, `checks.sh` anti-cheat grep now
    inspects the actually-used `$SYSTEM_MD`.
- **Harness rewired** (`scripts/ar_polyglot_harness.ail`): candidate prompt lives in
  the worktree (pointed via `POLYGLOT_SYSTEM_MD`), runner/TUI + splits come from main,
  `cwd=worktree` for git ops, `timeout_ms=1200000`.
- **Loop ran 3 iterations** through the live FSM:
  - run 1 baseline kept: TRAIN median `0.75` (`[0.833, 0.667]`, MAD `0.083`).
  - run 2 ReAct+Plan+Reflexion discarded: TRAIN `0.583`, slower.
  - run 3 efficiency/step-budget discarded: TRAIN `0.5`. Patience exhausted.
- **Held-out TEST (single pass):** baseline `0.500`; discarded ReAct candidate `0.667`.
- **Integrity gates all block:** empty-prompt no-op, TEST-leak cheat, immutable tamper.

## The Binding Constraint (read before doing anything)

DoD #3 (a kept scaffolding change that transfers to TEST) is **unmet**: both
candidates were soundly discarded and none beat the baseline. The held-out grade
showed the discarded ReAct candidate scoring *higher* on TEST than its TRAIN
regression. The cause is **R-noise**: at `samples=2` over 6 exercises the primary's
timeout-driven variance (`connect`/`ledger`/`bowling` flip around the 180s cap,
≈0.167/exercise) is comparable to candidate effect sizes, so keep/discard does not
transfer. Do **not** re-run candidates hoping variance lands a keep — that is the
p-hacking the loop exists to prevent.

## Recommended Next Work (to close DoD #3)

1. **Raise the signal-to-noise ratio first**, then re-run. Two levers:
   - Increase `samples` (4-6) in `ar_polyglot_harness.ail` so MAD reflects the true
     primary noise. Cost scales linearly (each TRAIN sample ≈ 10 min).
   - Make the primary less timeout-bound. Either raise `POLYGLOT_EXERCISE_TIMEOUT_SECS`
     well above each exercise's solve time (so failures are correctness-only) or add a
     deterministic correctness sub-metric. Note: with timeouts removed, the only
     headroom is `pov`/`dominoes`, which are hard to move by prompting alone.
2. **Reconsider the candidate surface.** A strong model's minimal prompt is a hard
   baseline to beat with prompt-only edits. Options: broaden scope to tool/skill
   config or agent strategy (still offline-legal), or run the warm-up on a weaker
   model where prompt scaffolding has real headroom (requires the operator to change
   the `POLYGLOT_ALLOWED_MODEL` pin in `bench/lib.sh` and re-hash).
3. **Then** run baseline + candidate via `ar_init`/`ar_run`/`ar_log`, grade TEST
   out-of-loop, and confirm a kept gain transfers. Only then is 0.5a complete.

## Run Recipes (verified working this session)

Init / run / log (background the `run` — a sample can take ~20-40 min):
```bash
set -a; . .env; set +a
ailang run --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream \
  --process-timeout 1500s --ai-stub --entry main \
  scripts/ar_polyglot_harness.ail -- init        # then: run | log <n> keep|discard
```
Candidate edits go in `/workspaces/motoko_agent_polyglot_wt/benchmarks/prompts/polyglot_system.md`.

Out-of-loop TEST grade:
```bash
POLYGLOT_MODEL=openrouter/deepseek/deepseek-v4-pro \
POLYGLOT_PYENV=/workspaces/motoko_agent/.motoko/ar_polyglot_py \
  bash benchmarks/fixtures/autoresearch_polyglot/bench/grade_test.sh
# grade a specific prompt: prepend POLYGLOT_SYSTEM_MD=<path>
```

## Verification After Edits
```bash
(cd benchmarks/fixtures/autoresearch_polyglot && sha256sum -c immutable.sha256)
bash -n benchmarks/fixtures/autoresearch_polyglot/bench/*.sh
ailang check scripts/ar_polyglot_harness.ail
```

## Guardrails (unchanged)

- No Docker; no ARC work; Polyglot model pinned to `openrouter/deepseek/deepseek-v4-pro`
  unless the user changes the pin.
- Do not let optimizer context see TEST scores mid-loop; grade TEST out-of-loop only.
- No size/LOC penalties.
- Do not edit `aider_polyglot.py`, fixture scripts, split files, or
  `packages/motoko-ext-autoresearch/` as *candidate* changes (infra/extension only).
- Candidate scope stays narrow (`benchmarks/prompts/polyglot_system.md`) unless you
  deliberately broaden it per recommendation 2 above.
