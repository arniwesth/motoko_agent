# 2026-08-05 Cluster 26: WI-D2 — the register closes, and the pin that only compared two claims

## Context

Branch: `arniwesth/mot-65-close-d64_gap_register`.

Session span: `7acdbf2` → **`def464e`, one commit, working tree clean**. Input was
`HANDOFF-execute-d2-close-the-parity-register-row-7.md`, executed cold against HEAD. Twenty-sixth code
session of project 009, second of C4's post-gate work list. Pin **v0.33.0**.

**Window: ~46 min**, `16:44Z` → `17:30Z`. Two long poles again, both waiting: the S13 whole-tree sweep
(~7 min over 243 files, run twice) and `make dst` (~15 min, run twice). The production change itself is
small — a record gains a field on two variants, a fold gains an accumulator, seven append sites — and
most of the judgement went into the gate rather than the driver.

**Grounding drift worth one line:** a docs-only commit from a different session
(`80c60bb`, cluster 23's summary, one file under `.agent/`) landed between the `git status` snapshot
and the commit. No source overlap, no measurement affected. The habit of confirming tree state with
`git status` rather than believing prose caught it for free — for the second consecutive item.

| Definition-of-done item | State |
|---|---|
| `d64_gap_register` at 3, survivors carrying reasons | **exceeded** — **2**, and the third was never gated |
| Both directions of `parity_register_findings` green | **met** |
| Row 7 re-answered against the ADR, reading named | **met** — all three conjuncts, the other two re-checked |
| A gate that fails if an append is DROPPED, not a count that rises | **met** — `make ledger_parity`, 17 variants wire-against-trace |
| S15: survivors' reasons as MEASUREMENTS, not diagnoses | **met** — both quote a count and name the run |
| S18: tense comments BEFORE the anchor cascade | **met** — seven sites tensed first, cascade paid **once** |
| S13 whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1` | **met** — 226/17 of 243, failing set byte-identical to baseline |
| S9: every live cache cleared, `~/.ailang/cache/registry` untouched | **met** |
| S17: mutation loops restore by `cp` | **met** — six mutants, each verified byte-identical after restore |

## THE ANSWER

**`d64_gap_register` goes 13 → 2. Acceptance row 7 is GREEN. Row 10 is the only red row left.**

| | before | after |
|---|---|---|
| `d64_gap_register()` | 13 | **2** (`ScratchpadResult`, `SessionSuspend`) |
| Logical variants reaching the returned trace | 15 of 28 | **26 of 28** |
| Variants compared wire-against-trace | 1 (`StreamDelta`) | **17** |

**The reading row 7 closed on:** *emissions that OCCUR reach the trace.* The two survivors are
**coverage** gaps measured at 0 of 1895 wire events across a full `make dst`, not parity gaps — their
emission sites are inside the log the driver now appends, so a run that emitted them would produce
them in the trace.

## The finding: a reason that disproved itself

The handoff reserved three variants and named the gate for two: *"`ScratchpadResult` and
`ExtToolHandled` need an installed extension (the `on_budget_plan` ABI change)."*

**`ExtToolHandled` needs neither.** It is emitted whenever `dispatch_tool_handle` returns `Handled`,
which any hook can do. **Measured: 47 `ext_tool_handled` lines on the wire across one `make dst` run at
HEAD, before this item wrote anything**, from `long_qwen_compaction_dst.ail`.

**How it was found is the transferable part.** I was not working the closures — I was running `make dst`
to get the wire counts needed to write the survivors' reasons as measurements per S15. One of the three
came back 47 instead of 0. **The reason I was about to write is what disproved it.** S15 asks for a
measurement because measurements outlive diagnoses; this is the second-order benefit — taking the
measurement is itself an audit of the claim.

It is closed and **witnessed**: `make ledger_parity` runs a subject whose hook returns `Handled`, so the
closure is observed by the gate rather than inherited from another target's green.

## The shape held: A1's loss channel, second instance

`tool_phase.ail` had **zero** references to `LedgerTrace` and took a multi-fire `emit` callback
returning `()`, while `ToolDispatchOutcome` returned the messages and the world and nothing about what
had been emitted. The handoff called this `on_chunk` again, and it was.

| Step | Precedent | Here |
|---|---|---|
| Widen the return channel | **A1** | `ToolDispatchOutcome` + `execute_allowed_tool_call` gain `emitted: [LedgerEvent]` |
| Fill it | **C1** | the fold threads `emitted` beside `accumulated` |
| Give it a reader | **C3** | the driver appends with `c2_trace_wire_events` — **a second caller, not a mechanism** |

**The forbidden fix was one line away and was declined.** `ledger_append` lives in `phase_vocab`, which
`tool_phase` already imports, so threading a `LedgerTrace` in type-checks immediately. It puts a second
appender in the tree, after which trace order is a function of two writers and D6.3's "decidable over
the returned trace alone" depends on their interleaving. The driver stays the sole appender.

`CostExhausted` took `DoneEvent`'s treatment exactly — appended before `c2_finalize`, D6.1 intact.
`Dp7VerifierRejected` needed its own small widening (it returned the rejection text and dropped the
event it had just projected). `ThinkingStreamEnd` was genuinely one line.

## The central result: a two-sided pin that checks consistency, not truth

**M5.** Set the register and the vocabulary survey to say `ThinkingStreamEnd` is closed. Delete both of
the driver's appends. Run everything.

```
make event_vocabulary   PASS
make invariants         PASS
make ledger_parity      ✗ ThinkingStreamEnd: projected 16, returned 0
```

`parity_register_findings` asserts the register equals the vocabulary's gap **in both directions**, and
the pinned literal beside the vocabulary asserts the count. Both are green. **Both compare the register
against `reaches_trace_today`, which is a hand-maintained SURVEY** — so they check that two claims match
each other, not that anything is appended. This is S16 one level up from C3's form: not a check whose
two sides share a producer, but two artifacts pinned against each other where **neither was produced by
an execution**.

**This is why the item could have shipped a false green.** Flipping the survey and shrinking the register
is the whole in-process ceremony, and it was available without touching the driver.

## Mutation results — six, and two of them are the argument

Restored by `cp` throughout (S17); every file verified byte-identical after each.

| # | Mutant | Result |
|---|---|---|
| M1 | the fold's `Deny` arm forgets to extend `emitted` | RED — `NativeToolDenied: projected 3, returned 1` |
| M2 | the driver drops `done.emitted` at the `Done` arm | RED — two variants at `projected 1, returned 0` |
| M3 | **wrong POSITION, every count unchanged** | **all 18 count rows GREEN; only the order pin red** |
| M4 | `CostExhausted` appended AFTER `c2_finalize` | RED on the order pin and the D6.1 row — **`make invariants` GREEN** |
| M5 | **register + survey say closed; driver appends nothing** | **both in-process gates GREEN; wire 16 against 0** |
| M6 | the required set becomes unreadable | RED, fail-closed |

**M3 is the handoff's predicted failure, reproduced and caught — but only on the second attempt.** The
first version of the gate compared per-variant counts alone. It is green over a log appended as a block
in the wrong place. The pinned order sequence was added *after* writing the mutant the handoff described
and watching all eighteen rows pass.

**M4 is why D6.1 is now checked on real runs.** `terminal_summary_findings` states it correctly and
`invariants_dst` exercises it hard — over a **constructed fixture**, so an append landing after the
finalizer is invisible. `ledger_parity_dst` now asserts, over each of eight runs, exactly one
`RunSummary` and it is the final wire record.

## The new gate, and the coupling that makes the register real

`make ledger_parity` → `run_ledger_parity_wire.sh` + `ledger_parity_dst.ail`, eight subjects.

- **In process:** the trace HOLDS each variant; D6.1 holds per run; append order equals a pinned
  sequence.
- **Out of process:** for every Logical variant `d64_gap_register()` does not excuse, the count
  `ledger_emit` wrote to stdout against the count `ledger_append` put in the returned trace. **17
  compared, every one equal.**

**The required set is `event_vocabulary()` minus `d64_gap_register()`, read out of the run rather than
restated in the shell.** So **removing a name from the register is what makes the gate demand its
append** — which is exactly the direction M5 shows the two in-process pins cannot see.

**Nine required variants are unwitnessed and printed BY NAME rather than counted as passes.** A variant
at zero on both channels is a coverage claim, and conflating it with a parity pass is how a green family
comes to mean nothing.

**Why the order claim is a pinned sequence and not a wire-against-trace sequence comparison:** the two
channels legitimately disagree at exactly one point — `DoneEvent` is appended before `c2_finalize` and
projected after (WI-A14) — so a global equality would be red by design.

## Stale prose: seven sites, and four share a shape

| # | Site | Claim that expired |
|---|---|---|
| 1 | `dst_event_vocabulary.ail` header | "14 of the 34 reach the returned trace" — **stale since WI-C3** |
| 2 | `dst_invariants.ail` header | the register "is now THIRTEEN" |
| 3 | `parity_gap_reasons` | **eleven of thirteen entries**, nine obsolete or wrong |
| 4 | `corpus_pr_dst.ail` | "`NativeToolDenied` and `NativeToolResults` … do not reach the returned trace" |
| 5 | `invariants_dst.ail` | "`CostExhausted` … the driver does not append it today" |
| 6 | `world_state_probe.ail` | "`NativeToolDenied` is `ledger_emit`-only" |
| 7 | `discovery_dst.ail` + `dst_discovery.ail` | "goes to the wire and is never appended to the returned trace" |

**Site 1 is a fourth instance of C4's stale-count class** — the same number in two places, one checked
and one not, reconciled by whichever a reader finds first.

**Sites 4, 6 and 7 share a shape worth naming: the REASON expired and the CONCLUSION did not.** All
three justified reading the wire instead of the trace on the grounds that the trace did not carry the
event. That ground is gone. The conclusion is unchanged and rests where it always belonged — **the wire
has a different AUTHOR**, and a witness read from the returned trace is produced by the same process as
the census it is compared against. All are restated in two parts rather than re-dated, so the next
reader can see which half is load-bearing.

**S15's discriminator held again, with a sharper failure mode.** The eleven register entries naming a
STRUCTURAL cause are the ones that went wrong — and **seven of them named the wrong structure**: "inside
the tool dispatch fold" described where the code lived, not what prevented the append, which was the
fold's RETURN TYPE.

## Sites where two answers type-checked and one was silently wrong: 53

**This item wrote production code and authored none.** The wire gate was built first (S1) and was red on
exactly the ten target variants before a line of production code moved.

**One was found, deliberately hunted per the handoff — and it was in the instrument.** The count-only
gate type-checks, passes, and is green over M3. Counter **53**, from D1's 52, attributed to WI-D2's own
gate rather than to the tree, because that is where it was. **Determinism has still caught none of the
fifty-three.**

**A fifty-fourth candidate was declined:** the two register pins are not *wrong* — they check what they
claim to. They are insufficient, and M5 is what makes the difference visible. Recorded rather than
counted.

## The anchor cascade, paid ONCE

**Five moved.** `tool_phase.ail` 288→313, 289→314, 344→373; `session.ail` 2543→2601, 2653→2711. Three did
not.

**Line-count neutrality — D1's route — was unavailable.** A record type gained a field on two variants
and a fold gained a threaded accumulator; neither has a "below the anchor" form.

**Every anchor re-derived, NO JUDGEMENT available** — one candidate each, same answer as B4/C1/C3/C5.
**The claim did not change**: same seven sites, same effects, same routed flags, still 6 routed of 7.
`driver_only` re-issued **v7 → v8** with the new content hash; six consumers updated.

**Paid exactly once, which C3 and C5 both failed to do.** S18 is why: all seven comment blocks tensed for
S15 were rewritten BEFORE the anchor numbers were derived. **The rule works, and this is its first clean
demonstration on an item that could not avoid the cascade.**

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 / 17 of 243.** Failing set **byte-identical
  to the baseline taken at the top of this item** (`diff` clean, not eyeballed). 243 rather than 242
  because this item adds one file.
- **`make dst` — EXIT 2, same two red targets as B4, C1, C3, C4, C5, D1:** `test_coverage`,
  `test_coverage_selftest`, both pre-existing. **831 ✓ rows** against D1's 809.
- **`make ledger_parity` — PASS**, `witnessed=17`.
- **`make stream_parity` — PASS both halves**, unaffected.
- **`make corpus_pr` — 9 expected classes, every one OBSERVED**, 27000 ms / 45000 ms ceiling. D1's rows 4
  and 11 unmoved.
- **`make anchors` — 10/10.**

## Corrections owed to the plan

1. **S16 generalises from a property's two sides to an ARTIFACT'S two pins.** *"When a pin compares two
   artifacts, ask which one an execution produced. If neither, the pin checks consistency, not truth."*
2. **A count comparison needs an order claim beside it** — measured twice now. C3 kept count and order
   separate and said why; D2's first gate forgot it one file over.
3. **S15's practical form is narrower than "structural reasons go stale":** a structural reason must
   **name the thing that would have to change**, not the place the code lives.
4. **The plan still has no item after Milestone C** (C4's planning defect 1). Two work-list entries
   remain: row 10's filesystem world class, and the `on_budget_plan` ABI change.
5. **A port widening is a six-consumer anchor cascade** and the plan should size it as one.

## Deliberately not done

- **Row 10** — the filesystem world class. Third item of the work list.
- **A constructed `ScratchpadResult` scenario.** Reachable by a hook returning `Handled` with a `cells`
  key, so one *could* be built — and it would close a register entry while establishing nothing about a
  profile. Left registered with its measurement, per the handoff's own rule.
- **The `on_budget_plan` ABI change**, and the two sibling `st.world_state` finalize sites D1 reported.
- **THE NAME.** Ten consecutive items have declined it. A four-row gate with one row red is a NO exactly
  as it was with four red.

## The sentence that has not been true before

**Row 10 is now the only red row.** Rows 4 and 11 closed at D1; row 7 closes here. Ten of C4's eleven
hold.

Two caveats the headline must not swallow: rows 3 and 5 remain **VACUOUS** in their installed-extension
clauses, and per D10 closing row 10 would make the gate green without making those non-vacuous.
