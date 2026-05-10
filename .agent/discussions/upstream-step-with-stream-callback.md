# `stepWithStream` stdout flush bug — per-token deltas arrive in a single burst

**Category:** Bug report
**Upstream:** AILANG Go runtime (`stepWithStream` implementation)
**AILANG version:** v0.18.8
**Motoko context:** Restoring real-time token streaming in the TUI after fork → upstream migration

## Status

`stepWithStream` was added in v0.18.7/v0.18.8 and the API is exactly what we requested. Motoko's AILANG-side wiring (`agent_loop_v2.ail`, `stub_step.ail`) and TUI-side rendering (`ui.ts`) are fully integrated and type-check clean. However, **streaming appears broken at runtime** — all token deltas arrive in a single burst when the call completes, not incrementally as tokens arrive from the provider.

## Root cause

**AILANG's buffered IO writer.** AILANG's Go runtime wraps `os.Stdout` in a `bufio.Writer` for general IO performance. The `on_chunk` callback calls `println`, which writes through this buffered writer. Each JSONL event is only ~100-200 bytes — the ~4KB buffer never fills during streaming, so all events accumulate and flush in one burst when `stepWithStream` returns and the deferred `Flush()` fires. (Note: Go's `os.Stdout` itself is unbuffered — this was verified with a Go test program. The buffering is in AILANG's `bufio.Writer` wrapper, not the kernel.)

## Reproduction

```bash
# Spawn motoko's full runtime via supervisor, capture timestamped events:
export OPENROUTER_API_KEY=sk-or-...
timeout 45 ailang run \
  --caps "Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream" \
  --ai "openrouter/deepseek/deepseek-v4-pro" \
  --allow-env OPENROUTER_API_KEY \
  --entry main \
  src/core/supervisor.ail \
  -- --profile default \
     --model "openrouter/deepseek/deepseek-v4-pro" \
     --workdir . --port 9999 --no-backend \
     "Write a haiku about the ocean" 2>&1 \
  | while IFS= read -r line; do
      ts=$(date +%s%N | cut -c1-13)
      type=$(echo "$line" | python3 -c \
        "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('type','?'))" \
        2>/dev/null || echo "non-json")
      echo "$ts $type"
    done
```

**Observed output** (timestamps in epoch-ms):

```
...6141  thinking_stream_start
...2054  thinking_delta        ← 6s gap (LLM latency, expected)
...2069  thinking_delta        ← 15ms later
...2085  thinking_delta        ← 16ms later
...2099  thinking_delta        ← 14ms later
  ...    (12 more deltas)
...2287  thinking_delta        ← all 16 deltas in a 233ms burst
...3080  thinking_stream_end
```

All 16 `thinking_delta` events arrive within a ~233ms window right at the end of the call. They should be spread across the full 6-second streaming window.

**Control test** — the callback itself works correctly. A standalone test calling `stepWithStream` with `println` inside the callback shows per-token output when stdout is a TTY:

```bash
# This produces per-token output because stdout is a TTY (line-buffered):
ailang run --caps IO,AI --ai "openrouter/deepseek/deepseek-v4-pro" \
  --allow-env OPENROUTER_API_KEY --entry main /tmp/test_stream.ail
```

```
[CONTENT_DELTA] Lines
[CONTENT_DELTA]  of
[CONTENT_DELTA]  code
[CONTENT_DELTA]  unfold
...
```

The difference: TTY stdout is line-buffered (each `println` flushes immediately), pipe stdout is block-buffered (flush only when the 4KB buffer fills or the stream completes).

## Fix needed (Go runtime side)

The Go-side implementation of `_ai_step_with_stream` needs to flush stdout after each callback invocation. Three options in order of preference:

### Option 1: Auto-flush after callback (recommended)

In the Go function that implements `_ai_step_with_stream`, after calling the user's `on_chunk` AILANG callback, call `.Flush()` on the `bufio.Writer` wrapping `os.Stdout`. This is the right fix because the entire purpose of a streaming callback is per-token delivery — buffering defeats it.

Pseudocode for the Go side:
```go
// Inside the SSE event loop in _ai_step_with_stream:
for event := range sseEvents {
    chunk := toStreamChunk(event)
    callAILANGCallback(onChunk, chunk)
    stdoutWriter.Flush()  // <-- this is the missing line
}
```

Note: `os.Stdout.Sync()` is NOT the right call — `Sync()` calls `fsync()` which returns `EINVAL` on pipes. The buffering is in the userspace `bufio.Writer`, not the kernel.

### Option 2: Add `flush()` to `std/io`

Export a `flush` function that calls `os.Stdout.Sync()`. Consumers would call it in their callback:

```ailang
func on_chunk(chunk: StreamChunk) -> () ! {IO} {
  match chunk {
    ContentDelta(text) => { println(text); flush() },
    ...
  }
}
```

Downside: every consumer must remember to call `flush()`. Easy to forget, hard to debug.

### Option 3: Line-buffered mode flag

Add a runtime flag (e.g., `--line-buffered-stdout`) or auto-detect when `stepWithStream` is called and switch stdout to line-buffered mode for the duration. More complex, less predictable.

## What's already wired (no changes needed once flush is fixed)

The full streaming pipeline is integrated and type-checks clean:

| Layer | File | Status |
|-------|------|--------|
| AILANG stdlib | `std/ai.ail` (v0.18.8) | `stepWithStream` + `StreamChunk` ADT |
| Runtime dispatch | `src/core/test/stub_step.ail:117` | Routes `LiveAI` through `stepWithStream` |
| Chunk → JSONL | `src/core/agent_loop_v2.ail:154-172` | `emit_stream_chunk` pattern-matches `ContentDelta`/`ThinkingDelta` |
| Loop wiring | `src/core/agent_loop_v2.ail:879` | Lambda captures `session_id`, `step_idx`, `stream_id` |
| TUI event types | `src/tui/src/runtime-process.ts:60-61` | `thinking_delta` + `reasoning_delta` in `AgentEvent` union |
| TUI buffer/render | `src/tui/src/ui.ts:1792-1831` | `streamBuffers` accumulation + `scheduleStreamRender()` |
| TUI reasoning | `src/tui/src/ui.ts:1818-1831` | Separate `reasoningBuffers` for API-level thinking |
| Type-check | `make check_core` | 23/23 modules pass |

## Cross-references

- `stepWithStream` API: `std/ai.ail` lines 270-316
- Motoko stream protocol spec: `.agent/specs/motoko_stream_protocol.md`
- PR #7 (this branch): includes all AILANG-side + TUI-side wiring
- Original discussion that led to `stepWithStream`: this file's git history
