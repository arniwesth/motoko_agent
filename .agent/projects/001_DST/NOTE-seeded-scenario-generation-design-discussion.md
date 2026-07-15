# Seeded Scenario Generation (ADR-001 Phase 4) — Design Discussion

**Date**: 2026-07-15
**Status**: Design discussion — not yet planned or implemented
**Context**: PR #84 (`mot-41` DST consolidation) landed the DST framework as-built and explicitly
deferred seeded scenario generation. This note records the design discussion for implementing it.
**Author**: Motoko session with operator

---

## Goal

ADR-001 Phase 4: add seeded generators *around fixed scenarios* so nightly runs explore the
parameter space (history sizes, tool-output sizes, token counts near compaction tier thresholds,
extension decisions) instead of only the hand-picked points, while every failure stays exactly
replayable from `scenario=<id> seed=<s>`. The invariant layer remains the oracle; the seed makes
discovered failures deterministic to reproduce. Nightly target from the ADR: `DST_SEEDS=500`.

## What PR #84 already provides

The consolidation made this cheap to add:

- `Scenario` in `src/core/test/dst_harness.ail` already carries `seed: string` (all current
  scenarios set `"fixed"`).
- The failure contract (`scenario=<id> seed=<s> invariant=<inv>` + `trace` lines) already
  reserves the seed slot.
- The Phase 3 invariants (`validate_compactor_output`, `history_valid_transcript`,
  `validate_checkpoint_chain`, tool-pairing, system-prefix) are properties, not exact-output
  assertions — exactly what generated inputs need as an oracle.

## Pre-existing bug found during discussion

`report_failure` in `dst_harness.ail` hardcodes `seed=fixed` in its output instead of printing
the scenario's `seed` field, and `run_one` passes only `s.id` through. This breaks the replay
contract the moment any scenario has a non-fixed seed. Fix this first, regardless of when Phase 4
lands.

## Grounding facts verified this session

- **No `std/random` in AILANG** — stdlib search via the docs MCP returns nothing for
  random/seed/prng, even at `latest`. The PRNG must be hand-rolled.
- **AILANG ints are 64-bit two's-complement with silent wraparound** — probed with the local
  `v0.24.2` binary: `2^62 + 2^62 = -9223372036854775808`.
- **Lehmer/minstd LCG arithmetic is overflow-safe**: `48271 * (2^31 - 1) ≈ 1.04e14 < 2^63`, so
  `(a * s) % m` with plain `*`/`%` is correct without bitwise ops. Verified
  `(48271 * 12345) % 2147483647 = 595905495` locally. SplitMix64 would need xor/shift operators,
  which were not confirmed to exist — minstd is the safe choice.

## Proposed design — five pieces

### 1. PRNG: `src/core/test/dst_rng.ail`

Pure Lehmer/minstd LCG: `state' = (48271 * state) mod (2^31 - 1)`, exposed as
`next(s: int) -> (int, int)` (value, new state). Pure integer arithmetic — no new capabilities,
no Clock, determinism by construction.

### 2. Generator combinators: `src/core/test/dst_gen.ail`

Thin threaded-state layer over the RNG: `int_in(lo, hi, rng)`, `pick(xs, rng)`,
`list_of(n, gen, rng)`, `weighted_bool(pct, rng)`. Sufficient for the ADR's Phase 4 parameter
list.

### 3. Scenario families, not new scenario types

A seeded family is a function `gen_scenario(seed: int) -> Scenario` that draws params, closes
over them, and returns `{ id: "compaction.gen.<family>", seed: show(seed), run: ... }`.
`run_all` works unchanged; the gate script expands the family over a seed list into a plain
scenario list.

**Debuggability requirement**: generators must echo the drawn parameters into the failure trace
(e.g. `trace param msgs=47 tool_len=312`) because there is no shrinking — a failing seed must be
human-readable, not just re-runnable.

### 4. Seed sourcing: from the caller, never from inside AILANG

No clock or entropy in-process. Makefile/CI passes `DST_SEEDS=N` (count) and `DST_BASE_SEED=k`
(start), read via `std/env` in the gate script (adds `Env` to seeded gates' caps — acceptable
under the narrowest-caps rule).

- Replay: `DST_BASE_SEED=<failing seed> DST_SEEDS=1 make <gate>_seeded`.
- Nightly: CI passes a date-derived base seed (`$(date +%Y%m%d)`) — each night explores new
  space, fully reproducible from the printed seed.
- PR CI: pinned `DST_SEEDS=5 DST_BASE_SEED=1` so the fast gate stays byte-deterministic.

### 5. Gates and CI

New `dst_seeded` make targets alongside the fixed ones; CI references make targets only (standing
rule). The "pass count must increase by exactly your additions" anti-silent-drop oracle breaks
when counts depend on `DST_SEEDS`, so seeded gates report a separate line shape —
`family=<id> seeds=<N> ok` — and fixed-scenario counts stay untouched.

## Explicitly out of scope for v1

- **Shrinking.** QuickCheck-style shrinking in AILANG is a large lift for marginal value given
  parameter echo + single-seed replay. Structure generators size-first so manual bisection is
  easy.
- **L2 (TypeScript) seeded generation.** If wanted later, `fast-check` under bun is the idiomatic
  path; land the AILANG side first.
- **Grammar-level structure generation.** See next section.

## Why parameters, not grammars (oracle-preservation rule)

Every scenario has a **shape** (qualitative structure: which message kinds in which order, which
tools, which extension decisions) and **parameters** (quantities: counts, sizes, token numbers).
Phase 4 generates parameters around hand-written shapes. Generating shapes from a message-sequence
grammar was considered and rejected for v1 because it breaks the oracle in three ways:

1. **Oracle re-implementation.** Invariants assume legal input. A grammar can emit e.g. an
   orphaned tool result; deciding what compaction *should* do with malformed history means
   encoding compaction policy into the test — a second copy of the policy that can share bugs
   with the first. Fixed shapes guarantee legality by construction, so any invariant violation is
   a genuine production bug.
2. **Uninformative failures.** A grammar-generated failure first raises "is this input even
   reachable by the production loop?" Filtering unreachable shapes precisely requires specifying
   the loop's reachable-state space — again re-implementing the system under test.
3. **Wrong bug class.** The bugs that motivated ADR-001 (`last_input_tokens` carry-forward,
   ephemeral compaction vs persisted history, tier selection 60/75/85 vs 70/85/95, emergency
   entry vs exhaustion gating) are threshold/state-carry bugs — quantities crossing boundaries on
   fine shapes. Parameter generation aims directly at those; grammar generation spends budget in
   shape-space where the known bug classes don't live.

**Escape hatches**: (a) new shapes are cheap to add by hand — a real bug with a novel shape
becomes a new fixed scenario family, then generators fuzz its parameters; (b) enumerated shape
choices as parameters (e.g. a generated `PassThrough`/`Compacted` decision at step k, or a pick
from fixed history skeletons) cover the ADR's "extension decisions" bullet while every choice
indexes into hand-vetted, reachable-by-construction structures.

The v1 rule: **generate only along axes where legality is guaranteed by construction.**

## Recommended starting point

`compaction.gen.*` families on the L0 policy gate (`scripts/dst/compaction_policy_dst.ail`):
generate tool-heavy histories straddling the exported elide/emergency thresholds; assert
`validate_compactor_output`, tool-pairing preservation, system-prefix preservation, and estimate
monotonicity (compacted ≤ original). Pure, runs under `--caps IO,Env`, exercises the whole
pipeline (RNG → gen → family → harness → failure contract), and thresholds are already exported
constants so no policy duplication. Then extend to L1 `phase_c.l1.*` (token counts near tiers,
extension decision sequences via scripted ports).

## Open decision points (for operator)

1. **Nightly base seed**: date-derived (explores new space each night, reproducible from printed
   seed) vs fixed enumeration `1..N` (identical every night, never explores new space).
2. **Seed config channel**: `std/env` inside gate scripts (adds `Env` cap) vs generating the seed
   list into a fixture file to keep gates cap-minimal.
3. **Priority**: L0 `compaction.gen.*` first (cheapest, proves the pipeline) vs going straight to
   L1 `phase_c.l1.*` where the real regression risk may live.
