# REVIEW-001: Codex (GPT-6-Astra) review of ADR-003 (judge wrong recoveries on real runs)

Date: 2026-10-06
Reviewer: Codex CLI, launched with `--yolo -m gpt-6-astra`; the terminal status line confirmed GPT-6-Astra, reasoning effort high. The reviewer itself says it cannot see its variant.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `adr003-astra`, pane `w7:pJ`, worktree `/workspaces/motoko_agent-review-223-astra`. Worked for 19m 28s.
Document reviewed: [ADR-003-judge-recoveries-on-real-runs.md](ADR-003-judge-recoveries-on-real-runs.md) at `f1eb8d9f` (draft PR #223).
Document SHA-256: `52e6adfaf694e336616145b56c2c662cbd2750971d913589458ee7077b1db2b3`.
Status: Assessed; dispositions below, in ADR-003 v0.2, which the operator accepted on 2026-10-06. A second, independent review is in `REVIEW-001-adr-003-claude-fable-5.1.md`.

## Scope

Both reviewers received the same brief (`.review/BRIEF.md` in each reviewer's worktree, sha256
`c2fdf9c212d54273…`) and worked separately, each in its own detached worktree at `f1eb8d9f`.
Neither was told what the other found. The brief asked each to verify the ADR's facts and
coordinates, assess D1 to D8 for soundness including on healthy runs outside the corpus, assess
the rejected options, propose mutants it predicted would pass the ADR's rules, check D8 against
009 ADR-001, and check the experiment's instruments. Reviewers were allowed read-only commands,
`ailang check`, single `ailang run` probes and one-edit mutants in their own worktree, and were
told not to run `make dst`, `make corpus_pr` or any sweep, and not to change anything tracked.

The response below is the reviewer's final message, taken verbatim from its session transcript.
Its links and paths refer to the reviewer's worktree. Both worktrees show only `.review/` as
untracked afterwards.

**One disclosed leak.** This reviewer reports that a process listing it ran showed the other
reviewer's command line; it says it opened none of their files and had already chosen its mutants.

## Reviewer response

*Model: GPT-6-based Codex. The exact model variant and reasoning-effort setting shown in your UI are not exposed to me.*

The core decision is supported: evaluating stronger rules on the fixed bank detects defects the existing invariant set misses. I would retain that direction, but revise the budget definition, soundness boundaries, acceptance controls, and several evidence claims before writing the plan. The spike supports specific detectors; it does not establish general recovery correctness or complete successor preservation.

The commit and ADR SHA-256 match the brief. All tracked files are restored and unchanged.

## Verdicts

| Decision | Verdict | Assessment |
|---|---|---|
| **D1** | **STANDS** | A separate gate over the sixteen fixed-bank runs is justified. This does not cover rotating search, other profiles, or every invariant obligation. |
| **D2** | **NARROWS** | Sound for actual finalized system runs: `Ok` iff `stop`. It is binary success agreement, not exact agreement about which failure occurred. Frame-only park-resume results need separate treatment. |
| **D3** | **STANDS** | No repeated main-loop `ProviderCallPrepared.step` within one run is sound. It does not establish consecutive progress, correct step labels, or termination. |
| **D4** | **NARROWS** | Use the effective `policy.step.step_budget`, with an explicit undeclared representation. Count main-loop prepared calls, and describe the retry rule as the budget conjunct of the recovery contract. |
| **D5** | **NARROWS** | Sound for fresh recording/generated worlds whose provider interactions correspond exclusively to this run’s main-loop calls. Recording alone is insufficient. This detects count imbalance, not complete successor preservation. |
| **D6** | **NARROWS** | The named mutants demonstrate the intended detections on this bank. The controls are insufficient for globally applied rules and do not exercise all boundary cases. |
| **D7** | **STANDS** | Rejecting the existing corpus identity/trajectory pins as a substitute is supported. Rejecting all possible trace snapshots would not be. |
| **D8** | **NARROWS** | No architectural reopening is necessary for this incremental strengthening. However, its identification of D5 with 009’s discovery contract is incorrect, and D3/D4 do not discharge the full bounded-progress obligation. |

## Findings, most important first

### 1. D4 must specify the effective budget, not merely the value supplied at entry

[session.ail:2351](/workspaces/motoko_agent-review-223-astra/src/core/session.ail:2351) normalizes every nonpositive entry budget to **8**, then stores that value in the policy. Consequently, copying an entry argument of `0` into the new execution field would reject a healthy run making any provider call. Copying a negative argument as “undeclared” would suppress checking a run actually bounded at eight.

There are three distinct quantities here:

- The entry argument.
- The normalized policy budget.
- The invariant record’s undeclared sentinel.

The plan must not conflate them. The lower-level decision policy also explicitly supports zero as unlimited; see `src/core/step_machine.ail:103` and its unlimited-budget test at `:605`.

The journal bridge needs particular care: [admission_run.ail:73](/workspaces/motoko_agent-review-223-astra/src/eval/journal/admission_run.ail:73) starts the driver with `List.length(jw.calls)`, rather than simply forwarding the boot budget. Both journal bridges must carry the actual execution policy.

Also specify the retry predicate as **remaining budget ≤ 1 is forbidden**, matching the prototype’s `step >= budget - 1`. “With one step left” alone leaves zero or negative remaining budget unstated.

### 2. D5’s independence holds for the tested drop, but its claimed property is broader than its detector

The trace-side count is genuinely independent of the returned world at the relevant provider handoff. [session.ail:3861](/workspaces/motoko_agent-review-223-astra/src/core/session.ail:3861) appends `ProviderCallPrepared` from local driver values before `witness` drains world-carried pending records. Dropping only the world successor does **not** remove that prepared record. This supports the M2 result.

However, preserving the count does not establish preservation of the successor.

I executed this additional one-edit mutant at `session.ail:3892`:

```ailang
world_state: { capt.world | gen: st.world_state.gen },
```

It retains the successor’s log but restores the predecessor’s generator state. On seed 19:

- Baseline retry steps: `[8]`.
- Mutated retry steps: `[8, 9]`.
- Both provider counts: `12`.
- Existing invariant findings: `[]`.
- Scratch implementations of D2–D5: all true.

The result is recorded in [probe-gen-rewind.txt:184](/workspaces/motoko_agent-review-223-astra/.review/probe-gen-rewind.txt:184), against [the baseline](/workspaces/motoko_agent-review-223-astra/.review/probe-baseline.txt:193). This is an exercised successor-preservation defect invisible to the proposed count balance.

D5 also needs these explicit premises:

- **No additional provider producer.** `ext_ai_step` calls `p.model_step` at `session.ail:1102` without creating a main-loop `ProviderCallPrepared`. A healthy recording extension profile can therefore have more logged provider interactions than prepared records.
- **Matching run boundaries.** Resume resets the trace and step index (`session.ail:2572`, `:2644`) while accepting a supplied world. Comparing a new run’s trace against a cumulative world log would overcount.
- **A recording adapter.** The ADR correctly excludes the nonrecording scripted adapter.

Deferring tool and approval balances is coherent. Their witnesses require separate work, and D5 is independently useful. But neither D5 nor its completion should be described as establishing 035’s whole-successor property.

### 3. D6 needs survival cases that match the scope of the shared rules

There are six acceptance rows but **five distinct source mutants**: the no-step-advance mutant serves both D3 and D4. That reuse is acceptable if acceptance asserts each specific finding separately.

What is missing is a compact set of controls for the cases the rules claim to support:

- Effective/defaulted and undeclared budgets.
- Exactly-at-budget calls.
- A valid retry with two steps remaining, and no retry with one remaining.
- Suspension and resumed runs.
- Park cancellation and frame-only park-resume returns.
- Extension-issued provider calls.
- Journal admission and candidate executions.
- Both directions of D5 imbalance.

The existing `stream_parity` control is valuable because it covers both recording and nonrecording adapters, but its fault-free two-step fixture does not cover these shapes.

The 100-summary survey is not a substitute. My recount produced:

| Finish reason | Summaries | Nonempty error |
|---|---:|---:|
| `stop` | 77 | 0 |
| `max_steps` | 11 | 11 |
| `cost_exhausted` | 1 | 1 |
| `error` | 5 | 5 |
| `compaction_exhausted` | 6 | 6 |

These are **wire summary fields**, not observations of the returned `Result`. Likewise, zero repeated steps among the printed wire events does not validate all returned traces: recipes filter output, some gates fail at baseline, and several paths are absent.

### 4. D2 is sound on terminal runs, but the closed park question needs qualification

The terminal paths I inspected support `Ok` iff `stop`:

- The success finalizer is `session.ail:3402`.
- Suspension constructs `Err` and `TermMaxSteps` at `:2789`.
- Park cancellation routes through `c2_fail` at `:3543`.
- Verifier rejection, solver feedback, nudges, and accepted candidates return through the loop’s existing transitions; they do not introduce a second successful terminal reason.

But [parked_frame_only at session.ail:5584](/workspaces/motoko_agent-review-223-astra/src/core/session.ail:5584) legitimately returns `Ok(plan.history)` **without a terminal summary**. It is reached on unmatched wakes, aborted wakes, and nonparked resume boundaries.

This is not an `Ok` run with a different finish reason; it is a frame in which no run opened. State that distinction explicitly. `execution_of` always constructs `RunCompleted` (`dst_execution.ail:139`), so blindly bridging every `TracedSessionResult` already misclassifies this case.

D2 also does not distinguish `TermProviderFailure` from `TermMaxSteps`, or another failure reason. “Exact” should mean exact binary success agreement unless additional failure classification is intended.

### 5. D8 conflates two different discovery checks

009’s D7 defines the discovery contract as **two executions under the same manifest and inputs producing the same program, log, outcome, and normalized trace**. See [009 ADR-001:2263](/workspaces/motoko_agent-review-223-astra/.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md:2263).

D5 instead compares class counts within one execution. Its implementation precedent is `dst_discovery.class_balance` at `src/core/dst_discovery.ail:374`, not that determinism contract.

The distinction is also explicit in `dst_invariants.ail:2071`: the discovery contract is a **pair relation**, outside the single-execution family set.

The architectural conclusion can remain “no reopen,” because these checks strengthen rather than contradict 009. Rewrite the justification accordingly. Also acknowledge that:

- Post-return checks cannot detect a run that never returns.
- Unique provider steps and a provider-call ceiling do not bound decision-only loops.
- Fixed-bank evaluation does not fulfill D11’s rotating-search obligation.
- D8’s failure artifacts and replay requirements remain applicable to the new gate.

### 6. The experiment’s headline results reproduce, but some evidence descriptions are inaccurate

I reran the scorers against the permitted raw directories and their planted cases from scratch copies under `.review/`.

Confirmed:

- Scorer self-tests: **15/15, 9/9, 11/11**.
- All thirteen original rows type-check.
- Part 2: all eleven real mutants remain clean under A; prediction scores **13/14** and **12/14**.
- Part 4: **18/18** predicted column pairs.
- M1: fourteen prepared calls on budget twelve.
- M2: twelve trace calls against two logged calls on three members, and twelve against nine on the fourth.
- M3 and its mirror: five and ten affected members.
- K0: zero differences across **1,609** normalized wire-event lines.
- Reported wire-difference counts and sweep durations.
- Original prediction hashes, including part 2 before its documented K2 addition.

Corrections required:

**The provider-failure branch count is contaminated.** `Makefile:1860` counts any matching `error` field. The reported eleven occurrences are **seven `run_summary` events plus four `stream_error_retry` events**. Removing every failure summary still leaves this particular branch witness reporting four. The branch was reached, but eleven is not its execution count.

**“Pass the whole of `make dst`” is false literally.** Baseline, M1, and M3 all exit **2**, with four failing targets. The supported conclusion is “no additional observed failures relative to the red baseline.” The findings note acknowledges this; the ADR headline should too.

**Part 3’s scorer loses timeouts.** `score3.py:60` treats exit `124` like zero when determining red gates. A planted input with all six probe gates and all six mutant gates timed out returned:

```text
verdict: NOT REACHED
fam: clean
```

See [scorer-edges.txt](/workspaces/motoko_agent-review-223-astra/.review/scorer-edges.txt). No recorded part-3 gate timed out, so this defect does not overturn its actual table.

**T3’s strict-replay explanation names the wrong failure.** The raw `strict_replay.log:215` says its deliberately mismatched-call-id fixture produced **zero** expected mismatches. It does not report an actual production call-id mismatch. The mutant destroys the fixture’s tool evidence; the gate’s adequacy checks catch that loss.

**“No gate reaches T2” exceeds the experiment.** The reach probes covered six gates plus the bank probe, not the entire `DST_TARGETS` set. Report that measured scope. The `ledger_parity` reach attribution is also an inference from its exit status, not the required visible poison signature.

The instruments are not universally constant: the planted cases and actual positive controls demonstrate discrimination. Their limitations concern specific observations and verdict handling.

### 7. Fix the remaining factual and editorial drift

All explicit ADR source coordinates resolve to the described sites; `session.ail:3529` is inside the park arm rather than its opening line.

Two surrounding claims need correction:

- D3’s “three transitions that keep the step” omits the successful wake transition at `session.ail:3548`. This does not invalidate D3: the prior provider call has already advanced the step before parking.
- The “12 record literals in 7 files” cost estimate is a grep-occurrence count, not a construction-site count. There are two full `ExecutionUnderTest` constructors: `dst_execution.ail:110` and `invariants_dst.ail:409`. The other hits include type declarations, record updates, and different record types. The five `execution_of` call expressions are real.

The findings note also retains conclusions superseded by part 4: “nothing was changed or tested beyond that” at `:376`, “none built or tested” at `:409`, and returned-trace availability “was not checked” at `:413`. Remove or date those statements.

## Option 3 and the deferred census

I compared the actual printed identity and trajectory keys, rather than relying only on outcome and log length:

| Mutant | Changed keys, out of 32 |
|---|---:|
| M1 | 2 |
| M2 | 8 |
| M3 | 0 |
| M9 | 0 |

Thus rejecting **those pins as a replacement** is justified. `dst_corpus.trajectory_text` hashes interactions (`src/core/dst_corpus.ail:172`), not terminal trace content. A normalized full-trace snapshot could detect M3 and M9, so the evidence does not reject every possible form of pinning. Also preserve the word **“only”** from 009’s statement about golden snapshots: it does not prohibit complementary pins.

Deferring the remaining census is reasonable, provided the plan explicitly leaves tool/approval successor loss unguarded on this bank and does not credit 034’s properties as complete.

## Additional source mutants

These were selected from production obligations, not merely the detector expressions. Except for the generator rewind, they remain predictions.

| Edit | Obligation challenged | Why D2–D5 would still pass |
|---|---|---|
| `session.ail:3920`: `TermProviderFailure` → `TermMaxSteps` | Correct terminal classification, associated with D2 | Both are nonsuccess reasons paired with `Err`; counts and progress are unchanged. |
| `session.ail:3887`: `step_idx + 1` → `step_idx + 2` | Retry consumes exactly one step, associated with D3/D4 | Steps remain unique; calls decrease rather than exceed the ceiling. |
| `session.ail:3892`: preserve `capt.world` but restore `gen: st.world_state.gen` | Carry the provider successor, associated with D5 | Logs and prepared-call counts remain balanced. **Executed on seed 19 and survived the scratch predicates.** |
| `session.ail:3808`: prepared-event `step: step_idx` → `step: policy.step.step_budget + step_idx` | Records carry the driver’s actual, budget-relative step, associated with D3/D4 | Labels remain unique; D4 counts records and checks retry-event steps, not prepared-event index bounds. |

These expose limits of the broader obligations invoked by the ADR. They do not logically contradict its narrower predicates. Acceptance should either add the missing checks or explicitly exclude these properties from its claims.

## What I would change first

1. Define D4’s effective-budget source and sentinel semantics.
2. State the exact run, producer, adapter, and log-boundary premises for D2–D5.
3. Expand D6 with the boundary and survival controls above; retain specific-rule acceptance.
4. Correct D8’s discovery-contract attribution and label this as partial implementation of 009’s obligations.
5. Correct the contaminated branch count, red-baseline wording, scorer timeout handling, and stale note sections.

A further general review round is unnecessary before those concrete changes and controls are made.

## Not verified

- I did not run `make dst`, `make corpus_pr`, or any sweep.
- I did not execute every proposed mutant or test the eventual implementation, which does not exist. The additional execution used existing invariants plus scratch D2–D5 predicates on two selected seeds.
- I did not find raw logs for the claimed prototype `make invariants`, `make stream_parity`, and nine-inline-test control runs within the permitted output directories.
- I did not independently verify the upstream compiler’s cache-limit implementation or external historical experiments.
- This was not a blind-mutant exercise: the brief required reading D6’s table.
- A process-list diagnostic inadvertently exposed another reviewer’s command line. I did not open their files or coordinate with them; the overlapping mutant ideas had already been selected before that output appeared.

## Checked by the delegating session, 2026-10-06

Before any disposition. Re-observed first-hand against the tree at `f1eb8d9f` and the spike's raw
output, and found as the reviews say:

- `session.ail:2351` turns a non-positive step budget into 8, and `step_machine.ail:103` treats a
  policy budget of 0 as unlimited.
- `ext_ai_step` (`session.ail:1094`) calls `model_step` with no `ProviderCallPrepared`.
- `parked_frame_only` (`session.ail:5584`) returns `Ok` with no summary.
- 009 ADR-001's "discovery contract" (`:2262`) is the run-twice determinism relation.
- On the spike's own corpus wires, runs whose `world_request` ordinals are not strictly +1: 0 of 18
  on the comment-only control, 4 of 18 under `M2`, 12 of 18 under `M6`, and 0 under `K1`, `M12`
  and `T3`.
- `corpus_pr`'s `provider_failure_finalize` counter of 11 is 7 run summaries plus 4 retry records.
- Under `M3`, six summaries carry `E_PROVIDER_PROTOCOL` and one `E_PROVIDER_TIMEOUT`.
- The unmutated sweep's log holds no `stream_error_retry` event, so its 100 summaries say nothing
  about retried runs.
- `T3`'s `strict_replay` line is the gate's own fixture check reporting zero mismatches where it
  expects one, not a production call-id mismatch.
- `score3.py` treats exit 124 as green.
- `ExecutionUnderTest` is built in full at two sites; "12 record literals in 7 files" was a grep count.
- `run_v2_session_traced_with_persist_retries` (`session.ail:4480`) starts its run from `pp`, where
  its sibling at `:4442` passes the post-init world. Its only callers are in
  `scripts/dst/phase_c2_wiring_scenarios.ail`. Whether that matters there was not established.

Not re-run by the delegating session: the reviewers' own mutants. Their probe output is under
`.review/` in each reviewer's worktree and reads as reported.

## Disposition — 2026-10-06, in ADR-003 v0.2 (accepted by the operator the same day)

The amended rules were run before they were written (the spike's part 5, 24 rows).

| Finding | Assessment | Change |
|---|---|---|
| 1. D4's budget | Accepted. | D4 carries the effective budget; a non-positive start is undeclared; the retry rule reads "budget minus step is 1 or less". The journal bridges are named as controls still owed (D6). |
| 2. D5's premises; count is not successor preservation | Accepted. | D5 states three premises. The generator rewind was rerun (`R6`): every rule is green. It is in D6's known-unseen list and *Not decided* item 2. 035's whole-successor property is no longer claimed. |
| 3. D6's controls | Accepted in part. | The mutant table is extended and the missing controls are listed as owed before acceptance. They were not built: the spike has no retry near the budget edge and no model-calling profile. |
| 4. `parked_frame_only`; D2 is binary | Accepted. | D2 is now by reason and excludes results with no terminal summary; D1's gate does not bridge them. |
| 5. D8's attribution | Accepted. | D8 rewritten: D5, D9 and D10 belong to 009 D2; the limits the review lists are stated. |
| 6. Evidence descriptions | Accepted, each re-observed. | Corrections 1, 2, 4, 5, 6, 7 and 10 in the findings note; the ADR's headline says "add no failure". `score3.py` is left as it ran and its defect recorded. |
| 7. Step-keeping transitions; record literals | Accepted. | D3 no longer counts transitions. The cost is "two constructions and five callers". |
| Option 3 | Accepted. | D7 and option 3 say "the existing keys"; 0 of 32 keys re-derived for `M3` and `M9`. |
| Proposed mutants | Three run in part 5 (`R1`, `R3`, `R6`); the step-label offset was not. | `R1` and `R3` are rows of D6. The offset is in the known-unseen list. |
