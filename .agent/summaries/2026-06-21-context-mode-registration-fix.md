# Context Mode Registration Fix Session

Date: 2026-06-21
Branch: `arniwesth/mot-12-fix-context-mode`

## Summary

Investigated why the `context_mode` extension was listed in
`.motoko/config/observability/config.json` but did not appear in Motoko's
available tool list. The extension boot probe succeeded, so the issue was not
profile loading or generated registry resolution. The actual root cause was the
published `sunholo/motoko_ext_context_mode@0.2.2` package: its `register.ail`
was a stub returning `provided_tools: []`, `on_describe_tools: []`, and no-op
hooks, even though the package contained a real `context_mode.ail`
implementation with `Ctx*` / `ctx_*` tools.

## Changes Made

- Added a versionable local package override at
  `packages/motoko-ext-context-mode/`.
- Pointed `ailang.toml` at the local context-mode package instead of the broken
  registry package.
- Added a fixed `register.ail` that wires:
  - `provided_tools()`
  - context-mode prompt patching
  - Bash policy denial for raw `context-mode` / `ctx_*` probes
  - direct `Ctx*` / `ctx_*` tool handling
  - final-output indexing
- Regenerated `ailang.lock`.
- Removed stale `sunholo/motoko_ext_autoresearch` references from the active
  dependency graph after moving the work to a branch without autoresearch, so
  `make run` works on this branch.
- Added `packages/motoko-ext-context-mode/README.md` explaining that
  `context_mode` wraps <https://github.com/mksglu/context-mode> and documenting
  two demo prompts:
  - architecture trace
  - debugging investigation
- Wrote PR notes to `.agent/prs/mot-12-fix-context-mode.md`.

## Verification

- `MOTOKO_CONFIG=observability make verify_extensions`
  - verified `compaction_ai`, `context_mode`, `exa_search`, and `scratchpad`.
- `make build`
  - passed package sync, extension boot probes, core AILANG checks, and TUI
    TypeScript build.
- `timeout 20s make run PROFILE=observability TASK='Say ready and stop.'`
  - started successfully and reported:
    `loaded_extensions=compaction_ai, context_mode, exa_search, scratchpad`.
- Direct runtime catalog probe confirmed advertised context-mode tools including
  `CtxDoctor`, `ctx_doctor`, `CtxStats`, `ctx_stats`, `CtxIndex`, `ctx_index`,
  `CtxSearch`, `ctx_search`, `CtxFetchAndIndex`, and `ctx_fetch_and_index`.

## Follow-Up

The upstream `sunholo/motoko_ext_context_mode` package should be updated and
republished with the fixed `register.ail`. Once that is available, Motoko can
drop the local path override and return to a normal registry dependency.

## Notes

- Unrelated untracked directories `ailang/` and `oh-my-pi/` were present and
  left untouched.
- A ClickStack `401 Unauthorized` trace-export warning appeared during one
  direct probe when tracing was configured without auth; it did not affect the
  context-mode checks.
