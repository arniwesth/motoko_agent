---
doc_type: short
full_text: sources/Brain_Formal_Verification.md
---

# Brain Formal Verification — Summary

This document defines a **three-tier formal verification stack** that extends the brain's self-modification upgrade pipeline beyond the existing test suite ([[concepts/brain-test-suite]]). It introduces two research-grade, independently removable gates — Dafny and Lean 4 — that sit above the production Z3 tier.

## Core Idea

Formal verification is organised as a **cost-escalation ladder**, not redundant parallel checks. Each property is attempted at the cheapest tier first; success at a lower tier prevents escalation to higher tiers.

| Tier | Tool | Feedback | Scope |
|------|------|----------|-------|
| 1 | Z3 (existing) | Counterexample or timeout | Quantifier-free invariants, linear arithmetic |
| 2 | Dafny | Concrete counterexample with input bindings | Recursive termination, postconditions, structural properties |
| 3 | Lean 4 | Unsolved proof goals | Full structural induction, behavioural equivalence, meta-theoretic properties |

## Phase 1 — Dafny (Tier 2)

Dafny bridges the gap between Z3's quantifier-free ceiling and Lean 4's proof-theory requirements. The brain re-implements AILANG functions in Dafny with `requires`/`ensures`/`decreases` clauses. Dafny calls Z3 automatically; when verification fails, the brain receives **concrete counterexamples** (e.g., `path = "/"`, `result = ""`) rather than unsolved goals. This makes the revision loop fundamentally about bug-fixing rather than proof construction.

Key targets: `walk_agents` termination, `dirname` shrinking, `extract_fence` structural postcondition, `parse_cwd` absolute-or-unchanged.

## Phase 2 — Lean 4 (Tier 3)

Lean 4 handles properties Z3 and Dafny cannot: full structural induction over unbounded data, equivalence proofs between old and new implementations, and properties about the language's own type system. The brain generates:

1. **An axiom layer** — `axiom` declarations bridging AILANG stdlib primitives to Lean 4's native `String` operations (trust anchors, ~10 axioms, human-auditable).
2. **Theorem statements** — behavioural contracts for each exported function.
3. **Tactic blocks** — proofs that discharge each theorem, revised when `lean --check` fails.

Key targets: `is_done` definitional equivalence, `parse_cwd` full induction, `with_cache_hint` prefix property, `extract_bash` priority order proof.

## Revision Loop Design

Both Dafny and Lean 4 phases implement a **budgeted revision loop** (default 5 attempts). On failure, the error output is fed back to the brain for revision. Budget exhaustion produces a **warning, not rejection** — the upgrade proceeds without the formal guarantee. This keeps both phases advisory during the research period. The brain is explicitly permitted to revise the *implementation* (not just the spec) when a proof reveals an actual bug.

## Relationship to Upgrade Pipeline

The formal verification gates sit between property tests and the `probe_main` smoke test in the upgrade sequence [[concepts/self-modifying-brain-safe-cutover]]. Gates 1–3 (type safety, inline tests, property tests, Z3) are hard failures. Gates 4–5 (Dafny, Lean 4) are advisory during the research phase. Gate 6 (smoke test) is a hard failure.

## Key Design Decisions

- **Independent removability**: Each phase gated by its own environment variable (`DAFNY_VERIFY`, `LEAN4_VERIFY`). Missing binary → skip with warning.
- **Mirror drift detection**: Dafny specs are re-implementations; stale specs (mismatched function signatures) count as verification failures.
- **Non-triviality guards**: Lean 4 specs are syntactically checked for vacuity — each function must have at least one theorem with a hypothesis or universal quantifier.
- **Artifacts as formal record**: Both Dafny and Lean 4 files are stored in `swe/dafny/` and `swe/lean4/`, constituting machine-checked evidence of behavioural contract preservation.

## What Success Looks Like

A brain upgrade passing both Dafny and Lean 4 gates has produced **machine-checked evidence at two independent levels of rigour** that new code satisfies the same contracts as old code. This is qualitatively distinct from testing: Lean 4 proofs can be checked independently of the brain that generated them.
