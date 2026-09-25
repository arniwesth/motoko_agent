# Handoff: execute WI-B2b — the world-token widening

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

**WI-B2a landed 2026-08-04** (2h13m): the ABI answer was **two rows, not four**, `make check_core` is
**green** for the first time since the repin, and the tree is **218 pass / 17 fail** — above the
v0.26.0 baseline of 213/22. **B2a's work is uncommitted: 79 source files plus `ailang.lock`, on
`arniwesth/mot-57-execute-wi-b2-part-1`.** Confirm that before starting; three handoffs in a row have
got the commit state wrong in one direction or the other, and this one is stating what B2a's report
stated plainly.

**Read first:** `NOTE-b2a-execution-report-and-plan-corrections.md`, then the plan's
`## Standing rules` — **S9 has been rewritten and partly refuted, and S11 is new.** Both matter here.

## Mission

**The world-token widening: `ExtPorts.ai_step`, the hook results, and the core dispatch results.**
This is the change D5 already requires and D1 defers to, and it is **the last of Milestone B's
content**. B4 is the wave's green gate and follows.

Also in scope, because B2b is the free moment for them: **the two `ScriptedStep` widenings**. They are
**two separate changes** and earlier revisions of this plan conflated them with each other and with
D4's latency pair — a provider **fault** needs an *error case*, a provider **latency** needs
`advance_ms`. Doing them inside this wave pays the anchor cascade once instead of twice.

## The rule you will break by accident

**This is the change that is SUPPOSED to move a pinned artifact — and the pin will look like a
regression.**

D5's classifier-2 membership criterion is *"a field whose call is the extension-side entry to a core
seam that D1 requires to thread successor state, **and which cannot return it**."* Read the derived
output at HEAD:

```
ai_step   member    ExtPorts.ai_step returns Result[string, string] and cannot carry it
proc_exec member    ExtPorts.proc_exec returns string and cannot carry it
env_get   member    ExtPorts.env_get returns string and cannot carry it
clock_now unrouted  the bridge reaches no core Ports seam
CLASSIFIER-2 SET (3): ai_step, env_get, proc_exec
```

**Every one of those three is a member *because it cannot return successor state*. Giving it a world
token is exactly the condition that removes it from the set.** So:

- `tools/ext_call_inventory/expected.json` carries a **pinned `membership` block**, checked by
  `derive.py:652`. B2a verified it **unchanged** and reported that as confirmation the row corrections
  did not move classifier 2's answer. **B2b is the change that should move it.**
- **A session that edits the pin to keep the selftest green has destroyed the signal.** The pin exists
  to make this exact transition loud. Move it *deliberately*, and say in the report which fields left
  the set and why the criterion no longer selects them.

**And the conformance consequence is larger than the pin.** `driver_only` **omits `compaction_ai`**,
and its recorded reason is precisely this criterion — `dst_driver_only.ail:226` says so in as many
words, ending *"Widening `ExtPorts` is Milestone B's ABI major, not a fix available here."* **You are
that fix.** If `ai_step` stops being a classifier-2 field, the omission's stated reason no longer
holds, and `driver_only` must be re-issued with the record corrected. **That is a profile version
bump, and it is D5's rule, not an optional tidy-up.**

**Do not, however, assume the omission simply disappears.** D5 also rejects installing an extension
with an unconditionally-dispatched hook excluded, and seven of eight slots are unconditional. Whether
`compaction_ai` becomes *installable* is a separate question from whether it stops being a
classifier-2 caller — **answer both, separately, and state which changed.**

## What "world token" means here, and the one shape decision

D1: `ExtPorts.ai_step` returns `Result[string, string]` and the hook results above it are
**decision-only**, so a successor has no way back to `C2LoopState`. That is the whole of the
exclusion. Lifting it needs the token to travel **in and out** at three levels:

| Level | Today | Needs |
|---|---|---|
| `ExtPorts.ai_step` | `(string, [Msg]) -> Result[string, string] ! {…, Trace}` | to take and return the token |
| Hook results — `ToolHandleDecision`, `PreStepDecision`, `ResponseInterceptDecision`, `FinalizeDecision` | decision-only sums (`Handled(…) \| Delegate`, …) | to carry the successor alongside the decision |
| Core dispatch results | unchanged | to thread it back to `C2LoopState` |

**D5 permits either representation** — "an explicit/opaque world token passed into the hook's effect
adapter, returning the successor with the hook decision, **or** an equivalent host-owned linear state
protocol". **Choose one and record why**; the ADR delegates it and it is the item's central decided
binding.

**A12's precedent is the one to copy, and it is measured.** The interim provider cursor was a
*record*, not a sum (plan P1), because a record makes a later cursor an additive field while a sum
makes it a variant restructuring — and a reviewer's probe showed a `ProviderState` widening left the
port module byte-identical. The same argument applies to a decision-plus-successor.

## Grounding, verified at HEAD

| Anchor | Value |
|---|---|
| `ExtPorts` | 4 fields; `ai_step` carries `Trace` as of B2a |
| Hook result sums | `packages/motoko-ext-abi/types.ail:130-142` |
| The pinned membership block | `tools/ext_call_inventory/expected.json`, checked at `derive.py:652` |
| `driver_only`'s omission record | `dst_driver_only.ail:224-226` — cites the criterion verbatim |
| Rowed implementation sites | **206**, not 191 — the plan's grep missed **15 lambda-form** hook assignments (`ToolHandleDecision` 52, `PreStepDecision` 62, `ResponseInterceptDecision` 45, `FinalizeDecision` 47) |
| `ext_ai_step`'s exclusion site | `session.ail` hands `empty_world_state()` by design (D1) — this is what stops |
| Tree at start | 218 pass / 17 fail; `check_core` green |

**The 17 remaining failures are not yours**: 9 pre-existing at v0.26.0, **7 `TC_ARITY_001` stale
smoke-script callers** of `run_v2` (byte-identical at HEAD, revealed not caused, and B2a argued they
are superseded rather than broken — no correct in-tree caller exists to copy), and **1 sealing probe
whose `IMP010` failure IS its pass.** Do not fix the probe.

## Definition of done

**The token threads in and out at all three levels**, with the representation chosen and its reason
recorded.

**`ExtPorts.ai_step`'s exclusion is lifted or explicitly still stands** — and either way, the
classifier-2 set, the pinned membership block, and `driver_only`'s omission record are **all three
brought into agreement**, with a profile version bump if the record changes.

**The two `ScriptedStep` widenings**, kept distinct: the fault half is an error case, the latency half
is `advance_ms` restored on replay from `TimedOutcome.advance_ms` exactly as the tool duration already
is — no codec change.

**Per S9 (rewritten) — clear EVERY live `.ailang/cache`, not the root one.** They are per-directory;
`rm -rf .ailang/cache` clears one. Use the sweep in S9, **with its two exclusions** — an unguarded
version deletes `tools/code-graph`'s tracked test fixtures.

**Per S11 (new) — no `export type X = X` where `X` is a record.** B2a removed two; one was blocking
33 files invisibly.

**Per S10 — drive tooling off the compiler's verdict, never its prose.** B2a hit the backwards `Hint:`
again, on a site S10 did not come from.

**Assert file line counts on every edit**, per B2a's guard — A5's anchors are line numbers and a
widening that collapses a multi-line signature moves every anchor below it. That guard caught a real
`session.ail` rewrite going 2962 → 2961.

**`make check_core` green at the end**, and say what `make dst` does. Expect `attribution_table` to
stay red: **nine of A5's ten anchors were already stale at HEAD before any repin edit**, and
re-deriving them is **B4's**, not yours.

## Out of scope

- **WI-B4**: classifier re-derivation, the manifest re-issue and the 13 stale `ailang 0.26.0` strings,
  **A5's nine stale anchors**, and both unfinished mutation loops — targeted at the **180 function
  rows**, not the 123 closed-row sites, which admit exactly one width.
- **The 7 `TC_ARITY_001` smoke scripts.** A behavioural decision (they make live API calls), not a row
  repair.
- **Removing the two v0.33.0-fixed defect workarounds.**
- **Milestone C** — the recorded-stream adoption (`WI-C1`), its positive probe (`C2`), and the name
  gate.

## Stop and report rather than deciding inline

- **If lifting the exclusion makes `compaction_ai` installable**, that changes what `driver_only`
  covers and is a profile-version and conformance decision — report it before re-issuing.
- **If the hook-result widening forces a change to the three rowless ABI slots**
  (`on_describe_tools`, `on_build_system_prompt`, `on_tool_policy`), **stop.** They are D5's entire
  coverable surface, B1, B2a and B3 all left them byte-identical by diff, and `make profile_coverage`
  passes today so a regression is visible.
- **If the token cannot thread without production code branching on test mode**, that falsifies D1 and
  is an ADR-level finding.

## Report back

Nineteenth calibration run, and the last of Milestone B's content.

- **The git wall-clock window.**
- **The representation chosen** for the token, and why — this is the item's central decided binding.
- **Which fields left the classifier-2 set**, and the state of all three artifacts that encode it.
- **Sites and files**, against the corrected **206**.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **37 across
  eighteen runs; determinism has caught none.** Note B2a's structural argument: closed rows admit
  exactly one width, so lockstep sites have no silent band — but **a row that is itself too wide
  compiles**, and this item changes rows.
