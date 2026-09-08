# 2026-08-02 Cluster 6: WI-A12, world-state threading — six effect classes, and the axis that caught nothing

## Context

Branch: `arniwesth/mot-47-execute-wi-a12`

Session span: `2fab2f3` → `04e65b7`, **9 commits**, six of them production source. Input was
`HANDOFF-execute-a12-world-state-threading.md`, executed cold against HEAD. Third code session of
project 009, following cluster 1 (`2026-08-02-cluster-1-first-code-a1-p6-a2-port-widenings.md`) and
cluster 4 (`2026-08-02-cluster-4-terminal-trace-a16-a9.md`), both of which left findings aimed
directly at this item.

A12 is Milestone A's critical path — A13, A14 and A15 all wait on it. The mission was to thread
`world_state` through the driver, one effect class per commit, each ending green, under one binding
rule: **land the executable advancement assertion for each cursor before threading it.**

It landed all six classes. The handoff sanctioned stopping after five; the session stopped there,
reported a sizing for the sixth, and then executed it when asked — which is how the run produced its
only over-estimate.

## What landed

| Commit | Class | Effect |
|---|---|---|
| `2b938e1` | **probe** | `world_state_probe` (3 axes) + `world_state_poison` + `make world_state`, wired into CI |
| `4401901` | **provider** | `ProviderState`→`WorldState`, interim field subsumed, dead `_history` deleted |
| `05b58c0` | **clock** | all 4 driver `now()` sites routed to the world clock (P3's routed set) |
| `dfaa8e8` | **approval** | in-loop `readLine` routed; `ScriptedWorld` seam added |
| `c5347c6` | **env** | all 6 driver `getEnvOr` calls routed; `session.ail` has zero |
| `ebf5788` | **randomness** | vacuous class, guarded rather than asserted in prose |
| `3c2f4ab` | **typed tool contract** | all three of D1's parts; the real dispatch site routed |
| `cbe222f`, `04e65b7` | report | costs, 29% ratio, seven plan corrections |

**Green:** `check_core`, `dst`, `terminal_trace`, `world_state`, `smoke_driver` all exit 0 **from a
cold cache**, plus the eight driver smoke scripts and `scripted_ports.ail`'s six unit tests. No wire
change, no golden changed.

## The finding that matters most: determinism caught nothing

**Four sites admitted two type-checking answers with a silent wrong one. The assertions caught all
four before they shipped. The determinism axis caught none of them.**

The sharpest is the clock. The entry point performs two clock reads before the loop starts; the
loop's initial world can come from `started.next_state` (right) or `provider.world` (wrong — and the
*more natural* thing to write, since the constructor already receives `provider`). The wrong form:

- type-checks clean — `✓ No errors found!`
- **trace-completeness axis: GREEN**
- **both determinism axes: GREEN** — it is perfectly reproducible
- `duration_ms: -1`

Only the advancement assertion sees it. The other three follow the same pattern: a frozen approval
queue, an un-routed env read, and a frozen tool cursor in the batch recursion — each type-checks,
each is perfectly reproducible, each is invisible to determinism.

**Across three clusters that is ten such sites and determinism has caught zero.** It is the check
that feels most like a proof of correctness. Advancement caught the frozen cursors, completeness
caught the dropped records, provenance caught the un-routed read.

This matters most for **A13**, whose D7 discovery-contract invariant is same-seed-twice. That
invariant is necessary and it is not sufficient.

## Cost and ratio

| Phase | Measured | Sites |
|---|---|---|
| Reading both prior reports, re-grounding, baselining, closure tool | ~14 min | — |
| Probe + poison + Makefile + CI | ~9 min | — |
| Provider / clock / approval / env / randomness | ~7 / 16 / 10 / 9 / 3 min | 31 / 24 / 12 / 18 / 0 |
| Typed tool contract | ~22 min | 34 |
| **Total** | **~92 min** vs plan's **"several days"** | **119** |

**Judgement ratio 29%** (34 of 119), against cluster 1's 19% for port widenings and cluster 4's 27%
for contract rewrites. The within-item split is the useful part: the provider class was a *rename*
and came in at **13%**, while every class introducing a new cursor sat at **28–38%**. The predictor
is not "port widening vs contract rewrite" but **whether the change introduces a value that did not
previously exist** — a rename converges mechanically; a new cursor forces a decision at every
consuming site.

The parallel `ailang check` closure tool was rebuilt before editing, per both prior clusters. 4.7 s
over 19 modules, and again what made convergence linear — the clock class alone took four rounds.

## The over-estimate, recorded rather than edited away

The report was first written after five classes, recommending the tool contract be taken as its own
cluster because it was "plausibly comparable to the five combined". **It came in at ~22 minutes and
34 sites — roughly a third of that**, and it is the only over-estimate in three calibration runs.

Every structural claim held: the driver really did not use `Ports.tool_exec` (it was bound to
`fake_tool`, returning `""` — a **dead stub**), deadline information really did not exist anywhere,
and it really was a return-class change. **The error was treating "return-class change" as
inherently expensive.** It costs in proportion to the *destructuring sites*:
`execute_allowed_tool_call` has 2 callers, `ToolDispatchOutcome` has 2 variants, the recursion is 4
self-calls in one function — six sites across two files. Cluster 4's comparable change cost 26 sites
because A9's class was seven terminal returns spread across the driver.

**Corrected rule: for a return-type change, count the destructuring sites before estimating.** One
grep, ~90 seconds, would have changed the recommendation.

## Plan corrections filed

- **C1. The handoff undercounts the dispatch carry sites: six, not three.** Cluster 1's own report
  says six; three were lost between report and handoff. Harmless here because the rename was
  uniform, but a session hand-threading from that list would have frozen three of them.
- **C2. The clock should be the LAST routed class, not the second.** It is the only port whose
  extension counterpart is zero-argument, which on this pin cannot carry a closure at all. Routing
  the cheap instance of a seam first surfaces the limitation on the cheap class.
- **C3. Prefer the un-routed option that fails loudly.** `ExtPorts.clock_now` is bound to an ambient
  read *on purpose*, so a caller appearing before WI-C5 turns the Clock poison probe red rather than
  silently reading a frozen value.
- **C4. The env class cannot have a poison pair** — a missing filesystem class, see Issues.
- **C5. `terminal_trace`'s structural guard is a `grep -c '{ result:'` that counts comment lines.**
  Writing the pattern in prose turned the gate red; the file cannot discuss its own invariant.
- **C6. `driver_only`'s routed-set claim is NOT recorded**, per D4's scheduling prohibition — it also
  needs WI-A5's attribution table (cluster 2, unbuilt).
- **C7.** The over-estimate above.

## Issues filed

`.agent/issues/context-usage-env-reads-block-the-env-poison-probe.md` — all six driver env reads are
routed, but a deterministic run still dies with `Env` withheld because `context_usage.ail` reads four
config variables from `resolve_context_limit` (six driver call sites). Those reads are **not routable
alone**: the function is `! {Env, FS}` and every env read in it computes a file path it then reads,
so routing the env half would pass a poison probe while still depending on ambient state — cluster
4's C1b defect, manufactured deliberately. Three costed options; hoisting config resolution above the
driver is the cheapest. The Makefile says **"DEFERRED, not skipped"** out loud.

## Pinned-compiler limitations, measured

Both documented at their sites, both cost real time in the clock class:

- **Zero-argument lambdas do not exist in expression position.** `func() ->` lexes `()` as the unit
  token; `func ( ) ->` builds a one-parameter function of unit. Partial application is unsupported.
  Only the top-level declaration form is zero-arity, and it captures nothing — so **no `() -> int`
  closure can carry the world**, which is why `ExtPorts.clock_now` cannot be bridged at all.
  `ExtPorts.env_get` and `proc_exec` are two-argument and *were* routed: same nominal scope boundary,
  opposite outcome, sole difference being parameter count.
- **`ports_shape_probe` cannot take a second function-typed parameter.** With two such parameters
  carrying different effect rows the checker unifies them against the wrong slots and reports the
  rows swapped. Adapters override by record update instead.

## Design notes worth carrying

- **`ScriptedWorld(WorldState)`** was added to `StepProvider` because the approval assertion could not
  otherwise be written — an always-empty queue is a cursor a probe cannot test. **A13 wants this seam
  for replay** and it now exists.
- **An unseeded tool world must delegate to the real dispatcher.** `smoke_v2_pending_full_loop` and
  `smoke_phase_a_tool_parity` execute tools for real through that path; a world-queue-only adapter
  would have silently replaced their results with empty strings, and `smoke_parity` could not have
  caught it since it diffs a build against itself.
- **No production code branches on test mode.** The live/deterministic difference lives entirely in
  the port closure. D1's prohibition held without strain at every class.

## Out of scope, honoured

The extension model path still gets `empty_world_state()` (D1's exclusion). The eight
`motoko-ext-compose` clock sites and `ext/runtime.ail:190` untouched. No profile, manifest or
conformance claim. No discovery, replay or program types. The conversation-loop `readLine` is **not**
routed and says so at the site — it reads the next *user turn*, above the traced entry point.

**No stop condition fired.** P2 never triggered: A12 *is* the subsumption.

## Downstream — what happened to these findings

Already absorbed by the author in `8ff54ff` and `aa55aa0`, before this summary was written:

- The three-axes finding became a **standing rule** in the plan ("assert advancement *and*
  completeness — never determinism alone"), and was folded into the measurement meta-decision
  `build-detectors-instead-of-specifying-them.md`.
- **S3, "route the cheap instance of a seam before the awkward one"**, is C2 generalised.
- The destructuring-sites rule is now the plan's sizing guidance for return-type changes.
- A13's acceptance gained a **non-determinism assertion beside** its same-seed-twice invariant.
- The author recorded C1 as their own anchor defect.

## Next

Cluster 3 (WI-A6, A7, A8) was handed off in `109555d`. A13/A14/A15 are unblocked. Still open:
the filesystem class that would close C4, and WI-C5 for the extension-side clock and `ExtPorts`
shapes that C2 and C3 leave un-routed.
