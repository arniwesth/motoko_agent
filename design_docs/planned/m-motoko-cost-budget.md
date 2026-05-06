# M-MOTOKO-COST-BUDGET — `max_cost_usd` economic budget cap for the v2 loop

**Status**: Planned  
**Priority**: P1 — correctness backstop; complements compaction + Pending policy  
**Estimated effort**: 0.5–1 day (~4-6 hours)  
**Dependencies**: `motoko-dx-compaction-pending` merged (DP0 hook pattern established)  
**Source**: motoko-explore inbox msg `331a93da` (2026-05-06)

---

## Problem

`max_steps` is the only correctness backstop for runaway agents today. Step count is a proxy metric that degrades as motoko's architecture matures:

- **Compaction** extends viable step counts by reclaiming context. A 100-step cap that was reasonable without compaction may now be too tight for a well-structured run that compacts three times.
- **Pending policy** can stall the loop waiting for human approval — steps accumulate before a human ever responds.
- **Multi-agent compose** orchestrates multiple sub-loops. Step count is not composable across them; cost is.
- **Local/unmetered models** (ollama, self-hosted) make `max_steps` the only knob; cost doesn't apply. So `max_steps` stays — it's the right knob for unmetered providers.

The user-stated need (2026-05-06 stress test): "max_steps … is just to avoid runaways during dev I guess. … a max cost flag would be good too."

Claude Code itself has no client-side cost cap — it relies on Anthropic-side account caps. `max_cost_usd` in motoko would be a genuine DX improvement, not parity-with.

---

## Goals

1. Add `max_cost_usd` to the `[agent]` profile block in `ailang.toml` and profile JSON
2. Accumulate per-step cost in `loop_v2` from `StepResult.input_tokens` + `StepResult.output_tokens`
3. Check accumulated cost at DP0 (before each step) — cap trips like compaction: emit event + return `Err`
4. Emit `cost_warning` events at 50% / 75% / 90% of cap (telemetry, not termination)
5. Zero behaviour change when `max_cost_usd` is 0 or absent (opt-in, not default)
6. `AI_MAX_COST_USD` env override (same pattern as `AI_MODEL`, `AI_MAX_STEPS` if those exist)

---

## Design

### Representation: millicents (integer arithmetic)

Following the same pattern as `compact_step`'s `usage_percent` — integer arithmetic avoids float precision edge cases.

```
1 millicent = $0.00001 USD
max_cost_usd = 1.50 → max_cost_millicents = 150_000
GLM-5 input rate  = 0.60 USD/1M tokens → 60_000 millicents/1M tokens
GLM-5 output rate = 2.08 USD/1M tokens → 208_000 millicents/1M tokens
per-step cost = (input_tokens * 60_000 + output_tokens * 208_000) / 1_000_000
```

Integer division truncates toward zero — always conservative (never over-counts cost, which would trip the cap early).

### Layer 1: `config.ail` — new fields (~30 LOC)

**`AgentConfig`** gains one field:
```ailang
export type AgentConfig = {
  ...existing fields...,
  max_cost_millicents: int  -- 0 = disabled; internal representation of max_cost_usd
}
```

**New helper `json_float_millicents`** reads a float-valued JSON field and converts to millicents (handles the `cost = { input_per_1m_usd = 0.60 }` TOML-float-to-JSON case):
```ailang
func json_float_millicents(obj: Json, key: string, fallback: int) -> int {
  -- JNumber in AILANG's JSON is backed by the raw string representation.
  -- We read as string and parse manually to avoid float representation issues.
  match getInt(get(obj, key)) {
    Ok(n) => n * 100_000,      -- integer dollar value (e.g. 1 → 100_000 millicents = $1)
    Err(_) => fallback          -- unknown/absent → disabled
  }
}
```

Note: for sub-dollar values like 0.60, `getInt` returns 0. A proper float reader is needed. **Implementation option A**: store `max_cost_usd_cents: int` in the profile JSON (e.g. `150` for $1.50) — simpler, no float parsing. **Implementation option B**: add `json_parse_float_string` helper. Option A is recommended for v1.

**`RuntimeConfig`** also carries `CostRates`:
```ailang
export type CostRates = {
  input_per_1m_millicents: int,   -- 0 if provider has no cost data
  output_per_1m_millicents: int
}
```

Parsed from `[ai_provider.cost]` block in `ailang.toml`. `0` means cost is unknown/unmetered — cap is skipped for that provider.

### Layer 2: `RunSettings` / `rpc.ail` — thread through (~10 LOC)

```ailang
type RunSettings = {
  ...existing fields...,
  max_cost_millicents: int,
  cost_rates: CostRates
}
```

### Layer 3: `agent_loop_v2.ail` — accumulation + DP0 check (~60 LOC)

**Accumulate** per-step cost after each `step()` call:
```ailang
func step_cost_millicents(result: StepResult, rates: CostRates) -> int {
  (result.input_tokens * rates.input_per_1m_millicents +
   result.output_tokens * rates.output_per_1m_millicents) / 1_000_000
}
```

**Thread `total_cost_millicents: int`** as an accumulator through `loop_v2` (same pattern as `step_idx`).

**DP0 check** fires before each step (alongside compaction's DP0 check):
```ailang
-- DP0a: cost budget check (before step)
let cost_check =
  if settings.max_cost_millicents > 0 &&
     rates.input_per_1m_millicents > 0 &&
     total_cost_millicents >= settings.max_cost_millicents
  then
    let _ = emit_json(jo([
      kv("type", js("cost_exhausted")),
      kv("step", jnum(_int_to_float(step_idx))),
      kv("total_cost_millicents", jnum(_int_to_float(total_cost_millicents))),
      kv("cap_millicents", jnum(_int_to_float(settings.max_cost_millicents)))
    ])) in
    Some(Err({ code: "BudgetExceeded", message: "cost cap reached", retryable: false }))
  else None;

match cost_check {
  Some(err) => err,
  None => -- proceed with compaction check, then step()
    ...
}
```

**Cost warning events** (at 50/75/90% — telemetry, not termination):
```ailang
let pct = if settings.max_cost_millicents > 0
          then (total_cost_millicents * 100) / settings.max_cost_millicents
          else 0;
let _ = if pct >= 90 && pct < 100 then emit_json(cost_warning_event("90pct", pct)) else ();
let _ = if pct >= 75 && pct < 90 then emit_json(cost_warning_event("75pct", pct)) else ();
let _ = if pct >= 50 && pct < 75 then emit_json(cost_warning_event("50pct", pct)) else ();
```

(Emit each threshold warning at most once — track `warned_50: bool, warned_75: bool, warned_90: bool` in loop state.)

### Profile JSON (`ailang.toml`) — v1 user-facing API

```toml
[agent]
max_steps = 50
max_cost_usd_cents = 150   # $1.50 cap; 0 or absent = disabled
```

Using integer cents avoids float parsing in the AILANG config parser (no `json_float` helper currently). Displayed to users as `$1.50` in warning events and TUI.

The env override:
```bash
AI_MAX_COST_USD_CENTS=150 motoko "..."
```

---

## Files

| File | Change | ~LOC |
|------|--------|------|
| `src/core/config.ail` | Add `max_cost_millicents` to `AgentConfig`; parse from `max_cost_usd_cents`; add `CostRates` type + parser for `[ai_provider.cost]` block | +60 |
| `src/core/rpc.ail` | Thread `max_cost_millicents` + `cost_rates` through `RunSettings`; pass to `run_v2_with_conversation` | +15 |
| `src/core/agent_loop_v2.ail` | DP0 cost check; `step_cost_millicents`; warning thresholds; accumulator in loop | +65 |
| `ailang.toml` (profiles) | `max_cost_usd_cents` examples in default and dogfood profiles | +5 |
| `src/core/compaction.ail` | No change — DP0 cost check added upstream of compaction check | 0 |

Total: ~145 LOC

---

## Acceptance criteria

- [ ] `max_cost_usd_cents = 150` in profile + GLM-5 rates → loop terminates after first step exceeds $1.50 cumulative
- [ ] `cost_exhausted` event emitted with `total_cost_millicents` and `cap_millicents` fields  
- [ ] `cost_warning` events emitted at 50% / 75% / 90% (each at most once per run)
- [ ] `max_cost_usd_cents = 0` (default): no cost check, loop unchanged
- [ ] Provider with no cost block (`input_per_1m_millicents = 0`): cost check skipped (fail-open for unmetered models)
- [ ] `step_cost_millicents` correct for GLM-5: 1000 input + 500 output at 0.60/2.08 rates = (60 + 104) / 1000 = 0 (rounds to 0 — harmless; cost is small relative to cap)
- [ ] 100 input + 100 output at 0.60/2.08 → `(6000 + 20800) / 1_000_000 = 0` millicents (normal per-step cost is sub-millicent; cap trips after many steps accumulate)
- [ ] `make check_core` still passes (23/23 modules)

---

## Open questions

1. **Float parsing for sub-dollar rates**: `json_float_millicents` needs to handle `0.60`. Option A (cents integer in profile) sidesteps the problem for `max_cost_usd_cents` but `[ai_provider.cost]` in `ailang.toml` is already float TOML. Need to decide: parse as string and do manual decimal → millicents conversion, OR add float-string reader to AILANG std. For v1, rates can be stored as `input_per_1m_millicents = 60000` in a new integer-valued field alongside the existing float field.

2. **Cost events in TUI**: The TS TUI currently renders `tool_pending`, `thinking_delta`, `done`, etc. `cost_warning` and `cost_exhausted` events need TUI rendering (or at minimum, not crashing the TUI). Suggest: pass-through as informational banner in the TUI status line.

3. **`ailang chains stats` integration**: once cost is accumulated per-run in the session JSONL (via `chain_id` from `m-motoko-chain-provenance.md`), `ailang chains stats` can show per-chain total cost. Worth wiring simultaneously.

4. **AG-UI mapping** (per `m-motoko-agui.md` pattern): `cost_exhausted` → `RUN_FINISHED` with `error.code = "BudgetExceeded"`. `cost_warning` → `motoko.COST_WARNING` custom event with `percent` field. Add to agui design doc when this lands.

---

## Cross-references

- `m-motoko-conversation-compaction.md` — DP0 hook pattern this reuses
- `m-motoko-tool-policy-pending.md` — companion correctness backstop
- `m-motoko-agui.md` — AG-UI mapping for `cost_exhausted` / `cost_warning` events
- `m-motoko-chain-provenance.md` — cost roll-up in `ailang chains stats`
- Source: inbox msg `331a93da` (2026-05-06)
