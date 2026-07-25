<!--
PASTE-READY GITHUB ISSUE BODY — sunholo-data/ailang
Nothing below this comment is internal. Paste the whole file into the issue form.

  Title:  Feature: recorded-stream API — stepWithStream cannot return the observed chunks (implementation available)
  Labels: feature
  File at: https://github.com/sunholo-data/ailang/issues/new

Duplicate check performed 2026-07-25: no existing recorded-stream or streaming-capture
issue. Nearest neighbour is #136 (std/stream WebSocket primitives), a different ask, closed.
-->

We're building deterministic replay testing for an agent loop written in AILANG
([motoko_agent](https://github.com/arniwesth/motoko_agent)), and we've hit a capability gap in
`std/ai.stepWithStream` that we can't work around at the call site. Full reproduction below, plus a
working implementation if you want it.

**Version**: reproduced on our pinned floor, on the current release, and on `dev` — see *Version
coverage* at the end.

```text
AILANG v0.26.0
Commit: 3b52a24
Full:   3b52a24d24431c372ed5605289ef039592209514
Built:  2026-07-15_08:04:20
```

## Summary

`std/ai.stepWithStream` delivers streamed chunks to a callback but gives the caller no way to
**retain** them. The callback must return `()`, its effect row is closed to `{IO}`, and the API's
result type (`Result[StepResult, AIError]`) does not carry the observed chunk list. A caller can
therefore stream chunks live, **or** capture them, but not both.

We would like an API that preserves immediate callback delivery **and** returns the exact ordered
observed chunks.

We have implemented one against `dev` and it is small — an accumulator beside the existing chunk
counter, above the provider layer, with no change to `Provider.StepWithStream`, to SSE handling, or
to `stepWithStream` itself. Details and test results are in *Proposed remedy* below. **We are happy
to open a PR if you want it in this shape**, or to drop it if you would rather design the surface
yourselves — the evidence stands either way.

## Why this matters

Two properties must hold at once for our use case:

1. **Live visibility is production behavior.** Chunks must reach the UI as they arrive; buffering
   them would be a real behavior change, so a test-only "collect then emit" path is not equivalent.
2. **The exact ordered chunks must land in an immutable trace**, so an execution can be replayed
   and its invariants asserted over the recorded trace.

Today we can satisfy either one, never both.

## Reproduction

Two minimal standalone modules.

**(A) The callback cannot thread an accumulator** — it must return `()`:

```ailang
module repro_a

import std/ai (stepWithStream, Message, StepResult, AIError, StreamChunk)
import std/result (Result)

func state_returning_callback(chunk: StreamChunk) -> [StreamChunk] ! {IO} {
  [chunk]
}

export func rejected(messages: [Message]) -> Result[StepResult, AIError] ! {AI} {
  stepWithStream("", messages, [], [], state_returning_callback)
}
```

```text
$ ailang check repro_a.ail
Error: type error in repro_a (decl 1): type unification failed at
[function application at repro_a.ail:11:17]: failed to unify parameter 4:
cannot unify type constructor () with *types.TList
```

**(B) The callback cannot tee to a side-channel** — its effect row is closed and rejects
`SharedMem`:

```ailang
module repro_b

import std/ai (stepWithStream, Message, StepResult, AIError, StreamChunk)
import std/bytes (fromString)
import std/io (println)
import std/result (Result)
import std/sharedmem (put)

func capture(chunk: StreamChunk) -> () ! {IO, SharedMem} {
  let _ = put("stream-capture/probe", fromString(show(chunk)));
  println("captured")
}

export func probe(messages: [Message]) -> Result[StepResult, AIError] ! {AI, IO, SharedMem} {
  stepWithStream("", messages, [], [], capture)
}
```

```text
$ ailang check repro_b.ail
Error: type error in repro_b (decl 1): type unification failed at
[function application at repro_b.ail:15:17]: failed to unify parameter 4:
failed to unify effect rows: incompatible closed rows: r1 has extra labels [],
r2 has extra labels [SharedMem]
```

(In both, "parameter 4" is the zero-indexed 5th argument — the `on_chunk` callback.)

Both errors are correct and clearly worded given the current signature. **This is an API capability
gap, not a diagnostics problem** — we are not asking you to change these messages.

**Positive control** — we can drive the current API correctly, so this is not user error. An
`IO`-only callback is invoked twice (`ContentDelta`, then `Usage`) and a final typed result is
returned:

```ailang
module probe_old_api

import std/ai (stepWithStream, Message, StreamChunk, ContentDelta, ThinkingDelta, Usage)
import std/io (println)

func render(chunk: StreamChunk) -> () ! {IO} {
  match chunk {
    ContentDelta(text) => println("LIVE content ${text}"),
    ThinkingDelta(_) => println("LIVE thinking"),
    Usage(_) => println("LIVE usage")
  }
}

export func main() -> () ! {AI, IO} {
  let messages: [Message] = [{
    role: "user", content: "old api regression probe",
    tool_calls: [], tool_call_id: "", images: []
  }];
  match stepWithStream("", messages, [], [], render) {
    Ok(result) => println("PASS old_api ${result.finish_reason}"),
    Err(error) => println("FAIL old_api ${error.code}")
  }
}
```

```text
$ ailang run --caps AI,IO --ai-stub --entry main probe_old_api.ail
LIVE content {"kind":"Wait"}
LIVE usage
PASS old_api stop
```

(Drop `images: []` when running against v0.26.0, where `Message` has four fields.)

The only thing we cannot do is *retain* those two chunks.

## Expected vs actual

- **Expected**: a caller can receive chunks immediately *and* obtain the identical ordered chunk
  sequence for recording.
- **Actual**: chunks are observable only as a side effect inside an `IO`-only, unit-returning
  callback; the result value discards them.

## What we tried, and why each is insufficient

| Approach | Outcome |
|---|---|
| Return an accumulator from the callback | Rejected — callback must return `()` (repro A) |
| Tee each chunk to a `SharedMem` recorder scope | Rejected — closed effect row excludes `SharedMem` (repro B) |
| Read the chunk list off the result | Not available — result is `Result[StepResult, AIError]` |
| Project chunks to stdout and reconstruct | Works, but moves the oracle out of the driver onto parsed wire output — unacceptable for our trace contract |

We separately validated the recording design itself against a modelled provider — success,
partial-stream-then-error, scope isolation, and 8-way process parallelism all pass — so the blocker
is the callback/result contract, not our recorder.

## Proposed remedy (implemented against `dev`)

An **additive** entry point that keeps immediate callback delivery and additionally returns the
exact ordered observed chunks. Implemented and tested at
`24120ade2ade3560af35e45fddd496fb1901c836`:

```ailang
export func stepWithStreamRecorded(
  model: string,
  messages: [Message],
  tools: [ToolSchema],
  cache_breakpoints: [CacheBreakpoint],
  on_chunk: (StreamChunk) -> () ! {IO}
) -> { chunks: [StreamChunk], outcome: Result[StepResult, AIError] } ! {AI}
```

Three properties are load-bearing for us. If you reshape the surface, these are what we actually
need — the signature above is just one way to get them:

1. **Both delivery and capture, not either.** `on_chunk` must still fire as each chunk arrives.
   Returning the list at the end *instead of* invoking the callback would silently remove live
   streaming, which is the reason we cannot simply buffer today.
2. **Chunks on both outcomes.** This is why the return is a record rather than
   `Result[{result, chunks}, AIError]` — that shape has nowhere to put chunks when the stream
   fails, and a partial stream followed by an error is precisely the run we most need a trace for.
3. **Identity, not reconstruction.** The returned chunks must be the values delivered to
   `on_chunk`, in the same order — not re-derived from the final message. Concatenating the
   `ContentDelta` payloads must still equal `StepResult.message.content`, per your own documented
   invariant. Our test asserts this by value identity, not equality.

**Why additive.** `stepWithStreamRecorded` breaks no existing caller. Widening `stepWithStream`'s
own return type would break every current user. We prefer the additive form for that reason and
because it is likelier to land — while acknowledging it adds a fourth `step*` variant, which you
may reasonably not want. **If you would rather have one entry point with a richer result, we are
happy either way**; the three properties matter, the spelling does not.

**A fallback we are not asking for**, listed only so the design space is complete: widening the
callback's effect row (row-polymorphic, or `{IO, SharedMem}`) so a caller can install its own
recorder. That also works, but it pulls `SharedMem` into a capability profile we deliberately keep
narrow.

### What the implementation touches

Three files, no provider changes:

| File | Change |
|---|---|
| `internal/effects/ai_step.go` | `aiStepWithStream` becomes a thin wrapper over a shared `runStepWithStream` that also returns the accumulated chunks; new `aiStepWithStreamRecorded` returns the `{chunks, outcome}` record |
| `internal/builtins/ai_step.go` | registers `_ai_step_with_stream_recorded` and its type |
| `std/ai.ail` | exports `stepWithStreamRecorded` |

The recording happens where the AILANG closure is already wrapped into the Go `onChunk` callback —
one `append` beside the existing `chunkCount++`, using the value `encodeStreamChunk` already
builds. `Provider.StepWithStream`, its five implementations, and SSE handling are untouched, so no
provider needs to change and the NO-OP fallback path is inherited unchanged.

Tests added in `internal/effects/ai_step_with_stream_recorded_test.go`:

```text
--- PASS: TestAIStepWithStreamRecorded_ReturnsDeliveredChunksOnSuccess
--- PASS: TestAIStepWithStreamRecorded_ReturnsChunksOnErrorPath
--- PASS: TestAIStepWithStreamRecorded_ContentDeltaConcatEqualsMessageContent
--- PASS: TestAIStepWithStream_UnchangedByRecordedVariant
```

plus the five pre-existing `TestAIStepWithStream_*` tests, all still passing. The error-path test
needed a new fake handler that emits chunks *then* fails — the existing `fakeStepHandler` aborts
before emitting anything, so that case was previously untested.

End-to-end from AILANG under `--ai-stub`:

```text
LIVE content {"kind":"Wait"}      <- callback still fires live
LIVE usage
RETURNED count=2                  <- and the same chunks come back
RETURNED order=content:{"kind":"Wait"}|usage|
PASS concat_equals_message_content
PASS recorded_stream stop
```

**Known gap**: the variant is native-only. `cmd/wasm/effects.go` has its own
`WasmAIHandler.StepWithStream` and a documented `ailangSetAIStepWithStreamHandler` JS hook; we did
not add a browser-side counterpart, since the JS `Response` contract is yours to extend and we did
not want to presume its shape.

## Version coverage

The gap is current at three points, each checked by compiling — not by reading docs:

| Version | Evidence |
|---|---|
| **v0.26.0** (our pinned floor) | Both repros above, commit `3b52a24d24431c372ed5605289ef039592209514` |
| **v0.30.0** (released) | Both repros reproduce identically. Release archive SHA-256 `58561c11ca7be7710b3b4eca9ddfdf263f39bc4e36428969a1968175f10b84b6`, compiler reports commit `e37b370d1d7a9c4e7136b319e38bec4d5f2bd9a0`. `std/ai.ail:331-337` carries the same signature: `on_chunk: (StreamChunk) -> () ! {IO}`, returning `Result[StepResult, AIError]` |
| **`dev`** (`24120ade2ade3560af35e45fddd496fb1901c836`) | `std/ai.ail:330-337` unchanged; a full-source search finds no recorded-stream variant. This is where we implemented the proposal |

On v0.30.0 the positive control additionally needs `images: []` added to its `Message` literal —
that is the v0.30.0 vision-input widening, unrelated to streaming, and we mention it only so the
change is not misread as a streaming regression.

---

### Unrelated docs-side observation

Offered separately, ignore if it's known: the stdlib snapshot served by the public docs MCP for
`0.30.0` does not list `stepWithStream` under `std/ai` at all — its function list ends at
`stepWithCache`, and `runTools` is likewise absent — even though the same version's `StreamChunk`
docstring still describes it as *"one event emitted by stepWithStream's on_chunk callback"* and the
guide *"Browser `ai.step` with BYO API key"* documents its handler contract. Looks like a
snapshot/indexing gap rather than an API removal.
