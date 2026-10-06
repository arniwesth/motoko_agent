# REVIEW-001: Claude Opus 5.5 review of the plan for ADR-003 (judge recoveries on real runs)

Date: 2026-10-06
Reviewer: Claude Code v2.1.291, launched with `--dangerously-skip-permissions --model claude-opus-5-5`; the transcript records `claude-opus-5-5` on all 212 assistant turns. Effort shown in the pane as xhigh.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `plan-review`, pane `w1:p5`, worktree `/workspaces/motoko_agent-review-plan-011`. Reviewer session: `2bd85d15-ec48-468a-b22a-09d6df5d91eb`. Worked for 28 minutes.
Documents reviewed, uncommitted, copied into a clean detached checkout of `59d5cbb9`:

| document | sha256 as reviewed |
|---|---|
| [PLAN-judge-recoveries-on-real-runs.md](PLAN-judge-recoveries-on-real-runs.md) | `61741c76e25225a570855c670a50a8bf60fd7f62821aa32caf56b9dc4ff987c2` |
| [HANDOFF-build-the-corpus-judge-gate.md](HANDOFF-build-the-corpus-judge-gate.md) | `88b667b9a1ba65551c87f2fbaa967fe0b3dbc2db2b900562dc276d2e45d1c936` |
| [HANDOFF-build-the-two-invariant-rules.md](HANDOFF-build-the-two-invariant-rules.md) | `d102090013d16e0bf174407ee6f3dad95a65e14b8a60b5d70b4621aa112309fa` |
| [ADR-003-judge-recoveries-on-real-runs.md](ADR-003-judge-recoveries-on-real-runs.md), its amendment | `19c93230a31678ff3b45c80e2844c68d6aaedfb3800a995fa94be928e2e22bfa` |

Status: Assessed; dispositions below. The documents were revised the same day and no longer hash
as above.

## Scope

One reviewer, at the operator's request ("lets review the plan first"), before anything was
committed. The brief (`.review/BRIEF.md` in the reviewer's worktree, sha256 `9d01aa03ceaf3f8b…`) made the
plan the subject, and put the two handoffs and the ADR's amendment in scope only for agreement
with the plan and with the source. It asked the reviewer to check facts and coordinates, to test
the plan's own findings because rulings 13 to 15 rest on them, to check completeness against
ADR-003 and the commissioning handoff, to ask of each done-check whether it could pass while the
work was wrong, and to check the sequencing, the acceptance design, the handoffs and the amendment.

The reviewer was allowed read-only commands, `ailang check`, `verify` and `test`, single
`ailang run` probes, `make invariants`, `make stream_parity` and `make corpus_pr` once each, and
throwaway probes in its own worktree. It was told not to run `make dst`, `make eval_matrix` or any
sweep, and not to change the documents. Its worktree shows the same entries afterwards, plus
`.review/`.

The response below is the reviewer's `.review/REVIEW.md`, verbatim. It is also its final message.

## Reviewer response

# Review: `PLAN-judge-recoveries-on-real-runs.md`

Reviewer: Claude Opus 5.5 (`claude-opus-5-5`). I cannot see my reasoning-effort setting.
Reviewed at `59d5cbb9`, AILANG v0.47.2. The four documents hash as the brief lists, before and after.
`git status` shows the same entries as at the start and `git diff --stat` only the ADR.

## Bottom line

None of §2's findings is wrong: F1, F2 and F3 hold against the source, so rulings 13 to 15 rest on
true premises. The plan is buildable, and I closed three of its open risks by running them: the
import route works for the run helpers, all sixteen members are clean at HEAD on the six gate
checks and on D2's table, and both budget-edge controls behave on the bank's rig as they did on
`stream_parity`'s. Seven findings ask for a change before the handoffs go out, and two of them are
checks that pass without checking anything: WI-4's reference matrix in one merge order, and the
contract policy run before the commit.

## Verdicts

| part | verdict | one line |
|---|---|---|
| §1 baseline | STANDS | Counts, the masked `corpus_pr` hash, the matrix identity and the CI table all reproduce. |
| F1 | STANDS | Every premise checked by reading. The assembled-tree type failure is by reading for me too. |
| F2 | STANDS | No workflow runs `make dst`, `invariants` or `stream_parity`. The `pr-corpus` job is green and takes about 6.5 of its 15 minutes. |
| F3 | STANDS | Wire counts reproduce (18 summaries: 10, 7, 1). Closing it is cheaper than stated: finding 6. |
| F4 | NARROWS | F4.2 reproduces. F4.3 names two of the seven items it leaves out of 009 D8 and settles them without a ruling: finding 5. |
| §3 re-grounding | STANDS | Every coordinate I checked holds. Two small misses, in finding 8. |
| WI-1 | NARROWS | The time criterion fails on noise, the sweep buys nothing for this commit, and the export list is short: findings 3 and 4. |
| WI-2 | NARROWS | Sound. One survival row is missing and one version question is unstated: finding 8. |
| WI-3 | NARROWS | Three bridge arguments unstated, one balance direction unproven, the failure record: findings 5, 6, 7. |
| WI-4 | NARROWS | Meets the meta-decision except where it says so. Precondition 1 names the wrong reference tree in one merge order: finding 1. |
| sequencing | NARROWS | The clusters share no file and either order builds. One sentence is stale and WI-4's "parent" depends on the order. |
| §5 and §6 | STANDS | The rulings table matches the ADR. The guardrails match the prototype diffs. |
| gate handoff | NARROWS | A fresh session could build from it. It inherits findings 3, 4 and 7. |
| rules handoff | NARROWS | All anchors hold. Its done-check runs the contract policy where it sees nothing: finding 2. |
| the amendment | NARROWS | It records the three rulings and their consequences and changes no decision. Ruling 14's wording has finding 1's hole. |

## Findings

### 1. WI-4's journal precondition compares against the wrong tree in one merge order

- **The plan says.** WI-4, precondition 1: "`make eval_matrix` at the handed-in commit against the
  matrix at its parent on `main`". Ruling 14 and D6's amended passage: "against the unmutated tree
  at the same commit". The clusters "can land in either order". §6: the ADR wins.
- **What I found.** The comparison means something only between a tree with D2 and D3 and a tree
  without them. "Its parent on `main`" is such a tree only when WI-2's merge is the tip. If the
  rules merge first and the gate second, or anything else merges after, the parent already has the
  rules and the comparer prints `IDENTICAL` whatever the rules do. "The unmutated tree at the same
  commit" is the spike's phrase. It was true there because the prototype was an uncommitted diff.
  Once the rules are committed, the unmutated tree at that commit is the tree under test.
- **Evidence (read).** Plan WI-4 item 1; ADR ruling 14 and the D6 passage in the diff; plan rule 1
  uses the same phrase. WI-2's done-check has it right: "its parent commit".
- **Change.** WI-4 and ruling 14 both name the reference as the last tree without the two rules:
  WI-2's parent, which is `baseline-59d5cbb9` while the README's validity check holds. The
  known-bad controls stay as the proof that the comparison can see.

### 2. The rules handoff runs `new_contract_policy` before the commit, where it cannot see the change

- **The handoff says.** Done, in order: `make verify_core verify_classify_check
  new_contract_policy`, then `make dst`, then "commit, and only then" the matrix.
- **What I found.** The policy reads `git diff origin/main...HEAD`: committed changes only. On an
  uncommitted tree it reports nothing added and exits 0.
- **Evidence (ran).** I appended a bare `pure func` with no contract to
  `src/core/dst_invariants.ail`, uncommitted, and ran the tool:
  `new_contract_policy: no pure func added under src/core/ since origin/main`, exit 0. Restored.
  The diff is at `new_contract_policy.py:64`.
- **Consequence.** The local check is green whether or not D2's table has its contract. CI's
  `verify` job catches it after the push, so it is not silent for long.
- **Change.** Commit first, then run the policy, and say what green looks like: the tool names
  each new function and prints `carries a contract` or its checked excuse.

### 3. WI-1's time criterion will stop a correct build, and its sweep measures nothing

- **The plan says.** `corpus_pr` twice before and twice after; "its wall time after is within the
  spread the two runs before showed"; a time outside that spread is a stop-and-report. Then
  `make dst`. WI-3 repeats the time check.
- **What I found.** Two samples define a range, not a spread. If nothing changed and the four
  times are independent, both after-runs land inside the range of the two before-runs one time in
  six. A run one second faster than the faster before-run is "outside the spread". The recipe
  measures in whole seconds.
- **The sweep.** No module imports `scripts/dst/corpus_pr_dst`; only `Makefile:1851` runs it
  (searched). So for commit 1 the 35-minute sweep can show nothing that `corpus_pr` alone does not.
  The handoff's sweep was written for a seven-file record change that ruling 13 removed.
- **Change.** One-sided, with a stated tolerance: no after-run slower than the slower before-run
  by more than, say, 10 s, and well under the 180 s ceiling. Faster is not a finding. Drop
  `make dst` from commit 1; commit 2's sweep covers both.
- **What does hold (ran).** The output check is a good instrument. I ran the corpus script with
  the recipe's flags and a private output path: 1,871 lines, 1,609 JSON, and both masked hashes
  equal `corpus_pr.wire.sha256`. That is a third checkout with the same bytes.

### 4. WI-1's export list is short of what WI-3 uses

- **The plan says.** WI-1 exports `fixed_bank`, `generated_world`, `empty_terminal_world`,
  `run_generated`, `run_recording` and two additions; "nothing else in the file moves". WI-3
  step 9 prints "generator id and version".
- **What I found.** `generator_id` and `generator_version` are private
  (`corpus_pr_dst.ail:298`, `:299`) and not in the list. The recipe for a member's run is also
  private: the id `"corpus_<seed>"`, the world constructor and the member ids live in `build_seed`
  (`:664`) and `build_constructed` (`:684`). The gate restates all of it. After WI-3 the budget has
  one home and the run recipe has two, and nothing checks that the gate's sixteen runs are
  `corpus_pr`'s.
- **Change.** Add the two functions to WI-1's exports. Better: export one helper per member kind
  that returns the starting world and the run, and have `build_seed` and `build_constructed` call
  it. Failing that, the gate prints `n=` and `ended=` per member and commit 2's done-check compares
  them with the `CORPUSROW` lines once.

### 5. F4.3 leaves out more of 009 D8 than it says, and decides it without a ruling

- **The plan says.** F4.3 is one of the corrections "none needing a ruling". Step 9 "does not
  preserve the serialized program or the trace", and re-running the gate is D8's replay command.
- **What I found.** D8 lists twelve things a generated failure "reports and preserves" (009
  ADR-001 `:2274` to `:2288`). Step 9 carries five: generator id, generator version, seed, first
  failed invariant, terminal outcome. It omits seven: schema version, the serialized program,
  source revision and toolchain, the profile and its manifest, the event-vocabulary version, the
  run configuration, the trace. The plan names two of the seven. D8 also says "Replay consumes the
  exact program and does not regenerate it" (`:2290`); re-running the gate regenerates from the seed.
- **Why it matters.** ADR-003 D8 says 009 is not reopened. This is the plan deciding how far a new
  gate may fall short of it.
- **Change.** Either put it to the operator as a fourth question, or close most of it cheaply: the
  recipe prints `git rev-parse HEAD` and `ailang --version`; the script prints the profile id and
  version and the vocabulary version, all exported today; and on red the recipe keeps its `mktemp`
  output, which holds every member's wire, and prints the path.

### 6. One balance direction is unproven, and F3's two rows are cheaper to close than stated

- **D10.** `tool-dispatches-unbalanced` is red "either way", but row 12 shows only log below
  trace, and step 5 gives one constructed input per rule id. D6 owes an over-recorded mutant for
  D5 and none for D10. Change: step 5 has one row per direction for both balance ids, and "what
  acceptance does not claim" names D10's over-recorded direction, or a thirteenth mutant covers it.
- **F3.** The plan says closing the cost and compaction rows "needs a bank member or a scripted
  run that ends on each reason". A scripted capped run exists: `ledger_parity_dst.ail:519`,
  asserted to carry `CostExhausted` (`:524`). `terminal_trace_dst.ail` and
  `long_qwen_compaction_dst.ail` name the other reason. So the open decision is whether the gate
  bridges a run from outside the bank, not whether to build one. Read, not run: I did not confirm
  how those runs end.

### 7. WI-3 leaves three of the bridge's eight arguments unstated

- **What I found.** D1 fixes the two budgets. The starting clock, the replay obligation and the
  metadata are in neither the plan nor the handoff, and the handoff says to take "the six
  expressions in `spk_row3` and nothing else", which excludes the line that shows them
  (`spike_families_on_bank.diff:240`: `initial.clock_ms`, `NoReplay`,
  `unknown_replay_metadata()`). With `NoReplay` the replay family is unevaluated on all sixteen.
  The journal bridge prints that (`unevaluated=replay-consistency`); the gate as planned does not.
- **Change.** State the three values in WI-3, and have the gate print the unevaluated families in
  one line. That is not the per-family reach report of *Not decided* item 8.

### 8. Smaller corrections

- **§3, pinned ids.** The evaluator pins two rule ids, not one: also `journal-payload-disagrees`
  (`witness_live_test.ail:376`, `MATRIX.expected.tsv:620`). Nothing here touches either.
  `evaluate` has one more caller, `witness_live_test.ail:328`.
- **WI-2, a missing survival row.** The fixture has one prepared record, so a D3 that fires on any
  two prepared records passes every planned row in `make invariants`. `make stream_parity` catches
  it in the same done-check, by its exact rule sets on two-step runs. Add a row with two distinct
  steps that must survive.
- **WI-2, the set's version.** `dst_invariants.ail:219` to `:222` says a rule-id change is a
  version change. `invariant_set_version()` has stayed `invariant-set/1` since A14 and only a
  banner reads it. The plan should say bump or leave.
- **WI-2, wording.** Of the six places, the total matches are the second to fourth, not "the first
  three". `with_trace` (`invariants_dst.ail:426`) also hardcodes `Ok([])`, so `with_records` resets
  an `Err` fixture's outcome.
- **WI-4, precondition 3.** Dropping the prepared append leaves no prepared call in any trace, so
  step 7's guard is red on every member beside the named rule. The gate must print its rule rows
  before the vacuity verdict.
- **WI-4, row 8.** It will land on seed 19, which takes a retryable timeout at step 11 of 12 and
  is not retried today. The table names no member.
- **Sequencing.** "The first joint run … is WI-4's unmutated control" is stale. Both handoffs run
  the joint state at the second cluster's done-check, and with ruling 15 the `pr-corpus` job runs
  it on the second pull request. The README's validity rule says to re-run the baseline after any
  change under `src` or `scripts`; the handoffs say the sibling's merge is expected and nothing
  moves. Pick one.
- **Calibration.** After ruling 13, WI-1 is about fifteen mechanical lines. Its ask-back prices a
  verification cycle, which §1 already has. The plan gives no estimate for WI-2, WI-3 or WI-4.
- **CI.** A step after a failed `corpus_pr` is skipped, so a wall-clock red there hides the gate.
  `if: ${{ !cancelled() }}` on the new step.
- **The amendment.** It adds one thing that is not a ruling, the closing pointer to the plan. The
  ADR is still called v0.2 though its text changed, and the plan's F1 quotes a D4 sentence the
  amended file no longer contains.

## Right where a reader would doubt

- **F1.** Four of the five `execution_of` call sites are under `EVALUATOR_PATHS`
  (`candidate.py:177`). The assembled tree is the candidate's with the pinned evaluator copied over
  it. `src/core/dst_*.ail` is inadmissible (`:202`). ADR-004 `:332` pins eight arguments.
  `check_bridge_inputs` (`bridge.ail:83`) has a row for every other bridge input. The amended D4
  still reads correctly: v0.2's "what the value is" bullet already spoke of the gate declaring.
- **The sharing route (ran).** I exported the helpers, imported them from a sibling script and ran
  all sixteen members and both controls in 51 s. The plan's probe imported only a type.
- **The bank at HEAD (ran).** Every member: no finding from today's set, steps contiguous from 0,
  provider and tool counts balanced, ordinals contiguous, D2's table satisfied. Six end `Err`: four
  on `E_PROVIDER_PROTOCOL`, seed 19 on `E_PROVIDER_TIMEOUT`, seed 244 on `StepBudgetExhausted`
  with `max_steps`. Retries at steps 1, 8, 1, 1, on seeds 9, 19, 32, 141. Ten members dispatch
  tools. Seeds 19 and 244 make 12 calls on 12. This matches every member count in WI-4's table.
- **The controls (ran).** On the bank's rig: budget 2 gives `Ok` on `stop`, steps 0 and 1, a retry
  at 0; budget 1 gives `Err` on `error`, one step, no retry. Both are clean on everything. The
  plan had this as a stop-and-report risk.
- **F4.2 (ran).** The table verifies under `ensures { true }`, so an excuse would be rejected.
  `ensures { result != "stop" }` verifies in 11 ms, and the same contract on a private function
  verifies too. A recursive list helper is skipped, so its excuse stands.
- **The matrix (ran).** `compare_matrix.py` on the baseline and the spike worktree's unmutated run:
  `IDENTICAL`, 621 rows. On a copy with one row changed: `DIFFERS`, exit 1.
- **Registration.** No guard reads the corpus script's source, no pin counts sweep targets, and
  `corpus_rotating` reads the workflow only for the scheduled job's lines.

## What I checked, and how

- **Ran.** `ailang verify` on a scratch table; `ailang test` on the invariant module (9 pass);
  `make invariants` (pass, 13 families, 40 constructors); `make stream_parity` (pass,
  `clock-balance` and none); the corpus script by its recipe's command; the import probe; the
  contract-policy probe; the comparer twice; `gh run list` and `gh run view`, read-only.
- **Checked in full, by reading.** Every `file:line` in §3's table, in F1, F3 and F4, in the CI
  table, and in both handoffs' anchor tables. The 52 and 21 target counts, by `make
  dst_target_list` against the workflows. The matrix counts, from the evidence files.
- **Sampled.** The sweep's 1.7 MB log: I read its summary and counted the sixteen corpus rows.

## What I did not verify

- **No sweep, no matrix, no mutant.** WI-4's twelve predictions are checked against per-member
  data and the source, not run. Rows 10 and 12's member counts beyond "ten members dispatch tools"
  are the spike's.
- **`make corpus_pr` itself.** I ran its script, not its recipe, so not its wall-clock check.
- **F1's type failure.** That an older evaluator fails to type-check against a nine-parameter
  bridge is by reading, as the plan says.
- **The two rules as implemented.** They do not exist. My probe computed D2's table and step
  uniqueness beside the run, which is what the rules would read.
- **The journal runs under the rules.** Part 6 of the findings note is the only evidence.
- **The hook-calling-the-model probe, and the new step's behaviour in CI.**
- **The baseline's wall times, and that its cache was cold.** `meta.txt` agrees with the plan.

## Checked by the delegating session, 2026-10-06

Before any disposition. Observed first-hand at `59d5cbb9`, and found as the review says:

- `new_contract_policy.py:64` diffs `{base}...HEAD`, so it reads committed changes only; `:497`
  prints `no pure func added` and returns when that diff is empty. Read, not run.
- No `.ail` file imports `scripts/dst/corpus_pr_dst`; the references outside it are comments, a
  copy under `evidence/D11-CEIL/`, and the recipe at `Makefile:1851`.
- `generator_id` and `generator_version` are private (`corpus_pr_dst.ail:298`, `:299`), and a
  member's run id, world, label and program are assembled only in `build_seed` (`:664`) and
  `build_constructed` (`:684`).
- 009 ADR-001 D8 lists twelve items (`:2276` to `:2288`) and says replay "consumes the exact
  program and does not regenerate it" (`:2290`). The plan's step 9 carried five.
- The prototype's bridge call is `spike_families_on_bank.diff:240`, with `initial.clock_ms`,
  `NoReplay` and `unknown_replay_metadata()`; the plan and the handoff stated none of the three.
- `journal-payload-disagrees` is pinned at `witness_live_test.ail:376` and
  `MATRIX.expected.tsv:620`; `evaluate(n_budget)` is called at `witness_live_test.ail:328`.
- `dst_invariants.ail:219` to `:222`: a change to a rule id is a version change, and the version
  is `invariant-set/1`. Its only reader is the banner at `invariants_dst.ail:1205`.
- `with_trace` (`invariants_dst.ail:426`) writes `Ok([])`, and `with_records` calls it.
- `ledger_parity_dst.ail:517` to `:524` runs a scripted session to a cost cap of 1 and expects
  `CostExhausted`; `long_qwen_compaction_dst.ail:848` expects `ContextExhausted`. The review also
  names `terminal_trace_dst.ail` for the second reason; a search of that file for it found nothing.
- `tool_phase.ail:470` builds the dispatch-start record and `:505` returns it in `emitted`, which
  is what reaches the returned trace (`session.ail:3623`). That gives D10's over-recorded
  direction a one-edit mutant.
- The corpus wire at this commit has one summary on `E_PROVIDER_TIMEOUT`, six on
  `E_PROVIDER_PROTOCOL` and one on `step budget exhausted`, which agrees with the reviewer's
  per-member list.

Reasoned, and found sound: finding 1 (a parent that already holds the rules compares identical
whatever they do), finding 3's arithmetic (two samples give a range; four independent times put
both later ones inside it one time in six), and the workflow point (a step after a failed step is
skipped unless it carries a condition).

Not re-run by the delegating session: the reviewer's probes. They are not in its worktree, which
holds only the brief and the review. What this record and the plan take from them is attributed.

## Disposition — 2026-10-06, in the revised plan, handoffs and amendment

| Finding | Assessment | Change |
|---|---|---|
| 1. WI-4's reference tree | Accepted. | WI-4's first precondition, ruling 14 and D6's amended passage name the reference as the last tree without D2 and D3. The baseline's README says when that is the committed baseline. Plan rule 1 is reworded the same way. |
| 2. The contract policy before the commit | Accepted. | The rules handoff and WI-2 run the policy after the commit and say what its green output names. Plan rule 6 states that the policy reads committed changes only. |
| 3. WI-1's time criterion and its sweep | Accepted. | One-sided: no later run more than 15 percent slower than the slower earlier run; faster is not a finding. The sweep and the depth canary are dropped from commit 1, since nothing else can move. |
| 4. WI-1's export list | Accepted, in its stronger form. | WI-1 exports one helper per member kind that gives the label, the starting world, the run and the program, called by `build_seed`, `build_constructed` and the gate. The gate prints `n=` and `ended=` and its done-check compares them with `corpus_pr`'s rows. |
| 5. 009 D8 | Accepted. It was a decision made in a sentence. | F4.3 no longer claims to need no ruling. Step 9 reports all twelve items, taking the program by reference to the artifact `corpus_pr` persisted. Whether a reference is enough was put to the operator as G4, who ruled the same day that it is ("I will go with your recommendation"; ADR-003 ruling 16). |
| 6. D10's direction; F3's cost | Accepted. | Step 5 has an input for each direction of both balances. WI-4 gains a row for D10's over-recorded direction, marked as not D6's and as predicted by reading. F3 says the runs exist and the open question is whether a gate bridges one. |
| 7. Three bridge arguments | Accepted. | Step 3 states the whole call, and the gate prints the families it did not evaluate. The handoff's "six expressions and nothing else" now includes the bridge call. |
| 8. Pinned ids, a caller | Accepted. | §3 and the rules handoff name both pinned ids and the caller at `:328`. |
| 8. A missing survival row | Accepted. | WI-2 and the handoff add two prepared records with different steps, silent. |
| 8. The set's version | Accepted: bump. | WI-2 moves it to `invariant-set/2`, by the module's own rule. |
| 8. Wording; `with_trace` | Accepted. | WI-2 names the three total matches, and says `with_trace` resets an outcome. |
| 8. Precondition 3 and the vacuity guard | Accepted. | Step 7 prints every member's rule rows before its verdict; WI-4 says why. |
| 8. Row 8's member | Accepted. | The row names seed 19, on the reviewer's run. |
| 8. Sequencing; the README's rule | Accepted. | The clusters meet in the second one's done-check and pull request. The README has one validity table that both handoffs point to. |
| 8. Calibration | Accepted. | WI-1 no longer claims to calibrate. The plan gives each item's least machine time from measured cycles, says authoring time is not estimated, and has each cluster report its cost at its end. |
| 8. The workflow step | Accepted. | The step carries `if: ${{ !cancelled() }}`. |
| 8. The amendment | Accepted in part. | The pointer to the plan is cut to one sentence, and F1 says its quotation is of v0.2 as accepted. The version label stays v0.2: the status line states the amendment and each amended passage carries its ruling. |

What the review ran and the plan now relies on, with attribution: the sharing route end to end;
every member clean at HEAD on what the six checks and D2's table read; the two budget controls on
the bank's rig. All three were stop-and-report risks in the first draft.

