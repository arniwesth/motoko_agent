# TUI Context Window Counter Plan

Date: 2026-04-24
Status: Proposed

## Goal

Show the user how much of the active model's context window the running
conversation is consuming, rendered in the TUI status bar as
`ctx: 12.3k/200k (6%)`.

The counter is a **local estimate** — chars ÷ 4 across the full composed
system prompt + message history — not provider-reported usage. Accuracy is
±20%, which is good enough to answer "am I about to run out?" without
touching the vendored `ailang/` fork or per-provider adapters. Upgrading
to real `usage.input_tokens` from the AI effect is a later, separate effort.

## Expected File Changes

### Modified files

- `src/core/rpc.ail` — compute estimate each step, emit new JSONL event
- `src/tui/src/runtime-process.ts` — type + forward the new event
- `src/tui/src/ui.ts` — track latest estimate, render in status bar
- `README.md` — document the counter under the status-bar description

### Added files

- `src/tui/src/ui.context-counter.test.ts` — rendering + formatting tests
- `src/core/context_usage.ail` — pure token-estimate helper with inline tests
- `src/core/context_usage_test.ail` — companion test file for cases whose
  inputs involve `Msg` ADT values (mirrors the `parse.ail` / `parse_test.ail`
  split described in README.md:301–331)

Note: `src/tui/src/models.ts` is deliberately **not** modified. The runtime
owns the per-model context-window table and emits `limit` in the JSONL
event — the TUI just renders whatever it's told. One source of truth.

## Protocol addition

New runtime → TUI event on stdout:

```json
{"type":"context_usage","step":3,"tokens_est":12345,"limit":200000}
```

- `tokens_est` = `(total_chars + 3) / 4` (integer ceil), where `total_chars`
  sums `length(composed_system) + sum(length(m.content) for m in state.msgs)`.
  `composed_system` is the **final** system string passed to `call` —
  i.e. the output of `with_cache_hint` / `with_agents_context` in
  `prompts.ail`, not `base_system()` — so injected cache hints and
  AGENTS.md context are included.
- `limit` comes from `context_limit_for(model)` in `context_usage.ail`.
  Returns `0` for unknown models; the TUI treats `0` as "hide the ratio".
  When `model` starts with `openrouter/`, strip the prefix and recurse so a
  user on `openrouter/anthropic/claude-sonnet-4-5` still sees the 200K limit.
- Emitted **once per loop iteration**, at the top of `run_ailang_step` /
  `run_step`, after the history is stable for that turn. One call site,
  no hunting for `msgs:` updates.

## Phase 1: Runtime estimate (AILANG side)

1. **`src/core/context_usage.ail`** — new module
   - Imports:
     - `import std/string (length)` — for char count
     - `import std/list (foldl)` — for the running-sum fold
     - `import src/core/types (Msg)` — for the message record type
     - `import std/string (startsWith, substring)` — for the
       `openrouter/` prefix-stripping case in `context_limit_for`
     Do **not** also import `std/list.length` in this module — it would
     collide with `std/string.length`. Use the lambda in `foldl` to sum
     lengths, never calling `list.length`.
   - `pure func estimate_tokens(msgs: [Msg], system: string) -> int`
     (no `! {}` — `pure func` already means effect-free)
     - `let total = length(system) + foldl(\acc m. acc + length(m.content), 0, msgs) in (total + 3) / 4`
   - `pure func context_limit_for(model: string) -> int`
     - Use an `if / else if` chain on string equality — AILANG `match` does
       not pattern-match on string literals.
     - Known mappings:
       - `anthropic/claude-sonnet-4-6`, `claude-opus-4-6`, `claude-haiku-4-5` → `200000`
       - `openai/gpt-4o`, `gpt-4o-mini` → `128000`
       - `google/gemini-2.5-flash` → `1000000`
       - `google/gemini-2.5-pro` → `2000000`
     - If none match **and** `startsWith(model, "openrouter/")`, recurse with
       the prefix stripped (`substring(model, length("openrouter/"), length(model))`)
       so Claude/GPT/Gemini routed via OpenRouter still resolve.
     - Otherwise → `0`.
   - Inline `tests [...]` on both functions with primitive expected values
     (only the empty-msgs cases — anything with a non-empty `[Msg]` input
     lives in `context_usage_test.ail`).
   - Acceptance: `ailang test src/core/context_usage.ail` passes.

2. **`src/core/rpc.ail`** — wire emission
   - `import src/core/context_usage (estimate_tokens, context_limit_for)`.
   - Add
     `emit_context_usage(state: AgentState, system: string, model: string) -> () ! {IO}`
     that builds and emits the JSONL object described above. The `model`
     parameter is required because `AgentState` (rpc.ail:66–68) does not
     carry the model string — it's threaded through the loop separately.
   - **Call site(s)**: invoke once per loop iteration, just after `system` is
     composed and before `call` is invoked. Verify during implementation
     whether the loop has a single outer dispatcher or whether each branch
     (`proposed_ailang` ~L561, `proposed_cmd` ~L702, `tool_calls` ~L925,
     `ext_tool_calls` ~L876, `native_tool_calls` ~L886) is entered
     independently. If single dispatcher: one call. If per-branch: accept
     3–5 call sites and keep the helper small.
   - Acceptance: running the agent prints one `context_usage` line per step
     on stdout; `tokens_est` grows monotonically within a session.

## Phase 2: TUI plumbing

3. **`src/tui/src/runtime-process.ts`**
   - Add `context_usage` to the discriminated-union event type:
     `{ type: "context_usage"; step: number; tokens_est: number; limit: number }`.
   - Forward through the existing event callback; no other changes.
   - Acceptance: existing stream-protocol tests still pass; add a parse case
     for the new event shape.

4. **`src/tui/src/ui.ts`**
   - Store `private latestContextUsage?: { tokensEst: number; limit: number }`.
   - Set it in the event handler when `event.type === "context_usage"`.
   - Extend `updateStatus()` (ui.ts:3151). Append to `line2` after
     `model: ...`:
     ```
     | ctx: 12.3k/200k (6%)
     ```
     - Helper `formatCount(n)`:
       - `n < 1000` → `"${n}"`
       - `1_000 ≤ n < 1_000_000` → `"${(n/1000).toFixed(1)}k"`
       - `n ≥ 1_000_000` → `"${(n/1_000_000).toFixed(1)}M"`
     - When `limit === 0`, render only `ctx: 12.3k` (no `/limit (%)`, no `NaN`).
     - Threshold colors: **yellow** at ≥75%, **red** at ≥90%, else inherit
       state color. **Chalk note**: the current code does `statusBar.setText(color(text))`
       which wraps the whole string in a single style, and nesting chalk
       colors inside that string leaks the outer reset. Fix by building
       `line2` as two assembled pieces — the pre-ctx portion wrapped in the
       state color, then the ctx segment wrapped in its own threshold color
       (or `color` if no threshold is crossed) — and concatenating them
       outside the outer `color(...)` wrap. Do **not** pass a string with
       embedded chalk codes into another `color(...)` call.
   - Acceptance: `npm test` (tui) passes including new counter tests.

## Phase 3: Tests & docs

5. **`src/tui/src/ui.context-counter.test.ts`**
   - `formatCount`: 999 → "999", 1000 → "1.0k", 12345 → "12.3k",
     1_000_000 → "1.0M", 2_000_000 → "2.0M".
   - Status line renders `ctx: 12.3k/200k (6%)` when limit known.
   - Status line omits `/limit (%)` when limit === 0.
   - Color escalates at 75% / 90% thresholds (assert on the wrapped segment,
     not the full line).

6. **`src/core/context_usage.ail`** inline tests
   Inline `tests [...]` entries use `((args_tuple), expected)` form per
   README.md:328. Inputs with empty `[Msg]` stay in this file; anything
   with a populated message list goes into `context_usage_test.ail`.
   - `estimate_tokens`:
     - `(([], ""), 0)`
     - `(([], "abcd"), 1)`   — 4 chars, `(4+3)/4 = 1`
     - `(([], "abcde"), 2)`  — 5 chars, `(5+3)/4 = 2`
     Note: the empty-list literal `[]` may need an explicit type annotation
     inside a `tests` tuple if inference fails; fall back to a tiny wrapper
     `pure func est0(sys: string) -> int = estimate_tokens([], sys)` and
     test that instead.
   - `context_limit_for`:
     - `(("anthropic/claude-sonnet-4-6"), 200000)`
     - `(("google/gemini-2.5-pro"), 2000000)`
     - `(("openrouter/anthropic/claude-sonnet-4-5"), 200000)` — prefix stripped
     - `(("openrouter/whatever"), 0)`
     - `(("totally-unknown"), 0)`

7. **`src/core/context_usage_test.ail`** — companion tests with non-empty `[Msg]`
   Thin wrappers that take primitive inputs, construct `Msg` values inside,
   and assert primitive outputs (same shape as `parse_test.ail`). At minimum:
   - `sum_of_two(a: string, b: string) -> int` that calls
     `estimate_tokens([Msg("user", a), Msg("assistant", b)], "")` and returns
     the token count, with a couple of `tests` entries pinning the arithmetic.

8. **README.md**
   - One-line addition under the status-bar description: explain the counter,
     call out that it's a local estimate (±20%) not provider-reported.

## Non-goals

- Real provider token counts via `std/ai` return shape — deferred.
- Tokenizer-accurate estimates (tiktoken / claude-tokenizer) — chars ÷ 4 is
  deliberately dependency-free.
- Showing cached-prompt savings — requires real provider usage.
- Per-step delta display — the absolute number is what users need.
- Dynamic limit lookup for `openrouter/*` — would need a second API call;
  `0` (hidden ratio) is acceptable for v1.

## Open question

Mid-session `/model` switches: the status bar's `this.model` updates on the
next runtime invocation (per README §5), so `latestContextUsage.limit`
stays consistent with the displayed model. No special handling needed, but
worth confirming during manual testing.

## Acceptance Criteria

1. `ailang test src/core/context_usage.ail` — new inline tests pass.
2. `cd src/tui && npm test` — new counter tests pass; no regressions.
3. Running the agent against any supported model shows a live `ctx:` segment
   that updates every step.
4. Running against `openrouter/<unknown>` shows `ctx: 12.3k` with no ratio
   (no crash, no `NaN%`).
5. At ≥75% / ≥90% of limit, the ctx segment visibly yellows / reds.
