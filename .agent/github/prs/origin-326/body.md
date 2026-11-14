---
repo: arniwesth/motoko_agent
pr: 326
branch: fix/ailang-0.60.4
ticket: null
title: "fix: ready for the checks AILANG v0.60.4 added"
---

## Summary

AILANG v0.60.4 (released 2026-11-13) checks four things v0.54.14 lets through: the types in a
contract, a lambda's effect row against its body, a type name two modules declare, and the types
in a test row. None of them is in #323. They stop most of this repo's files on v0.60.4. This PR
fixes the causes. With #324, which fixes the exhaustive-match half, every file that checks on
v0.54.14 checks on v0.60.4, except the 27 that pin AILANG limitations on purpose. v0.54.14 stays
the pin, and nothing changes on it.

## Changes

- fix: derive Eq for the six types that contracts compare
- fix: the conformance scenarios' effect row names Trace
- fix: import Msg by name in phase_c_l1_scenarios
- fix: prompts_test's Msg rows give all four fields
- chore: re-lock after the conformance change
- fix: the process-tree probe accepts AILANG v0.60

10 files changed.

The release notes for v0.60.1 to v0.60.4 are empty. The four checks are read from the errors and
the commits between the tags.

| v0.60.4 refuses | Here | Fix |
|---|---|---|
| `==` in a contract on a type without `Eq` (`TC_CONTRACT_001`, sunholo-data/ailang#2232, #2248) | `SessionLimit` and `Ceiling` (`process_limits.ail`), `PurityBasis` and `CapabilityKind` (`dst_profile_coverage.ail`), `ToolOffer` (`ports.ail`), `DecisionSite` (`ext/runtime.ail`). Every file importing one of these modules stopped | `deriving (Eq)` on each |
| A lambda that performs an effect its row leaves out | The four conformance scenarios call `compact_with` (`! {AI, IO, Trace}`) from a lambda whose row has no `Trace` | `Trace` in `Scenario.run`, the four lambdas, `run_scenario`, `run_all`, and `conformance_selftest`'s `expect_ok` and `expect_fail` |
| A type name reached through two modules (`TC_AMBIGUOUS_TYPE_001`) | `phase_c_l1_scenarios.ail` names `Msg`, which `src/core/types` and `motoko_ext_abi/types` both declare | Import the ABI's `Msg`, the one `validate_compactor_output` takes |
| A test row of the wrong type (`TC_TEST_001`) | `prompts_test.ail` builds three `Msg` values with two of their four fields | Add `tool_calls: []` and `tool_call_id: ""`. `fmt_msgs` reads neither |

One more, not a check: `make verify_native_process_tree`, which `make check_core` runs first,
lists the AILANG versions it accepts by name, up to v0.59.x. Every v0.60 release fails it before
the probe runs. It now accepts v0.60 to v0.69. On v0.60.4 every row of the probe passes,
including the two that pin what the wall does not reach (041 ADR-002 D5).

`ailang.lock`: only `sunholo/motoko_ext_conformance`'s content hash changes. `generated_at` keeps
main's value, so this lock and #324's merge in either order. When both re-locks moved it, a test
merge of the two branches conflicted on that line alone. The merged lock is current.

#324 and this PR touch different lines of `process_limits.ail` and merge cleanly. Neither alone
makes v0.60.4 check: without #324 files stop on `TC_MATCH_002`, and without this PR on the four
checks above.

Not changed:

- **The 27 limitation pins.** They are the 26 files in `scripts/dst/fixtures/adr001_boundary/` and
  the "smuggle" lambda at `scripts/dst/declared_vs_performed.ail:548`. They record what AILANG let
  through when 031 ADR-001 was written
  (`.agent/projects/031_system_one_decisions/NOTE-001-effect-inference-gap.md`), and v0.60.4
  refuses them: 24 because it now checks a lambda's effect row against its body, and 3 because it
  refuses a field the record does not have (`TC_REC_001`). Those are the limitations closing
  upstream. `make declared_vs_performed` cannot report it on v0.60.4: its
  probe is one of the 27, so every arm fails to compile before the gate reaches its "FIXED
  UPSTREAM" rows. What the ADR and the gate say now is ADR-001's call, so it is left to a
  separate change.
- **`make declared_vs_performed` on v0.54.14** reports 126 passed and 11 failed. It reports the
  same 11 rows on main, and `DST_KNOWN_RED` is empty. That predates this PR and is not fixed here.
- **`LDR006`** (#325) is unchanged on v0.60.4.

## Governing docs

- #323, the list of AILANG changes up to 1.0. This PR covers what v0.60.1 to v0.60.4 added
  beyond it.
- `.agent/projects/031_system_one_decisions/NOTE-001-effect-inference-gap.md`, for the pins left
  in place.

## Predicted outcome

On v0.54.14 nothing changes: every file checks or fails as it does on main, and every inline test
gives main's result. With #324, `ailang check` on v0.60.4 passes for every file that passes on
v0.54.14 except the 27 pins, the inline tests give the v0.54.14 results, and `make check_core`
passes. To check: the sweeps and runs below.

## Test evidence

v0.60.4 is the release binary (linux arm64, sha256 checked) run with its own `std/` from tag
v0.60.4 through `AILANG_STDLIB_PATH`. The files are the 502 tracked `.ail` files outside
`.agent/`.

AILANG relaxes `MOD010` for a tree under `/tmp`, so these runs are from a checkout outside it.
Under `/tmp`, 23 fixtures in `tools/` whose module names do not match their paths also check.

`ailang check`:

| Tree | v0.54.14 | v0.60.4 |
|---|---|---|
| this PR and #324 | 397 pass | 370 pass. The other 27 of the 397 are the pins |

The 397 are the same files that pass on #324's branch. This PR alone was compared with main from
exports under `/tmp`, run the same way for both. The same files pass on v0.54.14: 420, the 397
and the 23 fixtures.

`ailang test` on the 110 files whose text contains `tests [`:

- v0.54.14: main and this PR give the same result for every file, 1,953 tests (the `/tmp`
  exports).
- This PR with #324, in the checkout: v0.54.14 and v0.60.4 give the same result for every file
  (1,955 tests: #324 adds two), except `compaction_structural.ail`, which goes from 1 failed to 10/10 on v0.60.4.
- Without this PR, 34 of these files (681 tests) do not compile on v0.60.4, measured on #324's
  branch.
- Not clean on either compiler, as on main: `exa_search.ail` (2 failed), the deliberate
  `failing_test.ail` (1 failed), and three files that report "No tests found".

DSTs, this PR with #324:

| | v0.54.14 | v0.60.4 |
|---|---|---|
| `make conformance` | self-test PASS, registry probe PASS | same |
| `phase_c_l1_scenarios.ail` | PASS count=15 | same |
| `compaction_policy_dst.ail` | PASS count=3 | same |
| `compaction_seeded_dst.ail` | PASS seeds=5 | same |
| `make stream_parity` | DST PASS, wire gate PASS | same |
| `make check_core` | pass, `src/core/` 61/61 | pass, `src/core/` 61/61 |

Repo checks:

- `ailang lock --check`: current, on this branch and on the merge with #324.
- `make ext_hook_scope_selftest` and `make ext_ambient_inventory_selftest`: pass on both
  compilers.
