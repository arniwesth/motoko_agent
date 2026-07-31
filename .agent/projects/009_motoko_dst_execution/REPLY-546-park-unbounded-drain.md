# Reply to ailang#546 review — the park on the unbounded drain

Draft reply to https://github.com/sunholo-data/ailang/issues/546#issuecomment-5144770360
(`sunholo-voight-kampff`, 2026-07-31T15:48Z). Not yet posted.

Everything below was verified first-party against `sunholo-data/ailang@dev` (fetched
2026-07-31), not only against our v0.31.0 clone.

---

Thanks — and thanks for reviewing the patch rather than reinventing it.

Answering the question you asked directly: **(c)**, and I'd argue against **(b)** specifically.
But the reason is a fact about the current code that I think changes the cost/benefit rather
than a preference between the three, so let me lead with it.

## The fail-loud path has no reachable trigger at HEAD

`ai.StreamChunk` is a **sealed** interface — `internal/ai/provider.go:160-162` closes it with an
unexported `streamChunkMarker()`, so only types declared in package `internal/ai` can satisfy it.
Repo-wide at `dev` there are exactly three implementers:

```
$ grep -rn 'streamChunkMarker()' --include='*.go' . | grep -v _test
internal/ai/provider.go:162     streamChunkMarker()          # the interface
internal/ai/provider.go:172     func (StreamContentDelta)
internal/ai/provider.go:198     func (StreamThinkingDelta)
internal/ai/provider.go:213     func (StreamUsage)
```

`encodeStreamChunk` (`internal/effects/ai_step.go:422` at `dev`) has a case for all three.
And every provider call site passes a concrete struct value — `handler.go:367,369`,
`anthropic/streamstep.go:312,334,345,391`, `openai/streamstep.go:255,269,281,284`,
`gemini/streamstep.go:188,195,219` — so a nil interface can't arrive either.

**The `default: return nil` branch is therefore unreachable at v0.31.0 and at `dev`.** The
unencodable chunk that triggers fail-loud, that triggers the drain, that motivates the
cancellation dependency, cannot occur today.

That makes **(b)** hard to justify: a 7-implementer interface change reaching WASM, which
forfeits the purely-additive property your ADOPT verdict and the 1.x-stability claim rest on,
to make cancellable a path with no reachable trigger. **(c)** is cheap insurance and I'd take it
on those terms — bounded drain, no interface change, hazard capped if the path ever opens.

If cancellation is worth doing, I'd suggest it's worth doing on its own merits for the whole AI
surface — deadlines on live streams are a real user-facing need independent of recording — and
not as a blocking dependency of this.

## The real hazard is exhaustiveness, not cancellation

What makes that branch reachable is someone adding a fourth variant in `internal/ai` without
updating `encodeStreamChunk`. Go will not complain: the switch stays well-typed and the new
variant silently falls to `default`. Your own comment names the candidate —
`provider.go:157`, *"Future variant: ToolCallDelta — see M-AI-STEP-STREAMING-TOOLS"*.

So the guard that actually closes this is an exhaustiveness check on the sealed set, failing at
the point a variant is introduced rather than at runtime in a customer's stream. That is
cheaper than either bounding the drain or changing the interface, and it protects the existing
`stepWithStream` too, which has the same blind spot today.

I'd suggest that milestone regardless of which of (a)/(b)/(c) you pick.

## One divergence worth being deliberate about

The existing `aiStepWithStream` **already** silently skips an unencodable chunk — same two
lines, shipped: `internal/effects/ai_step.go:380-382` at `dev`. My patch inherits that verbatim,
deliberately, so the siblings differ only in return shape.

Adopting fail-loud in the recorded op alone means the two ops behave differently on identical
provider input: one skips and completes, the other returns typed `Internal` and drains. That may
well be what you want — but it should be a decision, not a side effect, because the equivalence
"the recorded sibling is the existing op plus a log" is precisely what makes it safe for us to
swap in. Either apply the invariant to both, or document the divergence in the LongDesc.

## On "silently skipping contradicts a lossless contract"

Agreed on the principle — but I'd separate *lossless* from *not-silently-wrong*. For replay we
don't need a guarantee that no chunk is ever dropped; we need a guarantee that we can never
mistake an incomplete log for a complete one.

The design doc already defines exactly the mechanism for that: `provider_chunks` vs
`delivered_chunks` (§Count invariant). The gap is that it puts them in **trace metadata**, which
is invisible at the AILANG level — the consumer holding the `{chunks, outcome}` record cannot
see them. Surfacing that discrepancy to the consumer (a counter on the record, or the fatal
index in the typed error, which the doc already specifies) satisfies no-silent-fallback without
requiring the stream to terminate at all. Fail loud at the consumer, where the replay contract
actually lives.

That's an option worth having on the table beside (a)/(b)/(c), and it's orthogonal to the drain.

## Scheduling — no consumer pressure, choose on merit

None of (a), (b) or (c) changes the `{chunks, outcome}` type, so none of them changes a line of
our consumer code. There is nothing for us to wait on between them.

And on "keep Project 009 blocked rather than waiting on us" — that's the right call and we've
already acted on it. A spike through the real driver this week found that the change adjacent to
this API on our side (widening our own `Ports.model_step` to carry an emission log) has no
upstream dependency at all; the chunks were dying one layer above `std/ai` regardless. Doing
that first shrinks eventual adoption of `stepWithStreamRecorded` to a single closure. So please
take the time the decision deserves.

Also noted: the two false "the callback's effect row is open" claims, and the credit. Both
appreciated. I'll come back separately on the five motoko PRs.

---

## Notes for us (not part of the reply)

- The reachability finding is new — it wasn't in the issue body and it isn't in the design doc's
  risk table, which lists "provider cannot be cancelled after representation failure" at Medium
  without noting the trigger is unreachable.
- Their §Count invariant already rejected "skip and call the log lossy" on no-silent-fallback
  grounds. We are not relitigating that; we're pointing out their own counters already make the
  loss non-silent if surfaced one layer up.
- Nothing here changes our sequencing. F2 (port widening) remains the next code item.
