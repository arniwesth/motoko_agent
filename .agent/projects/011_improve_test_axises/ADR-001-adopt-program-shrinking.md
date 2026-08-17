# ADR-001: Should we adopt program shrinking for test-case minimization?

**Status:** Proposed
**Date:** 2026-08-16

Relates to:
- `RESEARCH-test-axes-beyond-dst.md` — the research survey this ADR turns into a
  decision. Its §3.2 ranks program shrinking second by leverage-per-effort and
  sketches the ddmin design adopted here; its §2 records that the AILANG native
  shrinker is the wrong tool.
- `src/core/dst_program.ail` — the serialized `ExecutionProgram` this design
  minimizes over.
- `src/core/dst_replay.ail` / `scripts/dst/strict_replay_dst.ail` — the strict
  replay oracle this design reuses.
- `src/core/dst_invariants.ail` — home of the invariant-violation constructors
  (V) the keep rule keys on.
- `../../016_github_ops/ADR-001-github-pr-ops-pipeline.md` — this repo's ADR
  style exemplar (header, Context / Options / Decision / Consequences,
  Cross-references).

---

## Context

A failing deterministic-simulation discovery run records a full `ExecutionProgram`;
today a failing nightly seed is promoted to the corpus by hand, in whatever size it
fell. The most-cited evaluation gap is that failing programs are never *minimized*:
the paper's self-diagnosis (§8) names "no shrinking" and "no automatic promotion" as
two halves of a single gap. The question is which mechanism should shrink recorded
programs, and what must be true of a candidate reduction before it is kept.

## Options considered

1. **Do nothing.** Keep raw failing cases as-is and continue promoting seeds by hand.
   Zero implementation cost, but large cases stay hard to debug, corpus noise grows,
   and the gap stays open.
2. **AILANG native `property` shrinker.** The native shrinker exists and shrinks
   values with free counterexample reduction. It is the wrong tool because it shrinks
   *values*, not *recorded programs* — the reproduction key is the serialized
   `ExecutionProgram`, not the seed (RESEARCH §2, §3.2), so nothing off the shelf
   applies.
3. **ddmin over `ExecutionProgram`, strict replay as oracle (chosen).** The expensive
   half is already built: strict replay re-executes a program without the generator and
   compares normalized terminal traces. Minimization reduces to classic delta debugging
   over one data structure, generator-agnostic, one implementation covering all axes.

## Decision

Adopt **program shrinking by ddmin over the serialized `ExecutionProgram`** of a
failing discovery run, with strict replay as the oracle, per RESEARCH §3.2:

1. A failing discovery run records program P violating invariant constructor V.
2. ddmin over P's step list (and secondarily over per-step payload fields): candidate
   P′ → strict replay → **keep P′ iff the violation is the same constructor V** — not
   merely "some violation". This is the one subtle design decision; the construction
   is that constructors are deliberately 1:1 with invariant rules (~53 of them), so
   same-constructor is the obvious criterion and the keeper must be able to record
   (not silently drop) discarded shrinks that failed with a *different* constructor as
   secondary findings.
3. Minimized P* is auto-promoted into the fixed corpus with provenance: nightly run
   id, original seed, original/minimized step counts.

Validity constraint (also from §3.2): a shrunk program must remain well-formed — ddmin
operates at a step granularity that preserves pairing by construction (remove
call+result atomically) or replay's existing program validation rejects malformed
candidates cheaply.

### House caveats respected

Both standing constraints from the RESEARCH TL;DR are respected, despite neither being
about shrinking directly:

- **Mutation proves a guard CAN fire, not that it fires too much.** This design never
  treats a surviving-minimized-program as license for more lenient shrinking; and the
  keeper records discarded-different-constructor shrinks separately rather than dropping
  them, so the over-firing direction stays visible.
- **Faults are outcomes at the typed boundary, never Buggify-style in-code fault
  points.** Shrinking takes only recorded programs as input and never injects test-only
  branches; it preserves the boundary-outcomes model by construction.

## Consequences

**Costs:**
- Replay-based minimization is compute-heavy — measured ~381 ms/seed replay, so a
  100-probe ddmin run is ~40 s. Viable in the nightly job, not on a PR gate.
- Strict replay is deterministic only when the world is; flaky-discovery failures will
  resist shrinking.
- Provenance metadata adds corpus bookkeeping; the kept/discarded same-vs-different-V
  accounting is a new record shape.

**Enables:**
- Small, reviewable failing cases with traceable origin (nightly run id, seed,
  step-count delta).
- A growing, automatically curated regression corpus — the other half of the most-cited
  gap, closed.
- A foundation for later oracle refinements without touching generators.

**Explicitly NOT decided here:** Z3 contract expansion (§3.1) and AILANG `property`
adoption (§3.4) remain separate open items from the RESEARCH ranking; this decision
does not change their status.