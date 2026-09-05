# The driver re-folds the whole session trace on every tool step, and the run dies at ~10 000 records

## Status

**Fixed 2026-08-17** on `arniwesth/mot-99-fix-max-recursion-depth-10000-exceeded`. Two changes in
`src/core/session.ail`, both smaller than what the *Fix* section below prescribed — read
*What actually landed* before that section, which is kept for its reasoning and is superseded on
the mechanism. Item 3 (`--max-recursion-depth` from the TUI) remains **open** and is deliberately
not part of this fix.

## What actually landed, and why it is not fix 2

**The fault is recursion DEPTH, and AILANG's stdlib traversals are frame-free.** That single fact —
measured, and recorded in [`ailang-no-tail-call-optimization.md`](ailang-no-tail-call-optimization.md)
— makes the fix one function rather than a state-threading refactor:

1. **`runtime_status_counts` now folds with `List.foldl`** instead of hand-written recursion.
   `runtime_status_counts_rec` is gone; its per-record body survives unchanged as
   `runtime_status_count_one`. A `foldl` over 300 elements at a 300-frame descent completes at a
   ceiling of 350 — zero frames — where the hand-written version cost exactly one frame per record.
2. **The call site is lazy and name-guarded.** `encode(runtime_status_json(…))` moved inside the
   `runtime_builtin` lambda, under `call.name == "MotokoRuntimeStatus"`, so a batch that does not
   ask for the status no longer computes it. The predicate is duplicated with the one inside
   `runtime_status_tool_message` on purpose; the comment at the site says why removing either is a
   silent regression.

**Why not fix 2 (incremental counts).** It removes the O(|trace|) *time* as well, which `foldl` does
not — but it adds a field to a record every arm of `c2_loop` constructs, and a counter maintained at
the three sites that append counted records drifts silently the first time a fourth site appends
one. The fold keeps the count **derived from the trace**, which is correct by construction; and the
time cost it leaves is microseconds at the scale that killed the run, now paid only by batches that
actually call `MotokoRuntimeStatus`. The depth — the thing that aborts a session — is gone either
way.

**Evidence.** `ailang check` clean; all 23 `session.ail` inline tests pass, including the three that
assert `runtime_status` count correctness (`test_runtime_status_includes_prior_conversation_counts`,
`…_reports_actual_context_window`, `…_counts_generated_compaction_ai_id`); `make check_core` 57/57;
`driver_only_dst`, `invariants_dst`, `discovery_dst`, `execution_program_dst` all pass. Independently,
the spike (`.agent/projects/011_improve_test_axises/NOTE-spike-findings-resource-growth.md`) had
already established that removing this traversal takes the depth-vs-records slope to **exactly
0.00**, and that it is the **only** O(|accumulated state|) traversal on the driver path.

**Verified end to end, in the DST world.** The first version of this section said it could not be —
wrongly. Bisecting the *whole export* indeed cannot see the difference (the exporter's serializer
masks it: 86 either way), but that is a missing seam, not a limit of DST. `CG_EXPORT_PHASE=driver`
now restores the ablation the spike built and disposed of — five lines in
`scripts/dst/export_trace.ail`, writing nothing and off by default.

With it, the driver phase measured out of process at tolerance 1, same seeds, same traces:

| seed | records | before the fix | after | spike's independently-measured floor |
|---|---|---|---|---|
| 7  | 79  | 86  | **58** | 58 |
| 11 | 126 | 153 | **87** | 87 |
| 23 | 96  | 114 | **75** | 75 |

**Exact agreement on all three, to the frame**, against a spike that removed the traversal a
different way (`let counts = st.prior_counts;`, which undercounts). Two unrelated implementations
landing on the same floor is what you expect if both removed the same traversal and nothing else.

**Like-for-like**: record counts are identical in both conditions (79/126/96), so the depth moved and
the trace did not. The default export path is unchanged — `run_export_trace.sh --seed 7` still writes
79 records — and `driver_only_dst`, `invariants_dst`, `discovery_dst` pass.

**Gated** — `make depth_canary` (`scripts/dst/run_depth_canary.sh`), in `DST_TARGETS`. Two tiers,
both using a deliberately low `--max-recursion-depth` as the instrument:

- **Tier 0**, `scripts/dst/recursion_depth_probe.ail` — calls the real
  `session.runtime_status_counts` (exported for this one caller) over 8 192 constructed records at
  a ceiling of 200. Precise, milliseconds, cannot drift; guards one function. The trace is built by
  **doubling** on frame-free `++`, so the setup costs ~13 frames rather than 8 192 and cannot
  dominate the measurement.
- **Tier 1** — the real driver out of process at pinned per-seed ceilings (7→70, 11→104, 23→90;
  floors 58/87/75 plus ~20%). General: catches *any* new O(|trace|) traversal on the driver path,
  not just a regression of this one. Record counts are pinned too, because `export_trace` prints
  refusals and exits **zero** — without that assertion a misconfigured harness would pass.

**Shown to fire**, which is this project's standing caveat on any guard: against the pre-fix driver
all four rows go red (tier 0 aborts at 200; seeds 7/11/23 exceed their ceilings at 86/153/114);
against HEAD all four are green. That is a measurement of a real regression, not a hypothetical.

Neither tier is sufficient alone — tier 0 is narrow, tier 1 is a pin whose floor (~2.4 frames per
decision plus ~23) moves when `c2_loop`'s per-step cost legitimately changes. They cover each
other's weakness. What is still not built is ADR-002's full relation — slope of depth against
records with trajectory length held fixed. **The lever it was waiting on now exists.** It needed a
records-per-step knob the generator did not have, because `max_chunks_per_interaction` clamped a
draw hardcoded to `0, 3`; `PLAN-resource-growth-relation.md`'s WI-1 declared that range as
`GeneratorBounds.chunk_draw_hi` and gave `export_trace` a `CG_EXPORT_CHUNK_DRAW_HI` seam over it,
measured at 1.65×/1.71×/1.82× records on seeds 7/11/23 with step, provider-call and tool-batch
counts constant. The relation itself — the statistic, its threshold and the demonstration that it
fires — is WI-3 and is **planned but not built**; see
`.agent/projects/011_improve_test_axises/PLAN-resource-growth-relation.md`. Until it is green,
`run_depth_canary.sh` remains the only gate on this issue and does not retire.

## GitHub

[arniwesth/motoko_agent#160](https://github.com/arniwesth/motoko_agent/issues/160) — "Max recursion
depth 10000 exceeded". Response posted as the bot:
[#160 (comment)](https://github.com/arniwesth/motoko_agent/issues/160#issuecomment-5313284835).

First record here to carry a GitHub number. Existing records predate `016_github_ops`; now that the
pipeline treats the file on disk as truth and GitHub as transport, the pair should be reconcilable
from either end.

## Branch

arniwesth/mot-99-fix-max-recursion-depth-10000-exceeded — the fix branch, and where this record
lands. Diagnosed from a session run on arniwesth/mot-97-github-ops; the fault is at HEAD and is
neither branch's doing.

## Description

A live session died mid-run with the runtime process aborting:

```
Error: execution failed: RT_REC_003: max recursion depth 10000 exceeded.
Try smaller input, enable tail recursion, or increase with --max-recursion-depth
```

Two things have to be true at once for this to happen, and neither is sufficient alone.

**One: AILANG v0.33.0 has no tail-call optimization.** Every user-level function application costs
an interpreter frame against a 10 000 ceiling, tail position or not, so recursion depth over a list
is the list's length. Recorded separately as
[`ailang-no-tail-call-optimization.md`](ailang-no-tail-call-optimization.md) — that record carries
the measurement and the upstream-facing half.

**Two: the driver derives `MotokoRuntimeStatus`'s counters by folding the entire accumulated
`LedgerTrace` on every tool-dispatch step.** That is this issue. The fold is O(|trace|) per step
against a trace that only grows, so the run has a hard ceiling on total recorded events — and it
crosses it silently, mid-session, with no degradation beforehand.

### The crash site, pinned from the log

The session log dates it to the millisecond. Step 62 emitted `native_tool_calls` at 22:19:21.637
and the error landed at 22:19:21.681 — 44 ms later — with **no `v2_tool_dispatch_start`** for that
step. Every one of the 62 preceding steps emitted the dispatch event.

Exactly one thing runs between those two emissions, `session.ail:2470`:

```ailang
let runtime_status_content = encode(runtime_status_json(st, policy, tool_step_idx));
```

`runtime_status_json` (`session.ail:502`) opens at `:507` with

```ailang
let counts = runtime_status_counts_add(st.prior_counts, runtime_status_counts(st.trace));
```

which reaches `runtime_status_counts_rec` (`session.ail:437`) — one frame per trace record.

**It is computed unconditionally.** The value is only ever consumed inside the `runtime_builtin`
closure on the next line, which fires solely when the batch contains a `MotokoRuntimeStatus` call.
Every other tool batch in every session pays the full fold and discards the result.

### Why the trace reached ~10 000 records

Stream deltas dominate, and they are in the trace by design. `session.ail:2635` converts the
provider exchange's chunk log to `[LedgerEvent]`, and `:2639` appends all of them to the returned
trace. So **the trace grows with token volume, not with step count.**

Counted from `.motoko/logfile/session_2026-08-16T22-09-09-371Z.jsonl` up to the crash:

| source | count |
|---|---|
| wire records appended (8 678 of them `StreamDelta`) | 9 172 |
| `DecisionRecord` — 2 `c2_loop` arms × 63 steps | 126 |
| `CompactionStageRecord` — 9 loaded extensions × 63 steps | 567 |
| **total `trace.records`** | **9 865** |

The stage records are unconditional too: `fold_pre_step_chain_rec` (`ext/runtime.ail:300-323`)
conses one stage per hook per step on every arm, including `StagePassed`.

The remaining ~135 frames are the ambient depth of `c2_loop` itself (`session.ail:2240`), which is
also self-recursive with no TCO and retains 2–4 frames per step across 63 steps. 9 865 + ~135
crosses 10 000 — which is why it fired on this step and not the one before.

### Reproduction

The shape reproduces in isolation in a few lines — retained driver frames plus a fold over an
accumulated list:

```ailang
func count_rec(xs: [int], acc: int) -> int {
  match xs { [] => acc, _ :: rest => count_rec(rest, acc + 1) }
}

func driver(steps: int, xs: [int]) -> int {
  if steps == 0 then count_rec(xs, 0)
  else { let _ = count_rec(xs, 0); driver(steps - 1, xs) }
}

-- driver(500, build(9800, [])) → RT_REC_003
```

Reproducing it *through the real loop* needs a session that streams ~9 000 chunks, which is roughly
an hour of live agent work. That asymmetry is the whole problem with this class of fault and is why
the DST suite cannot see it — see below.

## Location

- `src/core/session.ail:2470` — the unconditional `encode(runtime_status_json(...))` per tool batch.
  **The crash site.**
- `src/core/session.ail:507` — `runtime_status_counts(st.trace)`, the O(|trace|) derivation.
- `src/core/session.ail:437` — `runtime_status_counts_rec`, one frame per record.
- `src/core/session.ail:2635`, `:2639` — stream chunks converted and appended to the trace; why the
  trace scales with token volume.
- `src/core/session.ail:2240` — `c2_loop`, self-recursive, contributes the ambient depth.
- `src/core/session.ail:367`, `:395` — `C2LoopState` and its existing `prior_counts` field.
- `src/core/ext/runtime.ail:300-323` — one `CompactionStageRecord` per hook per step, unconditional.
- `src/core/phase_vocab.ail:604` — `ledger_append`, the only writer.
- `src/tui/src/runtime-process.ts:474-491` — the `ailang run` argv; passes neither
  `--max-recursion-depth` nor `--process-timeout`, so both take AILANG defaults.
- Evidence: `.motoko/logfile/session_2026-08-16T22-09-09-371Z.jsonl` — 9 176 lines, the warning is
  the final one; step-62 `native_tool_calls` at line 9 175 with no matching dispatch event.

## Fix

`st.trace.records` is walked in exactly **one** place per step, so this is a single-site fix. In
priority order:

### 1. Maintain the counts incrementally (the real fix)

The mechanism is already in the tree and already crosses a session boundary: `C2LoopState` carries
`prior_counts: RuntimeStatusCounts` (`session.ail:395`) and `runtime_status_counts_add` composes
two of them. Extend the same idea inward — update a running `RuntimeStatusCounts` as records are
appended, and let `runtime_status_json` read it instead of re-deriving from the whole trace. The
counters are all monotone sums over record kinds, so there is nothing to reconstruct.

This removes the O(|trace|) work entirely rather than making it rarer, which is what the fault
actually requires: a session that legitimately calls `MotokoRuntimeStatus` late in a long run must
not be the thing that kills it.

### 2. Make the payload lazy (cheap, do it anyway)

Move `encode(runtime_status_json(...))` inside the `runtime_builtin` lambda at
`session.ail:2470-2471`, so it is computed only when a `MotokoRuntimeStatus` call is actually in
the batch. Roughly three lines. It does not close the fault on its own — this agent calls
`MotokoRuntimeStatus` routinely, including late in long sessions — but it removes a per-step cost
that is pure waste in every other batch, and it is correct independently of (1).

### 3. Pass `--max-recursion-depth` from the TUI

`src/tui/src/runtime-process.ts:474-491` passes neither this nor `--process-timeout`. The second is
already known — it is the 30 s cap that made this same session's `ClaudeExec`/`CodexExec` calls
report the misleading "could not be spawned" (#158). Raising the recursion ceiling only moves the
wall, and should not be mistaken for a fix, but an explicit value beats an inherited default that
nobody chose.

### Not a fix: trimming stream deltas from the trace

The obvious-looking move — stop appending 8 678 `StreamDelta` records — **violates a deliberately
designed invariant.** `StreamParityCount` (`dst_invariants.ail:432`) requires every projected stream
emission to reach the returned trace; D6.4 names streams as the one class where a shared
append/project transition is impossible and discharges the obligation with exactly this parity
check. The header at `dst_invariants.ail:100-121` records that both sides of the check were empty
before WI-C3 and that appending them is what made a real run testable at all.

The trace is *supposed* to mirror the wire delta-for-delta. The defect is the per-step fold over it,
not its size.

## Why nothing caught it except one specific shape of test

Four independent reasons, each sufficient on its own. Written out because "the DST suite would have
found this with more seeds" is the plausible and wrong answer.

**1. Wrong fault class for every family.** All twelve invariant families
(`dst_invariants.ail:219-233`) are correctness relations over a trace: pairing, parity, monotonicity,
agreement, replay equality. This is a *resource* fault — per-step work that is O(accumulated state).
Nothing in the set expresses growth or complexity. The nearest name, `BoundedProgress`, is bounded
*retry*, not bounded state. The trace that killed the run is perfectly well-formed; it is merely
large.

**2. The generator's declared bounds cap the exact axis, ~30× below the threshold.**
`dst_generator.ail`'s `choose_provider` drew stream chunks as `bounded_draw(…, 0, 3,
"max_chunks_per_interaction", …)`; declared profiles set that bound to 4 (`canary_bounds`) or 1,
with `max_interactions` 64–96. Ceiling: **~288 stream deltas per program**.
*(WI-1 replaced the literal `3` with the declared `chunk_draw_hi`, so the range is now a knob rather
than a constant. The paragraph below still holds and is the reason it had to become one: the ceiling
moves only where a profile declares that it moves, and no amount of seed-churning crosses it.)*
Production produced **8 678 from 63 steps** — ~138 per interaction.

This is not a sampling gap more seeds would close. Per D2 the generator *never* exceeds a declared
bound: it takes the bounded alternative and records a generator failure, and `HarnessHygiene`
requires those to be **zero**. The bounds are a hard ceiling by construction, so no amount of
seed-churning drifts toward the failing scale.

**3. The harness shares the fault's own budget.** DST runs in the same `ailang run` process, same
evaluator, same 10 000 default. If a program ever did reach that scale, RT_REC_003 would kill *the
harness* — a process abort, not an invariant violation — with a message pointing at the test. And
since the harness sits at its own ambient depth, the threshold would move between suites, so it
would not even be a stable repro.

**4. Shrinking would not have helped.** ddmin over `ExecutionProgram` *minimizes* a failing program
(project 011 §3.2). This fault exists only at maximum scale; the minimal reproducer is the whole
program. Shrinking finds the small witness inside a large failing case, and here there is none.

### What would catch it

Routed to `.agent/projects/011_improve_test_axises`, which is already the project for test axes and
whose RESEARCH doc has the open-questions section this belongs in:

- **A declared long-run / soak profile** with `max_chunks_per_interaction` in the hundreds. Not a
  bump to the existing bounds — D2's "not an unbounded test run" is deliberate — but a separate
  profile that declares the large scale and runs rarely.
- **A thirteenth family for resource growth.** Not checkable from a trace directly, since it is a
  property of the code; the checkable proxy is asserting observed `trace.records` against
  `decision_budget × a declared per-step record ceiling`. That turns "the trace grows with token
  volume" into a red row instead of a live crash.
- **§3.8, invariants as production monitors** — running the families over real session ledgers is
  the one axis where this scale actually occurs. It would not fire today, for reason 1 above, but
  it is the right place to hang the new family.

## Related

- [`ailang-no-tail-call-optimization.md`](ailang-no-tail-call-optimization.md) — the enabling
  condition, and the upstream-facing half.
- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md` — where the axis gap
  belongs; this is a concrete motivating case for it.
- #158 — the other default the TUI never passes (`--process-timeout`, 30 s), found in the same
  session and with the same shape: an inherited default nobody chose, surfacing as a misleading
  message.
