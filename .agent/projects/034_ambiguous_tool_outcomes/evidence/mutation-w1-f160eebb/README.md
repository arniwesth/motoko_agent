# Phase 1 mutation run at `f160eebb`: the result

Run on 2026-10-18/19 for `../../PLAN-001-effect-disclosure.md` W1.7, under standing rule 3 and
`.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`. Commit handed in:
`f160eebb` (W1.6, the head of `arniwesth/034-w1-world-and-catalogue`). AILANG v0.52.5, uid 1001.
Started 2026-10-18T23:18:03Z, ended 2026-10-19T00:02:06Z (`meta.txt`). No source was changed
by this task: the run's only new files are in this directory.

## The result

- **Every row of the plan's table is a kill.** v01-v22, all 26 ids the table lists (v15a/b and
  v16a-d included), each red on every test it named before the run. Three rows were added:
  v20b and v20c, two more of the adoption sites W1.3 re-seats, both kills; and v01b, the
  survivor below. 29 mutants in all. No mutant failed to compile,
  timed out or stopped before a suite's summary.
- **v12 is killed by both targets the task names**: `strict_replay_dst`'s standing-rule-6 row
  in the world-truth run, and `corpus_pr_dst`'s guard row, now that W1.6's bank draws `applied`.
- **One survivor, with its sentence: v01b**, an added row (below). It is not a row of the plan.
- **Both controls are green**: the unmutated source before the first mutant (`C-baseline`) and
  after the last (`C-restored`), 575 tests and rows each, with all 19 survival rows green.
  `K0`, a comment-only edit, leaves every suite green, so a recompile alone is not a kill.
- **The survival case holds**: the unmutated bank (all 18 members, `bank_replay.ail`), the
  legacy fixtures v1-v4 and the frozen v5 fixture decode and replay clean (the survival rows
  below, green in both controls and in K0).
- After the run the seven files it mutates are byte-identical to `f160eebb` (sha256 checked after
  every mutant and at the end), and `git status` shows nothing outside this directory.

| id | rule | expected red (named before the run) | verdict |
|---|---|---|---|
| v01 | W1.2 legacy program → empty world-truth list | `pp`: the v1-v4 legacy row | KILL |
| v01b | (added) the same, tool faults only | `pp`: the v1-v4 legacy row | SURVIVED (sentence) |
| v02 | W1.2 a /5 program must carry the line | `pp`: `artifact-missing-section ← the execution-program/5 world-truth line … deleted` | KILL |
| v03 | W1.2 a listed ordinal is not a completed call | `dst_replay:test_a_listed_completed_tool_outcome_refuses_replay` | KILL |
| v04 | D4 `applied` on a before-dispatch fault is rejected | `dst_replay:test_a_listed_before_dispatch_fault_refuses_replay` | KILL |
| v05 | W1.3 replay sets `applied` from the list | `sr`: world_truth reconstituted-queue row; world_truth rebuilt-effect-log row | KILL |
| v06 | W1.2 `applied` never enters the served payload | `sr`: world_truth (b) identical-interactions row; `ports:test_applied_never_reaches_the_outcome_or_its_payload` | KILL |
| v07 | W1.3 a fault is logged only when applied | `sr`: world_truth effect-log row; v5_fixture effect-log row | KILL |
| v08 | D4 twin must exist | `dst_fault_catalogue:test_world_only_twin_missing_fails`; `fc`: v08 row | KILL |
| v09 | D4 twin not world-only | `…twin_that_is_world_only_fails`; `fc`: v09 row | KILL |
| v10 | D4 twin constructor matches | `…twin_constructor_differs_fails`; `fc`: v10 row | KILL |
| v11 | D4 twin branch matches | `…twin_branch_differs_fails`; `fc`: v11 row | KILL |
| v12 | D4 no world-only id on the wire | `sr`: world_truth standing-rule-6 row; `cp`: guard row | KILL |
| v13 | before-dispatch ToolFailed → none | `tool_phase:test_w14_tool_failed_before_dispatch_none` | KILL |
| v14 | after-dispatch ToolFailed → unknown | `tool_phase:test_w14_tool_failed_after_dispatch_unknown` | KILL |
| v15a | deadline → unknown | `tool_phase:test_w14_deadline_unknown` | KILL |
| v15b | correlation mismatch → unknown | `tool_phase:test_w14_correlation_mismatch_unknown` | KILL |
| v16a | policy denial → none | `tool_phase:test_denial_message_uses_tool_role_and_call_id` | KILL |
| v16b | approval denial → none | `session:test_w14_policy_denied_message_none` | KILL |
| v16c | undecodable arguments → none | `tool_phase:test_w14_undecodable_arguments_none` | KILL |
| v16d | delegated deferral → none | `tool_phase:test_w14_delegated_deferred_none` | KILL |
| v17 | the stage round-trips | `ports:test_the_dispatch_stage_round_trips_through_the_tool_codec_both_values` | KILL |
| v18 | a legacy fault decodes after dispatch | `ports:test_a_legacy_failed_tool_payload_decodes_as_after_dispatch` | KILL |
| v19 | world truth stays out of the token | `ext_world:test_the_world_token_holds_neither_applied_nor_the_effect_log` | KILL |
| v20 | `applied` re-seated after adoption (`adopt_world`) | `ext_world:test_adoption_re_seats_applied_from_the_pre_hook_world` | KILL |
| v20b | (added) the same, at `tool_phase.ail:437` | `sr`: world_truth effect-log row | KILL |
| v20c | (added) the same, at the session pre-step chain | `sr`: world_truth effect-log row | KILL |
| v21 | effect log re-seated after adoption | `ext_world:test_adoption_re_seats_the_effect_log_from_the_pre_hook_world` | KILL |
| v22 | completed calls enter the effect log | `sr`: world_truth effect-log row; v5_fixture effect-log row | KILL |
| K0 | control: comment-only edit | nothing red | PASS |

`mutants.tsv` has each row's exact edit and site, every other test that went red (`also_red`,
never counted), and which survival rows the mutant turned red (`survival_red`).

## How it was run

    python3 .agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-w1-f160eebb/mutate.py --apply-check
    python3 .agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-w1-f160eebb/mutate.py

from the worktree root at `f160eebb`. `mutate.py` holds the spec and is the runner, on W0.6's
pattern (`../mutation-019f1c6c/mutate.py`). It refuses to start as root, off `f160eebb`, or with
anything dirty outside this directory. For each mutant, one at a time, it copies the file,
applies the edit (each `old` string must occur exactly once; `<EOF>` appends), runs all
seventeen suites, copies the file back and compares its sha256 with the original. It clears
`.ailang/dst-artifacts` and `.ailang/dst-corpus` before every script suite, so no mutant's
persisted artifact is read by the next run. `AILANG_FS_SANDBOX` is unset for each run.

| suite | command | what it holds |
|---|---|---|
| eleven inline | `ailang test --json src/core/<file>.ail` for ports, dst_replay, ext_world, tool_phase, session, dst_fault_catalogue, dst_persistence, dst_program, dst_corpus, tool_fault, tool_dispatch_adapter (`adapter`) | W1.2-W1.5's unit rows |
| `pp` | `make program_persistence`'s `program_persistence_dst` | W1.2 decode rows, the v1-v5 fixture rows |
| `ep` | `make execution_program`'s `execution_program_dst` | W1.2 structural rows |
| `fc` | `make fault_catalogue`'s `fault_catalogue_dst` | W1.5 v08-v11 rows |
| `sr` | `make strict_replay`'s `strict_replay_dst` main | W1.3 world_truth and v5_fixture, W1.5's guard |
| `cp` | `make corpus_pr`'s `corpus_pr_dst`, plus the target's before-dispatch wire count as one row | the bank, W1.5's guard |
| `bank` | `bank_replay.ail` (this directory) | the survival case: the bank strictly replayed |

**What counts.** An inline test is `suite:function`, red when its status is neither `pass` nor
`skip` (`skip` is a contract property with no generator: 7 in `tool_fault`, which ran nothing;
the first attempt of this run counted them red, so `C-baseline` failed and no mutant ran, and
the rule was set to W0.6's). A script row is `suite:<fragment of its pass line>`, red when
fewer pass lines carry the fragment than in `C-baseline`; digits compare as `#` except after `v`
or `/`, so a count that moves inside a passing line is not a failure. A mutant is a `KILL` when
every test in its expected set is red, in a run where every suite compiled and printed its
summary line. Other red tests are listed and never count. `NOT-RUN` and `PARTIAL` did not occur.
`apply-check.txt` is `--apply-check`: every mutant applied, `ailang check`ed and restored, all
compiling.

**Survival rows** (`SURVIVAL` in the script): `pp`'s frozen v1-v5 rows, the v1-v4 legacy row,
the v5 byte-identity row and the frozen-program regression replay; `sr`'s v5_fixture rows, the
world_truth strict replay and the rich and maxsteps replays; `cp`'s 18 load-back rows; and
`bank`'s 18 members' replay and world-truth rows and its closing row (5 applied faults listed
across seeds 11, 14, 102, 165 and 215, so world truth was replayed, not vacuously absent).

## Files

| file | what |
|---|---|
| `mutants.tsv` | one row per control and mutant; `commit` is `f160eebb` |
| `mutate.py` | the spec and the runner |
| `bank_replay.ail` | the bank survival case; run with `--relax-modules`, as its path is no module path |
| `apply-check.txt` | `--apply-check` output |
| `run.stdout.log` | the run's own progress lines |
| `meta.txt` | full commit, uid, AILANG version, start and end |
| `runs/<id>/` | `mutant.diff`, and each suite's log with the driver's JSON wire lines dropped |

## Choices a reader should know

- **v01 lists every fault-status ordinal; v01b only tool faults.** The four frozen legacy
  specimens hold no tool fault: their one fault, #3, is an extension effect. "All applied" is
  visible to them only through that ordinal, so v01 lists every fault and v01b was added to
  measure the narrower reading.
- **v06 carries `applied` in `ToolFailed.message`** (`scripted_tool_outcome`), the one field
  of the outcome the payload encodes that can hold it: `ToolOutcome` has no `applied` (D4's "no
  carrier"), so a mutant that encodes it must route it through a field that exists.
- **v12 gives the renderer the bit it lacks.** The typed renderer has no `applied` input, so the
  mutant (`tool_phase.ail:515`, line-neutral, helper at EOF) renders through a copy that, when the
  dispatch grew the world's effect log on a fault (that is, applied), writes the world-only id in
  `fault_class`. The effect log is used, not the pre-dispatch queue, because the bank's tools are
  generated inside `generating_tool` and never sit in `state.tools`; with the queue, the bank
  would not see the mutant. The guard is untouched.
- **v13-v16d change the disclosure and keep the kind**: `{ <builder> | effects: failed_fault(b).effects }`,
  at each renderer's call site, so the builders' contracts stay true and the red row is red on
  `effects`. v16b adds `failed_fault` to `session.ail:43`'s import, line-neutral.
- **v20 is mutated in `adopt_world`; v20b and v20c at two of its nine call sites**, each by
  handing it a pre-hook world with no tools, which drops the `applied` re-seat there alone. W1.3
  recorded the `tool_phase` site and "the intercept re-seat" as spot checks; the pre-step chain
  is the session site that runs before every dispatch.
- **Every edit in an anchored file is line-neutral** (`tool_phase.ail`, `session.ail`), and
  v17 keeps `ports.ail`'s line count, so no anchor moves under a mutant.

## The survivor

| id | rule | sentence |
|---|---|---|
| v01b | W1.2 a legacy program decodes with an empty world-truth list, read as "every tool fault applied" | An equivalent mutant on every pre-v5 artifact this tree holds: the four frozen specimens record no tool fault, and no gate builds a pre-v5 program that has one, so listing only tool faults lists nothing and decodes what the rule requires. v01 kills the same branch (`dst_persistence.applied_faults_at`'s pre-v5 arm). What v01b shows is that the legacy row would not see a decoder that special-cased tool faults. Not closed here, because this task makes one commit and changes no source: a pre-v5 tool-fault row is a few lines in `program_persistence_dst` (the v5 specimen rebuilt at `execution-program/4` without its `applied_faults` line, with `rebuild_at`, as the UnknownTag row does), and is handed to W1.8. |

The sentence was written after the run measured the survivor. It is in `mutate.py`'s
`SENTENCES` and in the row's `notes`, and the verdict stays the measured `SURVIVED`.

## What the also_red columns show

- **v17 also turns `dst_replay:test_a_listed_before_dispatch_fault_refuses_replay` red**: with
  the stage dropped, a before-dispatch fault decodes after dispatch, so D4's refusal cannot fire.
  The stage codec carries v04's rule too.
- **v05, v06, v07, v20-v22 each turn the bank survival case red**, and v07 also turns `cp` red
  (the observer counts a non-applied fault as world-only). That is the bank replaying world
  truth, which `make corpus_pr` alone does not do.
- **v13 also turns `cp`'s before-dispatch wire count red** (0 on the wire), the W1.6 check that
  keeps the typed renderer's `none` arm exercised in the bank.
