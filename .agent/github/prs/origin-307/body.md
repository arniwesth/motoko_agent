---
repo: arniwesth/motoko_agent
pr: 307
branch: arniwesth/041-w7-argument-errors
ticket: null
title: "041 W7: argument errors and scripted metadata, dark"
---

## Summary

An invalid `timeout_secs` in a `Limits` program now emits `ToolArgumentsInvalid` and neither Start nor Complete, and it never reaches the port. A scripted fault reports D4's limit fields, in `tool_outcome_message` and in `session.tool_outcome_text`. `ToolCompleted` and `Legacy` keep their bytes. Nothing activates: no writer produces a `Limits` program, and the C2 guard stays green.

## Changes

- **W6's stand-in is gone.** `invalid_request_outcome`, its caller and the `start_event` on that branch are removed. The request resolves ahead of Start, on the existing line at `:491`, and the clock and env reads stay. The event and message are in a new arm below `:499`.
- **`tool_outcome_message` and `tool_outcome_text` take the carrier,** on their existing lines. The fields go after `fault`, ahead of `detail` and `message`, so the cap cannot reach them. A deadline's own `timeout_ms` is replaced when there is a carrier. With no carrier, the bytes are today's.
- **New in `process_limits.ail`:** `carrier_limit_fields` (`process_limit_fields` now shares its body), and `rejected_request_text`, which echoes a rejected value bounded to 120 characters.
- **New in `tool_phase.ail`:** `invalid_request_message`, the eighth fault builder. `refused_call_ids` and P1's builder list gain it.
- **The event:** `ToolArgumentsInvalid(ToolCallInfo)`, wire name `tool_arguments_invalid`, Logical, in `phase_vocab`, `dst_event_vocabulary` and `event_vocabulary_dst`. The vocabulary goes from 42 rows to 43.
- **`ledger_parity` gains a subject,** and the subject count in `ledger_parity_dst`, `run_ledger_parity_wire.sh` and `run_world_framed_wire.sh` goes from 8 to 9. See Findings, on e1.
- **Register:** `rejected_echo_limit`'s pin and the totals line, and nothing else. `make verify_classify`'s solve-time churn is left out.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`, W7
- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md`, D1, D4 and D7

## Predicted outcome

### Matrix rows, predicted before the run

`evidence/W7/predict_matrix.sh` ran at `00bafdf4`, and its output was committed in `9c3e8080`, ahead of any `make eval_matrix` on this branch.

- **Predicted: no row moves.**
- **Cause:** no new protected finding (19 at base, 19 here). The first finding the M13 and M15 rows report is still `changed:<imports:1>`.

**Observed at `9c3e8080` against `9400bd07`: 619 rows each, 0 differ in any field but the commit.**

### Rows left red under R11

33 failed and 33 missing, all red at base too: `evidence/W7/matrix_rows_left_red.txt`, checked row by row against this run. `credited=418 equal=124 failed=33 inapplicable=11 missing=33` on both sides. `manifest-A`, `tools/eval_protected/`, `scripts/eval/` and `MATRIX.expected.tsv` are untouched. **R11's four weeks count from this item's merge.**

### H1

Resolved as the plan says, and not reopened. `attempted` is `after_dispatch` for `ToolFailed`, and true for `ToolCorrelationMismatch` and `ToolDeadlineExceeded`, on both paths. So a scripted `ToolFailed` with `after_dispatch: false`, and W6's live-arm refusal of `ExplicitMs`, report `requested_timeout_ms` and `max_timeout_ms` and no `timeout_ms`. Rows: `H1: a fault before dispatch reports no applied limit`, `A11: the live arm's refusal before dispatch reports no applied limit`, and `test_w7_outcome_text_failed_before_dispatch_reports_no_applied_limit`. Mutants x2 and x3 pin it.

### Profile version

**No bump.** `make profile_definition`, `make attribution_table` and `make anchors` pass unchanged. `make anchors` output is byte-identical at base and head.

`event-vocabulary/4` also stays. D8 says "a change to any variant" is a version change. I read a new row as not one, because old traces read as they did, and because adding `ToolArgumentsUndecodable` (`8980ba61`) did not bump. All three bumps so far were deletions. If the operator reads D8 otherwise, `/5` costs the six pinned strings in five DST scripts and a pin comment, with no profile bump, going by `3d21d9d3`.

### Line references that moved

| Plan says | Here | Responsibility |
|---|---|---|
| `tool_phase.ail:289`, `:499`; `session.ail:1150`, `:1382` | unmoved | signature, clock read, text, caller |
| `tool_phase.ail:515` | `:540` | the caller, inside the new arm |
| `tool_phase.ail:753-786` | `:793` onward | the w14 tests |
| `phase_vocab.ail:1546` | `:1548` | `cap_tool_message_content`, +2 from the variant and wire arm, not pinned by anchors |
| `dst_invariants.ail:1649` | `:1650` | `refused_call_ids`, +1 from its comment |
| `dst_invariants.ail:1675-1686` | `:1676-1686` | the builder list |
| `fault_catalogue_dst.ail:72` | unmoved, in `scripts/dst/` | caller |
| `invariants_dst.ail:1037-1046` | `:1038-1047`, in `scripts/dst/` | callers |

## Test evidence

| Gate | Result |
|---|---|
| `make check_core` | exit 0, 211 OK, `src/core/ type-check: 61 passed, 0 failed`, `check_single_construction: 576 .ail files, 0 breaches` |
| `make test` | exit 0 |
| `cd src/tui && bun run test` | exit 1: 4 suites fail to run, 472 tests pass, as W6 recorded at this base. W7 does not touch `src/tui` |
| `make test_coverage` | exit 0, 995 of 1008 passed, 13 skipped against a record |
| `make new_contract_policy BASE=origin/main` | exit 0, 5 in scope, all justified |
| `make verify_classify_check` | exit 0, 82 contracts, register agrees |
| `make anchors attribution_table profile_definition execution_program program_persistence strict_replay seeded_generator world_state invariants corpus_judge corpus_pr fault_catalogue journal_resume` | each exit 0 |
| `make event_vocabulary ledger_parity world_framed_wire discovery` | each exit 0 |
| `make dst` | exit 2 at both. FAILED at head: `declared_vs_performed`. FAILED at base: `declared_vs_performed`. 127 passed, 10 failed on both. No difference |
| `make eval_matrix` | exit 2 at both, 0 rows differ |

`make dst` ran at `00bafdf4` and `make eval_matrix` at `9c3e8080`. After them, the only code change is a test row in `strict_replay_dst` (`1e400`), and `make strict_replay` passed with it. `AILANG_FS_SANDBOX` was not set in this session's shell, so the DST targets ran plain.

### Mutants

`evidence/W7/mutants.tsv`, at `75b8c3f1`. All sixteen were killed by the row named before the run. The one code commit between that and the row above changes a printed subject count.

| Id | Rule | Killed by |
|---|---|---|
| e1 | no Start on an invalid request | `A14b: the tool-dispatches-unbalanced rule…` (`corpus_judge`) |
| e1w | no Start on the wire either | `V2ToolDispatchStart: projected…` (`ledger_parity`) |
| e2 | never the port | `invalid: the queue is untouched…` |
| e3 | `ToolCompleted` byte for byte | `test_w7_completed_is_served_byte_for_byte` |
| e4 | `Legacy` has no fields | `v5 replay: Legacy faults render today's bytes…` |
| e5 | the event is how P1 sees it | `P1 presence: the run's ToolArgumentsInvalid…` (`corpus_judge`) |
| e6 | `effects: none` | `invalid disclosure: the fault is refused, effects none` |
| e7 | `timeout_ms` once in the text | `test_w7_outcome_text_deadline_reports_timeout_ms_once` |
| e8 | the text's `ToolFailed` has fields | `test_w7_outcome_text_failed_reports_the_limit` |
| x1 | the bridge passes the carrier | `A16: an extension ToolFailed reports…` |
| x2, x3 | H1, on each path | named above |
| x4 | the echo is bounded | `A17: a 70,000-character timeout_secs…` |
| x5 | `refused_call_ids` names the event | `an invalid request without fault` (`invariants`) |
| x6 | `timeout_ms` once in `detail` | `test_w7_deadline_reports_timeout_ms_once` |
| x7 | the event reaches the trace | `ToolArgumentsInvalid: projected…` (`ledger_parity`) |

### Acceptance

In `scripts/dst/strict_replay_dst.ail`, run by `make strict_replay`, unless named otherwise.

- **A5, scripted:** ten `A5: … is refused, never launched, and reports no applied limit` rows, `A5: a null timeout_secs behaves as no argument`, `A5: 1e400 is undecodable…`, and `row_w7_invalid` in `tool_phase.ail`.
- **A14b:** `invalid: the queue is untouched…`, `invalid: one ToolArgumentsInvalid, and neither Start nor Complete`, `A14b: a Limits program holding an invalid request replays strictly…`, and `A14b: the tool-dispatches-unbalanced rule…` in `corpus_judge_dst`.
- **A11, refused:** `invalid disclosure…`, `A11: the live arm's refusal before dispatch reports no applied limit`, and `A11: a fault after dispatch reports the limit it was given` as the contrast.
- **A21, scripted:** the two `A21:` deadline rows, and `test_w7_deadline_disclosure_by_tool`. See Findings for `Search`.
- **A17:** `test_w7_fields_survive_the_cap_on_a_long_failure`, `test_w7_long_string_request_is_echoed_bounded`, and `A17: a 70,000-character timeout_secs…`.
- **A7, scripted:** `A7: an authored completion is served byte for byte under a carrier`, and `test_w7_completed_is_served_byte_for_byte`, which includes the cap.
- **A16:** the two `A16: an extension…` rows, through the real bridge, and `test_w7_outcome_text_*` in `session.ail`.

### Findings

- **e1 survived as first written, and the gap was real.** A Start emitted on the wire but not returned in `emitted` passed everything, because `corpus_judge` reads the trace. `ledger_parity` compares the two channels but had no invalid-request subject. It has one now, and e1 is split into e1 (both channels) and e1w (wire only). The surviving run was at `aabcc38c`.
- **e5, as the plan states it, cannot fail P1 on real bytes.** The message carries `fault` whether or not the event was emitted, and P1 only reads refusals on a message missing its disclosure. So the row takes the run's own trace and strips that one message's disclosure: P1 must find it, and only does if the run's event named the id. The mutant is unchanged, and the row is the one the plan names.
- **e4's "v5 replay" is the frozen v5 specimen's queue and mode through the driver.** A replay against its own recording cannot see a rendering, because both sides render alike, and the existing v5 scenario replays only the tool seam. The row asserts exact bytes.
- **A21's `Search` half does not hold on the scripted path, and I did not change it.** A scripted `Search` deadline says `effects: unknown` today, because `deadline_fault` does not look at the tool. `none` is the live arm's (`tool_runtime.ail:637`). Making it `none` would change a `Legacy` program's bytes and contradict A10. `unknown` is the safe direction, and the row pins today's bytes. The plan gives the `Search` half to W10 at line 546, but line 653 asks W13 for "A21 across both worlds", and that will meet this. **W13, or the operator, needs to decide what the scripted half means.**
- **Overlap:** PR #287 also changes `session.ail`. Whichever lands second rebases.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
