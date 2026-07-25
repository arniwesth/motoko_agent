# Upstream request (DRAFT — not submitted): recorded-stream API for `std/ai.stepWithStream`

**Status**: Draft for review. **Nothing has been sent.**
**Target**: `sunholo-data/ailang`
**Blocks**: `ADR-001-deterministic-test-world-architecture.md` (this project) — acceptance is gated
on this API landing plus a direct positive integration probe against the pinned runtime.
**Recommended channel**: Channel 1 (direct GitHub issue). Per `.claude/skills/ailang-feedback`,
Channel 1 is "best for bugs you can describe in detail" and yields a tracked URL the blocked ADR
can cite. Channel 2 (`ailang messages send`) takes a *one-line* summary and is a poor fit for a
report this long; Channel 3 (MCP `submit_feedback`) fits the body/snippet shape but returns only a
ticket id, not a URL we can reference.
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

Two minimal modules, both checked **under our project's own module resolution** against our pinned
stdlib (and reproducing identically as loose files elsewhere).

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

Both errors are correct and clearly worded given the current signature. This is an API capability
gap, not a diagnostics problem.

**Positive control** — we can drive the current API correctly, so this is not user error. An
`IO`-only callback is invoked twice (`ContentDelta`, then `Usage`) and a final typed result is
returned:

```text
$ ailang run --caps AI,IO --ai-stub --entry main probe_real_stream_callback.ail
LIVE content {"kind":"Wait"}
LIVE usage
PASS real_stream_callback stop
```

The only thing we cannot do is *retain* those two chunks.

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
immediate callback delivery and additionally returns the exact ordered observed chunks. Sketch
mirroring the existing `stepWithCache`/`stepWithStream` parameter shape — not a prescription:

```ailang
-- identical arguments to stepWithStream; returns the final result *and* the
-- chunks exactly as they were delivered to on_chunk
stepWithStreamRecorded(
  model: string,
  messages: [Message],
  tools: [ToolSchema],
  cache_breakpoints: [CacheBreakpoint],
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

Reproduced on **v0.26.0** (our pinned floor). We also checked **v0.30.0**, the current latest, via
the public AILANG docs MCP on 2026-07-24 and believe the blocker persists — but please correct us
if the released signature differs from what the published docs describe:

- The v0.30.0 `std/ai` module docs describe `StreamChunk` as *"one event emitted by
  stepWithStream's on_chunk callback"* — i.e. chunks are still delivered only as a callback side
  effect.
- The v0.30.0 guide *"Browser `ai.step` with BYO API key"* documents the `stepWithStream` handler
  contract as `(model, messages, tools, breakpoints, onChunk) => Promise<Response>`, and the
  `Response` shape it specifies carries `message`, `tool_calls`, token counts, `finish_reason`, and
  `model` — **no chunk list**. So the result still discards the observed chunks.

Three caveats on that check, stated plainly:

1. We did not install and compile against a v0.30.0 release.
2. The v0.30.0 stdlib snapshot served by the docs MCP does not list a `stepWithStream` entry under
   `std/ai` at all — its function list ends at `stepWithCache` — so we could not read the exact
   v0.30.0 signature or callback effect row from the docs. If that is a snapshot gap rather than an
   API removal, it may be worth fixing independently.
3. Files compiled *outside* a project source root on this machine resolve a newer `std/ai` than our
   pinned one — one whose `Message` already carries the v0.30.0 `images` field. The two failures
   above reproduce under **both** that newer stdlib and our pinned one, which is some evidence the
   callback contract is unchanged across the two — but we state it as an observation, not a claim
   about the released v0.30.0.

---

## Verification record (for the reviewer, not for submission)

Every quoted command output in the body was produced during this review, not transcribed from
`spike/README.md`. All of it now checks out:

- **repro A / repro B** — re-typed from the snippets exactly as published (the originals carry
  comment headers, so the spike's recorded line numbers did not match the abridged code), then
  checked under a real project module path (`scripts/dst/`) against the pinned stdlib **and** as
  loose files. Identical errors in both. The published line numbers match the published snippets.
- **Positive control — re-verified passing** under project module resolution, reproducing the
  spike's recorded output exactly (`LIVE content` / `LIVE usage` / `PASS real_stream_callback stop`).
- **Representation tests re-run**: `PASS returned.{success,partial_error}`,
  `PASS scoped.{success,partial_error,two_scope_isolation,collision_and_cleanup}`, and
  `live_projections=17 final_passes=1 bad_markers=0` — the cited 6/6 and 17/17.
- **8-way parallel isolation re-run**: `parallel_passes=8 bad_markers=0`. Claim confirmed.

### A false finding this review caught and removed

An earlier draft of this document reported, as a secondary bug, that `std/ai.Message` was
unconstructible (a literal supplying `images: []` was rejected as missing `images`, and `ImagePart`
was not exported). **That was wrong and has been deleted.** It was an artifact of running scratch
files *outside* a project source root, where this machine resolves a newer `std/ai` than the
project's pinned one. Under project module resolution the pinned `Message` has four fields, a
four-field literal checks clean (`src/core/ai_compat.ail:193` does exactly this in production), and
the spike's positive control passes. Filing it would have been a false bug report.

The operational lesson, worth keeping: **`ailang check` on a loose file does not resolve the same
stdlib as the project.** Any repro destined for upstream must be validated under a project module
path, not just in a scratch directory.

## Reviewer checklist before sending

Everything factual in this report has been verified. What remains are five judgment calls. Each is
stated with what is at stake and a recommendation.

### 1. The remedy sketch — the only proposal in the document

This will anchor the upstream design discussion, so it is worth more scrutiny than anything else
here. Four sub-decisions:

- **New function vs. changing `stepWithStream`'s return type.** As drafted we ask for an *additive*
  `stepWithStreamRecorded`, which breaks no existing caller. Widening `stepWithStream` itself to
  return chunks would be a breaking change for every current user. *Recommend keeping it additive* —
  it is far likelier to land — while acknowledging in the issue that it adds a fourth `step*`
  variant, which they may reasonably push back on. If they prefer one entry point with a richer
  result, we should say we are happy either way.
- **⚠ The sketch loses chunks on the error path.** `Result[{result, chunks}, AIError]` returns
  chunks only on `Ok`. But partial-stream-then-error is a case we *explicitly validated* in the
  spike (`PASS returned.partial_error`, `PASS scoped.partial_error`) — a trace that drops the
  chunks observed before a failure is exactly the trace we need for a failed run. **This is a real
  omission in the current draft.** *Recommend* asking for observed chunks on **both** outcomes,
  e.g. an error variant that carries them, or a top-level `{chunks, outcome}` shape.
- **Keep the callback.** We need live delivery *and* capture. If we only ask for "return the
  chunks," a reasonable implementer might drop the callback and hand back the list at the end —
  which silently breaks live streaming, our whole reason for asking. The draft keeps `on_chunk`;
  make sure any rewording preserves that both are required.
- **State the identity guarantee.** The returned list must be *the chunks as delivered to the
  callback*, not re-derived from the final message — and their `ContentDelta` concatenation should
  still equal `message.content`, per their own documented invariant.

### 2. `feature` vs `limitation`

Routing differs. `feature` is triaged as an enhancement that can be scheduled; `limitation` risks
being recorded as a known constraint and closed as working-as-intended — which would leave us
blocked with a tidy label. *Recommend `feature`*: we are asking for specific new API surface and
have proposed its shape. Low-regret either way; it is a label, not the argument.

### 3. Link the spike, or stay self-contained

*Recommend staying self-contained, and offering the spike on request.* Two reasons: the report
already carries the essential evidence (both repros, the positive control, the validation figures),
and `.agent/projects/` is our internal working record — linking it exposes project 009's
architecture and roadmap to an external reader for little gain. **Check before linking anything:
confirm whether `arniwesth/motoko_agent` is actually public**, or the links are both useless and a
signal of internal structure.

### 4. Pre-flight

- `gh auth status` — confirm we can file, and note *which account* files it, since that is public
  attribution.
- **Search upstream first**: check `sunholo-data/ailang` issues for an existing recorded-stream or
  streaming-capture request before opening a duplicate. If one exists, add our repros as a comment
  instead — a second reproduction on an existing issue is worth more than a new thread.
- If `gh` is unavailable, Channel 3 (MCP `submit_feedback`) needs no auth, at the cost of a ticket
  id instead of a URL.

### 5. Follow-up contact

*Recommend leaving it unset.* Filing via Channel 1 under a monitored GitHub account already routes
replies to that account and to the issue thread; a separate `contact` is a Channel 3 field with no
benefit here. Worth confirming the filing account is one someone actually watches, since this is a
blocker we want to hear back on.

---

## Review Comments

Reviewer: `claude-opus-5`, 2026-07-25. Independent pre-send review. **Nothing was sent.** Every
quoted figure below was re-executed on this machine; no result was transcribed from `spike/README.md`
or from the drafting session's verification record.

### R1 — Version-note caveat 3 is false, and it misattributes the cause to AILANG module resolution

The report tells upstream (lines 196–200) that "Files compiled *outside* a project source root on
this machine resolve a newer `std/ai` than our pinned one." That is not what happens. The real cause
is a **stale local compile cache** left in `spike/` by the v0.30.0 audit run on 2026-07-24. A loose
file in a scratch directory outside every project resolves the *pinned* four-field `Message`
correctly; only `spike/` diverges, because `spike/.ailang/cache/compile/modules/std__ai` holds a
cached v0.30.0 interface that the pinned v0.26.0 compiler then reuses without a version check.

Sweeping one identical four-field `Message` literal across four directories:

```text
$ for d in <scratchpad> .agent/projects/009_motoko_dst_execution/spike scripts/dst . ; do
    (write zz_msgshape.ail with a 4-field Message literal; cd "$d"; ailang check zz_msgshape.ail)
  done

<scratchpad>                                  ✓ No errors found!
.agent/.../spike    record field mismatch: expected 4 fields, got 5
                    actual fields: {content, images, role, tool_call_id, tool_calls}
scripts/dst                                   ✓ No errors found!
.  (project root)                             ✓ No errors found!
```

The scratchpad path is outside any project source root and resolves the pinned stdlib. Direct A/B on
the cache proves causation:

```text
$ cp -r .agent/projects/009_motoko_dst_execution/spike /tmp/.../spikecopy
$ cd /tmp/.../spikecopy && ailang check probe_real_stream_callback.ail
Error: ... record field mismatch: expected 4 fields, got 5 ... extra fields: images
$ rm -rf /tmp/.../spikecopy/.ailang && ailang check probe_real_stream_callback.ail
✓ No errors found!

$ ls -la .agent/projects/009_motoko_dst_execution/spike/.ailang/cache/compile/modules/std__ai/
-rw-r--r-- ... Jul 24 06:48 core.gob        # same timestamp as /tmp/ailang-v030-runtime.*/SHA256SUMS
```

Filing this sentence as written sends AILANG maintainers hunting a module-resolution bug that does
not exist, in a report whose whole credibility rests on the two type errors beside it.

**Action**: delete caveat 3 from the submission body. The substantive fact it was trying to carry —
that both failures reproduce under the newer `std/ai` as well as the pinned one — is true and is now
better evidenced by R2, so fold it there. Correct the same wrong sentence in
`spike/README.md:34-58` ("Toolchain resolution caveat") and in the verification record's
"operational lesson" at lines 230–232; the real lesson is *a stale `.ailang/cache/compile` from a
different compiler version silently poisons type resolution*. Separately: that cache behaviour is a
genuine AILANG defect worth its own `bug` report — a v0.26.0 compiler silently consuming a v0.30.0
cached interface and reporting a type error against the user's correct source — but it is a
different issue and must not be bolted onto this one.

### R2 — Version-note caveat 1 is false: we *did* compile against the released v0.30.0

Line 191 states "We did not install and compile against a v0.30.0 release," and the version note asks
upstream to "correct us if the released signature differs from what the published docs describe." The
checksum-verified v0.30.0 release is on this machine and I compiled both repros against it:

```text
$ /tmp/ailang-v030-runtime.Zskq0O/ailang --version
AILANG v0.30.0 / Full: e37b370d1d7a9c4e7136b319e38bec4d5f2bd9a0 / Built: 2026-07-19T09:27:00Z

$ sha256sum /tmp/ailang-v030-runtime.Zskq0O/linux.x64.ailang.tar.gz
58561c11ca7be7710b3b4eca9ddfdf263f39bc4e36428969a1968175f10b84b6   # matches its SHA256SUMS

$ cd /tmp/ailang-v030-audit.7DwR3w && $V030 check zzreview/probe_state_returning_callback_rejected.ail
Error: ... failed to unify parameter 4: cannot unify type constructor () with *types.TList

$ $V030 check zzreview/probe_sharedmem_callback_rejected.ail
Error: ... failed to unify parameter 4: failed to unify effect rows: incompatible closed rows:
r1 has extra labels [], r2 has extra labels [SharedMem]
```

And the released source is readable, not merely the docs — `/tmp/ailang-v030-audit.7DwR3w/std/ai.ail`
lines 331–337:

```ailang
export func stepWithStream(
  model: string, messages: [Message], tools: [ToolSchema],
  cache_breakpoints: [CacheBreakpoint],
  on_chunk: (StreamChunk) -> () ! {IO}
) -> Result[StepResult, AIError] ! {AI} =
```

This is the ADR's own position (`ADR-001-…:864-876`), so the report currently contradicts the
document it is filed to unblock. The cost is concrete: a hedged "we only read the docs, please
correct us" invites the cheapest possible upstream reply — *"please retest on latest"* — and burns
the one round of attention this report gets.

**Action**: replace caveats 1 and 3 with the executed v0.30.0 evidence: release tag, commit
`e37b370d…`, archive SHA-256, the two reproduced errors, and the `std/ai.ail:331-337` signature. Keep
caveat 2 (see *What is accurate*) — it is true and worth reporting. Note in passing that the v0.30.0
positive control needs `images: []` added to its `Message` literal, a v0.30.0 vision-input widening
unrelated to streaming, so upstream does not misread it as a streaming regression.

### R3 — The remedy sketch still drops chunks on the error path (send-blocker for the *ask*)

Confirmed: checklist item 1 (lines 250–255) names this defect, but the sketch at lines 155–165 was
never rewritten. `Result[{ result: StepResult, chunks: [StreamChunk] }, AIError]` returns chunks only
on `Ok`. The reviewer checklist is explicitly marked *"not for submission"*, so **the body that ships
contains only the defective shape.** If upstream implements the sketch literally, we land an API that
still cannot record a failed run — and we would have to re-open.

This is not a stylistic preference; the ADR requires the error path by name:

- `ADR-001-…:155-156` — "The provider exchange result must contain a lossless ordered emission log as
  well as the final `StepResult`/`AIError`."
- `ADR-001-…:361` — "partial stream followed by error" is a *required* provider fault class.
- The spike validated exactly this: `PASS returned.partial_error` and `PASS scoped.partial_error`
  (both re-run, see *What is accurate*).

**Action**: rewrite the sketch so observed chunks are returned on **both** outcomes, e.g.

```ailang
stepWithStreamRecorded(...) -> { chunks: [StreamChunk], outcome: Result[StepResult, AIError] } ! {AI}
```

and state in prose that a partial chunk sequence followed by an error must still return the chunks
observed before the failure.

### R4 — Three requirements the checklist calls load-bearing exist only in the non-submitted section

Checklist item 1 lists four sub-decisions; the submission body carries one of them. Missing from the
body:

- **The identity guarantee.** The body never says the returned list must be *the chunks as delivered
  to the callback*, not re-derived from `message.content`. Upstream documents the invariant
  themselves — the v0.30.0 browser guide states "concatenating all `contentdelta.text` payloads equals
  `response.message.content`" (verified, see below) — so we can ask for it in their own terms.
- **Both delivery and capture are required.** The sketch does keep `on_chunk` as a parameter, which
  mostly protects against an implementer returning a list and dropping live delivery. But the
  requirement is never stated as a requirement, and the sketch is labelled "not a prescription," so
  the one guardrail is the part we told them to ignore.
- **Additive vs. breaking preference.** The body offers "new function or richer result type" without
  saying we prefer the additive `stepWithStreamRecorded` and accept either. The checklist's reasoning
  for that preference is sound and belongs in the issue.

**Action**: promote all three into the "Requested remedy" section as explicit prose.

### R5 — The positive control is quoted as output with no source, and will not compile on v0.30.0

Lines 118–123 quote a command and three output lines, but `probe_real_stream_callback.ail` itself is
never shown. `.claude/skills/ailang-feedback` requires a "minimal reproduction: smallest `.ail`
snippet … Copy it out of the Motoko source tree into a fresh `repro.ail` and confirm `ailang check
repro.ail` shows the same error." Repros A and B satisfy that; the positive control does not — upstream
cannot run it. It also fails on v0.30.0 as written, because its `Message` literal predates the
`images` field (R2).

**Action**: inline the ~12-line probe source with `images: []` included, or drop the transcript to a
one-sentence statement that an `IO`-only callback fires twice and returns a typed result.

### R6 — `ailang_version` is paraphrased, not the verbatim `ailang --version` output

The skill asks for the output verbatim. Line 22 reformats it into prose. Every fact in it is correct —

```text
$ ailang --version
AILANG v0.26.0
Commit: 3b52a24
Full:   3b52a24d24431c372ed5605289ef039592209514
Built:  2026-07-15_08:04:20
```

— and the floor `ailang = ">=0.26.0"` matches `ailang.toml:6`. Low severity; fix while editing.

### R7 — The pre-flight in checklist item 4 cannot be run: `gh` is not installed

```text
$ gh auth status
/bin/bash: line 1: gh: command not found
$ ls ~/.ailang/          # cache  state   — no config.yaml
```

This removes Channel 2 entirely (it shells out to `gh`) and makes "confirm *which account* files it"
unanswerable from this machine. Channel 1 remains correct and remains available — the issue form is a
browser URL, no CLI required — so the channel recommendation stands unchanged.

**Action**: restate item 4's pre-flight as "file via the GitHub web form under a monitored account,"
and keep the duplicate-search step, which is still the highest-value pre-flight item.

### R8 — Checklist item 3's open question is now settled by fact, not judgment

`arniwesth/motoko_agent` is **public**:

```text
$ curl -sS -o /dev/null -w "%{http_code}\n" https://api.github.com/repos/arniwesth/motoko_agent
200
$ curl -sS https://api.github.com/repos/arniwesth/motoko_agent | grep '"private"'
  "private": false,
```

Links would resolve for an external reader. That removes the "useless links" half of the argument;
the disclosure half — `.agent/projects/` exposes project 009's architecture and roadmap — stands on
its own, and is now the *only* reason. The recommendation to stay self-contained is unchanged, but it
should rest on the reason that survives.

## What is accurate

Re-executed and confirmed verbatim, under project module resolution (`scripts/dst/zz_*.ail` with
matching `module scripts/dst/zz_*` lines, since deleted):

- **Repro A** — the snippet *as printed in the document* produces the error *as printed*, including
  position `11:17`: `cannot unify type constructor () with *types.TList`. Also reproduced as a loose
  file under module `repro_a`, matching the document's quoted `type error in repro_a` text exactly.
- **Repro B** — same, at position `15:17`: `incompatible closed rows: r1 has extra labels [], r2 has
  extra labels [SharedMem]`. The earlier revision's line-number mismatch is fixed; the published
  numbers match the published abridged snippets, and the un-abridged originals' `27:17` / `29:17`
  correctly do not appear.
- **"parameter 4" is the callback** — confirmed by both errors naming parameter 4 for the 5th argument.
- **Positive control** — passes under project module resolution, printing exactly `LIVE content
  {"kind":"Wait"}` / `LIVE usage` / `PASS real_stream_callback stop`. (Its packaging is R5; the
  transcript itself is real.)
- **6/6 representation tests** — `PASS returned.{success,partial_error}` and
  `PASS scoped.{success,partial_error,two_scope_isolation,collision_and_cleanup}`, plus the aggregate
  `PASS stream_capture_probe`.
- **17/17 projection parity** — `live_projections=17 final_passes=1 bad_markers=0`, awk gate exit 0.
  The "17 supplied" side checks out independently: 4+2+4+2+2+2+1 chunk literals at
  `stream_capture_probe.ail:186,200,214,224,248,249,264`.
- **8-way parallel isolation** — `parallel_passes=8 bad_markers=0`, awk gate exit 0.
- **Both negative probes reproduce under the newer `std/ai` too** — the claim caveat 3 was reaching
  for is true; only its stated cause is wrong (R1). Verified twice: in `spike/` under the cached
  5-field-`Message` interface, and against the real v0.30.0 compiler + stdlib (R2).
- **Version facts** — `ailang --version`, commit `3b52a24d…`, build date, and the `>=0.26.0` floor all
  match the Submission Fields block.
- **Version-note caveat 2** — true. `stdlib_module("std/ai", "0.30.0")` returns a function list ending
  at `stepWithCache`, with no `stepWithStream` (and no `runTools`) entry, while the same version's
  `StreamChunk` docstring still describes it as "one event emitted by stepWithStream's on_chunk
  callback." Worth reporting as the snapshot gap the draft calls it.
- **Both v0.30.0 doc quotations** — the `StreamChunk` docstring is verbatim (also present in the
  release source at `std/ai.ail:237`), and the browser guide's handler contract is
  `(model, messages, tools, breakpoints, onchunk) => promise<response>` with a `Response` carrying
  `message`, `tool_calls`, token counts, `finish_reason`, `model` — **no chunk list**, as stated.
- **The framing of "why this matters"** matches the ADR: D1 requires live projection plus an appended
  identical emission log without double-projection, and D6 requires the returned trace to be
  authoritative.
- **Channel routing** — Channel 1 is still the right call. The report is far too long for Channel 2's
  one-line summary, and only a GitHub issue yields the URL the blocked ADR must cite.
- **The deleted `Message`/`ImagePart` false bug** — correctly deleted. There is no such bug: the
  pinned `Message` has four fields (`~/.local/share/ailang/std/ai.ail:92-97`), a four-field literal
  checks clean, and `src/core/ai_compat.ail:193` constructs exactly that shape in production.

Scratch files created for this review (`scripts/dst/zz_*.ail`, a scratchpad copy of `spike/`, and a
temp dir under the v0.30.0 audit tree) were removed; `git status` is unchanged apart from this file.
The real spike probes, the Makefile, and CI were not touched.

## Send/hold recommendation

**Hold.** Send after three body edits: fix the two false version-note caveats (R1, R2) and rewrite the
remedy sketch to return chunks on both outcomes (R3). R4 should ride along in the same pass — it is
three sentences and it is what stops upstream from building the wrong thing. R5–R8 are polish and can
follow.

I agree the error-path gap is a send-blocker: it is the one defect that would still be a defect after
upstream says yes. R1 is the more urgent correction, though — R3 costs us a follow-up round, while
shipping a demonstrably false claim about their toolchain costs us the credibility that makes the
rest of the report persuasive.

**Residual risk after all edits**: unchanged and not removable by editing. The ask is only as good as
upstream's willingness to add API surface at all, and a fourth `step*` variant is a reasonable thing
for them to push back on. The error-path shape is the part most likely to need a second round even if
they agree in principle — expect to negotiate `{chunks, outcome}` versus an error variant carrying
chunks, and decide in advance which we can live with.
