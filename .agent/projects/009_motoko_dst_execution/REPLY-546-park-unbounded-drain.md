# Reply to ailang#546 review — the park on the unbounded drain

Reply to https://github.com/sunholo-data/ailang/issues/546#issuecomment-5144770360
(`sunholo-voight-kampff`, 2026-07-31T15:48Z).

**POSTED** 2026-08-01T04:21:07Z as
https://github.com/sunholo-data/ailang/issues/546#issuecomment-5149769680
(edited before posting; the version on the issue is authoritative).

All line citations below were verified by `git grep` / `git show` against
`sunholo-data/ailang@130ad1da2` — the exact HEAD the maintainer reproduced at — and re-checked
against `upstream/dev` = `386cf6d15` (9 commits ahead), where they are unchanged.

---

Direct answer to the question you asked: **(c)**, and I'd argue specifically against **(b)**.
But my reason is a structural fact about the current code rather than a preference between the
three, so let me lead with that.

(Letters throughout refer to the park's options — land-with-caveat / cancellation-dependency /
bound-locally. The design doc's §Count invariant uses a second, unrelated (a)/(b)/(c); where I
mean that one I name it in words.)

## The fail-loud path has no reachable trigger

`ai.StreamChunk` is a **sealed** interface — `internal/ai/provider.go:160-162` closes it with an
unexported `streamChunkMarker()`, so only types declared in package `internal/ai` can satisfy it.
Repo-wide and tests included, the grep returns the interface, its doc line, and exactly three
implementers:

```
$ git grep -n 'streamChunkMarker' 130ad1da2 -- '*.go'
130ad1da2:internal/ai/provider.go:160:	// streamChunkMarker is intentionally unexported — closes the type
130ad1da2:internal/ai/provider.go:162:	streamChunkMarker()
130ad1da2:internal/ai/provider.go:172:func (StreamContentDelta) streamChunkMarker() {
130ad1da2:internal/ai/provider.go:198:func (StreamThinkingDelta) streamChunkMarker() {
130ad1da2:internal/ai/provider.go:213:func (StreamUsage) streamChunkMarker() {
```

`encodeStreamChunk` (`internal/effects/ai_step.go:422`) has a case for all three; its
`default: return nil` is at `:447-448`. The only other way to reach that branch is a nil
interface value, and the one call site that forwards a variable rather than a struct literal —
`cmd/wasm/effects.go:244` — is guarded by `if chunk != nil` at `:243`. Every other invocation
constructs a concrete variant inline.

**So the unencodable chunk that triggers fail-loud, that triggers the drain, that motivates the
cancellation dependency, cannot occur at `130ad1da2` or at `dev`.** Identical result at both.

A corollary you'll hit in M1: the merge requirement for "unencodable first and middle chunks"
can only be written by having a fake handler call `onChunk(nil)`. The seal stops `internal/effects`
from declaring a fourth variant, and no test does today. The guard's only constructible input is
one no provider can produce.

## And where chunks *are* actually lost, the guard can't see it

This is the part I'd most like on the record, because it cuts against the completeness
guarantee rather than against the drain.

Unknown wire events never become an unrepresentable `StreamChunk`. They are dropped one layer
lower, in the provider adapters, before the effects layer observes anything:

- `internal/ai/anthropic/streamstep.go:330` switches on `ev.Delta.Type` with **no default** — a
  future delta type is silently ignored, and `onChunk` is never called for it.
- Same file `:336`: `input_json_delta` is accumulated into the block but deliberately **not**
  emitted as a chunk. Tool-call stream content is already absent from any recorded log by
  design — that is the `ToolCallDelta` your `provider.go:158` comment anticipates.
- `cmd/wasm/effects.go:348-366`: `jsToStreamChunk` returns nil for an unrecognised `kind`, and
  `:243` filters it. A JS handler emitting an unknown kind produces no callback, no record, and
  **no increment of your proposed `provider_chunks`** — the loss is invisible to the effects
  layer entirely.

The fail-loud invariant sits at the encoder. The boundary where chunks are actually lost is the
adapter, one layer below it. So as specified, fail-loud adds a completeness guarantee exactly
where nothing can violate it, and does not add one where something can — including on the WASM target
you flagged as the expensive part of (b), and which any WASM counterpart to the recorded op
would inherit.

I don't think that argues against fail-loud, and I'm explicitly **not** proposing you move the
guard down — an unknown wire event has no faithful typed representation, so catching it at the
adapter needs the opaque-byte provider contract §Count invariant already rejected, and that is a
much larger change than the one I'm arguing against in (b).

The ask is smaller: **scope the guarantee honestly in the LongDesc** — the log is exact with
respect to *emitted* chunks, not with respect to the wire. For our replay use that distinction is
fine and we'd rely on it. It just needs to be stated, because "lossless" currently reads as the
stronger claim.

## What that implies for (a)/(b)/(c)

**(b)** becomes hard to justify: a 7-implementer interface change reaching WASM, which forfeits
the purely-additive property your ADOPT verdict and the 1.x-stability claim rest on — to make
cancellable a path with no reachable trigger. If cancellation is worth doing, I'd suggest it's
worth doing on its own merits across the whole AI surface (deadlines on live streams are a real
user-facing need, independent of recording), not as a blocking dependency of this.

**(c)** is cheap insurance and I'd take it on those terms, with the caveat that it bounds a
hazard nothing currently reaches.

What actually pays is neither: the thing that would open that branch is someone adding a fourth
variant in `internal/ai` without updating `encodeStreamChunk`. Go will not complain — the switch
stays well-typed and the new variant falls to `default`. An **exhaustiveness guard over the
sealed set**, failing at the point a variant is introduced rather than at runtime in someone's
stream, closes it more cheaply than either bounding the drain or changing the interface, and it
protects the existing `stepWithStream` too. Happy to send that as a separate small patch if it's
wanted — it's independent of this issue.

## One divergence worth making deliberate

The existing `aiStepWithStream` **already** silently skips an unencodable chunk — same guard,
shipped: `internal/effects/ai_step.go:380-382`. My patch inherits it verbatim and on purpose, so
the siblings differ only in return shape.

Adopting fail-loud in the recorded op alone means the two ops behave differently on identical
provider input: one skips and completes, the other returns typed `Internal` and drains. That may
be exactly what you want, but it should be a decision rather than a side effect — the
equivalence "the recorded sibling is the existing op plus a log" is what makes it safe for us to
swap in. Either apply the invariant to both, or state the divergence in the LongDesc.

## On the no-silent-fallback argument

I've read §Count invariant, and I take the point that skip-and-continue was rejected on
no-silent-fallback grounds rather than overlooked. What I'd push back on is the *silent* premise,
not the principle.

For replay we don't need a guarantee that no chunk is ever dropped. We need a guarantee that we
can't mistake an incomplete log for a complete one. Your design already defines the mechanism
for that — `provider_chunks` vs `delivered_chunks`. The gap is that it puts them in **trace
metadata**, which is invisible at the AILANG level: a consumer holding the `{chunks, outcome}`
record cannot read them and so cannot tell. Surfacing the discrepancy on the record itself
satisfies no-silent-fallback without the stream having to terminate at all — fail loud at the
consumer, where the replay contract actually lives.

Worth having beside (a)/(b)/(c), and orthogonal to the drain either way.

## Scheduling — nothing here gates us, so choose on merit

None of (a), (b) or (c) changes the `{chunks, outcome}` type, so none of them changes a line of
our consumer code. There is nothing for us to wait on between them.

And "keep Project 009 blocked rather than waiting on us" is the right call — we've already acted
on it. A spike through the real driver this week found that the change adjacent to this API on
our side (widening our own `Ports.model_step` to carry an emission log) has no upstream
dependency at all: the chunks were dying one layer above `std/ai` regardless, so no upstream
change alone would have fixed it. Doing that first shrinks eventual adoption of
`stepWithStreamRecorded` to a single closure. Please take the time the decision deserves.

Also noted, and appreciated: the two false "the callback's effect row is open" claims, and the
credit. I'll come back separately on the five motoko PRs.

---

## Notes for us (not part of the reply)

- **New since the issue was filed**: (1) the encoder's `default` branch is structurally
  unreachable; (2) loss happens at the adapter boundary, below the proposed guard, silently, on
  every target. Neither is in the issue body, and the design doc's risk table lists "provider
  cannot be cancelled after representation failure" at Medium without noting the trigger is
  unreachable.
- We are **not** relitigating their fail-loud decision. The reply contests the reachability
  premise and the placement of the guard, not the principle.
- The `input_json_delta` finding is a real caveat for our own replay: tool-call stream content
  is not in the recorded log today, by upstream design. Fine for ADR-001's current scope —
  worth carrying into the D1 work if tool-call streaming ever matters to a scenario.
- If we offer the exhaustiveness-guard patch, it goes on the fork the same way the prototype
  did; it is not part of #546 and should not be bundled into it.
- Nothing here changes our sequencing. F2 (port widening) remains the next code item.
