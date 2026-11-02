---
repo: arniwesth/motoko_agent
pr: 305
branch: arniwesth/041-w6-scripted-carrier
ticket: null
title: "041 W6: scripted carrier, expiry and projection"
---

## Summary

`ToolInvocation` gains `process: Option[ResolvedProcess]`, so a `Limits` program's process tools expire against the resolved limit in the scripted world, for main dispatch and for extension effects. Until W10, the live arm refuses `ExplicitMs` before dispatch and runs nothing. Nothing activates: no writer produces a `Limits` program, and the C2 guard stays green.

## Changes

- **Carrier.** `Some` only for `BashExec` and `RunTests` in `Limits` mode, `None` for every other tool and all of `Legacy`. It comes only from `resolve_process_limit`.
- **Scripted expiry.** The deadline check in `scripted_tool_outcome` becomes `process_deadline_expires`, with the order unchanged, and `ToolDeadlineExceeded.timeout_ms` carries D4's display value.
- **`tool_phase`, below `:499`.** It resolves, builds the carrier and sets `timeout_ms` by `projected_timeout_ms`. The env read stays once per dispatch in both modes.
- **`session.ail`.** The extension invocation takes the carrier on its existing lines and does not read `timeout_secs`. `timeout_ms: 0` stays.
- **Live arm.** `live_tool_outcome` given `ExplicitMs` returns `ToolFailed` with code `process_limit_unavailable`, `after_dispatch: false`, and runs nothing. `SessionDefault` stays a plain `exec`.
- **New helpers in `process_limits.ail`:** `is_process_tool`, `dispatch_resolution`, `extension_tool_process`, `deadline_display_ms`, `needs_process_primitive`.
- **Register.** `contracts.register` gains two pins and the totals line, and nothing else.

### One thing the plan does not ask for

An invalid request in a `Limits` program does not reach the port. W7 owns this path, but D7 says it never launches, and handing it to the port with no carrier would run the command. So W6 refuses with `process_request_invalid`. It still emits Start and Complete, because moving those is above `:499` and is W7's stated change. W7 replaces this arm.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`, W6
- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md`, D4 and D7

## Predicted outcome

### Matrix rows, predicted before the run

`evidence/W6/predict_matrix.sh` ran at `42b789f8` and is committed in `6804942f`, ahead of any `make eval_matrix`:

- **Predicted: no row moves.**
- **Cause:** two protected findings are new, `ToolInvocation` and `live_tool_outcome`. They sit behind the first finding those rows already report (`changed:<imports:1>`).

**Observed at `d066e961` against `df14e9cb`: 619 rows each, 0 differ in any field but the commit.** Later commits changed `tool_phase`, `process_limits` and the register, so the measured run is at the final code and not the commit the prediction ran at.

### Rows left red under R11

33 failed and 33 missing, all red at base too: `evidence/W6/matrix_rows_left_red.txt`. `credited=418 equal=124 failed=33 inapplicable=11 missing=33` on both sides. `manifest-A`, `tools/eval_protected/`, `scripts/eval/` and `MATRIX.expected.tsv` are untouched. These rows stay red until the operator directs the regeneration after W12.

The plan's list of protected symbols W6 moves needs one correction: `live_tool_outcome` moves here, not first at W10, because the refusal is in it. `scripted_tool_outcome` and `session.ail`'s imports were findings at base already.

### Line references that moved

| Plan says | At `df14e9cb` | Responsibility |
|---|---|---|
| `ports.ail:675` | `:681` | `ToolInvocation` |
| `ports.ail:1881` | `:1887` | `scripted_tool_outcome` |
| `ports.ail:1841`, `:1910` | `:1847`, `:1916` | the empty-queue arms |
| `ports.ail:2953`, `:3016` | `:2959`, `:3022` | literals |
| `seams.ail:343` | unmoved, in `src/eval/journal/` | literal |
| `seams_live_test.ail:99` | literal opens `:98`, fields end `:100`, in `src/eval/journal/` | literal |
| `world_state_probe.ail:1222` | `:1224`, in `scripts/dst/` | literal |
| `strict_replay_dst.ail:1417` | `:1419`, in `scripts/dst/` | literal |
| `tool_phase.ail:499`, `:504`; `session.ail:1369-1374` | unmoved | |

`make anchors`: exit 0, byte-identical output at base and head (C3).

## Test evidence

| Gate | Result |
|---|---|
| `make check_core` | exit 0, 211 OK / 0 FAIL, `src/core/ type-check: 61 passed, 0 failed` |
| `make test` | exit 0 |
| `cd src/tui && bun run test` | exit 1: 4 suites fail to run, 472 tests pass. The same 4 fail at base, and W6 does not touch `src/tui` |
| `make test_coverage` | exit 0, 969 of 982 passed, 13 skipped against a record |
| `make new_contract_policy BASE=origin/main` | exit 0, 7 in scope, all justified |
| `make verify_classify_check` | exit 0, 81 contracts, register agrees |
| `make anchors attribution_table profile_definition execution_program program_persistence strict_replay seeded_generator world_state invariants corpus_judge fault_catalogue journal_resume` | each exit 0 |
| `make corpus_pr`, `make discovery` | exit 0. Run because W6 changes code a corpus run reads, and s4 concerns discovery's count |
| `make world_state`'s C2 guard | `c2_guard PASS` |
| `make dst` | exit 2 at both. FAILED at head: `declared_vs_performed`. FAILED at base: `declared_vs_performed`. No difference |
| `make eval_matrix` | exit 2 at both, 0 rows differ |

### Mutants

`evidence/W6/mutants.tsv`, at `d066e961`. All ten killed by the test named before the run.

| Id | Rule | Killed by |
|---|---|---|
| s1 | a carried tool never reads `timeout_ms` | `row_1000_3000_2000` (`ports.ail`) |
| s2 | `ReadFile` has no carrier | `A10 ReadFile keeps today's deadline` |
| s3 | an extension does not read `timeout_secs` | `R8 (timeout_secs 2)` |
| s4 | the env read stays in `Limits` | `limits: the REPLAYED run's log accounts for it` |
| s5 | `SessionDefault` projects today's value | `strict replay: a Legacy recording of a call with no request` |
| l1, l2 | the refusal, and its boundary | `live arm: world_tool refuses BashExec`, `live arm control: SessionDefault` |
| d1, p1, i1 | display, projection, the invalid stand-in | named in the table |

### Acceptance

All in `scripts/dst/strict_replay_dst.ail`, run by `make strict_replay`, unless named otherwise.

- **A8:** the four `A8 NoDeadline` rows.
- **A9, scripted:** the `A9 1000/3000/2000` rows, the 30 s `SameAsDefault` rows, fractional and non-positive defaults, and the projection through `deadline_ms`.
- **A10:** `A10 Finite(0) expires at t = 0`, `A10 timeout_ms 0 with no carrier never expires`, and a pair for each of `ReadFile`, `Search`, `WriteFile` and `EditFile`.
- **A14a:** `limits_scenario`, with every axis of `run_scenario`, a replay from the artifact, and a control that the same program replayed as `Legacy` does not match.
- **A14c:** `A14c: the recorded extension deadline replays strictly and is served again`, and a `Legacy` control.
- **A25:** those run through the real token and `ext_ports_of`, and `A25: a token without the key runs its effect as Legacy`.
- **A16, scripted:** `A16: the same argument at 1500 ms completes in main dispatch and expires in an extension effect`. Loopback is W10's.

### The live refusal

Each row looks for a file the command would have made, and each refusal has a twin that does make it, so an absent file is evidence. Rows cover `world_tool` with `BashExec` and `RunTests`, `world_ext_effect`, and a `Limits` session with an empty queue.

The twins earned their place. In the first draft `touch` used a relative path, `BashExec` does not read `workdir`, and the "did not run" rows passed while looking in the wrong directory. Only the twins went red.

### Findings

- **s1 cannot be killed end to end on the 1000/3000/2000 row.** Through `tool_phase`, the projection makes `timeout_ms` equal an `ExplicitMs` carrier, so the two reads agree. The direct row passes a disagreeing value, and the no-request rows catch the mutant end to end.
- **`verify_single_construction` reads only the first import on a line.** A result constructor in a joined import reads as a value. W6's import goes first on `tool_phase.ail:45`. W7 will meet this.
- **`make verify_classify` exits 1 on a solver timeout** in `tool_runtime`'s generated probe, which W6 does not touch.
- **Overlap:** PR #287 also changes `session.ail`, `strict_replay_dst.ail` and `world_state_probe.ail`. Whichever lands second rebases.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
