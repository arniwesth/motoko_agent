# Streaming-capture substrate spike

Date: 2026-07-24
Toolchain: AILANG v0.26.0 (`3b52a24d24431c372ed5605289ef039592209514`)
Status: Complete — current callback API cannot satisfy the ADR; upstream API work is required

This spike dispositions the streaming-capture gate in
`../ADR-001-deterministic-test-world-architecture.md`. It is validation scaffolding, not a
production implementation.

It tests two representations:

1. **Returned emission log.** A provider/runtime invokes the live callback immediately and returns
   the same ordered chunks with its final result. This is the ADR's preferred representation, but
   the probe initially models the provider side because AILANG v0.26.0 does not expose this result.
2. **Request-scoped recorder.** A callback-only provider tees each chunk to immediate IO and a
   CAS-claimed `SharedMem` scope, then drains and deletes that scope after the final result.

Both representations are tested for successful completion and partial-stream-then-error. The
request-scoped representation additionally tests two interleaved scopes, collision rejection, and
cleanup/reuse. Chunks include commas, a newline, and Unicode; capture uses base64 records so
arbitrary chunk text does not corrupt framing.

Two direct compiler probes then test whether either representation can be connected to the real
AILANG v0.26.0 API:

- `probe_state_returning_callback_rejected.ail` attempts to return the accumulator from the
  callback.
- `probe_sharedmem_callback_rejected.ail` returns `()` but performs `{IO, SharedMem}`.

`probe_real_stream_callback.ail` is the positive control: with `--ai-stub`, the actual API invokes
an IO-only callback twice (`ContentDelta`, then `Usage`) and returns a final successful result.

## Commands

```bash
cd .agent/projects/009_motoko_dst_execution/spike

ailang check stream_capture_probe.ail
ailang run --caps IO,SharedMem --entry main stream_capture_probe.ail
ailang run --caps IO --entry main_returned stream_capture_probe.ail
ailang run --caps IO,SharedMem --entry main_scoped stream_capture_probe.ail

# Positive control against the actual API.
ailang check probe_real_stream_callback.ail
ailang run --caps AI,IO --ai-stub --entry main probe_real_stream_callback.ail

# Both must fail for the stated type reason.
ailang check probe_state_returning_callback_rejected.ail
ailang check probe_sharedmem_callback_rejected.ail

# Projection parity: exactly 17 supplied chunks, no duplicate/error marker.
ailang run --caps IO,SharedMem --entry main stream_capture_probe.ail 2>&1 |
  awk '/^LIVE / {live += 1}
       /^PASS stream_capture_probe$/ {final += 1}
       /^(FAIL|CAPTURE_ERROR)/ {bad += 1}
       END {
         print "live_projections=" live " final_passes=" final " bad_markers=" (bad + 0);
         if (live != 17 || final != 1 || bad != 0) exit 1
       }'

# Process-isolation stress. Each independent evaluator uses the same fixed
# recorder scopes; all invocations must pass without cross-process collision.
seq 1 8 | xargs -P8 -I{} sh -c \
  'ailang run --caps IO,SharedMem --entry main stream_capture_probe.ail 2>&1' |
  awk '/^PASS stream_capture_probe$/ {passes += 1}
       /^(FAIL|CAPTURE_ERROR)/ {bad += 1}
       END {
         print "parallel_passes=" passes " bad_markers=" (bad + 0);
         if (passes != 8 || bad != 0) exit 1
       }'
```

## Results

All modeled representation tests pass:

```text
PASS returned.success
PASS returned.partial_error
PASS scoped.success
PASS scoped.partial_error
PASS scoped.two_scope_isolation
PASS scoped.collision_and_cleanup
PASS stream_capture_probe
```

The returned-emission representation runs with `--caps IO`; the callback-only recorder needs
`--caps IO,SharedMem`. Running `main_scoped` with only `IO` fails at effect performance:

```text
Error: execution failed: effect 'SharedMem' requires capability, but none provided
```

The projection audit reports exactly one projection per supplied callback:

```text
live_projections=17 final_passes=1 bad_markers=0
```

Eight parallel independent evaluators all pass while using identical fixed recorder scopes:

```text
parallel_passes=8 bad_markers=0
```

The actual API positive control passes:

```text
LIVE content {"kind":"Wait"}
LIVE usage
PASS real_stream_callback stop
```

The two direct compiler probes fail for the intended, distinct reasons:

```text
probe_state_returning_callback_rejected.ail:
  cannot unify type constructor () with *types.TList

probe_sharedmem_callback_rejected.ail:
  incompatible closed rows: ... extra labels [SharedMem]
```

## Disposition

Neither ADR representation is connectable to `std/ai.stepWithStream` in pinned AILANG v0.26.0:

- The API returns only `Result[StepResult, AIError]`, so Motoko cannot obtain the observed chunk
  list from the provider result.
- Its callback must return `()` and its closed effect row rejects `SharedMem`, so Motoko cannot
  thread an accumulator or install the validated request-scoped recorder.
- IO-only projection works, but reconstructing the trace from stdout would move the oracle outside
  the real session driver and does not satisfy the ADR.

The CAS-scoped recorder behavior itself is viable and fail-closed once the callback contract can
perform its effect, but widening the callback row would add `SharedMem` to the deterministic
profile and weaken capability-based hermeticity. The preferred upstream remedy is therefore a new
recorded-stream API (or result type) that preserves immediate callbacks and returns the exact
ordered observed chunks. Widening the callback to a row-polymorphic or `{IO, SharedMem}` contract
is a fallback requiring a separate capability/profile judgment.

The ADR remains blocked from acceptance until one upstream remedy lands and this spike gains a
direct positive integration probe against that pinned runtime.
