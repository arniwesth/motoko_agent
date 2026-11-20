# F1 results: reach probes under a full `make dst`

Run on 2026-11-19, 16:45 to 18:41 UTC, by `reach-dst-plan.md` and nothing else. Twelve sweeps, one
probe each, in the scratch worktree at `dd8a12f1`. Every sweep restored the tree to `base.sha256`
(`sequence.log`, 18:40:51Z). Machine readings: `reach-dst-scores.tsv`. Raw output: `runs/dst/X-*/`.

## Result

Of the 11 sites no `corpus_judge` run walks, **8 are walked by another `make dst` target**. **3 are
walked by none**: m15, and the two sites judged dead code (m08, m26).

| site | predicted | under `make dst` | targets that printed the probe's error |
|---|---|---|---|
| X-ctl (positive control) | reached | **reached** | corpus_judge, corpus_pr, depth_canary, discovery, latency_pair, seeded_generator, smoke_driver, smoke_parity, strict_replay; applied_twin by its kept output |
| m02, response-intercept arm | not reached | **reached** | discovery, driver_plus_compose, smoke_driver, smoke_parity, strict_replay |
| m03, approval timeout that allows | not reached | **reached** | smoke_driver, smoke_parity |
| m12, delegated backend | not reached | **reached**, read by hand | ledger_parity, world_framed_wire (below) |
| m13, a policy that denies | reached | **reached** | compaction_dst, journal_resume, smoke_driver, smoke_parity, terminal_trace, world_state |
| m15, scratchpad tool | reached | **not reached** | none |
| m17, await-wake state | reached | **reached** | driver_plus_herdr, herdr_graded, park_resume |
| m19, a policy that denies | reached | **reached** | as m13 |
| m23, wake match | reached | **reached** | park_resume |
| m30, wake match | reached | **reached** | driver_plus_herdr, herdr_graded, park_resume |
| m08, judged dead | not reached | **not reached** | none |
| m26, judged dead | not reached | **not reached** | none |

Target lists are a lower bound: a probe that fires ends its run, so later scenarios in that target
do not run. Several sweeps also turned other targets red without printing the probe's error
(`new_red_vs_C-base` in the TSV); those are not counted as reach.

**Predictions: 8 of 12 held.** The text search of `scripts/dst/` missed 4. m02, m03 and m12 were
predicted unreached and are reached. m15 was predicted reached and is not: the scratchpad tool
named in `attribution_table_dst` and `driver_plus_compose_dst` is a classified site and a stated
absence ("compose provides no tool named `scratchpad`"), not a run through the branch.

## m12, read by hand

The sweep turned `ledger_parity` and `world_framed_wire` red with no probe error in its log.
Both targets run `scripts/dst/ledger_parity_dst.ail` into a `mktemp` file, print only its `  ✗`
rows on failure, and delete the file on exit, so a runtime error is never shown. By the step fixed
at 18:39:09Z, `scripts/run_program.sh` ran that program once under the probe with its output kept
(`runs/program/ledger_parity_dst/X-m12/`). It holds `RT001: integer division by zero at
.../src/core/tool_phase.ail:476:23`, inside the `delegated` frame. Reached by both targets.

## What it changes, and what it does not

- **"Not reached" was a `corpus_judge` finding.** Across the suite, the reach gap among these 11
  is m15, the scratchpad-extension branch of `execute_allowed_tool_call`, which ADR-003 D6 already
  names ("a tool an extension handles"). m08 and m26 stay unreached, which is consistent with the
  dead-code judgement and does not prove it.
- **The 8 mutants at reached sites were never run under the targets that reach them.** Tier 3
  ran only on mutants a `corpus_judge` member reaches, and tier 4 only on m05, m10, m11 and m18.
  Whether those targets kill m02, m03, m12, m13, m17, m19, m23 and m30 is not measured.
- **A side observation.** `ledger_parity` and `world_framed_wire` discard a crashing program's
  error message: m12's probe crash shows only as a missing frame end. That is a diagnosability
  gap in two gates, not a missed failure; both went red.

## Not verified

- A gate that catches a runtime error and stays green would hide a hit. The three unreached
  sweeps show no `RT001` and no "division by zero" anywhere and no target newly red. Their logs
  are as long as C-base's (3852 lines), so the remaining risk is a gate that both swallows the
  error and changes nothing it prints.
- Sweep times ran from 207 s to 751 s under shared load (6 to 14). Every sweep printed its summary
  block; the short ones are not truncated.
