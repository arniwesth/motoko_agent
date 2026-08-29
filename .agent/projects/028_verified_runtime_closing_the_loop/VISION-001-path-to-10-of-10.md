# VISION-001 — What it would take to reach 10/10 in concept

Date: 2026-08-29
Status: Proposed (companion to ADR-001; work items in PLAN-001)
Evidence base: NOTE-motoko-session-assessment.md

The current 9/10 concept: "the agent should prove its code." That already
exists and works — Z3 refuses to commit an unverified cell (reproduced live
with the `buggyMax` counterexample). The 10th point is not a feature. It is
**closing the enforcement loop all the way down**, at four layers. Each layer
has working machinery in the repo today; none requires new autonomy, bigger
models, or more languages.

## Layer 1 — The runtime enforces its own contract on itself

SYSTEM.md says: *"The runtime will not catch this for you — that gate is on
the roadmap (msg `06adbc32`) but until then, the discipline is yours."*

The gate now exists (`session.ail:1800` `run_dp7_verifier`, runs
`make check_core` pre-finalize, injects rejection feedback) — but line 1804
is `Err(_) => Approve`: fail-open, plus config-switchable via
`rt.verification.enabled`. A 10/10 inverts the default: fail-closed and
non-bypassable in shipped profiles. The philosophy already exists at the cell
level ("not committed: verifier found a counterexample"); it is one semantic
flip away at the finalization level.

**Done when:** a verifier infra failure produces a visible rejection with a
reason (never a silent approval), and SYSTEM.md's "discipline is yours"
clause can be deleted as dead text. (PLAN-001 items 1, 3.)

## Layer 2 — The verification asymmetry is closed

Discipline lives in 66 AILANG files (~35K lines); 1,175 TypeScript files run
outside any verifier — including `env-server.ts`, the tool-execution layer the
verified core must trust, where the fail-open batch-skip bug ships with zero
test coverage. A 10/10 shrinks the TS layer to an irreplaceable minimum
(terminal, canvas) and moves every decision-bearing line into the verified
language — or brings contracts to the JSONL boundary itself.

**Done when:** the answer to "is there any code that can change agent
behavior which no verifier ever sees?" is *no*. Incremental path:
`012_continuous_ailang_adoption` + boundary contracts (ties to
`025_envharness_contracts`). (PLAN-001 item 5 for the boundary piece.)

## Layer 3 — From proven functions to proven claims

Today's Z3 gate proves *functions*. The same mechanism one level up:
**provenance for assertions**. An agent's factual claims ("56/56 pass",
"Lean unavailable") are statements about the world carried back through tool
results. A 10/10 runtime treats claims like cells: every final answer cites
the tool-call IDs / artifacts backing it, and unbacked claims are flagged
with the same vocabulary (`verified` vs `skipped` vs `unbacked`) instead of
trusting prose.

**Done when:** a final answer with an uncited factual claim is rejected or
flagged exactly the way an unverified cell is. Design doc first, then a
DP-style gate.

## Layer 4 — The recursion completed: Motoko fixing Motoko

Strongest precedent in the repo: the `ohmy_pi` token-storm bug (25-33% of
every BashExec call wasted) was found by **their own agent**, fixed with an
A/B repro (15x faster runs), a fail-fast startup guard, and a pinned
regression smoke (`make smoke_no_delegated_storm`). That is the 10/10 seed.
Completing it means a standing self-repair loop: dogfooding agents file
structured failure reports (msg hash + repro), and each report must close
with a pinned regression — so a bug class like the silent batch veto becomes
structurally impossible to reintroduce, rather than individually noticed.

**Done when:** every session-discovered defect lands as (guard + regression
test) automatically tracked, and the count of unpinned failure paths trends
to zero. The batch-skip bug (zero tests on its path) is the first candidate.

## What a 10/10 does NOT require

Not longer autonomy, not more languages, not bigger models. The ceiling is
about **where correctness enforcement lives and whether it can be bypassed**:
fail-closed gates, no unverified decision code, no unbacked claims,
self-improvement as a pinned-test pipeline.

## One line

A 9/10 concept says *"the agent should prove its code."* The 10/10 says:
**"the runtime cannot be convinced to skip the proof — by the agent, by
config, or by its own failure."** Motoko is close: it refuses unverified
cells, has the finalization gate written, and already documents the
philosophy. The most important line in the project is currently the one at
`session.ail:1804` that says *yes when it cannot check*.
