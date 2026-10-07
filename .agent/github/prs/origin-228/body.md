---
repo: arniwesth/motoko_agent
pr: 228
branch: feat/011-corpus-judge-gate
ticket: null
title: "feat(011): corpus_judge — the invariant set and six two-channel checks on every corpus member's real run"
---

## Summary

Builds cluster 1 of `PLAN-judge-recoveries-on-real-runs.md`, which is WI-1 and WI-3 of ADR-003.
`make corpus_judge` runs the fixed bank's sixteen members through `corpus_pr_dst`'s own helpers,
evaluates the invariant set on each real run, and holds each run to six two-channel checks. The
target is in `DST_TARGETS` and is a step of the `pr-corpus` job.

**A workflow file changes:** `.github/workflows/dst-corpora.yml` gains one step.

Not in this pull request: WI-2, the two invariant rules, which another branch carries; and WI-4,
acceptance by named mutants, which a third session runs once both have merged.

## Changes

- refactor(011): WI-1 — the corpus bank states its step budget and each member's run once, and exports them
- feat(011): WI-3 — corpus_judge, the invariant set and six two-channel checks on every corpus member's real run

4 files changed.

| file | what |
|---|---|
| `scripts/dst/corpus_pr_dst.ail` | `bank_step_budget()` replaces the literal 12 at two calls; `run_seed_member` and `run_constructed_member` hold a member's label, starting world, run and program, and `build_seed` and `build_constructed` call them; `run_recording_at` takes a budget; `fixed_bank` and `store_root` are exported. No behaviour change |
| `scripts/dst/corpus_judge_dst.ail` | new: the gate |
| `Makefile` | the `corpus_judge` target, in `DST_TARGETS` and not in `DST_TIMED_TARGETS` |
| `.github/workflows/dst-corpora.yml` | one step, `make corpus_judge`, after `corpus_pr` in `pr-corpus`, with `if: ${{ !cancelled() }}` |

## Governing docs

- `.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`: D1, D3's
  gate half, D4, D5, D9, D10, rulings 13, 15 and 16
- `.agent/projects/011_improve_test_axises/PLAN-judge-recoveries-on-real-runs.md`: WI-1 and WI-3
- `.agent/projects/011_improve_test_axises/HANDOFF-build-the-corpus-judge-gate.md`
- `.agent/projects/011_improve_test_axises/evidence/judge-recoveries/baseline-59d5cbb9/README.md`
- `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`: D8,
  which the failure record answers to

## What the gate does

- **Runs the bank as `corpus_pr` does.** It imports the run helpers and names no hook id, world or
  program of its own. Its declared step budget is `bank_step_budget()`, the value those helpers
  pass to the driver. The retry budget is one below it; the decision budget is undeclared.
- **Bridges each result that carries a terminal summary** with `execution_of` (the starting
  world's clock, `NoReplay`, eight parameters) and calls `evaluate`.
- **Makes six checks on each run**, and prints one row per rule per run:

  | rule id | red when |
  |---|---|
  | `steps-not-contiguous` | `ProviderCallPrepared.step` in the trace is not 0, 1, 2, … |
  | `provider-calls-exceed-budget` | more of those records than the step budget |
  | `retry-at-budget-edge` | a `StreamErrorRetry` at a step where budget minus step is 1 or less |
  | `provider-calls-unbalanced` | those records and the provider interactions the run logged differ, either way |
  | `tool-dispatches-unbalanced` | `V2ToolDispatchStart` records and the tool interactions the run logged differ, either way |
  | `request-ordinals-not-contiguous` | `WorldRequest.ordinal` does not run +1 from the starting world's ordinal to the returned world's |

- **Shows each check can fire.** One constructed input per rule id that produces that id and no
  other, one for each direction of the two balances, and one on which all six are silent.
- **Carries two budget-edge controls**, scripted worlds under the bank's rig: a retryable provider
  error at step 0 of a budget of 2 is retried and the run ends on `stop`; at a budget of 1 it is
  not retried.
- **Refuses a green that saw nothing.** Red if a member has no terminal summary, if a budget rule
  was not evaluated, if a member's trace holds no prepared call or no request ordinal, or if no
  member retried or none dispatched a tool. Rule rows are printed before that verdict.
- **Prints 009 D8's record for a red member**, with the serialized program by reference to the
  artifact `corpus_pr` persisted. It writes nothing under `.ailang/dst-corpus`.

## Predicted outcome

- **`corpus_pr` is unchanged in output and in time.** Checked: six runs, two before the edit and
  four after, hash to the baseline's value with `duration_ms` masked, and no run after is slower
  than the tolerance.
- **Every pull request runs the gate.** Checked by the `pr-corpus` job on this pull request, which
  has the new step. It adds one compile of `session.ail` to that job.
- **`make dst` gains one passing target and no failure.** Checked: at the second commit the sweep
  exits 2 with the baseline's four red targets, and `corpus_judge` passes inside it.
- **A recovery defect of a kind ADR-003 D6 lists turns the rule it breaks red, by name.** Not
  checked here. That is WI-4, run once at the commit handed in by a session that built none of
  this.
- **When the two invariant rules merge, this gate evaluates them with no edit.** Every member
  should stay clean; a red one is a stop-and-report by the plan's rule 3.

## Test evidence

Run on 2026-10-06 in a worktree at `93fb002e` plus these two commits, AILANG v0.47.2. Heavy runs
took a lock shared with the session building the other cluster, so none ran beside another.

- [x] **`make corpus_pr`, alone, twice before WI-1's edit and twice after.** All four outputs, with
  `duration_ms` masked, hash to `e521255679e2…fa0453ce39`, the value in
  `baseline-59d5cbb9/corpus_pr.wire.sha256`. Whole-target time 81,000 and 56,000 ms before, 59,000
  and 61,000 ms after, against a tolerance of 93,150 ms (the slower run before plus 15 percent).
- [x] **`make corpus_pr`, alone, at the second commit.** The same hash; 56,000 ms.
- [x] **`make corpus_judge` passes.** Sixteen members bridged, each with no finding from the set
  and none from the six checks; 31 `✓` rows and no `✗`. Retries on seeds 9, 19, 32 and 141 at
  steps 1, 8, 1 and 1; ten members dispatch tools; seeds 19 and 244 make 12 calls on 12. About 45 s.
- [x] **Its sixteen `n=` and `ended=` values equal `corpus_pr`'s `CORPUSROW` values**, compared
  line for line.
- [x] **The failure record, seen once on real members.** A temporary edit declared a step budget
  of 11 and a retry budget of 0. Seeds 19 and 244 went red on `provider-calls-exceed-budget` and
  seeds 9, 19, 32 and 141 on `bounded-progress/retry-bound-exceeded`. Each got a record with all of
  D8's items; the recipe kept its output file (1,538 wire lines) and printed its path, the source
  revision and the toolchain version. With `.ailang/dst-corpus` moved aside the record said the
  artifact was absent and named `make corpus_pr`. The edit was undone and `git status` was clean.
- [x] **`make dst` at the second commit, `-j8`.** Exit 2 in 2,785 s, 53 targets. Its failure
  set is the baseline's: `driver_plus_compose`, `driver_plus_no_ops`, `ext_hook_scope` and
  `ext_hook_scope_selftest`, each on the baseline's cause, the registration-shape inventory
  failing to read `test_dummy`. `corpus_judge` passes inside it. Its `corpus_pr` leg hashes to
  the same value, in 63,000 ms.
- [x] **The `pr-corpus` job on this pull request, with the new step.** Green at `fa65aa5b` in
  6 min 36 s against its fifteen-minute limit: the `corpus_pr` step took 108 s and the
  `corpus_judge` step 76 s, and the job log shows the gate's sixteen members clean.

## Not done here, and one thing a reviewer should know

- **Acceptance (WI-4) is not run.** No source mutant was applied to `src/core`.
- **On a red run in CI the kept output file is not uploaded.** The job log carries every row and
  every failure record, which name the program artifacts; the wire itself stays on the runner.
  Ruling 15 asks for one step, so an upload step is not added here.
