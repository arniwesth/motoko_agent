# Note: cluster 4 execution report — WI-A16, WI-A9, with plan corrections

Date: 2026-08-02. Status: closed — both commits landed green.
Handoff consumed: `HANDOFF-execute-a16-a9-terminal-trace.md` (commit `9e8b2e1`).
Commits: `61f38db` (WI-A16), `ff8d8e5` (WI-A9).

Second calibration run after cluster 1. Same three measurements, same rule: where the plan was
wrong it is recorded here rather than silently reconciled.

## Grounding, as required

`git diff 6dd1bbe..HEAD -- src packages scripts Makefile` was empty at session start, so the
handoff's re-measured anchor table was re-verified rather than re-measured. **Every anchor held**:
`emit_run_summary` at `session.ail:858`, call sites at `1350, 1584, 1737, 1744, 1801`,
`finish_reason_str` at `:845`, `ledger_append` at `phase_vocab.ail:557`, `RunSummary` at `:600`,
wire projection at `:682`, goldens at `:1105-1106`, and the 37/15 `ledger_emit`/`ledger_append`
imbalance. D6.1's zero-`RunSummary` claim was confirmed directly: **count=0 on every driven
terminal path**, measured by reverting the new append and re-running the gate.

All eight smoke scripts and `scripted_ports.ail`'s six unit tests passed at HEAD before any edit,
so there was no cluster-1 regression to report.

## Cost, measured

| Phase | Measured | Plan estimate | Files touched | Sites |
|---|---|---|---|---|
| Reading, re-grounding, baselining, rebuilding the closure-check tool | ~9 min | not estimated | — | — |
| **WI-A16** | **~9 min** | **under a day** | **6** | **11** |
| **WI-A9** | **~14 min** | **unsized** | **6** (2 new) | **26** |
| Total session | ~32 min | — | 10 distinct | 37 |

**A16's "under a day" is wrong in the same direction and by the same order as cluster 1's
estimates, and for the same reason** — it was sized as wiring work by file count. Cluster 1's
sites-not-files model predicts A16 well once the *real* site count is used (11, not the 2 the plan
implies), and predicts A9 well too: 26 sites at cluster 1's observed rate is ~13 min against ~14
actual. **The sites-not-files model now has two independent confirmations and should be treated as
the plan's sizing rule, not a cluster-1 observation.**

**A9's terminal-path count is the number that mattered, and it is not five.** The handoff asked for
both. There are **five `emit_run_summary` call sites** but **seven terminal returns** and **eight
reachable termination reasons**. Sizing against the five call sites would have missed two terminal
paths entirely — see C2 below. For items that rewrite a *class* of returns, the count to size
against is the class, not the helper's callers.

The 12 s parallel `ailang check` closure tool was rebuilt before editing, per cluster 1. It runs in
**2.6 s** over 19 modules here and surfaced one error per module. `probe_phase_vocab_sealed.ail`
fails at baseline (`IMP010: symbol 'MkHistory' not exported`) — **pre-existing, unrelated, and
unchanged by this work**; it is in no target, which is how it stayed broken.

## The judgement-versus-mechanical ratio

M1 measured 10%, cluster 1 measured 19% and recommended the plan carry 19% for contract-changing
work.

| | Sites | Judgement | Ratio |
|---|---|---|---|
| WI-A16 | 11 | 3 | 27% |
| WI-A9 | 26 | 7 | 27% |
| **Combined** | **37** | **10** | **27%** |

**27%, against cluster 1's 19% and M1's 10%.** Three runs now, monotonically increasing with how
much contract the item touches. The plan should carry **~27% for items that rewrite a class of
returns or a result contract**, and keep 19% for port widenings.

### The part that matters: four sites admitted two type-checking answers with a silent wrong one

Cluster 1 found two such sites and that finding changed WI-A12's acceptance evidence. **A9 has
four, and three of them are silent in a way no existing test catches.**

1. **Ordering at the success path.** `c2_finalize` emits the `run_summary` projection. Calling it
   *before* or *after* `ledger_emit(DoneEvent(...))` both type-check and both satisfy the new
   trace-level assertion, because the `DoneEvent` is projected only and never appended. The wrong
   order silently swaps `run_summary` and `done` on the wire. **`smoke_parity` cannot catch this**:
   it diffs run A against run B of the same build, so a consistent reordering is consistent.
   Verified by reading the emitted JSONL, not by a test.
2. **Which trace value to hand the finalizer, at both seal sites.** `trace_after_stages` and
   `ledger_append(trace_after_stages, WireRecord(event))` both type-check. The wrong one silently
   drops the `ErrorEvent` / `CompactionExhausted` record from the returned trace while the
   `RunSummary` assertion still passes — the invariant is satisfied by a trace missing the evidence
   the failure is about.
3. **The same hazard at the `Fail` site**: `st.trace` versus `trace_with_decision`. Both compile;
   the wrong one silently drops the decision record.
4. **`decision_fail_reason`'s max-steps discrimination** (compiler-surfaced only in the sense that
   the site was forced; the resolution was not). See C4.

**Consequence for WI-A12, and it is the same shape as cluster 1's but worse.** Cluster 1's silent
sites were *successor literals* where the wrong value froze a cursor. A9's are *trace arguments*
where the wrong value produces a trace that still passes its own invariant. A12 threads
`world_state` through the same literals **and** now through a finalizer that takes a trace argument.
**A12's executable advancement assertion must cover trace completeness, not only cursor
advancement**, or a dropped record will satisfy every check A9 leaves behind.

## Plan corrections

Filed rather than reconciled.

**C1. A16 as specified would have gated nothing for half the scripts it wired.** Four of the eight —
`smoke_v2_{dp7_gate,pending_full_loop,compaction_full_loop,cost_budget_full_loop}` — had **no
failing exit path**. They printed `✗` on a failed assertion and exited 0. Wiring them into a target
makes a target that is green regardless of whether their assertions hold. Measured, not inferred:
with one assertion deliberately inverted, the script exited **0** before the fix and **1** after.
The plan's acceptance ("verified by breaking one deliberately") is what surfaced this — it could
not be satisfied without fixing it, which is a good argument for keeping demonstration clauses in
acceptance evidence rather than assertions.

**C1b. Correcting cluster 1's C6, and this note's own first draft: the eight were NOT unrun.**
C6 says the eight scripts "are in no `make` target and no CI job", and WI-A16's justification in the
plan repeats it. All eight are in fact invoked by `scripts/dst/phase_a_event_parity.sh:174-183`,
which `make smoke_parity` runs and which is a CI step. The true state was narrower and worse than
"unrun": they were **run but ungated**. The harness consumes only their JSONL projection for an
A-versus-B parity diff, `awk '/^\{/'` strips the prose `✗` lines before the artifacts are written
(confirmed: zero `✗` in the captured `smoke_v2_dp7_gate.jsonl`), and the four with no exit path gave
`set -euo pipefail` nothing to catch. Measured end-to-end through the real harness with one broken
assertion: `phase_a_event_parity.sh` exits **0** with the pre-A16 scripts and **1** with the post-A16
scripts. The four that already had `exit(1)` were genuinely gated, via pipefail — which is why this
stayed invisible: half the set worked. **A green check implying absent coverage is a worse failure
mode than a missing check**, and it survived one execution report and one plan revision. C7's other
half stands: `scripted_ports.ail`'s six unit tests were run by nothing. Filed as
`.agent/issues/smoke-scripts-report-failure-but-exit-zero.md`, which also lists **11 more scripts**
with the same defect, two of them (`smoke_v2_handle`, `smoke_v2_hybrid`) in that same CI-reachable
path today.

**C2. ADR-001 D6.1's enumeration of terminal paths is incomplete, and the plan inherits it.** D6.1
says "every terminal summary routes through `emit_run_summary` … five call sites". There are
**seven terminal returns**. Two of them — invalid history (`c2_step_state` Err) and the internal
approval failure (`AwaitApproval` with no pending approval) — **emitted no `run_summary` at all**,
not even a projection. D6.1's "the returned trace contains no `RunSummary` on any path" was right;
its account of *why* was incomplete, and an implementer working from the five call sites alone would
have left two paths unfinalized. Both now finalize.

**C3. D6.2's list of termination reasons is wrong in both directions.** Derived from reachable
terminal returns, as D6.2 itself requires:

- **`dp7_rejected` is unreachable.** The old helper mapped `2 -> "dp7_rejected"` but **no call site
  ever passed 2**. A DP7 rejection re-injects a user message and the run terminates later via
  max-steps or budget. It is precisely the "stale label" D6.2 says not to preserve, and it is
  dropped.
- **Unrecovered tool failure is not a terminal path.** D6.2 and the handoff's definition of done
  both list it. Tool results feed back into the loop as messages; no terminal return corresponds to
  it. No variant was invented for it.
- **System-prompt-empty is reachable and missing from the list.** The seal failure
  `SealSystemPromptEmpty` is a real terminal return. It is now `TermSystemPromptEmpty`.

Net: **eight reachable reasons, not the eight enumerated** — same count, different membership. All
eight map exhaustively onto the existing wire strings, so **no wire change was required and the
stop condition in the handoff did not fire.**

**C4. The max-steps discrimination is a string match on an error message, and nothing records it.**
`decision_fail_reason` distinguishes max-steps from internal failure by
`message == "v2 loop: step budget exhausted"`, because `step_machine.ail:93` and `:57` emit **the
same `Internal` code** for the step-budget failure and the approval-without-pending-call failure.
Behaviour is preserved exactly, but an edit to that string in `step_machine.ail` would silently
reclassify every max-steps run as an internal failure. Giving the step-budget `Fail` its own code
fixes it and changes the `AIError` code callers see — **a compatibility decision A9 does not own.**
Worth an explicit owner in the plan.

**C5. `session.ail` and `phase_vocab.ail` carry inline unit tests that no target ran** — 21 and 27
respectively, including the `RunSummary` goldens the handoff names as what holds the wire strings.
This is the same class as cluster 1's C6/C7 and was not caught by them, because C7 looked at
`src/core/test/` rather than at `src/core/`. `check_core` type-checks `src/core/*.ail` but never
runs `ailang test` on it. Both are now in `make terminal_trace`. **The general defect is that
`ailang check` coverage and `ailang test` coverage are separate axes and only the first has a
target**; a plan item should sweep the second.

## What A16 bought, measured

A16 landed first specifically so A9's blast radius was instrumented. **It caught nothing** — all
eight scripts stayed green through A9. That is the honest result and it is still the right
sequencing: the cost was 9 minutes, and per C1b the alternative was rewriting every terminal return
in the driver with four of the eight full-loop scripts **unable to report a failure at all** — not
merely unrun, which would have been the milder problem. The value is bounded by what it would have
caught, which is unknowable, but the D6.6 capability probe and the finalizer-bypass guard added in
A9 both live in a target *because* A16 established the pattern of putting them there.

## Behaviour changes, stated rather than left to be found

1. **Two terminal paths now emit a `run_summary` that previously emitted nothing** — invalid history
   and the internal approval failure. Downstream consumers that treated a missing `run_summary` as a
   signal for these paths will see one now, with `finish_reason: "error"`. This is D6.1 being
   satisfied, not a regression, but it is a wire-visible change.
2. **Every returned `LedgerTrace` now ends with a `RunSummary` record.** Anything consuming the
   returned trace and assuming the last record is a wire event of some other kind will see the
   summary instead. Nothing in the tree did.
3. `finish_reason_str(r: int)` is deleted; no integer termination code survives at any call site.

## D6.6, held rather than collapsed

The handoff predicted a builder would try to unify in-runner typed failures with raw capability
bypasses. **The pressure was real and it is worth recording where it came from**: `dst_result.ail`
has a `HarnessFailureKind` ADT, and a `CapabilityDenied` variant looks natural sitting next to
`RoutingViolation`. It is deliberately absent, with the reason written into the module header, and
`make terminal_trace` **fails if a run with capabilities withheld ever exits 0**. Measured: a run
with `Env` withheld terminates evaluation mid-run with exit 1, no typed result, no partial trace —
exactly as D6.6 describes, on this pin.

## Out of scope, honoured

No event vocabulary (A8) — A9's three checks were decidable over the `RunSummary` variant as it
exists, and the author's judgement that A9 does not depend on A8 is **confirmed by construction**.
No `world_state` threading (A12). No mismatch-detection path (A13) — `dst_result.ail` defines the
types and the setup-failure path only, and `ReplayMetadata` carries the interpretation fields A9 can
fill honestly, with the generator-side D8 fields left to A13. No runtime exclusion enforcement
(A10); `RoutingViolation` exists as a kind for A10 to use and is unreferenced by the driver.

## What invalidates this note

WI-A12 landing, which threads `world_state` through the terminal literals this run rewrote and
should report its own ratio against the 27% recorded here — and, per the judgement section above,
should report whether its advancement assertion covers trace completeness.
