# ADR-003: How should DST judge a wrong recovery on a real run?

**Status:** **Accepted 2026-10-06, as v0.2.** The operator accepted v0.1's six rulings. Two
independent reviews then found that four of them rested on things that do not hold, and the
operator accepted the v0.2 amendment with three tightenings the same day (*Rulings*). v0.2 revises
D2, D3, D4, D5, D6 and D8, narrows D7's wording, and adds D9 and D10. **Amended the same day by
rulings 13 to 16**, on findings of
`PLAN-judge-recoveries-on-real-runs.md` and of its review: D4's budget is held by the gate and not
on the execution record; D6's journal precondition is the whole matrix read row for row; the gate
is also named in a CI workflow; a red row reports what 009 D8 lists, with the program by
reference. The amended passages are marked with their ruling.
**Implemented and accepted on 2026-10-07.** The gate and the two rules are on `main` (#228, #229).
All eight rule ids were accepted at `ce9cb247`, on the run recorded in
`evidence/judge-recoveries/acceptance-ce9cb247/` and by ruling 17. What acceptance does not claim
is D6's known-unseen list, which that ruling extends by two branches.
**Date:** 2026-10-06. Grounded at HEAD `259265b5`, AILANG v0.47.2 (`e939cba`).

Reviewed, separately, by Codex (GPT-6-Astra) and Claude Fable 5.1:
`REVIEW-001-adr-003-codex-gpt-6-astra.md`, `REVIEW-001-adr-003-claude-fable-5.1.md`. What v0.2
changes, and which finding each change answers, is the table in *Changes in v0.2*.

Relates to:
- `RESEARCH-test-axes-beyond-dst.md` §3.3 — the oracle-strength study this ADR is the first
  decision out of. Its cost basis is corrected in the findings note.
- `PLAN-spike-mutation-operator-feasibility.md` and
  `NOTE-spike-findings-mutation-operator-feasibility.md` — the spike, in five parts. **Every number
  below is from that note** and is not restated with its method. `evidence/mutation-spike/` holds
  the mutant table, the scripts and the score output.
- `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` D2 and D7 —
  govern. This ADR implements part of both and does not reopen either; see D8.
- `../035_antithesis_testing/RESEARCH-antithesis-inspired-testing.md` §5 — its first candidate
  property and its retry-bound row now have executed rows.
- `../034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md` — its P1 and P3 are
  invariant-set rules that read world-carried logs; D1, D9 and D10 are what they can lean on.
- `../../meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md` and
  `measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md` — D6 applies
  the first; the two prototypes are the second.

---

## TL;DR

**Problem.** Two single-edit defects in recovery branches the corpus reaches add no failure to
`make dst`: a retried stream error that consumes no step budget, and a non-retryable provider
failure that finalizes as success. Both break an obligation 009 D7 lists. The invariant set did not
see them for two reasons, and the second is the one that matters:

1. It is evaluated on a run-produced execution in one gate, on a two-step script with no fault.
2. Evaluated on all sixteen corpus members, it still reports nothing for either — or for any of
   eleven recovery mutants. The rules do not read what these defects change.

**Decision.** One new gate evaluates the invariant set on every corpus member's run (D1) and makes
five checks of its own on each run. In the invariant set: outcome agreement by reason (D2) and no
repeated driver step (D3). In the gate: steps numbered from zero without a gap (D3), two rules
against the run's effective step budget (D4), a provider-call balance (D5), contiguous request
ordinals (D9) and a tool-dispatch balance (D10). Each rule is accepted only on a named source
mutant seen red and named controls seen green (D6). The corpus's identity keys are not pinned
instead (D7).

**Evidence.** A throwaway prototype of v0.2 was run against 24 mutants and controls, the reviewers'
six among them. Every mutant that breaks a rule this ADR states goes red on that rule, no control
goes red, and the existing invariant gates still pass. One reviewer mutant passes everything, and
D6 records it as known and unseen. 24 of 24 outcomes were predicted in advance.

**Not decided.** The approval balance; successors dropped before their witness is drained; loss of
part of a successor; a world that reaches the one tool handoff no probed gate executes; a decision
budget; the sweep's cost.

## Context

All measured on 2026-10-05 and -06 in a throwaway worktree. The findings note carries the tables.

- **Eleven mutants, one stated rule each**, in recovery branches named by the fault catalogue or by
  a comment in the source. All type-check. `corpus_pr`'s wire witness shows every branch executed
  on the unmutated tree.
- **Nine add a failure to `make dst`; two do not.** The baseline is itself red on four
  extension-inventory targets in the spike worktree, so "do not" means a failure-line set identical
  to the unmutated sweep's. Of the nine, three are caught by an exact assertion in a scripted
  fixture or unit test, four by a presence or class check on the corpus (one of those also by the
  discovery balance), one by the discovery balance on scripted scenarios alone, and one — a dropped
  world successor in the retry branch, the demo's own bug class — only because the recursion-depth
  canary pins a record count.
- **The invariant set over the corpus is clean on the unmutated tree** and under every one of the
  eleven, at the driver's own bounds. A known-bad control turns it red, so the probe can see.
- **Why it is blind to the two survivors**, each located by a pair of rows:
  `outcome_agreement_findings` compares the outcome with the summary's error text and never reads
  `finish_reason`; `provider-step-repeated` reads the step the recorder logs, which is the world's
  own count of provider calls (`src/core/test/stub_step.ail:486`), not the driver's `step_idx`.
- **Why it is blind to a dropped world successor.** The interaction log the families read is
  carried in the world that was dropped. Measured at the tool handoff: the driver made three tool
  requests, the log holds none, and the set reports nothing.
- **The returned trace already holds a second channel.** `witness` appends one `WorldRequest`
  record, with its ordinal, for every request the driver makes (`src/core/session.ail:4572`). On
  the spike's corpus wires those ordinals break in 0 of 18 runs on the comment-only control, in 4
  under the dropped successor in the retry branch and in 12 under the approval mutant. v0.1 did not
  see this; the second review did.

## Options considered

1. **Leave it to each gate's own checks.** They caught nine of eleven. Rejected on the two.
2. **Evaluate the invariant set on the corpus and change no rule.** Necessary, and measured
   insufficient: none of eleven.
3. **Pin each corpus member's existing identity and trajectory keys.** Cheap, and it would have
   caught the no-budget retry and the dropped successor, whose keys change. **Rejected as a
   substitute, on measurement:** the failure-as-success mutant and the budget-edge retry change 0 of
   the 32 keys. This does not reject every snapshot. A pin over the whole normalized trace would see
   both, and 009 D7 says only that a run checked against "*only* its final prose or a golden
   snapshot" is not the axis.
4. **Rule changes, the set on the corpus, and two-channel checks in the same gate (chosen).**
5. **The whole discovery census on the corpus now.** Partly taken in v0.2. The provider and tool
   classes have a trace-side count on a generated world, measured clean on the corpus (D5, D10).
   The approval class does not yet: a first statement of it is red on two healthy members.

## Decision

For each detector: what it reads, when it is red, and where it stops being sound.

**D1. The invariant set is evaluated on every corpus member's run, in its own gate.**
*(Ruled 2026-10-06; v0.2 adds the last two sentences.)* `execution_of` over each member's
`TracedSessionResult`, then `evaluate`. Red on any finding. Not inside `corpus_pr`: that target
gates on its own wall clock, and a red here should name a rule. Sound for the `driver_only` bank and
the trajectories its sixteen members walk, and no further: it is not 009 D11's rotating search. The
gate declares its budgets in one place: the step budget of D4, a retry budget one below it, and no
decision budget. It bridges only results that carry a terminal summary (D2). *(Ruling 15.)* The
target is in `DST_TARGETS` and is also named in a CI workflow, as its own step beside `corpus_pr`:
no workflow runs `make dst`, so a target in that list alone is run only by hand. *(Ruling 16.)* On
a red row the gate reports the twelve things 009 ADR-001 D8 lists for a generated failure. It
takes the exact serialized program by reference, to the artifact `corpus_pr` persisted for the
same member, and persists none of its own: both gates run the same sixteen programs in the same
job, and a second writer of the corpus store would race with the first.

**D2. Outcome agreement is by reason.** *(Ruled 2026-10-06, as revised in v0.2.)* The returned
outcome is `Ok` if and only if the terminal summary finished `stop`. An `Err` outcome's summary
finishes with the reason its error code implies: `StepBudgetExhausted` with `max_steps`,
`BudgetExceeded` with `cost_exhausted`, `ContextExhausted` with `compaction_exhausted`, and every
other code with `error`.

- **The table is stated in the invariant module and not imported from the driver.** An oracle that
  asked `decision_fail_reason` would agree with it by construction.
- **As exact as the wire allows.** Four failure reasons share the wire string `error`, and the
  summary carries the string, so the rule cannot tell those four apart.
- **Fail direction.** A new code or reason makes a healthy run red until someone edits the table.
  v0.1 said a new reason would be a compile error; the table is keyed on strings, so it is not.
  The same holds for a provider error that arrives carrying one of the three named codes.
- **Already assumed elsewhere.** The journal admission check pairs `StepBudgetExhausted` with
  `max_steps` (`src/eval/journal/admission.ail:299`).
- **Boundary.** A result with no terminal summary is not a run that finalized.
  `parked_frame_only` (`src/core/session.ail:5584`) returns `Ok` with none, and `execution_of`
  would present it as a completed run. D1's gate does not bridge such results.
- At HEAD every finalize site satisfies the rule by reading (`:2723`, `:2789`, `:3335`, `:3402`,
  `:3572`, `:3792`, `:3799`, `:3920`), and all sixteen members by measurement.

Its own `Violation` constructor.

**D3. The driver's own step numbers do not repeat, and on the corpus they do not skip.**
*(Ruled 2026-10-06, as revised in v0.2.)* Two statements with different reach.

- **In the invariant set:** the `step` on each `ProviderCallPrepared` record in the returned trace
  (`src/core/session.ail:3807`) does not repeat. Sound for any single run: every continuation out
  of the provider-call arm adds one. `ProviderStepRepeated` keeps its meaning, the recorder's
  count. Its own constructor.
- **In the gate:** on a corpus run those steps are exactly 0, 1, 2 and so on. All sixteen members
  are, by measurement. This is not sound as a family rule: a park whose reply is dropped advances
  the step with no provider call (`:3535`). The bank never parks. If it gains a member that does,
  this check is restated with it.

**D4. The gate declares the run's effective step budget and states two rules against it.**
*(Ruled 2026-10-06, as revised in v0.2, with a tightening; amended by ruling 13.)*

- **Where the value lives.** *(Ruling 13.)* In the gate. v0.1 put it on the execution record
  because its two rules were family rules, and a family rule can read nothing else. v0.2 moved the
  rules to the gate and left the field behind, with the gate as its only reader and four call
  sites in project 013's evaluator stating a value nothing read. So `ExecutionUnderTest` gains no
  field and `execution_of` keeps its eight parameters. The gate declares the budget once and gives
  that one value to the run and to the two rules. If a later decision makes either rule a family
  rule, the field is added then, with its reader.
- **What the value is.** The budget the driver enforced. `session_policy_init` turns a non-positive
  argument into 8 (`src/core/session.ail:2351`), and the step machine reads a policy budget of 0 as
  unlimited (`src/core/step_machine.ail:103`). So a gate that started its run with a positive
  budget declares that number. A gate that did not declares the budget undeclared, with a negative
  value, and the two rules do not apply. It never copies a zero, and it does not restate the
  driver's default of 8, which would be wrong the day that default changes.
- **Undeclared is reported, never passed.** *(Tightening.)* A gate whose budget is undeclared
  prints the two rules as not evaluated. D1's gate declares a positive budget, so there both are
  always evaluated.
- **The rules.** Provider calls in the trace do not exceed the budget. No `StreamErrorRetry` is
  recorded at a step where the budget minus the step is 1 or less, which is the budget conjunct of
  `recovery.should_retry_stream_error`'s contract stated over an execution.
- **No decision budget is declared by this ADR.** `dst_invariants.ail` says a bound it chose "would
  be a bound no profile agreed to".

**D5. Provider calls balance across two channels.** *(Ruled 2026-10-06, as revised in v0.2.)* The
count of `ProviderCallPrepared` in a run's returned trace equals the count of provider interactions
that run added to the world's log. A gate check, not a family rule. Sound under three premises,
all of which the `driver_only` corpus meets:

- the world records, which the scripted adapter `stream_parity` also drives does not;
- no hook calls the model: `ext_ai_step` logs a provider interaction and writes no prepared record
  (`src/core/session.ail:1094`);
- the count is a delta over the log the run started with, so a resumed run is not charged for its
  predecessor.

Only the under-recorded direction has been seen red.

**D9. Request ordinals are contiguous.** *(New in v0.2; ruled 2026-10-06.)* The `WorldRequest`
ordinals in a run's returned trace run in steps of one from the starting world's ordinal to the
returned world's. A gate check. It reads no log, so it sees a successor dropped *after* its
witness was drained, for every request class at once. It does not see one dropped before: the
dropped world takes its undrained witness with it (`:4567`). The rule already exists for other
runs, in `make world_framed_wire` and `src/eval/journal/admission.ail:40`; this puts it on the
corpus.

**D10. Tool dispatches balance across two channels.** *(New in v0.2; ruled 2026-10-06.)* The count
of `V2ToolDispatchStart` in a run's returned trace equals the count of tool interactions that run
added to the log. A gate check, under D5's first and third premises. It sees the tool successor
dropped before its witness, which D9 cannot.

**Scope of D5, D9 and D10.** *(Tightening, ruled 2026-10-06.)* The three are checks of D1's gate on
the `driver_only` bank. That is the only place they were measured clean. A gate for another profile
adopts one only after measuring it clean on that profile's unmutated runs. A hook that calls the
model is a known way for a healthy run to be unbalanced (D5); tools handled by an extension were
not examined.

**D6. Acceptance is by named mutants.** *(Ruled 2026-10-06, as revised in v0.2, with a
tightening.)* A rule is accepted when its mutant has been seen red on that rule and the controls green.

| rule | mutant, one edit | must go red |
|---|---|---|
| D2, `Err` with `stop` | failure finalize reports the success reason (`session.ail:3920`) | D2, on the members that end in a provider failure |
| D2, `Ok` without `stop` | success finalize reports a failure reason (`session.ail:3402`) | D2, on the members that end `Ok` |
| D2, wrong failure reason | failure finalize reports `max_steps` (`session.ail:3920`) | D2, same members |
| D2, wrong failure reason | suspension reports an internal failure (`session.ail:2789`) | D2, on the suspended member |
| D3, repeat | the retry does not advance `step_idx` (`session.ail:3887`) | D3 in the set |
| D3, skip | the retry advances `step_idx` by two (`session.ail:3887`) | D3 in the gate |
| D4, calls | the step machine allows one call past the budget (`step_machine.ail:103`) | D4, alone, on the member that makes 13 on 12 |
| D4, edge retry | drop `remaining_step_budget > 1` (`recovery.ail:28`) | D4 |
| D5 and D9 | the retry keeps the pre-call world (`session.ail:3892`) | both |
| D9 | the denied-approval arm continues from `st` (`session.ail:3613`) | D9 |
| D9 | the failure finalize drops the capture read's successor (`session.ail:3920`) | D9 |
| D10 | the approved call's successor is dropped (`session.ail:3623`) | D10 |

Controls that must stay green: the unmutated corpus; a comment-only edit in the retry branch;
`make invariants`; `make stream_parity` with its pinned rule sets unchanged; the module's inline
tests. A mutant that fails to compile, times out, or turns a different check red is recorded as
that and is not a kill. At the acceptance gate a reviewer adds a handful of mutants without seeing
this table. The run happens once, at the commit handed in, and is not a CI gate.

**A precondition of acceptance.** *(Tightening.)* The spike did not have the four controls below.
No rule is accepted until each has run, and the first comes first.

- **The other real-run callers of `evaluate`.** `src/eval/journal/bridge.ail:103`,
  `candidate_checks.ail` and `witness_live_test.ail` will run D2 and D3 on suspended and stopped
  runs, and the last asserts no finding. They are the one existing place the new rules could turn
  a healthy run red. They run under `make eval_matrix`, which is outside `make dst` and named by
  no workflow, so nothing else would notice. The Makefile gives that run 25 to 40 minutes.
  *(Ruling 14.)* The control is the whole matrix, compared row for row with that of the last
  tree without D2 and D3, and the three suites that evaluate real runs (`witness_live_test`,
  `candidate_checks_live_test`, `admission_live_test`) exit 0 in both. The reference is named by
  what it lacks because, once the rules are committed, the parent of a later commit already has
  them and a comparison with it is identical whatever they do. Measured at `59d5cbb9`: 821 s, and
  identical in all 621 rows to the spike's matrix at `259265b5`.
- **A valid retry with two steps of budget left.** The corpus has two members at exactly their
  budget, but its retries are at steps 1 and 8 of 12, nowhere near the edge.
- **A mutant for D5's over-recorded direction.**
- **A profile with a hook that calls the model**, to show D5 is not applied there.

Known, and not seen by any rule here. Acceptance does not claim them:

- **The retry keeps the successor's log and rewinds its generator state** (`session.ail:3892`). Run
  by one reviewer and again in part 5: every rule is green.
- **Failure reasons that share `error`** are not told apart (D2).
- **A step label offset by a constant**, and **a re-issued park that consumes no budget**
  (`session.ail:3535`): proposed by the reviewers, not run. The corpus never parks.
- **A tool run without an approval loses its successor** (`tool_phase.ail:615`). *(Ruling 17.)* A
  blind reviewer's mutant at acceptance: every rule is green. The bank's policy sends every tool
  call to approval, so no member runs that arm of the fold. It is the handoff the spike's part 3
  found the bank does not reach.
- **After a verifier rejection the model is called again under the same step**
  (`session.ail:2985`). *(Ruling 17.)* A blind reviewer's mutant at acceptance: every rule is
  green. The bank runs with verification disabled. D3's family rule would see it on a run that
  takes that path; no gate evaluates the set on one.

**D7. The corpus's existing identity keys are not pinned by this ADR.** *(Ruled 2026-10-06; v0.2
narrows the wording to what was measured.)* Option 3. Existing pins, the depth canary's among them,
are not touched.

**D8. No reopen of 009 ADR-001.** *(Ruled 2026-10-06, as corrected in v0.2.)* Checked
against its text, and corrected after both reviews:

- D7's "the runner applies reusable invariants to the returned outcome and complete trace" is D1.
  "Agreement between returned outcome and terminal summary" is D2. "Bounded retry and progress
  behavior", with liveness "bounded and operational", is D3 and D4 in part.
- D5, D9 and D10 are **not** D7's "discovery contract". That is the relation between two runs of
  one seed. They are 009 D2's interaction record held against a second channel, the idea
  `dst_discovery.class_balance` already implements for scripted scenarios.
- This is a partial implementation. Nothing here sees a run that never returns, bounds a loop that
  makes decisions without provider calls, or covers D11's rotating search.

## Changes in v0.2

| | v0.1 | v0.2 | Why |
|---|---|---|---|
| D2 | `Ok` if and only if `stop` | also: an `Err`'s reason follows from its code; results with no summary are excluded | A provider failure reported as `max_steps`, and a suspension reported as an internal failure, passed v0.1. Both reviews; run in part 5. |
| D3 | no repeat | no repeat in the set; no gap on the corpus, in the gate | A retry that advances by two passed v0.1. |
| D4 | "the value the run was started with"; negative means undeclared | the effective budget; a non-positive start is undeclared; the calls rule has its own mutant | Zero means 8 to the driver and unlimited to the step machine. |
| D5 | sound "for a world that records" | three premises | A hook that calls the model writes no prepared record. |
| D9 | — | request ordinals contiguous | A witness already in every trace, missed by v0.1. It catches the approval mutant on 12 members. |
| D10 | deferred | tool balance on the corpus now | The stated reason for deferring it holds for approvals only. |
| D6 | six rows, five mutants | twelve rows; controls owed; a known-unseen list | Both reviews. |
| D7 | "not pinned" | "the existing keys are not pinned" | The measurement rejects those keys, not every snapshot. |
| D8 | D5 "is the discovery contract" | it is 009 D2's record against a second channel | 009 D7's discovery contract is the run-twice relation. |
| evidence | "pass the whole of `make dst`"; 100 wire summaries as support for D2 and D3; "12 record literals in 7 files" | "add no failure"; the 100 summaries are dropped as support; two constructions and five callers | The baseline is red on four targets. That log holds no retried run and no returned outcome. The 12 was a grep count. |

### What the two prototypes showed

`evidence/mutation-spike/scripts/prototype.diff` (v0.1) and `prototype2.diff` (v0.2). Never merged.

- **v0.2, 24 rows.** With the prototype on the unmutated tree, `make invariants` and
  `make stream_parity` pass, the nine inline tests pass, and all sixteen members are clean on the
  set and on all six gate checks. Every row of D6's table went red on its rule: the reason swaps on
  D2 with `err code='E_PROVIDER_PROTOCOL'` against `finish_reason='max_steps'`; the two-step retry
  on four members; the approval mutant on 12; the tool successor on 10; the extra call on the one
  member with 13 on 12. The generator rewind was clean on everything, as predicted.
- **The v0.1 prototype reused existing constructors, and one then lied.** The driver-step finding
  printed `provider step 8 appears 2 times in the interaction log; the cursor did not advance`. The
  log was fine. Hence "its own constructor" in D2 and D3.
- **Both prototypes computed the gate checks in the probe**, because `ExecutionUnderTest` has no
  step budget and the checks are not family rules.

### House caveats respected

- **Mutation proves a guard can fire, not that it fires too much.** D6 names the controls that must
  survive, and the unmutated corpus was measured clean under each prototype before any mutant ran.
- **Faults are outcomes at the typed boundary.** Nothing is injected. Every mutant is a source edit
  in a scratch worktree, restored and hash-checked after each run.

## Consequences

**Costs.**
- One more gate. The probe runs the whole bank, the set and the six checks in about 40 seconds,
  nearly all of it one compile of the driver module.
- D4 touches no record and no caller of `execution_of` *(ruling 13)*. v0.2 priced a field here:
  the two places that build the record in full and the five callers, four of them in project
  013's evaluator.
- Each new constructor touches the rule, family and message matches, the sample list and one
  mutant row in `invariants_dst`. Counts quoted in the DST report draft move.
- D2 freezes today's table of codes and reasons. A partial success on `max_steps`, or a new failure
  code, has to change the rule on purpose.
- Acceptance needs one `make eval_matrix`, which the Makefile puts at 25 to 40 minutes, beside the
  mutant runs.

**Enables.**
- 034's P1 and P3 get a real run with tool faults to be evaluated on, and D9 and D10 beside them: a
  dropped tool successor leaves a world-carried log clean and these two red.
- §3.3's kill matrix gets a first column that is not empty, and a 40-second instrument to fill the
  next ones.
- 035's property "a returned world successor is carried" gets checks that do not read the state
  whose loss is the defect. It is not established in full: see *Not decided* items 1 and 2.

## Not decided

1. **Successors dropped before their witness is drained, other than at the tool handoff.** The env
   and filesystem reads in `session_policy_init` are the measured cases: D9 cannot see them and no
   balance here counts those classes. Two scripted gates catch them today through a count derived
   from source.
2. **Loss of part of a successor.** The generator rewind in D6's known-unseen list.
3. **The approval balance on a generated world.** One reviewer's first statement of it is red on
   two healthy members.
4. **A world for the interrupted-batch handoff** (`src/core/session.ail:3694`). None of the six
   gates probed executes a tool and then meets an approval inside one dispatch.
5. **A decision budget.** Whether the `driver_only` profile declares one.
6. **The sweep's cost.** `session.ail` exceeds AILANG's 16 MiB cache blob limit and is recompiled
   at least fifty times per sweep; a warm sweep is about 31 minutes.
7. **`corpus_pr`'s own reporting.** Its recipe prints the last 40 lines and hides the failing rows,
   and its `provider_failure_finalize` counter also counts retry records: 11 at baseline is 7
   summaries and 4 retries.
8. **Reach reporting per family** on the corpus, in 035 §5's sense.
9. **`run_v2_session_traced_with_persist_retries` starts its run from the pre-init world**
   (`src/core/session.ail:4480`), where its sibling at `:4442` passes the post-init one. Found by a
   reviewer, confirmed by reading. Its only callers are in `scripts/dst/phase_c2_wiring_scenarios.ail`;
   whether it matters there was not established.
10. **A run that reaches each of the two branches acceptance found unreached** *(ruling 17)*: a
    tool run without an approval, and the step after a verifier rejection. One scripted control
    run for each in D1's gate, with its mutant seen red, would move both out of D6's known-unseen
    list. Its own small decision, and not a condition of acceptance.

## What a plan would sequence

By source surface, per `sequence-implementation-handoffs-by-source-surface.md`:

1. **The bank.** *(Ruling 13 replaces v0.2's step, "the record: D4's field with every site stating
   a value".)* The corpus script exports its bank and run helpers and states its step budget once;
   no behaviour changes. Sweep.
2. **The rules.** D2 and D3's family half, with their constructors, their mutant rows in
   `invariants_dst`, and D2's table. New pure functions under `src/core` need a contract or a
   checked `-- contracts:` line.
3. **The gate.** D1, the gate half of D3, D4's two rules, D5, D9 and D10 as one script and one
   target, added to `DST_TARGETS` and to a workflow *(ruling 15)*.
4. **Acceptance.** The four controls D6 makes a precondition, `make eval_matrix` first. Then D6's
   mutants, and a reviewer's own, run once at the commit handed in. `mutants.tsv`, the script and
   the commit go into this project's evidence.

The plan is `PLAN-judge-recoveries-on-real-runs.md`.

## Rulings

**On v0.1, all six accepted by the operator on 2026-10-06**, in conversation, after a
recommendation had been given for each decision: "I agree with the recommendations. Add my
rulings."

| # | Ruling on v0.1 |
|---|---|
| 1 | D2: outcome agreement is exact and two-sided, and it freezes today's table. |
| 2 | D3 and D4: bounded progress reads the driver's own step numbers, and a step budget carried on the execution record. A negative budget means undeclared. No decision budget is declared. |
| 3 | D5: the provider-call balance goes on the corpus now, as a gate check and not a family rule. The tool and approval balances are deferred. |
| 4 | D1: a separate gate, not a row in `corpus_pr`. |
| 5 | D6: acceptance by named mutants. A reviewer adds a handful without seeing the table, and the run happens once, at the commit handed in. |
| 6 | D7: corpus identities are not pinned. Existing pins stay as they are. |

**On v0.2, accepted by the operator on 2026-10-06**, in conversation, after the two reviews, the
24-row run and a recommendation for each item: "I will go with your recommendations". Rulings 4 and
6 stand as given; v0.2 changes neither decision. Rulings 1, 2, 3 and 5 are replaced:

| # | Replaces | Ruling on v0.2 | Tightening ruled with it |
|---|---|---|---|
| 7 | 1 | D2 by reason: an `Err`'s finish reason follows from its code, by a table in the invariant module; results with no summary are not bridged. | — |
| 8 | 2 | D3 gains a no-gap check in the gate. D4 carries the effective budget; a run started with a non-positive budget is undeclared; the calls rule has its own mutant. Still no decision budget. | An undeclared budget is reported as not evaluated, never as passed, and D1's gate declares a positive one. The no-gap check is restated if the bank gains a member that parks. |
| 9 | 3 | D5 with its three premises; D9, contiguous request ordinals; D10, the tool balance now. The approval balance stays undecided. | The three are checks of D1's gate on the `driver_only` bank. Another profile measures each clean before adopting it. |
| 10 | 5 | D6's table of twelve and its list of what is known and not seen. | The four controls still owed are a precondition of acceptance, the journal callers first. |
| 11 | — | D8 as corrected: no reopen of 009 ADR-001. D5, D9 and D10 belong to 009 D2, not to D7's discovery contract. | — |
| 12 | — | No second general review round of this ADR. The next independent check is the implementation's acceptance run, with the mutants a reviewer adds unseen. | — |

**On three findings of the plan, ruled by the operator on 2026-10-06**, in conversation, after
`PLAN-judge-recoveries-on-real-runs.md` had put each as a question with a recommendation: "I will
go with your recommendations". Every other ruling stands as given.

| # | Amends | Ruling |
|---|---|---|
| 13 | 8 | D4's effective step budget is declared and held by the gate. The execution record gains no field and `execution_of` keeps eight parameters. The definition of the value, the undeclared case and the two rules stand as ruled. |
| 14 | 10 | D6's journal precondition is the whole of `make eval_matrix`, read row for row against the last tree without D2 and D3, with the three suites that evaluate real runs exiting 0 in both. |
| 15 | 4 | The gate is in `DST_TARGETS` and is also named in a CI workflow, as its own step beside `corpus_pr`. It stays a separate target and outside `corpus_pr`'s wall clock. |

**On one finding of the plan's review, ruled by the operator on 2026-10-06**, in conversation,
after `REVIEW-001-plan-judge-recoveries-claude-opus-5.5.md` had shown the plan settling it in a
sentence and the revised plan had put it as a question with a recommendation: "I will go with your
recommendation".

| # | Amends | Ruling |
|---|---|---|
| 16 | — | A red row of D1's gate reports the twelve items of 009 ADR-001 D8. The serialized program is given by reference to the artifact `corpus_pr` persisted for that member; the gate persists none. This does not reopen 009: D8's "copy-pasteable local replay command or artifact reference" is met by the reference. |

**On the acceptance run, ruled by the operator on 2026-10-07**, in conversation, after the run in
`evidence/judge-recoveries/acceptance-ce9cb247/` had accepted six rule ids and held two on one
blind survivor each, and a recommendation had been given: "I will follow your recommendations".

| # | Amends | Ruling |
|---|---|---|
| 17 | 10 | All eight rule ids are accepted at `ce9cb247`. `driver-step-repeated` and `tool-dispatches-unbalanced` are accepted with the other six: every row D6 and the plan name for them was a kill, and the two blind survivors are on branches no corpus member runs, which D1 already puts outside what the gate is sound for. The two branches join D6's known-unseen list. A scripted run that reaches each is a follow-up of its own (*Not decided*, item 10), not a condition of acceptance. |
