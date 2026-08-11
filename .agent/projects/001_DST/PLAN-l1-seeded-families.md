# PLAN: L1 Seeded Families (ADR-001 Phase 4, v2 — phase_c.gen.*)

Date: 2026-07-18
Status: Draft implementation plan
Audience: implementation agent working in `/workspaces/motoko_agent`
Predecessor: `PLAN-seeded-scenario-generation.md` (L0, implemented in `5d01f22`, verified green)

## TL;DR

Extend seeded DST generation to the L1 layer: a new gate
`scripts/dst/phase_c_seeded_dst.ail` (same direct-loop pattern as the L0 seeded gate)
generates four `phase_c.gen.*` families against the pure phase-core functions — seal
exhaustion boundaries around the exported `exhaustion_pct()` 95 line, checkpoint decisions
around a *drawn* `checkpoint_pct`, system-prefix split laws over drawn prefix/tail counts,
and stage-record projection over drawn `PreStepStage` sequences. Wired as a second line
under the existing `dst_seeded` make target — **zero CI changes, zero shared-file
changes**; the same `DST_SEEDS`/`DST_BASE_SEED` knobs and replay contract govern both
layers.

## Blast Radius

**Smaller than the L0 change — two files, both additive.**

- `scripts/dst/phase_c_seeded_dst.ail` — new; imports only pure production functions
  (`phase_vocab`, `step_machine`, `hook_phase`, `ext/runtime` types, `src/core/compaction`)
  plus the existing seeded-test helpers. Zero impact on existing gates.
- `Makefile` — one added line under the existing `dst_seeded` target. No new target, no
  aggregate change, no CI edit (the workflow already calls `make dst_seeded` on both the
  PR and nightly paths, so the new gate inherits 5-pinned-seed PR runs and 500-seed
  nightlies automatically).
- **No shared files touched**: `dst_harness.ail`, `dst_gen.ail`, the fixed L1 gate, and
  the L0 seeded gate are all unmodified. The fixed gates' output cannot change.
- Failure/replay contract identical to L0 (`scenario=phase_c.gen.<family> seed=<s>` +
  `trace param ...`; replay `DST_BASE_SEED=<s> DST_SEEDS=1 make dst_seeded`).
- Rollback: delete the new file and the one Makefile line.

## Problem

L0 seeded generation (implemented) covers the compaction *policy* surface. The L1 layer —
`seal_compacted_payload` exhaustion, `decide`/checkpoint pressure, split/pinning laws,
stage-record projection — is where ADR-001's motivating bug class lives (threshold and
state-carry bugs in the phase-core scaffold), and it still runs only 15 hand-picked fixed
points. ADR-001 Phase 4 axes not yet generated: token counts near thresholds at L1,
extension decisions, history sizes.

## Goal

Seeded parameter families around the fixed L1 scenario shapes, same rules as L0: legality
by construction, invariants (or exact contracts composed from exported production
functions) as oracle, every failure replayable from `scenario=<id> seed=<s>` and readable
from its `trace param` echo.

## Non-Goals (v2)

- Decision-*sequence* generation through the real session loop — that territory belongs to
  `phase_c2_wiring_scenarios.ail` (scripted model steps, real `dispatch_pre_step_chain`);
  do not duplicate it. Seeded stage coverage here uses literal `PreStepStage` lists against
  `stage_record`, mirroring the fixed L1 scenarios.
- Drawn `TokenTelemetry` calibration axes (anchored calibration makes expected usage
  uncomputable without re-implementing the calibration formula — oracle-duplication risk).
  v2 uses zero telemetry so calibrated usage falls back to the raw `Σchars/4` estimate
  (verified fallback behavior). Telemetry axes are a possible v3 with invariant-only
  assertions.
- `StageObserved` outcomes (carry `[DiagnosticField]` payloads), illegal-input generation
  (e.g. non-contiguous system prefixes to force `history_from_seed` `Err`), step-budget and
  cost-budget boundary families. All deferred.
- A second RNG canary — the L0 gate's canary already guards `std/rand` stability for the
  whole `dst_seeded` target; do not duplicate it.

## Plan-Level Decisions (settled with operator 2026-07-18)

- **D1. Family set**: the three token-boundary families (`seal_boundary`,
  `checkpoint_pressure`, `split_prefix`) plus `stage_records` (covers the ADR "extension
  decisions" axis via literal lists without phase_c2 overlap).
- **D2. Wiring**: second `ailang run` line under the existing `dst_seeded` target (zero CI
  changes, one seed knob, one replay command). Same `--caps IO,Env,Rand` — all L1
  production functions used are pure (the fixed L1 gate runs at `--caps IO`).
- **D3. Same direct-loop pattern as L0 (inherited)**: the `Scenario.run` effect row has no
  `Rand`, so generated cases cannot live in `Scenario` records. Per-family
  `run_<family>(seed) -> bool`, per-family seed loops, `report_failure` from the harness.
  Each family function begins `rand_seed(seed)` then draws all params immediately;
  different families draw different ranges from the same seed, which is deterministic and
  replay-stable (the replay command re-runs all families at that seed).
- **D4. L1 type discipline**: L1 uses `src/core` types — `Message` (not the abi `Msg`),
  token math from `src/core/compaction` (`estimate_tokens_messages`,
  `usage_percent_with_limit`, `exhaustion_pct` — all exported, verified), thresholds from
  the *drawn policy record* (`StepPolicy.checkpoint_pct` etc. are caller-supplied, so
  drawing them is legal). Do not import the `pkg` compaction-structural estimators here.

## Implementation Steps

### Step 1 — New gate: `scripts/dst/phase_c_seeded_dst.ail`

Copy the L0 gate's skeleton (`compaction_seeded_dst.ail`): env config block
(`DST_SEEDS`/`DST_BASE_SEED` via `getEnvOr` + `stringToInt`, set-but-unparseable or `< 1`
⇒ `CONFIG ERROR` + `exit(1)`), per-family seed loops, output contract. Copy fixture
builders from the fixed L1 gate (`msg(role, content)`, `policy(context_limit)`,
`policy_with_checkpoint`-style builder with a **drawn** `checkpoint_pct`, a zero-telemetry
`StepState` builder — note the fixed gate's `state_from_msgs` sets
`last_input_tokens = context_limit`, which engages calibration; the seeded builder must
zero it per Non-Goals). Reuse `pick_int` from `src/core/test/dst_gen` and
`limit_for_pct`-style computation against the **core** `estimate_tokens_messages`.

Families (ids `phase_c.gen.<family>`; every failure echoes all drawn params in one
`trace param ...` line):

**A. `phase_c.gen.seal_boundary`** — the seal exhaustion/empty-prompt contract, exact
oracle composed from exported functions:
- Draw: `n_systems ∈ [0,2]`, `n_tail ∈ [1,8]`, `content_len ∈ [40,400]`,
  `require_system_prompt` from `rand_int(0,1)`, target pct via `pick_int` over
  `[exhaustion-5, exhaustion-1, exhaustion, exhaustion+5]` (from `exhaustion_pct()`).
- Build msgs: `n_systems` system messages then `n_tail` user/assistant messages (contiguous
  prefix by construction); `split = split_for_compaction(msgs)`;
  `limit = estimate*100/pct`.
- Expected outcome recomputed from **actual** values (rounding-proof, uses only exported
  production functions — composition test, not a re-implementation):
  - `require_system_prompt && system_prefix_chars(split.pinned) == 0` ⇒
    `Err(SealSystemPromptEmpty)` — note production keys on prefix **chars**, not message
    count (`phase_vocab.ail:147`); with `content_len >= 40` the two coincide, but express
    the expectation via the exported `system_prefix_chars` to match exactly;
  - else `usage_percent_with_limit(pinned ++ chain, limit) >= exhaustion_pct()` ⇒
    `Err(SealExhausted)`;
  - else `Ok(p)` — and assert `payload_messages(p) == pinned ++ chain` exactly
    (`payload_messages` is exported, verified at `phase_vocab.ail:124`).
- This asserts seal's *composition and check ordering* (empty-prompt check before
  exhaustion) at drawn boundary points including exactly-at-95.

**B. `phase_c.gen.checkpoint_pressure`** — one-sided decision assertions + post-checkpoint
invariants (mirrors the L0 invariants-only style; `should_checkpoint` also requires
`checkpoint_would_relieve`, so above-threshold does NOT guarantee `TakeCheckpoint`):
- Draw: `checkpoint_pct ∈ [50,99]`, `n_tail ∈ [2,10]`, `content_len ∈ [40,400]`, target
  usage via `pick_int` over `[cp-10, cp-1, cp+1, cp+10]`; one system message; zero
  telemetry; fresh `StepState` (no pending tools, fresh finish reason, `step_idx` 0).
- `context_limit = estimate*100/target_usage`; policy-off and policy-on variants per seed:
  - policy off (`checkpoint_enabled: false`): `decide` must NOT be `TakeCheckpoint`;
  - policy on, actual usage `< checkpoint_pct` (recomputed via the exported usage
    function): must NOT be `TakeCheckpoint`;
  - policy on, decision IS `TakeCheckpoint`: `apply_checkpoint` then assert
    `history_valid_transcript`, `validate_checkpoint_chain(before, [cp], after)`,
    `history_len == n_systems + 1`, and the *next* `decide` is `CallModel`
    (terminates, no checkpoint spin).

**C. `phase_c.gen.split_prefix`** — split/pinning laws over drawn shapes:
- Draw: `n_systems ∈ [0,4]`, `n_tail ∈ [0,12]`, `content_len ∈ [10,200]`. The
  all-zero corner (empty message list) is legal — verified: `system_is_head_prefix([])`
  is `true` (`phase_vocab.ail:77`), so `history_from_seed([])` is `Ok`.
- Assert: `split_for_compaction` pins exactly `n_systems` and segments exactly `n_tail`
  with no system role in the segment; `history_from_seed` is `Ok` (legal by construction);
  `history_len == n_systems + n_tail`; `history_valid_transcript`; `history_digest`
  computed twice is identical (digest determinism).

**D. `phase_c.gen.stage_records`** — projection contract over drawn stage sequences:
- Draw: `n_stages ∈ [1,8]`, `step ∈ [0,20]`, per-stage outcome from
  `rand_int(0,2)` → `StageApplied("gen") | StageRejected("gen") | StagePassed`; ext ids
  `"gen_ext_<i>"`.
- Map each through `stage_record(step, stage)`; assert record count, ext-id order
  preservation, per-element outcome mapping, and `step` field fidelity — the generated
  analog of the two fixed literal-list scenarios.

Output contract (same shapes as L0): per-seed
`scenario=phase_c.gen.<family> seed=<s> ok` lines; per-family
`family=phase_c.gen.<family> seeds=<N> ok`; final
`phase_c_seeded_dst PASS families=4 base_seed=<k> seeds=<N>` or
`phase_c_seeded_dst FAIL failed=<n>` + `exit(1)`. Script header documents the replay
command.

### Step 2 — Makefile

Extend the existing target (currently line 78-79) — no new target:

```make
dst_seeded:
	ailang run --caps IO,Env,Rand --entry main scripts/dst/compaction_seeded_dst.ail
	ailang run --caps IO,Env,Rand --entry main scripts/dst/phase_c_seeded_dst.ail
```

Sequential lines (first failure stops the target) — same convention as `compaction_dst`.
No CI edit: the workflow's "DST seeded gate" step already calls `make dst_seeded` with
pinned PR seeds and date-derived nightly seeds.

## Files Touched

- `scripts/dst/phase_c_seeded_dst.ail` — new (Step 1)
- `Makefile` — one line under `dst_seeded` (Step 2)

## Verification

1. `ailang check scripts/dst/phase_c_seeded_dst.ail` clean; all fixed gates
   (`make --keep-going compaction_dst phase_c_l1`) still green and unchanged (no shared
   files are touched, so this is a sanity check, not a diff requirement).
2. `make dst_seeded` (defaults) — both gates green; run twice, outputs byte-identical.
3. Replay: `DST_BASE_SEED=7 DST_SEEDS=1 make dst_seeded` twice → identical output; the
   `phase_c.gen.*` per-seed lines appear alongside the L0 lines.
4. Failure contract: on a scratchpad copy, break one invariant per family (e.g. flip the
   seal-boundary expected-outcome comparison) and confirm
   `scenario=phase_c.gen.<family> seed=<s> invariant=<inv>` + `trace param ...` + `FAIL`
   + nonzero exit; discard the copy.
5. Boundary reach: on a **scratchpad copy** (like item 4) add a per-seed outcome println,
   run `DST_SEEDS=200`, and grep-count that seal_boundary hit `Ok`, `SealExhausted`, and
   `SealSystemPromptEmpty` outcomes and checkpoint_pressure hit both `TakeCheckpoint` and
   non-checkpoint paths. The shipped gate prints no per-outcome debug output.
6. Nightly-scale smoke: `DST_SEEDS=200 DST_BASE_SEED=20260718 make dst_seeded` green in
   reasonable time (L0 alone was ~5s at 200 seeds; L1 functions are pure and cheaper).

## Follow-ups (out of this plan)

- Telemetry/calibration axes with invariant-only assertions (v3).
- `StageObserved` outcomes; illegal-input contract tests (`history_from_seed` `Err`);
  step/cost-budget boundary families.
- If a third seeded gate ever appears, extract the shared config block into a helper
  module.
- Update ADR-001 Phase 4 status to note L0+L1 seeded coverage as-built.
