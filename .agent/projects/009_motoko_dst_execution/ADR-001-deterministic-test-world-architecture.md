# ADR-001: Deterministic Test-World Architecture for Motoko Logical-Fault DST

Date: 2026-07-24
Status: Proposed — author self-review, streaming spike, two independent reviews, a vertical spike
through the real driver, AILANG v0.31.0 upstream recheck, and **three independent verifications of
the F1–F6 revision** and **eight independent delta reviews (two each of the
second, third, fourth, and fifth correction passes)** (all 2026-08-01,
recorded below) complete. The three verifications returned *Revise* and converged on one defect set;
each delta round returned *Revise* and converged on another, twice overturning this side's own
diagnosis. Every set is now corrected.

**Two acceptance blockers remain, and they are different in kind.**

1. **External substrate, not clearable here:** the upstream recorded-stream API is specified and
   agreed but not shipped in a released binary. D1 requires it to land in a *release*, the toolchain
   to be repinned, and the positive integration probe to pass. A fork prototype does not satisfy this.
2. **Internal and open:** the sixth correction pass — closing classifier 1's completeness hole,
   restating classifier 2's membership criterion, collapsing the rejection predicate to textual
   reference at extension granularity, giving the site-to-hook attribution table the D6 treatment,
   and adding the coverage floor — post-dates the two delta reviews of the fifth pass and has not
   been independently verified. D5's routing audit is not citable as gate evidence until it is.

Neither the correction set nor the acceptance state should be described as complete until (2) passes
a delta review and (1) is an actual release event.

**What is required next is a delta review of the sixth correction pass, not another full round.**
F1, F2, F3, F5, F6, the narrowed D1 blocking clause, the upstream return-shape ruling, and M2 were
each independently confirmed by all three verifications, and D6.1's zero-`RunSummary` claim by two of
the three. The eight delta reviews additionally confirmed D4's clock count (13) and routing state,
corrections C3/C4/C5/C9/C14, every configuration fact, and — in the fourth-pass round, by two
independent three-module probes — that the extension-model-path **exclusion is the right
disposition** and that `ProviderState`'s home in `src/core/ports.ail` is **buildable as specified**.
None of that is reopened.

**The fourth pass answered a finding that changed sequencing; the fifth corrects what that answer
claimed it cost.** Both delta reviews of the third pass found a second call through the
`Ports.model_step` seam — `src/core/session.ail:662`, inside `ext_ai_step` — behind an `ExtPorts` ABI
that cannot return a successor. The fourth pass excluded extension-issued model calls from the
interim seam and called such a profile "not conformance-eligible". **That was stronger than D5
licenses**, as both fourth-pass reviews found: D5's machinery already handles exclusion correctly, and
exclusion costs *coverage*, not conformance. The rule is now stated once, in D5's vocabulary — every
hook reaching the port must be an explicitly excluded hook, and installing such an extension *without*
excluding those hooks is a profile-definition rejection, because that path discards world state with
no fail-closed signal. Implementation Handoff item 2 remains a **partial** cursor fix.

**The second correction pass marked an open defect in D5 that was itself misdiagnosed, and both
delta reviews overturned it.** That marker claimed the routing audit failed open because
`tools/code-graph` discards calls through function-valued seams. The discarded call
(`ports.model_step(...)`) is a *routed* seam call, which is precisely what should be absent from an
ambient-effect inventory, and the parser does resolve direct ambient calls through its bare-import
path. The genuine disqualifiers are scope and granularity: `PROFILES["core"]` is `("src/core",)` and
never contained `packages/`, so the audit as scoped missed every extension-package site; and the
emitted rows are not sites. D5 obligation 2 is repaired accordingly — a conservative textual site
inventory over explicit `src` + `packages` roots — and the misdiagnosis is recorded there rather than
deleted, because a wrong diagnosis that survives into a fix is the more instructive half.

**No pass from the third onward carries an exhaustive-edit table, deliberately.** The second pass
shipped one (C1–C14) and it was incomplete: it disclosed only the D6.1 narrowing as post-dating
`d3bd9cd`, while `5eadee7` also added a Status paragraph and the D5 open-defect block. Both delta
reviews caught the omission. Every pass is now committed before it is reviewed, so a delta reviewer
should read `git log` and diff the commits rather than trust a hand-maintained enumeration. The
change is measurable but smaller than an earlier revision of this paragraph claimed, and the
overstatement is corrected here rather than quietly dropped: the round reviewing the second pass
spent six of fifteen findings on provenance and anchor questions; the round reviewing the third pass,
with a real two-commit diff, spent **two of twelve — both on the same deferred `stub_step.ail`
comment range**, not zero. Narrowed to *provenance* alone the improvement is real and clean, one of
fifteen against none. Anchor precision is a separate problem that a diff does not solve, and this
document has now shipped anchor errors in five consecutive passes, twice in the note whose only
purpose is to record an exact deferred-edit range, and once in an edit whose only purpose was fixing
an anchor.

**There is no separate `## Spike-findings disposition (F1–F6)` section, and there was never meant to
be one.** An earlier draft of this Status block and of
`HANDOFF-review-adr-001-f1-f6-revision.md` both referred to one; two of the three verifications
correctly reported it absent. The reference was the error, not the omission: **the normative body is
the disposition record.** Each of F1–F6 is answered where the decision it affects lives — F1 and F2
in D1, F3 and F4 in D4, F5 in D6, F6 in D1 and Implementation Handoff item 2 — and each says in the
decision's own voice what changed and why, including where an earlier revision was wrong. A separate
defendant's summary written after three verdicts would be a reconstruction, not a record. The
handoff has been corrected to match.

Grounded at: `7b9b4a4c266b229be85de5c09342f2b654c89fe7`, **partially re-grounded at
`99749c7d` on 2026-08-01 (two passes).** Both prior reviews certified that
`git diff --stat 7b9b4a4c..HEAD -- src packages scripts Makefile .github` was empty, so every anchor
was evaluable at the grounding revision. **That is no longer true**: `89a1d67` (WI-C13c) changed
`src/core/session.ail` (93 lines) and `src/core/test/stub_step.ail` (37).

The first re-grounding pass corrected two Context rows and claimed "the rest verified unchanged."
**That claim was false and is retracted**: all three verifications independently found a third stale
row (`stub_step.ail`, provider chunk ordering), and two of them found an arithmetic error introduced
*by* the correction pass itself. Three rows anchoring into the two changed files are now corrected
and marked re-grounded; rows in files untouched since `7b9b4a4c` were spot-checked by all three
reviewers and hold. The lesson is recorded rather than paraphrased: **a "re-grounded" label is a
claim to re-verify, not a warrant.** A fresh reviewer must re-verify anchors rather than inherit
them, including these.
Upstream rechecked at: AILANG v0.31.0 release commit `1f6f7dd28`; upstream request filed as
[`sunholo-data/ailang#546`](https://github.com/sunholo-data/ailang/issues/546) and reviewed
2026-07-31 — see *Upstream recorded-stream API status* below.

Depends on:
- `../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md` after review disposition
  and acceptance. That ADR owns the definition, scope, and naming gate.
  **Satisfied 2026-07-26** — 007 is Accepted. This ADR's remaining acceptance blockers are its own:
  the upstream recorded-stream API and an independent review.

Amends:
- The implementation architecture in
  `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md`. Its production-code,
  explicit-fake, normalized-trace, stable-scenario, and invariant decisions remain in force. This
  ADR replaces the assumption that scripted model results plus normalized traces are a sufficient
  simulated environment.
- `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` for the generated DST axis. Its pure
  `decide`, production phase/state transitions, driver-owned effect execution, append-only ledger,
  and extension-resident policy decisions remain in force. This ADR replaces function-valued ports
  as the complete deterministic-state mechanism, requires returned-trace/emission parity, and
  disallows that ADR's residual raw-effect allowances inside a D5-conformant simulation profile.
  It additionally **replaces 004's stream-delta ledger-append handle** — the mechanism by which a
  streaming callback was to append deltas to the ledger as they arrived. That resolution is not
  merely superseded, it is unbuildable: the provider callback returns unit and its effect row is
  closed, so it cannot append, accumulate, or tee, which is the finding the spike in `spike/`
  established and the reason for the upstream request. D1's returned ordered emission log replaces
  it — the driver appends the log after the call returns, in arrival order, before the final
  response transition. **004's Phase-B byte-parity test for the
  `thinking_stream_start → N×delta → thinking_stream_end` sequence is retained and relocated to
  that returned-log path.** The ordering and payload it protects is a live TUI contract, not an
  internal detail, and moving where deltas come from must not change what the TUI receives.

Relates to:
- `../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md` — extension-resident policy
  remains extension-resident; this ADR controls the effects through which that policy observes and
  acts on the world.
- `NOTE-scope-and-sequence.md` — project boundary, rollout order, and acceptance gates.
- [`sunholo-data/ailang-world`](https://github.com/sunholo-data/ailang-world) and
  `NOTE-ailang-world-overlap.md` — AILANG World's persistent production effect broker, immutable
  transition history, and replay machinery overlap conceptually with this ADR's effect boundary
  and artifacts. The note records the layer boundary, possible reuse, and terminology risk; AILANG
  World does not replace the seed-driven deterministic test world.

## TL;DR

Motoko earns the name **single-actor, logical-fault DST** by running its real traced session driver
against one explicit, driver-threaded deterministic world. Seeded discovery reacts to the external
requests production code actually makes, chooses modeled outcomes, logical faults, and virtual
latencies, and records the resulting ordered `ExecutionProgram`. Replay consumes that exact
program without invoking the generator. Provider, typed tool, approval, environment, runtime
randomness, conformant extension effects, logical resource state, and time share this boundary;
every system termination returns one complete `LedgerTrace`, and whole-execution invariants decide
the result. The simulator stays sequential and does not model physical faults.

The DST name remains unavailable until the automated conformance gate passes for a named,
fail-closed profile. The checked streaming spike proved that pinned AILANG v0.26.0 cannot both keep
provider chunks immediately visible and return the identical ordered chunks in the immutable
trace: the API rejects both state-returning callbacks and callback-side `SharedMem` capture. Before
this ADR can be accepted, an upstream recorded-stream API must land and pass the spike's direct
integration probe. Rechecks at v0.30.0 (2026-07-24) and v0.31.0 (2026-07-31) both preserve the same
callback and result contract, so upgrading does not by itself remove this blocker.

**What changed on 2026-07-31 is the character of that blocker, not its existence.** Upstream
reviewed `ailang#546`, reproduced the constraint first-party, and recommended adopting this
project's reference implementation with its `{chunks, outcome}` shape intact. The design question
is therefore settled and the remaining gate is a release event. Two consequences follow and are
carried in the decisions below: the API's *shape* may now be designed against, and — separately, and
independently of upstream — a vertical spike through the real driver established that adopting that
API changes nothing observable until Motoko widens its own `Ports.model_step`, because the chunks
are discarded one layer above `std/ai` (D1, F2).

## Context

Motoko already has valuable deterministic testing infrastructure:

- fixed scenario families and seeded parameter generation;
- a real phase-oriented session driver;
- `Scripted([ScriptedStep])` model results;
- a function-valued `Ports` record containing model, approval, clock, environment, tool, and
  extension-runtime functions;
- `ScriptedPortsState` helpers for model results, approvals, and clock values;
- a typed `LedgerTrace` and a traced session entry point; and
- invariant-oriented CI gates.

That is strong scenario testing and property-based testing, but it is not yet a deterministic
simulation environment. The pieces do not form one authoritative world:

- `ScriptedStep` is a successful model-result record, not an execution event or fault sum type.
- The seed chooses scalar parameters; it does not generate the ordering of external events.
- `Ports` is projected into some extension paths, but the main session still performs important
  effects directly. Approval uses `readLine`, session timing uses `std/clock.now`, and native tool
  execution does not uniformly consume `Ports.tool_exec`.
- The function-valued `Ports` shape has no explicit state transition. `Scripted` works because the
  driver threads the provider tail, while `scripted_ports_from_steps` derives an index from message
  history. Neither mechanism can safely consume one ordered program across provider, tool,
  approval, environment, and clock requests.
- `Ports.hooks_runtime` has no production consumer, and several effectful extensions do not use
  `ExtCtx.ports`: MCP, scratchpad, compose, context-mode, and similar hooks can perform
  `Process`/`Net`/`FS`/`SharedMem` effects directly. “Ported core” therefore does not imply a
  hermetic extension profile.
- The clock fixture supplies values but does not advance session-wide time or control a real
  deadline, retry, or timeout. The pinned toolchain supplies no virtual clock to fall back on:
  `--virtual-time` prints a status banner, after which `std/clock.now` still returns real wall-clock
  epoch and `std/clock.sleep` still blocks for real time. Session-wide time must therefore be
  modeled entirely in explicit world state (D4).
- Provider streaming is push-based: `stepWithStream` invokes a callback returning `()`. The current
  compatibility wrapper explicitly leaves its returned `chunks` empty because it cannot accumulate
  callback values without a reference. Live chunks can therefore be projected immediately, but
  current Motoko code has no lossless, run-scoped way to return those same chunks in `LedgerTrace`.
  The project-009 spike confirms that this is an upstream API constraint, not merely a missing
  Motoko helper. AILANG v0.30.0 retains the same closed `{IO}` callback and final
  `Result[StepResult, AIError]`, with no recorded-stream result or API.
- The ordinary scripted entry point returns messages, while the traced entry point must be chosen
  separately;
- some error returns have no terminal summary, and emitted summaries are not guaranteed to be part
  of the returned `LedgerTrace`; and
- a seed can replay the current generator only while its mapping remains unchanged. There is no
  authoritative, versioned execution program to replay.

Extending `ScriptedStep` alone cannot close these gaps. Model outcomes, tools, approvals, time,
terminal tracing, replay, and the declared extension profile must share one architecture.

Load-bearing current-source anchors:

| Premise | Grounding |
|---|---|
| `Ports` is function-valued and its tool seam is stringly | `src/core/ports.ail:17-24` |
| Existing scripted state demonstrates explicit `result + next` for three separate queues, but is not threaded through the session | `src/core/test/scripted_ports.ail:20-65` |
| `ScriptedStep` contains only successful-result fields | `src/core/test/stub_step.ail:34-41` |
| `TracedSessionResult` currently contains only `result + trace` | `src/core/session.ail:146-149` |
| Approval and session clock bypass `Ports` | `src/core/session.ail:1619` (`readLine`), `1991`, `2089` (`now()`) — re-grounded 2026-08-01 |
| Success emits `RunSummary`/`DoneEvent` without appending them to the returned trace; other errors return directly | **Five** `emit_run_summary` call sites in `src/core/session.ail` — `1325`, `1554`, `1704`, `1711`, `1762` (`1554-1555` is the success path; `1325` is the shared `c2_fail` helper, so call sites do **not** equal terminal paths). The "return directly" clause is grounded separately on the two terminal returns that emit no summary at all: invalid history at `1528-1531` and the approval-state invariant at `1614-1616` — re-grounded 2026-08-01 (second pass) |
| Native tools execute sequentially and directly against FS/Process | `src/core/tool_runtime.ail:151-165` |
| Core tool dispatch is serial; MCP execution is a blocking call; provider chunks are callback-ordered | `src/core/tool_phase.ail:302-357`; `packages/motoko-ext-mcp/exec.ail:63-70,165-176`; `src/core/test/stub_step.ail:88-96` (`play_chunks`), `148-154` (the live closure passing `on_chunk` to `stepWithStream`), `157-168` (the scripted closure), `192-199` (the one-arm `dispatch_step` pass-through, whose `:198` is the sole `model_step` call *in `dispatch_step`* — the seam has a second call at `src/core/session.ail:662` inside `ext_ai_step`, see D1) — re-grounded 2026-08-01 (fourth pass); the previously cited `:175-204` predates `89a1d67` and straddles two things: `175-191` is the comment block, partly stale (see *Known stale source comment* below), while `192-199` is live `dispatch_step` and `203-204` opens `prose_step` |
| The current streaming wrapper cannot return the chunks it projects live | `packages/motoko-ext-ai-compat/ai_compat.ail:31-37,60-71,197-220` |
| Neither state-returning nor `SharedMem`-capturing callbacks fit the pinned real API | `spike/README.md`; `spike/probe_state_returning_callback_rejected.ail`; `spike/probe_sharedmem_callback_rejected.ail` |
| Latest upstream does not close the streaming-capture gap | AILANG MCP `ailang_versions` reports v0.30.0 latest; release `std/ai.ail:330-337` at `e37b370d1d7a9c4e7136b319e38bec4d5f2bd9a0` retains `on_chunk: (StreamChunk) -> () ! {IO}` and returns only `Result[StepResult, AIError]`; both negative probes reproduce under the checksum-verified v0.30.0 compiler |
| The pinned AILANG runtime supplies **no** usable virtual clock, so time must be modeled explicitly | `ailang run --virtual-time --caps IO,Clock` on a `now/sleep/now` probe returns real epoch and blocks for real time (`delta=3001` for a 3000 ms sleep, `real 0m3.139s`); identical with `--seed`, with `AILANG_SEED`, and on the prototype toolchain. `std/clock.ail:1-5,20-22` documents virtual advancement, which the implementation does not provide — the docstring is stale, not the contract |
| Existing delegated adapters have real timeout contracts that can ground the first virtual-time seam | `packages/motoko-ext-mcp/exec.ail:45-70,165-170`; `packages/motoko-ext-context-mode/context_mode.ail:120-128,171-185` |
| The extension ABI exposes function-valued `ExtPorts`, while reached hooks may perform broad effects | `packages/motoko-ext-abi/types.ail:62-66,151-164` |
| Effectful extensions can bypass `ExtCtx.ports` | `packages/motoko_scratchpad/scratchpad.ail:90-101`; `packages/motoko-ext-mcp/exec.ail:165-170` |
| Core provider retry policy is count/budget based | `src/core/recovery.ail:12-18` |

**Known stale source comment.** `src/core/test/stub_step.ail:171-173` describes a `dispatch_step`
signature that `89a1d67` deleted: `:171-172` promise that it "Returns both the step result and the
updated provider (tail of script for `Scripted`)" and that "Loop callers thread `next_provider`", and
`:173` says "rt is forwarded to `tools_with_extensions`" — but `rt` was a real parameter of that
function before `89a1d67` and is not one now (`:192-199` takes `ports`, `model`, `msgs`, `on_chunk`;
`rt` is captured by `live_ports(rt)` instead). The same comment block contradicts itself at
`:190-191` ("There is no `next_provider` to return").

**The exact range matters to whoever executes this fix: delete `171-173`.** `:170` ("Dispatch one step
call through the provider") is accurate and must survive; `:189` is a bare `--` marker; `:190-191` are
correct and stay. The premise the row above grounds is unaffected — both closures fire `on_chunk`
serially — but the stale lines must be deleted as a source fix, and this ADR's anchors into that file
re-grounded in the same change.

Recorded here rather than silently repaired, because moving source under this ADR is the specific
pattern that produced the stale anchors above. **This note has now been wrong twice**, which is its own
argument for the deferral discipline: the first revision cited `170-171`/`189-190`, which would have
deleted a correct line and left a stale one; the second cited `171-172`, which would have left `:173`.
Both were caught by review, neither by the authoring side.

## Decision

### D1. Use a driver-owned, state-threaded execution-world protocol

Motoko will have one semantic boundary for external observations that can affect session control
flow or the ledger. The boundary is a state transition, conceptually:

```text
handle(world_state, world_request)
  -> Result({
       intermediate_emissions[],
       response,
       next_world_state,
       observations
     }, HarnessError)
```

The real session driver owns and threads `world_state` alongside its existing loop state. Every
request returns the next state explicitly, including error outcomes. The implementation must not
hide the program cursor or clock in `SharedMem`, process-global mutation, an ambient RNG, or a
mutable test singleton: those would reintroduce order dependence and make parallel test processes
unsafe. The clock is no exception and gets no exemption: per D4 the explicit value in `world_state`
is the only clock, and no runtime clock participates in a deterministic run.

**`world_state` owns every replay and generator cursor, and it is the only owner.** An earlier
revision of this decision listed only the hiding places above, which left an already-threaded cursor
unaddressed — and Motoko has one: `StepProvider` carries the remaining `Scripted` script in its ADT
payload. Both available arrangements satisfy the letter of "returns the next state explicitly", and
the vertical spike proved they are not equivalent. Placing the provider inside the world adapter —
`LiveWorld(StepProvider)`, the natural reading of *"a live world delegates requests to evolved
production adapters"* below — type-checked, kept the type-check gate fully green, and silently
failed 6 of 18 scenarios by freezing the script cursor so every step replayed step 0. The
implementation plan therefore retires `C2LoopState.provider` rather than leaving two homes for the
same fact.

**"The only owner" is the end-state invariant, and the interim home is named rather than left to an
implementer.** `world_state` does not exist yet, while the F6 cursor defect is live today and is
sequenced ahead of it (Implementation Handoff item 2). Between now and the migration the scripted
cursor lives in **one explicit field on `C2LoopState`, threaded by the driver** — not in a
closure captured inside a `Ports` value, not in a provider ADT payload, and not re-derived from
message history. That interim field is subsumed by `world_state` when it lands and is deleted in the
same change. The prohibition that matters throughout is the one this decision opens with: exactly one
home, visibly threaded. An interim explicit field satisfies it; a second closure-captured cursor
alongside `world_state` would not.

**Naming the home is not enough, because no mechanism currently reaches it.** An earlier revision
stopped at the field and pointed at Implementation Handoff item 1 for the mechanism, which does not
supply one: item 1 widens `model_step`'s *result* with an emission log, and a successor cursor is not
an emission. `Ports.model_step` takes no state parameter (`src/core/ports.ail:18`), so a returned
cursor has no way back in on the next call, while returning a successor `Ports` puts the cursor in
that value's closure — the arrangement this decision prohibits by name. The already-tested state
machine has the shape the port lacks at both ends:
`scripted_model_next(state) -> {result, next}` (`src/core/test/scripted_ports.ail:38-48`).

**The interim provider operation therefore takes the current provider state and returns its
successor, alongside `emissions` and the outcome.** The sole persistent copy is the named
`C2LoopState` field. This is a **second widening of `Ports.model_step`, on a second and separately
stated ground** — state threading, not discarded emissions — and unlike the first it is **not
behaviour-preserving**, because it changes the port's input shape and every construction site's
contract. The two must be planned and reviewed as distinct changes even though they touch one field;
Implementation Handoff items 1 and 2 are marked accordingly. The loss-channel scoping rule below
governs the *emission* widening and does not reach this one, which is grounded here instead.

**Three mechanical facts constrain that widening, and each was found by review rather than by
design.**

*The state type must be concrete and declared at or below `src/core/ports.ail`.* The interim state is
a named `ProviderState` in `ports.ail`, not the existing `ScriptedPortsState`. That type
(`src/core/test/scripted_ports.ail:20-24`) carries `ScriptedStep`, declared in
`src/core/test/stub_step.ail:34`, and `scripted_ports.ail` imports `ports`, `stub_step`, **and**
`session` — so neither module that must declare the widened field nor the driver that must hold the
`C2LoopState` field can import it without closing a cycle, which AILANG rejects (`LDR002`). The
generic escape does not exist either: parameterising `Ports` over its state type is accepted as a
declaration but its instantiation fails unification on the pinned compiler, and no parameterised
record type appears anywhere in the tree. **`ScriptedPortsState`/`scripted_model_next` are therefore a
design precedent, not reusable code**, and making the real thing requires relocating `ScriptedStep` to
`ports.ail` or below — a source move that must be budgeted in the plan, not discovered inside it.

*The live and caller-supplied adapters return their input state unchanged.* `live_ports` is stateless.
The identity transition is the specified answer, not an implementation detail left to six construction
sites. `ported_provider` (`src/core/session.ail:695-701`) returns the initial state alongside the
`Ports` — a pair, or a paired constructor — with the empty `ProviderState` for the `LiveAI` and
`Ported` arms and the script-derived one for `Scripted`. Only successors replace it thereafter.

*The extension model path cannot carry the token, and is excluded rather than hand-waved.* There are
**two** calls through `Ports.model_step`, not one: `src/core/test/stub_step.ail:198` in `dispatch_step`,
and `src/core/session.ail:662` inside `ext_ai_step`, which `ext_ports_of` (`:668-677`) wraps as
`ExtPorts.ai_step` and hands to four hook contexts. That ABI returns `Result[string, string]`
(`packages/motoko-ext-abi/types.ail:63`) and the hook results above it are decision-only, so a
successor has no way back to `C2LoopState`. Discarding it at `:662` recreates F6 exactly; capturing it
in the closure creates the second home this decision prohibits. **The interim seam therefore covers
the main loop only, and extension-issued model calls are excluded from every conformant profile until
the world-token ABI D5 already requires has landed.** Two consequences follow and neither is
cosmetic: **Implementation Handoff item 2 is a partial cursor fix and says so**, and **every hook that
can reach `ExtPorts.ai_step` must be an explicitly excluded hook in any conformant interim profile.**

**That is a coverage cost, not a conformance disqualification, and an earlier revision of this
paragraph got it wrong.** It said such a profile was "not conformance-eligible", which is stronger
than D5 licenses: D5's machinery already handles this case correctly — an explicitly excluded hook is
not covered, is named in the result, and causes a fail-closed `HarnessFailure` if dispatch reaches it
— and the acceptance table lists excluded hooks as evidence a profile *passes*. A profile installing
an `ai_step`-calling extension and excluding its reaching hooks is conformant and honest; it simply
does not cover those hooks, and any run that reaches one fails closed rather than silently discarding
a cursor.

Two things follow, and the second is the one with teeth:

- **The conformance obligation is on the profile definition, not on the extension.** Installing an
  `ai_step`-calling extension is permitted. Installing one **without excluding every hook it
  registers** is a **profile-definition rejection**, because an un-excluded path discards provider
  state with no fail-closed signal.

  **The predicate is "the extension contains a classifier-2 field reference", and it is deliberately
  coarser than the hooks that actually reach the port.** An earlier revision said "every hook that
  *can reach* the port" — a call-graph property with no instrument. Classifier 2 inventories
  *reference sites*, which is textual; nothing mapped a site to its reaching hooks, and establishing
  that `compaction_ai`'s single reaching hook is `on_pre_step` took a four-edge manual walk through
  two modules. An ADR that requires inspection where it has just built an artifact to avoid it
  (clause 3, D4) is specifying a checklist. The coarse rule is decidable **today** from a grep plus
  the extension's `register.ail`, it fails closed, and it costs only the ability to keep one hook of
  a referencing extension. If per-hook granularity is wanted later, the refinement path is to extend
  D4's site-to-hook attribution table to extension packages and have this rule read it; until that
  exists, extension granularity is the rule.

  **One predicate, used everywhere.** D5's exclusion paragraph, D5's validation bullet, obligation
  2's classifier 2, and the acceptance row all state this rule, and an earlier revision phrased it
  four different ways — "can reach the port", "reaches a non-world-mediated seam", "references a
  field", "reaching a field from an un-excluded hook". The seam phrasing was the worst of these:
  read literally at HEAD, where nothing is routed, it rejects every extension-installing profile.
  The rule is **references**, at extension granularity, and every site now says so.
- **The practical consequence is about utility, not eligibility.** `compaction_ai` calls
  `ctx.ports.ai_step` (`packages/motoko-ext-compaction-ai/compaction_ai.ail:106`) and appears in the
  extension order of **all fourteen** checked-in configurations. Every one of them can be made
  conformant by excluding `compaction_ai`'s hooks — it registers **eight**, of which `on_pre_step` is
  the only non-trivial one and the only one reaching the port, the other seven being
  constant-returning lambdas — so the profile is conformant and inert on the compaction path. The first *useful* interim
  profile is therefore a purpose-built narrow one rather than a shipped configuration, which is what
  D5 already contemplates in "pure guards and deterministic fixture hooks may form the initial
  profile." The interim milestone must not be planned as though it delivers a conformant *and
  covering* `default`.

Widening `ExtPorts.ai_step` and the hook results to carry the token is the eventual path, it belongs
to the ABI major the repin already forces (*Consequences*), and it must not be smuggled into the
interim step. This exclusion is consistent with D5's own coverage criterion rather than an exception
to it: D5 admits an effectful hook only when it is "effectful only through D1 world-mediated ports,
with explicit world state returned to the host", and `ai_step` returns none.

**Deriving a replay position from mutable message history is prohibited by name.** It is not merely
one more hiding place; it is the arrangement that currently executes, and compaction mutates the
history it reads. The only scripted provider the DST actually runs
(`scripted_ports_from_steps`) re-derives its index from `assistant_count` on every call, while both
implementations that thread a cursor explicitly are disconnected from the driver. Under a folding
compactor that derived index **pins** rather than rewinds: the payload's assistant count stops at the
compaction floor while real history keeps growing, the same step is served forever, and the run dies
of budget exhaustion in a way indistinguishable from an ordinary result. That is a confirmed defect
in the harness today (F6), and it is the concrete reason this sentence is normative rather than
stylistic. D2's seeded generation of longer programs is what makes it reachable.

A request may yield ordered intermediate emissions before its final response. Provider stream
chunks are the current case. The provider exchange result must contain a lossless ordered emission
log as well as the final `StepResult`/`AIError`. A live adapter also projects each chunk to the UI
at arrival; after the call returns, the driver appends the adapter's identical emission log to the
authoritative `LedgerTrace` in arrival order before it applies the final response transition. A
deterministic adapter supplies timed emissions from the program, and the driver projects and
appends each at its virtual arrival point. The two paths must produce the same event ordering and
content without double-projecting live chunks.

This requirement is a blocking substrate gate, not an implementation detail. The checked spike in
`spike/` dispositions the two candidate representations against pinned AILANG v0.26.0:

1. A modeled provider result that preserves immediate projection and returns the ordered chunks
   passes success and partial-stream-then-error parity under `--caps IO`, but the real API exposes
   no such result.
2. A CAS-claimed, request-scoped `SharedMem` recorder passes success, partial-error,
   collision/cleanup, interleaved-scope, and eight-process isolation probes, but the real
   `stepWithStream` callback's closed `{IO}` row rejects `SharedMem`.
3. The real API's IO-only positive control streams `ContentDelta` and `Usage` and returns a final
   result, while a state-returning callback fails type unification against `()`.

The 2026-07-24 latest-upstream recheck does not change that disposition. The configured AILANG MCP
reported v0.30.0 as latest. An empty diff between the v0.26.0 and v0.30.0 `stepWithStream`
signatures confirmed that v0.30.0 still requires a unit-returning, closed `{IO}` callback and still
returns only `Result[StepResult, AIError]`. A full-source search found no recorded-stream variant.
The checksum-verified v0.30.0 compiler reproduced both intended failures: the state-returning
callback fails `()` versus list unification, and the recorder callback fails closed-row unification
because of `SharedMem`. The official v0.30.0 IO-only streaming example checks and runs with
`--ai-stub`, so these failures are specific to capture rather than evidence that streaming itself
was removed.

Therefore the selected prerequisite is an evolved upstream provider/runtime API that preserves
immediate callbacks and returns the lossless ordered observed chunks with the final result. A
row-polymorphic callback plus scoped recorder is not the default fallback: it adds `SharedMem` to
the deterministic profile and weakens capability-based hermeticity, so selecting it would require
an explicit amendment. A process-global, unscoped, or silently colliding recorder remains rejected.
Delaying all chunk projection until provider completion also remains rejected because it changes
current live UX semantics.

Before this ADR is accepted, the upstream recorded-stream API must be pinned and a direct positive
version of the spike must prove immediate projection, exact returned-log parity, success,
partial-stream-then-error, and no duplicate delivery. Until then, complete streaming trace parity
is blocked.

**That gate blocks streaming trace parity. It does not block the port widening, and an earlier
revision of this clause wrongly implied that it did** by adding "and production migration must not
begin" without qualification. A planner reading D1 top to bottom sequenced: wait for upstream →
adopt the new API → replace `Ports` later. That ordering is a trap. `Ports.model_step` returns
`Result[StepResult, AIError]`, which structurally cannot carry an emission log, and
`ported_provider` funnels **every** provider through it before the loop starts — so adopting the
upstream API without widening the port first changes nothing observable, and guarantees an empty
emission log through the adoption step and most of the migration. The widening has no upstream
dependency: the field can be widened today with `emissions: []` at every construction site, and the
change is independently testable against `Scripted` providers with no provider access at all.

The ordering rule is: **widen the port before adopting whatever fills it**, since the port is where
the information is thrown away. **The rule is scoped to ports with a demonstrated loss channel, and
today that is exactly one field.** An earlier revision justified it as general "because every `Ports`
field is a lossy crossing of the same kind." That is not established. `model_step` takes a multi-fire
`(StreamChunk) -> () ! {IO}` callback whose values the returning closure discards
(`src/core/test/stub_step.ail:148-154`) while returning only `Result[StepResult, AIError]` — a
concrete, demonstrated loss. `approval_read` is a synchronous `ApprovalRequest -> ApprovalResolution`
and `clock_now` is a point read `() -> int`; neither has an intermediate channel through which a
value could be silently dropped, and this decision's own bullets below preserve both result types
unchanged. Generalizing to them would mandate widenings this ADR neither names nor justifies. The
stringly `tool_exec` also needs widening, but for a separately named reason — a typed
`ToolCallEnvelope` and deadline contract, below — not because of a discarded emission channel.
Extending the rule to a further field requires identifying that field's loss channel and its richer
producer contract first.

**A widening may also be required on a ground this rule does not cover, and one is.** `model_step`
is widened twice: once by this rule, for its discarded emission log; and once for interim provider
state threading, on the ground stated above under cursor ownership. The second is not a loss-channel
case and is not licensed by this paragraph. Where the two are confused, the emission widening looks
sufficient for the F6 fix, which it is not.

Doing the provider case first shrinks the upstream dependency's blast radius to a
single closure in `live_ports`, which is the strongest de-risking available on this gate. What
remains blocked until the API lands is the content of that one closure and the parity proof that
depends on it — not the migration.

`world_state` is more than a cursor. It contains the virtual clock, generator/replay state,
synthetic environment and runtime-random stream, and any logical resource state promised by the
selected profile—for example an in-memory file map, tool/MCP availability, or approval-channel
state. A profile may treat an opaque external tool as a scripted typed boundary instead of
emulating its internals, but must say so; it may not imply filesystem/server semantics it does not
model.

The authoritative request surface covers:

1. provider requests and streaming, tagged by origin (main loop or extension);
2. native and delegated tool execution as a typed request/result contract;
3. approval input;
4. environment/config reads performed during the established run;
5. runtime randomness, if any;
6. monotonic time and time-bearing completion/deadline decisions; and
7. conformant extension-side external effects (D5).

The existing `src/core/ports.ail` record is the migration root and live-adapter vocabulary, but its
function-valued shape is not itself the final world protocol. In particular:

- the provider exchange wraps the existing typed `Result[StepResult, AIError]` with its ordered
  intermediate-emission log. **The site is `Ports.model_step`**, named here as concretely as
  `tool_exec` is named below, because this is an edit to a record that exists today and not only a
  property of the future world protocol. The emission log is a property of the **port**; the
  upstream API and the world protocol are both consumers of it;
- the tool contract must carry a typed `ToolCallEnvelope`, timeout/deadline information, and a typed
  result/error rather than `tool_exec(string, string) -> string`;
- approval remains a typed `ApprovalResolution`; and
- clock reads return the current world time without advancing it.

The world ends at the external result boundary. Production code still validates and interprets
`StepResult`/`AIError`, correlates tool-call ids, converts typed tool outcomes into history
messages, applies approval/policy decisions, updates budgets, and records ledger events. Moving
those operations into the simulator would violate D5.

The unused `Ports.hooks_runtime` callback is not a world-state carrier. The implementation plan
must either give it a separate demonstrated production purpose or remove/deprecate it; hiding the
simulator behind that callback is rejected.

A live world delegates requests to evolved production adapters. A deterministic world interprets
the recorded program. The driver uses the same request/response types and transition code in both
cases; production state-machine and policy code does not branch on “test mode.” A small adapter
dispatch between `LiveWorld` and `DeterministicWorld` is mechanism, analogous to the current
`StepProvider`, not a second behavior implementation.

An effect is required to cross this boundary when changing its result could change:

- the next state-machine decision;
- messages or tool results appended to history;
- a ledger record;
- retry/finalization behavior;
- budget or timeout behavior; or
- the terminal outcome.

Diagnostic output that cannot influence execution may remain outside the modeled world, but it must
not be used as the only copy of an invariant-bearing fact. The deterministic executor accumulates
its result, trace, and diagnostics first; a wrapper may print them afterward. A live projection
sink may mirror events during production, while the deterministic profile uses a collecting/no-op
sink so reporting `IO` does not justify ambient input during execution.

### D2. Discovery is seed-driven; replay consumes a resolved execution program

Precomputing exact expected requests would require duplicating the session logic to predict them.
Motoko therefore separates **discovery** from **replay**.

During discovery, a deterministic seeded world receives each real D1 request as the production
driver makes it. A schema-versioned generator chooses a compatible response, fault, and latency
from that request plus explicit generator state. The choice changes the next production state and
therefore which request arrives next. The world records every actual request projection and chosen
outcome into a resolved `ExecutionProgram`.

Replay receives that resolved program and never calls the generator:

```text
DiscoveryConfig {
  schema_version
  generator_id
  generator_version
  seed
  initial_world {
    messages_and_policy
    synthetic_environment
    clock_epoch
    extension_profile
  }
}

ExecutionProgram {
  schema_version
  generator_id
  generator_version
  seed
  initial_world
  execution_manifest        -- or a named sidecar the validator requires
  interactions[]
}

Interaction =
    ExpectProvider(origin, request_matcher, timed_outcome)
  | ExpectTool(origin, request_matcher, deadline, timed_outcome)
  | ExpectApproval(request_matcher, deadline, timed_outcome)
  | ExpectExtensionEffect(origin, request_matcher, deadline, timed_outcome)
  | EnvironmentRead(key, value_or_missing)
  | RuntimeRandomDraw(bounds, value)
  | AdvanceClock(delta)
```

`ExpectExtensionEffect` closes what would otherwise be a hole: D1 puts conformant extension-side
external effects on the authoritative request surface, D3 requires the corresponding
provider/tool/process failure for an effectful hook, and D5 admits such hooks only through
world-mediated ports — but a program with no interaction for them could record neither the request
nor its outcome, so the class would be unreplayable. Its `origin` is the extension id, and its
class id is the same stable identifier D3's catalogue and D11's coverage counters use, so a
process-failure class cannot be counted as reached under one name and mapped under another. An
implementation may instead represent extension `proc_exec` as `ExpectTool`, but only by stating that
normatively and giving the conversion and identity rules; leaving the choice implicit is not
permitted.

The exact AILANG type names are plan-level, but these semantics are architectural:

- Discovery chooses only at requests the real driver actually makes. It never invents a tool,
  approval, or extension-effect request disconnected from production control flow. A generated
  provider outcome may contain a tool call and thereby cause a later production tool request; the
  seed controls the resulting trajectory without a test copy of the state machine.
- Each discovery choice is a deterministic function of generator id/version, seed, generator
  state, the bounded request projection, and current world state. No ambient RNG participates.
- The resolved interactions are an ordered expected protocol, not anonymous response queues. Each
  records (a) a stable causal identity used to decide whether the outcome can be delivered and
  (b) a bounded full request projection/digest used for strict reproduction and invariants.
  Every interaction identity includes a global encounter ordinal. Provider identity additionally
  includes kind, origin, step, and model; extension-effect identity additionally includes kind,
  origin (the extension id), the effect class id, and call id where the effect has one; tool and
  approval identity additionally includes kind,
  origin, call id, and name. The ordinal keeps repeated production call ids representable so an
  invariant can reject them as system behavior rather than the program decoder rejecting the
  artifact. Arguments and message/payload digests are recorded projections, not silently
  discarded.
- Replay has two explicit modes. **Strict replay** (the reproduction contract) requires causal
  identity and recorded projections to match under the recorded execution manifest/profile.
  **Regression replay** on a newer revision requires compatible causal identity, records
  projection differences, and may continue so the same environment outcomes exercise changed
  production logic. A wrong kind/origin, unsafe identity mismatch, exhausted program, or unused
  interaction is a
  `HarnessFailure`, not a simulated system fault. Regression replay never weakens tool-call/result
  correlation or delivers an outcome to a different logical request.
- `timed_outcome` carries deterministic latency or completion time. Before delivery, the world
  advances its monotonic clock by the recorded non-negative amount. Explicit `AdvanceClock`
  interactions model time between response-bearing requests. Clock reads return the current value
  and do not independently advance it.
- A provider timed outcome may contain ordered stream chunks with non-decreasing virtual offsets
  followed by a final `StepResult` or `AIError`. The driver records each chunk at its offset before
  the final response. Chunk callbacks remain serial within the provider request; they do not become
  independent actors under this ADR.
- Environment reads and runtime random draws are also recorded in encounter order. Discovery uses
  synthetic environment values and the seeded world; replay returns the recorded values. Unknown
  required keys, incompatible random bounds, or stream exhaustion are harness failures.
- The program contains concrete outcomes and the bounded actual request projections needed to
  diagnose mismatches. The generator id/version and seed explain discovery; the serialized
  resolved program is the authoritative reproduction artifact.
- Program decoding and a pure structural validator run before replay. They reject malformed
  schemas, negative time, duplicate interaction identities, impossible static references, and
  absent required initial values.
- Each generator schema declares hard bounds for interactions, stream chunks, payload bytes,
  logical-resource size, and clock advancement. Exceeding a bound is a generator/harness failure,
  not an unbounded test run.
- The discovery gate reports generator failures and forbidden-effect/harness-failure counts; all
  must be zero. A harness failure deliberately created by a conformance probe is reported
  separately from the search corpus.

Generation may also choose ordinary configuration and message inputs, but scalar input generation
does not count as the trajectory. To satisfy the naming gate, seeded choices at multiple real
effect boundaries must influence ordering, fault placement, and time across the resulting
execution.

### D3. Logical faults are modeled outcomes, not injected internal decisions

Faults enter through the same boundary as successful external outcomes. The state machine and
session driver remain production code and decide how to react.

The minimum catalogue required before adopting the DST name is:

| Boundary | Required fault classes |
|---|---|
| Provider | retryable `AIError`, non-retryable `AIError`, protocol-inconsistent typed result, partial stream followed by error, empty terminal response |
| Tool | typed execution error/non-zero result, protocol-inconsistent result (for example wrong call id), and completion after its declared deadline |
| Approval | explicit denial and no response before a declared approval deadline, where that deadline is enabled by the production policy |
| Conformant extension effect | the corresponding provider/tool/process failure when the selected D5 profile contains an effectful hook using that world request |

**That mapping is a versioned, machine-readable artifact that the gate reads — not prose in an
implementation plan.** One catalogue is the single source of truth, and for every class it carries:
a stable class id; the applicability condition, if the class is conditional; the production result
or error constructor it is delivered as; the **named recovery-branch id** it is intended to reach;
and its logical-state transition. A decorative fault variant that cannot influence the production
session does not satisfy this decision, and "cannot influence" must be decidable by reading the
artifact rather than by inspecting the implementation.

Two of the required classes above are conditional — the approval deadline exists only where
production policy enables it, and the extension-effect class only where the selected profile
contains an effectful hook using that world request. A profile may therefore legitimately not
exercise them. **When it does not, the run report and the D5 profile definition must name each
waived class and the condition that waived it**, so a coverage claim is readable against D3's full
table rather than silently against its applicable subset. An unstated waiver is a coverage claim
this decision does not grant.

Every successful or faulty outcome also defines its logical world transition. Write-like tool
faults specify whether the all-or-nothing logical update occurred; server-drop faults update
availability for subsequent calls; deadline outcomes specify whether work completed before or
after the observation. Torn/partial physical writes remain excluded, but “timeout” cannot leave
the simulator's logical state ambiguous.

The injection boundary matters. A malformed `ToolCall.arguments` string or inconsistent
`StepResult` can be delivered through the typed provider boundary and exercises session validation.
A malformed raw HTTP/SSE payload exercises a provider adapter parser, not the session, unless that
adapter is explicitly inside the selected simulation profile. The fault catalogue must not claim
wire-parser coverage from a typed post-parse result.

Timeout is not a freely selected error label for purposes of pillar 5. The deterministic world
derives it from the generated completion time and the production request's deadline. An explicitly
scripted `Timeout` that would occur regardless of clock advancement counts as logical fault
injection, but not as virtual-time evidence.

Directly forcing `StepDecision`, editing ledger state, or bypassing validation is rejected as fault
injection: it would test a second test-only transition system.

The catalogue can grow without a new ADR when additions preserve this boundary. Adding physical
faults or changing the system's durability contract requires revisiting the project scope. That
exclusion is bound to accepted 007 D1.3 and carries its triggers verbatim rather than a looser
paraphrase: **reopen before adding a crash-recovery, fsync, WAL, resume-from-ledger, or
replicated-state correctness contract.** Any one of those five gives Motoko a physical durability
contract it does not have today, and the moment it has one, the physical-fault exclusion stops
being a scope decision and becomes an untested gap.

### D4. One monotonic virtual clock controls all time-bearing behavior

The deterministic world owns a monotonic clock. Session code and conformant extensions read it
through the authoritative boundary; they do not read ambient wall time when the value can affect
behavior or an asserted trace.

**The explicit clock value in `world_state` is the only clock.** No runtime clock participates in a
deterministic run: there is no runtime epoch to record, no mirrored advance, and no conformance
assertion comparing an explicit value against a runtime one. `AdvanceClock(delta)` and the latency
carried by a timed outcome update the explicit value and nothing else.

This is a correction, not a preference. An earlier revision of this decision required deterministic
runs under the pinned runtime's `--virtual-time`, with `AdvanceClock(delta)` driving
`std/clock.sleep(delta)` so that residual direct `std/clock.now` reads would observe the same
virtualized clock during migration. **That mechanism does not exist.** On pinned v0.26.0 the flag
prints a status banner and changes nothing observable:

```text
$ ailang run --virtual-time --caps IO,Clock --entry main vclock.ail
  ⏰ Virtual time enabled
t0=1785301954869 t1=1785301957870 delta=3001
real  0m3.139s
```

`now()` returns real wall-clock epoch, a 3000 ms `sleep` blocks for ~3000 ms of real time, and the
delta varies run to run. The same holds with `--seed`, with `AILANG_SEED`, and on the prototype
toolchain. The evidence previously cited for this row — that the flag parses and the run exits 0 —
established only that the flag is accepted.

The architecture does not depend on that mechanism being fixed upstream. It never needed a runtime
clock to be *correct*; the explicit value was always authoritative, and the runtime mirror existed
only as a migration convenience. Removing it costs the convenience and buys a simpler contract.

What it costs is specific and belongs in the implementation plan rather than being discovered
during it: **the clock seam must be routed completely before a profile can claim conformance, not
incrementally.** With no runtime virtualization there is no interval in which a residual direct
`std/clock.now` read is merely unrecorded-but-deterministic — such a read is nondeterministic, so it
is a hermeticity failure like any other unrouted ambient effect, and it is caught by the same D5
mechanisms rather than by a clock-specific one. Two detectors apply, and they are different in kind:
the **source and ABI routing audit** enumerates such reads as a conservative textual site inventory
over explicit `src` + `packages` roots, per D5 obligation 2, and is the one a profile depends
on; **withholding the `Clock` capability** from a deterministic run is a coarse fail-closed backstop
that stops the run rather than returning a typed result.

That backstop is a **run-time** check, and an earlier revision of this decision described it as
"a build-and-profile-level gate, not an in-execution one". It is neither. `{Clock}` stays in the
effect row and AILANG fails only when a read is actually *performed*: a function whose row contains
`{Clock}` but whose taken branch never calls `now()` runs to completion with the capability
withheld. Verified against the real driver — the deterministic entry point completes with `Clock`
withheld while the live world on the same driver dies with `effect 'Clock' requires capability, but
none provided`.

The correction cuts both ways and both halves matter to a profile. The backstop is **stronger** than
previously assumed, because it catches unrouted reads on the paths a run actually takes rather than
merely declared ones. It is also **weaker**, because it says nothing about reachable paths a given
run did not exercise, so it cannot on its own discharge the all-or-nothing routing requirement
above. The source/ABI audit remains the primary detector; this is a per-run backstop.

**The clock set is larger than earlier revisions assumed, and most of it is not in the core.** The
**repo-wide inventory** across `src` and `packages` at HEAD on pinned v0.26.0 is **13 distinct call
sites, not 4**:

| Location | Sites | Routed at HEAD | Profile-reachable when |
|---|---|---|---|
| `src/core/session.ail` driver (`791`, `842`, `1991`, `2089`) | 4 | no | always — driver code (clause 1) |
| `src/core/ext/runtime.ail` `emit_dummy_hook` (`190`) | 1 | no | the `test_dummy` hook is installed (clause 3) |
| `packages/motoko-ext-compose` (`compose` 6, `author_tools` 1, `authoring/dispatcher` 1) | 8 | no | `compose` is installed (clause 2) |

Every condition is an **installation** condition. An earlier revision qualified the `compose` row with
"and the model calls `Compose`" — the execution-path test the definition below forbids, and factually
too narrow besides, since the response-intercept path reads the clock without any `Compose` tool call
(`packages/motoko-ext-compose/compose.ail:767`, inside `on_response_intercept` at `:761-790`).

**This is a repo-wide inventory, not a per-profile reachable set, and the two must not be conflated.**
An earlier revision called the eight `compose` reads "reachable under the *default* profile, not an
exotic one." That is false against the checked-in configuration: `.motoko/config/default/config.json`
lists an extension order of `empty_stop_guard`, `progress_contract_guard`, `compaction_ai`,
`context_mode`, `exa_search`, `scratchpad`, `compaction_structural` — no `compose`. `compose` appears
only in `.motoko/config/ailang/config.json`, `test_dummy` in no checked-in config at all, and
`parse_tokens` (`src/core/ext/registry_generated.ail:51-65`) instantiates only hooks whose name
appears in the configured order. Under the default configuration nine of the thirteen are
unreachable, and **no checked-in configuration realizes all thirteen.** The dispatch chain is
genuinely there once `compose` is installed — `handle_compose_tool` is the `on_tool_handle` hook — but
installation is the precondition, and that is a property of the named D5 profile, not of this table.

**Each D5 simulation profile must therefore state its own reachable clock set, derived from its
extension list, and route that set completely (D4's all-or-nothing rule).** The number 13 bounds the
work; it does not describe any profile. Under the installation scoping defined below: a profile
installing neither `compose` nor `test_dummy` — which is every checked-in configuration except
`.motoko/config/ailang` — has **four** sites to route; one installing `compose` but not `test_dummy`,
which is `.motoko/config/ailang`, has **twelve**; one installing both would have all **thirteen**,
and no checked-in configuration does.

**Nothing is routed at HEAD.** An earlier revision of this table reported 14 sites, added a separate
`conversation_loop_v2` row, and said "only the first row is routed" — all three were measured on the
spike's surgically-modified driver and imported into this ADR as HEAD state. Corrected: the driver
has exactly four `now()` sites (`now` has a single binding, `import std/clock (now)` at `session.ail:30`,
so no alias hides a fifth); `conversation_loop_v2` performs no read of its own; and the path the
fifth row was reaching for is real but is not a distinct site — `run_v2_with_conversation` calls
`derive_session_id`, whose fallback branch is the already-counted `:791`. The spike demonstrated
that the four driver sites *can* be routed on a throwaway branch; that surgery is not at HEAD and is
not gate evidence.

Counting the `test_dummy` hook, nine of the thirteen sit behind an extension hook
rather than in the driver. The seam that would route them already exists — `ExtPorts.clock_now` in
`packages/motoko-ext-abi/types.ail` — and it has **zero call sites repo-wide**, so it has never been
exercised and may not survive first contact unchanged. Routing the clock is therefore not a
core-only task, and the implementation plan must budget the extension-side work and its version
surfaces rather than discovering them inside Track 1.

Because no real sleeping occurs, modeled time is free: a program that advances the clock past a
thirty-second deadline costs no wall-clock time, where the mirrored design would have blocked for
thirty real seconds. Determinism no longer trades against gate runtime.

External shell, MCP, and OS-process timeout mechanisms remain real-time operations and are never
invoked as the clock oracle in a deterministic run. Each deterministic run still uses a fresh
evaluator or process, now for ambient-state isolation generally rather than to prevent one seed
inheriting another's runtime virtual time.

`AdvanceClock(delta)` and timed outcomes must reject negative or overflowing movement. A program may
hold time still or advance it by an explicit duration. When a world request carries a deadline, the
deterministic adapter compares the generated completion time with that deadline and returns the same
typed completion/timeout result that the live adapter exposes. Production retry, timeout, and
deadline derivation remains production code. Completion-versus-deadline resolution is a shared pure
helper or an explicit conformance-tested adapter contract, not duplicated ad hoc in the generator.

Clock normalization remains appropriate for nondeterministic display-only fields. It does not
satisfy this decision. Before adopting the DST name, at least one generated trajectory pair must
hold the request and underlying completion result constant while changing only latency/clock
advancement, and demonstrate the expected different observed completion-versus-timeout (or
equivalent deadline/retry) behavior. Both programs must replay deterministically.

If no production behavior observes time, merely carrying unused clock interactions does not meet
the gate. At HEAD, the core retry loop is count/budget based and session `now()` calls primarily
derive ids and durations; several tool/process adapters enforce real external timeouts. The first
time-bearing seam should therefore be a typed tool or delegated-process request whose existing
timeout becomes an explicit live/deterministic adapter contract. The project must not invent a new
agent retry policy merely to make the clock observable.

These two requirements are distinct and must not be conflated during planning. *Which* seam
demonstrates that time matters is a choice, and a tool or delegated-process deadline is the cheapest
first one. *How much* of the clock must be routed is not a choice: complete routing of every
profile-reachable time read is a precondition of conformance, because there is no longer a
virtualization layer under which an unrouted read would still be deterministic. A profile may be
narrow, but within its declared scope the clock seam is all-or-nothing.

**"Profile-reachable" is installation-scoped, not the result of a reachability analysis**, and the
distinction is load-bearing because D5's inventory explicitly does not decide reachability. An effect
site or hook is profile-reachable when it is:

1. in the core driver; or
2. in a module the profile *installs*; or
3. in a core effect site **attributed to an installed hook** by the profile's versioned
   site-to-hook attribution table.

Clauses 1 and 2 are answered by the profile's extension list plus the module inventory. Clause 3 is
answered by an explicit recorded artifact, not by inspection. The term applies to **effect sites and
hooks alike**: a profile-reachable hook is every hook the profile installs, whether or not any corpus
run invokes it.

**Clause 3 is an attribution table, not a semantic test, and an earlier revision got this wrong.** It
read "guarded solely by an installed hook's identity" — a control-path property that the profile list
and module inventory cannot decide, and one whose failure direction is wrong. A site guarded by hook
identity *and* something else fails "solely", falls through unclassified, and is then not required to
be routed: **fail-open**, in the decision that exists to close exactly that hole. Mixed guards are not
hypothetical here — `src/core/tool_phase.ail:222` guards an effectful call with
`is_scratchpad_tool_name(envelope.tool) && scratchpad_extension_active(rt)`.

The mechanical rule: **every core effect site is either attributed to one or more installed hooks in
the table, or it is an unconditional core site under clause 1.** Un-attributed sites fail closed into
clause 1, which over-counts rather than under-counts. Additional guards never remove a site from an
attributed hook's scope — attribution is a claim about which hook can cause the site to execute, not
about the guard being the only condition.

**The table is a constructed, validated artifact, not a name for an intention**, and it gets the same
treatment D6 gives the event vocabulary because it carries the same kind of weight:

- **Contents and binding.** One row per core effect site: the site, its effect, and the installed
  hooks it is attributed to. The table is bound to a source revision and recorded in the versioned
  profile definition above; a source change that adds, moves, or re-guards a core effect site
  invalidates it.
- **Correctness condition.** An attribution asserts that **installation of at least one attributed
  hook is a *necessary* condition of the site executing** — not a sufficient one. Necessity is what
  makes removal from clause 1 safe; sufficiency is what mixed guards break, and requiring it would
  reintroduce the path analysis this clause exists to avoid.
- **Scope.** Only effect sites **after** the simulation boundary are attributable. Host configuration
  discovery, package hydration, and child-process setup sit outside that boundary and must not be
  pulled into the world by an attribution.
- **Validation.** At profile load, failing closed on a site that is neither in the table nor
  unconditional-core, on an entry naming an uninstalled or unknown hook, on a stale source-revision
  binding, and on a malformed row. A *wrong positive* attribution is the failure the fail-closed
  default does not catch, which is why the correctness condition is stated as a checkable claim
  rather than left to the author's judgement.
- **Producer.** Construction, in the same change that builds obligation 2's classifiers — the
  classifiers enumerate the effect sites the table must account for, so building either without the
  other leaves a gap.
- **Scheduling.** As with D6's vocabulary, **no D4 routing-completeness claim and no D5 conformance
  claim may be scheduled before the table exists and validates.** Until then "four driver clock
  reads" is not a derivable number: without an attribution for `src/core/ext/runtime.ail:190`, the
  fail-closed default counts it as unconditional core and the driver obligation is five.

Clause 3 is not a technicality. `src/core/ext/runtime.ail:190` reads the clock inside
`emit_dummy_hook`, in a core module present in *every* profile, behind five `emit_dummy_hook` calls
(`:206`, `:222`, `:245`, `:287`, `:374`), each guarded by `if is_test_dummy(h.id)` (`:206`, `:222`,
`:239`, `:280`, `:368`) — two of the five guards are inline with their call, three open a block above
it.
Clauses 1 and 2 alone would classify it as always-reachable, making the driver's obligation five
sites rather than four. Attributed to `test_dummy`, it is reachable exactly when that hook is
installed, and no checked-in configuration installs it.

The term does **not** mean "a site some execution path can actually perform." Deciding that would
require the reachability analysis D5 obligation 3 declines to require and nothing here builds. The
consequence is deliberately conservative: a site in an installed extension counts and must be routed
even if no run in the corpus reaches it. Withholding the `Clock` capability remains the per-run
backstop for anything that slips through, and it catches executed paths only.

### D5. Execution uses the real traced driver and a named conformant profile

The runner executes an `ExecutionProgram` through `Session.run_v2_session_traced` or a successor
that retains the same production driver, threads D1 world state, and returns a complete trace. The
ordinary `run_v2_from_messages` message-only result is not the DST oracle.

Every run names its **simulation profile** and records an **execution manifest**. The stable,
versioned profile defines the extension hooks, adapter/parser boundaries, resource models, and
effect policy included in the system under test. The per-run manifest pins the core revision,
toolchain, and exact extension/package/ABI versions that realized that profile. “Motoko DST” means
the core under the named profile and recorded manifest; it does not imply that every installable
production extension is hermetic or covered.

A versioned profile definition records:

- profile id/version;
- included extension ids and per-hook classifications (effect-free, world-mediated, or explicitly
  excluded);
- included and excluded provider/tool adapter and parser boundaries;
- logical resource models promised by the profile;
- permitted diagnostic projections;
- forbidden ambient effects/capabilities during execution;
- every required D3 fault class the profile waives, each with the condition that waives it; and
- the **site-to-hook attribution table** (D4 clause 3) under which its profile-reachable set was
  computed, bound to the source revision it was derived from.

Changing any of those semantic scope fields requires a profile-version change. The execution
manifest separately records source revision, toolchain, extension package versions, ABI version,
profile id/version, event-vocabulary version (D6), and normalized profile configuration. Source or package updates therefore
remain exactly reproducible without pretending that every build creates a new semantic profile;
if an update changes the profile's coverage or effect classification, the profile version must
also change.

An extension may appear as covered in a conformant profile only when every hook reachable within
that profile is either:

1. deterministic and effect-free for its explicit inputs; or
2. effectful only through D1 world-mediated ports, with origin tagged by extension id and explicit
   world state returned to the host.

An explicitly excluded hook is not covered, must be named in the result, and causes a fail-closed
`HarnessFailure` if dispatch reaches it. Thus a run cannot gain coverage credit merely because its
seed happened not to exercise a direct-effect hook.

**Exclusion is a coverage cost, not a conformance disqualification, and a profile installing an
extension whose hooks are all excluded is conformant and inert rather than invalid.**

**A coverage floor keeps that from becoming a laundering path.** Because exclusion costs only
coverage, "conformant" would otherwise be satisfiable by a profile that installs everything and
excludes everything. So: **a conformant profile must cover at least one hook of every extension it
installs, or must not list the extension as installed at all.** Installed-and-fully-excluded is not a
conformant configuration; it is a profile that should have omitted the extension and said so. The
interim `ai_step` case is the deliberate exception and must be named as such in the profile
definition, because there the full exclusion is forced by a substrate limit rather than chosen — and
naming it is what keeps the exception visible instead of ambient.

**Per-hook classification reads *declared* effect rows in the interim, not performed ones.** The
reconciling detector that would let a profile claim a hook performs less than it declares is
explicitly unavailable (obligation 2's successor detector), so a hook declaring
`{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}` while returning a constant is **not**
effect-free for classification purposes. This is the conservative reading and it has a real cost:
three of `compaction_ai`'s seven trivial hooks declare exactly that row, so they classify as
effectful and need exclusion despite performing nothing. The extension-granularity rejection rule
above already forces all eight to be excluded, so the two rules agree; when the successor detector
lands, this paragraph is what relaxes.

What *is*
invalid is installing an extension that **references** a classifier-2 `ExtPorts` field while any hook
it registers is **not** excluded: such a path discards world state with no fail-closed signal, so it
is a **profile-definition rejection** rather than a runtime exclusion. The interim `ExtPorts.ai_step`
case is exactly this (D1), and obligation 2's classifier 2 supplies the reference inventory. The
predicate is textual reference at **extension** granularity, not "reaches a seam" and not per-hook
call-graph reachability; D1 states why.
The distinction matters because the two failures happen at different times and only one of them is
detectable at run time: an excluded hook fails closed when dispatch reaches it, while an un-excluded
reaching hook runs successfully and silently.

Direct `AI`, `Process`, `Net`, `FS`, `SharedMem`, `Clock`, environment, or random effects from a
reached hook fail the profile's hermeticity probe. Bounded `IO`/`Trace` projection may remain only
when it cannot feed back into the decision and is not the oracle. Current effectful extensions that
bypass `ExtCtx.ports` are excluded until migrated; pure guards and deterministic fixture hooks may
form the initial profile. Changing an effectful extension to use state-threaded world ports may
require an `motoko-ext-abi` major and its existing lockstep rollout.

An effectful hook cannot retain the current “callback returns only a decision” shape while hiding
world mutation behind `ExtCtx.ports`. A conformant ABI must pass an explicit/opaque world token into
the hook's effect adapter and return the successor token with the hook decision, or provide an
equivalent host-owned linear state protocol. The implementation plan may choose the representation,
but hidden mutable port state is prohibited by D1.

The simulation boundary begins after the runner has decoded and validated its synthetic
configuration and constructed the named runtime/profile. Host configuration discovery, package
hydration, and TypeScript child-process setup remain in the existing harness-boundary tests. No
live secrets or inherited host environment values enter the deterministic world.

Capability flags are necessary but not sufficient because broad `IO` can permit both reporting and
`readLine`, and broad effect rows do not prove which operation was performed. Each profile's
hermeticity gate therefore combines:

- the narrowest executable capabilities, with generation and reporting separated where practical;
- a source/ABI routing audit for direct ambient calls in every in-profile module, subject to the
  structural-first rule below;
- a profile-reachable clock audit whose roots include the extension packages the profile installs,
  derived from that profile's extension list rather than from the repo-wide inventory: a profile
  installing `compose` cannot claim conformance until its eight clock reads route through
  `ExtPorts.clock_now`, and a profile installing none still has the four driver reads to route (D4);
- poison/negative probes for provider, tool, approval, environment, clock, random, and reached
  extension-effect bypasses; and
- profile-definition validation and runtime routing that fail closed when an unclassified
  extension, hook, or adapter is loaded or reached, **and when an installed extension references a
  non-world-mediated `ExtPorts` field from a hook the profile has not excluded** (classifier 2).

**The routing audit is structural first and inventory second, and neither is a reachability
analysis.** An earlier revision required the audit to be "reachability-aware, not textual." That
named a property rather than a buildable analysis, and this repo cannot answer the question it
implies: `tools/code-graph` emits function-to-function edges only
(`INVOKE_FIELDS = ["from_slug", "to_slug", "resolution", "approximate"]`), its parser is regex-based
and self-described as a source-parsed approximation, `ctors.csv` indexes constructor *declarations*
rather than constructor flow, and its default `core` profile is scoped to `src/core` alone —
excluding both `packages/` and `src/core/test/**`, the latter holding `dispatch_step`, `live_ports`,
and `scripted_ports_from_steps`, which are production-executed despite the path. "Can any reachable
caller produce the variant this match arm consumes" is unanswerable from those tables. The
requirement is replaced by three ordered obligations:

1. **Prefer making the defect unrepresentable.** Where a seam admits a dead dispatch arm, narrow the
   type instead of auditing the arm. This is the fix that actually resolved the motivating instance:
   `89a1d67` retyped `C2LoopState.provider` from `StepProvider` to `Ports` and deleted the
   unreachable `LiveAI`/`Scripted` branches, converting a runtime invariant into a compile-time fact
   strictly stronger than any audit this gate could run. A profile may not cite an audit where
   narrowing was available and declined.
2. **For the residual ambient-effect inventory, use a conservative textual inventory of
   ambient-effect imports and call names, per in-profile module, at *site* granularity.** Its profile
   roots are stated explicitly and cover **`src` and `packages`**, including production code under
   `src/core/test/**`. Any ambient import, or any call name it cannot resolve to a routed seam, is a
   fail-closed candidate for manual triage. Over-approximation is the correct bias: an inventory that
   reports more candidate ambient sites than exist forces routing work, which fails closed.

   **The detector is textual by decision, not by default, and the call-graph is explicitly rejected
   for this use.** Two earlier revisions got this wrong in opposite directions and both are recorded
   because the reasoning matters more than the conclusion. The first required a "reachability-aware,
   not textual" audit — a property, not a buildable analysis. The second recommended a
   conservatively over-approximate *function-level call-graph* audit and justified it by claiming
   `tools/code-graph` drops calls through function-valued seams. Both are wrong:

   - The dropped call that claim rests on — `_resolve_call`
     (`tools/code-graph/extractor/source_parser.py:176-199`) discarding `ports.model_step(...)`
     because `ports` is a local binding rather than an import alias — is a **routed** seam call, which
     is precisely the case that *should* be absent from an ambient inventory. The parser resolves
     direct ambient calls through its bare-import path, so `now()` under `import std/clock (now)` is
     seen. That drop never established a fail-open.
   - The real disqualifiers are scope and granularity. `PROFILES["core"]` is `("src/core",)` and never
     contained `packages/` (`tools/code-graph/extractor/config.py:13-17`), so a `core`-scoped audit —
     even with `--include-tests` — misses every extension-package site, including the eight
     `motoko-ext-compose` clock reads the bullet above makes a conformance precondition. And the
     emitted rows are not sites: the plain-call path dedups on `(from_slug, std_module, symbol)`
     while the interpolation path carries no `seen` check, so N ambient calls in one function may
     collapse to one row or emit several. An audit that cannot count sites cannot certify routing
     *completeness*, which is exactly what D4's all-or-nothing rule needs.

   **There are two classifiers, and a profile needs both.** The first covers ambient stdlib effects;
   the second covers ABI port fields that do not yet carry the world token. Neither sees what the
   other sees, and specifying only the first is what left D1's extension-model-path rule without a
   detector.

   ***Classifier 1 — effect-bearing target modules, derived from two sources and reconciled.*** The
   detection set is the **union** of:

   - **the builtin surface**, obtained by filtering `ailang builtins list -json` on
     `is_pure == false` and projecting the `module` field (21 modules on the pin); and
   - **the pinned stdlib's own source**, scanned for `export func … ! {…}` with a non-empty effect
     row, over `~/.local/share/ailang/std/*.ail`.

   **The builtin projection alone is insufficient, and this is the third revision of this obligation
   to be corrected — the reason is recorded so a fourth does not rediscover it.** An effect-bearing
   stdlib module need not have an effect-bearing *builtin row*, because its effects can be defined in
   AILANG source rather than in the builtin registry. `std/sem` is the live case: its only builtin
   rows are the pure `_embedding_decode`/`_embedding_encode`, so the projection omits the module
   entirely — while `std/sem.ail:374,385` export `load_frame` and `store_frame` at `! {SharedMem}`.
   `src/core/cache.ail:29` imports both and calls them at `:60` and `:75`, reached from
   `src/core/rpc.ail:200` via `get_hint`. A classifier built on the projection alone certifies a clean
   inventory over an unrouted `SharedMem` pair **in the core driver**. `std/extension` is a second
   case (`requireWorkdirFile` at `! {FS}`, imported by `packages/motoko-ext-omnigraph/register.ail:4`).
   The trap is subtle enough to have survived two reviews that prescribed the projection: every
   derived row *does* carry a real `std/*` module, which is true and irrelevant — the question is
   whether every effect-bearing module the repo **imports** has a derived row, and ten of the
   twenty-one `std/*` modules this repo imports do not.

   **A reconciliation check is therefore mandatory before the routing inventory may be cited**: compare
   the derived set against every `std/*` module actually imported under the scan roots, and treat any
   imported module not *proven* effect-free as a fail-closed candidate for manual triage. Proving a
   module effect-free means all its builtin rows are pure **and** its source exports no function with
   a non-empty effect row. This check is two commands and is what the previous two revisions both
   skipped.

   Deriving the set from the toolchain rather than hand-listing it matters: the two available
   enumerations disagree — the builtin surface reports seventeen effect labels plus `Pure`, while
   `ailang.toml`'s `[effects] max` permits twelve — so neither alone is a classifier, and a
   hand-maintained list would silently rot. **`Pure` must be filtered out explicitly**; it is the
   largest group, and a gate treating all eighteen output groups as effect-bearing would flag every
   `std/list` import.

   **The classifier is target modules, not symbols, and this is a correction.** An earlier revision
   specified it "as module plus exported symbol". That is underivable from the named command and
   fail-open if built literally: the emitted `name` is the *internal* builtin
   (`_clock_now`, `_fs_readFile`), never the exported wrapper, so no row carries `now` — the name
   Motoko source actually writes under `import std/clock (now)`. An implementer building
   `(module, symbol)` pairs would scan for `_clock_now`, find nothing, and certify a clean inventory
   over thirteen unrouted clock reads. That the `name` field is internal is precisely *why* the
   matching rule below is target-module matching.

   ***Classifier 2 — `ExtPorts` fields that drop a cursor D1 requires threaded.*** The membership
   criterion is: **a field whose call is the extension-side entry to a core seam that D1 requires to
   thread successor state, and which cannot return it.** Today that is exactly **`ai_step`**, because
   `Ports.model_step`'s successor is the only cursor D1 currently demands and `ExtPorts.ai_step`
   returns `Result[string, string]`. Inventory its field-reference sites across every in-profile
   source root.

   **`clock_now`, `proc_exec`, and `env_get` are explicitly *not* members**, and saying so is
   load-bearing rather than tidy. An earlier revision defined the set as "fields that do not yet
   return world state", which selects all four — and under that reading the clock bullet above becomes
   self-defeating: it *requires* a `compose` profile to route its eight reads **into**
   `ExtPorts.clock_now`, which the rejection rule would then reject six lines later. Those three
   fields lose no cursor. They are point reads and effect crossings that the world protocol will
   eventually mediate, but nothing in the interim depends on them returning successor state, so they
   are routing destinations rather than rejection triggers.

   The set is therefore one field today and grows only when D1 requires another cursor threaded
   through an extension-side entry. It does not "retire field by field": it is retired **once**, by
   the single world-token ABI major that *Consequences* budgets, and an earlier revision's
   field-by-field phrasing implied a schedule that does not exist.

   ***Classifier 2's own matcher boundary*** — it does not inherit classifier 1's wholesale, because
   an ABI-field scan and a module-import scan fail differently. The shared limits are the fixed
   `src` + `packages` roots and the refusal to decide reachability. Its own limits: a field reached
   through a **local alias, a re-export, a wrapper function, or a computed field access** is not seen.
   Nothing at HEAD does any of these — the only two `ai_step` references are
   `packages/motoko-ext-compaction-ai/compaction_ai.ail:106` and
   `packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90` — and nothing prevents them, so
   an unresolved or indirect field access is a fail-closed candidate for manual triage rather than a
   pass.

   **Re-deriving both classifiers is a required step of every toolchain repin**, tied to the
   ABI-major milestone *Consequences* already budgets, and both derived sets are recorded with the
   profile or its execution manifest so a later reader can tell what was scanned. Neither is wired
   into CI today, which is acceptable only because the repin is itself a sequenced milestone and
   because D5's routing audit is not citable as gate evidence until it is verified.

   **Match on the imported target module, not on bound symbol names.** Aliased and qualified forms
   typecheck on the pin — `import std/clock as c` followed by `c.now()` compiles clean — so a
   name-matching inventory would miss them by construction. Target-module matching covers the bare,
   aliased, and qualified forms together. Nothing at HEAD uses an alias for `std/clock`, which is why
   this has cost nothing so far and is exactly why it must be specified rather than assumed.

   **Soundness boundary, stated because the gate cites it.** Three limits, all load-bearing and none
   closed by this ADR:

   - It does **not** see effects performed outside the scanned AILANG tree — TypeScript child
     processes, MCP subprocesses, shelled binaries.
   - It does **not** decide reachability. It enumerates sites; the profile decides which are in scope
     (D4).
   - It does **not** reach AILANG source outside the `src` + `packages` roots. A registry dependency
     is the live case: `ailang.toml:9` declares `sunholo/logging` resolved from the registry rather
     than a path, so its AILANG source sits under neither root. Exposure today is nil — the only
     importer is an out-of-profile example — but the gate is the point. **A profile must either
     extend the roots through the resolved lock graph for every AILANG package it installs, or fail
     validation closed when an installed package's source lies outside the scanned roots.**

   Effects reached through an `ExtPorts` or `Ports` closure are **covered**, and this is worth stating
   because the previous two attempts at this obligation both turned on confusing it: the closure is
   written literally at a site inside its defining module, so a site-granularity scan over `src` +
   `packages` sees it. What the scan cannot follow is the *call edge*, which an ambient inventory does
   not need.

   This is a different use than the one that failed in F2 — there a textual scan was asked *which
   seam is live*, a question over-approximation answers wrongly, and it certified
   `std/ai.stepWithStream` as the live provider seam when the only hit was an unreachable ADT branch
   (the same was true of `tools_with_extensions(rt)` and `system_prompt_cache_breakpoint()`).
   Architecture discovery and hermeticity inventory are not the same detector and must not share a
   justification.

   **The successor detector is declared-versus-performed effect-row reconciliation**, which is
   compiler-checked and cannot silently rot as a textual scan can. It is not available today:
   `src/core/agents_md.ail:106` declares `walk_agents` with no effect row while calling `fileExists`,
   a live `FS` under-declaration that pinned v0.26.0 accepts. Closing that class of gap, and the
   reconciliation gate itself, belong to the implementation plan.
3. **If constructor-level reachability is ever genuinely required**, specify the analysis, its
   soundness boundary, its profile roots, and its fail-closed behavior *before* naming it as
   name-adoption gate evidence. Nothing in this ADR currently requires it.

> **Verification gate on obligation 2.** The text above is a repair written by the authoring side in
> response to the two 2026-08-01 delta reviews, which independently converged on it. It has not
> itself been independently verified. **D5's routing audit is not citable as name-adoption gate
> evidence until a reviewer confirms the replacement detector**, and no separate non-citability
> marker is carried elsewhere: D4's clock-detector sentence and this section's third bullet were
> corrected in the same pass rather than left asserting the withdrawn over-approximation claim.

Test-only code may:

- generate and decode programs;
- implement the deterministic world;
- collect replay metadata; and
- evaluate invariants.

It may not reimplement state transitions, recovery policy, tool-history construction, compaction,
or finalization.

Fixed scenarios and pure property tests may continue using narrower entry points. Their existence
does not satisfy this decision unless the generated DST axis drives the real traced session.

### D6. Every run returns one complete terminal trace

The DST runner returns one of two disjoint result classes:

```text
SystemRun {
  outcome,
  ledger_trace,
  interaction_log,
  replay_metadata
}

HarnessFailure {
  kind,
  interaction_position,
  actual_request_projection,
  partial_ledger_trace,
  replay_metadata
}
```

The exact representation may reuse existing types, but the contract is:

1. Every `SystemRun`, whether successful or failed, has exactly one canonical `RunSummary` record in
   `ledger_trace`; it is the final record for the established run. **The starting count at HEAD is
   zero on every terminal path, not one on some.** Every terminal summary routes through
   `emit_run_summary` (`src/core/session.ail:833`, five call sites at `1325`, `1554`, `1704`, `1711`,
   `1762`, of which `1325` is a shared error-return helper reached from several terminal paths), and
   that function's only ledger operation is `ledger_emit` — which is an effectful *projection*,
   `-> () ! {IO, Trace}` at `src/core/session.ail:290`, not an append. The pure function that builds
   the returned trace is `ledger_append` (`src/core/phase_vocab.ail:557`), and no terminal path calls
   it with a `RunSummary`. The returned `LedgerTrace` therefore contains no `RunSummary` on any path.
   That is the exact case item 4 warns about, true of the entire driver
   today rather than of a hypothetical future event. The spike confirmed the requirement is
   reachable without restructuring the driver — routing all seven through one finalization point that
   emits the projection *and* appends the same record was sufficient — but the plan should treat this
   as unimplemented everywhere rather than partially satisfied.
2. A typed internal termination reason maps exhaustively to the wire `finish_reason`. Success,
   budget exhaustion, maximum steps, compaction exhaustion, provider failure, unrecovered tool
   failure, invalid history, and internal driver failure are distinguishable. The implementation
   must derive this list from reachable terminal returns rather than preserve the current
   integer-code helper or stale labels.
3. `DoneEvent` may remain a success event, but it is not a second terminal record. Returned outcome,
   `DoneEvent` when present, and `RunSummary` must agree.
4. Every logical `LedgerEvent` produced by the driver reaches the returned trace, and the obligation
   is **parity**, not a shared transition. Where the substrate permits it, append and project in one
   transition — that is the strongest form and the default. **Stream emissions are the named
   exception where it is not permitted**: the provider callback's closed effect row means projection
   happens during the call and the append happens after it returns, so a single shared transition is
   impossible by construction (D1). For that class the obligation is discharged by an explicitly
   checked invariant instead: the projected sequence and the returned emission log must match
   exactly in order and content, with no duplicate and no omission. Display-only telemetry excluded
   from the ledger is classified separately, by the event-vocabulary artifact below. An external
   `ledger_emit` call is not evidence that the event is in `LedgerTrace`; the returned trace is
   authoritative.
5. Display-only fields such as duration and session id use virtual time or normalization and cannot
   change invariant results.
6. A program mismatch, invalid program, exhausted interaction stream, or forbidden effect is a
   `HarnessFailure`, not a production `RunSummary`. If it occurs after execution begins, the result
   contains the partial trace and actual request projection needed to diagnose it. **This applies to
   violations the runner can observe** — a profile-routing or exclusion violation detected inside the
   runner, which can return a typed value because the driver is still running. It does **not** apply
   to a raw capability bypass: a denied ambient effect terminates evaluation, so no typed result and
   no partial trace can be returned. That case is an expected non-zero run, and the two must not be
   conflated in either the contract or the probes that test it. If both are ever required to return
   the same typed value, an effect-interposition mechanism that preserves the driver-owned partial
   trace must be named and proven on the pinned substrate first; none exists today.
7. Setup failure before the deterministic world and profile are established is also a typed
   `HarnessFailure`; it must not appear as a successful empty trace.
8. Captured console output is diagnostic only.

The implementation should centralize “append to returned trace + emit projection” so new
invariant-bearing events cannot silently update one channel without the other.

**The event vocabulary is a versioned artifact, and it is the fifth recorded axis.** Project 007,
now accepted, records the terminal trace and its wire projection as a maintained compatibility
surface alongside the program schema, generator version, profile version, and execution manifest.
This ADR carries that obligation here rather than leaving it delegated to decisions that do not
mention it. One artifact binds, for every `LedgerEvent` variant:

- the variant itself;
- its wire name;
- its payload schema;
- and its **classification as logical or display-only** — the distinction D6.4 and D7's parity
  invariant both depend on, and which exists nowhere today.

At HEAD the vocabulary has 34 variants whose wire names live in trailing source comments rather
than in a type, and whose consumer is a `switch` in a separate TypeScript process. That is a mapping
which can drift silently, and once the returned trace is the oracle it must not.

**This is new construction, and nothing in the repo is a partial implementation of it.** The one
naming function that exists — `src/core/phase_vocab.ail:561 ledger_record_name` — names **3 of the
34** variants and collapses the other 31 to the literal string `"wire"`. It is not a seed that can be
grown into the artifact; it is a different thing that happens to share a subject. The vertical spike
found this the hard way: its check that the `RunSummary` is the final record in the returned trace
could not be written against `ledger_record_name` and needed a bespoke matcher. The implementation
plan must therefore schedule the artifact as construction with a fail-closed validator, and **must
not schedule any D7 parity invariant or acceptance row that depends on the logical/display-only
classification before the artifact exists** — those checks are undecidable until it does.

The artifact is
validated at load and **fails closed on an unclassified variant**, so a new event cannot enter the
ledger without declaring which side of the logical/display-only line it falls on. The preferred form
derives the wire name from the type, making drift a compile error rather than a runtime surprise;
that also makes the inventory regenerable instead of hand-maintained. Its version is recorded in the
execution manifest (D5) and preserved in the failure record (D8), on the same footing as the other
four axes. A change to any variant, wire name, payload schema, or classification is a version
change, and the compatibility rule for old traces is the one D8 applies to old programs: preserve
decoding or pin a runner, never silently reinterpret.

### D7. Invariants are evaluated over the whole execution

The runner applies reusable invariants to the returned outcome and complete trace. At minimum, the
name-adoption gate requires:

- exactly one final `RunSummary` for every `SystemRun`, and none synthesized for a harness failure;
- parity between all logical ledger emissions and returned trace records;
- legal phase/state transitions;
- valid tool-call/tool-result pairing, including denial and failure paths;
- monotonically valid budget/cost accounting;
- bounded retry and progress behavior under the modeled fault catalogue;
- checkpoint/compaction history invariants already owned by the framework;
- agreement between returned outcome and terminal summary;
- strict-replay request equality, safe regression-replay compatibility, and complete interaction
  consumption;
- valid logical-world transitions, including declared commit/no-commit behavior under faults;
- monotonic virtual time and deadline derivation; and
- zero discovery-generator failures, matcher mismatches, forbidden effects, and ambient RNG reads.

The discovery contract is itself an invariant: under the same execution manifest/profile,
`(schema_version, generator_id, generator_version, seed, initial_world)` run twice must produce the
same resolved program, interaction log, outcome, and normalized trace.

Example-based assertions remain useful, but a generated run that checks only its final prose or a
golden snapshot is not the new DST axis.

Liveness claims must be bounded and operational—for example, “terminates or reaches a named retry
bound within N decisions”—rather than relying on an unbounded test run.

### D8. Replay records the program, not just the seed

Every generated failure reports and preserves:

- execution-program schema version;
- stable generator id/family;
- generator version;
- seed;
- the exact serialized program;
- source revision and AILANG/toolchain version;
- the named profile plus its exact execution manifest;
- the event-vocabulary version under which the trace was written (D6), without which the trace's
  wire names and logical/display-only classifications cannot be interpreted later;
- the normalized run configuration and policy/model-registry inputs needed to interpret it;
- the first failed invariant;
- the terminal outcome; and
- the normalized trace or a stable location containing it.

Replay consumes the exact program and does not regenerate it. This keeps historical failures valid
when generator distributions, draw order, or ranges change.

Programs use a deterministic, diffable encoding with an explicit compatibility policy. The
implementation plan may select the encoding and storage path, but CI output must provide a
copy-pasteable local replay command or artifact reference.

Any change to the PRNG algorithm, draw order, generator ranges, boundary strategy, or default
initial world that can remap a seed requires a generator-version change. A pinned generator canary
for each stable generator id must fail if such a remap occurs without that bump.

The reproducibility promise is precise:

- Repeating discovery under the recorded execution manifest/profile and seed must reproduce the same
  resolved program.
- Under the recorded execution manifest/profile, the exact program must reproduce the same normalized
  interaction log, terminal outcome, and trace.
- Under a newer revision, the program remains the same regression input, but a changed outcome or
  trace may be the intended evidence that a bug was fixed. Compatibility-aware regression mode may
  continue across recorded request-projection differences, but stops on unsafe causal mismatch.
  Replay does not promise identical output across code changes.
- A schema migration must either preserve old-program decoding or provide a pinned runner/artifact;
  silently reinterpreting an old program is forbidden.

Programs contain synthetic values only. Environment maps and interaction artifacts must reject or
redact secret-shaped/live credentials before persistence. Large exact payloads may live in a CI
artifact addressed by digest; a digest without retained bytes is not sufficient for replay.

Shrinking operates on programs, not only seeds, preserves request causality and schema validity, and
revalidates the failure after every reduction. It may land after the first name-adoption gate if the
project records that deferral explicitly, but replay of the unshrunk failing program is not
optional.

### D9. The simulator is sequential until the production contract changes

The deterministic world consumes one expected interaction at a time at production effect
boundaries and threads one explicit world state. It does not add a concurrent scheduler for the
current agent loop.

This decision must be revisited before introducing parallel ledger-affecting tools, ledger-sharing
subagents, state-mutating background callbacks, or independently state-advancing stream handlers.
At that point, reproducibility may require explicit actor identities, runnable sets, and
seed-selected interleavings. Adding concurrency without revisiting this ADR invalidates the
simulation model.

### D10. Existing tests remain, and naming changes only at the conformance gate

Fixed deterministic scenarios, seeded scalar PBT, conformance tests, and live-provider smokes test
different things and remain valuable. The new axis complements them.

During implementation, new code and targets use a non-simulation working name. The unqualified
“DST”/“simulation” label is adopted for the generated axis only after the acceptance test below
passes for a documented baseline profile and the project-007 definition/taxonomy ADR is accepted.
Every report names the profile; additional profiles earn coverage separately.

Existing historical target names are handled by the taxonomy ADR’s grandfathering decision; this
ADR does not broaden that exception.

### D11. Search is a first-class gate, not a collection of fixed seeds

The generated axis has two complementary corpora:

1. a blocking PR corpus containing fixed seeds and exact promoted regression programs; and
2. a scheduled rotating corpus whose seed window changes deterministically and is reported.

Every run reports generator id/version, attempted seeds, completed `SystemRun` count,
harness/generator failures, fault classes reached, **named recovery branches reached**, waived fault
classes with their waiving conditions, terminal reasons reached, and elapsed budget. Class-reached
and branch-reached are separate counters read from D3's catalogue artifact: reaching a fault class
is not evidence that the production branch it targets was executed, and only the second is the
coverage the acceptance test asks for. PR
and scheduled jobs each declare an operator-accepted minimum seed count; the gate asserts that
exact count completed. A zero, silently truncated, or below-minimum window fails. The fixed coverage
bank must collectively reach every required fault class that the profile does not waive, and each
waiver must be declared per D3; rotating search expands beyond it. A
scheduled failure retains its exact resolved program **together with the execution manifest it ran
under** and is promoted to the fixed regression corpus before or with the fix. The two travel as one
artifact. D8's reproducibility promise is conditioned on the recorded manifest and profile, so a
program promoted without one is not a reproduction unit — it is a program nobody can state the
meaning of. A corpus member whose manifest is stale or unresolvable is not silently reinterpreted:
strict replay fails closed, and regression replay may proceed only with the difference recorded.

The implementation plan selects seed counts, rotation, retention, and sharding from measured CI
cost. Parallel workers run independent world states and programs; this is search parallelism, not
multi-actor simulation inside one run.

## Mapping to the project-007 conformance profile

| Project-007 pillar | Architectural evidence in this ADR |
|---|---|
| 1 Hermetic determinism | D1 explicit state; D5 named profile, capability/routing audits, and bypass probes |
| 2 Logical simulated environment | D1 modeled world/resource state; D3 typed outcomes and state transitions; D5 honest profile boundary |
| 3 Seed-driven trajectory | D2 reactive seeded discovery and resolved ordered program |
| 4 Logical fault injection | D3 requires a versioned, checked class→production-branch map, and D11 reports branch-reached counters reading it |
| 5 Controlled time | D4 virtual latency, deadlines, and shared timeout semantics |
| 6 Invariant oracle | D6 authoritative complete trace; D7 whole-execution invariants |
| 7 Search and reproduction | D8 strict replay/artifacts; D11 fixed and rotating search corpora |

## Acceptance test for the name

A reviewer can approve the generated axis as **Motoko single-actor, logical-fault DST** only when
all answers below are supported by an automated gate:

| Question | Required evidence |
|---|---|
| Does one seed generate an execution rather than only values? | At multiple real effect requests, the seeded world chooses responses/faults/latencies that influence subsequent production requests; discovery has zero unexpected harness failures and records the resolved interaction sequence. |
| Is there a modeled logical environment? | Provider, typed tool execution, approval, synthetic environment, runtime randomness if used, clock, and profile-declared logical resource state flow through one explicit state-threaded world with checked transition semantics. |
| Is the tested boundary honest? | The result names the execution manifest and profile; every profile-reachable hook is effect-free, world-mediated, or explicitly excluded; excluded hooks and adapter/parser boundaries are listed; dispatch to an exclusion fails closed; profile-definition validation found no installed extension that references a classifier-2 `ExtPorts` field while registering an un-excluded hook, and none required rejection (D5 classifier 2); and every installed extension has at least one covered hook (the coverage floor). |
| Do injected faults reach production recovery code? | A bounded seed corpus generated by the real generator reaches and replays every required fault class the profile does not waive, together with its mapped production branch, evidenced by D11's branch-reached counters read from D3's catalogue; every waived class is named with its waiving condition. |
| Does virtual time matter? | Every time-bearing read reachable in the profile is routed through the world clock — no residual direct `std/clock` read survives the routing audit — and two replayable programs holding non-time inputs constant but changing generated latency/clock movement produce the expected completion-versus-timeout or equivalent deadline result without invoking an OS timeout. |
| Is production logic under test? | The runner calls the real traced session driver with threaded world state; no test transition loop computes state-machine decisions or history. |
| Is the oracle complete? | Every enumerated `SystemRun` terminal path returns exactly one final `RunSummary`; all logical ledger emissions appear in the returned trace and all D7 invariants pass. |
| Are harness failures separate? | Deliberate mismatch and in-runner routing/exclusion probes return typed `HarnessFailure` with partial evidence and no synthetic production summary; raw capability-bypass poison probes fail the run non-zero, which is the expected and distinct outcome for that class. |
| Are discovery and replay stable? | Repeated discovery with the same seed produces the same resolved program; exact-program replay reproduces its interaction log and normalized trace under the recorded execution manifest/profile without invoking the generator. |
| Is hermeticity enforced? | Generate and execute phases run under declared capabilities; probes show ambient effect, host-env, clock, and RNG bypasses fail or are detected for the baseline profile. |
| Is there actual search? | PR and rotating scheduled corpora complete their declared minimum counts, the fixed bank reaches every required non-waived fault class, class-reached and branch-reached counters are reported, and exact counterexample programs are retained/promoted with their manifests. |

Passing only the current seeded scalar families, replaying only a seed, normalizing timestamps, or
adding fault-shaped constructors without reaching recovery behavior fails this acceptance test.

## Alternatives considered

### Extend `ScriptedStep` with fault variants

Rejected as the complete architecture. `ScriptedStep` currently describes successful model results;
it does not control approval input, typed tool execution, time, terminal tracing, or explicit world
state. It may be migrated into the provider-outcome portion of `ExecutionProgram`, but cannot
represent the whole world by itself.

### Keep the current function-valued `Ports` shape and hide a mutable cursor behind it

Rejected. The callback record does not return next state. A cursor in `SharedMem`, a process global,
or a mutable closure would make replay depend on ambient call ordering and make concurrent test
processes unsafe. D1 requires state to be owned and threaded visibly by the driver.

### Treat all installed extensions as covered once core is ported

Rejected. Many current hooks perform direct effects outside `ExtCtx.ports`, and the ABI's
function-valued ports do not thread deterministic world state. D5 requires a named conformant
profile and honest exclusions; profile coverage expands only as extensions become effect-free or
world-mediated.

### Build a second simulation-only session loop

Rejected. A parallel loop would make deterministic tests precise about the wrong implementation
and allow production recovery behavior to drift.

### Inject state-machine decisions directly

Rejected. The simulator supplies external outcomes; production code owns decisions. Direct decision
injection bypasses the behavior the tests are intended to validate.

### Keep normalizing time instead of virtualizing it

Rejected for time-dependent behavior. Normalization makes traces comparable but cannot search
timeout, retry, deadline, or backoff trajectories.

### Script `Timeout` as an arbitrary outcome and call that virtual time

Rejected. It usefully tests recovery from a timeout, but it does not prove the clock influences
behavior. Pillar-5 evidence derives completion-versus-timeout from generated latency and the
production request deadline.

### Require a concurrent event scheduler now

Rejected. No ledger-affecting interleaving was found in the current loop, tool dispatch, MCP
subprocess, streaming, or compose-subagent paths. A sequential interaction program is the smallest
faithful model. D9 records the conditions that invalidate this choice.

### Store only seed plus generator version

Rejected. A generator version identifies code but does not preserve a failure if that code becomes
unavailable or its dependencies change. The exact program is the durable replay unit, stored inline
or as a retained artifact.

### Split faults, clock, tracing, and generation into separate ADRs

Rejected initially. These mechanisms share the same environment boundary and reproduction contract.
Splitting them before that boundary is decided risks incompatible abstractions. A separate ADR is
warranted later only for a genuinely independent production contract, such as crash recovery or
durable ledger restoration.

## Consequences

Positive:

- “Motoko DST” gains a mechanical, reviewable architecture rather than a naming aspiration.
- Production and test execution share one effect boundary and one state machine.
- Failures survive generator evolution because the exact program is replayable.
- Logical faults and time exercise real recovery behavior.
- Coverage claims name their extension and adapter/parser profile instead of implying the entire
  installable ecosystem is hermetic.
- The architecture remains proportional to a sequential agent loop; it does not import a
  distributed-systems scheduler without a concurrency contract.

Costs and risks:

- Threading world state touches session recursion, provider dispatch, tool/approval phases, and
  traced entry points.
- Complete returned streaming traces depend on an upstream recorded-stream API that no released
  AILANG through v0.31.0 provides. That prerequisite blocks streaming trace parity; it does **not**
  block the `Ports.model_step` widening, which must precede it (D1).
- The typed tool/deadline boundary replaces the current stringly `Ports.tool_exec` seam.
- Effectful extension coverage may require an extension-ABI major and lockstep package rollout;
  until then those extensions remain outside the baseline profile.
- **Repinning the toolchain forces an extension-ABI major on its own, for a reason unrelated to
  extension coverage.** Measured v0.26.0 → v0.31.0: 381 effect-row edits across 71 files, of which
  three change `packages/motoko-ext-abi/types.ail` — `ExtPorts.ai_step` gains `Trace` (its declared
  row was simply wrong), and all four `ExtensionHooks` rows gain `Rand` and `Trace`. Since that file
  states bumping `ExtensionHooks` is a major version, the repin forces an ABI major **and a
  coordinated re-release of every extension package**. This is a scheduling fact independent of what
  upstream does about the recorded-stream API, and D1 requires the repin, so it is on the critical
  path and must be sequenced rather than discovered mid-migration. Two latent under-declarations
  that v0.26.0 accepted surface as hard errors at the same time: `agents_md.walk_agents` performs
  `FS` undeclared, and `motoko_ext_omnigraph.register_with_config` performs `Process` undeclared.
- **That same ABI major must also carry the extension-model-path widening, and it is the larger
  change of the two.** D1 excludes extension-issued model calls from the interim state-threaded seam
  because `ExtPorts.ai_step` returns `Result[string, string]` and the hook results above it are
  decision-only, so no successor can reach `C2LoopState`. Lifting that exclusion means widening
  `ExtPorts.ai_step`, the hook results that carry its outcome, and the core dispatch results — the
  world-token protocol D5 already requires — alongside the mechanical `Trace`/`Rand` row edits above.
  Until it lands, a profile installing an `ai_step`-calling extension is conformant only by excluding
  every hook that reaches the port — a coverage cost, and a profile-definition rejection if it fails
  to (D1, D5). `compaction_ai` calls it and is in the extension order of **all fourteen** checked-in
  configurations, so each can be made conformant only by disabling the hook that gives it its
  function; the first *useful* interim profile is a purpose-built narrow one rather than a shipped
  configuration.
- The trace contract changes error handling and may expose terminal cases currently visible only in
  logs.
- A typed program schema, request matchers, interaction log, and compatibility policy become
  maintained test infrastructure.
- Generated trajectories enlarge the failure space and make shrinking more valuable.
- The sequential design can become stale if a concurrency feature lands without triggering D9.

## Non-goals

- Physical-fault or distributed-systems simulation.
- A production durable ledger, session resume, or crash-recovery mechanism.
- Declaring every deterministic Motoko test to be DST.
- Removing fixed scenarios or seeded PBT.
- Selecting exact AILANG syntax, module names, serialization library, CI seed counts, or rollout
  commit boundaries; those belong to fresh, source-grounded implementation plans.

## Implementation handoff

The checked spike in `spike/` is complete and negative against pinned AILANG v0.26.0, and its two
load-bearing negative compiler results reproduce on latest-checked AILANG v0.30.0 and v0.31.0.
Before acceptance, the upstream recorded-stream API selected by D1 must land, the toolchain must be
repinned to a version containing it, and the direct positive integration probe must pass. This
prerequisite may change the AILANG dependency and spike artifacts, and it must not silently select
the forbidden delayed-projection fallback.

**Work that does not wait for that gate.** An earlier revision of this section read as though the
whole migration queued behind the upstream API. Three items have no upstream dependency and should
be sequenced first, because two of them change what the migration costs and one is a live defect:

1. **Widen `Ports.model_step`'s result with an emission log** (D1, F2). Behaviour-preserving with
   `emissions: []` at every construction site, testable entirely against `Scripted` providers, and it
   shrinks the eventual adoption to one closure in `live_ports`. **This item does not enable item 2**
   — it widens the result only, and a successor cursor is not an emission.
2. **Fix the scripted cursor, partially** (D1, F6). This requires a **second, bidirectional widening
   of the same field**: `model_step` must take the current provider state and return its successor.
   It is *not* behaviour-preserving — it changes the port's input shape and every construction site's
   contract — and it is grounded in D1's cursor-ownership paragraph, not in the loss-channel rule
   that licenses item 1. Plan and review it as a distinct change even though it touches one field.
   Per D1, the successor's sole persistent copy is **one explicit `C2LoopState` field** until
   `world_state` subsumes it; do not park it in a closure inside the `Ports` value.

   **This item does not fix the extension model path**, and that is a decision, not an oversight:
   `ext_ai_step` reaches the same seam through an ABI that cannot return a successor (D1). It fixes
   the main loop. A profile installing an `ai_step`-referencing extension is conformant only by
   excluding **every hook that extension registers** — a coverage cost, and a profile-definition
   rejection if it does not (D1, D5). That is also the one case exempt from the coverage floor, and
   it must be named as such in the profile definition. Budget three things the ADR names and the
   plan must sequence: a
   concrete `ProviderState` declared in `src/core/ports.ail`, the **relocation of `ScriptedStep`** to
   that module or below (the current type is unreachable from both consumers without a module cycle),
   and `ported_provider` returning an initial-state pair. `ScriptedPortsState`/`scripted_model_next`
   (`src/core/test/scripted_ports.ail:20-48`) is a **design precedent, not reusable code** — an
   earlier revision of this item implied it could be wired in, and it cannot.
   `scripts/dst/spike_scripted_cursor_probe.ail` is the executable statement of the defect and
   becomes a passing regression test for the main-loop path when fixed.
3. **Sequence the repin as its own milestone**, budgeting the extension-ABI major it forces
   (Consequences). It is on the critical path because D1 requires it.

A fresh, source-grounded session writes the implementation plan once this ADR and the project-007
taxonomy ADR are accepted; the plan does not wait on the upstream release either, since only the
content of one closure and the parity proof depend on it. **Cite the spike's measurements rather
than re-estimating them** — M1 (the `Message` migration: 14 minutes, 28 files, 69 additive sites,
and 7 sites needing genuine judgement that a grep-derived estimate misses entirely) and M2 (the
repin) are in `NOTE-spike-findings-real-driver-vertical.md`. The plan must survey every effect call
site and re-verify:

- the direct positive D1 streaming-capture evidence and the recorded-stream API's ABI/runtime
  impact;
- every construction and consumer of `Ports` and `StepProvider`;
- the feasibility and ABI impact of explicitly threading world state through `C2LoopState`,
  provider dispatch, tool phases, approval resumption, and traced results;
- all direct `readLine`, `std/clock`, environment, process, filesystem, network, stream, and random
  effects reachable during a session;
- the typed request/result and timeout contracts for native, delegated, MCP, and extension tools;
- every hook reachable in the proposed baseline profile, whether it uses `ExtCtx.ports`, and every
  direct effect that would exclude it or require an ABI migration;
- every return from the traced session driver;
- the ledger event vocabulary, terminal-summary consumers, and all sites where `ledger_emit` is not
  paired with `ledger_append`;
- current seeded-family and CI behavior; and
- all exhaustive matches affected by world requests, typed termination reasons, programs, and
  outcome types.

The plan must preserve user changes and current behavior while migrating one effect class at a time.
No implementation target should adopt “DST” or “simulation” merely because this ADR exists.

## Latest AILANG upstream recheck

Date: 2026-07-24

The repository-configured MCP endpoint in `.mcp.json` was queried first. Its `ailang_versions` tool
reported v0.30.0 as latest. The MCP snapshot was not sufficient by itself: `stdlib_module` and
`stdlib_search` omitted `stepWithStream` even though the same version's guide still documented it,
the listed streaming design document could not be fetched, and the manual-install asset name
returned 404. Those inconsistencies were treated as MCP indexing/metadata defects, not evidence
that the API had been removed. The v0.30.0 source and example also describe the callback effect row
as “open,” but the exported `! {IO}` signature and the compiler's closed-row rejection of
`SharedMem` make that prose stale or incorrect; the executable contract is load-bearing here.

The MCP-selected version was therefore checked against AILANG's official v0.30.0 tag and released
compiler. The release archive's SHA-256 was verified as
`58561c11ca7be7710b3b4eca9ddfdf263f39bc4e36428969a1968175f10b84b6`; the compiler reports v0.30.0
at commit `e37b370d1d7a9c4e7136b319e38bec4d5f2bd9a0`. The authoritative result is:

- `std/ai.ail:330-337` has the same `stepWithStream` signature as pinned v0.26.0;
- the callback still returns `()` and has the closed `{IO}` effect row;
- the call still returns only `Result[StepResult, AIError]`;
- no recorded-stream API or returned chunk log exists in the v0.30.0 AILANG source;
- both project spike negative probes fail for their intended type/effect reason on v0.30.0; and
- AILANG's v0.30.0 IO-only streaming example checks and runs under `--ai-stub`.

Ruling: no ADR decision changes. The D1 acceptance blocker is current through AILANG v0.30.0.

## Upstream recorded-stream API status

Date: 2026-08-01. Tracking issue:
[`sunholo-data/ailang#546`](https://github.com/sunholo-data/ailang/issues/546) (open, `enhancement`).

Released v0.31.0 (`1f6f7dd28`) still exports no recorded-stream API, so the D1 substrate gate is
**not cleared**. What changed is that the gate stopped being a design question.

Upstream triaged the request on 2026-07-31 and reviewed it the same day. It reproduced the
constraint first-party at HEAD `130ad1da2` — an `{IO}` rendering callback type-checks; an `{FS}`
callback appending each chunk to a file fails with `incompatible closed rows` — and independently
confirmed this ADR's finding. Its verdict was to **adopt this project's reference implementation
rather than reinvent it**: the patch applies clean, is purely additive (+452 lines, 5 files, 0
deletions), its tests pass, and the surrounding suite stays green. The
`{chunks: [StreamChunk], outcome: Result[StepResult, AIError]}` shape was judged correct for the
reason the request gave — a `Result[{result, chunks}, err]` discards every chunk observed before a
mid-stream failure, which is the case replay depends on most. A design doc has landed upstream
(`design_docs/planned/v0_31_0/m-recorded-stream-api.md`) at P0, and authorship is to be credited.

The work is **parked** on one scope question that is explicitly *not* about direction: whether the
fail-loud path's unbounded drain requires adding cancellation to the provider interface. This
project's answer, filed 2026-08-01, is recorded in `REPLY-546-park-unbounded-drain.md`.

**Two facts from that exchange are load-bearing for this ADR:**

1. **None of the parked options changes the `{chunks, outcome}` type.** The shape survived two
   quorum rounds and the park concerns drain semantics beneath it. The API's shape may therefore be
   designed against now, and the adapter seam this ADR requires can be typed before the release
   exists.
2. **No date was promised**, and upstream explicitly advised keeping this project blocked rather than
   waiting. Combined with F2 — that adoption changes nothing observable until `Ports.model_step` is
   widened — the correct response is to proceed with the upstream-independent work rather than to
   idle. D1 and the implementation handoff are revised accordingly.

Ruling: no decision changes; the blocker narrows from "an API must be designed and land" to "a
released binary must ship an API whose shape is already agreed."

## Author self-review record

Reviewer: Codex (`GPT-5`), 2026-07-24. This is an iterative author-side review, not the independent
review required before acceptance.

The review used five adversarial passes:

1. **Current-source feasibility.** Rejected the draft's assumption that the function-valued
   `Ports` record could consume one cross-effect program; replaced it with explicit driver-threaded
   world state and recorded the load-bearing source anchors.
2. **Simulation semantics.** Split reactive seeded discovery from resolved-program replay, added
   ordinal causal request identity, strict versus regression replay, logical resource state, and
   explicit fault state transitions.
3. **Clock and trace attack.** Required timeout to derive from generated completion time plus a real
   production deadline; verified and incorporated AILANG v0.26.0 runtime virtual time; exposed the
   callback/immutable-trace substrate gap; ran the checked capture spike, which proved an upstream
   recorded-stream API is required; and made the returned ledger complete with one final canonical
   `RunSummary`.
4. **Boundary and prior-decision consistency.** Added fail-closed versioned extension profiles,
   separated their semantic definitions from per-run execution manifests, prohibited hidden
   mutable port state, and explicitly amended the phase-core port/raw-effect decisions while
   preserving its functional-core and policy boundaries.
5. **Enforceability and search.** Added capability-plus-routing hermeticity checks, deliberate
   harness-failure probes, generator bounds/version canary, profile evidence, required fault
   reachability, fixed/rotating corpora, and counterexample promotion.

No further decision-level defect was found after those revisions. The ADR intentionally remains
Proposed until the upstream D1 recorded-stream API lands and the direct positive spike passes.
Other residual implementation risks are explicit rather than hidden: AILANG ergonomics may affect
the concrete state-token representation; an effectful-extension profile may require an ABI major;
and the first baseline profile and measured CI seed counts still require operator approval in the
fresh implementation plan. A fresh independent review must attack the revised decisions before
this ADR becomes Accepted.

## Review Comments

_Reviewer: Claude Code (model: `claude-opus-5`), 2026-07-26. Independent review for acceptance._

_Revision used: HEAD `d894638375471ced85c3bc0477975489b08c041b` (branch
`arniwesth/mot-43-l1-seeded-families`). The ADR is grounded at `7b9b4a4c` and HEAD has moved five
commits, but `git diff --stat 7b9b4a4c..HEAD -- src packages scripts Makefile .github` is **empty** —
every commit since is `.agent/`, `design_docs/`, `bun.lock`, `package.json`. Every source anchor in
this ADR is therefore evaluable at HEAD without re-grounding, and 007's HEAD-verified single-actor
and physical-fault rulings carry forward unchanged. Toolchains exercised: pinned AILANG v0.26.0
(`3b52a24`, `~/.local/bin/ailang`) and the local prototype (`~/src/ailang/bin/ailang`, `dev`
`24120ade2-dirty`)._

---

### R1. D4's virtual clock does not exist on the pinned toolchain, and the Context row that grounds it proves only that a flag is accepted

**Defect:** `--virtual-time` is a status banner. On pinned v0.26.0, `std/clock.now()` returns real
wall-clock epoch and `std/clock.sleep(ms)` blocks for `ms` of *real* time with a run-to-run variable
delta, with or without the flag. Every mechanism in D4 that depends on the runtime clock —
the fixed virtual epoch, the checked-delta mirror, the conformance assertion comparing explicit and
runtime clocks, and the migration safety net that makes residual `std/clock.now` reads deterministic
— is unimplementable as written, on the pinned toolchain *and* on the prototype the D1 probes ran
against.

**Grounding:** Probe (`scratchpad/rowprobe/vclock.ail`): `t0 = now(); sleep(5000); t1 = now();
sleep(1000); t2 = now()`. All five activation paths on pinned v0.26.0:

```text
$ ailang run --virtual-time --caps IO,Clock --entry main vclock.ail
t0=1785077152822 t1=1785077157823 t2=1785077158824 d1=5001 d2=1001
$ ailang run --seed 42 --caps IO,Clock --entry main vclock.ail
t0=1785077158870 t1=1785077163871 t2=1785077164872 d1=5001 d2=1001
$ ailang run --virtual-time --seed 42 --caps IO,Clock --entry main vclock.ail
t0=1785077164923 t1=1785077169927 t2=1785077170928 d1=5004 d2=1001
$ AILANG_SEED=42 ailang run --caps IO,Clock --entry main vclock.ail
t0=1785077170997 t1=1785077176001 t2=1785077177002 d1=5004 d2=1001
$ ailang run --caps IO,Clock --entry main vclock.ail          # no flags, control
t0=1785077177057 t1=1785077182054 t2=1785077183055 d1=4997 d2=1001
```

`t0` is real epoch in every case; `d1` for a 5000 ms sleep ranges 4997–5004 across runs; wall-clock
elapsed is ~6.0 s (`time` reported `real 0m6.102s` under `--virtual-time`, `0m6.033s` without).
Identical on the prototype: `~/src/ailang/bin/ailang run --virtual-time … → t0=1785077068981 …
d1=5001`, `real 0m6.320s`.

Source explanation, offered as diagnosis rather than as the finding: `--virtual-time` and `--seed`
are printed and not otherwise threaded (`~/src/ailang/cmd/ailang/main_run_exec.go:184-189`); the
clock's deterministic branch gates on `ctx.Env.Seed != 0`
(`/tmp/ailang-v030-audit.7DwR3w/internal/effects/clock.go:47,96` — the v0.30.0 release tree), and
`EffEnv.Seed` is populated only from `AILANG_SEED` (`internal/effects/context.go:495-502`), which
also failed to activate it above. I did not diagnose why the env path fails; that is upstream's, not
this ADR's.

The affected ADR text: `ADR:90-91` ("AILANG v0.26.0 does provide runtime virtual time
(`--virtual-time`; `std/clock.sleep` advances it)"); `ADR:124` (the Context row); and D4 at
`ADR:401-411` in full. `ADR:124`'s cited command reproduces *exactly* — `ailang run --virtual-time
--caps IO --no-print scripts/smoke_ports_record.ail` prints `⏰ Virtual time enabled` and exits 0 —
which is the point: the evidence establishes that the flag parses, not that a clock is virtualized.
The stdlib docstring agrees with the ADR and contradicts the implementation
(`~/.local/share/ailang/std/clock.ail:1-5,20-22`: "advances virtual time in deterministic mode").
This is precisely the failure mode the ADR itself named for streaming — "the v0.30.0 source and
example also describe the callback effect row as 'open,' … the executable contract is load-bearing
here" (`ADR:862-864`) — applied to the callback and not to the clock.

Consequences beyond D4. (a) `AdvanceClock(delta)` mapped to `sleep(delta)` makes replay cost real
wall time proportional to modeled latency, which destroys D11's seed budget and, because the delta
is not exact, breaks D7's "monotonic virtual time" as a *deterministic* invariant. (b) The migration
sequencing changes materially: D4 currently leans on runtime virtualization so that un-routed reads
are merely unexplained ("runtime virtualization makes them deterministic but does not record why
they were read", `ADR:407-409`). They are not deterministic. Every residual `now()` —
`src/core/session.ail:788,839,1990,2089` — is a live nondeterminism source until routed, so complete
`std/clock` routing becomes a hard precondition of D5 conformance rather than an incremental
convenience. (c) Acceptance-test row 5 (`ADR:709`) opens with "Discovery/replay run under pinned
runtime virtual time", which no toolchain I tested can satisfy.

**Action:** Delete the runtime-clock mirror from D4 and rely solely on the explicit `world_state`
clock, which D4 already declares authoritative (`ADR:404-406`) and which needs no upstream support.
Concretely: drop the `--virtual-time` requirement, the fixed-epoch/checked-delta/conformance-assertion
paragraph, and the fresh-evaluator-per-seed clause; replace the migration allowance with a hard D5
requirement that no in-profile module may reach `std/clock` directly, enforced by the D5 routing
audit and a `Clock`-capability poison probe. Rewrite acceptance row 5's first clause to test the
explicit clock. Re-ground `ADR:90-91` and `ADR:124` on the executable result above. If the runtime
mirror is retained instead, record it as a **second** upstream blocker of equal standing to the
recorded-stream API and say so in the Status line — but the world-clock-only route is cheaper,
needs no upstream, and is what D1 already requires. The stdlib-docstring/implementation divergence is
independently worth an upstream report, alongside the compile-cache one.

### R2. The ADR amends 004 but leaves in force 004's normative stream-delta ledger-append handle, which this ADR's own spike proves unbuildable

**Defect:** 004 resolved the identical streaming/trace-ordering problem with a *normative* mechanism
— a driver-supplied ledger append handle used *during* the model call — and carried a Phase-B
byte-parity test for it. This ADR's `Amends:` clause preserves 004's "append-only ledger" and
"driver-owned effect execution" and replaces only "function-valued ports as the complete
deterministic-state mechanism" (`ADR:22-26`). It never names 004's append handle, which is not
merely superseded by D1 but *impossible* on any AILANG the spike tested. A future implementer
reading 004 builds the handle; reading this ADR, the emission log. Two live normative answers to one
question, one of which cannot compile.

**Grounding:** `../004_phase_core_refactor/ADR-001-phase-oriented-core.md:152-159`: "**Streaming
protocol** (review P1-R3/P2-R4): … Normative resolution: the driver hands the model phase a **ledger
append handle** (a port) scoped to stream-delta events only; deltas are appended through it in
arrival order while the call is in flight. The handle is driver-constructed, so single logical
authority holds… Phase B carries a byte-parity test for the `thinking_stream_start → N×delta →
thinking_stream_end` sequence." Such a handle must mutate shared state from inside `on_chunk`, whose
row is closed at `{IO}`. The spike settles `SharedMem`; I extended it to `Trace`, which the append
handle would also need:

```text
$ ailang check trace_cb.ail   # top-level func render(chunk) -> () ! {IO, Trace}
Error: … failed to unify parameter 4: failed to unify effect rows:
  incompatible closed rows: r1 has extra labels [], r2 has extra labels [Trace]
```

I also tested the obvious escape hatch — declaring the widened row on an intermediate function's
*parameter* rather than at the `stepWithStream` call site. It fails, and fails at the outer
application, because the inner call narrows the declared parameter row to `{IO}`:

```text
$ ailang check smuggle.ail
Error: … type unification failed at [function application at smuggle.ail:20:11]:
  … incompatible closed rows: r1 has extra labels [], r2 has extra labels [SharedMem]
```

(This also explains why `src/core/test/stub_step.ail:185` can declare `on_chunk: (StreamChunk) -> ()
! {IO, Trace}` and still typecheck — `ailang check src/core/test/stub_step.ail` → `✓ No errors
found!` — while no `{IO, Trace}` function can actually be passed to it. The annotation is inert.)

**Action:** Add 004 §3's stream-delta append-handle resolution to this ADR's explicit amendment list,
stating that D1's returned ordered emission log replaces it and why (the mechanism is unbuildable,
not merely superseded), and say what becomes of 004's Phase-B byte-parity test for the
`thinking_stream_start → N×delta → thinking_stream_end` sequence — the ordering it protects is a live
TUI contract and D1 must preserve it.

### R3. 007 delegates a fifth versioned surface — the ledger event vocabulary and its wire projection — to D5/D8/D11, and none of them carries it

**Defect:** Accepted 007 books the ledger/wire event vocabulary as a maintained compatibility
surface and assigns its "encoding, migration mechanism, and compatibility policy" to this ADR's D5,
D8, and D11. D5's manifest enumerates six recorded fields and the vocabulary is not among them; D8's
compatibility policy is scoped to *program* encoding; D11 is search policy. So an accepted ADR
promises something this ADR does not supply.

**Grounding:** `../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md:311-337` —
"*The ledger event vocabulary and its wire projection.* `LedgerEvent` already carries 34 variants
(`src/core/phase_vocab.ail:597-631`) … the mapping lives in a trailing comment … and the consumer is
a TypeScript `switch` in a separate process (`src/tui/src/index.ts:428`). D2's trace oracle makes
that mapping load-bearing in both directions … Versioning is therefore not one number but four
independent axes … **plus a wire vocabulary shared with the TUI** … The encoding, migration
mechanism, and compatibility policy belong to `../009_motoko_dst_execution/ADR-001-…` (D5, D8,
D11)." Against `ADR:457-461` (the manifest records "source revision, toolchain, extension package
versions, ABI version, profile id/version, and normalized profile configuration") and `ADR:612-614`
(D8's encoding/compatibility policy, scoped to programs).

Verified at HEAD: 34 variants, and all 34 wire names are trailing comments —
`sed -n '598,631p' src/core/phase_vocab.ail | grep -c '^  [=|]'` → `34`, and `| grep -c -- '--'` →
`34`. One variant maps to two wire names (`StreamDelta … -- [prod] thinking_delta |
reasoning_delta`, `phase_vocab.ail:631`). The one recorded guard is already broken: 004's documented
regeneration command, run at HEAD, returns nothing, because `agent_loop_v2.ail` is now a 123-line
compatibility facade —

```text
$ grep -o 'emit_event(session_id, "[a-z_]*"' src/core/agent_loop_v2.ail | wc -l
0
```

— so the "29 event types" inventory pinned in `src/core/phase_vocab.ail:467-470` and
`004/ADR-001:139-147` is both stale against 34 and unregenerable. D6.2 makes this worse before
better: it requires replacing today's `finish_reason_str(r: int)` helper
(`src/core/session.ail:817,835,857`) with a derived typed enumeration, which is exactly the
TUI-observable contract 007 flags.

**Action:** Either add the ledger event vocabulary and the typed termination-reason enumeration as a
fifth recorded axis — versioned in D5's profile/manifest and preserved in D8's failure record — or
state explicitly that this ADR declines 007's delegation and route it back with a named owner. Do
not leave it assigned to three decisions that do not mention it. If adopted, the cheapest form is
the one 007's Open Questions already suggest: derive the wire name from the type so drift is a
compile error, which would also repair the unregenerable inventory.

### R4. D6.4 is unsatisfiable for the one event class this ADR spends most of its effort on, and D1 prescribes the mechanism that violates it

**Defect:** D6.4 requires every logical `LedgerEvent` to be appended to the returned trace *by the
same transition that projects it*. For stream chunks that is structurally impossible, and D1 says so
itself: projection happens inside the callback during the call, the append happens after the call
returns. A reviewer applying D6.4 mechanically must fail the streaming path.

**Grounding:** `ADR:548-551` — "Every logical `LedgerEvent` produced by the driver is appended to the
returned trace by the same transition that projects it to IO/Trace." Against `ADR:156-161` — "A live
adapter also projects each chunk to the UI at arrival; **after the call returns**, the driver appends
the adapter's identical emission log…". The callback cannot do both: its row rejects `Trace` (R2's
first probe) as well as `SharedMem`. `spike/README.md:184-188` records exactly this and rules it "a
note for the implementation plan, not a defect" — but the ADR body, which is the normative document
and the thing the gate is applied to, carries no exception. Acceptance row 7 (`ADR:711`) then asks
for "all logical ledger emissions appear in the returned trace", which parity *can* deliver;
D6.4's stronger same-transition clause cannot.

**Action:** Restate D6.4 as a *parity* obligation — same transition where the mechanism permits,
otherwise an explicitly checked parity invariant — and name stream deltas as the class where
projection and append are necessarily distinct transitions, citing the closed callback row. One
clause; it changes nothing architectural and removes a gate a conformant implementation would fail.

### R5. Acceptance row 4 demands evidence that D3 does not require to exist and D11 does not require to be reported

**Defect:** The fault row of the acceptance test asks for a corpus that reaches "every required fault
class **and its mapped production branch**", but D3 defers the class→branch mapping to the
implementation plan and requires no checkable artifact, and D11's mandated counters report fault
classes only. A reviewer cannot reach yes/no from the gate output; they must judge. That is 007 R8's
defect surviving inside this ADR's fix for it.

**Grounding:** `ADR:708` (row 4) versus `ADR:368-370` — "The **implementation plan** must map every
modeled class to a real production error or result type and name the recovery branch it is intended
to reach" — and `ADR:673-675`, which requires reporting "generator id/version, attempted seeds,
completed `SystemRun` count, harness/generator failures, **fault classes reached**, terminal reasons
reached, and elapsed budget". No branch-level coverage is required anywhere. The mapping table
compounds this by claiming delivery: `ADR:693` reads "4 Logical fault injection | D3 fault catalogue
**mapped to production branches**", which D3 does not do. This now propagates: accepted 007 D2 names
this ADR's D3 as the normative minimum catalogue (`007/ADR-001:190-192`), so the overclaim is
load-bearing outside this project.

**Action:** In D3, require the fault-class→production-branch map to be a machine-readable artifact
that the gate reads (007's Open Question "Fault-catalogue ownership" asks for exactly one source of
truth). In D11, add branch-reached counters alongside fault-class counters. Correct `ADR:693` to say
D3 *requires* the mapping rather than supplies it.

### R6. The promoted regression artifact is the program alone, but the reproducibility promise is conditioned on a manifest the program does not contain

**Defect:** D2 calls the serialized program "the authoritative reproduction artifact" and D11
promotes the program to the fixed corpus, while D8's reproducibility promise holds only "under the
recorded execution manifest/profile" — which is not a field of `ExecutionProgram`. A corpus member
therefore does not carry what its own strict-replay contract requires, and 007 makes the corpus's
oldest member the compatibility floor.

**Grounding:** `ADR:282-289` — `ExecutionProgram` fields are `schema_version, generator_id,
generator_version, seed, initial_world, interactions[]`; `initial_world` carries `extension_profile`
(`ADR:274-279`) but no manifest. `ADR:336-338` — "the serialized resolved program is the
authoritative reproduction artifact". `ADR:620-625` — "Under the recorded execution
manifest/profile, the exact program must reproduce the same normalized interaction log, terminal
outcome, and trace." `ADR:679-680` — "A scheduled failure retains its exact resolved program and is
promoted to the fixed regression corpus." D8's failure *report* does list the manifest
(`ADR:602-603`), but the promoted corpus artifact is specified as the program.

**Action:** Make the manifest travel with the promoted program as one artifact — either a field of
`ExecutionProgram` or a named sidecar the D2 structural validator requires — and state what a corpus
member whose manifest is stale or unresolvable means: strict replay fails closed, regression replay
may proceed with the difference recorded. `NOTE-ailang-world-overlap.md:105-116` already recommends
the stronger form (content-address program, trace, and manifest; retain bytes; fail explicitly on an
unavailable pinned artifact); adopting it here would close this.

### R7. D6.4's logical-versus-display-only classification is required but unlocated, so D7's parity invariant and acceptance row 7 are not decidable

**Defect:** D6.4 requires display-only telemetry to be "classified separately" but names no artifact,
owner, validation, or version for that classification — unlike the profile (D5 gives it a versioned
definition and fail-closed runtime validation) and the program (D2 gives it a structural validator).
D7's "parity between all logical ledger emissions and returned trace records" and acceptance row 7
both quantify over a set nothing defines.

**Grounding:** `ADR:548-551` (the classification requirement, one sentence, no home) and `ADR:552-553`
(only duration and session id are named as display-only). The set is not small at HEAD: `session.ail`
has 37 `ledger_emit` call sites against 14 `ledger_append` sites, and `tool_phase.ail`'s eight
emissions flow through `emit: (LedgerEvent) -> () ! {IO, Trace}` (`tool_phase.ail:311`), a
unit-returning callback that structurally cannot append, into a `ToolDispatchOutcome` that carries no
trace (`tool_phase.ail:148-150`). A concrete instance the Context row does not mention:
`ThinkingStreamEnd` is emitted at `src/core/session.ail:1770` and is absent from the trace expression
built at `:1778`, which appends only `start_event`, `prepared_event`, and `phase.events`.

**Action:** Give the classification the same treatment as the profile — a versioned artifact,
validated at load, fail-closed on an unclassified `LedgerEvent` — and fold it into R3's fifth axis so
one surface carries variant, wire name, and logical/display-only class together.

### R8. Two of D3's four required fault classes are conditional, and nothing requires a run to declare that it waived them

**Defect:** D3's approval row is conditioned on a deadline "enabled by the production policy" and its
extension row on the selected profile containing an effectful hook. Neither condition holds at HEAD
or in the baseline profile D5 sketches, so the normative minimum that accepted 007 defers to can
shrink to provider + tool without any report saying so.

**Grounding:** `ADR:365-366` (both conditions) against `ADR:477-479` — "Current effectful extensions
that bypass `ExtCtx.ports` are excluded until migrated; pure guards and deterministic fixture hooks
may form the initial profile" — and HEAD's approval path, which is a blocking `readLine()` with no
timer (`src/core/session.ail:1616`); `AllowAfterTimeout`/`DenyAfterTimeout`
(`src/core/tool_phase.ail:152-156`) are policy defaults with no deadline behind them. D11 requires
reporting classes *reached* (`ADR:673-675`); nothing requires reporting classes *waived*. Accepted
007 D2 pillar 4 points at D3 as "the normative minimum" (`007/ADR-001:190-192`), so a reader of 007
will over-read what a passing gate proves.

This is honest engineering, not a hole — D4 rightly refuses to invent a retry policy to make the
clock observable (`ADR:430-431`). The defect is silence, not scope.

**Action:** Require the run report and the D5 profile definition to name every required fault class
that the profile waives and the condition that waived it, so a coverage claim is readable against
D3's full table rather than against its applicable subset.

### R9. D3's physical-fault tripwire is weaker than the one accepted 007 D1.3 binds it to

**Defect:** 007 D1.3 names five concrete reopen triggers and says the tripwires "belong both in the
taxonomy ADR and beside the execution runner". This ADR carries the concurrency tripwire precisely
(D9) but reduces the physical-fault tripwire to a general clause naming no trigger.

**Grounding:** `007/ADR-001:175-178` — "**Reopen before adding a crash-recovery, fsync, WAL,
resume-from-ledger, or replicated-state correctness contract.**" Against `ADR:392-393` — "Adding
physical faults or changing the system's durability contract requires revisiting the project scope."
`NOTE-scope-and-sequence.md:92-93` does carry the named triggers, but that NOTE is "Proposed project
boundary", not the normative decision. By contrast D9 (`ADR:648-652`) matches 007 D1.1's four
triggers item for item, which is the standard to meet.

**Action:** Restate D3's physical-fault clause with 007 D1.3's five named triggers, so both
exclusions are equally hard to trip over.

---

## What is accurate

Re-executed or re-read at HEAD `d894638`, not assumed. The three rulings the handoff asked for come
first.

**Ruling 1 — D1's explicitly-threaded world state is threadable through the real driver. Confirmed.**
This is the keystone and it holds. `C2LoopState` is already an explicit record threaded through
`c2_loop`'s recursion and already carries both adapter state and the trace
(`src/core/session.ail:338-357,1509-1524`); adding a `world` field is the same move the record
already makes for `provider: StepProvider` and `trace: LedgerTrace`. Provider dispatch already
returns a successor — `dispatch_step(...) -> { result, next_provider }`
(`src/core/test/stub_step.ail:180-186`) — so `{ result, emissions, next_world }` is an extension of
an existing shape, not a new discipline; the D1 vertical slice models exactly that and compiled
first try. Approval sits directly in the driver branch that already builds the successor state
(`session.ail:1609-1617,1675`). The traced entry point constructs initial state in one place
(`:1989-1995`, `run_v2_session_traced` at `:1999`). There is one driver: `agent_loop_v2.ail` is a
123-line compatibility facade re-exporting `session` (`src/core/session.ail:17`), so no second loop
has to be threaded. The two genuinely hard seams are correctly identified by the ADR and no others
were found: `ToolDispatchOutcome` returns neither state nor trace and must gain both across four
signatures in `tool_phase.ail` and one call site (`session.ail:1658`); and `ExtensionHooks` returns
decisions with broad effect rows and no successor (`packages/motoko-ext-abi/types.ail:151-164`),
which is the ABI major D5 already books. The one seam that cannot be threaded at all is the chunk
callback — which is exactly the upstream ask. D1's "production code does not branch on test mode" is
reachable: the `StepProvider` match in `dispatch_step` is adapter dispatch on a value, which is the
analogy D1 itself draws (`ADR:236-238`).

**Ruling 2 — the single-actor boundary holds, and D9 is correctly scoped.** 007's D1.1 evidence was
verified at `a7932c6`; `src`, `packages`, `scripts`, `Makefile`, and `.github` are byte-identical
between that revision and HEAD, so the ruling carries without re-derivation. Spot-checked anyway:
tool entries recurse in list order (`tool_phase.ail:314-357`), native batches are sequential
(`run_native_batch_rec`, `tool_runtime.ail:151-165`), MCP is a blocking `exec("bash", …)`
(`packages/motoko-ext-mcp/exec.ail:63-70`, reached from `run_mcp_tool` at `:165-170`). D9's four
reopen triggers match 007 D1.1's four item for item, and `NOTE-ailang-world-overlap.md:196-199`
adds the right fourth-party trigger (a World scheduler introducing concurrent ledger-affecting
execution).

**Ruling 3 — the streaming disposition is correct, the gate is genuinely open, and the chunk-timestamp
conclusion survives independent re-derivation.** Re-derived rather than accepted: D2's stream offsets
are *generated* by the seeded generator during discovery and *read from the program* during replay
(`ADR:329-332`), and discovery runs against a deterministic world, not a live provider
(`ADR:261-264`) — so no path in this ADR requires observing a real chunk arrival time. The live
adapter needs arrival *order* only, which the proposed API supplies. D2's "non-decreasing virtual
offsets" clause is therefore reachable, the upstream ask is complete, and it should not acquire a
timestamp requirement. The negative results all reproduce at HEAD (after `rm -rf .ailang` — the
cache caveat is real):
`probe_state_returning_callback_rejected.ail` → `cannot unify type constructor () with *types.TList`;
`probe_sharedmem_callback_rejected.ail` → `incompatible closed rows: … extra labels [SharedMem]`;
`probe_real_stream_callback.ail` under `--caps AI,IO --ai-stub` → `PASS real_stream_callback stop`.
I extended the spike with two escape routes it did not test — a `{IO, Trace}` callback, and the
widened row declared on an intermediate *parameter* — and both fail (see R2), which strengthens the
disposition rather than weakening it. The gate is unambiguously **not** cleared: the prototype is
uncommitted working-tree modifications to `std/ai.ail` and three Go files on `dev`, and the committed
tree has none of it —

```text
$ cd ~/src/ailang && git show 24120ade2:std/ai.ail | grep -c stepWithStreamRecorded
0
$ git show 24120ade2:std/ai.ail | grep -n "^export func stepWithStream"
330:export func stepWithStream(
```

— so the blocker is current on `dev` as well as on v0.26.0 and v0.30.0. `spike/README.md:5-7,43-47`
states this correctly and cannot be read as claiming otherwise. Both new probes pass against the
prototype and are load-bearing: `run_world_slice.sh` → `world_slice: PASS — live and deterministic
paths agree on both outcomes`, including `program_non_empty (emissions=2)`, which is the assertion
that makes a vacuous pass impossible.

**Citation audit — all seventeen Context anchors verified, plus the v0.30.0 line cite.** Every row of
`ADR:109-127` resolves to the claimed construct at HEAD: `ports.ail:17-24` (six function-valued
fields, `tool_exec: (string, string) -> string`); `scripted_ports.ail:20-65` (`ScriptedPortsState`
at 20; `scripted_model_next`/`_approval_next`/`_clock_next` at 38/50/62, each returning `result +
next`); `stub_step.ail:34-41` (exact — the six-field success-only record); `session.ail:146-149`
(exact — `TracedSessionResult { result, trace }`); `:1610-1617` (`readLine()` at 1616);
`:1989-1995` (`now()` at 1990); `:1525-1557` (exact — `InvalidHistory` direct return at 1527-1528,
`emit_run_summary` at 1551 and `DoneEvent` at 1552 both absent from `trace_after_empty_floor`);
`:1609-1614` (pending-approval direct return); `tool_runtime.ail:151-165`; `tool_phase.ail:302-357`;
`packages/motoko-ext-mcp/exec.ail:63-70,165-176` and `:45-70,165-170`;
`stub_step.ail:175-204`; `ai_compat.ail:31-37,60-71,197-220` (`chunks: []` on both arms, docstring
"populating it would require an AILANG Ref"); `motoko-ext-abi/types.ail:62-66,151-164`;
`motoko_scratchpad/scratchpad.ail:90-101` (`on_tool_handle` performs `{Net}` directly, no
`ExtCtx.ports`); `recovery.ail:12-18` (`should_retry_stream_error`, no time dimension). The v0.30.0
cite is exact: `std/ai.ail:330-337` in the release tree is `export func stepWithStream(` through
`_ai_step_with_stream(...)`, with `on_chunk: (StreamChunk) -> () ! {IO}` at 335. The only anchor I
would call imprecise is `scripted_ports.ail:20-65`, which stops one line inside
`scripted_clock_next`; not worth a finding. `ADR:124` is the sole row whose *evidence* reproduces
while its *premise* fails (R1).

**Other claims confirmed by execution or reading.** `Ports.hooks_runtime` has no production consumer
— every occurrence is the declaration and builder (`ports.ail:23,38,46`), a test shape probe
(`stub_step.ail:144,154,167`), or a DST script (`scripts/dst/long_qwen_compaction_dst.ail:186,257`);
its disposition in `ADR:230-232` is a real architectural ruling (it cannot be the world-state
carrier) with only the housekeeping choice deferred, which I read as adequate. D4's HEAD claims hold:
the retry loop is count/budget based (`recovery.ail:17-18`), session `now()` calls derive ids and
durations (`session.ail:788,839,1990,2089`), and MCP/context-mode timeouts are real OS mechanisms
that cannot inherit a virtual clock (`exec.ail:45-61` builds `timeout "${secs}s"` into a bash
script). D6.2's premise is right: `finish_reason_str(r: int)` at `session.ail:817` with
`finish_code: int` at `:835` is the integer-code helper that must be replaced. The
mapping-to-007-pillars table (`ADR:686-696`) holds row by row except row 4 (R5). The rejection of
splitting this ADR (`ADR:775-780`) survives attack: D2/D8 share the program identity, D3/D4 share
deadline derivation, D5/D7 share what invariants may observe, and D1 is upstream of all of them —
the only decision with an independent contract is D11's CI budget policy, which is small enough that
extracting it would cost more than it clarifies.

## Recommended pre-acceptance actions

Ordered by dependency. Items 1–4 are this ADR's to fix before acceptance; 5–7 are body edits that can
land in the same pass; item 8 is not this ADR's to clear.

1. **Resolve R1 first — it changes D4, the acceptance test, and the migration order.** Decide between
   the world-clock-only route (recommended: no upstream dependency, and D1 already declares the
   explicit clock authoritative) and a second upstream blocker. Everything else in D4 and
   acceptance row 5 follows from that choice.
2. **R2 — complete the amendment of 004** before an implementer can act on either document, and
   dispose of 004's Phase-B byte-parity test explicitly.
3. **R3 — settle the wire-vocabulary axis** with accepted 007, since 007 cannot be edited to route it
   elsewhere without reopening an accepted decision. R7's classification folds into whatever surface
   this creates.
4. **R4 — restate D6.4 as parity.** One clause, and it unblocks a gate a correct implementation would
   otherwise fail.
5. **R5, R6, R8, R9** — four bounded edits to D3, D11, D2/D8, and the mapping table.
6. Re-ground `ADR:90-91` and `ADR:124` on executed results, and add the R1 probe to `spike/` so the
   clock claim is defended the same way the streaming claim is.
7. Update the Status line to reflect however many upstream prerequisites survive item 1.
8. **The recorded-stream API remains open and is not mine to clear.** It is unlanded on v0.26.0,
   v0.30.0, and committed `dev` `24120ade2`; the working prototype is uncommitted local changes. D1's
   condition is that the API *land* and the toolchain be *repinned* — a prototype does not satisfy
   it, and `spike/README.md` correctly refuses to claim otherwise.

Belonging to the implementation plan rather than to this ADR: the `ToolDispatchOutcome` and
`tool_phase` emit-callback rework (R7's grounding sizes it), the `motoko-ext-abi` major, the
`ledger_emit`/`ledger_append` pairing audit, and the concrete `DeterministicTestWorld`/`AilangWorld`
naming choice that `NOTE-ailang-world-overlap.md:180-193` defers.

## Accept / revise recommendation

**Revise, then accept.** The architecture is sound and D1 — the keystone — is genuinely threadable
through the real driver; nothing here calls for a redesign. But R1 removes a mechanism D4 is built on
and that the acceptance test requires, R2 leaves a contradictory normative answer live in an ADR this
one claims to amend, and R3 is an unmet obligation to a decision that is already Accepted. Those
three plus R4 should land in the body before acceptance; R5–R9 are bounded edits that can ride along.
The upstream recorded-stream API stays exactly where the ADR puts it — open, external, and blocking
production migration — and R1 should be resolved so it does not silently become a second one.

**Residual risk, recorded as the handoff anticipated.** The migration is under-estimated in a way the
ADR's own warning does not quite cover: R1 means the clock seam must be routed *completely* rather
than incrementally, which moves work from Track 2 into Track 1 and removes the safety net that made a
partial port safe. And the D9 staleness risk is real but well-guarded — the tripwire is stated in
three places and matches 007's wording, so the likelier silent invalidation is not a concurrency
feature but a new `LedgerEvent` variant landing with a wire name in a trailing comment and no
classification, which is precisely what R3 and R7 exist to prevent.

## Review Comments

_Reviewer: Codex (model: `GPT-5`), 2026-07-26. Independent review for acceptance._

_Revision used: HEAD `d894638375471ced85c3bc0477975489b08c041b` (branch
`arniwesth/mot-43-l1-seeded-families`). The ADR is grounded at `7b9b4a4c`; the exact command
`git diff --stat 7b9b4a4c..HEAD -- src packages scripts Makefile .github` produced no output, and
`git diff --name-only -- src packages scripts Makefile .github` also produced no output. Source is
therefore unchanged both since the ADR's grounding revision and in the worktree. Toolchains
executed: pinned AILANG v0.26.0 (`3b52a24d24431c372ed5605289ef039592209514`) and the local
prototype at `/home/motoko/src/ailang`, committed `dev`
`24120ade2ade3560af35e45fddd496fb1901c836` plus uncommitted changes._

### R1. D4 and its Context anchor rest on a false executable claim: `--virtual-time` does not virtualize `std/clock`

**Defect:** On every activation path tested, `std/clock.now()` returned a real epoch and
`std/clock.sleep()` consumed wall time, so D4's runtime mirror, residual-read safety net,
conformance assertion, and acceptance row 5 cannot be implemented as written.

**Grounding:** I checked a probe whose body is `t0 = now(); sleep(200); t1 = now(); sleep(100);
t2 = now()`:

```text
$ TIMEFORMAT='wall=%R'; time env -u AILANG_SEED ailang run --virtual-time --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078295805 t1=1785078296006 t2=1785078296106 d1=201 d2=100
wall=0.406

$ time env -u AILANG_SEED ailang run --seed 42 --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078296177 t1=1785078296378 t2=1785078296479 d1=201 d2=101
wall=0.373

$ time env -u AILANG_SEED ailang run --virtual-time --seed 42 --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078296534 t1=1785078296735 t2=1785078296835 d1=201 d2=100
wall=0.351

$ time env AILANG_SEED=42 ailang run --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078296882 t1=1785078297083 t2=1785078297184 d1=201 d2=101
wall=0.351
```

The local prototype behaves the same:

```text
$ /home/motoko/src/ailang/bin/ailang run --virtual-time --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078302670 t1=1785078302871 t2=1785078302971 d1=201 d2=100
wall=0.642
```

The ADR's cited command itself reproduces:

```text
$ ailang run --virtual-time --caps IO --no-print scripts/smoke_ports_record.ail
⏰ Virtual time enabled
[fake] fake drive: t=1234567890 home=(unset)
[fake] emit-only path ok
[fake] scripted: 7, 11, -1
```

That proves only that the flag parses and prints a banner. The prototype source confirms the
disconnect: `/home/motoko/src/ailang/cmd/ailang/main_run_exec.go:184-189` only prints `seed` and
`virtualTime`; the clock implementation selects virtual behavior through `ctx.Env.Seed != 0`
(`/home/motoko/src/ailang/internal/effects/clock.go:46-53,95-104`), and the executed environment
path did not activate it. The load-bearing false claims are `ADR:89-91`, `ADR:124`, D4
`ADR:401-411`, and acceptance row 5 at `ADR:709`.

**Action:** Make the explicit `world_state` clock the only deterministic clock: delete the runtime
mirror, `--virtual-time`, fixed-runtime-epoch, checked-delta, reset, and residual-read-safety
requirements; require every in-profile `std/clock` read to be routed before conformance and enforce
that with the D5 audit plus a no-`Clock` execution capability. Rewrite acceptance row 5 to test the
explicit clock. If the runtime mirror is retained, name a working pinned runtime as a second
upstream blocker and prove it with this behavioral probe rather than the banner.

### R2. D5's capability poison and D6's typed forbidden-effect result have no compatible mechanism on the pinned runtime

**Defect:** A raw ambient-effect bypass denied by AILANG capabilities terminates evaluation instead
of returning a typed value, while D6 and acceptance row 8 require that same forbidden effect to
return `HarnessFailure` with the driver's partial immutable trace.

**Grounding:** D5 requires direct ambient effects to fail the hermeticity probe and combines
capabilities with bypass poison probes (`ADR:474-501`); D6 says a forbidden effect after execution
begins is a typed `HarnessFailure` containing `partial_ledger_trace` (`ADR:528-534,554-556`), and
acceptance row 8 requires deliberate forbidden-effect probes to return that value (`ADR:712`).
The spike already contains a direct capability poison:

```text
$ cd .agent/projects/009_motoko_dst_execution/spike
$ ailang run --caps IO --entry main_scoped stream_capture_probe.ail
Error: execution failed: effect 'SharedMem' requires capability, but none provided
Hint: Run with --caps SharedMem
$ echo $?
1
```

No AILANG `Result`, `HarnessFailure`, or returned partial trace crosses that process failure. An
outer wrapper cannot reconstruct the authoritative immutable trace from `ledger_emit`, because D6
correctly says the returned trace—not external projection—is authoritative (`ADR:548-551`).

**Action:** Separate two cases in D5/D6 and the gate: profile-routing/exclusion violations detected
inside the runner may return typed `HarnessFailure`; a raw capability-bypass poison may be an
expected non-zero evaluator failure but cannot promise a returned partial trace. If both must return
the same typed value, name and substrate-prove an effect-interposition/trapping mechanism that
preserves the driver-owned partial trace before acceptance.

### R3. D2 cannot record one of the external-effect classes D1, D3, and D5 require it to replay

**Defect:** `ExecutionProgram.Interaction` has no extension-effect or process interaction even
though conformant extension-side process effects are part of the authoritative world and required
fault surface.

**Grounding:** D1 includes “conformant extension-side external effects” in the request surface
(`ADR:205-213`); D3 requires the corresponding “provider/tool/process failure” for an effectful hook
(`ADR:366`); and D5 permits effectful hooks only through world-mediated ports (`ADR:463-468`).
But D2's exhaustive conceptual interaction list is only `ExpectProvider`, `ExpectTool`,
`ExpectApproval`, `EnvironmentRead`, `RuntimeRandomDraw`, and `AdvanceClock`
(`ADR:291-298`). The current ABI makes the missing case concrete:
`packages/motoko-ext-abi/types.ail:62-66` contains a distinct
`proc_exec: (string, string) -> string`; it is not a typed tool-call envelope.

**Action:** Add a typed `ExpectProcess`/`ExpectExtensionEffect` interaction with origin, causal
identity, bounded request projection, deadline/timing, typed result, and state transition; or state
normatively that extension `proc_exec` is represented by `ExpectTool` and give the conversion and
identity rules. Ensure D3 process failures and D11 coverage use the same stable class id.

### R4. The amendment of 004 leaves an impossible, contradictory streaming mechanism normative

**Defect:** 004 still requires the live chunk callback to append through a driver-issued ledger
handle while this ADR requires a returned emission log precisely because callback-side append
effects cannot fit the real API.

**Grounding:** `../004_phase_core_refactor/ADR-001-phase-oriented-core.md:152-159` calls the append
handle the “Normative resolution” and requires a Phase-B byte-parity test. This ADR's amendment
metadata (`ADR:22-26`) does not name or supersede that mechanism, while D1 appends only after the
provider call returns (`ADR:154-161`). A direct probe using a
`(StreamChunk) -> () ! {IO, Trace}` callback confirms the handle cannot be passed:

```text
$ ailang check /tmp/motoko_adr_trace_callback.ail
Error: ... failed to unify parameter 4: failed to unify effect rows:
  incompatible closed rows: r1 has extra labels [], r2 has extra labels [Trace]
```

The existing `SharedMem` negative probe independently fails for the same closed-row reason.

**Action:** Add 004's stream-delta append-handle resolution to the explicit amendment list and say
that D1's returned ordered emission log replaces it. Retain and relocate 004's
`thinking_stream_start → N×delta → thinking_stream_end` byte/order parity test to the returned-log
path.

### R5. The wire vocabulary delegated by accepted 007 is absent from D5, D8, and D11

**Defect:** Accepted 007 makes the ledger-to-TUI wire vocabulary a maintained compatibility surface
owned here, but this ADR versions neither its encoding nor its migration/compatibility policy.

**Grounding:** Accepted 007 records the `LedgerEvent`/wire mapping and TUI consumer at
`../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md:310-337`, then assigns its
encoding, migration mechanism, and compatibility policy to this ADR's D5/D8/D11. D5's manifest
fields (`ADR:456-461`) omit it, D8's compatibility policy is for execution programs
(`ADR:612-631`), and D11 contains search policy. At HEAD:

```text
$ sed -n '598,631p' src/core/phase_vocab.ail | rg -c '^  [=|]'
34
$ sed -n '598,631p' src/core/phase_vocab.ail | rg -c -- '--'
34
```

All 34 wire names live in comments, with `StreamDelta` mapping to two names
(`src/core/phase_vocab.ail:597-631`). The separate-process consumer is also not validating the
contract: `src/tui/src/runtime-process.ts:103-112` accepts any string-valued `type` and casts the
object to `AgentEvent`; its union at `:56-101` contains only a subset of ledger variants.

**Action:** Define a versioned event-vocabulary artifact that derives or validates
`LedgerEvent variant ↔ wire name ↔ payload schema ↔ TUI consumer`, record its version in the
profile/manifest and replay artifact, and give it an explicit compatibility/migration rule.

### R6. D6.4 contradicts D1 for stream chunks and would fail a conformant implementation

**Defect:** D6.4 requires projection and trace append to occur in the same transition, but D1
requires live projection during the callback and trace append after the provider call returns.

**Grounding:** Compare `ADR:548-551` with `ADR:154-161`. The direct `{IO, Trace}` callback probe in
R4 fails, so the two operations cannot share a callback transition. The world slice says the same
thing explicitly at `spike/README.md:183-188`: stream projection and append are necessarily
separate and must be checked by parity.

**Action:** Make D6.4 a parity obligation. Require one shared append+project transition where the
substrate permits it, but name stream emissions as the required exception and enforce exact
ordered/no-duplicate parity between the callback projection and returned emission log.

### R7. The fault-to-production-branch gate has no machine-readable map or branch evidence

**Defect:** Acceptance row 4 requires every fault class to reach its mapped production branch, but
D3 delegates the map to prose in an implementation plan and D11 reports only fault-class counters.

**Grounding:** D3 says the implementation plan must map classes and name branches
(`ADR:368-370`); D11 reports “fault classes reached” and terminal reasons, not recovery branches
(`ADR:674-680`); the mapping table nevertheless claims D3 already maps the catalogue
(`ADR:693`); and acceptance row 4 requires the missing evidence (`ADR:708`). The catalogue also uses
open labels such as “protocol-inconsistent typed result” and “corresponding ... process failure,”
so stable sub-class ids are necessary before “every required fault class” is enumerable. Accepted
007 now points to D3 as the normative minimum
(`../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md:189-191`).

**Action:** Require one versioned machine-readable fault catalogue containing stable class id,
applicability condition, production result/error constructor, named recovery-branch id, and
logical-state transition. Make D11 report both class-reached and branch-reached counters from that
artifact, and correct the mapping-table wording from “mapped” to “requires a checked map” until it
exists.

### R8. The promoted reproduction unit omits the manifest under which D8 promises reproduction

**Defect:** D2/D11 call the serialized program the authoritative promoted artifact, while strict
reproduction is conditioned on an execution manifest that is not part of that program.

**Grounding:** `ExecutionProgram` contains schema/generator/seed/initial-world/interactions but no
manifest (`ADR:282-289`); D2 calls that serialized program authoritative (`ADR:336-338`); D8
promises reproduction only under the recorded manifest/profile (`ADR:620-625`); and D11 promotes
the exact program to the fixed corpus (`ADR:679-680`). D8's failure report separately lists the
manifest (`ADR:595-607`), but nothing requires the promoted corpus member to retain or resolve that
sidecar.

**Action:** Define the reproduction artifact as an envelope containing the exact program and
normalized execution manifest, or require a content-addressed manifest sidecar in the program
validator. Specify fail-closed strict replay when the pinned manifest is unavailable and
compatibility-aware regression replay when a newer manifest is deliberately substituted.

### R9. The logical-versus-display-only event set has no owner, version, or fail-closed validator

**Defect:** D6/D7 quantify trace parity over “logical” events but never define the set, so a reviewer
cannot decide whether a missing returned record is a parity defect or permitted telemetry.

**Grounding:** D6.4 introduces the classification without a home (`ADR:548-553`), and D7 requires
parity over that undefined set (`ADR:569-581`). Current source demonstrates why inference is unsafe:

```text
$ rg -c 'ledger_emit\\(' src/core/session.ail
37
$ rg -c 'ledger_append\\(' src/core/session.ail
14
```

For example, `ThinkingStreamEnd` is emitted at `src/core/session.ail:1769-1770` but omitted from the
trace constructed at `:1778`; `ToolDispatchOutcome` carries neither events nor trace
(`src/core/tool_phase.ail:148-150`) while its callbacks emit unit (`:196,219,297,311`).

**Action:** Put logical/display-only classification in R5's versioned event-vocabulary artifact,
fail profile validation on every unclassified variant, and generate the D7 parity set from it.

### R10. Conditional D3 fault classes can disappear from a passing profile without a recorded waiver

**Defect:** Approval timeout and conformant-extension faults are called part of the minimum
catalogue but are conditional, and neither the profile nor D11 must report that they were waived.

**Grounding:** The approval timeout applies only where production policy enables a deadline, and
the extension class only where the selected profile includes an effectful hook (`ADR:365-366`).
HEAD approval blocks on `readLine()` with no deadline (`src/core/session.ail:1609-1617`), while
`AllowAfterTimeout`/`DenyAfterTimeout` are only policy-default variants
(`src/core/tool_phase.ail:152-156`); D5 allows the baseline to exclude current effectful hooks
(`ADR:474-479`). D11 reports reached classes only (`ADR:674-680`).

**Action:** Require each profile and run report to enumerate every D3 class as required,
inapplicable, or waived, with the exact applicability condition and evidence. The fixed-bank gate
must compare coverage against that declared set.

### R11. D3's physical-fault tripwire is weaker than binding 007 D1.3

**Defect:** This ADR replaces 007's named physical-contract reopen triggers with a generic
“physical faults or durability contract” clause, making the runner-side tripwire easier to miss.

**Grounding:** Accepted 007 requires reopening before “crash-recovery, fsync, WAL,
resume-from-ledger, or replicated-state correctness” is added
(`../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md:175-178`); D3 says only
that physical faults or a changed durability contract require revisiting scope (`ADR:392-393`).
The exact list exists in `NOTE-scope-and-sequence.md:92-96`, but that note is informational project
scope rather than this ADR's execution decision.

**Action:** Copy 007 D1.3's five named triggers into D3 and require the same tripwire beside the
execution runner, matching D9's precise concurrency treatment.

## What is accurate

The following rulings were re-executed or re-read at HEAD `d894638`; they are not inherited from
the author review or the earlier independent review.

**D1 threadability — confirmed.** `C2LoopState` is already one explicit value containing provider
state and `LedgerTrace` (`src/core/session.ail:338-357`) and is passed through `c2_loop`
(`:1509-1524`). `dispatch_step` already returns `result + next_provider`
(`src/core/test/stub_step.ail:180-204`). Approval suspension stores the request in the same state
and recurses (`session.ail:1661-1682`), then resumes inside the driver (`:1609-1634`). The traced
entry point constructs and returns that state in one place (`:1989-2015`). The exact sizing commands
returned 13 `next_state: C2LoopState` literals and 16 `c2_loop(` call sites; invasive is accurate,
but no control-flow rewrite is required merely to add and pass a world field.

The hard seams are real and already budgeted: `ToolDispatchOutcome` returns no successor world
(`src/core/tool_phase.ail:148-150,288-364`), and `ExtensionHooks` returns decisions without a world
token (`packages/motoko-ext-abi/types.ail:151-164`), requiring the D5 ABI change. A sum-valued adapter
dispatch can preserve common request/response and transition code just as `StepProvider` does now;
production policy need not branch on a test flag. The local vertical slice passed both outcomes:

```text
$ AILANG_SRC=/home/motoko/src/ailang AILANG_BIN=/home/motoko/src/ailang/bin/ailang ./run_world_slice.sh
mode=success       ... PASS program_non_empty (emissions=2) ... PASS trace_parity
mode=partial_error ... PASS program_non_empty (emissions=2) ... PASS trace_parity
world_slice: PASS — live and deterministic paths agree on both outcomes
```

That slice validates the API/world-request shape, not threading through the real Motoko driver; the
source audit above supplies the latter ruling. `Ports.hooks_runtime` also has a real disposition:
`rg -n 'hooks_runtime' --glob '*.ail' . --hidden -g '!.git/**' -g '!**/.ailang/**'` found only its
declaration/builders, a test-shape probe, and one DST script—no production read. Requiring a
demonstrated purpose or removal while forbidding it as a state carrier is adequate.

**Single-actor boundary — confirmed.** Tool entries recurse in list order
(`src/core/tool_phase.ail:314-357`), native batches recurse synchronously
(`src/core/tool_runtime.ail:151-165`), MCP execution blocks in `exec("bash", ...)`
(`packages/motoko-ext-mcp/exec.ail:63-70,165-176`), and delegated TUI calls are awaited in a
`for` loop (`src/tui/src/runtime-process.ts:618-642`). No ledger-mutating interleaving was found.
D9's four concurrency triggers match accepted 007 D1.1. Search workers with independent worlds do
not violate this boundary. The residual risk is correctly stated: a future parallel tool,
ledger-sharing subagent, background hook, or state-advancing stream handler invalidates the model.

The physical-fault exclusion also matches current source: the exact
`rg -ni --glob '*.ail' --glob '*.ts' '\\b(fsync|write[- ]ahead|wal|resume[-_ ]from[-_ ]ledger|replicated[-_ ]state)\\b' src packages`
command returned no hits, and restart emits `SessionSuspend` then exits without restoring history
(`src/core/session.ail:2209-2216`). R11 is about preserving the accepted tripwire, not current scope.

**Streaming disposition — confirmed.** On a clean copy of the spike:

```text
$ ailang check probe_state_returning_callback_rejected.ail
exit 1: cannot unify type constructor () with *types.TList
$ ailang check probe_sharedmem_callback_rejected.ail
exit 1: incompatible closed rows: ... extra labels [SharedMem]
$ ailang run --caps AI,IO --ai-stub --entry main probe_real_stream_callback.ail
LIVE content {"kind":"Wait"}
LIVE usage
PASS real_stream_callback stop
```

Both prototype probes pass, including partial-stream-then-error and non-empty program parity:

```text
$ AILANG_SRC=/home/motoko/src/ailang AILANG_BIN=/home/motoko/src/ailang/bin/ailang ./run_integration_probe.sh
integration_probe: PASS — all five D1 properties hold on both outcomes
$ AILANG_SRC=/home/motoko/src/ailang AILANG_BIN=/home/motoko/src/ailang/bin/ailang ./run_world_slice.sh
world_slice: PASS — live and deterministic paths agree on both outcomes
```

The prototype is not the gate:

```text
$ git -C /home/motoko/src/ailang rev-parse HEAD
24120ade2ade3560af35e45fddd496fb1901c836
$ git -C /home/motoko/src/ailang status --short
 M internal/builtins/ai.go
 M internal/builtins/ai_step.go
 M internal/effects/ai_step.go
 M std/ai.ail
?? internal/effects/ai_step_with_stream_recorded_test.go
?? probe_recorded_stream.ail
$ committed_count=$(git -C /home/motoko/src/ailang show HEAD:std/ai.ail | rg -c stepWithStreamRecorded || true)
$ printf 'committed_recorded_count=%s\n' "${committed_count:-0}"
committed_recorded_count=0
```

The committed `dev` signature remains the unit-returning closed `{IO}` API at
`std/ai.ail:330-337`; stock v0.26.0 makes both new probe scripts exit 1 with
`IMP010: symbol 'stepWithStreamRecorded' not exported by 'std/ai'`. The API has not landed and no
toolchain has been repinned, exactly as `spike/README.md:43-47` warns.

Chunk timestamps are not a missing upstream requirement. I executed an independent callback probe:

```text
$ ailang check /tmp/motoko_adr_clock_callback.ail
Error: ... incompatible closed rows: r1 has extra labels [], r2 has extra labels [Clock]
```

D2 discovery nevertheless generates the latency/offset as part of the deterministic provider
outcome (`ADR:260-264,325-332`); replay reads it from the program. A live provider is not D2
discovery and needs arrival order, not virtual timestamps. The “non-decreasing virtual offsets”
clause is reachable without observing wall-clock arrival, so the upstream ask is complete.

**Citation audit — all file anchors resolve, with R1 the one false premise.** Every Context-table
source range at `ADR:113-128` was opened at HEAD. The cited constructs are present: six
function-valued `Ports` fields and stringly tool seam; three separate scripted `result + next`
queues; the success-only `ScriptedStep`; `TracedSessionResult {result, trace}`; direct approval and
clock reads; missing returned summaries; serial tool/MCP/provider paths; empty live-wrapper chunks;
real adapter timeout contracts; broad extension effects and direct bypasses; and count/budget
provider retry. The supplied, previously executed v0.30.0 release result is consistent with the
committed `dev` signature I independently inspected. Only the runtime-clock premise fails despite
its cited banner command succeeding.

Other source-grounded D1-D11 claims also hold: the four direct `now()` sites are
`session.ail:788,839,1990,2089`; MCP/context-mode timeouts are real process mechanisms;
`finish_reason_str(int)` is the current terminal helper (`session.ail:817-867`); current
effectful hooks can bypass `ExtCtx.ports`; and no production consumer of `hooks_runtime` exists.

Accepted 007's four independent reproduction axes are all named here: program schema and generator
version in D2/D8, profile version in D5, and execution manifest in D5/D8. R8 is about binding them
into the promoted unit, and R5 is the separate wire-vocabulary obligation. The mapping table's
pillars 1, 3, and the core of 2/5/6/7 have corresponding decisions; pillar 4 overclaims a completed
branch map (R7), pillar 5's runtime mechanism is false (R1), and pillar 6's trace mechanism needs
R5/R6/R9.

**D5 hermeticity is largely buildable, with the R2 distinction required.** Narrow capabilities can
deny `AI`, `Process`, `Net`, `FS`, `SharedMem`, `Clock`, `Env`, and `Rand`; a complete source/ABI
routing audit handles broad `IO`; fail-closed profile validation can reject unclassified
hooks/adapters before dispatch; and runtime routing can return a typed exclusion failure. A raw
capability poison also proves that a bypass cannot silently succeed. What it cannot prove on this
runtime is D6's stronger claim that the capability failure itself returns the driver's typed
partial trace.

**Acceptance-test application at HEAD.** This exact command returned no hits:

```text
$ rg -n 'ExecutionProgram|DiscoveryConfig|HarnessFailure|SimulationProfile|execution_manifest|profile_version|generator_version|DeterministicWorld|LiveWorld|world_state' src packages scripts Makefile .github
```

All eleven rows therefore return **No** at HEAD, not “unknown”:

| Row | HEAD result | Future mechanical status |
|---|---|---|
| Seed generates execution | No | Decidable after D2 implementation |
| Modeled logical environment | No | Decidable after D1/D2, including R3 |
| Honest tested boundary | No | Decidable from the versioned D5 profile |
| Faults reach recovery | No | Not decidable until R7/R10 |
| Virtual time matters | No | Unsatisfiable as written; R1 |
| Production logic under test | No | Decidable by entrypoint/source evidence |
| Complete oracle | No | Not decidable until R5/R6/R9 |
| Harness failures separate | No | Forbidden-effect case needs R2 |
| Discovery/replay stable | No | Decidable after D2/D8 and R8 binding |
| Hermeticity enforced | No | Decidable after D5, with R2's two failure classes |
| Actual search | No | Decidable after D11, but coverage set needs R7/R10 |

Amendment fidelity otherwise holds. This ADR preserves 001's production-code, explicit-fake,
normalized-display-trace, stable-scenario, and invariant decisions while replacing its definition
and incomplete environment/replay architecture as accepted 007 permits. It preserves 004's pure
decision core, production phase transitions, extension-resident policy, and driver ownership; R4
is the unamended streaming exception, while R5 covers the now-load-bearing wire contract. The
rejection of splitting the ADR also survives: D1 is the common boundary; D2/D8 share replay
identity; D3/D4 share deadline semantics; D5/D7 share oracle visibility; and D11 gates the exact
fault/program artifacts those decisions define. D10 and parts of D11 are independently editable
policy, but extracting them would not remove an architectural ambiguity found here.

## Recommended pre-acceptance actions

This ADR must fix, in dependency order:

1. Resolve R1 first: select the explicit-world-only clock or add a second proven upstream blocker;
   then update Context, D4, D5 migration order, acceptance row 5, and Status consistently.
2. Resolve R2's forbidden-effect semantics so the hermeticity and `HarnessFailure` rows demand
   evidence the pinned substrate can return.
3. Complete the 004 amendment and reconcile D1/D6 streaming transitions (R4/R6), retaining the
   live byte/order/no-duplicate parity test.
4. Complete the program's request surface for extension-side process effects (R3).
5. Define and version the ledger/wire/classification surface delegated by 007 (R5/R9).
6. Make the normative fault catalogue and branch/waiver evidence machine-readable (R7/R10).
7. Bind program and manifest into one promoted reproduction artifact (R8).
8. Copy the binding physical-fault tripwires into D3 (R11), then update the status line to list the
   actual remaining blockers.

The fresh implementation plan, not this ADR, owns the concrete `WorldState` representation; edits
to the 13 `C2LoopState` successor literals and tool-phase return shapes; the extension-ABI major;
complete routing of all four current clock reads; centralized terminal finalization; the concrete
event-vocabulary codec and TUI changes; profile source-audit tooling and poison fixtures; branch
instrumentation; CI seed counts/rotation/retention; and either a demonstrated production purpose
for `Ports.hooks_runtime` or its removal. The migration remains feasible but should be estimated as
a cross-cutting redesign of effect routing and trace returns, not as a small diff.

The recorded-stream API remains an external pre-acceptance blocker: the local prototype proves the
proposed shape, but it has not landed on committed `dev`, no release contains it, and Motoko has not
repinned. Clearing that blocker belongs upstream and is not claimed by this review.

## Accept / revise recommendation

**Revise.** D1 is threadable and the streaming/sequential architecture is sound, but R1 makes D4 and one gate row false, R2/R5/R7 leave required evidence non-mechanical, and R3/R4/R6/R8–R11 require bounded architectural corrections; the unlanded recorded-stream API remains a separate external blocker that this review does not clear.

## Review Comments

_Reviewer: Claude (model: `claude-sonnet-5`), 2026-08-01. Third independent review — verification of
the F1–F6 disposition revision, per
`HANDOFF-review-adr-001-f1-f6-revision.md`. This round adjudicates nothing; it verifies the
authoring side's own disposition of F1–F6._

_Revision reviewed: the working-tree ADR at HEAD `99749c7d29d013adac9e252c982d297ace984ba8`
(branch `arniwesth/mot-44-motoko_dst_execution_primer`), i.e. the F1–F6 revision as staged, unmerged.
Toolchain executed: pinned AILANG v0.26.0 (`3b52a24d24431c372ed5605289ef039592209514`, built
2026-08-01). No upstream or forked toolchain was used; every claim below was checked against the
pinned toolchain and HEAD source only. `git diff --stat 7b9b4a4c..HEAD -- src packages scripts
Makefile .github` was re-run rather than inherited (see anchor ruling below)._

### R1. D5's "reachability-aware, not textual" routing-audit requirement is not shown to be buildable, and the repo's own call-graph tool demonstrates the opposite on the exact case that motivated it

**Defect:** ADR:677-684 requires the hermeticity gate's source/ABI routing audit to be
"reachability-aware, not textual," grounded in F2's finding that a textual audit certifies
`dispatch_step`'s dead `stepWithStream` branch as live. The only reachability infrastructure in this
repo — `tools/code-graph` — does not support the granularity this requirement needs, and in its
default configuration cannot even see the file the defect lived in.

**Grounding:**

```text
$ python3 tools/code-graph/query/cgq.py q callers dispatch_step      # default `core` profile
{"data": [], ..., "rows_returned": 0}
```

`dispatch_step` is defined in `src/core/test/stub_step.ail`, and `tools/code-graph/README.md:29-31`
states the default `core` profile excludes `src/core/test/**` — exactly the directory where
`dispatch_step`, `scripted_ports_from_steps`, and `live_ports` live, despite that code being
production-executed (it is not test code by function, only by path). Re-extracting with
`--include-tests` makes the function visible:

```text
$ tools/code-graph/extract.sh --include-tests
$ python3 tools/code-graph/query/cgq.py q callers dispatch_step
{"data": [{"caller": "src/core/session#c2_loop", "distance": 1}, ... 27 rows], "rows_returned": 27}
```

but this only proves the tool can answer *function-level* reachability, and at HEAD `dispatch_step`
now has exactly one match arm (`89a1d67` deleted the other two), so the branch-level question F2
actually turned on — "is this specific ADT arm of a reachable function reachable" — is no longer
even askable against current source, and the tool has no mechanism for it in general: `invokes.csv`
records function calls, not which constructor of a multi-arm `match` a given caller can produce.
Confirming this isn't a fixable configuration slip: the concrete fix applied to this exact instance
(`89a1d67`, "Make the invariant structural instead of conventional") did not add an audit at all — it
retyped `C2LoopState.provider` from `StepProvider` to `Ports` and deleted the dead arms, turning a
runtime/audit-time invariant into a compile-time fact. The ADR's D5 change doesn't mention that this
is the pattern that actually worked here, and doesn't name what would make "reachability-aware"
implementable for the cases where narrowing isn't available (e.g. `ExtPorts`/`ExtensionHooks`, which
stay broad by ABI necessity).

**Action:** Either narrow D5 to what's demonstrated — prefer type-narrowing/structural invariants
over auditing wherever the dead-arm pattern recurs, reserving "reachability-aware audit" for the
genuinely audit-shaped part of the gate (unrouted ambient effects, not ADT dispatch dead code) — or
specify the analysis precisely enough to be buildable (branch/constructor-level, not function-level;
a profile scope that cannot silently exclude load-bearing code under `src/core/test/**`) before this
becomes a name-adoption gate requirement.

### R2. F4's "14, not 4" recount does not hold at HEAD on the pinned toolchain

**Defect:** D4 (ADR:557-563) and the D5 hermeticity bullet (ADR:685-686) both cite a
profile-reachable clock count of 14, broken down as 4 (`session.ail` driver) + 1
(`conversation_loop_v2`, "above the traced entry") + 1 (`ext/runtime.ail` `test_dummy`) + 8
(`motoko-ext-compose` family). Verified at HEAD on pinned v0.26.0: `session.ail` contains exactly
four `now()` call sites total, not five, and none of them is attributable to a fifth,
`conversation_loop_v2`-specific read.

**Grounding:**

```text
$ grep -n "now()" src/core/session.ail
791:  else "session_${show(now())}"
842:  let now_ms = now();
1991:  let started_at_ms = now();
2089:  let started_at_ms = now();
$ grep -n "^import" src/core/session.ail | grep clock
30:import std/clock (now)
```

`now` has exactly one binding (line 30), so no alias hides a fifth call. `conversation_loop_v2` is
defined at `session.ail:2251-2269`; its body calls only `ported_provider` and
`conversation_loop_v2_with_policy` and contains no `now()` call of its own.
`git show 89a1d67 -- src/core/session.ail | grep -- '-.*now\|-.*Clock'` shows no removed
`now()`/`Clock` line, so the missing fifth read is not a casualty of WI-C13c; it traces to the
spike's modified driver (which "carries the throwaway driver surgery," per
`NOTE-spike-findings-real-driver-vertical.md:8-13`), not to mainline `session.ail`. The other two
rows check out exactly: `ext/runtime.ail:190` is the sole hit, and `motoko-ext-compose` totals 8
(`compose.ail` 6 at lines 362,503,597,651,681,767; `author_tools.ail:101`; `authoring/dispatcher.ail:217`).
True total at HEAD: **13, not 14.**

**Action:** Correct the table to 13 (or locate and cite an actual fifth session-adjacent read if one
exists in the profile-reachable set, rather than `conversation_loop_v2`, which has none). The
qualitative conclusion — far above 4, extension-dominated — is unaffected, but this number is now
written into two decisions (D4, D5) in their second revision and should not carry an unverified
figure forward a third time.

### R3. One of the two Context anchor rows marked "re-grounded 2026-08-01" contains an arithmetic error introduced by this revision

**Defect:** ADR:147 grounds the `RunSummary`-bypass premise at "`src/core/session.ail:1554-1555`,
and the **other six** `emit_run_summary` calls at `1325`, `1704`, `1711`, `1762`" — four line
numbers, labeled six. Three hundred lines later in the same revision, D6.1 (ADR:731) correctly states
"five call sites at `1325`, `1554`, `1704`, `1711`, `1762`" — i.e. four others besides 1554, matching
the four numbers actually listed at line 147, not six.

**Grounding:**

```text
$ grep -n "emit_run_summary(" src/core/session.ail
1325:  let _ = emit_run_summary(...)
1554:          let _ = emit_run_summary(...)
1704:              let _ = emit_run_summary(...)
1711:              let _ = emit_run_summary(...)
1762:                    let _ = emit_run_summary(...)
```

Five sites, confirmed independently. Both the count at line 147 ("six") and the count at line 731
("five call sites") were edited in this same revision pass (both are new text per the diff against
the pre-revision ADR); one is right and one is wrong.

**Action:** Change "six" to "four" at ADR:147 (or restate the row as "five call sites total," without
a subtracted count, to remove the off-by-two arithmetic entirely). More significant than the typo
itself: this is the second miscount surviving in this revision's freshly re-verified numbers (with
R2), both introduced during the very re-grounding pass meant to fix stale ones. Treat "re-grounded
2026-08-01" as a claim to re-verify, not a warrant — it does not yet mean what its label implies.

### R4. D1's generalized port-widening rule is stated as fact but demonstrated for only one of the three ports it's applied to

**Defect:** ADR:260-262 asserts the ordering rule — widen the port before adopting whatever fills it
— is general "because every `Ports` field is a lossy crossing of the same kind." The source note this
draws from (`NOTE-spike-findings-real-driver-vertical.md:219-224`) names `approval_read` and
`clock_now` as instances but hedges: "narrow enough that the loss is invisible today." The ADR drops
that hedge and states the rule as established fact. `model_step`'s lossiness is directly demonstrated
— it takes a multi-fire `on_chunk` callback whose values are discarded one layer above `std/ai`
before the call returns (`stub_step.ail:148-155`, cited at ADR:85). `approval_read` and `clock_now`
have no comparable channel:

**Grounding:** `src/core/ports.ail:17-24`:

```ailang
export type Ports = {
  model_step: (string, [Message], (StreamChunk) -> () ! {IO}) -> Result[StepResult, AIError] ! {AI, IO, Trace},
  approval_read: (ApprovalRequest) -> ApprovalResolution ! {IO},
  clock_now: () -> int ! {Clock},
  ...
}
```

`approval_read` is a plain synchronous request/response; `clock_now` is a plain point-read. Neither
has a callback parameter or any other channel through which an intermediate value could be silently
dropped the way `model_step`'s stream chunks are. No loss analogous to F2's has been observed or
argued for either field — the generalization is asserted, not shown.

**Action:** Scope the rule to ports with a callback/emission channel (currently only `model_step`),
or, if the concern is that a future richer `ApprovalResolution`/`clock_now` could lose timing or
channel metadata, say what would need to be true to establish that for those two fields specifically,
rather than inheriting the conclusion from one unrelated instance.

### R5. D1 states `world_state` is the cursor's sole owner as an absolute, but the sequenced near-term F6 fix necessarily places the cursor somewhere else first, and the ADR doesn't reconcile the two

**Defect:** ADR:183-192 states "`world_state` owns every replay and generator cursor, and it is the
only owner," and separately that "the implementation plan therefore retires `C2LoopState.provider`."
Implementation Handoff item 2 (ADR:1109-1112) sequences the F6 fix — wiring `ScriptedPortsState`'s
already-tested threaded cursor into the scripted provider — ahead of, and independent of,
`world_state`, which does not exist yet and is the rest of the D1 migration. Wiring a threaded cursor
before `world_state` exists means it has to live somewhere in the interim — most plausibly an
explicit field alongside `provider: Ports` on `C2LoopState` — which the ADR's own absolute wording
does not sanction. An implementer who takes "the only owner" literally has nowhere ADR-approved to
put the interim state; one who doesn't risks recreating a second home for the same fact, the pattern
F1 was written to rule out, just with a different pair of homes (`Ports`-closure state vs. an
explicit sibling field).

**Grounding:** `C2LoopState.provider: Ports` at `src/core/session.ail:344` (confirmed retyped by
`89a1d67`, not `StepProvider`); `ScriptedPortsState` is defined and unit-tested in
`src/core/test/scripted_ports.ail` but is not a field of `C2LoopState` today, so item 2 as written
requires adding one.

**Action:** Add one sentence to D1 or to Implementation Handoff item 2 naming the interim home for
the cursor (e.g., "a new explicit field on `C2LoopState`, not a second closure-captured cursor, until
`world_state` subsumes it"), so "the only owner" reads as the end-state invariant it's meant to be
rather than a constraint the very next action item can't literally satisfy.

## What is accurate

**F1 (cursor ownership) — resolved for the concrete defect, with the R5 gap.** The prohibition on
deriving replay position from mutable history (ADR:194-203) is stated by name and matches a
confirmed-still-live defect: `scripted_ports_from_steps` (`src/core/test/stub_step.ail:157-168`)
still derives its index from `assistant_count(msgs) - base_assistant_count` over the compacted
payload, unchanged by `89a1d67`. An implementer following the ADR could not repeat F1's specific
`LiveWorld(StepProvider)` mistake, since that arrangement is now named and excluded. The "sole
owner" framing has the R5 gap for the period before `world_state` exists.

**F2 (port-widening ordering) — resolved, and stronger at HEAD than the text argues.** Re-derived
independently: `Ports.model_step` returns `Result[StepResult, AIError] ! {AI, IO, Trace}`
(`stub_step.ail:149`, `dispatch_step` at `192-199`), structurally incapable of carrying an emission
log. `ported_provider` (`session.ail:695-701`) is invoked at all six current entry-point call sites
(`2015, 2051, 2114, 2137, 2267, 2295`) before any loop starts, exactly as claimed. Since `89a1d67`
this is actually stronger than the ADR states: `C2LoopState.provider` is now typed `Ports` directly,
not `StepProvider`, so the funnel is a compile-time guarantee rather than merely a checkable runtime
invariant — the ADR still argues the weaker, pre-`89a1d67` case. The generalization of this to every
`Ports` field is not equally supported (R4).

**F3 (the Clock backstop is a runtime, not build-time, check) — confirmed by direct, independent
reproduction on the pinned toolchain**, not merely re-read:

```text
$ ailang run --caps IO clock_probe.ail        # {Clock,IO} row, branch not taken
taking non-clock branch
completed with result: 0
$ ailang run --caps IO clock_probe2.ail       # same function, branch taken
Error: execution failed: effect 'Clock' requires capability, but none provided
```

This matches the ADR's corrected framing exactly: the row survives declaration but fails only on
actual invocation.

**F4 (profile-reachable clock count) — does not hold as stated; see R2.** The qualitative conclusion
(far above 4, extension-dominated) survives; the specific "14" and the `conversation_loop_v2` row do
not.

**F5 (event-vocabulary artifact is new construction) — resolved, and the added prohibition has real
teeth, contrary to the concern that it might be inert.** `ledger_record_name`
(`phase_vocab.ail:561-579`) names exactly 3 of the 34 `LedgerEvent` variants (counted directly off
the type at `phase_vocab.ail:596-629`) — the 3-of-34 claim is exact. D7's parity invariant ("parity
between all logical ledger emissions and returned trace records," ADR:821) and acceptance row 7
("all logical ledger emissions appear in the returned trace," ADR:973) both use "logical," which is
precisely the undefined classification F5 says doesn't exist yet — so the prohibition on scheduling
those checks before the artifact exists is not decorative.

**F6 (scripted cursor pins under folding compaction) — confirmed still live at HEAD, correctly
sequenced, not yet fixed.** The `assistant_count`-derivation mechanism is unchanged by `89a1d67`;
Implementation Handoff item 2 correctly treats this as open and dependent on item 1, not as already
resolved.

**The narrowed D1 blocking clause is correctly scoped and does not license starting the migration
before this ADR is accepted.** `Ports.model_step`'s structural incapacity to carry an emission log
(verified above under F2) supports treating the widening as behavior-preserving and
upstream-independent, so carving it out of the streaming-parity gate is sound reasoning, not a
loophole. Implementation Handoff's "work that does not wait for that gate" list (items 1–3,
ADR:1102-1114) is followed immediately by the sentence tying "the plan" to "once this ADR and the
project-007 taxonomy ADR are accepted" (ADR:1116), and the Status line still requires this
independent review plus the unlanded upstream release. Read in isolation, the three-item list risks
being mistaken for permission to start now — a presentational risk worth tightening — but the
surrounding text does not actually grant that; it corrects planner sequencing within the still-gated
eventual plan, not the acceptance gate itself.

**The uncorrected Context anchors spot-checked hold.**
`git diff --stat 7b9b4a4c..HEAD -- src packages scripts Makefile .github` was re-run rather than
inherited and returns `Makefile` (2-line, unrelated CLI-alias change), the new
`scripts/dst/spike_scripted_cursor_probe.ail`, `src/core/session.ail`, and
`src/core/test/stub_step.ail` — confirming no other anchored file moved. Three rows grounded in
untouched files were opened directly and match current source exactly: `src/core/ports.ail:17-24`
(function-valued `Ports`, stringly `tool_exec`); `packages/motoko-ext-abi/types.ail:62-66,151-164`
(function-valued `ExtPorts`/`ExtensionHooks` with broad rows); `src/core/tool_runtime.ail:151-165`
(`run_native_batch_rec`, sequential recursion). The inference that unchanged-file anchors are still
good holds on this sample — but R3 shows that of the two rows the revision *did* touch, only one was
correctly fixed, so the inference should not be extended to the touched rows without checking each.

**The two corrected Context anchors are accurate apart from R3's count.** `readLine()` at
`session.ail:1619` and `now()` at `1991` and `2089` (ADR:146) verified present exactly as cited.

**The upstream status section holds and does not overstate.** `REPLY-546-park-unbounded-drain.md:137`
states, in the project's own posted reply, "None of (a), (b) or (c) changes the `{chunks, outcome}`
type" — the ADR's load-bearing claim (ADR:1196) restates the project's own filed position rather than
inferring it. The section correctly states the tracking issue is open and unmerged, and that no
ship date was promised.

**M2's checkable claims hold.** `packages/motoko-ext-abi/types.ail:7` states verbatim "Bumping
`ExtensionHooks` is a major version of motoko-ext-abi," matching the ADR's citation exactly. One of
the two "latent under-declaration" claims is independently reproducible at HEAD without doing the
repin: `agents_md.ail:106`'s `walk_agents` calls `fileExists(...)` (an `FS` effect) while declaring no
effect row at all — a real, currently-uncaught under-declaration. The 381-edits/71-files/3-widenings
figures are correctly framed throughout as a spike measurement rather than a HEAD-verifiable
certainty, consistent with treating M2 as a measurement to cite rather than re-run.

## Recommended pre-acceptance actions

In dependency order:

1. Fix R2 and R3 — both are numeric corrections to tables/rows already written into D4/D5/Context,
   no architectural change required.
2. Resolve R4: scope "every `Ports` field is a lossy crossing" to what's demonstrated (`model_step`),
   or gather equivalent grounding for `approval_read`/`clock_now` before generalizing the rule to
   them.
3. Resolve R1 before D5's reachability-aware audit is treated as a name-adoption gate requirement:
   either specify the analysis precisely enough to be buildable (branch/constructor-level, scoped to
   include `src/core/test/**`), or replace it with the structural (type-narrowing) approach that is
   the one demonstrated fix for the concrete instance that motivated it.
4. Add the one sentence R5 asks for, naming the interim home for the scripted cursor between now and
   full `world_state` migration.
5. Not this ADR's to clear: the upstream recorded-stream API must still land in a released binary
   before acceptance, per the Implementation Handoff's own unmodified opening paragraph and the
   Upstream status section's own ruling.

Items 1–2 belong to this ADR directly. Item 3 is this ADR's requirement but its resolution may
legitimately defer detail to the implementation plan, provided the plan is told which shape of
analysis to build rather than left to infer "reachability-aware" on its own. Item 4 is a one-sentence
ADR fix. Item 5 is external and unowned by any reviewer.

## Accept / revise recommendation

**Revise.** The F1, F2, F3, F5, and F6 dispositions hold up under independent re-derivation — F2's
case is stronger at HEAD than the text argues, since `89a1d67` already made the invariant structural
rather than conventional. F4's recount needs a numeric fix (R2), compounded by an unrelated
arithmetic slip introduced in the same re-grounding pass (R3) — together these mean this revision's
"re-grounded"/"measured" labels should be re-verified rather than trusted at face value even after a
second pass. D5's new reachability-aware-audit requirement (R1) and D1's generalized port-widening
rule (R4) are new normative claims this round introduces without adequate support and should be
narrowed before acceptance. None of R1–R5 reopens D1's core threadability or the streaming
architecture, and none licenses starting the migration early — the ADR's own gating text still
requires this review plus the upstream release before any of that begins. The upstream
recorded-stream API blocker remains open, unmerged, and is not this review's to clear.

## Review Comments

_Reviewer: Codex (model: `GPT-5`), 2026-08-01. Independent verification of the F1–F6 revision._

_Revision reviewed: working-tree ADR blob
`374d46fbe39ccb77b2fd4a5e71b3dabc0c70f741` before this section was appended, at HEAD
`99749c7d29d013adac9e252c982d297ace984ba8` on branch
`arniwesth/mot-44-motoko_dst_execution_primer`; pinned AILANG v0.26.0
(`3b52a24d24431c372ed5605289ef039592209514`). The file already contained an uncommitted Claude
third-review section when this session began. It was preserved verbatim, so this is necessarily the
fourth `## Review Comments` heading rather than an overwrite of user-owned review history._

### R1. D5's reachability-aware routing audit is not specified as a buildable acceptance gate

**Defect:** Requiring the source/ABI audit to be “reachability-aware, not textual” makes a precise
constructor/branch analysis normative without defining that analysis, its soundness boundary, or a
tool capable of performing it.

**Grounding:** `tools/code-graph/README.md:7-9` calls this repository's call/effect graph a
source-parsed approximation; `:29-33` says the default `core` profile excludes
`src/core/test/**`, although the motivating production seam lives in
`src/core/test/stub_step.ail`. With `--include-tests` already enabled, the executed query was:

```text
$ python3 tools/code-graph/query/cgq.py q callers dispatch_step
... "include_tests": true, "approximate": true ...
... {"caller":"src/core/session#c2_loop","distance":1} ...
... "rows_returned": 27 ...
```

That establishes function-level reachability only. The emitted schema is exactly
`INVOKE_FIELDS = ["from_slug", "to_slug", "resolution", "approximate"]`
(`tools/code-graph/extractor/emit.py:24`), and its parser finds calls with a regex
(`tools/code-graph/extractor/source_parser.py:14,176-199`); it records neither match arm nor
constructor flow. The actual repair for F2 instead made the invariant structural:
`C2LoopState.provider: Ports` (`src/core/session.ail:338-356`) and
`dispatch_step(ports: Ports, ...)` (`src/core/test/stub_step.ail:192-199`) make the deleted
`StepProvider` arms unrepresentable. No reachability audit was built.

**Action:** Make the gate enforceable in one of two ways: prefer structural type narrowing/deletion
where the dead-arm pattern occurs and use a conservative source/ABI inventory for remaining direct
ambient calls, or specify a sound branch/constructor-level analysis, its profile roots (including
production code under `src/core/test/**`), and its fail-closed behavior before naming it as required
acceptance evidence.

### R2. F4's clock disposition reports both the wrong count and spike-only routing as HEAD state

**Defect:** D4 says there are 14 profile-reachable reads and that the four driver reads are routed,
but HEAD has 13 distinct direct `now()` call sites and all four core sites still call ambient
`std/clock.now`.

**Grounding:** Recounted on pinned v0.26.0 with comments excluded:

```text
$ awk '!/^[[:space:]]*--/ && /(^|[^[:alnum:]_])now\(\)/ {n++} END {print n+0}' \
    src/core/session.ail src/core/ext/runtime.ail \
    packages/motoko-ext-compose/compose.ail \
    packages/motoko-ext-compose/author_tools.ail \
    packages/motoko-ext-compose/authoring/dispatcher.ail
13
$ rg 'world_state|WorldState|LiveWorld|DeterministicWorld' src packages scripts --glob '*.ail' | wc -l
0
$ rg '\.clock_now\s*\(' src packages scripts --glob '*.ail' | wc -l
0
```

The 13 sites are four in `src/core/session.ail:791,842,1991,2089`, one at
`src/core/ext/runtime.ail:190`, and eight in `packages/motoko-ext-compose`
(`compose.ail:362,503,597,651,681,767`, `author_tools.ail:101`,
`authoring/dispatcher.ail:217`). `conversation_loop_v2` at
`src/core/session.ail:2251-2269` contains no separate read; `run_v2_with_conversation` calls
`derive_session_id`, which reaches the already-counted site at `:791`. The spike routed the four
driver sites on its throwaway branch, but that surgery is not at HEAD.

**Action:** Change the table to 13 and distinguish source states explicitly: HEAD routes none; the
throwaway spike demonstrated that the four driver sites can be routed; the nine extension-side
sites remain un-routed. Keep the independently confirmed eight-`compose` D5 obligation.

### R3. D1 over-generalizes F2's port-widening rule beyond the only lossy crossing demonstrated

**Defect:** “Every `Ports` field is a lossy crossing of the same kind” is false or undecidable for
the fields to which no richer producer contract or required widened result is named.

**Grounding:** `src/core/ports.ail:17-23` defines six unlike contracts. `model_step` has a multi-fire
chunk callback but returns only `Result[StepResult, AIError]`, so its information loss is concrete.
By contrast, `approval_read` is a synchronous `ApprovalRequest -> ApprovalResolution` and
`clock_now` is `() -> int`; D1 itself preserves those results at ADR:294-295. Neither has an
intermediate channel whose values the port discards, and the revision specifies no widening target
or gate evidence for either. The same blanket sentence also reaches `env_get`, `tool_exec`, and
`hooks_runtime`, even though D1 separately gives only `tool_exec` a named replacement contract and
rejects `hooks_runtime` as a world carrier.

**Action:** Scope “widen before adoption” to `Ports.model_step` and any future port for which a
specific richer producer contract is identified; keep the typed-tool widening as its separately
named decision instead of turning one observed ordering bug into an unenforceable rule over every
field.

### R4. The uncorrected provider-callback Context anchor no longer reaches the implementation it claims to ground

**Defect:** The Context row at ADR:149 still cites `stub_step.ail:175-204` for callback-ordered
provider chunks even though WI-C13c moved both live and scripted provider implementations outside
that range.

**Grounding:** At HEAD, `src/core/test/stub_step.ail:148-154` contains the live closure that passes
`on_chunk` to `stepWithStream`, and `:157-168` contains the scripted closure that calls
`play_chunks` before returning the result. The cited `:175-204` now contains explanatory comments,
the one-arm `dispatch_step` pass-through at `:192-199`, and the start of a constructor helper. At
`7b9b4a4c`, the cited range contained the old `LiveAI`/`Scripted` match arms; `git diff
7b9b4a4c..HEAD -- src/core/test/stub_step.ail` shows those arms were deleted by `89a1d67`.

**Action:** Re-ground that cell on `src/core/test/stub_step.ail:148-168,192-199` (and retain the
upstream API anchor for arrival ordering). The premise remains true; the claimed “remaining anchors
verified unchanged” does not.

### R5. The re-grounded RunSummary Context row miscounts its own citations and omits the direct-return evidence

**Defect:** ADR:147 calls four listed sites “the other six” and does not cite the two terminal
returns that support its claim that other errors return directly.

**Grounding:** The executed inventory is:

```text
$ rg -n 'emit_run_summary\(' src/core/session.ail
833:func emit_run_summary(
1325:  let _ = emit_run_summary(...)
1554:          let _ = emit_run_summary(...)
1704:              let _ = emit_run_summary(...)
1711:              let _ = emit_run_summary(...)
1762:                    let _ = emit_run_summary(...)
```

There are five call sites total, hence four besides `1554`, exactly as D6.1 states at ADR:731-732.
The uncited direct terminal returns are invalid history at `src/core/session.ail:1528-1531` and an
approval-state invariant failure at `:1612-1616`; neither emits a summary.

**Action:** State “five call sites total” and cite the two direct returns separately. Do not derive a
terminal-path count from call-site count; `c2_fail` at `:1301-1327` is one call site shared by
several typed `Fail` reasons.

### R6. The promised Spike-findings disposition section is absent

**Defect:** The revision and its handoff claim a historical `## Spike-findings disposition (F1–F6)`
section exists “below,” but the ADR contains no such section, leaving no author-owned per-finding
disposition record to verify.

**Grounding:** At the pre-review blob:

```text
$ rg '^## Spike-findings disposition \(F1–F6\)$' .agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md | wc -l
0
$ rg '^## Review Comments$' .agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md | wc -l
3
```

ADR:8 nevertheless says “the F1–F6 round below was dispositioned by the authoring side,” and the
handoff names the missing section as input 2. The normative body contains responses to the findings,
but it is not the historical defendant's summary the review was instructed to preserve.

**Action:** The authoring side should add the promised F1–F6 disposition record without rewriting
the independent reviews, or correct the status/handoff if the intentional record is the body alone.

## What is accurate

**F1 — resolved.** The end-state owner is now decidable: `world_state` is the sole cursor owner,
history-derived position is prohibited by name, and `C2LoopState.provider` is explicitly retired.
Keeping `StepProvider` as an entry argument does not prevent this: `Scripted(script)` can seed the
initial world program/cursor without remaining a cursor owner inside the loop. HEAD is openly
identified as non-conformant (`scripted_ports_from_steps` still derives
`assistant_count(msgs) - base_assistant_count` at `stub_step.ail:157-165`), and Implementation
Handoff item 2 sequences the repair. An implementer cannot reproduce the specific
`LiveWorld(StepProvider)` freeze or retain history-derived replay position while complying with D1.

**F2 — resolved for `model_step`, with R3 limited to the unsupported generalization.**
`Ports.model_step` returns only `Result[StepResult, AIError]` (`ports.ail:17-18`), so it cannot carry
an emission log. `ported_provider` returns `Ports` (`session.ail:695-701`), and its six call sites at
`:2015,2051,2114,2137,2267,2295` normalize every `StepProvider` entry before the loop. Since
`89a1d67`, `C2LoopState.provider` is itself `Ports`, making the funnel structural rather than a
convention. Widening this port before adopting the upstream filler is mandatory and correctly
sequenced.

**F3 — resolved and reproduced.** The existing substrate smoke declares `{Clock, Env, IO}` on both
entries. With only `IO`, the fake branch completes while the taken live clock read fails:

```text
$ ailang run --caps IO --entry main scripts/smoke_ports_record.ail
... [fake] scripted: 7, 11, -1
$ ailang run --caps IO --entry main_live scripts/smoke_ports_record.ail
Error: execution failed: effect 'Clock' requires capability, but none provided
main_rc=0 live_rc=1
```

D4's “stronger and weaker” framing is exact: capability denial catches a read on an executed path
but proves nothing about reachable, untaken paths.

**F4 — not resolved as written.** The qualitative conclusion survives: the set is extension-heavy,
the eight `compose` sites are real, and `ExtPorts.clock_now` has zero reads repo-wide. R2 records the
numeric and source-state corrections.

**F5 — resolved.** The executed counts were `LedgerEvent variants=34` and `named variants=3` from
`phase_vocab.ail:597-631` and `ledger_record_name` at `:561-579`. D7's parity invariant at ADR:821
and acceptance row 7 at ADR:973 both quantify over “logical” events, so forbidding those checks
before the classification artifact exists has real scheduling force.

**F6 — resolved at the ADR level and still open in implementation, as the revision says.** The HEAD
probe was re-run on pinned v0.26.0: the control served `[s0,s1,s2,s3,done]`, the folding case served
`[s0,s1,s2,s2,s2,s2,s2,s2,s2,s2,s2,s2]`, ended in step-budget exhaustion, and exited
`probe_rc=1` by design. D1 excludes the mechanism and the handoff makes the probe a future passing
regression rather than claiming HEAD is fixed.

**The narrowed D1 blocking clause is correct and does not authorize migration before acceptance.**
The port widening is upstream-independent, while only the live closure's recorded content and parity
proof need the released API. ADR:1095-1100 still requires the API to land, the repin, and the positive
probe before acceptance; ADR:1116 says the implementation plan is written only once this ADR is
accepted. “Can be widened today” describes dependency order, not present authorization.

**D6.1's zero-RunSummary claim holds at HEAD.** `emit_run_summary` constructs the only production
`RunSummary` in `session.ail` and performs only `ledger_emit` (`:833-870`). The five callers listed
under R5 never append that value; every `ledger_append` site in `session.ail` appends a decision,
stage, or another named wire event. The two direct terminal returns also append no summary. Thus no
terminal path places `RunSummary` in the returned `LedgerTrace`, even though the projection is
visible. The throwaway spike's finalizer is not at HEAD.

**The upstream return-shape ruling holds and the status section does not claim a merge.** Re-read
from upstream's design object rather than inheriting this project's reply:
`git -C ailang show 386cf6d15:design_docs/planned/v0_31_0/m-recorded-stream-api.md` defines
`RecordedStream = {chunks: [StreamChunk], outcome: Result[StepResult, AIError]}` and presents the
parked choices at lines 38-42: (a) land with the drain caveat, (b) add provider cancellation first,
or (c) bound the drain locally. (a) changes documentation, (b) the Go provider interface, and (c)
the recorded operation's local drain; none changes the public record. Current `upstream/dev`
contains the parked design doc but `git -C ailang grep stepWithStreamRecorded upstream/dev -- std
internal cmd examples` returns no source hit, and no released tag contains the design commit. The ADR
correctly says PARKED/open/unmerged and promises no date.

**M2 is accurately framed as a spike measurement.** Current
`packages/motoko-ext-abi/types.ail:7` says “Bumping `ExtensionHooks` is a major version of
motoko-ext-abi.” `git diff 4aaf59f..6382dc8 -- packages/motoko-ext-abi/types.ail` shows the three
semantic widenings: `ExtPorts.ai_step` gains `Trace`, and all four hook rows gain `Rand` and
`Trace`. Consequences labels 381 edits/71 files as “Measured v0.26.0 → v0.31.0”; it does not present
that edit count as a fresh HEAD recount.

**The unchanged-file Context-anchor inference holds; the blanket uncorrected-anchor claim does
not.** `git diff --name-only 7b9b4a4c..HEAD` over every anchored source file returns only
`src/core/session.ail` and `src/core/test/stub_step.ail`. Spot checks in untouched files still match:
`ports.ail:17-23` is function-valued/stringly, `motoko-ext-abi/types.ail:62-66,151-164` has the
claimed function-valued ABI/broad rows, and `tool_runtime.ail:151-165` is sequential recursion.
Within the changed files, `ScriptedStep` (`stub_step.ail:34-41`) and `TracedSessionResult`
(`session.ail:146-149`) still match, but R4 and R5 mean the revising session's inference does not
cover every uncorrected/touched row.

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. Resolve R1 before D5's hermeticity audit becomes name-adoption evidence: specify a buildable
   analysis or use conservative inventory plus structural invariants.
2. Correct F4 per R2, including both 13-versus-14 and HEAD-versus-spike routing state.
3. Scope D1's port-widening rule to demonstrated contracts (R3).
4. Repair the two Context anchors (R4/R5) and restore or explicitly dispose of the missing
   author-owned F1–F6 disposition record (R6).
5. After those edits, obtain a fresh independent verification; do not treat either appended review
   as clearing revisions it has not seen.

**The implementation plan, after acceptance, owns:** widening `Ports.model_step` first; moving the
scripted cursor into the sole world state and turning the F6 probe green; constructing the event
vocabulary before classification-dependent D7/acceptance checks; routing every in-profile clock
site, including the eight `compose` reads, through the world; and sequencing the measured
toolchain/extension-ABI major rollout. It must not substitute the throwaway spike for any gate.

**External and not this ADR's author or reviewer's to clear:** the recorded-stream API must land in
a released AILANG binary, Motoko must repin to that release, and the direct positive integration
probe must pass before acceptance, exactly as D1 and the handoff require.

## Accept / revise recommendation

**Revise.** F1, F2, F3, F5, F6, D6.1, the narrowed blocker, the upstream return shape, and M2 survive
independent execution/source checks; F4 does not, D5 still names an unspecified static analysis as a
gate, and the anchor/disposition record is incomplete. The upstream API remains parked, unmerged,
unreleased, and is not cleared by this review.

## Review Comments

_Reviewer: Kimi (model: `moonshotai/kimi-k3` via OpenRouter), 2026-08-01. Third independent
verification of the F1–F6 revision, per `HANDOFF-review-adr-001-f1-f6-revision.md`._

_Revision reviewed: the working-tree ADR at HEAD `99749c7d29d013adac9e252c982d297ace984ba8` (branch
`arniwesth/mot-44-motoko_dst_execution_primer`) — i.e. the F1–F6 revision body, which is itself
**uncommitted** (`git diff HEAD --numstat` on this file: 814 insertions, 27 deletions, of which the
last ~597 lines are the two prior 2026-08-01 verification sections). Toolchain executed: pinned
AILANG v0.26.0 (`3b52a24d24431c372ed5605289ef039592209514`, `~/.local/bin/ailang`). Every claim below
was re-run or re-read by me before I compared notes with the two uncommitted 2026-08-01
verifications already in this file; the convergence recorded at the end is therefore independent,
not inherited. This is the fifth `## Review Comments` heading, not the third the handoff's output
contract anticipated — see R8. Nothing above this section was edited._

### R1. F4's clock disposition is wrong three ways at HEAD: the count is 13 not 14, the `conversation_loop_v2` row misattributes the fifth read, and "Only the first row is routed" imports spike-branch state as HEAD state

**Defect:** D4 (ADR:557-568) claims a measured 14 profile-reachable clock reads with a separate
`conversation_loop_v2` row, and asserts "Only the first row is routed" (ADR:566). At HEAD on pinned
v0.26.0 there are 13 distinct `now()` call sites in the named set; `conversation_loop_v2` performs
no read of its own; and **no** row is routed — the routing existed only on the throwaway spike
branch.

**Grounding:** Recounted by me, comments/imports excluded:

```text
$ grep -n 'now()' src/core/session.ail …        → 791, 842, 1991, 2089        (4, driver)
$ grep -n 'now()' src/core/ext/runtime.ail      → 190                         (1, test_dummy)
$ grep -n 'now()' packages/motoko-ext-compose/  → compose.ail: 362,503,597,651,681,767 (6)
                                                  author_tools.ail: 101 (1); authoring/dispatcher.ail: 217 (1)
```

Total: 4+1+8 = **13 distinct sites**. `now` has a single binding in `session.ail`
(`import std/clock (now)`, line 30), so no alias hides a fifth driver read. `conversation_loop_v2`
(`session.ail:2251-2269`) calls only `ported_provider` and `conversation_loop_v2_with_policy` — no
`now()` in its body, and it takes `session_id` as a parameter. The read the spike's own table
attributed to `session.ail:2374 (run_v2_with_conversation)` resolves at HEAD to
`run_v2_with_conversation` calling `derive_session_id()` at `session.ail:2293`, whose fallback
branch is the already-counted site `:791` (`else "session_${show(now())}"`) — a real reachability
path "above the traced entry" but the *same call site*, so the table double-counts it. At HEAD,
`session.ail:2374` is inside `test_millicents_to_usd_fraction`. The spike measured on its own
surgically-modified driver (`NOTE-spike-findings-real-driver-vertical.md:8-13`: "carries the
throwaway driver surgery"), which explains both the line drift and the fifth row. For the
routed-state clause: all four driver sites at HEAD call ambient `std/clock.now` directly
(`derive_session_id` at 791, `emit_run_summary` at 842, `1991`, `2089`); no world clock exists at
HEAD (`rg 'world_state|WorldState|LiveWorld|DeterministicWorld' src packages scripts --glob '*.ail'
→ 0` hits), so "Only the first row is routed" is false at HEAD — it restates the spike table's
"routed through the world" State cell, which described the throwaway branch. Corollary: ADR:568's
"nine of the fourteen" should be "nine of the thirteen". The D5 bullet's "eight clock reads"
(ADR:686) is exact and survives.

**Action:** Correct the table to 13 distinct sites; replace the `conversation_loop_v2` row with the
accurate statement (the M8 entry `run_v2_with_conversation` reaches the already-counted
`derive_session_id` fallback at `:791` above the traced entry); and state the routing status as it
is at HEAD — none routed at HEAD, four demonstrated routable on the throwaway spike, nine
extension-side reads still unrouted. Do not carry a third revision forward with "measured" numbers
that were measured on a different tree.

### R2. D5's "reachability-aware, not textual" audit requirement names a property, not a buildable analysis — and the one fix that actually landed was structural, which the ADR does not say

**Defect:** ADR:677-684 makes a reachability-aware source/ABI routing audit a hermeticity-gate
requirement, motivated by F2's dead-ADT-arm false positive. Nothing in this repo can answer the
branch-level question that motivation turns on, and the ADR neither specifies the analysis nor
mentions that the concrete instance was fixed by type narrowing, not by any audit.

**Grounding:** Executed against the repo's only call-graph infrastructure:

```text
$ python3 tools/code-graph/query/cgq.py q callers dispatch_step
{"data": [{"caller": "src/core/session#c2_loop", "distance": 1}, …], …}
$ sed -n '24p' tools/code-graph/extractor/emit.py
INVOKE_FIELDS = ["from_slug", "to_slug", "resolution", "approximate"]
$ sed -n '14,18p' tools/code-graph/extractor/source_parser.py
DECL_RE / CALL_RE = regex-based extraction
```

Edges are function-to-function only; `ctors.csv` (101 rows) indexes constructor *declarations*
(`slug,module,name,type_slug,source`), not constructor flow, so "can any reachable caller produce
the variant this match arm consumes" is unanswerable from the emitted tables. `tools/code-graph/README.md:7-9`
calls the call graph a "source-parsed approximation" and `:29-31` states the default `core` profile
excludes `src/core/test/**` — the directory containing `dispatch_step`, `scripted_ports_from_steps`,
and `live_ports`, which are production-executed despite the path (the current `.out` happens to be
an `--include-tests` build; the default still excludes them). Meanwhile `89a1d67` repaired the
motivating instance structurally: `C2LoopState.provider: Ports` (`session.ail:344`) and
`dispatch_step(ports: Ports, …)` (`stub_step.ail:192-199`) make the dead arms unrepresentable — a
compile-time invariant, strictly stronger than any audit this gate could plausibly run. The ADR's
F2 grounding paragraph even narrates this deletion but draws no lesson from it.

**Action:** Narrow D5 to what is demonstrably buildable, in order of preference: (1) require the
structural pattern first — dead-arm seams of this class must be made unrepresentable by type
narrowing, as `89a1d67` did, with the audit as backstop rather than primary; (2) for the residual
ambient-effect inventory, name the actual analysis (a function-level, conservatively
over-approximate call graph with a profile scope that explicitly includes production code under
`src/core/test/**`, plus fail-closed manual triage of its false positives — noting that for a
*hermeticity* audit over-approximation fails closed, which the F2 case did not); or (3) if
constructor-level reachability is genuinely required, specify it (analysis, soundness boundary,
profile roots, fail-closed behavior) before it becomes name-adoption gate evidence. As written the
gate demands a detector no one has built or specified.

### R3. The revision header's "the rest verified unchanged" is falsified by one uncorrected Context row in the touched files: `stub_step.ail:175-204` no longer grounds "provider chunks are callback-ordered"

**Defect:** The header (ADR:14-16) claims the five Context rows anchoring into the two files changed
by `89a1d67` were re-checked, two corrected, and "the rest verified unchanged". Context row ADR:149
cites `src/core/test/stub_step.ail:175-204` for callback-ordered provider chunks; at HEAD that range
contains only comment text and the one-arm `dispatch_step` pass-through — the constructs that ground
the premise moved.

**Grounding:**

```text
$ grep -n 'func play_chunks\|stepWithStream(model\|export func dispatch_step' src/core/test/stub_step.ail
88:func play_chunks(chunks, on_chunk: (StreamChunk) -> () ! {IO, Trace}) …
152:      stepWithStream(model, msgs, tools_with_extensions(rt), system_prompt_cache_breakpoint(), on_chunk)
192:export func dispatch_step(
```

The live streaming call is at `:152`, the scripted chunk playback at `:88-99`, the scripted closure
at `:157-165` — all outside the cited `:175-204`. Worse, the cited range's own comment block is now
internally contradictory: `:171-173` still says dispatch "Returns both the step result and the
updated provider (tail of script for Scripted)" and that "Loop callers thread next_provider", while
`:191` in the same block says "There is no `next_provider` to return" — the stale half describes the
pre-`89a1d67` signature the commit deleted. The premise remains true (both closures fire `on_chunk`
serially), but the row as cited grounds it in a comment that also asserts a false return shape, and
the header's blanket claim does not survive contact with this row. `git diff --stat 7b9b4a4c..HEAD
-- src packages scripts Makefile .github` re-run by me returns exactly `Makefile` (2-line CLI-alias
change), the new `scripts/dst/spike_scripted_cursor_probe.ail`, `src/core/session.ail`, and
`src/core/test/stub_step.ail` — so no *other* anchored file moved, and the two prior reviews'
certification covers rows in untouched files; the gap is confined to this one row inside the changed
set.

**Action:** Re-ground the row on `src/core/test/stub_step.ail:88-99,148-165,192-199`; correct the
header claim (or re-verify the remaining touched-file rows individually and say which); and delete
the stale `next_provider` comment half in `stub_step.ail` as part of the same fix (source edit,
noted here because the ADR anchors into it).

### R4. The re-grounded RunSummary Context row labels four line numbers "the other six"

**Defect:** ADR:147 reads "`src/core/session.ail:1554-1555`, and the **other six** `emit_run_summary`
calls at `1325`, `1704`, `1711`, `1762`" — four numbers, labeled six; D6.1 (ADR:731-732) correctly
says five call sites in the same revision.

**Grounding:**

```text
$ grep -n 'emit_run_summary(' src/core/session.ail
833 (defn); call sites: 1325, 1554, 1704, 1711, 1762 — five total, four besides 1554
```

Both counts were introduced in this same re-grounding pass; one is right (D6.1) and one is wrong
(Context). Two further nits in the same row: "other errors return directly" is grounded by the
InvalidHistory return at `session.ail:1528-1530` and the approval-invariant return at `:1612-1615`,
neither of which the row cites; and the note's original "seven terminal returns" was never a
call-site count — `git grep -c emit_run_summary 4aaf59f -- src/core/session.ail` shows the same five
call sites pre-`89a1d67` — so the correction to citing sites is right, and the original number is a
live example of why spike numbers must be re-run, exactly as the handoff warned.

**Action:** Restate as "five call sites total" (or "the other four"), and cite the two direct
terminal returns for the second clause.

### R5. D1's "every `Ports` field is a lossy crossing of the same kind" is demonstrated for exactly one field

**Defect:** ADR:260-262 states the general rule — widen the port before adopting whatever fills it
— as established fact "because every `Ports` field is a lossy crossing of the same kind". The
source note hedges (`approval_read`/`clock_now` are "narrow enough that the loss is invisible
today"); the ADR drops the hedge. Only `model_step` has a demonstrated loss channel.

**Grounding:** `src/core/ports.ail:17-24`: `model_step` takes a multi-fire
`(StreamChunk) -> () ! {IO}` callback whose values the returning closure discards
(`stub_step.ail:148-155`) — the F2 loss, directly demonstrated. `approval_read:
(ApprovalRequest) -> ApprovalResolution ! {IO}` is a synchronous request/response with no
intermediate channel; `clock_now: () -> int ! {Clock}` is a point read; neither has anything
analogous to a dropped emission log. The ADR's own D1 bullets preserve those two result types
unchanged (ADR:294-295: "approval remains a typed `ApprovalResolution`", "clock reads return the
current world time"), so the rule as stated would mandate widenings the same decision neither names
nor justifies.

**Action:** Scope the rule to ports with a demonstrated loss channel (today: `model_step`; the
stringly `tool_exec` has its own separately-named typed-envelope widening), or state what evidence
would establish lossiness for `approval_read`/`clock_now` specifically. Keep "widen before adopting"
for `model_step` — that case is proven and the sequencing is correct.

### R6. "The only owner" is stated as an absolute, but the ADR's own handoff item 2 must house the scripted cursor somewhere else first

**Defect:** ADR:183-191 makes `world_state` the sole cursor owner and retires
`C2LoopState.provider`, while Implementation Handoff item 2 (ADR:1109-1112) sequences the F6 fix —
a threaded scripted cursor — ahead of, and independent of, `world_state`, which does not exist yet.
The interim home for that cursor is unnamed, so the next implementation action cannot literally
comply with the absolute wording.

**Grounding:** `C2LoopState.provider: Ports` at `session.ail:344` (immutable record value);
`ScriptedPortsState` (`src/core/test/scripted_ports.ail:20-65`) is unit-tested
(`test_scripted_model_threads_state`) but consumed nowhere — `run_v2_with_scripted_ports`
(`scripted_ports.ail:99`) still routes through `scripted_ports_from_steps`. Item 2's own mechanism
("once `model_step` returns a record it can return next-state too") implies the driver must store
that successor somewhere — a new explicit field on `C2LoopState` or a replaced provider value —
which is a second, non-`world_state` home for the cursor by construction.

**Action:** Add one sentence to D1 or to handoff item 2 naming the interim home (e.g. an explicit
`C2LoopState` field until `world_state` subsumes it), so "the only owner" reads as the end-state
invariant it is meant to be.

### R7. The `## Spike-findings disposition (F1–F6)` section the revision and handoff both reference does not exist

**Defect:** ADR:8 says "the F1–F6 round below was dispositioned by the authoring side", and the
handoff names the disposition section as review input 2 and as a historical record not to be
edited; no such section exists in the committed blob or the working tree.

**Grounding:**

```text
$ grep -c '^## Spike-findings disposition' ADR-001-….md   → 0 (working tree)
$ git show HEAD:…ADR-001….md | grep -c 'Spike-findings disposition' → 0 (committed blob)
$ grep -c '^## Review Comments' ADR-001-….md              → 5 (working tree, incl. this section)
```

The normative body does carry per-finding responses, but the author-owned defendant's summary the
review process was built around is absent.

**Action:** The authoring side adds the disposition record (without touching any review section),
or corrects ADR:8 and the handoff to name the body as the record.

### R8. The entire F1–F6 acceptance record is uncommitted, and this handoff has already been executed twice — the output contract's "append a third section" would falsify the record if followed literally

**Defect:** The F1–F6 revision body, the claude-sonnet-5 verification, and the GPT-5 verification
are all uncommitted working-tree content on top of HEAD `99749c7d`; the committed ADR contains none
of it. The handoff describes "two existing review sections" and instructs appending "a third" — two
executions of that same handoff later, this is the fifth `## Review Comments` heading and the third
independent verification of the revision.

**Grounding:**

```text
$ git status --short →  M .agent/…/ADR-001-….md ; M .agent/…/REPLY-546-….md ; ?? HANDOFF-review-…md
$ git show HEAD:…ADR-001….md | grep -c '^## Review Comments' → 2
$ git diff HEAD --numstat — ADR: 814 insertions / 27 deletions across Status, Context, D1, D4, D5,
  D6, Consequences, the new Upstream section, and the two appended verifications
```

Consequences, not complaint: (a) anyone reading the committed ADR sees none of the revision this
round verifies; (b) the Status line's "a fresh independent review of this revision is also required"
is currently satisfiable only by uncommitted text; (c) my findings below converge with the two prior
verifications because the defects are real and were re-derived independently — but the record
should show that there *are* three verifications, not one.

**Action:** Commit the revision together with all three verification sections (or deliberately
restart the round); do not squash, reorder, or "correct" the prior sections — they are historical
records. Any body edit made in response to R1–R7 post-dates all three verifications and needs a
fresh delta review, not a fourth full round.

## What is accurate

Re-run or re-read by me at HEAD `99749c7d` + working-tree revision, on pinned v0.26.0. The three
requested rulings first.

**Ruling 1 — per-finding dispositions.** **F1: resolved.** `world_state` as sole cursor owner plus
the by-name prohibition on history-derived position (ADR:183-203) excludes the failing arrangement
by mechanism, not merely by naming it: an adapter holding the cursor violates "sole owner"
regardless of how explicitly it threads state. HEAD is openly named non-conformant ("the arrangement
that currently executes … a confirmed defect in the harness today (F6)"), the transition is
sequenced (handoff items 1-2), and "the implementation plan therefore retires
`C2LoopState.provider`" (ADR:191) is a ruling, not a deferral. `Scripted(script)` remaining the
entry-point argument (`scripts/dst/phase_c2_wiring_scenarios.ail:120,126,184`) does not undermine
this — `ported_provider` (`session.ail:695-701`) already normalizes it before loop state exists.
Caveat: R6's interim-home gap. **F2: resolved for `model_step`.** `Ports.model_step` returns
`Result[StepResult, AIError] ! {AI, IO, Trace}` (`ports.ail:17-18`) and structurally cannot carry an
emission log; `ported_provider` is invoked at all six entry-point sites
(`session.ail:2015,2051,2114,2137,2267,2295`) before any loop starts; since `89a1d67` the funnel is
a compile-time fact (`C2LoopState.provider: Ports`), stronger than the ADR's checkable-invariant
argument. The generalization beyond `model_step` is R5. **F3: resolved, exactly.** Re-ran both
probes on pinned v0.26.0 — synthetic: a `{Clock, IO}` function taking the non-clock branch
completes under `--caps IO` (rc=0), the clock branch dies `effect 'Clock' requires capability`
(rc=1); real driver: `scripts/smoke_ports_record.ail` `main` rc=0 vs `main_live` rc=1 with the same
error. "Stronger and weaker" is the correct framing and D4 does not under-claim.
**F4: not resolved as written — R1.** The qualitative conclusion (extension-dominated, 8-of-13 in
`compose`, default-profile reachable via `handle_compose_tool`) survives; the number, the
attribution, and the routed-state clause do not. `ExtPorts.clock_now` has zero invocation sites
repo-wide (`.clock_now(` → no matches; constructions only), so the D5 conformance condition is
load-bearing and correct. **F5: resolved, with real teeth.** Counted directly:
`ledger_record_name` (`phase_vocab.ail:561-579`) names 3 of the 34 `LedgerEvent` variants
(`:596-630`, all 34 wire names in trailing comments, `StreamDelta` mapping to two) and collapses 31
to `"wire"`. D7's parity invariant (ADR:821) and acceptance row 7 (ADR:973) both quantify over
"logical" emissions — the undefined classification — so the prohibition on scheduling those checks
before the artifact exists is not inert. **F6: resolved at the ADR level, live in code as stated.**
Re-ran `scripts/dst/spike_scripted_cursor_probe.ail` at HEAD on pinned v0.26.0: control
`served=[s0,s1,s2,s3,done]` advancing=true; folding `served=[s0,s1,s2,s2,s2,s2,s2,s2,s2,s2,s2,s2]`,
`assistants_out` pinned at 2 while `segment_in` grows to 23, death by step-budget exhaustion, rc=1
by design. The ADR correctly treats it as open and sequenced, not fixed.

**Ruling 2 — the narrowed blocking clause is correct and opens no hole.** The port widening is
upstream-independent (a record-field addition testable against `Scripted` providers), and what
remains gated is exactly the live closure's recorded content plus the parity proof. The narrowing
does not license pre-acceptance migration: the Status block (ADR:5-8) still names the upstream
release and an independent review as the acceptance blockers, and the handoff binds the
implementation plan to "once this ADR and the project-007 taxonomy ADR are accepted" (ADR:1116).
"Can be widened today" describes dependency order inside that plan, not present authorization. The
one presentational risk — the three-item "work that does not wait" list readable in isolation as
permission — is covered by the immediately following gating sentence; acceptable as written.

**Ruling 3 — the uncorrected Context anchors hold in untouched files; the header's blanket claim
does not hold inside the two changed files.** Re-ran the diff myself (four files: `Makefile`,
probe, `session.ail`, `stub_step.ail`). Spot-checked ten rows in untouched files, all exact:
`ports.ail:17-24` (six function-valued fields, stringly `tool_exec`); `scripted_ports.ail:20-65`;
`tool_runtime.ail:151-165`; `tool_phase.ail:302-357`; `motoko-ext-mcp/exec.ail:63-70,165-176`;
`ai_compat.ail:31-37,60-71,197-220` (`chunks: []` on both arms); `motoko-ext-abi/types.ail:62-66,151-164`;
`motoko_scratchpad/scratchpad.ail:90-101` (direct `{Net}`); `recovery.ail:12-18` (count/budget
retry); `phase_vocab.ail:557,561,596-630`. Inside the changed files: `ScriptedStep`
(`stub_step.ail:34-41`) and `TracedSessionResult` (`session.ail:146-149`) still exact; the two
corrected rows are right apart from R4's arithmetic (`readLine()` at `session.ail:1619`; `now()` at
`1991`,`2089`; the five `emit_run_summary` sites); and R3's row is stale. The inference the handoff
asked about — prior certification covers unchanged-file anchors — holds on this sample and is worth
stating as a ruling; it must not be extended to rows inside the two changed files.

**D6.1's zero-`RunSummary` claim holds at HEAD, verified path by path.** `emit_run_summary`
(`session.ail:833-870`) contains exactly one ledger operation, `ledger_emit(session_id,
RunSummary({…}))` at `:857`; `RunSummary` appears nowhere else in `session.ail` but its import, so
no `ledger_append` ever receives one. Five call sites (R4); `1325` is `c2_fail`, the shared
error-return helper reached through the `Fail` decision's several finish codes; the Finalize branch
(`:1554-1559`) emits `RunSummary`/`DoneEvent` and returns `trace_after_empty_floor` containing
neither; the two direct returns (InvalidHistory `:1528-1530`, approval-invariant `:1612-1615`)
return with no summary at all; `1704`/`1711`/`1762` append their error events, never the summary.
The spike's `c2_finalize` fix is not at HEAD, and the ADR correctly instructs treating D6.1 as
unimplemented everywhere.

**The upstream status section is accurate and does not overstate.** Re-derived from the upstream
design doc itself (`git -C ailang show
386cf6d15:design_docs/planned/v0_31_0/m-recorded-stream-api.md`): status PARKED,
`needs-human-review`; the offered shape `RecordedStream = {chunks: [StreamChunk], outcome:
Result[StepResult, AIError]}`; options (a) land-with-caveat (documentation), (b) provider-interface
cancellation (Go `AIHandler`, 7 implementers), (c) bound the drain locally (chunk/byte budget) —
none touches the AILANG-level `{chunks, outcome}` record, which is what licenses designing against
the shape now. The ADR's "survived two quorum rounds" matches the doc's "Quorum BLOCKED twice … the
design DIRECTION … survived both rounds"; "recommended adoption, parked on scope" matches the
ADOPT-direction/PARKED-on-scope split. The API is absent upstream: `git -C ailang grep
stepWithStreamRecorded upstream/dev -- std internal cmd examples` → no hits, and no recent tag
contains it. "Not merged, no date promised" is stated plainly; the fork prototype is not treated as
the gate anywhere in the ADR.

**M2 is real and correctly framed.** `packages/motoko-ext-abi/types.ail:7` states verbatim "Bumping
`ExtensionHooks` is a major version of motoko-ext-abi". The three widenings verified on the spike
branch: `git diff 4aaf59f..6382dc8 -- packages/motoko-ext-abi/types.ail` shows `ExtPorts.ai_step`
gaining `Trace` and all four `ExtensionHooks` rows gaining `Rand` and `Trace` — at HEAD the hook
rows are still `{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}` with neither. The
Consequences text cites "381 effect-row edits across 71 files" as "Measured v0.26.0 → v0.31.0" —
measurement framing, not a forecast.

## Recommended pre-acceptance actions

This ADR must fix, in dependency order:

1. **R1** — correct the F4 disposition (13, the attribution, the routed-state clause). It is written
   into D4 and cited by D5, so it lands first.
2. **R3 + R4** — repair the two Context rows and the header's "the rest verified unchanged" claim;
   same re-grounding pass, same files.
3. **R2** — narrow or specify the reachability-aware audit before it becomes gate evidence; prefer
   the structural pattern `89a1d67` demonstrated.
4. **R5** — scope the port-widening rule to demonstrated loss channels.
5. **R6** — one sentence naming the interim cursor home.
6. **R7** — restore the disposition record or correct the references to it.
7. **R8** — commit the revision and all three verification sections as one record; any body edit
   from items 1-6 post-dates all three verifications and requires a fresh delta review, which the
   Status line should say.

Belonging to the implementation plan, not this ADR: the `Ports.model_step` widening; the scripted
cursor fix that turns `spike_scripted_cursor_probe.ail` into a passing regression test; the
event-vocabulary construction ahead of any classification-dependent D7/acceptance check; routing
all 13 profile-reachable clock reads including the eight `compose` sites through the world/
`ExtPorts.clock_now`; and sequencing the measured extension-ABI major. The throwaway spike branch
must not be cited as gate evidence for any of it.

External and not this review's to clear: the recorded-stream API must land in a released AILANG
binary, the toolchain must be repinned to it, and the direct positive integration probe must pass
before acceptance. It is parked upstream, unmerged, unreleased, and unchanged by anything in this
round.

## Accept / revise recommendation

**Revise.** The architecture and the F1/F2/F3/F5/F6 dispositions survive a third independent
execution-grounded verification — the third verifier to reach that conclusion, independently — but
the F4 disposition carries false numbers and false state into two decisions (R1), D5 names an
unspecified analysis as a gate (R2), the re-grounding pass falsified its own completeness claim
(R3/R4), and the acceptance record exists only in an uncommitted working tree (R7/R8). This is the
same core defect set found by both prior 2026-08-01 verifications; three independent convergences
on identical findings is the strongest evidence they are real. The upstream recorded-stream blocker
remains exactly where the ADR puts it — open, parked, external — and is not cleared by this review.

---

## Review Comments

_Reviewer: Claude Code (model: `claude-opus-5`), 2026-08-01. **Delta review** of the F1–F6
correction pass, per `HANDOFF-delta-review-adr-001-f1-f6-corrections.md`. Sixth section: two reviews
2026-07-26, three verifications 2026-08-01, this delta._

Reviewed at `5eadee76dc66d687d697e277784e82a991d79bfb` (working tree clean), corrections committed as
`d3bd9cd` plus the two ADR edits in `5eadee7`. Toolchain `AILANG v0.26.0` (commit `3b52a24`),
matching `scripts/install-prerequisites.sh:39`. Scope is the corrected text only; F1, F2, F3, F5, F6,
D6.1, the narrowed D1 blocking clause, the upstream return-shape ruling, M2, and the architecture are
not reopened.

The pre-correction blob is confirmed unretrievable, so no correction could be isolated by diff:

```text
$ git cat-file -e 374d46fbe39ccb77b2fd4a5e71b3dabc0c70f741 || echo "NOT IN OBJECT STORE"
NOT IN OBJECT STORE
```

Every claim below was re-executed at HEAD. Nothing is inherited from the handoff's enumeration, from
the spike branch, or from the three prior verifications.

### R1. D5 obligation 2 does fail open, but not for the reason the OPEN DEFECT gives — the real hole is profile scope, and run as written the inventory misses 8 of the 13 clock reads D4 depends on

**Defect:** The marked OPEN DEFECT (ADR:791-805) attributes obligation 2's fail-open to
`_resolve_call` discarding `ports.model_step(...)`. That mechanism does not establish fail-open, and
resting the repair on it will produce the wrong fix. The tool captures direct ambient calls in both
syntactic forms; what it drops is calls *through* the seam, which are already routed. The actual
fail-open is that obligation 2 names only one scope correction (`src/core/test/**`) while the
default profile is `("src/core",)` and excludes `packages/` — where D4 itself puts 8 of the 13
reads.

**Grounding.** The tool resolves bare selective imports (`source_parser.py:193-198`) and qualified
std calls (`:186-187`, which returns without any membership check — a permissive, genuinely
over-approximate path). Executed against the real extractor:

```text
$ python3 -c "...sp.parse_all([session.ail, compose.ail, stub_step.ail])..."
src/core/session      std_calls now: derive_session_id, emit_run_summary,
                                     run_v2_from_messages_traced_with_policy_and_counts,
                                     run_v2_from_messages_with_policy_and_counts   (4)
compose               std_calls now: snippet_meta_json, one_attempt, one_attempt,
                                     run_attempts, handle_compose_tool, on_response_intercept
stub_step             model_step edges: []
```

The four `session.ail` rows are exactly D4's four attributed driver functions — i.e. the inventory
obligation 2 is *for* works. The empty `model_step` edge list is the drop the OPEN DEFECT cites, and
it is a routed call, not an ambient one. Any direct ambient effect is written literally at some
definition site inside the scanned tree, and the tool sees the literal form there; the seam-drop
hides the *edge*, not the *call*, and a module-level inventory does not need edges.

The scope hole, executed across all three profiles (`tools/code-graph/extractor/config.py:13-17`,
`source_parser.py:37-39,53-56`):

```text
profile=core include_tests=False: files=34  clock_std_calls=5
profile=core include_tests=True:  files=43  clock_std_calls=5
profile=all  include_tests=False: files=178 clock_std_calls=14
```

Obligation 2 as written — `core`, plus `src/core/test/**` — yields **5**. It misses all 8
`motoko-ext-compose` reads, which D5's own third bullet (ADR:749-751) makes a conformance
precondition. `include_tests=True` changes nothing, because the `core` profile's root tuple never
contained `packages/`. That is a 62% miss on the one measurement D4 and D5 jointly depend on.

A second, independent defect in the same tool: its output is neither a site count nor a stable
function count. The plain-call path dedups on `(from_slug, std_module, symbol)`
(`source_parser.py:257-262`), so N ambient calls in one function collapse to one row; the
interpolation path (`:267-281`) carries no `seen` check, so interpolated calls emit unconditionally.
`compose#one_attempt` appears twice because `:503` is interpolated and `:597` is plain, while a
function with two plain calls would appear once. The audit therefore cannot reproduce D4's "13
distinct call sites" and cannot certify routing *completeness* — only that a function mentions an
ambient symbol.

**Ruling on the handoff's A1 question.** The correction has the tool preference inverted, and a
conservative textual inventory is the right primary detector for *this* use. D4's 13 was reproduced
here by exactly that method:

```text
$ grep -rn "\bnow\s*(" --include=*.ail src packages
```

which returned all 13 in-profile sites plus `scripts/smoke_ports_record.ail:65` — over-approximate
and complete, which is the required bias. D5's disparagement of "grep-based audit" is correct only
for F2's architecture-discovery use, which obligation 2 already separates by name; it should not
carry over to hermeticity inventory.

**On effect rows as primary detector:** not viable alone at HEAD. `src/core/agents_md.ail:106`
declares `func walk_agents(current: string, acc: [string]) -> [string]` with no effect row while
calling `fileExists(...)` at `:109` — a live `FS` under-declaration. Rows are the right *eventual*
primary, because they are compiler-checked and cannot silently rot, but only behind a
declared-versus-performed reconciliation gate that does not exist.

**Action:** Replace obligation 2's tool with a conservative textual inventory of ambient-effect
imports and call names, per in-profile module, at **site** granularity, with fail-closed manual
triage; state its profile roots as `src` + `packages` explicitly, and state its soundness boundary
(it cannot see effects performed outside the scanned AILANG tree — e.g. TypeScript child processes —
and cannot see which sites are reachable). Delete the over-approximation argument that rests on the
call-graph. Name effect-row reconciliation as the successor detector and its blocker. Constructing
the inventory belongs to the implementation plan; naming the detector and its boundary belongs to
this ADR, because D5 is what the name-adoption gate cites.

### R2. The OPEN DEFECT's non-citability is marked only in D5, while D4 restates the same unsupported bias and requires the same audit for the clock gate, unmarked

**Defect:** D5's marker ends "**D5's routing audit must not be cited as name-adoption gate evidence
until it does**" (ADR:805). But D4:601-604 independently asserts the property the marker retracts,
and D4 is the section a profile reads for the clock:

> the **source and ABI routing audit** enumerates such reads — conservatively and with
> over-approximate bias, per D5 — and is the one a profile depends on

That is C10's softened text, and it now propagates a claim D5 has withdrawn, with no marker. D5's
own third hermeticity bullet (ADR:749-751) makes the same audit a conformance precondition —
"cannot claim conformance until its eight clock reads route through `ExtPorts.clock_now` (D4)" — and
is likewise unmarked. A reader entering at D4 or at the hermeticity bullet list gets the retracted
claim with no signal.

**Grounding:** `ADR:601-604`, `ADR:749-751`, `ADR:805`.

**Action:** Either propagate the non-citability marker to D4:601-604 and D5's third bullet, or —
better — repair obligation 2 per R1 and delete all three markers together. Do not leave the
retraction reachable from only one of the three places that assert it.

### R3. C8 names the interim cursor's home but no mechanism reaches it, and the only mechanism available under the widening Handoff item 1 specifies violates C8's own prohibition

**Defect:** C8 (ADR:235-244) puts the interim scripted cursor in "**one explicit field on
`C2LoopState`, threaded by the driver** — not in a closure captured inside a `Ports` value". C13
(ADR:1223-1228) supplies the mechanism: "It rides on item 1: once `model_step` returns a record it
can return next-state too." But item 1 (ADR:1220-1222) specifies the widening as
"Behaviour-preserving with `emissions: []` at every construction site" — an emissions field and
nothing else — and C9 (ADR:305-319) scopes the port-widening rule to `model_step`'s *demonstrated
emission* loss channel specifically. A successor cursor is not an emission. Item 1 as specified does
not enable item 2.

Working the mechanism through to HEAD source, the two candidate completions both fail:

- If the successor returned is a `Ports`, the driver stores it in `C2LoopState.provider`
  (`src/core/session.ail:344`, already `provider: Ports`) and the cursor lives inside that value's
  closure — precisely "a closure captured inside a `Ports` value", which C8 prohibits by name.
- If the successor is a bare cursor, the scripted closure must receive it back on the next call. It
  cannot: `Ports.model_step` is `(string, [Message], (StreamChunk) -> () ! {IO}) -> ...`
  (`src/core/ports.ail:18`) with no state parameter. The pre-built state machine C13 points at is
  shaped `scripted_model_next(state) -> {result, next}` (`src/core/test/scripted_ports.ail:38-48`)
  — state in *and* out — which is not `model_step`'s shape at either end.

So the F6 fix requires `model_step` to gain a state **parameter** as well as a successor field. That
is a bidirectional widening, it is not behaviour-preserving, and it is named nowhere: not in C9's
loss-channel scoping, not in item 1, not in the D1 bullet at ADR:349-353.

**Grounding:** `ADR:235-244`, `ADR:305-319`, `ADR:1220-1228`; `src/core/ports.ail:18`;
`src/core/session.ail:338-357`; `src/core/test/scripted_ports.ail:38-48`.

**Action:** State the interim mechanism in D1 or item 1 explicitly — that `model_step` takes and
returns provider state alongside `emissions`, that this is a second widening of the same field on a
second stated ground, and that it is *not* behaviour-preserving. Then reconcile C9: either widen its
scope sentence to cover state-threading as a named ground distinct from emission loss, or say that
`model_step` is widened twice for two reasons. As written the three paragraphs are jointly
unsatisfiable.

### R4. C6's claim that `stub_step.ail:175-204` "now contains only comment text" is false — that range holds `dispatch_step`'s entire definition

**Defect:** The re-grounded Context row (ADR:181) states the previously cited `:175-204` "predates
`89a1d67` and now contains only comment text, part of which is itself stale." Only `175-191` is
comment. Lines `192-199` are the complete definition of `dispatch_step` — including `:198`, the sole
`ports.model_step` call — and `203-204` open `prose_step`.

**Grounding:**

```text
$ awk 'NR>=190 && NR<=204 {printf "%d: %s\n", NR, $0}' src/core/test/stub_step.ail
190: -- There is no `next_provider` to return: a Ports is immutable, and the old
191: -- Ported branch returned it unchanged.
192: export func dispatch_step(
193:   ports: Ports,
...
198:   ports.model_step(model, msgs, on_chunk)
199: }
203: export pure func prose_step(text: string) -> ScriptedStep {
```

The old anchor was not invalidated by comment drift; it still lands on live code. That matters
because the row's stated reason for re-grounding is wrong, and the ADR's own lesson —
"a 're-grounded' label is a claim to re-verify, not a warrant" (ADR:40) — is what this violates.

**Action:** Correct the parenthetical to "the previously cited `:175-204` predates `89a1d67`; the
comment half (`175-191`) is partly stale (see below) and the code half is now the one-arm
`dispatch_step` at `192-199`, cited separately above."

### R5. C7's two anchors are each off by one, and one of them names a line that is not stale

**Defect:** The *Known stale source comment* note (ADR:185-193) cites `stub_step.ail:170-171` as the
stale text and `:189-190` as the self-contradiction. Both are shifted by one.

**Grounding:**

```text
170: -- Dispatch one step call through the provider.                      <- accurate, not stale
171: -- Returns both the step result and the updated provider (tail of script for Scripted).
172: -- Loop callers thread next_provider into their recursive call.
...
189: --                                                                    <- bare comment marker
190: -- There is no `next_provider` to return: a Ports is immutable, and the old
191: -- Ported branch returned it unchanged.
```

The two stale sentences the note quotes are at `171-172`; the note's range includes `:170`, which is
correct and must survive the source fix, and omits `:172`, which must not. The contradicting sentence
is at `190-191`. An implementer executing the deferred source fix against the cited ranges would
delete a good line and leave a stale one.

**Action:** Change `170-171` to `171-172` and `189-190` to `190-191`.

**On deferring the fix itself:** deferring is right. Moving source under an in-review ADR is the
pattern that produced these stale anchors, and the note is explicit about why. But the deferral is
only safe if the ranges are exact, which is what R5 fixes. Record the source fix as a work item
somewhere durable — right now it exists only inside a prose note in a proposed ADR.

### R6. `HANDOFF-review-adr-001-f1-f6-revision.md:216` still claims D6.1 was confirmed three times — the exact overstatement `5eadee7` narrowed in the ADR

**Defect:** The Status line was correctly narrowed to "D6.1's zero-`RunSummary` claim by two of the
three" (ADR:14-15). C14's handoff edits did not carry that narrowing across:

```text
$ sed -n '215,217p' .agent/projects/009_motoko_dst_execution/HANDOFF-review-adr-001-f1-f6-revision.md
... F1, F2, F3, F5, F6,
D6.1, the narrowed blocking clause, the upstream return-shape ruling, and M2 were each independently
confirmed three times and are not reopened.
```

That paragraph is in the *corrected* part of the handoff — the closed output contract C14 added, not
the preserved historical contract — so it is a live instruction, and it tells the next reader D6.1 is
settled more firmly than it is.

**The narrowing itself is correct.** Codex verifies D6.1 path-by-path at ADR:2825-2829; Kimi at
ADR:3201-3209. Claude's section touches D6.1 only at ADR:2398, and there only to cite its *count* in
support of a different finding — not a ruling on the zero-`RunSummary` claim. "Two of the three" is
the accurate reading.

**Action:** Narrow HANDOFF:216 to match ADR:14-15.

### R7. C6's `88-99` range for `play_chunks` overshoots into the next function

**Defect:** The Context row (ADR:181) cites `src/core/test/stub_step.ail:88-99` for `play_chunks`.
`play_chunks` is `88-96`; `97` is blank and `98-99` open `assistant_count`.

**Grounding:**

```text
 96: }
 97:
 98: pure func assistant_count(msgs: [Message]) -> int {
 99:   match msgs {
```

Harmless to a reader, but this row was re-grounded in the pass whose stated purpose was anchor
precision, and `assistant_count` is the function F6 is *about* — an anchor that silently spans both
is the kind of thing that reads as intentional later.

**Action:** Change `88-99` to `88-96`.

## What is accurate

**C11's count and routing state are right this time — ruled explicitly.** Re-derived from scratch at
HEAD on pinned v0.26.0, not inherited:

```text
$ grep -rn "\bnow\s*(" --include=*.ail src packages
src/core/session.ail:791, 842, 1991, 2089                                   (4)
src/core/ext/runtime.ail:190                                                (1)
packages/motoko-ext-compose/compose.ail:362,503,597,651,681,767             (6)
packages/motoko-ext-compose/author_tools.ail:101                            (1)
packages/motoko-ext-compose/authoring/dispatcher.ail:217                    (1)
                                                                        total 13
```

Thirteen, with the table's per-file split (4 / 1 / 8) exact and the compose sub-split (`compose` 6,
`author_tools` 1, `authoring/dispatcher` 1) exact. The wider sweep the handoff asked for finds
nothing further: `import std/clock` appears in exactly six files repo-wide, no import is aliased
(`grep -rn "std/clock (.*as"` → empty), so no alias hides a site; `src/core/session.ail:30` is the
single `now` binding in the driver, confirming "no fifth"; and there are **zero** `sleep(` call sites
in `src`, `packages`, or `scripts`. The only clock read outside the tabulated set is
`scripts/smoke_ports_record.ail:65`, a standalone smoke module with its own `main`, correctly out of
the session profile.

Attributions verified: `:791` is inside `derive_session_id` (`session.ail:788-792`), which is called
at `1990`, `2088`, and `2293`; `2293`'s enclosing function is `run_v2_with_conversation`
(`:2277`), exactly as the correction says. `conversation_loop_v2` (`:2251-2269`) takes `session_id`
as a parameter and performs no clock read — the phantom row is correctly retired. `:842` is inside
`emit_run_summary`; `1991` and `2089` are `started_at_ms` in the two `run_v2_from_messages_*`
entry points.

"Nothing is routed at HEAD" holds, and is in fact stronger than stated: `clock_now` has **zero
invocations repo-wide** for *both* `Ports` and `ExtPorts`. Every hit is a field construction or a
`noop_clock_now` definition; `src/core/session.ail:675` passes `p.clock_now` through to `ExtPorts`
without calling it.

The default-profile reachability argument for the eight compose reads also holds:
`handle_compose_tool` is reached from `on_tool_handle` (`compose.ail:758`), registered as the hook at
`:839`, and dispatched by the core runtime at `src/core/ext/runtime.ail:338`.

**C12's replacement is buildable but incorrectly biased — ruled at R1.** The *distinction* obligation
2 draws (hermeticity inventory ≠ architecture discovery) is sound and is the most valuable sentence
in the correction; the tool it recommends does not have the property the argument needs, though for a
different reason than the OPEN DEFECT states, and the honest primary detector today is the
conservative textual inventory D5 currently disparages. D5 *can* name a buildable primary detector —
it is just not the one it names. Obligations 1 and 3 are unaffected and correct.

**The enumeration is complete, with one omission.** `git show --stat d3bd9cd` touches only three
documents (this ADR, the review handoff, `REPLY-546-park-unbounded-drain.md`) and `5eadee7` only two;
the working tree is clean, and `git diff --stat 7b9b4a4c..HEAD -- src packages scripts Makefile
.github` still returns only the four files the handoff lists. No source moved under this review. I
found no corrected text outside C1–C14 plus the two `5eadee7` ADR edits — except that the handoff
discloses only the D6.1 narrowing as post-dating `d3bd9cd`, while `5eadee7` also added the
Status-block paragraph at ADR:18-22 announcing the open defect. Its content is disclosed elsewhere
in the handoff, so this is an enumeration gap rather than an undisclosed edit. The caveat that
remains unclosable: with no pre-correction blob I can certify that each cited location *contains what
the table describes*, not that the table describes everything that *changed* there.

**Confirmed sound, re-executed:**

- **C5.** Five `emit_run_summary` call sites at `1325`, `1554`, `1704`, `1711`, `1762` (`:833` is the
  definition). `1554` is the success path (`result: Ok(st.msgs)`); `1325` is inside `c2_fail`
  (`:1301`), so call sites genuinely do not equal terminal paths. Both direct returns check out:
  invalid history at `1528-1531` and the approval-state invariant at `1614-1616`, each returning with
  no summary emitted.
- **C6, the parts that hold.** `148-154` is `live_ports` with the `stepWithStream` call at `:152`;
  `157-168` is `scripted_ports_from_steps` exactly; `192-199` is the one-arm `dispatch_step` exactly.
  Three of five ranges exact — see R4 and R7 for the other two.
- **C9.** The narrowing is defensible, not an over-correction. `env_get` is
  `(string, string) -> string ! {Env}` and `approval_read` is
  `(ApprovalRequest) -> ApprovalResolution ! {IO}` (`src/core/ports.ail:19-21`) — neither has an
  intermediate multi-fire channel through which a value can be silently discarded, which is the loss
  the rule is about. `env_get`'s missing-versus-empty conflation is real but is a *modeling* gap in
  the world's synthetic environment, not a discarded-emission loss, and belongs to D1's `world_state`
  contract rather than to this rule. No contradiction with D1's own bullets: `ADR:351-353` preserves
  `ApprovalResolution` and the point clock read unchanged, and `ADR:349-350` names `tool_exec`'s
  widening on the separate `ToolCallEnvelope`/deadline ground exactly as C9 says.
- **C3, verified per finding (A6).** Every one of F1–F6 has a locatable response where C3 claims:
  F1 at ADR:227-234, F2 at ADR:296-322, F3 at ADR:607-620, F4 at ADR:621-641, F5 at ADR:905-914,
  F6 at ADR:236-244/245-254 and Implementation Handoff item 2 at ADR:1223-1228. No
  `## Spike-findings disposition` heading exists. C3 is a correct ruling, not a rationalization.
- **C14's handoff edits are additive (A7).** Each is marked as a correction over preserved history —
  "**Corrected 2026-08-01:**" at HANDOFF:22, "The review text is intentionally left as written — it
  is a historical record" at :200, "The contract below is retained as the historical record of what
  the three executed rounds were asked for" at :220. The original contract is legible as history and
  the executed rounds are not made to look like they were asked for something else. R6 is the single
  exception, and it is a factual overstatement rather than a rewrite.
- **C1/C2, apart from R6.** The D6.1 narrowing is correct (grounded at R6). I checked the remaining
  "all three" claims for the same overstatement and found none: Claude rules on the narrowed
  blocking clause at ADR:2531, on the upstream return shape at ADR:2557-2562, and on M2 at
  ADR:2564-2570, matching Codex and Kimi.
- **C4.** The retraction is accurate and the falsified completeness claim is stated in the ADR's own
  voice rather than paraphrased.
- **C10.** Softened as described — but see R2 for what it now propagates.
- **Five prior `## Review Comments` sections counted directly before appending this one.**

**Process finding, not an ADR defect.** The handoff is right that the unretrievable blob is a
mechanical consequence of Kimi's R8. The cost is concrete and lands on this review: three of my seven
findings (R4, R5, R7) are anchor errors that a two-line diff would have surfaced in seconds, and I
had to re-derive every one of the fourteen corrections from prose to find them. Commit acceptance
records before they are reviewed, one commit per pass.

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. **R1 — repair D5 obligation 2.** Everything else in D5 and D4's clock gate depends on which
   detector is named. Replace the call-graph recommendation with the site-level textual inventory,
   state `src` + `packages` as profile roots, state the soundness boundary, name effect-row
   reconciliation as successor.
2. **R2 — then delete or propagate the non-citability markers.** Cannot be done before (1), because
   what the markers say depends on whether obligation 2 is repaired.
3. **R3 — reconcile C8, C9, and item 1** on the interim cursor mechanism. Independent of (1) and (2)
   and can proceed in parallel, but must land before the implementation plan is written, because item
   2 is sequenced first in that plan and is currently unbuildable as specified.
4. **R4, R5, R7 — correct the three anchor ranges.** Mechanical; all three verified above.
5. **R6 — narrow HANDOFF:216.** Mechanical.

**Belongs to the implementation plan, not this ADR:**

- Constructing the ambient-effect inventory itself, and pinning its output format so it can be
  diffed gate-to-gate. This ADR names the detector; the plan builds it.
- The deferred `stub_step.ail:171-172` / `190-191` comment fix, with this ADR's anchors into that
  file re-grounded in the same change. Track it as a work item — it currently exists only as prose
  inside a proposed ADR.
- The declared-versus-performed effect-row reconciliation gate, and closing the
  `agents_md.walk_agents` under-declaration (`src/core/agents_md.ail:106-110`) that demonstrates why
  it is needed.
- `ExtPorts.clock_now`'s first use. Zero invocations repo-wide means the seam that must route nine of
  the thirteen reads has never executed; budget for it changing shape on first contact, as D4 says.

## Accept / revise recommendation

**Revise** — R1 and R3 are substantive and change what the ADR requires, R2 leaves a retracted claim
reachable from two unmarked places, and R4/R5/R7 are three more anchor errors in a re-grounding pass
whose stated purpose was anchor precision; none is architectural, and the architecture, the F1–F6
dispositions, and C11's now-correct clock measurement all survive this pass intact. The upstream
recorded-stream API blocker is untouched by this review and is not clearable here: it remains open,
parked, unmerged, and external, D1 still requires it to land in a *release* with the toolchain
repinned before acceptance, the `arniwesth/ailang` fork's `stepWithStream` on `v0.31.0` does not
satisfy that, and it therefore continues to block acceptance independently of every finding above.

---

## Review Comments

_Reviewer: Codex (model: `GPT-5`), 2026-08-01. Independent delta verification of the F1-F6
correction pass. This is the seventh section in the working tree: five historical sections exist at
HEAD, and an uncommitted sixth section authored by Claude Code was already present when this review
started._

_ADR body reviewed at commit `5eadee76dc66d687d697e277784e82a991d79bfb`; correction commit
`d3bd9cd2`. Toolchain: AILANG v0.26.0, commit
`3b52a24d24431c372ed5605289ef039592209514`._

### R1. D5 still names no conservatively over-approximate routing detector, and D4 continues to rely on that unsupported bias

**Defect:** D5 obligation 2 and D4's clock gate require an over-approximate source/ABI inventory,
but the available graph is a regex approximation with incomplete call resolution and profiles that
do not cover the required source roots; the marked defect's dropped `ports.model_step` edge is real,
but that routed seam call is not itself an ambient-effect site and does not identify the detector the
gate can soundly use.

**Grounding:** `tools/code-graph/extractor/source_parser.py:176-199` drops a dotted call when the
prefix is not an import binding; `tools/code-graph/extractor/config.py:12-17` defines `core` as only
`src/core` and `all` as `src`, `scripts`, `examples`, and `packages`. Executed against the parser:

```text
$ python3 - <<'PY'
... parse default core and all profiles; count std/clock.now rows; parse stub_step invokes ...
PY
core_now_rows= 5
all_src_packages_now_rows= 13
stub_model_step_edges= []
```

The same parser finds all thirteen direct `now()` sites when supplied the broad file set, showing
why the dropped port edge and the ambient-site inventory are different questions. It nevertheless
does not promise conservative coverage: it recognizes calls only through the import-resolution
cases at `source_parser.py:181-199`, and its shipped `core` scope omits the eight package sites D4
requires. Effect rows cannot be the primary detector at HEAD either:
`src/core/agents_md.ail:106-117` calls `fileExists` while declaring no `{FS}` row.

**Action:** Replace obligation 2's unspecified function-level/call-graph preference with a
conservative textual inventory of ambient-effect imports and call names over explicit profile roots,
including production code in `src/core/test/**` and every selected extension package. Treat an
ambient import or unresolved effectful call as a fail-closed candidate for manual triage, state the
soundness boundary, and name declared-versus-performed effect-row reconciliation as the successor
detector. Repair D4:601-604 at the same time so it no longer asserts an unavailable bias.

### R2. C8 and C13 name a cursor home but not an executable state-transition shape

**Defect:** Returning a successor cursor from a widened `model_step` cannot thread it through the
next provider call because the current port accepts no cursor input, while storing the cursor inside
a successor `Ports` closure is exactly the second home C8 prohibits.

**Grounding:** `src/core/ports.ail:17-24` defines
`model_step: (string, [Message], callback) -> Result[...]` with no state parameter;
`src/core/session.ail:338-357` gives `C2LoopState` only `provider: Ports` and no scripted-state field;
and `src/core/test/scripted_ports.ail:38-48` demonstrates the required shape as
`scripted_model_next(state) -> {result, next}`. D1 says the cursor must be an explicit
`C2LoopState` field and not closure-captured (ADR:235-243), while Handoff item 2 says merely that a
record return can carry next-state (ADR:1223-1228).

**Action:** Specify that the interim provider operation takes the current scripted/provider state
and returns its successor alongside `emissions` and the outcome, with the sole persistent value in
the named `C2LoopState` field. Update Handoff item 1 to distinguish the behaviour-preserving emission
widening from this additional bidirectional state-threading change, and reconcile C9's separately
named widening grounds.

### R3. C11's count is repo-wide, not a demonstrated default-profile-reachable set

**Defect:** The thirteen-site number is exact across `src` and `packages`, but D4 incorrectly calls
all thirteen reachable under the default profile even though the checked-in default installs neither
`compose` nor `test_dummy`, and no checked-in profile installs both.

**Grounding:** The wider sweep returned thirteen direct call sites: four in `session.ail`, one in
`ext/runtime.ail`, and eight in `motoko-ext-compose`; the only `std/clock` import outside that set is
the out-of-profile `scripts/smoke_ports_record.ail`. Configuration and registry execution show the
scope mismatch:

```text
$ sed -n '36,39p' .motoko/config/default/config.json
  "extensions": {
    "order": ["empty_stop_guard", "progress_contract_guard", "compaction_ai", "context_mode", "exa_search", "scratchpad", "compaction_structural"],
    "strict": false

$ rg -n 'test_dummy|"compose"' .motoko/config -g 'config.json'
.motoko/config/ailang/config.json:45:      "compose"
```

`src/core/ext/registry_generated.ail:51-69` instantiates only names present in that order.
`src/core/ext/runtime.ail:187-198,206,222,245,287,374` performs the fifth read only for a hook whose
id is `test_dummy`; `packages/motoko-ext-compose/compose.ail:756-758,816-840` makes the other eight
reachable only when `compose` is installed.

**Action:** Relabel thirteen as the repo-wide `src` + `packages` inventory, or name and version the
specific D5 simulation profile whose extension set makes those sites reachable. Record per-profile
counts separately; do not use “default profile” for a set no current default configuration realizes.

### R4. C1 contradicts the live acceptance state recorded immediately below it

**Defect:** The Status block says the convergent defects are corrected and that only the upstream
release event blocks acceptance, while the same block requires a fresh delta review and marks D5's
routing audit as a non-citable open defect.

**Grounding:** ADR:4-10 says “those defects are corrected” and “One acceptance blocker remains”;
ADR:12-22 says the corrections have not been independently reviewed and that D5 remains defective
and cannot be cited as gate evidence.

**Action:** Say one *external substrate* blocker remains, while separately listing the correction
defects and their delta verification as internal pre-acceptance work. Do not claim the correction set
is complete until the resulting delta passes.

### R5. The handoff's supposedly exhaustive edit account omits two post-`d3bd9cd` ADR additions

**Defect:** The handoff discloses only the D6.1 narrowing as post-dating `d3bd9cd`, but `5eadee76`
also added a six-line Status paragraph and the fifteen-line D5 open-defect block.

**Grounding:** Executed diff:

```text
$ git diff --unified=0 d3bd9cd..HEAD -- .agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md
@@ -14,3 +14,9 @@
 [D6.1 narrowing plus six-line “One correction carries a known open defect” paragraph]
@@ -784,0 +791,15 @@
 [fifteen-line “OPEN DEFECT in obligation 2” block]
```

The pre-correction blob remains unavailable, so C1-C14's exhaustiveness at `d3bd9cd` cannot be
mechanically certified; every enumerated location contains the described text, but there is no
object against which to prove that no other correction was made.

**Action:** Correct the post-commit edit account to enumerate all three ADR changes in `5eadee76`
and retain the explicit limitation that C1-C14 cannot be proven exhaustive without the missing blob.

### R6. C6's second-pass re-grounding still misstates two source ranges

**Defect:** The Context row overextends `play_chunks` into `assistant_count` and falsely says
`stub_step.ail:175-204` now contains only comments even though it includes the complete live
`dispatch_step` definition and the start of `prose_step`.

**Grounding:** Executed source excerpt:

```text
$ awk 'NR>=88 && NR<=99 || NR>=190 && NR<=204 {printf "%d:%s\n", NR, $0}' src/core/test/stub_step.ail
88:func play_chunks(...
96:}
98:pure func assistant_count(...
190:-- There is no `next_provider` to return: ...
192:export func dispatch_step(
198:  ports.model_step(model, msgs, on_chunk)
199:}
203:export pure func prose_step(text: string) -> ScriptedStep {
```

The other C6 ranges hold: `148-154` is `live_ports`, `157-168` is
`scripted_ports_from_steps`, and `192-199` is the one-arm pass-through. The serial core and blocking
MCP anchors also hold at `tool_phase.ail:302-357` and `motoko-ext-mcp/exec.ail:63-70,165-176`.

**Action:** Change `88-99` to `88-96`, and replace the “only comment text” claim with an accurate
description: `175-191` is the partly stale comment block, `192-199` is live `dispatch_step`, and
`203-204` begins `prose_step`.

### R7. C7's stale-comment and contradiction anchors are both off by one

**Defect:** The note cites `170-171` for two stale sentences and `189-190` for their contradiction,
but the stale sentences are `171-172` and the contradiction is `190-191`.

**Grounding:** `src/core/test/stub_step.ail:170` accurately says “Dispatch one step call through the
provider”; `:171-172` incorrectly promise an updated provider and threaded `next_provider`; `:189`
is only `--`; and `:190-191` state there is no `next_provider` to return.

**Action:** Change the ranges to `171-172` and `190-191`. Deferring the source edit remains sound,
but track it as an implementation work item and re-ground this ADR in the same source change.

### R8. C14's live handoff correction still overstates D6.1 verification

**Defect:** The corrected, live part of `HANDOFF-review-adr-001-f1-f6-revision.md` says D6.1 was
confirmed three times even though the ADR correctly narrowed that claim to two.

**Grounding:** HANDOFF:213-217 includes D6.1 among claims “independently confirmed three times.”
Codex verifies the zero-`RunSummary` claim at ADR:2825-2830 and Kimi at ADR:3201-3210; Claude's
section cites only D6.1's five-call-site count at ADR:2397-2401 and does not rule on zero returned
summaries.

**Action:** Narrow HANDOFF:215-217 to say D6.1 was confirmed by two of the three, matching ADR:13-16.

## What is accurate

**C11's numeric count and routing state are correct this time.** On pinned AILANG v0.26.0, the
wider `src` + `packages` sweep finds exactly thirteen direct `now()` call sites: four in
`src/core/session.ail` (`791`, `842`, `1991`, `2089`), one in `src/core/ext/runtime.ail` (`190`),
and eight in `motoko-ext-compose` (`compose.ail` six, `author_tools.ail` one,
`authoring/dispatcher.ail` one). There are no aliased `std/clock` imports. The only additional site
is `scripts/smoke_ports_record.ail:65`, outside the claimed source/package set. The replacement
attribution holds: `session.ail:791` is inside `derive_session_id`; `run_v2_with_conversation` calls
it at `:2293`; `conversation_loop_v2` performs no clock read.

“Nothing is routed at HEAD” also holds. This command exited 1 with no output:

```text
$ rg -n --glob '*.ail' '\.clock_now\s*\(' src packages scripts
[no output]
```

All `clock_now` hits are definitions, record fields, or the `p.clock_now` pass-through at
`session.ail:675`, not invocations. R3 concerns the set's profile label, not its count or routing
column.

**C12's replacement is not correctly biased as written, but a buildable primary detector exists.**
The distinction between architecture discovery and hermeticity inventory is sound. A conservative
textual import/call inventory over explicit semantic-profile roots can be built today and can
genuinely over-approximate by treating unresolved imports/calls as candidates. Effect rows are the
right eventual detector only after declared-versus-performed reconciliation closes accepted latent
under-declarations. Obligations 1 and 3 remain sound.

**The enumeration is not complete.** R5 identifies the definite post-`d3bd9cd` omissions. Because
the pre-correction blob was never written, no reviewer can prove C1-C14 exhaustive at the correction
commit; this is a process limitation, not an additional architecture defect.

The following corrections were also re-run and confirmed:

- **C3:** every F1-F6 response is locatable where claimed: F1 at ADR:224-243, F2 at :300-324, F3 at
  :607-619, F4 at :621-645, F5 at :893-917, and F6 at :235-254 plus Handoff item 2. The missing
  disposition heading was a bad reference, not a missing normative record.
- **C4:** the retraction accurately records that source moved under the ADR and that the blanket
  “rest verified unchanged” claim was false.
- **C5:** `emit_run_summary` has five call sites at `1325`, `1554`, `1704`, `1711`, and `1762`;
  `1325` is the shared `c2_fail` helper; `1554` is the success branch; and the direct returns at
  `1528-1531` and `1614-1616` emit no summary. Call sites do not equal terminal paths.
- **C7, disposition only:** deferring the contradictory source-comment edit is appropriate during a
  findings-only review; only its anchors are wrong (R7).
- **C9:** the loss-channel narrowing is defensible. `model_step` alone has the demonstrated
  multi-fire callback whose emissions are discarded. `env_get`'s fallback semantics are a modeling
  contract rather than a discarded intermediate channel, and `tool_exec` is widened on its separate
  typed-envelope/deadline ground. R2 requires an additional state-threading ground for
  `model_step`; it does not revive the rejected all-fields generalization.
- **C14, historical treatment:** the corrections are explicitly labeled and preserve the spent
  original contract as history. R8 is a remaining factual overstatement, not a rewrite of what the
  three executed rounds were asked to do.
- **C1/C2 ruling counts:** the D6.1 narrowing to two verifications is correct. The remaining listed
  F1/F2/F3/F5/F6, narrowed-blocker, upstream-return-shape, and M2 rulings are present in all three
  2026-08-01 sections. R4 concerns the current blocker count, not those historical ruling counts.

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. **R3:** define or name the semantic profile whose routing gate is being counted, then state its
   exact source/package roots; alternatively relabel thirteen as a repo-wide inventory.
2. **R1:** name the conservative textual detector and soundness boundary over those roots, then
   repair D4's dependent over-approximation claim and remove the non-citability marker only after the
   replacement is independently verified.
3. **R2:** specify the interim cursor operation's state-in/state-out shape and reconcile D1 with
   Handoff items 1-2 and C9's widening grounds.
4. **R4, R5, and R8:** correct the acceptance status, post-commit edit enumeration, and D6.1 count in
   the live handoff.
5. **R6 and R7:** correct the mechanical source anchors.

**Belongs to the implementation plan, not this ADR:**

- Build and pin the textual ambient-effect inventory for each versioned profile, with diffable
  output and fail-closed triage.
- Add declared-versus-performed effect-row reconciliation and close known under-declarations such as
  `agents_md.walk_agents`.
- Implement the bidirectional scripted-provider cursor transition and turn the existing F6 probe
  green without placing state in a closure.
- Delete the stale `stub_step.ail:171-172` comments, retain the accurate `:170`, and re-ground the ADR
  in that source change.
- Route the clock sites belonging to each named profile through the world seam and add first-contact
  conformance coverage for `ExtPorts.clock_now`.

## Accept / revise recommendation

**Revise.** C11's raw count and routing state now hold, but R1-R3 leave the hermeticity gate and
interim cursor mechanism underspecified or incorrectly scoped, and R4-R8 leave contradictory status,
provenance, and anchors. The upstream recorded-stream API blocker is unchanged and independently
continues to block acceptance: it remains open, parked, unmerged, and external; a fork prototype does
not clear the gate, which still requires the API to land in a release, the toolchain to be repinned,
and the positive integration probe to pass.

## Review Comments

_Reviewer: Claude Code (model: `claude-opus-5`), 2026-08-01. **Delta review of the third correction
pass**, per `HANDOFF-delta-review-third-correction-pass.md`. **Eighth section**: two reviews
2026-07-26, three verifications of the F1–F6 revision 2026-08-01, two delta reviews of the second
correction pass 2026-08-01, this delta._

Reviewed at `139d4498d3c801cb7b969fd579c6b4a87b9b8a18` (working tree clean). Baseline
`4ea8862` — the commit carrying the two delta reviews verbatim. Target range, exhaustive:

```text
$ git diff 4ea8862..HEAD --stat -- .agent/projects/009_motoko_dst_execution/
 ...DR-001-deterministic-test-world-architecture.md | 259 +++++++++++++++------
 ...NDOFF-delta-review-adr-001-f1-f6-corrections.md |  17 ++
 .../HANDOFF-delta-review-third-correction-pass.md  | 216 +++++++++++++++++
 .../HANDOFF-review-adr-001-f1-f6-revision.md       |  10 +-
 4 files changed, 427 insertions(+), 75 deletions(-)
```

Toolchain `AILANG v0.26.0` (commit `3b52a24`), matching the pin. Scope is the corrected text alone.
F1/F2/F3/F5/F6, the narrowed D1 blocking clause, the upstream return-shape ruling, M2, D6.1's
zero-`RunSummary` claim, D4's count of 13, "nothing is routed at HEAD", corrections C3/C4/C5/C9/C14,
and the accepted 007 architecture are not reopened. Every claim below was executed at HEAD; nothing
is inherited from the handoff, from the spike branch, or from the seven prior sections. The
`.ailang` cache warning was honoured — all probe results below are from a clean scratch directory
outside the repo.

Having a real two-commit diff worked. Six of the previous round's fifteen findings were provenance
or anchor errors; this round has none, because the diff answered those questions directly.

### R1. The bidirectional widening has a second `Ports.model_step` call site the ADR does not account for, and it sits behind the extension ABI

**Defect:** D1's new paragraph and Implementation Handoff item 2 specify that `model_step` "must
take the current provider state and return its successor," with the sole persistent copy in a
`C2LoopState` field. There are **two** calls through that field, not one. The second —
`src/core/session.ail:662`, inside `ext_ai_step` — is reached from `ExtPorts.ai_step`, whose ABI
signature carries no state in either direction and cannot reach `C2LoopState`. The widening
therefore forces either an unbudgeted `ExtPorts` ABI change or a second, discarded copy of provider
state: precisely the "second home" D1 prohibits by name, arriving through a path the ADR never
mentions.

**Grounding:**

```text
$ grep -rn "\.model_step(" src packages --include=*.ail
src/core/session.ail:662:  match p.model_step(provider_api_model(model, base_url), msgs_to_messages(msgs), on_chunk) {
src/core/test/stub_step.ail:198:  ports.model_step(model, msgs, on_chunk)
```

`session.ail:654-666` defines `ext_ai_step(p: Ports, ...)`; `session.ail:668-677` wraps it as
`ExtPorts.ai_step`; that `ExtPorts` is constructed at four driver sites from loop state:

```text
$ grep -n "ext_ports_of" src/core/session.ail
668:func ext_ports_of(p: Ports, base_url: string) -> ExtPorts ! {...}
1622: ... ext_ports_of(st.provider, policy.step.provider_base_url), ...
1649: ... ext_ports_of(st.provider, policy.step.provider_base_url), ...
1696: ... ext_ports_of(st.provider, policy.step.provider_base_url), ...
1778: ... ext_ports_of(st.provider, policy.step.provider_base_url), ...
```

The ABI signature admits no state (`packages/motoko-ext-abi/types.ail:63`):

```text
  ai_step: (string, [Msg]) -> Result[string, string] ! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream},
```

The ADR's only contemplated change to this field is an effect-row addition — ADR:1290 lists
"`ExtPorts.ai_step` gains `Trace`" among the repin's ABI major. A state parameter is nowhere
budgeted. The Context row corrected in this pass compounds the problem by asserting `:198` "is the
sole `ports.model_step` call": literally true of the identifier `ports`, false of the seam, and D1's
whole argument turns on the seam's singularity.

**Action:** In D1, state which of the two dispositions applies to `ext_ai_step`: (a) `ExtPorts.ai_step`
widens too, in which case say so and move it into the ABI-major budget in *Consequences* alongside
the `Trace` row; or (b) the extension AI path is explicitly declared out of the state-threaded
provider seam — a fixed non-scripted sub-provider whose calls do not advance the cursor — in which
case say why an extension-issued model call may skip the script without diverging replay. Silence is
not an option here, because a discarded successor at `:662` is the exact defect F6 records. Also
re-word the Context row: `:198` is the sole call *in `dispatch_step`*, not the sole call through the
field.

### R2. The state type the widening names cannot be seen by the two modules that must declare and thread it — the module graph forbids it and the generic escape does not typecheck

**Defect:** D1 points at `scripted_model_next(state) -> {result, next}`
(`src/core/test/scripted_ports.ail:38-48`) as "the shape the port lacks at both ends," and item 2
says `ScriptedPortsState` "already models the threaded cursor in the required shape." Neither
`src/core/ports.ail` (which must declare the widened field) nor `src/core/session.ail` (which must
hold the `C2LoopState` field and construct initial state at `ported_provider`) can import that type:
`scripted_ports.ail` imports both, and AILANG rejects the cycle. The obvious escape — parameterising
`Ports` over the state type — does not typecheck on the pin.

**Grounding:** the import edges that close the cycle:

```text
$ grep -n "^import src/core" src/core/test/scripted_ports.ail
13:import src/core/ports (ApprovalResolution, ApprovalAllowed, ApprovalDenied, Ports, ports_shape_probe)
15:import src/core/test/stub_step (...)
18:import src/core/session as Session
```

`ScriptedStep` — the payload of `ScriptedPortsState.model_steps` — is declared at
`src/core/test/stub_step.ail:34`, and `stub_step.ail:23` imports `src/core/ports`, so it is not
visible in `ports.ail` either. The compiler rejects the cycle (clean scratch dir, no repo cache):

```text
$ ailang check cyc/a.ail
Error: dependency cycle: LDR002: dependency cycle detected: cyc/a -> cyc/b -> cyc/a -> ...
```

A parameterised record declaration is accepted but its instantiation is unusable — both annotation
and field access fail:

```text
$ cat p4.ail
module p4
export type PortsG[s] = { model_step: (string, s) -> { result: int, next: s } }
export func use(p: PortsG[int], st: int) -> int { (p.model_step("m", st)).result }
...
$ ailang check p4.ail
Error: type error in p4 (decl 0): type unification failed at [field access at p4.ail:8:5]:
cannot unify type application PortsG[int] with { model_step: α1, | r }
```

(An annotated `let` fails the same way: `cannot unify old record type with *types.TApp`.) There are
no parameterised record types anywhere in the tree —
`grep -rnE "^(export )?type [A-Za-z_]+\[[a-z]" src packages` returns nothing — so this is unprecedented
as well as unsupported. Compounding it, `state_from_step_provider`
(`scripted_ports.ail:30-36`), the only existing initial-state constructor, is unreachable from the
driver for the same cycle reason: `grep -rn "src/core/test/scripted_ports" src --include=*.ail`
outside `src/core/test/` returns nothing, and `session.ail` imports only `stub_step` (`:133`).

**What does work.** The shape composes fine with a record of closures and with recursive state
threading, provided the state type is **concrete and declared in `src/core/ports.ail` or below**. A
three-module probe mirroring the real layering (`ports` → `stub` → `session`, live and scripted
adapters, a recursive driver threading the successor through one loop-state field) typechecks and
effect-checks clean at v0.26.0:

```text
$ ailang check lay/session.ail
→ Type checking lay/session.ail...
→ Effect checking...
✓ No errors found!
```

**Action:** Say in D1 (or in item 2) that the widening requires a concrete `ProviderState` type
declared in `src/core/ports.ail`, that `ScriptedStep` must move to `ports.ail` or a module below it
to make that possible, and that `ScriptedPortsState`/`scripted_model_next`/`state_from_step_provider`
are a *design precedent* rather than reusable code — the current text reads as if they can be wired
in. Both are relocations of source under this ADR, the pattern the Status block already names as the
source of its stale anchors, so budget them in item 2 rather than discovering them during
implementation.

### R3. The live adapter's successor is unspecified, and `ported_provider` has no way to produce an initial state for two of its three arms

**Defect:** `live_ports` is stateless — it wraps `stepWithStream` and holds nothing
(`src/core/test/stub_step.ail:148-155`). The ADR never says what it returns as successor state, so
every construction site now carries a field with no stated meaning on the live path. Separately,
`ported_provider` returns a bare `Ports` and is the single funnel for all six construction sites; its
`Ported(p) => p` and `LiveAI => live_ports(rt)` arms have no script from which an initial state could
be derived, and the ADR does not say who initialises the new `C2LoopState` field for them.

**Grounding:** `src/core/session.ail:695-701`:

```text
func ported_provider(rt: ExtRuntime, history: [Message], provider: StepProvider) -> Ports {
  match provider {
    Ported(p) => p,
    LiveAI => live_ports(rt),
    Scripted(script) => scripted_ports_from_steps(history, script)
  }
}
```

called at `2015, 2051, 2114, 2137, 2267, 2295` — all six confirmed. Only the `Scripted` arm carries
a script. The identity answer does work — the layered probe above has `live_ports` return
`next: st` unchanged and it typechecks — so this is a specification gap, not an impossibility.

**Action:** One sentence in D1: the live and caller-supplied adapters return their input state
unchanged, and `ported_provider` returns the initial state alongside the `Ports` (or a paired
constructor does), with the empty state used for `LiveAI`/`Ported`. Name it explicitly rather than
leaving six sites to infer it.

### R4. The new "profile-reachable" definition does not classify the `test_dummy` read, and the D4 table's own "reachable when" column contradicts it

**Defect:** ADR:751-759 defines a read as profile-reachable "when it occurs in the core driver or in
a module the profile *installs*", and explicitly rules out "a read some execution path can actually
perform". Two uses in the same section do not satisfy that definition.

(a) `src/core/ext/runtime.ail:190` is in neither category: `runtime.ail` is a core module present in
every profile, and what is conditionally installed is a *hook*, not a module. Read literally, the
definition makes that read profile-reachable always — which contradicts "a profile installing no
clock-reading extension has four sites to route" (ADR:687-688). It is five under the definition as
written.

(b) The table row for `compose` gives its reachability condition as "`compose` is installed **and**
the model calls `Compose`" (ADR:671). The second conjunct is exactly the execution-path test the
definition forbids, and the prose sixteen lines later drops it: "one installing `compose` has
twelve" counts all eight on installation alone. Both cannot be right.

**Grounding:** the read is gated on hook identity, not on module installation
(`src/core/ext/runtime.ail:187-198`):

```text
187:func emit_dummy_hook(hook: string, key: string, val: string) -> () ! {IO, Clock} {
190:    kv("ts", jnum(intToFloat(now()))),
197:func is_test_dummy(hook_id: string) -> bool {
198:  hook_id == "test_dummy" || startsWith(hook_id, "test_dummy#")
```

with six call sites all of the form `if is_test_dummy(h.id) then emit_dummy_hook(...)` (`:206, 222,
239/245, 280/287, 368/374`).

**Action:** Extend the definition to hooks: a read is profile-reachable when it occurs in the core
driver, in a module the profile installs, **or in a core code path guarded solely by an installed
hook's identity**. Then delete "and the model calls `Compose`" from the table's `compose` row so the
column states an installation condition throughout, and confirm in the text that the four/twelve
arithmetic assumes `test_dummy` is not installed. Choosing the other resolution — making the read
unconditionally reachable — would change the stated four to five, so the choice must be made
explicitly rather than left to the reader.

### R5. D5 obligation 2 names a detector whose detection set is never enumerated, and its stated soundness boundary omits out-of-tree AILANG package source

**Defect:** Obligation 2 requires "a conservative textual inventory of **ambient-effect imports** and
call names". That term appears nowhere else in a defining role — the ADR never enumerates which
imports are ambient-effect-bearing, never says whether the set is fixed or pinned to a toolchain
version, and never addresses aliased imports or re-export chains. A detector whose detection set is
undefined is not buildable, and the sole gate that would catch a missing entry is the same detector.
Separately, the stated boundary ("blind outside the AILANG tree; does not decide reachability") is
incomplete: a registry dependency's source is AILANG and is under neither scan root.

**Grounding:** the only adjacent enumeration is per-profile and is a *forbidden* list, not an
ambient-bearing one (ADR:782, inside "A versioned profile definition records"): "forbidden ambient
effects/capabilities during execution". Obligation 2 does not reference it. An enumerable set does
exist and the ADR does not cite it (`ailang.toml:54`):

```text
[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "SharedIndex", "Rand", "Trace"]
```

The scan-root gap:

```text
$ grep -n "sunholo/logging" ailang.toml
9:"sunholo/logging" = "0.4.0"
```

Every other dependency is `{ path = "packages/..." }`; `sunholo/logging` resolves from the registry,
so its source is under neither `src` nor `packages` while being AILANG — a case the "outside the
AILANG tree (TypeScript child processes, MCP subprocesses, shelled binaries)" clause does not
describe. Exposure today is nil: `grep -rn "sunholo/logging" src packages --include=*.ail` returns
only `src/examples/test_logging/test_logging.ail:3`, out of profile. The gate is the point, not the
current tree.

On aliasing: there are no aliased `std/clock` imports at HEAD — all five are the bare form
`import std/clock (now)` (`session.ail:30`, `ext/runtime.ail:3`, `compose/author_tools.ail:3`,
`compose/compose.ail:5`, `compose/authoring/dispatcher.ail:4`) — so nothing is missed today, but
obligation 2 says nothing about the aliased or `as`-qualified forms it would have to handle.

On the `ExtPorts`-closure question the handoff raises: that case is *covered*. An effect reached
through a closure supplied by a scanned package is still written literally at a site inside that
package, so a site-granularity textual inventory over `src` + `packages` sees it. This is the one
part of the boundary that holds without amendment, and it is worth stating in the ADR since the
previous two attempts turned on exactly this confusion.

**Action:** Enumerate the ambient-effect import set in obligation 2 — cite `[effects] max` from
`ailang.toml` as the pinned source and name the corresponding modules (`std/clock`, `std/fs`,
`std/process`, `std/net`, `std/env`, `std/io`, `std/ai`, and whatever `SharedMem`/`Rand`/`Stream`
surface as) — and state that repinning the toolchain requires re-deriving it, tying that to the
ABI-major milestone the Consequences section already budgets. Specify that the inventory matches on
the import *target module* rather than on bound symbol names, so aliased and qualified forms are
covered by construction. Add out-of-tree AILANG package source as a third named limit alongside the
two already stated, with the profile obliged to declare any registry dependency it installs.

### R6. The re-corrected stale-comment note fixes two lines and leaves a third that is stale by the same test

**Defect:** The *Known stale source comment* note now instructs "Delete `171-172` only."
`src/core/test/stub_step.ail:173` is stale for the identical reason — it describes a parameter
`89a1d67` removed from the same function — and the note's emphasis that "the exact ranges matter to
whoever executes this fix" makes an incomplete range a defect rather than a nit.

**Grounding:** the live signature takes no `rt` (`src/core/test/stub_step.ail:192-199`):

```text
192:export func dispatch_step(
193:  ports: Ports,
194:  model: string,
195:  msgs: [Message],
196:  on_chunk: (StreamChunk) -> () ! {IO, Trace}
197:) -> Result[StepResult, AIError] ! {AI, IO, Trace} {
```

while `:173` still reads "rt is forwarded to tools_with_extensions so extension tools appear in the
LLM catalog." The pre-commit signature confirms `rt` was a real parameter of *this* function:

```text
$ git show 89a1d67~1:src/core/test/stub_step.ail | grep -n "func dispatch_step" -A 6
180:export func dispatch_step(
181-  provider: StepProvider,
182-  model: string,
183-  msgs: [Message],
184-  rt: ExtRuntime,
185-  on_chunk: (StreamChunk) -> () ! {IO, Trace}
186-) -> { result: Result[StepResult, AIError], next_provider: StepProvider } ! {AI, IO, Trace} {
```

**Action:** Change the note to "Delete `171-173`." `:170` remains accurate and must survive, as the
note correctly says.

## What is accurate

Everything re-run below was executed at HEAD `139d449` on the clean tree.

**A1 — is the bidirectional widening buildable as specified? No, but it is buildable.** Ruling in
three parts. The *shape* composes: a record-of-closures field taking state and returning
`{result, next, emissions}`, threaded through a recursive driver holding one state field, typechecks
and effect-checks clean on pinned v0.26.0 across a three-module probe that mirrors the real
`ports`→`stub_step`→`session` layering. A closure can accept state it did not capture, and the
successor threads without a second home appearing. What fails is everything the ADR left unsaid: the
state type is not expressible where the ADR points it (R2), the live adapter's successor and the
initial state for four of six construction sites are unspecified (R3), and a second call through the
seam sits behind an ABI that cannot carry state (R1). R1 is the one that could change the plan
rather than just the prose. The sequencing decision — this before the repin, as a change distinct
from the emission widening — is right, and D1's grounds for separating them (state threading is not
a loss channel) are correctly stated and correctly kept out of the loss-channel rule's scope.

**A2 — is D5 obligation 2 specified well enough to build? Not yet, but it is close, and the
diagnosis it now rests on is correct.** The overturn is verified in full. `_binding_maps`
(`source_parser.py:164-173`) populates `bare[sym]` for every non-aliased import, and `_resolve_call`
(`:193-196`) resolves bare `std` calls, so `now()` under `import std/clock (now)` is seen — the
second pass's fail-open claim was wrong and the correction is right to withdraw it. Both replacement
disqualifiers hold: `PROFILES["core"] = ("src/core",)` (`config.py:13-17`, `packages` appears only
under `"all"`), and the granularity claim is exact — the plain-call path dedups on
`(from_slug, target, member)` via `seen` (`source_parser.py:248, 257-261`) while the interpolation
path at `:275-281` has no `seen` check at all. What is missing is the detection set itself (R5). The
`ExtPorts`-closure sub-question resolves in the correction's favour.

**A3 — does the new "profile-reachable" definition hold everywhere the term is used? Not everywhere
— two of five uses fail, both inside D4.** The acceptance-table rows survive it. *Is the tested
boundary honest?* (ADR:1190, "every profile-reachable hook") reads correctly under installation
scoping, since hooks are the thing a profile installs; the definition does not change what that row
demands. *Does virtual time matter?* (ADR:1192) says "every time-bearing read reachable in the
profile", which the definition governs and which is satisfied by it. D5's clock bullet (ADR:828-831)
is explicitly installation-derived and consistent. The two failures are the `test_dummy`
classification and the `compose` row's execution-path conjunct (R4). On the trade: **installation
scoping is the right choice.** It is the conservative direction — it forces routing work for reads
no run reaches, which fails closed — it is decidable from artifacts that exist today, and it is the
only choice consistent with D5 obligation 3 declining to require a reachability analysis. It does not
make any existing profile unachievable: the default profile installs no clock-reading extension, so
its obligation is the four driver reads (five, once R4(a) is resolved), and no checked-in profile
installs `compose` except `.motoko/config/ailang`.

**A4 — the configuration facts, re-derived independently.** All hold.
`.motoko/config/default/config.json:37` lists exactly `empty_stop_guard, progress_contract_guard,
compaction_ai, context_mode, exa_search, scratchpad, compaction_structural` — no `compose`.
`compose` appears in exactly one checked-in config, `.motoko/config/ailang/config.json:41-46`.
`test_dummy` appears in no checked-in config: `grep -rn "test_dummy" .motoko/config/*/config.json`
is empty. `parse_tokens` (`registry_generated.ail:51-65`) instantiates only names resolved from the
configured order (`resolve(name, cfg)` at `:56`, `None => skip`), so an unlisted extension is never
constructed. No checked-in configuration realizes all thirteen — confirmed. The arithmetic is right
under installation scoping: 4 + 8 = 12, and excluding `test_dummy` is correct because no config
installs it. The count and split were re-derived from scratch and match: fourteen `now()` hits across
`src` + `packages`, of which `session.ail:785` is comment text, leaving 13 sites — 4 in
`session.ail` (`791, 842, 1991, 2089`), 1 in `ext/runtime.ail` (`190`), 8 in `motoko-ext-compose`
(`compose.ail:362, 503, 597, 651, 681, 767`; `author_tools.ail:101`;
`authoring/dispatcher.ail:217`).

**A5 — anchors.** Every anchor introduced or changed in `5db6706` was re-run. All exact except as
noted in R6. `registry_generated.ail:51-65` is `parse_tokens`, opening and closing on those lines.
`scripted_ports.ail:38-48` is `scripted_model_next`, and its return shape is literally
`{ result: ..., next: ... }`. `config.py:13-17` is the `PROFILES` dict. `source_parser.py:176-199` is
`_resolve_call`, exactly. `agents_md.ail:106` is `func walk_agents(current: string, acc: [string]) ->
[string]` with no effect row, calling `fileExists` at `:109` — the under-declaration is real and
v0.26.0 accepts it. `ports.ail:18` is the `model_step` field. In `stub_step.ail`: `88-96` is
`play_chunks` exactly (the previous `88-99` overshot into `assistant_count` at `:98`; corrected);
`148-154` is `live_ports` with `stepWithStream` at `:152`; `157-168` is
`scripted_ports_from_steps`; `192-199` is `dispatch_step` in full — the fix for the previous pass's
false "contains only comment text" claim is correct, and the new split (`175-191` comment,
`192-199` function, `203-204` opens `prose_step`) is exact. The stale-comment note's corrected
ranges are right as far as they go: `:171-172` are the two stale lines, `:190-191` the
contradicting pair, `:170` accurate and must survive, `:189` a bare `--`. "Eighteen lines later"
checks out (172→190). The previous ranges would indeed have deleted `:170` and left `:172`.

**A6 — the Status block.** No self-contradiction, and no contradiction with the body. The two-blocker
split is coherent and matches ADR:78 ("the upstream recorded-stream API and an independent review").
Numbering the internal item as a blocker rather than following Codex R4's narrower phrasing is a
defensible strengthening, not a regression. The "settled" list is accurate: D6.1 is now correctly
attributed to "two of the three," matching the delta reviews' finding; the F1/F2/F3/F5/F6, narrowed
blocking clause, upstream return shape, and M2 attributions to all three hold; the delta reviews'
confirmations of D4's count and of C3/C4/C5/C9/C14 are correctly reported. The "no exhaustive-edit
table, deliberately" paragraph discloses the previous table's omission accurately and the diff is
now the record — which is what let this review skip six of the previous round's fifteen findings.
`HANDOFF-review-adr-001-f1-f6-revision.md:216` no longer overstates D6.1 (Claude R6 / Codex R8
answered), and `HANDOFF-delta-review-adr-001-f1-f6-corrections.md` is correctly marked spent with its
A1 preserved as a recorded misdiagnosis.

**A7 — collateral.** The withdrawn over-approximation claim is gone from both places it lived. D4's
detector sentence (ADR:652-653) now says "a conservative textual site inventory over explicit `src` +
`packages` roots, per D5 obligation 2" and defers rather than restating a bias; D5's routing-audit
bullet (ADR:826-827) asserts no bias at all; the clock bullet (ADR:828-831) is derived from the
profile's extension list. They agree with obligation 2 and with each other. Consolidating the
non-citability marker into D5 alone is sound given D4 now defers to it. The 007 pillar-1 row
("capability/routing audits", ADR:1173) is generic enough to remain true. The acceptance row at
ADR:1192 cites "the routing audit" as gate evidence, which is exactly what the Status block and the
D5 verification gate declare non-citable until verified — consistent, and correctly flagged rather
than silently broken.

**One thing the history vindicates.** The pre-`89a1d67` `dispatch_step` returned
`{ result, next_provider: StepProvider }` — a successor *provider value*, the arrangement D1 now
prohibits by name. D1's prohibition is not hypothetical; it is a retrospective judgement on code
this repo actually shipped, and R1's `ext_ai_step` gap is the same defect trying to come back
through the extension seam.

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. **R1** — decide `ext_ai_step`'s disposition. It is first because it can move the widening from the
   pre-repin group into the ABI-major milestone, which changes the sequencing D1 just set.
2. **R2 and R3** — with (1) settled, state the concrete `ProviderState` type, its module home, the
   `ScriptedStep` relocation it implies, the live/`Ported` successor, and who constructs the initial
   state. These are two or three sentences in D1 plus a line in item 2.
3. **R4** — extend the profile-reachable definition to hook-guarded core paths, delete the execution
   conjunct from the `compose` row, and reconcile four-versus-five.
4. **R5** — enumerate the ambient-effect import set from `ailang.toml`'s `[effects] max`, specify
   target-module matching, and add out-of-tree package source as a third boundary limit.
5. **R6** — one-character range fix.

**Belongs to the implementation plan, not this ADR:**

- Building and pinning the textual inventory, its output format, and its manual-triage workflow.
- The `ScriptedStep`/`ProviderState` source relocation R2 requires, and re-grounding this ADR's
  `stub_step.ail` anchors in the same change as the `:171-173` deletion.
- Declared-versus-performed effect-row reconciliation and the `agents_md.ail:106` under-declaration
  it would catch.
- `ExtPorts.clock_now`'s first use — still zero call sites repo-wide, so the seam that must route
  nine of thirteen reads remains unexercised.

## Recommendation

**Revise** — the third correction pass answers all fifteen delta-review findings and its factual
claims hold, but R1 exposes a second seam call the widening cannot cross as designed, and R2/R3/R5
leave the two newly specified mechanisms underdetermined; all six findings are bounded text changes
to D1, D4, and D5, and none reopens the architecture. **The upstream API blocker is unchanged and
untouched by this review**: it remains open, external, and not clearable here — the fork's working
`stepWithStreamRecorded` on `v0.31.0` is a prototype, and D1 still requires the API in a *release*,
the toolchain repinned, and the positive integration probe passing. R1 may enlarge what that repin
must carry, but it does not clear it.

## Review Comments

_Reviewer: Codex (model: `GPT-5`), 2026-08-01. **Ninth independent delta review of the third
correction pass**, explicitly authorized after the repository was found to contain an eighth review.
The eighth section is preserved unchanged and was not treated as verification evidence for this
review._

Reviewed correction target `139d4498d3c801cb7b969fd579c6b4a87b9b8a18`, baseline `4ea8862`.
Current repository HEAD was `d7647d948e949772e2aa6a701edf93eb290a47dd`, whose only delta from the
target is the historical eighth review. The correction range was therefore held fixed rather than
allowing that appended review to enter the target:

```text
$ git diff --stat 4ea8862..139d449 -- .agent/projects/009_motoko_dst_execution/
 ...DR-001-deterministic-test-world-architecture.md | 259 +++++++++++++++------
 ...NDOFF-delta-review-adr-001-f1-f6-corrections.md |  17 ++
 .../HANDOFF-delta-review-third-correction-pass.md  | 216 +++++++++++++++++
 .../HANDOFF-review-adr-001-f1-f6-revision.md       |  10 +-
 4 files changed, 427 insertions(+), 75 deletions(-)

$ git show 139d449:.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md \
    | rg -c '^## Review Comments$'
7
```

The compiler used below was pinned `AILANG v0.26.0` at commit `3b52a24`. Every repository
`.ailang/cache` directory was deleted before the source check. The settled findings named in the
handoff were not reopened.

### R1. The bidirectional `model_step` widening cannot cross the existing extension-model path, so it is not buildable across the real driver as specified

**Defect:** D1 requires every provider operation to consume and return the sole driver-owned provider
state, but the second call through `Ports.model_step` is wrapped in `ExtPorts.ai_step` and then in
decision-only hook returns, none of which can return the successor to `C2LoopState`.

**Grounding:** the claimed single seam consumer is not single:

```text
$ rg -n '\.model_step\(' src packages -g '*.ail'
src/core/session.ail:662:  match p.model_step(provider_api_model(model, base_url), msgs_to_messages(msgs), on_chunk) {
src/core/test/stub_step.ail:198:  ports.model_step(model, msgs, on_chunk)
```

The second call is `ext_ai_step` (`src/core/session.ail:654-666`) wrapped by `ext_ports_of`
(`:668-677`). `ExtPorts.ai_step` returns only `Result[string, string]`
(`packages/motoko-ext-abi/types.ail:62-66`); `ExtensionHooks.on_pre_step` returns only
`PreStepDecision` (`:151-164`); and `PreStepChainResult` contains only `msgs`, `stages`, and
`artifacts` (`src/core/ext/runtime.ail:33`). This is a live provider path:
`packages/motoko-ext-compaction-ai/compaction_ai.ail:104-120` calls `ctx.ports.ai_step`, including
retries. Four core hook contexts receive `ext_ports_of(st.provider, ...)`:

```text
$ rg -n 'ext_ports_of\(' src/core/session.ail
668:func ext_ports_of(p: Ports, base_url: string) -> ExtPorts ! {AI, Clock, Env, FS, IO, Net, Process, SharedMem, Stream} {
1622: ... ext_ports_of(st.provider, policy.step.provider_base_url), ...
1649: ... ext_ports_of(st.provider, policy.step.provider_base_url), ...
1696: ... ext_ports_of(st.provider, policy.step.provider_base_url), ...
1778: ... ext_ports_of(st.provider, policy.step.provider_base_url), ...
```

Passing a state into the closure does not solve this path: discarding `next` recreates F6, while
capturing and replacing it inside the closure creates the second persistent home D1 prohibits.
The Context row at ADR:204 also calls `:198` the sole `ports.model_step` call; that is literally the
only receiver named `ports`, but it is not the sole call through the field and is misleading in the
architecture argument.

**Action:** D1 must choose and budget the extension path explicitly: either widen `ExtPorts.ai_step`,
the relevant hook result(s), and core dispatch results so the same token returns to `C2LoopState`
(placing those changes in the ABI-major milestone), or declare extension-issued model calls outside
the interim state-threaded seam and outside any conformant profile until the full world-token ABI
lands. In the latter case item 2 is only a partial cursor fix and must say so. Reword ADR:204 to say
`:198` is the sole `model_step` call in `dispatch_step`, not the sole seam call.

### R2. The concrete state type named as the implementation precedent is above both modules that must use it

**Defect:** `ScriptedPortsState` cannot be used as the widened field's parameter in `ports.ail` or as
the new driver field in `session.ail` without refactoring the module graph, yet D1 and handoff item 2
describe it as already modeling the required shape without naming the lower-layer replacement or
relocation.

**Grounding:** `src/core/test/scripted_ports.ail:13-18` imports `src/core/ports`,
`src/core/test/stub_step`, and `src/core/session`; `ScriptedPortsState` at `:20-24` contains
`ScriptedStep`, which is declared in `stub_step.ail:34-41`, and `stub_step.ail:23` itself imports
`ports.ail`. Importing the existing state type from either required consumer therefore closes a
cycle. A clean-cache two-module reproduction of that graph was rejected by the pinned compiler:

```text
$ ailang check cycle/a.ail
→ Type checking cycle/a.ail...
→ Effect checking...
Error: dependency cycle: LDR002: dependency cycle detected: cycle/a -> cycle/b -> cycle/a -> cycle/b -> cycle/a
```

The underlying design is viable when the state type is below the consumers. A separate three-module
scratch probe declared concrete `ProviderState`/`Ports` in `probe/ports`, live and scripted closures
in `probe/stub`, and an immutable recursive `LoopState` with one `provider_state` field in
`probe/session`:

```text
$ ailang check probe/session.ail
→ Type checking probe/session.ail...
→ Effect checking...

✓ No errors found!
```

**Action:** Name a concrete interim `ProviderState` in `src/core/ports.ail` or a lower shared module,
and say that the current `ScriptedPortsState`/`scripted_model_next` is a behavioral precedent rather
than directly reusable code. Handoff item 2 must budget the necessary `ScriptedStep`/state-helper
relocation or equivalent layering change; the implementation plan may select the exact syntax.

### R3. The live and caller-supplied provider arms have no specified initial state or successor semantics

**Defect:** `ported_provider` returns only `Ports`, so neither the stateless `LiveAI` arm nor the
arbitrary `Ported(p)` arm can initialize the new `C2LoopState` provider-state field, and D1 never says
what either adapter returns as its successor.

**Grounding:** `live_ports` captures no mutable state and directly returns `stepWithStream`
(`src/core/test/stub_step.ail:148-155`). The normalization funnel is:

```text
src/core/session.ail:695:func ported_provider(rt: ExtRuntime, history: [Message], provider: StepProvider) -> Ports {
src/core/session.ail:697:    Ported(p) => p,
src/core/session.ail:698:    LiveAI => live_ports(rt),
src/core/session.ail:699:    Scripted(script) => scripted_ports_from_steps(history, script)
```

All six public-entry uses do pass through it, as the correction assumes:

```text
$ rg -n 'ported_provider\(' src/core/session.ail
695:func ported_provider(...)
2015:  ... ported_provider(rt, history, provider))
2051:  ... ported_provider(rt, history, provider))
2114:  ... ported_provider(rt, messages, provider))
2137:  ... ported_provider(rt, history, provider))
2267:  let live_provider = ported_provider(rt, history, provider);
2295:  let live_provider = ported_provider(rt, initial_messages, provider);
```

That funnel makes the change mechanically applicable at all six sites, but its return type cannot
supply the newly required initial value. The scratch probe confirmed that an identity transition for
a stateless live adapter compiles; the gap is specification, not language capability.

**Action:** Specify that normalization returns `{ports, initial_provider_state}` (or an equivalent
pair), that live/stateless adapters return their input state unchanged, and whether `Ported` carries
caller-supplied initial state or is deliberately restricted to the stateless identity contract. The
pair's state is then installed once in `C2LoopState` and only successors replace it.

### R4. D5 obligation 2 still does not define the detector's classification set or close its package-root boundary

**Defect:** “Ambient-effect imports” has no enumerated, versioned meaning, so obligation 2 cannot
determine which import targets and symbols are candidates, how aliases are resolved, or what happens
when an installed AILANG dependency lives outside the fixed `src` + `packages` roots.

**Grounding:** in the normative body the phrase occurs only at ADR:855-856; the only nearby
enumeration is the profile's *forbidden* capabilities at ADR:782, not the detector input. The pinned
toolchain exposes more than the illustrative module list and the module/effect relationship is not
one-to-one:

```text
$ ailang builtins list --by-effect | rg '^# '
# AI (13)
# Clock (5)
# Cog (1)
# DOM (5)
# Debug (2)
# Env (3)
# FS (33)
# IO (6)
# Msg (5)
# Net (2)
# Process (4)
# Pure (209)
# Rand (5)
# Secret (1)
# SharedIndex (7)
# SharedMem (5)
# Stream (14)
# Trace (4)
```

`ailang.toml:53-54` permits a different twelve-label maximum, so that list alone is not a stable
module/symbol classifier. Module aliases are legal on the pin; a clean probe using
`import std/clock as c` and `c.now()` produced:

```text
$ ailang check alias_module.ail
→ Type checking alias_module.ail...
→ Effect checking...

✓ No errors found!
```

Matching imported target modules would handle that form; matching only bound call names would not.
For local wrappers and `ExtPorts` closures, scanning the defining module does see the literal ambient
site, so that part of the stated boundary is sound. The unresolved root case is concrete:
`ailang.toml:9` declares `sunholo/logging` from the registry and `ailang.lock:14-16` records
`source: "registry"`; its AILANG source is in neither normative scan root. It is used only by an
out-of-profile example today (`src/examples/test_logging/test_logging.ail:3`), but obligation 2 does
not say that a future profile must reject or scan such a dependency.

**Action:** Define and version the classifier from the pinned toolchain's effect-bearing stdlib/
builtin surface (module plus exported symbol), record it with each profile or manifest, match import
targets so qualified aliases are covered, and require re-derivation on every toolchain repin. Expand
the roots through the resolved lock graph for installed AILANG packages, or fail profile validation
closed when an installed package's source is outside the scanned roots. Keep manual triage and the
separate executed-path capability backstop; neither repairs an undefined classifier.

### R5. The installation-scoped “profile-reachable” definition contradicts two D4 classifications and does not define its hook use

**Defect:** the new definition covers reads in driver or installed-extension modules, but D4 assigns
`test_dummy` reachability to hook identity inside an always-present core module, retains an
execution-path conjunct for `compose`, and later applies the term to hooks rather than reads.

**Grounding:** ADR:751-759 defines only a *read* and explicitly rejects execution-path reachability.
Against that definition:

- `src/core/ext/runtime.ail:187-198` contains the `now()` site and the `is_test_dummy` guard in core;
  the module itself is not installed by a profile. Its five call sites execute the read only under the
  installed hook id (`:206`, `:222`, `:239-246`, `:280-287`, `:368-375`). ADR:678 nevertheless says
  the site is reachable when the hook is installed.
- ADR:679 says `compose` is reachable when it is installed **and the model calls `Compose`**, which
  is the path-sensitive meaning ADR:755-756 rejects. It is also factually too narrow as execution
  reachability: the installed extension's response-intercept path can call `now()` at
  `packages/motoko-ext-compose/compose.ail:756-771` without a `Compose` tool call.
- ADR:1190 requires every “profile-reachable hook” to be mediated, but the definition's subject is
  only reads, leaving the hook classification implicit.

Installation scoping itself is a sound conservative choice: it is enumerable, aligns with D5's
decision not to require reachability analysis, and makes conformance harder rather than easier. The
defect is the scope boundary and inconsistent applications. The arithmetic is correct only with the
missing qualifier: a checked-in profile with `compose` and without `test_dummy` has `4 + 8 = 12`;
a profile installing both has 13.

**Action:** Generalize the definition to effect sites and hooks, and include core sites guarded solely
by an installed hook's identity. Make every table condition installation-only: remove “and the model
calls `Compose`,” retain `test_dummy` under the new guarded-core clause, and say “a profile installing
`compose` but not `test_dummy` has twelve.” State that “profile-reachable hook” means every hook
installed by the profile, whether or not the corpus invokes it.

### R6. The re-corrected deferred source-comment range still leaves one stale line

**Defect:** the note prescribes deleting `stub_step.ail:171-172` only, but `:173` still describes the
removed `dispatch_step` parameter and is stale under the same source change.

**Grounding:** the three consecutive lines are:

```text
171 -- Returns both the step result and the updated provider (tail of script for Scripted).
172 -- Loop callers thread next_provider into their recursive call.
173 -- rt is forwarded to tools_with_extensions so extension tools appear in the LLM catalog.
```

The live signature at `src/core/test/stub_step.ail:192-199` accepts `ports`, `model`, `msgs`, and
`on_chunk` only. `rt` is instead captured by `live_ports(rt)` and used in its closure at `:148-154`.
The note is right that `:170` remains accurate and that `:190-191` correctly describe the current
one-arm function.

**Action:** Change the deferred source-fix instruction to delete `171-173`, preserving `:170` and
`:189`; re-ground the Context row when that source-only cleanup lands.

## What is accurate

All statements here were re-run against the correction target's unchanged source, rather than
inherited from any prior review.

**A1 — is the bidirectional widening buildable as specified? No; the core shape is buildable, but
the real integration is not yet specified.** A closure can accept state it did not capture, and an
immutable recursive record can replace the single successor field without a second home: the clean
three-module v0.26.0 probe passed. The six `ported_provider` users share a usable normalization
funnel. R1-R3 are the missing pieces: the extension-provider round trip, the concrete lower-layer
state type, and live/`Ported` initialization and identity semantics. This does not overturn D1's
state-threading decision; it bounds the additional contract and ABI work required to implement it.

**A2 — is D5 obligation 2 specified well enough to build? No.** The correction accurately withdraws
the preceding call-graph diagnosis. `source_parser.py:164-173` binds bare imports and `:193-196`
resolves their direct std calls; executing the parser on `src/core/session.ail` returned the four
`std/clock#now` rows for `derive_session_id`, `emit_run_summary`, and both run entry helpers. The
source-parser test suite also passed:

```text
$ python3 -m pytest -q tools/code-graph/tests/test_source_parser.py
...                                                                      [100%]
3 passed in 0.01s
```

The correction's scope and granularity disqualifiers are exact:
`PROFILES["core"] = ("src/core",)` at `config.py:13-17`; the plain-call path deduplicates at
`source_parser.py:248-261`; the interpolation path emits without that `seen` check at `:268-281`.
The proposed replacement still lacks the classifier and dependency-root rule in R4, so its
verification marker cannot be cleared.

**A3 — does “profile-reachable” hold across every use? No.** Installation scope is the correct
fail-closed trade and does not inherently make an existing configuration unachievable, but R5 shows
that it fails the `test_dummy` and `compose` rows and is read-specific while the acceptance table uses
it for hooks. “Every time-bearing read reachable in the profile” at ADR:1192 is consistent once the
definition is repaired; “every profile-reachable hook” at ADR:1190 needs the explicit hook rule in
R5.

**A4 — configuration and clock arithmetic.** Re-enumerating every checked-in
`.motoko/config/*/config.json` confirmed that default's order is exactly the seven names stated at
ADR:683-686, `compose` occurs only in `.motoko/config/ailang/config.json`, and `test_dummy` occurs in
none. The executed counts were:

```text
compose-config-count=1
test-dummy-config-count=0
now-code-sites=13
clock-import-files=5
```

`parse_tokens` at `registry_generated.ail:51-65` iterates only configured tokens and constructs only
`Some(hook)` returned by `resolve`; there is no implicit installation. The 13 code sites re-count as
4 driver + 1 guarded `test_dummy` + 8 `compose`, none routed through `ExtPorts.clock_now`. Thus no
checked-in config realizes all 13, the default configuration has 4 installation-scoped sites, and
the checked-in `ailang` configuration has 12. Every per-row condition is correct after R5's
installation-only repair.

**A5 — anchors.** The requested anchors were printed with `nl -ba`. These are exact:
`registry_generated.ail:51-65` (`parse_tokens`), `scripted_ports.ail:38-48`
(`scripted_model_next`), `config.py:13-17` (`PROFILES`), `source_parser.py:176-199`
(`_resolve_call`), `ports.ail:18` (`model_step`), `stub_step.ail:88-96` (`play_chunks`), `:148-154`
(the live closure and constructor call), `:157-168` (`scripted_ports_from_steps`), and `:192-199`
(`dispatch_step`). `agents_md.ail:106` is the effect-row-free `walk_agents` declaration and its
`fileExists` operations are at `:109` and `:116`; clean-cache checks of both
`src/core/session.ail` and `src/core/agents_md.ail` completed with “No errors found,” confirming that
v0.26.0 accepts the under-declaration. The stale
note's `171-172` and `190-191` ranges are correctly re-anchored but its requested edit is incomplete
because of R6; the prior ranges would indeed have removed correct `:170` and retained stale `:172`.

**A6 — Status.** At the reviewed target, the two blocker kinds are coherent: unshipped external API
versus unverified internal correction text. “Both sets are now corrected” describes authoring state;
“neither the correction set nor acceptance state ... complete” correctly withholds verification and
acceptance, so those sentences do not contradict. The seven historical sections support the settled
list: the three F1-F6 verifications each rule on F1/F2/F3/F5/F6, the narrowed clause, upstream shape,
and M2; only the Codex and Kimi sections explicitly certify the zero-`RunSummary` claim. Both delta
reviews rederive 13/unrouted and confirm C3/C4/C5/C9/C14. D6.1 is therefore correctly stated as two
of three, not three.

**A7 — collateral consistency.** D4:652-655 now defers to D5's textual site inventory without
asserting a call-graph bias. D5's hermeticity bullet at `:826-831` derives clock scope from installed
extensions, and obligation 2 states site inventory rather than reachability; aside from R4 and R5,
the three statements agree. The 007 pillar mapping at ADR:1173 says only “capability/routing audits”
and remains accurate. The virtual-time acceptance row at ADR:1192 requires the same completeness
audit that D5 marks non-citable until verification, so it does not silently treat the gate as passed.

**Upstream blocker.** The public upstream issue
[`sunholo-data/ailang#546`](https://github.com/sunholo-data/ailang/issues/546) was checked read-only
on 2026-08-01: it remains Open, has no linked development, records zero
`stepWithStreamRecorded` symbols in the v0.31.0 release, and describes the working implementation as
the author's fork diff. That is prototype evidence only. Nothing in this correction range lands an
upstream release or repins this repo; `ailang.toml:6` and `ailang.lock:2-4` remain v0.26.0.

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. Resolve **R1** first: decide whether the interim provider token traverses extension AI calls and
   budget the resulting `ExtPorts`/hook ABI changes, or explicitly narrow the interim fix and profile.
   This determines whether handoff item 2 truly precedes or partly joins the ABI-major milestone.
2. With that boundary fixed, resolve **R2-R3**: name the concrete lower-layer state, initialization
   pair, live identity transition, and `Ported` contract. Keep one persistent copy in `C2LoopState`.
3. Resolve **R4**: define the versioned ambient classifier, alias rule, lock-graph/root policy, and
   repin invalidation rule before removing D5's non-citability marker.
4. Resolve **R5**: make installation scope cover installed hooks and hook-guarded core sites, and
   reconcile the table and 4/12/13 wording.
5. Resolve **R6**: correct the deferred cleanup range to `171-173`.

**The implementation plan, not this ADR, owns:**

- the actual state/helper relocation, `Ports`/`StepProvider` constructor edits, all immutable
  `C2LoopState` successor copies, and any extension-ABI migration selected by R1;
- building and pinning the site-level inventory, resolving package sources from the lock graph,
  effect-row reconciliation, diffable output, and fail-closed manual-triage workflow;
- routing the selected profile's 4, 12, or 13 clock sites and exercising `ExtPorts.clock_now`, which
  still has zero call sites; and
- performing the source-comment cleanup and re-grounding anchors in the same source change.

## Accept / revise recommendation

**Revise — R1-R5 leave the two new mechanisms under-specified and R6 leaves an unsafe deferred edit;
the upstream API blocker remains fully in force, is not cleared by the fork prototype or this review,
and will still block acceptance after these ADR fixes until the recorded-stream API ships in a
release, this repository repins to that release, and the positive integration probe passes.**

## Review Comments

_Reviewer: Claude Code (model: `claude-opus-5`), 2026-08-01. **Delta review of the fourth correction
pass**, per `HANDOFF-delta-review-fourth-correction-pass.md`. **Tenth section**: two reviews
2026-07-26, three verifications of the F1–F6 revision 2026-08-01, two delta reviews of the second
correction pass, two of the third, this delta._

_Reviewed at `81b0a899c9338a63a6abfe08172ee6cb15d313ec` (branch
`arniwesth/mot-44-motoko_dst_execution_primer`), working tree clean but for an untracked `mmd/`.
Target range `git diff abb059d..HEAD -- .agent/projects/009_motoko_dst_execution/` — the fourth
correction pass `f3a6a63` plus the `ai_step` scope correction `81b0a89`. Toolchain: `AILANG v0.26.0`
(commit `3b52a24`), matching `ailang.toml:6` and `scripts/install-prerequisites.sh:39`. All three
probes below were built and run in scratch directories outside the repository, so no `.ailang` cache
in this tree could contribute a phantom result._

### R1. D1's new exclusion has no detector — nothing in the ADR derives which hooks to exclude, and obligation 2's one enumerated classifier is blind to `ExtPorts` field calls by construction

**Defect:** D1 excludes extension-issued model calls from every conformant profile, but D5's exclusion
machinery is per-*hook* while `ai_step` is a *port field*, and the only classifier the ADR enumerates
cannot see a call to it — so no gate step forces a profile author to exclude anything.

**Grounding:**

- D5's machinery is per-hook and definitional (ADR:894-896): "An explicitly excluded hook is not
  covered, must be named in the result, and causes a fail-closed `HarnessFailure` if dispatch reaches
  it."
- `ai_step` is a field on `ExtCtx.ports`, not a hook (`packages/motoko-ext-abi/types.ail:62-67`).
- Obligation 2's classifier is "the pinned toolchain's effect-bearing stdlib/builtin surface …
  derived from `ailang builtins list --by-effect`" (ADR:979-982). `ai_step` is not in that surface:

```text
$ ailang builtins list -json | python3 -c "import sys,json; d=json.load(sys.stdin)['builtins']; \
  print('rows:',len(d)); print('named ai_step:',[b for b in d if b['name']=='ai_step'])"
rows: 324
named ai_step: []
```

- ADR:1010 then declares closure-reached effects **covered**, attributing them to the defining site in
  core rather than the extension's call site — so a site-granularity scan of `packages/` sees nothing
  at `packages/motoko-ext-compaction-ai/compaction_ai.ail:106`.

Enforcement is *available* but unnamed. `compaction_ai` reaches the port through exactly one hook —
`register.ail:98,103-104` binds `on_pre_step` to `compact_with_ai`, which reaches
`summarize_with_ai_result` (`compaction_ai.ail:119-120`) → `summarize_attempt` (`:104-106`) — so D5's
per-hook exclusion can express it once someone knows to. And the detector is one grep:

```text
$ grep -rn "ports\.ai_step" packages src --include=*.ail
packages/motoko-ext-compaction-ai/compaction_ai.ail:106:  match ctx.ports.ai_step(model, prompt_msgs) {
packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90:  let summary = match ctx.ports.ai_step(ctx.model, msgs) {
```

**Failure scenario:** a plan author writes a profile definition installing `compaction_ai`, runs
obligation 2's inventory over `src` + `packages`, gets no candidate at `:106` (it is not a stdlib
call), consults the profile-validation bullet at ADR:929-930 which fails closed only on *unclassified*
extensions, classifies `compaction_ai` as covered, and ships a profile D1 says cannot exist. This is
the "checklist wearing a gate's clothes" defect the earlier round named, reproduced one layer down.

**Action:** Add a second, ABI-derived classifier alongside the stdlib one in obligation 2 — the
`ExtPorts` field set read from `packages/motoko-ext-abi/types.ail:62-67`, re-derived on the same repin
trigger — and require profile-definition validation to **fail closed when any installed package
textually references an `ExtPorts` field that does not yet carry the world token** (today: `ai_step`).
It is exactly parallel to the target-module rule at ADR:990-994, costs one grep, and turns D1's
sentence into a gate.

### R2. "Not conformance-eligible" contradicts D5's own machinery and the acceptance table, both of which permit a conformant profile to contain named, fail-closed excluded hooks

**Defect:** D1, *Consequences*, and Handoff item 2 all say a profile installing an `ai_step`-calling
extension is **not conformance-eligible**; D5 and the acceptance table say exclusion costs *coverage*,
not conformance — and the pass's whole sequencing conclusion rests on the stronger reading.

**Grounding:** the strong claim appears three times, all added by this pass — ADR:344-345 ("a profile
installing any extension that calls `ExtPorts.ai_step` is not conformance-eligible in the interim"),
ADR:1430, ADR:1477. Against it:

- ADR:887-888: "An extension may appear **as covered** in a conformant profile only when every hook
  reachable within that profile is either…" — the predicate governed is coverage, and the profile is
  already stipulated conformant.
- ADR:1316, the *Is the tested boundary honest?* acceptance row: "every profile-reachable hook is
  effect-free or world-mediated, **excluded hooks** and adapter/parser boundaries are listed, and
  dispatch to an exclusion fails closed." Listing excluded hooks is presented as evidence a profile
  *passes*, not as a disqualification.

**Failure scenario:** a plan author reads D5 and ADR:1316, installs `compaction_ai` with `on_pre_step`
named as an excluded hook and fail-closed dispatch, and declares a conformant `default` profile —
precisely the outcome ADR:350-351 and ADR:1432-1433 assume is impossible when they conclude "the first
conformant profile is a purpose-built narrow one rather than a shipped configuration."

**Action:** Pick one and state it once. Either (a) an installed `ai_step`-calling hook is *excluded and
named* — conformant but not covered — in which case "the first conformant profile is a purpose-built
narrow one" is false as written and must be restated as a *coverage* claim; or (b) an `ai_step`-reaching
hook is a **profile-definition rejection**, not a hook exclusion, in which case say so at ADR:894-896
and add the carve-out to ADR:1316. (b) is the reading D1 needs; it is not the reading D5 currently
supports.

### R3. Obligation 2's classifier is derivable at module granularity but not as "module plus exported symbol" — the command emits internal builtin names that appear nowhere in Motoko source, so a `(module, symbol)` classifier matches nothing

**Defect:** ADR:981 specifies the detection set "as **module plus exported symbol**, derived from
`ailang builtins list --by-effect`". That command emits the *internal* builtin symbol, never the
exported one, so the symbol half of the specified classifier is both underivable and, if built
literally, a silent fail-open on the obligation whose two prior revisions both failed open.

**Grounding:**

```text
$ ailang builtins list -json | python3 -c "import sys,json; d=json.load(sys.stdin)['builtins']; \
  eff=[b for b in d if not b['is_pure']]; print('effect-bearing rows:',len(eff)); \
  print('named now:',[b for b in d if b['name']=='now']); \
  print('non-underscore effect-bearing names:',sorted({b['name'] for b in eff}-{n for n in {b['name'] for b in eff} if n.startswith('_')}))"
effect-bearing rows: 115
named now: []
non-underscore effect-bearing names: []
```

Every effect-bearing builtin is `_`-prefixed (`_clock_now`, `_fs_readFile`, `_ai_step`). Motoko source
writes `now()` under `import std/clock (now)` (`src/core/session.ail:30,791`) — a name no row carries.

Two further precision points the same run settles:

- The eighteen labels include `Pure` (209 builtins). A gate treating all eighteen as effect-bearing
  flags every `std/list` import. The effect-bearing label count is seventeen.
- The module-less rows (`$builtin`, `core`) are **all** `Pure`; filtering on `is_pure == false` leaves
  21 modules, every one a real `std/*`. The handoff's worry that the surface is partly module-less does
  not survive — but only after `Pure` is dropped, and the ADR does not say to drop it.

**Failure scenario:** an implementer builds the classifier as `(module, exported symbol)` pairs from the
command, scans `src` + `packages` for `_clock_now`, gets zero hits, and certifies a clean routing
inventory over thirteen unrouted clock reads.

**Action:** Replace "as **module plus exported symbol**" with "as the set of effect-bearing target
modules, obtained by filtering `ailang builtins list -json` on `is_pure == false` and projecting
`module`", and note that the `name` field is the internal builtin symbol, not the exported wrapper —
which is *why* the matching rule two paragraphs later is target-module matching rather than name
matching. Also record that nothing re-derives it today:

```text
$ grep -rn "builtins list\|builtins --" Makefile .github scripts
(no output)
```

### R4. "Both checked-in configurations" is false — there are fourteen, all fourteen install `compaction_ai`, and D4 in this same document treats the set as larger

**Defect:** the follow-up commit `81b0a89` grounds a universal conclusion ("No checked-in configuration
is conformance-eligible") on a premise about two configurations, and mis-states the size of the
checked-in configuration set.

**Grounding:** three sites, all introduced by `81b0a89` — ADR:39 ("Both checked-in configurations
install `compaction_ai`"), ADR:349-350 ("appears in the extension order of **both** checked-in
configurations, `default` and `ailang`"), ADR:1431.

```text
$ python3 -c "
import json,glob
ps=sorted(glob.glob('.motoko/config/*/config.json'))
print('configs:',len(ps))
print('with compaction_ai:',sum('compaction_ai' in json.load(open(p)).get('extensions',{}).get('order',[]) for p in ps))"
configs: 14
with compaction_ai: 14
```

D4 knows better in the same file: ADR:763 ("`compose` appears only in
`.motoko/config/ailang/config.json`") and ADR:773 ("every checked-in configuration except
`.motoko/config/ailang`") both presuppose a set larger than two. Independently confirmed: `compose`
appears in exactly one config, `test_dummy` in none —

```text
$ grep -rl '"compose"' .motoko/config/*/config.json
.motoko/config/ailang/config.json
$ grep -rl "test_dummy" .motoko/config/
(no output)
```

The conclusion at ADR:350-351 is true and **stronger** than the ground given: fourteen of fourteen, not
two of two.

**Action:** At ADR:39, ADR:349-350, and ADR:1431 replace "both checked-in configurations" with "all
fourteen checked-in configurations", and drop the enumeration `default` and `ailang` — naming two of
fourteen is what made the premise look narrower than the conclusion.

### R5. The Status block claims the third-pass round spent zero findings on anchor questions; both third-pass reviews spent their R6 on one, and the ADR's own stale-comment note records it

**Defect:** ADR:57-60 offers a measured justification for dropping the edit table — "the round reviewing
the second pass spent six of its fifteen findings on provenance and anchor questions a diff answers
directly; the round reviewing the third pass, with a real two-commit diff, spent **none**." The second
half is false under the same categorization that produces the first.

**Grounding:** the second-pass count checks out — 7 + 8 = 15 findings, of which ADR:3693 (R4, the
`175-204` range), ADR:3722 (R5, "C7's two anchors are each off by one"), ADR:3774 (R7, the `88-99`
range), ADR:4048 (R5, the omitted edit account), ADR:4070 (R6, "still misstates two source ranges"), and
ADR:4098 (R7, "off by one") are provenance/anchor = six. But the third-pass round carries the same
category:

- ADR:4491 — `### R6. The re-corrected stale-comment note fixes two lines and leaves a third that is
  stale by the same test`
- ADR:4907 — `### R6. The re-corrected deferred source-comment range still leaves one stale line`

Two of twelve. The ADR itself records exactly this at ADR:103-106: "**This note has now been wrong
twice** … the second cited `171-172`, which would have left `:173`. Both were caught by review, neither
by the authoring side."

**Failure scenario:** the metric is load-bearing for a process decision (no edit table from here on).
Overstating it by rounding two down to zero is the same unearned-claim pattern the prior rounds
punished, and this section files three anchor findings against the fourth pass (R4, R7, R8).

**Action:** Either state "spent two of twelve, both on the same `stub_step.ail` comment range", or
narrow the category to *provenance* alone — under which the second round spent one of fifteen
(ADR:4048) and the third spent none — and say which is meant. Do not keep the current pairing.

### R6. The Status header still says "two independent delta reviews", twenty lines above a paragraph the fourth pass rewrote to distinguish four

**Defect:** ADR:5-6 reads "**three independent verifications of the F1–F6 revision** and **two
independent delta reviews of the correction pass** (all 2026-08-01, recorded below) complete". Four
delta reviews are recorded.

**Grounding:** ADR:3535 (Claude Code, second pass), ADR:3940 (Codex, second pass), ADR:4218 (Claude
Code, "**Eighth section**", third pass), ADR:4668 (Codex, "**Ninth** independent delta review of the
third correction pass"). The fourth pass rewrote ADR:28-30 to say "The two delta reviews of the
*second* pass … The two delta reviews of the *third* pass …" and left ADR:5-6 unchanged.

**Action:** "four independent delta reviews (two of the second correction pass, two of the third)".

### R7. The clause-3 paragraph says "six call sites"; there are five

**Defect:** ADR:844-845 grounds clause 3 on "six call sites all of the form
`if is_test_dummy(h.id) then emit_dummy_hook(...)`". Five exist.

**Grounding:**

```text
$ grep -rn "is_test_dummy" src packages scripts --include=*.ail
src/core/ext/runtime.ail:197:func is_test_dummy(hook_id: string) -> bool {
src/core/ext/runtime.ail:206:      let _ = if is_test_dummy(h.id) then emit_dummy_hook(...) else ();
src/core/ext/runtime.ail:222:      let _ = if is_test_dummy(h.id) then emit_dummy_hook(...) else ();
src/core/ext/runtime.ail:239:      let _ = if is_test_dummy(h.id) then {
src/core/ext/runtime.ail:280:  let _ = if is_test_dummy(h.id) then {
src/core/ext/runtime.ail:368:  let _ = if is_test_dummy(h.id) then {
```

Five guards; five `emit_dummy_hook` calls (`206`, `222`, `245`, `287`, `374`). The miscount is inherited
verbatim from the third-pass review at ADR:4426, which listed the same five entries
(`206, 222, 239/245, 280/287, 368/374`) and called them six — the correction pass copied the number
without recounting the list beside it.

**Action:** "five call sites". The substantive claim is unaffected and is confirmed below.

### R8. The compose response-intercept citation opens inside `on_tool_handle` — the very path the sentence says is not required

**Defect:** ADR:755-756 justifies dropping "and the model calls `Compose`" by noting "the
response-intercept path reads the clock without any `Compose` tool call
(`packages/motoko-ext-compose/compose.ail:756-771`)". Line 756 is the *tool-handle* hook.

**Grounding:** `packages/motoko-ext-compose/compose.ail:756` is
`export func on_tool_handle(ctx: ExtCtx, call: ToolCallEnvelope, ...)`, closing at `:759`;
`on_response_intercept` opens at `:761`; the clock read is `let name = "inline_${show(now())}"` at
`:767`.

**Failure scenario:** a reader checking the claim lands on `on_tool_handle` and concludes the citation
proves the opposite of what the sentence asserts. Given that this ADR has already burned three review
rounds on off-by-N ranges, the standard here is exact.

**Action:** cite `:761-771`, or just `:767`.

## What is accurate

Everything below was re-run at `81b0a89` on `AILANG v0.26.0`, not inherited.

**Anchors introduced or changed by this pass — all confirmed.** `src/core/session.ail:662`
(`p.model_step(provider_api_model(model, base_url), …)` inside `ext_ai_step`); `:654-666`
(`ext_ai_step`, signature to closing brace); `:668-677` (`ext_ports_of`, which wraps `ext_ai_step` as
`ExtPorts.ai_step` — the closing brace is `:678`, a one-line undershoot, not worth an action);
`:695-701` (`ported_provider`, returning bare `Ports` today); `packages/motoko-ext-abi/types.ail:63`
(`ai_step: (string, [Msg]) -> Result[string, string] ! {…}`);
`packages/motoko-ext-compaction-ai/compaction_ai.ail:106`; `packages/motoko-ext-compose/compose.ail:767`;
`src/core/test/scripted_ports.ail:20-24` and `:20-48`; `src/core/test/stub_step.ail:34` and `:192-199`
(with `:198` the sole `model_step` call *in `dispatch_step`*); `src/core/ext/runtime.ail:190`
(`kv("ts", jnum(intToFloat(now())))` inside `emit_dummy_hook`, `187-195`). "Four hook contexts" is
exact — `ext_ports_of` has call sites at `session.ail:1622, 1649, 1696, 1778`.

**The stale-comment note is correct on its third revision.** `171-173` is the right range and the new
`rt` justification holds:

```text
$ git show 89a1d67^:src/core/test/stub_step.ail | sed -n '180,186p'
export func dispatch_step(
  provider: StepProvider,
  model: string,
  msgs: [Message],
  rt: ExtRuntime,
  on_chunk: (StreamChunk) -> () ! {IO, Trace}
) -> { result: Result[StepResult, AIError], next_provider: StepProvider } ! {AI, IO, Trace} {
```

`rt` was a real parameter and `next_provider` a real return before `89a1d67`; neither is now
(`:192-199`). `:170` is accurate and must survive, `:189` is a bare `--`, `:190-191` are correct.
Deleting `171-173` leaves a well-formed block. Third time is right.

**Configuration facts (other than the count in R4).** `compose` in `.motoko/config/ailang` only;
`test_dummy` in no config; `compaction_ai` in all fourteen. D4's clock arithmetic survives clause 3
unchanged — driver 4 (`session.ail:791, 842, 1991, 2089`; `:785` is a comment), compose 8
(`compose.ail:362, 503, 597, 651, 681, 767`; `author_tools.ail:101`; `authoring/dispatcher.ail:217`),
`emit_dummy_hook` 1, total 13; 4 / 12 / 13 for the three installation cases, and no checked-in
configuration reaches 13.

**Clause 3 is decidable, and "solely" does not smuggle back path analysis.** All five guards are
literally `if is_test_dummy(h.id) then … else ()` with no second conjunct — no config flag, no
execution-path condition — so the predicate is answered by reading one `if` head. `is_test_dummy` and
`emit_dummy_hook` have zero uses outside `src/core/ext/runtime.ail`, so the clause captures no other
core site and misses none. A hypothetical path guarded by hook identity *and* a config flag would fail
"solely" and fall through unclassified; that is the conservative direction and no such site exists
today, but the ADR could say so in a clause. The acceptance-table row at ADR:1316 reads correctly under
the new hook sense: ADR:840 defines a profile-reachable hook as every hook the profile installs, which
is exactly the quantifier that row needs. Note the interaction with R2 — under D1's exclusion,
`compaction_ai.on_pre_step` becomes a profile-reachable hook that is neither effect-free nor
world-mediated, which is precisely why ADR:1316's "excluded hooks … are listed" clause must be
reconciled with D1's stronger claim.

**Non-anchor claims in D5 obligation 2's new text.** `ailang.toml:9` does declare
`"sunholo/logging" = "0.4.0"` from the registry, and its sole importer is
`src/examples/test_logging/test_logging.ail` — an out-of-profile example, so exposure today is nil, as
stated. The aliased-import claim is confirmed by execution: `import std/clock as c` followed by
`c.now()` typechecks and effect-checks clean, as does the bare form, so target-module matching is
required rather than optional.

### Ruling 1 — is the A1 exclusion the right disposition, and is it enforceable?

**Right disposition: yes, and axis 4 checks out exactly as the ADR argues.** D5's coverage criterion 2
(ADR:891-892) admits an effectful hook only when it is "effectful only through D1 world-mediated ports,
with origin tagged by extension id and explicit world state returned to the host". `ExtPorts.ai_step`
returns `Result[string, string]` (`types.ail:63`) and no world state, so an `ai_step`-calling hook
already fails D5's own test independently of D1 — the exclusion follows from the criterion rather than
excepting it. (The ADR's quotation at ADR:340-341 elides "with origin tagged by extension id and"
without an ellipsis; the substance is unaffected.) The alternative — pulling the ABI widening into the
interim milestone — is not too-conservative-to-reject: it collapses Handoff items 1, 2, and 3 into one
change, and the widening is not a field edit but `ExtPorts.ai_step` plus the hook result types plus the
core dispatch results, behind an ABI major that ADR:1417-1419 says forces "a coordinated re-release of
every extension package". Sequencing that ahead of a change testable entirely against `Scripted`
providers is strictly worse. Exclude.

**Enforceable: partially, and not as the ADR specifies it.** The *unit* works — `compaction_ai` reaches
the port through exactly one hook, so D5's per-hook machinery can name and fail-close it. What is
missing is the step that derives *which* hook, and the ADR's one enumerated classifier cannot see the
call (R1). And D1's "not conformance-eligible" is stronger than what D5 and ADR:1316 actually license
(R2). As it stands the exclusion is a statement with an available but unnamed enforcement path — one
grep and one validation clause from being a gate.

**Is the interim milestone still worth sequencing first? Yes — but the ADR's justification needs one
concrete addition.** The purpose-built narrow profile is constructible from packages already in the
tree: neither `empty_stop_guard` nor `progress_contract_guard` calls the port (they only *construct*
`noop_ai_step` for their own smoke fixtures — `empty_stop_guard.ail:52-53,70`,
`progress_contract_guard.ail:136-137,154`), and `grep -rn "ports\.ai_step"` finds no call in either. So
D5's "pure guards and deterministic fixture hooks may form the initial profile" (ADR:900-902) is not
aspirational here. But the ADR names no candidate, and "the first conformant profile is a purpose-built
narrow one" is currently an assertion a reader cannot check. Name one — even as an example — and the
sequencing argument stands on its own.

### Ruling 2 — is `ProviderState`'s home and shape buildable as specified? (A2)

**Home: yes, verified by execution.** A three-module probe mirroring the real graph — a ports-analogue
declaring `ScriptedStep` (relocated) and a concrete `ProviderState`, a stub-analogue above it declaring
`StepProvider` and `ported_provider` returning a `{ports, state}` pair, and a driver-analogue holding
one `provider_state` field in a `C2LoopState`-analogue and threading the successor — typechecks clean:

```text
$ ailang check mod/pdriver.ail
→ Type checking mod/pdriver.ail...
→ Effect checking...

✓ No errors found!
```

Built from scratch in `/tmp/.../a2probe`, outside the repository. The relocation drags in nothing: the
only non-primitive dependency of `ScriptedStep` is `ToolCall` from `std/ai`, and `src/core/ports.ail:9`
already imports `std/ai`. The ADR has **not** named an impossible home.

The cycle claim behind the relocation is also correct. `src/core/test/scripted_ports.ail` imports
`ports` (`:13`), `stub_step` (`:15`), **and** `session` (`:18`); `stub_step.ail:23` imports `ports`;
`session.ail:133,139` imports both. So `ports.ail` can import neither, and a cycle probe reproduces the
stated rejection:

```text
Error: dependency cycle: LDR002: dependency cycle detected: mod/a -> mod/b -> mod/a -> ...
```

The generic escape is closed as described — `type Ports[s] = { … }` is accepted as a declaration and its
instantiation fails (`type unification failed … cannot unify old record type with *types.TApp`), and
`grep -rnE "^\s*(export\s+)?type\s+\w+\[[a-z]" src packages --include=*.ail` returns nothing.

**Shape: an acceptable plan-level detail, not a repeat of R2.** Both candidate shapes are constructible
— my probe used the record form (`{ model_steps: [ScriptedStep] }`, empty state `{ model_steps: [] }`)
and it composes with the `ported_provider` pair without a match at each construction site; a sum works
too. The type *can* exist, which is what distinguished R2's failure. One genuine gap worth closing in
the ADR rather than the plan: the type is named `ProviderState` but specified as the model cursor only,
while the precedent it replaces (`ScriptedPortsState`, `scripted_ports.ail:20-24`) carries `approvals`
and `clock_values` as well. Say whether the approval and clock cursors ride along in the interim
widening or are separate later ones — otherwise the plan will guess, and guessing wrong reproduces the
same bidirectional widening a second time.

### Ruling 3 — is obligation 2's classifier derivable in a gate? (A4)

**Yes at module granularity; no at symbol granularity (R3).** The command exists on the pin, exits 0,
is byte-deterministic across runs (identical `md5sum` on two invocations), and carries a `-json` flag
emitting `{name, module, signature, is_pure, effect, num_args, description}` per builtin — better gate
infrastructure than the ADR claims. The disagreement it cites is real: eighteen labels from the builtin
surface (one of which is `Pure`) against twelve in `ailang.toml:54`
(`IO, Env, AI, Net, FS, Process, SharedMem, Clock, Stream, SharedIndex, Rand, Trace`), so neither alone
is a classifier — confirmed. Every effect-bearing row carries a real `std/*` module once `Pure` is
filtered, so the handoff's worry about a module-less surface does not survive, and target-module
matching covers the bare, aliased, and qualified forms as claimed. What is not derivable is the
"exported symbol" half, and building it literally yields a classifier that matches nothing. It is also
not wired into CI, the Makefile, or `scripts/` today, so "re-derived on every repin" is a process
obligation with no mechanism — acceptable only because the repin is itself a sequenced milestone.

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. **R2** — decide whether an installed `ai_step`-calling hook is an *excluded hook* (conformant,
   uncovered) or a *profile-definition rejection*. Everything below depends on which. R1's fix is only
   well-formed once this is settled, and R4's conclusion is phrased in whichever vocabulary this picks.
2. **R1** — add the `ExtPorts`-field classifier and the fail-closed validation clause, so the exclusion
   chosen in (1) has a detector rather than a paragraph.
3. **R3** — restate obligation 2's detection set as effect-bearing target modules derived by
   `is_pure == false` from `ailang builtins list -json`, drop "exported symbol", and name the `Pure`
   exclusion. Do this in the same edit as (2) so the two classifiers are specified side by side.
4. **R4** — correct "both checked-in configurations" to "all fourteen" at ADR:39, :349-350, :1431.
5. **R5, R6, R7, R8** — the four precision corrections. Independent of each other and of the above.

**Belongs to the implementation plan, not this ADR:**

- `ProviderState`'s concrete field shape (record vs sum) — either builds.
- Whether the approval and clock cursors ride along in the interim widening; the ADR should pose the
  question, the plan should answer it.
- Naming the first purpose-built narrow conformant profile, and confirming its extension set against
  the R1 detector once that detector exists.
- Building both classifiers and the `171-173` source deletion, in the same change that re-grounds this
  ADR's anchors into `src/core/test/stub_step.ail`.

## Accept / revise recommendation

**Revise — the fourth pass's substance holds (the extension-model-path exclusion is the right
disposition and follows from D5's own criterion, and `ProviderState`'s home is buildable exactly as
specified, both verified by execution), but R1 leaves that exclusion without a detector, R2 leaves D1
and D5 saying different things about what it costs, and R3 leaves the routing classifier fail-open if
built literally; the upstream API blocker is untouched by this pass and remains fully in force — it
still requires the recorded-stream API in an actual AILANG *release*, this repository repinned to that
release, and the positive integration probe passing, none of which the `v0.31.0` fork prototype
satisfies.**

**Residual risk if the five actions land as recommended:** the exclusion's detector is a textual grep
over installed packages and inherits obligation 2's stated soundness boundary — it will not see an
`ai_step` reached through an alias or a re-exported wrapper inside an extension, which nothing at HEAD
does and nothing prevents. The classifier's repin re-derivation still has no CI mechanism. And the
first conformant profile remains unnamed, so "purpose-built narrow one" is a claim the plan, not this
ADR, will have to make good.

## Review Comments

_Reviewer: Codex (model: `GPT-5`), 2026-08-01. Independent delta verification of the fourth
correction pass at `81b0a899c9338a63a6abfe08172ee6cb15d313ec`, covering
`abb059d..81b0a89` under pinned AILANG v0.26.0 (`3b52a24`). **Eleventh section:** `HEAD` contained
nine review sections, but the working tree already contained an uncommitted tenth section when this
review began; that section was preserved verbatim and this review was appended at the user's explicit
direction. Fresh typechecking probes ran outside the repository so its `.ailang` cache could not
affect the result._

### R1. The interim `ai_step` exclusion has no detector, so its universal profile rejection is not an enforceable gate

**Defect:** D1 rejects every profile installing an extension that calls `ExtPorts.ai_step`, but D5's
existing fail-closed mechanism acts only after a hook has already been classified as excluded, and
the sole specified source classifier cannot discover this port-field use.

**Grounding:** D5 says an explicitly excluded *hook* is named and fails closed if dispatch reaches it
(ADR:894-896), and profile validation fails closed only for an *unclassified* extension, hook, or
adapter (ADR:929-930). `ai_step` is instead a field of `ExtPorts`
(`packages/motoko-ext-abi/types.ail:62-67`). The complete direct-reference inventory was:

```text
$ rg -n "ctx\.ports\.ai_step|ports\.ai_step|\.ai_step\(" src packages --glob '*.ail'
packages/motoko-ext-compaction-ai/compaction_ai.ail:106:  match ctx.ports.ai_step(model, prompt_msgs) {
packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90:  let summary = match ctx.ports.ai_step(ctx.model, msgs) {
```

Obligation 2 derives only the toolchain's stdlib/builtin surface; that surface cannot classify an ABI
record-field call. For the live extension, the call is reachable through one known hook:
`packages/motoko-ext-compaction-ai/register.ail:103-105` installs `compact_with_ai` as
`on_pre_step`, which reaches `summarize_with_ai_result` and then the call at `compaction_ai.ail:106`.
Thus D5 can enforce a manually known exclusion, and omitting the entire extension is sufficient for a
specific narrow profile, but nothing in the ADR derives that classification for this or a future
extension.

**Action:** Add a second, ABI-port classifier to D5 obligation 2: enumerate the `ExtPorts` fields that
are not yet D1 world-mediated (today `ai_step`), inventory their field-reference sites across every
in-profile source root, and fail profile-definition validation closed when an installed hook or
extension reaches one. State the textual detector's alias/wrapper soundness boundary and require
manual fail-closed triage for unresolved references.

### R2. D1's “not conformance-eligible” rule contradicts D5's treatment of named excluded hooks

**Defect:** D1 says installing an `ai_step`-calling extension disqualifies the whole profile, whereas
D5 and the acceptance table permit a conformant profile to contain a named, uncovered hook whose
dispatch fails closed.

**Grounding:** the stronger rule appears at ADR:339-343, :1423-1433, and :1475-1478. D5 instead says
“An explicitly excluded hook is not covered, must be named in the result, and causes a fail-closed
`HarnessFailure` if dispatch reaches it” (ADR:894-896). The acceptance row at ADR:1316 likewise lists
excluded hooks plus fail-closed dispatch as passing evidence for an honest tested boundary. Under
that text, installing `compaction_ai` with `on_pre_step` classified as excluded costs coverage and
makes an attempted dispatch fail; it does not by itself make the profile non-conformant.

**Action:** Choose one contract and use it consistently. The sequencing argument is clearest if an
installed hook that can call a non-world-mediated `ai_step` is a **profile-definition rejection**
until the ABI major, rather than an ordinary D5 excluded hook; if that is the intended rule, add it to
D5 and its acceptance row. Otherwise replace the “not conformance-eligible” and “first conformant
profile” claims with coverage claims.

### R3. Obligation 2's exported-symbol classifier cannot be derived from the command it names

**Defect:** `ailang builtins list --by-effect` exposes internal builtin names, not exported AILANG
symbols, so the specified `(module, exported symbol)` classifier silently matches no source calls if
implemented literally.

**Grounding:** the machine-readable form exists and is stable, but its names are internal:

```text
$ ailang builtins list -json | jq '{effect_bearing_count: ([.builtins[] | select(.is_pure == false)] | length), source_now_names: [.builtins[] | select(.name == "now")], internal_clock_now: [.builtins[] | select(.name == "_clock_now")], effect_names_not_internal_count: ([.builtins[] | select(.is_pure == false and (.name | startswith("_") | not))] | length)}'
{
  "effect_bearing_count": 115,
  "source_now_names": [],
  "internal_clock_now": [{"name":"_clock_now","module":"std/clock", ...}],
  "effect_names_not_internal_count": 0
}
```

Source uses the exported wrapper name `now`, for example `src/core/session.ail:30,791`. All 115
effect-bearing rows do have real `std/*` modules; the only `$builtin`/`core` rows are pure. The label
count also needs a qualifier:

```text
$ ailang builtins list -json | jq '[.builtins[] | if .is_pure then "Pure" else .effect end] | unique'
["AI","Clock","Cog","DOM","Debug","Env","FS","IO","Msg","Net","Process","Pure","Rand","Secret","SharedIndex","SharedMem","Stream","Trace"]
$ sed -n 's/^max = \[\(.*\)\]/\1/p' ailang.toml | awk -F',' '{print NF}'
12
```

There are eighteen output groups **including `Pure`**, hence seventeen effect labels, versus twelve
permitted effects. Neither enumeration alone is a source classifier. Two consecutive JSON
invocations were byte-identical, `jq` parsed the documented fields, and no current gate consumes it:

```text
$ rg -n "builtins list|--by-effect|builtins.*-json" Makefile .github scripts --glob '*'
(no output)
```

**Action:** Define the conservative classifier as the target-module set obtained from
`ailang builtins list -json` by selecting `is_pure == false` and projecting `module`; scan every call
bound from those modules at site granularity and manually triage pure exports. Drop “exported symbol”
unless a separate stdlib-export mapping is specified, and say explicitly that `Pure` is filtered out.

### R4. Profile-reachable clause 3 is not gate-decidable as written, and its motivating count is wrong

**Defect:** “guarded solely by an installed hook's identity” is an unspecified control-path property,
not something the profile list plus module inventory decides, and the paragraph miscounts five guard
sites as six.

**Grounding:** the current motivating sites are direct and all fit an identity-only lexical guard, but
there are five:

```text
$ rg -n "is_test_dummy|emit_dummy_hook" src/core/ext/runtime.ail
197:func is_test_dummy(hook_id: string) -> bool {
206:      let _ = if is_test_dummy(h.id) then emit_dummy_hook(...) else ();
222:      let _ = if is_test_dummy(h.id) then emit_dummy_hook(...) else ();
239:      let _ = if is_test_dummy(h.id) then {
245:        emit_dummy_hook(...)
280:  let _ = if is_test_dummy(h.id) then {
287:    emit_dummy_hook(...)
368:  let _ = if is_test_dummy(h.id) then {
374:    emit_dummy_hook(...)
```

The ambient `now()` is inside the callee at `runtime.ail:190`, so even this case requires proving that
all callers are identity-guarded; it is not answered by a module inventory alone. A live mixed-guard
shape already exists at `src/core/tool_phase.ail:222-223`:
`is_scratchpad_tool_name(envelope.tool) && scratchpad_extension_active(rt)` guards the effectful
`exec_scratchpad_cell_ws` call. It can execute when `scratchpad` is installed but fails the word
“solely”; a future identity guard plus a config flag has the same problem. The acceptance-table phrase
“every profile-reachable hook” remains grammatically correct, but only after the underlying predicate
is made mechanical.

**Action:** Replace the semantic “solely” test with an explicit, versioned site-to-hook attribution
in the profile/routing inventory; un-attributed core effect sites fail closed as unconditional core
sites. Additional guards must not remove a site from the installed hook's scope. Correct “six” to
“five.”

### R5. The follow-up's “both checked-in configurations” premise is false

**Defect:** The follow-up repeatedly says there are two checked-in configurations, but the repository
tracks fourteen and every one installs `compaction_ai`.

**Grounding:** the changed claims are at ADR:38-40, :345-352, and :1429-1433. The executed inventory
was:

```text
$ git ls-files '.motoko/config/*/config.json' | wc -l
14
$ for f in $(git ls-files '.motoko/config/*/config.json'); do jq -e '.extensions.order | index("compaction_ai") != null' "$f" >/dev/null && printf '%s\n' "$f"; done | wc -l
14
```

`compose` occurs only in `.motoko/config/ailang/config.json`, while `test_dummy` occurs in none. The
universal conclusion “No checked-in configuration” is therefore supported more strongly than stated,
but “both” and the enumeration of only `default` and `ailang` are false.

**Action:** Replace all three “both checked-in configurations” claims with “all fourteen checked-in
configurations” and avoid presenting `default` and `ailang` as an exhaustive list.

### R6. The Status opening still records two delta reviews when the ADR contains four

**Defect:** The Status header's review count and “both sets” summary were not updated for the two
third-pass delta reviews that the fourth pass answers.

**Grounding:** ADR:4-8 says “two independent delta reviews of the correction pass.” The historical
sections begin at ADR:3533 and :3938 for the second pass, and :4216 and :4666 for the third pass — four
delta reviews in two rounds. The newly rewritten ADR:28-31 itself distinguishes both rounds.

**Action:** State “four independent delta reviews (two of the second correction pass and two of the
third)” and revise the defect-set count so the opening agrees with the historical record and the body.

### R7. The Status block's claimed zero anchor/provenance findings in the third-pass round is false

**Defect:** The process justification says the two third-pass reviews spent no findings on anchors,
but both reviews' R6 corrected the same stale source range.

**Grounding:** ADR:57-60 says the third-pass round “spent **none**.” The two historical findings are:

```text
ADR:4491  ### R6. The re-corrected stale-comment note fixes two lines and leaves a third that is stale by the same test
ADR:4907  ### R6. The re-corrected deferred source-comment range still leaves one stale line
```

The second-pass arithmetic is six of fifteen; the third-pass arithmetic is two of twelve, both about
the `stub_step.ail` comment anchor. ADR:103-106 independently acknowledges that both were caught by
review.

**Action:** Replace “none” with “two of twelve, both on the same deferred source-comment range,” or
narrow the comparison to provenance alone and recompute both sides consistently.

### R8. The response-intercept anchor begins in the tool-handle hook

**Defect:** The range cited to prove a response-intercept clock read without a `Compose` tool call
starts at `on_tool_handle`, the path the sentence is distinguishing it from.

**Grounding:** `packages/motoko-ext-compose/compose.ail:756` opens `on_tool_handle` and it closes at
`:759`; `on_response_intercept` opens at `:761`, and its direct clock read is at `:767`. The ADR cites
`:756-771` at ADR:756.

**Action:** Change that citation to `packages/motoko-ext-compose/compose.ail:761-771` or simply `:767`.

## What is accurate

Everything below was re-run at commit `81b0a899c9338a63a6abfe08172ee6cb15d313ec` under AILANG
v0.26.0 rather than inherited from an earlier review.

**A1 ruling — the exclusion is the right sequencing disposition, but is not enforceable as
specified.** `ExtPorts.ai_step` returns only `Result[string, string]` (`types.ail:63`), while
`PreStepDecision`, `ToolHandleDecision`, `ResponseInterceptDecision`, and `FinalizeDecision` carry no
successor token (`types.ail:118-164`). D5 criterion 2 requires explicit world state returned to the
host (ADR:887-892), and D5 separately rejects hidden mutation behind decision-only hooks
(ADR:905-909). Thus an `ai_step`-calling hook is not world-mediated under D5 today; the exclusion
follows D5 rather than creating an exception. Pulling the hook/ABI widening into the interim milestone
would join item 2 to the ABI major and the repin/re-release sequence, delaying a main-loop cursor fix
that is independently testable now. Excluding that path is the better disposition. For a known
profile, omitting the whole extension is sufficient; the missing universal detector and the conflict
between profile rejection and hook exclusion are R1-R2.

The interim milestone remains worth sequencing first. No shipped configuration is eligible under the
strong D1 interpretation because all fourteen install `compaction_ai`, but a purpose-built narrow
profile is constructible: the installed `empty_stop_guard` and `progress_contract_guard` hook
decisions are pure functions (`empty_stop_guard.ail:8-40`,
`progress_contract_guard.ail:8-120`), and neither calls `ctx.ports.ai_step`. Their `noop_ai_step`
functions occur only in local test-context construction, not installed hook execution. This supports
D5's statement that pure guards and deterministic fixture hooks may form the initial profile, though
the implementation plan must name and validate the actual profile.

**A2 ruling — `ProviderState`'s home and required shape are buildable as specified.** `ScriptedStep`
depends only on primitive fields plus `ToolCall` from `std/ai` (`stub_step.ail:34-41`); `ports.ail`
already imports `std/ai`, so relocating the type there does not import a consumer of `ports` or create
the cycle it is meant to avoid. A fresh three-module probe declared `ScriptedStep` and
`ProviderState = { model_steps: [ScriptedStep] }` in the ports analogue, returned
`{ports, state}` from a stub analogue for `LiveAI | Scripted | Ported`, and threaded the successor
through one driver-state field:

```text
$ cd /tmp/adr001_codex_a2_probe && ailang check mod/pdriver.ail
→ Type checking mod/pdriver.ail...
→ Effect checking...

✓ No errors found!
```

The record makes live/`Ported` emptiness `{model_steps: []}`, scripted initialization
`{model_steps: script}`, and the identity successor for stateless adapters explicit. A sum type could
also express it. Choosing record versus sum is an acceptable implementation-plan detail because D1
specifies the observable initialization and transition contracts and at least one concrete lower-layer
shape composes; this is not another “specified where it cannot exist” defect.

**A3 current-source ruling.** All five `emit_dummy_hook` calls are guarded directly by
`is_test_dummy(h.id)`, and `is_test_dummy`/`emit_dummy_hook` have no other uses. No checked-in config
installs `test_dummy`. The clause correctly motivates attributing `runtime.ail:190` to that hook, but
R4 is required to turn the attribution into a stable gate rule.

**A4 ruling — obligation 2 is derivable in a gate only after the R3 correction.** The command exists
on the pin, exits zero, has a documented JSON mode, produced byte-identical JSON in two consecutive
runs, and every non-pure row has a `std/*` module. The module-less builtin concern does not survive
execution. The three accepted import forms all typechecked in fresh scratch modules:

```text
import std/clock (now)          → now()
import std/clock as c           → c.now()
import std/clock as c (now)     → c.now()

$ ailang check mod/bare.ail; ailang check mod/aliased.ail; ailang check mod/qualified_selective.ail
✓ No errors found!
✓ No errors found!
✓ No errors found!
```

Target-module matching therefore covers bare, aliased, and qualified forms by construction. The
classifier is not wired into CI today, which is acceptable for an unimplemented gate only if the ADR
specifies the derivation precisely and the implementation plan wires repin re-derivation before the
non-citability marker is removed.

**A5 anchors.** Confirmed: `src/core/session.ail:654-666` is `ext_ai_step`, with the second
`model_step` call at `:662`; `:668-677` constructs the `ExtPorts` record and binds `ai_step`; its four
call sites are `:1622,1649,1696,1778`; `:695-701` is the current bare-`Ports` `ported_provider`;
`packages/motoko-ext-abi/types.ail:63` is the state-less ABI; and
`packages/motoko-ext-compaction-ai/compaction_ai.ail:106` is the live extension call.
`src/core/test/scripted_ports.ail:20-24` is the three-queue precedent and `:38-48` the explicit
`result + next` model transition. `src/core/test/stub_step.ail:34-41` is `ScriptedStep`, and
`:192-199` is the one-arm `dispatch_step` whose `:198` is the sole seam call in that function.
`src/core/ext/runtime.ail:190` is the guarded dummy clock read. The compose clock read is exactly
`:767`, subject only to R8's over-broad range.

The known-stale-comment target is correct on its third revision. Current `stub_step.ail:171-173`
promises a successor provider and an `rt` parameter that no longer exist at `:192-199`; before
`89a1d67`, `dispatch_step` did take `rt` and return `next_provider`. Line `:170` remains accurate,
`:189` is a bare comment marker, and `:190-191` correctly describe the current function. Deleting
only `171-173` is exact.

**Configuration and D4 arithmetic.** All fourteen configurations install `compaction_ai`; only
`.motoko/config/ailang/config.json` installs `compose`; none installs `test_dummy`. The clock
inventory re-counts as four live `session.ail` reads (`791,842,1991,2089`), eight compose-package
reads (`compose.ail:362,503,597,651,681,767`, `author_tools.ail:101`,
`authoring/dispatcher.ail:217`), and one dummy-hook read (`runtime.ail:190`): 4 / 12 / 13 under the
three installation cases. Nothing is routed at HEAD, and no checked-in configuration realizes 13.

**Status and collateral, excluding R5-R8.** The settled F1/F2/F3/F5/F6, narrowed D1 blocker,
upstream return-shape, M2, D6.1, D4 count/routing, C3/C4/C5/C9/C14, and third-pass configuration,
anchor, and collateral rulings match the nine historical sections. D1, Consequences, and Handoff
item 2 consistently describe the main-loop cursor work as partial and place extension-world-token
widening in the ABI major. No remaining body text describes item 2 as a complete extension-path
cursor repair.

The upstream blocker is unchanged: the reviewed range neither ships a recorded-stream API in an
AILANG release nor repins this repository nor passes the required positive integration probe. The
`v0.31.0` fork prototype does not clear any of those conditions.

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. Resolve R2: define whether non-world-mediated `ai_step` use rejects the profile definition or is
   an ordinary excluded/uncovered hook. The fourth pass's sequencing argument indicates
   profile-definition rejection.
2. Resolve R1: specify the ABI-port-use detector and fail-closed validation that enforce the choice
   from step 1.
3. Resolve R3: derive obligation 2 from non-pure target modules in JSON, remove the underivable
   exported-symbol promise, and record the `Pure` filter.
4. Resolve R4: replace “solely” with a mechanical site-to-hook attribution rule and correct the guard
   count to five.
5. Apply the factual and record corrections in R5-R8: fourteen configurations, four delta reviews,
   two of twelve third-pass anchor findings, and the precise response-intercept range.

**Belongs to the implementation plan, not this ADR:**

- choose the concrete `ProviderState` representation and relocate/re-export `ScriptedStep`;
- build both source classifiers, wire them into CI and repin invalidation, and validate their alias,
  wrapper, and resolved-package-root boundaries;
- name and implement the first purpose-built narrow conformance profile, then run it through the
  profile validator; and
- delete `stub_step.ail:171-173` and re-ground this ADR's affected source anchors in that source
  change.

## Accept / revise recommendation

**Revise — the extension-model-path exclusion is the right sequencing choice and `ProviderState` is
buildable at the specified layer, but R1-R4 leave two required gates ambiguous or fail-open and
R5-R8 leave factual/history precision defects; the upstream API blocker remains fully in force and
still requires a recorded-stream API in a released AILANG version, a repository repin to that
release, and the positive integration probe passing.**

## Review Comments

_Reviewer: Claude Code (model: `claude-opus-5`), 2026-08-01. **Delta review of the fifth correction
pass**, per `HANDOFF-delta-review-fifth-correction-pass.md`. **Twelfth section**: two reviews
2026-07-26, three verifications of the F1–F6 revision 2026-08-01, four delta reviews of the second and
third correction passes, two of the fourth, this delta._

_Reviewed at `e8242f1570078337c203606b6ae5792108628876` (the fifth correction pass). The working tree
is `1d3f1c4d5ecc520645c0c336b656f62fdc3d894b`; `git diff e8242f1..HEAD` over this ADR is empty, so the
reviewed text is the text at HEAD. Target range `git diff b042757..e8242f1 --
.agent/projects/009_motoko_dst_execution/` — one commit, 146 insertions, 63 deletions, one file. The
untracked `mmd/` is out of scope. Toolchain `AILANG v0.26.0` (commit `3b52a24`), matching
`ailang.toml:6` and `scripts/install-prerequisites.sh:39`. Every probe below was built and run in a
scratch directory outside the repository, so no `.ailang` cache in this tree could contribute a
phantom result._

_The pass answers all eight findings of the tenth and eleventh sections. R2, R4, R5, R6, R7 of both
are fixed and confirmed below. R1 and R3 are fixed in form but not in substance (R1, R2, R3 here), and
R8's replacement anchor is wrong (R8 here)._

### R1. Classifier 1 still fails open, for the third consecutive revision — the module set it derives cannot see effect-bearing stdlib modules whose effects come from AILANG source rather than builtins, and two of them are called in-tree, one from the core driver

**Defect:** ADR:1036-1038 defines classifier 1's detection set *by construction* — "obtained by
filtering `ailang builtins list -json` on `is_pure == false` and **projecting the `module` field**".
That projection yields 21 modules. `std/sem` and `std/extension` are not among them, yet both export
effectful functions that this repository imports and calls, including a `SharedMem` write reached from
`src/core`.

**Grounding:** the derivation, run on the pin:

```text
$ ailang builtins list -json > b.json && python3 -c "
import json; d=json.load(open('b.json'))['builtins']
c1=sorted({b['module'] for b in d if not b['is_pure']})
print('classifier 1 modules:',len(c1))
print('std/sem in set?','std/sem' in c1,'| std/sem rows:',[(b['name'],b['is_pure']) for b in d if b['module']=='std/sem'])
print('std/extension in set?','std/extension' in c1,'| std/extension rows:',len([b for b in d if b['module']=='std/extension']))"
classifier 1 modules: 21
std/sem in set? False | std/sem rows: [('_embedding_decode', True), ('_embedding_encode', True)]
std/extension in set? False | std/extension rows: 0
```

Both modules are effect-bearing in the pinned stdlib source, and the effects are the ones D5:949 names
as hermeticity failures:

```text
$ grep -n "export func \(store_frame\|load_frame\)" /home/motoko/.local/share/ailang/std/sem.ail
374:export func load_frame(key: string) -> Option[sem_frame] ! {SharedMem} {
385:export func store_frame(key: string, frame: sem_frame) -> unit ! {SharedMem} {
$ grep -n "export func.*! *{" /home/motoko/.local/share/ailang/std/extension.ail
27:export func requireWorkdirFile(workdir: string, rel: string) -> Result[(), string] ! {FS} =
```

`std/sem` carries a real runtime capability requirement, not just a declared row — a scratch probe
outside the repository:

```text
$ cd /tmp/.../c1probe && ailang run --entry main mod/main.ail
→ Type checking...
→ Effect checking...
✓ Running mod/main.ail
Error: execution failed: effect 'SharedMem' requires capability, but none provided
Hint: Run with --caps SharedMem
```

Both are live in-tree, and one is in the core driver, therefore profile-reachable under clause 1 in
*every* profile:

```text
$ grep -n "import std/sem\|store_frame\|load_frame" src/core/cache.ail
29:import std/sem    (make_frame_at, store_frame, load_frame)
60:  match load_frame(key) {
75:  store_frame(key, frame)
$ grep -rn "get_hint" src --include=*.ail | grep -v "^src/core/cache.ail"
src/core/rpc.ail:24:import src/core/cache   (get_hint)
src/core/rpc.ail:200:  let hint = get_hint(task);
$ grep -rn "^import std/extension" src packages --include=*.ail
packages/motoko-ext-omnigraph/register.ail:4:import std/extension (requireWorkdirFile)
```

Neither `std/sem` nor `std/extension` appears anywhere in this ADR (`grep -n "std/sem\|std/extension"`
returns nothing), so the hole is unacknowledged as well as unclosed.

**Failure scenario:** an implementer builds classifier 1 exactly as ADR:1036-1038 specifies, scans
`src` + `packages` for imports of the 21 derived modules, finds `src/core/rpc.ail:200` clean because
`std/sem` is not in the set, and certifies a complete routing inventory over an unrouted `SharedMem`
read-write pair in the core driver. D4's all-or-nothing rule then rests on a count that is not
complete, which is the exact defect the two previous revisions of this obligation were rewritten to
close.

**Why the prescription missed it:** both fourth-pass reviews checked that every `is_pure == false`
*row* carries a real `std/*` module — true, and confirmed again below — and inferred that the
projection is therefore total. It is not: the question is not whether the derived rows have modules,
it is whether every effect-bearing *module the repo imports* has a derived row. Ten of the twenty-one
`std/*` modules this repo imports have no effect-bearing row, and two of those ten export effectful
functions.

**Action:** the detection set cannot be the builtin projection alone. Either (a) union the builtin
projection with a scan of the pinned stdlib's own `.ail` sources for `export func … ! {…}` with a
non-empty row — derivable from `~/.local/share/ailang/std/*.ail` on the pin, same repin trigger, and
it recovers `std/sem` and `std/extension` mechanically; or (b) invert the classifier to a deny-list —
treat *every* imported `std/*` module as effect-bearing unless it appears in a derived
all-rows-pure allow-list, which fails closed by construction and is the direction the rest of
obligation 2 already argues for. State which, and record that the builtin surface alone is
insufficient and why, so a fourth revision does not rediscover it.

### R2. Classifier 2's stated criterion selects all four `ExtPorts` fields, not one — and applied literally it rejects the very remedy D5's clock gate mandates three bullets earlier

**Defect:** ADR:1054-1055 defines classifier 2 as "the fields of `ExtPorts` … **that do not yet return
world state** — today `ai_step`". None of the four fields returns world state. The parenthetical
"today `ai_step`" is the intended set; the criterion is not the criterion that produces it.

**Grounding:**

```text
$ sed -n '62,67p' packages/motoko-ext-abi/types.ail
export type ExtPorts = {
  ai_step: (string, [Msg]) -> Result[string, string] ! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream},
  proc_exec: (string, string) -> string ! {IO, Process, FS},
  clock_now: () -> int ! {Clock},
  env_get: (string, string) -> string ! {Env}
}
```

`Result[string, string]`, `string`, `int`, `string` — four non-world-mediated returns. The ADR's own
framing agrees that nothing is world-mediated yet: D5:956-960 requires "an explicit/opaque world token
… and return the successor token with the hook decision", which no field does.

**The contradiction this creates is load-bearing, not academic.** D5:974-977 makes routing *into*
`ExtPorts.clock_now` the condition of conformance for a clock-reading extension:

> a profile installing `compose` cannot claim conformance until its eight clock reads route through
> `ExtPorts.clock_now`

D5:980-982 then fails profile-definition validation closed "when an installed extension references a
non-world-mediated `ExtPorts` field from a hook the profile has not excluded". Under the stated
criterion `clock_now` is a non-world-mediated field, so a `compose` profile that does what :976-977
requires becomes a profile-definition rejection under :981-982. The prescribed remedy triggers the
prescribed rejection, six lines apart.

**"Retired field by field" is decorative under the narrow reading and unbudgeted under the wide one.**
If the set is `{ai_step}`, a one-element set does not retire field by field. If it is all four, the
world-token widening Consequences budgets (ADR:1505-1510: "`ExtPorts.ai_step`, the hook results that
carry its outcome, and the core dispatch results") covers only one of them, and the other three need
their own ABI majors that nothing schedules.

**Action:** state the criterion that actually selects `ai_step`, which is not "does not return world
state" but *"is the extension-side entry to a core seam that D1 requires to thread a cursor, and
cannot return it"* — `Ports.model_step`'s successor is the only cursor D1 currently demands, so
`ai_step` is the only member today. Then say explicitly that `clock_now`, `proc_exec`, and `env_get`
are **not** classifier-2 members in the interim and why, because D5:976-977 depends on `clock_now`
being a legal routing destination. If the intended set really is all four, say so and reconcile
:976-977, or the clock gate is unreachable.

### R3. "Every hook that can reach the port" is a call-graph property with no instrument, in the same document that just built one for the structurally identical core problem — and four sites state three different predicates

**Defect:** D1:365 makes the rejection turn on "excluding every hook that **can reach** the port".
Classifier 2 (ADR:1056) inventories "their **field-reference sites**" — textual, at site granularity.
Nothing maps a reference site to the hooks that can reach it. Clause 3 solved exactly this problem for
core, three hundred lines earlier, with a versioned site-to-hook attribution table; classifier 2 gets
no such instrument.

**Grounding:** the mapping the rule needs, re-derived rather than inherited, is four call-graph edges
across two modules with a self-recursive callee:

```text
$ grep -n "compact_with_ai\|summarize_with_ai_result\|summarize_attempt\|ports.ai_step" \
    packages/motoko-ext-compaction-ai/register.ail packages/motoko-ext-compaction-ai/compaction_ai.ail
register.ail:103:    on_pre_step: func(ctx: ExtCtx, msgs) -> PreStepDecision ! {...} {
register.ail:104:      compact_with_ai(ctx, msgs, compaction_cfg)
compaction_ai.ail:498:export func compact_with_ai(ctx: ExtCtx, msgs: [Msg], cfg: CompactionAiConfig) -> PreStepDecision ! {...}
compaction_ai.ail:484:    else match summarize_with_ai_result(ctx, summarization_prompt(...), cfg.model) {
compaction_ai.ail:515:          else match summarize_with_ai_result(ctx, update_summarization_prompt(...), cfg.model) {
compaction_ai.ail:119:export func summarize_with_ai_result(ctx: ExtCtx, prompt: string, model: string) -> Result[string, string] ! {...}
compaction_ai.ail:120:  summarize_attempt(ctx, prompt, model, summarizer_max_attempts())
compaction_ai.ail:104:func summarize_attempt(ctx: ExtCtx, prompt: string, model: string, attempts_left: int) -> Result[string, string] ! {...}
compaction_ai.ail:106:  match ctx.ports.ai_step(model, prompt_msgs) {
```

That is a manual walk. ADR:865-866 says of the identical shape in core: "Clause 3 is answered by an
explicit recorded artifact, **not by inspection**." Classifier 2 asks for inspection.

**The predicate also drifts across the four sites the split is asserted at**, which is what makes the
gap hard to see:

| Site | Predicate |
|---|---|
| D1:365 | hook that **can reach** the port (call-graph) |
| D5:941 | extension that **reaches a non-world-mediated seam** (call-graph, and *seam* is broader than `ExtPorts` field — `Ports.model_step` is a seam) |
| D5:981-982, ADR:1056-1058 | extension that **references** a non-world-mediated `ExtPorts` **field** (textual, site granularity) |
| Acceptance row ADR:1397 | extension **reaching** a non-world-mediated `ExtPorts` field from an un-excluded hook |

D5:941's "seam" is the widest and, read literally at HEAD where nothing is routed, would reject every
extension-installing profile. The textual "references" is the only one a detector can answer.

**Failure scenario:** a profile author greps for `ports.ai_step`, finds
`packages/motoko-ext-compaction-ai/compaction_ai.ail:106`, and must now decide *which hooks to
exclude*. With no attribution artifact the safe answer is "all of them" and the ADR's answer is
"`on_pre_step`" (ADR:373) — but nothing in the ADR licenses the narrower one, so two authors reading
the same text ship different profiles and only one of them is conservative.

**Action:** pick one predicate and give it the instrument clause 3 already has. The cheapest sound
rule needs no call-graph at all: **an installed extension with any classifier-2 field reference is
rejected unless every hook it registers is excluded.** That is decidable from a grep plus the
extension's `register.ail`, it is conservative, and it costs only the ability to keep one hook of a
referencing extension. If the narrower per-hook rule is wanted instead, extend clause 3's versioned
site-to-hook attribution table to cover extension packages and say that classifier 2 reads it —
which also gives the table a second consumer and makes R5 below cheaper to answer.

### R4. Implementation Handoff item 2 still says an `ai_step`-installing profile is non-conformant — the exact claim this pass overturned, in the third of the three sites both fourth-pass reviews named

**Defect:** the pass corrected D1 (:353-378) and Consequences (:1511-1516) but not Handoff item 2,
which still carries the overturned strong reading.

**Grounding:**

```text
$ awk 'NR>=1558 && NR<=1561' .agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md
   **This item does not fix the extension model path**, and that is a decision, not an oversight:
   `ext_ai_step` reaches the same seam through an ABI that cannot return a successor (D1). It fixes
   the main loop, and profiles installing an `ai_step`-calling extension stay non-conformant until
   the world-token ABI lands.
```

Against ADR:353 ("That is a coverage cost, **not a conformance disqualification**") and ADR:939
("Exclusion is a coverage cost, not a conformance disqualification"). The tenth section's R2 named the
three sites as ADR:344-345, ADR:1430, ADR:1477; the eleventh named ADR:339-343, :1423-1433, :1475-1478.
Both included the Handoff item. Two of three were fixed.

**Failure scenario:** the Implementation Handoff is the section a plan author reads *first and often
only*. It tells them the interim milestone cannot produce a conformant profile from any shipped
configuration, which is the conclusion this pass exists to retract.

**Action:** at ADR:1560, replace "stay non-conformant until the world-token ABI lands" with "are
conformant only by excluding every hook that reaches the port — a coverage cost, and a
profile-definition rejection if they do not (D1, D5)". Then re-grep `non-conformant`,
`conformance-eligible`, and `disqualif` across the body before committing; the same grep is what would
have caught this one.

### R5. The site-to-hook attribution table is a required artifact with no producer, no validator, no schema, and no slot in the versioned profile definition it is named after

**Defect:** clause 3 now turns on "the profile's **versioned** site-to-hook attribution table"
(ADR:862-863) and gives it a fail-closed default (ADR:878-882). It gives it nothing else — and the
versioned profile definition that enumerates what a profile records does not list it.

**Grounding:** the profile-definition record, in full:

```text
$ awk 'NR>=910 && NR<=919' .agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md
A versioned profile definition records:
- profile id/version;
- included extension ids and per-hook classifications (effect-free, world-mediated, or explicitly
  excluded);
- included and excluded provider/tool adapter and parser boundaries;
- logical resource models promised by the profile;
- permitted diagnostic projections;
- forbidden ambient effects/capabilities during execution; and
- every required D3 fault class the profile waives, each with the condition that waives it.
```

Seven bullets, none of them the attribution table. The execution manifest (ADR:921-923) lists source
revision, toolchain, package versions, ABI version, profile id/version, event-vocabulary version, and
normalized configuration — also not it. So the artifact clause 3 calls "the profile's versioned …
table" is versioned by nothing and stored nowhere.

**The contrast with D6 is the measure of the gap.** The event-vocabulary artifact (ADR:1207-1240) gets
enumerated contents, an explicit "this is new construction" ruling, a fail-closed validator at load, a
scheduling prohibition on dependent checks until it exists, a preferred derivable form that makes
drift a compile error, a manifest slot, and a version-change rule. The attribution table gets a name
and a default.

**Failure scenario:** the plan schedules the routing audit, discovers there is no table, and either
writes one by hand — reintroducing the hand-maintained-list rot ADR:1038-1041 rejects for classifier
1 — or falls back to clause 1 for every core effect site, which raises the driver's clock obligation
from four to five and makes D4's 4 / 12 / 13 arithmetic wrong.

**Action:** add the table to the ADR:910-919 record as an eighth bullet, and specify the three things
D6 got and this did not: **what makes an attribution correct** (a claim that the named hook's
installation is a necessary condition of the site executing — not that it is sufficient, per
ADR:880-882), **when it is validated** (at profile load, failing closed on a site not in the table and
not in core-unconditional), and **who produces it** (construction, in the same change that builds the
classifiers). Also state the D6-style scheduling prohibition: no D4 routing-completeness claim before
the table exists, because until then "four driver reads" is not derivable.

### R6. The Status header undercounts delta reviews for the second consecutive pass, and contradicts itself three lines later and again at line 29

**Defect:** ADR:6-7 now says "**four independent delta reviews (two of the second correction pass, two
of the third)** … recorded below". Six are recorded below at this commit. The pass applied both
fourth-pass R6 actions verbatim — correct at `81b0a89`, stale at `e8242f1`, because the two fourth-pass
reviews were themselves committed into the ADR at the baseline `b042757`.

**Grounding:**

```text
$ grep -n "^## Review Comments" .agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md
1698 2158            <- two full reviews, 2026-07-26
2635 2950 3229       <- three F1-F6 verifications
3616 4021            <- two delta reviews, second correction pass
4299 4749            <- two delta reviews, third correction pass
5135 5590            <- two delta reviews, FOURTH correction pass (baseline b042757)
```

Six delta reviews, not four. Two further inconsistencies inside the same block:

- ADR:9 was not touched and still reads "**the two delta reviews** returned *Revise* and converged on
  another" — three lines under a corrected count of four. The eleventh section's R6 action asked for
  exactly this ("revise the defect-set count so the opening agrees"); the tenth's did not, and the
  pass followed the tenth.
- ADR:29-32 says "**The four delta reviews** additionally confirmed … and — **in the fourth-pass
  round**, by two independent three-module probes — that the … exclusion is the right disposition".
  It attributes to "the four" a ruling from a round the parenthetical at :6-7 excludes from the four.

**Action:** "six independent delta reviews (two each of the second, third, and fourth correction
passes)"; update ADR:9 to match; and drop "in the fourth-pass round" at :30 or keep it and let the
count include that round — one or the other, not both.

### R7. `compaction_ai` does not have one hook — it registers seven, and excluding only `on_pre_step` is not obviously sufficient under D5's own hermeticity clause

**Defect:** ADR:373 says excluding `compaction_ai`'s `on_pre_step` "disables the extension's **only**
hook". The extension registers seven hooks.

**Grounding:**

```text
$ awk 'NR>=99 && NR<=110' packages/motoko-ext-compaction-ai/register.ail
    provided_tools: [],
    on_describe_tools: \_ . [],
    on_build_system_prompt: \_ . { prepend: [], append: [] },
    on_budget_plan: \_ _ . { ... } ! {Env, FS},
    on_pre_step: func(ctx: ExtCtx, msgs) -> PreStepDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream} {
      compact_with_ai(ctx, msgs, compaction_cfg)
    },
    on_tool_policy: \_ _ . Allow,
    on_tool_handle: \_ _ . Delegate ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
    on_response_intercept: \_ _ . NoIntercept ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
    on_solver_candidate: \_ _ . NoDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}
```

The **conclusion** survives — the other six are constant-returning lambdas, so excluding `on_pre_step`
does leave the extension inert on the compaction path, which is what the paragraph is arguing. The
stated fact does not.

**The secondary point is not cosmetic.** Three of the six trivial lambdas *declare*
`{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}` while performing nothing. D5:949 fails a
profile on "direct `AI`, `Process`, `Net`, `FS`, `SharedMem`, `Clock`, environment, or random effects
from a reached hook", and D5's per-hook classification (ADR:913-914) admits only effect-free,
world-mediated, or excluded. Whether a declared-but-unperformed row classifies as effect-free is
undecided here, and ADR:1104 concedes the reconciling detector "is not available today". Under the
declared-row reading, four hooks need exclusion, not one.

**Action:** "its only non-trivial hook, and the only one that reaches the port" at ADR:373. Separately,
state whether per-hook classification reads declared or performed effect rows in the interim — the
answer changes how many hooks a `compaction_ai` profile must exclude, and the successor detector that
would settle it is explicitly deferred.

### R8. The replacement compose anchor is wrong — `on_response_intercept` is `:761-790`, not `:761-771` — making this the fifth consecutive pass to ship an anchor error, in the edit whose only purpose was to fix an anchor

**Defect:** ADR:781 now reads "(`packages/motoko-ext-compose/compose.ail:767`, inside
`on_response_intercept` at `:761-771`)". The `:767` half is correct. The range asserts the function's
extent and is nineteen lines short.

**Grounding:**

```text
$ awk 'NR==761 || NR==771 || NR==790 || NR==792 {printf "%d: %s\n", NR, $0}' packages/motoko-ext-compose/compose.ail
761: export func on_response_intercept(ctx: ExtCtx, response_text: string, mode: string, snippet_caps: string) -> ResponseInterceptDecision ! {IO, Process, FS, Clock} {
771:       let _ = writeFile(path, "${compose_module_header(name)}\n\n${clean}");
790: }
792: func no_budget_patch() -> BudgetPatch {
```

`:771` is a `writeFile` in the middle of the inner `else` block; the function closes at `:790`. Both
fourth-pass reviews proposed "`:761-771` or simply `:767`" without stating the function's extent, and
the pass adopted the range *and* attached the words "`on_response_intercept` at" to it, converting a
loose citation into a false claim.

**A second, smaller instance in the same pass.** ADR:885-886 says `emit_dummy_hook` sits "behind five
call sites all of the form `if is_test_dummy(h.id) then emit_dummy_hook(...)` (`:206`, `:222`, `:245`,
`:287`, `:374`)". Three of those five lines are not of that form:

```text
$ grep -rn "is_test_dummy\|emit_dummy_hook" src/core/ext/runtime.ail
206:      let _ = if is_test_dummy(h.id) then emit_dummy_hook("on_build_system_prompt", ...) else ();
222:      let _ = if is_test_dummy(h.id) then emit_dummy_hook("on_budget_plan", ...) else ();
239:      let _ = if is_test_dummy(h.id) then {
245:        emit_dummy_hook("on_pre_step", "decision", tag)
280:  let _ = if is_test_dummy(h.id) then {
287:    emit_dummy_hook("on_tool_policy", "decision", tag)
368:  let _ = if is_test_dummy(h.id) then {
374:    emit_dummy_hook("on_solver_candidate", "decision", tag)
```

The guards are `206, 222, 239, 280, 368`; the calls are `206, 222, 245, 287, 374`. The count of five is
right and the tenth section stated both lists correctly; the pass merged them and cited the call lines
under the guard's syntactic form.

**Action:** `:761-790`, or drop the range and cite `:767` alone. At ADR:885-886, either cite the guard
lines with the guard form, or say "five `emit_dummy_hook` calls (`:206`, `:222`, `:245`, `:287`,
`:374`), each guarded by `if is_test_dummy(h.id)` (`:206`, `:222`, `:239`, `:280`, `:368`)". And
update ADR:68 — "anchor errors in four consecutive passes" is now five.

## What is accurate

Everything below was re-run at `e8242f1` on `AILANG v0.26.0`, not inherited from any prior section.

**Classifier 1's corrected label and module arithmetic — every number confirmed.**

```text
$ ailang builtins list -json | python3 -c "..."
total rows: 324 | effect-bearing rows: 115 | pure rows: 209
output groups (Pure + effects): 18
effect labels (is_pure==false): 17
modules from effect-bearing rows: 21, non-std/* among them: []
$ python3 -c "import re; ... ailang.toml max"
12 ['IO','Env','AI','Net','FS','Process','SharedMem','Clock','Stream','SharedIndex','Rand','Trace']
```

"Seventeen effect labels plus `Pure`" is exact; `[effects] max` is twelve at `ailang.toml:54`; the two
enumerations do disagree, so neither alone is a classifier. `Pure` is the largest group (209 of 324),
and projecting `module` over *all* rows would include `std/list`, `std/string`, `std/json` and the rest
of the pure surface — so "`Pure` must be filtered out explicitly" is a real and necessary instruction.
Every `is_pure == false` row does carry a real `std/*` module; there are no `$builtin`/`core` rows in
the effect-bearing set. The "module plus exported symbol" diagnosis is correct: the emitted `name` is
the internal builtin and no row carries `now`. **The correction the two fourth-pass reviews prescribed
was necessary and is faithfully applied. R1 is that it is not sufficient, which neither review tested.**

**D4's clock arithmetic survives the clause-3 rewrite unchanged.** Re-derived, not inherited:

```text
$ grep -rn "now()" src packages --include=*.ail
```

Thirteen live reads — `session.ail:791, 842, 1991, 2089` (`:785` is a comment), `ext/runtime.ail:190`,
`compose.ail:362, 503, 597, 651, 681, 767`, `author_tools.ail:101`, `authoring/dispatcher.ail:217`. The
four `noop_clock_now` *definitions* (`ctx_defaults.ail:15`, `progress_contract_guard.ail:144`,
`harness.ail:40`, `empty_stop_guard.ail:60`) match the grep on their names only and are not reads.
4 / 12 / 13 holds for the three installation cases, and clause 3's new form preserves it: attributing
`:190` to `test_dummy` keeps the driver obligation at four rather than five, which is what the table
needs. Nothing is routed at HEAD.

**Configuration facts.** Fourteen tracked `.motoko/config/*/config.json`, all fourteen with
`compaction_ai` in `extensions.order`, none without. The "all fourteen" correction is right at all
three sites (ADR:372, :1513, and the Status block).

**Anchors confirmed.** `packages/motoko-ext-abi/types.ail:62-67` is exactly the `ExtPorts` declaration
through its closing brace. `src/core/tool_phase.ail:222` is exactly
`if is_scratchpad_tool_name(envelope.tool) && scratchpad_extension_active(rt) then {`, and it is a real
live mixed guard over an effectful call at `:223` — the motivating counterexample is correctly stated.
`src/core/ext/runtime.ail:206, 222, 245, 287, 374` are the five `emit_dummy_hook` calls, and the count
of five is now right (subject to R8's form/line conflation).
`packages/motoko-ext-compaction-ai/compaction_ai.ail:106` is `match ctx.ports.ai_step(model,
prompt_msgs) {`. `packages/motoko-ext-compose/compose.ail:767` is the response-intercept clock read.
Only the `:761-771` range is wrong.

**The Status block's corrected metric — both numbers recounted independently, both right.** I
enumerated the `### R` headings in all four rounds rather than trusting the tenth section's arithmetic:

```text
second-pass round: 7 findings (ADR:3638-3857) + 8 (ADR:4032-4193) = 15
third-pass round:  6 findings (ADR:4329-4574) + 6 (ADR:4778-4990) = 12
```

*Anchor/provenance, second pass:* Claude R4 (`175-204`), R5 (two anchors off by one), R7 (`88-99`);
Codex R5 (omitted edit account), R6 (two source ranges), R7 (off by one) = **six of fifteen** ✓.
*Third pass:* Claude R6 (ADR:4574) and Codex R6 (ADR:4990), both on `stub_step.ail`'s deferred comment
range = **two of twelve, both on the same range** ✓. *Provenance alone:* Codex R5 is the only
second-pass member — Claude's R6 and Codex's R8 are about a handoff overstating a verification count,
which is a different category and defensibly excluded — and the third-pass round has none, so **one of
fifteen against none** ✓. The retraction is honest and the arithmetic behind it holds. This is the
one place the pass improved on its own inputs rather than transcribing them.

**Collateral that is clean.** D11 (ADR:1348-1374) carries class-reached and branch-reached counters and
no hook-coverage counter, so nothing there contradicts the split. The profile-definition record's
per-hook classifications — "effect-free, world-mediated, or **explicitly excluded**" (ADR:913-914) —
are exactly the three categories the split needs, and an un-excluded reaching hook is unclassifiable
under them, which is the right shape for a definition-time rejection. Consequences (ADR:1505-1516) is
correctly rewritten. The acceptance row (ADR:1397) is correctly rewritten in substance, though
"validation **rejected no** installed extension reaching…" is ambiguous between "found nothing to
reject" (intended) and "failed to reject" (the defect); "no installed extension … was rejected, and
none required rejection" would not be.

### Ruling 1 — is the coverage/rejection line in the right place, and does it have a detector? (A1)

**The line is in the right place, the timing argument is sound, and the detector does not exist.**

*Axis 1 — timing.* Sound, and I verified both halves against D5's machinery. An excluded hook that
dispatch reaches raises a fail-closed `HarnessFailure` (ADR:935-937), so it is a run-time-detectable
event and a coverage bookkeeping question. An un-excluded hook that reaches `ai_step` returns
`Result[string, string]` (`types.ail:63`) into a decision-only `PreStepDecision`, so the successor has
nowhere to go and the run completes normally with the cursor silently dropped — no failure, no counter,
no trace record. The two failures genuinely differ in detectability, and that asymmetry is the correct
reason to move one to definition time. **This is the pass's best work and neither review proposed it.**

*Axis 2 — "can reach".* It does reintroduce the trap. See R3: the predicate is a call-graph property,
classifier 2 is a textual site inventory, and clause 3 built the missing instrument for the identical
problem in core without extending it here. **Ruling: the same instrument should govern classifier 2**,
or the rule should be restated at extension granularity where a grep decides it. Nothing else in the
ADR closes this.

*Axis 3 — is "conformant and inert" worth having?* **Yes, and it is bookkeeping rather than
laundering — but the ADR should say one more sentence than it does.** The claim a conformant-and-inert
profile makes is narrow and true: *this* profile's world is honest about *its* boundary, and the paths
it does not test are named. That is exactly what D5's honesty criterion is for, and refusing the label
would mean a profile becomes non-conformant by installing something it then correctly excludes — which
punishes disclosure. The laundering risk is real but lives one level up, in what a *reader* does with
the word: ADR:377-378 already anticipates it ("must not be planned as though it delivers a conformant
*and covering* `default`"). What is missing is the acceptance-side consequence: D11 reports coverage
counters but nothing requires a profile to *have* non-zero hook coverage, so "conformant" is currently
satisfiable by a profile that excludes everything. **Add a floor** — a conformant profile must cover at
least one hook of every extension it installs, or must declare the extension itself excluded rather
than installed-and-fully-excluded. That closes the laundering path without weakening the split.

*Axis 4 — consistency.* Substantively consistent at all four sites; the *predicate* is not (R3's
table). D1:365, D5:941, D5:981-982, ADR:1056, and ADR:1397 use "can reach", "reaches a seam",
"references a field", and "reaching a field" for what must be one rule.

### Ruling 2 — is classifier 2's scope correctly bounded? (A2)

**No.** The set as defined by the ADR's own criterion is all four `ExtPorts` fields; the set the ADR
names is one; and the gap is not cosmetic because D5:976-977 makes `ExtPorts.clock_now` the mandatory
routing destination for the clock gate, which the criterion then rejects (R2). The handoff's framing —
"the ADR says the former and means the latter" — is exactly right, and the latter needs to be written
down. "Retired field by field" is decorative if the set is `{ai_step}` and unbudgeted if it is not.

Classifier 2's *soundness boundary by reference* to classifier 1's, however, does transfer correctly:
classifier 1's three stated limits (ADR:1080-1089) are out-of-tree effects, non-reachability, and roots
outside `src` + `packages`, and all three apply verbatim to an ABI-field scan. The alias/wrapper caveat
at ADR:1061-1063 is an honest addition and I confirmed nothing at HEAD aliases `ai_step` — the only two
reference sites are `compaction_ai.ail:106` and
`packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90`.

### Ruling 3 — is clause 3's attribution table an artifact or an intention? (A3)

**An intention.** It has a name, a versioning adjective, a fail-closed default, and a correct
semantics clause (ADR:880-882: attribution is necessity, not sufficiency — which is the right choice
and answers the mixed-guard problem properly). It has no producer, no validator, no schema, no storage
location, and no slot in the seven-bullet profile-definition record that is supposed to version it
(R5). Measured against D6's event-vocabulary artifact in the same document, it is missing five of the
six things that made D6 buildable.

*On the sub-question of whether failing closed into clause 1 is always conservative:* **for the routing
gate, yes** — clause 1 forces routing, and routing a site no run reaches costs work, not correctness.
I found no case at HEAD where it is the wrong answer rather than the expensive one. One boundary worth
recording: ADR:962-965 places host configuration discovery, package hydration, and child-process setup
*outside* the simulation boundary, so a core effect site that is genuinely pre-boundary would be forced
by clause 1 into a routing obligation the ADR elsewhere says it does not have. No such site exists
today — all four driver clock reads are already ruled in-scope by D4 — but the two rules have not been
reconciled and the table is where that reconciliation would live.

### What I could not clear

The upstream blocker is untouched by this pass and unchanged. The reviewed range ships no
recorded-stream API in an AILANG release, does not repin this repository, and passes no positive
integration probe. `arniwesth/ailang`'s `stepWithStreamRecorded` on the `v0.31.0` tag is a prototype
and satisfies none of D1's three conditions.

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. **R2** — restate classifier 2's criterion so it selects `ai_step` and not `clock_now`, and reconcile
   with D5:976-977. Everything about the split's detector is downstream of what the set *is*.
2. **R1** — close classifier 1's derivation. It is the more severe defect but is independent of (1),
   and the two belong in one edit so the classifiers stay specified side by side. Do not ship a third
   revision without checking the derived set against the repo's actual `std/*` imports; that check is
   two commands and is what the last two revisions both skipped.
3. **R3** — pick one predicate for the rejection rule and give it an instrument. If the extension-
   granularity rule is chosen, this closes without new machinery. If the per-hook rule is kept, it
   depends on (5).
4. **R4** — correct Handoff item 2, then re-grep the body for the overturned vocabulary.
5. **R5** — give the attribution table the D6 treatment: an eighth bullet at ADR:910-919, a load-time
   fail-closed validator, a correctness criterion, and a scheduling prohibition on D4
   routing-completeness claims until it exists.
6. **R6, R7, R8** — the three precision corrections, independent of each other and of the above.
   Recount the review sections at the commit being written, not at the commit being answered.

**Belongs to the implementation plan, not this ADR:**

- Building both classifiers and wiring their repin re-derivation; neither is in CI, the Makefile, or
  `scripts/` today.
- Producing the first attribution table, once the ADR says what one is.
- Naming the first purpose-built narrow conformant profile and validating it against the R3 detector.
  Still unnamed, as the tenth section flagged; `empty_stop_guard` and `progress_contract_guard` remain
  the obvious candidates.
- Whether per-hook classification reads declared or performed effect rows (R7's second half), and the
  `ProviderState` field shape and approval/clock cursor question the fourth-pass round deferred.
- The `stub_step.ail:171-173` deletion.

## Accept / revise recommendation

**Revise — the pass's central judgment is right and better than either review that prompted it: the
coverage-versus-rejection split is correctly placed, its timing argument is sound and verified against
D5's machinery, "conformant and inert" is honest bookkeeping rather than laundering, clause 3's
attribution semantics (necessity, not sufficiency) is the correct answer to the mixed-guard problem,
and the Status block's self-correction is the first metric in this document that survives an
independent recount. But R1 leaves classifier 1 fail-open on a live `SharedMem` site in the core
driver — the third consecutive revision of that obligation to fail open, and the first to do so on
evidence sitting in `src/core`; R2 leaves classifier 2's stated criterion rejecting the clock gate's
own mandated remedy; R3 leaves the rejection rule without the attribution instrument clause 3 just
built for the identical problem; and R4 leaves the overturned "non-conformant" claim standing in the
section a plan author reads first. The upstream API blocker is untouched by this pass and remains
fully in force — it still requires the recorded-stream API in an actual AILANG *release*, this
repository repinned to that release, and the positive integration probe passing; the `v0.31.0` fork
prototype satisfies none of the three.**

**Residual risk if the six actions land as recommended:** the classifiers remain textual and inherit
their stated soundness boundary — an `ai_step` reached through an alias or a re-exported wrapper is
still invisible, and nothing prevents one; the stdlib-source scan proposed in R1's action is itself a
textual derivation over a directory the toolchain owns, so a stdlib module whose effects arrive
through a mechanism neither builtins nor `export func … ! {…}` expresses would still be missed;
neither classifier has a CI mechanism, so "re-derived on every repin" remains a process obligation
carried by a milestone rather than a check; and the first conformant profile is still unnamed, so
"purpose-built narrow one" is a claim the plan, not this ADR, will have to make good.

## Review Comments

_Reviewer: Codex (model: `GPT-5`), 2026-08-01. Independent delta review of the fifth correction
pass. Reviewed commit: `e8242f1570078337c203606b6ae5792108628876`. Target range:
`b0427570cff3dcc8128b7ac7062c1081413f7ea9..e8242f1570078337c203606b6ae5792108628876` over
`.agent/projects/009_motoko_dst_execution/`._

_The reviewed commit contains eleven `## Review Comments` sections. This is the thirteenth heading in
the current worktree because a pre-existing uncommitted twelfth section was retained verbatim at the
user's direction. Later handoff/visualization commits and `mmd/` are outside the reviewed range. The
target range itself is one commit, one changed file, 146 insertions and 63 deletions._

### R1. Classifier 1's corrected builtin projection is still fail-open because source-defined effectful stdlib modules need not have an impure builtin row

**Defect:** Filtering builtin rows on `is_pure == false` and projecting `module` omits at least
`std/sem` and `std/extension`, even though the pinned stdlib gives them concrete `Clock`, `SharedMem`,
`SharedIndex`, and `FS` operations used under the classifier's `src` + `packages` roots.

**Grounding:** exact commands and output from pinned AILANG v0.26.0:

```text
$ ailang builtins list -json | python3 -c 'import json,sys; d=json.load(sys.stdin)["builtins"]; ms={b["module"] for b in d if b["is_pure"] is False}; print("modules",len(ms)); print("std/sem in set", "std/sem" in ms, [(b["name"],b["is_pure"],b.get("effect")) for b in d if b["module"]=="std/sem"]); print("std/extension in set", "std/extension" in ms, [(b["name"],b["is_pure"],b.get("effect")) for b in d if b["module"]=="std/extension"])'
modules 21
std/sem in set False [('_embedding_decode', True, None), ('_embedding_encode', True, None)]
std/extension in set False []

$ rg -n 'export func (make_frame|load_frame|store_frame|requireWorkdirFile).*![[:space:]]*\{' /home/motoko/.local/share/ailang/std/sem.ail /home/motoko/.local/share/ailang/std/extension.ail
/home/motoko/.local/share/ailang/std/extension.ail:27:export func requireWorkdirFile(workdir: string, rel: string) -> Result[(), string] ! {FS} =
/home/motoko/.local/share/ailang/std/sem.ail:191:export func make_frame(id: string, content: string, opaque: bytes) -> sem_frame ! {Clock} {
/home/motoko/.local/share/ailang/std/sem.ail:374:export func load_frame(key: string) -> Option[sem_frame] ! {SharedMem} {
/home/motoko/.local/share/ailang/std/sem.ail:385:export func store_frame(key: string, frame: sem_frame) -> unit ! {SharedMem} {
/home/motoko/.local/share/ailang/std/sem.ail:466:export func store_frame_ns(ns: namespace, frame: sem_frame) -> unit ! {SharedMem, SharedIndex} {
```

The omitted modules are used at `src/core/cache.ail:29,60,75`,
`packages/motoko-ext-context-mode/context_mode.ail:6,19,28,36,45`, and
`packages/motoko-ext-omnigraph/register.ail:4,26`.

**Action:** derive classifier 1 from the complete pinned stdlib interface/source surface as well as
the builtin registry, and treat an imported `std/*` module not proven effect-free as a fail-closed
candidate. Add a required comparison between the derived set and the repository's actual `std/*`
imports before the routing inventory may be cited.

### R2. Classifier 2's criterion selects all four `ExtPorts` fields while its asserted result names only `ai_step`, making D5's clock remedy reject itself

**Defect:** “Fields that do not yet return world state” describes `ai_step`, `proc_exec`, `clock_now`,
and `env_get`, not only `ai_step`; under that literal set, routing `compose` reads through
`ExtPorts.clock_now` as D5 requires triggers classifier 2's own profile-definition rejection.

**Grounding:** `packages/motoko-ext-abi/types.ail:62-67` is:

```text
export type ExtPorts = {
  ai_step: (string, [Msg]) -> Result[string, string] ! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream},
  proc_exec: (string, string) -> string ! {IO, Process, FS},
  clock_now: () -> int ! {Clock},
  env_get: (string, string) -> string ! {Env}
}
```

D5 requires a `compose` profile's reads to route through `ExtPorts.clock_now` at ADR:974-977, then
rejects un-excluded references to a non-world-mediated field at ADR:980-982. Classifier 2's
“retired field by field” text is also unsupported: the consequence scheduled at ADR:1505-1510 is one
ABI-major widening centered on `ai_step`, not four independently scheduled retirements.

The reference to classifier 1's soundness boundary is only partly transferable. Fixed scan roots and
the refusal to decide reachability apply to both scans; classifier 1's out-of-tree ambient-effect
limit is not by itself a boundary definition for an ABI-field matcher, which instead needs its own
alias, re-export, computed-field, and wrapper rules. ADR:1061-1063 names only part of that boundary.

**Action:** define the set by the property the ADR means: fields whose call loses successor state that
D1 requires the underlying core seam to return — today `ai_step`. Explicitly state why `proc_exec`,
`clock_now`, and `env_get` are not classifier-2 members under this interim rule; replace or precisely
explain “retired field by field”; and state classifier 2's own matching/soundness boundary.

### R3. The coverage-versus-rejection split has the right timing but no detector for its per-hook “can reach” predicate

**Defect:** Classifier 2 inventories textual field-reference sites, while D1 rejects a definition
unless every hook that *can reach* each site is excluded; no specified artifact or analysis maps an
extension reference site to its reaching hooks.

**Grounding:** the only live production `ctx.ports.ai_step` reference is
`packages/motoko-ext-compaction-ai/compaction_ai.ail:106`, but attributing it to `on_pre_step` requires
this manual chain:

```text
$ rg -n 'compact_with_ai|summarize_with_ai_result|summarize_attempt|ports\.ai_step' packages/motoko-ext-compaction-ai/register.ail packages/motoko-ext-compaction-ai/compaction_ai.ail
packages/motoko-ext-compaction-ai/register.ail:104:      compact_with_ai(ctx, msgs, compaction_cfg)
packages/motoko-ext-compaction-ai/compaction_ai.ail:104:func summarize_attempt(...)
packages/motoko-ext-compaction-ai/compaction_ai.ail:106:  match ctx.ports.ai_step(model, prompt_msgs) {
packages/motoko-ext-compaction-ai/compaction_ai.ail:119:export func summarize_with_ai_result(...)
packages/motoko-ext-compaction-ai/compaction_ai.ail:120:  summarize_attempt(...)
packages/motoko-ext-compaction-ai/compaction_ai.ail:484:    else match summarize_with_ai_result(...) {
packages/motoko-ext-compaction-ai/compaction_ai.ail:498:export func compact_with_ai(...)
packages/motoko-ext-compaction-ai/compaction_ai.ail:515:          else match summarize_with_ai_result(...) {
```

The four normative statements also drift: D1:365 says “can reach the port”; D5:941 says “reaches a
non-world-mediated seam”; D5:981-982 and classifier 2 say “references a ... field”; and the acceptance
row at ADR:1397 says “reaching a ... field from an un-excluded hook.” Only the reference-site
predicate is answered by the named textual scan.

**Action:** use one predicate everywhere. Either extend the versioned site-to-hook attribution
artifact to extension-package classifier-2 sites and make validation consume it, or adopt the coarser
mechanical rule that any installed extension containing such a reference must exclude every hook it
registers. The narrower per-hook rule is not a gate until one of those detectors exists.

### R4. Clause 3's site-to-hook attribution table is an intention, not a specified artifact, and an incorrect attribution can still fail open

**Defect:** The table has a name and a conservative default but no producer, schema, storage/version
slot, correctness rule, drift check, or validator, so nothing prevents falsely attributing an
unconditional site to an uninstalled hook and removing it from the routing obligation.

**Grounding:** clause 3 introduces the table at ADR:862-866 and its un-attributed fallback at
ADR:878-882. The complete versioned profile record at ADR:910-919 has seven fields and does not include
the table; the manifest at ADR:921-923 does not include it either. By contrast, D6's event-vocabulary
artifact at ADR:1207-1240 specifies contents, load-time validation, a manifest slot, a version-change
rule, and a prohibition on scheduling dependent checks before it exists.

Failing an *un-attributed* in-boundary core site into clause 1 is conservative: it forces excess
routing rather than omitting routing. That does not protect against a wrong positive attribution, and
the mechanical rule should be scoped explicitly to effect sites after the simulation boundary at
ADR:962-965 so pre-boundary setup is not silently pulled into the world.

**Action:** add the table to the versioned profile definition and specify: the construction owner; a
source-revision-bound schema; the correctness condition that site execution implies activation of at
least one attributed hook; how that implication is derived or independently checked; load-time
validation that fails closed on missing, stale, unknown, or malformed entries; and a prohibition on
D4/D5 routing-completeness claims before the table exists and validates. Then use the same artifact
for R3 if the per-hook classifier-2 rule is retained.

### R5. Implementation Handoff item 2 still states the conformance claim that this pass says it overturned

**Defect:** The handoff still says every profile installing an `ai_step`-calling extension remains
non-conformant, contradicting the new coverage-cost/profile-rejection split in D1, D5, Consequences,
and the acceptance table.

**Grounding:** ADR:1558-1561 says:

```text
**This item does not fix the extension model path**, and that is a decision, not an oversight:
`ext_ai_step` reaches the same seam through an ABI that cannot return a successor (D1). It fixes
the main loop, and profiles installing an `ai_step`-calling extension stay non-conformant until
the world-token ABI lands.
```

The contrary corrected statements are ADR:353-378, ADR:939-947, ADR:1397, and ADR:1511-1516.

**Action:** rewrite Handoff item 2 in the same vocabulary as D1/D5: such a profile is conformant only
when all reaching hooks are explicitly excluded, and definition validation rejects it otherwise.
Re-run the body-only searches for `non-conformant`, `conformance-eligible`, and `disqualif` after the
edit.

### R6. The Status block records four delta reviews where the reviewed commit contains six, and it contradicts that count twice

**Defect:** ADR:6-7 counts only the second- and third-pass delta reviews even though the two
fourth-pass reviews are already the tenth and eleventh committed sections at baseline `b042757`; the
same block then says “the two delta reviews” at ADR:9 and attributes fourth-pass evidence to “the four
delta reviews” at ADR:29-32.

**Grounding:** exact command and output at the reviewed commit:

```text
$ git show e8242f1:.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md | rg -n '^## Review Comments$'
1698:## Review Comments
2158:## Review Comments
2635:## Review Comments
2950:## Review Comments
3229:## Review Comments
3616:## Review Comments
4021:## Review Comments
4299:## Review Comments
4749:## Review Comments
5135:## Review Comments
5590:## Review Comments
```

Sections 1-2 are full reviews, 3-5 are F1-F6 verifications, and 6-11 are six delta reviews — two each
of correction passes two, three, and four.

**Action:** say “six independent delta reviews (two each of the second, third, and fourth correction
passes)” and make ADR:9 and ADR:29-32 use the same six-review history.

### R7. `compaction_ai` registers eight hooks, not one, leaving its remaining per-hook classifications unstated

**Defect:** ADR:373 says excluding `on_pre_step` disables the extension's “only hook,” but the
extension registers eight hooks and three of the seven constant-returning hooks carry broad declared
effect rows.

**Grounding:** `packages/motoko-ext-compaction-ai/register.ail:99-110` registers
`on_describe_tools`, `on_build_system_prompt`, `on_budget_plan`, `on_pre_step`, `on_tool_policy`,
`on_tool_handle`, `on_response_intercept`, and `on_solver_candidate` fields; excluding the required
`provided_tools` field leaves eight hooks. Only `on_pre_step` calls `compact_with_ai`, but
`on_tool_handle`, `on_response_intercept`, and `on_solver_candidate` declare
`{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}` while returning constants.

**Action:** change “only hook” to “only non-trivial hook and the only hook that reaches `ai_step`,”
and state whether D5's interim per-hook classification is based on performed effects or declared
effect rows. The profile-definition record must classify all eight hooks even if only one requires
classifier-2 exclusion.

### R8. Two replacement anchors are still factually wrong: the compose hook range is truncated and three dummy-hook guard lines are cited as call lines

**Defect:** ADR:781 presents `:761-771` as the enclosing `on_response_intercept` range although the
function closes at `:790`, while ADR:884-886 describes five cited call lines as five syntactic guard
sites even though three guards begin earlier.

**Grounding:** source locations; the second command's call arguments are abbreviated in the displayed
output because the cited line numbers, rather than the elided arguments, ground the finding:

```text
$ awk 'NR==761 || NR==767 || NR==771 || NR==790 || NR==792 {printf "%d: %s\n", NR, $0}' packages/motoko-ext-compose/compose.ail
761: export func on_response_intercept(ctx: ExtCtx, response_text: string, mode: string, snippet_caps: string) -> ResponseInterceptDecision ! {IO, Process, FS, Clock} {
767:       let name = "inline_${show(now())}";
771:       let _ = writeFile(path, "${compose_module_header(name)}\n\n${clean}");
790: }
792: func no_budget_patch() -> BudgetPatch {

$ rg -n 'is_test_dummy|emit_dummy_hook' src/core/ext/runtime.ail
206:      let _ = if is_test_dummy(h.id) then emit_dummy_hook(...) else ();
222:      let _ = if is_test_dummy(h.id) then emit_dummy_hook(...) else ();
239:      let _ = if is_test_dummy(h.id) then {
245:        emit_dummy_hook(...)
280:  let _ = if is_test_dummy(h.id) then {
287:    emit_dummy_hook(...)
368:  let _ = if is_test_dummy(h.id) then {
374:    emit_dummy_hook(...)
```

The mixed-guard counterexample is correctly anchored at `src/core/tool_phase.ail:222`, with the
effectful `exec_scratchpad_cell_ws` call at `:223`. The `ExtPorts` and `ai_step` anchors at
`types.ail:62-67` and `compaction_ai.ail:106` are also correct.

**Action:** cite `on_response_intercept` as `:761-790` (or cite only the clock site at `:767`), and
separate the dummy-hook call sites `206,222,245,287,374` from their guard starts
`206,222,239,280,368`. Update the Status statement from four to five consecutive correction passes
with anchor defects.

## What is accurate

All confirmations below were re-run against `e8242f1` and pinned AILANG v0.26.0.

**A1 ruling — the line is conceptually correct and its timing argument is sound, but the stated rule
has no complete detector.** An excluded hook is named as uncovered and fails closed if runtime
dispatch reaches it (ADR:935-937). An un-excluded `ai_step` path returns only
`Result[string, string]` through `ExtPorts` (`types.ail:63`) and only a decision through
`on_pre_step`; after the interim `Ports.model_step` widening there is no return channel for the
successor, so discarding it completes silently. Definition-time rejection is therefore the correct
side of the timing boundary. R3 is why it is not enforceable yet.

“Conformant and inert” is honest profile bookkeeping, not coverage laundering, provided the result
continues to name every excluded hook and awards it no coverage, as ADR:935-940 requires. A fully
excluded extension contributes no extension-path evidence; that makes the profile low-utility, not
dishonest. The ADR already warns that this must not be represented as a conformant *and covering*
`default` (ADR:370-378). The implementation report should keep conformance and hook coverage visibly
separate; D11's class/branch counters do not replace that disclosure.

**A2 ruling — classifier 2 is not correctly bounded.** Its literal criterion selects all four fields,
its intended criterion selects one, “retired field by field” does not match the one scheduled
ABI-major change, and classifier 1's soundness boundary cannot be inherited wholesale by a different
kind of matcher. R2 states the required correction.

**A3 ruling — clause 3 is still an intention rather than a buildable artifact.** Its necessity-not-
sufficiency attribution semantics are the right response to mixed guards, and missing attribution
failing into clause 1 is conservative for post-boundary routing sites. It lacks the production and
validation contract needed to make either that claim or an incorrect-positive attribution safe.

**Classifier arithmetic confirmed, but not completeness.** The corrected arithmetic is exact:

```text
$ ailang builtins list -json | python3 -c 'import json,sys; d=json.load(sys.stdin)["builtins"]; imp=[b for b in d if b["is_pure"] is False]; print("rows",len(d),"impure",len(imp),"pure",sum(b["is_pure"] is True for b in d)); print("labels",len({b["effect"] for b in imp}),sorted({b["effect"] for b in imp})); print("groups",len({"Pure" if b["is_pure"] else b["effect"] for b in d})); print("modules",len({b["module"] for b in imp}),"non_std",[(b["name"],b["module"]) for b in imp if not b["module"].startswith("std/")])'
rows 324 impure 115 pure 209
labels 17 ['AI', 'Clock', 'Cog', 'DOM', 'Debug', 'Env', 'FS', 'IO', 'Msg', 'Net', 'Process', 'Rand', 'Secret', 'SharedIndex', 'SharedMem', 'Stream', 'Trace']
groups 18
modules 21 non_std []
```

`ailang.toml:53-54` lists twelve `[effects] max` labels. Thus seventeen effect labels plus `Pure`, the
explicit `Pure` filter, 21 projected effect-bearing modules, no non-`std/*` impure rows, and the count
of twelve are all correct. R1 rules that the 21-module projection is necessary but not sufficient.

**Clock arithmetic and routing state confirmed.** `rg -n '\bnow\(\)' src packages -g '*.ail'`
returns thirteen live reads: four in `session.ail`, one in `ext/runtime.ail`, and eight in the compose
package. None has been replaced by a world-clock call at HEAD. With the runtime site correctly
attributed to `test_dummy`, the installation-scoped counts remain 4 / 12 / 13. Until R4's table exists,
however, that attribution is not valid gate evidence and the fail-closed fallback would count the
runtime site unconditionally.

**Configuration and remaining anchors confirmed.** The exact configuration recount was:

```text
$ git ls-files '.motoko/config/*/config.json' | wc -l
14
$ git ls-files '.motoko/config/*/config.json' | xargs -n1 jq -r '(.extensions.order // []) | index("compaction_ai") != null' | sort | uniq -c
     14 true
```

`types.ail:62-67`, `tool_phase.ail:222`, `compose.ail:767`, and `compaction_ai.ail:106` are accurate;
R8 records the two range/form errors.

**Status metrics confirmed independently.** The finding counts for review sections 6-9 are
`7 + 8 = 15` for the second-pass round and `6 + 6 = 12` for the third-pass round. The six
anchor/provenance findings in the former are sections 6 R4/R5/R7 and 7 R5/R6/R7. Narrowly defined as
edit provenance, section 7 R5 is one of fifteen and the third-pass round has none. The two third-pass
anchor findings are sections 8 R6 and 9 R6, both on the same deferred `stub_step.ail` comment range.
Thus “six of fifteen,” “two of twelve,” and “one of fifteen against none” hold; the header's count of
four delta reviews does not.

**Collateral consistency confirmed subject to the findings.** D11 reports fault-class and
production-branch reach, not hook coverage, and does not contradict the split. D5's profile record
has the three required per-hook classifications — effect-free, world-mediated, excluded — although
R4 shows it omits the attribution table and R7 shows all registered hooks still require a
classification. Consequences uses the corrected split. D1, D5's exclusion paragraph, D5 validation,
and the acceptance row agree on coverage versus definition-time rejection in substance, but their
reach/reference predicates drift as R3 records. Handoff item 2 is the one remaining normative
disqualification statement (R5).

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. Close classifier 1's full-stdlib completeness hole (R1); the routing inventory cannot be cited
   while source-defined effect modules are invisible.
2. Define classifier 2's actual one-field criterion and its own matcher boundary (R2).
3. Specify and version the site-to-hook artifact, including correctness, production, validation, and
   scheduling rules (R4).
4. Normalize the coverage/rejection predicate and make classifier 2 consume that artifact, or adopt
   the conservative extension-level rule (R3).
5. Correct the remaining conformance contradiction and state how all eight `compaction_ai` hooks are
   classified (R5, R7).
6. Correct the review history and both anchors, then re-run body-wide terminology and anchor checks
   (R6, R8).

**Belongs to the implementation plan, after the ADR defines the contracts:**

- Build both classifiers, derive them on the repin milestone, and wire fail-closed profile-load
  validation.
- Produce the initial source-revision-bound site-to-hook table and its drift validator.
- Implement runtime exclusion dispatch and profile-definition rejection, with separate conformance
  and per-hook coverage reporting.
- Name and validate the first useful narrow profile; no checked-in configuration supplies covering
  `compaction_ai` behavior under the interim ABI.

## Accept / revise recommendation

**Revise — the fifth pass's coverage-versus-rejection timing is sound, but neither classifier nor the
attribution artifact is yet a complete enforceable gate, and R5-R8 leave normative/history/anchor
contradictions. The upstream API blocker remains fully in force and unchanged: acceptance still
requires a recorded-stream API in an actual AILANG release, this repository repinned to that release,
and the positive integration probe passing; the fork prototype clears none of those conditions.**

---

## Review Comments

**Reviewer:** independent delta review of the **sixth correction pass**, fresh session, no context
from the correcting side.
**Model:** `claude-opus-5`.
**Date:** 2026-08-01.
**Reviewed at:** `c45473c` (HEAD), covering `d1b5c14..c45473c` — the pass commit `6eca7fe` plus the
delta-review-count follow-up. Baseline `d1b5c14` is the two fifth-pass delta reviews committed
verbatim before any response. Section count verified by execution at both commits: thirteen
`## Review Comments` sections at `6eca7fe` and at `c45473c`; **this is the fourteenth.**
**Toolchain:** `AILANG v0.26.0` (commit `3b52a24`), matching `ailang.toml` `>=0.26.0` and
`scripts/install-prerequisites.sh:39` `AILANG_REF="v0.26.0"`.
**Verdict: Revise.** Four of the eight answered findings are correct and land. Three of the pass's
own headline claims are false against the document it produced, and one fifth-pass finding was
answered at a different site than the one it was raised against, leaving the defect verbatim.

---

### R1. Read as written, the extension-granularity predicate rejects the ADR's own "first *useful* interim profile" — both guards textually reference `ai_step`

D1:366-388 makes the predicate "the extension **contains a classifier-2 field reference**", explicitly
"textual", explicitly "decidable **today** from a grep", and explicitly *not* reachability. Run that
grep. It does not select two packages; it selects five, and two of them are `empty_stop_guard` and
`progress_contract_guard` — the exact pair D1:393-396 and ADR:1026 name as the first useful interim
profile.

```text
$ for d in packages/*/; do n=$(grep -rl "ai_step" "$d" --include=*.ail | wc -l); \
    [ "$n" -gt 0 ] && echo "$(basename $d): $n file(s)"; done
motoko-ext-abi: 1 file(s)
motoko-ext-compaction-ai: 1 file(s)
motoko-ext-empty-stop-guard: 1 file(s)
motoko-ext-progress-contract-guard: 1 file(s)
motoko_ext_conformance: 2 file(s)

$ grep -rn "ai_step" packages/motoko-ext-empty-stop-guard/
packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:52:func noop_ai_step(...)
packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:53:  Err("ext ai_step port unavailable")
packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:70:    ai_step: noop_ai_step,
```

`packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:136,137,154` is the same
shape: a `noop_ai_step` stub and an `ai_step:` field construction, both in the package's own unit-test
scaffolding. Under D1's predicate as written, a profile installing either guard must exclude **all
eight** hooks it registers or be rejected — which excludes `on_solver_candidate`, where both guards'
entire behaviour lives (`register.ail:34-36` → `decide`). The narrow purpose-built profile is
therefore not merely coverage-limited; it is inert or rejected.

The pass avoided seeing this because it counted *call* sites, not references. **ADR:1181 states "the
only two `ai_step` references are `packages/motoko-ext-compaction-ai/compaction_ai.ail:106` and
`packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90`". That claim is false as written**;
it is true only of `ctx.ports.ai_step(` call sites:

```text
$ grep -rn "\.ai_step(" src packages --include=*.ail
packages/motoko-ext-compaction-ai/compaction_ai.ail:106:  match ctx.ports.ai_step(model, prompt_msgs) {
packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90:  let summary = match ctx.ports.ai_step(ctx.model, msgs) {
```

So the rule is decidable from a grep, as claimed — and the grep decides the wrong thing. The coarse
rule's stated virtue (decidability) and its stated cost ("it costs only the ability to keep one hook
of a referencing extension", D1:378) are both mis-stated: the cost is every hook of five packages,
including both guards and the ABI package itself.

This also answers the scope question the pass left open. `motoko-ext-abi` is not an extension and
`motoko_ext_conformance` is not registrable — `grep -n conformance src/core/ext/registry_generated.ail`
returns nothing — but the ADR never defines which packages the predicate ranges over, so nothing in
the text excludes them.

**Action:** decide, in one sentence, whether the predicate ranges over *field-access sites on an
`ExtPorts`-typed value* (`ctx.ports.ai_step`, two sites) or over *any textual occurrence of the field
name* (five packages), and make D1:378, D1:393, D5:1013-1017, ADR:1181 and the acceptance row all say
the chosen one. If it is the former, "textual reference" is the wrong name for it and the grep must be
specified as `\.<field>(` on an `ExtPorts` binding — which reintroduces exactly the alias/wrapper
blindness classifier 2's matcher-boundary paragraph (ADR:1174-1183) already concedes. Also state
whether non-registrable packages (`motoko-ext-abi`, `motoko_ext_conformance`) are in scope.

---

### R2. The fifth pass's R2 Action was applied to classifier 2 but not to the D5 bullet it cited by line number; the self-defeating clock contradiction survives verbatim

The fifth-pass review at ADR:6189-6213 located the contradiction precisely — "D5:980-982 then fails
profile-definition validation closed 'when an installed extension references a non-world-mediated
`ExtPorts` field from a hook the profile has not excluded'… The prescribed remedy triggers the
prescribed rejection, six lines apart" — and its Action required reconciling that bullet. The pass
adopted the reviewer's replacement criterion into classifier 2 (ADR:1155-1160, verbatim from the
Action's wording) and **did not touch the cited bullet**:

```text
$ git show 6eca7fe -- .../ADR-001-*.md | grep -c "non-world-mediated .ExtPorts. field from a hook"
0
$ git show d1b5c14:.../ADR-001-*.md | grep -n "non-world-mediated \`ExtPorts\` field from a hook"
982:  non-world-mediated `ExtPorts` field from a hook the profile has not excluded** (classifier 2).
```

At HEAD it is ADR:1055-1056, three lines below the clock bullet at ADR:1048-1051 that makes routing
`compose`'s eight reads **into** `ExtPorts.clock_now` a conformance precondition. `clock_now` is a
non-world-mediated field; the bullet therefore rejects the profile that does what the bullet above it
requires. The contradiction the pass diagnosed at length in classifier 2 ("under that reading the
clock bullet above becomes self-defeating", ADR:1163-1167) is still live at the site the reviewer
named. The same bullet is also still **per-hook** ("from a hook the profile has not excluded"), not
extension-granularity.

**Action:** rewrite ADR:1055-1056 to the adopted predicate — installed extension, classifier-2 field,
extension granularity — and drop "non-world-mediated" from it entirely, since that phrase is now the
name of a rejected membership criterion.

---

### R3. The Status block still carries the abandoned "every hook reaching the port" predicate, in the paragraph that asserts the rule "is now stated once"

ADR:41-44:

> exclusion costs *coverage*, not conformance. The rule is now stated once, in D5's vocabulary — every
> hook **reaching the port** must be an explicitly excluded hook, and installing such an extension
> *without* excluding **those hooks** is a profile-definition rejection

That is the call-graph phrasing D1:371-374 declares abandoned ("An earlier revision said 'every hook
that *can reach* the port' — a call-graph property with no instrument"). Combined with R2, the pass's
headline claim at D1:384-388 — "**One predicate, used everywhere** … The rule is **references**, at
extension granularity, and **every site now says so**" — is false at two of six sites. Inventory at
HEAD:

| Site | Predicate |
|---|---|
| Status ADR:41-44 | "every hook **reaching the port**" — stale, call-graph |
| D1 ADR:366-388 | references / every hook it registers — **adopted** |
| D5 exclusion ADR:1013-1017 | references classifier-2 field / any hook it registers — **adopted** |
| D5 validation bullet ADR:1055-1056 | "**non-world-mediated** field from **a hook** not excluded" — stale on both axes (R2) |
| Acceptance row ADR:1519 | references classifier-2 field / registering an un-excluded hook — **adopted** |
| Impl. Handoff ADR:1683 | every hook that extension registers — **adopted** |

**Action:** restate ADR:41-44 in the adopted predicate, and change "stated once" to "stated at six
sites, all in the same words" — which is what the pass actually attempted and is the honest claim.

---

### R4. `ExtensionHooks` fixes effect rows at the ABI, so the declared-not-performed rule makes the coverage floor vacuous *and* makes the pure-guard interim profile inert

The sixth pass added two rules in the same edit and neither was checked against the ABI type they
range over. `packages/motoko-ext-abi/types.ail:151-165` declares `ExtensionHooks` as a **closed record
whose per-field effect rows are properties of the ABI, not of the extension**:

```text
$ sed -n '151,165p' packages/motoko-ext-abi/types.ail
export type ExtensionHooks = {
  id: string,
  provided_tools: [string],
  on_describe_tools: () -> [ToolSchema],                        <- pure, ABI-fixed
  on_build_system_prompt: (ExtCtx) -> PromptPatch,              <- pure, ABI-fixed
  on_budget_plan: (ExtCtx, BudgetPlan) -> BudgetPatch ! {Env, FS},
  on_pre_step: ... ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
  on_tool_policy: (ExtCtx, ToolCallEnvelope) -> ToolPolicyDecision,   <- pure, ABI-fixed
  on_tool_handle: ... ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
  on_response_intercept: ... ! {IO, ...},
  on_solver_candidate: ... ! {IO, ...}
}
```

Three consequences, none of which the pass accounts for:

1. **"Every hook it registers" is always all eight, for every extension** — the record is closed, so
   the field set is not a per-extension fact and reading `register.ail` cannot narrow it. D1:377-378's
   refinement path ("extend D4's site-to-hook attribution table to extension packages and have this
   rule read it") is therefore the *only* possible refinement; `register.ail` will never supply one.
2. **The coverage floor is vacuous.** D5:993-1001 requires "at least one hook of every extension it
   installs" to be covered, where covered means effect-free or world-mediated (D5:979-984). Every
   extension has three ABI-pure hooks by construction, and in this repo all three are constant
   lambdas (`on_describe_tools: \_ . []` etc.). A profile that installs all fourteen configured
   extensions and excludes every hook with behaviour satisfies the floor by covering
   `on_describe_tools`. That is precisely the "installs everything and excludes everything"
   configuration D5:993-995 says the floor exists to forbid.
3. **The pure-guard interim profile is inert.** ADR:1026 says "pure guards and deterministic fixture
   hooks may form the initial profile." Both guards' logic is `export **pure** func decide`
   (`empty_stop_guard.ail:40`, `progress_contract_guard.ail:120`) — genuinely effect-free — but it is
   reached only through `on_solver_candidate`, whose row the ABI fixes at the full nine effects
   (`register.ail:34-36` in both packages). Under "classification reads *declared* effect rows"
   (D5:1002-1012), that hook is effectful, hence not coverable, hence excludable only. There are no
   pure guards under the pass's own rule.

**Action:** state the floor over *hooks the profile classifies as covered and that carry behaviour*,
or over a named minimum set, not "at least one hook" — otherwise delete it, because as written it
constrains nothing. Separately, either carve the three ABI-pure slots out of the declared-effects rule
explicitly, or withdraw ADR:1026's "pure guards … may form the initial profile", which the rule
contradicts.

---

### R5. The `ai_step` exemption from the coverage floor has no slot in the profile-definition record and no clause in the acceptance row, so the acceptance gate as written fails all fourteen checked-in configurations

D5:998-1000 and the Implementation Handoff at ADR:1683-1685 both require the exemption to be "named
as such in the profile definition". The versioned profile definition at ADR:959-970 has eight
bullets, and none of them is an exemption slot — the closest, "included extension ids and per-hook
classifications (effect-free, world-mediated, or explicitly excluded)", records the exclusions but
cannot distinguish a licensed floor exemption from a floor violation.

The acceptance row is worse than ambient — it is contradictory. ADR:1519 ends:

> and every installed extension has at least one covered hook (the coverage floor).

with no exemption clause. All fourteen checked-in configurations install `compaction_ai`
(settled, re-confirmed by every prior round), which under the extension-granularity rule must have all
eight hooks excluded and therefore has **zero** covered hooks. The acceptance row as written fails
every checked-in configuration, including the one D1:392-396 says is the intended interim disposition.

**Action:** add a ninth bullet to ADR:959-970 — "coverage-floor exemptions, each naming the extension,
the substrate limit that forces full exclusion, and the classifier-2 field involved" — and append
"except extensions carrying a recorded coverage-floor exemption" to ADR:1519.

---

### R6. The attribution table's correctness condition is not checkable by the validator the same bullet list defines, and the text claims otherwise

ADR:918-922 lists four load-time checks: site neither in table nor unconditional-core; entry naming an
uninstalled or unknown hook; stale source-revision binding; malformed row. All four are schema,
staleness and referential-integrity checks. None tests the correctness condition at ADR:911-914 —
"installation of at least one attributed hook is a *necessary* condition of the site executing" —
because necessity is a control-path property, which is what ADR:913-914 itself says the clause exists
to avoid computing.

Concrete failure: attribute `src/core/rpc.ail:200` (`get_hint`, reaching
`src/core/cache.ail:60` → `std/sem.ail:374` at `! {SharedMem}`) to `test_dummy`. Row well-formed ✓,
hook known ✓, binding fresh ✓, site present ✓ — validator passes. A profile not installing
`test_dummy` now drops a live core `SharedMem` read from its profile-reachable set and certifies
routing completeness over it. That is the exact fail-open clause 3 was rewritten to close, re-entering
through the artifact.

The sentence at ADR:920-922 — "which is why the correctness condition is stated as a checkable claim
rather than left to the author's judgement" — is a non-sequitur. Stating a condition precisely does
not make it machine-checkable, and the pass's own bullet list is the evidence.

**Action:** say plainly that necessity is **manually reviewed and unchecked by the validator**, and
require the profile definition to record a named reviewer per attribution row. If a mechanical check
is wanted, the one available over-approximation is *syntactic dominance*: require every attributed
site to be textually dominated by a guard mentioning the attributed hook id — which
`src/core/ext/runtime.ail`'s `if is_test_dummy(h.id)` at `:206, :222, :239, :280, :368` already
satisfies, and which is decidable by the same textual inventory D5 obligation 2 builds.

---

### R7. Classifier 1's stdlib source-scan pattern is both incomplete and over-broad, and the `std/*.ail` glob misses a subdirectory module

The prescribed pattern is `export func … ! {…}` with a non-empty row over
`~/.local/share/ailang/std/*.ail` (ADR:1116-1120). Three defects, all executed:

**(a) Multi-line signatures are missed. `std/process` has zero matches.**

```text
$ cd ~/.local/share/ailang/std && grep -cE '^export func .*! \{[^}]+\}' process.ail
0
$ sed -n '59,62p' process.ail
export func exec(
  cmd: string, args: [string]
) -> Result[ProcessOutput, ProcessError] ! {Process} {
```

Sixteen such multi-line effectful exports exist across `ai.ail`, `net.ail`, `process.ail`, `smoke.ail`
and `zip.ail`. At HEAD the union rescues all of them — `std/process` is in the builtin projection — so
this is not a live fail-open today. It is a fail-open *mechanism*, in the half of the classifier that
was added precisely because the other half was found insufficient.

**(b) Effect-*polymorphic* rows are counted as effect-bearing, and the module flagged is `std/list`.**

```text
$ grep -nE '^export func .*! \{[^}]+\}' list.ail
193:export func mapE[a, b, e](f: (a) -> b ! {e}, xs: [a]) -> [b] ! {e} {
204:export func filterE[a, e](p: (a) -> bool ! {e}, xs: [a]) -> [a] ! {e} {
215:export func foldlE[a, b, e](f: (b, a) -> b ! {e}, acc: b, xs: [a]) -> b ! {e} {
226:export func flatMapE[a, b, e](f: (a) -> [b] ! {e}, xs: [a]) -> [b] ! {e} {
237:export func forEachE[a, e](f: (a) -> () ! {e}, xs: [a]) -> () ! {e} {
```

`e` is an effect variable, not an effect. The scan therefore adds `std/list` to the detection set, and
the mandatory reconciliation then makes every `std/list` import a fail-closed triage candidate — the
outcome ADR:1131-1133 names as the canonical symptom of a badly-built gate ("a gate treating all
eighteen output groups as effect-bearing would flag every `std/list` import").

**(c) The glob is `std/*.ail`; `std/ai/streaming.ail` is a subdirectory module with six `! {Stream}`
exports (`:100,113,149,172,178,183`) and is matched by neither half of the union** — the builtin
projection carries `std/ai`, not `std/ai/streaming`. No repo module imports it today
(`grep -rnoE 'import +std/[a-z_]+/[a-z_]+' src packages` returns nothing), so this too is latent.

**Reproducibility of the path is fine and should be said so in the ADR.** `~/.local/share/ailang` is
not an arbitrary user-home location: it is a git clone at the pinned ref, created identically by
`scripts/install-prerequisites.sh:569-579` and by `.github/workflows/verify-extensions.yml:70-72`.
The residual risk is that `AILANG_REF="v0.26.0"` is a mutable tag and an existing clone is updated by
`git checkout` rather than re-cloned.

**Action:** (i) make the pattern signature-scoped rather than line-scoped, or state that the scan runs
on a signature-normalised stream; (ii) exclude rows whose every element is a lower-case effect
variable; (iii) glob `std/**/*.ail`; (iv) state in the ADR that the scan root is the pinned
`install-prerequisites.sh` clone and require the derivation to record the resolved commit
(`git -C ~/.local/share/ailang rev-parse HEAD`) alongside the derived set.

---

### R8. Anchors and arithmetic introduced by this pass — one range off by a line at each end, one count off by one

Every anchor the pass introduced was re-derived. **These hold:** `~/.local/share/ailang/std/sem.ail:374,385`;
`std/extension.ail:27`; `src/core/cache.ail:29,60,75`; `src/core/rpc.ail:200`;
`packages/motoko-ext-omnigraph/register.ail:4`;
`packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90`;
`packages/motoko-ext-compaction-ai/compaction_ai.ail:106`; `packages/motoko-ext-compose/compose.ail:767`
and the corrected `:761-790` (`on_response_intercept` closes at `:790`); and both
`src/core/ext/runtime.ail` lists — guards at `206, 222, 239, 280, 368`, calls at `206, 222, 245, 287,
374`, with `now()` at `:190`. The corrected `:761-790` and the guard/call separation are clean fixes.

**Two defects:**

- **ADR:392 / `register.ail:99-110`.** The eight-hook count is correct, but the range is not: line 99
  is `provided_tools: []` (not a hook) and line 110 is the record's closing `}`. The eight hooks span
  `:100-109`. The anchor was inherited verbatim from the fifth-pass review at ADR:6864 and never
  re-derived.
- **ADR:1007-1009 — "three of `compaction_ai`'s seven trivial hooks declare exactly that row".** True
  of *that* row, but the conclusion drawn ("so they classify as effectful and need exclusion") applies
  to **four**: `on_budget_plan` (`register.ail:102`) declares `! {Env, FS}`, which is also non-empty
  and also not effect-free. Of the seven trivial hooks, three are pure and four are effectful.

**Action:** `:100-109`; and "four of the seven trivial hooks declare a non-empty row — three the full
nine-effect row, `on_budget_plan` `! {Env, FS}`".

---

### R9. D4 asserts the 4 / 12 / 13 split flatly and denies its derivability sixty lines later

ADR:817-821 states without qualification that a profile installing neither `compose` nor `test_dummy`
"has **four** sites to route", one installing `compose` "has **twelve**", and one installing both
"all **thirteen**". ADR:925-930, added by this pass, says: "Until then 'four driver clock reads' is not
a derivable number: without an attribution for `src/core/ext/runtime.ail:190`, the fail-closed default
counts it as unconditional core and the driver obligation is five."

The arithmetic itself survives — 4 + 8 = 12, +1 = 13 — and D4's count of 13 is settled. But the
pre-table numbers are 5 / 13 / 13, which collapses the twelve-versus-thirteen distinction the table's
third row exists to draw. One of the two passages must yield.

**Action:** add "once the attribution table validates" to ADR:819, and change ADR:927 from "is not a
derivable number" to "is not yet derived — pre-table the split is 5 / 13 / 13".

---

### R10. The coverage floor is asserted in the acceptance row with no producing artifact, and no reporting requirement anywhere

Every other clause of ADR:1519-1521 names its evidence — the manifest, the exclusion list, D11's
branch-reached counters read from D3's catalogue. The floor names none. D11's counters are
fault-class and branch-reached (ADR:1480, 1527); nothing in D11 counts hooks, and no result field
anywhere requires per-hook coverage to be reported. The floor is the only acceptance clause in the
table that no artifact produces.

**Action:** either require the run result to report covered/excluded hook counts per installed
extension, or move the floor out of the acceptance table into D5 as a profile-definition well-formedness
rule checked at load — which is where the rest of its family already lives.

---

## What is accurate

Re-run and confirmed by execution at `c45473c` on pinned `v0.26.0`:

- **Section count.** Thirteen `## Review Comments` sections at both `6eca7fe` and `c45473c`; the
  follow-up commit's correction of the Status block from "six" to "**eight** independent delta reviews
  (two each of the second, third, fourth, and fifth correction passes)" is **correct**, and
  2 full + 3 verifications + 8 delta = 13 reconciles. The rest of the Status block is free of this
  staleness class; its one surviving defect is R3, which is a content stale, not a count stale.
- **Classifier 1's motivating case is real and correctly diagnosed.** `std/sem.ail:374,385` export
  `load_frame`/`store_frame` at `! {SharedMem}`; `src/core/cache.ail:29` imports them and calls them at
  `:60`/`:75`; `src/core/rpc.ail:200` reaches `get_hint`. `std/sem` is absent from the builtin
  projection. The second case is real too: `std/extension.ail:27` `! {FS}`, imported at
  `packages/motoko-ext-omnigraph/register.ail:4`.
- **The 21 / 21 / 10 arithmetic.** The builtin projection yields exactly 21 modules; the repo imports
  exactly 21 distinct `std/*` modules under `src` + `packages`; exactly **ten** of those have no
  derived row (`std/bytes crypto datetime extension json list option result sem string`). The claim
  at ADR:1128-1130 is confirmed to the number.
- **The reconciliation recovers both live cases.** `std/sem` and `std/extension` are both in the
  source-scan set. The seven remaining unmatched modules (`bytes crypto datetime json option result
  string`) are provably effect-free by the ADR's own criterion — zero concrete effect rows anywhere in
  their sources — so the check terminates rather than producing an unbounded triage list. Transitive
  imports are handled by construction: the criterion is a property of the imported module's own
  exported rows, and `std/sem`'s `{SharedMem}` row is what the scan reads.
- **Anchors** — the eleven listed under R8 as holding, including the two corrections the pass made.
- **`ExtPorts.clock_now` still has zero call sites; `ctx.ports.ai_step` still has exactly two.**
- **Classifier 2's rewritten membership criterion is right**, and the argument for it (ADR:1163-1172)
  is the strongest paragraph in the pass. `clock_now`, `proc_exec`, `env_get` lose no cursor;
  `ai_step` returns `Result[string, string]` and cannot carry `Ports.model_step`'s successor. Retiring
  "field by field" in favour of a single ABI major is also correct.
- **Clause 3's necessity-not-sufficiency semantics** — not reopened; R6 is about the validator only.
- **The separated guard/call line lists** and the `:761-790` correction are genuine anchor fixes.

### Three explicit rulings the handoff asked for

**A1 — are the extension-granularity rule and the coverage floor compatible? No, on two independent
grounds, and the exception is not specified well enough to be one.** (i) The floor's stated purpose is
defeated by the ABI, not by the exception: three hook slots are pure for every extension by
`ExtensionHooks`'s type, so the floor is satisfiable by covering a constant-returning no-op (R4). (ii)
The exception itself is ambient exactly as suspected — no slot in the profile-definition record at
ADR:959-970, and no clause in the acceptance row at ADR:1519, which as written fails all fourteen
checked-in configurations (R5). Separately, the coarse rule is what *creates* the collision: under
per-hook granularity `compaction_ai`'s three ABI-pure hooks would satisfy the floor without any
exception at all. **On the narrower question — is the coarse rule right as an interim gate? — yes in
principle: it is decidable and it fails closed, and requiring the attribution-table refinement up
front would have blocked the interim on an artifact that does not exist.** But its predicate must be
disambiguated before it is a gate rather than a grep (R1), and its cost is mis-stated.

**A2 — is classifier 1's source scan complete and reproducible? Reproducible yes; complete no.** The
path is a pinned git clone used identically by the installer and by CI, so the derivation is
reproducible on another machine — the ADR should say that rather than leave the path bare, and should
record the resolved commit. Completeness fails on three counts, one of which (`std/list` via `! {e}`)
produces a live false positive today and two of which (multi-line signatures, the `std/*.ail` glob) are
latent fail-opens rescued only by the union (R7). **This is the fourth consecutive revision of this
obligation to leave a completeness hole, and the pass's claim at ADR:1121-1123 that "the reason is
recorded so a fourth does not rediscover it" is itself the fourth.**

**A4 — is the attribution table's correctness condition checkable by its validator? No.** The four
listed checks are schema, staleness and referential integrity; necessity is a control-path property
the same section refuses to compute. The wrong-positive attribution is caught by nothing, and
ADR:923-925 implies otherwise (R6). A mechanical over-approximation — syntactic dominance by a guard
naming the hook id — is available and is what the ADR's own `is_test_dummy(h.id)` example exhibits.

---

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. **R1** — disambiguate the classifier-2 reference predicate (field-access site vs. textual
   occurrence) and scope it to registrable extension packages. Everything below depends on which
   reading is chosen, and under the literal reading the ADR's own interim plan is unbuildable.
2. **R3, R2** — propagate the chosen predicate to ADR:41-44 and ADR:1055-1056. R2 additionally removes
   the surviving "non-world-mediated" criterion, without which the clock gate is unreachable.
3. **R4** — restate or delete the coverage floor, and reconcile the declared-effects rule with
   ADR:1026's "pure guards may form the initial profile", which it currently contradicts.
4. **R5** — add the exemption slot to ADR:959-970 and the exemption clause to ADR:1519. Depends on 3.
5. **R6** — say that necessity is manually reviewed, and either require a recorded reviewer or adopt
   syntactic dominance as the mechanical check.
6. **R7** — fix the scan pattern (signature-scoped, effect-variable exclusion, `std/**/*.ail`) and
   record the scan root's resolved commit.
7. **R8, R9, R10** — anchor range, the three-versus-four count, the 4/12/13 conditional, and the
   floor's missing producer.

**Belongs to the implementation plan, not this ADR:** building the attribution table and both
classifiers in one change (already correctly scheduled at ADR:920-922); wiring either into CI, the
Makefile or `scripts/` — neither is wired anywhere today; the successor detector that would relax the
declared-effects rule; and extending the attribution table to extension packages, which R4(1)
establishes is the only possible route to per-hook granularity.

---

## Accept / revise

**Revise.** The pass's four substantive corrections — classifier 2's membership criterion, the
declared-versus-performed ruling, the attribution table's D6 treatment, and the two anchor fixes — are
correct and worth keeping; but R1 makes the pass's central new rule reject the profile the ADR is
built around, R2 leaves a fifth-pass finding unfixed at the line it was raised against, R3 falsifies
the pass's "every site now says so", and R4/R5 make the coverage floor simultaneously vacuous and
unsatisfiable. **The upstream API blocker is untouched by any of this and remains fully in force:
acceptance still requires the recorded-stream API in an actual AILANG release, this repository
repinned to it, and the positive integration probe passing — `arniwesth/ailang`'s
`stepWithStreamRecorded` on the `v0.31.0` tag is a prototype and clears none of those three.**

---

## Review Comments

**Reviewer:** independent delta review of the **sixth correction pass**, performed from source in a
fresh Codex session.
**Model:** `GPT-5`.
**Date:** 2026-08-01.
**Reviewed at:** `c45473c95765debccae2f083e1a0b86deb1f827a`, covering
`d1b5c14..c45473c` — correction commit `6eca7fe` plus the count-correction follow-up.
**Section count:** thirteen committed `## Review Comments` sections at both `6eca7fe` and
`c45473c`. A pre-existing uncommitted fourteenth section attributed to `claude-opus-5` was present
when this review began; it was preserved verbatim, and the user explicitly authorized appending this
independent review. **This is therefore the fifteenth section.**
**Toolchain:** `AILANG v0.26.0`, commit
`3b52a24d24431c372ed5605289ef039592209514`.
**Verdict: Revise.** The classifier-2 membership correction, declared-row ruling, table scheduling,
count follow-up, and changed anchors hold, but the new rejection rule, coverage floor, classifier-1
scan, and attribution-table validation are not yet coherent enforceable gates.

---

### R1. The undefined meaning of “textual reference” makes the coarse rejection predicate select the proposed guard packages' own `ExtPorts` fixture construction

**Defect:** Read literally, “an extension contains a classifier-2 field reference” includes the
`ai_step:` record fields embedded in both proposed guard packages, forcing all eight of each guard's
hooks to be excluded and making the ADR's first useful interim profile inert or rejected.

**Grounding:** the broad textual inventory and the narrower access-call inventory are different:

```text
$ rg -n 'ai_step' packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail \
    packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail
packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:52:func noop_ai_step(_model: string, _msgs: [Msg]) -> Result[string, string] ! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream} {
packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:53:  Err("ext ai_step port unavailable")
packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:70:    ai_step: noop_ai_step,
packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:136:func noop_ai_step(_model: string, _msgs: [Msg]) -> Result[string, string] ! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream} {
packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:137:  Err("ext ai_step port unavailable")
packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:154:    ai_step: noop_ai_step,

$ rg -n '\.ai_step\(' src packages --glob '*.ail'
packages/motoko_ext_conformance/fixtures/reject_fixtures.ail:90:  let summary = match ctx.ports.ai_step(ctx.model, msgs) {
packages/motoko-ext-compaction-ai/compaction_ai.ail:106:  match ctx.ports.ai_step(model, prompt_msgs) {
```

ADR:1181-1183's “only two `ai_step` references” is therefore true only of `.ai_step(` access calls,
not of textual occurrences or record-field references. The package scope is also undefined:
`motoko_ext_conformance` exports fixture hooks but is absent from `src/core/ext/registry_generated.ail`,
while D5:1026 expressly contemplates deterministic fixture hooks in an initial profile.

The hook set itself is decidable, but not for the reason D1 gives. All fifteen runtime
`register_with_config` functions return the closed `ExtensionHooks` record at
`packages/motoko-ext-abi/types.ail:151-165`, so every registration always has the same eight hook
fields even if its values are selected conditionally. Five `register.ail` files delegate to
`make_hooks`, so the fields are not always textually present in `register.ail`:

```text
$ rg -n '^[[:space:]]+make_hooks\(' packages/*/register.ail
packages/motoko-ext-mcp/register.ail:10:  make_hooks(cfg)
packages/motoko-ext-ailang-docs/register.ail:25:  make_hooks(workdir, timeout_ms, max_output_chars)
packages/motoko-ext-exa-search/register.ail:20:  make_hooks(workdir, timeout_ms, max_output_chars)
packages/motoko-ext-a2a/register.ail:11:  make_hooks(cfg)
packages/motoko_scratchpad/register.ail:18:  make_hooks(timeout_secs)
```

**Action:** define classifier 2's matcher as an exact syntactic/typed operation — for example, a call
through a classifier-2 field selected from an `ExtPorts`-typed value — and say whether field
declarations, record construction, strings/comments, embedded unit scaffolding, ABI packages, and
non-registry fixture packages are in scope. Cite the closed ABI, not `register.ail`, as the source of
the eight-hook set. If arbitrary textual field occurrences are intended, withdraw the useful-guard
profile claim because both guards match.

---

### R2. The pass's “one predicate, used everywhere” claim is false, and D5's surviving predicate still rejects the clock routing it requires

**Defect:** Status, D1, D5 validation, and Consequences retain the abandoned reachability or
“non-world-mediated” per-hook predicates, so the rule is neither extension-granular nor consistent
and the D5 validation bullet still makes `ExtPorts.clock_now` self-defeating.

**Grounding:** the committed body retains “hook reaching the port” at Status:42, “can reach
`ExtPorts.ai_step`” at D1:353, “excluding its reaching hooks” at D1:360, “non-world-mediated
`ExtPorts` field from a hook” at D5:1056, and “every hook that reaches the port” at
Consequences:1634. Implementation Handoff:1683 instead uses the adopted “every hook that extension
registers.”

D5:1048-1051 requires a `compose` profile to route eight reads into `ExtPorts.clock_now`; the
unchanged D5:1054-1056 bullet then rejects an un-excluded hook referencing that
“non-world-mediated” field. D1:383-388's assertion that every site now says “references, at
extension granularity” is contradicted inside the same normative body.

**Action:** after resolving R1's matcher, replace the stale predicates at Status:41-44,
D1:343-360, D5:1054-1056, and Consequences:1633-1634 with the same extension-granularity sentence
already used at D5:1013-1018 and the acceptance row; remove “non-world-mediated” from classifier-2
validation because classifier membership, not general port mediation, is the adopted criterion.

---

### R3. Rejecting attribution rows that name an uninstalled hook makes the table unable to prove that a hook-guarded site is absent

**Defect:** The validator rejects an entry naming an uninstalled hook even though absence of that
hook is exactly the fact clause 3 needs to remove the attributed site from a profile's reachable set.

**Grounding:** D4:882-883 makes a core site reachable when it is attributed to an **installed** hook;
D4:918-920 then fails profile load when a row names an **uninstalled** hook. The concrete consequence
is stated by the ADR itself at D4:931-938: `src/core/ext/runtime.ail:190` is attributable to
`test_dummy`, and no checked-in configuration installs `test_dummy`. Under the validator as written,
the table cannot retain that attribution in those profiles; if it omits the row, D4:898-900 defaults
the site into unconditional core. D4:926-929 therefore says the obligation is five, while the table
at D4:817-821 states four without qualification.

**Action:** make the attribution artifact source-global over **known** hook identities, permit rows
whose known hooks are absent from a particular profile, and compute reachability by intersecting each
row's hook set with the installed set. Reject unknown hook ids, not known-but-uninstalled ids. Then
state the clock arithmetic conditionally: before a valid attribution table it is 5 / 13 / 13; after
the `test_dummy` row validates it is 4 / 12 / 13.

---

### R4. The `ai_step` coverage-floor exception is ambient because neither the profile record nor the acceptance gate can represent it

**Defect:** D5 requires the exception to be named in the profile definition, but the exhaustive
profile record has no exemption field and the acceptance row unconditionally requires one covered
hook per installed extension.

**Grounding:** the versioned record at ADR:959-970 has eight bullets: identity, per-hook
classification, adapter/parser boundaries, resources, projections, ambient policy, D3 waivers, and
the attribution table. None records a coverage-floor exemption. D5:993-1000 names the `ai_step`
exception, while ADR:1519 ends unconditionally with “every installed extension has at least one
covered hook (the coverage floor).”

An `ai_step`-referencing extension must have all eight hooks excluded under D1/D5 and therefore has
zero covered hooks; the prose exception and automated acceptance row produce opposite results.
D11:1477-1486 reports fault-class and recovery-branch counters, not hook coverage, and no other result
field is named as the producer of floor evidence.

**Action:** add a versioned `coverage_floor_exemptions` field, with extension id, classifier-2 field,
and substrate reason; make profile-load validation consume it; add the same exception to ADR:1519;
and require the result or manifest to report each installed extension's covered/excluded hook count
and any applied exemption.

---

### R5. Declared-row classification makes the proposed pure-guard profile cover only ABI no-op slots, not either guard's behavior

**Defect:** The closed ABI gives every extension three effect-free hook types, making the new floor
easy to satisfy, while both guards' useful `on_solver_candidate` hook declares the full effect row
and must be excluded under the pass's declared-not-performed rule.

**Grounding:** `packages/motoko-ext-abi/types.ail:151-165` fixes
`on_describe_tools`, `on_build_system_prompt`, and `on_tool_policy` without an effect row, but fixes
`on_solver_candidate` at the full nine-effect row. The empty-stop guard registers the three pure
slots at `packages/motoko-ext-empty-stop-guard/register.ail:27-28,31` and its behavioral
`on_solver_candidate` at `:34-36` with
`! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}`.

`progress_contract_guard/register.ail:23-37` is identical in classification shape. D5:1002-1010
forbids treating the performed-pure `decide` call as effect-free because classification reads the
registered declaration. Thus the floor is syntactically satisfiable by a no-op pure slot while the
only behavioral hook is excluded, contradicting D1:394-397 and D5:1026's claim that these pure guards
can form the first useful profile.

**Action:** define what useful hook coverage means rather than accepting any ABI slot: name at least
one required covered behavioral hook per installed extension in the profile, and for the proposed
guard profile either make `on_solver_candidate` classifiable as covered or withdraw the claim that
the profile exercises the guards. Keep D11's fault/branch counters separate, but add a profile-load
hook-coverage check and reported evidence for the acceptance row.

---

### R6. Classifier 1's source rule is neither complete over the language/toolchain tree nor reproducibly bound to the compiler being classified

**Defect:** The flat `export func` scan misses accepted effectful declaration and module-path forms,
does not define the treatment of effect variables, and reads a user-home checkout that the repository
does not guarantee matches the executing compiler.

**Grounding:** pinned v0.26.0 accepts `export pure func ... ! {Declassify}`, a declaration form outside
the stated `export func` pattern:

```text
$ (cd /home/motoko/.local/share/ailang && env XDG_CACHE_HOME=/tmp/motoko_adr_review_cache ailang check examples/runnable/contracts/inbox_injection_v2.ail)
→ Type checking examples/runnable/contracts/inbox_injection_v2.ail...
→ Effect checking...

✓ No errors found!

$ rg -n '^export pure func.*! \{[^}]+' /home/motoko/.local/share/ailang/examples/runnable/contracts/inbox_injection_v2.ail
39:export pure func sanitizeBody(rawBody: string<email>) -> string<sanitized> ! {Declassify}
66:export pure func safeForward(rawEmail: string<email>, recipient: string) -> SendAction ! {Declassify}
```

The stdlib has a nested effect-bearing module excluded by `std/*.ail`:

```text
$ rg -n '^export func|^\) ->.*! \{' /home/motoko/.local/share/ailang/std/ai/streaming.ail
100:export func openaiCompatStream(
104:) -> Result[StreamConn, StreamErrorKind] ! {AI, Stream, Net} {
113:export func anthropicStream(
117:) -> Result[StreamConn, StreamErrorKind] ! {AI, Stream, Net} {
149:export func callStream(
153:) -> Result[string, AIError] ! {AI, Stream, Net} {
172:export func onEvent(conn: StreamConn, handler: (StreamEvent) -> bool) -> unit ! {Stream} {
178:export func runEventLoop(conn: StreamConn) -> unit ! {Stream} {
183:export func disconnect(conn: StreamConn) -> unit ! {Stream} {
```

The “non-empty row” rule also selects effect variables rather than concrete ambient labels:

```text
$ rg -n '^export func.*! \{[a-z][^}]*\}' /home/motoko/.local/share/ailang/std/list.ail
193:export func mapE[a, b, e](f: (a) -> b ! {e}, xs: [a]) -> [b] ! {e} {
204:export func filterE[a, e](p: (a) -> bool ! {e}, xs: [a]) -> [a] ! {e} {
215:export func foldlE[a, b, e](f: (b, a) -> b ! {e}, acc: b, xs: [a]) -> b ! {e} {
226:export func flatMapE[a, b, e](f: (a) -> [b] ! {e}, xs: [a]) -> [b] ! {e} {
237:export func forEachE[a, e](f: (a) -> () ! {e}, xs: [a]) -> () ! {e} {
```

On this machine the checkout is correct — `git -C ~/.local/share/ailang rev-parse HEAD` returned
`3b52a24d24431c372ed5605289ef039592209514` — but the gate does not establish that. `ailang.toml:6`
is `>=0.26.0`, and `scripts/install-prerequisites.sh:554-559` returns before creating/updating
`~/.local/share/ailang` whenever any installed AILANG satisfies that floor. The later clone at
`:569-578` is reached only when installation is needed. CI creates the expected path, but from the
mutable version tag rather than a recorded commit.

**Action:** derive exported effect rows from parsed module interfaces (or a signature-normalized AST
scan) over the recursive stdlib tree belonging to the exact executable; include `export pure func`,
multiline signatures, and nested modules; specify how row variables are classified; and record and
verify the resolved stdlib commit with the classifier output. A user-home path alone must not be gate
identity.

---

### R7. The attribution validator does not check the necessity condition it presents as checkable

**Defect:** The four load-time checks establish schema, freshness, and referential integrity but do
not establish that installation of an attributed hook is necessary for the site to execute.

**Grounding:** ADR:911-914 defines necessity as the correctness condition. ADR:918-922 checks only a
missing classification, unknown/uninstalled hook, stale source binding, and malformed row. No check
relates a site's control context to its attributed hooks. After R3 permits known-but-uninstalled hook
ids so the table can function, a fresh, well-formed but false attribution of
`src/core/cache.ail:60` to `test_dummy` would satisfy those structural checks and remove a live core
`SharedMem` site from profiles without that hook. Determining the attribution is false requires the
control/path fact that the listed validator does not compute.

The post-boundary scope restriction itself is correct: ADR:915-917 matches the boundary at
ADR:1036-1039, after synthetic configuration is validated and the runtime/profile constructed, with
host discovery, hydration, and TypeScript child-process setup outside.

**Action:** state explicitly that necessity is manually reviewable and is not checked by the
load-time validator; record reviewer/evidence per attribution row, or add a conservative mechanical
proof obligation such as a checked guard/dominance anchor. Do not describe precision of the claim as
mechanical validation of its truth.

---

## What is accurate

Re-run and confirmed at `c45473c`:

- **Review count and Status follow-up.** `git show 6eca7fe:.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md
  | rg -c '^## Review Comments$'` and the same command at `HEAD` both returned `13`. Two full reviews + three
  F1–F6 verifications + eight delta reviews = thirteen, so HEAD's “eight independent delta reviews
  (two each of the second, third, fourth, and fifth correction passes)” is correct. The structural
  remedy for the two repeated count mistakes is a documentation check that derives the total from
  standardized review metadata at the commit being written, rather than another hand-written
  resolution. Status's “five consecutive passes” anchor count also remains correct: the A5 ranges
  below are valid, so this review does not manufacture a sixth anchor-error pass. Status's surviving
  content staleness is the predicate drift in R2.
- **Classifier 1's motivating cases and reconciliation.** The builtin projection contains 21
  modules; the repo imports 21 distinct `std/*` modules; the ten imported modules absent from that
  projection are `std/bytes`, `std/crypto`, `std/datetime`, `std/extension`, `std/json`, `std/list`,
  `std/option`, `std/result`, `std/sem`, and `std/string`. The source half recovers
  `std/sem` (`! {SharedMem}` at `sem.ail:374,385`) and `std/extension` (`! {FS}` at
  `extension.ail:27`). Transitive implementation is handled for these live cases because the
  importing wrapper exports its own declared row: `std/sem` imports `std/sharedmem`, and
  `std/extension` imports `std/fs`.
- **Classifier 2 membership.** The new cursor-loss criterion correctly selects `ai_step` and excludes
  `clock_now`, `proc_exec`, and `env_get`; those three are legal routing destinations because they do
  not discard a successor D1 requires returned.
- **Static hook set.** All fifteen runtime registrations return `ExtensionHooks`; the closed ABI
  always contains eight hooks. Conditional hook *values* cannot conditionally add or remove fields.
- **Declared versus performed effects.** The conservative declaration-based classification does not
  contradict D5's hermeticity probe. The former decides static coverage eligibility; the latter is a
  runtime backstop for ambient effects actually performed by reached hooks. It does, however, create
  the utility defect in R5.
- **Anchors.** Every A5 anchor holds: `std/sem.ail:374,385`; `std/extension.ail:27`;
  `src/core/cache.ail:29,60,75`; `src/core/rpc.ail:200`; omnigraph `register.ail:4`; fixture `:90`;
  compaction `:106`; the eight-hook record enclosed by `register.ail:99-110` (the eight fields are
  exactly `:100-109`); compose `:761-790` and clock call `:767`; and runtime guards
  `206,222,239,280,368` versus calls `206,222,245,287,374`. The enclosing `:99-110` range is not a
  factual anchor error merely because it also contains `provided_tools` and the record's closing
  brace. The statement that three trivial hooks declare the full nine-effect row is also true; it
  does not claim that `on_budget_plan`'s `{Env, FS}` row is pure.
- **Clock arithmetic.** The settled 4 / 12 / 13 split survives as the post-validation result; R3 is
  about the current validator and the missing qualification, not the settled repo-wide count of 13.

### Explicit rulings requested by the handoff

**A1 — extension granularity versus the coverage floor:** **not compatible as an enforceable gate in
the text produced.** D5 declares an exception, so the concepts can coexist, but there is no record
slot, acceptance clause, or evidence producer for it (R4), while the general floor can be satisfied
by ABI-pure no-op slots without covering extension behavior (R5). The coarse extension rule is an
acceptable interim precision trade in principle: it is fail-closed, its eight-hook consequence is
statically decidable from the ABI, and requiring extension site-to-hook attribution up front would
delay the interim gate. It is acceptable only after R1 precisely defines the field-access matcher and
scope; the current literal reading disables the proposed guards themselves.

**A2 — classifier 1 completeness and reproducibility:** **neither is established as specified.** The
union and reconciliation recover today's `std/sem` and `std/extension` holes, but the source pattern
omits accepted declaration/path forms and mishandles row variables, while the named home-directory
tree is not bound by the gate to the executable's resolved commit (R6). The local checkout happens to
match the pin and CI has a usable clone recipe; those facts are inputs to the repair, not proof of the
current rule.

**A4 — attribution correctness:** **necessity is not checkable by the listed validator.** Moreover,
the validator's uninstalled-hook rejection currently prevents the table from expressing the
`test_dummy` absence it is meant to exploit (R3). Once that is corrected, necessity remains a manual
or separately proven control-path property (R7). The post-simulation-boundary scope is correct.

---

## Recommended pre-acceptance actions

**This ADR must fix, in dependency order:**

1. **R1 and R2:** define the exact classifier-2 access matcher and package/test-fixture scope, ground
   the eight-hook set in the ABI, and propagate one identical predicate through Status, D1, D5,
   Consequences, the acceptance row, and the implementation handoff.
2. **R3 and R7:** make the attribution table global over known hook identities, allow known absent
   hooks during profile evaluation, state the pre/post-table clock arithmetic, and distinguish the
   structural validator from manual or mechanically evidenced necessity review.
3. **R4 and R5:** add the explicit floor-exemption record and acceptance clause, define useful
   behavioral hook coverage, identify the gate/result evidence that enforces it, and reconcile or
   withdraw the proposed pure-guard profile.
4. **R6:** replace the ad-hoc home-path pattern with a recursive parsed/signature-normalized export
   derivation bound to the resolved toolchain commit, including declaration variants and a specified
   effect-row-variable rule.
5. Add a documentation check that recounts standardized review metadata at the commit being written;
   do not repair the repeated Status-count failure with another prose-only resolution.

**Belongs to the implementation plan, not this ADR:** implement the two classifiers and attribution
producer in one source-revision-bound change; wire their profile-load validation and recorded output
into CI; implement per-extension hook coverage/exemption reporting; build the declared-versus-performed
successor detector before relaxing conservative hook classification; and optionally extend
site-to-hook attribution into extension packages if later profiles need per-hook precision. The
extension attribution refinement is not required to make the deliberately coarse interim gate sound.

---

## Accept / revise

**Revise. The upstream API blocker remains fully in force and unchanged: acceptance still requires a
recorded-stream API in an actual AILANG release, this repository repinned to that release, and the
positive integration probe passing; the `v0.31.0` fork prototype clears none of those conditions.**
