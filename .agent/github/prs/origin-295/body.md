---
repo: arniwesth/motoko_agent
pr: 295
branch: arniwesth/041-w4-resolver
ticket: null
title: "feat(core): add the process-limit resolver (041 W4)"
---

## Summary

This is `041/PLAN-001/W4`. It adds `src/core/process_limits.ail`: the per-call process limit's types, its one resolver, and the pure functions that display and project what the resolver decided.

**Nothing calls this module yet, so no behaviour changes.** W5 onward wires it in, and until W12 no live world is in `Limits` mode.

- **A leaf (C1):** it imports only from `std`, so `dst_program`, `ports` and `tool_runtime` can all use its types.
- **One constructor (D7):** `resolve_process_limit` is the only place either result is built. The compiler cannot enforce that, because records are structural, so `evidence/W4/check_single_construction.py` scans for breaches from outside. **No gate runs that check yet:** W4 could not change the Makefile, so a later item has to wire it in.
- **I1 as a contract:** `clamp_ms` carries `ensures { result <= ceiling && (request > ceiling || result == request) }`.
- **The register:** `tools/verify_classify/contracts.register` is the regenerated output of `make verify_classify`, not a hand edit. It adds seven `substantive` rows and moves the total from 66 to 73. Every other changed line differs only in its `solve=` timing, so the raw diff looks larger than it is.

## Changes

- feat(core): add the process-limit resolver (041 W4)
- test(core): mutation evidence and construction check for the resolver (041 W4)
- chore(core): pin the resolver's contracts in the register (041 W4)

6 files changed.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md`: D2, D4, D7
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`: W4, C1, and the parts of A3, A4, A5, A8, A9 and A10 that W4 owns
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

## Predicted outcome

No production behaviour changes and no matrix row moves. This PR touches no `MATRIX.expected.tsv`, `tools/eval_protected/` or `scripts/eval/`, and no other module imports the new one.

`make check_core` type-checks one more file (61, up from 60), `make test_coverage` runs 189 more rows, and `make verify_classify_check` pins 76 contracts, up from 69.

**Expect a conflict with #287 in the register.** It also changes `contracts.register`, and timing churn touches most rows. Whichever lands second should re-run `make verify_classify` rather than merge by hand.

## Test evidence

The first six rows ran at `eaa51dd5`. The only later commit changes the register. `verify_classify_check` ran at `be90d040`, which has the regenerated register.

| Command | Exit | Result |
|---|---|---|
| `make check_core` | 0 | `src/core/ type-check: 61 passed, 0 failed` |
| `make test` | 0 | `All core runtime module tests passed!` (does not run the new rows) |
| `cd src/tui && bun run test` | **1** | `Test Suites: 4 failed, 44 passed, 48 total` / `Tests: 469 passed, 469 total` |
| `make test_coverage` | 0 | `src/core/process_limits.ail: 189/189 passed`; `899 of 912 passed, 13 skipped against a record` |
| `make new_contract_policy BASE=origin/main` | 0 | `26 in-scope new pure func declarations, all justified` |
| `make verify_mutations` | 0 | `5 falsified, 0 unfalsified` (the five existing guards only; the new contracts are not cases there) |
| `make verify_classify_check` | 0 | `verify_classify: 76 contracts, register agrees (73 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified)` |

**The TUI suite is not a pass.** The four failing suites are `compose-output-validator`, `compose_guard_semiformal`, `env-server` and `src/scratchpad/loopback`. They match the base numbers given in the W4 brief, but the base was not re-measured for this PR. This PR does not touch `src/tui`.

**Mutation table, at `858af7cb`:** 92 killed, 0 survived, 1 passed (the survival control `r9.survive`), 1 n/a (`e3.1e400`, which fails inside `std/json`, so no edit to this module can reach it). `git diff 858af7cb..HEAD -- src/core/process_limits.ail` is empty, so the table describes this module exactly. Edits and observed failures are in `evidence/W4/mutants.tsv`.

This was not one clean run. The first full run had 6 survivors: 4 missing rows (added), 1 redundant guard (removed), and 1 wrong expected test that was corrected after seeing the result. The author also wrote the mutant list, so the table shows the stated rules are tested, not that the list is unbiased.

**Not run:** `make dst`, `make eval_matrix` and the G-dst set. They are not in W4's gate set.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
