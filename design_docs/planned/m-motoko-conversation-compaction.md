# M-MOTOKO-CONVERSATION-COMPACTION

**Status**: Planned  
**Priority**: P1 — gates long-running Phoenix-architecture agents  
**Estimated effort**: 3-4 days  
**Dependencies**: `context_limit_for` table complete (✅ fixed in PR #4), DP0 pre-step hook (see below)  
**Source**: motoko-explore inbox msg `6ef7406b` (2026-05-06)

---

## Problem

motoko has output-level compression (`compress_output`) and context-usage telemetry (`estimate_tokens`, `context_limit_for`) but **no conversation-level compaction**. When the cumulative message list approaches the model's context window, motoko sends the request anyway and fails at the provider with no recovery path.

The practical ceiling for long-context dogfood tasks on smaller-window models is ~50-80 steps regardless of `max_steps` setting:

| Model | Window | Steps before overflow (est.) |
|-------|--------|------------------------------|
| GLM-5 (128k) | 128k | ~40-50 steps |
| Sonnet (200k) | 200k | ~65-80 steps |
| Gemini 2.5 Pro (2M) | 2M | ~650+ steps |

The Phoenix-architecture promise — long-running self-modifying agents at `max_steps=150+` — is gated on this.

---

## Goals

1. Prevent provider-side context overflow by proactively compacting old turns
2. Degrade gracefully: deterministic structural compaction first, no extra LLM calls required
3. Keep compaction policy pluggable — default is conservative, extension can override
4. Zero behaviour change for short-context tasks (< 60% window usage)

---

## Design

### New dispatch point: DP0 (pre-step trim)

Add a `dispatch_pre_step` hook that fires **before** each LLM call, receiving the current message list and returning a (possibly trimmed) replacement:

```ailang
type PreStepDecision
  = PassThrough
  | Compacted(msgs: [Msg], note: string)

-- Extension hook signature
type PreStepHook = ([Msg], string, string) -> PreStepDecision ! {AI}
--                  msgs   system  model
```

The core loop calls `dispatch_pre_step(msgs, system, model)` before building the request. If any registered hook returns `Compacted`, the returned `msgs` replaces the input for this step only — the session log is unchanged.

### Default compaction policy (in `src/core/compaction.ail`)

Three thresholds, applied in order:

| Usage | Action |
|-------|--------|
| > 70% | Elide tool_result content older than last 10 turns: replace with `[ReadFile foo.ail elided — was 1240 lines]` |
| > 85% | Drop tool_result bodies older than last 5 turns entirely (keep assistant text) |
| > 95% | Refuse to step; emit `compaction_exhausted` event; return error to caller |

Usage = `estimate_tokens(msgs, system) / context_limit_for(model)`. If `context_limit_for` returns 0 (unknown model), skip compaction entirely — fail open.

### Structural compactor (no extra LLM call)

```ailang
pure func elide_old_tool_results(msgs: [Msg], keep_last: int) -> [Msg]
```

Walks `msgs` in reverse, keeps the last `keep_last` tool_result entries intact, replaces older ones with a one-line summary derived from the content structure (file path if present, char count, first line).

This is deterministic, type-checkable, and costs nothing at runtime.

### Optional: AI summarisation hook

An extension (`motoko-ext-compaction-ai`) can register a `PreStepHook` that calls a cheap model to produce a prose summary of old turns. This upgrades the quality of compacted context without baking a dependency on AI into the core.

---

## Files

| File | Change |
|------|--------|
| `src/core/agent_loop_v2.ail` | Add DP0 `dispatch_pre_step` call before each step |
| `src/core/compaction.ail` | New — default policy + structural elider |
| `src/core/ext/types.ail` | Add `PreStepHook` to `ExtensionHooks` |
| `src/core/ext/registry.ail` | Wire `dispatch_pre_step` to registered hooks |
| `src/core/context_usage.ail` | Already fixed (PR #4) |

~250-350 LOC new code, ~30-50 LOC loop changes.

---

## Acceptance criteria

- [ ] `elide_old_tool_results` unit tests: elides beyond keep_last, preserves recent, handles empty list
- [ ] Agent loop test: at 75% usage, tool_results older than last 10 turns are elided
- [ ] Agent loop test: at 90% usage, tool_result bodies older than last 5 turns are dropped
- [ ] Agent loop test: at 96% usage, step is refused with `compaction_exhausted` event
- [ ] Unknown model (context_limit_for returns 0) → compaction skipped, step proceeds normally
- [ ] Compaction is transparent to session JSONL (original msgs logged, compacted view is per-step only)
- [ ] Extension can register a `PreStepHook` and it is called before the default policy
- [ ] Verified end-to-end in motoko_explore with GLM-5 at `max_steps=100`

---

## Open questions

1. **DP0 positioning**: should `dispatch_pre_step` be part of the existing 6-DP dispatch contract or a new named hook? The existing DPs use a "first-matching wins" model for some and "union" for others. Pre-step trim is naturally a transform (union of all registered hooks applied in order).
2. **motoko-ext-compaction vs core**: since no sensible default exists today and the structural compactor is small, making it core (always-on, no-op at < 70%) is simpler than shipping an extension that everyone needs to add.
3. **Interaction with `motoko-ext-compaction` from extensions-as-packages proposal**: if extensions become packages (separate design doc), the AI-summarisation variant ships as a package. The structural variant stays in core.

---

## Test plan (motoko_explore)

```bash
# Run a task that exceeds 80 steps on GLM-5 (128k window)
# Before this fix: provider error at ~50 steps
# After: compaction fires at step ~35 (70% threshold), agent continues to 100+
```
