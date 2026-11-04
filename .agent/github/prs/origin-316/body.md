---
repo: arniwesth/motoko_agent
pr: 316
branch: fix/catalog-opus-5-5-window
ticket: null
title: "fix(catalog): context window for claude-opus-5 and 5.5"
---

## Summary

The default profile runs `openrouter/anthropic/claude-opus-5.5`, and the model appeared in
neither `context_limits` nor any profile's `agent.context_limit`. Startup therefore warned that
the context limit is unknown, and with no window `compaction_ai` and `compaction_structural`
cannot trigger at all — the exact fail-open measurement boundary 028 NOTE-005 recorded for
`openrouter/tencent/hy4-preview`, recurring for the model the default profile now uses. This
adds the two missing catalogue rows.

## Changes

- fix(catalog): context window for claude-opus-5 and 5.5

1 file changed.

## Governing docs

- `.agent/projects/028_verified_runtime_closing_the_loop/NOTE-005-third-session-compaction-blind-spot-and-ungated-examples.md`
  — the same blind spot, measured end to end: one absent catalogue row becomes 0% usage on every
  poll and compaction that is installed, booting and doing nothing.
- `.agent/projects/013_core_architecture_for_dst/ADR-001-sequencing-the-dst-architecture-caps.md`
  §P1 — `CatalogueMiss`/`ModelNotInCatalogue`, the named miss that turns this silence into the
  startup warning this PR answers.

## Predicted outcome

The startup warning for `openrouter/anthropic/claude-opus-5.5` stops, `MotokoRuntimeStatus`
reports `context_limit: 1000000` instead of `0`, and the two compaction extensions have a window
to compare against. Checked by a session on the default profile starting without the warning and
reporting a non-zero `usage_pct`.

Values are OpenRouter's own: `GET https://openrouter.ai/api/v1/models` reports
`context_length: 1000000` and `top_provider.context_length: 1000000` for both
`anthropic/claude-opus-5.5` and `anthropic/claude-opus-5` (read 2026-11-04).

Both rows are stored unprefixed. `lookup_context_limit` (`src/core/context_usage.ail:79`) strips a
leading `openrouter/` before its second attempt, so one row serves the direct and the
OpenRouter-routed identifier. `anthropic/claude-opus-5` is included because the same warning would
fire for it and the same API response answers it; no other model is touched.

## Test evidence

`catalog_context_limit_for` run against this branch's catalogue, via a throwaway probe script
(`ailang run --caps IO,FS,Env`, since the change is data read by the effectful path, not code):

```
openrouter/anthropic/claude-opus-5.5 -> 1000000
anthropic/claude-opus-5.5            -> 1000000
openrouter/anthropic/claude-opus-5   -> 1000000
```

Before the change the same probe returns `0` for all three. `python3 -c "json.load(...)"` parses
the file. No `.ail` or `.ts` file changes, so `make check_core` and the test suites are unaffected
by this diff.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
