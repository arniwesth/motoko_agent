---
repo: arniwesth/motoko_agent
pr: 324
branch: fix/ailang-1.0-readiness
ticket: null
title: "fix: ready for AILANG's JInt and exhaustive-match changes (#323)"
---

## Summary

Issue #323 lists the AILANG changes between v0.54.14 and 1.0 that affect this repo. Item 1
landed in #321 and #322. This PR fixes items 2 and 3. Item 2 is live from AILANG v0.60.0
(released 2026-11-10), which gives an integer as `JInt`, and four matches here stop seeing
integers. Item 3 is live from v0.60.4 (released 2026-11-13): a non-exhaustive `match` is a
compile error, `TC_MATCH_002`, and twelve matches here fail it. One of them can also fail at
run time on v0.54.14. The same source checks and passes its tests on v0.54.14, which stays the pin,
and on v0.60.0. v0.60.4 also adds checks that #323 does not list. #326 fixes those, and
with both PRs every file that checks on v0.54.14 checks on v0.60.4, except 27 deliberate
limitation pins.

Closes #323

## Changes

- fix: read JSON numbers through asNumber, so a JInt is still a number
- fix: name every constructor in the ten matches that left one out
- chore: re-lock after the skills and progress-contract-guard changes
- fix: name the constructors two more matches left out

11 files changed.

**Item 2, `JInt` (sunholo-data/ailang#2223).** The four matches read numbers with `asNumber`,
as the issue's comment suggests. It accepts `JNumber` and `JInt` on newer compilers and
`JNumber` on v0.54.14, so no file names `JInt`. It cannot be named yet: v0.54.14's `std/json`
does not export it (`IMP010`).

| Match | What an integer did on v0.60.0 | Now |
|---|---|---|
| `process_limits.ail` `parse_timeout_request` | `{"timeout_secs": 60}` → `BadRequest` → `ProcessInvalid` | `ValidMs(60000)`, as on v0.54.14 |
| `skills.ail` `json_kind` | run-time failure, no arm matched | "a number". The numbers are the final `_` arm |
| `skills.ail` `name_violations` | an all-digit `name:` skipped its specific message | specific message again |
| `association.ail` `arguments_equal` | outer: run-time failure. Inner: `60` ≠ `60.0` | numbers compare by value through `asNumber` |

**Item 3, exhaustive matches (sunholo-data/ailang#2146).** #323 lists ten matches. v0.60.4's
checker found two more, which #323's text search missed. Each now names the constructors it
left out:

| Match | Added |
|---|---|
| `compaction_policy_dst.ail` (4), `compaction_seeded_dst.ail` (2) | `PassThroughObserved` does what `PassThrough` does. Both mean "no compaction" |
| `stream_parity_dst.ail` `has_adjacent_repeat` | `[] => false` in the inner match |
| `progress_contract_guard.ail` test (2) | `Accept => false`, so the test passes only on the decision it expects |
| `scripted_ports.ail` `state_from_step_provider` | the four `*World` providers return their world's script, the world `session.ail`'s `ported_provider` builds. New test for `ScriptedWorld` and `RecordingWorld` |
| `admission.ail` `ad_rejection_location` | `AppliedFaultNotATool` and `AppliedFaultRepeated` at the ordinal they list, `CeilingInvalid` at the program. New test |
| `verify_herdr_orchestrator.ail` `kind_of` | `DecisionSolverJudge` and `DecisionToolPolicy` |

Eleven of these cannot fail today, because the missing constructor never arrives. For `kind_of`,
herdr registers neither decision capability. `ad_rejection_location` can fail:
`validate_program` returns all three constructors it left out, and `check_a9` maps it over that
list. On v0.54.14, a program with an invalid ceiling or a bad applied-fault ordinal stopped A9
with "no pattern matched in match expression" instead of giving a finding. The new test fails
that way before the change and passes after it.

`ailang.lock`: only the content hashes of the two edited packages change.

Not changed:

- PLAN-001 E3 in `041_process_execution_timeouts` says "`std/json` holds every number as a
  float". That was measured on v0.54.14 and is a record, so it stays. The comment on
  `parse_timeout_request` now says what holds on both compilers.
- From v0.60.0, `arguments_equal` compares two integers above 2^53 as floats, so it can call
  two different large integers equal. That is not a regression: v0.54.14 already loses that
  precision when it decodes.
- From v0.60.0, `getInt` returns `None` for a fractional value where it used to truncate. No
  inline test changes result because of it (see the 110-file run below).

Found while testing and not fixed here: v0.60.0 warns `LDR006` that
`sunholo/motoko_ext_scratchpad` imports four root-package modules (`src/core/env_client`,
`src/core/tool_contract`, `src/core/tool_envelope_dispatch`, `src/core/types`), which is
"planned to become an error". It is not in #323. Filed as #325. It is still a warning on
v0.60.4.

Not fixed here: v0.60.1 to v0.60.4 also type-check contracts and test rows, check a lambda's
effect row against its body, and refuse a type name two modules declare. These stop most files
on v0.60.4 and are not in #323. #326 fixes them.

## Governing docs

- #323, items 2 and 3, and its comment proposing `asNumber`.
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`, E3: `60` and
  `60.0` are the same valid request. This PR keeps that true on v0.60.0.

## Predicted outcome

On v0.60.0, an integer `timeout_secs` resolves to its budget instead of `ProcessInvalid`. A
skill whose `name:` is all digits gets the "has to be quoted" message instead of a run-time
failure. Two tool calls that differ only in `60` against `60.0` still associate. On v0.54.14,
A9 gives a `program-ceiling-invalid` or `program-applied-fault-*` finding where it used to stop,
and nothing else changes. On v0.60.4 these twelve matches check. To check: `ailang check` on
v0.60.0 prints no `TC_MATCH_005` for this repo's files, on v0.60.4 with #326 no file fails
on `TC_MATCH_002`, and the inline-test counts below hold.

## Test evidence

v0.60.0 is the release binary (linux arm64, sha256 checked) run with its own `std/` from tag
v0.60.0 through `AILANG_STDLIB_PATH`. Without that it reads the installed v0.54.14 stdlib.

Item 2, inline tests:

| File | v0.54.14 before | v0.54.14 after | v0.60.0 before | v0.60.0 after |
|---|---|---|---|---|
| `src/core/process_limits.ail` | 239/239 | 239/239 | 194/239 | 239/239 |
| `packages/motoko-ext-skills/skills.ail` | 62/62 | 62/62 | 61/62 | 62/62 |
| `src/eval/journal/association.ail` | 31/31 | 31/31 | 30/31 | 31/31 |

The "v0.60.0 before" column matches the counts in #323. After the change, `ailang check` on
v0.60.0 prints no `TC_MATCH_005` for these files. No `JNumber(...) =>` arm is left in the
repo's tracked `.ail` files.

Item 3:

- `ailang check` passes on v0.54.14 and v0.60.0 for all five files.
- `ailang test`: `scripted_ports.ail` 11/11 and `progress_contract_guard.ail` 25/25 on both.
- On v0.54.14: `compaction_policy_dst` PASS count=3, `compaction_seeded_dst` PASS seeds=5,
  `make stream_parity` wire gate PASS.

The two matches v0.60.4 found:

- `admission.ail` inline tests: v0.54.14 12 passed and 1 failed before the change. The new test
  fails with "no pattern matched in match expression". After the change: 13/13 on v0.54.14 and
  v0.60.0.
- `ailang check` passes on v0.54.14 and v0.60.0 for both files and for the 15 files that import
  `admission.ail`. Those with tests give the same counts on both.
- `make verify_herdr_orchestrator` on v0.54.14: 24 OK, `orchestrator.ail` 90/90.

v0.60.4, from a checkout with #326 applied: 397 of the 502 tracked `.ail` files outside
`.agent/` check on v0.54.14, and 370 of them check on v0.60.4. The other 27 are the limitation
pins #326 describes, and no file reports `TC_MATCH_002`. Every one of the 110 files with
`tests [` gives its v0.54.14 result on v0.60.4, except `compaction_structural.ail`, which goes
from 1 failed to 10/10. This PR's files give `process_limits` 239/239, `skills` 62/62,
`association` 31/31, `admission` 13/13, `scripted_ports` 11/11 and `progress_contract_guard`
25/25. Without #326, both files in the last commit stop on v0.60.4 at `process_limits.ail`'s
contracts.

Whole tree: `ailang test` on every tracked `.ail` file whose text contains `tests [` (110 files,
1,954 tests) gives the same result on v0.54.14 and v0.60.0 for every file. Not all of them come
out clean, and the same way on both compilers:

- `compaction_structural.ail` (1 failed) and `exa_search.ail` (2 failed). Neither imports a
  file this PR changes.
- `tools/test_coverage/fixtures/failing_test.ail` (1 failed) is a deliberate failing fixture.
- `scripts/verify_herdr_gate.ail`, `scripts/verify_herdr_delegate_wait.ail` and
  `tools/test_coverage/fixtures/phantom_pattern.ail` report "No tests found". `tests [` appears
  only in their text.

Repo checks:

- `ailang lock --check`: current.
- `make new_contract_policy`: 0 in-scope new `pure func`. The new test is out of scope, because
  only its own `tests` block reaches it.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
