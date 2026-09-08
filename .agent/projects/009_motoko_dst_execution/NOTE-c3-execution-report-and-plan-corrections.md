# WI-C3 execution report — the bridge, and the half of D6.4 no in-process check can make

Twenty-second calibration run. Written against HEAD `aebad19`, branch
`arniwesth/mot-61-execute-wi-c3`.

## Window

**~72 minutes** wall-clock: `2026-08-05T08:59Z` → `2026-08-05T10:11Z`. Grounding was clean: `git
status` clean at `aebad19`, exactly what the handoff said, which is the second handoff in a row to get
commit state right.

**Against C1's 57 minutes, for markedly more work**, and the reason is worth carrying: the item's
central risk — threading a new field through a 3000-line recursive driver, 16 loop-state literals and
7 terminal calls — cost almost nothing, because every site is a CLOSED record and the compiler names
each one. That is B2a's closed-row finding paying off at scale. **The cost was elsewhere: roughly 25
minutes on the D4 anchor cascade and the artifacts it re-issues, PAID TWICE**, and about 15 on the
mutation loop. Per S4, the driver threading was 23 transcribed sites; the cascade was six discovered
ones plus two consumers nothing lists.

## The scope decision: **BRIDGE**. And what that does and does not discharge

**The bridge is built.** `src/core/dst_execution.execution_of` converts a `TracedSessionResult` into
an `ExecutionUnderTest`, and `scripts/dst/stream_parity_dst.ail` drives the real driver through it
and evaluates **all sixteen D7 families** over what comes back. **C4's acceptance row for D6.4's
stream-parity obligation is claimable from this item.**

**Stated precisely, because C4 reads this paragraph and a bare "discharged" would be over-claiming:**

- **D6.4's NAMED STREAM EXCEPTION is discharged.** `StreamDelta` is out of `d64_gap_register` — the
  driver now appends the events to the returned trace — and parity is checked on a real run by two
  gates that cover different halves (below). It left the register by being **APPENDED**, not by being
  reclassified, and `invariants_dst` asserts that in both directions exactly as it does for
  `DoneEvent`.
- **D6.4's GENERAL obligation is NOT discharged and this item did not claim to.** The register went
  **14 → 13**. Twelve of the thirteen are the tool-dispatch fold and the terminal paths; one
  (`ThinkingStreamEnd`) is the closing half of the very bracket this item's events sit inside.

## The finding that resized the item a SECOND time, and it inverts the handoff's model

The handoff described the two sides of parity as:

> **Witness** ← `exchange.emissions` … **Trace** ← the returned `LedgerTrace.records`, filtered to
> `StreamDelta` — **what the callback actually emitted**.

**The second half was false at HEAD, and measurably so.** The callback calls `ledger_emit`;
`ledger_emit` writes the WIRE and calls `emit_trace_event`. It does **not** call `ledger_append`, and
`ledger_append` is the only thing that puts a record in the returned `LedgerTrace`. So **the returned
trace contained ZERO `StreamDelta` records on every path in the driver's history** — which is
precisely why `StreamDelta` was in `d64_gap_register` in the first place, and the register said so at
the site the whole time.

**So it was not "the log has no reader". BOTH SIDES WERE EMPTY.** The witness was `[]` because
nothing read `exchange.emissions`; the trace side was `[]` because nothing appended. A parity check
over two empty lists is green.

**This changes the item's minimum viable scope.** Populating the witness alone — the handoff's
"channel" option — would have produced `StreamParityCount(N, 0)` on every run, and the two-line
repairs for that are the fail-open ones the handoff names. Building the bridge alone, without the
append, would have produced the same. **The append had to land with the bridge, and closing the
register gap is therefore not a bonus this item picked up; it is a precondition it discovered.**

Worth saying plainly: the append was not merely unwritten before, it was **unwritable**. There was
nothing to append *from* until `stepWithStreamRecorded` returned a log. WI-A1 predicted the shape,
WI-C1 supplied the log, WI-C3 spent it.

## The tautology boundary, MEASURED rather than reasoned about

The handoff asked for the two sides to come from different places, and warned that the check is
vacuous the moment both derive from one. **In-process, both do, and there is no alternative.**

`ProviderExchange.emissions` is the **only** observation of the stream that exists in the driver's
process. The callback's own projections go to `ledger_emit`, which returns `()`; the callback's row
is closed `{IO}` so it cannot accumulate them; and D1 rejected the scoped recorder and `SharedMem`
explicitly. There is no third channel to compare against.

**So the in-process check was built to test what it actually can, and the split is measured with a
mutant rather than argued:**

| Mutant, in the PRODUCTION path | `stream_parity_dst` | wire gate |
|---|---|---|
| **A.** The tool-call branch keeps the trace and drops the witness (`emissions: st.emissions`) | **RED** — 5 rows, both subjects | RED (via A) |
| **B.** The CALLBACK de-duplicates adjacent repeats — a second converter in the projection only | **GREEN, entirely** | **RED** — count, order, and fixture adequacy |
| **C.** Revert the trace append (the pre-WI-C3 driver: project every delta, append none) | **RED** — `StreamParityCount(7, 0)` | RED (via C) |

**Mutant B is the item's headline and it is exactly S14's shape one level up.** A projection that
disagrees with the returned log — which is *literally what D6.4 says must not happen* — leaves the
invariant suite **completely green**. Anyone who builds only the in-process check ships a green gate
over the defect D6.4 exists to find. That is why `make stream_parity` runs **two** gates:

- **`stream_parity_dst.ail`** — witness against returned trace. Both sides derive from the returned
  log, so what it tests is that the driver carries **both channels forward on every branch**. The
  trace has ONE junction after the call (`trace_after_call`); the witness is set in **six** branch
  literals. That asymmetry is deliberate and mutant A is its justification. **This is S12's
  identity-transition class arriving on a pair of channels rather than on a world token.**
- **`run_stream_parity_wire.sh`** — the WIRE against the returned trace. The wire is what the
  **callback** projected, during the call, from the chunk the provider handed it; the trace is what
  the **driver** appended afterwards from the log the provider returned. **Two producers, two
  channels, one claim.** It is out of process because the wire is, and that is the honest reason it
  is a shell script rather than an invariant family.

**Neither gate subsumes the other**, and the table above is the evidence rather than the assertion.

**What NEITHER tests, and it is A8's not D6.4's:** whether the mapping itself is right. Both sides of
both gates use `stream_chunk_event`, so a wrong `kind` is invisible to parity by construction. Said
at the site rather than left to be inferred from a green.

## Whether the invariant ran on a real seeded run, and what it said the first time

**Yes, and this is the first time in the project that any D7 family has been evaluated over an
execution a run produced rather than over a constructed fixture.** First run, verbatim:

```
[scripted]  witness=7 trace_stream_records=7 expected=7
[scripted]  all sixteen families over the real run: 1 finding(s) — clock-balance
[recording] witness=7 trace_stream_records=7 expected=7
[recording] all sixteen families over the real run: 0 finding(s)
```

**Parity was green on the first run and stayed green.** The two counts matched at 7 on both subjects,
which is the fixture's own total (4 + 3) and is asserted against it rather than against a literal.

**The one finding is real information and it is attributable.** `clock-balance` is D7 family 11:
`world.clock_ms - initial_clock_ms` against `total_advance_ms(world.log)`. `scripted_ports` advances
the virtual clock through `virtual_clock` and records **no interaction**, so the log cannot account
for the advance. The **recording** adapter, which does record, balances to **zero findings across all
sixteen families**. That is what makes it an adapter property rather than a driver defect, and it is
why two subjects were driven rather than one.

**Both are PINNED, not printed.** The script asserts the exact rule set per subject —
`["clock-balance"]` for scripted, `[]` for recording. A printed count is a number nobody checks; C1
made the same correction one item earlier about prose.

### The third side, and it is the only one with a genuinely independent producer in-process

The recording adapter writes each played chunk into the world's interaction log through
`chunk_records` — a different function, reached through a different channel, from the `emissions` the
exchange returns. So for the recording subject the script asserts the log's chunk texts equal the
witness's **text for text**, and that comparison tests two producers agreeing rather than one channel
threaded twice. **It exists only under the recording adapter** — `live_ports` records nothing into the
world — and the report says so rather than letting the coverage read as general.

## One converter, and the off-by-one it exists to prevent

`stream_chunk_event : (int, string, StreamChunk) -> Option[LedgerEvent]` is the single core. The
`Usage` exclusion and the `thinking`/`reasoning` selection live in exactly one place, used by the
projection (`append_stream_delta`), the trace append, and the witness.

**The trap is real and NO ACCEPTANCE SCRIPT IN THIS TREE CAN REACH IT.** No scripted world plays a
`Usage` chunk, so a witness built by mapping every returned chunk is green on every gate here and
reports `StreamParityCount(N+1, N)` on the first live provider run. It is pinned by a **unit test**
for that reason, and the test asserts the **difference** rather than the count — a row asserting
`== 2` is also green on an implementation that drops the first `ContentDelta` instead. A second row
pins the kind selection separately, because one row over a mixed list cannot say which of the two
things it read.

The two scripted `play_chunks` sites are populated the same way: `play_chunks` now takes
`[StreamChunk]`, each site builds the list **once** and both plays it and reports it. There is one
list and it cannot drift from itself.

## The A1 tripwire fired, and it was right to

`phase_c2_wiring_scenarios`' WI-A1 acceptance asserted `emission_count == 0` and carried this
sentence:

> If this scenario ever starts failing on the emptiness clause, something began populating the log and
> the behaviour-preserving claim needs re-checking.

**It went red on the first `make dst` after the change.** It is recorded here rather than quietly
rewritten, because a pin edited to match whatever the code now does is not a pin. The row now asserts
something **strictly stronger** than the emptiness it replaces — the scripted exchange reports
*exactly* the chunks it played, with the count derived from the fixture — and the scenario is renamed
so the id does not claim the old fact.

**This is the first time in this project that a deliberately-planted tripwire from an earlier item
fired on the item it was planted for.** Worth carrying: the pin cost WI-A1 one line and it caught the
one change it was written about.

## Does the D7 suite still have ONE construction site? **No — two, and only one is a fixture.**

Measured at the end of this item:

| Question | At WI-C1's HEAD | Now |
|---|---|---|
| `ExecutionUnderTest` construction sites | **1** (`invariants_dst.ail:326`, hand-authored, `emissions: []`) | **2** — that fixture, plus `dst_execution.execution_of` |
| Sites that build one from a RUN | **0** | **1** |
| Modules importing `src/core/dst_invariants` | 3 | **4** (`dst_execution` added) |
| Families evaluated over a real run | **0 of 16** | **16 of 16**, on two subjects |

**The fixture is not replaced and should not be.** It reaches shapes a scripted run does not — a
differing `seq`, a trace holding exactly one of two deltas — and a constructed row cannot be made
vacuous by a driver change. The two are complements; per S14 the real-run pair is the one that
certifies the adoption. `invariants_dst`'s header for those rows is corrected, because the sentence it
carried ("no run produces a non-empty emission log today") stopped being true.

**The remaining honest gap: fifteen families now run on a real run because they ride along with
parity, not because anything wires them deliberately.** One script, one profile, two adapters. Wiring
the seeded runners through the bridge is a separate item with its own red surface, exactly as the
handoff scoped it.

## What the driver had to gain, and it is a D6-level change

The handoff named this as a stop-and-report condition. It occurred, and here is what was missing.

`session.c2_finalize` is the sole assembly site of the result/trace/world triple, and the triple
carried **no emission channel**. `ExecutionUnderTest` needs one, and the only value available for it
was `[]` — which on a real run is indistinguishable from a run that streamed nothing.

So `TracedSessionResult` gained `emissions: [LedgerEvent]`, and `C2LoopState` gained the accumulator
that feeds it. **This is reported rather than absorbed**: it is a change to what D6 says a run
returns, it touches 16 loop-state literals and 7 terminal calls, and every one of those is an S12
site where the identity transition type-checks.

**No effect row widened.** `c2_finalize` stays `! {IO, Clock, Trace}`, the callback stays closed
`{IO}`, `live_ports` stays `! {AI, Clock, Env, IO}`. B4's refutation was not engaged and D1's
streaming disposition is untouched.

## Sites where two answers type-checked and one was silently wrong: 3

**Base 45 from C1's report — which corrected the handoff's 39 to B4's 43, plus C1's two. This run
makes it 48. Determinism has still caught none.**

1. **The witness including `Usage`.** Both forms type-check; the wrong one is green on **every gate in
   this tree**, because no scripted world plays a `Usage` chunk, and reports
   `StreamParityCount(N+1, N)` on the first live run. **Caught by the handoff's prose, not by a
   gate** — and it is now pinned by the unit test described above, which is the only thing here that
   can see it.
2. **`emissions: st.emissions` on a post-call branch.** Six branches, both forms type-check, and the
   wrong one is silent under `ailang check`, `check_core` and `driver_only`. Mutant A is the measured
   version: it reddens 5 rows on both subjects — **and only because this item built the gate in the
   same change.** Before `make stream_parity` existed nothing in the tree could see it.
3. **`result_of` mapping a failed run to `RunFailed`.** Both type-check. A provider error is a run
   *outcome*, not a harness failure, and classifying it as one makes
   `satisfies_terminal_trace_contract` **vacuously true for every failed run** — a HarnessFailure
   carries no RunSummary obligation by design. Written correctly and the reason recorded at the site;
   nothing in the tree would have gone red for the wrong answer.

**All three are the same species: a value that is well-formed under both readings and whose wrong
reading makes a check pass.** Two of the three are only visible to instruments this item built.

## Recorded bindings: decided versus discovered

**Discovered — a tool, the compiler or a measurement forced it:**

1. **`StreamDelta` never reached the returned trace.** `ledger_emit` ≠ `ledger_append`. This is the
   finding that resized the item and it falsifies the handoff's model of the trace side.
2. **Both parity sides were empty, not one.** Follows from (1) plus the witness having no producer.
3. **Mutant B is invisible in-process.** Built the wire gate expecting to have to justify it as
   belt-and-braces; it is the only gate that catches a projection disagreeing with the returned log.
4. **The scripted subject reports `clock-balance` and the recording subject reports nothing.**
   Measured on the first run; the difference is what makes it attributable to the adapter.
5. **Six anchors moved, not three, and they moved TWICE.** `make anchors` named them both times.
   `now()` is unique in `stub_step.ail` and `session.ail` has exactly one real `now()` call and four
   `ports.clock_now(` sites — **one candidate each, so no judgement was available**, said plainly
   rather than claimed as a decision. Final: `session.ail` 851→878, 992→1104, 1097→1210, 2365→2521,
   2475→2631; `stub_step.ail` 182→202.
6. **The attribution table's content hash changed twice too**, `e201c1da…` → `426c94af…` →
   `ea292462…`, forcing the `driver_only` v5 → v6 re-issue and then a second re-record of the same
   version. **The cascade is not idempotent across an item**: paying it before the prose edits meant
   paying it again after, and the second payment was found by `make dst` rather than by remembering.
7. **The A1 emptiness tripwire fires**, and `omitted_site()`'s fixture anchor was a *second* consumer
   of the moved line that only the completeness row could see.
8. **The whole-tree sweep needs `AILANG_RELAX_MODULES=1`.** Without it every `packages/**` file fails
   MOD010 and the sweep reads 146/93 instead of 222/17 — a **false red of 76 files**. No prior report
   records the flag; see corrections.

**Decided — a human chose:**

1. **Bridge, not channel.** The item's central decision, and the finding above made it the only one
   that produces anything checkable.
2. **Two gates rather than one**, with the split measured by mutant B rather than asserted.
3. **Both parity sides derive from `exchange.emissions`, and the limitation is written at the site**
   rather than worked around. `SharedMem` was not selected; D1 rejected it and selecting it needs an
   amendment.
4. **The trace has one junction and the witness has six.** The asymmetry is what makes the in-process
   check able to fail at all, so it is deliberate rather than incidental.
5. **Two subjects — scripted and recording** — because the recording adapter is the only one that
   supplies the independent third side, and a single adapter would certify the bridge against the
   adapter it was written with.
6. **`execution_of` takes five bindings as PARAMETERS rather than defaulting them.** Four of the five
   would be silently wrong in the direction that makes a family green; `NoReplay` as a default makes
   family 9 return `[]` unconditionally, which is S8's complement inside the bridge itself.
7. **`result_of` always returns `RunCompleted`** — see two-answer site 3.
8. **The whole-family rule set is ASSERTED per subject, not printed.**
9. **The A1 scenario is strengthened and renamed** rather than relaxed, and its firing is recorded.
10. **The constructed fixture rows in `invariants_dst` are kept**, with their header corrected to say
    why they survive rather than deleting rows that still cover shapes a run does not reach.
11. **`stream_parity` joins `make dst`.** Unlike `recorded_stream` it needs no network and no python
    beyond what is already there.

## Gate state

- **`make stream_parity` — exit 0.** 12 rows per subject across two subjects, plus 6 wire rows.
- **`make dst` — EXIT 2, with the SAME TWO red targets as B4 and C1**, cache-cold:
  - **`test_coverage`** — 3 findings across 2 rules (`failing`, `stale_skip_record`), from
    `src/core/prompts_test.ail`. Pre-existing; B2a measured it deterministic across three runs and
    attributed it to module resolution in `ailang test`.
  - **`test_coverage_selftest`** — `stale_skip_record` on *"Named test blocks not yet implemented"*
    plus a `named_only.ail` finding. Pre-existing.
  - **No other target is red, and `stream_parity` / `recorded_stream` / `invariants` /
    `attribution_table` / `driver_only` / `phase_c_l1` all pass inside the run.**
- **Whole-tree sweep — 222 pass / 17 fail**, cache-cold with S9's command and both exclusions,
  **`AILANG_RELAX_MODULES=1`**. Run TWICE — once mid-item and once after every edit — and the failing
  set is **byte-identical between them and to B4's and C1's**, verified by `diff`. Reasons spot-checked
  and unchanged (`TC_ARITY_001` on the smoke scripts, `IMP010` on the sealed probe). 222 rather than
  220 because `dst_execution.ail` and `stream_parity_dst.ail` are new.
- **0 tracked `.ailang/cache` paths**, verified after a full `make dst` — the condition that put 34
  files in git twice before WI-C1 fixed it.
- **`make anchors` / `attribution_table` / `driver_only` — exit 0** after the v6 re-issue.
- **`make invariants` — exit 0**, register at 13.
- **`make phase_c_l1` — exit 0** after the A1 tripwire was answered.

### Three targets went red DURING this item and all three were the item's own tripwires

Recorded because "no target went red" is what C1 could say and this item cannot:

1. **`phase_c_l1`** — the A1 emptiness scenario. Answered, strengthened.
2. **`invariants`** — the register count pinned at 14 in two places (the acceptance script and a unit
   test in `dst_invariants`). Both are deliberate literals rather than derivations, and **that is
   correct**: a row asserting the register equals itself is green after any edit.
3. **`attribution_table`** — the completeness fixture fired **two** rules instead of one, because
   `omitted_site()` carried a copy of a moved anchor. This is S7's "prove the wrong thing" row doing
   its job, and it is the only thing in the tree that could have seen that second consumer.

## A process near-miss, reported because it nearly cost the item

**`git checkout src/core/session.ail`, used to revert a mutant, reverted the entire item's
implementation.** Recovered from a `cp` backup taken in the same command block seconds earlier;
without it the loss would have been ~90 minutes of threading. **A mutation loop must save and restore
by file copy, never by `git checkout`**, because the working tree is the item and git is the only
copy of the thing before it. Adding this to the mutation-loop discipline S8 already asks items to
budget for.

## Corrections owed to the plan

1. **A whole-tree sweep requires `AILANG_RELAX_MODULES=1`.** Every `packages/**` module declares a
   `sunholo/...` path that does not match its file path, so a bare `ailang check` reports MOD010 on
   all 76 of them. **The unflagged sweep reads 146 pass / 93 fail against the flagged 222 / 17** —
   a false red four times larger than the fifth frontier B4 found. S13 says "sweep the whole tree
   before believing a gate"; it does not say how, and the how matters by 76 files. **Add the flag to
   S13's text.**
2. **`ledger_emit` does not append to the returned trace, and a variant in `d64_gap_register` is a
   variant with NO trace side at all.** Any future item that reads "parity is checked over the
   returned trace" for a registered variant is reading a comparison against an empty list. **Two
   empty sides are green.**
3. **A parity check whose two sides share a producer tests THREADING, not parity** — and the
   distinction is worth 100% of the defect class D6.4 names. Measured: mutant B is green in-process
   and red on the wire. **This generalises past streaming to every "the projection matches the
   record" claim in this project.**
4. **The line-number anchor cascade is not half-avoidable, is not mostly-comment, and is NOT PAID
   ONCE PER ITEM.** C1 refuted the "insert below the anchor" claim with a comment; **WI-C3 refutes the
   rest with a record FIELD and an EXTRACTED FUNCTION**, neither of which has a below-the-anchor
   version — a record's fields have an order, and a converter must be in scope before its caller.
   **Four consecutive items have paid it, and this item paid it TWICE**: the second payment was caused
   by three lines of prose added after the first, and it was found by `make dst` rather than by
   remembering. **Operationally: finish every source edit, including comments, BEFORE running the
   cascade.** Two further consumers exist that no checklist in this project names — the
   `predicate-anchors` script itself, and `attribution_table_dst`'s `omitted_site()` fixture — and both
   were found by a gate rather than by search.
5. **A mutation loop must restore by file copy, not `git checkout`.** See the near-miss above.
6. **A tripwire planted for a future item WORKS, and this is the first evidence.** WI-A1 spent one
   line asserting `emission_count == 0` with a written prediction of what its failure would mean.
   That is a cheaper instrument than anything else in this project's inventory and it should be used
   deliberately rather than as a byproduct.
7. **The counter is 48**, from C1's corrected base of 45.

## Deliberately not done

- **WI-C4, the name gate.** **No target gained the "DST" or "simulation" name.** D10 gates the name on
  the full acceptance table, and B4's `on_budget_plan` argument is untouched by anything here: no
  extension is installable under D5 while that hook carries the ABI's closed `! {Env, FS}` row, so
  `driver_only` still covers nothing *provably*. **C3 going well does not move that**, and the
  acceptance row it does supply is one row.
- **WI-C5** — `proc_exec`/`env_get` widening and the declared-versus-performed detector.
- **The other fifteen invariant families, wired deliberately.** They run over a real run today
  because they ride along with parity in one script, on one profile, with two adapters. Wiring the
  seeded runners through `execution_of` is its own item, and its red surface is unknown — the one
  measurement here is that the scripted adapter already trips `clock-balance`.
- **The extension bridge's emission channel.** `ext_ai_step` still drops `exchange.emissions`;
  closing it needs `ExtPorts.ai_step` widened to carry a chunk log the ABI has no type for. Named at
  the site, narrower than WI-A1's gap, still separate.
- **A partial-stream-then-error seeded run.** `ScriptedStep` has no error channel, so no seed can
  produce a stream that fails part-way. That is now the *only* thing keeping
  `provider_partial_stream_then_error` unreachable by search — the parity half stopped being the
  obstacle — and it is the same one named field as `provider_error_retryable`.
- **The `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.** Unchanged, still owed, still the
  plan's.
