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
  `seed` parameter and `run_one` passes it; **no callers of either exist outside the harness
  itself** (verified by grep across `src/`, `scripts/`, `packages/`), so the signature change
  cannot ripple. All DST gates recompile; output stays byte-identical because every current
  scenario has `seed: "fixed"`. Verified by `make dst` diffing clean.
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

Consequence of global state: each seeded case calls `rand_seed(seed)` and immediately draws
all its params before doing anything else, so its inputs are a pure function of its seed
regardless of run order. See D5 for how this removes the need for closures entirely.

### D2. Nightly base seed: date-derived

Nightly CI passes `DST_BASE_SEED=$(date +%Y%m%d)` and `DST_SEEDS=500` (ADR target). Each
night explores fresh seeds; any failure is reproducible because the seed is printed in the
failure line.

### D3. Seed config channel: `std/env` in the gate script

`getEnvOr("DST_SEEDS", "5")` / `getEnvOr("DST_BASE_SEED", "1")`, parsed with
`std/string.stringToInt` (returns `Option[int]`). Unset vars get the defaults via
`getEnvOr`; a var that is *set but unparseable*, or `DST_SEEDS < 1`, is a hard config error
(`exit(1)`) — never a silent fallback or a silent zero-scenario pass. Adds
`Env` to the seeded gate's caps — acceptable under the narrowest-caps rule; it is the
established repo pattern (`src/core/config.ail`, `src/core/session.ail`, extension
`register.ail` files).

### D4. Scope: L0 `compaction.gen.*` only

Prove the whole pipeline (RNG → gen → family → harness → replay contract) on the cheapest
gate. The fixed gate `scripts/dst/compaction_policy_dst.ail` stays untouched and
byte-deterministic under `--caps IO`; seeded scenarios live in a **new** script.

### D5. Direct seed loop — no `Scenario` closures (review finding)

The note's original design stored generated params in `Scenario.run` closures and reused
`run_all`. Plan review found the repo **never stores a capturing closure in a record
field** — every `run:` field in every gate and every `ExtPorts` field is a named top-level
function, and no lambda syntax appears anywhere in `src/` or `scripts/`. The closure design
would therefore rest on unverified AILANG behavior (lambda capture plus effect-row
subsumption inside record fields).

Deferred execution buys nothing here anyway: draws happen at expansion time regardless (D1).
So the seeded gate loops seeds directly — generate, check, report, next seed — and reuses
the harness's reporting helpers (`report_failure` post-Step-0, `print_trace`,
`ok_or_failure`, `failure`) without importing `Scenario`/`run_all`. The printed contract is
identical to what the closure design would have produced. If a later AILANG version makes
capturing closures well-supported, families can migrate to `Scenario` records without
changing a byte of output.

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
- `pick_int(xs: [int]) -> int` — uniform pick via `rand_int(0, length(xs) - 1)`; caller
  guarantees non-empty (true by construction for fixed choice lists). Monomorphic on
  purpose: v1 only picks from int lists, and a generic effectful `pick(xs: [a])` would be
  another construct with no precedent in the repo — generalize only when a family needs it.
- `int_in(lo, hi)` is just `rand_int` directly — no wrapper.

Keep minimal; grow combinators (e.g. `weighted_bool`) only when a family needs them. v1
needs only `pick_int` plus direct `rand_int` calls.

### Step 2 — Seeded gate: `scripts/dst/compaction_seeded_dst.ail` (new)

Reuses the fixed gate's building blocks: same imports from
`pkg/sunholo/motoko_ext_compaction_structural/compaction_structural` (exported thresholds
`elide_tier_pct`/`elide_hard_tier_pct`/`emergency_pct`, `compact_for_pre_step`,
`estimate_tokens_messages`, `usage_percent_with_limit`); copy only the private helpers the
gate actually uses from `compaction_policy_dst.ail` (`tool`/`user`/`assistant`/`call`
constructors, `ctx(limit)`, `limit_for_pct`) — the invariants-only assertion set does not
need `count_kept_tools`/`same_tool_ids` (that ground is covered by
`validate_compactor_output`).

Structure (per D5, a direct loop — imports `report_failure`, `print_trace`, `ok_or_failure`,
`failure` from the harness, but not `Scenario`/`run_all`):

**RNG canary** — `run_rng_canary() -> bool`, runs first, reported as
`scenario=compaction.gen.rng_canary seed=fixed`: `rand_seed(12345)` then assert the next 3
`rand_int(0, 2147483646)` values equal golden constants (record them once during
implementation against the pinned v0.26.0 binary). Failure message: "std/rand sequence
changed — recorded seeds no longer reproduce historical inputs".

**Family v1: `compaction.gen.tool_heavy`** — `run_tool_heavy(seed: int) -> bool` (effect
row annotated to match what `compact_for_pre_step` requires plus `Rand`/`IO`; exact row
settled by `ailang check` at implementation, mirroring how the fixed gate annotates its
scenario functions):
1. `rand_seed(seed)`; immediately draw all params: `n_tools` in `[3, 30]`, `content_len` in
   `[40, 400]` (build content by repetition to that length), and a target usage pct via
   `pick_int` over points straddling the exported thresholds — e.g. `[elide-5, elide+5,
   hard-5, hard+5, emergency-3, emergency+2]` computed from the exported functions, never
   literals.
2. Build a legal-by-construction history: leading `user` msg, then an `assistant` msg whose
   tool calls pair 1:1 with the subsequent `tool` results (ids `t0..tn`) — mirroring the
   fixed gate's `tool_heavy_msgs()` / `scenario_tool_shape_preserved_by_elision` shapes.
3. `limit = limit_for_pct(msgs, pct)`; run `compact_for_pre_step(ctx(limit), msgs)`.
4. Assert **invariants only** (no exact-output expectations — draws straddle thresholds,
   and small `n_tools` can make every tier a legitimate no-op/`PassThrough`):
   - `validate_compactor_output(input, output)` from
     `packages/motoko_ext_conformance/invariants.ail` (system-prefix, tool pairing, id
     preservation; it uses the same abi `Msg` type — verified: `invariants.ail` imports
     `Msg` from `pkg/sunholo/motoko_ext_abi/types`, same as the compaction gate);
   - estimate monotonicity: `estimate_tokens_messages(out) <= estimate_tokens_messages(input)`;
   - length preservation on `Compacted` (elision keeps message count);
   - if drawn pct `< elide_tier_pct()`, decision must be `PassThrough`.
5. On success print `scenario=compaction.gen.tool_heavy seed=<s> ok`; on failure call
   `report_failure("compaction.gen.tool_heavy", show(seed), f)` (post-Step-0 signature) and
   return `false`.
6. **Every failure trace echoes the drawn params**:
   `trace param n_tools=.. content_len=.. pct=.. limit=.. usage=..` — no shrinking, so a
   failing seed must be readable, not just re-runnable. Build the param trace lines once
   after drawing and pass them into every `ok_or_failure` call.

**`run_seeds(base: int, n: int) -> int`** — recursive loop over `base .. base+n-1` calling
`run_tool_heavy`, returning the failure count (same accumulator shape as the harness's
`run_all`).

**`main`** (`! {IO, Env, Rand}`, exact row settled by `ailang check`): read config; if
either env var is present but unparseable, or `DST_SEEDS < 1`, print a config error and
`exit(1)` (never silently run zero scenarios); run canary + `run_seeds`.

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

CI references make targets only (standing rule). In the `verify_extensions` job, insert a
step directly after the existing `- name: DST AILANG gates` step (verified at line ~95):

```yaml
      - name: DST seeded gate
        run: |
          if [ "$GITHUB_EVENT_NAME" = "schedule" ]; then
            DST_SEEDS=500 DST_BASE_SEED=$(date +%Y%m%d) make dst_seeded
          else
            DST_SEEDS=5 DST_BASE_SEED=1 make dst_seeded
          fi
```

- PR / push: pinned `DST_SEEDS=5 DST_BASE_SEED=1` (fast gate stays byte-deterministic).
- `schedule` (the existing nightly cron trigger, 06:00 UTC): 500 date-derived seeds
  (ADR-001 nightly target).

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
