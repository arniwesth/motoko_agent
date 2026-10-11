---
repo: arniwesth/motoko_agent
pr: 257
branch: arniwesth/005-w2-remove-persist-nudge
ticket: null
title: "refactor(core): the persist nudge leaves core (005 W2)"
---

## Summary

Removes the persist nudge from core: the step that sent a final answer back to the model when a
budget was set and the session had not attempted a `WriteFile`. This is workstream W2 of
`PLAN-finalize-policy-migration.md`, which implements 005 ADR-001 Amendment 1 (A5, accepted
2026-10-10): the nudge is deleted, not migrated, and no guard is built in its place.

After this, `classify_candidate` has no nudge arm, the wire event `persist_nudge` no longer
exists and the event vocabulary is `event-vocabulary/3`. The `nudges_used` counter is gone from
the loop state. The driver no longer reads `MOTOKO_PERSIST_RETRIES`, so it reads eleven
environment keys where it read twelve, and the host no longer passes the variable.

## Changes

- refactor(core): remove the persist-nudge policy (005 W2-2)
- refactor(core): remove the nudges_used counter (005 W2-3)
- refactor(core): drop the MOTOKO_PERSIST_RETRIES env read (005 W2-4)
- refactor(tui): stop passing MOTOKO_PERSIST_RETRIES (005 W2-5)
- docs(records): mark persist-nudge records superseded (005 W2-6)
- docs(anchors): re-baseline attribution anchors after W2 (005 W2-6 follow-up)

56 files changed.

W2-1 was a probe in a scratch tree and has no commit. W2-7 is the gate under *Test evidence* and
adds no change of its own.

**Thirteen of the files are evaluator paths** (`src/eval/journal/` and its `testdata/`), all in
W2-4's commit. Under 013 ADR-004 D5 that part is an evaluator change and should be reviewed as
one. The evaluator now serves eight environment values where it served nine, and its witness
expects eleven reads.

**The anchor re-baseline is the eight-file, four-profile form**, the one W1 used, not the
six-file form the note at `tools/predicate-anchors/anchors.sh` describes. The five clock anchors
in `src/core/session.ail` were re-measured at their new offsets; no clock site was added, removed
or re-routed. All four DST profiles are re-issued against the new table (`driver_only` 35 to 36,
`driver_plus_no_ops` 24 to 25, `driver_plus_compose` 16 to 17, `driver_plus_herdr` 5 to 6), and
the two literals in `scripts/dst/herdr_graded_dst.ail` that spell the herdr version move with it.
The six-file form was measured first and leaves `make driver_plus_herdr` and `make herdr_graded`
red on `[attribution-identity-stale]`.

**In 013 ADR-004 the two `MOTOKO_PERSIST_RETRIES` rows are removed by a numbered change, and
their text still stands in the tables.** Change 2 says to read D1's settings table and D3's
table of expected reads without them. That follows the section's own rule ("leaves that text as
written") and keeps every line coordinate other records cite. The operator has ruled that this
reading of "both rows go" stands.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`: Amendment 1
  (A5) is the decision. This branch adds the note under D4 that marks it superseded.
- `.agent/projects/005_harness_policy_boundary/PLAN-finalize-policy-migration.md`, W2: the work
  items. Not edited here.
- `.agent/projects/005_harness_policy_boundary/HANDOFF-write-persist-nudge-migration-plan.md`:
  marked superseded, "Do not write this plan".
- `.agent/projects/013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md`:
  Change 2, described above.

## Predicted outcome

- **No session behaves differently unless it set the budget.** The budget's default was `0`,
  which is off, and the plan's research found no `Makefile` target, CI job, profile or evaluation
  script that set it. A session that did set `MOTOKO_PERSIST_RETRIES` now finalizes where it
  would have been nudged: the host drops the variable and the runtime does not read it. Checked
  here by one live session on the `default` profile (below): one `done` event and no
  `persist_nudge`. The next ordinary session is the real check.
- **Every session makes one environment read fewer at start-up.** Recorded programs are one
  request shorter, and the pins that count them moved with the read: the depth canary's record
  counts are 122, 190 and 216, and the ledger-parity order strings lose one `WorldRequest`.
- **A resume across this merge is not refused for the prompt.** W2 does not touch `SYSTEM.md`,
  so the system prompt's digest does not change and W1's resume note does not apply here. Not
  measured: no session was resumed across the merge. The plan found that no stored journal holds
  a nudge count.
- **Old traces need the pinned runner.** A build at `event-vocabulary/3` refuses an
  `event-vocabulary/2` manifest with `ManifestVersionDrifted`. Version 2 is read by commit
  `da88a08801aac7fe154be19d57251b1cba8830e1`, the commit this branch is cut from. Nothing is
  built for the pin and no recorded trace is committed.
- **`make eval_matrix` stays red exactly as it is on `main`.** It exits 2 at `da88a088` on 61 of
  621 rows, and it exits 2 here on the same 61. The operator's reading of the gate is "no bad row
  beyond that baseline", and the two `join.tsv` files are byte-identical. The evaluation's
  protected manifest is not regenerated here and still refuses `main`; that is the evaluator's
  task (013 ADR-004 D5).
- **CI.** Every target CI runs was run here and passed. CI's own result was not waited for.

## Known leftovers

- **An unused import is still in place.** `src/core/session.ail:34` imports `toLower`, as it has
  since W1. Left by the same decision.
- **`make demo_dst`'s prompt plants a bug through a name that is gone.**
  `.agent/notes/DEMO-dst-self-test-prompt.md:83` and `:126` rewrite a line to use `r_persist`,
  which W2-4 deleted, so the planted line should no longer type-check. `:80` also says the
  function reads four environment variables; it reads three. Read, not run. The plan does not
  name this file.
- **The depth canary's ceilings are about 2.4 times the floor on AILANG v0.52.5.** They are
  76, 110 and 126, set as "floor + ~20%" on v0.33.0. W2-4 bisected the lowest passing ceilings at
  32, 41 and 52. This predates W2. Whether the fault the canary exists for still trips the
  ceilings is not measured.
- **`make eval_protected_selftest` exits 2, before and after this branch.** It fails on a parser
  cross-check for eight symbols in `dst_interaction.ail`, `ports.ail` and `test/stub_step.ail`.
  It generates its manifest from a pinned commit and does not read the working tree. Inside the
  matrix, `tools/eval_protected/selftest.py` exits 1 here and at `da88a088` alike.
- **Four ordinal pins that no run reaches.** `scripts/eval/test_candidate.py:1251`, `:1260`,
  `:1300` and `:1309` pin interaction positions. Their tests fail earlier at baseline, on the
  protected-manifest refusal, so nothing showed whether the positions moved with the read.
- **The key and the nudge are still named in text.** `tools/eval_protected/manifest-A.json` names
  `PersistNudge` and `should_inject_persist_nudge`. Comments record why a pin moved. Several
  plans and handoffs in 005, and one research note in 031, still call the migration a follow-on;
  W2-6 names two records and kept to them.
- **Nothing checks the herdr script's version literal** against the profile's version. It is
  moved by convention, and `anchors.sh` now says so.
- W3 (hybrid mode) is a later pull request. It starts from `main` after this one has merged.

## Test evidence

All of it ran in the branch's worktree at `32939758`, the last commit before this pull request's
record, on AILANG v0.52.5 (`7200786`), each command as `env -u AILANG_FS_SANDBOX <command>` and
one group at a time. The tree was clean after every group but the last: `make eval_matrix` leaves
`src/eval/journal/testdata/MATRIX.tsv` untracked, and it was moved out of the tree.

| Command | Exit | Result |
|---|---|---|
| `make check_core` | 0 | `src/core/ type-check: 60 passed, 0 failed`; 185 `OK` lines, no `FAIL`; `verify_native_path_guard` among them |
| `make test_coverage_selftest test_coverage` | 0 | `self-test: 0 failure(s)`; 73 files, 50 with tests, `611 of 616 passed, 5 skipped against a record` |
| `make smoke_parity` | 0 | two runs of the ten smokes, `diff -r` empty |
| `make dst` | 0 | 54 targets, `all targets passed`, 434 s wall at `-j8`, not a cold run; `corpus_pr` ran by itself as the sweep's timed phase, 15000 ms against a ceiling of 180000 ms |
| `make test` | 0 | `agents_md.ail` 12 passed, `parse_test.ail` 19 passed, 0 failed |
| `make verify_core verify_mutations verify_classify_check` | 0 | `16 contracts proven, 0 unstated, 1 blocked; 0 files failed, 49 bare`; `5 falsified, 0 unfalsified`; 18 unit tests OK; `17 contracts, register agrees` |
| `make new_contract_policy BASE=origin/main` | 0 | `no pure func added under src/core/ since origin/main` |
| `make verify_skills_tests verify_skills_refusal smoke_no_delegated_storm verify_profile_dir_agreement tui_context_limit dst_l2` | 0 | skills 62, 11 and 18 passed; `verify_skills_refusal: 51 passed, 0 failed`; four profiles `ohmy_pi=false`; `host and runtime agree on all 14 layouts`; 14 pass, 0 fail; 25 pass, 0 fail |
| `python3 -m pytest tools/code-graph/tests/test_event_subjects.py -q` | 0 | `25 passed` |
| `make discovery` | 0 | `driver_env_keys() re-derived from the driver's ports.env_get call sites (11 keys)` |
| `make strict_replay` | 0 | `✓ src/core/dst_replay.ail` |
| `make program_persistence` | 0 | `✓ src/core/dst_secrets.ail` |
| `make run_report` | 0 | `✓ src/core/dst_run_report.ail` |
| `make seeded_generator` | 0 | `seeded generator: all axes green` |
| `make driver_plus_compose` | 0 | `✓ src/core/dst_driver_plus_compose.ail` |
| `make herdr_graded` | 0 | `HERDR-GRADED: PASS`, `driver_plus_herdr/6 rests on it` |
| `make ledger_parity` | 0 | `ledger_parity wire gate PASS` |
| `make depth_canary` | 0 | `depth canary PASS`; 122, 190 and 216 records for seeds 7, 11 and 23 |
| `make eval_matrix`, run alone | **2** | same as `main`; see below |

`new_contract_policy` reads commits only. It ran with every change committed and `origin/main` at
`da88a088`, the branch's merge base. The nine targets from `discovery` to `depth_canary` are the
ones W2-1 probed; each ran as its own `make` after the sweep, which also runs them.

**`make eval_matrix` exits 2 and is read against the baseline.** The operator's decision: the
gate is "no new bad rows beyond the 61-row baseline", compared row for row against `join.tsv` from
`da88a088`.

```
eval_matrix: 621 rows: credited=420, equal=129, failed=28, inapplicable=11, missing=33
eval_matrix: suites 28, non-zero exit: scripts/eval/test_candidate.py=1, tools/eval_protected/selftest.py=1
```

Those two lines are the baseline's two lines. The two `join.tsv` files are byte-identical
(`sha256:5a6776e4…b255dd8`): 621 rows in the same order, no status differs, no row is in one file
only, and the 61 bad rows are the same 61. The baseline was measured by W2-1 in a detached
checkout of `da88a088`, the commit this branch is cut from.

**One live session.** Headless, from the worktree, on the `default` profile and that profile's own
model (`openrouter/meta/muse-spark-1.3-contributor`):

```
MOTOKO_CONFIG=default MOTOKO_HEADLESS=1 MOTOKO_JSONL_OUTPUT=1 ./scripts/run-agent.sh \
  "What is 17 + 25? Reply with the number only. Do not call any tool."
```

Exit 0 in 7 s. The session log has 34 events: one `done`, one `run_summary` with
`finish_reason: stop`, `steps_executed: 1` and one provider call, no tool call, no
`ext_solver_feedback`, no `dp7_verifier_rejected` and no `persist_nudge`. No line of the log names
`MOTOKO_PERSIST_RETRIES`. The nine extensions of the profile loaded. The `HERDR_*` variables were
unset for the run, so that it would not report agent state for the pane the gate ran in.

**Not run:**

- `make verify_ext`. Nothing under `src/core/ext` or `packages` changes.
- The TUI's full jest suite. One line of `src/tui/src/runtime-process.ts` changes. W2-5 ran the
  four suites that call `buildChildEnv` (40 tests) and `tsc --noEmit` at its commit; this gate
  ran `tui_context_limit` and `dst_l2`.
- `make demo_dst`, `make eval_protected_selftest` on its own and `protected.py check` on the
  evaluation manifest (see *Known leftovers*).
- A cold `make dst`, and a second run of the sweep or of `corpus_pr`.
- A resume across the merge, and a session inside the TUI or a herdr pane.
- CI on this pull request was not waited for.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
