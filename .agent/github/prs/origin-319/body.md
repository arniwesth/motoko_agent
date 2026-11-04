---
repo: arniwesth/motoko_agent
pr: 319
branch: docs/system-md-lean
ticket: null
title: "docs(system): SYSTEM.md lean, and true to the tree"
---

## Summary

`SYSTEM.md` goes into every provider call as the first part of the system prefix. It drops from
6,902 to 3,108 characters (125 to 35 lines). The recorded 12,307-character prefix drops to 8,513,
about 950 fewer tokens per step by the runtime's own char/4 estimate. Five statements the tree
contradicts are corrected, not just shortened. One of them told the model that a tool the same
prefix advertises does not exist, and another conflicted with what the default-on herdr extension
tells the model to do. The `<plan>` block keeps its tag and stays framed as a plan. A live call to
`claude-opus-5.5` still returns `tool_use`, not `refusal`.

## Changes

- docs(system): SYSTEM.md lean, and true to the tree

1 file changed.

**Corrected, because the tree contradicts the old text**

| Old claim | What the tree says |
|---|---|
| "Rebase-forward policy and fork surface inventory: `ailang/FORK.md`" | The file does not exist. |
| "Runtime: vendored AILANG fork in `ailang/`" | `ailang/` is gitignored (`.gitignore:13-16`, "Local AILANG source checkout used to build a patched binary"). The TUI spawns `$AILANG_BIN` or `ailang` from PATH (`src/tui/src/runtime-process.ts:954-957`). Here that binary is upstream v0.54.14 (commit `e1ef33f`), which is not in the local `ailang/` checkout at `2063f4ce`. Now: "It runs on the `ailang` binary on PATH, or `$AILANG_BIN` when set." |
| "external execution is performed by the environment server"; "HTTP between runtime and env-server" | Native tools run in the runtime process through `std/process exec` (`src/core/tool_runtime.ail:9`, `:1045-1047`). `backend.exec_backend` has no caller. Only the scratchpad extension posts to the env-server (`env_client.exec_scratchpad_cell`). Removed. |
| "Use ONLY the following tool names … if a name is not listed here, it does not exist" (six tools) | The native catalog has seven tools. The seventh is `MotokoRuntimeStatus` (`src/core/tool_catalog.ail:70`, listed in `tools()` at `:78-88`). `tools_with_extensions` adds extension tools as well. The recorded prefix itself advertises the `scratchpad` tool, after the AGENTS.md block. Now: "Call only tools in the tool list you were given." |
| A prose-only response is to be used "only when you are done or need the user to answer a blocking question" | `herdr` is on in the default profile, and its tool results tell the model "To wait for it, end your turn: the loop parks and wakes you" (`packages/motoko-ext-herdr/herdr.ail:257, 351, 1489, 1569, 1720, 1903`). `classify_candidate` parks a candidate while a wait is open (`src/core/session.ail:2939`). That case is now named as a third reason to end a turn. |
| "I am Motoko, a a highly experimental …" | Doubled "a" fixed. |

**Removed, with the reason each removal is safe**

| Removed | Why it is safe |
|---|---|
| `ailang/FORK.md` pointer | Stale path. |
| "You communicate over JSONL …" (intro) and "Protocol: JSONL … HTTP …" (Project Identity) | Duplicates of each other. The env-server half is contradicted (above). The JSONL half is kept once, in the source paragraph. |
| "Core runtime" / "Frontend" bullets | Merged into one sentence with the `rpc.ail` entry point. |
| Tool table columns for purpose and arguments | Duplicates. Every name, description and required argument already goes to the provider in the tool schemas (`tool_catalog.ail:34-88`). The facts the schemas lack are kept: `replace_all`, `bash -lc`, and that `RunTests` needs `cmd`. |
| "Tool Usage (When Available)" argument list and "Edit workflow" | Third and fourth copies of the same arguments and the same read-before-edit rule. Merged into one preference rule and one `EditFile` line. |
| "As of M-MOTOKO-RPC-LOOP-FULL-MIGRATION (2026-05-06) …", the four-provider list (Anthropic `tool_use`, OpenAI `tool_calls`, Gemini `functionCall`, OpenRouter), and "dispatches each one through its policy gate / tool-handle hooks / backend split" | Inert. Migration history, the mechanics of providers the model is not running on, and runtime internals give the model nothing to act on. The rule is kept: native API only, and JSON in prose is not executed. |
| "The legacy text-based parser was removed in this migration" | Inert history. It is true (`src/core/parse.ail:3-9`), and the rule it justified is kept. |
| Rules 1–3 under the plan pattern, and the `## Pattern:` template line | They repeat the opening sentence. They are folded into it: mandatory, nothing before `<plan>`, the answer after `</plan>`. |
| "This is not optional. Producing a final answer while the modified code fails to type-check is a violation of your operating contract." | Duplicate of step 4, which is kept as step 3, "Do not give your final answer until these checks pass". |
| "Each unrequested file costs token budget, creates cleanup work …" | Rationale prose. The rule it explains is kept. |

**Kept although it looks wrong or cannot be verified. Flagged for a decision, not changed here**

1. **`RunTests` schema vs runtime.** The schema says `cmd` "defaults to 'make test'" and marks it
   optional (`tool_catalog.ail:61`). `parse_exec_from_args` defaults it to `""`
   (`tool_runtime.ail:184`), and no `make test` default exists anywhere in core. SYSTEM.md keeps
   "Always pass `cmd` to `RunTests`", which is the true statement. The schema should be fixed
   separately.
2. **`EditFile` schema omits `replace_all`**, which the runtime honours (`tool_runtime.ail:207`,
   `:846`). SYSTEM.md is currently the only place the model learns about it. Adding it to the
   schema would let SYSTEM.md drop that line.
3. **`make check_core` is no longer just a type-check.** It now has 17 `verify_*` prerequisites
   (`Makefile:2703`), so it can fail for reasons unrelated to the file the model changed. The
   rule's own alternative, `ailang check` on each changed file, is cheaper. The rule is kept as
   written. Whether to put the per-file check first is your call.
4. **"A response with none is taken as your final answer."** That is true of core. But the
   default profile's `empty_stop_guard` and `progress_contract_guard` can send a candidate back,
   at most twice each. They are safety nets, not something the model should rely on, so the
   statement stays.
5. **The scope rule speaks in benchmark terms** ("any verifier the task ships", "pass criteria").
   It is kept. SYSTEM.md is copied into foreign workdirs as `.motoko-system-prompt.md` by the 037
   fixtures, and the rule is harmless when there is no verifier.

## Governing docs

- PR #317 (`.agent/github/prs/origin-317/body.md`). The `<plan>` block must stay a plan. It must
  not ask for internal reasoning or use a `<thinking>` tag, because Anthropic's platform refuses
  every request when it does. The block here is shorter, its tag and framing are unchanged, and it
  was re-measured live (Test evidence).
- `.agent/projects/005_harness_policy_boundary/PLAN-finalize-policy-migration.md` WI-5 and
  `ADR-001-harness-policy-boundary.md` Amendment 1, A4. Core runs no verifier on a candidate, so
  the verification section still ends "The runtime does not check this, so the check is yours to
  run". The same plan (`:217-220`) says to warn that **editing `SYSTEM.md` changes the system
  prompt's digest**. A session started before this lands and resumed after it under the same
  profile is refused as `Prompt` unless the resume is forced (`src/core/journal.ail`). That is
  the journal working as designed.

## Predicted outcome

Every provider call on a session rooted in this repo sends 3,794 fewer characters of system
prefix, about 950 tokens by char/4. Behaviour should not change, except in the three places the
old text misled the model:

- It now calls extension tools without being told they do not exist.
- It ends its turn to park on a herdr delegate without that contradicting the stop rule.
- It no longer looks for `ailang/FORK.md` or treats `ailang/` as the runtime.

To check: the next default-profile session shows a `<plan>` block on every step, and
the journal's `provider_call_prepared` event reports `system_prefix_chars` 3,794 lower for the
same AGENTS.md and extension set.

## Test evidence

**Size**, from `wc -lmc` on `git show main:SYSTEM.md` and on this branch:

| | lines | chars | bytes |
|---|---|---|---|
| before | 125 | 6,902 | 6,916 |
| after | 35 | 3,108 | 3,108 |
| recorded system prefix (session `session_1793825850965-c64b80f058af3307`, SYSTEM.md part swapped) | | 12,307 → 8,513 | |

**Hard constraints**: `grep -c "<plan>" SYSTEM.md` gives 2 (the instruction and the example).
`grep -in "thinking\|reasoning" SYSTEM.md` finds nothing. No `.ts` or `.ail` file changed.

**Live, `openrouter.ai/api/v1`, `anthropic/claude-opus-5.5`, streamed.** The system message was
the new SYSTEM.md plus the rest of the recorded 12,307-character prefix (the AGENTS.md block and
the scratchpad extension text), 8,513 characters in all. The tools were the seven native schemas
parsed from `src/core/tool_catalog.ail`. There were three calls:

| user message | `native_finish_reason` | completion tokens | output |
|---|---|---|---|
| "Find out what make check_core runs in this repo and tell me." | `tool_use` | 83 | `<plan>Search the Makefile for the check_core target, read it, and report what it runs.</plan>` then `Search {"pattern": "check_core"}` |
| "Is there a demo target in the Makefile? If so, tell me what it does." | `tool_use` | 101 | `<plan>Search the Makefile for a demo target, read it, and explain it.</plan>` then `Search {"pattern": "demo", "dir": "."}` |
| "Who are you?" | `end_turn` | 78 | `<plan>…</plan>` then "I am Motoko, a highly experimental agent harness runtime. My core is written in AILANG." |

None was refused. Every response opened with a well-formed `<plan>` block. The identity reply now
reads correctly.

**TUI** (no `.ts` changed). `bun node_modules/.bin/jest src/ui.think-tags.test.ts` gives 9/9
passed. The full `bun run test` gives **481 tests passed, 0 failed**, with 46 suites passed and
4 failed. The 4 suites (`env-server`, `compose-output-validator`, `compose_guard_semiformal`,
`scratchpad/loopback`) fail at load with `TypeError: callSite.getFileName is not a function` in
`node_modules/depd`. PR #317 recorded the same failure on unmodified `main`.

**Claims checked against the tree.** Each corrected claim's row above gives the `file:line` it was
checked against. The six tool names and their arguments were compared with
`src/core/tool_catalog.ail` and `src/core/tool_runtime.ail`: the `start`/`end` defaults 1 and 200,
`rg` for `Search`, `bash -lc` wrapping, the `replace_all` and match-count errors. `make check_core`
and `make verify_core` both exist (`Makefile:2703`, `:3387`).

No `.ail` file changed, so `make check_core` is not affected by this diff and was not run.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
