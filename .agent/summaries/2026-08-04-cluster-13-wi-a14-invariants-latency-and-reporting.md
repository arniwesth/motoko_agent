# 2026-08-04 Cluster 13: WI-A14 — D7's invariant set, D4's latency pair, D11 run reporting

## Context

Branch: `arniwesth/mot-51-execute-wi-a13`

Session span: `0dd098f` → `14fffa5`, **4 commits**, three of them production source. Input was
`HANDOFF-execute-a14-invariants-latency-and-reporting.md`, executed cold against HEAD. Thirteenth
code session of project 009, following clusters 1, 4, 6, 3, 2, 5, 7, 8, 9, 10, 11 and 12.

Re-grounding first, as the handoff instructed: `git diff --stat 506a677..HEAD -- src packages scripts
Makefile` was **empty**, so the handoff's verified-input table held without re-measurement.

**Full completion of all three mission pieces. WI-A15 is unblocked.** Two assigned sub-items are
explicitly not done and are carried with owners.

| | |
|---|---|
| Piece 1 — the D7 invariant set | **landed, green** |
| Piece 3 — D11 run reporting | **landed, green** |
| Piece 2 — D4's latency pair | **landed, green** |
| The `ScriptedStep` latency widening | **not done** — and not needed for D4, see below |
| `max_resource_size` | **decided and sized**, not coded — owner A15 |

## What landed

| Commit | Item | Gate |
|---|---|---|
| `00dbdb4` | **D7's twelve invariant families**, the discovery contract, and D6.4's gap closed by one | `make invariants` (new) |
| `ea81e66` | **D11's run report** — the two counters, the evidence kinds, the CI replay affordance | `make run_report` (new) |
| `3dd8a82` | **D4's latency pair** on the tool class, with the branch shown taken | `make latency_pair` (new) |
| `14fffa5` | cluster report, three plan corrections, two ADR amendments | note + plan + ADR |

Five new files: `src/core/dst_invariants.ail` (1876), `src/core/dst_run_report.ail` (894),
`scripts/dst/invariants_dst.ail` (1075), `scripts/dst/run_report_dst.ail` (610),
`scripts/dst/latency_pair_dst.ail` (565). Modified: `Makefile` (+~200, three targets),
`src/core/dst_event_vocabulary.ail`, `src/core/session.ail` (+22/−14, one terminal path). 6036
insertions, 36 deletions.

**`make dst` exits 0** on the committed tree, read as an exit status — **551 checks** against 466 at
the item's start (487 after piece 1, 528 after piece 3). The single `✗` in the log is the
`✗ Failed: 0` summary label of a passing `ailang test` run, checked rather than assumed.
`make check_core` exits 0, **50 modules** (48 before). A5 anchors verified intact at start and end
(`src/core/test/stub_step.ail:161`, `session.ail` 948/1053/2290/2400); `driver_only` stays at **v3**.

## The order the work took

The handoff's suggested order was invariants → reporting → latency pair, on the premise that the pair
needs a world-input widening. **The order was kept and the premise turned out to be wrong** — see
correction 1 — which cost nothing, because the pair was cheaper than budgeted rather than harder.

1. **Grounding**, ~15 minutes: the cluster-12 note, the plan's standing rules, D4/D6/D7/D8/D11, and
   the export surface of nine DST modules. Baseline closure check (19 modules, 11 s) and the A5
   anchors read before the first edit.
2. **The invariant assertions landed BEFORE the change they guard (S1).** `dst_invariants` was
   written with the parity register asserting the closed state, went **red for the right reason**
   (`parity-gap-register-missing` for `DoneEvent`), and the driver change made it green.
3. **`session.ail`'s terminal path**, sized line-count-neutral so the anchors below it did not move.
4. **The acceptance suite**, then 30 mutants; two escapes repaired (sites 25 and 26).
5. **Piece 3 whole**, then 13 mutants and 6 Makefile-guard mutants.
6. **Piece 2 whole**, then 6 mutants including two against the wire witness.

## The three decisions the item owned

### `DoneEvent` — resolved, and the resolution was free

WI-A8 recorded the tension and could not settle it: **D6.3** requires outcome, `DoneEvent` and
`RunSummary` to *agree* — an invariant over content, which `DisplayOnly` denies — while **D6.1**
requires the summary to be the *final* record, and the driver projected the `DoneEvent` after
`c2_finalize` had appended it.

**The unlock is one clause nobody had read as load-bearing: D6.4's obligation is PARITY, not a shared
transition.** That licenses separating the append from the projection at the single site where the
two obligations conflict. The `Finalize` arm now appends the `DoneEvent` **before** `c2_finalize` and
projects it **after**, unchanged — so D6.4, D6.1, D6.3 and D8's wire order all hold at once.

**The alternative is worth recording because it is the one-line wrong answer in its most tempting
form**: classifying it `DisplayOnly` would not merely make D6.4 vacuous for it, it would make **D6.3
unstatable**, since "display-only … cannot change invariant results" and D6.3 is an invariant over
precisely this event's content.

**And A8's separation paid a dividend nobody predicted.** Closing the gap did **not** bump
`event_vocabulary_version` — D8 versions a change to a variant, a wire name, a payload schema or a
**classification**, and `reaches_trace_today` is none of those four. Folded into the classification,
closing a parity gap would have been a compatibility event requiring a decoder for every old trace.
**Keeping a measurement out of a versioned artifact is worth more than it looks.**

### The coordinate-independent A5 anchor — do not build it

Fifth data point, and it runs against the case. Piece 1 edited `session.ail` **above** two anchors —
the case clusters 8 and 10 both paid a five-artifact cascade for — and paid **zero**, by sizing the
replacement to the same line count (twelve for twelve). The comment block was going to be rewritten
anyway; making it seven lines instead of five was free.

**The cascade correlates with adding a `StepProvider` VARIANT, not with editing near an anchor** — a
variant forces a match arm that cannot sit below the sites it precedes, which no anchoring scheme
fixes because the *code* has to move. Recommendation to A15: don't build it; revisit only when an
item must add a variant.

### `max_resource_size` — decided and sized, not coded

The handoff framed it as "give it a resource that can grow, or delete it". **Both are more expensive
than that implies.** Deleting is a schema change specifically because `bounds` encodes as a
five-field line with `required_header_tags()` declaring arity 5, and both frozen specimens carry
`bounds\t18\t19\t4096\t21\t22` — so the decoder would **refuse them**.

**But the decisive argument is not cost: D2 requires five declared bounds**, and deleting the fourth
makes the set 4 of 5 — a specification regression wearing a cleanup's clothes. So keep it and rebind
it to a resource that grows — which changes when `choose_environment`'s bounded alternative fires,
which changes the draw stream, which is a **generator-version bump with a canary re-pin**. Owner
**A15**, which already re-pins seeds.

## Three corrections to the plan

1. **D4's latency pair does NOT need the `ScriptedStep` widening, and the plan said it did** — in A13
   stage 4's scope note, in WI-A14's item 2, and in cluster 10's correction 2. The pair needs a class
   with a **latency channel**, a **declared deadline** and a **comparison**; the **tool** class has
   had all three since WI-A12. The **provider** class has none, so the widening closes D2's generator
   completeness gap and not D4's. **The two obligations are separable and only the first is met.**
2. **Provider FAULT and provider LATENCY are different fields.** The plan says "both one field away
   (`advance_ms`)" — right for the latency, wrong for the fault, which is delivered on the `AIError`
   path and needs an **error case**. The handoff's piece-3 table inherited this and listed the
   provider class as reachable once piece 2 landed; it would not have been.
3. **D7 has twelve families; the sizing basis said eleven.** `make invariants` now counts the
   declared `InvariantFamily` variants against `all_families()`, so it is checkable.

## Sites 25, 26 and 27 — two type-checking answers, the wrong one silent

**Twenty-seven across thirteen clusters. Determinism has caught none of them.** All three were found
by mutating something and reading *why* a row went red.

- **Site 25 — the stream-parity check compared TAGS, not content.** D6.4's *named exception* requires
  the projected sequence and the returned log to match "in order and content", and
  `ledger_event_key` **had no `StreamDelta` arm** — it fell through a `_ => "<opaque>"` catch-all, so
  every delta hashed identically. The count, omission and duplicate rows were all green; a
  **reordering** produced **no finding at all**. Cluster 12's site 24 recurring one level up: the
  right quantity, insufficient alone, visible only to a case constructed to defeat it.
- **Site 26 — a mutant green on the wrong rule.** The retry-bound mutant appended its record *after*
  the `RunSummary` and tripped `record-after-terminal`. Caught **only because the row names the rule
  it expects**; a row asserting "some finding" would have been green and the retry bound would have
  had no instrument.
- **Site 27 — the terminal-outcome row cannot see a lost latency.** Mutating `dst_replay.tools_of` to
  reconstitute durations as `0` makes the slow half replay as a **completion**. Three rows red, and
  **`the replay reproduces the terminal outcome` stays green** — the run still ends `Ok`, so the axis
  A13 stage 3 added is blind to a fault class replaying as a success.

## What the mutation testing found that the gates did not

**Twelve mutants across the three pieces, twelve caught after the three repairs.** Six are Makefile
guard mutants, and one exposed a defect in a guard written minutes earlier:

| Mutant | Result |
|---|---|
| `all_families()` / `all_reach_ids()` / `sample_violations()` lose a member | caught |
| **`sample_rejections()` loses the NULLARY `SeedWindowEmpty`** | **caught only after the guard was rewritten** |
| `replay_command` names a non-existent entry point | caught |
| the entry point exists but reports no successful load | caught |
| `world_tool` drops the "a deadline was declared" conjunct | caught **by the control world alone** |
| the wire witness: none fault / all fault | caught |

**The nullary case is the finding.** Both structural guards originally *counted* constructors with
`grep -oE '[A-Z][A-Za-z]+\('`, which **misses every constructor without arguments** — `make
run_report` went red reporting 12 against 13, correct for the wrong reason. Both were rewritten to
check **membership by name**, which is strictly stronger: a count is also satisfied by sampling one
constructor twice and omitting another.

## Sizing

**Seventeen recorded bindings — twelve decided, five discovered.** Per piece: invariants 7 (4, **3**),
run report 6 (4, **2**), latency pair 4 (4, **0**).

**Cost: 78 minutes on the git wall clock** (`0dd098f` → `3dd8a82`), split **56 / 12 / 10**.

**The discovered count predicts and the total does not, for the third consecutive measurement, and
this is the widest spread yet.** Totals of 7, 6, 4 predict roughly 56 : 48 : 32; measured is
**56 : 12 : 10**. No felt ratio is offered beside these — cluster 12 measured that contemporaneous
ratios over-report by 2–3× wherever the cost is deliberation, and every piece here was deliberation.

**And a finding for S6's FIRST term rather than its second: grounding is paid PER SESSION, not per
piece.** Piece 3 — a new module, a new acceptance script, a make target with three structural guards,
thirteen mutation rows — cost **twelve minutes**, the cheapest composition this project has measured,
because piece 1 had already read every input it needed. **That argues for cutting items by SHARED
INPUTS rather than by obligation**, the same shape as cluster 12's finding that stage 6 was two pieces
sized as one.

**Round trips: 5 compiler, 2 gate, 3 silent.** The compiler five: **`channel` and `timeout` are
reserved words** on the pin and produce a `PAR_NO_PREFIX_PARSE` pointing at the *next* token rather
than at the identifier; `++` is list-only for strings; an anonymous record type in return position
does not parse across lines; `ExtRuntime` is exported by the ABI types module, not by
`src/core/ext/runtime`.

**Judgement ratio (undetermined fraction):** the invariant set **~70%** — D7 gives twelve one-line
bullets and specifies no shape at all; the surviving fixture ~35%; the run report **~40%, the lowest
machinery figure in the project** — D11 gives the field list, the two-counter rule *and* the seed
window's failure modes explicitly, and is the one decision that reads like a specification rather than
a delegation; the documented register ~25%; the latency pair ~30%; **its three numbers ~15%, the
lowest content figure recorded** — they are forced by one inequality (the deadline must lie strictly
between the two latencies), and the suite asserts it.

**Estimate versus measurement: 3–5 days against 78 minutes.** The basis priced the *width* of the
family set. The cost was three discovered bindings in one piece; the twelve families were
transcription once their shape was decided.

## An AILANG defect, reproduced and filed

**`ailang test`'s cluster harness fails a passing test NON-DETERMINISTICALLY** — 6 runs in 10 — with
`harness evaluation failed: harness evaluation failed: record has no field: site`, naming a field of
`dst_profile.CoreSite`, which is in the transitive closure and which the assertion never touches. The
same call under `ailang run` is stable over every trial, as are the callee's own inline tests.

`.agent/issues/ailang-test-cluster-harness-bogus-record-field-error.md`. **Filed upstream as
`fb_2ad074d754cd2c25`**, unminimised, after an independent re-reproduction at the same 6-in-10 rate —
the workaround had removed the trigger from the tree, so it was re-created, measured again and the
source restored. **Two independent 6-in-10 measurements is what made it worth filing without a
minimal case**: the rate is itself evidence, and the nested "harness evaluation failed" gives the
harness owner a lead that does not require our closure.

**The workaround is an improvement on its own terms**, which is why it was taken without more
digging: the assertion moved out of `tests` into the acceptance script where it is deterministic, and
the conjunction it lived in was split into one row per fact. **A flaky gate is worse than a red one —
it trains the reader to re-run rather than to read.**

The `let`-binding workaround for `fb_e44ba922db1c42be` (a call in a record-update field position is
not registered as a dependency) was needed again at **ten sites** in `run_report_dst.ail`, making it
the most frequently-hit of the three filed defects.

## Two patterns worth carrying

**The shrink-only register, now used twice.** `d64_gap_register()` and `documented_coverage()` are the
same shape: a declared gap asserted equal to a derived truth in **both** directions, so it can only
shrink and closing an entry is forced to be recorded. It is what makes "the fifteen are the work, not
the answer" executable rather than exhortative.

**S8's third form: the CONTROL that tests the "except".** The latency pair discharges both known S8
halves by assertion — the two world inputs compared field by field (decorative path), the deadline
asserted to lie strictly between the two latencies (unwalked branch). Neither can see whether latency
reaches the outcome *around* the comparison. A **third world** — same 3000 ms latency, no declared
deadline, must complete — can, and dropping `world_tool`'s `inv.timeout_ms > 0` conjunct reddens that
control and nothing else. **Cheaper than either half, and the only thing that tests the word
"except".**

## Carried forward

**To A15** — the counters exist and are validated but **nothing has fed them from a real sweep**;
`documented_coverage()` is explicitly a declared register and the corpora replace it with
observations. Key on `artifact_identity`: the latency pair is a worked example, its halves differing
in one integer and producing two different identities where a `(id, version, seed)` key would have
filed them as one. `max_resource_size` is a generator-version item. And `make dst` grew three targets
this cluster, which is the baseline A15 measures CI cost against.

**Not done, both unblocked** — the `ScriptedStep` latency widening (predicted **zero** A5 cost,
source-derived: `session.ail` references `[ScriptedStep]` as a type at 2656/2677 and constructs none;
28 literal sites elsewhere — but that is a prediction, not the fourth data point the handoff wanted),
and `max_resource_size`'s implementation.
