# Draft reply to `sunholo-data/ailang#578` — cancellable provider context, and the `IncompleteStream` question

**Status: POSTED 2026-08-04T13:25:55Z** by the operator, as the first comment on
[#578](https://github.com/sunholo-data/ailang/issues/578) — 6,335 characters, with a lead-in noting
the overlap with #546. Awaiting a response; nothing is owed back until upstream replies.

This file is retained as the record of what was sent and the checks behind it.

**Supersedes `DRAFT-reply-546-incomplete-stream-error-code.md`**, which was written for #546's context
before #546 closed. #578 differs in three ways that change the reply rather than just its address:

- **#578 has zero comments**, so this is the first thing in the thread.
- **Its body does not restate the `IncompleteStream` question.** Upstream's pointer — *"your
  `IncompleteStream` question is the open thread there"* — is the only link between them, so the reply
  has to re-state the question it is answering or a reader will not know what it is about.
- **Its body explicitly asks for demand evidence**: *"Do NOT start without demand evidence per the
  mission's routing rules"*, alongside *"this is insurance, not a live bug"*. That is the thread's
  actual subject, and we have something to say about it — so it leads.

Permalinks pinned to `arniwesth/motoko_agent@28991c9` (pushed; `1d4b7be` is not).

---

## The reply

Two things for this thread — demand evidence for the cancellable context, and a scope correction that
makes it cheaper than the issue estimates. Then the `IncompleteStream` answer I owe you from #546.

### 1. Demand evidence, honestly scoped

You wrote *"this is insurance, not a live bug"*, and for the unencodable-chunk path that is exactly
right — my own sealed-interface analysis is why. **But the wall-clock residual has a live instance on
our side that is not that path**, and it is filed and open:

> A provider request was dispatched and **never returned a stream nor an error**. The session log
> ends at step 26 with `thinking_stream_start` + `provider_call_prepared`, and then nothing — no
> delta, no stream end, no summary, no error. The loop parked on an unresolved promise and the run
> never terminated. Sibling sessions on the same model terminate cleanly, so it is abnormal rather
> than expectedly bounded.

Free-tier OpenRouter endpoints accept a request and silently drop the stream. There is no
unencodable chunk anywhere in it; the stream simply never ends.

**Two honest qualifications, because the evidence is adjacent rather than identical:**

- **Today that hang is in our TypeScript layer**, in the chat-completion `fetch` that has no
  `AbortController`. We can fix it there, and that is the filed fix.
- **That escape route is closing.** Our DST migration has moved the provider seam into AILANG — the
  driver now threads world state through `Ports.model_step`, and the deterministic and live adapters
  differ only in the closure behind it. As the live path follows, the place to bound a hung provider
  stops being a TypeScript `fetch` and becomes the AILANG provider interface — **which has no context
  to cancel with.** So our demand is not hypothetical, but it is *forward-dated*: we will need this
  before we finish moving the seam, not today.

Treat that as one data point of the kind your routing rules ask for, with its limits stated.

### 2. A scope correction that makes v2 cheaper

The scope note says: *"out-of-repo: at least @arniwesth's driver"*.

**We implement no `AIHandler`.** Motoko is an AILANG *consumer* — the driver is `.ail` calling
`std/ai`; the only Go in our tree is a local clone of yours, git-ignored and not part of our source.
Checked before writing this: zero files outside that clone reference `AIHandler` or `StepWithStream`.

The Go patch I contributed to `internal/effects` was a patch to *your* repo, not evidence of an
implementer in ours. **So your out-of-repo implementer count for this interface change is, as far as
we are concerned, zero** — the blast radius is your 4 production + 3 test doubles. That should make
v2 meaningfully cheaper than the issue currently assumes.

### 3. The `IncompleteStream` question — yes, a first-class code

You asked for one word; the reasoning is what transfers, because **we hit this exact fork in our own
codebase and took it both ways.**

**Where we took it your S1 way.** Our step machine emits the same `Internal` code for two
structurally different failures —
[`step_machine.ail:58`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/step_machine.ail#L58)
(approval with no pending call) and
[`:102`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/step_machine.ail#L102)
(step budget exhausted) — so the driver discriminates them by **matching the message text**
([`session.ail:1535`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/session.ail#L1535)).
We applied the best mitigation available *without* changing the code: the message is one shared
constant referenced by both sides, so an edit cannot desynchronise them. The comment above that
matcher
([`session.ail:1520-1534`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/session.ail#L1520-L1534))
records the residual, and it is your question in our words:

> The `Internal` CODE is deliberately unchanged — the code change was declined because it is
> caller-visible, and grounding it found the consequence is larger: the code is emitted as an `error`
> wire event (`ErrorEvent { code: e.code }`) that the TUI consumes, so a new code would change a wire
> event on every max-steps run. **What remains open: the discrimination is still by message rather
> than by type, so a THIRD `Internal` failure sharing this message would be misclassified. Closing
> that needs the compatibility decision above.**

It is an open issue in our tree, and open *because* the fix is now a compatibility event.

**Where we took it the other way.** Three tool fault classes were introduced as strings and adopted
**verbatim as stable class ids** when the fault catalogue was built
([`dst_fault_catalogue.ail:81-83`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/dst_fault_catalogue.ail#L81-L83)),
asserted on the wire rather than in source — because "both sides reference the same constant" is a
claim about source, not output. That cost nothing, because the ids were right at introduction.

**So, three points:**

1. **The cheap moment is now.** Ours is wire-visible, so changing it later is a compatibility event —
   which is exactly why ours is still open. Yours is not wire-visible yet.
2. **The stated objection cuts the other way.** "It widens the public error vocabulary" — S1 already
   ships `unencodable stream chunk` *as public contract*. The widening has happened, in the form that
   cannot be version-checked or enumerated. A code is versioned and greppable; a message prefix is
   prose that behaves like an API.
3. **What we would do with it.** Our fault catalogue requires a **stable class id** per class, mapped
   to a named recovery branch. With `IncompleteStream` we key on the code. With the prefix we would
   key a versioned artifact on a prose string — the same mistake as (1), committed knowingly.

If the code lands we match on it and drop the prefix match entirely. If it does not, we will match
the prefix and treat it as a versioned surface on your behalf — which works, but puts the stability
burden on a string neither of us can enforce.

*(And separately: thank you for v0.33.0, and for the `js && wasm` reasoning that ruled out the
sentinel-panic abort. That constraint is not one we would have found.)*

---

## Facts checked before drafting

| Claim | How verified |
|---|---|
| #578 has zero comments; its body asks for demand evidence and does not restate the question | issues API |
| We implement no `AIHandler` | `grep -rln 'AIHandler\|StepWithStream' --include=*.go` outside `ailang/`, which is git-ignored → 0 |
| The hang is real, filed and open | `.agent/issues/free-tier-hang-no-timeout.md` |
| The hang is in TypeScript, not the AILANG provider path | same issue's Location section |
| The two `Internal` sites, the matcher, the adopted ids | read at `28991c9` |
| `28991c9` is pushed; `1d4b7be` is not | commits API, 200 vs 422 |
