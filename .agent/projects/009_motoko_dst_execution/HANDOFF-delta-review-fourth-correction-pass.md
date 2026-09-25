# Handoff: delta review of the fourth correction pass to ADR-001-deterministic-test-world-architecture.md

Audience: a fresh agent session with no context from the correcting session. The corrections you are
reviewing were written by the authoring side in response to two delta reviews. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

**Narrow delta review.** The ADR carries nine `## Review Comments` sections: two full reviews
(2026-07-26), three verifications of the F1–F6 revision, two delta reviews of the second correction
pass, and two of the third (all 2026-08-01). The architecture has been reviewed to exhaustion. Your
target is one commit plus a small follow-up.

## Mission

Verify the **fourth correction pass**, which answers all six findings from the two delta reviews
recorded as the ADR's eighth and ninth sections.

## Target range

```text
abb059d  the two third-pass delta reviews (verbatim, committed before any response)  <-- BASELINE
f3a6a63  fourth correction pass
<HEAD>   ai_step scope correction + this handoff
```

```text
$ git diff abb059d..HEAD -- .agent/projects/009_motoko_dst_execution/
```

That range is exhaustive; there is no hand-maintained edit table, deliberately. The follow-up commit
corrects a factual scope claim made *in* `f3a6a63` — see A1 — and is the least-reviewed text in the
range.

The previous round, working from a real diff for the first time, produced zero anchor or provenance
findings against fifteen the round before. Use the diff.

## The one thing that is not a fact

**A1 is an adjudication, not a verified claim.** Both third-pass delta reviews found the second
`Ports.model_step` call and both deliberately left the disposition to the author, offering two
options. The authoring side chose one. Everything else in this pass is a fact you can check; A1 is a
judgment you should second-guess.

## Attack list

### A1. The extension-model-path exclusion — is it the right disposition, and is it enforceable?

D1 now excludes extension-issued model calls from the interim state-threaded seam, rather than
widening `ExtPorts.ai_step` and the hook results to carry the successor token. The stated grounds:
the ABI returns `Result[string, string]`, the hook results above it are decision-only, and widening
them is the world-token protocol D5 already requires — i.e. the ABI major, not a field change.

Attack it on four axes:

1. **Is exclusion right?** The alternative is pulling the ABI widening into the interim milestone.
   That collapses items 1–2 and the repin into one change. Argue whichever way the evidence goes, but
   note the consequence below before deciding the exclusion is too conservative.
2. **Is it enforceable, or is it a statement?** This is the sharpest question. D5's exclusion
   machinery is *per-hook*: an excluded hook is named in the result and causes a fail-closed
   `HarnessFailure` if dispatch reaches it. But `ai_step` is a **port on `ExtCtx`**, not a hook — any
   installed hook can call it. If the only enforcement available is excluding the whole extension,
   say so and say whether that is sufficient. **An exclusion with no detector is the "checklist
   wearing a gate's clothes" defect an earlier review named**, and this ADR should not acquire one.
3. **Does it leave the interim milestone with anything to be conformant about?** The follow-up commit
   corrects `f3a6a63` on this: `compaction_ai` calls `ctx.ports.ai_step` and appears in the extension
   order of **both** checked-in configurations, so no shipped configuration is conformance-eligible
   in the interim. The ADR's answer is that the first conformant profile is a purpose-built narrow
   one, citing D5's "pure guards and deterministic fixture hooks may form the initial profile."
   Verify both halves — the configuration fact, and whether that answer actually holds — and rule on
   whether the interim milestone is still worth sequencing first if it delivers no conformant shipped
   profile.
4. **Consistency with D5.** The ADR claims the exclusion follows from D5's own criterion rather than
   excepting it, because D5 admits an effectful hook only when world state is returned to the host
   and `ai_step` returns none. Check that reading against D5's actual text.

### A2. The `ProviderState` specification may create the problem it solves

D1 now requires a concrete `ProviderState` declared in `src/core/ports.ail`, and says `ScriptedStep`
must relocate there or below because the current type is unreachable from both consumers without a
module cycle.

- **Does the relocation itself typecheck?** `ports.ail` imports `std/ai`, `std/result`, `std/trace`,
  `pkg/sunholo/motoko_ext_abi/types`, and `src/core/phase_vocab`. Confirm `ScriptedStep`'s definition
  can live there without dragging in an importer of `ports` — the exact failure the relocation is
  meant to escape. If it cannot, the ADR has named an impossible home.
- **Is `ProviderState`'s shape specified enough to build?** It must be empty for `live_ports`/`Ported`
  and a script cursor for `Scripted`. Sum type, record with optional fields, or something else — the
  ADR does not say. Rule on whether that is an acceptable plan-level detail or a gap that will
  reproduce R2's "specified where it cannot exist" failure one layer down.
- The two prior reviews each built a three-module probe confirming the shape composes when the state
  type is concrete and below the consumers. Re-derive rather than inherit.

### A3. `profile-reachable` clause 3 — is "solely" decidable?

The definition gained: "in a **core code path guarded solely by an installed hook's identity**."

- Is "solely" a decidable predicate, or does it smuggle back the path analysis clauses 1–2 were
  written to avoid? Consider a core path guarded by hook identity *and* a config flag.
- `emit_dummy_hook` is the motivating case, with six call sites of the form
  `if is_test_dummy(h.id) then ...` (`src/core/ext/runtime.ail:206, 222, 239/245, 280/287, 368/374`).
  Confirm all six fit the clause, and look for any other core site the clause now captures or misses.
- The term now covers hooks as well as effect sites. Check the acceptance-table row *Is the tested
  boundary honest?* ("every profile-reachable hook") still reads correctly.

### A4. Obligation 2's classifier — derived, but is it derivable in a gate?

The classifier is now "the pinned toolchain's effect-bearing stdlib/builtin surface, as module plus
exported symbol", derived from `ailang builtins list --by-effect`, re-derived on every repin.

- Is that command's output stable and machine-parseable enough to be gate infrastructure? Is it
  present in CI?
- **Does "module plus exported symbol" actually work for builtins?** Builtins may not be
  module-scoped the way `std/clock (now)` is. If the surface is partly module-less, the classifier
  needs a second rule the ADR does not give.
- The pass justifies toolchain derivation by noting the two enumerations disagree — 18 builtin effect
  labels versus 12 in `ailang.toml`'s `[effects] max`. Re-verify both numbers and the claim that
  neither alone is a classifier.
- Target-module matching is claimed to cover aliased and qualified forms "by construction". Test it
  against `import std/clock as c` and any other form the pin accepts.

### A5. Anchors introduced or changed in this pass

All unverified by any reviewer. Re-run every one:

`src/core/session.ail:662`, `:654-666`, `:668-677`, `:695-701`; `packages/motoko-ext-abi/types.ail:63`;
`packages/motoko-ext-compaction-ai/compaction_ai.ail:106`;
`packages/motoko-ext-compose/compose.ail:756-771` and `:767`;
`src/core/test/scripted_ports.ail:20-24`, `:20-48`; `src/core/test/stub_step.ail:34`, `:192-199`;
`src/core/ext/runtime.ail:190` and its six guard sites; the `171-173` range in the *Known stale source
comment* note; and the extension orders in `.motoko/config/default/config.json` and
`.motoko/config/ailang/config.json`.

The stale-comment note has now been wrong twice — `170-171`, then `171-172`. It now says `171-173`.
Verify it a third time; a deferred source fix is only safe if its target is exact.

### A6. The Status block, fourth rewrite

Check for self-contradiction and for contradiction with the body. Check the "settled" list still
matches what the nine sections actually ruled, including the new claims about what the third-pass
delta reviews confirmed.

### A7. Collateral

The pass edited D1, D4, D5, Consequences, the Status block, the Context table, and Handoff item 2.

- Does the new *Consequences* bullet (the `ai_step` widening joining the ABI major) agree with D1's
  exclusion and with D5's world-token requirement?
- Does D4's clock arithmetic (4 / 12 / 13) survive the clause-3 addition?
- Does anything still describe item 2 as a complete cursor fix?

## Settled — do not reopen

- **F1, F2, F3, F5, F6**; the **narrowed D1 blocking clause**; the **upstream return-shape ruling**;
  **M2** — confirmed by all three F1–F6 verifications. **D6.1** by two of the three.
- **D4's count of 13** and **"nothing is routed at HEAD"** — re-derived by all four delta reviewers.
- **Second-pass corrections C3, C4, C5, C9, C14**; all configuration facts; the Status block's
  coherence at the third pass; every anchor confirmed by the third-pass reviews.
- **That the bidirectional shape composes at all** — two independent three-module probes typechecked
  clean on pinned v0.26.0. What was open is where the state type lives (A2), not whether it works.

## Leads already checked — do not re-derive

- `ExtPorts.clock_now` has **zero call sites repo-wide**.
- `ledger_record_name` names 3 of 34 `LedgerEvent` variants.
- No aliased `std/clock` imports at HEAD; zero `sleep(` sites in `src`, `packages`, `scripts`.
- `agents_md.walk_agents` performs `FS` undeclared and v0.26.0 accepts it.
- `scripts/dst/spike_scripted_cursor_probe.ail` exits 1 by design and is deliberately unwired.
- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors.** Clear every `.ailang/cache`
  before believing a type error that contradicts the source you are reading. Both third-pass
  reviewers ran their probes from scratch directories outside the repo; do the same.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`.

## Output contract

Append a **tenth** `## Review Comments` section to the ADR. There are nine. Count them yourself before
appending — a previous handoff said "third" and was executed three times.

Do not rewrite the body, and do not edit any existing review section. All nine are historical records,
including the two that overturned the authoring side's own diagnosis.

State your model id, the date, and the commit you reviewed at.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then, in this order:

1. **What is accurate** — name what you re-ran and confirmed. Three deserve an explicit ruling:
   whether the A1 exclusion is the right disposition **and enforceable**, whether `ProviderState`'s
   home and shape are buildable as specified (A2), and whether obligation 2's classifier is derivable
   in a gate (A4).
2. **Recommended pre-acceptance actions** — ordered by dependency, separating what this ADR must fix
   from what belongs to the implementation plan.
3. **Accept / revise recommendation** — one line, and say explicitly what happens to the upstream API
   blocker.

## Constraints

- **Findings only.** Do not modify source, scripts, the Makefile, the spike, other ADRs, or this
  ADR's body during review.
- **Do not re-litigate accepted 007**, and do not re-argue the decision to request an upstream API.
- **Verify by execution.** A claim you did not re-run is a claim you cannot certify.
- **Do not treat the fork prototype as the gate cleared.** D1 requires the recorded-stream API in a
  *release* with the toolchain repinned; `arniwesth/ailang`'s `stepWithStreamRecorded` on the
  `v0.31.0` tag is a prototype.
- **Do not treat the throwaway spike branch as HEAD state.**
- If the corrections hold, say so plainly and record residual risk. The likeliest surviving
  candidates, in order: A1's enforceability (an exclusion with no detector), A2's relocation target,
  and A4's classifier being underivable in practice.
