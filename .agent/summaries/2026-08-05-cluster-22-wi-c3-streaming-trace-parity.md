# 2026-08-05 Cluster 22: WI-C3 — the bridge from a run to an ExecutionUnderTest, and the half of D6.4 no in-process check can make

## Context

Branch: `arniwesth/mot-61-execute-wi-c3`.

Session span: `aebad19` → **`b145eef`, one commit, working tree clean**. Input was
`HANDOFF-execute-c3-streaming-trace-parity.md`, executed cold against HEAD. Twenty-second code
session of project 009, second of Milestone C. Pin **v0.33.0**.

**Window: ~72 min**, `08:59Z` → `10:11Z`. Under expectation for the work, and the reason is the
carryable one: threading a new field through a 3000-line recursive driver — 16 loop-state literals, 7
terminal calls — cost almost nothing, because every site is a **closed record** and the compiler names
each one. That is B2a's closed-row finding paying off at scale. **The cost was elsewhere: ~25 min on
the D4 anchor cascade, paid TWICE, and ~15 on the mutation loop.**

| Definition-of-done item | State |
|---|---|
| The scope decision, stated | **met** — BRIDGE; D6.4's named stream exception discharged, general obligation explicitly not |
| One converter, used by projection AND witness | **met** — `stream_chunk_event`; `Usage` exclusion pinned by unit test |
| The two scripted `play_chunks` sites populated | **met** — one list, played and reported, cannot drift from itself |
| Invariant proven red against a **production-path** mutant | **met** — three mutants, and the table is the item's main finding |
| S13 whole-tree sweep, cache-cold | **met** — 222/17, run twice, failing set byte-identical to B4's |
| S9: every live cache cleared, both exclusions | **met** — three times; 0 tracked cache paths after a full `make dst` |
| `make dst` status with each red attributed | **met** — exit 2, B4's exact two reds, no new class |
| S15: line-number anchors in prose get tense | **met** — and the cascade had two consumers no checklist names |

## Grounding

HEAD `aebad19`, tree clean — exactly what the handoff said. **Second consecutive handoff to get commit
state right**, after five that did not. The instruction to confirm with `git status` rather than
believe the prose keeps earning its place in both directions.

## The finding that resized the item, and it inverts the handoff's model

The handoff described parity's two sides as: witness ← `exchange.emissions`, trace ← the returned
`LedgerTrace` filtered to `StreamDelta`, *"what the callback actually emitted"*.

**The second half was false at HEAD.** The callback calls `ledger_emit`; `ledger_emit` writes the WIRE
and calls `emit_trace_event`. It does **not** call `ledger_append`, and `ledger_append` is the only
thing that puts a record in the returned `LedgerTrace`. So **the returned trace held ZERO `StreamDelta`
records on every path in the driver's history** — which is precisely why `StreamDelta` sat in
`d64_gap_register`, and the register said so at the site the whole time.

**So it was not "the log has no reader". BOTH SIDES WERE EMPTY**, and two empty lists are green.

This changed the item's minimum viable scope. Populating the witness alone — the handoff's "channel"
option — yields `StreamParityCount(N, 0)` on every run, and the two-line repairs for that are the
fail-open ones the handoff names. **The trace append had to land with the bridge; closing the register
gap was a precondition the item discovered, not a bonus it picked up.**

Worth saying plainly: the append was not merely unwritten, it was **unwritable**. There was nothing to
append *from* until `stepWithStreamRecorded` returned a log. WI-A1 predicted the shape, WI-C1 supplied
the log, WI-C3 spent it.

## The scope decision: BRIDGE

`src/core/dst_execution.execution_of` converts a `TracedSessionResult` into an `ExecutionUnderTest`.
`scripts/dst/stream_parity_dst.ail` drives the real driver through it and evaluates **all sixteen D7
families**. **C4's acceptance row for D6.4's stream-parity obligation is claimable from this item.**

Stated precisely, because C4 reads it:

- **D6.4's NAMED STREAM EXCEPTION is discharged.** `StreamDelta` is out of the register, having left
  by being **APPENDED** rather than reclassified — asserted in both directions exactly as `DoneEvent`
  is, because "it is out of the gap" is *also* true if someone flipped the exception to DisplayOnly.
- **D6.4's GENERAL obligation is NOT discharged.** Register **14 → 13**; twelve are the tool-dispatch
  fold and the terminal paths, one (`ThinkingStreamEnd`) is the closing half of the very bracket this
  item's events sit inside.

## The tautology boundary, MEASURED — and this is the session's headline

In-process there is exactly **one** observation of the stream: `ProviderExchange.emissions`. The
callback's projections go to `ledger_emit`, which returns `()`; the callback's row is closed `{IO}` so
it cannot accumulate them; D1 rejected the scoped recorder and `SharedMem` explicitly. **There is no
third channel.** So both in-process sides derive from the same expression, and rather than argue about
what that costs, it was measured with three mutants **in the production path**:

| Mutant | `stream_parity_dst` | wire gate |
|---|---|---|
| **A.** The tool-call branch keeps the trace and drops the witness | **RED** — 5 rows, both subjects | red (via A) |
| **B.** The CALLBACK de-duplicates adjacent repeats — a second converter in the projection only | **GREEN, entirely** | **RED** — count, order, fixture adequacy |
| **C.** Revert the trace append (the pre-C3 driver: project every delta, append none) | **RED** — `StreamParityCount(7, 0)` | red (via C) |

**Mutant B is S14's shape one level up.** A projection disagreeing with the returned log — *literally
what D6.4 forbids* — leaves the invariant suite completely green. Anyone who builds only the
in-process check ships a green gate over the defect D6.4 exists to find. So `make stream_parity` runs
**two** gates:

- **`stream_parity_dst.ail`** — witness against returned trace. Tests that the driver carries **both
  channels forward on every branch**: the trace has ONE junction after the call, the witness is set in
  **six** branch literals, and that asymmetry is deliberate. **S12's identity-transition class arriving
  on a pair of channels rather than on a world token.**
- **`run_stream_parity_wire.sh`** — the WIRE against the returned trace. The wire is what the
  **callback** projected during the call; the trace is what the **driver** appended afterwards from the
  returned log. **Two producers, one claim.** Out of process because the wire is, which is the honest
  reason it is a shell script and not an invariant family.

**Neither gate subsumes the other**, and the table is the evidence rather than the assertion.

**What NEITHER tests:** whether the mapping is right. Both sides of both gates use
`stream_chunk_event`, so a wrong `kind` is invisible by construction. **That is A8's vocabulary
contract, not D6.4's** — said at the site rather than left to be inferred from a green.

## The first real-run evaluation of D7 in this project

Verbatim, first run:

```
[scripted]  witness=7 trace_stream_records=7 expected=7
[scripted]  all sixteen families over the real run: 1 finding(s) — clock-balance
[recording] witness=7 trace_stream_records=7 expected=7
[recording] all sixteen families over the real run: 0 finding(s)
```

Parity was green first try and stayed green. The 7 is the fixture's own total (4 + 3) and is asserted
against it, not against a literal.

**The one finding is real information and it is attributable.** `clock-balance` compares
`world.clock_ms - initial_clock_ms` against `total_advance_ms(world.log)`. `scripted_ports` advances
the virtual clock and records **no interaction**, so the log cannot account for it. The **recording**
adapter balances to zero across all sixteen. That difference is what makes it an adapter property
rather than a driver defect, and it is why two subjects were driven rather than one.

**Both are PINNED as exact rule sets, not printed.** A printed count is a number nobody checks — C1
made the same correction one item earlier about prose.

### The third side, and it is the only independent producer available in-process

The recording adapter writes each played chunk into the world's interaction log through
`chunk_records` — a different function on a different channel from the `emissions` the exchange
returns. The script asserts the log's chunk texts equal the witness **text for text**, which tests two
producers agreeing rather than one channel threaded twice. **It exists only under the recording
adapter** (`live_ports` records nothing into the world), and the report says so rather than letting the
coverage read as general.

## One converter, and the off-by-one no gate in this tree can see

`stream_chunk_event : (int, string, StreamChunk) -> Option[LedgerEvent]` is the single core; the
`Usage` exclusion and the `thinking`/`reasoning` selection live in exactly one place, used by the
projection, the trace append and the witness.

**The trap is real and unreachable from any acceptance script here.** No scripted world plays a
`Usage` chunk, so a witness that maps every returned chunk is green on every gate in the tree and
reports `StreamParityCount(N+1, N)` on the first live provider run. It is pinned by a **unit test**,
and the test asserts the **difference** rather than the count — a row asserting `== 2` is also green on
an implementation that drops the first `ContentDelta` instead. A second row pins the kind selection
separately, because one row over a mixed list cannot say which of the two things it read.

## WI-A1's tripwire fired, and it was right to

`phase_c2_wiring_scenarios` asserted `emission_count == 0` and carried this sentence:

> If this scenario ever starts failing on the emptiness clause, something began populating the log and
> the behaviour-preserving claim needs re-checking.

**It went red on the first `make dst` after the change.** Recorded rather than quietly rewritten,
because a pin edited to match whatever the code now does is not a pin. The row now asserts something
**strictly stronger** — the scripted exchange reports *exactly* the chunks it played, count derived
from the fixture — and the scenario is renamed so its id does not claim the old fact.

**This is the first time in this project that a deliberately-planted tripwire from an earlier item
fired on the item it was planted for.** It cost WI-A1 one line.

## What the driver had to gain, and it is a D6-level change

`c2_finalize` is the sole assembly site of the result/trace/world triple, and the triple carried **no
emission channel**. The only value available for `ExecutionUnderTest.emissions` was `[]`, which on a
real run is indistinguishable from a run that streamed nothing.

So `TracedSessionResult` gained `emissions: [LedgerEvent]` and `C2LoopState` gained the accumulator
feeding it. Reported rather than absorbed: it changes what D6 says a run returns.

**No effect row widened.** `c2_finalize` stays `! {IO, Clock, Trace}`, the callback stays closed
`{IO}`, `live_ports` stays `! {AI, Clock, Env, IO}`. B4's refutation was never engaged.

## Sites where two answers type-checked and one was silently wrong: 3 → counter 48

Base **45** from C1's report (which corrected the handoff's 39 to B4's 43, plus C1's two).
**Determinism has still caught none.**

1. **The witness including `Usage`.** Green on **every gate in this tree**; wrong only on a live
   provider. **Caught by the handoff's prose, not by a gate**, and now pinned by the only instrument
   that can see it.
2. **`emissions: st.emissions` on a post-call branch.** Six branches, silent under `ailang check`,
   `check_core` and `driver_only`. Mutant A is the measured version — **and it is visible only because
   this item built the gate in the same change.**
3. **`result_of` mapping a failed run to `RunFailed`.** A provider error is a run *outcome*, not a
   harness failure; classifying it as one makes `satisfies_terminal_trace_contract` **vacuously true
   for every failed run**. Nothing in the tree would have gone red.

**All three are one species: a value well-formed under both readings whose wrong reading makes a check
pass. Two of the three are visible only to instruments this item built.**

## Does the D7 suite still have one construction site? No — two, and only one is a fixture

| | At WI-C1's HEAD | Now |
|---|---|---|
| `ExecutionUnderTest` construction sites | **1** (hand-authored, `emissions: []`) | **2** |
| Sites that build one from a RUN | **0** | **1** |
| Modules importing `dst_invariants` | 3 | **4** |
| Families evaluated over a real run | **0 of 16** | **16 of 16**, two subjects |

**The fixture is kept and should be.** It reaches shapes a scripted run does not — a differing `seq`, a
trace holding exactly one of two deltas — and a constructed row cannot be made vacuous by a driver
change. Its header is corrected, because the sentence it carried ("no run produces a non-empty emission
log today") stopped being true.

**The honest remaining gap: fifteen families run on a real run because they RIDE ALONG with parity, not
because anything wires them deliberately.** One script, one profile, two adapters.

## Three targets went red during the item, and all three were its own tripwires

Recorded because "no target went red" is what C1 could say and this item cannot:

1. **`phase_c_l1`** — A1's emptiness scenario. Answered and strengthened.
2. **`invariants`** — the register count pinned at 14 in two places, an acceptance row and a unit test.
   Both are deliberate literals rather than derivations, and **that is correct**: a row asserting the
   register equals itself is green after any edit.
3. **`attribution_table`** — the completeness fixture fired **two** rules instead of one, because
   `omitted_site()` held a copy of a moved anchor. S7's "prove the wrong thing" row doing its job, and
   the only thing in the tree that could have seen that second consumer.

## The near-miss, reported because it nearly cost the item

**`git checkout src/core/session.ail`, used to revert a mutant, reverted the entire implementation.**
Recovered from a `cp` backup taken seconds earlier in the same command block; without it the loss was
~90 minutes of threading. **During an item the working tree IS the work and git is the only copy of the
state before it** — a path-scoped checkout does not distinguish the mutant from what is underneath it.
Now **S17**.

## Plan corrections landed

1. **S13 amended: the whole-tree sweep needs `AILANG_RELAX_MODULES=1`.** Every `packages/**` module
   declares a `sunholo/...` path that does not match its file path. **Unflagged the sweep reads
   146 pass / 93 fail; flagged it reads 222 / 17** — a false red four times larger than the fifth
   frontier B4 found, and no prior report records the flag. The command and the stable 17-member
   failing set are now written into the rule.

   **The MECHANISM came from the review session (`b9dd8d7`), and it is the part I did not have: a
   WARM CACHE MASKS MOD010 COMPLETELY.** The same file passes cache-warm unflagged and fails
   cache-cold unflagged (measured 12 of 12 sampled `packages/**` files). So the flag's necessity is
   visible **only** under the discipline S9 and S13 themselves impose — which is why three prior
   items measured sweeps and never needed it. **Cache-warm unflagged fails GREEN; cache-cold
   unflagged fails RED by 76 files. Opposite directions, which is why neither reads as a defect on
   its own.**
2. **S16 (new): a parity check whose two sides share a PRODUCER tests threading, not parity.** With the
   mutant-B measurement and its corollary — *a variant in `d64_gap_register` has no trace side at all*,
   so "parity is checked over the returned trace" for a registered variant is a comparison against an
   empty list. **Binds C5's declared-versus-performed detector directly; it has exactly this shape.**
3. **S17 (new): a mutation loop must save and restore by file copy, never `git checkout`.**
4. **The D4 cascade is not half-avoidable, not mostly-comment, and NOT PAID ONCE PER ITEM.** C1 refuted
   "insert below the anchor" with a comment; C3 refutes the rest with a record **field** and an
   **extracted function**, neither of which has a below-the-anchor version. **Four consecutive items
   have paid it, and this item paid it twice** — the second payment caused by three lines of prose added
   after the first, found by `make dst` rather than by remembering. Operationally: **finish every source
   edit, including comments, before running the cascade.** Two consumers no checklist names: the
   `predicate-anchors` script itself, and `attribution_table_dst`'s `omitted_site()` fixture.
5. **A tripwire planted for a future item WORKS**, first evidence. One line, and it caught the one
   change it was written about.

## Gate state

- **`make stream_parity` — exit 0.** 12 rows per subject × 2 subjects, plus 6 wire rows.
- **`make dst` — EXIT 2, cache-cold, the SAME TWO red targets as B4 and C1:**
  - `test_coverage` — 3 findings / 2 rules from `prompts_test.ail`. Pre-existing.
  - `test_coverage_selftest` — `stale_skip_record` + a `named_only.ail` finding. Pre-existing.
  - No other target red; `stream_parity`, `recorded_stream`, `invariants`, `attribution_table`,
    `driver_only`, `phase_c_l1` all pass inside the run.
- **Whole-tree sweep — 222 pass / 17 fail**, cache-cold, run **twice** (mid-item and after every edit);
  failing set byte-identical between them and to B4's and C1's, verified by `diff`. 222 rather than 220
  because two files are new.
- **`driver_only` re-issued v5 → v6**, attribution ref re-recorded twice
  (`e201c1da…` → `426c94af…` → `ea292462…`). Coverage unchanged: install list empty, waived set
  unchanged, no hook classification moved.
- **0 tracked `.ailang/cache` paths**, verified after a full `make dst`.

## Deliberately not done

- **WI-C4, the name gate.** No target gained the "DST" or "simulation" name. B4's `on_budget_plan`
  argument is untouched: no extension is installable under D5 while that hook carries the ABI's closed
  `! {Env, FS}` row. **C3 going well does not move that**, and the acceptance row it supplies is one row.
- **WI-C5** — `proc_exec`/`env_get` widening and the declared-versus-performed detector. **S16 binds it.**
- **The other fifteen families, wired deliberately.** Their red surface is unknown; the one measurement
  is that the scripted adapter already trips `clock-balance`.
- **The extension bridge's emission channel.** `ext_ai_step` still drops `exchange.emissions`; closing
  it needs `ExtPorts.ai_step` widened to carry a chunk log the ABI has no type for. Named at the site.
- **A partial-stream-then-error seeded run.** `ScriptedStep` has no error channel — now the *only* thing
  keeping `provider_partial_stream_then_error` unreachable by search, since the parity half stopped
  being the obstacle. Same one named field as `provider_error_retryable`.
- **The `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.** Unchanged, still owed.

## Independent verification

A concurrent review session (`b9dd8d7`, session `01BwYXuFYoy5QBfRqt6SiLzq`) reproduced the item's
load-bearing claims before applying anything to the plan:

- **Mutant B reproduces exactly** — in-process gate green with 0 findings across all sixteen families,
  wire gate red on three rows at `wire_deltas=10` against `trace_deltas=14`. It restored by `cp`, per
  this item's own S17.
- **`ledger_emit` calls `emit_json` and `emit_trace_event` and never `ledger_append`** — the finding
  that resized the item is real.
- **`d64_gap_register` is 13**, `StreamDelta` out and `ThinkingStreamEnd` in.
- **`make stream_parity` exit 0** — 12 rows per subject on two subjects, 6 wire rows.
- **The `AILANG_RELAX_MODULES` claim reproduces** — 12 of 12 sampled `packages/**` files fail MOD010
  cache-cold without it, 0 of 12 with it.

It also caught itself adding **second copies of S16, S17 and the RELAX_MODULES text** — the exact
duplicate-rule defect it removed from S9/S10 one item earlier — and removed them, keeping only the
independently measured numbers. **That is S15's shape a third time: a superseded rule and a current
one are indistinguishable by inspection, and this time the author noticed within the same item.**

## Artifacts

- `src/core/dst_execution.ail` — **new.** The bridge.
- `scripts/dst/stream_parity_dst.ail` — **new.** Real run → `ExecutionUnderTest` → all sixteen families.
- `scripts/dst/run_stream_parity_wire.sh` — **new.** Wire against trace; the only two-producer gate.
- `.agent/projects/009_motoko_dst_execution/NOTE-c3-execution-report-and-plan-corrections.md`
- Commit **`b145eef`**.
