# Note: cluster 1 execution report — WI-A1, P6, WI-A2, with plan corrections

Date: 2026-08-02. Status: closed — all three commits landed green.
Handoff consumed: `HANDOFF-execute-a1-a2-port-widenings.md`.
Commits: `e59acaa` (WI-A1), `4ad2c7a` (P6), `6dd1bbe` (WI-A2).

This is the plan's **calibration run** — the first work item with real cost data. Everything below is
measured, not estimated. Where the plan was wrong, it is recorded here rather than silently
reconciled; that is what building cluster 1 first was for.

## Grounding, as required

`git diff a0d4edb..HEAD -- src packages scripts` was empty at session start, so the handoff's anchor
table was re-verified rather than re-measured. Every anchor in it held: `Ports` at `ports.ail:17-24`
with 6 fields, `ports_shape_probe` at `:36`, the five construction sites, the three result consumers,
`C2LoopState` at `session.ail:338-357` with 18 fields, `ported_provider` at `:695`, and P5's stale
comment at `stub_step.ail:170-173` including the stale `rt` clause at `:173`. The F6 baseline
reproduced byte-identically to the output quoted in the handoff.

## Cost, measured

Agent-driven wall clock, directly comparable to M1's "14 min, agent-driven, including writing the
tooling". Timings are from commit timestamps and baseline-artifact mtimes.

| Phase | Measured | Plan estimate | Files touched |
|---|---|---|---|
| Reading, re-grounding, baselining, writing the fix-loop tooling | ~12 min | not estimated | — |
| **WI-A1** | **~5.5 min** | **half a day** | **6** (plan said 4) |
| **P6** | **~2 min** | not sized | **4** |
| **WI-A2** | **~10 min** | **1–2 days** | **9** (7 source + `Makefile` + ADR) |
| Total session | ~30 min | ~1.5–2.5 days | 11 distinct files |

**The plan's A1 and A2 estimates are wrong by roughly two orders of magnitude, and the error is
systematic rather than a lucky run.** Both were flagged in the plan as *estimates by analogy*, sized
against M1's 28 files at a deliberately slower per-file rate. The analogy failed in one specific way:
M1's cost was dominated by **69 additive sites across 28 files**, and cluster 1 has **48 sites across
11 files**. Scaling M1's 14 minutes by site count predicts ~10 minutes; the actual was ~18 minutes of
editing. That is the right model. The "half a day / 1–2 days" figures came from treating file count
as the driver and then adding a large safety margin on top of an already conservative rate.

**What this does and does not license.** It does *not* mean the rest of Milestone A is minutes.
A13 (discovery and replay) and B2 are new-artifact work, not port widenings, and nothing here
measures those. What it does mean: **any remaining Milestone A item whose work is "widen a type and
converge the construction sites" should be re-sized against sites-touched, not files-touched or
days.** WI-A12's world-state threading is the immediate beneficiary — it revisits the exact
`C2LoopState` successor literals this change just threaded, and it is currently sized by analogy too.

The 14-minute discipline held for the reason M1 said it would: **the tooling was written first.** A
parallel `ailang check` over the 22-module affected import closure runs in 12 s and surfaces one
error per module instead of one error overall. Without it, A2's convergence would have cost one
compiler round-trip per site.

## The judgement-versus-mechanical ratio

M1 measured **7 of 69 (10%)**, and the rest of Milestone A is scheduled against that number.

| | Sites | Judgement | Ratio |
|---|---|---|---|
| WI-A1 | 13 | 3 | 23% |
| WI-A2 | 35 | 6 | 17% |
| **Combined** | **48** | **9** | **19%** |

**The ratio is about 2x M1's, and the plan should carry 19% rather than 10% for contract-changing
work.** WI-A2 was already sized in "M1's judgement band, not its additive band", so this is a
confirmation for A2 and a correction for everything sized on the additive band.

**The ratio is the less important half of this finding.** The more important half is that
**the *kind* of judgement differs, and the difference has teeth**:

- M1's 7 judgement sites were all **compiler-surfaced**: `Msg` versus `Message` type-identity
  breaks, each one a hard error naming its location. The judgement was in writing the conversion,
  not in noticing the site.
- **Two of A2's six are sites where both alternatives type-check and the wrong one is silent.**
  1. **The successor-literal split.** Thirteen `C2LoopState` successor literals gained
     `provider_state`. The compiler forces the field to be present at all thirteen — but accepts
     `st.provider_state` at every one of them. Six of the thirteen are downstream of the
     `dispatch_step` call and must carry `exchange.next_state`. Writing the carry-forward form there
     compiles clean and **freezes the cursor, reproducing F6**. This was verified, not assumed: all
     six were flipped, `ailang check src/core/session.ail` reported `✓ No errors found!`, and the run
     served `[s0,s0,s0,s0,s0,s0,s0,s0,s0,s0,s0,s0]` in **both** the control and folding scenarios —
     a total freeze, worse than the original defect. `scripted_cursor_probe` is the only thing in the
     tree that catches it.
  2. **`run_v2_with_scripted_ports`.** The compiler flagged the site (the old constructor was gone)
     but not the correct resolution: `Ported(scripted_ports())` type-checks and silently strands the
     script, because the script now rides in `ProviderState` rather than in the closure. The fix is
     to hand the entry point `Scripted(script)` and let `ported_provider` build the pair.

**Consequence for WI-A12, and it is not cosmetic.** A12 threads `world_state` through the same
successor literals and will face the identical silent-freeze hazard, at a larger site count, for a
value that has no equivalent of `scripted_cursor_probe` watching it. **A12 must land an executable
advancement assertion for each cursor it threads before it threads it**, or it will reproduce this
defect class with no instrument. This is the single most transferable finding from cluster 1.

## Plan corrections

Filed rather than reconciled, per the handoff.

**C1. WI-A1's edit surface was 6 files, not 4 — the plan missed a construction site it had the means
to find.** The plan enumerated "the `ports.ail` type, `ports_shape_probe`, 2 `stub_step.ail`
adapters, 3 `long_qwen` sites, and the 3 result consumers". It omits `fake_model` /
`fake_ports` in `src/core/test/scripted_ports.ail:69-80`, a sixth construction site reached through
`ports_shape_probe`. The plan's own framing names `ports_shape_probe` as the sole constructor, so
enumerating its callers would have caught this; the survey enumerated `model_step` textually instead.
**A2's stated edit surface was correct.**

**C2. `phase_c2_wiring_scenarios` is 19 scenarios, not 18.** WI-A2's acceptance evidence says
"`phase_c2_wiring_scenarios` 18/18". WI-A1's acceptance requires "a `Scripted`-provider test asserts
the emission log is present and empty", and that harness is where such a test belongs, so satisfying
A1 necessarily moves A2's number. The handoff had already anticipated this by writing "at its full
count" rather than 18; **the plan should say the same.** The new scenario is
`phase_c.c2.scripted_exchange_carries_empty_emission_log`.

**C3. P6 has no owning cluster, and a session following the cluster map alone would have skipped
it.** `NOTE-execution-clustering-and-handoff-generation.md` lists cluster 1 as "A1 + A2". P6 says
`hooks_runtime` "is deleted in the same edit wave as WI-A1 (both touch every construction site;
separate commit)" — but P6 is a plan *decision*, not a work item, so it appears in no cluster row.
It was executed here only because the handoff's reading order named P6 explicitly. **The cluster map
should list cluster 1 as "A1 + P6 + A2".** Had it been missed, a later session would have paid a
third full pass over every construction site — exactly the cost P6's sequencing exists to avoid.

**C4. The `ScriptedStep` relocation cost nothing, and the budgeted "import sites of `ScriptedStep`"
edit surface was zero.** The plan budgeted the relocation as a real source move that "must be
budgeted in the plan, not discovered inside it" — correct that it was required, and the `LDR002`
reasoning holds exactly as stated. But `export type ScriptedStep = ScriptedStep` in `stub_step.ail`
re-exports the relocated type, and **all eleven importers compiled unchanged.** Worth recording as an
available technique: on the pin, a type can be relocated below a module cycle and re-exported from
its old home at zero cost to consumers.

**C5. `ported_provider`'s `history` parameter is now dead.** It survives as `_history` because it is
part of the normaliser's signature at six call sites and D1 keeps the seam stable until `world_state`
replaces it. It existed solely to compute `base_assistant_count` — the derived index that was the
defect. **WI-A12 should delete the parameter when it retires the seam.**

**C6. Eight smoke scripts exercise the driver's full loop and are in no `make` target and no CI job.**
`scripts/smoke_v2_{dp7_gate,pending_full_loop,compaction_full_loop,stream_parity,ext_fixture_parity,
cost_budget_full_loop,compaction_chain}.ail` and `smoke_phase_a_tool_parity.ail`. A2 changed the
contract every one of them depends on, and nothing in the repo would have run them. All eight were
run by hand here and all eight pass. **This is a live coverage gap the plan does not note**, and it
belongs with WI-A14's invariant work or earlier: `smoke_v2_dp7_gate` is the only executable coverage
of `c2_after_dp7`, whose two successor literals A2 had to thread.

**C7. `src/core/test/scripted_ports.ail`'s six unit tests are also run by nothing.** `check_core`
covers `src/core/*.ail` only, and no target names this file. It is the module whose
`scripted_model_next` the ADR cites as the design precedent for the fix.

## Behaviour changes, stated rather than left to be found

**Extension-issued model calls against a `Scripted` provider now serve `terminal_step()` instead of
an `assistant_count`-derived step.** `ext_ai_step` is handed a fresh empty `ProviderState`, per D1's
exclusion of the extension model path. Previously it served whatever the derived index happened to
point at — accidentally, since the derivation was the defect. **No test in the tree changed its
output, which means nothing covers "an extension calls `ai_step` against a `Scripted` provider".**
That is a coverage gap worth an entry in WI-A7's fault-class table, and it is the concrete reason
D1's rule — a conformant interim profile must exclude *every* hook registered by an
`ai_step`-calling extension — has no instrument behind it yet.

## What did not need re-deriving

The handoff's "settled" list held without exception. P1's record-not-sum shape was right; P2 never
triggered (no interim consumer wanted a non-constant approval, so its reopening condition did not
fire); the `ScriptedStep` relocation was required for exactly the stated `LDR002` reason;
`ScriptedPortsState` was indeed precedent and not reusable code; and the interim cursor went into one
explicit `C2LoopState` field. **The trap the handoff named was real**: A1 and A2 do touch one field
and it is tempting to merge them, and A1's diff was checked for a state parameter before committing.
A1 also demonstrably did not enable A2 — after A1 landed, `scripted_cursor_probe` still failed
byte-identically to its baseline.

None of the standing traps fired: no stale-cache type error, no `/tmp` probing, and the pin held at
v0.26.0 throughout.

## What invalidates this note

WI-A12 landing, which deletes the `C2LoopState.provider_state` field this run introduced and should
report its own ratio against the 19% recorded here.
