---
repo: arniwesth/motoko_agent
pr: 320
branch: fix/tool-schemas-runtests-editfile
ticket: null
title: "fix(core): RunTests and EditFile schemas say what the runtime reads"
---

## Summary

The model learns a native tool's arguments only from that tool's schema, and two schemas disagreed
with `src/core/tool_runtime.ail`. `RunTests` promised a default `cmd` that does not exist, so a
call without `cmd` comes back as a failed test run. `EditFile` never offered `replace_all`, which
the runtime honours and its own error message tells the model to set. Both schemas now say what
the runtime reads, and a new test pins them. This is the follow-up flagged in #319 (items 1 and 2).

## Changes

- fix(core): RunTests and EditFile schemas say what the runtime reads

1 file changed.

| Schema | Before | After | Runtime it now matches |
|---|---|---|---|
| `RunTests.cmd` | optional, "Test command, defaults to 'make test'" | **required**, "Test command to run, e.g. 'make test' or 'pytest'" | `parse_exec_from_args` defaults `cmd` to `""` (`tool_runtime.ail:184`). No `make test` default exists anywhere in core. |
| `EditFile` edit items | `old`, `new` | adds `replace_all` (boolean, "default false"). `old` now says it must be non-empty and match exactly once unless `replace_all` is true | `parse_edit_ops_rec` reads `replace_all` (`:207`). `apply_edits` rejects an empty `old` and a 0-match, and answers a multiple match with "set replace_all=true" (`:842-846`). |

`test_schemas_state_what_the_runtime_reads` decodes both schemas, so a schema that stops being
valid JSON fails too. It checks:

- `RunTests` requires `cmd`.
- The description of `cmd` promises no default.
- Each edit item declares `replace_all` as a boolean.
- The required lists of `EditFile` and its edit items are unchanged.

It is a plain `func` with a `tests` clause, as `tool_runtime.ail`'s examples are, because
`std/json.decode` is not `pure`.

Not changed:

- The `EditFile` description's claims about dry-run and the SHA-256 guard. Both hold:
  `run_edit_file` reads `dry_run` and `expected_sha256` (`:243`, `:925-934`).
- The recorded request bodies under `.agent/projects/037_skills_system/evidence/`. They are
  evidence of what was sent at the time.
- SYSTEM.md. #319 keeps "Always pass `cmd` to `RunTests`" and the `replace_all` line. Once both
  PRs land, those lines repeat the schema and can be cut. The re-read-and-retry rule on the same
  line is not in the schema and should stay.

## Governing docs

- #319 (`docs/system-md-lean`). Its PR body lists these two schema gaps as kept-but-flagged
  items 1 and 2.
- No `.agent/projects/` document governs the native tool catalog's argument text.

## Predicted outcome

A model calls `RunTests` with a command instead of relying on a default that does not exist. It
uses `replace_all` for a repeated substring instead of failing once on "matched multiple
occurrences" and then retrying. To check: a session's `RunTests` calls carry `cmd`, and in an
`EditFile` journal entry `replace_all` is set where a substring repeats.

Neither resume digest covers the native schemas. `resume_refusal` compares the workdir,
`ext_set_digest` (extension ids and capability kinds, `ext/runtime.ail:1327-1335`) and the
system-prefix digest, and tool definitions are not part of the system prefix. So unlike a
SYSTEM.md edit, this change does not cause a same-profile resume to be refused.

## Test evidence

**The module's own tests.** `ailang check src/core/tool_catalog.ail` reports no errors.
`ailang test src/core/tool_catalog.ail` gives **10 passed, 0 failed**, including the new test.

**The new test can fail.** Each fix was reverted on its own and the test rerun:

| schema state | `test_schemas_state_what_the_runtime_reads` |
|---|---|
| old `RunTests` schema, new `EditFile` | ✗ (9 passed, 1 failed) |
| new `RunTests`, `replace_all` removed | ✗ (9 passed, 1 failed) |
| both fixed | ✓ (10 passed) |

**The `RunTests {}` failure is real, not inferred from reading the code.** A scratch
`ailang run --caps IO,Process` of `exec("", [])` printed `ERR NotFound()`. The `Err` arm of
`run_process_result` turns that into a `RunTestsResult` with exit 1 and one failure named
`test-command` (`tool_runtime.ail:1048-1062`).

**Repo checks:**

- `make new_contract_policy BASE=origin/main` reports "no pure func added under src/core/ since
  origin/main".
- `ailang verify src/core/tool_catalog.ail` reports "2 exported functions: 2 without contracts",
  the same as on `main`.
- `make test` reports "All core runtime module tests passed!".
- `make tool_catalog_registry` reports **PASS**: the native schemas are unchanged under every
  wrapper, and every name appears once across all 20 registered extensions (74 tools).
- `make check_core` exits 0. All 17 `verify_*` prerequisites pass, and "src/core/ type-check: 61
  passed, 0 failed".

**Live, `openrouter.ai/api/v1`, `anthropic/claude-opus-5.5`, streamed.** This branch's seven
native schemas, parsed from `tool_catalog.ail`, went in as tool definitions with the recorded
12,307-character system prefix. The task was "notes.txt has the word foo on lines 3, 9 and 14 …
Replace every foo with bar, then run the tests with RunTests." The result was
`native_finish_reason=tool_use` with no error, so the provider accepted both changed definitions.
The plan was `<plan>Read notes.txt to confirm where foo appears, replace every occurrence with
EditFile (replace_all), check that no foo is left, then run the tests.</plan>`. It was followed by
`ReadFile` and `Search` calls.

The `ailang` commands print a lock warning on every run: "dependency sunholo/motoko_ext_skills
content changed … Run 'ailang lock'". This diff touches no package and no lock file, so the warning
is not from this change.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
