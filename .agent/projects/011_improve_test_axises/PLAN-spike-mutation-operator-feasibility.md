# Plan: throwaway spike — do single-site mutants of the driver's recovery branches get killed?

Status: **written before any mutant ran**, 2026-10-05. Worktree `/workspaces/motoko_agent-spike-mut`,
branch `spike/011-mutation-operator-feasibility`, forked from `259265b5`. **The branch never merges.**
Toolchain: AILANG v0.47.2 (`e939cba`), the binary on `PATH`; no other `ailang` exists on this host now.

**This is not the mutation study.** `RESEARCH-test-axes-beyond-dst.md` §3.3 asks for a kill matrix
and says it "needs a small operator-feasibility spike before planning". This is that spike. It
produces the numbers a plan needs — does a text-level operator work, what does a mutant cost, and
what does a first small sample say — and decides nothing.

It follows `PLAN-spike-resource-growth-feasibility.md` in form: questions with falsification stated
first, the instrument calibrated on a known-good and a known-bad input before any other number is
read, and a list of what it does not establish.

## What is already measured, so the spike does not redo it

All 2026-10-05 in the spike worktree, unmutated, cold caches.

- **The check set is green at HEAD.** `ailang check src/core/session.ail` 50 s, `make corpus_pr`
  79 s, `make strict_replay` 116 s, `make discovery` 87 s, run serially.
- **`session.ail` is never served from the compile cache.** Every run prints
  `CACHE_WRITE_FAILED module=src/core/session … ARTIFACT_TOO_LARGE … using fresh compilation`. So a
  mutant costs no more to compile than an unmutated run does, and each `ailang run` of a script that
  imports the driver pays that compile.
- **Every named recovery branch is reached by `corpus_pr`.** Its wire witness at baseline:
  `approval_denied×35 empty_stop_finalize×1 ToolFailed×3 ToolCorrelationMismatch×5
  ToolDeadlineExceeded×3 stream_error_retry×4 provider_failure_finalize×11 malformed_arguments×6`,
  against 67 executed dispatch batches. The bank is 16 members.
- **The whole invariant set meets a run-produced execution in one gate only.** By grep over
  `scripts`, `src` and `packages`, `evaluate(` is called from `invariants_dst.ail` (constructed
  fixtures and mutant rows; it runs the driver zero times) and from `stream_parity_dst.ail`, whose
  world is a two-step script with no fault in it (`stream_parity_dst.ail:109`). `src/eval/journal`
  also calls it, outside `DST_TARGETS`. So no invariant family is evaluated against a real run that
  takes a recovery branch. The recovery branches are guarded by each gate's own checks: wire
  counters, the census, the discovery contract. This shaped the predictions below and is itself a
  finding to carry into the plan for §3.3.

## Questions, with falsification criteria

**Q1 — Does a text-level operator work here?** Each mutant is one replacement of text that occurs
exactly once.
- *Confirms* if at least two thirds of the mutants type-check and run.
- *Falsifies* if more than a third fail to compile or cannot be written as a unique replacement.
  That would answer RESEARCH open question 2 toward AST-level mutation.

**Q2 — Is the runner calibrated?** Two controls run first.
- `K0`, a comment-only edit in the retry branch, must leave every gate green with the same branch
  counters as the baseline.
- `K1`, the demo's mutant, must turn `strict_replay` red on `[discovery-env-read-under-recorded]`
  naming `MOTOKO_RETRY_STREAM_ERROR`, as EXP-SIBLINGS-04 observed on the same `session.ail` bytes.
- *Falsifies* if either comes back otherwise. Then no other row is scored until the runner is fixed.

**Q3 — Is each mutated branch reached?** Read from the baseline wire witness above, not assumed.
- A mutant in a branch whose counter is zero at baseline is INCONCLUSIVE, never a survivor.
- All eight counters are above zero, so every row below is assessable against `corpus_pr`.

**Q4 — Which gate kills which mutant?** A prediction per row, written below before the run.
- The population claim under test is the demo's: DST catches what the type checker misses. It is
  *falsified for a mutant* if that mutant type-checks, sits in a reached branch, changes behaviour,
  and no gate in the full sweep goes red.
- A wrong prediction in either direction is a result about how legible the detectors are, and is
  reported as that.

**Q5 — What does a mutant cost?** Seconds per mutant for the targeted set, and the cost of one full
sweep on this host. No pass or fail.

## The check set

Per mutant, tier T:

| step | what it is |
|---|---|
| `ailang check src/core/session.ail` | the type checker; covers `tool_phase` and `recovery` as imports |
| `ailang verify src/core/recovery.ail` | the Z3 contract on the retry predicate. Not a DST gate; its own column |
| `make corpus_pr` | 16-member bank through the real driver; branch-reached wire counters |
| `make strict_replay` | record, replay, discovery contract, env witness |
| `make discovery` | discovery contract against `driver_only` |
| `make stream_parity` | the only gate that runs `evaluate()` on a real execution |
| `make ledger_parity` | wire against returned trace over its own traced runs |

Tier S, the full `make dst` sweep, runs on the unmutated tree, on `K0`, and on every mutant that
survives tier T. A tier-T survivor is called a survivor of DST only if its sweep's red set equals
`K0`'s.

## Verdicts

- **COMPILE_FAIL** — the type check is red. Not a kill.
- **TIMEOUT** — a gate hit its 900 s limit. Recorded as that, not a kill.
- **KILLED AS PREDICTED** — the predicted gate is red and, where a signature is named, the gate's
  log contains it.
- **KILLED OTHERWISE** — some gate is red, and it is not the predicted gate or signature. This
  includes a mutant predicted to survive.
- **SURVIVED T** — every tier-T gate is green. Goes to tier S.
- **INCONCLUSIVE** — the mutated branch was not reached at baseline.

A kill is read from a gate's exit status. The signature is read from that gate's own log.

## The mutants, and the prediction for each

Derived from the fault catalogue's `logical_transition` text and from two rules the source states
in comments, not from the tests. The executable form is `tmp/spike/mutants.py`
(sha256 `d6f33ac159d7a567…` when this was written); it refuses a replacement that does not match
exactly once. Every mutant was dry-run applied and restored before this was written.

| id | site | rule it breaks | edit | predicted | gate | signature |
|---|---|---|---|---|---|---|
| K0 | `session.ail:3880` | none: control | trailing comment | SURVIVE | | |
| K1 | `session.ail:2354` | a discarded successor drops the reads it carried | third env read threaded from `r_persist` | KILL | `strict_replay` | `[discovery-env-read-under-recorded]` … `'MOTOKO_RETRY_STREAM_ERROR'` |
| M1 | `session.ail:3887` | retry: `step_idx` advances, so the retry consumes budget | `step_idx: step_idx` | SURVIVE | | |
| M2 | `session.ail:3892` | retry: the world advances to the exchange's successor | `world_state: st.world_state` | KILL | `corpus_pr` | none named |
| M3 | `session.ail:3920` | non-retryable: the run finalizes as `TermProviderFailure` | `TermSuccess` | SURVIVE | | |
| M4 | `session.ail:3387` | empty stop: the record is appended to the returned trace | return the trace without the append | SURVIVE | | |
| M5 | `session.ail:3386` | empty stop: the record is projected | drop the `ledger_emit` | KILL | `corpus_pr` | the `empty_stop_finalize` branch counter |
| M6 | `session.ail:3613` | approval: passing `st` for `post` freezes the queue | `post` → `st` on the denied arm | KILL | `corpus_pr` | none named |
| M7 | `tool_phase.ail:281` | `ToolFailed` is rendered with its own `fault_class` | label it `ToolDeadlineExceeded` | KILL | `corpus_pr` | the `ToolFailed` branch counter |
| M8 | `tool_phase.ail:286` | a mismatch message carries the id that was got | `got_id` := `expected_id` | SURVIVE | | |
| M9 | `recovery.ail:27` | a retry needs remaining budget above 1 | drop the conjunct | SURVIVE | | |
| M10 | `recovery.ail:25` | only a retryable error is retried | `retryable` → `true` | KILL | `corpus_pr` | `NON-RETRYABLE` |
| M12 | `session.ail:2387` | the filesystem read's successor is carried like the env reads' | return `r_headless.next_state` | KILL | `strict_replay` | `[discovery-under-recorded]` |

Seven predicted kills, six predicted survivors.

**Why six survivors are predicted**, so the predictions can be wrong for a stated reason:

- `M1`, `M3`, `M4`: each breaks something an invariant family names — `BoundedProgress`,
  `OutcomeAgreement`, `EmissionParity` — and no gate evaluates those families on a run that takes
  the branch. `M3`'s run summary still carries the error text `corpus_pr`'s counters read.
- `M8`: nothing reads the detail of a tool fault message.
- `M9`: the mutated condition only differs when a retryable error arrives with one step of budget
  left. The contract column should be red for `M9` and `M10`; that is the existing
  `verify_contract_mutations.sh` result, and 035 asks whether execution sees it too.
- `K0`: a comment.

`M9` and `M10` also carry a contract prediction: `ailang verify` red on both, green on every other row.

## Out of scope

- The kill matrix, a mutation score, or any rate. Thirteen hand-written rows give none.
- Any new gate, `make` target or CI change. The `Makefile` edit in this worktree gives `corpus_pr`
  a private output path and exists only so another session's sweep cannot overwrite it.
- Fixing a survivor. A survivor is reported; a test for it is the plan's work.
- Generator policy (035 §6), a second profile, AST-level operators.

## Guardrails

- **It never merges.** Source edits live only in this worktree, one at a time, and the tree is
  restored and its hash compared after every mutant.
- **Nothing here touches the main checkout.** Live Motoko sessions compile `src/core` from it.
- **The host is checked before every mutant, and the check is called.** `run_all.sh` waits for a
  one-minute load below 3.0 and aborts after 15 minutes instead of proceeding.
- **A red baseline stops the spike.** So does a `K0` that is not green.
- **Predictions are not edited after the run.** The table above and `mutants.py` are the record. The
  hash is self-attested: `tmp/` is ignored by git.

## Amendment, 2026-10-05 18:59 UTC — before any mutant ran

The first launch stopped at its own guard, on the unmutated tree. Recorded here because it changed
the runner and the scorer after the sections above were written.

- **What happened.** The runner ran all five gates in parallel. `corpus_pr` came back red with every
  content check green and one failure: `the PR corpus target took 207000 ms against a declared
  ceiling of 180000 ms`. Alone it takes 79 s. The `Makefile` says exactly this at `:620-632` and
  runs the target alone for that reason (`DST_TIMED_TARGETS`); the runner had not read it.
- **Runner.** `corpus_pr` now runs alone, first, as `make dst` runs it. The other four gates run in
  parallel after it. The mutant table and every prediction are unchanged (`mutants.py` is still
  `d6f33ac159d7a567…`).
- **Scorer.** A gate that is red only on its wall-clock ceiling is scored TIMEOUT, not KILLED: it
  measured the machine. A gate red on the ceiling and on something else is still a kill. Both cases
  are planted in `score_selftest.py`, and the real parallel baseline (`out/baseline-1`) scores as
  `TIMEOUT corpus_pr(ceiling)`.
- **What it says about the gate.** `corpus_pr`'s verdict depends on wall time. Under host contention
  it is a false red, not a missing verdict. A mutant that only slows the bank would also show up
  here, so a TIMEOUT row is rerun once on a quiet host before anything is concluded from it.

## Part 2, 2026-10-06 — the invariant set over the bank's real runs

Written after part 1 was finished and the unmutated probe had run, and before any mutant was run
through the probe. Part 1's findings note names this as the measurement it did not make.

**The question.** Part 1 found two mutants that survive `make dst` and said why: no gate evaluates
the invariant set on a real run that takes a recovery branch. If the set *were* evaluated on the
bank, would it catch them? "Yes" makes the remedy wiring. "No" makes it oracle strength, which is
RESEARCH §3.3's question in its own words.

**The instrument.** `scripts/dst/spike_families_on_bank.ail` is `corpus_pr_dst.ail` verbatim with
one added entry point. It runs the same sixteen members through the same driver configuration,
bridges each run with `dst_execution.execution_of`, and prints the rules `evaluate()` reports. It
never merges. Two declared budget settings, both printed:

- **A** — the driver's structural bound: a 12-step budget and "a retry needs remaining budget above
  1" give at most 11 retries; no decision budget is declared.
- **B** — `stream_parity_dst.ail`'s literal `12, 3`, the only precedent in the tree.

**Already measured, unmutated.** Under A the set reports **no finding on any of the sixteen
members**, including every member that takes a recovery branch. That is the survival half, and it
was not guaranteed. Under B, seven members report `decision-budget-exceeded`: a decision budget of
12 was declared for a six-step script and does not transfer to a twelve-step run. B is kept for its
retry bound and its decision budget is read as mis-declared, not as a driver fault.

**Q6 — Would wiring be enough?**
- *Confirms* if `M1` and `M3` each add a finding under A that the unmutated run does not have, and
  `K0` adds none.
- *Falsifies* if either stays clean. Then that mutant is an oracle gap: the family that states the
  obligation does not check it.

**Q7 — Which family sees which mutant?** All thirteen rows, one probe run each. A row is RED when it
carries a member-and-rule pair the baseline lacks.

**Predictions**, in `tmp/spike/predictions2.tsv` (sha256 `3129a908a6650fff…`) with a reason each:

| id | A | B | rule expected if red |
|---|---|---|---|
| K0 | clean | as baseline | |
| K1 | clean | as baseline | |
| M1 | **RED** | **RED** | `bounded-progress:provider-step-repeated` |
| M2 | clean | **RED** | `bounded-progress:retry-bound-exceeded` |
| M3 | clean | as baseline | |
| M4, M5, M6, M7, M8, M9, M12 | clean | as baseline | |
| M10 | clean | **RED** | `bounded-progress:retry-bound-exceeded` |

So the prediction for Q6 is that it **falsifies on `M3`**: `outcome_agreement_findings` compares the
outcome with the summary's error text and never reads `finish_reason`
(`dst_invariants.ail`, the `agree` match). Under A only `M1` is predicted red, of thirteen.

**Scorer.** `tmp/spike/score2.py`; `score2_selftest.py` plants nine cases built from the real
baseline output — a new finding under A, under B only, the baseline's own B finding repeated, a
trajectory change with no finding, a missing member row, no end line, a non-zero exit, an
unparseable row — and all nine come back as named.

**Out of scope.** Adding the probe to any gate; changing a family; a second profile.

## Part 3, 2026-10-06 — the tool handoffs

Written before any part-3 row ran. Asked for after part 2, which predicted from reading that a
driver dropping the world successor **at the tool handoff** would erase the evidence
034's P1 and P3 are meant to read. Part 1 and 2 had no mutant there.

**The sites.** The driver takes the world back from tool execution in three places, each with a
comment stating the rule:

| id | site | edit |
|---|---|---|
| T1 | batch finished, `session.ail:3692` | `done.world` → `st.world_state` |
| T2 | batch interrupted by an approval, `session.ail:3694` | `pending.world` → `st.world_state` |
| T3 | approved call executed, `session.ail:3623` | `executed.next_state` → `post.world_state` |

**Reach is measured, not assumed.** A handoff that carries no advance makes its mutant a no-op.
So each site also gets a probe, `P1`–`P3`: the same expression, unchanged when the successor's
`ordinal` equals the predecessor's, and `1 / 0` when it does not. A gate that goes red on `P<n>`
with `panic: division by zero` executed that handoff with a real world request. A gate that stays
green never did, and its verdict on `T<n>` is not a survival. The primitive was tried first on a
scratch program: silent when the ordinals match, a panic and exit 2 when they differ.

**Check set.** Part 1's tier T, plus `world_state` (the WI-A12 advancement probe), plus part 2's
bank probe. `corpus_pr` alone and first. An unmutated `baseline-3` runs first and must be green.

**Q8 — Which gates reach each tool handoff?** No pass or fail; a map.

**Q9 — Is each reached mutant killed, and by what kind of check?**
- *Confirms part 2's reading* if the invariant set on the bank stays clean under a mutant the bank
  reaches, while a gate that holds the log against the wire goes red.
- *Falsifies it* if the set reports a finding there.
- A mutant no gate reaches is NOT REACHED, and that is a result about the worlds, not the mutant.

**Predictions**, in `tmp/spike/predictions3.tsv` (sha256 `202e24b062488b27…`):

| row | predicted |
|---|---|
| P1 | reached by `stream_parity`, `ledger_parity`, `world_state`; not by the bank, whose policy sends every call to approval |
| P2 | reached by nothing |
| P3 | reached by `corpus_pr`, `strict_replay`, `discovery` and the bank probe |
| T1 | red on `world_state` and `ledger_parity`; `stream_parity` reaches it and stays green |
| T2 | NOT REACHED |
| T3 | red on `corpus_pr`, `strict_replay`, `discovery`; the invariant set on the bank stays clean |

**Scorer.** `tmp/spike/score3.py`; `score3_selftest.py` plants eleven cases — reached and killed,
reached and green, reached only on the bank, not reached, a probe red without the panic, a mutant
red where the probe did not reach, the ceiling-only red, a missing step, a type-check failure, the
families red on the bank — and all eleven come back as named.

## Part 4, 2026-10-06 — a prototype of the two rule changes and the provider-call balance

The predictions file was written and hashed before the eighteen rows were launched
(`tmp/spike/predictions4.tsv`, sha256 `13b3103ff2fab3f2…`, recorded in `out4/sequence.log`). This
section was written while they ran.

**Why.** Parts 1 and 2 left two mutants that survive `make dst` and that the invariant set does
not see even on the bank. The operator asked for recommendations and accepted four:

1. Outcome agreement becomes exact and two-sided: the outcome is `Ok` if and only if the summary
   finished `stop`. At HEAD one finalize site returns `Ok` and it is the success one
   (`session.ail:3402`).
2. New rules get their own `Violation` constructors in the real change. **The prototype reuses
   existing constructors**, because it never merges and a constructor costs five sites.
3. Of the discovery census, only the provider-call balance goes on the bank now. The tool and
   approval balances are a separate item: the scripted gates build those counts from a scripted
   world's cursors (`strict_replay_dst.ail:368`), which a generated world does not have.
4. No decision budget is declared. `dst_invariants.ail` says a bound it chose "would be a bound no
   profile agreed to". The step budget comes from the run's own configuration, 12.

**The prototype.** `tmp/spike/proto_apply.py` makes four exact-once edits to
`src/core/dst_invariants.ail` in this worktree: the finish-reason condition in
`outcome_agreement_findings`, and in `bounded_progress_findings` a repeat check over the step
numbers the **driver** put on its own provider-call records in the returned trace. Three more
rules are computed in the probe (`families_probe2`), from the run's configuration and its two
channels: provider calls must not exceed the step budget; no retry with one step left; provider
calls in the trace must equal provider interactions in the world's log.

**Survival, measured before any mutant.** With the prototype applied to the unmutated tree:
`make invariants` passes, `make stream_parity` passes with its pinned rule sets unchanged, the
module's nine inline tests pass, and the probe reports nothing on any of the sixteen members. The
census balances on every member.

**Q10 — Do the two survivors turn red, and does nothing healthy?**
- *Confirms* if `M1` and `M3` each add a finding, and the unmutated bank and `K0` add none.
- *Falsifies* if either survivor stays clean, or if a control goes red.

**Q11 — What does the prototype still not see?** Eighteen rows; no pass or fail.

**Predictions.** `M1`, `M3`, the mirror `M3m` and the known-bad `K2` red in the invariant set;
`M1`, `M2` and `M9` red in the probe-side rules; the other eleven rows clean in both, among them
`T3`, which the bank reaches and whose lost records are tool records.

**Out of scope.** New constructors, mutant rows in `invariants_dst`, a `make` target, the tool and
approval balances, any change on `main`.

## Part 5, 2026-10-06 — a prototype of the amended rules, after two reviews

The predictions file was written and hashed before the 24 rows were launched
(`tmp/spike/predictions5.tsv`, sha256 `b264d63c0068ffd8…`, recorded in `out5/sequence.log`). This
section was written after they ran.

**Why.** ADR-003 v0.1 was reviewed separately by Codex (GPT-6-Astra) and Claude Fable 5.1. Both
found rules that pass defects they are meant to guard, and one found a witness v0.1 had missed.
The detector discipline says a detector found unsound in review is built, not respecified. So the
amendment's rules were run before they were written into the ADR.

**The prototype.** `proto2_apply.py`: in `dst_invariants.ail`, outcome agreement by the reason the
error code implies, and the no-repeat rule over the driver's own steps. In the probe
(`families_probe3`), six gate checks over the run's configuration, its returned trace and the
delta of its world: calls within the budget; no retry with one step of budget or less; steps
numbered from zero without a gap; a provider-call balance; a tool-dispatch balance; contiguous
request ordinals.

**Rows.** The eighteen of part 4 and six from the reviews (`mutants5.py`): a provider failure
reported as `max_steps`; a suspension reported as an internal failure; a retry that advances by
two; a failure finalize that drops the capture read's successor; a step machine that allows one
call past the budget; a retry that keeps the successor's log and rewinds its generator.

**Survival, measured before any mutant.** `make invariants` and `make stream_parity` pass, the nine
inline tests pass, and the probe reports nothing on any of the sixteen members.

**Q12 — Does each amended rule go red on the mutant written against it, and nothing healthy?**
- *Confirms* if the first five review mutants and the earlier rows go red on the rule named for
  them, and the unmutated bank and `K0` stay clean.
- *Falsifies* if any stays clean, or a control goes red.

**Predictions.** Red in the set: `K2`, `M1`, `M3`, `M3m`, `R1`, `R2`. Red in the gate checks: `M1`,
`M2`, `M6`, `M9`, `T3`, `R3`, `R4`, `R5`. Clean in both: the other eleven, among them `R6`, the
generator rewind, which one reviewer had already run.

## Part 6, 2026-10-06 — the journal control, with the prototype

This section was written after the runs. There is no predictions file for this part: nothing was
predicted for the comparison, and the one expectation stated before its run is the known-bad
control's, below.

**Why.** ADR-003 D6, as ruled, makes the other real-run callers of `evaluate` the first control
before any rule is accepted. They are in project 013's evaluator (`src/eval/journal/`), and
`make eval_matrix` is the target that runs them. Running it with the prototype costs under an hour
and says before a plan is written whether D2 or D3 turns a healthy journal run red.

**Runs**, in the spike worktree at `259265b5`, one after the other (`drive6.sh`):
1. `make eval_matrix` on the unmutated tree.
2. The same with `proto2_apply.py` applied to the working tree, hash-checked against part 5's.
3. A known-bad control (`control6.sh`): the prototype with one wrong row in D2's table,
   `StepBudgetExhausted` implying `error`, run against `witness_live_test.ail` and
   `candidate_checks_live_test.ail` alone. Stated before it ran: the two suites should go red if
   they evaluate a suspended run.

**Comparison** (`compare6.py`): each suite's exit code, each case's observed verdict, first
finding and position, and each case's join status. A file or row missing on one side is reported,
never counted as equal.

**Q13 — Does the prototype add anything to the matrix's baseline?**
- *Confirms the rules are safe there* if the two runs are identical and the known-bad control is red.
- *Falsifies* if any suite or row differs, or the known-bad control stays green.

## What survives, and where it goes

`NOTE-spike-findings-mutation-operator-feasibility.md`, beside this file: one table, the five
verdicts, the prediction score, what it does not establish, and the corrections it owes to
RESEARCH §3.3 and to 035.
