# Additional eval backends — Lean 4 and other verifiers

Date: 2026-06-18. Author: design discussion following the plan-05 AILANG eval
implementation. Status: **research / not committed to a plan.**

## Context

Plan 05 added `language:"ail"` to the `eval` tool: a persistent, source-backed
AILANG scratchpad gated by `ailang ai-check`, with optional Z3 contract
verification. In building it we did not really build "an AILANG kernel" — we
built a **verified-eval kernel pattern**:

- a **source-accumulating session** (accepted declarations/imports persist; a
  failed candidate never mutates state),
- a **check → optional-verify gate** that decides whether to commit,
- **honest status mapping** (`check: passed|failed|skipped`,
  `verify: verified|failed|unknown|timeout|skipped`) where `verified` means the
  prover actually proved it,
- a **one-time teaching prompt** surfaced in the visible output,
- env-server normalization + a host capability ceiling + TUI status rendering.

Any backend whose workflow is "accumulate declarations → check → optionally
prove" slots into that shape. The existing lanes:

- **py / js** — general *compute* (mutable REPL kernels).
- **ail** — *type-check + SMT-contract* verification of pure functions.

The interesting new axes are **stronger proof** (arbitrary theorems),
**imperative/contract verification**, **system/protocol model checking**, and
**raw constraint solving**.

## Headline candidate: Lean 4

Lean 4 is the most interesting addition because it upgrades the eval tool from
"checks contracts" to "**proves theorems**" — arbitrary mathematical/logical
propositions, not just the decidable arithmetic fragment SMT handles.

### How it fits

- **Backend: the Lean `repl`** (`leanprover-community/repl`), not raw
  `lean file.lean`. It accepts JSON commands and returns JSON with `messages`,
  `sorries`, and — crucially — an **`env` id you thread into the next command**.
  That environment-threading is a near-drop-in for our `AilangSession`
  persistence model: each accepted cell advances the environment; a failed cell
  doesn't advance it. We'd barely have to invent persistence semantics.
- **The proof caveat becomes more important AND sharper.** With Z3, "not
  verified" = unknown / timeout / counterexample. With Lean, the silent escape
  hatches are `sorry` / `admit` and sneaky `axiom`s. So `verify: verified` must
  mean **"elaborated with zero `sorries` and no unexpected axioms"**, confirmed
  via the repl's `sorries` field **plus** a `#print axioms` check (flag anything
  beyond the standard `propext` / `Classical.choice` / `Quot.sound`). This is the
  exact same honesty discipline as AILANG's `available/verified/unknown`, with a
  Lean-shaped status set: `verified | sorry | failed | error`.

### Caveats (honest)

- **Weight / latency.** Bare Lean (installed via `elan`) is fine and fast. The
  moment you want **Mathlib**, you're into multi-GB caches and slow elaboration;
  per-cell latency goes from sub-second to seconds+. Recommendation: ship
  **Lean-without-Mathlib** first (already strong for logic, arithmetic,
  inductive proofs), make Mathlib an opt-in / pre-warmed flag.
- **No cheap `ai-check` equivalent** — elaboration *is* the check. The repl's
  persistent env mitigates re-elaboration of prior cells.
- **Teach prompt matters even more** — models reflexively write Lean 3 tactics.
  A Lean-4-specific guide surfaced once (same mechanism as AILANG) is important.

## Other candidates

| Backend | New capability it adds | Fit to the kernel pattern | Cost |
|---|---|---|---|
| **Lean 4** (repl) | Real theorem proving (arbitrary math/props) | Excellent — env-threading = persistence; sorry/axiom detection = proof caveat | Medium (heavy with Mathlib) |
| **Dafny** | *Imperative* verification: `requires`/`ensures`/`invariant`, loop/array proofs | Excellent — closest sibling to AILANG; **reuses the Z3 we already installed**; verified/failed/timeout/counterexample maps onto existing status code | Low–Medium |
| **SMT-LIB / Z3 cell** | Raw constraint/SAT solving, models & unsat cores | Trivial — Z3 already present; reuses counterexample/model rendering | Very low |
| **TLA+ / Apalache** | *System*-level reasoning: temporal invariants, concurrency, protocols | Different flavor (model checking, counterexample traces) | Medium |
| **Alloy** | Lightweight relational/structural invariants, fast counterexamples | Counterexample-driven; lighter than TLA+ | Low–Medium |

Also-rans / deliberately not prioritized:

- **Coq / Rocq** — same lane as Lean 4 but older UX; pick Lean 4, not both.
- **F\*** — dependently typed + SMT; powerful but heavy; overlaps Lean + Dafny.
- **Idris 2** — dependent types + totality; lighter than Lean but smaller
  ecosystem/AI-tooling story.
- **CBMC / Kani (Rust)** — bounded model checking for C/Rust; niche but
  interesting if Motoko works on systems code.

## Recommendation

- **Most impressive / best-aligned next step:** **Lean 4 via the repl.** Turns
  eval from "checks contracts" into "proves theorems," and the honesty/proof
  plumbing from plan 05 is exactly what stops it from lying about `sorry`.
- **Cheapest high-value win:** **Dafny** (reuses Z3, sibling semantics, near-zero
  new conceptual surface) or an **SMT-LIB cell** (roughly an afternoon).

## Suggested next action (before committing to a plan)

Run a **Phase-0-style spike** mirroring the plan-05 AILANG verification, i.e.
verify behavior empirically rather than assuming:

1. Install path: `elan` → `lake` → build/run the `repl`.
2. JSON shapes: command in, `{ messages, sorries, env }` out.
3. Environment-threading: prove a `theorem` in cell 1, use it in cell 2.
4. Honesty signals: confirm `sorries` reporting and `#print axioms` output (so
   `verified` can be defined as "no sorries, no unexpected axioms").
5. Latency: cold vs. warm, with and without Mathlib.

Output: a short smoke note (like `05-phase0-smoke-notes.md`) recording exact
commands + JSON, so the Lean-without-Mathlib vs. Dafny vs. both decision is made
on measured facts, not assumptions.

## Design note: generalizing the kernel pattern

If two or more verifier backends land, factor the shared shape out of
`kernel-ailang.ts` / `ailang-session.ts`:

- a `VerifiedSession` interface (accumulate / render / commit / reset),
- a `VerifierKernel` interface (`run(cell) -> { check, verify, committed, ran,
  functions, notice }`),
- per-backend **status mapping** (the only part that's genuinely
  language-specific) and a per-backend **teach prompt**.

The TUI status lines, env-server normalization, capability ceiling, teach-prompt
surfacing, and proof-caveat wording are all backend-agnostic and already exist.
