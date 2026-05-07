# M-MOTOKO-EVAL-INSTRUMENTATION — JSONL schema for downstream eval harnesses

**Status**: Planned
**Priority**: P0 — **blocking** AILANG's M-MOTOKO-EXECUTOR-ADAPTER (the executor adapter cannot populate `Result.CostUSD` / `Result.InputTokens` without these emissions)
**Estimated effort**: 0.5–1 day (~4–6 hours, ~80–120 LOC of `agent_loop_v2.ail` edits + tests)
**Dependencies**: `motoko-dx-compaction-pending` branch (lands as part of PR #6 against `arniwesth/motoko_agent`)
**Target**: motoko v0.6.x (within current PR cycle)
**Source**: AILANG sprint planning session 2026-05-07; identified during M-MOTOKO-EXECUTOR-ADAPTER design review when actual session JSONL was inspected and found to lack per-step token/cost data and a terminal totals event.
**Related**: AILANG `design_docs/planned/v0_18_0/m-motoko-executor-adapter.md` (consumes this work)

---

## Problem

The session JSONL emitted at `${WORKDIR}/.motoko/logfile/session_<timestamp>.jsonl` is motoko's primary structured output — there is no OTEL emission, no `result.json`, no separate metrics endpoint. The JSONL is the surface every downstream consumer (TUI replay, eval harnesses, debug tooling) parses.

Today the JSONL is **rich on agent-loop semantics** (every tool call, every thinking delta, every gate decision) but **thin on usage telemetry** (token counts and cost) — exactly the data an eval harness needs to compare runs across models.

### Verified gaps (against `agent_loop_v2.ail` HEAD on `motoko-dx-compaction-pending`)

Inspecting a real session (`session_2026-05-07T17-38-27-188Z.jsonl`, 9KB, 16 events):

| Field eval harness needs | Where it lives in motoko today | Why it doesn't reach JSONL |
|---|---|---|
| Per-step `input_tokens` / `output_tokens` | `result.input_tokens` / `result.output_tokens` (line 736) | Used to compute cost; raw counts never emitted |
| Per-step `cost_usd` | `step_cost_millicents(...)` (line 556) | Computed in millicents; never emitted per-step |
| Total `cost_usd` for the run | `total_cost_millicents` accumulator | Only emitted in `cost_warning` (50%/75%/90% thresholds) and `cost_exhausted` — absent on a normal `done`-terminated run |
| Total tokens for the run | not tracked | No cumulative totals |
| Cache token reporting (Anthropic prompt-caching) | not surfaced | upstream API returns it; motoko discards |
| Final `usage` summary event | none | The `done` event has only `output` text + `step` + `source` |
| Top-level `session_id` | embedded in filename only | Parsers shouldn't filename-grep |
| Schema version field | absent | Future shape changes risk silently breaking parsers |

### Comparison: shape every other eval harness consumer expects

`internal/executor/{opencode,pi,codex,claude,gemini}` in AILANG all emit/parse a JSONL where each event carries `tokens.{input, output, cache_read, cache_write, total}` plus `cost` (USD, float). Pi additionally emits a per-message `usage: {input, output, cacheRead, cacheWrite, totalTokens, cost: {input, output, cacheRead, cacheWrite, total}}` block. Opencode emits `tokens` per `assistant` part and `cost` per part.

motoko is the only proposed harness that does NOT emit either today. Adding it puts motoko on equal footing with the rest of the leaderboard.

### Why this blocks M-MOTOKO-EXECUTOR-ADAPTER

The AILANG-side adapter populates `executor.Result` from JSONL events. Without this work, `Result.CostUSD = 0`, `Result.InputTokens = 0`, `Result.OutputTokens = 0` for every motoko run — the eval leaderboard would show motoko as "free" and "tokenless", which is both wrong and useless for the cheap-model-vs-frontier-model threshold measurement that is the strategic point of adding the adapter.

---

## Goals

1. Surface `tokens` + `cost_usd` on every per-step JSONL event that today carries `step:` (i.e. `thinking`, `native_tool_calls`, `native_tool_results`)
2. Emit a new terminal `run_summary` event with cumulative totals — always emitted, even on early termination (`Err` paths, cap exhaustion, dp7 rejection, panic-deferred)
3. Promote `session_id` to a top-level field on `session_start` (and propagate through subsequent events)
4. Add a `schema_version: "1"` field to every emitted event (forward-compat — future schema changes can ship a `"2"` version with the parser branching cleanly)
5. Surface cache-token data (Anthropic prompt-caching) as **best-available** — non-zero where the upstream provider returns it (Anthropic), zero where it doesn't (Gemini, OpenRouter-OS-models). Never lie.
6. Zero behavioural change to motoko's loop — pure additive metadata; existing consumers ignore unknown fields and keep working.

### Success metrics

- `cat session_*.jsonl | jq 'select(.type=="run_summary") | .total_cost_usd'` returns a positive number on every successful run that ran against a metered provider
- Per-step events expose `input_tokens` + `output_tokens` so downstream tooling can build per-step cost histograms without re-deriving from millicents
- AILANG's M-MOTOKO-EXECUTOR-ADAPTER fixture tests `TestParseSessionJSONL_Success` etc. read fields directly from these events — no special-casing for motoko vs other harnesses

---

## High-impact decisions

| Decision | Rationale | Chosen by | Change cost |
|---|---|---|---|
| Cost source: derive USD from existing `step_cost_millicents` (AILANG cost_rates path) — NOT from upstream `usage.cost` field | Cost rates are configured per-profile in motoko; using them keeps a single source of truth and matches what `cost_warning` already reports. OpenRouter-supplied `usage.cost` may be nil for many providers. | human | medium (changing later means dual source-of-truth) |
| Schema version is a **string** (`"1"`), not an integer | Allows `"1.1"` minor bumps for additive changes if needed without breaking integer-comparing parsers | human | low |
| `run_summary` is emitted in **all** termination paths (success, Err, cap-exhausted, dp7-rejected mid-loop, compaction-exhausted) | Eval harness needs partial totals on crash; missing-summary-on-failure is the worst possible UX | human | low |
| `tokens.cache_read` / `tokens.cache_write` populated only when upstream provider returns them; absent (omitted from JSON) otherwise — NOT zero | A literal `0` would mislead the harness into thinking caching was attempted but ineffective; absent makes "no data" unambiguous | human | low |
| Per-step `cost_usd` is a `number` with 6 decimal places (`%.6f` format) | Matches the precision of `OpenRouter`'s `usage.cost` field; sub-millicent costs are common with cheap models | agent | low |
| `session_id` format: existing `session_<ISO-timestamp>` filename stem (e.g. `session_2026-05-07T17-38-27-188Z`) — promote that stem to the top-level field, no new format | Keeps consistency with filename; avoids generating new IDs | agent | low |

### Design Freeze

- [x] Cost source: AILANG cost_rates path (millicents → USD divide-by-100000), NOT upstream `usage.cost`
- [x] `run_summary` always emits, regardless of termination reason
- [x] Cache fields use omit-when-absent semantics (NOT zero-fill)
- [ ] Whether per-step events should carry the FULL `usage` sub-block (matching pi's shape) or just the flat fields (`input_tokens`, `output_tokens`, `cost_usd`) — pick before M2 (recommend: flat for events, structured `usage` block only on `run_summary`)

---

## Schema

### Per-step events (additive — applies to `thinking`, `native_tool_calls`, `native_tool_results`)

```jsonc
{
  "schema_version": "1",            // NEW: forward-compat marker
  "type": "thinking",                // unchanged
  "step": 5,                         // unchanged
  "session_id": "session_2026-05-07T17-38-27-188Z",  // NEW: top-level
  "stream_id": "step-5",             // unchanged
  "text": "...",                     // unchanged
  "finish_reason": "tool_calls",     // unchanged

  "input_tokens": 1234,              // NEW: from result.input_tokens
  "output_tokens": 567,              // NEW: from result.output_tokens
  "cost_usd": 0.001234,              // NEW: from step_cost_millicents/100000
  "cache_read_input_tokens": 256,    // NEW (when provider supports): Anthropic prompt-cache hit
  "cache_creation_input_tokens": 128 // NEW (when provider supports): Anthropic prompt-cache write
}
```

### `session_start` (additive)

```jsonc
{
  "schema_version": "1",                                   // NEW
  "type": "session_start",
  "session_id": "session_2026-05-07T17-38-27-188Z",        // NEW: top-level
  "task": "...",                                            // unchanged
  "model": "anthropic/claude-haiku-4-5",                    // unchanged
  "brainVersion": "0.2.0",                                  // unchanged
  "ailangBuilt": "unknown",                                 // unchanged
  "config_profile": "dogfood",                              // unchanged
  "config_dir": "...",                                      // unchanged
  "backend_mode": "external_http",                          // unchanged
  "loaded_extensions": [],                                  // unchanged

  "motoko_commit": "7cb0d9b"                                // NEW: short SHA for self-referential masking detection
}
```

### `run_summary` (NEW terminal event — always emitted)

```jsonc
{
  "schema_version": "1",
  "type": "run_summary",
  "session_id": "session_2026-05-07T17-38-27-188Z",
  "model": "anthropic/claude-haiku-4-5",
  "motoko_commit": "7cb0d9b",
  "finish_reason": "stop",          // "stop" | "cost_exhausted" | "dp7_rejected" | "compaction_exhausted" | "max_steps" | "error"
  "steps_executed": 12,
  "usage": {
    "input_tokens":  18534,
    "output_tokens": 2891,
    "cache_read_input_tokens":     1024,   // omitted if provider doesn't report
    "cache_creation_input_tokens":  512,   // omitted if provider doesn't report
    "total_tokens": 21425
  },
  "total_cost_usd":      0.0428,
  "total_cost_millicents": 4280,           // for downstream tools that need integer math
  "duration_ms": 18230,                     // wall-clock from session_start to terminal
  "error": null                              // populated string on error termination
}
```

---

## Implementation plan

### Phase 1: Schema scaffolding (~1 hour)

- [ ] M1: Add `schema_version` constant `pure func schema_version() -> string { "1" }` near top of `agent_loop_v2.ail`; thread through `emit_json` call sites by adding `kv("schema_version", js(schema_version()))` to every event payload (mechanical edit, ~30 sites)
- [ ] M2: Add `session_id` derivation — read from existing logfile-naming logic; thread as parameter through `loop_v2` (already takes many params; one more is fine) and add `kv("session_id", js(session_id))` to every emit_json call

### Phase 2: Per-step usage emission (~2 hours)

- [ ] M3: At the per-step emit sites for `thinking` (lines ~691, ~711, ~718, ~724) and `native_tool_calls` (existing) and `native_tool_results` (existing): add `kv("input_tokens", jnum(_int_to_float(result.input_tokens)))`, `kv("output_tokens", jnum(_int_to_float(result.output_tokens)))`, `kv("cost_usd", jnum(millicents_to_usd(step_cost)))` (where `millicents_to_usd` is a new pure helper: `func millicents_to_usd(mc: int) -> float { _int_to_float(mc) / 100000.0 }`)
- [ ] M4: Add cache-token plumbing — extend `StepResult` reading to include `result.cache_read_input_tokens` / `result.cache_creation_input_tokens` if upstream provider returns them; emit only when non-zero (per Design Freeze: omit-when-absent, NOT zero-fill). May require a small upstream stdlib tweak if `std/ai.step` doesn't surface these — verify in M3.
- [ ] M5: Update the existing `cost_warning` event to also carry the flat `cost_usd` field for parser uniformity (currently has `total_cost_millicents` + `cap_millicents` only)

### Phase 3: `run_summary` terminal event (~2 hours)

- [ ] M6: Define `emit_run_summary(...)` helper taking all accumulated state (totals, finish_reason, error, duration); always builds the full `run_summary` JSON object per schema above
- [ ] M7: Wire `emit_run_summary` into all 6 termination paths in `loop_v2`:
  - Successful `done` path (after solver `Accept`)
  - `Err` paths (compile error, runtime error, AI error, etc.)
  - `cost_exhausted` path
  - `dp7_verifier_rejected` (if it cascades to budget exhaustion)
  - `compaction_exhausted`
  - `max_steps` exhaustion
- [ ] M8: For each termination path, populate `finish_reason` with the right variant and `error` with the failure message (null on success)
- [ ] M9: Add `motoko_commit` to `session_start` and `run_summary` — derive from a build-injected constant (e.g. `pure func motoko_commit() -> string { "${MOTOKO_COMMIT}" }` filled at build time, falling back to `"dev"`)

### Phase 4: Tests + docs (~1 hour)

- [ ] M10: Snapshot test — run a small canned task end-to-end, capture the resulting JSONL, commit as a fixture under `examples/fixtures/eval_session_v1.jsonl`. Re-run on every test run; failure indicates schema drift.
- [ ] M11: Schema version test — `pure func test_schema_version() -> bool { schema_version() == "1" }` to make accidental version bumps obvious in code review
- [ ] M12: Update `agents.md` with a "Session JSONL schema v1" section documenting the contract for downstream consumers
- [ ] M13: Update CHANGELOG with the additive-only behavior, schema version, and link to AILANG's M-MOTOKO-EXECUTOR-ADAPTER as the primary downstream consumer

---

## Files to modify/create

**Modified:**
- `src/core/agent_loop_v2.ail` (~+80 LOC, -0 LOC) — add helpers, thread `session_id`, emit `tokens`/`cost_usd` per step, add `emit_run_summary` + wire into 6 termination paths
- `agents.md` (+~30 lines) — new "Session JSONL schema v1" section
- `CHANGELOG.md` (+~15 lines) — eval-instrumentation entry under next version

**New:**
- `examples/fixtures/eval_session_v1.jsonl` (~50 lines) — captured fixture for regression testing

**Possibly:**
- `src/core/types.ail` if `StepResult` needs new fields surfaced from `std/ai.step` for cache tokens — only required if AILANG-side `std/ai.step` doesn't already expose them (verify in M3)

---

## Conflict surface

This is **not** a parser/typechecker change — it's purely additive metadata in JSON output. The conflict surface is the JSONL schema itself.

### What else lives here

The session JSONL is consumed by at least three known parsers:
- motoko's own TUI replay (in this repo)
- AILANG's planned M-MOTOKO-EXECUTOR-ADAPTER (to be built)
- motoko_explore's `runs/<timestamp>/` post-run analysis scripts (`grep`-based for `dp7_verifier_rejected`, etc.)

All three currently parse known event types and ignore unknown fields. Adding new fields (`schema_version`, `session_id`, `tokens`, `cost_usd`, `cache_*`) is safe.

Adding a new EVENT TYPE (`run_summary`) is also safe — consumers either know it (and parse it) or don't (and skip on `type` switch).

### Programs that MUST still work

- Any existing `jq '.[] | select(.type=="done")'` style query — `done` event shape unchanged
- TUI replay (this repo) — additive fields are ignored
- Post-run grep for `dp7_verifier_rejected` — event unchanged
- Any tooling that filename-greps for `session_<timestamp>` — filename format unchanged (only ADDED top-level `session_id`)

### What deliberately changes

Nothing existing breaks. This is strictly additive. The schema_version field documents the version at which the additions were introduced — future breaking changes will increment it.

---

## Testing strategy

**Unit tests** (in motoko_agent):
- `pure func test_schema_version()` — guards accidental version bumps
- `pure func test_millicents_to_usd_conversion()` — verifies divide-by-100000 with edge cases (0, 1, 100, 12345678)

**Snapshot test**:
- `examples/fixtures/eval_session_v1.jsonl` captured from a small canned run
- CI replays it and asserts: contains `schema_version: "1"` on every event; contains exactly one `run_summary` event; that event has `usage.input_tokens > 0`; per-step `thinking` events all have `input_tokens` + `output_tokens` + `cost_usd` fields

**Integration test (gated)**:
- Wire `motoko --task "<simple>" --model openrouter/z-ai/glm-5` end-to-end; assert the resulting session JSONL conforms to schema v1 with non-zero usage totals
- Skip unless `MOTOKO_LIVE_INSTRUMENTATION_TEST=1` set

**Cross-repo test (after AILANG-side adapter lands)**:
- AILANG's `internal/executor/motoko/motoko_test.go::TestParseSessionJSONL_Success` will be the production-equivalent of the snapshot test; once it passes, the contract is locked

---

## Non-goals

- **OTEL emission from motoko itself** — out of scope. The downstream eval adapter wraps motoko in `motoko.execute` + `motoko.turn` OTEL spans on the AILANG side (matching how `pi.execute`/`pi.turn` and `opencode.execute`/`opencode.step` work). Motoko's only job is to emit JSONL events the adapter can decorate spans with.
- **`result.json` output file** (the original M-BENCH-MOTOKO doc proposed this) — replaced by the `run_summary` JSONL event. Keeping everything in one stream keeps motoko's output story consistent.
- **A `--json` headless mode flag** (the original M-BENCH-MOTOKO doc proposed this) — unnecessary; the JSONL is always emitted today; the adapter just tails it.
- **Provider-side `usage.cost` reconciliation** — out of scope; cost is computed from motoko's own `cost_rates` (see Design Freeze decision)
- **Real-time streaming token counts during a single step** — out of scope; per-step counts are sufficient for the eval-harness use case. Streaming token counts would require restructuring `thinking_delta` events.

---

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `std/ai.step` doesn't surface cache tokens — adapter can't get them | Medium | Low | Document as "requires AILANG ≥ vX.Y for cache tokens"; ship without cache fields if needed (omit-when-absent semantics handle this gracefully) |
| Per-step emission inflates JSONL file size noticeably (lots of small numeric fields × hundreds of steps) | Low | Low | Estimate: 6 new fields × ~30 bytes each × 50 steps = ~9KB additional per session — negligible vs the existing thinking-text payloads |
| Parser drift between schema_version "1" producer (motoko) and a future "2" consumer (downstream) | Medium | Medium | The version field IS the mitigation — consumers can branch on `schema_version` cleanly. Document that bumping requires sweeping all downstream parsers in lockstep. |
| Wall-clock `duration_ms` requires a clock dependency that may not be there | Low | Low | Already have `now()` from `std/clock` in many places; adding it to loop_v2 is one import |
| `motoko_commit` build-time constant requires a Makefile change | Low | Low | Falls back to `"dev"` if not injected; non-blocking |

---

## Axiom compliance

| Axiom | Score | Justification |
|---|---|---|
| A1: Determinism | 0 | Pure additive emission; no new nondeterminism |
| A2: Replayability | +1 | Snapshot fixture + schema_version makes JSONL replays robust to future shape changes |
| A3: Effect Legibility | 0 | All additions are inside existing emit_json IO calls |
| A4: Explicit Authority | 0 | No authority changes |
| A5: Bounded Verification | +1 | Per-step + per-run totals enable downstream verification of cost/token claims without re-running |
| A6: Safe Concurrency | 0 | No concurrency changes |
| A7: Machines First | +2 | The whole point is making motoko's output mechanically consumable on equal footing with claude/gemini/codex/opencode/pi |
| A8: Minimal Syntax | 0 | No syntax |
| A9: Cost Visibility | +2 | Surfaces per-step + per-run cost in USD as first-class JSONL fields — exactly the cost-visibility axiom in action |
| A10: Composability | +1 | Schema versioning composes with future shape evolution; `run_summary` composes with downstream eval aggregation |
| A11: Structured Failure | +1 | `run_summary.finish_reason` + `error` fields turn termination causes into typed values |
| A12: System Boundary | 0 | No boundary changes |

**Net Score: +8** ✅ Proceed to implementation

### Hard violation check

- [x] A1: No nondeterminism added
- [x] A3: All effects already inside existing emit_json sites
- [x] A4: No ambient authority granted
- [x] A7: Optimizing for machine-readability (THE point of the doc)

---

## References

- **Downstream consumer:** AILANG `design_docs/planned/v0_18_0/m-motoko-executor-adapter.md` — the executor adapter that depends on this work
- **Source observation:** AILANG sprint planning session 2026-05-07 — actual session JSONL inspected, gaps identified
- **Pattern reference:** AILANG `internal/executor/opencode/opencode.go` (line 502+) and `internal/executor/pi/pi.go` (line 533+) — canonical `tokens` + `cost` event schema in other harnesses
- **AILANG executor framework:** `docs/internal/EXECUTOR_SHAPE.md` — the contract this enables motoko to participate in
- **Related motoko design:** `design_docs/planned/m-motoko-cost-budget.md` — established the millicents accumulator that this doc surfaces

---

## Future work

- **Schema v2: streaming token counts** — emit `tokens_delta` per `thinking_delta` event for real-time cost dashboards. Requires restructuring; defer until a concrete consumer asks.
- **`usage.reasoning_tokens`** — once OpenAI o-series / Anthropic extended-thinking models emit reasoning token counts via `std/ai.step`, surface them as a separate field
- **Per-tool cost attribution** — currently cost is per-step; a future schema could break it down by tool call (microRAG retrievals vs LLM calls vs context-mode probes)
- **`run_summary.extension_metrics`** — let extensions inject their own per-run telemetry (e.g. `compose.attempts`, `omnigraph.queries`, `mcp.tool_calls`) into the summary
