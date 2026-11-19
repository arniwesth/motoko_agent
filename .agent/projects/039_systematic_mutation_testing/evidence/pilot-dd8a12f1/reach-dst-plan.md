# F1: reach probes under a full `make dst`

Added 2026-11-19 at the operator's request, after the pilot and amendment A5. Tier 2 ran each reach
probe under `make corpus_judge` only, so "not reached" meant not reached by its 18 members and 5
controls. F1 runs the same probes under `make dst`, to read which of those sites any gate in the
suite runs.

**What runs.** These probes, from `scripts/fixed_edits.py` unchanged, one at a time in the scratch
worktree at `dd8a12f1` by `scripts/run_gate.sh dst`, in this order:

- `X-ctl`, the positive control: the approved-call handoff, which fired on seed 3 in tier 2;
- the nine not reached by `corpus_judge` and not judged dead: `X-m02`, `X-m03`, `X-m12`,
  `X-m13`, `X-m15`, `X-m17`, `X-m19`, `X-m23`, `X-m30`;
- the two judged dead code, last, as a check of that judgement: `X-m08`, `X-m26`.

m09 and m14 are not run: `corpus_judge`'s own controls already reach them, and `make dst` runs
`corpus_judge`.

**What counts as reach.** `scripts/score_reach_dst.py`, self-tested on planted cases before any
F1 sweep ran. A site is reached when the sweep's log holds the probe's own error, `RT001: integer
division by zero` at the probe's file and line. Any other target newly red against C-base (the
tier-4 base sweep, same tree and toolchain) is read by hand and is not reach. A static check can
go red on the added statement without the site running.

**Predictions**, written before any F1 sweep, from a text search of `scripts/dst/` only:

| probe | predicted | why |
|---|---|---|
| X-ctl | reached, by `corpus_judge` at least | it fired in tier 2 |
| X-m02 | not reached | `compose_live_exec.ail` drives the intercept dispatch but says it is not a session |
| X-m03 | not reached | `AllowAfterTimeout` appears in no DST script |
| X-m12 | not reached | the delegated backend appears only in event-vocabulary checks |
| X-m13 | reached | a denying policy appears in `ledger_parity_dst`, `world_state_probe`, `scripted_cursor_probe` |
| X-m15 | reached | the scratchpad tool appears in `attribution_table_dst` and `driver_plus_compose_dst` |
| X-m17 | reached | `park_resume_dst.ail` |
| X-m19 | reached | as X-m13 |
| X-m23 | reached | as X-m17 |
| X-m30 | reached | as X-m17 |
| X-m08 | not reached | judged dead code |
| X-m26 | not reached | judged dead code |

**Limits, known before running.** A probe that fires ends the run it fires in, so a target's later
scenarios may not run. The list of targets that reach a site is therefore a lower bound. A gate
that catches runtime errors without printing them would hide a hit; the positive control shows
which targets print it.
