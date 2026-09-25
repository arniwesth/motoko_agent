# Handoff: delta review of the fifth correction pass to ADR-001-deterministic-test-world-architecture.md

Audience: a fresh agent session with no context from the correcting session. The corrections you are
reviewing were written by the authoring side in response to two delta reviews. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

**Narrow delta review.** The ADR carries eleven `## Review Comments` sections: two full reviews
(2026-07-26), three verifications of the F1–F6 revision, and four delta reviews of correction passes
two through four (all 2026-08-01). The architecture is settled and has been re-derived by every round.
Your target is one commit.

## Mission

Verify the **fifth correction pass**, which answers all eight findings from the two delta reviews
recorded as the ADR's tenth and eleventh sections.

## Target range

```text
b042757  the two fourth-pass delta reviews (verbatim, committed before any response)  <-- BASELINE
e8242f1  fifth correction pass
```

```text
$ git diff b042757..e8242f1 -- .agent/projects/009_motoko_dst_execution/
```

One commit, exhaustive, no hand-maintained edit table. An untracked `mmd/` directory (Mermaid
diagrams and SVGs) appeared during the previous round; it is **not** part of this target and was not
authored by the correcting session.

## The one thing that is not either reviewer's recommendation

**A1 is an adjudication that departs from both reviews.** They framed the R2 contract question as a
binary: either restate "not conformance-eligible" as a coverage claim, *or* add a profile-definition
rejection category to D5. The pass took **both**, split along a line neither drew. That split is the
least-supported text in the range and is where you should start.

## Attack list

### A1. The coverage-versus-rejection split — is the line in the right place, and does the rule it states have a detector?

D1 and D5 now say:

- installing an `ai_step`-calling extension **and excluding every hook that reaches the port** is
  conformant, uncovered, and inert on that path — D5's existing machinery, unchanged;
- installing one **without** excluding those hooks is a **profile-definition rejection**.

The stated reason is timing: an excluded hook fails closed when dispatch reaches it, while an
un-excluded reaching hook runs successfully and silently discards world state, so only one is
detectable at run time.

Four axes:

1. **Is the timing argument sound?** Verify both halves against D5's actual machinery and against
   what a run would do in each case.
2. **"Every hook that *can reach* the port" may reintroduce the trap clause 3 was just fixed to
   avoid.** This is the sharpest sub-item and the authoring side flags it rather than having resolved
   it. "Can reach" is a call-graph property. Classifier 2 (below) inventories *field-reference sites*,
   which is textual — but mapping a reference site to the hooks that can reach it is exactly the
   reachability question D5 obligation 3 declines to require and nothing builds. The fourth-pass
   review established `compaction_ai`'s single reaching hook by following
   `register.ail:103-105` → `compact_with_ai` → `summarize_with_ai_result` →
   `compaction_ai.ail:106` — a manual call-chain walk, not a mechanical rule. **Clause 3 solved the
   structurally identical problem with a versioned site-to-hook attribution table.** Rule on whether
   the same instrument should govern classifier 2, or whether something else does.
3. **Is "conformant and inert" a conformance claim worth having?** A profile that excludes the only
   hook giving an extension its function passes D5's honesty test while testing nothing on that path.
   Argue whether that is correct bookkeeping or a laundering of coverage machinery, and whether the
   ADR should say more about it.
4. **Consistency.** The split is now asserted in D1, in D5's exclusion paragraph, in D5's validation
   bullet, and in the acceptance table's *Is the tested boundary honest?* row. Check all four say the
   same thing.

### A2. Classifier 2's scope and retirement rule

Obligation 2 gained a second classifier: the `ExtPorts` fields "that do not yet return world state —
today `ai_step`", re-derived on the repin trigger and "retired field by field as the world-token ABI
lands."

- **Is `ai_step` really the only member of that set today?** `ExtPorts` also carries `proc_exec`,
  `clock_now`, and `env_get` (`packages/motoko-ext-abi/types.ail:62-67`), none of which returns world
  state either. If the set is defined by "does not return world state", it is all four; if it is
  defined by "discards state that D1 requires to be threaded", it may be one. The ADR says the former
  and means the latter. Rule on which is right and whether the text needs to say it.
- **Is "retired field by field" coherent?** The world-token ABI is a single ABI-major change. If
  fields cannot in practice be retired individually, the sentence is decorative.
- Classifier 2's soundness boundary is stated by reference to classifier 1's. Check that the
  inherited boundary actually applies to an ABI-field scan.

### A3. Clause 3's attribution table is a new required artifact with no owner

Clause 3 now reads: a core effect site is profile-reachable when it is "attributed to an installed
hook by the profile's versioned site-to-hook attribution table", with un-attributed sites failing
closed into clause 1.

- **Who authors the table, when is it validated, and what makes an attribution correct?** The ADR
  introduces the artifact and its fail-closed default but names no producer and no validator. The
  event-vocabulary artifact (D6) got a fail-closed validator and a scheduling prohibition; this one
  has neither.
- **Is failing closed into clause 1 always conservative?** Clause 1 means "unconditional core site",
  which forces routing. Confirm there is no case where that is the *wrong* answer rather than merely
  the expensive one.
- Verify the motivating case is stated correctly: five `is_test_dummy` guard sites at
  `src/core/ext/runtime.ail:206, 222, 245, 287, 374`, and the mixed-guard counterexample at
  `src/core/tool_phase.ail:222`.

### A4. Classifier 1's corrected derivation

Both fourth-pass reviews prescribed this fix and the pass applied it: filter
`ailang builtins list -json` on `is_pure == false`, project `module`, filter `Pure` explicitly,
seventeen effect labels plus `Pure`.

- Re-derive rather than inherit. Confirm the module set is what a routing inventory needs, and that
  no effect-bearing row lacks a `std/*` module once `Pure` is dropped.
- Confirm the corrected label arithmetic and the `ailang.toml` `[effects] max` count of twelve.

### A5. Anchors introduced or changed in this pass

All unverified by any reviewer:

`packages/motoko-ext-abi/types.ail:62-67`; `src/core/tool_phase.ail:222`;
`src/core/ext/runtime.ail:206, 222, 245, 287, 374`;
`packages/motoko-ext-compose/compose.ail:767` and the enclosing `on_response_intercept` at `:761-771`;
`packages/motoko-ext-compaction-ai/compaction_ai.ail:106`; and the claim that **all fourteen**
checked-in `.motoko/config/*/config.json` install `compaction_ai`.

This document has shipped anchor errors in four consecutive passes, including twice in the note whose
entire purpose is to record an exact deferred-edit range. Assume a fifth.

### A6. The Status block, fifth rewrite — including a corrected metric that is partly inherited

The "spent none" process claim was false and is now restated as "two of twelve, both on the same
deferred `stub_step.ail` comment range", with a narrower provenance-only comparison given as "one of
fifteen against none".

- **That provenance-only arithmetic was taken from the tenth section's suggested wording and not
  independently recounted by the authoring side.** Verify both numbers yourself.
- Check the Status block for self-contradiction and against the body, as every round has. The header
  now claims four delta reviews; confirm that is right and that nothing else in the block still
  counts an earlier round.

### A7. Collateral

The pass edited D1, D4, D5, the acceptance table, Consequences, and the Status block.

- Does the coverage/rejection split contradict D11's coverage counters or D5's profile-definition
  record (which lists "included extension ids and per-hook classifications")?
- Does anything still describe an `ai_step`-calling profile as disqualified rather than uncovered?
- Does D4's clock arithmetic (4 / 12 / 13) survive the clause-3 rewrite?

## Settled — do not reopen

- **F1, F2, F3, F5, F6**; the **narrowed D1 blocking clause**; the **upstream return-shape ruling**;
  **M2** — all three F1–F6 verifications. **D6.1** — two of the three.
- **D4's count of 13** and **"nothing is routed at HEAD"** — re-derived by all four delta reviewers.
- **The extension-model-path exclusion is the right disposition** — both fourth-pass reviews ruled on
  it explicitly, against D5's coverage criterion. What was open is what it *costs* (A1), not whether
  to do it.
- **`ProviderState`'s home in `src/core/ports.ail` is buildable** — two independent three-module
  probes typechecked clean on pinned v0.26.0, and `ScriptedStep`'s only non-primitive dependency is
  `ToolCall` from `std/ai`, which `ports.ail` already imports.
- Second-pass corrections **C3, C4, C5, C9, C14**; all configuration facts; every anchor confirmed by
  a prior round.

## Leads already checked — do not re-derive

- `ExtPorts.clock_now` has **zero call sites repo-wide**.
- `ledger_record_name` names 3 of 34 `LedgerEvent` variants.
- `ailang builtins list -json` exists on the pin, exits 0, is byte-deterministic across runs, and
  emits `{name, module, signature, is_pure, effect, num_args, description}`. Its `name` is the
  *internal* builtin (`_clock_now`), never the exported wrapper.
- All three import forms typecheck on the pin: `import std/clock (now)`, `import std/clock as c`, and
  `import std/clock as c (now)`.
- `agents_md.walk_agents` performs `FS` undeclared and v0.26.0 accepts it.
- Neither classifier is wired into CI, the Makefile, or `scripts/` today.
- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors.** Every prior round's probes were
  built in scratch directories outside the repository; do the same.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`.

## Output contract

Append a **twelfth** `## Review Comments` section to the ADR. There are eleven. Count them yourself
before appending — a previous handoff said "third" and was executed three times.

Do not rewrite the body, and do not edit any existing review section. All eleven are historical
records, including the two that overturned the authoring side's own diagnosis and the two that
overturned its conformance claim.

State your model id, the date, and the commit you reviewed at.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then, in this order:

1. **What is accurate** — name what you re-ran and confirmed. Three deserve an explicit ruling:
   whether the coverage/rejection line is in the right place **and has a detector** (A1), whether
   classifier 2's scope is correctly bounded (A2), and whether clause 3's attribution table is
   specified enough to be an artifact rather than an intention (A3).
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
  candidates, in order: A1's "can reach" needing the same attribution instrument clause 3 just got,
  A3's table having no producer or validator, and A2's field set being larger than the one field the
  ADR names.
