# ADR-003: How should DST judge a wrong recovery on a real run?

**Status:** Proposed. The operator accepted the direction of D2–D5 in conversation on 2026-10-06;
nothing is ruled in writing and nothing is implemented on `main`.
**Date:** 2026-10-06. Grounded at HEAD `259265b5`, AILANG v0.47.2 (`e939cba`).

Relates to:
- `RESEARCH-test-axes-beyond-dst.md` §3.3 — the oracle-strength study this ADR is the first
  decision out of. Its cost basis is corrected in the findings note.
- `PLAN-spike-mutation-operator-feasibility.md` and
  `NOTE-spike-findings-mutation-operator-feasibility.md` — the spike, in four parts. **Every number
  below is from that note** and is not restated with its method. `evidence/mutation-spike/` holds
  the mutant table, the scripts and the score output.
- `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` D7 — governs. This
  ADR implements two of its bullets and does not reopen it; see D8.
- `../035_antithesis_testing/RESEARCH-antithesis-inspired-testing.md` §5 — its first candidate
  property and its retry-bound row now have executed rows.
- `../034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md` — its P1 and P3 are
  invariant-set rules and inherit D1 and the limit in *Not decided* item 1.
- `../../meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md` and
  `measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md` — D6 is the
  first applied to this decision; the prototype is the second.

---

## TL;DR

**Problem.** Two single-edit defects in recovery branches the corpus reaches pass the whole of
`make dst`: a retried stream error that consumes no step budget, and a non-retryable provider
failure that finalizes as success. Both break an obligation 009 D7 lists. The invariant set did not
see them for two reasons, and the second is the one that matters:

1. It is evaluated on a run-produced execution in one gate, on a two-step script with no fault.
2. Evaluated on all sixteen corpus members, it still reports nothing for either — or for any of
   eleven recovery mutants. The rules do not read what these defects change.

**Decision.** Evaluate the invariant set on every corpus member's run, in its own gate (D1). Make
outcome agreement exact and two-sided (D2). Make bounded progress read the driver's own step
numbers (D3). Carry the run's step budget on the execution record and state two rules against it
(D4). Compare provider calls in the trace with provider interactions in the log (D5). Accept each
rule only on a named source mutant seen red and named controls seen green (D6). Do not pin corpus
identities instead (D7).

**Evidence.** A throwaway prototype of D2–D5 was run against eighteen mutants and controls:
both survivors go red, the mutant that only an unrelated pin had caught goes red on its own rule,
no control goes red, and the existing invariant gates still pass. Eighteen of eighteen outcomes
were predicted in advance.

**Not decided.** The tool and approval balances for generated worlds, which 034 needs; a world that
reaches the one tool handoff no gate executes; a decision budget; the sweep's cost.

## Context

All measured on 2026-10-05 and -06 in a throwaway worktree. The findings note carries the tables.

- **Eleven mutants, one stated rule each**, in recovery branches named by the fault catalogue or by
  a comment in the source. All type-check. `corpus_pr`'s wire witness shows every branch executed
  on the unmutated tree.
- **Nine turn `make dst` red; two do not.** Of the nine, three are caught by an exact assertion in
  a scripted fixture or unit test, four by a presence or class check on the corpus (one of those
  also by the discovery contract), one by the discovery contract on scripted scenarios alone, and
  one — a dropped world successor in the retry branch, the demo's own bug class — only because the
  recursion-depth canary pins a record count.
- **The invariant set over the corpus is clean on the unmutated tree** and under every one of the
  eleven, at the driver's own bounds. A known-bad control turns it red, so the probe can see.
- **Why it is blind to the two survivors**, each located by a pair of rows:
  `outcome_agreement_findings` compares the outcome with the summary's error text and never reads
  `finish_reason`; `provider-step-repeated` reads the step the recorder logs, which is the world's
  own count of provider calls (`src/core/test/stub_step.ail:486`), not the driver's `step_idx`.
- **Why it is blind to a dropped world successor.** The interaction log the families read is
  carried in the world that was dropped. Measured at the tool handoff: the driver made three tool
  requests, the log holds none, and the set reports nothing. The gates that catch it hold the log
  against a second channel.

## Options considered

1. **Leave it to each gate's own checks.** They caught nine of eleven. Rejected on the two.
2. **Evaluate the invariant set on the corpus and change no rule.** Necessary, and measured
   insufficient: none of eleven.
3. **Pin each corpus member's identity and trajectory.** Cheap, and it would have caught the
   no-budget retry and the dropped successor, whose members change. **Rejected on measurement:**
   the failure-as-success mutant and the budget-edge retry change no member's log length or
   outcome, so a pin does not see them. 009 D7 also says a generated run checked against "a golden
   snapshot is not the new DST axis".
4. **Rule changes, the set on the corpus, and one two-channel balance (chosen).**
5. **The whole discovery census on the corpus now.** Deferred, not rejected. The scripted gates
   build their tool and approval counts from a scripted world's cursors
   (`scripts/dst/strict_replay_dst.ail:368`), which a generated world does not have, and part of
   that witness is read from the final world.

## Decision

For each detector: what it reads, when it is red, and where it stops being sound.

**D1. The invariant set is evaluated on every corpus member's run, in its own gate.**
`execution_of` over each member's `TracedSessionResult`, then `evaluate`. Red on any finding. Not
inside `corpus_pr`: that target gates on its own wall clock, and a red here should name a family.
Sound for the `driver_only` bank and the trajectories its sixteen members walk, and no further.

**D2. Outcome agreement is exact and two-sided.** The returned outcome is `Ok` if and only if the
terminal summary's finish reason is the success reason. At HEAD one finalize site returns `Ok` and
it is the success one (`src/core/session.ail:3402`); every other reason returns `Err`. A
budget-suspended run returns `Err` on `max_steps` (`c2_suspend`, `:2760`), and the park arm either
continues the loop or fails (`:3529`), so neither returns `Ok` on another reason. On the wire of
the unmutated full sweep, 100 run summaries: `stop` never carries an error and every other reason
always does. The table lives in one exhaustive match beside `TerminationReason`, so a new reason
is a compile error there and not a default. Its own `Violation` constructor.

**D3. Bounded progress reads the driver's own step numbers.** The `step` on each
`ProviderCallPrepared` record in the returned trace (`src/core/session.ail:3807`) must not repeat.
`ProviderStepRepeated` keeps its meaning, the recorder's count. Its own constructor. No healthy
run repeats one: 0 of the 100 runs on the unmutated sweep's wire. The three loop transitions that
keep the step (`:3417`, `:3480`, `:3697`) do not lead to a second provider call at it. Sound within
one run's trace.

**D4. The execution record carries the run's step budget, and two rules read it.** Provider calls
in the trace do not exceed it. No `StreamErrorRetry` is recorded at a step with one step of budget
left, which is `recovery.should_retry_stream_error`'s contract stated over an execution. The value
is the one the run was started with, and a negative value means undeclared, as for the two
budgets the record already carries. **No decision budget is declared by this ADR**:
`dst_invariants.ail` says a bound it chose "would be a bound no profile agreed to".

**D5. Provider calls balance across two channels, on the corpus.** The count of
`ProviderCallPrepared` in the returned trace equals the count of provider interactions in the
world's log. This is the discovery contract's class balance for one class, with a witness taken
from the trace alone. It lives in D1's gate until the census in *Not decided* item 1 exists.
**It is a gate check, not a family rule**: it is sound only for a world that records, and the
scripted adapter `stream_parity` also drives records no interaction at all.

**D6. Acceptance is by named mutants.** A rule is accepted when its mutant has been seen red on
that rule and the controls green.

| rule | mutant, one edit | must go red |
|---|---|---|
| D2, one direction | failure finalize reports the success reason (`session.ail:3920`) | D2, on the members that end in a provider failure |
| D2, the other | success finalize reports a failure reason (`session.ail:3402`) | D2, on the members that end `Ok` |
| D3 | the retry does not advance `step_idx` (`session.ail:3887`) | D3 |
| D4, calls | the same | D4, on the member that then makes 14 calls on 12 |
| D4, edge retry | drop `remaining_step_budget > 1` (`recovery.ail:28`) | D4 |
| D5 | the retry keeps the pre-call world (`session.ail:3892`) | D5 |

Controls that must stay green: the unmutated corpus; a comment-only edit in the retry branch;
`make invariants`; `make stream_parity` with its pinned rule sets unchanged; the module's inline
tests. A mutant that fails to compile, times out, or turns a different check red is recorded as
that and is not a kill. Every mutant so far was written by the author of the rules; at the
acceptance gate a reviewer adds a handful without seeing this table, as the mutation discipline
allows. The run happens once, at the commit handed in, and is not a CI gate.

**D7. Corpus identities are not pinned by this ADR.** Option 3.

**D8. No reopen of 009 ADR-001 D7.** Checked against its text. "The runner applies reusable
invariants to the returned outcome and complete trace" is D1. "Agreement between returned outcome
and terminal summary" is D2. "Bounded retry and progress behavior under the modeled fault
catalogue", with liveness "bounded and operational", is D3 and D4. D5 is the discovery contract
D7 already calls an invariant. This ADR states what those bullets must read.

### What the prototype already showed, and what it showed the real change must not copy

`evidence/mutation-spike/scripts/prototype.diff`, never merged.

- Both survivors red; the mirror mutant red on all ten `Ok` members; the dropped successor red on
  D5 with twelve calls in the trace against two in the log; the edge retry red at step 11 of 12.
  The eleven other rows clean, as predicted.
- **It reused existing constructors, and one then lied.** The driver-step finding printed
  `provider step 8 appears 2 times in the interaction log; the cursor did not advance`. The log was
  fine. Hence "its own constructor" in D2 and D3.
- **It compared against the literal `"stop"`.** Hence the exhaustive match in D2.
- **It computed D4 and D5 in the probe**, because `ExecutionUnderTest` has no step budget.

### House caveats respected

- **Mutation proves a guard can fire, not that it fires too much.** D6 names the controls that must
  survive, and the unmutated corpus was measured clean under the prototype before any mutant ran.
- **Faults are outcomes at the typed boundary.** Nothing is injected. Every mutant is a source edit
  in a scratch worktree, restored and hash-checked after each run.

## Consequences

**Costs.**
- One more gate. The probe runs the whole bank and the set in about 40 seconds, nearly all of it
  one compile of the driver module.
- D4's field touches every site that builds the record: 5 callers of `execution_of` and 12 record
  literals in 7 files, by grep at `259265b5`.
- Each new constructor touches the rule, family and message matches, the sample list and one
  mutant row in `invariants_dst`. Counts quoted in the DST report draft move.
- D2 freezes today's table. A partial success on `max_steps` would have to change the rule on
  purpose.

**Enables.**
- 034's P1 and P3 get a real run with tool faults to be evaluated on. The bank reaches
  `ToolFailed`, `ToolDeadlineExceeded` and `ToolCorrelationMismatch`.
- §3.3's kill matrix gets a first column that is not empty, and a 40-second instrument to fill the
  next ones.
- 035's property "a returned world successor is carried" gets, for the provider class, a check
  that does not read the state whose loss is the defect.

## Not decided

1. **The tool and approval balances on a generated world.** A dropped tool successor leaves the
   set clean on the corpus even after this ADR. Three other gates catch it today. 034's P1 and P3
   read world-carried logs and need this before they mean what they say.
2. **A world for the interrupted-batch handoff** (`src/core/session.ail:3694`). No gate executes a
   tool and then meets an approval inside one dispatch.
3. **A decision budget.** Whether the `driver_only` profile declares one.
4. ~~Whether a suspended or parked run may return `Ok` with another finish reason.~~ **Read
   2026-10-06 and closed into D2**: neither does.
5. **The sweep's cost.** `session.ail` exceeds AILANG's 16 MiB cache blob limit and is recompiled
   at least fifty times per sweep; a warm sweep is about 31 minutes.
6. **`corpus_pr`'s failure output.** Its recipe prints the last 40 lines and hides the failing rows.
7. **Reach reporting per family** on the corpus, in 035 §5's sense.

## What a plan would sequence

By source surface, per `sequence-implementation-handoffs-by-source-surface.md`:

1. **The record.** D4's field with every site stating a value; no behaviour changes. Sweep.
2. **The rules.** D2, D3 and D4's two rules with their constructors, their mutant rows in
   `invariants_dst`, and the table beside `TerminationReason`. New pure functions under `src/core`
   need a contract or a checked `-- contracts:` line.
3. **The gate.** D1 and D5 as one script and one target, added to `DST_TARGETS`.
4. **Acceptance.** D6's mutants run once at the commit handed in; `mutants.tsv`, the script and the
   commit go into this project's evidence.

Items 1 and 2 of *Not decided* are their own decision.

## For the operator to rule on

1. D2: the exact two-sided rule, and that it freezes today's table.
2. D3 and D4: the driver's step numbers and a declared step budget as what bounded progress reads.
3. D5 now, with the rest of the census deferred to *Not decided* item 1.
4. D1: a separate gate, not a row in `corpus_pr`.
5. D7: no pins.
