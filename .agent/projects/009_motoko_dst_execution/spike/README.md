# Streaming-capture substrate spike

Date: 2026-07-24 (integration probe added 2026-07-25)
Toolchain: AILANG v0.26.0 (`3b52a24d24431c372ed5605289ef039592209514`)
Status: Negative result complete — the current callback API cannot satisfy the ADR. A direct
positive integration probe now exists and **passes against a local prototype** of the proposed
upstream API; the D1 gate remains open until that API lands and the toolchain is repinned.

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

## Direct positive integration probe (added 2026-07-25)

`probe_recorded_stream_integration.ail` + `run_integration_probe.sh` are the direct positive probe
D1 requires for acceptance. Unlike `stream_capture_probe.ail`, which *models* the provider, this one
drives the real path: a native SSE stream, the real `std/ai` chunk callback, and the proposed
`stepWithStreamRecorded` API.

**It does not close the D1 gate.** It passes against a *local prototype* of the upstream API, not a
pinned release. D1 requires the API to have landed and the toolchain to be repinned. What this probe
buys us now is different and still worth having: it validates the proposed API shape end-to-end from
a consumer's perspective *before* upstream builds anything, so a shape problem surfaces while it is
still cheap to change.

### What it asserts

All five D1 properties, on **both** outcomes:

| Property | How it is asserted |
|---|---|
| immediate projection | every `LIVE` line falls between `CALL begin` and `RETURNED`, so chunks reached the sink during the call rather than batched after it |
| exact returned-log parity | returned count and order equal the supplied sequence |
| no duplicate delivery | projected count == supplied count == returned count |
| success | server `MODE=success` → `OUTCOME ok stop` |
| partial-stream-then-error | server `MODE=partial_error` → `OUTCOME err ConnectionFailed`, with both pre-failure chunks still returned |

The probe cannot accumulate its own projections — that is precisely the capability the upstream
request is about — so parity is asserted externally by comparing projected stdout lines against the
returned list, the same method `stream_capture_probe.ail` uses.

`fault_sse_server.py` is a minimal OpenAI-shaped SSE endpoint. In `partial_error` mode it emits two
real content deltas and then drops the connection mid-chunked-body. The `OPENAI_BASE_URL`
environment variable redirects AILANG's OpenAI provider at it, so no compiler patching is needed to
induce the fault. This matters: a config-driven provider could not be used, because `stepWithStream`
falls back to a NO-OP synthetic-chunk path for those, which cannot produce a *partial* stream.

### Running it

```bash
AILANG_SRC=~/src/ailang AILANG_BIN=~/src/ailang/bin/ailang ./run_integration_probe.sh
```

`AILANG_SRC` must be the toolchain source root — the compiler resolves its stdlib from the working
directory, and the probe needs a `std/ai` exporting `stepWithStreamRecorded`.

Recorded result against the prototype (`AILANG dev`, `24120ade2`):

```text
mode=success
  PASS no_duplicate_delivery (projected=2)
  PASS returned_parity_count (returned=2)
  PASS returned_parity_order
  PASS outcome
  PASS immediate_projection (all LIVE within the call)

mode=partial_error
  PASS no_duplicate_delivery (projected=2)
  PASS returned_parity_count (returned=2)
  PASS returned_parity_order
  PASS outcome
  PASS immediate_projection (all LIVE within the call)

integration_probe: PASS — all five D1 properties hold on both outcomes
```

The harness is load-bearing: run against the stock v0.26.0 toolchain it fails all ten assertions and
exits 1, because `stepWithStreamRecorded` does not resolve.

```bash
AILANG_BIN=~/.local/bin/ailang ./run_integration_probe.sh   # exit 1, as it must
```

### What the partial-error result settles

Both chunks observed before the failure come back:

```text
LIVE partial-1
LIVE partial-2
RETURNED count=2 order=partial-1|partial-2|
OUTCOME err ConnectionFailed
```

That is the case a `Result[{result, chunks}, AIError]` shape would silently discard, and it is the
concrete reason the upstream request asks for `{chunks, outcome}` instead. It is now demonstrated
against a real stream rather than argued from the ADR.

## D1 world-protocol vertical slice (added 2026-07-25)

`probe_world_protocol_slice.ail` + `run_world_slice.sh` exist to answer a different question from
every probe above. Those ask *"does the API return the chunks?"*. This one asks the question that
actually decides adequacy: **can a driver satisfy D1 with it?**

It runs a full discovery → replay cycle in one process:

1. **Discovery** — a live provider exchange via `stepWithStreamRecorded`. Chunks project at
   arrival; the returned list becomes the record.
2. **Program** — the recorded emission log, which is exactly what the live exchange returned. *This
   is the step the current callback-only API makes impossible* — the list would be empty.
3. **Replay** — a deterministic exchange consuming that program, projecting each emission at its
   virtual arrival point, calling no provider.
4. **Parity** — emission logs, traces, and successor state must match.

Run it:

```bash
AILANG_SRC=~/src/ailang AILANG_BIN=~/src/ailang/bin/ailang ./run_world_slice.sh
```

Recorded result on the error path — the live and deterministic traces are identical:

```text
PHASE discovery
PROJECT live content:partial-1
PROJECT live content:partial-2
PHASE replay
PROJECT replay content:partial-1
PROJECT replay content:partial-2
SLICE live_trace=content:partial-1/content:partial-2/outcome:err:code:ConnectionFailed/
SLICE replay_trace=content:partial-1/content:partial-2/outcome:err:code:ConnectionFailed/
```

Both modes pass. The runner also fails all eight assertions and exits 1 against the stock v0.26.0
toolchain, so the harness is load-bearing rather than vacuously green. The `program_non_empty`
assertion exists specifically to catch a vacuous pass: two *empty* emission logs are trivially
equal, and an empty log is exactly what the current API produces.

### What the slice established

- **The proposed shape destructures cleanly into D1.** `{chunks, outcome}` maps onto
  `{intermediate_emissions[], response}` with no contortion — `emissions: map(describe,
  recorded.chunks)`, `outcome: summarize(recorded.outcome)`. The probe compiled first try. This was
  the main open question and the answer is favourable.
- **Live/deterministic parity holds on both outcomes**, including partial-stream-then-error, which
  is the case the trace contract most depends on.
- **Chunk arrival times cannot be observed.** The callback's closed `{IO}` row rejects `Clock`
  exactly as it rejects `SharedMem`:

  ```text
  incompatible closed rows: r1 has extra labels [], r2 has extra labels [Clock]
  ```

  and the returned `[StreamChunk]` carries no offsets. This looked like a gap against D2's "ordered
  stream chunks with non-decreasing virtual offsets" — but it is not one: discovery **generates**
  latency from the seeded generator rather than observing it, and replay takes offsets from the
  recorded program. The live adapter only ever needs arrival *order*, which it has. Recorded here so
  a future reader does not re-derive it, and so the upstream ask can stay focused rather than
  acquiring a speculative timestamp requirement.
- **Projection and trace-append are necessarily separate transitions for stream chunks.** Projection
  happens inside the callback, during the provider call; the append happens after it returns. D6
  asks the implementation to centralize "append to returned trace + emit projection" so neither
  channel can be updated silently without the other — for chunks that is structurally impossible,
  and the invariant has to be enforced by a parity check instead of by a shared code path. D1
  already anticipates the split; this is a note for the implementation plan, not a defect.

## Stale-compile-cache caveat (added 2026-07-24, corrected 2026-07-25)

> **Correction.** This section previously claimed that `ailang` resolves a *different, newer*
> `std/ai` for files outside a project source root. **That is false** and was independently
> disproved on 2026-07-25: a loose file in a scratch directory outside every project resolves the
> pinned stdlib correctly. The original diagnosis was wrong, and the wrong version of it reached a
> draft of `../UPSTREAM-REQUEST-ailang-recorded-stream-api.md` before review caught it. The real
> cause is below.

For a period, `probe_real_stream_callback.ail` failed when run **from this directory** with a
`Message` record-field mismatch over the v0.30.0 vision-input `images` field, while the same file
checked clean everywhere else.

The cause was a **stale local compile cache**. The 2026-07-24 v0.30.0 audit was run from this
directory and left `spike/.ailang/cache/compile/modules/std__ai` holding a v0.30.0 `std/ai`
interface. The pinned v0.26.0 compiler then silently reused that cached interface — no version
check, no warning — and reported a type error against correct source. Removing the cache directory
restored normal behaviour:

```bash
cp -r spike /tmp/spikecopy && cd /tmp/spikecopy
ailang check probe_real_stream_callback.ail   # record field mismatch ... extra fields: images
rm -rf /tmp/spikecopy/.ailang
ailang check probe_real_stream_callback.ail   # ✓ No errors found!
```

The stale cache has been deleted. The probe needs no editing and never did; it passes from this
directory on a clean cache. The two expected-negative probes and `stream_capture_probe.ail` were
unaffected throughout — they reproduce identically in every context (re-verified 2026-07-25,
including `live_projections=17 final_passes=1 bad_markers=0` and `parallel_passes=8 bad_markers=0`).

The lesson, corrected: **a stale `.ailang/cache/compile` written by a different compiler version
silently poisons type resolution, and the resulting error blames your source.** When a type error
contradicts the stdlib you believe you are using, suspect cache invalidation before you suspect the
compiler — and clear the cache before quoting any result upstream. (That missing version check is
itself a defensible AILANG bug, and a separate report from the recorded-stream request.)

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
