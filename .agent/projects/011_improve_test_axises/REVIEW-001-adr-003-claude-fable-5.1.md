# REVIEW-001: Claude Fable 5.1 review of ADR-003 (judge wrong recoveries on real runs)

Date: 2026-10-06
Reviewer: Claude Code v2.1.291, launched with `--dangerously-skip-permissions --model claude-fable-5-1`; the terminal banner confirmed Fable 5.1 and the transcript records `claude-fable-5-1` on every turn. Effort shown as high.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `adr003-fable`, pane `w7:pK`, worktree `/workspaces/motoko_agent-review-223-fable`. Reviewer session: `efe56856-fdaf-4ce1-86f0-9c8584d9f585`.
Document reviewed: [ADR-003-judge-recoveries-on-real-runs.md](ADR-003-judge-recoveries-on-real-runs.md) at `f1eb8d9f` (draft PR #223).
Document SHA-256: `52e6adfaf694e336616145b56c2c662cbd2750971d913589458ee7077b1db2b3`.
Status: Assessed; dispositions below, in ADR-003 v0.2, which the operator accepted on 2026-10-06. A second, independent review is in `REVIEW-001-adr-003-codex-gpt-6-astra.md`.

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

## Reviewer response

**Model:** Claude Fable 5.1 (`claude-fable-5-1`). **Reasoning effort:** not visible to me in this session, so I can't state it.

# Review of ADR-003 (011) at `f1eb8d9f`

## Bottom line

The ADR's direction is right and its central facts hold: the sha matches, the source has not changed since `259265b5`, and the driver's finalize table and step arithmetic are as described. Three things should change before a plan is written:

- **D2 is not exact.** It separates success from failure but passes a failure reported under the wrong failure reason; two one-edit mutants show it on the bank.
- **The ADR overlooks a witness already in every returned trace.** The `WorldRequest` ordinal sequence catches the dropped-successor class for every request class, and a trace-side tool balance works on the bank today. The reason given for deferring the tool balance does not hold.
- **D4 does not define the value it carries.** The driver gives a zero budget two meanings, and "negative means undeclared" matches neither.

Four of the five mutants I propose pass D2 to D5 on all sixteen members, measured. Tracked files are untouched (`git status` shows only `.review/`).

## Verdicts

| | Verdict | |
|---|---|---|
| D1 | STANDS | The gate must also say which retry and decision budgets it declares. |
| D2 | NARROWS | To a two-class check (success against any failure). Not "exact" until it also compares the failure reason. |
| D3 | NARROWS | No-repeat is sound for any single driver run. It does not see a skipped step. |
| D4 | NARROWS | Needs the carried value defined, and a mutant of its own for the calls rule. |
| D5 | NARROWS | Sound for `driver_only`, a recording world and an empty starting log. Should sit beside an ordinal rule and a tool balance. |
| D6 | NARROWS | Missing mutants and controls, listed below. |
| D7 | STANDS | The stated measurement only rejects a log or outcome pin; 009 D7's text carries the rest. |
| D8 | STANDS | One sentence misattributes D5. |

## How I tested

I wrote a probe (`.review/wt/scripts/dst/review_probe_223.ail`): `corpus_pr_dst.ail` verbatim plus probe-side statements of D2 to D5 from the ADR's text. It adds two extra checks: `WorldRequest` ordinals strictly +1 and ending at `world.ordinal`, and `V2ToolDispatchStart` count against `expect_tool` log entries. Each mutant was applied by `.review/mut.py`, run once, and restored. The unmutated bank is clean on every rule (`.review/probe-base.out`).

## Findings

**1. D2 passes a failure reported as the wrong failure.**
- `session.ail:3920`, `TermProviderFailure` → `TermMaxSteps`: five members read `ended=err fin=max_steps`, all of D2 to D5 green (`.review/probe-P1.out`).
- `session.ail:2789`, `TermMaxSteps` → `TermInternalFailure`: seed-244 reads `err`/`error` while still suspended, all green (`probe-P5.out`).
- Suggested fix: compare the summary with `finish_reason_wire(decision_fail_reason(err.code))`. By reading, every `Err` finalize site at HEAD satisfies it (`:2723`, `:2789`, `:3335`, `:3572`, `:3792`, `:3799`, `:3920`). I did not run this rule.
- The "compile error, not a default" claim is weaker than stated: `RunSummary.finish_reason` is a wire string (`session.ail:1778`), so the rule cannot match on `TerminationReason` directly.
- `parked_frame_only` (`session.ail:5583-5593`) returns `Ok` with no `RunSummary` at all. D2's "one finalize site returns `Ok`" is true of `c2_finalize` callers only.

**2. The trace already carries a successor witness the ADR does not mention.**
`witness` appends a `WorldRequest{ordinal, class}` for every helped request (`session.ail:4572-4585`). `make world_framed` and `src/eval/journal/admission.ail:40` check strict +1, but not on the bank.

| Mutant | D2 to D5 | Ordinal rule | Tool balance |
|---|---|---|---|
| Unmutated | clean | clean, 16 of 16 | clean, 16 of 16 |
| M2, retry keeps pre-call world | D5 red, 4 members | red, same 4 | clean |
| M6, approval successor dropped | clean | red, 12 members | clean |
| T3, tool successor dropped | clean | clean | red, 10 members |
| Failure finalize drops the capture read (`:3920`, `capt.world` → `stepped.world`) | clean | red, 4 members | clean |

- The spike's own wires agree: `out/K0/corpus_pr.wire` has 0 of 18 runs with an ordinal fault, `out/M2` has 4, `out/M6` has 12 (`.review/ordscan.py`).
- The ordinal rule cannot see a drop made before the witness: T3 on the bank, and K1 and M12 on the spike's wires, show no ordinal fault.
- Option 5's reason for deferral ("a generated world does not have" cursors) is accurate about `strict_replay_dst.ail:368`, but the tool class has a trace-side witness now.
- Deferring approvals is right: my naive balance (denied + dispatched = approvals logged) is red on two healthy members, seed-4 and seed-141.

**3. D4's carried value is undefined at zero.**
- `session_policy_init` turns `step_budget <= 0` into 8 (`session.ail:2351`).
- `decide` treats a policy budget of 0 as unlimited (`step_machine.ail:105`, `pol.step_budget > 0 &&`).
- A gate that records the 0 it passed in would be red on every healthy run. The plan should say the record carries the effective budget and where it is read from.
- D1 never says which retry budget the gate declares. The prototype used 11, a bound the healthy bank never approaches (one retry per member at most).

**4. D3 does not see a skipped step.** `session.ail:3887`, `step_idx + 1` → `+ 2`: four members change, seed-19 flips from `error` to `max_steps`, steps read `0 1 3`, all green (`probe-P2.out`). On the healthy bank the steps are exactly `0..n-1` on all sixteen, so contiguity would work as a gate check there. It is not sound as a family rule, because a dropped park reply advances the step without a call (`:3535`).

**5. D5's soundness boundary is incomplete.**
- `ext_ai_step` calls `p.model_step` with no `ProviderCallPrepared` (`session.ail:1094-1107`). A healthy run under any profile whose hook calls the model is unbalanced. This is from reading, not a run.
- The equality assumes an empty starting log; stating it as a delta costs nothing.
- Only the under-recorded direction has been seen red.

**6. The evidence is weaker than the ADR's wording in four places.**
- **The 100 run summaries.** The count reproduces (77 `stop` without error, 23 others with). But the log holds zero `"type":"stream_error_retry"` events: the bank's wire is not in it. So "0 of 100 repeat a step" says nothing about retried runs. The wire also carries no returned outcome, so for D2 it shows finish reason against error text only. The source reading and the 16-member probe are the real support.
- **Eighteen of eighteen.** The rules were written from these same rows after parts 1 to 3 were known, and eleven predictions are clean/clean. It shows the prototype does what it was built to do.
- **"12 record literals in 7 files."** That is `grep decision_budget:`, which counts type fields, record updates and other records. I find three `ExecutionUnderTest` literals in two files, plus the five `execution_of` callers.
- **The note's "all seven … `E_PROVIDER_PROTOCOL`".** Six are; one is `E_PROVIDER_TIMEOUT`.

**7. D3 names three step-keeping transitions; there are six.** Also `:2868`, `:2920` and the accepted-wake arm at `:3548`. The conclusion holds: every continuation out of the `CallModel` arm adds one.

**8. D8's last sentence is wrong on attribution.** 009 D7's "discovery contract" is run-twice determinism (009 ADR-001 lines 2262-2264). The class balance is 009 D2's (`dst_discovery.ail:1`). No reopen follows, since D7 says "at minimum" and D5 is a gate check.

**9. D6's controls omit the other real-run callers of `evaluate`.** `src/eval/journal/bridge.ail:61,103` and `candidate_checks_run.ail:108` will run the new family rules on suspended and stopped runs. By reading they are single driver runs and healthy, but they should be named controls.

## Mutants I propose

| # | One edit | Rule broken | D2 to D5 on the bank |
|---|---|---|---|
| 1 | `session.ail:3920` `TermProviderFailure` → `TermMaxSteps` | outcome and summary agree | pass, measured |
| 2 | `session.ail:2789` `TermMaxSteps` → `TermInternalFailure` | a suspension reports `max_steps` | pass, measured |
| 3 | `session.ail:3887` `step_idx + 1` → `+ 2` | a retry costs one step | pass, measured |
| 4 | `session.ail:3920` `capt.world` → `stepped.world` | a returned successor is carried | pass, measured; the ordinal rule catches it |
| 5 | `session.ail:3535` `st.step_idx + 1` → `st.step_idx` | a re-issued park consumes budget | predicted pass, not run |

- Mutant 5 passes for two reasons: the bank never parks, and D3 and D4 read only provider-call records.
- Mutant 1 sits on the token M3 changed, and M3 survived the whole sweep, so I expect no other gate reads it. That is inference.
- Add one kill to the author's table: `step_machine.ail:105`, `>=` → `>`, turns D4's calls rule red alone on seed-244 with 13 calls (`probe-P4.out`). Today that rule shares M1 with D3.

## What I would change first

1. Make D2 compare the failure reason, and say what it does with no summary.
2. Put the ordinal rule and the tool balance in D1's gate beside D5. Shrink *Not decided* item 1 to approvals and the pre-witness bootstrap reads.
3. Define D4's value and its source, settle zero, and state the gate's retry budget.
4. State D5's limits: no hook that calls the model, and a delta over the starting log.
5. Extend D6 with the mutants above, the journal callers as controls, and a mutant for D5's other direction.
6. Reword the evidence claims in finding 6 and fix the D8 sentence and the transition count.

## Not verified

- No `make` target or sweep was run, so I do not know whether any other gate catches mutants 1 to 5.
- My probe does not call `evaluate` and `prototype.diff` was not applied. That the shipped set is clean on the bank is taken from the spike's score files.
- Sweep timings beyond three summary files, the tier-T/S table, part 3's reach probes and the Z3 column were not checked.
- The note's 272 and 350 differing wire lines: I get 282 and 398 counting both sides; its method is not in the evidence.
- 034, 035 and RESEARCH §3.3 were read at the cited lines only. Two of the three meta-decisions were not read.
- `session.ail:4480` passes `pp` where its sibling at `:4442` passes the post-init world. It looks like the K1 class in a harness entry; I did not confirm it is a defect.
- Extension profiles, the live path and the TypeScript host were not run.

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
| 1. D2 passes a wrong failure reason | Accepted. | D2 by reason, with the table in the invariant module rather than a call to `decision_fail_reason`. Both mutants run in part 5 (`R1`, `R2`): red. The "compile error" claim is withdrawn. |
| 2. The ordinal witness and the tool balance | Accepted. Re-observed on the spike's own wires before anything else. | D9 and D10. `M6` red on 12 members, the capture-read drop (`R4`) on 4, `T3` on 10. *Not decided* item 1 shrinks to the pre-witness reads; the approval balance stays open (item 3). |
| 3. D4 undefined at zero | Accepted. | As the other review's finding 1. D1 now states the budgets the gate declares. |
| 4. D3 does not see a skipped step | Accepted, as a gate check only. | D3 in the gate: steps 0, 1, 2 and so on. `R3` red on 4 members. Not a family rule, for the reason the review gives. |
| 5. D5's boundary | Accepted. | The three premises; the over-recorded direction is a mutant still owed. |
| 6. Evidence wording | Accepted, each re-observed. | Corrections 3, 8, 9 and 11 in the findings note; the 100 summaries are dropped as support. "18 of 18" and now "24 of 24" are reported with the caveat the review gives. |
| 7. Six transitions, not three | Accepted. | D3 no longer counts them. |
| 8. D8's last sentence | Accepted. | D8 rewritten. |
| 9. Journal callers as controls | Accepted. | Listed as controls still owed in D6. |
| Proposed mutants | Four run in part 5 (`R1`, `R2`, `R3`, `R4`) and the added kill (`R5`). The re-issued park was not. | Rows of D6; the park is in the known-unseen list. |
| `session.ail:4480` | Confirmed by reading; impact not established. | *Not decided* item 9. |
