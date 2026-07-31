# Streaming-capture substrate spike

Date: 2026-07-24 (integration probe added 2026-07-25)
Toolchain: AILANG v0.26.0 (`3b52a24d24431c372ed5605289ef039592209514`)
Status: Negative result complete — the current callback API cannot satisfy the ADR. A direct
positive integration probe now exists and **passes against a local prototype** of the proposed
upstream API; the D1 gate remains open until that API lands and the toolchain is repinned.

**2026-07-31: a vertical spike through the real session driver was executed on top of this work.
Its results are the last section of this file, "Vertical spike through the real driver". The D1
gate is unchanged by it.**

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

---

## Vertical spike through the real driver (added 2026-07-31)

Executed `../PLAN-spike-real-driver-vertical.md`. Branch `spike/009-real-driver-vertical`
(motoko) + `spike/motoko-009-prototype-v031` (AILANG clone, at released v0.31.0).
**Neither merges.**

All five questions resolved against released AILANG v0.31.0. Q1, Q2, Q4 and Q5 confirm; Q2's second
clause falsifies; Q3 is measured. Four ADR defects found, listed at the end — plus an unplanned
measurement of the v0.26.0 → v0.31.0 repin, which is a D1-gate prerequisite and the largest single
cost the spike found.

### Toolchain: repinned to released v0.31.0

The spike was first executed against the in-repo clone at `/workspaces/motoko_agent/ailang`, which
turned out to be **v0.28.0-dev** — it carried neither the `stepWithStreamRecorded` prototype nor the
v0.30.0 `Message` widening (both were built on a different machine). Repinning to *that* is a no-op:
`check_core` is 34/34 clean before and after. The clone was therefore fetched and checked out at
**released v0.31.0** (`1f6f7dd28`, the latest tag), and the prototype reimplemented on top of it.
Every result in this section is against that build.

v0.31.0 supplies the real `Message` shape natively — `{role, content, tool_calls, tool_call_id,
images: [ImagePart]}` with `ImagePart = {source, mime}` — so **Q3 below measures the migration
against the released record, not a hand-applied approximation.**

What is still local is one thing only: `stepWithStreamRecorded`, added as an effect op + builtin +
stdlib surface (~235 lines of Go/AILANG) returning
`{ chunks: [StreamChunk], outcome: Result[StepResult, AIError] }` — chunks on **both** outcomes, the
shape `../UPSTREAM-REQUEST-ailang-recorded-stream-api.md` asks for.

**v0.31.0 std/ai still has no recorded-stream API.** The D1 gate is unchanged and this spike does
not clear it: a locally-built prototype on top of a released toolchain is still not a released API,
exactly as the plan's guardrails say.

### The v0.26.0 → v0.31.0 repin cost (unplanned, and the largest single cost measured)

Repinning is a prerequisite of the D1 gate ("the toolchain to be repinned to a released version
containing it"), so its cost belongs in the implementation plan. It is **not** small:

| | |
|---|---|
| Files needing effect-row corrections | **71** |
| Effect-row edits | **381** |
| ABI-level widenings (versioned surfaces) | **3** |
| Files failing before repair | 67 |
| Files failing after | 0 new (the 13 that fail at pre-spike HEAD still fail) |

v0.31.0's effect checker rejects functions and lambdas that perform effects their signature does not
declare — something v0.26.0 accepted. Almost all 381 edits are mechanical additions the compiler
names precisely, and a compiler-driven repair loop converged in a handful of rounds. Three are not
mechanical, because they change **versioned ABI surfaces** in `packages/motoko-ext-abi/types.ail`:

1. `ExtPorts.ai_step` gains `Trace` — it calls `Ports.model_step`, which has always been
   `{AI, IO, Trace}`. The row was simply wrong and v0.26.0 did not notice.
2. All four `ExtensionHooks` rows gain `Rand` — the a2a extension calls `uuid4()` inside
   `on_tool_handle`, an effect the hook row never declared. A latent ABI defect, now a hard error.
3. The same four rows gain `Trace`, following from (1).

Each of those is an `ExtensionHooks` change, which the ABI's own header says "is a major version of
motoko-ext-abi" — so the repin is not merely a toolchain bump, it forces an extension-ABI major.

Two smaller repin findings:

- Two latent under-declarations in first-party code that v0.26.0 accepted:
  `agents_md.walk_agents` performs `FS` undeclared, and `motoko_ext_omnigraph.register_with_config`
  performs `Process` undeclared.
- **The stale-compile-cache hazard documented at the top of this file reproduced, across a compiler
  *version* change rather than a stdlib one.** Mid-repin, `src/core/rpc.ail` and `supervisor.ail`
  reported an `ExtPorts.ai_step` row mismatch against source that was already correct. Clearing every
  `.ailang/cache` in the tree fixed them with no source change. Same lesson, now confirmed twice:
  clear the compile cache before believing any type error that follows a toolchain change.

### Q3 — the `Message` migration cost (measured)

| | |
|---|---|
| Wall clock | **14 min** (04:45:38 → 04:59:30 UTC), agent-driven, including writing the tooling |
| Files touched | **28** `.ail` files |
| Sites given `images: []` | **69** |
| Over-applications a mechanical pass made and had to revert | **47**, every one a `Msg`-typed literal |
| Sites needing genuine judgement | **7** |

**The migration is not additive, and that is the part a grep estimate misses.** `src/core/types.ail`
documents `Msg` as "structurally identical to `std/ai.Message` and `motoko_ext_abi.Msg`", and the
codebase relies on it: `Message` values cross into `[Msg]`-typed APIs implicitly in seven places.
Widening `Message` breaks the identity and every crossing becomes a compile error needing a written
conversion. A `messages_to_msgs` export had to be **added** to `phase_vocab` (it did not exist), and
one smoke helper was retyped `Message` -> `Msg` end to end. The 69 additive sites are the cheap part.

Second planning-relevant fact: the compiler reports **one record-field mismatch at a time** across
the whole module graph, so naive convergence costs one round-trip per site. The 14 minutes only
holds because a brace-balanced literal rewriter and a compiler-driven fix loop were written first.

The one architectural decision, made once and gating all 116 mechanical edits: **Motoko's `Msg` and
the ext-ABI `Msg` stay at four fields**; vision parts are dropped at the seam. Widening the ABI `Msg`
is a separate versioned-surface decision.

### Q1 — world-state threading: **confirms**

`world_state` threads through `C2LoopState`, provider dispatch, and `run_v2_session_traced`.
17 successor literals updated. `check_core` 35/35. Every pre-existing scenario still passes. No seam
required production code to branch on test mode, and no hidden mutable state was needed.

The finding is worth more than the code. The first cut put the provider inside the adapter
(`LiveWorld(StepProvider)`) — the natural reading of D1's "a live world delegates to evolved
production adapters". It type-checked, `check_core` stayed green, and **6 of 18 scenarios failed
with "step budget exhausted"**: capturing the provider froze the `Scripted` script cursor so every
step replayed step 0. `StepProvider`'s cursor already lives in its ADT payload and is already
explicitly threaded through `C2LoopState.provider`. D1 forbids *hiding* a cursor but says nothing
about where an existing explicitly-threaded one should live once `world_state` arrives — and the
wrong answer compiles clean. **The implementation plan must name the owner.**

### Q2 — clock routing: **confirms on its criterion, falsifies on its second clause**

A deterministic run through the real traced driver executes to completion with the `Clock`
capability withheld — `--entry main_deterministic` without `Clock`, 4/4 assertions, exit 0. The
backstop is load-bearing in both directions: the same driver on the **live** world dies with
`effect 'Clock' requires capability, but none provided`, and so does the spike's own discovery
scenario, which is why it is excluded from the no-`Clock` entry point rather than hidden.

**Correction to D4's characterisation of that backstop.** The ADR calls withholding `Clock`
"a build-and-profile-level gate, not an in-execution one". It is neither: it is a **run-time** check.
`{Clock}` stays in the effect row and the run only dies if a read is actually *performed*
(verified with a minimal probe: a function with `{Clock}` in its row that never calls `now()` runs
fine under `--caps IO`). That is stronger than the ADR assumes — it catches unrouted reads on paths
actually taken — and weaker: it says nothing about paths a given run did not reach.

**The reachable set is 14, not 4.**

| Location | Reads | State |
|---|---|---|
| `session.ail` driver | 4 | routed through the world |
| `session.ail:2374` (`run_v2_with_conversation`) | 1 | unrouted, above the traced entry |
| `src/core/ext/runtime.ail:190` (`test_dummy` hook) | 1 | unrouted |
| `motoko-ext-compose` (compose 6, author_tools 1, dispatcher 1) | 8 | unrouted |

All nine extension-side reads are profile-reachable under the default profile — `handle_compose_tool`
is the `on_tool_handle` hook, so any session where the model calls `Compose` performs them. And the
seam they should use **already exists**: `ExtPorts.clock_now` is in the ABI at
`packages/motoko-ext-abi/types.ail:65`, and `grep -rn "ports.clock_now"` across the whole repo
returns **nothing**. No extension has ever used it. D4's all-or-nothing rule therefore costs ten more
sites than the review counted, in packages with their own version surfaces.

### Q4 — one canonical `RunSummary`: **confirms, after fixing what the question found**

Starting count was **zero on every terminal path**. All seven terminal returns called
`emit_run_summary`, which only ever called `ledger_emit`; the returned `LedgerTrace` never contained
a `RunSummary` record at all. That is precisely the case D6.4 warns about in the abstract — "an
external `ledger_emit` call is not evidence that the event is in `LedgerTrace`" — and it was true of
the entire driver at HEAD.

Routing all seven through one `c2_finalize` (emit the projection **and** append the same record) was
tractable and did not restructure the driver beyond what the ADR budgets. `duration_ms` now comes
from the virtual clock: the program's 1500 ms latency, not wall time.

### Q5 — discovery to replay parity against the real driver: **confirms**

```text
EVIDENCE discovery_emissions=content:{"kind":"Wait"}|usage
EVIDENCE discovery_interactions=provider::msgs=2
EVIDENCE replay_emissions=content:{"kind":"Wait"}|usage
EVIDENCE replay_interactions=provider::msgs=2
EVIDENCE replay_virtual_now=2500
spike_world_vertical PASS count=5
```

Discovery is a live exchange through the real `std/ai` path (under `--ai-stub`), the real chunk
callback, and `stepWithStreamRecorded`. Its returned emission log becomes the program; replay
consumes it through the same entry point and calls no provider. Non-vacuous (`program_non_empty`
is asserted) and load-bearing (seeding `content:WRONG` fails the scenario with both logs printed).

**The largest finding of the spike: the upstream API landing is necessary but not sufficient.**
The first run returned `program_non_empty=0` despite the prototype working standalone.
`session.ail:732`:

```ailang
func ported_provider(rt, history, provider) -> StepProvider {
  match provider { Ported(_) => provider, LiveAI => Ported(live_ports(rt)), Scripted(s) => Ported(...) }
}
```

The traced entry point calls this **before the loop starts**, funnelling every provider — `LiveAI`
included — through `Ports.model_step`, whose return type `Result[StepResult, AIError]` structurally
cannot carry an emission log. The chunks are discarded one layer *above* `std/ai`, so no upstream
change fixes it. `Ports.model_step` had to be widened to
`{ emissions: [StreamChunk], result: Result[StepResult, AIError] }` before discovery recorded
anything. D1 names `ports.ail` as "the migration root" and says its function-valued shape "is not
itself the final world protocol", but nothing in the ADR puts `Ports.model_step`'s **return type**
on D1's critical path. It is on it.

### Substrate notes (verified with minimal repros, not asserted)

Both reproduce against the **stock** `stepWithStream`, so neither is a property of the prototype and
neither is an upstream bug report:

- One callback value cannot be passed to both `dispatch_step` (`{IO, Trace}`) and
  `std/ai.stepWithStream` (`{IO}`): `incompatible closed rows: r1 has extra labels [],
  r2 has extra labels [Trace]`. Each call alone is fine. Workaround: call the port directly.
- The callback must be written as `func(c: StreamChunk) -> () ! {IO} { ... }`; the `\c. ...` lambda
  form fails to unify against the closed `{IO}` row.

### ADR defects found

1. **D1 does not say who owns the provider cursor once `world_state` exists.** Both answers compile;
   one silently freezes the script cursor (Q1).
2. **D4 mischaracterises the withheld-`Clock` backstop** as build/profile-level. It is a run-time
   check with different, and partly better, properties (Q2).
3. **D4's profile-reachable clock set is 14, not the 4 the review counted** — and the extension seam
   that would fix nine of them (`ExtPorts.clock_now`) exists with zero call sites (Q2).
4. **D1 omits `Ports.model_step`'s return type from the emission-log critical path.**
   `ported_provider` funnels every provider through it before the loop starts, so the upstream API
   is necessary but not sufficient (Q5).

A fifth item is a gap rather than a defect: **D6's versioned event-vocabulary artifact does not
exist**, and the only naming function in the repo, `phase_vocab.ail:561 ledger_record_name`, names
**3 of the 34** `LedgerEvent` variants and collapses the rest to the literal `"wire"`. The Q4
"`RunSummary` is the final record" check could not be written against it.

### Gate state on the spike branch (released AILANG v0.31.0)

`check_core` 35/35 · `phase_c2_wiring` 18 · `phase_c_l1` 15 · `phase_c_approval` 7 ·
`compaction_policy` 3 · `compaction_catalog` · `compaction_seeded` · `phase_c_seeded` ·
`runtime_status_tool` 2 · `long_qwen` 8 · conformance 6/6 · `spike_world_vertical` 5 ·
`spike_world_vertical[deterministic]` 4 with `Clock` withheld.

Newly broken files: **zero** — the 13 still failing are the same 13 that fail at pre-spike HEAD
under the pinned v0.26.0 toolchain.

### Disposal

All spike code dies with the branches: `src/core/world.ail` (334 lines),
`scripts/dst/spike_world_vertical.ail`, the `session.ail` / `ports.ail` / `stub_step.ail` edits, and
the AILANG clone's prototype.

What survives is this section, the Q3 number the implementation plan cites instead of estimating,
the four ADR defects above, and — separately from the ADR — the v0.31.0 repin measurement, which is
a prerequisite of the D1 gate and belongs in the plan's sequencing regardless of what upstream does
about the recorded-stream API. The 381 mechanical effect-row edits are throwaway, but the three ABI
widenings and the two latent under-declarations are real defects that will have to be fixed for
real, and the extension-ABI major version they force is a scheduling fact, not a spike artifact.
