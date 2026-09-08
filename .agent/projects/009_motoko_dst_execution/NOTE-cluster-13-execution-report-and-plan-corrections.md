# Cluster 13 execution report — WI-A14

Thirteenth calibration run. **All three mission pieces landed, green and committed.**

Commits:

- `00dbdb4` feat(A14): piece 1 — D7's invariant set, and D6.4's gap closed by one
- `ea81e66` feat(A14): piece 3 — D11's run report, and three unreached classes kept apart
- `3dd8a82` feat(A14): piece 2 — D4's latency pair, on the class that has a deadline

**`make dst`: exit 0** — read as an exit status — at **551 green checks**, against 466 at the
item's start. **`make check_core`: exit 0**, 50 modules (48 before this item). The single `✗` in the `dst` log is the `✗ Failed: 0`
summary label of a passing `ailang test` run, checked rather than assumed.

No source drift at session start (`git diff --stat 506a677..HEAD -- src packages scripts Makefile`
was empty).

**A5 anchors undisturbed.** `src/core/test/stub_step.ail:161` and `session.ail`'s 948/1053/2290/2400
verified intact at start and end; `driver_only` stays at **v3**. Piece 1 changed a terminal path in
`session.ail` and the edit was sized **line-count-neutral on purpose** — twelve lines replaced by
twelve — so the two anchors below it did not move. That is the first time this project has paid the
anchor cost by *counting lines* rather than by writing below them, and it worked.

---

## The three decisions this item owned

### 1. `DoneEvent` — RESOLVED, and the resolution was free

WI-A8 recorded the tension and could not settle it: **D6.3** requires the returned outcome, the
`DoneEvent` and the `RunSummary` to *agree* — an invariant over content, which `DisplayOnly` denies
— while **D6.1** requires the `RunSummary` to be the *final* record, and the driver projected the
`DoneEvent` *after* `c2_finalize` had appended the summary. Both cannot hold by **appending it where
it is emitted**.

**What makes the resolution free is one clause nobody had read as load-bearing: D6.4's obligation is
PARITY, not a shared transition.** The decision says so in as many words, and names streams as the
case where a shared transition is impossible by construction. So the append and the projection are
*separated at this one site*: `session.ail`'s `Finalize` arm now appends the `DoneEvent` **before**
`c2_finalize` and projects it **after**, unchanged.

Four obligations hold simultaneously where three could not before:

| | |
|---|---|
| D6.4 | a Logical event reaches the returned trace |
| D6.1 | the `RunSummary` is **still** the final appended record |
| D6.3 | agreement is now decidable over the returned trace **alone** |
| D8 | the wire still carries `run_summary` before `done` — **no compatibility surface moves** |

**The alternative was refused for a reason worth recording**, because it is the one-line wrong answer
in its most tempting form: classifying `DoneEvent` as `DisplayOnly` would not merely make D6.4
vacuous for it — it would make **D6.3 unstatable**, since `DisplayOnly` means "cannot change
invariant results" and D6.3 is an invariant over precisely this event's content.

**And the separation A8 insisted on paid a dividend nobody predicted.** Closing the gap did **not**
bump `event_vocabulary_version`. D8 makes a change to a variant, a wire name, a payload schema or a
**classification** a version change; `reaches_trace_today` is none of those four. Had the survey been
folded into the classification — the "tidier" artifact — closing a parity gap would have been a
compatibility event requiring a decoder for every old trace. **Keeping a measurement out of a
versioned artifact is worth more than it looks, and this is the demonstration.**

### 2. The coordinate-independent anchor for A5's table — NOT BUILT, and the evidence now runs the other way

The handoff said the evidence was four stages deep and it was this item's call. **It is now five, and
the fifth is the strongest argument yet for NOT building it.**

Piece 1 changed `session.ail` **above** two anchors — the case cluster 8 and cluster 10 both paid a
five-artifact cascade for — and paid **nothing**, because the replacement was sized to the same line
count. The comment block being rewritten was going to be rewritten anyway; making it seven lines
instead of five was free.

So the running score is:

| | Cost |
|---|---|
| A13 stages 3, 4, 5, 6 — wrote *below* the anchors | zero |
| **A14 piece 1 — wrote ABOVE an anchor, line-count-neutral** | **zero** |
| Stage 2, cluster 10 — added a `StepProvider` **variant** | a `driver_only` re-issue each |

**The cascade correlates with adding a VARIANT, not with editing near an anchor**, and a variant
forces a match arm that cannot sit below the sites it precedes — which no anchoring scheme fixes,
because the *code* has to move. A symbol-plus-digest anchor would have cost this item real work and
saved it nothing. **Recommendation to A15: do not build it. Revisit only if an item must add a
`StepProvider` variant, and then price the anchor against that one item's cascade.**

### 3. `max_resource_size` — RESOLVED as a decision, NOT as code, and the reason is that it is not a one-liner

The handoff framed this as "give it a resource that can grow, or delete it". **Both options are more
expensive than that framing implies, and grounding them changed the answer.**

**Deleting it is a schema change, and specifically this one.** `bounds` is encoded as a five-field
tab-separated line with `required_header_tags()` declaring `{ tag: "bounds", arity: 5 }`, and both
frozen specimens carry it — `bounds\t18\t19\t4096\t21\t22`, where `21` is `max_resource_size`.
Dropping the field takes the arity to 4 and the decoder then **refuses the frozen v0 and v1
specimens**, which is exactly the event D8's schema-version rule governs. So deletion costs a schema
version *plus* a decode path for the old form, *plus* the compatibility-policy row that proves it.

**And deletion is wrong on the merits, which is the decisive argument and is not the cost argument.**
D2 requires five declared bounds — interactions, stream chunks, payload bytes, **logical-resource
size**, and clock advancement. Deleting the fourth makes the declared set 4 of D2's 5. That is a
specification regression wearing a cleanup's clothes.

**So: keep the bound, rebind it to a resource that grows — and that rebinding is a GENERATOR-VERSION
change.** `max_resource_size` is consulted inside `choose_environment`, whose bounded alternative
drops an entry and calls `note_bound`. Rebinding it to a quantity that grows with the trajectory
changes when that alternative is taken, which changes the draw stream, which is precisely what D8
requires a generator-version bump for and what stage 5's canary exists to catch. Re-pinning
`pinned_canary_v1`/`v2` is part of the work, not an afterthought.

**Named owner: A15**, which already re-pins seeds for its corpora and is the cheapest place to absorb
a version bump. **This is a deferral with a named owner and a sized reason, not a resolution** — and
the sizing is the contribution: it is a generator-version item, not a field edit.

---

## What landed

### Piece 1 — the D7 invariant set (`00dbdb4`)

**`src/core/dst_invariants.ail`**, new — `InvariantFamily` (12, each carrying D7's own words),
`Violation` (**37 constructors, one per rule**), `ExecutionUnderTest`, the twelve family functions,
`family_evidence`, and D7's thirteenth statement (the discovery contract) over a **pair** of
executions. **`scripts/dst/invariants_dst.ail`**, new — one surviving fixture, S7 both halves
executable, 30 single-field mutants. **`make invariants`**, wired into `make dst`.

**The parity family is decided rather than made vacuous, and the defence is three-sided:**

1. `display_only_baseline()` pins the six display-only variants **by name**. The one-line wrong
   answer — reclassify the gap as `DisplayOnly` — turns `display-only-set-changed` red.
2. `d64_gap_register()` is asserted **equal to `logical_variants_not_in_trace()` in both
   directions**, so the register may only **shrink**; closing a gap without recording it is
   `parity-gap-register-stale`.
3. `parity_findings` asserts over a real returned trace that every record in it is a **Logical**
   variant — the runtime half, and the one D6.4 calls authoritative.

**Each of the remaining fourteen gaps carries a reason** (`parity_gap_reasons()`), because D3's rule
for a waived fault class applies to a parity gap: one recorded without its reason is a name nobody
can plan against. The reasons are not uniform and that is the point — `StreamDelta` is **externally
blocked** (Milestone B), `CostExhausted` and `Dp7VerifierRejected` are **unblocked one-line
appends**, nine are **inside the tool dispatch fold** (where the remaining bulk lives), and
`ScratchpadResult`/`ExtToolHandled` are **unreachable under `driver_only`**.

The sharpest single line in that register: **`ThinkingStreamStart` reaches the trace and
`ThinkingStreamEnd` does not.** The same code path appends one bracket and projects the other.

### Piece 3 — D11's run report (`ea81e66`)

**`src/core/dst_run_report.ail`** and **`scripts/dst/run_report_dst.ail`**, new; **`make
run_report`**, wired in.

**The two counters are separate, and the suite proves they CAN disagree** rather than merely
reporting two numbers: a report that reached every fault class and executed no recovery branch fails
on `required-branch-not-reached` and **not** on a class rule. A merged counter is green on exactly
the report D11 says is not the coverage the acceptance test asks for.

**Not-reached is four facts and a waiver is a fifth**, each its own constructor with a reason.
`D3`'s `NoReachableBranch` travels into the branch counter **as** a structural gap carrying the
catalogue's own text, rather than being flattened to "not covered" — which would demand coverage of
something the artifact says does not exist and leave the report permanently red for a reason no seed
can fix.

**D8's CI replay affordance is real, not illustrative.** `replay_command` names
`--entry replay_artifact`, that entry point **exists**, and `make run_report` **runs it** against the
frozen v1 specimen and requires the load to report the specimen's own identity. A command naming an
entry point nobody wrote satisfies every AILANG-side check while being unpasteable: the
reporting-layer twin of the digest-without-retained-bytes D8 forbids outright. **The first draft had
exactly that defect** — it named `strict_replay_dst.ail --entry replay`, which does not exist.

### Piece 2 — D4's latency pair (`3dd8a82`)

**`scripts/dst/latency_pair_dst.ail`**, new; **`make latency_pair`**, wired in. Two worlds identical
but for one integer, run through the **real driver**: 40 ms and 3000 ms against a 1000 ms deadline
read through the env class.

**The branch is shown taken, not inferred from the outcome.** Both operands of `world_tool`'s
comparison are read off the recorded interaction — the deadline (1000 in both) and the advance (40
and 3000) — so each half is shown to sit on its own side of the comparison rather than merely to
have produced a different answer.

**And S8's "except through the mechanism" is executable.** A **third** world carries the *same*
3000 ms latency with **no declared deadline**, and must COMPLETE. `world_tool`'s guard is
`inv.timeout_ms > 0 && duration > timeout`; if a 3000 ms tool faulted with no deadline in force,
latency would be reaching the outcome *around* the comparison and the pair would be measuring
duration rather than lateness. **Nothing else in the file can see that.**

Both programs replay deterministically, and the reconstituted tool queue is asserted to **carry the
latency back** — see site 27 below for why that row is not redundant.

---

## Correction 1 — D4's latency pair does NOT need the `ScriptedStep` widening, and the two obligations are separate

**The handoff, the plan (WI-A13 stage 4's scope note, and WI-A14's item 2) and cluster 10's
correction 2 all state or imply that A14's latency pair and the deferred provider-latency widening
are the same work. They are not.**

D4's pair needs a class with three things: a **latency channel**, a **declared deadline**, and a
**comparison** between them. The **tool** class has had all three since WI-A12 —
`ScriptedTool.duration_ms`, `ToolInvocation.timeout_ms` read through the env class at
`tool_phase.ail:343`, and `world_tool`'s guard. The pair is buildable today and piece 2 builds it,
touching no world-input type.

The **provider** class has **none** of the three. Widening `ScriptedStep` gives it a latency channel
and closes cluster 10's declared D2 gap — the generator chooses "a compatible response, fault, and
latency" and chooses only the response on that class. That is a real obligation. **It is not D4's:**
a provider latency with no provider deadline still has no completion-versus-timeout behaviour to
demonstrate.

**Consequence for the plan:** WI-A14's D4 acceptance evidence is met without the widening, and the
widening is a **separable item** that belongs with the generator's D2 completeness rather than with
D4. It is **not done** — see "What is not done" below.

## Correction 2 — the plan's own sentence conflates provider FAULT with provider LATENCY, and they are different fields

`dst_generator.ail`'s scope note and the plan both say the provider fault and the provider latency
are **"both one field on `ScriptedStep` away (`advance_ms`)"**. That is right for the latency and
**wrong for the fault**: a provider fault is delivered on the `AIError` path, so `ScriptedStep`
needs an **error case**, not an advance. Two fields, two changes.

The handoff's piece-3 table inherits this — it lists "the provider fault class" as reachable "once
piece 2 lands". It would not have been. `dst_run_report`'s `documented_coverage()` records the
provider classes as `unreachable-until-change` with the corrected reason.

## Correction 3 — D7 has TWELVE families, and the plan's sizing basis says eleven

The plan sizes WI-A14 on "eleven D7 invariant families over an existing trace ADT". D7's bullet list
is **twelve**, and `make invariants` counts the declared `InvariantFamily` variants against
`all_families()` so the number is now checkable rather than transcribed. Minor, but it is the kind of
off-by-one that a hand-written set is supposed to stop.

---

## Sites 25, 26 and 27 — three type-checking answers with a silent wrong one

**Twenty-seven across thirteen clusters. Determinism has caught none of them.** All three below were
found by mutating something and reading **why** a row went red — never by running a gate.

### Site 25 — the stream-parity check compared TAGS, not content

`stream_parity_findings` discharges D6.4's **named exception**: "the projected sequence and the
returned emission log must match exactly in **order and content**". Its comparison key is
`"${event_variant_id(e)}|${ledger_event_key(e)}"`, and `ledger_event_key` **had no `StreamDelta`
arm** — it fell through the `_ => "<opaque>"` catch-all.

So every delta hashed to the same key. The **count** row was green, the **omission** row was green,
the **duplicate** row was green — and a **reordering** produced **no finding at all**, as would any
content drift. A suite without the reordering row would have been fully green on a stream-parity
check that certifies nothing about either order or content.

This is cluster 12's **site 24 recurring one level up**: the right quantity, insufficient on its own,
and only visible to a case constructed specifically to defeat it. The catch-all is what made the
wrong answer type-check.

### Site 26 — a mutant green on the wrong rule

The retry-bound mutant appended a `StreamErrorRetry` record **after** the `RunSummary`, and tripped
`record-after-terminal` instead of `retry-bound-exceeded`. It was caught **only because the row names
the rule it expects** — a row asserting "some finding" would have been green, and the retry bound
would have had no instrument behind it.

This is the fourth time C5's "each row asserts its own rule" has paid, and it is still the cheapest
rule in the project. (The placeholder also constructed the *wrong event type* — a `CompactionExhausted`
where the counter reads `StreamErrorRetry` — which the same row caught.)

### Site 27 — the terminal-outcome row cannot see a lost latency

Mutating `dst_replay.tools_of` to reconstitute tool durations as `0` instead of from
`TimedOutcome.advance_ms` makes the **slow half replay as a completion**. Three rows went red and
**one stayed green**, and the green one is the instructive part:

```
✗ slow: the exact program replays to an identical interaction log
✗ slow: the reconstituted tool queue carries the latency back
✓ slow: the replay reproduces the terminal outcome        ← still green
```

The run still ended `Ok`, so the terminal-outcome axis — which A13 stage 3 added precisely because
"a replay that reproduced every request and then failed differently has not reproduced the run" — is
**blind to a fault class being replayed as a success**. The dedicated latency row is not redundant
with it; it is the only row that names the quantity.

---

## What the mutation testing found that the gates did not

**Twelve mutants across the three pieces, twelve caught after the three repairs above.** Six of them
are Makefile guard mutants and are worth naming because one exposed a defect in a guard I had just
written:

| Mutant | Result |
|---|---|
| `all_families()` loses a family | caught |
| `sample_violations()` loses a constructor | caught |
| `all_reach_ids()` loses `Waived` | caught |
| **`sample_rejections()` loses the NULLARY `SeedWindowEmpty`** | **caught — but only after the guard was rewritten** |
| `replay_command` names a non-existent entry point | caught |
| the entry point exists but reports no successful load | caught |

**The nullary case is the finding.** Both new structural guards originally *counted* constructors
with `grep -oE '[A-Z][A-Za-z]+\('`, and that regex **misses every constructor without arguments**.
`make run_report` went red on its first run reporting 12 against 13 — correct, for the wrong reason.
Both guards were rewritten to check **membership by name**, which is strictly stronger anyway: a
count is also satisfied by sampling one constructor twice and omitting another.

---

## Sizing — S6 per piece, and the discovered count predicts again

**Recorded bindings: seventeen — twelve decided, five discovered.**

**Piece 1, the invariant set (7: 4 decided, 3 discovered).**

1. *Decided.* **The parity family MEASURES, and a shrink-only register is what stops it going
   vacuous.** Readable off D6.4 and A8's header with both open.
2. *Decided.* **`DoneEvent`: append before, project after** — turns on D6.4 saying *parity*.
3. *Decided.* **The discovery contract is not a thirteenth family.** It needs two executions; a
   family that passed whenever it had one would be S8's complement inside the invariant set.
4. *Decided.* **The fixture is constructed, not swept** (cluster 12's limit).
5. *Discovered.* **Site 25.**
6. *Discovered.* **Site 26.**
7. *Discovered.* **The AILANG cluster-harness non-determinism** (below). This one cost the most of
   the three, because a 6-in-10 failure rate makes every single trial uninformative.

**Piece 3, the run report (6: 4 decided, 2 discovered).**

1. *Decided.* `ReachStatus` is a sum with four non-reached variants and a waiver.
2. *Decided.* Both coverage lists derived from the catalogue, never written out.
3. *Decided.* `NoReachableBranch` becomes a structural gap, not a coverage miss.
4. *Decided.* The report does **not** claim a measured number; `documented_coverage()` is declared
   and labelled as such in the rendered output.
5. *Discovered.* **The replay command named an entry point nobody wrote** — visible only on reading
   the rendered output and asking whether it could actually be pasted.
6. *Discovered.* **The count-based guard misses nullary constructors.**

**Piece 2, the latency pair (4: 4 decided, 0 discovered).**

1. *Decided.* **The pair belongs on the tool class** — correction 1.
2. *Decided.* **Read both operands off the record**, do not infer the branch from the outcome.
3. *Decided.* **The S8 control is a third world**, not a comment.
4. *Decided.* **The wire witness is COUNTED, not grepped for presence** — presence is satisfied by a
   world that faults everything.

### Cost, as the git wall-clock window

| Piece | Window (handoff → commit, then commit → commit) | Bindings (decided / discovered) |
|---|---|---|
| 1 — invariants | **56 min** | 7 (4 / **3**) |
| 3 — run report | **12 min** | 6 (4 / **2**) |
| 2 — latency pair | **10 min** | 4 (4 / **0**) |

**Whole item: 78 minutes** on the clock, handoff `0dd098f` to `3dd8a82`.

**The discovered count predicts and the total does not, for the third consecutive measurement, and
this is the widest spread yet.** Totals of 7, 6 and 4 predict roughly 56 : 48 : 32; the measured
windows are **56 : 12 : 10**. Discovered counts of 3, 2 and 0 order them correctly and get the shape
roughly right. Cluster 12's refinement to S6's second term survives a third data point.

**No felt ratio is offered beside these**, and that is deliberate: cluster 12 measured that a
contemporaneous ratio over-reports by two to three times wherever a piece's cost is deliberation, and
every piece here was deliberation. The clock is the checkable number.

**And piece 3 is the cheapest composition this project has measured** — twelve minutes for a new
module, a new acceptance script, a new make target with three guards, and thirteen mutation rows.
The reason is legible and it is S6's *first* term rather than its second: **piece 1 had already read
every input artifact piece 3 needed.** The catalogue, the profile, the persistence store and the
discovery witness were all open. Grounding is paid **per session, not per piece**, and an item whose
pieces share inputs pays it once — which is an argument for cutting items by *shared inputs* rather
than by obligation, and it is the same shape as cluster 12's finding that stage 6 was two pieces
sized as one.

### Round trips

**5 compiler, 2 gate, 3 silent.**

- **Compiler (5).** `channel` and `timeout` are **reserved words** on the pin and produce a
  `PAR_NO_PREFIX_PARSE` pointing at the *next* token rather than at the identifier; `++` is list-only
  for strings; an anonymous record type in return position does not parse across lines; `ExtRuntime`
  is exported by the ABI types module and not by `src/core/ext/runtime`.
- **Gate (2).** The nullary-constructor guard, and the first `make invariants` run.
- **Silent (3).** Sites 25, 26, 27. **Determinism caught none** — 27 sites, 13 clusters, 0-for-27.

### Judgement ratio, split, per piece

(The figure is the *undetermined* fraction.)

- **Machinery, the invariant set: ~70%.** D7 gives twelve one-line bullets and specifies **no shape
  at all** — not what an invariant is evaluated over, not what a violation carries, not how a family
  reports. The determined part is the list of twelve.
- **Content, the surviving fixture: ~35%.** Down from a naive estimate because the coverage
  requirement is **read off** `all_interaction_kinds()`, the outcome-status set, the three
  `LedgerRecord` constructors and the three tool fault classes. What was left to judgement is which
  eleven quantities go in the distinctness set — and *that* list is the interesting artifact, because
  S7 asks for two different things (every shape PRESENT, no two quantities EQUAL) and conflating them
  produces a fixture bloated with sixteen environment reads for no reason.
- **Machinery, the run report: ~40% — the lowest in the project.** D11 gives the field list
  explicitly *and* the two-counter rule explicitly *and* the seed-window failure modes explicitly.
  This is the one decision in the ADR that reads like a specification rather than a delegation.
- **Content, the documented register: ~25%.** Transcribed from the cluster reports and D3's own
  coverage gaps.
- **Machinery, the latency pair: ~30%.** D4 states the experiment almost operationally, and
  `world_tool` supplies the mechanism. What is undetermined is *how to show the branch was taken*,
  which is where the whole design effort went.
- **Content, the three numbers: ~15% — the lowest figure this project has recorded.** They are
  forced: the deadline must lie strictly between the two latencies, which is one inequality, and the
  suite asserts it.

---

## An AILANG defect, written up

**`ailang test`'s cluster harness fails a passing test NON-DETERMINISTICALLY** — six runs in ten —
with `harness evaluation failed: record has no field: site`, naming a field of `dst_profile.CoreSite`
which is in the module's transitive closure and which the assertion never touches. The same call
under `ailang run` is stable over every trial, as are the callee's own inline tests.

Written up in `.agent/issues/ailang-test-cluster-harness-bogus-record-field-error.md`, **not
minimised** — a reduced module with the same imports and the same body passes, so the trigger needs
something about the containing module, and bisecting nine test functions against a 6-in-10 failure
rate was not worth the time.

**The workaround is an improvement on its own terms**, which is why it was taken without more
digging: the affected assertion moved out of `tests` and into the acceptance script, where it is
deterministic, and the conjunction it lived in was split into one row per fact. **A flaky gate is
worse than a red one** — it trains the reader to re-run rather than to read.

The `let`-binding workaround for the record-update dependency defect
(`fb_e44ba922db1c42be`) was needed again, at **ten sites** in `run_report_dst.ail`. That defect is
now the most frequently-hit of the three.

---

## What is NOT done

Both are assigned, both are real, and neither is blocked.

1. **The `ScriptedStep` latency widening** (cluster 10's correction 2). Not needed for D4 —
   correction 1 — but still the open half of D2's "response, fault, and latency" on the provider
   class. **Predicted cost, source-derived rather than measured: zero A5 anchor cost.** `session.ail`
   references `[ScriptedStep]` as a *type* at 2656 and 2677 and **constructs none**, and adding a
   field to a record breaks only construction sites (plan P1's probe). The 28 literal sites are in
   `stub_step`, `ports`, `dst_replay`, `dst_generator` and eight scripts. **This is a prediction, not
   the fourth data point the handoff asked for** — that requires doing it.
2. **`max_resource_size`** — decided as above, sized as a generator-version item, owner A15.

---

## What A15 should carry

1. **The counters exist and are validated; nothing has fed them from a real sweep.**
   `dst_run_report` is complete and `documented_coverage()` is explicitly a **declared** register,
   labelled as such in the rendered output. A15's corpora replace it with observations, and the swap
   is the point at which the three unreached classes stop being documented and start being measured.
2. **Key the corpora on `artifact_identity`, and the latency pair is a worked example of why.** Its
   two halves differ in one integer and produce two different identities
   (`2095b6d8…` and `70605bfb…`) — a corpus keyed on `(id, version, seed)` would have filed them as
   one, since they differ in neither.
3. **`make dst` now runs three more targets and the wall-clock cost is real.** A15 selects seed
   counts and rotation from measured CI cost; the DST gate is the measurement's baseline and it grew
   this cluster.
4. **A shrink-only register is a transferable pattern, and it is now used twice.**
   `d64_gap_register()` and `documented_coverage()` are the same shape: a declared gap asserted equal
   to a derived truth in **both** directions, so it can only shrink and closing an entry is forced to
   be recorded. It is what makes "the fifteen are the work, not the answer" executable rather than
   exhortative, and A15's corpora have the same exposure.
5. **Budget mutation loops as the cost of a detector, not as verification after one.** Cluster 12's
   first carry-forward held for a thirteenth cluster: all three silent defects were found by mutating
   and reading *why* a row went red, and one of them (site 27) was found only because a row that
   **stayed green** was read alongside the three that went red.
