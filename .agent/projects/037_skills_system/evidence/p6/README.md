# 037 P6 — evidence index

Evidence for PLAN-001 §5 P6: the repair (`ailang_tools` named in the four DST profile
lists), then the re-pin (`skills` in the four omitted lists, the two inventory fixtures,
and `declared_vs_performed`'s arm pairs and counts). Produced on 2026-10-05 in
`/workspaces/motoko_agent-skills` on `feat/skills-extension`, with AILANG v0.47.2. P6
started at `0f4724de`. The repair is `c708d2cc` and the re-pin is `7e6f6ab6`; the commit
after them adds this folder only.

## The result

- **No gate is newly red against the P0 baseline.** Of ADR A7's seventeen, thirteen exit 0
  as before, `declared_vs_performed` goes from red to green, and three stay red:
  `ext_hook_scope`, `driver_plus_no_ops` and `driver_plus_compose`.
- **None of the three P5 failures names `skills` any more.** `declared_vs_performed` is
  green. The two profile gates pass the check they failed on (every resolved extension is
  installed or omitted by name) and stop at the guard's next check, on `test_dummy`.
- **`driver_plus_no_ops` and `driver_plus_compose` are not green, and P6 cannot make them
  green inside its scope.** What stops them is `test_dummy`'s registration, which builds
  its capability list with an expression since `3159797d` (2026-10-01, before the
  baseline). It is the finding `ext_hook_scope` is red on in the baseline. The baseline's
  failure on `ailang_tools` fired first and hid it. See "The failure behind the failure".
- `driver_plus_herdr` is green at both commits, as in the baseline. `DST_KNOWN_RED` is
  untouched.

## What moved (`GATES.tsv`, `gates/`)

| Pin | Before P6 | After the repair | After the re-pin |
|---|---|---|---|
| `driver_only` version; extensions named | 32; 5 | 33; 6 | 34; 7 |
| `driver_plus_no_ops` version; omitted | 21; 14 | 22; 15 | 23; 16 |
| `driver_plus_compose` version; omitted | 13; 17 | 14; 18 | 15; 19 |
| `driver_plus_herdr` version; omitted | 2; 17 | 3; 18 | 4; 19 |
| `herdr_graded_dst.ail`: omitted count; `extension_profile` | 17; `/2` | 18; `/3` | 19; `/4` |
| `ext_ambient_inventory` fixture: extensions; package dirs | 18; 18 | | 20; 20 |
| `ext_hook_scope` fixture: extensions; atoms | 18; 45 over 18 | | 20; 48 over 20 |
| `ext_hook_scope` fixture: `hook_port_mediated` | 6 names | | 7, `skills` added |
| `declared_vs_performed.ail`: arm pairs | 18 | | 20 |
| `run_declared_vs_performed.sh`: absorption Env; FS; Process | 16; 13; 3 | | 18; 15; 3 |

`run_gates.sh` ran each gate as `make <gate>` from the worktree root, one at a time, with
the eleven credential variables removed, at each of the two commits (`gates/repair/`,
`gates/repin/`). Each log ends in `exit=<code>`; `HEAD.txt` is the commit and `STATUS.txt`
is `git status --short` when the run began (this folder, untracked, and nothing else).
After A7's seventeen and `verify_skills_refusal` it runs five targets A7 does not list:
the two inventory self-tests whose fixtures P6 moves, `herdr_graded`, and the CI targets
`verify_core` and `verify_classify_check`.

`compare_logs.py` compares two log folders line by line after dropping colour codes,
durations, the pane id, commit hashes, the lock-warning lines and the `exit=` line. Its
output for P5 against each commit, and the repair against the re-pin, is in
`gates/COMPARE_*.txt`. Read with it:

- Thirteen logs are identical to P5's at both commits.
- `driver_only`, `driver_plus_herdr` and `herdr_graded` differ only in the version and
  the count lines.
- `test_coverage` differs in its timing line.
- `declared_vs_performed`, the two profile gates and the two self-tests differ as the
  sections below describe.

## The failure behind the failure (`baseline_export/b2_atom_enumeration.log`)

Both profile guards (`tools/profile_definition/check_no_op_profile.py`,
`check_compose_profile.py`) check the partition first and then call
`hook_scope_atoms()`, which enumerates every extension's registered atoms and fails closed
if any registration is not a literal `{ config, caps }`.

- **At the baseline** the partition check failed on `ailang_tools` and the guard exited.
- **At the repair** it failed on `['skills']` alone.
- **At the re-pin** it passes, and the next call fails:

  ```
  FAIL: B2 reads 'test_dummy's registration as None, not `config-caps` (ABI 8.0); its atom
  count cannot be enumerated, so the denominator for it is UNKNOWN rather than eight.
  ```

- **That call fails the same way on the baseline tree.** `baseline_export/` holds runs on
  an export of `501cd879` (`git archive` of `src`, `packages`, `scripts`, `tools`, the
  `Makefile` and the root manifest and lock, in a directory outside any repository and
  outside `/tmp`, which the inventory tool refuses; deleted afterwards).
  `b2_atom_enumeration.log` is `hook_scope_atoms()` called there directly: the same
  message, exit 1.
- **Nothing it reads changed since.** `git diff 501cd879 HEAD` is empty for
  `tools/profile_definition`, the two inventory tools and `packages/motoko-ext-test-dummy`.

So the gates did not gain a failure. They show one they had and could not reach.
`ext_hook_scope` reports the same registration in the baseline (`pass 18 of 19; fail 1`)
and here (`pass 19 of 20; fail 1`).

Making the two gates green means changing `test_dummy`'s registration or how the guards
treat it. Both are outside P6's brief.

## `declared_vs_performed` (`gates/repin/declared_vs_performed.log`)

Red in the baseline, green at the re-pin: 137 passed, 0 failed.

- **It had not run to its end since `ailang_tools` joined the registry** (`140dde9e`,
  2026-09-28). The member-for-member row was red, and the differential loop then exited
  at the missing `reg_ailang_tools` arm: the baseline's log stops after `microrag`, the
  extension before it in registry order.
- **Both new subjects are CONFOUNDED in both regimes.** Each registration reads `Env` and
  then a file, so the capability trap cannot see past it. That is the result eight other
  extensions already have, and the gate's assertion is that none is BLOCKING. MEASURED 10
  of 20, CONFOUNDED 10 of 20.
- **The absorption pins were measured, not copied from a failure.** With the runner's own
  `grep`, before the pins were written: 18 registration rows (20 − 3 rowless + 1), `Env`
  admitted by 18, `FS` by 15, `Process` by 3. Both new registrations declare
  `! {Env, FS}`, so `Env` and `FS` each move by 2 and `Process` does not move.
- Everything the runner checks after that loop passed on its first run since
  2026-09-28. No other pin in it had drifted.

## The two inventory self-tests (`selftest_residue.txt`, `gates/head_before/`)

Neither is in A7 and neither was recorded at P0, so P6 measured their baseline on the
export.

| | Baseline, `501cd879` | Before P6, `0f4724de` | The repair | The re-pin |
|---|---|---|---|---|
| `ext_ambient_inventory_selftest` | 1 failure: 18 pinned, 19 derived | 1 failure: 18, 20 | the same | **0 failures** |
| `ext_hook_scope_selftest` | 5 failures | 5 failures | the same | 4 failures |

`selftest_residue.py` reduces each failing line of the hook-scope self-test to the
extensions on which the pin and the tool disagree. At the re-pin the four that remain
disagree on `test_dummy` and on nothing else: the pins say `config-caps`, `pass`, 4 atoms
and HOOK-PORT-MEDIATED, and the tool derives head `None`, `fail`, no atom count and
HOOK-UNRESOLVED. Before P6 three of those lines also listed `skills`, and the count line
said 20 against 18.

P6 did not move the `test_dummy` pins. The self-test's own message for a flipped shape
says not to re-pin until the cause is known; the cause is a change to the package, and
whether it stands is not 037's decision.

The first run on the export printed ten more failures (`no-cached-interface`): the
export had no compile cache yet. That log is kept as
`baseline_export/ext_ambient_inventory_selftest.cold_cache.log`. The second run, with
the cache the first one built, is the one in the table.

## The reasons (`src/core/dst_driver_*.ail`)

Each of the two extensions has its own entry and its own reason in each profile, written
as a literal in the list. Neither joins the lists that share `barrier_reason()`, whose
text counts the extensions that share it.

- **`ailang_tools`**, measured at `0f4724de`: AMBIENT, 6 ambient sources, 0 `ExtPorts`
  field calls; hook scope HOOK-UNRESOLVED with one registration-only source; one atom, a
  `ToolProvider`, whose `write_ail` and `edit_ail` are `! {FS, Process}` through `std/fs`
  and `std/process`. The effects are the hook's own and leave outside `ctx.ports`.
- **`skills`**, measured at `c708d2cc`: AMBIENT, 5 ambient sources, 1 `ExtPorts` field
  call; hook scope HOOK-PORT-MEDIATED with all five sources registration-only; the one
  hook effect is `ctx.ports.file_read` at `register.ail:331`; two atoms, `DescribeTools`
  and a `ToolProvider`. The reason then gives P1's numbers: loaded in the first response
  in 88% to 100% of sessions per model (261 of 270, seven models); followed in 53 of 54;
  reloaded 0 times under the structural compactor and once per run under `compaction_ai`;
  a 16,000-char index accepted by 7 of 7 provider families.

## Mutation check (`mutants.tsv`, `mutate_p6.sh`, `mutants/`)

Four runs, four killed. Each is one change to a tracked file, restored afterwards.

| | Change | Run | Seen |
|---|---|---|---|
| m1 | absorption pins back to 16 and 13 | `make declared_vs_performed` | 135 passed, 2 failed: the `Env` row and the `FS` row |
| m2 | `skills` atoms pinned at 3 | `make ext_hook_scope_selftest` | the atom row reports 3 pinned, 2 derived |
| m3a | `driver_plus_no_ops` omitted count 15 | `ailang test` on the module | 6 of 7; the partition test fails |
| m3b | the same | `make test_coverage` | red, naming the module and the test |

m3 is not run through `make driver_plus_no_ops`. That recipe runs the module's tests
last, and at this commit the guard before them stops on `test_dummy`, so the target does
not reach them. `test_coverage` runs them.

## The other readers of a profile version (`gates/consumers/`, `sweep/`)

Four `src/core` modules changed version twice, and scripts outside A7's list import
them. Thirteen such targets were run one at a time at `7e6f6ab6`, and all exit 0:
`corpus_rotating`, `discovery`, `execution_program`, `seeded_generator`, `latency_pair`,
`park_wake`, `run_report`, `strict_replay`, `program_persistence`, `journal_resume`,
`park_resume`, `world_framed_wire` and `depth_canary`. `corpus_pr` and `terminal_trace`
passed inside the sweep below; `corpus_pr`'s artifacts carry `manifest: driver_only/34`.

**The whole sweep was started and stopped.** `make dst DST_JOBS=1` ran for 22 minutes
and was in `smoke_parity`, the fifth of its 52 targets: here every smoke script compiles
from scratch (`CACHE_WRITE_FAILED ... ARTIFACT_TOO_LARGE` on `src/core/session`). P6
stopped it and ran the importers above instead. `sweep/partial_make_dst.log` is what it
wrote: `corpus_pr`, `test_coverage` (517 of 522 passed, 5 skipped),
`declared_vs_performed` (137 passed, 0 failed) and `terminal_trace` (PASS) completed.

**Not run at all**, twenty sweep targets that import none of the four modules:
`smoke_parity` (interrupted), `smoke_driver`, `world_state`, `event_vocabulary`,
`phase_c_l1`, `recorded_stream`, `invariants`, `compaction_dst`, `fault_catalogue`,
`stream_parity`, `test_coverage_selftest`, `attribution_table`, `compose_live_exec`,
`ledger_parity`, `dst_seeded`, `hook_guard`, `dst_l2`, `predicate_anchors`,
`driver_leaf_inventory` and `driver_leaf_inventory_selftest`. Also not run:
`make eval_matrix`, which runs the `src/eval/journal` suites that import `driver_only`.
Its recipe gives it 25 to 40 minutes and a memory rule; those modules read the version
through `driver_only_version()` and no file under `src/eval` or `scripts/eval` holds a
profile version as a literal.

## Notes

- No model or network service was called and no file here holds a credential.
- `scripts/dst/herdr_graded_dst.ail` is the one file changed outside the four profile
  modules, the two fixtures and the two `declared_vs_performed` files. It carries the
  herdr profile's omitted count, which would have turned `driver_plus_herdr` red, and the
  `extension_profile` literal and PASS line, which followed the version at `eba309c8`.
- The default profile, every package and `DST_KNOWN_RED` are unchanged.
