# WI-D2 — the parity register. **ROW 7 CLOSES. The register is TWO, not three.**

Twenty-sixth calibration run, and the second item of C4's post-gate work list. Written against HEAD
`7acdbf2`, branch `arniwesth/mot-65-close-d64_gap_register`.

## Window

**~46 minutes** wall-clock: `2026-08-05T16:44Z` → `2026-08-05T17:30Z`. Grounding was clean: `git
status` clean at `7acdbf2`, and the handoff's branch name matches the branch — second item running.

## THE ANSWER

**`d64_gap_register` goes 13 → 2, and acceptance row 7 is GREEN on all three conjuncts.**

The handoff's target was 13 → 3. It is **two**, because one of the three variants it reserved as
"gated elsewhere" is not gated at all — see the finding below.

**The reading row 7 was closed on, stated because it is the whole question:** *emissions that OCCUR
reach the trace.* Every Logical variant any run in this tree emits is appended to the returned trace,
and that claim is now checked out of process, per variant, by comparing what the driver PROJECTED
against what it APPENDED. The two survivors are **coverage** gaps, not parity gaps: no run in this
tree emits them at all, measured rather than argued, and if one did it would reach the trace — their
emission sites are inside the log the driver now appends. **A variant no run emits cannot fail to
appear.**

| | before | after |
|---|---|---|
| `d64_gap_register()` | 13 | **2** (`ScratchpadResult`, `SessionSuspend`) |
| Logical variants reaching the returned trace | 15 of 28 | **26 of 28** |
| Variants compared wire-against-trace | 1 (`StreamDelta`) | **17**, all eleven closed ones among them |

## THE FINDING: `ExtToolHandled` was never gated, and it had been emitted 47 times a run

The handoff reserved three variants and named the gate for two of them: *"`ScratchpadResult` and
`ExtToolHandled` need an installed extension (the `on_budget_plan` ABI change)."*

**`ExtToolHandled` needs neither.** It is emitted whenever `dispatch_tool_handle` returns `Handled`,
which any hook can do — no install, no ABI change, and no scratchpad. **MEASURED: 47
`ext_tool_handled` lines on the wire across one `make dst` run at HEAD, before this item wrote
anything**, produced by `scripts/dst/long_qwen_compaction_dst.ail`, which had been doing it since
long before WI-D2.

It was found by looking for the *survivors'* measurements rather than by working the closures: I ran
`make dst`, counted the three reserved wire names to write their reasons as measurements per S15, and
one of the three came back 47 instead of 0. **The reason I was about to write was the thing that
disproved it.** A register entry stating a structural gate, checked against a number, on the one item
that had to produce the number anyway.

`ExtToolHandled` is therefore closed and **witnessed** — `make ledger_parity` runs a `handled` subject
whose hook returns `Handled`, so the closure is observed by the gate rather than inherited from
another target's output.

## The shape the item was told to expect, and it held exactly

**The tool-dispatch fold was WI-A1's loss channel, second instance**, and the precedent was the
design. `tool_phase.ail` had zero references to `LedgerTrace` and took a multi-fire `emit` callback
returning `()`, while `ToolDispatchOutcome` returned the messages and the world and nothing about what
had been emitted.

| Step | Precedent | Here |
|---|---|---|
| Widen the return channel | **A1** | `ToolDispatchOutcome` gained `emitted: [LedgerEvent]` on both variants; `execute_allowed_tool_call` likewise |
| Fill it | **C1** | the fold threads `emitted` exactly as it threads `accumulated` |
| Give it a reader | **C3** | the driver appends with `c2_trace_wire_events` — **a second caller, not a mechanism** |

**No `LedgerTrace` was threaded into `tool_phase`, and the temptation was real**: `ledger_append` is
in `phase_vocab`, which that module already imports, so the second-appender version type-checks in one
line. The driver remains the sole appender.

`ThinkingStreamEnd` was one line. `CostExhausted` took `DoneEvent`'s treatment exactly — appended
before `c2_finalize`, so D6.1's final-record rule holds. `Dp7VerifierRejected` needed its own small
widening (`dp7_rejection_errors` returned the text and dropped the event it had just projected) and is
unconstrained by D6.1 because the re-injection path is not terminal.

## Mutation results — six, and TWO of them are the item's argument

Restored by `cp` throughout (S17); every file verified byte-identical after each.

| # | Mutant | Result |
|---|---|---|
| M1 | the fold's `Deny` arm forgets to extend `emitted` | RED — `NativeToolDenied: projected 3, returned 1` |
| M2 | the driver drops `done.emitted` at the `Done` arm | RED — two variants at `projected 1, returned 0`, plus the order row |
| M3 | **the block lands in the WRONG POSITION, every count unchanged** | **all 18 count rows GREEN; only the order pin red** |
| M4 | `CostExhausted` appended AFTER `c2_finalize` | RED on the order pin and on the D6.1 row — **`make invariants` stays GREEN** |
| M5 | **register and survey both say closed; the driver appends nothing** | **`make event_vocabulary` and `make invariants` COMPLETELY GREEN; wire gate `projected 16, returned 0`** |
| M6 | the required set becomes unreadable | RED, fail-closed, "FAIL (vacuous)" |

**M5 is the item's central result and it is S16's shape, one level up from C3's.** The two in-process
pins that this project built to make the register honest — `parity_register_findings` in both
directions, and the pinned literal beside the vocabulary — **both compare the register against
`reaches_trace_today`, which is a hand-maintained SURVEY**. Flip the survey and the register together
and they agree with each other about a claim neither of them checks. With the driver appending nothing
at all, every in-process row is green and the wire reads 16 against 0. **The register's two-sided pin
is not a check that the append exists; it is a check that two claims match.**

**M3 is the failure the handoff predicted, reproduced deliberately and caught.** *"A tool-event log
appended as a block in the wrong position passes a count check and fails order."* It does: eighteen
count rows green. It is caught only because the gate carries a pinned order sequence alongside the
counts — added **after** M3 was written, because the first version of the gate compared counts alone
and would have shipped over it.

**M4 is the reason row 7's first conjunct is now checked on real runs.** `terminal_summary_findings`
states D6.1 correctly and `invariants_dst` exercises it hard — over a **constructed fixture**. An
append landing after the finalizer is invisible to it. Every append this item added is on a path where
that is one expression away, so `ledger_parity_dst` now asserts, over each of its eight runs, that
there is exactly one `RunSummary` and it is the final wire record.

## What the in-process check establishes and what it does not (S16)

**The wire comparison WAS extended**, and it is a new gate rather than a widening of C3's:
`make ledger_parity` → `scripts/dst/run_ledger_parity_wire.sh` + `scripts/dst/ledger_parity_dst.ail`.

- **In process** (`ledger_parity_dst`): that the returned trace HOLDS each variant, that D6.1 holds on
  each run, and that the append ORDER is the pinned sequence. It cannot compare the two channels —
  the driver builds one event value, hands it to `ledger_emit`, and appends the same value, so both
  sides of any in-process comparison derive from one expression.
- **Out of process** (the shell): for every Logical variant `d64_gap_register()` does not excuse, the
  count `ledger_emit` wrote to stdout against the count `ledger_append` put in the returned trace.
  **17 variants compared, every one equal.**

**THE COUPLING IS THE POINT AND IT IS NEW.** The required set is `event_vocabulary()` minus
`d64_gap_register()`, read out of the run rather than restated in the shell. **Removing a name from
the register is what makes the gate demand its append.** A register shrunk without the production
change is red there — which is precisely what M5 shows the two in-process pins cannot see.

**Nine required variants are NOT witnessed by this fixture and are printed by name rather than counted
as passes**, because a variant at zero on both channels is a *coverage* claim and conflating it with a
parity pass is how a green family comes to mean nothing. They need compaction, hybrid tools,
checkpoints, a solver hook, a response intercept or a persist budget.

## Row 7, re-answered against the ADR's text

**"Is the oracle complete?" — PASS.** All three conjuncts, and the two that already held were
re-checked because appending on terminal paths is exactly where they break.

1. **Exactly one final `RunSummary` per terminal path.** `terminal-summary` family green with its
   three discriminating mutants; `✓ all terminal returns route through c2_finalize`. **And now also
   asserted over eight real runs** including the cost-capped one, which the fixture could not reach.
2. **All D7 invariants pass.** `✓ the fixture satisfies all twelve families`, `✓ all 12 families
   reached`, `invariants_dst PASS`. D6.3's agreement family reports nothing on any subject.
3. **All logical ledger emissions appear in the returned trace.** The register is 2, both entries
   carry a measured reason, and 17 variants agree wire-against-trace.

**Nothing was closed by narrowing.** No variant was reclassified `DisplayOnly` — the pinned baseline is
still the same six, and a new row asserts by name that all eleven WI-D2 closed are still classified
Logical, so "it left the gap" cannot be satisfied by "it was dissolved". No profile claim was
weakened; `driver_only`'s coverage claim is unchanged.

## Stale reasons and prose: SEVEN sites, and the discriminator held again

The handoff named none of these; they were found by grepping for the claims the change falsifies.

| # | Site | Claim that expired |
|---|---|---|
| 1 | `dst_event_vocabulary.ail` header | "14 of the 34 reach the returned trace" — **stale since WI-C3**, a fourth instance of C4's stale-count class |
| 2 | `dst_invariants.ail` header | the register "is now THIRTEEN" |
| 3 | `dst_invariants.parity_gap_reasons` | **eleven of thirteen entries**, nine already obsolete or wrong |
| 4 | `corpus_pr_dst.ail` | "`NativeToolDenied` and `NativeToolResults` … do not reach the returned trace" |
| 5 | `invariants_dst.ail` | "`CostExhausted` … the driver does not append it today" |
| 6 | `world_state_probe.ail` | "`NativeToolDenied` is `ledger_emit`-only" |
| 7 | `discovery_dst.ail` + `dst_discovery.ail` | "it goes to the wire and is never appended to the returned trace" |

**Four of the seven are the same shape and it is worth naming: the REASON expired and the CONCLUSION
did not.** Sites 4, 6 and 7 all justified reading the wire instead of the trace on the grounds that
the trace did not carry the event. That ground is gone; the conclusion is unchanged and now rests
where it always belonged — **the wire has a different AUTHOR**, and a witness read from the returned
trace would be produced by the same process as the census it is compared against. All four are
restated in two parts rather than re-dated, so the next item can see which half is load-bearing.

**S15's discriminator held a second time.** Of `parity_gap_reasons`' thirteen entries, the eleven that
named a STRUCTURAL cause were the ones that went wrong — seven said "inside the tool dispatch fold" as
though the fold were the obstacle when the obstacle was the fold's RETURN TYPE, and one asserted
`ExtToolHandled` was unreachable while `make dst` emitted it 47 times a run. **Both surviving entries
now quote a count and name the run it came from.**

## Sites where two answers type-checked and one was silently wrong

**This item wrote production code and authored none.** Every alternative that type-checked was caught
by a gate landed before the change (S1) — the wire gate was built first and was red on exactly the ten
target variants before a line of production code moved.

**Deliberately hunted, per the handoff, and one was found — in the instrument rather than in the
tree.** The first version of `run_ledger_parity_wire.sh` compared per-variant COUNTS and nothing else.
That type-checks, passes, and is green over a log appended in the wrong position — M3, which the
handoff predicted by name. It was caught by writing the mutant the handoff described and watching all
eighteen rows go green. **The counter is 53**, from D1's 52, attributed to WI-D2 and to this item's own
gate rather than to production code, because that is where it was. **Determinism has still caught none
of the fifty-three.**

Worth recording separately: **the two register pins are a fifty-fourth candidate that this item
declined to count**, because they are not wrong — they check what they claim to check. They are
merely insufficient, and M5 is what makes the difference visible.

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243.** Failing set
  **byte-identical to the pre-change baseline taken at the top of this item**: 7 `TC_ARITY_001` smoke
  scripts, the sealed-vocabulary probe, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage
  fixture. Stable across B4, C1, C3, C5, C4, D1 and now D2. 243 rather than 242 because this item adds
  one file.
- **`make dst` — EXIT 2, with the SAME TWO red targets as B4, C1, C3, C4, C5 and D1:** `test_coverage`
  and `test_coverage_selftest`, both pre-existing. Every other target passes. **831 ✓ rows** against
  D1's 809.
- **`make ledger_parity` — PASS**, 17 variants compared, `witnessed=17`.
- **`make stream_parity` — PASS on both halves**, unaffected.
- **`make corpus_pr` — 9 expected classes, every one OBSERVED**, 27000 ms against a 45000 ms ceiling.
  D1's rows 4 and 11 unmoved.
- **`make anchors` — 10/10**, after the cascade below.

## The anchor cascade, paid ONCE

**Five anchors moved** and line-count neutrality was not available: a record type gained a field on two
variants and a fold gained a threaded accumulator, neither of which has a "below the anchor" form.
`tool_phase.ail` 288→313, 289→314, 344→373; `session.ail` 2543→2601, 2653→2711. Three anchors did not
move.

**Every anchor was re-derived and NO JUDGEMENT was available** — one candidate each, same answer as B4,
C1, C3 and C5. **The claim did not change**: same seven sites, same effects, same routed flags, same
reviewers, still 6 routed of 7. Coverage unchanged.

`driver_only` re-issued **v7 → v8** with the table's new content hash. Four consumers updated, the same
set C3 and C5 found: the table, `anchors.sh`, `attribution_table_dst`'s fixture, and
`dst_attribution_table`'s own unit test — plus `driver_only_dst` and `profile_definition_dst`.

**And it was paid exactly once, which C3 and C5 both failed to do.** S18 is why: all seven comment
blocks tensed for S15 were rewritten BEFORE the anchor numbers were derived. The rule works.

## Recorded bindings: decided versus discovered

**Discovered — a tool or a measurement forced it:**

1. **`ExtToolHandled` is not gated and never was.** 47 wire occurrences at HEAD, from an existing
   target. The handoff's reservation was wrong and the register is 2 rather than 3.
2. **The register's two-sided pin does not check that anything is appended.** M5: both directions green
   with the driver appending nothing. Both sides derive from the survey field.
3. **A per-variant count comparison is green on a misplaced block.** M3: eighteen rows green, and it is
   the exact defect the handoff named.
4. **`make invariants` cannot see an append that lands after the finalizer.** M4: green. D6.1 was only
   ever checked on a constructed fixture.
5. **The vocabulary header's count had been stale since WI-C3**, alongside the pinned literal C4 found
   — the same number in two places, one checked and one not, third consecutive item to carry this.
6. **Seven prose sites went stale, and in four of them the REASON expired while the CONCLUSION held.**
   The independence argument for reading the wire never depended on the trace being empty.
7. **`DelegatedToolDeferred` was closed-but-unwitnessed** after the first pass — structurally in the
   trace, reached by no subject. Found by the gate printing unwitnessed variants by name.

**Decided — a human chose:**

1. **Return the events; the driver appends them.** No `LedgerTrace` in `tool_phase`, no second
   appender, D6.3's decidability preserved.
2. **A NEW gate rather than an extension of `run_stream_parity_wire.sh`.** The stream gate's subject is
   one variant and its fixture is built around adjacent repeats; overloading it would have made both
   claims harder to read.
3. **The required set is driven off `d64_gap_register()`, not off `reaches_trace_today`.** The survey is
   the claim under test, so a gate reading it would agree with whatever it said.
4. **The order claim is a PINNED SEQUENCE over the returned trace, not a wire-against-trace sequence
   comparison.** The two channels legitimately disagree at exactly one point — `DoneEvent` is appended
   before `c2_finalize` and projected after (WI-A14) — so a global equality would be red by design.
5. **`ScratchpadResult` stays registered.** It is reachable by a hook returning `Handled` with a `cells`
   key, so a scenario could be constructed — and constructing one would close a register entry while
   establishing nothing about a profile. Left with its measurement, per the handoff's own rule.
6. **The witnessed floor is 17, recorded as a measurement** with the nine unreached variants named and
   the reason each is unreached.
7. **`emitted` is threaded as a fold parameter, not accumulated on return.** It sits beside
   `accumulated: [Message]`, which is the same kind of thing, so a branch that forgets it looks wrong
   next to a branch that does not.
8. **Events are appended under the SAME condition they are emitted under**, at both batch sites, rather
   than unconditionally — an unconditional append type-checks and puts a record in the trace for a
   batch that announced nothing on the wire.

## Corrections owed to the plan

1. **S16 GENERALISES FROM A PROPERTY'S TWO SIDES TO AN ARTIFACT'S TWO PINS.** C3's form is about a
   check whose two sides share a producer. D2's is about two SEPARATE artifacts — a register and a
   survey — pinned against each other, which reads like redundancy and is not: both are hand-written
   claims, and agreeing with each other is not evidence about the code. Suggested extension: *"when a
   pin compares two artifacts, ask which one an execution produced. If neither, the pin checks
   consistency, not truth."*
2. **A COUNT COMPARISON NEEDS AN ORDER CLAIM BESIDE IT, and this is now measured twice.** C3 kept
   `stream-parity-count` and `stream-parity-order` separate and said why; WI-D2's first gate forgot
   the lesson one file over and M3 walked straight through it. The rule belongs in the plan rather
   than in each gate's header.
3. **S15's discriminator now has a second dataset and a sharper form.** Eleven of thirteen entries
   named a structural cause; nine were wrong. **A structural reason is stale the moment the structure
   changes and nothing tells it — but the specific failure mode here is narrower: seven of the eleven
   named the wrong structure.** "Inside the tool dispatch fold" described where the code was, not what
   prevented the append, which was the fold's RETURN TYPE. Suggested extension: *"a structural reason
   must name the thing that would have to change, not the place the code lives."*
4. **The plan still has no item after Milestone C.** C4's planning defect 1 stands. The work list has
   two entries left: row 10's filesystem world class, and the `on_budget_plan` ABI change. Neither is
   in the plan.
5. **A port widening is a five-consumer anchor cascade and the plan should size it as one.** WI-D2 paid
   it once by following S18, but the cost is real: two source files, four artifact consumers, a profile
   version bump and a content-hash re-record. D1 avoided it by being line-count-neutral; that route is
   unavailable whenever a type gains a field.

## Out of scope, unchanged and still owed

- **Row 10, hermeticity** — the filesystem world class for `resolve_context_limit`. The third item of
  the work list, and see below.
- **The `on_budget_plan` ABI change**, and `ScratchpadResult`'s and `SessionSuspend`'s coverage.
- **The two sibling `st.world_state` finalize sites** (`SealSystemPromptEmpty`, `SealExhausted`) — still
  owed, still unexercised by any profile here.
- **D4's provider latency pair** — the recorder half.
- **The adversarial partial stream** — D1's narrowed residue.

## THE NAME

**ROW 10 IS NOW THE ONLY RED ROW.** Rows 4 and 11 closed at WI-D1; row 7 closes here. Of C4's eleven,
ten hold and one does not: the host-env clause of hermeticity, which needs a filesystem class in the
world so `resolve_context_limit`'s `Env` and `FS` halves can be routed together.

**That sentence has not been true in this project before.** Ten consecutive items have declined the
name and this is the tenth — `driver_only` does not adopt "DST" or "simulation", because a four-row
gate with one row red is a NO exactly as it was with four red. But **the name is one item away**, and
the item is named, sized and has a producer.

Two of C4's ten passes remain **VACUOUS in their installed-extension clauses** (rows 3 and 5's transfer
caveat), and per D10 that does not change: those rows are earned again from scratch by any second
profile. Row 10 closing would make the gate green; it would not make the vacuous passes non-vacuous.
