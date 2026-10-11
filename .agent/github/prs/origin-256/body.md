---
repo: arniwesth/motoko_agent
pr: 256
branch: arniwesth/005-w1-remove-dp7-verifier
ticket: null
title: "refactor(core): the DP7 pre-finalize verifier leaves core (005 W1)"
---

## Summary

Removes the DP7 verifier from core: the step that ran a profile's verification command on a final
answer and sent the answer back when the command failed. This is workstream W1 of
`PLAN-finalize-policy-migration.md`, which implements 005 ADR-001 Amendment 1 (accepted
2026-10-10): core does not decide whether a final answer is good enough, and nothing replaces the
verifier. The amendment records the two sessions that could not finish because of it.

After this, `classify_candidate` has four stages (pending, waits, completion, finalize), the wire
event `dp7_verifier_rejected` no longer exists, and the event vocabulary is `event-vocabulary/2`.

## Changes

- test(dst): delete the tests that test only DP7 (005 WI-7)
- test(dst): corpus control moves to solver-feedback (005 WI-8)
- refactor(core): classify_candidate loses its verification stages (005 WI-1)
- refactor(core): delete the DP7 verifier (005 WI-2)
- refactor(core): neutral name for the approved candidate (005 WI-3)
- refactor(core): wire event goes, vocabulary to v2 (005 WI-4)
- docs(system): prompt states the runtime does not check (005 WI-5)
- docs(records): mark DP7 records superseded, re-baseline anchors (005 WI-9)

45 files changed.

The tests go first (WI-7, WI-8), so that every later commit removes code from a tree whose suites
are green before and after. WI-6 is withdrawn in the plan and has no commit. WI-10 is the gate
under *Test evidence* and adds no change of its own.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`, Amendment 1:
  the decision. Not edited here.
- `.agent/projects/005_harness_policy_boundary/PLAN-finalize-policy-migration.md`, W1: the work
  items and their order. Not edited here.
- `.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`: ruling 19,
  the corpus gate's control moves from `verifier-rejection` to `solver-feedback`.
- `.agent/projects/013_core_architecture_for_dst/ADR-002-park-and-wake.md`: D2's stage 2 and the
  DP7 cross-product cases marked superseded.
- `.agent/projects/013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md`: Change
  1, the `rt.verification` row of the T0 settings is no longer needed.
- `.agent/projects/028_verified_runtime_closing_the_loop/ADR-001-fail-closed-verification-everywhere.md`
  and `.agent/projects/028_verified_runtime_closing_the_loop/PLAN-001-closing-the-loop.md`: the
  finalization item marked superseded.
- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`:
  Amendment 7, for "and deterministic verification" in D4 and "DP7" in freeze evidence item 6.

## Predicted outcome

- **Core no longer sends a final answer back on its own.** The only thing that returns a final
  answer to the model is an extension judge answering `ContinueWithFeedback`. Checked here by one
  live session on the `default` profile (below): one `done` event, no `dp7_verifier_rejected`.
  The next ordinary session is the real check.
- **A resume across this merge is refused unless forced.** WI-5 edits one sentence of
  `SYSTEM.md`, which changes the system prompt's digest. A session started before the merge and
  resumed after it under the same profile is refused as `Prompt` unless the resume is forced
  (`src/core/journal.ail:1807-1808`). That is the journal working as designed. Not measured here:
  no session was resumed across the edit.
- **A profile's `verification` block is read and then ignored.** A profile that still sets
  `verification.enabled: true` starts as usual and nothing is verified. All sixteen tracked
  profiles carry an empty block (#251). What the host should do with a config entry it does not
  use is left to its own pull request (the plan, WI-6).
- **Old traces need the pinned runner.** A build at `event-vocabulary/2` refuses a
  `event-vocabulary/1` manifest with `ManifestVersionDrifted`. Version 1 is read by commit
  `86f2b8176bfc33cc186b1e1007acefd9e04266cc`, the commit this branch is cut from, or any later
  commit that still has it. Nothing is built for the pin and no recorded trace is committed.
- **The evaluation's protected manifest drifts further.** `session.ail`'s import region is a
  protected span of `tools/eval_protected/manifest-A.json`, and WI-2 changes it. The manifest
  already refuses `main` and is not edited here; regenerating it is the evaluator's task (013
  ADR-004 D5).
- **CI.** Every target CI runs was run here and passed, and so were three things no CI job runs:
  `make dst` as a whole, `make test` and the code-graph test file. CI's own result was not waited
  for.

## Known leftovers

- **An unused import, left by decision.** `src/core/session.ail:34` still imports `toLower`.
  WI-2 deleted its only caller. It stays with `ProcessError` and `ProcessOutput` (`:37`), which
  were unused before: the plan names only `exec` and `toString` for removal.
- **WI-9's re-baseline is wider than the plan words it, and the operator's call on that is
  pending.** The plan says six files and three DST profiles. The branch changes eight files and
  re-issues four profiles: it adds `src/core/dst_driver_plus_herdr.ail` (v4 to v5) and the two
  literals in `scripts/dst/herdr_graded_dst.ail` that spell that version. WI-9's delegate measured
  the six-file form first: `make driver_plus_herdr` and `make herdr_graded` both exited 2 on
  `[attribution-identity-stale]`, because that profile pins the attribution table like the other
  three (`DST_KNOWN_RED` is empty). The gate below ran on the eight-file form as committed. If the
  six-file form is wanted exactly, revert the hunks in those two files and the herdr sentences in
  `tools/predicate-anchors/anchors.sh`; both targets are then red until the profile is re-issued.
- **Comments still say DP7** in about twenty files: the profile re-issue notes, `phase_vocab`,
  two in `session.ail`, two in the ABI's `types.ail`, two in the `Makefile` and others. No code
  names it. The one data file that does is the evaluation manifest, above.
- W2 (the persist nudge) and W3 (hybrid mode) are later pull requests. Each starts from `main`
  after the one before it has merged.

## Test evidence

All of it ran in the branch's worktree at `8d3a4ee0`, the last commit before this pull request's
record, on AILANG v0.52.5, each command as `env -u AILANG_FS_SANDBOX make <targets>` and one group
at a time.

| Command | Exit | Result |
|---|---|---|
| `make check_core` | 0 | `src/core/ type-check: 60 passed, 0 failed`; all fifteen prerequisites passed, `verify_native_path_guard` among them |
| `make test_coverage_selftest test_coverage` | 0 | `self-test: 0 failure(s)`; 73 files, 50 with tests, `617 of 622 passed, 5 skipped against a record` |
| `make smoke_parity` | 0 | two runs of the smokes, `diff -r` empty |
| `make dst` | 0 | 54 targets, `all targets passed`, 1090 s wall at `-j8`, cold; `corpus_pr` ran by itself as the sweep's timed phase |
| `make test` | 0 | `agents_md.ail` 12 passed, `parse_test.ail` 19 passed, 0 failed |
| `make verify_core verify_mutations verify_classify_check` | 0 | `16 contracts proven, 0 unstated, 1 blocked; 0 files failed, 49 bare`; `5 falsified, 0 unfalsified`; 18 unit tests OK; `17 contracts, register agrees` |
| `make new_contract_policy BASE=origin/main` | 0 | `0 in-scope new pure func declarations, all justified; 1 more out of scope, reachable only from a tests block` |
| `make verify_skills_tests verify_skills_refusal smoke_no_delegated_storm verify_profile_dir_agreement tui_context_limit dst_l2` | 0 | skills 62, 11 and 18 passed; `verify_skills_refusal: 51 passed, 0 failed`; four profiles `ohmy_pi=false`; `host and runtime agree on all 14 layouts`; 14 pass, 0 fail; 25 pass, 0 fail |
| `python3 -m pytest tools/code-graph/tests/test_event_subjects.py -q` | 0 | `25 passed` |

`new_contract_policy` reads commits only. It ran with every change committed and `origin/main` at
`86f2b817`, the branch's merge base.

**One live session.** Headless, from the worktree, on the `default` profile and that profile's own
model (`openrouter/meta/muse-spark-1.3-contributor`):

```
MOTOKO_CONFIG=default MOTOKO_HEADLESS=1 MOTOKO_JSONL_OUTPUT=1 ./scripts/run-agent.sh \
  "What is 17 + 25? Reply with the number only. Do not call any tool."
```

Exit 0 in 11 s. The session log has 43 events: one `done`, one `run_summary` with
`finish_reason: stop`, `steps_executed: 1` and one provider call, no tool call, no
`ext_solver_feedback`, and no `dp7_verifier_rejected` (no line of the log or of the JSONL wire
contains `dp7`). The nine extensions of the profile loaded. The `HERDR_*` variables were unset for
the run, so that it would not report agent state for the pane the gate ran in; the herdr extension
loaded with no herdr environment to act on.

**Not run:**

- `make eval_matrix`. It is not in W1's gate; the plan puts it in W2's and W3's.
- `make verify_ext`. Nothing under `src/core/ext` or `packages` changes.
- The TUI's full jest suite. No file under `src/tui` changes; `tui_context_limit` and `dst_l2`
  ran.
- `protected.py check` on the evaluation manifest, which refuses `main` already (see above).
- A resume across the `SYSTEM.md` edit, and a session inside the TUI or a herdr pane.
- CI on this pull request was not waited for.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
