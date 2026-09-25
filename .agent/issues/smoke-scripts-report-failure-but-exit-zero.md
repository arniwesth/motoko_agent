# Smoke scripts report `✗` but exit 0, so the gates that run them cannot fail

## Status
open (4 of 15 fixed in `61f38db`; 11 remain)

## Branch
arniwesth/mot-46-execute-wi-a16-and-wi-a9 (surfaced while executing WI-A16)

## Description

Fifteen scripts under `scripts/` have a `main` that evaluates assertions, prints `  ✗ <name>` or
`FAIL` when one fails, and then **returns normally with exit code 0**. A failed assertion is
therefore indistinguishable from a passing run to anything that checks the exit status.

This was found while wiring WI-A16 and it makes the coverage story worse than the plan recorded —
see "The C6 correction" below, which is the part worth reading.

### Measured, not inferred

One assertion in `scripts/smoke_v2_dp7_gate.ail` was deliberately inverted
(`test_dp7_fail_open_on_missing_make` flipped to return `false`) and the script run directly:

| | exit code |
|---|---|
| before adding an exit path | **0** |
| after adding an exit path | **1** |

The same break, run through `scripts/dst/phase_a_event_parity.sh` — the script behind
`make smoke_parity`, which **is** a CI step:

| | exit code |
|---|---|
| pre-A16 script (no exit path) | **0** — CI green with a broken assertion |
| post-A16 script (exit path) | **1** — CI red |

### The C6 correction

`NOTE-cluster-1-execution-report-and-plan-corrections.md` C6 states that the eight driver smoke
scripts "are in no `make` target and no CI job". **That is wrong, and WI-A16's justification in the
plan inherits the error.** All eight are invoked by `scripts/dst/phase_a_event_parity.sh:174-183`,
which `make smoke_parity` runs and which the `smoke_parity` CI step calls.

What was actually true is narrower and worse:

- the scripts **ran** in CI, but only their **JSONL projection** was consumed — the harness diffs
  run A against run B for event parity;
- `awk '/^\{/'` (`phase_a_event_parity.sh:78`) keeps only lines starting with `{`, so the prose
  `✗` lines **never reach the diff artifacts**. Confirmed: the captured
  `smoke_v2_dp7_gate.jsonl` contains zero `✗`;
- and because four of the eight exited 0 on failure, `set -euo pipefail` had nothing to catch.

So the eight were **run but ungated**: executed on every CI run, with their assertions unable to
fail the build. That is a more dangerous state than "never run", because the green check implies
coverage that does not exist. The four scripts that already had `exit(1)`
(`stream_parity`, `ext_fixture_parity`, `compaction_chain`, `phase_a_tool_parity`) *were* gated,
via pipefail — which is why the defect was invisible: half the set worked.

C7's other half stands unchanged: `src/core/test/scripted_ports.ail`'s six unit tests genuinely were
run by nothing.

## Location

**Fixed in `61f38db`** — these four now aggregate their case booleans and `exit(1)`:

- `scripts/smoke_v2_dp7_gate.ail`
- `scripts/smoke_v2_pending_full_loop.ail`
- `scripts/smoke_v2_compaction_full_loop.ail`
- `scripts/smoke_v2_cost_budget_full_loop.ail`

**Still open — reports failure in prose, exits 0:**

| script | referenced by a target? |
|---|---|
| `scripts/smoke_v2_handle.ail` | yes — `phase_a_event_parity.sh:183` (**run but ungated**) |
| `scripts/smoke_v2_hybrid.ail` | yes — `phase_a_event_parity.sh:184` (**run but ungated**) |
| `scripts/smoke_v2_backend.ail` | no |
| `scripts/smoke_v2_compaction.ail` | no |
| `scripts/smoke_v2_cost_budget.ail` | no |
| `scripts/smoke_v2_pending.ail` | no |
| `scripts/smoke_v2_policy_denial.ail` | no |
| `scripts/smoke_v2_workdir_resolution.ail` | no |
| `scripts/smoke_v2_writefile_missing_parent.ail` | no |
| `scripts/smoke_compaction_e2e.ail` | no |
| `scripts/smoke_compaction_tool_call_id.ail` | no |
| `scripts/probe_phase_vocab_sealed.ail` | no — and broken at HEAD, see separate issue |

`smoke_v2_handle` and `smoke_v2_hybrid` are the urgent two: they are in a CI-reachable path today
and cannot fail it.

A further nine scripts have no exit path *and* no failure reporting at all
(`smoke_callstream`, `smoke_dispatch_adapter`, `smoke_ports_record`, `smoke_v2_bash_wrap`,
`smoke_v2_conversation`, `smoke_v2_factual`, `smoke_v2_intercept`, `smoke_v2_policy`,
`smoke_v2_tool_build`, `smoke_v2_tool_read`, `smoke_v2_tool_write`, `spike_trace_forwarding`,
`verify_extension_boot`). Those are demo/inspection scripts rather than assertions, so they are not
in scope here, but they are why a blanket "every script must exit non-zero" rule would be wrong.

## Fix

1. **`smoke_v2_handle` and `smoke_v2_hybrid` first**, since they are the two in a live CI path.
   Both already compute a pass/fail boolean and print `PASS`/`FAIL`; they need the established
   house pattern only:

   ```
   if all_ok then println("<name> PASS")
   else {
     let _ = println("<name> FAIL");
     exit(1)
   }
   ```

   Add `exit` to the `std/io` import. This is the form
   `smoke_v2_compaction_chain.ail:197-205` already uses.

2. The remaining nine unwired ones, same pattern, then decide per script whether it is worth a
   target. Several look like they were written as one-off demos and never promoted; the ones that
   assert real behaviour belong in `make smoke_driver`.

3. **Add a guard so this class cannot recur.** A grep-level check in the Makefile — any script under
   `scripts/` whose source contains a `✗` or `FAIL` literal must also contain `exit(` — would have
   caught all fifteen and costs nothing to run. This is the same shape as the finalizer-bypass guard
   added in `ff8d8e5`.

## Non-goals

- Do **not** convert the demo/inspection scripts into assertion scripts. Some exist to print output
  a human reads.
- Do not add these scripts to `phase_a_event_parity.sh` to gate them. That harness exists for JSONL
  event parity and strips prose by design; adding assertion-checking to it would conflate two jobs.
  `make smoke_driver` is the right home.

## Notes

The general lesson is the one WI-A16's acceptance clause encoded: **"the target fails when any one
of them fails, verified by breaking one deliberately"** is a materially different requirement from
"the scripts run in a target", and only the first would have caught this. Acceptance evidence that
demands a demonstration rather than an assertion is worth the extra minutes — it cost about two here
and invalidated a claim that had already survived one execution report and one plan revision.

Related: `.agent/projects/009_motoko_dst_execution/NOTE-cluster-4-execution-report-and-plan-corrections.md`
(C1), which records the cost and the ratio for the four that were fixed.
