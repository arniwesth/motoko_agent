# Handoff: close `d64_gap_register` — acceptance row 7, the oracle row

Audience: a fresh session grounded against HEAD. Source-heavy driver work; you are that session.

**Second item of C4's post-gate work list.** The plan has nothing after Milestone C — that is C4's
planning defect 1 — so this is scheduled by acceptance row, not by plan order.

**WI-D1 landed 2026-08-05** (~2h05m): rows 4 and 11 close, the corpus's unreachable register is empty,
and it found a production defect on the way — `c2_loop`'s unretried-failure branch was finalizing from
the pre-call world. Verified at review: `corpus_pr` green on nine expected classes with nothing
subtracted, `provider_error_non_retryable` witnessed at seeds 3 and 36, `make anchors` 10/10 unmoved.
**Confirm tree state with `git status`.**

**Read first:** `NOTE-d1-fault-reachability-rows-4-and-11.md`, then `NOTE-c4-name-adoption-gate-verdict.md`
row 7, then the plan's `## Standing rules` — **S12 gained its instrument, S15 its practical form, and
S19 now covers absent counts.**

## Mission

**Close `d64_gap_register` for every variant `driver_only` can reach, and turn acceptance row 7
green.** Row 7 — *"all logical ledger emissions appear in the returned trace"* — is the largest
remaining blocker and **the row that actually refuses the name**, which nobody was tracking until C4
ran the table.

**The target is 13 → 3, not 13 → 0.** Three variants are gated elsewhere and must stay registered with
their reasons: `ScratchpadResult` and `ExtToolHandled` need an installed extension (the
`on_budget_plan` ABI change), and `SessionSuspend` needs a profile with a suspend trigger. The row asks
that emissions which *occur* reach the trace; a variant no run under this profile emits cannot fail to
appear. **Say which reading you closed it on.**

## The finding that shapes the whole item

**The tool-dispatch fold — seven of the thirteen — is WI-A1's loss channel, second instance, and the
project has already solved this shape twice.**

`tool_phase.ail` contains **zero** references to `LedgerTrace` or `ledger_append`. It cannot reach the
trace. Instead:

```ailang
dispatch_tool_entries_with_builtin(…, emit: (LedgerEvent) -> () ! {IO, Trace}, …)
  -> ToolDispatchOutcome

type ToolDispatchOutcome
  = ToolDispatchDone({ msgs: [Message], world: WorldState })
  | ToolDispatchPending({ request: ApprovalRequest, accumulated: [Message], world: WorldState })
```

and the driver passes `\event. ledger_emit(session_id, event)` (`session.ail:2126`).

**That is `on_chunk` again, exactly.** A multi-fire callback whose values the caller discards, over a
result type that returns everything *except* what was emitted — which is what `ProviderExchange` was
before WI-A1 widened it. `ledger_emit` writes the wire and calls `emit_trace_event`; **it never calls
`ledger_append`**, which is the only thing that puts a record in the returned trace. C3 established
that and it is why these variants are registered at all.

**So the move is the one already made and validated across three items, not a new design:**

| Step | Precedent | Here |
|---|---|---|
| Widen the return channel first | **A1** — "widen the port before adopting whatever fills it, because the port is where the information is thrown away" | `ToolDispatchOutcome` gains an emitted-event log on both variants |
| Fill it | **C1** — `live_ports` returns `rec.chunks` | the fold accumulates what it emits |
| Give it a reader | **C3** — `stream_chunk_events` → `c2_trace_wire_events` | the driver appends the returned log |

**`c2_trace_wire_events` already exists and already does this job** for stream deltas at
`session.ail:2251`. You are adding a second caller, not a mechanism.

## The rule you will break by accident

**Do not thread a `LedgerTrace` into `tool_phase`.** It is the obvious fix, it type-checks, and it
puts a **second appender** in the tree — after which trace order is a function of two writers and
D6.3's "agreement decidable over the returned trace alone" depends on their interleaving. The driver
is the sole appender today and that is load-bearing. **Return the events; let the driver append them.**

**And the ordering constraint that bit `DoneEvent`, stated at `session.ail:1991-1999`:** D6.1 requires
the `RunSummary` to remain the **final appended record**. A14's answer was to append the event
*before* `c2_finalize` and project it *after*, which let D6.4, D6.1 and D6.3 hold simultaneously where
three could not. **`CostExhausted` is the same shape** — its recorded reason says so in as many words,
"emitted on the cost-cap terminal path immediately before the finalizer… the same one-line append."
Any append that lands after `c2_finalize` breaks D6.1 and row 7's own first conjunct.

**Events must land where they happened.** The stream-delta append is positioned deliberately —
*"between the prepared event and whatever the outcome produces, which is when they actually
happened"*. A tool-event log appended as a block in the wrong position passes a count check and fails
order.

## What each piece costs

| Piece | Variants | Note |
|---|---|---|
| **The tool-dispatch fold** | `NativeToolDenied`, `ToolPending`, `DelegatedToolDeferred`, `V2ToolDispatchStart`, `V2ToolDispatchComplete`, `NativeToolCalls`, `NativeToolResults` | Seven of the thirteen. The A1-shaped widening above; the bulk of the item |
| **The stream bracket** | `ThinkingStreamEnd` | `ThinkingStreamStart` is appended at `session.ail:2251` and the end event is only `ledger_emit`'d — **the same code path appends one bracket and projects the other.** Genuinely one line |
| **Terminal / re-injection** | `CostExhausted`, `Dp7VerifierRejected` | `CostExhausted` is `DoneEvent`'s exact precedent. `Dp7VerifierRejected` is on the re-injection path, which is **not** terminal — the run continues, so D6.1's ordering does not bind it |
| **Gated elsewhere — leave registered** | `ScratchpadResult`, `ExtToolHandled`, `SessionSuspend` | Keep with reasons. Removing them is the forbidden narrowing |

## Two guards already in place, and one gap you must not repeat

**The register's pin is TWO-SIDED here, unlike D1's.** `parity_register_findings` asserts the register
equals the vocabulary's gap in **both** directions: `ParityGapRegisterMissing` fires for a gap nobody
registered, and `ParityGapRegisterStale` for a registered variant that is no longer a gap. **So D1's
asymmetry trap does not recur** — closing a variant without shrinking the register goes red here,
where in the corpus it went silent. Do not add a one-sided count beside it.

**Reclassifying as `DisplayOnly` remains the forbidden one-line answer**, guarded by
`display_only_baseline` and named in the invariant's own text as *"never a field flip that turns a red
invariant green"*.

**The gap you must not repeat is S16's.** C3 built a **wire gate** for stream parity because the
in-process check derives both sides from one producer, and D1's M5 showed the in-process rows staying
green through exactly the defect they exist to catch. **The new appends have the same structure** —
the log you append and the log you projected come from one accumulation. `make stream_parity`'s wire
gate covers `StreamDelta` only. **Either extend the out-of-process comparison to the tool events, or
state plainly at the site what the in-process check does and does not establish.** Do not let a green
parity family read as evidence that the projection and the trace agree.

## Definition of done

**`d64_gap_register` at 3, with the remaining three carrying reasons**, and both directions of
`parity_register_findings` green.

**Row 7 re-answered against the ADR's text**, with the reading named — and its other two conjuncts
re-checked, since appending on terminal paths is exactly where "exactly one final `RunSummary`" breaks.

**A gate that fails if an append is dropped**, not merely a count that rises. Per **S19**, a census
reading zero is a claim — and per D1, the absent count was the signal that found a production defect.

**Per S15 — reasons for the three survivors recorded as MEASUREMENTS, not diagnoses.** D1 measured
that structural reasons ("the type has no such field") went false within an item or two while the one
quoting a number was still true four items later. Seven stale reasons in one item is the cost of
getting this wrong.

**Per S18 — tense any comment you rewrite BEFORE running the anchor cascade**, and prefer
line-count-neutral edits: D1 avoided the cascade entirely that way, the first item in four to do so.

**Per S13 — whole-tree sweep cache-cold with `AILANG_RELAX_MODULES=1`**, failing set member-for-member
against the expected seventeen. **Per S9 — clear every live `.ailang/cache`, leave
`~/.ailang/cache/registry` alone.** **Per S17 — mutation loops restore by `cp`.**

## Out of scope

- **Row 10, hermeticity** — the filesystem world class for `resolve_context_limit`. The last red row
  after this one, and the third item of the work list.
- **The `on_budget_plan` ABI change** and everything gated on it, including two of the three variants
  you will leave registered.
- **The two sibling `st.world_state` finalize sites** D1 reported (`SealSystemPromptEmpty`,
  `SealExhausted`) — still owed, still unexercised by any profile here.
- **D4's provider latency pair** — the recorder half.
- **THE NAME.** Row 10 stays red regardless of how this goes, so `driver_only` does not adopt
  "DST" or "simulation". Ten consecutive items will have declined it.

## Stop and report rather than deciding inline

- **If appending a tool event requires `tool_phase` to import anything from the ledger layer**, stop —
  that is the second-appender design above, and it is a layering decision with D6.3 behind it.
- **If closing a variant reddens `terminal-summary` or D6.3's agreement family**, report the sequence
  before repairing. Those are row 7's other two conjuncts and they currently hold.
- **If a variant turns out to be emitted on a path no seed reaches**, that is a *coverage* claim, not a
  parity one — say so and leave it registered with the measurement, rather than closing it on a
  constructed scenario.

## Report back

Twenty-sixth calibration run.

- **The git wall-clock window.**
- **The register's final size and the reading row 7 was closed on.** The item's durable output; C4's
  table reads it.
- **What the in-process parity check establishes and what it does not**, per S16 — and whether the
  wire comparison was extended.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **52 across
  twenty-five runs; determinism has caught none.** D1's was found by a census reading zero, and this
  item adds appends whose absence is exactly that shape — so look for it deliberately.
- **Whether row 10 is now the only red row.** If it is, say so plainly: the name would then be one
  item away, and that sentence has not been true in this project yet.
