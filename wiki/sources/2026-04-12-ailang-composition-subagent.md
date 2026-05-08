# AILANG Composition Subagent — Extended Implementation Summary

**Date:** 2026-04-12  
**Primary plan:** `.agent/plans/AILANG_Composition_Subagent.md`  
**Baseline context:** `.agent/summaries/2026-04-11-ailang-composition-language.md`

## Scope of this implementation pass

This pass extended the previous Compose/subagent rollout with:

1. true runtime-side streamed `/compose` transport (line-by-line forwarding)
2. intent-preserving handoff (raw user prompt as primary objective)
3. higher retry budget defaults and retry-policy fixes
4. output-contract enforcement and stdout-elision behavior hardening
5. richer TUI compose UX (live draft, error contrast, width-safe error boxes, expansion policy)
6. telemetry for compose outcomes
7. anti-fabrication controls for analysis-style snippets
8. hint policy inversion (hints optional and disabled by default)
9. prompt calibration to preserve Compose triggering for broad architecture reasoning tasks

---

## Major behavior changes

### 1) Compose transport now streams live from runtime

**Problem before:** `/compose` emitted NDJSON incrementally, but runtime consumed it via buffered request flow, so `compose_*` events reached TUI only after completion.

**Implemented:**
- Added streaming primitive in `src/core/env_client.ail` using `asyncExecProcess("curl", ["-N", ...])` and line assembly.
- `run_compose_tool` in `src/core/rpc.ail` now uses this streaming path and forwards each incoming NDJSON line immediately to runtime stdout.

**Result:** `compose_author_delta`, `compose_check`, `compose_retry`, etc. are visible in-flight in TUI.

---

### 2) Intent-preservation fix: raw trigger prompt is primary objective

**Problem before:** planner-derived intent could narrow scope vs user’s original request.

**Implemented:**
- Added `trigger_prompt` field in compose payload from runtime -> env-server.
- Runtime derives last user prompt and forwards it with Compose request.
- Author prompt in env-server now explicitly sets:
  - **Primary objective:** verbatim user trigger prompt
  - **Compose guidance:** planner scaffold (non-binding)
  - Scope guardrails against strict-subset narrowing.

**Result:** Compose subagent aligns to original user intent; planner narrowing is guidance only.

---

### 3) Retry budget defaults increased

Default `AILANG_SUBAGENT_MAX_ATTEMPTS` fallback changed from `20` -> `50` in both:
- runtime (`src/core/rpc.ail`)
- env-server (`src/tui/src/env-server.ts`)

This raises probability of eventual valid snippets for research/debug workloads.

---

### 4) Retry policy corrected for runtime execution failures

**Problem observed:** compose could stop early at attempt N with `exit=1` after first check-pass/run-fail.

**Implemented:**
- Nonzero `ailang run` exits are now treated as retryable within `/compose` loop.
- Emits `compose_exec`, then `compose_retry`, then continues attempts until success or max.
- Runtime failure context (stderr/stdout slices + directive) is appended to priorErrors to improve next author attempt.

**Result:** no premature termination on first runtime failure after type-check success.

---

### 5) Output-contract and stdout policies (Phase 3b completion)

Implemented deterministic expected-output validator and exit semantics:
- supports structured expected_output contract kinds (`non_empty`, `contains_all`, `lines_regex`)
- if snippet run is 0 but validator is decided+high-confidence unsatisfied => force `exit_code=2`
- free-text expected_output remains inconclusive (no forced code 2)

Stdout handling:
- raw stdout persisted under `.motoko-store/compose/<compose_id>.stdout`
- returned stdout elided above `AILANG_COMPOSE_STDOUT_MAX_BYTES` (default 4000)
- returned payload includes marker pointing to persisted raw output

---

### 6) Compose telemetry

Added compose result telemetry JSON for research/debug analytics:
- attempts started/completed
- author failures
- missing fence/empty snippet
- check failure categories (parse/effect/type/import_or_symbol/other)
- run failures
- validator unsatisfied/inconclusive
- summary failures
- success/exhaustion/final exit/duration

Propagated end-to-end to core types, env client decode, rpc tool result display, runtime-process type, and TUI card rendering.

---

### 7) Subagent author streaming and UI visibility fixes

#### Source streaming
- Added streamed author path in env-server by spawning a small AILANG wrapper using `std/ai.callStreamResult`.
- Parses subprocess stream events and bridges deltas to `compose_author_delta`.
- Added fallback to single buffered delta when stream events are absent.
- Forced `MOTOKO_STREAM_EVENTS=1` for author subprocess to ensure runtime emits stream deltas.

#### TUI rendering fix
- Bug fixed: `authorDelta` was collected but not rendered.
- Compose card now renders live “authoring draft” from `compose_author_delta` before finalized `compose_snippet` arrives.

**Result:** generated AILANG draft is visible during generation, not only at completion.

---

### 8) Error UX improvements in TUI

Requested UI treatment for AILANG errors was implemented and iterated:

1. high-contrast boxed red error blocks for:
   - inline `ailang_check` failures
   - compose attempt `checkErrors`
2. switched from bright aggressive red to darker red background + white text
3. fixed broken rendering on narrow terminals by making box width terminal-aware and wrapping/chunking content to fit CLI width

**Result:** error presentation is readable, high-contrast, and width-safe.

---

### 9) Compose card expansion policy updated

**Requested behavior:** keep streamed snippet/errors visible after successful compose.

**Implemented:**
- compose cards remain expanded by default after `compose_result`
- optional old behavior via `AILANG_SUBAGENT_AUTO_COLLAPSE=1`
- `AILANG_SUBAGENT_VERBOSE` retained for compatibility

---

### 10) Hint policy updated (optional + disabled by default)

**Requested:** hints optional and not defaulted into subagent prompt.

**Implemented in two layers:**

1. Runtime policy gate in `rpc.ail`:
   - hints are stripped by default before `/compose`
   - opt-in via `AILANG_COMPOSE_ENABLE_HINTS=1|true|yes`

2. Env-server author prompt formatting:
   - hint lines are omitted entirely when no hints are provided

Prompt guidance in `src/core/prompts.ail` was updated accordingly (hints optional/omit by default).

---

### 11) Compose triggering regression and fix

After de-emphasizing hints, broad prompt `"Use AILANG tool call system to reason about core"` became less likely to trigger Compose.

**Fix in system prompt:**
- added explicit guidance: for broad repo-understanding tasks (reason about core / architecture / flow), prefer Compose as first tool call
- added concrete Compose example for architecture reasoning (without hints)

---

### 12) Anti-fabrication guard for analysis snippets

Observed regression: model produced simulated architecture narrative rather than evidence-based reads.

**Implemented runtime guard in env-server:**
- rejects snippets containing fabrication markers (e.g., "simulated analysis", "in a real execution", "would read files")
- for analysis-intent prompts, rejects snippets lacking evidence-read primitives (`readFile` or `exec`)
- rejection emits failed `compose_check` + retry with targeted corrective hint

Prompt card also strengthened to forbid simulated/hypothetical analysis text.

---

## File-level implementation highlights

### Core runtime
- `src/core/rpc.ail`
  - compose streaming call path
  - trigger prompt forwarding
  - hints disabled-by-default policy gate (`AILANG_COMPOSE_ENABLE_HINTS`)
  - default retries set to 50

- `src/core/env_client.ail`
  - streaming `/compose` transport
  - `trigger_prompt` passthrough in compose payload

- `src/core/prompts.ail`
  - compose contract updates (hints optional/omit-by-default)
  - Compose-trigger guidance for architecture reasoning
  - subagent anti-fabrication prompt hardening

- `src/core/types.ail`
  - compose telemetry field threading

### TUI / env-server
- `src/tui/src/env-server.ts`
  - streamed author subprocess path (`callStreamResult` bridge)
  - `MOTOKO_STREAM_EVENTS=1` for author subprocess
  - output validator + exit code 2 policy + stdout elision/raw persistence
  - run-failure retry continuation
  - anti-fabrication snippet guard
  - default max attempts set to 50

- `src/tui/src/ui.ts`
  - Compose card renderer enhancements (live author draft)
  - high-contrast error boxes (darker red + white text)
  - width-safe boxed error rendering
  - expanded-by-default compose completion behavior
  - optional collapse env toggle

- `src/tui/src/runtime-process.ts`
  - compose result telemetry support

### Plan tracking updates
- `.agent/plans/AILANG_Composition_Subagent.md`
  - updated repeatedly to reflect completed phases/partials and policy changes
  - includes notes for: streaming, telemetry, intent-preservation, retry-policy, hint defaults, anti-fabrication guard, UI expansion policy

---

## Verification performed

Repeatedly verified throughout the session:

- Core checks:
  - `ailang check src/core/rpc.ail`
  - `ailang check src/core/env_client.ail`
  - `ailang check src/core/prompts.ail`

- TUI checks:
  - `cd src/tui && npm run build && npm test`
  - all observed runs passed (`12` suites, `70` tests)

---

## Effective runtime defaults after this pass

- `AILANG_COMPOSITION_MODE=subagent`
- `AILANG_SUBAGENT_MAX_ATTEMPTS=50` (fallback default)
- hints disabled by default unless `AILANG_COMPOSE_ENABLE_HINTS=1`
- compose cards expanded after completion by default
- optional old collapse behavior via `AILANG_SUBAGENT_AUTO_COLLAPSE=1`

---

## Notes for next session

1. Add focused tests for new compose guards:
   - anti-fabrication rejection
   - runtime-failure retry continuation
   - hints-disabled policy gate
   - compose auto-collapse env toggle
2. Consider making analyzer-evidence guard stricter with intent/output-contract coupling.
3. Add compact compose telemetry visualization in TUI (optional).

