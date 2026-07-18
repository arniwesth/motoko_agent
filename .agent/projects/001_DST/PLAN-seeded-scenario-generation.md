# PLAN: Seeded Scenario Generation (ADR-001 Phase 4, v1 — L0)

Date: 2026-07-18
Status: Draft implementation plan
Audience: implementation agent working in `/workspaces/motoko_agent`
Source design: `NOTE-seeded-scenario-generation-design-discussion.md` (2026-07-15)

## TL;DR

Add seeded parameter generation around the existing fixed DST scenario shapes: a new L0 gate
(`scripts/dst/compaction_seeded_dst.ail`) generates tool-heavy histories straddling the
exported 70/85/95 compaction thresholds using `std/rand` (new in AILANG v0.26.0), asserts
the existing invariants as oracle, and reports every failure as
`scenario=<id> seed=<s>` + a `trace param ...` echo so it replays with
`DST_BASE_SEED=<s> DST_SEEDS=1 make dst_seeded`. PR CI runs 5 pinned seeds; nightly runs 500
date-derived seeds. Prerequisite: fix the harness bug that hardcodes `seed=fixed` in failure
output. Fixed gates are untouched. An RNG canary scenario guards against AILANG silently
changing the `std/rand` algorithm between versions.

## Blast Radius

**Small and additive.** No production (`src/core` runtime, extension) code changes.

- `src/core/test/dst_harness.ail` — the only shared file touched. `report_failure` gains a
  `seed` parameter and `run_one` passes it. Every existing gate compiles against the harness,
  so all DST gates recompile; output stays byte-identical because every current scenario has
  `seed: "fixed"`. Verified by `make dst` diffing clean.
- New files (`dst_gen.ail`, `compaction_seeded_dst.ail`) — zero impact on existing gates.
- `Makefile` — new `dst_seeded` target added to the `dst` aggregate; existing targets
  unchanged. Anyone running `make dst` locally now also runs 5 seeded scenarios (~seconds).
- CI — one added step in `verify_extensions`. PR wall-time impact: ~5 seeded scenarios.
  Nightly grows by 500 scenarios on the pure L0 policy path (no AI/network), so runtime
  impact is bounded and local to that step. A seeded failure fails the same job as the fixed
  gates.
- Failure-output contract — the `scenario=<id> seed=<s>` line shape is unchanged for fixed
  scenarios; consumers grepping gate output see a new, distinct `family=... seeds=... ok`
  line only from the new gate. The fixed gates' `PASS count=N` oracle is deliberately not
  reused.
- New capability surface — the seeded gate runs under `--caps IO,Env,Rand`; no existing
  gate's caps change.

**Rollback:** revert is clean — delete the two new files, the Makefile target, and the CI
step; the harness fix (Step 0) is worth keeping regardless.

## Problem

PR #84 landed the DST consolidation and explicitly deferred seeded scenario generation
(ADR-001 Phase 4). All DST scenarios today are hand-picked fixed points; nightly CI runs the
same inputs every night and never explores the parameter space where the motivating bug class
lives (quantities crossing the 70/85/95 tier thresholds, state-carry across steps).

Additionally, `report_failure` in `src/core/test/dst_harness.ail` hardcodes `seed=fixed` in
its output and `run_one` drops `s.seed`, which breaks the replay contract the moment any
scenario carries a real seed.

## Goal

Seeded generators *around fixed scenario shapes* so nightly runs explore parameter space
(history sizes, tool-output sizes, usage percentages straddling tier thresholds) while every
failure stays exactly replayable from `scenario=<id> seed=<s>`. The invariant layer remains
the oracle. v1 generates **only along axes where input legality is guaranteed by
construction** (parameters, not grammars — see the note's oracle-preservation rule).

## Non-Goals (v1)

- Shrinking (parameter echo + single-seed replay instead; size-first generators keep manual
  bisection easy).
- L2 (TypeScript) seeded generation (`fast-check` under bun later, if wanted).
- Grammar-level shape generation (rejected in the note; new shapes are added by hand).
- L1 `phase_c.l1.*` seeded families (fast follow-up after L0 proves the pipeline).

## Plan-Level Decisions (settled with operator 2026-07-18)

### D1. PRNG: `std/rand` (supersedes the note's hand-rolled minstd plan)

The note's "no stdlib random" grounding fact was against AILANG v0.24.2. The pinned v0.26.0
ships `std/rand`: `rand_seed(int)`, `rand_int(min,max)`, `rand_bool()` — all `! {Rand}`,
cap `Rand`, global runtime seed state.

Accepted risk: the underlying algorithm is an AILANG runtime implementation detail; a
toolchain upgrade could silently change what a recorded seed reproduces. Mitigations:
- an **RNG canary scenario** that asserts a golden `rand_seed(k)` → sequence mapping and
  fails loudly if the algorithm ever changes;
- every failure **echoes its drawn parameters** into the trace, so a historical failure is
  human-readable even if its seed no longer reproduces.

Consequence of global state: all draws happen at *expansion time* (in the gate's `main`,
per family per seed: `rand_seed(seed)` then draw all params immediately); the generated
`Scenario.run` closure closes over the drawn values. Each scenario's params are then a pure
function of its seed regardless of run order, and `Scenario.run`'s effect row is unchanged
(it does not include `Rand`).

### D2. Nightly base seed: date-derived

Nightly CI passes `DST_BASE_SEED=$(date +%Y%m%d)` and `DST_SEEDS=500` (ADR target). Each
night explores fresh seeds; any failure is reproducible because the seed is printed in the
failure line.

### D3. Seed config channel: `std/env` in the gate script

`getEnvOr("DST_SEEDS", "5")` / `getEnvOr("DST_BASE_SEED", "1")`, parsed with
`std/string.stringToInt` (returns `Option[int]`; fall back to the default on `None`). Adds
`Env` to the seeded gate's caps — acceptable under the narrowest-caps rule; it is the
established repo pattern (`src/core/config.ail`, `src/core/session.ail`, extension
`register.ail` files).

### D4. Scope: L0 `compaction.gen.*` only

Prove the whole pipeline (RNG → gen → family → harness → replay contract) on the cheapest
gate. The fixed gate `scripts/dst/compaction_policy_dst.ail` stays untouched and
byte-deterministic under `--caps IO`; seeded scenarios live in a **new** script.

## Implementation Steps

### Step 0 — Fix seed threading in the harness (prerequisite)

`src/core/test/dst_harness.ail`:
- `report_failure` (lines 38-41): add a `seed: string` parameter; print
  `scenario=${scenario} seed=${seed} invariant=${f.failed_invariant}`.
- `run_one` (line 50): pass `s.seed`.
- All existing scenarios set `seed: "fixed"`, so every current gate's output stays
  byte-identical. Confirm with `make dst`.

### Step 1 — Generator helpers: `src/core/test/dst_gen.ail` (new)

Thin layer over `std/rand`, all `! {Rand}`:
- `pick(xs: [a]) -> a` — uniform pick via `rand_int(0, length(xs) - 1)`; caller guarantees
  non-empty (true by construction for fixed choice lists).
- `weighted_bool(pct: int) -> bool` — `rand_int(1, 100) <= pct`.
- `int_in(lo, hi)` is just `rand_int` directly — no wrapper.

Keep minimal; grow combinators only when a family needs them.

### Step 2 — Seeded gate: `scripts/dst/compaction_seeded_dst.ail` (new)

Reuses the fixed gate's building blocks: same imports from
`pkg/sunholo/motoko_ext_compaction_structural/compaction_structural` (exported thresholds
`elide_tier_pct`/`elide_hard_tier_pct`/`emergency_pct`, `compact_for_pre_step`,
`estimate_tokens_messages`, `usage_percent_with_limit`); copy the small private helpers from
`compaction_policy_dst.ail` (`tool`/`user`/`assistant`/`call` constructors, `ctx(limit)`,
`limit_for_pct`, `count_kept_tools`, `same_tool_ids`).

**RNG canary** — first scenario, id `compaction.gen.rng_canary`, seed `"fixed"`:
`rand_seed(12345)` then assert the next 3 `rand_int(0, 2147483646)` values equal golden
constants (record them once during implementation against the pinned v0.26.0 binary).
Failure message: "std/rand sequence changed — recorded seeds no longer reproduce historical
inputs".

**Family v1: `compaction.gen.tool_heavy`** — `gen_tool_heavy(seed: int) -> Scenario ! {Rand}`:
1. `rand_seed(seed)`; draw `n_tools` in `[3, 30]`, `content_len` in `[40, 400]` (build
   content by repetition to that length), and a target usage pct via `pick` over points
   straddling the exported thresholds — e.g. `[elide-5, elide+5, hard-5, hard+5,
   emergency-3, emergency+2]` computed from the exported functions, never literals.
2. Build a legal-by-construction history: leading `user` msg, then an `assistant` msg whose
   tool calls pair 1:1 with the subsequent `tool` results (ids `t0..tn`) — mirroring the
   fixed gate's `tool_heavy_msgs()` / `scenario_tool_shape_preserved_by_elision` shapes.
3. `limit = limit_for_pct(msgs, pct)`; run `compact_for_pre_step(ctx(limit), msgs)`.
4. Assert **invariants only** (no exact-output expectations — draws straddle thresholds):
   - `validate_compactor_output(input, output)` from
     `packages/motoko_ext_conformance/invariants.ail` (system-prefix, tool pairing, id
     preservation; already imported alongside abi `Msg` by `phase_c_l1_scenarios.ail`, so
     types align);
   - estimate monotonicity: `estimate_tokens_messages(out) <= estimate_tokens_messages(input)`;
   - length preservation on `Compacted` (elision keeps message count);
   - if drawn pct `< elide_tier_pct()`, decision must be `PassThrough`.
5. Return `{ id: "compaction.gen.tool_heavy", seed: show(seed), run: <closure over drawn
   msgs/limit> }`.
6. **Every failure trace echoes the drawn params**:
   `trace param n_tools=.. content_len=.. pct=.. limit=.. usage=..` — no shrinking, so a
   failing seed must be readable, not just re-runnable.

**`main`** (`! {IO, Env, Rand}`): read config, expand the family over seeds
`base .. base+N-1` into a plain `[Scenario]`, prepend the canary, `run_all` via the harness.

**Output contract** — do **not** reuse the fixed gates' `PASS count=N` shape (the
"pass count must increase by exactly your additions" oracle breaks when counts depend on
`DST_SEEDS`). Print instead:
- per family: `family=compaction.gen.tool_heavy seeds=<N> ok`
- final: `compaction_seeded_dst PASS families=1 base_seed=<k> seeds=<N>`, or
  `compaction_seeded_dst FAIL failed=<n>` + `exit(1)`.

Script header documents the replay contract:
`DST_BASE_SEED=<failing seed> DST_SEEDS=1 make dst_seeded`.

### Step 3 — Makefile

New target next to the other DST targets (~lines 74-84):

```make
dst_seeded:
	ailang run --caps IO,Env,Rand --entry main scripts/dst/compaction_seeded_dst.ail
```

`DST_SEEDS`/`DST_BASE_SEED` pass through from the environment. Add `dst_seeded` to the
`dst` aggregate target's list.

### Step 4 — CI wiring (`.github/workflows/verify-extensions.yml`)

CI references make targets only (standing rule). In the `verify_extensions` job, after the
"DST AILANG gates" step (~line 95), add a step running `make dst_seeded` with
event-dependent env:
- PR / push: pinned `DST_SEEDS=5 DST_BASE_SEED=1` (fast gate stays byte-deterministic).
- `schedule` (the existing nightly cron trigger, 06:00 UTC): `DST_SEEDS=500`,
  `DST_BASE_SEED=$(date +%Y%m%d)`.

Implement as one step with a small `if [ "$GITHUB_EVENT_NAME" = schedule ]` shell prelude
(or two `if:`-guarded steps — whichever reads cleaner in the file).

## Files Touched

- `src/core/test/dst_harness.ail` — seed threading fix (Step 0)
- `src/core/test/dst_gen.ail` — new (Step 1)
- `scripts/dst/compaction_seeded_dst.ail` — new (Step 2)
- `Makefile` — `dst_seeded` target + `dst` aggregate (Step 3)
- `.github/workflows/verify-extensions.yml` — seeded CI step (Step 4)

## Verification

1. `ailang check` on new/changed `.ail` files; `make dst` — all fixed gates pass with
   byte-identical output (Step 0 is invisible while every seed is `"fixed"`).
2. `make dst_seeded` (defaults: 5 seeds from base 1) — passes; run twice and diff output to
   confirm byte-determinism.
3. Replay: `DST_BASE_SEED=7 DST_SEEDS=1 make dst_seeded` twice → identical output.
4. Failure contract: temporarily tighten an invariant (e.g. assert an impossible kept-count)
   and confirm the failure prints
   `scenario=compaction.gen.tool_heavy seed=<s> invariant=<inv>` plus `trace param ...`
   lines; revert.
5. Nightly-scale smoke: `DST_SEEDS=200 DST_BASE_SEED=20260718 make dst_seeded` — passes in
   reasonable time.
6. Canary passes on the pinned v0.26.0 binary.

## Follow-ups (out of this plan)

- L1 seeded families (`phase_c.l1.*`): token counts near tiers, extension decision sequences
  via scripted ports — same pipeline, next PR.
- Update `NOTE-seeded-scenario-generation-design-discussion.md` status line to point here.
