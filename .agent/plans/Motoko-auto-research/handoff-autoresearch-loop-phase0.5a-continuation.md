# Handoff: continue Phase 0.5a Polyglot autoresearch loop

This handoff starts after the first Polyglot loop proof and the DeepSeek V4 Pro
retry. The next agent should stay in the Polyglot lane. Do not start ARC or
Terminal-Bench work, and do not use Docker.

## Current State

- Branch: `autoresearch-loop`, ahead of origin by 5 commits.
- Latest commits:
  - `a8f7424 Retry Polyglot fixture with DeepSeek V4 Pro`
  - `82f1e31 Run Polyglot autoresearch loop proof`
  - `d029020 Use noisy primary MAD for autoresearch improvement`
- Expected unrelated dirty state:
  - `.motoko/config/default/config.json`
  - `.emsdk/`
- Do not revert unrelated dirty state.

## What Is Already Done

- Polyglot fixture exists at `benchmarks/fixtures/autoresearch_polyglot/`.
- The fixture is currently pinned to exactly:
  - `openrouter/deepseek/deepseek-v4-pro`
- Any other `POLYGLOT_MODEL` fails fast in `bench/lib.sh`.
- TRAIN/TEST split files and canary manifest are hashed by `immutable.sha256`.
- `benchmark.sh` runs TRAIN only.
- `grade_test.sh` runs held-out TEST only and must remain operator-invoked.
- Scratch is kept under `.motoko/ar_bench_scratch/`, outside candidate scope.
- `aider_polyglot.py` now supports `--skip-preflight`.
- The fixture bounds per-exercise runtime with `POLYGLOT_EXERCISE_TIMEOUT_SECS`.
- `scripts/ar_polyglot_harness.ail` can drive the real autoresearch hooks directly:
  - `ar_init`
  - `ar_run`
  - `ar_log`
  - `ar_notes`

## Results So Far

### Flash Route

Model:

```bash
openrouter/deepseek/deepseek-v4-flash
```

Autoresearch loop proof:

- Baseline TRAIN, segment 2 run #1:
  - median `pass_rate=0.5833335`
  - samples `[0.666667, 0.5]`
  - primary MAD `0.0833335`
- ReAct-style prompt candidate, run #2:
  - median `pass_rate=0.75`
  - samples `[0.666667, 0.833333]`
  - primary MAD `0.083333`
  - `ar_log keep` committed `f3efa47446c5af9a7515e7191e0b87d06b90383a` in the linked worktree
- Held-out TEST:
  - `pass_rate=0.000000`
  - all six TEST exercises errored or timed out

Interpretation: the autoresearch FSM and noisy maximize primary path were proven,
but the kept TRAIN improvement did not transfer to held-out TEST.

### Pro Route

Model:

```bash
openrouter/deepseek/deepseek-v4-pro
```

Direct fixture retry with the default Polyglot prompt:

- `checks.sh`: passed
- TRAIN `benchmark.sh`:
  - `pass_rate=1.000000`
  - `wall_ms=138656`
  - all six exercises `pass_1`
- held-out TEST `grade_test.sh`:
  - `pass_rate=1.000000`
  - `wall_ms=103285`
  - all six exercises `pass_1`

Interpretation: Pro solves the current split cleanly. This confirms the Flash
failure was route/capability limited, but it still does not satisfy the 0.5a exit
gate because no optimizer-kept scaffolding change was tested for transfer under Pro.

## Critical Caveat

The current TRAIN/TEST split is now too easy for DeepSeek V4 Pro. A loop over this
split will saturate at `pass_rate=1.0`, leaving no measurable headroom for prompt or
scaffolding improvements.

The next agent must first create a harder Polyglot segment before claiming 0.5a exit.

## Read First

1. `.agent/plans/Motoko-auto-research/autoresearch-loop.md`
2. `packages/motoko-ext-autoresearch/README.md`
3. `benchmarks/fixtures/autoresearch_polyglot/README.md`
4. `scripts/ar_polyglot_harness.ail`
5. `papers/ledger.md`

## Verify The Current Fixture

Run these before changing anything:

```bash
(cd benchmarks/fixtures/autoresearch_polyglot && sha256sum -c immutable.sha256)
bash -n benchmarks/fixtures/autoresearch_polyglot/bench/*.sh
ailang check scripts/ar_polyglot_harness.ail
```

Cheap model route smoke:

```bash
POLYGLOT_MODEL=openrouter/deepseek/deepseek-v4-pro \
POLYGLOT_PYENV=/workspaces/motoko_agent/.motoko/ar_polyglot_py \
POLYGLOT_EXERCISE_TIMEOUT_SECS=180 \
bash benchmarks/fixtures/autoresearch_polyglot/bench/checks.sh
```

## Recommended Next Work

### 1. Rebalance The Split For Pro

Pick a harder TRAIN/TEST subset from `/workspaces/polyglot-benchmark/python/exercises/practice`
or from the existing `benchmarks/polyglot_logs/python/` exercise names.

Goal:

- TRAIN should not saturate at 1.0 under `openrouter/deepseek/deepseek-v4-pro`.
- TEST should be disjoint and never referenced by `benchmark.sh`.
- Keep initial split small enough for loop speed.

Suggested approach:

- Probe candidate harder exercises one at a time with Pro.
- Prefer exercises that are not trivial one-file string/list transformations.
- Keep 6 to 10 exercises per split initially.
- Avoid using TEST scores while selecting TRAIN candidates. If you probe TEST, record it as operator validation only.

Single-exercise probe template:

```bash
MOTOKO_BENCHMARK_ROOT=/workspaces/polyglot-benchmark \
CORE_EXT_ORDER=context_mode,exa_search \
POLYGLOT_PYENV=/workspaces/motoko_agent/.motoko/ar_polyglot_py \
python3 benchmarks/aider_polyglot.py \
  --language python \
  --exercise EXERCISE_NAME \
  --model openrouter/deepseek/deepseek-v4-pro \
  --results .motoko/ar_bench_scratch/probes/EXERCISE_NAME.json \
  --heartbeat-secs 0 \
  --no-retry \
  --skip-preflight
```

After changing split files or fixture docs, update:

```bash
(cd benchmarks/fixtures/autoresearch_polyglot && \
  sha256sum README.md splits/train.txt splits/test.txt splits/manifest.txt \
    bench/lib.sh bench/benchmark.sh bench/checks.sh bench/grade_test.sh \
    > immutable.sha256)
```

Then verify:

```bash
(cd benchmarks/fixtures/autoresearch_polyglot && sha256sum -c immutable.sha256)
```

### 2. Re-run The Autoresearch Loop Under Pro

Use `scripts/ar_polyglot_harness.ail` if the model still does not reliably call
`ar_*` tools itself. This harness drives the real extension implementation and keeps
benchmark model usage pinned to Pro.

Initialize a fresh segment:

```bash
ailang run \
  --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream \
  --process-timeout 1m \
  --ai-stub \
  --entry main scripts/ar_polyglot_harness.ail -- init
```

Run baseline:

```bash
ailang run \
  --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream \
  --process-timeout 10m \
  --ai-stub \
  --entry main scripts/ar_polyglot_harness.ail -- run
```

Log baseline:

```bash
ailang run \
  --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream \
  --process-timeout 2m \
  --ai-stub \
  --entry main scripts/ar_polyglot_harness.ail -- log 1 keep
```

Then apply one in-scope scaffolding candidate to:

```text
benchmarks/prompts/polyglot_system.md
```

Run another `ar_run`, then `ar_log keep|discard` based on the extension metadata.

### 3. Grade TEST Out Of Loop

Only after a candidate is kept or discarded, run:

```bash
POLYGLOT_MODEL=openrouter/deepseek/deepseek-v4-pro \
POLYGLOT_PYENV=/workspaces/motoko_agent/.motoko/ar_polyglot_py \
POLYGLOT_EXERCISE_TIMEOUT_SECS=180 \
bash benchmarks/fixtures/autoresearch_polyglot/bench/grade_test.sh
```

Do not wire this into `benchmark.sh` or `ar_init`.

### 4. Finish The Missing Integrity Gates

Still open from 0.5a:

- Oracle-vs-no-op:
  - Current/default scaffolding should clearly beat an empty/broken prompt on TRAIN.
- Cheat trial:
  - Attempt a candidate that reads TEST split or edits grader/fixture.
  - Confirm `off_limits`/scope handling blocks keep or requires deviation justification.
- Held-out transfer:
  - Need a kept scaffolding change that improves or preserves performance on TEST,
    not merely TRAIN.

## Verification Commands

Use after edits:

```bash
(cd benchmarks/fixtures/autoresearch_polyglot && sha256sum -c immutable.sha256)
bash -n benchmarks/fixtures/autoresearch_polyglot/bench/*.sh
python3 -m py_compile benchmarks/aider_polyglot.py benchmarks/motoko_rpc.py
AILANG_RELAX_MODULES=1 ailang check packages/motoko-ext-autoresearch/autoresearch.ail
ailang check scripts/ar_polyglot_harness.ail
ailang test packages/motoko-ext-autoresearch/metrics_test.ail
```

`ailang check --package packages/motoko-ext-autoresearch` may still fail on the
pre-existing `_smoke.ail` numeric type issue; do not treat that as a regression unless
you changed that file.

## Guardrails

- Do not use Docker.
- Do not start ARC work.
- Do not use any model other than `openrouter/deepseek/deepseek-v4-pro` for Polyglot
  testing unless the user explicitly changes the pin again.
- Do not let optimizer context see TEST scores mid-loop.
- Do not add size/LOC penalties.
- Do not edit `benchmarks/aider_polyglot.py`, fixture scripts, split files, or
  `packages/motoko-ext-autoresearch/` as candidate changes. Those are benchmark/infra
  or extension code, not scaffolding surface.
- Candidate scope should stay narrow, preferably `benchmarks/prompts/polyglot_system.md`.

## Definition Of Done For The Next Agent

0.5a can be marked complete only when all are true:

- Harder Pro split is documented and hashed.
- Baseline and at least one candidate segment ran through `ar_init`/`ar_run`/`ar_log`.
- A kept scaffolding change transfers to held-out TEST.
- Oracle-vs-no-op gate passed.
- Cheat trial was blocked or correctly rejected from keep.
- Literature ledger has claim vs measured outcome for the kept/discarded method.
- `autoresearch-loop.md` and `.agent/summaries/2026-05-31-autoresearch-polyglot-phase0_5a.md`
  are updated with exact metrics.
