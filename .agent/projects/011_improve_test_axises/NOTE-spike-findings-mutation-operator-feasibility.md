# Findings: do single-site mutants of the driver's recovery branches get killed?

Date: 2026-10-05, finished 2026-10-06 00:10 UTC. Parts 2, 3 and 4 added 2026-10-06. Status: complete.

_Executed `PLAN-spike-mutation-operator-feasibility.md` in full, with one recorded deviation.
**Q1, Q2 and Q3 confirm. Q4: of eleven mutants, nine turn `make dst` red and two do not. Q5
falsifies the cost figure §3.3 was planned on.**_

_Revision: worktree `/workspaces/motoko_agent-spike-mut`, branch
`spike/011-mutation-operator-feasibility`, forked from `259265b5`. **The branch never merges.** It
carries one `Makefile` edit (private output paths for seven fixed `/tmp` names) and no source
change. Each mutant was applied, run and restored, and the hash of the three mutated files was
compared after every one: `FINAL INTEGRITY: PASS` on both sequences._

_Toolchain: AILANG v0.47.2 `e939cba`, the only `ailang` on the host. Every number below was measured
in that worktree; none is inherited._

## The headline

**Two mutants survive the whole of `make dst`.** Each is one edit in a recovery branch the corpus
reaches, each type-checks, each changes the wire, and each sweep's set of failure lines is identical
to the unmutated sweep's.

- `M1` — a retried stream error consumes no step budget (`session.ail:3887`, `step_idx: step_idx`).
- `M3` — a non-retryable provider failure finalizes as success (`session.ail:3920`, `TermSuccess`).
  All seven failure summaries in the corpus read `"finish_reason":"stop"` while still carrying
  `"error":"generated E_PROVIDER_PROTOCOL"`, and the returned outcome is still `Err`.

Both break an obligation an invariant family states: `BoundedProgress` and `OutcomeAgreement`. The
families did not see them, because **no gate evaluates the invariant set on a real run that takes
a recovery branch.** `evaluate()` meets a run-produced execution in `stream_parity` only, on a
two-step script with no fault in it. That gate killed none of the thirteen rows and was green in
all seven sweeps.

**Wiring the set to the corpus would not have caught them either.** Part 2 measured it: with
`evaluate()` run on all sixteen bank members at the driver's own bounds, none of the eleven mutants
adds a finding. The two survivors are gaps in what the families check, not in where they run.

**The other nine are caught, by five different kinds of check.** Where a mutant was caught says
more than whether it was:

| kind of check | caught | example |
|---|---|---|
| presence on the generated bank's wire | `M5`, `M7` | `the wire carries NO record of the recovery branch …` |
| a class or code check on the bank | `M6`, `M10` | `declared but never observed: approval_denied` |
| the discovery contract on scripted scenarios | `M6`, `M12` (and `K1`) | `[discovery-env-read-under-recorded]` |
| an exact assertion in a scripted fixture or unit test | `M4`, `M8`, `M9` | `test_stream_retry_policy_test_1` |
| a value pinned from an earlier run, about something else | `M2` | `seed 7 did not report 123 records` |
| the invariant families on a real run | none | |

The generated runs give breadth and are checked for presence. The exact assertions live in scripted
fixtures, where someone wrote one. `M1` and `M3` fall where the bank reaches the branch and nobody
wrote one.

## Instrument calibration, before any number below

- **Scorer.** `tmp/spike/score_selftest.py` plants fifteen cases — every verdict, a signature in the
  wrong gate's log, a red on the wall-clock ceiling alone, a red on the ceiling and a real failure —
  and all fifteen come back as named. It ran before the scorer saw a real result.
- **Known good.** `K0`, a comment added in the retry branch: every targeted gate green, and the
  corpus wire identical to the unmutated run's line for line once `duration_ms` is masked (0 of
  1,609 lines differ). That is also a determinism check across two processes.
- **Known bad.** `K1`, the demo's mutant: `strict_replay` red on
  `[discovery-env-read-under-recorded]` naming `MOTOKO_RETRY_STREAM_ERROR`, as predicted;
  `discovery` and `ledger_parity` red as well.
- **The runner failed once, on the unmutated tree, and its guard stopped it.** The first launch ran
  five gates in parallel and `corpus_pr` went red on its wall-clock ceiling, 207 s against 180 s,
  with every content check green. See the plan's amendment. No mutant had run.

## Q1 — Does a text-level operator work here? **CONFIRMS.**

Thirteen of thirteen rows are one replacement of text that occurs once, type-check, and run. One
needed an anchor because its text occurs twice (`M12`). None failed to compile. RESEARCH open
question 2 does not need the AST route to start.

## Q2 — Is the runner calibrated? **CONFIRMS.** See above.

## Q3 — Is each mutated branch reached? **CONFIRMS.**

`corpus_pr`'s wire witness on the unmutated tree, and identically on `K0`:
`approval_denied×35 empty_stop_finalize×1 ToolFailed×3 ToolCorrelationMismatch×5
ToolDeadlineExceeded×3 stream_error_retry×4 provider_failure_finalize×11 malformed_arguments×6`,
against 67 executed dispatch batches. No row is INCONCLUSIVE.

## Q4 — Which gate kills which mutant?

### Tier T: the targeted gates

`T` is the type check, `Z3` the contract on the retry predicate, then the five gates. `·` is green.

| id | rule broken | T | Z3 | corpus_pr | strict_replay | discovery | stream_parity | ledger_parity | predicted |
|---|---|---|---|---|---|---|---|---|---|
| K0 | none (comment) | · | · | · | · | · | · | · | survive ✓ |
| K1 | env read's successor dropped (the demo's) | · | · | · | **red** | **red** | · | **red** | kill ✓ |
| M1 | a retry consumes step budget | · | · | · | · | · | · | · | survive ✓ |
| M2 | a retry advances the world | · | · | · | · | · | · | · | kill ✗ |
| M3 | a non-retryable failure finalizes as failure | · | · | · | · | · | · | · | survive ✓ |
| M4 | the empty-stop record is in the returned trace | · | · | · | · | · | · | · | survive ✓ |
| M5 | the empty-stop record is projected | · | · | **red** | · | · | · | · | kill ✓ |
| M6 | approval: continue from `post`, not `st` | · | · | **red** | **red** | **red** | · | · | kill ✓ |
| M7 | `ToolFailed` is labelled `ToolFailed` | · | · | **red** | · | · | · | · | kill ✓ |
| M8 | a mismatch message carries the id that was got | · | · | · | · | · | · | · | survive ✓ |
| M9 | a retry needs budget above 1 | · | **red** | · | · | · | · | · | survive ✓ |
| M10 | only a retryable error is retried | · | **red** | **red** | · | · | · | · | kill ✓ |
| M12 | filesystem read's successor dropped | · | · | · | **red** | **red** | · | **red** | kill ✓ (other check) |

Five of eleven real mutants are killed here; six go on to tier S. The type checker passes all
thirteen rows.

What killed the five, in the gate's own words:

- `M5`, `M7` — `corpus_pr`: `the wire carries NO record of the recovery branch
  'session.c2_loop/empty_stop_finalize' executing`, and the same for
  `'tool_phase.tool_outcome_message/ToolFailed'`.
- `M10` — `corpus_pr`: `10 stream_error_retry record(s) on the wire carry a NON-RETRYABLE provider
  error code`.
- `M6` — `corpus_pr`: `declared but never observed: approval_denied`. `strict_replay`:
  `[discovery-under-recorded] the driver made 3 'expect_approval' request(s) and the interaction
  log records 1`. This is the assertion the comment at `session.ail:3587` promises.
- `M12` — `strict_replay`: four `[discovery-env-read-under-recorded]` findings, naming
  `MOTOKO_CONFIG`, `MOTOKO_MODELS_FILE`, `MOTOKO_PROFILE_DIR` and `MOTOKO_REPO`, the env reads made
  inside the context-limit resolution. **No finding names the file read itself.** The one non-env
  handoff tried was caught by the env rule because the dropped successor carried env reads too.
  Whether a dropped successor carrying only a file read is caught is still open.

### Tier S: the full sweep on each tier-T survivor

The reference is the unmutated sweep, which is red on four targets in this worktree (see Q5).
"Beyond baseline" is what a mutant adds to that.

| id | sweep | red beyond baseline | what the gate says | verdict |
|---|---|---|---|---|
| M1 | 1,817 s | none | failure lines identical to the unmutated sweep | **survives `make dst`** |
| M3 | 1,839 s | none | failure lines identical to the unmutated sweep | **survives `make dst`** |
| M2 | 1,838 s | `depth_canary` | `seed 7 did not report 123 records — the harness did not measure what this pin describes`; the same for seed 23 at 217 | red, by a pin about something else |
| M4 | 1,871 s | `phase_c_l1` | three scenarios fail, among them `phase_c.c2.empty_stop_floor_without_guard` | killed, by a check about the rule |
| M8 | 1,770 s | `world_state` | `a wrong-call-id answer is a correlation fault — third tool result did not report the correlation mismatch` | killed, by a check about the rule |
| M9 | 1,875 s | `test_coverage` | `src/core/recovery.ail: 5/7 passed`; `test_stream_retry_policy_test_1` and the contract property fail | killed, by a unit test about the rule |

- **`M2` is the case to read twice.** It is the demo's defect class — a discarded world successor —
  moved from `session_policy_init` to the retry branch. The bank's retries go from 4 to 33, four of
  sixteen members change, and promoted `seed-141` flips from `Ok` to `Err`. `corpus_pr`,
  `strict_replay`, `discovery`, `stream_parity` and `ledger_parity` pass. It is caught because
  `depth_canary` pins a record count per seed so that its recursion-depth measurement stays valid,
  and two of its three seeds changed. By the mutation discipline's rule 3 that is a different test
  failing, and the message reads as a harness fault. It is still a red sweep.
- **The newly red targets respond to behaviour, not to the text of an edit.** `depth_canary`,
  `phase_c_l1`, `world_state` and `test_coverage` were rerun on `K0` and all four pass.

### What each tier-T survivor changed

Measured against `K0`'s corpus wire, `duration_ms` masked.

| id | wire lines that differ | bank rows that change | what is visibly different |
|---|---|---|---|
| M1 | 272 | 1 of 16 | `seed-19` runs 45 interactions, not 41: the retry cost no budget, so the run goes on |
| M2 | 350 | 4 of 16 | retries 4 → 33; `seed-9` and promoted `seed-141` flip `Ok` → `Err` |
| M3 | 14 | 0 | all seven `"finish_reason":"error"` summaries become `"stop"` |
| M4 | 0 | 0 | nothing on the wire: only the returned trace loses the record |
| M8 | 294 | 0 | every mismatch message reports `got_id` equal to `expected_id` |
| M9 | 5 | 0 | one extra retry, at step 11 of a 12-step budget |

### The prediction score

Twelve of thirteen tier-T verdicts were predicted correctly. Of the five rows where the failing
check was also named in advance, four matched.

- **`M2` was predicted killed by `corpus_pr` and was not.** The counters only require one, and
  member identities are recomputed each run, never pinned.
- **`M12` was killed by the predicted gate through a different rule.**
- **The stated reason for `M9` was wrong though the verdict was right.** The plan says the mutated
  condition would probably not be reached. It was: the wire shows the extra retry.
- **The plan's reason for `M4` was incomplete.** It says no gate evaluates `EmissionParity` on a run
  that takes the branch. True of `evaluate()`; `phase_c_l1` has scripted scenarios on the empty-stop
  floor and caught it. No tier-S prediction was written, so this is a correction, not a score.

## Q5 — What does a mutant cost? **FALSIFIES the planning figure.**

- **Targeted set: 3.7 minutes per mutant.** Thirteen rows in 48 minutes, `corpus_pr` alone and the
  other four gates in parallel.
- **Full sweep: 3,032 s cold at `-j8`; 1,770 to 1,875 s warm at `-j4`.** RESEARCH §3.3 budgets 196 s
  per sweep and 5.5 h per 100 mutants. At the warm figure 100 mutants are about 51 hours.
- **Why.** `src/core/session.ail` no longer fits the compile cache. Every run that imports it prints
  `CACHE_WRITE_FAILED … ARTIFACT_TOO_LARGE … using fresh compilation`; the limit is a constant,
  `maxArtifactBlobBytes = 16 << 20` (`internal/pipeline/cache_artifacts.go:27` at `e939cba`), with
  no environment override. The sweep's log records fifty fresh compilations of that module, a lower
  bound since some recipes discard stderr; thirty-two are serial, inside `smoke_parity`.
- **The unmutated sweep is not green in this worktree.** Four targets fail on an extension-inventory
  check: `driver_plus_compose`, `driver_plus_no_ops`, `ext_hook_scope`, `ext_hook_scope_selftest`.
  Two targets listed in `DST_KNOWN_RED` pass. Not investigated, and not checked against `main`'s CI.

## Part 2 — would the invariant set catch them if it ran on the bank? **FALSIFIES.**

Planned in the plan's *Part 2* section before any mutant went through the probe.

**The instrument.** `scripts/dst/spike_families_on_bank.ail`: `corpus_pr_dst.ail` verbatim plus one
entry point that bridges each member's run with `execution_of` and prints what `evaluate()` reports.
Sixteen members, one process, 40 seconds. Two declared budget settings: **A**, the driver's
structural bound (at most 11 retries on a 12-step budget, no decision budget), and **B**,
`stream_parity_dst.ail`'s literal `12, 3`.

**Calibration.**
- *Known good.* The unmutated tree and `K0`: no finding on any of the sixteen members under A,
  including every member that takes a recovery branch. This was not guaranteed and it is a result:
  the set does not over-fire on the bank.
- *Known bad.* `K2`: the failure finalize returns `Ok` while the summary keeps its error text. A is
  red with `outcome-agreement:outcome-summary-disagree` on the five members that end in a provider
  failure. **`K2` was added after the thirteen rows had run**, because without it "nothing is red
  under A" could have been the probe's answer to anything. Its prediction was written before it ran.
- *Scorer.* `score2_selftest.py`, nine planted cases built from the real baseline output, all as named.

**The result.** "Runs changed" counts members whose outcome or log length differs from the
unmutated run.

| id | runs changed | A | B | predicted |
|---|---|---|---|---|
| K0 | 0 | clean | clean | ✓ |
| K1 | 16 | clean | clean | ✓ |
| K2 | 5 | **red** | **red** | ✓ |
| M1 | 1 | clean | clean | ✗ predicted red |
| M2 | 4 | clean | **red**: `retry-bound-exceeded` on three members | ✓ |
| M3 | 0 | clean | clean | ✓ |
| M4, M5, M7, M8, M9 | 0 | clean | clean | ✓ |
| M6 | 12 | clean | red on `decision-budget-exceeded` only | ✗ on B |
| M10 | 4 | clean | **red**: `retry-bound-exceeded` on three members | ✓ |
| M12 | 16 | clean | clean | ✓ |

**Under A, none of the eleven mutants adds a finding.** Under B two do through the retry bound, both
already caught elsewhere, and one through a decision budget that is red on seven members of the
*unmutated* bank: 12 was declared for a six-step script and does not transfer to a twelve-step run.

**Why the two survivors are invisible, each located by a pair of rows.**

- **`M3`.** `outcome_agreement_findings` compares the returned outcome with the summary's error
  text and never reads `finish_reason`. `K2` changes the outcome and is caught; `M3` changes the
  finish reason and is not.
- **`M1`.** `provider-step-repeated` reads the step the *recorder* logs, and the recorder computes
  it as the number of provider calls already in the world's log (`stub_step.ail:486`). That is the
  world's cursor, not the driver's `step_idx`. The driver's own `provider_call_prepared` events
  carry the defect in plain sight — for `seed-19` the steps read `0 1 2 3 4 5 6 7 8 8 9 10 10 11`,
  fourteen calls on a twelve-step budget — and no family reads them. The prediction assumed the
  logged step was the driver's.

**Why the set is blind to the rest.** From reading, one line each; not separately tested.

- `K1`, `M2`, `M6`, `M12` drop a world successor. The interaction log the families read is carried
  *in* that world, so the dropped records take their own evidence with them. `strict_replay` and
  `discovery` catch `K1`, `M6` and `M12` because they hold the log against a second channel, the
  wire or the source. `evaluate()` has one.
- `M4`, `M5` differ only in whether a record reached the wire or the returned trace. A single
  execution carries the trace and not the wire.
- `M7`, `M8` change what a fault message says. The families read what the world served.
- `M9`, `M10` change how many retries happen. That shows only against a declared bound, and the
  driver's own bound is too loose to see either.

**What this adds up to.** On this sample the single-execution families check that a trace is
well-formed, and a wrong recovery is still well-formed. What catches wrong recoveries here is a
comparison across two independently written channels, or an exact assertion someone wrote for one
scenario. That is the DST report's "reachability is not oracle strength" as a measurement.

**Prediction score, part 2.** Setting A: thirteen of fourteen, the miss being `M1`. Setting B:
twelve of fourteen, missing `M1` and `M6`.

## Part 3 — the tool handoffs. **CONFIRMS part 2's reading.**

Planned in the plan's *Part 3* section before any row ran. The driver takes the world back from
tool execution in three places. Each got a mutant that keeps the pre-tool world (`T1`–`T3`) and a
reach probe (`P1`–`P3`) that is silent unless that handoff carries a real world request and then
panics. An unmutated `baseline-3` was green on all six gates and the bank probe first.
`FINAL INTEGRITY: PASS`.

| handoff | gates that reach it | gates red on the mutant | invariant set on the bank | verdict |
|---|---|---|---|---|
| `T1` batch finished, `session.ail:3692` | `discovery`, `stream_parity`, `ledger_parity`, `world_state` | `discovery`, `ledger_parity`, `world_state` | bank does not reach it | killed |
| `T2` batch interrupted by an approval, `:3694` | none | none | bank does not reach it | **not reached** |
| `T3` approved call executed, `:3623` | `corpus_pr`, `strict_replay`, `discovery`, the bank | `corpus_pr`, `strict_replay`, `discovery` | **clean** | killed |

- **`T3` is the direct test of part 2's reading, and it holds.** The bank executes every tool
  through this handoff. With the successor dropped, the invariant set over the bank reports
  nothing, while `discovery` says `[discovery-under-recorded] the driver made 3 'expect_tool'
  request(s) and the interaction log records 0`, `corpus_pr` says `declared but never observed:
  ToolFailed, ToolCorrelationMismatch, ToolDeadlineExceeded`, and `strict_replay` reports a tool
  request carrying a different call id. The log the families read is carried in the world that
  was dropped.
- **`stream_parity` reaches `T1` and stays green.** It is the one gate that runs the invariant set
  on a real execution, it executes this handoff, and it does not notice the tool's successor is gone.
- **`T2` is a gap in the worlds, not a survivor.** No gate executes a tool and then meets an
  approval inside one dispatch, so the comment at `session.ail:3703` states a rule nothing exercises.
- **The bank says nothing about `T1`.** Its policy sends every call to approval, so its batches
  never finish with an executed tool.
- **`ledger_parity` is credited as reaching `T1` by its exit status only.** Its recipe does not
  print the probe's panic, so the scorer flags it; a red on a probe that changes nothing unless it
  fires can only be the probe.

**For 034.** Its P1 and P3 read the world's interaction log and a proposed effect log. `T3` shows
what a dropped tool successor does to a log carried in the world: three tool requests on the wire,
none in the log, and no single-execution rule the wiser. The properties need a count taken from
the driver's own records beside the world-side ones.

**Prediction score, part 3.** Reach: seventeen of eighteen gate cells, the miss being `discovery`
reaching `T1`. Mutants: `T2` and `T3` exactly; `T1` right on five gates of six and wrong on
`discovery`, which goes red.

## Part 4 — a prototype of the fix. **CONFIRMS.**

Planned in the plan's *Part 4* section; the predictions were hashed before the rows ran. The
prototype is two rule changes in this worktree's `dst_invariants.ail` and three rules computed in
the probe. It never merges; it is kept as `tmp/spike/prototype.diff` and `proto_apply.py`, and the
worktree's source is back at HEAD.

**Survival first.** With the prototype on the unmutated tree: `make invariants` passes,
`make stream_parity` passes with its pinned rule sets unchanged, the module's nine inline tests
pass, and the probe reports nothing on any of the sixteen bank members. The provider-call census
balances on every one.

**The rows.** Eighteen, forty seconds each. `FINAL INTEGRITY: PASS`.

| id | invariant set, with the two rule changes | probe-side rules | evidence |
|---|---|---|---|
| unmutated, K0 | clean | clean | |
| K2 known bad | **red**, 5 members | clean | outcome `ok`, summary carries an error |
| **M3** survivor | **red**, 5 members | clean | `the returned outcome is 'err' and the terminal RunSummary reports 'finish_reason='stop''` |
| M3m, its mirror | **red**, 10 members | clean | outcome `ok`, `finish_reason='error'` |
| **M1** survivor | **red**, 4 members | **red**, 1 member | driver step 8 and step 10 each twice on `seed-19`; 14 provider calls on a budget of 12 |
| M2 | clean | **red**, 4 members | provider calls: 12 in the trace, 2 in the log, on three members; 12 against 9 on the fourth |
| M9 | clean | **red**, 1 member | a retry at step 11 of 12 |
| K1, M4, M5, M6, M7, M8, M10, M12 | clean | clean | |
| T1, T2, T3 | clean | clean | |

- **Q10 confirms.** Both mutants that survived `make dst` are red under the prototype, in both
  directions for the outcome rule, and no control is.
- **`M2` is now caught by a check about its rule.** Part 1 found it only through an unrelated pin.
  The census puts the driver's twelve calls beside the two the log kept.
- **`M9` is now caught by execution.** Before, only the contract and an inline test saw it.
- **Q11: what the prototype still does not see on the bank.** Eleven rows. Ten of them are caught
  by another gate in `make dst`: the env and filesystem successor drops (`K1`, `M12`), wire against
  trace (`M4`, `M5`), the approval and tool successor drops (`M6`, `T3`, `T1`), message content
  (`M7`, `M8`) and the retried code (`M10`). `T2` is reached by nothing.

**Prediction score, part 4.** Eighteen of eighteen, both columns.

**What the prototype shows the real change must do differently.**
- **Own constructors.** The driver-step finding is reported through the reused constructor's
  message, `provider step 8 appears 2 times in the interaction log; the cursor did not advance`.
  That is false of this condition: the log is fine and the driver's step is what repeated.
- **No string literal.** The prototype compares against `"stop"`. The real rule should take the
  table from one exhaustive match beside `TerminationReason`.
- **A declared step budget.** Two of the probe-side rules need it. `ExecutionUnderTest` has no such
  field, and adding one touches every site that builds the record.
- **Still unread.** The suspend and park path, which may return `Ok` with another finish reason.

## Three things about the gates, found on the way

1. **`corpus_pr`'s verdict depends on wall time.** Run beside four other gates it is red with every
   content check green. The `Makefile` knows and runs it alone inside `make dst`; run any other way
   on a busy host it is a false red.
2. **When `corpus_pr`'s in-process checks fail, the recipe prints the last 40 lines.** For `M6` those
   are the corpus rendering and `✗ WI-A15 commit 1 FAILED`; the three failing rows are about 180
   lines further up and are not shown.
3. **`stream_parity` is where the whole invariant set meets a real run, and its world has no fault.**
   Its script is one tool step and one prose step (`stream_parity_dst.ail:109`).

## Deviation from the plan

The plan called for a full sweep of `K0` as the tier-S reference. At 50 minutes that sweep was not
run. The unmutated sweep is the reference, and the four targets that any survivor turned red were
rerun on `K0` instead. Recorded before the first survivor sweep finished.

In part 2 the known-bad control `K2` was not in the plan. It was added after the thirteen planned
rows had run and before it was run itself, with its prediction written first.

## What this note does not establish

- **No rate.** Eleven hand-written mutants, chosen by one author who had read the gates first. Nine
  of eleven is a count, not a mutation score.
- **Not that a strengthened family would catch `M1` and `M3`.** Part 2 shows the present ones do
  not and names what each would have to read. Nothing was changed or tested beyond that.
- **Two driver gates could not report.** `driver_plus_compose` and `driver_plus_no_ops` are red at
  baseline, so a mutant that only they would catch reads as a survivor here. Their failure lines did
  not change under `M1` or `M3`.
- **One profile, one bank.** The bank reaches every branch; it does not reach every state in a
  branch.
- **`M12` does not settle the non-env handoff.** See tier T.

## Disposition

**Against RESEARCH §3.3.**
- Its cost basis is void at HEAD. Plan on 3 to 4 minutes per mutant for a targeted set and about 30
  minutes for a warm sweep, until the driver module is back under the cache limit.
- Its matrix of fault classes against invariant families is empty for real runs today, and part 2
  filled in the first column: at the driver's own bounds the set sees none of these eleven mutants
  on the bank. Evaluating the families on the bank is necessary and not sufficient. The first work
  item is two rule changes and a provider-call balance on the bank. Part 4 prototyped all three:
  both survivors go red, the controls stay green, and the existing invariant gates still pass.
- Text-level operators are sufficient to start.
- A tiered design works: the targeted set found six candidates in 48 minutes, and only those needed
  a sweep.

**Against 035.** Its candidate property "a request's returned world successor is carried into
subsequent execution" now has six executed rows: four env handoffs in `session_policy_init`
(EXP-SIBLINGS-04, corrected), the filesystem handoff (`M12`), and the retry branch (`M2`). Five are
caught by a check about the property. `M2` is caught only by an unrelated pin. Its retry-bound row
(`M9`) is executed: the contract and an inline test kill it, and no driver execution does.

**Against the DST demo's third claim.** "strict_replay catches a bug the type checker misses" holds
for the bug planted. The same bug class one function away is missed by `strict_replay` and by every
check written about it.

**For whoever plans the fix — candidates the data names, none built or tested.**
- `OutcomeAgreement`: an `Err` outcome needs a failure finish reason, not only a non-empty error.
  Check the combination table first: `seed-244` ends `Err` on `max_steps`.
- `BoundedProgress`: the driver's own step numbers must not repeat. They are on the wire in
  `provider_call_prepared`; whether they are in the returned trace was not checked.
- Budgets declared per member from the run's own policy, so `M2`, `M9` and `M10` have a bound to break.
- The probe itself is forty seconds for the whole bank. As a gate it would be the cheapest one here.

**Upstream.** `session.ail` exceeding AILANG's fixed 16 MiB cache blob limit is worth an issue
against AILANG or a split of the module here. Not filed.

## Where the evidence is

**On this branch:** `evidence/mutation-spike/` — `mutants.tsv` (generated from the run output),
the scripts, the predictions and the score output. Raw gate and sweep logs are not copied; they
are in the spike worktree until it is removed. The decision drawn from this note is
`ADR-003-judge-recoveries-on-real-runs.md`.

**In the spike worktree:**

`tmp/spike/` in the worktree, ignored by git: `mutants.py` (the table and the predictions),
`run_set.sh`, `run_all.sh`, `sweep_one.sh`, `sweep_all.sh`, `score.py`, `score_selftest.py`, and
`out/` with one directory per row, `sequence.log`, `sweeps.log` and `score.txt`. Part 2:
`scripts/dst/spike_families_on_bank.ail` (untracked, spike only), `tmp/spike/predictions2.tsv`,
`run_probe_all.sh`, `score2.py`, `score2_selftest.py`, and `tmp/spike/out2/`. Part 3:
`mutants3.py`, `predictions3.tsv`, `run_set3.sh`, `score3.py`, `score3_selftest.py`, `out3/`.
Part 4: `proto_apply.py`, `prototype.diff`, `mutants4.py`, `predictions4.tsv`, `run_probe4.sh`,
`score4.py`, `out4/`.
