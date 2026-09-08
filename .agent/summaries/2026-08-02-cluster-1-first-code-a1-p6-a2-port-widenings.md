# 2026-08-02 Cluster 1: the project's first code — both `Ports.model_step` widenings, and F6 fixed

## Context

Branch: `arniwesth/mot-44-motoko_dst_execution_primer`

Session span: `d0b1176` → `f1685a6`, **4 commits**, three of them production source. This is the
first code project 009 has written. Everything before it was documentation: the previous session
(`2026-08-02-adr-001-acceptance-and-review-loop-retrospective.md`) closed a nine-round review loop
having changed no production source at all.

Input was `HANDOFF-execute-a1-a2-port-widenings.md`, executed cold against HEAD per
`author-each-artifact-in-the-session-whose-assets-it-consumes.md`. The mission was two commits;
it landed three, plus a calibration report.

## What landed

| Commit | Item | Effect |
|---|---|---|
| `e59acaa` | **WI-A1** | `ProviderExchange = { emissions, result }`; behaviour-preserving |
| `4ad2c7a` | **P6** | `Ports.hooks_runtime` removed — zero calls repo-wide |
| `6dd1bbe` | **WI-A2** | `model_step` takes `ProviderState`, returns its successor. **Fixes F6** |
| `f1685a6` | report | measured costs, seven plan corrections, two applied in-commit |

**A1** widened the port's result with an emission log, on D1's loss-channel rule. One judgement call
shaped the diff: `dispatch_step` **propagates** the whole exchange rather than unwrapping `.result`.
The plan listed it as a "result consumer", which reads as unwrap — but it is a pass-through of the
port, so unwrapping would have recreated the loss channel one line above the port it had just closed.
The two ABI-constrained consumers (`ext_ai_step`, long_qwen's `ExtPorts.ai_step` closure) do drop the
log, which is a `Result[string, string]` limit rather than an oversight.

**A2** widened the same field bidirectionally. `ProviderState` (a record, per P1) is declared in
`ports.ail`; `ScriptedStep` relocated there too, because `ProviderState` carries it and
`scripted_ports.ail` imports `ports`, `stub_step` *and* `session`, so both required consumers would
close an `LDR002` cycle where it sat. The cursor's sole persistent copy is one explicit
`C2LoopState.provider_state` field, threaded by the driver. `ext_ai_step` is handed a fresh empty
state — D1's exclusion of the extension model path, made explicit rather than hand-waved.

**Green:** `check_core` 34/34; `make dst` exit 0 with every pre-existing scenario byte-identical;
`phase_c2_wiring_scenarios` 19/19; `test_core`, `test_integration`, and all eight smoke scripts;
no `assistant_count`-derived index anywhere. `scripted_cursor_probe` — promoted out of spike naming
into the `make dst` aggregate — prints PASS and exits 0, where it exited 1 by design before.

## The finding that matters most

**Six of A2's thirteen successor literals must carry `exchange.next_state`; the compiler accepts
`st.provider_state` at all thirteen.**

The compiler forces the field to be *present* everywhere (record-field mismatch), which reads as
type-system coverage. It is not. Verified rather than asserted: flipping all six downstream literals
to the carry-forward form gave `✓ No errors found!` and a run that served
`[s0,s0,s0,s0,s0,s0,s0,s0,s0,s0,s0,s0]` in **both** the control and folding scenarios — a total
cursor freeze, worse than the original F6. `scripted_cursor_probe` is the only thing in the tree that
catches it.

**WI-A12 threads `world_state` through those same literals**, at a larger site count, with no
equivalent instrument watching. A12 must land an executable advancement assertion per cursor
*before* it threads it, or it reproduces this defect class blind. This is the single most
transferable result of the session.

## Calibration — the plan's first real cost data

| | Measured | Plan estimate |
|---|---|---|
| Reading, re-grounding, baselining, tooling | ~12 min | not estimated |
| **WI-A1** | **~5.5 min, 6 files** | half a day, 4 files |
| **P6** | ~2 min, 4 files | not sized |
| **WI-A2** | **~10 min, 9 files** | 1–2 days |
| Session total | ~30 min | ~1.5–2.5 days |

**Both estimates were wrong by roughly two orders of magnitude, and systematically so**: they scaled
M1 by *file* count where *site* count is the driver. 48 sites against M1's 69 predicts ~10 min of
editing; actual was ~18. This does **not** license "the rest of Milestone A is minutes" — A13 and B2
are new-artifact work and nothing here measures those — but every remaining item shaped as *widen a
type and converge the construction sites* should be re-sized against sites touched.

M1's discipline held for the stated reason: **the tooling was written first.** A parallel
`ailang check` across the 22-module affected import closure runs in 12 s and yields one error per
module instead of one error overall. A2 converged in three rounds.

**Judgement ratio: 9 of 48 sites (19%)**, against M1's 7 of 69 (10%). The ratio is the less important
half — M1's judgement sites were all compiler-surfaced type-identity breaks, whereas two of A2's six
are sites where both alternatives type-check and the wrong one is silent (the successor-literal split
above, and `run_v2_with_scripted_ports`, where `Ported(scripted_ports())` compiles and strands the
script).

## Plan corrections filed

Recorded in `NOTE-cluster-1-execution-report-and-plan-corrections.md`; C2 and C3 applied to the plan
and cluster map in `f1685a6`.

- **C1** A1's edit surface was 6 files, not 4 — the plan missed `fake_model`/`fake_ports` in
  `scripted_ports.ail`, a construction site its own "sole constructor" framing would have caught.
- **C2** `phase_c2_wiring_scenarios` is 19, not 18: A1's acceptance test necessarily moves A2's count.
- **C3** **P6 had no owning cluster.** The map said "A1 + A2"; P6 is a plan *decision*, so it appeared
  in no row, and a session working from the map alone would have skipped it — costing a later session
  a third full pass over every construction site. The map now says "A1 + P6 + A2", with a standing
  instruction to sweep plan decisions, not just work items, when generating a handoff.
- **C4** The `ScriptedStep` relocation cost zero consumer edits: `export type ScriptedStep =
  ScriptedStep` re-exports it from its old home and all eleven importers compiled unchanged. Worth
  keeping as an available technique on the pin.
- **C5** `ported_provider`'s `history` parameter is now dead (kept as `_history` for signature
  stability); A12 should delete it.
- **C6** **Eight full-loop smoke scripts run in no `make` target and no CI job**, including
  `smoke_v2_dp7_gate`, the only executable coverage of `c2_after_dp7` — whose two successor literals
  A2 had to thread. All eight run by hand here; all pass.
- **C7** `scripted_ports.ail`'s six unit tests are also run by nothing — the module whose
  `scripted_model_next` the ADR cites as the design precedent for this very fix.

## Behaviour change, stated

Extension-issued model calls against a `Scripted` provider now serve `terminal_step()` instead of an
`assistant_count`-derived step, per D1's exclusion. **No test in the tree changed its output**, which
means nothing covers "an extension calls `ai_step` against a `Scripted` provider" — a gap belonging
in WI-A7's fault-class table, and the concrete reason D1's every-hook exclusion rule still has no
instrument behind it.

## What the handoff got right

Its "settled — do not re-derive" list held without exception, and the trap it named was real: A1 and
A2 do touch one field and merging them is tempting. A1's diff was checked for a state parameter
before committing. The ADR's prediction also held empirically — after A1 landed,
`scripted_cursor_probe` still failed byte-identically to baseline, confirming that **A1 did not
enable A2**. No standing trap fired: no stale-cache type error, no `/tmp` probing, pin held at
v0.26.0.

The handoff's own hedge on A2's acceptance ("at its full count" rather than the plan's "18/18") was
the correct call and is why C2 was a plan correction rather than a conflict.

## Next

Cluster 1 landing unblocks **clusters 4 (A9) and 6 (A12)** and makes their handoffs writable. Both
must re-ground first: this session moved `ScriptedStep`, widened `Ports.model_step` twice, removed
`Ports.hooks_runtime`, and added `C2LoopState.provider_state`, so every anchor into `ports.ail`,
`stub_step.ail` and `session.ail` has shifted. Clusters 2 and 3 remain independent and can run in
parallel.
