# 2026-04-23 Compose + Rebase-Forward Follow-up Summary

## Scope
Session focused on finishing Phase 6 documentation status and fixing multiple Composer regressions in Motoko/AILANG integration.

## Reported Regressions
1. `Reason about core` no longer triggered `Compose`.
2. After initial fix, Compose triggered but stalled at single-object JSON tool call.
3. Compose then ran but failed with repeated:
   - `empty snippet returned by subagent (missing ```ailang fence or empty body)`
4. Composer "streaming not working" even when fallback execution succeeded.
5. Composer system prompt was only a minimal 2-line stub, missing the full teacher prompt.

## Changes Applied

### 1) Compose routing/runtime recovery (`src/core/rpc.ail`)
- Restored Compose execution path via `exec_compose_stream`.
- Added Compose call splitting/handling so Compose calls are executed before other tool paths.
- Added helper flow for Compose result construction and handling.

### 2) Env server Compose endpoints restored (`src/tui/src/env-server.ts`)
- Reinstated `/exec-ailang` and `/compose` behavior.
- Reconnected compose loop (author/check/run/retry/result NDJSON events).

### 3) Parse robustness for single-tool JSON root (`src/core/parse.ail`, `src/core/parse_test.ail`)
- Added support for root object tool-call payloads like:
  - `json {"tool":"Compose", ...}`
- Added parser tests; parse suite passed.

### 4) Compose snippet extraction hardening (`src/tui/src/env-server.ts`)
- Expanded extraction beyond strict ```ailang-only matching:
  - explicit ` ```ailang ` fence
  - generic fenced code if code-like
  - unfenced code fallback if code-like and includes `export func main`
- Added repeated-empty early-stop logic.

### 5) Authoring failure visibility + fallback (`src/tui/src/env-server.ts`)
- Added explicit `compose_author_error` events.
- On streaming author failure, fallback to non-stream author call in same attempt.
- Included compact failure details to avoid opaque "empty snippet" diagnosis.

### 6) Composer streaming fixes (`src/tui/src/env-server.ts`, `src/tui/src/runtime-process.ts`, `src/tui/src/ui.ts`, `src/tui/src/index.ts`)
- Fixed stream helper snippet import to use:
  - `import std/ai_motoko (callStreamResult)`
- Fixed stream helper type error:
  - replaced invalid string concatenation (`++`) with string interpolation for result marker line.
- Expanded stream delta parsing compatibility:
  - event types: `thinking_delta`, `assistant_delta`, `text_delta`
  - delta fields: `text_delta`, `delta`, `text`
- Added UI/plain-logger support for `compose_author_error` so stream-path failures are visible live.

### 7) Phase 6 plan status update (`.agent/plans/Motoko_AILANG_Rebase_Forward.md`)
- Added explicit `Status: Completed on 2026-04-21` with evidence pointers under Phase 6.

### 8) Composer system prompt source-of-truth fix (`src/core/rpc.ail`)
- Implemented loading of full teacher prompt directly from root file:
  - `v0.12.1.md`
- Compose now passes full file contents verbatim as `system_prompt` (with fallback to legacy stub if file missing).

## User-Confirmed Outcomes
- Compose now triggers and executes.
- Composer streaming now works after stream-helper fixes.
- Composer now uses full teacher prompt from `v0.12.1.md` (not a derived prompt).

## Additional Policy/Surface Check
- User flagged four AILANG files lacking motoko fence markers.
- Verified these files currently have no net staged divergence vs `v0.13.0` baseline (inside `ailang/`), so no marker insertion was required for those specific files in their current state.

## Validation Executed During Session
- `./ailang/bin/ailang check src/core/parse.ail` (via tests)
- `./ailang/bin/ailang test src/core/parse_test.ail` (passed)
- `./ailang/bin/ailang check src/core/prompts.ail` (passed after reversion/final wiring)
- `./ailang/bin/ailang check src/core/rpc.ail` (passed)
- `npm --prefix src/tui run -s build` (passed repeatedly after each major patch)

## Key Files Touched in Session
- `src/core/rpc.ail`
- `src/core/prompts.ail`
- `src/core/parse.ail`
- `src/core/parse_test.ail`
- `src/tui/src/env-server.ts`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/ui.ts`
- `src/tui/src/index.ts`
- `.agent/plans/Motoko_AILANG_Rebase_Forward.md`

