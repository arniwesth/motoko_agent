# Upstream request (DRAFT — not submitted): recorded-stream API for `std/ai.stepWithStream`

**Status**: Draft for review. **Nothing has been sent.**
**Target**: `sunholo-data/ailang`
**Blocks**: `ADR-001-deterministic-test-world-architecture.md` (this project) — acceptance is gated
on this API landing plus a direct positive integration probe against the pinned runtime.
**Recommended channel**: Channel 2 (`ailang messages send --github`) for auto-triage envelope
metadata, falling back to Channel 1 (direct GitHub issue) if the pre-flight check reports
`NEEDS SETUP`. Per `.claude/skills/ailang-feedback`.
**Category**: `feature` — the ask is concrete new API surface. (`limitation` is the defensible
alternative; the errors below are correct and clear, so this is not a diagnostics pattern for the
skill's pattern table.)

---

## Submission fields

- **title**: `Feature: recorded-stream API — stepWithStream cannot return the observed chunks`
- **category**: `feature`
- **ailang_version**: `AILANG v0.26.0` (commit `3b52a24d24431c372ed5605289ef039592209514`, built
  2026-07-15) — verified locally with `ailang --version`; repo floor is `ailang = ">=0.26.0"`.
- **from**: `motoko_agent`

## Body (submission-ready)

### Summary

`std/ai.stepWithStream` delivers streamed chunks to a callback but gives the caller no way to
**retain** them. The callback must return `()`, its effect row is closed to `{IO}`, and the API's
result type (`Result[StepResult, AIError]`) does not carry the observed chunk list. A caller can
therefore stream chunks live, **or** nothing — there is no supported way to do both live delivery
and exact capture.

We would like an API that preserves immediate callback delivery **and** returns the exact ordered
observed chunks.

### Why this matters

We are building deterministic replay testing for an agent loop. Two properties must hold at once:

1. **Live visibility is production behavior.** Chunks must reach the UI as they arrive; buffering
   them would be a real behavior change, so a test-only "collect then emit" path is not equivalent.
2. **The exact ordered chunks must land in an immutable trace**, so an execution can be replayed
   and its invariants asserted over the recorded trace.

Today we can satisfy either one, never both.

### Reproduction

Two minimal standalone modules, both confirmed with `ailang check` outside our source tree on
v0.26.0.

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
[function application at repro_a.ail:27:17]: failed to unify parameter 4:
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
[function application at repro_b.ail:29:17]: failed to unify parameter 4:
failed to unify effect rows: incompatible closed rows: r1 has extra labels [],
r2 has extra labels [SharedMem]
```

**Positive control** — the current contract works as documented; an `IO`-only callback is invoked
twice (`ContentDelta`, then `Usage`) and a final result is returned:

```text
$ ailang run --caps AI,IO --ai-stub --entry main probe_real_stream_callback.ail
LIVE content {"kind":"Wait"}
LIVE usage
PASS real_stream_callback stop
```

Both errors are correct and clearly worded given the current signature. This is an API capability
gap, not a diagnostics problem.

### Expected vs actual

- **Expected**: a caller can receive chunks immediately *and* obtain the identical ordered chunk
  sequence for recording.
- **Actual**: chunks are observable only as a side effect inside an `IO`-only, unit-returning
  callback; the result value discards them.

### What we tried, and why each is insufficient

| Approach | Outcome |
|---|---|
| Return an accumulator from the callback | Rejected — callback must return `()` (repro A) |
| Tee each chunk to a `SharedMem` recorder scope | Rejected — closed effect row excludes `SharedMem` (repro B) |
| Read the chunk list off the result | Not available — result is `Result[StepResult, AIError]` |
| Project chunks to stdout and reconstruct | Works, but moves the oracle out of the driver onto parsed wire output — unacceptable for our trace contract |

We separately validated that a CAS-claimed, request-scoped recorder is behaviorally sound once a
callback is *allowed* to perform its effect: 6/6 representation tests pass (success and
partial-stream-then-error), 17/17 projection parity (exactly one projection per supplied chunk),
and 8 parallel independent evaluators using identical fixed scopes all pass with no cross-process
collision. So the blocker is purely the callback/result contract, not the recording design.

### Requested remedy

**Preferred** — a recorded-stream entry point (new function or richer result type) that keeps
immediate callback delivery and additionally returns the exact ordered observed chunks. Sketch, not
a prescription:

```ailang
-- returns the final result *and* the chunks exactly as delivered to the callback
stepWithStreamRecorded(
  model: string, messages: [Message], tools: [...], opts: [...],
  on_chunk: (StreamChunk) -> () ! {IO}
) -> Result[{ result: StepResult, chunks: [StreamChunk] }, AIError] ! {AI}
```

**Fallback** — widen the callback's effect row (row-polymorphic, or `{IO, SharedMem}`) so a caller
can install its own recorder. We consider this strictly worse for our use case: it pulls
`SharedMem` into a capability profile we deliberately keep narrow, weakening the
capability-based hermeticity the deterministic profile relies on. It would need a separate
capability judgment on our side.

Either remedy unblocks us; the first requires no capability-model change.

### Version note

Rechecked against **v0.30.0** (release commit `e37b370d1d7a9c4e7136b319e38bec4d5f2bd9a0`) via the
repository-configured AILANG MCP on 2026-07-24: the released source and compiler preserve the same
callback and result contract, so upgrading from v0.26.0 does not remove the blocker.

---

## Verification record (for the reviewer, not for submission)

Both reproductions were copied out of the Motoko tree into a fresh scratch directory, renamed to
standalone modules, and re-checked — per the skill's "confirm it reproduces standalone" rule. The
error text quoted above is the verbatim output of those runs on the local `v0.26.0` binary, not the
text recorded in the spike.

Source probes (unmodified originals) live in `spike/`:
`probe_state_returning_callback_rejected.ail`, `probe_sharedmem_callback_rejected.ail`,
`probe_real_stream_callback.ail` (positive control), `stream_capture_probe.ail` (representation
tests). `spike/README.md` carries the full command list and result transcript.

## Reviewer checklist before sending

1. Confirm the requested-remedy sketch is the shape we actually want — it is the one thing here
   that is a *proposal* rather than a verified fact, and it will anchor the upstream design
   discussion.
2. Decide `feature` vs `limitation` (routing differs).
3. Decide whether to link the public repo/spike, or keep the report self-contained as drafted.
4. Choose the channel and run its pre-flight:
   `test -f ~/.ailang/config.yaml && grep -q "default_repo" ~/.ailang/config.yaml || echo "NEEDS SETUP"`
   plus `gh auth status`.
5. Confirm we want `contact` set (currently unset) for follow-up.
