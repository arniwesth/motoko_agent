# Handoff: execute WI-A6, WI-A7, WI-A8 — three constructed artifacts with fail-closed validators

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

This is **cluster 3 of Milestone A**. Three clusters have landed (1, 4, 6); WI-A12 completed the
world-state migration and unblocked the critical path. **Read the plan's `## Standing rules` section
first — S1 binds every item here.**

Cluster 2 (A4 + A5 + A11, the Python detectors) is independently groundable and touches none of
these files. It can run in parallel with this one.

## Mission

Build three artifacts, each with a fail-closed validator, as **three separate commits**:

- **WI-A6** — coverage-floor and per-extension disclosure validation (D5).
- **WI-A7** — D3's fault catalogue.
- **WI-A8** — D6's event vocabulary, the fifth recorded axis.

They are grouped because they share a shape — a constructed, versioned artifact plus a validator
that fails closed — not because they share files. The plan is your specification; read WI-A6, WI-A7
and WI-A8 there, plus D3, D5 and D6 in the ADR.

**This cluster is on the critical path twice.** WI-A13 needs A7's stable class ids directly, and
WI-A10 needs A6, A7 and A8 before A13 can consume its manifest. A8 additionally gates A14: no D7
parity invariant depending on the logical/display-only classification may be scheduled before it
exists.

## The rule you will break by accident

**Three of D3's required fault classes already exist in the tree as bare string literals, and a
catalogue built from D3's prose alone will orphan them.**

WI-A12 landed the typed tool contract three commits ago and introduced, at
`src/core/tool_phase.ail:234`, `:238`, `:242`:

```
tool_fault_message(call, "ToolFailed",               …)
tool_fault_message(call, "ToolCorrelationMismatch",  …)
tool_fault_message(call, "ToolDeadlineExceeded",     …)
```

Those are exactly D3's three required **tool** classes — typed execution error, protocol-inconsistent
result, and completion after the declared deadline. They are stringly, unversioned, and reach the
model inside a `fault_class` JSON field. **A7 must adopt these as the catalogue's class ids or
migrate the call sites to the catalogue's ids in the same commit.** Inventing fresh ids beside them
leaves the tree with two vocabularies for one concept, which is the drift D3's "one catalogue is the
single source of truth" exists to prevent — and nothing would catch it, because both would
type-check and neither is currently validated.

Check for the same shape elsewhere before assuming three is all: `grep -rn 'fault_class' src packages`.

## Re-ground before you rely on anything

Re-measured at HEAD 2026-08-02 after cluster 6. **Run
`git diff --stat aa55aa0..HEAD -- src packages scripts Makefile` first; if non-empty, re-measure.**

Every count below was derived from a command run while writing this table, per the
handoff-generation rule — the commands are given so you can re-run them rather than trust me.

| Anchor | Now | Command |
|---|---|---|
| `LedgerEvent` variants | **34**, at `phase_vocab.ail:697` | `awk '/export type LedgerEvent/,/^$/' … \| grep -c '^  [\|=]'` |
| `ledger_record_name` | names **9** cases, collapses the rest to `"wire"` at `:615` | `awk '/func ledger_record_name/,/^}/' … \| grep -c '=> "'` |
| `StreamDelta`'s two wire names | `reasoning_delta` / `thinking_delta`, selected from `i.kind` | see plan WI-A8 |
| Existing goldens | **37** `golden(` assertions in `phase_vocab.ail` | `grep -c '&& golden('` |
| `TerminationReason` (A9, do not rebuild) | 8 variants at `phase_vocab.ail:541-549` | — |
| Fault-class string literals (see above) | **3**, `tool_phase.ail:234/238/242` | `grep -rn 'fault_class' src` |
| ABI hook slots | **8**, closed record | `packages/motoko-ext-abi/types.ail` |
| Unconditional hook dispatch | folds over `rt.registry.hooks` at `ext/runtime.ail:213, 229, 275, 319, 363, 414` | `grep -n 'rt.registry.hooks'` |
| The one gated hook | `on_tool_handle`, via `contains_tool` at `ext/runtime.ail:337` | same |

Note `ledger_record_name` names **9**, not the 3 the plan's survey recorded — it grew. It is still
not a partial implementation of the vocabulary and is not to be grown into one (D6); the number is
given so you do not treat a changed count as a discovery.

## Definition of done, per commit

**S1 applies to all three: write the validator, and a fixture that fails it, before the artifact is
complete.** Three clusters have produced ten sites where both alternatives type-check and the wrong
one is silent. For constructed artifacts the equivalent failure is an artifact that validates while
being incomplete — so each item's acceptance below names a *set-completeness* fixture, not only a
row-shape one.

**A6 green.** Profile load rejects: an installed extension with zero covered hooks; an installed
extension with an unconditionally-dispatched hook excluded; covered/excluded sets that are not
disjoint or do not exhaust all eight slots. Hook **ids**, not counts, in definition and result. A
fixture profile of each rejecting shape is in a CI-invoked target, and `driver_only`'s empty install
list passes vacuously.

**A7 green.** The catalogue is versioned and machine-readable; the validator fails closed on a row
missing any field or naming an unknown constructor, **and on a catalogue missing any required D3
class id** — an empty catalogue must fail. The two conditional classes carry their waiving
conditions. The three existing `fault_class` literals are reconciled per above. This item also
**owns two decisions the plan assigned it**: the max-steps discrimination that currently rests on
matching the literal string `"v2 loop: step budget exhausted"` (`session.ail:1357`, same `Internal`
code as the approval failure — fixing it changes a caller-visible `AIError` code, which is why A9
declined it), and the uncovered "extension calls `ai_step` against a `Scripted` provider" case.

**A8 green.** All 34 variants carry variant, wire name, payload schema, and logical/display-only
classification; load validation fails closed on an unclassified variant; **every one of the 34, and
both `StreamDelta` branches, round-trips to the wire name the current projection produces.** The
schema is `wire name = f(variant, payload)` — settled in the plan, do not re-litigate it. The 37
existing goldens make the round-trip cheap; use them rather than writing new fixtures.

## Out of scope — actively do not do these

- **The profile definition and manifest** — A10's, and it consumes all three of these.
- **Anything reading the catalogue's counters** — A11 and A14. A7 defines ids; it does not count.
- **Classifier 2, the attribution table, the predicate check** — cluster 2, running in parallel.
- **Any D7 parity invariant** — A14's, and it is precisely what A8's existence unblocks. Build the
  vocabulary; do not build the invariant that will consume it.
- **`driver_only`'s routed-set claim.** True since A12 routed the four driver clock sites, still not
  recordable — it needs cluster 2's attribution table (D4's scheduling prohibition). Leave it to A10.

## Stop and report rather than deciding inline

- If reconciling the three `fault_class` literals requires a **wire-visible** change to what reaches
  the model, stop. That is a compatibility decision the plan owns — the same call A9 correctly
  declined for the `AIError` code.
- If a `LedgerEvent` variant cannot be classified logical-or-display-only without deciding what a
  D7 invariant should do with it, stop and report the variant. D6 says the classification is the
  artifact's job, but a variant that genuinely resists it is a finding about D6, not a judgement call.
- If any required D3 class has no reachable production branch to map to, say so. D3 requires a
  *named recovery-branch id* per class, and a class with nowhere to point is a coverage gap worth
  more than a placeholder.

## Traps

Clear `.ailang/cache` before believing a contradicting type error. **Rebuild the parallel
`ailang check` closure tool before editing** — three clusters have reported it is what keeps site
convergence linear (12 s / 2.6 s / 4.7 s over ~19–22 modules). Never probe from `/tmp`. `make dst`
and CI both use `--keep-going`; read exit status, not the last line.
`scripts/dst/probe_phase_vocab_sealed.ail` fails at baseline (`IMP010`, pre-existing, in no target —
WI-A17 owns it); do not chase it. **`terminal_trace`'s structural guard is a `grep -c '{ result:'`
over `session.ail` that counts comment lines** (cluster 6, C5) — if you write that pattern in prose
in that file, you will turn the gate red for no reason.

## Report back

Fourth calibration run, and **the first on new-artifact work.** The sites-not-files model has three
confirmations, but all three were widen-a-type-and-converge; the plan explicitly states the rate is
**not** assumed to transfer here. This run is what tells us whether A13, A14 and B2 can be sized
against it — which is the entire remaining schedule question.

- **Time and sites per artifact**, and say plainly whether the widen-and-converge rate transferred.
  If new-artifact work is materially slower per site, that is the single most useful thing this run
  can produce.
- **Judgement ratio** against the corrected predictor: the band is set by *whether the change
  introduces a value that did not previously exist*. All three of these introduce new values, so
  expect the high band — if it comes in low, the predictor needs revisiting.
- **Whether any site admitted two type-checking answers with a silent wrong one**, and what caught
  it. For this cluster the likely shape is an artifact that validates while incomplete, so report
  what your set-completeness fixtures caught that row-shape checks did not.
- Anything the plan got wrong, as a plan correction.
