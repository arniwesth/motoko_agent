# Handoff: execute WI-A16 and WI-A9 — wire the unrun coverage, then own the terminal trace

Audience: a fresh session grounded against HEAD. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`,
implementation is source-heavy work and belongs in a session that just read HEAD. You are that
session.

This is **cluster 4 of Milestone A**. Cluster 1 (A1, P6, A2) landed 2026-08-02 — read its report,
`NOTE-cluster-1-execution-report-and-plan-corrections.md`, before starting: it corrected the plan's
sizing model and found the defect class A9 sits next to. The session cut is
`NOTE-execution-clustering-and-handoff-generation.md`.

## Mission

Land **WI-A16 first, then WI-A9**, as separate commits, ending green.

A16 before A9 is not arbitrary. A16 wires eight driver smoke scripts that currently run in no target
and no CI; A9 then rewrites every terminal return in the driver. **A16 is the net A9 falls into.**
Doing them in the other order means A9's blast radius is unmeasured for the length of the change.

The plan is your specification — read WI-A16 and WI-A9 there. This handoff carries only what the
plan cannot: current grounding, the rule each item will break by accident, and the definition of
done.

## Reading order

1. `NOTE-cluster-1-execution-report-and-plan-corrections.md` — the whole thing; it is short and it
   is the closest prior art. C6 and C7 are A16's entire justification.
2. `PLAN-implementation-deterministic-test-world.md` — WI-A16, WI-A9.
3. ADR-001 **D6** — the result contract. Items 1, 2, 6 and 7 are what A9 builds. Read item 6
   twice; see *the rule you will break* below.
4. `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md`.

## Re-ground before you rely on anything

**Every A9 anchor in the plan's survey is stale.** Cluster 1 rewrote `session.ail`, and the survey's
figures were measured before it. This table was re-measured at HEAD on 2026-08-02, *after* cluster 1
landed — but re-run it anyway; that is the discipline, and this handoff is itself evidence for why.

| Anchor | Was (plan survey) | **Now** |
|---|---|---|
| `emit_run_summary` | `session.ail:833` | **`:858`** |
| its call sites | `1325, 1554, 1704, 1711, 1762` | **`1350, 1584, 1737, 1744, 1801`** |
| `finish_reason_str(r: int)` | `session.ail:820` | **`:845`** |
| `ledger_append` | `phase_vocab.ail:557` | `:557` (unchanged) |
| `RunSummary` variant | `phase_vocab.ail:597`ff | **`:600`**, wire projection at `:682`, goldens at `:1105-1106` |
| `ledger_emit` vs `ledger_append` in `session.ail` | 37 / 15 | **37 / 15** (unchanged — the imbalance A9 exists to fix) |

Start with `git diff --stat 6dd1bbe..HEAD -- src packages scripts Makefile` — if non-empty,
re-measure the whole table before trusting a line of it.

**D6.1's starting count is still zero on every path, not one on some.** `emit_run_summary`'s only
ledger operation is the `ledger_emit` *projection*; no terminal path calls `ledger_append` with a
`RunSummary`. Do not assume any path is partially done.

## The rule each item will break by accident

**A16: adding a `make` target is not adding CI coverage.** `.github/workflows/verify-extensions.yml`
names its targets explicitly — `check_core`, `smoke_no_delegated_storm`,
`make --keep-going compaction_dst conformance phase_c_l1`, `dst_seeded`, `smoke_parity`,
`verify_core`, `dst_l2`. A new target that nothing in that file calls is invisible to CI and will
sit unrun exactly like the eight scripts you are fixing. **Edit the workflow, or extend a target the
workflow already calls.** Then prove it: break one script deliberately and confirm the job goes red.

**A9: an in-runner typed failure and a raw capability bypass are different outcomes and must not be
unified.** D6.6 is emphatic and a builder will naturally try to make everything return a typed
value. A profile-routing or exclusion violation the runner observes *can* return a typed
`HarnessFailure` with a partial trace, because the driver is still running. A denied ambient effect
**terminates evaluation** — no typed result and no partial trace can exist. That case is an expected
non-zero run. The ADR's clause: if both are ever required to return the same typed value, an
effect-interposition mechanism preserving the driver-owned partial trace must be named and proven on
the pin *first*, and none exists. If you find yourself writing a catch-all that returns
`HarnessFailure` for a capability denial, stop — that is the collapse this paragraph exists to
prevent.

Secondary, and confirmed by both plan reviewers: **A9 does not depend on WI-A8.** Its three checks
are structural over the returned trace's ADT and decidable against the `RunSummary` variant as it
exists today. Do not block on the event vocabulary; do not build any part of it here.

## Definition of done

**A16 green:** all eight scripts plus `src/core/test/scripted_ports.ail`'s six unit tests run from a
target CI actually invokes; the job fails when any one of them fails, **demonstrated by breaking one
and watching it go red**, not asserted. The eight are
`scripts/smoke_v2_{dp7_gate,pending_full_loop,compaction_full_loop,stream_parity,ext_fixture_parity,cost_budget_full_loop,compaction_chain}.ail`
and `scripts/smoke_phase_a_tool_parity.ail`. They pass at HEAD today (cluster 1 ran all eight by
hand), so a red result on first wiring means your invocation is wrong, not the script. They need the
full capability set and `--ai-stub`; `smoke_v2_dp7_gate`'s `main` is
`! {AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream, Trace}` and the others are the same
shape. Mirror `compaction_dst`'s existing invocation line, including `< /dev/null`.

**A9 green:** a trace-level test asserts exactly one `RunSummary` as the **final** record in the
returned trace on every enumerated terminal path — success, budget, max-steps, compaction
exhaustion, provider failure, tool failure, invalid history, internal; returned outcome, `DoneEvent`
and `RunSummary` agree; no integer code survives at a terminal call site; a setup failure before the
world is established returns a typed `HarnessFailure` rather than a successful empty trace; and a
raw capability bypass still exits non-zero. `check_core` green, `make dst` green, and — now that
A16 has landed — all eight smoke scripts still green.

The spike proved the finalizer tractable: routing every terminal return through one `c2_finalize`
that emits the projection **and** appends the same record was sufficient, with no restructuring
beyond what the ADR budgets. You are not inventing the approach, only building it at HEAD.

`finish_reason_str`'s table has a unit test at `session.ail:2424` pinning seven integer codes to
strings. Replacing the integer helper means replacing that test with one over the typed reason —
the wire strings must not change, and `phase_vocab.ail:1105-1106`'s `RunSummary` goldens are what
hold you to that.

## Out of scope — actively do not do these

- **The event vocabulary (A8)**, per above.
- **World-state threading (A12).** A9 rewrites terminal returns; it does not thread state. If a
  change starts needing `world_state`, it belongs to A12.
- **`HarnessFailure`'s mismatch-detection path** — A13 builds discovery/replay and produces the
  mismatch fixture. A9 builds the *types* and the setup-failure path only.
- **Runtime exclusion enforcement** — that is A10's, and vacuous until a profile installs something.

## Stop and report rather than deciding inline

- If one of the eight smoke scripts fails at HEAD before you change anything, that is a regression
  cluster 1 did not catch. Report it; do not fix it inside A16.
- If any terminal path cannot route through a single finalizer without restructuring beyond the
  ADR's budget, that falsifies a spike result (Q4) and is a plan correction, not a workaround.
- If the typed termination reason cannot map exhaustively onto the existing wire `finish_reason`
  strings, stop: D6.2 requires the list be derived from reachable terminal returns, and a wire
  change is a compatibility decision the plan owns, not this session.

## Traps

Clear `.ailang/cache` before believing a contradicting type error. The compiler reports one
record-field mismatch at a time — cluster 1's parallel `ailang check` over the affected import
closure ran in 12 s and surfaced one error per module; **rebuild or reuse that tool before editing,
not after.** Never probe from `/tmp`. PR #103 must not be merged. Pin is v0.26.0,
Makefile-guarded. `make dst` and CI's line 96 both use `--keep-going`, so read the exit status
rather than the last line of output.

## Report back

Same three measurements, in a note alongside cluster 1's:

- **time and sites touched** for each of A16 and A9, against the plan's estimates (A16: under a day;
  A9: unsized). Cluster 1 established that **sites, not files, is the sizing driver** — A9 has five
  `emit_run_summary` call sites but the terminal-path count is what matters, so report both.
- **judgement-versus-mechanical ratio**, and — more important than the ratio — **whether any site
  admitted two type-checking answers with a silent wrong one.** Cluster 1 found two such sites and
  that finding changed WI-A12's acceptance evidence. It is the thing worth looking for.
- **anything the plan got wrong.** File it as a plan correction; do not silently reconcile.

A9 is the last driver-surface item before A12, which is the critical path. If A9 surfaces a hazard
of cluster 1's kind, say so loudly — A12 threads more cursors through the same literals and is the
item most exposed to it.
