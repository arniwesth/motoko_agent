# 2026-08-17 A per-step fold that aborted a live run, and the test axis that could not see it

## Context

Branch: `arniwesth/mot-99-fix-max-recursion-depth-10000-exceeded`, off `mot-98`. Entry point was an
issue and a log — *"Investigate this issue: …/issues/160. You may be able to use last motoko run
log for insights as this is the session where it happened"* — with the fix, the axis work, the gate
and the PR all arriving as follow-on asks rather than as a stated scope.

25 commits, 44 files, +4,569/−101. The split is the shape of the session:

```text
.agent/                     17 files, +3,620    the record: 1 ADR, 2 plans, 5 notes, 2 issue records
src/ scripts/ tools/ Makefile  26 files, +928   the fix, the lever, the seam, the gate
```

The fix itself is **four hunks**. Everything else is either what it took to be sure it was the
right fix, or what it took to stop it coming back.

Shipped: #160 fixed and verified end to end; `make depth_canary` in `DST_TARGETS`; a records-per-step
lever in the generator; PR [#161](https://github.com/arniwesth/motoko_agent/pull/161) open as the bot,
stacked on #162.

## The fault

A live session died at `RT_REC_003: max recursion depth 10000 exceeded`, in code containing no
unbounded recursion. Two things had to be true at once:

1. **AILANG v0.33.0 eliminates no tail calls.** Measured exactly: 9,999 passes, 10,000 aborts. A
   tail call costs one frame, so depth over a list is the list's length.
2. **`runtime_status_json` folded the whole accumulated `LedgerTrace` once per tool batch**
   (`session.ail:2470` → `:507` → `:437`), with hand-written recursion.

Pinned from the log rather than inferred: step 62 emitted `native_tool_calls` and no
`v2_tool_dispatch_start`, and exactly one thing runs between those two points. The trace was ~9,865
records — 88% of them `StreamDelta`, so it scales with **token volume**, not step count.

**The obvious remedy was forbidden.** Trimming stream deltas from the trace violates
`StreamParityCount` / D6.4, which requires every projected stream emission to reach the returned
trace. Recorded as a "Not a fix" section because it is what the next reader reaches for first.

## The fix is smaller than the issue record prescribed

The record called incremental counts "the real fix". One measured fact collapsed it: **AILANG's
stdlib traversals are frame-free** — `foldl`, `++`, `List.map`, `Str.join`, `std/json.encode` all
cost zero frames at a 300-frame descent over 300 elements. Depth in this codebase comes *only* from
recursion we write ourselves.

So: `List.foldl` instead of hand-written recursion, plus a lazy name-guarded call site. One function
and one lambda, against threading a new `C2LoopState` field through every arm of `c2_loop` — and it
keeps the count **derived from the trace**, which cannot drift the way a maintained counter can.

## Three passes, and what each one caught

The ADR that governs the test axis was wrong three times, and the passes are the point:

| pass | mechanism | found |
|---|---|---|
| authoring | prose | — |
| review | prose + targeted probes | 2 majors |
| **execution** (throwaway spike) | the smallest working version | **3 more**, one of them blinding |
| **WI-1** (the lever, another session) | building the thing the ADR assumed | **4 more**, one invalidating its central claim |

Corrections 1–5 came from reading; 6–12 came from running. The three that mattered most:

- **The instrument measured the wrong process.** The ADR named `export_trace` as the phase to
  bisect. Its own serializer recurses per record, so a faulty and a fixed driver both report **86** —
  the two rows the relation exists to separate are the two it could not tell apart. *Third* instance
  of the same maximum-wins confounder: twice I fixed the specific source and never swept the class.
- **"Slope must be zero" was a property of the lever, not the driver.** True at 1.25× range, false
  past it — the healthy slope rises to 0.027–0.146, because `stream_chunk_events` walks one step's
  chunks by hand-written recursion and every per-step list here is built that way. The separation is
  a **ratio, not a floor**.
- **The gate is green on a regression of the fault it was built for.** Restore the fold, leave the
  fix's *name guard* in place, and tier 1 passes on all three seeds — no generated world requests
  `MotokoRuntimeStatus`, so the guarded traversal is unreachable. **The laziness half of a fix
  silently narrowed the reach of the gate built for that fix**, and no reading of either change
  would have surfaced it.

## Verified, in the DST world

"Not verified end to end" was my own conclusion and it was wrong. Bisecting the *whole export*
genuinely cannot see the fix; that is a **missing seam, not a limit of DST**. The spike built the
seam and disposed of it by guardrail, and I then treated its absence as a property of the system.

`CG_EXPORT_PHASE=driver` restores it — five lines, writes nothing, off by default. With it, the
driver phase at tolerance 1:

| seed | records | before | after | spike's independently-derived floor |
|---|---|---|---|---|
| 7  | 79  | 86  | **58** | 58 |
| 11 | 126 | 153 | **87** | 87 |
| 23 | 96  | 114 | **75** | 75 |

Exact agreement on all three, to the frame, against a spike that removed the traversal a different
way. Record counts identical in both conditions: the depth moved and the trace did not.

## The gate

`make depth_canary`, two tiers, because neither is sufficient alone:

- **Tier 0** — the real exported `runtime_status_counts` over 8,192 records at a ceiling of 200.
  The trace is built by **doubling on frame-free `++`**, so setup costs ~13 frames instead of 8,192;
  a probe whose own setup dominates its measurement is the same confounder again. Asserts the
  **count** as well as the depth, because a fold that returns zero without traversing is frame-free
  and worthless.
- **Tier 1** — the real driver out of process at pinned per-seed ceilings. Record counts are pinned
  too, and that is load-bearing: `export_trace` prints refusals and exits **zero**, so a
  misconfigured harness would otherwise pass.

**Shown to fire**, which is this project's standing caveat on any guard: against the pre-fix driver
all four rows go red; against HEAD all four are green.

## What DST was and was not

The twelve invariant families could not have caught this and still cannot — they are correctness
relations over a trace, and this is a *resource* property whose quantity is how many times the
driver **walked** the trace, which a trace does not record. **No thirteenth family was added.**

But the substrate carried the detection entirely: generator, `driver_only` profile, deterministic
replay, world/ports boundary and exporter, all reused unmodified. The instrument uses DST's **world
and none of its oracle** — it never calls `evaluate()`, never builds an `ExecutionUnderTest`, and
could not, since that type describes one run and the property is a relation between two.

**DST's world was reusable enough to build a different kind of detector on**, and that is the thing
that got vindicated. What the work strained against was **parameterization and observability**, not
fidelity: a chunk draw hardcoded `0, 3`, trajectory shape that cannot be required, phases that
cannot be ablated. Written up in `NOTE-dst-substrate-versus-oracle.md`.

## Cost that nobody budgets

The #160 fix's functional diff is four hunks. It re-issued **three profile versions across six
files**, because the five pinned `session.ail` clock anchors moved — pushed by the ~54 lines of
**comment** the fix added above them. Thirty lines of prose above an anchor cost exactly what thirty
lines of code do. The D4 judgement was made rather than assumed: `grep -o 'clock_now(.*'` is
identical before and after, six sites and six, so it is an anchor re-measurement and not a table
correction.

Cascade width was **derived by grep, not assumed** — the four fixture scripts in the documented
eleven-file set needed no edit, because they call `driver_only_version()` derivatively rather than
pinning literals. Six files, not eleven.

## Verified

```text
ailang check src/core/session.ail       ✓          make depth_canary       PASS (4 rows)
ailang test  src/core/session.ail       23/23      make anchors            PASS (10 anchors)
make check_core                         57/57      make attribution_table  PASS
driver_only_dst, invariants_dst,                   make driver_only        PASS
discovery_dst, execution_program_dst    PASS       make profile_definition PASS
```

Known red, pre-existing and untouched: `driver_plus_no_ops` / `driver_plus_compose` fail the
`agentcli` inheritance check. Confirmed identical at the stashed baseline before and after; both
profiles' own re-issues validate inside those runs. `017_extension_handling`'s subject.

## Open

- **ADR-002's full slope relation is not built.** It needs a declared threshold (Correction 9) and a
  seed-set decision — 15 of seeds 1–40 never reach the tool arm, so a single-seed gate is vacuously
  green better than one time in three. `PLAN-resource-growth-relation.md` WI-2/WI-3.
- **Fix item 3**, passing `--max-recursion-depth` from the TUI, deliberately not bundled.
- **`ailang-no-tail-call-optimization.md` is not filed upstream.** Filing is outward-facing and was
  not asked for. The error text advising "enable tail recursion" — a feature that does not exist —
  is worth filing whatever the status of the TCO half.
- **`DST_KNOWN_RED` lists two targets that now pass** (`test_coverage`, `test_coverage_selftest`).
  One-line Makefile edit, nobody's cluster.
- **A live-session test exists but has not been run**: `tmp/issue-160-test/`. Its verifier fails
  closed on the two ways that test goes green for the wrong reason — never calling
  `MotokoRuntimeStatus`, or never reaching production scale.

## Method notes worth keeping

- **Verified is not validated.** I ran my own recipe end to end against the real target, got a real
  number, and shipped it as evidence the instrument worked. The number was measuring the serializer.
  An instrument that *runs* is not one that *discriminates* — the check is a known-good and a
  known-bad input with different answers.
- **When review identifies a class, the correction is a sweep, not a patch.** The masking-traversal
  class was found in review, fixed at one site, and its third instance sat inside the very process
  the correction then named.
- Both traps I wrote into the spike's method appendix were caught **only by running the snippet**:
  a `--max-recursion-depth` placed after the `.ail` path is silently ignored, and bisecting through
  `run_export_trace.sh` reads `grep`'s exit status. Both fail toward a false green.
- Recorded as a third instance on
  `../meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
  — the first where rule 2 was **obeyed** rather than violated, and the payoff measured.
