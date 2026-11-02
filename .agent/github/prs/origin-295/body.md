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
- fix(core): refuse a sub-millisecond fraction under m and h in parse_ceiling_ms (041 W4)
- test(core): pin the combinations the resolver's rows missed (041 W4)
- refactor(core): read the digits past the ninth with decimal_value (041 W4)
- test(core): mutants for the review's rows and the parse_ceiling_ms fix (041 W4)

### Independent review follow-up

A review at `ce9f39b9` found the resolver's logic correct and the evidence incomplete: twelve mutants that break stated rules survived, because the rows pinned each table line alone and never the combinations.

- **One logic fix, `parse_ceiling_ms`.** `1.0000000001h` and `1.0000000001m` were accepted as whole milliseconds. Go reads them as `3600000000360` and `60000000006` ns, so D2 refuses them. A non-zero digit past the ninth under `m` or `h` is now refused. `1.0000000001s` stays accepted.
- **13 rows from the review**, each with its own mutant: a `NoDeadline` default with a ceiling, a non-zero `legacy` in both directions against an explicit budget and a finite default, the `r_ns == d` boundaries, a ceiling that is not whole seconds, and no-attempt reports.
- **Dropped `row_project_test_10`,** which exercised the test helper `carrier_of` rather than a rule. D7 states no projection for an invalid request, and `row_resolve_test_19` pins that it is `ProcessInvalid`.
- **Comments only:** `row_agreement`, and the two `ensures` that hold over unbounded integers and fail under `-verify-contracts` near the boundary.

**Where the parser now differs from Go.** D2's whole-millisecond rule and Go's truncation to a nanosecond disagree on a narrow class, and this PR follows the brief's rule. A non-zero digit past the ninth under `m` or `h` that Go truncates to a whole millisecond is refused here: `1.00000000001m` is `60000000000` ns in Go, but its exact value is not a whole number of milliseconds. The reverse also exists and predates this PR: `89.50070000000000h` is accepted here at its exact value, while Go's float arithmetic reads it as a non-whole number of nanoseconds. A differential of 1,511 durations against Go 1.22.5 (random, plus hand-picked boundary cases) gave 22 disagreements before the fix and 8 after: these two kinds.

**The checker hole the review reported is not closed here.** An update on a call result, `{ idr(r) | budget: ExplicitMs(999999) }`, still passes `check_single_construction.py`.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md`: D2, D4, D7
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`: W4, C1, and the parts of A3, A4, A5, A8, A9 and A10 that W4 owns
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

## Predicted outcome

No production behaviour changes and no matrix row moves. This PR touches no `MATRIX.expected.tsv`, `tools/eval_protected/` or `scripts/eval/`, and no other module imports the new one.

`make check_core` type-checks one more file (61, up from 60), `make test_coverage` runs 207 more rows, and `make verify_classify_check` pins 76 contracts, up from 69.

**Expect a conflict with #287 in the register.** It also changes `contracts.register`, and timing churn touches most rows. Whichever lands second should re-run `make verify_classify` rather than merge by hand.

## Test evidence

`check_core`, `test_coverage`, `new_contract_policy` and `verify_classify_check` ran after the review follow-up, at `f3ad735c` with only `evidence/W4` changed on top of it. `make test`, the TUI suite and `verify_mutations` were not re-run: their rows are from `eaa51dd5` and `be90d040`, before the follow-up.

| Command | Exit | Result |
|---|---|---|
| `make check_core` | 0 | `src/core/ type-check: 61 passed, 0 failed` |
| `make test` | 0 | `All core runtime module tests passed!` (does not run the new rows; not re-run) |
| `cd src/tui && bun run test` | **1** | `Test Suites: 4 failed, 44 passed, 48 total` / `Tests: 469 passed, 469 total` (not re-run) |
| `make test_coverage` | 0 | `src/core/process_limits.ail: 207/207 passed` (was 189/189); `917 of 930 passed, 13 skipped against a record` |
| `make new_contract_policy BASE=origin/main` | 0 | `27 in-scope new pure func declarations, all justified` |
| `make verify_mutations` | 0 | `5 falsified, 0 unfalsified` (the five existing guards only; the new contracts are not cases there; not re-run) |
| `make verify_classify_check` | 0 | `verify_classify: 76 contracts, register agrees (73 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified)` |

**The TUI suite is not a pass.** The four failing suites are `compose-output-validator`, `compose_guard_semiformal`, `env-server` and `src/scratchpad/loopback`. They match the base numbers given in the W4 brief, but the base was not re-measured for this PR. This PR does not touch `src/tui`.

**Mutation table, at `f3ad735c`:** 111 killed, 0 survived, 1 passed (the survival control `r9.survive`), 1 n/a (`e3.1e400`, which fails inside `std/json`, so no edit to this module can reach it). Edits and observed failures are in `evidence/W4/mutants.tsv`. The 19 new mutants are labelled `B*` and `c.subms-*`.

This was not one clean run. The first W4 run had 6 survivors: 4 missing rows (added), 1 redundant guard (removed), and 1 wrong expected test that was corrected after seeing the result. In the follow-up, `c.subms-zeros` was first written inverted and survived, so that one mutant was corrected and re-run alone at the same commit. The author wrote most of the list, and the review's twelve survivors show that a list chosen this way can miss rules, so the table shows the listed rules are tested, not that every rule is.

**Not run:** `make dst`, `make eval_matrix` and the G-dst set. They are not in W4's gate set.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
