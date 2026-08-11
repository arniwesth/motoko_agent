# Handoff: execute WI-B4 — close the repin wave

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-B2b landed 2026-08-04** (~2h05m): the world token is an opaque `ExtWorld = { token: Json }`,
`ai_step` left the classifier-2 set (3 → 2, **zero member call sites**), `make check_core` is green at
52 modules, and `make driver_only` **deliberately exits 2**. **Confirm the tree state with
`git status` rather than believing any sentence in this handoff** — four consecutive handoffs restated
commit state and all four were wrong, while the file counts were right every time.

**Read first:** `NOTE-b2b-execution-report-and-plan-corrections.md`, then B2a's, then the plan's
`## Standing rules` — **S12 is new, S11 grew a second clause, and S9's count and command were both
corrected.**

## Mission

**Close the repin wave.** B4 is its green integration gate: B1–B3 were never independently green by
design, B2a and B2b brought `check_core` back, and this item is where the wave is declared done or
not.

It is the largest accumulated list in the project, so **take it in this order** — verification before
decision, because two of the decisions depend on what verification finds:

1. **Verify** — the whole-tree sweep and `make dst`, neither of which B2b ran (budget, stated).
2. **Re-derive** — both classifiers on the new pin, with their sets and scan-root commit re-recorded.
3. **Reconcile** — the **four** artifacts that encode the old `ai_step` exclusion.
4. **Re-issue** — `driver_only`'s manifest, and the 13 stale `ailang 0.26.0` strings.
5. **Mutation loops** — B1's and B3's, both unfinished, targeted per below.
6. **A5's anchors** — nine of ten stale, and re-deriving them is yours.

## The rule you will break by accident

**B2b answered the `compaction_ai` question against the classifier-2 objection only. There is a
SECOND, independent barrier it did not reach — and on the measured evidence `compaction_ai` is still
not installable.**

B2b reports: *"Is `compaction_ai` now installable? **Yes, on the evidence**"* — reasoning that it
calls no other classifier-2 field, so the recorded omission reason is void. **That reasoning is
correct and it is not sufficient.** D5 admits a hook as covered only when it is either
**(1)** deterministic and effect-free for its explicit inputs, or **(2)** effectful only through D1
world-mediated ports with explicit world state returned. And separately: **per-hook classification
reads *declared* effect rows, not performed ones.**

Measured at HEAD — `compaction_ai`'s eight slots against the dispatch split in
`dst_profile_coverage.hook_dispatch`:

| Slot | Binding | Dispatch | Under the declared-row rule |
|---|---|---|---|
| `on_describe_tools` | `\_ . []` rowless | Unconditional | **coverable** (criterion 1) |
| `on_build_system_prompt` | rowless constant | Unconditional | **coverable** |
| `on_tool_policy` | `\_ _ . Allow` rowless | Unconditional | **coverable** |
| `on_budget_plan` | constant, but declares `! {Env, FS}` | **Unconditional** | **not effect-free** |
| `on_pre_step` | the real one — calls `ai_step`, returns `PreStepOutcome` | **Unconditional** | see below |
| `on_response_intercept` | constant + `next_state: ctx.world`, declares nine | **Unconditional** | **not effect-free** |
| `on_solver_candidate` | same shape | **Unconditional** | **not effect-free** |
| `on_tool_handle` | same shape, declares nine + `Rand` | Gated | not effect-free |

**Four unconditionally-dispatched slots are excludable-only under criterion 1**, and D5 is explicit
that an extension with **any** unconditionally-dispatched hook excluded **may not be installed** — it
must be omitted. So the omission survives its original reason's death.

**The one genuinely open question, and it is yours to decide:** does `on_pre_step` now qualify under
**criterion 2**? It reaches its effects through `ExtPorts.ai_step`, which B2b made world-mediated, and
it returns explicit world state as `PreStepOutcome.next_state`. Criterion 2 is not an effect-free
test — the declared-row paragraph constrains criterion **1**. If criterion 2 is an independent path to
coverage, `on_pre_step` may now take it; the three constant-returning nine-effect slots and
`on_budget_plan` still cannot, because they perform nothing *and* declare effects, which is exactly
the case the declared-row rule refuses to let a profile claim down.

**Decide it explicitly and record the reasoning. Do not install `compaction_ai` on B2b's sentence
alone** — and if the answer is that it stays omitted, **rewrite the omission reason**, because the one
recorded today is now false.

## The four artifacts, and they must end in agreement

| Artifact | State at HEAD |
|---|---|
| The derived classifier-2 set | **2** — `env_get`, `proc_exec`; zero member call sites |
| The pin — `tools/ext_call_inventory/fixtures/expected.json` (**note the `fixtures/` segment**) | moved deliberately, `ai_step: member` → `returns-it`; selftest green **with the pin moved** |
| `driver_only`'s omission record | **stale, and loudly red** — `make driver_only` exits 2 naming the disagreement |
| **`dst_fault_catalogue.ail:299-333`** | **stale and silent** — its `NoReachableBranch` still says `ext_ai_step` "hands the port a FRESH EMPTY world". It no longer does. B2b found this fourth one; my B2b handoff named only three |

**The fourth is the dangerous one**: it is prose inside a versioned artifact, it gates nothing, and
nothing will go red when it is wrong.

## Where the mutation loops go, and where they do not

**Target the 180 function rows, not the 123 closed-row lockstep sites.** B2a's argument holds and B2b
re-confirmed it: a closed row admits exactly one width — an implementation must *equal* its ABI
field's row — so there is no band where two answers type-check. **Function rows are different: a
wider row type-checks fine.** That is the band B1's three known over-widenings live in
(`context_mode.ail:163`, `omnigraph.ail:79`, `:113`), so the population is known to contain the
defect. And note the mechanism: the compiler reports what a body needs *given its callees' declared
rows*, so **one over-wide callee propagates a too-wide answer to every caller above it**, all of which
type-check.

**Probe from the module that FORCES the row.** B2a reproduced B1's per-file blind spot deliberately:
removing `Trace` from the `ai_step` rows reads **GREEN** probed from `compaction_ai.ail`, which
over-declares `Trace` independently, and **RED** probed from `session.ail`, where the demand arises.
Choosing the probe by convenience turns a load-bearing row into a false over-wide finding.

**And per S9 as corrected: clear EVERY live `.ailang/cache`, with both exclusions.** They are
per-directory; `rm -rf .ailang/cache` clears one. An unguarded sweep deletes `tools/code-graph`'s
**tracked test fixtures**. Do not cite a fixed count — it is however many source directories have been
compiled.

## Two detectors that fail open, and one that fails loudly

**`derive.py` fails OPEN and its failure is indistinguishable from a pass.** B2b nearly shipped that
twice: a nested paren in an argument list, and an anonymous record return type, each independently
reclassified `ai_step` as `unrouted` — which is not a milder `member`, it means *the field bypasses
the world protocol entirely*. **Read the derived membership, not the exit code.** The tool wants a
**positive control**: a fixture whose field *must* resolve to a seam and which fails loudly if it
stops. `control_resolved.ail` checks call-site resolution, not the bridge.

**`make driver_only` fails loudly and correctly.** It is red *because* the pin moved and the profile
did not. Do not silence it by reverting the pin.

## Everything else on the list

- **The whole-tree sweep and `make dst`** — B2b ran neither. `check_core` and the extension packages
  are verified; **`scripts/dst/` is type-checked only where a dependency pulled it in.** Sweep before
  trusting any tree-wide number.
- **`make attribution_table`** — expected red: **nine of A5's ten anchors were already stale at HEAD**
  before any repin edit, invisible because `make dst` exited 2 before reaching the check. B2b moved
  `session.ail`'s five further (2962 → 3028 lines, structurally unavoidable) and **held
  `ext/runtime.ail:190` deliberately** — the one that matched — by collapsing an import onto one line.
  Re-deriving the table is a D4 judgement with other consumers, and it is yours.
- **B2a's line-count guard belongs somewhere durable.** It asserts a file's line count is unchanged on
  every mechanical edit, and it caught a real `session.ail` rewrite going 2962 → 2961 that would have
  silently moved two anchors.
- **`fb_2ad074d754cd2c25` is now testable** — its probe module was blocked on `stub_step.live_ports`,
  which B2a cleared. B2b deliberately did not retest it, wanting a clean 10-run measurement. Yours.
- **The ABI is now at three changed rows plus a shape change** across B1/B2a/B2b, so the
  `motoko-ext-abi` **major and its lockstep re-release are owed.** Package versions and `[effects]`
  ceilings were left alone by every item; **no package declares `Trace` or `Rand` in its ceiling.**
- **The 13 stale `ailang 0.26.0` manifest strings** — 8 via `driver_only_manifest`, 5 inline. **Stale,
  not red**: `driver_only_dst` passed on them before B2b, because the string is *data passed in*
  rather than a value validated against the toolchain. An accuracy item, not a gate.
- **The 7 `TC_ARITY_001` smoke scripts** — a behavioural decision, not a row repair: they call `run_v2`
  with 10 of 13 arguments, they are byte-identical at HEAD, and B2a's evidence says they are
  *superseded* rather than broken (every sibling `_full_loop` script uses `run_v2_with_scripted_ports`,
  and there is **no correct in-tree caller of raw `run_v2` to copy**). Deletion or migration; both are
  somebody's decision to take deliberately.

## Definition of done

**The wave is green or the reason it is not is named.** `make check_core` exit 0, a whole-tree sweep
run cache-cold with S9's corrected command, and `make dst`'s exit status reported with each remaining
red target attributed to a class.

**Both classifiers re-derived** on v0.33.0, sets and scan-root commit re-recorded, and
`ext_call_inventory_selftest` green **with its membership read, not just its exit code**.

**All four artifacts agree**, with the conformance decision recorded either way.

**The mutation loops run over the 180 function rows**, cache-cold, probed from the forcing module —
and their result stated as *measured* or *unmeasurable*, never as clean. B1's 20 and B3's 64 were both
"unverified, which must not read as verified"; say which of those are now covered.

**Per S12** — an identity transition is correct for a component that did nothing and a silent defect
for one that did something. B2b shipped a comment-level mitigation and said so. **If you can build the
instrument — an assertion that a hook which performed a provider call did not return the world it was
given — this is the item for it.** If you cannot, say the mitigation is weaker than a check rather
than letting a comment read as one.

## Out of scope

- **Milestone C entirely**: `WI-C1` (adopt the recorded-stream API in the one `live_ports` closure),
  `C2` (the positive integration probe — D1's actual gate evidence), `C3`, `C4` (the name gate), `C5`.
- **`ExtPorts.proc_exec` / `env_get` widening** — WI-C5's, and deliberately left as live classifier-2
  members so C5 keeps a real target.
- **Removing the two v0.33.0-fixed defect workarounds** (`fb_e44ba922db1c42be`,
  `fb_b39697480a4e8bbc`). Each carries a comment pointing at its issue file; a deliberate item.

## Stop and report rather than deciding inline

- **If the sweep or `make dst` reveals a fifth frontier**, report it as a class. Four have been found
  this milestone — effect rows, `images`, the third frontier, `GeneratorBounds` — and each was
  invisible behind the last.
- **If installing `compaction_ai` would change what `driver_only` covers**, that is a conformance
  claim and a profile version bump; state the coverage delta rather than absorbing it.
- **If re-deriving A5's table changes which sites are attributed**, that changes profile-reachable sets
  and therefore `driver_only`'s routed-set claim. Report the delta.

## Report back

Twentieth calibration run, and the last of Milestone B.

- **The git wall-clock window.**
- **The conformance decision**, with its reasoning — this is the item's durable output.
- **What the mutation loops measured**, and what remains unmeasurable.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **39 across
  nineteen runs; determinism has caught none.**
- **A closing view of Milestone B**: four items, four frontiers, and what Milestone C needs that no
  item report says. C is where the name is earned, and whoever takes it will be reading D1's
  acceptance table for the first time in a long while.
