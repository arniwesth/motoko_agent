# Code Review: development → use_tui_editor

**Date:** 2026-03-31  
**Reviewers:** 4 agents (parallel)  
**Files changed:** 13 (+1122/-123 lines)  
**Verdict:** PASS — all 5 issues fixed

---

## Executive Summary

This PR introduces a declarative slash-command registry modelled on oh-my-pi's `{ name, description, handle }` pattern, and replaces the TUI's `Input` component with an `Editor` component for slash-command tab-complete. The core implementation is clean and well-typed. All 5 review findings have been fixed.

---

## Issues (all resolved)

### ~~P1 — SIGINT handler broken in TTY mode~~ FIXED
**File:** `tui/src/index.ts`  
**Status:** Added `ui.onAbort = () => brain?.abort()` to the TTY wiring block. Updated comment to reference Ctrl+C alongside /abort.

---

### ~~P1 — `make run` target removed without replacement~~ FIXED
**File:** `Makefile`  
**Status:** Restored `run: build` target calling `./scripts/run-agent.sh $(TASK)`, with documentation comments.

---

### ~~P2 — Version banner printed twice in non-TTY mode~~ FIXED
**File:** `tui/src/index.ts`  
**Status:** Removed `{ version }` parameter from `PlainLogger` constructor; `main()` handles the single version banner. Updated call site to `new PlainLogger()`. Rebuilt dist/.

---

### ~~P2 — `getSuggestions` ignores `AbortSignal`~~ FIXED
**File:** `tui/src/commands.ts`  
**Status:** Added early return `if (options.signal.aborted) return null;` as the first statement in `getSuggestions`. Rebuilt dist/.

---

### ~~P2 — Broken markdown fence in plan doc~~ FIXED
**File:** `.agent/plans/AILANG_Agent.md`  
**Status:** Removed the stray pair of adjacent fences; the code block now opens properly once and closes on the original line.

---

## Scope Notes

- **dist/ files committed to repo:** `tui/dist/*.js`, `tui/dist/*.d.ts`, and their source maps are committed. This is unusual but appears intentional — the Makefile builds against them. Worth discussing whether `dist/` should live in `.gitignore` and be built in CI, or if there's a deliberate reason (e.g., no TypeScript toolchain on deployment targets).
- **References.md:** Two new links added (`elizaOS/eliza`, `remorses/kimaki`). Links are valid.

---

## Positives

- **Clean architecture:** The commands registry is properly decoupled from oh-my-pi's AgentSession/ModelRegistry/MCP stack. `SlashCommandHandlerCtx` exposes only what handlers need.
- **Type safety:** No `any` types or unsafe casts. `AutocompleteProvider` and `SlashCommand` interfaces from `@mariozechner/pi-tui` are correctly conformed to.
- **Test coverage:** `commands.test.ts` covers valid commands, invalid commands, autocomplete edge cases, and command parsing (empty args, quoted args, partial matches).
- **DRY:** Command parsing (`parseSlashCommand`) is a single pure function used by both the autocomplete provider and the dispatch path.

---

## Diff Summary (at time of review)

| # | Severity | File | Description | Effort | Status |
|---|----------|------|-------------|--------|--------|
| 1 | P1 | `tui/src/index.ts` | `ui.onAbort` not wired in TTY branch — Ctrl+C dead | 1 line | FIXED |
| 2 | P1 | `Makefile` | `make run` target removed without replacement | 1-3 lines | FIXED |
| 3 | P2 | `tui/src/index.ts` | Version double-print in non-TTY mode | 1 line | FIXED |
| 4 | P2 | `tui/src/commands.ts` | Autocomplete ignores `AbortSignal` | 2-3 lines | FIXED |
| 5 | P2 | `.agent/plans/AILANG_Agent.md` | Broken markdown fence | 1 line | FIXED |
