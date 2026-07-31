<!--
FILL-IN GUIDE FOR THE GITHUB ISSUE FORM — sunholo-data/ailang

  Form:  https://github.com/sunholo-data/ailang/issues/new?template=feature_request.yml
  Title: Feature: recorded-stream API — stepWithStream cannot return the observed chunks (implementation available)

This is NOT a single paste. `.github/ISSUE_TEMPLATE/feature_request.yml` is a GitHub *issue form*
with five fields. Each `### FIELD n` heading below maps to one textarea/dropdown — paste the block
under it, without the heading itself.

  FIELD 1  What problem does this solve?   (textarea, REQUIRED)
  FIELD 2  Proposed Solution               (textarea, REQUIRED)
  FIELD 3  Alternatives Considered         (textarea, optional)
  FIELD 4  Area                            (dropdown, REQUIRED) -> "AI Integration"
  FIELD 5  Additional Context              (textarea, optional)

Do NOT set labels by hand: the form applies `enhancement` automatically.

The form's own preamble says "Focus on the *use case* — the 'what and why' — not the
implementation." Fields 1-3 are therefore written use-case first; all implementation detail lives
in field 5, where it does not compete with the argument.

Duplicate check RE-RUN 2026-07-31 (searches must include closed issues — the nearest
neighbour is closed, so the default is:open filter hides it):
  is:issue stepWithStream  -> no results
  is:issue stream chunk    -> #223 (zlib), #136 (closed)
  is:issue streaming       -> #136 #137 #138 (all closed), #81/#82 (test issues)
  is:issue recorded        -> nothing relevant
No duplicate. Nearest neighbour remains #136 (generic std/stream primitives), closed,
different ask. #137/#138 are closed WASM browser-streaming issues — adjacent to the
native-only note in field 5, not duplicates.

Implementation is public at
  https://github.com/arniwesth/ailang/compare/v0.31.0...spike/motoko-009-prototype-v031
(branch and the v0.31.0 tag both pushed to that fork, so the compare renders for anyone).
A standalone patch sits beside this file as recorded-stream-v0.31.0.patch; it applies clean
to the tag (verified with `git apply --check`).
-->

### FIELD 1 — What problem does this solve?

We're building deterministic replay testing for an agent loop written in AILANG
([motoko_agent](https://github.com/arniwesth/motoko_agent)). To replay a run we have to record what
the model actually streamed, and `std/ai.stepWithStream` gives us no way to retain it.

Two properties must hold **at the same time** for the use case, and today we can have either but
never both:

1. **Live visibility is production behaviour.** Chunks must reach the UI as they arrive. Buffering
   them and emitting at the end is a real behaviour change, so a test-only "collect then flush"
   path is not equivalent to what ships.
2. **The exact ordered chunks must land in an immutable trace**, so a run can be replayed and its
   invariants asserted against the recording.

The blocker is the callback/result contract: the callback must return `()`, its effect row is
closed to `{IO}`, and the result type `Result[StepResult, AIError]` does not carry the observed
chunks. So chunks are observable only as a side effect that nothing can capture.

**Expected**: a caller can receive chunks immediately *and* obtain the identical ordered sequence
for recording.
**Actual**: chunks are visible only inside an `IO`-only, unit-returning callback; the result value
discards them.

#### Reproduction

Two minimal standalone modules. **(A) the callback cannot thread an accumulator** — it must return `()`:

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

**(B) the callback cannot tee to a side-channel** — its effect row is closed and rejects `SharedMem`:

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

("parameter 4" is the zero-indexed 5th argument — the `on_chunk` callback.)

Both errors are correct and clearly worded given the current signature. **This is an API capability
gap, not a diagnostics problem** — we are not asking you to change these messages.

**Positive control** — we can drive the current API correctly, so this is not user error. An
`IO`-only callback fires twice and a typed result comes back:

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

(Drop `images: []` on v0.26.0, where `Message` has four fields.) The only thing we cannot do is
*retain* those two chunks.

### FIELD 2 — Proposed Solution

An **additive** entry point that keeps immediate callback delivery and additionally returns the
exact ordered observed chunks:

```ailang
export func stepWithStreamRecorded(
  model: string,
  messages: [Message],
  tools: [ToolSchema],
  cache_breakpoints: [CacheBreakpoint],
  on_chunk: (StreamChunk) -> () ! {IO}
) -> { chunks: [StreamChunk], outcome: Result[StepResult, AIError] } ! {AI}
```

Three properties are load-bearing for us. **If you reshape the surface, these are what we actually
need — the signature above is just one way to get them:**

1. **Both delivery and capture, not either.** `on_chunk` must still fire as each chunk arrives.
   Returning the list *instead of* invoking the callback would silently remove live streaming,
   which is the reason we cannot simply buffer today.
2. **Chunks on both outcomes.** This is why the return is a record rather than
   `Result[{result, chunks}, AIError]` — that shape has nowhere to put chunks when the stream
   fails, and a partial stream followed by an error is precisely the run we most need a trace for.
3. **Identity, not reconstruction.** The returned chunks must be the values delivered to
   `on_chunk`, in the same order — not re-derived from the final message. Concatenating the
   `ContentDelta` payloads must still equal `StepResult.message.content`, per your own documented
   invariant. Our test asserts this by value identity, not equality.

**Why additive.** `stepWithStreamRecorded` breaks no existing caller; widening `stepWithStream`'s
own return type would break every current user. We prefer the additive form for that reason and
because it is likelier to land — while acknowledging it adds a fourth `step*` variant, which you
may reasonably not want. **If you would rather have one entry point with a richer result, we are
happy either way** — the three properties matter, the spelling does not.

We have implemented and tested this against the `v0.31.0` tag (details and diff in *Additional
Context*). **We are happy to open a PR if you want it in this shape**, or to drop it entirely if
you would rather design the surface yourselves — the evidence stands either way.

### FIELD 3 — Alternatives Considered

| Approach | Outcome |
|---|---|
| Return an accumulator from the callback | Rejected — callback must return `()` (repro A) |
| Tee each chunk to a `SharedMem` recorder scope | Rejected — closed effect row excludes `SharedMem` (repro B) |
| Read the chunk list off the result | Not available — result is `Result[StepResult, AIError]` |
| Project chunks to stdout and reconstruct | Works, but moves the oracle out of the driver onto parsed wire output — unacceptable for our trace contract |
| Buffer chunks and emit them after completion | Rejected by us, not by the compiler — it changes live streaming UX, which is production behaviour |

We separately validated the recording design itself against a modelled provider — success,
partial-stream-then-error, scope isolation and 8-way process parallelism all pass — so the blocker
is the callback/result contract, not our recorder.

**A fallback we are explicitly *not* asking for**, listed only so the design space is complete:
widening the callback's effect row (row-polymorphic, or `{IO, SharedMem}`) would let a caller
install its own recorder. We do not want it — it puts `SharedMem` into an otherwise hermetic
capability profile, and a scoped recorder is more machinery than a returned list for the same
result. If you prefer it, we can work with it, but the record-returning shape is both smaller and
stricter.

### FIELD 4 — Area

`AI Integration`

(If you'd rather route by surface than by subsystem, `Standard Library` also fits — the change is
in `std/ai`.)

### FIELD 5 — Additional Context

#### The implementation

Against **`v0.31.0`** (`1f6f7dd28dd22ce0e0d84d818a37fce874f1c351`). Browsable diff:

**https://github.com/arniwesth/ailang/compare/v0.31.0...spike/motoko-009-prototype-v031**

or `git remote add arniwesth https://github.com/arniwesth/ailang.git && git fetch arniwesth
spike/motoko-009-prototype-v031`. Five files, +452 lines, no deletions, no provider changes:

| File | Change |
|---|---|
| `internal/effects/ai_step.go` | new `aiStepWithStreamRecorded` returning the `{chunks, outcome}` record |
| `internal/builtins/ai_step.go` | registers `_ai_step_with_stream_recorded` and its type |
| `std/ai.ail` | exports `stepWithStreamRecorded` + the `RecordedStream` type |
| `internal/effects/ai_step_with_stream_recorded_test.go` | tests (below) |

Recording happens where the AILANG closure is already wrapped into the Go `onChunk` callback — one
`append` beside the existing `chunkCount++`, reusing the value `encodeStreamChunk` already builds.
`Provider.StepWithStream`, its five implementations and SSE handling are untouched, so no provider
changes and the NO-OP fallback path is inherited unchanged.

```text
$ go test ./internal/effects/ -run TestAIStepWithStream -v
--- PASS: TestAIStepWithStreamRecorded_ReturnsDeliveredChunksOnSuccess
--- PASS: TestAIStepWithStreamRecorded_ReturnsChunksOnErrorPath
--- PASS: TestAIStepWithStreamRecorded_ContentDeltaConcatEqualsMessageContent
--- PASS: TestAIStepWithStream_UnchangedByRecordedVariant
--- PASS: TestAIStepWithStream_FiresContentDeltaAndUsageChunks
--- PASS: TestAIStepWithStream_HandlerErrorReturnsErrResult
--- PASS: TestAIStepWithStream_NoFnCallerWiredReturnsTypedErr
--- PASS: TestAIStepWithStream_EncodesThinkingDeltaCorrectly
--- PASS: TestAIStepWithStream_PassesCacheBreakpointsToHandler
ok      github.com/sunholo-data/ailang/internal/effects
```

The last five are your existing tests, unchanged and still passing.
`TestAIStepWithStream_UnchangedByRecordedVariant` additionally pins that `stepWithStream` still
returns `Result[StepResult, AIError]` directly rather than a record, so the change is additive by
test and not only by inspection.

The error-path test needed a new fake handler that emits chunks *then* fails: the existing
`fakeStepHandler` returns before emitting anything when `Step` errors, so "partial stream, then
failure" — the case this request is about — was previously untestable in your suite.

#### We have driven this through a real consumer, not just a probe

Our original evidence was a standalone probe: does the API return the chunks. That is necessary but
weak — it does not show the shape is *usable*. We have since built the consumer.

We threaded a record/replay layer through our real session driver — the production loop, not a
harness around it — and ran the same program twice: once live through `stepWithStreamRecorded`
under `--ai-stub`, recording what came back, and once replaying that recording deterministically
with no provider call. The two agree on the emission log, the interaction log and the normalised
trace:

```text
discovery_emissions = content:{"kind":"Wait"} | usage
replay_emissions    = content:{"kind":"Wait"} | usage
discovery_interactions = provider::msgs=2
replay_interactions    = provider::msgs=2
```

The check is non-vacuous — it asserts the recording is non-empty, since two empty logs would
compare equal — and load-bearing: seeding the replay with a deliberately wrong chunk fails it.

**The part likely most useful to you:** building the consumer showed the remaining work is mostly
*on our side, not yours*. Our own provider seam discarded the chunk list one layer above `std/ai`,
so landing this API alone would have changed nothing for us until we fixed that too. We mention it
because it means we are not asking you to speculate about whether we would use this — we have
already paid the consumer-side cost against a local build of the proposal, and the only remaining
gap is the API.

#### Version coverage

The gap is current at three points, each checked by compiling — not by reading docs:

| Version | Evidence |
|---|---|
| **v0.26.0** (our pinned floor) | Both repros above, commit `3b52a24d24431c372ed5605289ef039592209514` |
| **v0.30.0** (released) | Both repros reproduce identically. Release archive SHA-256 `58561c11ca7be7710b3b4eca9ddfdf263f39bc4e36428969a1968175f10b84b6`, compiler reports commit `e37b370d1d7a9c4e7136b319e38bec4d5f2bd9a0`. `std/ai.ail:331-337` carries the same signature |
| **v0.31.0** (current release, `1f6f7dd28dd22ce0e0d84d818a37fce874f1c351`) | `std/ai.ail:330-337` still carries `on_chunk: (StreamChunk) -> () ! {IO}` returning `Result[StepResult, AIError]`; `grep -c stepWithStreamRecorded std/ai.ail` is `0`. This is the tag the proposal is implemented against |

On v0.30.0 and later the positive control additionally needs `images: []` in its `Message` literal
— that is the v0.30.0 vision-input widening, unrelated to streaming, mentioned only so the change
is not misread as a streaming regression.

#### Known gap: native-only

The variant is native-only. `cmd/wasm/effects.go` has its own `WasmAIHandler.StepWithStream` and a
documented `ailangSetAIStepWithStreamHandler` JS hook; we did not add a browser-side counterpart,
since the JS `Response` contract is yours to extend and we did not want to presume its shape. We
note #137/#138 covered the browser-side callback contract separately, so that seam looks like yours
to shape rather than ours to guess at.

#### Related issues

Checked before filing: #136 (generic bidirectional `std/stream` primitives, closed) is the nearest
neighbour and a different ask — it is about stream *transport*, not about retaining what a model
streamed through `std/ai`. #137/#138 (closed) are WASM browser-streaming issues, adjacent to the
native-only note above.

#### Unrelated docs-side observation

Offered separately, ignore if known: the stdlib snapshot served by the public docs MCP for `0.30.0`
does not list `stepWithStream` under `std/ai` at all — its function list ends at `stepWithCache`,
and `runTools` is likewise absent — even though the same version's `StreamChunk` docstring still
describes it as *"one event emitted by stepWithStream's on_chunk callback"* and the guide *"Browser
`ai.step` with BYO API key"* documents its handler contract. Looks like a snapshot/indexing gap
rather than an API removal.
