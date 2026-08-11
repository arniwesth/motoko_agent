# 2026-08-02 Cluster 4: the driver's terminal trace — A16's net, A9's finalizer, and a green check that was lying

## Context

Branch: `arniwesth/mot-46-execute-wi-a16-and-wi-a9`

Session span: `9e8b2e1` → `bf44b18`, **4 commits**, two of them production source. Input was
`HANDOFF-execute-a16-a9-terminal-trace.md`, executed cold against HEAD per
`author-each-artifact-in-the-session-whose-assets-it-consumes.md`. Second code session of project
009, following cluster 1 (`2026-08-02-cluster-1-first-code-a1-p6-a2-port-widenings.md`).

The mission was two commits in a fixed order — A16 before A9, because A16 is the net A9 falls into.
It landed both, plus a calibration report and three issues. The last of those changed a claim the
plan had been carrying since cluster 1.

## What landed

| Commit | Item | Effect |
|---|---|---|
| `61f38db` | **WI-A16** | `smoke_driver` target, called from CI; four scripts given failing exit paths |
| `ff8d8e5` | **WI-A9** | one `c2_finalize`, typed `TerminationReason`, D6's `SystemRun`/`HarnessFailure` |
| `ff75528` | report | measured costs, 27% ratio, five plan corrections |
| `bf44b18` | issues | three filed; C6's "unrun" claim corrected |

**A16** wired eight driver smoke scripts and `scripted_ports.ail`'s six unit tests into a target the
workflow actually names. The plan framed this as wiring. It was not — see the finding below.

**A9** routed all seven terminal returns through one finalizer that emits the `run_summary`
projection **and** appends the same record to the returned trace. D6.1's starting count was zero on
every path: `emit_run_summary`'s only ledger operation was the projection, so the returned
`LedgerTrace` — the trace D6 makes authoritative — contained no `RunSummary` anywhere.
`finish_reason_str(r: int)` is deleted; the typed reason lives beside `RunSummaryInfo` with an
exhaustive map onto unchanged wire strings. `session.ail` now holds exactly **one** `{ result:`
literal, inside the finalizer, and a make check fails if a second appears.

**Green:** `make dst` exit 0 (read from exit status, per the `--keep-going` trap) with all eight
sub-targets run; `check_core` 35/35; all eight smoke scripts; `session.ail` 21 inline tests,
`phase_vocab.ail` 27, `dst_result.ail` 3.

## The finding that matters most

**The eight smoke scripts were not unrun. They were run on every CI build and could not fail it.**

Cluster 1's C6 says they are "in no `make` target and no CI job", and WI-A16's entire justification
in the plan rests on that. `scripts/dst/phase_a_event_parity.sh:174-183` invokes all eight, and
`make smoke_parity` is a CI step. What was actually true:

- only the **JSONL projection** is consumed — the harness diffs run A against run B for event parity;
- `awk '/^\{/'` strips the prose `✗` lines before the artifacts are written. Confirmed: zero `✗` in
  the captured `smoke_v2_dp7_gate.jsonl`;
- and **four of the eight exited 0 on a failed assertion**, so `set -euo pipefail` had nothing to
  catch.

Measured end-to-end through the real harness, one assertion deliberately inverted:

| | `phase_a_event_parity.sh` exit |
|---|---|
| pre-A16 scripts | **0** — CI green with a broken assertion |
| post-A16 scripts | **1** |

The four that already had `exit(1)` *were* genuinely gated via pipefail. That is why this survived an
execution report and a plan revision without being noticed: **half the set worked.** A green check
implying coverage that is absent is a worse failure mode than a missing check, and the defect is
wider than the eight — 11 more scripts share it, two of them (`smoke_v2_handle`, `smoke_v2_hybrid`)
in that same CI-reachable path today.

What surfaced it was A16's acceptance clause: *"verified by breaking one deliberately."* It could not
be satisfied without discovering the scripts could not fail. **Acceptance evidence demanding a
demonstration rather than an assertion cost about two minutes here and invalidated a claim two prior
artifacts had asserted.**

## Second finding: four silent-wrong sites, and they are trace arguments

Cluster 1 found two sites where both alternatives type-check and the wrong one is silent, and that
finding changed WI-A12's acceptance evidence. A9 has **four**, and three are worse in kind:

1. **Ordering at the success path.** Calling `c2_finalize` before or after `ledger_emit(DoneEvent)`
   both type-check and both satisfy the new trace assertion, because the `DoneEvent` is projected
   and never appended. The wrong order silently swaps `run_summary` and `done` on the wire, and
   `smoke_parity` cannot catch it — it diffs A against B of the same build, so a consistent
   reordering is consistent.
2. **Which trace to hand the finalizer, at both seal sites.** `trace_after_stages` versus
   `ledger_append(trace_after_stages, WireRecord(event))` both compile; the wrong one silently drops
   the `ErrorEvent`/`CompactionExhausted` record **while the `RunSummary` invariant still passes** —
   a trace that satisfies its own contract while missing the evidence the failure is about.
3. The same hazard at the `Fail` site: `st.trace` versus `trace_with_decision`.
4. `decision_fail_reason`'s max-steps discrimination (see issues below).

**Consequence for WI-A12**, which is the critical path: cluster 1's silent sites froze a *cursor*;
these produce a *trace that passes its own invariant*. A12 threads `world_state` through the same
literals **and** through a finalizer taking a trace argument. Its executable advancement assertion
must cover trace completeness, not only cursor advancement.

## Cost and ratio

| | Measured | Plan estimate | Files | Sites |
|---|---|---|---|---|
| WI-A16 | ~9 min | under a day | 6 | 11 |
| WI-A9 | ~14 min | unsized | 6 (2 new) | 26 |
| Session | ~32 min | — | 10 | 37 |

Cluster 1's **sites-not-files** sizing model now has two independent confirmations and should be the
plan's rule. **A9's terminal-path count is the number that mattered and it is not five**: five
`emit_run_summary` call sites, but **seven terminal returns** and **eight reachable reasons**. Sizing
against the helper's callers would have missed two terminal paths outright.

Judgement ratio **27%** (10 of 37), against cluster 1's 19% and M1's 10% — three runs, rising with
how much contract the item touches. The plan should carry ~27% for items rewriting a class of
returns or a result contract.

## Plan corrections filed

Five, in `NOTE-cluster-4-execution-report-and-plan-corrections.md`:

- **C1/C1b** — the exit-code defect and the C6 correction above.
- **C2** — ADR-001 D6.1's five-call-site enumeration is incomplete. There are seven terminal
  returns; two (invalid history, the internal approval failure) emitted **no `run_summary` at all**.
  Both now finalize — a wire-visible behaviour change.
- **C3** — D6.2's reason list is wrong in both directions. `dp7_rejected` is unreachable (no call
  site ever passed `2`); unrecovered tool failure is **not** a terminal path; system-prompt-empty is
  reachable and absent. Same count, different membership. All eight map onto existing wire strings,
  so the handoff's wire-change stop condition did not fire.
- **C4** — the max-steps discrimination is a string match on an error message.
- **C5** — `ailang check` and `ailang test` are separate coverage axes and only the first globs.

## Issues filed

- `smoke-scripts-report-failure-but-exit-zero.md` — the finding above, plus the 11 remaining scripts.
  `smoke_v2_handle` and `smoke_v2_hybrid` are the urgent two.
- `max-steps-termination-discriminated-by-error-message-string.md` — `step_machine` emits one
  `Internal` code for two failures, so max-steps is matched by message text. A reword silently flips
  the wire `finish_reason` from `max_steps` to `error`. A9 preserved behaviour and added a tripwire
  test; the fix changes the `AIError` code callers see and needs an owner.
- `ailang-test-coverage-has-no-target-and-a-probe-is-broken.md` — `phase_vocab.ail`'s 27 inline
  tests, **including the `RunSummary` wire goldens ADR-001 relies on**, were never executed. Also
  records `probe_phase_vocab_sealed.ail` as broken at HEAD and unwired (pre-existing, untouched).

## D6.6, held rather than collapsed

The handoff predicted a builder would try to unify in-runner typed failures with raw capability
bypasses, and the pressure was real: `dst_result.ail` has a `HarnessFailureKind` ADT where a
`CapabilityDenied` variant would sit naturally beside `RoutingViolation`. It is deliberately absent,
with the reason in the module header, and `make terminal_trace` **fails if a run with capabilities
withheld ever exits 0**. Measured: withholding `Env` terminates evaluation mid-run, exit 1, no typed
result, no partial trace — exactly as D6.6 describes on this pin.

## What A16 bought, measured

**Nothing caught.** All eight scripts stayed green through A9. That is the honest result and the
sequencing was still right: 9 minutes, and the alternative was rewriting every terminal return in the
driver with four of the eight unable to report a failure at all. The D6.6 probe and the
finalizer-bypass guard both live in a target because A16 established the pattern.

## Out of scope, honoured

No event vocabulary (A8) — A9's checks were decidable over the `RunSummary` variant as it exists, so
the author's judgement that A9 does not depend on A8 is **confirmed by construction**. No
`world_state` threading (A12). No mismatch-detection path (A13); `dst_result.ail` defines the types
and the setup-failure path only. No runtime exclusion enforcement (A10) — `RoutingViolation` exists
as a kind for A10 and is unreferenced by the driver.

None of the standing traps fired: no stale-cache type error, no `/tmp` probing, pin held at v0.26.0,
PR #103 untouched.

## Next

**WI-A12 is the critical path and the item most exposed to this session's findings.** It should read
the judgement section of the cluster 4 report before threading anything, and land trace-completeness
assertions alongside its advancement assertions. Independently, `smoke_v2_handle` and
`smoke_v2_hybrid` should get exit paths — they are ungated in CI right now.

## Downstream — what happened to these findings

Recorded after the fact; both commits landed from another session while this summary was being
written, so this section is provenance rather than this session's work.

- `a10c353` **applied all five corrections and amended ADR-001 D6.1 and D6.2 directly** rather than
  routing them through review, per the plan's own clause. D6.1's five-call-site account and D6.2's
  reason list are now correct in the ADR. The sizing rule is stated as the plan's rule with three
  bands — 10% additive, 19% port widenings, **27% for rewriting a class of returns** — plus the
  corollary this session taught: *count the class, not the helper's callers.* C4's max-steps string
  match went to A7. **A new WI-A17 sweeps the `ailang test` coverage axis**, which is the third
  issue filed here.
- `094cd11` handed off **cluster 6, WI-A12**, with its assertion requirement strengthened to cover
  trace completeness — the consequence this session flagged as the most transferable.

The exit-code issue (`smoke_v2_handle`, `smoke_v2_hybrid`) remains open at the time of writing.
