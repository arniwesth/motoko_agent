# Handoff: WI-D25 — the successor audits: `on_pre_step` and `on_solver_candidate`

Audience: a fresh session grounded against HEAD. **Item 1 of the goal line's remaining critical
path.** S29 requires a slot's driver arms audited before the slot is routed, the base rate on
audited slots is 2 drops of 2, and the demonstration (critical-path item 3) is the first run in
this project's history where hooks PERFORM — which is exactly when a dropped successor stops being
invisible and starts silently swallowing the evidence the demonstration exists to produce.

**Read first:** S29 in the plan (both halves — write side and read side), S34 (any fold you touch
stamps and clears by key-set), and the goal-line scope rule.

## The measured state at HEAD, and it is NOT what the base rate predicts

This handoff started the audit and the picture inverted: **both slots are mostly threaded
already.** The item's job is to finish the audit to evidence, not to hunt for the 2-of-2 drop. Every
row below was measured this session; re-derive per S22.

**`on_solver_candidate` — one production call site, and all three arms thread.**
`dispatch_solver_candidate` is called from production exactly once, `session.ail:2800`, and D19
already re-seated the write side (`{ post_ctx | world: intercepted.next_state }`). `FinalizeDecision`
has three variants (`types.ail:604-608`), and every arm binds `finalized.next_state`:
`Accept` → `c2_after_dp7(… token_to_world(finalized.next_state) …)` (`:2803`),
`ContinueWithFeedback` → the loop state's `world_state` (`:2814`), `NoDecision` → `c2_after_dp7`
(`:2863`, D19-tagged). The remaining audit work is the read side of each arm and anything between
the dispatch and the first `token_to_world`.

**`on_pre_step` — one production call site, threaded on the happy path, and the drop is a
DOCUMENTED deferral whose scope finally arrives.** `dispatch_pre_step_chain` is called once
(`session.ail:2537`); `chain.next_state` feeds `dispatch_step` at `:2581` (B2b). But the two
seal-terminal branches — `SealSystemPromptEmpty` and `SealExhausted` — pass **`st.world_state`** to
`c2_finalize` while `chain.next_state` exists, and the comment at `:2522-2530` says so in so many
words: *"They still ignore `chain.next_state`, the pre-step chain's successor, which remains a
separate un-threaded seam and is out of this item's scope."* Written at WI-D4. **This is the item
whose scope it is.** Thread both arms (the recommended shape: swap the argument in place —
line-count-neutral is achievable and D19 proved it matters for the cascade) and re-tense the
comment two-part per S15; or, if measurement turns up a reason the D4-era ground still binds, keep
the deferral and re-date its ground. Do not leave the 2026 tree citing a 2026-08-02 scope decision
as if it were a reason.

**Record the base-rate honestly in the report.** If the seal-terminal drop is the only finding,
S29's record becomes: two slots audited late with two drops found (D19/D20), two slots audited here
with one documented deferral and no unknown drop — largely because D19's intercept work already
threaded the solver path in passing. That is evidence the standing rules changed behaviour, and it
belongs in the plan.

## The capability bounds — compile-witnessed, and one corrects WI-D24

The disclosure table (goal-line clause 2) needs each slot's reachable surface stated with a
measured reason. The effect checker answers this totally (the plan's own underused-producer rule),
and the row algebra was derived this session:

- **`on_pre_step` declares `! {AI, IO, Trace}`** (`types.ail:882`). Exactly **one** `ExtPorts`
  field is callable under it: `ai_step`, whose row is identical (`:293`). Every other field needs
  `FS`, `Env`, `Clock`, or `Process`.
- **`on_solver_candidate` declares `! {Process}`** (`types.ail:956-957`). **Zero** `ExtPorts`
  fields are callable under it — even `proc_exec` needs `{IO, Process, FS}` — **so WI-D24 §12.2's
  "on_solver_candidate CAN reach the seam" is FALSE as written, and the plan's D24 milestone entry
  repeats it.** The truth: the row *contains* `Process` but cannot call the mediated seam; the only
  subprocess this slot can perform is **ambient** `std/process.exec`. That is S33's shape in this
  reviewing role — "can" was inferred from the presence of an effect, not from row inclusion — and
  the plan text is corrected in the same commit as this handoff.

**Make both bounds executable, not prose**: a probe binding per slot that the compiler REJECTS
(pre-step calling `clock_now`; solver calling `proc_exec`) beside one it ACCEPTS (pre-step calling
`ai_step`; solver calling ambient `exec`). `declared_vs_performed` already houses this style of
evidence; the item picks the home. These four verdicts are disclosure-table rows and the audit's
most durable output.

## The witnesses, sized to what each slot can observably do

**Pre-step: constructible, and it is the fixture that makes the seal-terminal drop observable for
the first time.** `ai_step` threads the provider seam (`session.ail:880-884` →
`ext_ai_step(p, w0, …)`), so a pre-step hook that calls it against a scripted world **consumes a
scripted provider step** — an observable world advance. The witness: a graded scenario (D19's
pattern) with a performing pre-step hook and a run driven into a `Seal*` terminal; assert the
terminal world accounts for the hook's consumption. Under the drop (the mutant: revert the two
`c2_finalize` arguments) the consumed step "un-happens" in the terminal world — the row goes red.
Use an ext id that is not compose's (S33), and keep every count distinct (S7).

**Solver: NOT constructible at current rows, and the honest move is the narrowed label.** With zero
reachable ports, a solver hook cannot change world content; a threading witness would need a
fabricated token, and a fabricated token dies at the next `token_to_world` (S34's total-decoder
fact — this is the same wall, met from the other side). **Do not build a row that passes either
way** (S33). Assert the solver path by enumeration — the three arms, source-anchored — and name the
gap at the site: the threading claim for this slot is verified by reading, not by fixture, until
some future row widening gives the slot a port. D20 §8.2 is the precedent and the wording to reuse.

## S34 compliance, inherited

All four folds stamp and clear the holder (D24). The audit re-verifies the two folds it reads and
does not add new ones. Any fold this item does touch: `stamp_holder`/`clear_holder`, never a world
round trip.

## Counters, in advance

The seal-terminal drop is **disclosed at its site by an item that deferred it on stated scope** —
it is a documented deferral, not a production site where the wrong answer ships silently (no
performing pre-step hook exists in production at HEAD, and the drop is named in a comment). The
default is: **no new silent-wrong count.** If the item finds an UNdocumented drop anywhere in the
two paths, that is a count. Instrument-weaker: the solver slot's narrowed label exists precisely to
avoid becoming instance 8 — a fixture-less claim labeled as fixture-backed would be one.

## Cascade

Threading the two seal arms in place is line-count-neutral (argument swap); the comment re-tense is
not. Edits in the `:2520-2560` region sit above the `:2921`/`:3031` anchors, so any net line change
re-baselines the five `session.ail` anchors — the **six-file** form (`anchors.sh`, attribution
table + its dst, both profiles → **22 / 9**). `ext/runtime.ail` and `tool_phase.ail` should not be
touched at their anchor lines; if either moves, the law says **nine** (fixture-carried anchors —
D24's correction). S18: re-tense before computing anchors.

## Definition of done

1. Both slots audited to evidence: every arm of both consumers enumerated with thread/drop verdict
   and source anchor; read side checked per S29's second half.
2. The seal-terminal seam resolved — threaded (with the D4 comment re-tensed two-part) or
   re-grounded, not left citing scope as a reason.
3. The pre-step witness exists and goes red under the revert-mutant; restore by file copy (S17).
4. The four capability probes exist as compiler verdicts, wherever they live.
5. Green: `world_state`, `discovery`, `execution_program`, `program_persistence`,
   `declared_vs_performed`, `conformance`, `anchors`, `predicate_anchors`, `attribution_table`;
   profiles re-issued if the cascade fires; yields and inventory asserted unmoved (4/15, 5/15,
   compose 11/32 — this item routes nothing).
6. `make sync_packages` only if `types.ail` is touched — it should not be; the probes live outside
   the ABI package.

## Out of scope, per the goal-line rule

- **Widening either slot's declared row** — that is the barrier question (D7's three barriers
  stand; moving one is an ABI event and is not on the critical path).
- Routing (item 2), the C5 profile (item 3).
- The `ai_step` seam's own ambient/recording status — read it, cite it, do not change it.
- `RandomDraw`'s adapter; everything in the maintenance register.

## Stop and report rather than deciding inline

- If threading the seal arms changes any gate's recorded hash or program bytes beyond the profiles
  the cascade re-issues — that would mean the drop was load-bearing somewhere, which is a finding,
  not a fix-in-passing.
- If the capability derivation is wrong — a probe compiling where this handoff says it must not
  (or vice versa) — stop; the disclosure table depends on these four verdicts and a wrong one
  poisons clause 2.
- If a third production call site of either dispatch turns up that this handoff's census missed.

## Report back

`NOTE-d25-…` in the established form: the arm-by-arm table with verdicts and anchors; what the
seal-terminal resolution was and why; the witness's numbers and its mutant; the four compiler
verdicts verbatim; the honest base-rate statement for S29's record; the cascade cost; and what item
2 (routing) inherits — in particular whether anything in these two paths constrains where compose's
routed `exec` calls may land.
