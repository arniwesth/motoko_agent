# ADR-001: What governs contract adoption — solver-computed classification, not a proven count

**Status:** Proposed (v2 — supersedes v1 after adversarial review)
**Date:** 2026-08-29 (v2: 2026-08-29)
**Review record:** `REVIEW-adr001-verdicts.md` — two independent adversarial reviews plus
local re-measurement. v1 was **rejected as written**; three of its load-bearing claims were
false and are retracted below.

Relates to:
- `REVIEW-adr001-verdicts.md` — the review that killed v1 and the measurements behind v2.
- `RESEARCH-contract-baseline.md` — still the baseline; §3 E7 (added after this ADR's v2)
  supplies the substantive guard contracts that make §1's `spec-equals-body` tier a waypoint.
  **§3 E4 and §4.5 are retracted**
  (see Retractions). §1's classification of the four contracts stands, independently confirmed
  by two mutation probes.
- `PLAN-z3-contract-adoption.md` — v2 of the plan; P2's *upstream ask* is cancelled and the
  slot now holds the local string-tier refactor, P3's mechanism changed, P5 added.
- `design_docs/planned/m-motoko-z3-contracts.md` — origin doc; its `verify_core: >= 5 proven`
  acceptance criterion is rejected here as before.
- `src/core/dst_invariants.ail` — the pinned-register pattern, and (`:72-84`) the record of
  how a hand-maintained register fails. v1 proposed repeating that failure; v2 does not.
- `src/core/session.ail:1800` — DP7, the consumer that makes this load-bearing.

---

## Context

`ailang verify` runs, Z3 4.8.12 is wired, `make verify_core` is green. It reports `2 with
contracts, 0 failed, 51 without contracts` across 53 modules. Four contracts verify. One is
substantive; two are tautologies over `bool`; one restates its own body verbatim.

The contract layer is where the DST axis was before 007's conformance bar: a
verification-shaped surface whose green is not evidence. Three symptoms, all measured twice:
`verify_core` prints ✓ for `compress.ail`, which proves nothing *and* whose `requires` clauses
are never checked against any caller (`verify.go:290-304`); two `@verify(depth: 1)` predicates
in `agents_md.ail:192,198` sit under a `Z3 / SMT verification targets` banner that no tool
reads, one claiming a termination guarantee nothing has checked; and the design doc's success
metric is a count that rises fastest by writing tautologies.

The decision needed before any contract is written: **what is the unit of progress?** Get it
wrong and the work produces a number that goes up while the codebase learns nothing — and that
number is the one proposed to gate the autonomous loop.

## Retractions from v1

Recorded first because they change the decision, and because v1's confident tone about them
is exactly the failure mode this ADR is about.

1. **"Solver-side triviality detection is not available today" (Option 4) — false.** The
   classification is two mechanical probes and runs in 0.25s for all four contracts
   (REVIEW §2.1). v1 deferred to upstream a mechanism the local solver already provides.
2. **"No string-producing function can carry a contract" (RESEARCH E4) — false.** The
   conclusion stands and the string tier is **not** gated on upstream work, so the *upstream
   feedback item* is cancelled — PLAN v2 reuses the P2 slot for the local refactor that
   replaces it.

   The cause recorded here on first writing — a bare `str_length` instead of
   `std/string.length` — is **not** the blocker; corrected after a direct counterfactual.
   Holding the ensures at `std/string.length` and keeping the interpolation still yields
   `SKIPPED — unencodable builtin: show`; swapping the interpolation for `concat_String`
   verifies (`[32.6ms]`). The blocker is string interpolation lowering through `show`, and the
   fix is `concat_String` plus `pure func` — RESEARCH §3 E4's three verdicts, unchanged.
3. **"`verify_core` is seconds" (RESEARCH §4.5) — false.** Measured 15.3s (REVIEW §2.4).
4. **"DP7's rejection tells the model its code was verified" (v1 §5) — inverted.** DP7 says
   *"does not type-check"* (`session.ail:1825`). A vacuous gate can only make DP7 *approve*
   more; it cannot produce a misleading rejection. v1's argument for delaying P4 was wrong,
   even though P4 should still be delayed.
5. **"Amber prints the rejection code AILANG already gives" — not on the text path.**
   `verify.go:340-349` prints `r.Message` only. P0 promises reasons, not codes.

Two reviewers found 1, 3, and 4 independently. 2 was found by one reviewer and confirmed by
me with a corrected probe; the root cause (a typo in my own experiment) was mine to find.

## Options considered

1. **Do nothing.** Zero cost, but the misleading surface already exists and a reader who
   greps `@verify` or reads a ✓ concludes something is checked. Not neutral.
2. **Coverage sweep against a proven count** (the design doc's plan). Cheap, legible, and
   satisfiable without ever constraining a body — three of today's four contracts would count.
   Rejected.
3. **Classification register, hand-maintained** (v1's choice). Right taxonomy, wrong
   mechanism: a hand register cannot validate its own labels, and name-pinning in both
   directions asserts inventory, not classification truth. An editor changes the contract and
   the label together, which is not even an attack — it is the normal workflow. This is the
   failure recorded at `dst_invariants.ail:72-84`, and v1 proposed repeating it while citing
   it. **Superseded by option 5.**
4. **Solver-side classification**, which v1 called unavailable. It is available. Merged into
   option 5.
5. **Solver-computed classification, pinned, with a narrow human residual (chosen).** The
   class of every contract is *computed* by Z3 and pinned; a human may override only on
   recorded grounds, and every override names the probe result it overrides. The pinned
   artifact and the tree can then only agree by being right.

## Decision

**Contract adoption is governed by solver-computed classification. `proven` is not a metric;
`substantive` is. The classification is generated and pinned, not hand-written.**

### 1. The classification, mechanically defined

For contract `E` over `f(args) -> T` with body `B`, two probes decide the class:

- **TAUT** — `f_taut(args, r: T) -> T ensures { E } { r }`. VERIFIED ⇒ `E` holds for every
  result ⇒ **tautology**.
- **DETERMINE** — `f_det(args, r: T) -> T requires { E[result := r] } ensures { result == B(args) } { r }`.
  VERIFIED ⇒ `E` admits only the body's answer ⇒ **spec-equals-body**. This is semantic, not
  textual, so it also catches restatements through lets, aliases, and algebraic rewrites.
- **substantive** ⇔ both probes VIOLATION: `E` is falsifiable *and* admits results the body
  would not produce.

Measured on the four live contracts (REVIEW §2.1, 0.25s total):

| Contract | TAUT | DETERMINE | Class |
|---|---|---|---|
| `normalize_range` (`tool_runtime.ail:196`) | VIOLATION | VIOLATION | **substantive** |
| `isSome` (`:24`) | VERIFIED | — | tautology |
| `is_native_backend` (`:1007`) | VERIFIED | — | tautology |
| `is_absolute_path` (`:277`) | VIOLATION | VERIFIED | spec-equals-body |

Only the first counts. The other two are permitted and registered, never counted.

**Residual, acknowledged.** A contract can be falsifiable and non-determining yet unrelated to
the body's purpose (`ensures { result.start >= -1000 }`). No probe catches that; it is the one
place a human judgment is required, and it is narrow. Overrides must name the probe result
they override, so an override is always visible as a disagreement with the solver rather than
a fresh opinion.

**What `spec-equals-body` is worth.** v1 said it pins the body against silent edits. It does
not — contract and body sit in one declaration and are edited together. But it does catch a
body-only edit, which makes it a regression *test*, not evidence. Kept, counted as zero
substantive, and described honestly.

**And it is a waypoint, not a resting place** (added after RESEARCH §3 E7). The reviewers'
disagreement was over whether a restatement on an uncovered guard is worth keeping. The
question is moot where a substantive contract exists, and for both guards that motivated it
one does — measured, not argued: a *recall* property (`(not contains(s, ";") || result) && …`
on the shell-token guard: ✓ on the current body, ✗ with `";"` removed, ✓ with a token added)
and a *precision* property (`result == false || contains(path, "/")` on the bare-root guard,
✓ VERIFIED). Both are strictly weaker than their bodies, so both classify **substantive** and
count, and each survives a different legitimate edit that a restatement would obstruct.

So a `spec-equals-body` entry in the register is a standing invitation to look for the weaker
property, and the register should read as such. Where the search has been done and failed, the
override line records that — the same mechanism as the residual above, used to say "no
abstraction found" rather than "solver disagreed". The sweep is `PLAN` P5.

### 2. The register is generated, pinned, and checked in both directions

Following `display_only_baseline()` / `parity_register_findings()`: a `verify_classify` target
emits the probe modules, runs them, and writes `contracts.register` (name → class,
machine-written, with `-- override: <grounds>` lines where a human disagrees). The check
fails if any contract's *computed* class differs from the pin. Both directions hold: a contract
that changes class without the pin moving is red, a pinned contract that no longer exists is
red, and — the part v1 could not do — **a contract whose class is hand-relabelled while the
solver computes something else is red.** Reclassifying *into* substantive remains the edit
that must be hardest to make by accident, because that is the direction the metric rewards.

### 3. The gate may not report a false green

Precondition (PLAN P0). `verify_core` stops ticking files that prove nothing. No file with
zero `VERIFIED` lines prints a ✓, and each prints the reason `ailang verify` gives
(`no ensures clause (nothing to verify)`, `uses an unencodable builtin: std/string.concat`) —
reasons, not codes, unless P0 adds JSON plumbing (REVIEW §2.5).

**Split by cause, and treat the halves oppositely.** "Amber" is two states that happen to look
alike in a count:

- **unstated** — `requires` with no `ensures`: no obligation was ever written. `compress.ail`
  is the whole population (measured: the only file in `src/core/` with `requires` and no
  `ensures`), and it is **unchecked**, not merely unproven — its `requires` clauses are never
  asserted against a caller (`verify.go:290-304`), so they are documentation. This half
  **fails the build**, because an incomplete annotation is worse than none: it reads as
  specified.
- **blocked** — an `ensures` exists and the fragment rejected it (`NOT_PURE`, `RECURSIVE`,
  `HIGHER_ORDER`, `UNENCODABLE_TYPE`). This half is reported and **never fails**. Failing here
  punishes the attempt, and makes deleting the contract the cheapest route to green — the
  exact incentive §4's justification comments exist to avoid.

**When it flips: at P2, not at the register.** The failing half costs one file to adopt and P2
fixes that file, so it lands in the same commit. v1 tied this to the register landing; a
zero-cost ratchet deferred to an expensive milestone is how the design doc's own Phase 1 came
to ship green and empty for months. Note the contrast with §4, which genuinely must be
`git diff`-keyed because ~1545 declarations predate it — here there is no backlog to grandfather.

### 4. Justifications name a rejection reason

Every new `pure func` in `src/core/` carries a contract, or a comment naming what blocks it:

```
-- contracts: SKIPPED — uses an unencodable builtin: std/string.concat (rewrite to concat_String)
-- contracts: SKIPPED — RECURSIVE (find_last)
```

Free text is what let `compaction.ail`'s honest comments and `agents_md.ail`'s misleading
banner look alike. A checkable reason is better than an excuse. Applied to **new** declarations
only, keyed on `git diff` — v1's form applied to ~1500 existing declarations with no migration
story, which is not a policy.

### 5. The ratchet is tied to the register, not to a date

The `unstated` half of §3 fails from P2 (not from the register — see §3). `verify_core` is
folded into
`check_core` — and therefore into DP7's oracle — only when the register exists **and** three
things hold, none of them vacuity:

- **touched-file scoping, not a wall-clock budget.** `verify_core` is 15.3s today against
  ~20s for `check_core` (REVIEW §2.4): +75% per finalize *before a single new contract
  exists*. Measured since (PLAN Q2): that cost is ~97% per-module fixed overhead — 53 modules
  at ~350ms each — and only ~3% contract solving, which runs at **~11ms per contract, linear**
  (4/16/64 probes: 67/183/694ms; worst measured single contract 73ms, a 9-way `startsWith`
  disjunction). Fifty contracts therefore add ~0.6s, not a doubling. So the budget is not the
  lever and watching a number is not the fix: scope DP7 to the modules the step actually
  touched, which `m-motoko-dp7-verifier-gate.md` already defers as v2 work. With scoping, the
  marginal cost of folding `verify_core` in is one module's parse plus its contracts.
  Classification cost does **not** enter here at all — `verify_classify` maintains the
  register in CI and never runs in DP7's path.
- **an honest DP7 message.** `session.ail:1825` says "does not type-check". A Z3 timeout must
  not surface as a type error; the message has to distinguish them before verify rides along.
- **a pinned verified-set.** The regression a weak gate would otherwise miss is *disappearance*
  — `VERIFIED` becoming `SKIPPED` — so the identities that must stay VERIFIED are pinned and
  their absence fails.

Roll out in `dogfood` first.

## Consequences

**Accepted costs.** Probe generation is a real tool (~40 lines, per the review) and another
artifact in the build. The residual class needs a human. Contracts on string-producing
functions may need a mechanical rewrite from `std/string.concat` / interpolation to
`concat_String` to be provable — a source change, not an upstream wait.

**What gets slower.** Much less than v1 predicted: the classification is generated, so no
judgment call per contract. The first honest report will still look *worse* than today's —
2 files with contracts and 4 proven becomes roughly 1 substantive, 1 unstated, 2 tautologies and
1 restatement registered. That regression in the number is the decision working.

**What changed by cancelling P2.** Nothing upstream is needed. The string tier is open now, so
P3 can write contracts there immediately rather than blocking. This is a scope *reduction* of
about half a day and the removal of an external dependency.

**What unblocks.** A substantive count is a metric DP7 can be gated on without lying to the
model — the oracle upgrade argued for in [2503.10784](https://arxiv.org/abs/2503.10784) and
recorded in `papers/README.md`. It also gives `023_hybrid_verification_cris` §7 (mock and
contract must not drift) a place to attach: a shared validity predicate is registrable as
substantive on both sides.

**What stays open.** `std/string.concat` and `join` remain unmapped, so list-driven string
building must be rewritten to `concat_String` to carry a contract; whether that rewrite is
worth it per call site is a judgment P3 makes as it goes. De-recursing `find_last` is still
its own change (PLAN P1.2).

## Cross-references

- Implementation: `PLAN-z3-contract-adoption.md` (v2) — P0 (§3), P3 (§1, §2, §4), P4 (§5).
- Evidence: `REVIEW-adr001-verdicts.md` (authoritative; corrects RESEARCH §3 E4 and §4.5),
  `RESEARCH-contract-baseline.md` §1 (classification, confirmed), §2 (three false greens).
- Pattern source: `src/core/dst_invariants.ail` — and, at `:72-84`, the warning this ADR's v1
  failed to heed.
