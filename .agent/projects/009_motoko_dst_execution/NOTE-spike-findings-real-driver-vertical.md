# Findings: vertical spike through the real driver

Date: 2026-07-31. Status: complete, dispositioned into this note.

_Executed `PLAN-spike-real-driver-vertical.md` in full. All five questions resolved: Q1, Q2, Q4 and
Q5 confirm, Q2's second clause falsifies, Q3 is measured._

_Revision: motoko `6382dc8` on throwaway branch `spike/009-real-driver-vertical`, forked from
`4aaf59f`. **That branch never merges** — it is published only so the code behind these findings can
be read (draft PR #103, which would conflict in six files and revert the WI-C13c fix `89a1d67`, a
commit it predates). It carries the throwaway driver surgery and nothing else: this note,
`spike/README.md`, the F6 probe and the refreshed upstream issue were stripped from it after being
cherry-picked here, so there is exactly one copy of each._

_Toolchain: **released AILANG v0.31.0** (`1f6f7dd28`), carrying one addition — a
`stepWithStreamRecorded` prototype plus its Go tests. That is published at
`https://github.com/arniwesth/ailang`, branch `spike/motoko-009-prototype-v031`, with the `v0.31.0`
tag pushed alongside so the compare against the released base renders for anyone. The in-repo clone
at `ailang/` is repointed to match: `origin` is that fork, `upstream` is `sunholo-data/ailang` with
its push URL disabled so an upstream push cannot happen by accident._

The narrative, the executed commands, and the recorded output live in
`spike/README.md`, section *"Vertical spike through the real driver"*. This note carries only what
has to be acted on: five findings against the ADR (F1–F5), one confirmed defect in the DST harness
itself (F6), two measurements the implementation plan should cite instead of estimating, and an
explicit statement of what the spike does **not** establish.

## What this note does not change

**The D1 substrate gate is exactly where it was.** Released v0.31.0's `std/ai` still exports no
recorded-stream API; the spike used a locally built prototype. D1 requires the API to have landed
and the toolchain to be repinned to a released version containing it. A prototype on top of a
released toolchain is still not that. Nothing here is grounds for calling D1 cleared, and the
upstream issue remains the only item on this project with third-party latency.

## Findings against the ADR

Filed in the same shape as the two prior reviews, so they can be dispositioned the same way.

### F1. D1 does not say who owns the provider cursor once `world_state` exists, and the wrong answer compiles clean

**Defect:** `ADR:158-163` forbids hiding the program cursor in `SharedMem`, process-global
mutation, an ambient RNG, or a mutable test singleton. It says nothing about an *already
explicitly-threaded* cursor that predates `world_state`. Motoko has exactly one: `StepProvider`
carries the remaining `Scripted` script in its ADT payload and the driver threads it through
`C2LoopState.provider`. When `world_state` arrives there are two defensible homes for it and the
ADR selects neither.

**Grounding:** The first implementation put the provider inside the adapter — `LiveWorld(StepProvider)`
— which is the natural reading of *"a live world delegates requests to evolved production adapters"*
(`ADR:245-249`). It type-checked, `check_core` stayed 35/35 green, and **6 of 18 scenarios in
`scripts/dst/phase_c2_wiring_scenarios.ail` failed with "step budget exhausted"**: capturing the
provider in the adapter froze the script cursor, so every step replayed step 0. Moving the provider
back out — passing it per request and returning `next_provider` — restored 18/18. Both arrangements
satisfy the letter of D1, because both return the next state explicitly.

See also F2, which sharpens this question rather than merely relating to it. The reason the wrong
answer *ran at all* is that capturing the raw provider resurrects `dispatch_step`'s
otherwise-unreachable `Scripted` branch, whose cursor is the threaded ADT tail. And the reason it is
hard to answer "who owns the cursor" from the source is that **the provider the DST actually runs
has no cursor to own**: `scripted_ports_from_steps` re-derives its position from
`assistant_count(msgs)` on every call. Of the three scripted implementations in the tree, the two
that thread state explicitly are both disconnected. So D1's premise — explicit state threading — is
not merely unstated for this seam, it is currently contradicted by the only implementation that
executes.

**Action:** D1 must name the owner. Recommended: `world_state` owns all replay/generator cursors,
and the implementation plan retires `C2LoopState.provider` rather than leaving two homes for the
same fact. Concretely, that means the live scripted provider stops deriving its index from
`assistant_count` and starts consuming a threaded cursor — either `ScriptedPortsState`, which
already exists and is tested, or the world program itself. Deriving replay position from mutable
history is the one arrangement D1 should rule out by name, because compaction mutates history. Whatever is chosen, state it, because the failure mode is silent — green types, green
type-check gate, wrong behaviour only visible in a multi-step scenario.

### F2. D1's sequencing hides a mandatory, upstream-independent change behind the upstream gate, and the obvious place to adopt the new API is dead code

**Defect:** D1 is not wrong about *what* is required — `ADR:229-230` does say "the provider exchange
wraps the existing typed `Result[StepResult, AIError]` with its ordered intermediate-emission log".
The defect is narrower and entirely about **where and when**:

1. The bullet never names the concrete site. Compare it with the bullet directly beneath, which
   names `tool_exec(string, string) -> string` explicitly. The provider bullet leaves
   `Ports.model_step` unnamed, so it reads as a property of the future world protocol rather than an
   edit to a record that exists today.
2. `ADR:206-207` then says "until then, complete streaming trace parity is blocked and production
   migration must not begin." A planner reading D1 top to bottom sequences: wait for upstream →
   adopt the new API → replace `Ports` with the world protocol later. **That ordering is the trap.**
   The port widening has no upstream dependency and must happen first; deferring it behind the gate
   guarantees an empty emission log through the adoption step and most of the migration.
3. The site a reader would pick for the adoption step is unreachable.

**Grounding — the funnel.** `src/core/session.ail:732` (pre-spike `4aaf59f:692`):

```ailang
func ported_provider(rt: ExtRuntime, history: [Message], provider: StepProvider) -> StepProvider {
  match provider {
    Ported(_)      => provider,
    LiveAI         => Ported(live_ports(rt)),
    Scripted(script) => Ported(scripted_ports_from_steps(history, script))
  }
}
```

All four entry points into the loop call it before `c2_loop` runs
(`4aaf59f:1992, 2091, 2268, 2296`), and every one passes the *normalised* value:
`c2_initial_state_with_counts(history, live_provider, ...)`. `dispatch_step`'s `Ported` branch
returns `next_provider: Ported(ports)` unchanged, so the state never leaves `Ported`.

**Grounding — the invariant.** `st.provider` is `Ported(_)` everywhere inside the loop, and this is
checkable rather than probable:

- Exactly two functions construct the initial `C2LoopState`
  (`run_v2_from_messages_traced_with_policy_and_counts`, `run_v2_from_messages_with_policy_and_counts`,
  at `4aaf59f:1994` and `4aaf59f:2093`) and both pass `live_provider = ported_provider(...)`.
- All fifteen successor literals assign either `st.provider` or `next_provider`
  (`4aaf59f:1369,1414,1467,1490,1568,1593,1668,1745,1796,1828,1862,1891,1921`).
- `next_provider` is `dispatch_step(...).next_provider`, and its `Ported` branch returns
  `Ported(ports)` unchanged.
- The only two `provider: LiveAI` literals in the file (`4aaf59f:2489,2539`) are inside pure test
  functions that build a `C2LoopState` to feed `runtime_status_json`; neither reaches `c2_loop`.
- `c2_initial_state` (`4aaf59f:614`), the wrapper that would let a caller bypass the counts variant,
  has zero callers.

**Grounding — the dead branch.** `StepProvider` is a three-variant ADT
(`LiveAI | Scripted([ScriptedStep]) | Ported(Ports)`) and `dispatch_step` matches all three, but
`dispatch_step` has exactly one caller in the repo (`4aaf59f:src/core/session.ail:1729` — the other
`git grep` hits are unrelated `tools/code-graph` test fixtures) and that caller passes `st.provider`.
By the invariant above, **`dispatch_step`'s `LiveAI` and `Scripted` branches are unreachable from
every session entry point.** The type says three providers; the runtime has one.

`ext_ports_for_provider` (`4aaf59f:680`) is a second instance of the same thing: the same three-way
match, four call sites (`1619, 1646, 1693, 1777`), every one passing `st.provider` or
`next_provider`, so its `LiveAI` and `Scripted` branches are dead too.

**To be precise about what is dead:** the `Scripted` *variant* is not. It is the DST's public
injection API and is load-bearing — `scripts/dst/phase_c2_wiring_scenarios.ail:120,126,184` and
`scripts/dst/runtime_status_tool_dst.ail:56` all call
`run_v2_session_traced(..., Scripted(script))`. What is dead is `dispatch_step`'s *handling* of it.

**Provenance — this is a half-completed refactor, not rot.** `dispatch_step`'s three branches were
all live when introduced (`2145ca51`, M-MOTOKO-STUB-STEP: StepProvider injection). Commit `f30f475`
(2026-07-05), titled *"WI-C13c Wire model dispatch through ports"*, added `ported_provider` and
inserted it at both loop entry points. It did exactly what its title says — funnelled all model
dispatch through the `Ports` seam — and left `dispatch_step` untouched. The normalization landed,
the superseded dispatch was not deleted, and nothing failed because the tests continued to pass
through the new path. That is worth stating plainly in the note, because it tells the plan what kind
of work this is: finishing WI-C13c, not repairing a regression.

This is worse than ordinary dead code, in three specific ways.

*It is a decoy at exactly the spot the migration aims for.* `dispatch_step`'s `LiveAI` branch is the
**only** appearance of `std/ai.stepWithStream` in the driver's call graph. It is where a reader
adopting the recorded-stream API would put it. Doing so compiles, passes every test, and changes
nothing observable.

*It defeats the source audit that D4 and D5 rely on.* `ADR:476-480` names the "source and ABI
routing audit" as the detector a profile depends on, in preference to the coarse capability
backstop. A grep for `stepWithStream` returns two hits in `stub_step.ail` — `dispatch_step`'s dead
`LiveAI` branch and `live_ports`' live closure — and only the second is reachable. The same is true
of `tools_with_extensions(rt)` and `system_prompt_cache_breakpoint()`. **An audit that is textual
rather than reachability-aware certifies the wrong seam**, and D5 does not say which kind it must be.

*It is one of three scripted-provider implementations, and the only one that runs threads no
cursor at all.* This is the part with consequences beyond tidiness. Scripted provider behaviour
exists three times in the tree:

| Implementation | Cursor model | Reachable from a session run? |
|---|---|---|
| `dispatch_step`'s `Scripted` branch | ADT tail, threaded explicitly — `next_provider: Scripted(rest)` | **No** — `ported_provider` converts first |
| `scripted_ports_from_steps` closure (`stub_step.ail:159`) | **derived** — `assistant_count(msgs) - base_assistant_count`, recomputed per call | **Yes — the only one** |
| `ScriptedPortsState` + `scripted_model_next` (`src/core/test/scripted_ports.ail`) | explicit threaded state record, with a passing `test_scripted_model_threads_state` | **No** — unit-tested, never wired in |

The third is the clearest signal that this is unfinished rather than intended: it models threaded
scripted state properly, its companion `fake_model` returns
`Err("use scripted_model_next for state-threaded tests")` pointing at it, and the function that
would consume it — `run_v2_with_scripted_ports` — calls `scripted_ports_from_steps` instead.

**So the only scripted provider the DST executes is the one that does not thread a cursor.** It
re-derives its position on every call by counting assistant messages in the history it was handed.
Both implementations that thread a cursor explicitly — which is exactly what D1 requires — are
disconnected.

That derived index is not merely inelegant. It is broken under compaction, and the failure is worse
than a rewind — see **F6**, which was raised here as a hypothesis and has since been confirmed
against the real driver.

**Grounding — why the type system cannot help.** The live provider call is not in the driver at all.
It is inside a closure built by `live_ports(rt)` (`src/core/test/stub_step.ail:150`) and stored in a
function-valued record field whose declared type was
`(string, [Message], (StreamChunk) -> () ! {IO}) -> Result[StepResult, AIError] ! {AI, IO, Trace}`.
The chunks are discarded at closure construction, one layer *above* `std/ai`. Nothing downstream can
recover them, and no amount of propagation from the upstream API reaches past that boundary. It is a
lossy crossing, not a missing wire. Widening the field to
`{ emissions: [StreamChunk], result: Result[StepResult, AIError] }` was required before discovery
recorded anything.

**Action:** two changes to D1, one to the plan's ordering.

- Name the site. The provider bullet at `ADR:229-230` should name `Ports.model_step` the way the
  tool bullet names `tool_exec`, and should say the log is a property of the **port**, not only of
  the world protocol or the upstream API.
- Carve the port widening out of the blocking clause at `ADR:206-207`. It has no upstream
  dependency: the field can be widened today with `emissions: []` at every construction site, and
  the change is independently testable against `Scripted` providers with no provider access at all.
  Doing it first shrinks the upstream dependency's blast radius to a single closure in `live_ports`,
  which is the strongest de-risking available on this gate.
- **Finish WI-C13c.** Delete the unreachable `LiveAI` and `Scripted` branches in `dispatch_step`
  and `ext_ports_for_provider`, and collapse the three scripted implementations to one. That is a
  single coherent piece of work, not three cleanups: it removes the decoy at the migration site,
  removes the divergent cursor that let F1's wrong answer look like it worked, and forces a decision
  about which cursor model the DST's scripted provider actually uses. If the three-variant
  `StepProvider` shape is deliberately retained as a compatibility surface for the older entry
  points, say so in the code, and say that `Ported` is the only inhabited variant inside `c2_loop`.
- **D5 must state that the routing audit is reachability-aware, not textual.** A grep-based audit of
  this driver reports `stepWithStream` as a live seam when it is not. That is a false positive on
  the detector D4 says a profile depends on, and it is not a hypothetical: it is the current state
  of the tree.

**Generalisation, for the plan rather than the ADR.** Every `Ports` field is a lossy crossing of the
same kind, and D1 explicitly budgets only one of them — the tool contract. `approval_read` and
`clock_now` are narrow enough that the loss is invisible today, but `model_step` is the one that
gates D1 and it is the one the ADR does not name. When the plan works through D1's request surface,
the ordering rule should be general: **widen the port before adopting whatever fills it**, because
the port is where the information is thrown away.

### F3. D4 mischaracterises the withheld-`Clock` backstop

**Defect:** `ADR:477-480` describes withholding the `Clock` capability as "a build-and-profile-level
gate, not an in-execution one". It is neither. It is a **run-time** check.

**Grounding:** `{Clock}` stays in the effect row; AILANG only fails when a read is actually
*performed*. Minimal probe: a function whose row contains `{Clock}` but whose taken branch never
calls `now()` runs to completion under `--caps IO`. Against the real driver, the deterministic
entry point completes with `Clock` withheld (4/4 assertions, exit 0) while the live world on the
same driver dies with `effect 'Clock' requires capability, but none provided`.

**Action:** Restate the property accurately, because the correction cuts both ways and both halves
matter to a profile. It is *stronger* than D4 assumes — it catches unrouted reads on paths the run
actually takes, not merely declared ones. It is also *weaker* — it says nothing about reachable
paths a given run did not exercise, so it cannot on its own discharge D4's all-or-nothing routing
requirement. The source/ABI audit remains the primary detector; this is a per-run backstop.

### F4. D4's profile-reachable clock set is 14, not 4 — and the seam that fixes nine of them exists with zero users

**Defect:** The plan's Q2 asked whether the reachable set is "materially larger than the four reads
the review counted" (`PLAN-spike-real-driver-vertical.md:48`). It is, by 3.5×, and the extra reads
sit in extension packages with their own version surfaces.

**Grounding:**

| Location | Reads | State after the spike |
|---|---|---|
| `src/core/session.ail` driver | 4 | routed through the world |
| `src/core/session.ail:2416` (`conversation_loop_v2`) | 1 | unrouted — above the traced entry |
| `src/core/ext/runtime.ail:190` (`test_dummy` hook) | 1 | unrouted |
| `packages/motoko-ext-compose` (compose 6, `author_tools` 1, `authoring/dispatcher` 1) | 8 | unrouted |

All nine extension-side reads are reachable under the default profile: `handle_compose_tool` is the
`on_tool_handle` hook, so any session in which the model calls `Compose` performs them. The seam
that would route them already exists — `ExtPorts.clock_now` in `packages/motoko-ext-abi/types.ail`
— and `grep -rn "ports.clock_now"` across the whole repo returns **nothing**. No extension has ever
used it, so the seam has never been exercised and may not survive first contact unchanged.

**Action:** D4/D5 should say that a profile installing `compose` cannot claim conformance until
those eight reads route through `ExtPorts.clock_now`, and the implementation plan should budget the
extension-side work rather than treating "route the clock" as a core-only task.

### F5. D6's versioned event-vocabulary artifact does not exist, and the one naming function in the repo is too lossy to check against

This is a gap rather than a contradiction, but it blocks a check the ADR requires.

**Defect:** `ADR:664-686` makes the event vocabulary "the fifth recorded axis" — a versioned
artifact binding every `LedgerEvent` variant to its wire name, payload schema, and
logical/display-only classification, validated at load and failing closed on an unclassified
variant. Nothing implements it.

**Grounding:** `src/core/phase_vocab.ail:561 ledger_record_name` is the only naming function in the
repo. It names **3 of the 34** variants (`provider_call_prepared`, `ext_compaction_rejected`,
`extension_diagnostic`) and collapses the other 31 to the literal string `"wire"`. The spike's D6.1
check — "the `RunSummary` is the final record in the returned trace" — could not be written against
it and needed a bespoke matcher. The ADR already notes the wire names live in trailing comments
(`ADR:676`); what it does not note is that the existing helper is not a partial implementation of
the artifact, it is a different thing that cannot be grown into one.

**Action:** Keep the artifact in D6 but stop implying the mapping merely needs formalising. The
implementation plan should treat it as new construction with a fail-closed validator, and should not
schedule any D7 parity invariant or acceptance row that depends on the logical/display-only
classification before it exists.

### F6. The DST's scripted provider silently loops forever under folding compaction (confirmed defect in the code, not the ADR)

**Defect:** `scripted_ports_from_steps` derives its script index from
`assistant_count(payload) - assistant_count(initial_history)`, where `payload` is the
**post-compaction** message list actually sent to the provider (`session.ail`, the `CallModel`
branch, passes `compacted_msgs`). A compactor that folds turns into a summary caps the payload's
assistant count. The index then stops advancing while the real history keeps growing, so the same
scripted step is served on every subsequent iteration until the step budget is exhausted.

This is not an ADR gap. It is a live defect in the DST harness, reachable in the default profile.

**Grounding:** `scripts/dst/spike_scripted_cursor_probe.ail` drives `run_v2_session_traced(...,
Scripted(script))` twice with the same five-step script — four continuers with distinguishable
prose, then a terminator — and the same driver entry point, varying only the `on_pre_step` hook.
The folding hook reproduces `motoko_ext_compaction_ai`'s shape exactly
(`prefix ++ [summary_msg] ++ recent_turns`) with no AI call, so the result is about the cursor and
nothing else. The served sequence is read from the returned trace's `ProviderResult` records, which
works on the error path too.

```text
control: outcome=ok
control: served=[s0,s1,s2,s3,done]                      advancing=true

folding: outcome=err Internal: v2 loop: step budget exhausted
folding: served=[s0,s1,s2,s2,s2,s2,s2,s2,s2,s2,s2,s2]   advancing=false
```

Instrumenting the hook shows the mechanism directly — the real segment grows on every step while the
folded payload's assistant count pins at two:

```text
PRESTEP step=1  segment_in=3  assistants_in=1  -> segment_out=3  assistants_out=1
PRESTEP step=2  segment_in=5  assistants_in=2  -> segment_out=3  assistants_out=2
PRESTEP step=3  segment_in=7  assistants_in=3  -> segment_out=3  assistants_out=2
PRESTEP step=4  segment_in=9  assistants_in=4  -> segment_out=3  assistants_out=2
...
PRESTEP step=11 segment_in=23 assistants_in=11 -> segment_out=3  assistants_out=2
```

Re-verified on the **pinned v0.26.0 toolchain**, on `arniwesth/mot-44-motoko_dst_execution_primer`,
with byte-identical output. The defect is in the driver, not an artifact of the spike's v0.31.0
repin.

So the behaviour is a **pin, not a rewind** — which is the worse of the two. A rewind would replay a
visibly wrong step; a pin produces a run that looks like an ordinary budget exhaustion. Nothing
crashes, no invariant fires, and the terminal step is simply never reached.

Two things bound the severity honestly:

- **It is not firing in CI today.** Structural compaction cannot trigger it: `elide_old_tool_results`
  shortens tool-result content and never removes a message, so the assistant count is unchanged.
  Current `Scripted` scenarios have histories far below the default context limit, so
  `compaction_ai` — which does fold this way — never engages.
- **Project 009 is about to make it reachable.** D2's seeded generation of longer execution programs
  and D8's replay of them are exactly the conditions that push a scripted run past the compaction
  threshold. The bug is latent now and would surface as "the generator produced a program that
  exhausts its budget", which is close to indistinguishable from a real result.

**Action:** fix the cursor, not the compactor. The scripted provider must consume a threaded cursor
rather than deriving position from a mutable, compactable message list — `ScriptedPortsState`
already models this and is unit-tested, or the world program can carry it directly once D1 lands.
Deriving replay position from history is the specific arrangement D1 should rule out by name (F1),
and this is the concrete reason why. Until then, no generated DST program should be run through
`Scripted(...)` with any folding compactor installed, because the result is not trustworthy.

## Defect fixed in passing, worth recording

**Q4's starting count was zero, not one.** All seven terminal returns in `c2_loop` called
`emit_run_summary`, which only ever called `ledger_emit`. The returned `LedgerTrace` contained no
`RunSummary` record on *any* path. That is the exact case `ADR:643-644` warns about — "an external
`ledger_emit` call is not evidence that the event is in `LedgerTrace`; the returned trace is
authoritative" — and it was true of the entire driver at HEAD, not of a hypothetical future event.

Routing all seven through one `c2_finalize` (emit the projection **and** append the same record) was
tractable and did not restructure the driver beyond what the ADR budgets. D6.1 is reachable; it was
simply unsatisfied everywhere.

## Measurements for the implementation plan

### M1. The `Message` migration costs 14 minutes and 28 files, and it is not additive

Measured against the **released** v0.31.0 record shape, not an approximation.

| | |
|---|---|
| Wall clock | 14 min, agent-driven, including writing the tooling |
| Files touched | 28 `.ail` |
| Sites given `images: []` | 69 |
| Over-applications a mechanical pass made and had to revert | 47, every one a `Msg`-typed literal |
| Sites needing genuine judgement | 7 |

The number to carry forward is not 69. `src/core/types.ail` documents `Msg` as "structurally
identical to `std/ai.Message` and `motoko_ext_abi.Msg`", and the codebase relies on it: `Message`
values cross into `[Msg]`-typed APIs implicitly in seven places. Widening `Message` breaks that
identity and each crossing becomes a compile error needing a written conversion — a
`messages_to_msgs` export had to be **added** to `phase_vocab`, and one smoke helper retyped
end to end. A grep-derived estimate counts the 69 additive sites and misses all seven that took
thought.

One architectural decision gates the other 116 edits and should be made explicitly rather than
discovered: **Motoko's `Msg` and the ext-ABI `Msg` stay at four fields**, vision parts dropped at
the seam. Widening the ABI `Msg` is a separate versioned-surface decision.

Planning note: the compiler reports **one record-field mismatch at a time** across the whole module
graph, so naive convergence costs one round-trip per site. The 14 minutes holds only because a
brace-balanced literal rewriter and a compiler-driven fix loop were written first.

### M2. The v0.26.0 → v0.31.0 repin forces an extension-ABI major version

This was not in the plan's scope. It is in the plan's *path*: D1 requires the toolchain repinned to
a released version containing the new API, so this cost is unavoidable and should be sequenced.

| | |
|---|---|
| Files needing effect-row corrections | 71 |
| Effect-row edits | 381 |
| Extension-ABI widenings | 3 |
| Files failing before repair / after | 67 / 0 new |

v0.31.0's effect checker rejects functions **and lambdas** that perform effects their signature does
not declare, which v0.26.0 accepted. Almost all 381 edits are mechanical corrections the compiler
names precisely, and a compiler-driven repair loop converged in a few rounds. Three are not
mechanical, because they change `packages/motoko-ext-abi/types.ail`:

1. `ExtPorts.ai_step` gains `Trace`. It calls `Ports.model_step`, which has always been
   `{AI, IO, Trace}`. The declared row was simply wrong.
2. All four `ExtensionHooks` rows gain `Rand`. `packages/motoko-ext-a2a` calls `uuid4()` inside
   `on_tool_handle`, an effect the hook row never declared — a latent ABI defect, now a hard error.
3. The same four rows gain `Trace`, following from (1).

`packages/motoko-ext-abi/types.ail:7` states that "Bumping `ExtensionHooks` is a major version of
motoko-ext-abi". **So repinning is not a toolchain bump; it forces an extension-ABI major and a
coordinated re-release of every extension package.** That is a scheduling fact independent of what
upstream does about the recorded-stream API, and it should appear in the plan's sequencing rather
than surfacing during Track 1.

Two smaller repin findings:

- Two latent under-declarations in first-party code that v0.26.0 accepted:
  `src/core/agents_md.ail walk_agents` performs `FS` undeclared, and
  `packages/motoko-ext-omnigraph/register.ail register_with_config` performs `Process` undeclared.
- **The stale-compile-cache hazard already documented in `spike/README.md` reproduced, this time
  across a compiler *version* change rather than a stdlib one.** Mid-repin, `src/core/rpc.ail` and
  `src/core/supervisor.ail` reported an `ExtPorts.ai_step` row mismatch against source that was
  already correct; clearing every `.ailang/cache` in the tree fixed both with no source change. The
  lesson holds twice now: clear the compile cache before believing any type error that follows a
  toolchain change, and before quoting one upstream.

## Substrate notes

Both were reduced to minimal repros and both reproduce against the **stock** `std/ai.stepWithStream`
on v0.31.0, so neither is a property of the prototype and neither is an upstream bug report. They
are migration ergonomics worth knowing in advance:

- A single callback value cannot be passed to both `dispatch_step` (`{IO, Trace}`) and
  `std/ai.stepWithStream` (`{IO}`): `incompatible closed rows: r1 has extra labels [], r2 has extra
  labels [Trace]`. Either call alone is fine. Workaround: call the port directly rather than routing
  through `dispatch_step`.
- The chunk callback must be written as `func(c: StreamChunk) -> () ! {IO} { ... }`. The `\c. ...`
  lambda form fails to unify against the closed `{IO}` row.

## Resuming this work

`HANDOFF-post-upstream-recorded-stream-landing.md` is the triggered handoff for the session that
picks this up — it carries the trigger condition, the ordered open items, the traps that cost time
during the spike, and the loose threads (including two found here but not dispositioned: the
hardcoded `checkpoint_enabled: false`, and the unexplained module-sensitivity behind AILANG #386).

## Disposal

The code dies with the branches — `src/core/world.ail`, `scripts/dst/spike_world_vertical.ail`, the
`session.ail` / `ports.ail` / `stub_step.ail` edits, and the AILANG prototype. What survives is this
note plus the narrative in `spike/README.md`.

Of what survives, one part is throwaway and one is not. The 381 mechanical effect-row edits are
throwaway — they will be redone by whoever repins for real. The three ABI widenings, the two latent
under-declarations, and the six findings are not: they are defects that exist at HEAD today and will
still be there when the branch is deleted.

One piece of spike code is worth keeping rather than deleting:
`scripts/dst/spike_scripted_cursor_probe.ail`. It is thirty lines of fixture around a two-scenario
comparison, it needs no provider and no network, and it is the only executable statement of F6. If
the cursor is fixed it becomes a passing regression test; if it is not, it keeps failing for the
right reason. Everything else in the spike should go.

Expect another ADR revision round. Five findings from one spike, on decisions two reviews had
already read, is the plan's own prediction coming true — executing finds what reading does not — and
it means the next revision should be budgeted rather than treated as a formality.
