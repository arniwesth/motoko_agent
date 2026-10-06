# Plan: one gate that judges every corpus member's real run

Status: **written; reviewed once and revised; all four of its questions ruled 2026-10-06; not
started.** Date: 2026-10-06. Grounded against `59d5cbb9`
(`main`, equal to `origin/main`), AILANG v0.47.2 (`e939cba`).
Commissioned by `HANDOFF-write-judge-recoveries-plan.md`; decided by
`ADR-003-judge-recoveries-on-real-runs.md` v0.2 (Accepted 2026-10-06; rulings 4, 6 and 7 to 16).

**Subject, one sentence.** Add one DST gate that evaluates the invariant set and five two-channel
checks on every corpus member's real run, change two invariant rules so they read what a wrong
recovery changes, and accept each rule only on a named source mutant seen red.

**What this is.** A sequencing of ADR-003 v0.2. It re-derives no decision. Where the survey of HEAD
contradicts the ADR, the contradiction is a finding in §2. Three of them were questions for the
operator, and the review raised a fourth. The operator ruled on all four the same day (§5);
ADR-003 carries the rulings as 13 to 16.
Nothing is built. Three throwaway probes ran and were removed (§3).

**Reviewed** by Claude Opus 5.5 on 2026-10-06, before anything was committed:
`REVIEW-001-plan-judge-recoveries-claude-opus-5.5.md`. It found no finding of §2 wrong, and seven
things to change. All are applied here; that record has the disposition of each. Where this text
relies on something the reviewer measured and this session did not, it says so.

**How to read the numbers.** *Measured* means by this session at `59d5cbb9`. *Inherited* means the
findings note's figure at `259265b5`. No file under `src`, `scripts`, `tools`, `.github` or the
`Makefile` differs between the two commits (`git diff --stat 259265b5 59d5cbb9` over those paths is
empty), so every inherited source anchor was expected to hold. Each was re-observed anyway (§3).

---

## 1. The calibration ask, answered

> *"Before scheduling, establish the baseline at HEAD on a clean checkout: which `make dst` targets
> and which matrix suites are red, and whether CI agrees."*

### Method

A detached worktree at `59d5cbb9`, `/workspaces/motoko_agent-011-baseline`, with nothing edited and
nothing untracked, on a compile cache emptied by a sandbox rebuild the same day. `make dst` at the
default `-j8`, then `make eval_matrix`, one after the other. The spike saw its baseline only in a
worktree carrying a private-path `Makefile` edit; this one carries none. The results, the driving
script and a comparer are in `evidence/judge-recoveries/`; the full logs are in
`tmp/plan-011-baseline-2026-10-06/` of the main checkout (git-ignored).

### `make dst` at HEAD

| | |
|---|---|
| exit | 2 |
| wall | 2,085 s (34 min 45 s) at `-j8`, cold |
| targets | 52 run, 48 pass, 4 fail |
| red | `driver_plus_compose`, `driver_plus_no_ops`, `ext_hook_scope`, `ext_hook_scope_selftest` |
| listed in `DST_KNOWN_RED` and passing | `driver_plus_herdr`, `herdr_graded` |
| tree afterwards | clean |

- **These are the four the spike saw**, so its red baseline was not an artifact of its worktree or
  of its `Makefile` edit.
- **They have one cause, and it is not this plan's.** Each reports that the registration-shape
  inventory cannot read the `test_dummy` extension: `REGISTRATION SHAPE: pass 19 of 20; fail 1`,
  and in the two driver gates `B2 reads 'test_dummy's registration as None, not config-caps`.
  The file is `packages/motoko-ext-test-dummy/register.ail`, last changed in `3159797d`.
- **The sweep tells whoever runs it that the four are theirs.** Its summary prints
  `NEW — this one is yours` for each, because none is in `DST_KNOWN_RED`, while the two that are in
  that list pass. A builder of any item below will see this on an unedited tree.

### `make eval_matrix` at HEAD

| | |
|---|---|
| result | the target fails; three of 28 suites exit non-zero |
| wall | 821 s (13 min 41 s) |
| rows | 621: 419 credited, 129 equal, 29 failed, 33 missing, 11 inapplicable |
| suites red | `scripts/eval/test_candidate.py`, `src/eval/journal/candidate_checks.ail`, `tools/eval_protected/selftest.py` |
| the suites that evaluate real runs | `witness_live_test.ail`, `candidate_checks_live_test.ail`, `admission_live_test.ail`: all exit 0 |
| against the spike's unmutated matrix at `259265b5` | **identical in every observed field of all 621 rows** |

- **The matrix is stable.** Two runs, two commits, two checkouts, a day apart: no row differs. So a
  row-for-row comparison is an exact instrument here and costs one run of under fourteen minutes.
- **The three red suites are project 013's**, for the reasons part 6 of the findings note records.
- **The run was not alone on the machine.** Another session was installing a Python environment
  during the matrix half, and one of this session's probes ran during the sweep. Neither changed
  a verdict: the sweep's reds are the spike's four and the matrix is the spike's matrix.


### What CI runs, and what it does not

**No workflow runs `make dst`.** The sweep has 52 targets (`make dst_target_list`).
`.github/workflows/verify-extensions.yml` and `dst-corpora.yml` name 21 of them between them:

| job | targets |
|---|---|
| `dst_gates_heavy` (`verify-extensions.yml:129`) | `terminal_trace`, `smoke_driver`, `world_state` |
| `dst_gates_rest` (`:172`) | `compaction_dst`, `conformance`, `phase_c_l1`, `profile_coverage`, `profile_definition`, `driver_only`, `fault_catalogue`, `event_vocabulary`, `attribution_table`, `predicate_anchors`, `ext_call_inventory`, `ext_call_inventory_selftest` |
| `coverage` (`:194`, `:197`) | `smoke_parity`, `test_coverage`, `test_coverage_selftest` |
| `verify` (`:245` to `:316`) | `verify_core`, `verify_mutations`, `verify_classify_check`, `new_contract_policy` |
| others | `check_core`, `dst_seeded`, `dst_l2`; `corpus_pr` in `dst-corpora.yml:99` |

The other 31 run only when someone runs the sweep. Among them are `invariants` and
`stream_parity`, two of D6's five named controls (F2), and `strict_replay`, `discovery`,
`ledger_parity` and `depth_canary`, four of the gates that caught the spike's mutants. So CI cannot
agree or disagree about the targets that are red above: it runs none of them.

### Costs, measured today

| run | cost | note |
|---|---|---|
| `corpus_pr`, alone, cold | 82 s against its 180 s ceiling | the ceiling is `pr_target_ceiling_ms()`, `src/core/dst_corpus.ail:487` |
| a script that imports `scripts/dst/corpus_pr_dst` and runs nothing | 53 s cold | one compile of `session.ail`; the spike's 40 s was warm |
| `make dst`, `-j8`, cold | 2,085 s | the spike measured 3,032 s cold and 1,770 to 1,875 s warm at `-j4` |
| `make eval_matrix` | 821 s | the spike measured 831 and 1,062 s; the `Makefile` says 25 to 40 minutes |

`session.ail` still exceeds AILANG's cache blob limit at HEAD: the import probe printed
`CACHE_WRITE_FAILED module=src/core/session … ARTIFACT_TOO_LARGE`.

---

## 2. Findings against ADR-003

The handoff said to expect defects. These are four. None reopens a decision; F1 asks for one
sentence of D4 to be re-ruled.

### F1 — D4's record field has one reader in v0.2, and it is the gate that writes it

**What v0.1 said.** "The execution record carries the run's step budget, and two rules read it."
Its sequencing put "D4's two rules with their constructors" in the invariant module (ADR-003 at
`f1eb8d9f`, step 2). A family rule can only read the record, so the record needed the field.

**What v0.2 said as accepted** (the text at `59d5cbb9`; ruling 13 has since replaced it). "…and
the gate states two rules against it." Its sequencing moved "D4's two rules" to step 3, the gate,
and left step 1, "the record: D4's field with every site stating a value", as it was. The reader
moved; the field did not.

**What the survey finds.** In v0.2 nothing in `dst_invariants.ail` reads a step budget. The only
reader of the new field is D1's gate, which is also the code that starts the run with that budget
and therefore already holds the value. The other four call sites would state a value that no rule
reads and no check compares with the run.

**What step 1 costs as written.** Seven files, four of the edits judgement (the table under WI-1).
Beyond the edit count:

- **Four of the five `execution_of` callers are project 013's evaluator**, under
  `EVALUATOR_PATHS` (`scripts/eval/candidate.py:177`). A candidate tree is the candidate's
  `src/core` with the pinned evaluator's files copied over it (`candidate.py`, step 2 of its
  header). An evaluator pinned before the change calls `execution_of` with eight arguments against
  a `src/core` that wants nine, and the assembled tree does not type-check. A candidate cannot
  carry the fix: `src/core/dst_*.ail` is on D3's inadmissible path list (`candidate.py:202`). So the
  next evaluator commit 013 pins must be at or after WI-1's commit. By reading; not run.
- **013's decision record pins the arity.** ADR-004 says "the bridge takes eight arguments"
  (`ADR-004-journal-as-evaluation-source.md:332`).
- **A8 checks every bridge input against what the entry fixes** (`bridge.ail:83`,
  `check_bridge_inputs`). A ninth input with no row there is an unchecked claim inside a check
  whose purpose is to have none. Whether it gains a row is 013's decision, not this plan's.
- **The findings note's third limit of part 6 exists only because of this edit**: the journal
  control was run on a prototype with no D4.

**Three ways to carry the budget.**

| | what changes | edits outside the gate's own files | what it keeps of D4 |
|---|---|---|---|
| **A**, as written | a field on `ExecutionUnderTest`, a ninth parameter on `execution_of` | 7 files, 3 of them 013's evaluator, holding 4 of the 5 call sites | all of it |
| **B**, the gate holds it | nothing in `src/core`; the gate declares the budget once and passes it to the run and to the two rules | none | the effective-budget definition, undeclared-is-reported, one value not two; **not** "the record carries" |
| **C**, the record carries it and the bridge defaults it | the field, set to undeclared by `execution_of` and to the declared value by a record update in the gate | 2 files in `src/core` and the fixture; none in the evaluator, and no arity change | "the record carries"; **not** "every site stating a value" |

**Recommendation: B.** The value has one writer and one reader and they are the same file. The
record already holds one field that was added before its reader, and its comment says so
(`dst_invariants.ail:661`, "NO FAMILY READS IT YET"). If a later decision makes either D4 rule a
family rule, the field arrives with its reader, and C is then the cheaper route to it than A.

**Ruled 2026-10-06: B** (G1; ADR-003 ruling 13, which amends D4's first sentence, its cost line
and step 1 of its sequencing). Shape A stays under WI-1 as the pricing the handoff asked for.

### F2 — "added to `DST_TARGETS`" is not "runs in CI", and two of D6's controls do not run there either

ADR-003 places the gate in `DST_TARGETS` and says no more. That makes it part of a sweep CI does
not run (§1). The same holds for `make invariants`, where WI-2's mutant rows live, and for
`make stream_parity`, whose pinned rule sets D6 names as a control. Of everything this plan adds,
CI sees only what lives in `src/core/dst_invariants.ail`: that it type-checks (`check_core`), its
contract (`verify`), and its inline tests (`test_coverage`). Of the scripts this plan touches it
runs one, `corpus_pr_dst.ail`, so the edit that shares the bank is checked there.

The consequence for D2's table is concrete: a new failure code makes a healthy run red "until
someone edits the table" (D2, *Fail direction*), and that red would be seen only by whoever next
runs the sweep by hand.

**Ruled 2026-10-06: the target is also named in a workflow** (G3; ruling 15), beside `corpus_pr`
in `dst-corpora.yml`, as its own step so `corpus_pr`'s wall-clock check stays alone. Its cost is
one more compile of `session.ail`, about a minute, in a job with a fifteen-minute limit.

### F3 — two of D2's four table rows are judged on no real run

D2's table has four rows: `StepBudgetExhausted` with `max_steps`, `BudgetExceeded` with
`cost_exhausted`, `ContextExhausted` with `compaction_exhausted`, every other code with `error`.
Measured today on the corpus gate's wire: eighteen run summaries, ten `stop`, seven `error`, one
`max_steps`, and none on cost or compaction. Six of the sixteen members end in `Err`: seeds 5, 7,
19, 30 and 32, and seed 244, which the findings note identifies as the one that exhausts its step
budget. Every bank run is started with a cost cap of zero (`corpus_pr_dst.ail:358`), which the step
machine reads as no cap (`step_machine.ail:112`).

So D1's gate judges the `error` row, the `max_steps` row and the `Ok` half. The other two rows are
checked only on constructed records in `make invariants`, and D6's table has no source mutant for
either, because no bank run would show one red. This is consistent with D2's soundness claim, which
rests on reading the finalize sites. It is a limit on what acceptance can claim, and WI-4 records it
beside D6's known-unseen list. Scripted runs that end on each reason exist outside the bank:
`ledger_parity_dst.ail:519` runs to its cost cap, and `long_qwen_compaction_dst.ail:848` expects
`ContextExhausted`. So closing it is a question of whether a gate bridges a run from outside the
bank, and that is a decision this plan does not take (§5).

### F4 — smaller corrections

1. **"Counts quoted in the DST report draft move."** One code literal moves:
   `dst_invariants.ail:2290`, `List.length(vs) == 40`. No document needs editing. The only draft
   that quotes a constructor count is `papers/motoko-dst-report/DRAFT.md:503`, a snapshot grounded
   at `b3953a9` that reads "twelve families, thirty-seven" against today's thirteen and forty. The
   `Makefile` comment at `:1612` to `:1614` also reads `(12)` and `(37)`; the guard beneath it
   counts by name and is unaffected.
2. **The contract policy has no exemption for `dst_*` modules.** `new_contract_policy.py` diffs all
   of `src/core` and exempts only declarations reachable solely from a `tests` block. The module has
   no contract and no `-- contracts:` line today. D2's table function is not recursive, and a probe
   shows such a function **verifies** under a synthesised `ensures { true }`, so an excuse on it
   would be rejected. It needs a real contract. `ensures { result != "stop" }` verifies in under
   100 ms and says something the rule depends on. The first contract in the file takes it out of
   `verify_core`'s "bare" bucket and requires `tools/verify_classify/contracts.register` to be
   regenerated in the same commit, or `verify_classify_check` fails in CI.
3. **A red row's failure record is not specified, and this one does need a ruling.** ADR-003 does
   not reopen 009 ADR-001, whose D8 lists twelve things a generated failure "reports and preserves"
   (`:2274` to `:2288`) and says replay "consumes the exact program and does not regenerate it"
   (`:2290`). This plan's first draft carried five of the twelve and settled the rest in a
   sentence; the review caught it. WI-3's step 9 now reports all twelve and takes the serialized
   program by reference to the artifact `corpus_pr` persists for the same member. **Ruled
   2026-10-06: a reference is enough** (G4; ruling 16).
4. **"Five checks" and "six gate checks" are the same thing counted two ways.** D4 is one check
   with two rules. This plan counts six rule ids.
5. **Two inherited coordinates are off without being wrong.** `ExecutionUnderTest` opens at
   `dst_invariants.ail:612`; `:645` is its `decision_budget` field. The `Makefile` comment at `:617`
   gives `corpus_pr`'s ceiling as 80 s; the source says 180,000 ms.

**Found on the way, and not this plan's.** The bank's promoted member, seed 141, is carried for
"the richest Err-terminating trajectory … one run that does NOT end Ok"
(`corpus_pr_dst.ail:587`). At HEAD it ends `Ok` (`CORPUSROW seed-141 … ended=Ok`), and no scenario
asserts otherwise. The findings note's part 1 already reads it as `Ok` at baseline.

---

## 3. Re-grounding: what HEAD says

Every anchor the handoff and ADR-003 give for the work below, observed at `59d5cbb9`.

| claim | HEAD | status |
|---|---|---|
| `ExecutionUnderTest` is built in full at two sites | `dst_execution.ail:110`, `invariants_dst.ail:409` | holds |
| `execution_of` has five callers | `stream_parity_dst.ail:269`; `bridge.ail:61`; `witness_live_test.ail:295`, `:296`; `candidate_checks_run.ail:108` | holds |
| other code builds the record | only by `{ x \| … }` updates (`invariants_dst.ail:929`, `:936`; `witness_live_test.ail:323`, `:325`; `candidate_checks_live_test.ail:402`), which a new field does not break | new |
| `evaluate` has callers outside the module | `invariants_dst.ail`, `stream_parity_dst.ail:293`, `:328`, `bridge.ail:103`, `witness_live_test.ail:174`, `:186`, `:328`, `candidate_checks.ail:383` | holds |
| a new `Violation` constructor breaks a caller's match | no: the one match outside the module, `candidate_checks.ail` `cc_violation_step`, ends in a wildcard | new |
| the rule ids WI-2 sits beside are pinned outside the module | no: `outcome-summary-disagree` and `provider-step-repeated` are named only in `invariants_dst.ail` (`:960`, `:945`). The evaluator pins two ids, `decision-budget-exceeded` (`witness_live_test.ail:334`, `candidate_checks_live_test.ail:404`, `MATRIX.expected.tsv:592`) and `journal-payload-disagrees` (`witness_live_test.ail:376`, `MATRIX.expected.tsv:620`); nothing here touches either | new |
| `Violation` `:318`, `violation_family` `:381`, `violation_rule` `:426`, `violation_message` `:471`, `bounded_progress_findings` `:1570`, `outcome_agreement_findings` `:1687`, `evaluate` `:2010`, `sample_violations` `:2306` | as given; forty constructors, nine inline tests | holds |
| the surviving fixture meets both new rules unchanged | outcome `Ok`, summary `finish_reason: "stop"` (`invariants_dst.ail:338`), one `ProviderCallPrepared` at step 0 (`:376`) | new |
| `stream_parity` pins the rule set of a real run | `["clock-balance"]` for the scripted adapter (`:380`), `[]` for the recording one (`:390`); both runs start with a step budget of 6 and end `Ok` | holds |
| D2's codes and reasons | `decision_fail_reason` `session.ail:2467`; `finish_reason_wire` `phase_vocab.ail:966`; the three named codes come from `step_machine.ail:111`, `:113`, `:117` and `session.ail:3798` | holds |
| the bank is not importable | `fixed_bank` `:573`, `generated_world` `:310`, `run_generated` `:354`, `run_recording` `:361`, `empty_terminal_world` `:604` are private; `BankEntry` `:548` and `main` `:1205` are exported | holds |
| a script can import the corpus script | yes: `import scripts/dst/corpus_pr_dst (BankEntry)` from a sibling script type-checks and runs (probe, removed). The reviewer went further: with the helpers exported, a sibling script ran all sixteen members and both controls in 51 s | new |
| the budget is a literal | `12` at `corpus_pr_dst.ail:358` and `:365` | holds |
| the corpus rig already has copies | `scripts/dst/export_trace.ail:97` ("kept byte-for-byte in step with `corpus_pr_dst.ail:299-313`"), which `depth_canary` pins; `evidence/D11-CEIL/per_seed_bench.ail` | new |
| `DST_TARGETS` `Makefile:507`; `corpus_pr` is the only timed target `:632` | as given; untimed targets get a private cache lane by default (`:646`) | holds |
| what a new script must be registered with | a target and a `DST_TARGETS` entry. `test_coverage` walks `src/core` only and asks nothing of a script. One inventory globs scripts by name: `tools/profile_definition/check_fixtures.py:954` reads every `scripts/dst/driver_*_dst.ail` | new |
| every source line D2 to D10 and D6's table cite | `session.ail:1094`, `:2351`, `:2723`, `:2789`, `:3335`, `:3402`, `:3535`, `:3572`, `:3613`, `:3623`, `:3694`, `:3792`, `:3799`, `:3807`, `:3887`, `:3892`, `:3920`, `:4480`, `:4572`, `:5584`; `step_machine.ail:103`; `recovery.ail:28`; `stub_step.ail:486` | all hold |
| the corpus at HEAD is the corpus the spike measured | wire witness identical to the note's: `approval_denied×35 … stream_error_retry×4 provider_failure_finalize×11 malformed_arguments×6`, 67 dispatch batches; ten members end `Ok`, six `Err` | holds |

**The three probes.** A twelve-line script importing `BankEntry` from `scripts/dst/corpus_pr_dst`,
run once in this plan's worktree and deleted. A scratch file outside the tree holding D2's table as
a function, given to `ailang verify` with three contracts. A script running two scripted worlds
through `run_v2_session_traced` at step budgets of 2 and 1, run once and deleted (WI-3, step 6).

**Measured by the reviewer, not by this session.** On each of the sixteen members at HEAD: no
finding from today's set; prepared steps contiguous from 0; provider and tool counts balanced;
request ordinals contiguous; D2's table satisfied. Six end `Err`: four on `E_PROVIDER_PROTOCOL`,
seed 19 on `E_PROVIDER_TIMEOUT`, seed 244 on `StepBudgetExhausted` with `max_steps`. Retries are at
steps 1, 8, 1 and 1, on seeds 9, 19, 32 and 141. Ten members dispatch tools. Seeds 19 and 244 make
12 calls on 12. Its probe computed these beside each run; it is not in the repository.

**Not re-observed by anyone.** The spike's per-mutant results. The two rules as implemented, which
do not exist.

---

## 4. The work items

### Which item carries which decision

| decision | item | accepted on (WI-4) |
|---|---|---|
| D1, the set on every member's run | WI-3 | the unmutated bank clean; rows 1 to 5 seen through the gate |
| D2, outcome agreement by reason | WI-2 | rows 1 to 4 |
| D3, no repeat (family) and no gap (gate) | WI-2, WI-3 | rows 5 and 6 |
| D4, the effective budget and its two rules | WI-3, on WI-1's single budget value | rows 7 and 8; the two budget-edge controls |
| D5, provider balance | WI-3 | row 9; the over-recorded mutant; the model-calling-hook probe |
| D9, request ordinals | WI-3 | rows 9, 10 and 11 |
| D10, tool balance | WI-3 | rows 12 and 13 |
| D6, acceptance by named mutants | WI-4 | — |
| D7, existing pins untouched | every item, rule 4 | — |
| D8, no reopen of 009 | no work | — |

### Rules that hold for every item

1. **Green is a difference.** A sweep or a matrix is green when its failure set equals that of
   the tree without the change under test (§1's, while that baseline is valid), not when it exits
   0.
2. **Run `corpus_pr` alone.** It gates on wall time.
3. **A healthy run that goes red is a finding.** Stop and report. Do not tune the rule.
4. **No existing pin moves** (D7): `stream_parity`'s two rule sets, the depth canary's counts and
   ceilings, a corpus identity, a register count.
5. **Mutation discipline** (`mutate-each-stated-rule-once-and-see-its-test-fail.md`). A row counts
   only when the rule it names goes red. A compile failure, a timeout or another check going red is
   recorded as that.
6. **A `src/core` change also runs** `make verify_core verify_classify_check new_contract_policy`
   and `ailang test` on the module. `make dst` runs none of them. The policy reads
   `origin/main...HEAD`, so it sees a change only after it is committed.
7. **Give a fixed `/tmp/*.out` path a private name** before running a gate beside another session.
   `corpus_pr`'s recipe writes `/tmp/corpus_pr.out`.

### Names this plan fixes

So that WI-4's table can be written before the code exists. A builder may rename a constructor or
a file; the rule ids are the contract between items.

| what | name |
|---|---|
| D2's constructor and rule id | `OutcomeFinishDisagrees`, `outcome-finish-disagrees`, family `OutcomeAgreement` |
| D3's family constructor and rule id | `DriverStepRepeated`, `driver-step-repeated`, family `BoundedProgress` |
| the gate | target `corpus_judge`, script `scripts/dst/corpus_judge_dst.ail`. Not `driver_*_dst.ail`: that name is globbed by the profile inventory (§3) |
| the six gate rule ids | `steps-not-contiguous` (D3), `provider-calls-exceed-budget` and `retry-at-budget-edge` (D4), `provider-calls-unbalanced` (D5), `request-ordinals-not-contiguous` (D9), `tool-dispatches-unbalanced` (D10) |

### WI-1 — the budget and the run recipe have one home (D4)

No behaviour changes. **The gate holds the budget** (ruling 13), so this item is the edit that
lets a second gate run the bank exactly as `corpus_pr` does.

One file, `scripts/dst/corpus_pr_dst.ail`, about twenty-five lines:

- one exported `bank_step_budget()` returning 12, used by both run helpers in place of the two
  literals (`:358`, `:365`);
- **one exported helper per member kind that gives a member's label, its starting world, its run
  and its program.** `build_seed` (`:664`) and `build_constructed` (`:684`) call it, and so does
  the gate. Today the id `"corpus_<seed>"`, the world constructor, the member label and the choice
  between `program_of` (`:373`) and `constructed_program` (`:617`) live only inside those two
  functions, and a gate that restated them would give the recipe two homes with nothing checking
  that they agree;
- a budget-taking form of `run_recording`, for WI-3's two control runs;
- `export` on `fixed_bank`, on `store_root` (`:394`), which the gate's failure record needs to
  name a member's persisted program, and on whatever the helpers above need.

Nothing else in the file moves. `export_trace.ail`'s copy of the rig is not touched: the depth
canary pins it, and rule 4 applies.

- **The rule a builder breaks by accident.** Moving the bank into a shared module "while here".
  That changes what `corpus_pr` compiles, shifts the lines `export_trace.ail:99` cites, and turns a
  no-behaviour-change commit into one that needs its own measurement.
- **Done.** `make corpus_pr`, alone, twice before the edit and twice after.
  - Its output is the same line for line with `duration_ms` masked: four equal hashes, equal to
    the one in `evidence/judge-recoveries/baseline-59d5cbb9/corpus_pr.wire.sha256`. Three
    checkouts have produced those bytes so far.
  - No run after is slower than the slower run before by more than 15 percent, with nothing else
    running. Faster is not a finding. The recipe itself enforces the 180 s ceiling.
  - `git diff --stat` shows the one file.
  - **No sweep.** No module imports the corpus script and only the `corpus_pr` recipe runs it
    (`Makefile:1851`), so no other target can move. WI-3's sweep covers both commits.
- **Stop and report.** Any differing line. A slowdown beyond that tolerance that a repeat
  confirms.

After ruling 13 this item calibrates nothing but itself: it is a mechanical edit and its cost is
four runs of one target. The cost report that the schedule waits for comes from the clusters (see
*Sequencing*).

**The route not taken, kept as the pricing the handoff asked for.** Had the record carried the
budget (shape A of F1), these are the sites and what each would have stated:

| site | what it states | kind |
|---|---|---|
| `dst_invariants.ail:612`, the type | a `step_budget: int` field beside `retry_budget` (`:646`), negative meaning undeclared | mechanical |
| `dst_execution.ail:100` to `:126` | a ninth parameter copied into the record; the header's "five bindings" (`:35`) becomes six | mechanical |
| `invariants_dst.ail:409`, the fixture | undeclared: a hand-authored fixture ran nothing | judgement, small |
| `stream_parity_dst.ail:269` | 6, from one value shared with the two run sites (`:373`, `:387`) and threaded into `check_execution` (`:263`) | judgement: it must not become a third literal |
| `bridge.ail:61` | `List.length(jw.calls)` when positive, which is what the admission run is started with (`admission_run.ail:73`); undeclared when zero, because the driver then enforces 8 (`session.ail:2351`) | judgement |
| `witness_live_test.ail:295`, `:296` | `x.step_budget`, passed through | mechanical |
| `candidate_checks_run.ail:108` | `e.calls` when positive: the candidate is started with `step_budget = N` (`:14`) and K4 takes "the entry's values, never recomputed from C's run" (`:26`). A dedicated entry field would change the entry codec, which this plan does not do | judgement |

Three mechanical, four judgement, by prediction. Its done-check would also have needed a matrix run
on the committed branch, and a note in project 013 that the bridge has nine parameters and that
its next pinned evaluator must be at or after the commit. Zero means 8 to the driver and unlimited
to the step machine, so a site that copied its argument would have been wrong in a way no test
saw.

### WI-2 — two rules in the invariant set (D2, and D3's family half)

Files: `src/core/dst_invariants.ail`, `scripts/dst/invariants_dst.ail`,
`tools/verify_classify/contracts.register` (generated).

**In the module.**

- **Two constructors**, each added in six places: the type (`:318`), `violation_family` (`:381`),
  `violation_rule` (`:426`), `violation_message` (`:471`), `sample_violations` (`:2306`), and the
  literal at `:2290`, which becomes 42. The three functions are total matches and fail to compile
  if missed. The sample list and the literal do not: `make invariants` checks the first by name,
  and the second is an inline test.
- **D2** in `outcome_agreement_findings` (`:1687`): `Ok` requires `stop`; an `Err`'s reason is
  the one its code implies. The table is a function in this module with a contract (F4.2), and it
  does not import `decision_fail_reason`. The existing error-text rule and its constructor stay as
  they are. A result with no terminal summary keeps today's `SummaryAbsentForOutcome`.
- **D3** in `bounded_progress_findings` (`:1570`): the `step` of each `ProviderCallPrepared` in
  the returned trace does not repeat. `ProviderStepRepeated` keeps reading the log. The import
  list at `:136` gains `ProviderCallPrepared`.
- **Messages that are true of the condition.** The v0.1 prototype reported a repeated driver step
  as a cursor that "did not advance" in a log that was fine.
- **The set's version.** `invariant_set_version()` (`:222`) becomes `invariant-set/2`. The comment
  above it says a change to a rule id is a version change. Only the banner of `make invariants`
  reads it.
- **Inline tests for the table**, one row per code and one for an unknown code. They are the only
  part of this item CI runs (F2).
- **Recursive helpers** take a `-- contracts: BLOCKED — RECURSIVE; …` line, the form already used
  in `dst_profile_coverage.ail:741`.

**In `invariants_dst.ail`,** beside the existing rows at `:909` to `:962`. Rejection rows assert
their own rule, as every row there does.

| row | must |
|---|---|
| `Err` with each of the four code and reason pairs, error text present | survive: no finding |
| two `ProviderCallPrepared` records with different steps | survive: no finding |
| `Ok` with `finish_reason` `error` | `outcome-finish-disagrees` |
| `Err` on a provider code with `stop` | `outcome-finish-disagrees` |
| `Err` on a provider code with `max_steps` | `outcome-finish-disagrees` |
| `Err` on `StepBudgetExhausted` with `error` | `outcome-finish-disagrees` |
| `Err` on `BudgetExceeded`, and on `ContextExhausted`, each with `error` | `outcome-finish-disagrees` (F3: the only place these two rows are checked) |
| two `ProviderCallPrepared` records with one step | `driver-step-repeated`, and **not** `provider-step-repeated` |
| the existing frozen-cursor row (`:942`) | still `provider-step-repeated`, and **not** `driver-step-repeated` |

The second row is there because the fixture has one prepared record: without it, a D3 that fired
on any two prepared records would pass every row in this script.

The fixture builds only an `Ok` outcome today. `fixture_result` (`:394`) and `with_trace` (`:426`)
both write `Ok([])`, so `with_records` resets the outcome of any fixture passed through it, and
the summary helper fixes `stop` (`:337`). All three need a second form. An `Err` fixture is also
not the `Ok` one with its outcome flipped: the fixture trace carries a `DoneEvent` (`:389`), which
`done_agreement` (`dst_invariants.ail:1728`) rejects beside a summary error, so a survival row
built that way is red on `done-event-disagrees`.

- **What makes it hard.** The two "and not" rows. They are the difference between two rules and
  one rule reported twice, which is the defect part 4 found.
- **Done.** `make invariants` passes with the new rows. `make stream_parity` passes with
  `["clock-balance"]` and `[]` unchanged. `ailang test src/core/dst_invariants.ail` passes, nine
  tests and the new ones. `make verify_core verify_classify_check` pass with the register
  regenerated. `make dst` adds no failure. Then, **after the commit**:
  - `make new_contract_policy` names each new function with `carries a contract` or
    `excuse checked`. Before the commit it prints `no pure func added` and exits 0 whatever the
    tree holds.
  - **`make eval_matrix` is row for row the matrix of this commit's parent**, which is §1's while
    `main` has not moved; `evidence/judge-recoveries/compare_matrix.py` does the comparison. This
    is D6's first precondition (ruling 14) run early: this commit is where D2 and D3 start running
    on journal runs, and `witness_live_test.ail:186` asserts no finding on one.
  - `make corpus_judge` passes, if the other cluster has merged.
- **Stop and report.** A healthy run red under either rule, in any place that evaluates one. A
  pinned rule set that would have to change. A matrix row that differs.

### WI-3 — the gate (D1, D3's gate half, D4's two rules, D5, D9, D10)

Files: `scripts/dst/corpus_judge_dst.ail` (new), `Makefile`, `.github/workflows/dst-corpora.yml`.

**How two gates share one bank.** Decided here, as the handoff asks.

| route | verdict |
|---|---|
| **Export the bank and its run helpers from the corpus script and import them** | **Chosen.** `corpus_pr` runs the same code from the same file, so its counters, identities and wall time have no reason to move, and WI-1's done-check measures that they did not. The reviewer ran this route end to end: sixteen members and both controls from a sibling script, 51 s |
| Move the bank and the rig into a shared module | Rejected for now. It would also let `export_trace.ail` drop its copy, which is the better end state, but it changes what `corpus_pr` compiles and where the depth canary's rig lives, so it moves two pinned gates at once. Its own decision |
| A second entry point inside the corpus script | Rejected. Every line added there is compiled by the one target that gates on wall time |
| A copy, as the spike's probe was | Rejected by the handoff. A third copy of a rig that already has two |

**What the script does.**

1. **Runs the bank through the corpus script's own helpers**, imported: one call per member to
   the helpers WI-1 exports. It builds, persists and keys nothing. `corpus_pr` deletes and
   rewrites `.ailang/dst-corpus`; this gate does not write there. It prints each member's log
   length and outcome in `corpus_pr`'s terms (`n=`, `ended=`).
2. **Declares its budgets in one place** (D1): the step budget is `bank_step_budget()`, the value
   the run helpers pass to the driver (ruling 13); the retry budget is one below it; there is no
   decision budget.
3. **Bridges and evaluates** each member:
   `execution_of(run, <the starting world's clock>, NoReplay, -1, bank_step_budget() - 1, 0, [], unknown_replay_metadata())`,
   then `evaluate`. The clock is the member's starting world's, not zero. The obligation is
   `NoReplay`, because this is a discovery run, so the replay family is not evaluated on any
   member; the gate prints the families that were not evaluated in one line, as the journal bridge
   does. The two audit counts are supplied, not derived. It bridges only a result that carries a
   terminal summary (`run_summary_finish_reason`, `phase_vocab.ail:1266`), and it is red if it
   bridged fewer than all sixteen.
4. **Makes the six checks** on each run. The functions are local to the script: they are gate
   checks by ruling, and outside `src/core` they are outside the contract policy and outside 013's
   path list.

   | rule id | reads | red when |
   |---|---|---|
   | `steps-not-contiguous` | `ProviderCallPrepared.step` in the trace | not 0, 1, 2, … |
   | `provider-calls-exceed-budget` | the same records, the declared budget | more calls than budget |
   | `retry-at-budget-edge` | `StreamErrorRetry.step`, the declared budget | a retry where budget minus step is 1 or less |
   | `provider-calls-unbalanced` | prepared records; provider interactions the run added to the log | the two counts differ, either way |
   | `tool-dispatches-unbalanced` | `V2ToolDispatchStart` records; tool interactions the run added | the two counts differ, either way |
   | `request-ordinals-not-contiguous` | `WorldRequest.ordinal` in the trace; the starting and returned worlds' ordinals | not +1 from the first to the second |

   The two balances use `dst_discovery.class_balance` (`:374`), which already reports both
   directions from one comparison. Log counts are a delta over the starting world's log.
5. **Proves each check can fire and can stay silent,** in the script: a constructed input per
   rule id that must produce that id, **one for each direction of the two balances**, and one
   that must produce nothing.
6. **Carries the two budget-edge controls D6 owes** as permanent rows, on constructed worlds run
   through the budget-taking helper. Both shapes are measured at HEAD: by this session on
   `stream_parity`'s rig, and by the reviewer on the bank's rig with the same result.
   - *A valid retry with two steps left.* Budget 2; the script serves a retryable provider error
     (`error_code: "E_PROVIDER_TIMEOUT"` on a `ScriptedStep`) and then a prose stop. Measured: `Ok`
     on `stop`, prepared steps 0 and 1, one retry at step 0, two provider interactions logged. Every
     rule here is green on it.
   - *No retry with one step left.* Budget 1; the script serves the same error. Measured: `Err`
     with `E_PROVIDER_TIMEOUT` on `error`, one prepared step, no retry record.

   No scripted scenario in the tree serves a retryable provider error today; only generated seeds
   reach the retry branch. If either control behaves differently in the built gate, that is a
   stop-and-report, and a bank member is not the fallback.
7. **Refuses to be vacuously green.** Red if no member recorded a retry, if no member dispatched a
   tool, or if any member's trace holds no prepared call or no request ordinal. **It prints every
   member's rule rows before this verdict.** A defect that empties a trace trips this guard on
   every member, and the rule it broke must still be on the screen.
8. **Reports an undeclared budget as not evaluated**, and treats not-evaluated on a bank member as
   red. The bank always declares; the path is exercised by one constructed row.
9. **On a red row, reports what 009 D8 lists** (ruling 16):

   | D8 asks for | from |
   |---|---|
   | program schema version, generator id, generator version, seed | the member's program record, which WI-1's helper returns |
   | the exact serialized program | **by reference**: `artifact_path(store_root(), program)` (`dst_persistence.ail:1254`), the path where `corpus_pr`'s `build` (`:637`) persisted this member's program. `corpus_pr` runs before this gate in the sweep and in the workflow. If the file is absent the gate says so and names the command that writes it. The gate does not persist a program of its own, which would make it a second writer of that store |
   | source revision and toolchain version | the recipe: `git rev-parse HEAD`, `ailang --version` |
   | the profile and its manifest | the program's `extension_profile` and `manifest` fields; `driver_only_version()` (`dst_driver_only.ail:528`) |
   | the event-vocabulary version | `event_vocabulary_version()` (`dst_event_vocabulary.ail:121`) |
   | the run configuration | the declared budgets and the rig's fixed arguments |
   | the first failed invariant | `first_failed_invariant` for a family finding; the rule id for a gate check |
   | the terminal outcome | the member's `ended=` and finish reason |
   | the trace, or where it is | the recipe keeps its output file when the target is red and prints the path; it holds every member's wire |

   D8 also says replay "consumes the exact program and does not regenerate it". The reference
   above is to that program. The gate's own re-run regenerates from the seed and is offered as the
   quick reproduction, not as the replay.

**In the `Makefile`.** One target with `corpus_pr`'s capability list and `--ai-stub`, output to a
`mktemp` file that is removed on green and kept on red, in `DST_TARGETS` (`:507`) and not in
`DST_TIMED_TARGETS` (`:632`), so it runs in the fan-out on its own cache lane.

**In the workflow** (ruling 15). One step, `make corpus_judge`, after "D11's blocking PR corpus"
in the `pr-corpus` job of `dst-corpora.yml` (`:98`), with `if: ${{ !cancelled() }}`: a step after
a failed one is skipped by default, and a wall-clock red on `corpus_pr` must not hide this gate.
The job hydrates packages first, has a fifteen-minute limit, and takes about six and a half
minutes today by the reviewer's reading of its runs.

- **The rules a builder breaks by accident.** Writing `12` in the gate. Reusing the probe, which is
  a copy of the corpus script with the budget hardcoded. Applying a balance to a run outside the
  `driver_only` bank.
- **Done.**
  - The target passes on the unmutated tree: all sixteen members clean on the set and on six
    checks, every self-check row as named, both controls green.
  - Each member's `n=` and `ended=` equal `corpus_pr`'s `CORPUSROW` values. That is the check that
    the gate's sixteen runs are `corpus_pr`'s.
  - The failure record has been seen once, on a real member, by a temporary edit that is then
    restored: all of step 9's items present, the output kept, its path printed.
  - `make corpus_pr`, alone, is unchanged in output and within WI-1's tolerance in time.
  - `make dst` adds no failure and gains one passing target.
  - If the other cluster has merged, all of this holds with its two rules in the set.
- **Stop and report.** A healthy member red on anything. `corpus_pr` changed by the sharing. Either
  control needing a bank member. A `driver_only` member that parks, which restates
  `steps-not-contiguous` by ruling 8.

### WI-4 — acceptance (D6)

Run once, at the commit handed in, by a session that built none of it. Its evidence goes to
`evidence/judge-recoveries/` in this project: `mutants.tsv`, the script, the predictions and their
hash, the score output, the commit.

**First, the four preconditions, in this order.**

1. **The journal callers** (ruling 14). `make eval_matrix` at the handed-in commit, compared row
   for row, with `compare_matrix.py`, against **the last tree without the two rules**. That is
   WI-2's parent, and it is `baseline-59d5cbb9` while that baseline's validity check holds. It is
   not "the parent of the handed-in commit": if the gate merges after the rules, that parent
   already has them, and the comparison would print `IDENTICAL` whatever the rules do. The three
   suites that evaluate real runs exit 0 in both. Then two known-bad controls, so that "no
   difference" is not the answer to everything: D2's table with `StepBudgetExhausted` implying
   `error`, as in part 6, and D3's rule inverted so it fires on any run. Each must turn
   `witness_live_test.ail` red with a finding at `aggregate:invariants:<family>`. The D3 control
   shows only that these suites would report a D3 finding; no journal run contains a retry, so no
   driver mutant can show it there. `scripts/eval/test_candidate.py` assembles its trees from a
   commit and refuses them all at HEAD before running (`ProtectedRegionTouched`), so that suite
   says nothing either way, as in part 6.
2. **The two budget-edge controls**, already rows of the gate (WI-3, step 6).
3. **A mutant for D5's over-recorded direction.** Drop the `ProviderCallPrepared` append at
   `session.ail:3861`. Predicted: `provider-calls-unbalanced`, log above trace, on every member.
   It also leaves every trace with no prepared call, so step 7's guard is red on every member
   beside it. The row counts when the named rule is printed, which is why step 7 prints rule rows
   first.
4. **A profile whose hook calls the model.** A one-off probe, kept in the evidence and not in the
   gate: a recording run whose pre-step hook calls `ai_step`, the shape
   `scripts/dst/world_state_probe.ail:237` already has (`consuming_pre_step_2`). Expected: a healthy
   run with more provider interactions logged than prepared records, which is why D5 is fenced to
   the bank. Its cost is one hook binding and one scripted world, both with a shape to copy. No
   existing gate bridges such a run to `execution_of`, so the probe counts the two channels itself.

**Then D6's twelve rows and one this plan adds,** one at a time, source restored and hash-checked
after each, predictions written and hashed before the first run. The member predictions are
consistent with the reviewer's per-member run at HEAD (§3).

| # | one edit | must go red |
|---|---|---|
| 1 | `session.ail:3920` reports the success reason | `outcome-finish-disagrees`, the five provider-failure members |
| 2 | `session.ail:3402` reports a failure reason | `outcome-finish-disagrees`, the ten `Ok` members |
| 3 | `session.ail:3920` reports `max_steps` | `outcome-finish-disagrees`, the same five |
| 4 | `session.ail:2789` reports an internal failure | `outcome-finish-disagrees`, seed 244 |
| 5 | `session.ail:3887`, the retry does not advance `step_idx` | `driver-step-repeated` |
| 6 | `session.ail:3887`, the retry advances by two | `steps-not-contiguous` |
| 7 | `step_machine.ail:103` allows one call past the budget | `provider-calls-exceed-budget`, alone, on the member with 13 on 12 |
| 8 | `recovery.ail:28`, drop `remaining_step_budget > 1` | `retry-at-budget-edge`, on seed 19, which takes a retryable timeout at step 11 of 12 and is not retried today |
| 9 | `session.ail:3892`, the retry keeps the pre-call world | `provider-calls-unbalanced` and `request-ordinals-not-contiguous` |
| 10 | `session.ail:3613`, the denied-approval arm continues from `st` | `request-ordinals-not-contiguous` |
| 11 | `session.ail:3920` drops the capture read's successor | `request-ordinals-not-contiguous` |
| 12 | `session.ail:3623`, the approved call's successor is dropped | `tool-dispatches-unbalanced`, log below trace |
| 13 | `tool_phase.ail:505`, `start_event` left out of `emitted` | `tool-dispatches-unbalanced`, log above trace, on the ten members that dispatch tools |

Row 13 is not D6's. D6 owes an over-recorded mutant for D5 and none for D10, but the gate states
both balances as red either way, and the mutation discipline asks for one mutant per case. Its
prediction is by reading.

**Controls that must stay green:** the unmutated corpus; a comment-only edit in the retry branch;
`make invariants`; `make stream_parity` with its two rule sets; the module's inline tests.

**Then a reviewer's own mutants.** A fresh agent given D2 to D5, D9 and D10 as prose and told not
to open D6's table, this plan's WI-4, the findings note's parts 4 and 5, or
`evidence/mutation-spike/`. The two ADR reviews were not blind, and one said so; this is the first
round that can be.

**What acceptance does not claim,** recorded with the result: D6's known-unseen list; the two
table rows of F3; anything in *Not decided*.

**Instruments.** `evidence/mutation-spike/scripts/` has the mutant applier, the runner and the
scorers. `score3.py` reads a timed-out gate as green (correction 7 of the findings note); do not
reuse it unrepaired. The detector for all fourteen mutant rows is the one gate, about a minute a
row.

### Sequencing

By source surface: two build clusters that share no file, then acceptance.

| cluster | items | files | handoff |
|---|---|---|---|
| 1 | WI-1 then WI-3, two commits | `scripts/dst/corpus_pr_dst.ail`, `scripts/dst/corpus_judge_dst.ail`, `Makefile`, `.github/workflows/dst-corpora.yml` | `HANDOFF-build-the-corpus-judge-gate.md` |
| 2 | WI-2 | `src/core/dst_invariants.ail`, `scripts/dst/invariants_dst.ail`, `tools/verify_classify/contracts.register` | `HANDOFF-build-the-two-invariant-rules.md` |
| then | WI-4 | this project's evidence only | written when both have merged |

The two clusters can run in parallel from the first day, each in its own worktree, and can land in
either order. They first meet in whichever lands second: its done-check runs the gate with the
rules in the set, and with ruling 15 so does the `pr-corpus` job on its pull request. A member red
there is rule 3.

**Both build handoffs are written with this plan.** Neither cluster moves a line the other cites,
so both can be grounded today, and each opens with a source-unchanged check for the day it is
picked up. WI-4's handoff waits: it needs the built names and the gate's real output.

**What each item costs in machine time, at the least.** From §1's measurements, on a cold cache.
Authoring time is not estimated: nothing here has measured it, and each cluster reports its own
when it ends. The first report replaces the analogy for the other.

| item | what it cannot skip | about |
|---|---|---|
| WI-1 | `corpus_pr` four times | 6 min |
| WI-3 | the gate, `corpus_pr` once, one sweep | 40 min |
| WI-2 | one sweep and one matrix, and the invariant, parity and contract gates, which were not timed | 50 min and those |
| WI-4 | sixteen runs of the gate, one matrix, and two known-bad controls, which are a matrix each if run whole | 30 to 60 min, and the reviewer's rows |

**Not in this plan.** A `PLAN-*.dagr.json` beside this file: project 008's ADR-001, which asks for
one, is in draft PR #215 and not on `main`.

---

## 5. The operator's rulings, and what stays the operator's

Ruled on 2026-10-06, in conversation, after this plan's recommendation for each: "I will go with
your recommendations".

| gate | question | ruling | in ADR-003 |
|---|---|---|---|
| **G1** | F1: does the record carry the step budget (A), does the gate hold it (B), or does the record carry it with a default (C)? | **B.** The gate holds it; `execution_of` keeps eight parameters | ruling 13 |
| **G2** | The handoff's open question: is D6's journal precondition the whole matrix read as a difference, or only the suites that reach `evaluate`? | **The whole matrix, row for row**, with `witness_live_test`, `candidate_checks_live_test` and `admission_live_test` exiting 0 in both. §1 shows the comparison is exact, and it costs under fourteen minutes | ruling 14 |
| **G3** | F2: is the new target also named in a CI workflow? | **Yes**, as its own step beside `corpus_pr` | ruling 15 |

Ruled the same day, after the review, on the revised plan's recommendation: "I will go with your
recommendation".

| gate | question | ruling | in ADR-003 |
|---|---|---|---|
| **G4** | F4.3, raised by the review: on a red row the gate reports all twelve of 009 D8's items, and takes the serialized program by reference to the artifact `corpus_pr` persisted for that member, not by persisting one itself. Is a reference enough? | **Yes.** Both gates run the same sixteen programs in the same job, and a second writer of the corpus store is a race | ruling 16 |

**Not settled here, by the handoff's instruction:** the nine items of ADR-003's *Not decided*;
whether a gate bridges a run from outside the bank to judge the cost and compaction rows (F3); a
new fixed-bank member for any control.

**Stop-and-report triggers, collected:** a healthy corpus member or journal run red under a rule as
implemented; any existing pin that would have to move; `corpus_pr` changed in output or time by the
sharing; a precondition control that needs a bank member; a `driver_only` member that parks.

---

## 6. Guardrails, carried from the handoff and re-verified

- **Do not copy the prototype.** Confirmed in `prototype2.diff`: it reuses `ProviderStepRepeated`
  and `OutcomeSummaryDisagree`, and `spike_families_on_bank.diff` passes `12` beside the run's own.
- **Read `make dst` and `make eval_matrix` as differences.** §1 gives today's failure sets.
- **Run `corpus_pr` alone.** 82 s alone today; the spike saw 207 s beside four gates.
- **A kill counts only when the named rule goes red.** Rule 5.
- **Scope.** `provider-calls-unbalanced`, `tool-dispatches-unbalanced` and
  `request-ordinals-not-contiguous` are checks of this gate on the `driver_only` bank. Not a family
  rule, not another profile.
- **The ADR wins** where this plan and it disagree. After rulings 13 to 16 it does not disagree
  with §2.

---

## Appendix A — the baseline, verbatim

`make dst` at `59d5cbb9`, clean checkout, 2026-10-06, the closing summary:

```
─── make dst ──────────────────────────────────────────────────────────
  2085s wall, -j8, load 1.66 2.82 4.72

  FAILED (4):
    driver_plus_compose          NEW — this one is yours
    driver_plus_no_ops           NEW — this one is yours
    ext_hook_scope               NEW — this one is yours
    ext_hook_scope_selftest      NEW — this one is yours

  NOTE: driver_plus_herdr is listed in DST_KNOWN_RED but PASSED.
  NOTE: herdr_graded is listed in DST_KNOWN_RED but PASSED.

  exit 2 — make's "errors were encountered". See the NEW rows above.
```

`make eval_matrix` at the same commit, its two summary lines:

```
eval_matrix: 621 rows: credited=419, equal=129, failed=29, inapplicable=11, missing=33
eval_matrix: suites 28, non-zero exit: scripts/eval/test_candidate.py=1, src/eval/journal/candidate_checks.ail=1, tools/eval_protected/selftest.py=1
```

`evidence/judge-recoveries/baseline-59d5cbb9/` holds the sweep's summary with each red target's
failing lines, the matrix's `MATRIX.tsv`, suite exits and join statuses, the masked hash of
`corpus_pr`'s output, and the driving script; `compare_matrix.py` beside it compares two matrix
runs. The full sweep log and the per-suite logs are in `tmp/plan-011-baseline-2026-10-06/` of the
main checkout, which is git-ignored.
