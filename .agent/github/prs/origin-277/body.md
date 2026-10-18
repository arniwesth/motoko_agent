---
repo: arniwesth/motoko_agent
pr: 277
branch: arniwesth/034-w0-effect-disclosure
ticket: null
title: "feat(core): tool faults disclose whether their effect may have happened (034 Phase 0)"
---

## Summary

This is Phase 0 of 034 ADR-001 (`034/PLAN-001` workstream W0, tasks `034/PLAN-001/W0.1` to `034/PLAN-001/W0.7`). When a tool fails, the result the model sees now has a `fault` object. The object gives the fault's `kind` and says whether the tool's `effects` may have happened: `none` or `unknown`. Until now the model got `"error":true` and a message, and could not tell a refusal that changed nothing from a timeout, kill or write failure that may have done its work.

**This changes the model-facing wire for every faulted tool result (ADR D5's cost).** Every `ToolErrorResult`, and every faulted `BashExecResult` and `RunTestsResult`, now renders `"fault":{…}` straight after `"tool"`. A result that ran to its own exit is byte-identical to before. `exit_code` stays 1 on a faulted result. Every other reader of the result JSON reads by key (PLAN-001 *What is true*), so an extra key breaks none of them.

**After review.** Sol's review of `a490a8b9` found three faults, and `d3047dd1` fixes them. Search now runs `rg` read-only, so the `none` it discloses on a process error is true. **Search no longer applies the user's ripgrep config** (`RIPGREP_CONFIG_PATH`): it runs `rg … --no-config -e <pattern> -- <target>`. The unknown-tool refusal echoes at most 200 characters of the caller's tool name, so a long name can no longer push `fault` out of the capped message. And the mutation run's second survivor, Search's `rg` failure, had a false reason. It is now mutant m36, and it is killed.

## Changes

- test(034): record deterministic baseline before Phase 0 (034 W0.1)
- feat(core): tool faults carry a ToolFault with kind and effects (034 W0.2)
- feat(core): tool_result_item_to_json emits fault (034 W0.3)
- fix(core): BashExec description states what happens past the cap (034 W0.4)
- test(dst): add live fault disclosure witness rows a-p (034 W0.5)
- test(034): Phase 0 mutation run m01-m35 and survivors (034 W0.6)
- test(034): baseline after Phase 0 matches W0.1 row for row (034 W0.7)
- fix(core): contracts on tool_fault's 29 new pure funcs (new_contract_policy)
- fix(core): Search reads only, the unknown tool name is cut (#277 review)
- test(034): mutation follow-up at d3047dd1, m36-m39 all killed; s-rg was false
- test(034): baseline after the #277 review follow-up matches W0.1 (034 W0.7)

What each part does:

- **W0.2, the types.** `src/core/types.ail` gains `EffectDisclosure`, `FaultKind` and the `ToolFault` record. `ToolErrorResult` requires a fault. `BashExecResult` and `RunTestsResult` carry an optional one. The new `src/core/tool_fault.ail` is the one place for the keys, values, kind names and the two sentences. It also holds the two exhaustive mappings over `ProcessError` (ADR D2 as ruled). Every construction site in `tool_runtime.ail` states its disclosure.
- **W0.3, the renderer.** `tool_dispatch_adapter.ail` renders `fault` before every field whose size is not bounded, so the tool-message cap cannot cut it off. `dispatch_one_typed`'s defensive branch now reports `io_error`/`unknown`.
- **W0.4, the `BashExec` description.** It says what happens past the output cap or time limit. The description is not part of `system_prefix_digest`.
- **W0.5, live witnesses.** `make world_state` runs a new `fault_disclosure_witness` entry, which has 19 live rows: a to p, and q, r and s from the review.
- **W0.6, the mutation run.** 38 mutants were run at `019f1c6c` and 4 more at `d3047dd1`, and all were killed. One survivor is recorded, with its reason. A second, Search's `rg` failure, was recorded with a false reason. It is now mutant m36, a kill.
- **W0.7, the "after" baseline** and its comparison, measured at `c8ca2521` and again at `2ac0ff88`, after the review.
- **The contracts, `a490a8b9`.** CI's `new_contract_policy` refused the PR because the 29 new `pure func`s in `tool_fault.ail` had no contract. Each now carries an `ensures`. All 29 classify substantive, and `tools/verify_classify/contracts.register` is regenerated. The mappings' contracts state D2's safety direction: only `NotAllowed` and `NotFound` may disclose `none`.
- **The review follow-up, `d3047dd1`**, for Sol's review of `a490a8b9`:
  1. *[High] Search could report `effects: none` after changing state.* `rg` read `RIPGREP_CONFIG_PATH`, whose config can set `--pre=<program>`. The pattern was passed positionally, so a pattern such as `--pre=/tmp/x` was read as an option. `search_argv` now runs `rg -n --no-heading --color never --no-config -e <pattern> -- <target>`. That invocation only reads, so D2 row 4 (`none` for a read-only tool) holds as ruled. Witnesses: W0.5 row q (a pattern `--pre=<helper>` is found as text, and the helper does not run) and the inline test `t_search_argv_reads_only`.
  2. *[Medium] A long unknown tool name pushed `fault` out of the message.* `unknown_tool_refusal` echoes the name through `echoed_tool_name(name, 200)`: at most 200 characters, then `...[tool name cut]`. That is a new pure func with an `ensures`, classified substantive, and the register is regenerated. Witnesses: the adapter test `t_long_unknown_tool_keeps_fault` (a 102,400-character name through `tool_result_message`'s cap) and W0.5 row s (a 70,000-character name down the live path).
  3. *[Medium] The Search survivor's reason was false.* W0.5 row r searches an 11 MiB matching file. `rg` launches, its output passes the 10 MiB cap, and the message reads `output_limit`, `none`, `bytes` 10485760. Mutant m36 (that arm discloses `unknown`) is killed by row r. Its measured result replaces the survivor's reason in `mutants.tsv`, `mutate.py` and the README. m37 to m39 mutate the two fixes, and all three are killed.

The diff counts 253 files changed. Most are evidence files: the per-mutant run logs under `evidence/mutation-019f1c6c/runs/`, and the three baseline directories.

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md`
- `.agent/projects/034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md` (and `PLAN-001.dagr.json`; task addresses `034/PLAN-001/W0.1`, `034/PLAN-001/W0.2`, `034/PLAN-001/W0.3`, `034/PLAN-001/W0.4`, `034/PLAN-001/W0.5`, `034/PLAN-001/W0.6`, `034/PLAN-001/W0.7`)
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-3ae506cc/README.md` (before)
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-after-c8ca2521/README.md` (after, and the comparison)
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-after-2ac0ff88/README.md` (after the review follow-up, and the comparison)
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-019f1c6c/README.md`

## Predicted outcome

- In a live session, a faulted tool result reaches the model with `fault.kind` and `fault.effects`. A model can then tell "nothing changed, retry is safe" from "it may have run, check before you retry". How that is checked: W0.5's 19 live rows in `make world_state`, and W0.6's mutants.
- No deterministic baseline row moves except the ones the plan expected. That is checked and holds; see below.
- No model-in-the-loop run is a gate (ADR ruling 5), so this PR does not claim any change in model behaviour.

### Baselines, before and after

- Before: `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-3ae506cc/`, at the commit the branch was cut from.
- After: `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-after-c8ca2521/`, at `c8ca2521`. That is this branch before the W0.7 commit, which adds only that directory.
- After the review: `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-after-2ac0ff88/`, at `2ac0ff88`. That holds `a490a8b9` and the review follow-up, and is this branch before the commit that adds only that directory.

Every changed row at `2ac0ff88`, with its cause:

| what changed | cause |
|---|---|
| `world_state` gains `fault_disclosure_witness` rows a to s, all `✓` | W0.5, and the review's q, r and s. Expected |
| `test_coverage`: 596 tests in 49 files → 657 tests in 51 files, and 5 → 13 skipped, all against a record. `tool_fault.ail` passes 36/43 (7 skipped), `tool_dispatch_adapter.ail` 15/15, `tool_runtime.ail` 18/21 (3 skipped) | W0.2 and W0.3; `a490a8b9`'s 29 contract properties, 7 of them over an ADT parameter that has no generator; `d3047dd1`'s 2 tests and `echoed_tool_name`'s 2 properties, 1 skipped as out of contract. Expected |
| `profile_definition` and `driver_only`'s ABI-pin check scans 569 tracked `.ail` files, not 568. It passes in both runs | W0.2's new `src/core/tool_fault.ail`. Only a log count changed, not a status |
| `eval_matrix`: none. Run 2 prints `VERDICT: IDENTICAL` over 619 rows and 28 suites, as at `c8ca2521`. Run 1 printed `DIFFERS` on one suite's exit code, with all 619 rows the same: 1 of `scripts/eval/test_mem_guard.py`'s 55 tests rejected a late memory sample (`monitor_gap`) at a load average of up to 17.6 | `scripts/eval` and `src/eval` are unchanged since the base. The suite passes 55/55 alone three times and in run 2. A load flake |
| DST failed targets: none, both runs empty. `corpus_pr`'s masked wire hash is identical | |

Timing, load, temp names and the revision line also differ, as the after README lists.

## Test evidence

W0.7 again, after the review, all at `2ac0ff88`, uid 1001 (`id -u` → `1001`), AILANG v0.52.5, run one at a time:

| command | exit | last lines |
|---|---|---|
| `REV=2ac0ff88 WT=<this worktree> run_baseline.sh` → `env -u AILANG_FS_SANDBOX make dst` | 0 | `1508s wall, -j8, load 17.55 19.17 13.72` … `all targets passed` |
| the same script → `env -u AILANG_FS_SANDBOX make eval_matrix --logs` (run 1) | 2, as at the base | `make: *** [Makefile:3529: eval_matrix] Error 1`. 3 suites exit 1: the base's 2 and `scripts/eval/test_mem_guard.py` |
| `compare_matrix.py baseline-3ae506cc <run 1>` | 1 | `rows whose observation differs: 0` … `VERDICT: DIFFERS`, on `test_mem_guard.py`'s exit alone |
| `python3 -m pytest -q scripts/eval/test_mem_guard.py`, alone, three times | 0, 0, 0 | `55 passed` |
| `env -u AILANG_FS_SANDBOX make eval_matrix --logs` (run 2, alone) | 2, as at the base | `make: *** [Makefile:3529: eval_matrix] Error 1`. The base's 2 suites exit 1 |
| `compare_matrix.py baseline-3ae506cc <run 2>` | 0 | `VERDICT: IDENTICAL` |
| `diff dst-failed.txt` and the `corpus_pr` hash diff | 0, 0 | no output |
| `make check_core verify_core verify_mutations test_coverage verify_classify_check new_contract_policy` | 0 | `src/core/ type-check: 60 passed, 0 failed` … `verify_mutations: 5 falsified, 0 unfalsified` … `test_coverage: every file carrying inline tests was run; 644 of 657 passed, 13 skipped against a record` … `new_contract_policy: 30 in-scope new pure func declarations, all justified` |
| `env -u AILANG_FS_SANDBOX make world_state` | 0 | `fault_disclosure_witness PASS`, rows a to s; no `NOT EVALUATED` line |
| `make compose_live_exec` | 0 | `compose_live_exec PASS` |
| `make verify_native_path_guard` | 0 | `OK: ReadFile inside the workdir still works` |

The review follow-up's own runs, at `d3047dd1`:

| command | exit | last lines |
|---|---|---|
| `mutate.py --followup --apply-check` | 0 | m36, m37, m38, m39 and K0f `compiles` |
| `mutate.py --followup` (`meta-followup.txt`: uid 1001) | 0 | `m36 KILL`, `m37 KILL`, `m38 KILL`, `m39 KILL`, `K0f PASS`, `F-restored PASS 60 tests ran, 0 red; survival rows all 13 green` |
| `make verify_classify`, then `make verify_classify_check` | 0, 0 | `register agrees (44 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified)` |

Under m37, the old argv, row q prints `helper ran: true`: the review's first finding, reproduced live. Under m39, the uncut name fills the 65,536-character message and `fault` is gone: the second.

W0.7 before the review, all at `c8ca2521`, uid 1001 (`id -u` → `1001`), AILANG v0.52.5, run one at a time:

| command | exit | last lines |
|---|---|---|
| `REV=c8ca2521 WT=<this worktree> run_baseline.sh` → `env -u AILANG_FS_SANDBOX make dst` | 0 | `852s wall, -j8` … `all targets passed` |
| the same script → `env -u AILANG_FS_SANDBOX make eval_matrix --logs` | 2, as at the base | `make: *** [Makefile:3529: eval_matrix] Error 1`. The same 2 suites exit 1 as at the base: `tools/eval_protected/selftest.py` and `scripts/eval/test_candidate.py` |
| `compare_matrix.py baseline-3ae506cc baseline-after` | 0 | `VERDICT: IDENTICAL` |
| `diff dst-failed.txt` and the `corpus_pr` hash diff | 0, 0 | no output |
| `make compose_live_exec` | 0 | `compose_live_exec PASS` |
| `make verify_native_path_guard` | 0 | `OK: ReadFile inside the workdir still works` |
| `cd src/tui && bun run test` | 1, as at the base | 5 suites fail to load, the same 5 as at `3ae506cc` (two runs there). 460 of 460 tests pass |

About the TUI run: `bun install --frozen-lockfile` was run first, because the worktree had no `node_modules`. The first full run at the head also failed 2 tests in `runtime-process.wake.test.ts` (`ENOENT` on a `/tmp/wake-protocol-*` journal). The same suite passed 27/27 in six runs alone, three at the head and three at the base, and passed in two more full runs at the head. It is recorded as a load flake, and `src/tui` is unchanged by this PR.

The earlier tasks' gates are in their commits:

- W0.2, W0.3, W0.4: `make check_core` exit 0, with 60 passed and 0 failed.
- W0.2, W0.3: `make test_coverage` exit 0.
- W0.5: `env -u AILANG_FS_SANDBOX make world_state` exit 0 as uid 1001 (`id -u` → `1001`), with no `NOT EVALUATED` line.
- W0.6: `mutate.py` as uid 1001 (`meta.txt`: `uid 1001`). All 38 mutants were killed. Then `make world_state` exit 0 and `make check_core` exit 0.

Not run, or not run as specified:

- `make compose_live_exec` and `make verify_native_path_guard` were run without the `env -u AILANG_FS_SANDBOX` wrapper, at both `c8ca2521` and `2ac0ff88`. At `c8ca2521` the session's permission layer refused it. They ran with the environment as it was.
- `--no-config` is witnessed by `t_search_argv_reads_only` and mutant m38, not by a live row with `RIPGREP_CONFIG_PATH` set: the probe has no way to set an environment variable for the `rg` it launches. The review's config repro was rerun by hand in a shell. With a config holding `--pre=<helper>`, the new argv does not run the helper and the old one does.
- `cd src/tui && bun run test` was not run again at `2ac0ff88`: `src/tui` is unchanged since `3ae506cc`.
- `src/tui` still runs `rg` with the pattern passed positionally, in `env-server.ts`, `scratchpad/loopback.ts` and `ohMyPi/dispatcher.ts`. Those paths render no `fault`, so they make no `effects` claim. They are outside W0 and are not changed here.
- W0.5's root branch, where rows e and f print `NOT EVALUATED`, was not run as root, because there is no root in this container.
- No model-in-the-loop run was made.
- CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
