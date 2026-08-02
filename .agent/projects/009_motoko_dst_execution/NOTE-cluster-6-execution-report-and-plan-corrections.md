# Note: cluster 6 execution report — WI-A12, world-state threading, with plan corrections

Date: 2026-08-02. Status: **closed — WI-A12 complete, all six effect classes landed green.**
Handoff consumed: `HANDOFF-execute-a12-world-state-threading.md`.
Commits: `2b938e1` (probe), `4401901` (provider), `05b58c0` (clock), `dfaa8e8` (approval),
`c5347c6` (env), `ebf5788` (randomness), `3c2f4ab` (typed tool contract).

**Note on this note.** It was first written after five classes, recommending the typed tool contract
be taken as its own cluster on a sizing that turned out to be **wrong by roughly 3x**. The tool class
was then executed in the same session. The bad estimate is left visible in C7 rather than edited
away, because it is the only over-estimate in three calibration runs and the reason for it is
reusable.

Third calibration run, and the first on an item the plan sized in *days*.

## Grounding, as required

`git diff ff8d8e5..HEAD -- src packages scripts Makefile` was empty at session start, so the
handoff's anchor table was re-verified rather than re-measured. **Every anchor held** — with one
undercount, C1 below. `Ports` at 5 fields with `model_step` already state-threaded; the interim
field at `session.ail:359`; 25 `provider_state` occurrences; `dispatch_step` at `:1809`;
`ported_provider` at `:730` with a dead `_history`; four driver clock sites at `826/908/2079/2177`;
approval `readLine` at `:1692`; `c2_finalize` at `:897`; the extension model path at `:689`.
All baselines green before any edit: `check_core`, `terminal_trace`, `dst`, and the eight smoke
scripts. `probe_phase_vocab_sealed.ail` fails at baseline as documented and was not chased.

## Cost, measured

| Phase | Measured | Files | Sites |
|---|---|---|---|
| Reading both cluster reports, re-grounding, baselining, rebuilding the closure tool | ~14 min | — | — |
| **Probe** (`world_state_probe` + poison script + Makefile + CI) | **~9 min** | 3 | — |
| **Provider class** | **~7 min** | 8 | 31 |
| **Clock class** | **~16 min** | 7 | 24 |
| **Approval class** | **~10 min** | 4 | 12 |
| **Env class** | **~9 min** | 7 | 18 |
| **Randomness class** | **~3 min** | 1 | 0 |
| **Typed tool contract** | **~22 min** | 6 | 34 |
| Total session | **~92 min** | 14 distinct | 119 |
| Plan estimate | **"several days"** | | |

**All of WI-A12 landed in about an hour and a half, and per the handoff that is worth saying
plainly: it is the third confirmation.** The sites-not-files model predicts it well — 119 sites at
cluster 1's observed rate (~48 sites / 18 min of editing) predicts ~45 min against ~67 min actual
editing. The two residuals are the clock class (C2) and the tool class, both of which overran for
stated reasons.

**What this licenses.** A13, A14 and B2 are the remaining schedule risk and the plan should re-size
them against sites. But A13 is *new-artifact* work, and nothing in three calibration runs has
measured that — all three were widen-a-type-and-converge. **The rate transfers to A14 and to the
tool contract; it should not be assumed for A13's generator and replay modes.**

The 12 s parallel `ailang check` closure tool was rebuilt before editing, per both prior clusters.
It ran in **4.7 s over 19 modules** and is again what made site convergence linear — the clock class
alone produced four distinct convergence rounds, each surfacing one error per module.

## The judgement-versus-mechanical ratio

M1 measured 10%, cluster 1 measured 19% for port widenings, cluster 4 measured 27% for contract
rewrites. **A12 is both, which is why the handoff called the band genuinely informative.**

| | Sites | Judgement | Ratio |
|---|---|---|---|
| Provider | 31 | 4 | 13% |
| Clock | 24 | 9 | 38% |
| Approval | 12 | 4 | 33% |
| Env | 18 | 5 | 28% |
| Randomness | 0 | 1 | — |
| Typed tool contract | 34 | 11 | 32% |
| **Combined** | **119** | **34** | **29%** |

**29%, landing just above cluster 4's 27% contract-rewrite band and well clear of cluster 1's 19%.**
The tool class is the highest single-class ratio in three runs at 32%, which fits: it is the only one
that both introduced new values AND rewrote a return class. The
split within the item is the useful part and it is not noise: the provider class was a *rename*
(13%, below even the port-widening band), while every class that added a port shape and routed real
call sites sat at 28–38%. **The predictor is not "port widening vs contract rewrite" but whether the
change introduces a value that did not previously exist.** A rename converges mechanically; a new
cursor forces a decision at every site that consumes it.

## The question that has paid twice: did a site admit two type-checking answers with a silent wrong one?

**Yes — four times, and A12's assertions caught all four BEFORE they shipped.** Per the handoff
this is the strongest available evidence the requirement was worth imposing, so each is recorded
with what caught it and, more importantly, **what did not**.

**1. The clock class, and this is the one that matters.** The entry point performs two clock reads
before the loop starts. The loop's initial world can come from `started.next_state` (correct) or
from `provider.world` (wrong — and the *more natural* thing to write, because the constructor
already receives `provider` and reading the world off it needs no new parameter). Measured by
applying it:

- type-checks clean: `✓ No errors found!`
- **trace-completeness axis: GREEN**
- **both determinism axes: GREEN** — it is perfectly reproducible
- `duration_ms: -1`

Only the *advancement* assertion catches it. This is the concrete vindication of cluster 4's
strengthening being necessary **and** of keeping cluster 1's axis alongside it: a defect that is
reproducible and trace-complete is invisible to everything except a check that the cursor moved.
`c2_initial_state_with_counts` now takes the world as an explicit parameter for exactly this reason.

**2. The approval class.** `{ st | world_state: input.next_state }` versus carrying `st` forward.
Type-checks clean, freezes the queue, determinism axis stays green, caught by advancement.

**3. The env class.** Reverting one routed read to ambient `getEnvOr` type-checks clean and is
caught only by the provenance assertion — the determinism axis cannot see it, because an un-routed
env read is *also* perfectly reproducible when the variable is unset in both runs.

**4. The tool class, in the batch recursion.** `dispatch_tool_entries_with_builtin(ports, world, …)`
versus `(ports, executed.next_state, …)`. Type-checks clean, freezes the tool queue so the first
outcome is served for every call in the batch, and turns three of the four contract assertions red —
while **both determinism axes stay green**. There are two further sites of the same shape in the same
class, both flagged in comments at the site: `ToolDispatchDone`'s world (taking it off `st` rewinds
the world to before the batch) and `ToolDispatchPending`'s (dropping the advances of tools that
already ran before an approval interrupted the batch).

**The generalisation, and it is the transferable finding of this run: DETERMINISM IS THE WEAKEST OF
THE THREE AXES AND IT FAILED TO CATCH EVERY SINGLE DEFECT ABOVE.** It is the axis that feels most
like a proof of correctness and it caught nothing. Cluster 1's freeze, cluster 4's dropped record,
and all four defects here are consistent across runs. A13 will be tempted to lean on
"same seed twice → identical output" as its discovery-contract invariant (D7 asks for exactly that).
**That invariant is necessary and it is not sufficient**, and A13 should carry an advancement or
completeness assertion beside it.

Recorded as a fourth, smaller instance in the same family: `scripted_world_state` was written as
`{ empty_world_state() | script: script }` rather than a fresh literal, because a fresh literal must
name every field and the edit that type-checks most easily on each new class is the one that
hard-codes a default and silently diverges from the empty world. The compiler forces the *edit*; it
does not force the *right* edit.

## Plan corrections

Filed rather than reconciled, per the handoff.

**C1. The handoff undercounts the dispatch carry sites: there are SIX, not three.** It names
`1829`, `1881`, `1914`. There are also `1949`, `1979`, `2010`, all carrying `exchange.next_state`
and all downstream of the `dispatch_step` call. **Cluster 1's own report says six** ("six of the
thirteen are downstream of the dispatch call"), so the handoff's re-measured table lost three
between the report and the handoff. It changed nothing here because the rename was uniform, but a
session hand-threading those sites from the handoff's list would have frozen three of them — the
exact defect cluster 1 filed, reintroduced by an anchor table.

**C2. A12's order puts the clock second, and the clock is the class that should go LAST among the
routed ones.** It overran (~16 min against ~7–10 for the others) and every minute of the overrun was
the same cause: `clock_now` is the only port whose extension-side counterpart is **zero-argument**.
Two pinned-compiler limitations, both measured, both documented at their sites:

- **Zero-argument lambdas do not exist in expression position.** `func() ->` lexes `()` as the unit
  token; `func ( ) ->` builds a one-parameter function of unit ("arity mismatch: 0 vs 1"). Partial
  application is unsupported ("cannot unify int with TFunc2"). Only the top-level declaration form
  is zero-arity, and it captures nothing. **So no `() -> int` closure can carry the world**, and
  `ExtPorts.clock_now` therefore cannot be bridged at all on this pin.
- **`ports_shape_probe` cannot take a second function-typed parameter.** With two function-typed
  parameters carrying different effect rows the checker unifies them against the wrong slots and
  reports the rows swapped — `record field 'clock_now': r1 has extra labels [AI IO Trace]`, plus the
  mirror-image message for `model_step`. Tested with both a top-level reference and an inline lambda;
  identical failure, so it is the arity and not the argument form. The constructor keeps one
  function parameter and adapters override by record update.

The contrast that makes this a *plan* correction rather than a note: **`ExtPorts.env_get` is
two-argument, so the env class routed its extension seam in one line.** Same nominal scope boundary,
opposite outcome, and the only difference is parameter count. Had the clock run after env, the
limitation would have been found on the cheap class first.

**C3. `ExtPorts.clock_now` is bound to an ambient read ON PURPOSE, and the plan should record the
reasoning as a pattern.** Given that it cannot be bridged, there were two un-routed options: a
frozen snapshot (silently wrong, cluster 1's pinned cursor exactly, invisible to every gate) or an
ambient read. The ambient read is chosen because it makes a caller appearing before WI-C5 turn the
**Clock poison probe red** rather than silently serving a stale value. It has zero call sites today,
so nothing changes. **Prefer the un-routed option that fails loudly over the one that fails
silently** — this is the same judgement A16 was built on and it deserves to be stated once in the
plan rather than re-derived per seam.

**C4. The env class cannot have a poison pair, and the reason is a missing filesystem class.** All
six of the driver's own env reads are routed — `session.ail` has zero `getEnvOr` calls — but a
deterministic run still dies with `Env` withheld, because `context_usage.ail` reads four config
variables from `resolve_context_limit`, which the driver calls at six sites. **Those reads are not
routable alone**: the function is `! {Env, FS}` and every env read in it computes a file path it then
reads, so routing the env half would pass a poison probe while still depending on ambient state —
cluster 4's C1b defect, manufactured deliberately. A12's specified order contains no filesystem
class. Filed as `.agent/issues/context-usage-env-reads-block-the-env-poison-probe.md` with three
costed options; option 2 (hoist config resolution above the driver, six call sites, all passing the
same `model`) is the one worth costing first. **The Makefile says "DEFERRED, not skipped" out loud**
so the absence cannot later read as an oversight.

**C5. The `terminal_trace` structural guard is a `grep -c '{ result:'` over `session.ail` and it
counts comment lines.** Writing that pattern in prose — in a comment explaining the guard — turned
the gate red. Harmless here (it false-positives, it cannot false-negative) but it means the file
cannot discuss its own invariant. Worth a more precise matcher when someone is next in that target.

**C6. `driver_only`'s routed-set claim is NOT recorded, per D4's scheduling prohibition.** The four
driver clock sites are routed and the claim is now *true*; it also needs WI-A5's attribution table,
which is cluster 2 and unbuilt. Left to A10, as instructed.

## What A12 changed that the plan did not anticipate

**`ScriptedWorld(WorldState)` was added to `StepProvider`.** The approval class's assertion could not
otherwise be written: with no way to seed the world, the approval queue is always empty, and a cursor
that never advances is one a probe cannot test — the precise weakness the advancement rule exists to
prevent. It is the same `scripted_ports()` adapter with a supplied initial world. **A13 will want
exactly this seam for replay**, and it exists now.

## Behaviour changes, stated rather than left to be found

1. **`duration_ms` in a scripted run is now a virtual-clock difference, not wall time.** It is small
   and deterministic (typically 1) where it used to be 12–20. Anything treating a `Scripted` run's
   `duration_ms` as a performance measurement is now measuring the world.
2. **Scripted runs no longer read wall time at all.** A scripted run completes with `Clock` withheld.
3. **`ported_provider` lost its `history` parameter**; six call sites were passing a message list
   nothing read.
4. **Three new reachable tool outcomes.** A tool call can now come back as a typed execution
   failure, a correlation mismatch, or a deadline overrun, each reaching the model as a
   `fault_class`-tagged result message. None is reachable without a seeded world or a configured
   `MOTOKO_TOOL_TIMEOUT_MS`, so no existing run changes — but the *set* of things a tool result can
   say is larger, and a consumer matching exhaustively on tool-result shapes will see new members.
5. **`ExtPorts.proc_exec` no longer returns `""` unconditionally.** It was bound to a stub; it now
   projects the typed outcome. Zero call sites, so nothing observable changes.
6. No wire change. No golden changed. The eight smoke scripts and `scripted_ports.ail`'s six unit
   tests passed unchanged throughout, from a cold cache.

## Out of scope, honoured

The extension model path (`session.ail:689`) still hands `empty_world_state()` — D1's deliberate
exclusion. The eight `motoko-ext-compose` clock sites and `ext/runtime.ail:190` are untouched. No
profile, manifest or conformance claim. No discovery, replay or program types. The
conversation-loop `readLine` is NOT routed and says so at the site: it reads the next *user turn*,
above the traced entry point, outside D1's driver surface.

**No stop condition fired.** No class needed an interim cursor before `world_state` subsumed it (P2
never triggered — A12 *is* the subsumption). **No production code branches on test mode**: the
live/deterministic difference lives entirely in the port closure, and D1's prohibition held without
strain at every class.

## C7. The typed tool contract, and the one over-estimate in three calibration runs

This note originally recommended the tool class be taken as its own cluster, on the reasoning that it
was "plausibly comparable to the five classes above combined". **It came in at ~22 minutes and 34
sites — roughly a third of that.** The over-estimate is recorded because it is the only one in three
runs, and its cause is reusable.

**What was right.** Every structural claim held. The driver really did not use `Ports.tool_exec` —
`live_ports` bound it to `fake_tool`, which returned `""` unconditionally, so the production tool
port was a **dead stub** forwarded to `ExtPorts.proc_exec` while real execution went
`execute_allowed_tool_call` → `dispatch_one`, bypassing `Ports` entirely. Deadline information really
did not exist anywhere. And it really was a return-class change.

**What was wrong: "return-class change" was treated as a cost, when the cost is the CALLER SET.**
`execute_allowed_tool_call` has **2** call sites. `ToolDispatchOutcome` has **2** variants. The
recursion is **4 self-calls inside one function**. Changing what a function returns is only expensive
in proportion to how many places destructure it, and here that was six places in two files. Cluster
4's "rewrite a class of returns" cost 26 sites because A9's class was *seven terminal returns spread
across the driver*, not because rewriting a return is inherently dear.

**The corrected heuristic, and it is the sizing rule this run adds:** for a return-type change,
**count the destructuring sites before estimating, not the conceptual blast radius.** One `grep` for
the function name answers it. The measurement cost about 90 seconds and would have changed the
recommendation.

**One design constraint was discovered rather than predicted, and it is the reason the class is
behaviour-preserving.** An unseeded world must **delegate to the real dispatcher**: the gated smoke
scripts `smoke_v2_pending_full_loop` and `smoke_phase_a_tool_parity` execute tools for real through
this path, so a world-queue-only adapter would have silently replaced their tool results with empty
strings — and `smoke_parity` could not have caught it, since it diffs a build against itself. The
delegation is also what makes the poison pair non-vacuous, and that was verified in both directions:
the unseeded arm completes **with** `Process` and dies without it.

**A note for A10 and the D5 routing audit.** `ExtPorts.proc_exec` previously returned `""` for every
call. It now projects the typed outcome, so faults are rendered rather than dropped. It has no call
sites, so nothing changes today — but a profile claiming extension-side tool routing should know the
seam was a stub, not an implementation.

## What this note invalidates

**Cluster 1's report is invalidated by this landing and should be marked so.** A12 deleted the
`C2LoopState.provider_state` field it introduced and the `_history` parameter its C5 flagged.
Its C6 was already corrected by cluster 4's C1b. Its transferable finding — land the advancement
assertion first — is **confirmed three more times here** and should be carried forward as a standing
rule rather than a per-item clause.

This note is invalidated by any filesystem class that closes C4, and by WI-C5 routing the
extension-side clock and `ExtPorts` shapes that C2 and C3 leave un-routed. **WI-A12 itself is
complete**; A13, A14 and A15 are unblocked.
