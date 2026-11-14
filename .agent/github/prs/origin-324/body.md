---
repo: arniwesth/motoko_agent
pr: 324
branch: fix/ailang-1.0-readiness
ticket: null
title: "fix: ready for AILANG's JInt and exhaustive-match changes (#323)"
---

## Summary

Issue #323 lists the AILANG changes between v0.54.14 and 1.0 that affect this repo. Item 1
landed in #321 and #322. This PR fixes items 2 and 3. Item 2 is already live: AILANG v0.60.0
(released 2026-11-10) gives an integer as `JInt`, and four matches here stop seeing integers.
Item 3, a non-exhaustive `match` becoming a compile error, is planned for 1.0, and ten matches
here would fail it. The same source checks and passes its tests on v0.54.14, which stays the
pin, and on v0.60.0.

Closes #323

## Changes

- fix: read JSON numbers through asNumber, so a JInt is still a number
- fix: name every constructor in the ten matches that left one out
- chore: re-lock after the skills and progress-contract-guard changes

9 files changed.

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

**Item 3, exhaustive matches (sunholo-data/ailang#2146).** None of these can fail today, because
the missing constructor never arrives. Each now names it:

| Match | Added |
|---|---|
| `compaction_policy_dst.ail` (4), `compaction_seeded_dst.ail` (2) | `PassThroughObserved` does what `PassThrough` does. Both mean "no compaction" |
| `stream_parity_dst.ail` `has_adjacent_repeat` | `[] => false` in the inner match |
| `progress_contract_guard.ail` test (2) | `Accept => false`, so the test passes only on the decision it expects |
| `scripted_ports.ail` `state_from_step_provider` | the four `*World` providers return their world's script, the world `session.ail`'s `ported_provider` builds. New test for `ScriptedWorld` and `RecordingWorld` |

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
`sunholo/motoko_ext_scratchpad` imports root-package modules (`src/core/env_client`,
`src/core/tool_contract`, `src/core/types`), which is "planned to become an error". It is not in
#323.

## Governing docs

- #323, items 2 and 3, and its comment proposing `asNumber`.
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`, E3: `60` and
  `60.0` are the same valid request. This PR keeps that true on v0.60.0.

## Predicted outcome

On v0.60.0, an integer `timeout_secs` resolves to its budget instead of `ProcessInvalid`. A
skill whose `name:` is all digits gets the "has to be quoted" message instead of a run-time
failure. Two tool calls that differ only in `60` against `60.0` still associate. On v0.54.14
nothing changes. When AILANG makes non-exhaustive matches an error, these ten matches do not
fail. To check: `ailang check` on v0.60.0 prints no `TC_MATCH_005` for this repo's files, and
the inline-test counts below hold.

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
