# M-MOTOKO-CHAIN-PROVENANCE

**Status**: Planned  
**Priority**: P2 — observability / dogfood quality  
**Estimated effort**: 2-3 days  
**Dependencies**: `M-DETERMINISTIC-CHAT-LINKING` (AILANG-side, already shipped per chains-health note)  
**Source**: motoko-explore inbox msg `5f532fb4` (2026-05-06)

---

## Problem

motoko's session JSONL (`.motoko/logfile/session_*.jsonl`) is a parallel provenance stream that exists entirely outside AILANG's chain system. The `session_start` event emits:

```json
{
  "type": "session_start",
  "task": "...",
  "model": "openrouter/z-ai/glm-5",
  "brainVersion": "0.2.0",
  "ailangBuilt": "unknown",
  "config_profile": "default",
  "loaded_extensions": []
}
```

None of the correlation IDs used by `ailang chains` / `ailang trace` appear: no `chain_id`, `task_id`, `stage_id`, `trace_id`, `span_id`. Verified by:

```bash
jq -c 'select(. | tostring | test("chain_id|task_id|correlation|trace_id|span_id"))' session_*.jsonl
# (no matches)
```

`ailang chains list` shows eval_suite runs but motoko sessions never appear. The two provenance systems are disjoint.

---

## Concrete consequences

- `ailang chains find <inbox-msg-id>` cannot trace from a feedback message → fix design doc → motoko run that validated the fix → cross-check chain. The chain stops at AILANG's boundary.
- `ailang chains diff <chain-id>` cannot show what motoko changed in a self-modification run, even though that provenance is exactly what the Phoenix architecture promises as durable.
- `ailang chains journey <chain-id>` would naturally include the agent's tool-call narrative — motoko's narrative lives in a separate format the chains tool doesn't index.
- The `bin/sweep` harness in `motoko_explore` can't group multiple model runs of the same task under a single chain for automatic comparison.

---

## Goals

1. Each motoko session emits `chain_id`, `task_id`, `stage_id` in `session_start` and all subsequent JSONL events
2. motoko registers its session as a chain stage with AILANG's chain registry on startup
3. AILANG's `step()` spans inherit the same chain_id so the full tool-call trace is addressable
4. `bin/run-task` / `bin/sweep` in `motoko_explore` can pass correlation IDs via env vars and group model runs under one chain
5. Zero behaviour change when no correlation IDs are provided (standalone / legacy mode)

---

## Design

### Layer 1: Session correlation IDs in JSONL (~1 day)

**Source of IDs**: motoko generates a `chain_id` (UUID v4) and `task_id` (UUID v4) on startup if they're not already present in the environment. If `MOTOKO_CHAIN_ID` / `MOTOKO_TASK_ID` env vars are set, use those instead (sweep harness injection).

A `stage_id` is always generated fresh per motoko invocation (one stage = one agent run).

**session_start change** in `src/core/supervisor.ail` (or wherever `session_start` is emitted):

```ailang
{
  "type": "session_start",
  "chain_id": chain_id,
  "task_id": task_id,
  "stage_id": stage_id,
  "task": task,
  "model": model,
  ...existing fields...
}
```

**All subsequent JSONL events** carry `chain_id` + `stage_id` for cross-event correlation. The `step_idx` already provides event-within-stage ordering.

**Changes needed in motoko**:
- `src/core/supervisor.ail`: read env vars `MOTOKO_CHAIN_ID`, `MOTOKO_TASK_ID`, generate `stage_id`; thread through the loop
- `src/core/agent_loop_v2.ail` + `src/core/rpc.ail`: propagate `chain_id` / `stage_id` into all `emit_json` calls (can use the `ExtCtx.state_key` slot or add a dedicated field to `ExtCtx`)

### Layer 2: Register as AILANG chain stage (~1 day)

On motoko startup, after generating IDs, call into AILANG's chain registry to declare a stage. The AILANG-side API (from `M-DETERMINISTIC-CHAT-LINKING`) exposes something like:

```ailang
import std/chains (register_stage, StageKind)

register_stage({
  chain_id: chain_id,
  task_id: task_id,
  stage_id: stage_id,
  kind: StageKind.Agent,
  label: "motoko:${model}",
  meta: { task: task, model: model, profile: config_profile }
}) ! {Net, Env}
```

This call is best-effort — if the chains registry is unavailable (no `AILANG_CHAIN_ENDPOINT`), it fails silently. motoko's agent behaviour is unaffected.

The AILANG-side chains system (already shipped) handles the stage record and makes it queryable via `ailang chains view <chain-id>`.

### Layer 3: Trace span inheritance (~0.5 days)

AILANG's `std/ai.step()` emits OTEL spans. If `chain_id` is passed as a trace context baggage item (W3C baggage header), the step spans inherit it automatically. Pass via the AILANG `--trace-context chain_id=<id>` flag or via the `OTEL_TRACE_CONTEXT` env var.

This ensures that `ailang trace list --chain-id <id>` returns both motoko's JSONL events AND the LLM API spans under the same chain.

### Layer 4: Sweep harness integration (~0.5 days)

Update `bin/run-task` in `motoko_explore` to accept `--chain-id` and `--task-id` flags that are forwarded as env vars:

```bash
TASK_ID="wire-mcp-$(date +%s)"
CHAIN_ID="$(uuidgen)"
for model in $(cat models.txt); do
  MOTOKO_CHAIN_ID="$CHAIN_ID" MOTOKO_TASK_ID="$TASK_ID" \
    bin/run-task tasks/medium/wire-mcp-extension/ "$model"
done
ailang chains view "$CHAIN_ID"  # all 5 model attempts as sibling stages
```

---

## Files

| File | Change |
|------|--------|
| `src/core/supervisor.ail` | Read `MOTOKO_CHAIN_ID` / `MOTOKO_TASK_ID` env vars; generate `stage_id`; add IDs to `session_start` event |
| `src/core/agent_loop_v2.ail` | Thread `chain_id` / `stage_id` into `emit_json` calls |
| `src/core/rpc.ail` | Same — propagate IDs into existing JSONL event emitters |
| `src/core/config.ail` | Add `chain_id`, `task_id`, `stage_id` to `RuntimeConfig` or a new `ProvenanceConfig` |
| `src/core/env_client.ail` | Pass IDs to env-server for TUI correlation |
| `motoko_explore/bin/run-task` | Accept `--chain-id` / `--task-id` flags; forward as env vars |

---

## Acceptance criteria

- [ ] `session_start` event in JSONL contains `chain_id`, `task_id`, `stage_id` fields
- [ ] All step JSONL events (`thinking`, `done`, `native_tool_calls`, etc.) contain `chain_id` + `stage_id`
- [ ] `ailang chains list` shows motoko sessions (requires AILANG chain registry endpoint)
- [ ] `ailang chains view <chain-id>` shows motoko stage alongside eval-suite stages when IDs match
- [ ] `MOTOKO_CHAIN_ID=X bin/run-task ...` correctly groups the run under chain X
- [ ] When `MOTOKO_CHAIN_ID` / `MOTOKO_TASK_ID` absent: IDs auto-generated; behaviour unchanged
- [ ] No regression on existing JSONL consumers (TUI, log viewers) — new fields are additive

---

## Open questions

1. **chains registry endpoint**: where does motoko call to register a stage? Is it the same OTEL-backed endpoint AILANG uses, or a separate `ailang chains register` CLI call? Need to check the `M-DETERMINISTIC-CHAT-LINKING` spec for the registration API.
2. **ExtCtx threading**: the cleanest motoko-internal approach is adding `chain_id` / `stage_id` as fields to `ExtCtx` so extensions can include them in their own events. Alternatively, make them loop-level globals threaded as parameters. The former is cleaner but requires a breaking ExtCtx change.
3. **Ordering with Pending + compaction**: `dispatch_calls` now emits `tool_pending` events — these should also carry chain/stage IDs. Wire simultaneously with Layer 1.
