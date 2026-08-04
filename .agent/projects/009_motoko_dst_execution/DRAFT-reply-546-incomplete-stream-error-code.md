# Draft reply to `sunholo-data/ailang#546` — the `IncompleteStream` question

**⚑ DESTINATION CHANGED 2026-08-04: post to [#578](https://github.com/sunholo-data/ailang/issues/578),
not #546.** Upstream's closing comment on #546 — *"Shipped in v0.33.0 … S2 continues under #578 (your
`IncompleteStream` question is the open thread there)"* — moved the thread. The content and the
permalinks are unaffected.

**Status: DRAFT, not posted.** Posting is outward-facing and awaits the operator's decision.
Answering the question asked 2026-08-03T10:20Z and repeated 16:35Z as owed before S2.

All permalinks below are pinned to `arniwesth/motoko_agent@28991c9` — the pushed head of PR #114's
branch. **Note that PR #114's own diff does not contain any of this code**: it is a draft stacked on
`mot-53` and its 21 files are WI-A17's test-coverage tooling. The code that answers the question
landed in earlier branches, so the reply cites commit permalinks rather than the PR.

---

## The reply

**Yes — a first-class `AIError` code. And I can show you the same decision taken both ways inside one
codebase, because we hit this exact fork six weeks ago and have been living with both outcomes.**

You asked for one word; here is the evidence behind it, since the reasoning is what transfers.

### Where we took it your S1 way, and what it cost

Our step machine emits **the same `Internal` code for two structurally different failures** —
[`step_machine.ail:58`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/step_machine.ail#L58)
(approval requested with no pending call) and
[`step_machine.ail:102`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/step_machine.ail#L102)
(step budget exhausted). Because the code cannot tell them apart, the driver discriminates them by
**matching the message text**:
[`session.ail:1535`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/session.ail#L1535).

We did the best available mitigation *without* changing the code: the message is no longer a literal
on either side — both the emitter and the matcher reference one shared constant, so an edit cannot
desynchronise them. The comment above that matcher
([`session.ail:1520-1534`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/session.ail#L1520-L1534))
records what is left, and it is your question in our words:

> The `Internal` CODE is deliberately unchanged — [we] declined the code change because it is
> caller-visible, and grounding it found the consequence is larger than that: the code is emitted as
> an `error` wire event (`ErrorEvent { code: e.code }`) that the TUI consumes, so a new code would
> change a wire event on every max-steps run. **What remains open, stated rather than implied: the
> discrimination is still by message rather than by type, so a THIRD `Internal` failure sharing this
> message would be misclassified. Closing that needs the compatibility decision above.**

It is filed as an open issue, and it is open precisely because the fix is now a compatibility event.

### Where we took it the other way, and what it cost

Our tool contract introduced three fault classes as strings. When the fault catalogue was built, it
adopted them **verbatim as stable class ids** —
[`dst_fault_catalogue.ail:81-83`](https://github.com/arniwesth/motoko_agent/blob/28991c9/src/core/dst_fault_catalogue.ail#L81-L83)
— and asserts them on the wire rather than in the source, because "both sides reference the same
constant" is a claim about source, not about output. That one cost nothing, because the ids were
right at introduction.

### So, three concrete points

1. **The cheap moment is now.** Ours is wire-visible, so changing it later is a compatibility event —
   which is exactly why ours is still open. Yours is not wire-visible yet.
2. **Your stated objection cuts the other way.** "It widens the public error vocabulary" — S1 already
   ships `unencodable stream chunk` *as public contract*. The widening has happened; it has happened
   in the form that cannot be version-checked or grepped. A code is versioned and enumerable; a
   message prefix is prose that behaves like an API.
3. **What we would do with it.** Our D3 fault catalogue requires a **stable class id** per fault
   class, mapped to a named recovery branch. With `IncompleteStream` we key on the code. With the
   prefix we would key a versioned artifact on a prose string — which is the same mistake as (1),
   committed knowingly.

If the code lands we would match on it and drop the prefix match entirely. If it does not, we will
match the prefix and treat it as a versioned surface on your behalf — which works, but puts the
stability burden on a string neither of us can enforce.

*(Separately: thank you for #578 and for the `js && wasm` reasoning on the sentinel-panic abort —
that is a constraint we would not have found, and it is worth having in the design doc.)*

---

## Facts checked before drafting

| Claim | How verified |
|---|---|
| PR #577 merged 2026-08-03T16:55:09Z | GitHub API |
| `std/ai.ail` has `stepWithStreamRecorded` at `dev`, **not** at `v0.32.0` | GitHub contents API at both refs |
| v0.32.0 published 15:22Z, **1h33m before** the merge | releases API |
| The two `Internal` sites and the matcher | read at `28991c9` |
| PR #114 does not contain the cited code | its file list is 21 files, all WI-A17 |
