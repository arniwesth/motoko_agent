# AILANG Composition Language — Implementation Summary

**Date:** 2026-04-11
**Plan:** `.agent/plans/AILANG_Composition_Language.md`
**Branch:** `AILANG_Composition_Language`

## Goal

Add a third execution mode to the Motoko agent where the LLM writes AILANG
snippets (fenced ```ailang blocks) that compose multiple file/search/bash
operations into a single agent step. This sits alongside the existing JSON
tool-call mode and the bash fallback, and is intended for multi-step workflows
(3+ chained operations) where the LLM benefits from AILANG's effect system,
pure data transformations, and pre-execution type-checking.

## End-to-end flow

1. LLM response contains a ```ailang fenced block.
2. `extract_ailang` in `src/core/parse.ail` pulls the body (ignoring fences
   inside `<think>`/`<thinking>` spans).
3. `run_ailang_step` in `src/core/rpc.ail` POSTs the code to
   `/exec-ailang` on the embedded env-server.
4. Env-server writes a uniquely-named temp module, runs `ailang check`, and if
   the check passes runs `ailang run --caps <...> --entry main` inside the
   workdir sandbox (`AILANG_FS_SANDBOX=WORKDIR`).
5. Type-check failures return early with `check_passed=false` and `check_errors`
   populated. The runtime gives the LLM up to 3 free retries per step, each
   augmented with a targeted doc section chosen by error category.
6. Successful execution returns `{stdout, stderr, exit_code}` which the runtime
   folds into the message history as a normal observation.

## Files modified

### `src/core/parse.ail`
- Added `extract_ailang(text) -> Option[string]` plus helper
  `extract_ailang_search` that reuses the existing `think_spans`/`in_any_span`/
  `find_from` machinery to skip fences inside think-tags.

### `src/core/parse_test.ail`
- 6 new tests covering basic extraction, missing fence, unclosed fence,
  fence-inside-think, fence-only-in-think, and empty body. Total suite: 53
  passing.

### `src/core/types.ail`
- Added:
  ```
  export type AilangExecResult = {
    stdout: string, stderr: string, exit_code: int,
    check_passed: bool, check_errors: string
  }
  ```

### `src/core/env_client.ail`
- Imported `AilangExecResult` and `asBool` from `std/json`.
- Added `exec_ailang(url, code, caps, timeout_secs) -> AilangExecResult ! {Net}`
  which POSTs to `/exec-ailang` and decodes the response.

### `src/tui/src/env-server.ts`
- New `POST /exec-ailang` endpoint.
- Creates `.motoko-store/` at startup for session-scoped state; registers
  SIGINT/SIGTERM/exit handlers to remove it.
- Writes snippets to `/tmp/motoko-snippets/tmp/snippet_<counter>_<epoch>.ail`,
  strips any LLM-provided `module` line, and prepends the correct module decl.
- Runs `ailang check` (10s) first; on failure returns early with the errors.
- On pass, runs `ailang run --caps <caps> --entry main` with
  `AILANG_FS_SANDBOX=<workdir>`. Temp file cleaned in `finally`.

### `src/core/rpc.ail`
- Added imports: `AilangExecResult`, `exec_ailang`, `extract_ailang`,
  `ailang_error_doc_section`.
- `count_ailang_retries(msgs)` scans the reversed history for
  `"AILANG type-check failed (retry"` markers so retry count survives across
  `rpc_loop` iterations.
- `fmt_ailang_obs(result)` formats snippet output for the message log.
- `run_ailang_step(...)`:
  - Reads `AILANG_SNIPPET_CAPS` (default `IO,FS,Process`).
  - Emits `proposed_ailang` event, then the check result as `ailang_check`.
  - On check_fail with `check_attempt < 3`: appends retry message including
    `ailang_error_doc_section(errors)` and does **not** decrement the step
    budget.
  - On check_fail after 3 attempts: decrements budget, falls back with a plain
    error observation.
  - On success: emits `obs`, runs `is_done` logic like any other step.
- Wired into both `run_legacy_step` (before `extract_bash`) and
  `run_hybrid_step` (after `NoToolCalls`, before solver dispatch).

### `src/core/prompts.ail`
- Imported `contains` from `std/string`.
- `ailang_composition_card()` — ~2K-token system-prompt insert describing:
  mode selection priority, function shape, effect annotations, common imports,
  key syntax patterns, a worked example, and common mistakes.
- `ailang_error_doc_section(errors)` — maps error substrings
  (`"Missing effects"`, `"undefined"`, `"pattern"`, `"let"/"scope"`,
  `"type mismatch"`) to targeted AILANG reference sections.
- Injected card into `base_system()`.

### `src/tui/src/runtime-process.ts`
- Added to `AgentEvent`:
  ```
  | { type: "proposed_ailang"; step: number; code: string }
  | { type: "ailang_check"; step: number; passed: boolean;
      errors: string; attempt: number; max_attempts: number }
  ```

### `src/tui/src/ui.ts`
- Handler for `proposed_ailang` — renders snippet with AILANG syntax
  highlighting via `highlightCodeLines(event.code, "ailang")`.
- Handler for `ailang_check` — green "passed" or red "failed (N/M)" plus the
  first three error lines.

### `src/tui/src/index.ts`
- PlainLogger handlers for the two new events (line count and pass/fail
  status) so non-TTY runs log snippet activity.

## Retry / budget semantics

- First 2 type-check failures per step are **free** (step counter not
  decremented; retry message appended with a doc hint).
- 3rd failure decrements the budget and returns a normal observation so the
  LLM can switch tactics.
- Retry count is re-derived each turn from the message history via
  `count_ailang_retries`, so it remains correct across `rpc_loop` recursion.

## Sandbox / capability surface

- Default caps for snippets: `IO,FS,Process` (override with
  `AILANG_SNIPPET_CAPS`).
- `AILANG_FS_SANDBOX` pins FS operations to the workdir.
- `Net` is intentionally **not** in the default set — snippet code cannot make
  arbitrary outbound requests unless the operator opts in.

## Verification

- `ailang check` clean on `parse.ail`, `env_client.ail`, `rpc.ail`,
  `prompts.ail`.
- `ailang test src/core/parse_test.ail` — 53 passing.
- `ailang test src/core/agents_md_test.ail` — 11 passing.
- `cd src/tui && npm test` — 66 passing (includes new env-server +
  ui.highlight coverage).
- `cd src/tui && npx tsc --noEmit` — clean.

## Deferred / optional

- **Z3 verification of pure snippets** (original plan Phase 5) — not
  implemented; marked optional in the plan.
- **SharedMem trajectory cache for snippets** (Strategy 4) — deferred; the
  existing bash trajectory cache is untouched.
- No caching of successful snippets yet — each invocation re-checks and
  re-runs from scratch.

## How to try it

```bash
make run TASK="List every .ts file under src/tui that imports express, then print each filename with its line count" MODEL=anthropic/claude-sonnet-4-6
```

The model should emit a single ```ailang block chaining `listDir` → `filter`
→ `filterE(readFile + contains)` → `forEachE(split + println)`, which runs in
one agent step instead of 4–6 sequential bash calls.
