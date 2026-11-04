---
repo: arniwesth/motoko_agent
pr: 317
branch: fix/system-prompt-plan-tag
ticket: null
title: "fix(prompt): the plan block is a plan, not the model's reasoning"
---

## Summary

`SYSTEM.md` opened with a block mandating that every response begin with a `<thinking>` block
holding "your internal reasoning process". Anthropic's platform classifier reads that as an attempt
to extract model reasoning and blocks the request outright, so `claude-opus-5.5` via OpenRouter
refused every call — three sessions on 2026-11-04 died at step 2 without a word. The block is
rewritten around a `<plan>` tag that describes a plan, and the TUI learns the third spelling so
nothing about rendering changes.

## Changes

- fix(prompt): the plan block is a plan, not the model's reasoning
- feat(tui): the think panel recognises <plan>

3 files changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/PLAN-empty-stop-guard.md` and
  `ADR-001-harness-policy-boundary.md` — the guard that masked this did exactly what it specifies.
  Its input was wrong, not its logic: at the point where it decides, a blocked request is
  indistinguishable from a silent model, so it nudged twice and finalised. Nothing here changes the
  guard.
- `.agent/projects/028_verified_runtime_closing_the_loop/NOTE-005-third-session-compaction-blind-spot-and-ungated-examples.md`
  — the same shape of failure one layer down: an absent input read as "no problem detected". This
  one ends in `run_summary.finish_reason: "stop"` with `error: ""` for a run in which every
  provider call was refused and 29,736 input tokens were billed for zero output.

## Predicted outcome

A session on the default profile reaches step 1 with content instead of dying at step 2, and the
mandated block folds into the think panel exactly as `<thinking>` did, for every model. Checked by
starting a session on `openrouter/anthropic/claude-opus-5.5` and seeing a tool call rather than
three empty steps.

What this does **not** fix: a refusal is still invisible if one happens again for another reason.
AILANG drops the `refusal` string and maps `content_filter` to an errorless `finish_reason:
"error"` — filed upstream as sunholo-data/ailang#2123. Until that lands, any future block on any
model will again look like a model that chose to say nothing.

## Test evidence

**Live, `openrouter.ai/api/v1`, `anthropic/claude-opus-5.5`** — this branch's preamble bytes plus
the real 12,307-char system prefix, streamed, with tool definitions, twice:

```
run 1: native_finish_reason=tool_use  completion_tokens=317  reasoning chunks=19
run 2: native_finish_reason=tool_use  completion_tokens=371  reasoning chunks=13
```

Both emitted a well-formed block before the tool calls, e.g.

> `<plan>`Look in the repo for an existing demo entry point (Makefile targets, scripts, docs). If I
> find a long demo, run it and report what it printed. If several exist, or a demo needs
> credentials or an interactive TUI, say so instead of guessing.`</plan>`

**Why both edits are load-bearing.** Six narrower rewordings of the old block were measured the
same way; none lifted the block:

| System prompt | `native_finish_reason` |
|---|---|
| old preamble + rest (2 runs) | `refusal` |
| old preamble alone | `refusal` |
| old preamble alone, 6 variants: MANDATE sentence dropped; "internal reasoning process" reworded; example removed; tag renamed to `<plan>`; tag renamed to `<reasoning>` | `refusal` (6/6) |
| rest only, preamble deleted | `end_turn`, normal content |
| **this branch's preamble + rest (2 runs)** | **`tool_use`, tool calls + `<plan>` block** |

The refusal text is the same every time: *"This request was blocked as it seems to violate
Anthropic's Terms of Service restrictions on reverse engineering or duplicating model outputs."*

Caveat on that fixture: a system prompt consisting of *only* such a block is refused even after
rewriting, so block-alone is a reliable trigger but not a clean A/B. The two `end_turn` rows are
the controls.

**TUI.** `cd src/tui && bun run build` → `tsc` clean. `bun run test` → **478 passed, 3 failed;
45 suites passed, 5 failed.** `ui.think-tags.test.ts` contributes 9 passing cases: the new tag on
all three functions, both old spellings, the last-block rule, the `<p>` guard, and the
cross-convention `<plan>a</thinking>` pairing.

Neither failing group is this diff:

- **Four suites** (`env-server`, `compose-output-validator`, `compose_guard_semiformal`,
  `scratchpad/loopback`) fail at *load*, before any test runs:
  `TypeError: callSite.getFileName is not a function` in `node_modules/depd` ←
  `body-parser` ← `express`, under bun. All four fail the same way on unmodified `main` in the
  shared checkout, same `express@4.22.1`. Pre-existing.
- **`runtime-process.cancel.test.ts`** failed its 3 rows after 240.8 s — its
  `START_BUDGET_MS`. It spawns the real runtime, which compiles the core cold in a fresh worktree
  because `.ailang/` is gitignored and does not come with one. Warm, it passes both ways: 3/3 in
  15.9 s with this branch, and 3/3 in 85.4 s with `SYSTEM.md` and `ui.ts` reverted to `main`. A
  cold-cache artifact of the worktree, not the change.

No `.ail` file changes, so `make check_core` is unaffected by this diff.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
