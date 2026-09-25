# LEG-D11-CEIL — re-measure D11's PR corpus cost and move its constants (013 surface)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). This task is **outside 031's line R**, which is
complete: it is 013's D11 corpus arithmetic, handed over by the operator because the gate blocks PR 186.
You do not edit the ADR or PLAN-001, you do not write the dagr run file, and you do not touch other panes
or worktrees.

## The failure

`make corpus_pr` fails: **"the PR corpus target took 106000 ms against a declared ceiling of 80000 ms"**
(CI run `35884636365`, job `pr-corpus`, PR 186 at `42dc0c18`). The ceiling is
`pr_target_ceiling_ms()` (`src/core/dst_corpus.ail:394`, 80000); the seed arithmetic is
`seeds_affordable_in(budget) = budget / measured_ms_per_seed()` (`:326`, 381).

**Read those two functions' comment blocks before anything else.** They state the method and forbid the
lazy fix: the ceiling is set **from the slow (cold) end**, with the headroom ratio the previous pair had
(50000 × 1.58 ≈ 80000), and *"re-measure and move `measured_ms_per_seed()` with it rather than raising the
ceiling alone"* — because the seed minimums are arithmetic over that constant.

## What is already established (do not redo, but do check my method if you doubt it)

Measured by the orchestrator, **cold, fresh never-run clone, `make CI=1 sync_packages` first**:

| commit | cold `corpus_pr` |
|---|---|
| `2f3ee4d1` (before 031 line R) | **96 s** |
| `42dc0c18` (line R, PR head) | **87 s** |
| CI at `42dc0c18` | 106 s |

So the gate was **already failing cold before line R**, and line R made the target ~9 s faster. The one CI
pass (`2f3ee4d1`, exactly 80000 against 80000) was a warm/lucky run on the line.

**Measurement trap, which cost me two wrong numbers.** A `git clone` keeps the tracked `ailang.lock`, whose
path dependencies are **absolute paths into the primary checkout** — such a clone compiles the *primary's*
packages and measures nothing (my first attempt: 103 s of the wrong tree). Always: fresh clone → `make CI=1
sync_packages` → then the target. A second run in the same clone is **warm** and is not this gate's number
(warm is ~26-32 s; the file's own note says 47-50 s cold vs 24 s warm).

## What you do

1. **Measure.** At PR head (`42dc0c18` or later `main_dst`-merged head, say which), **at least 5 cold
   samples**, each a fresh clone + `sync_packages`, recording every sample, the median and the slow end. Do
   the same for **`scheduled_target_ceiling_ms()`**'s target (`make corpus_rotating`) if your numbers suggest
   it is near its 120000 ceiling — say either way.
2. **Decide the constants, showing the arithmetic.**
   - `pr_target_ceiling_ms()` from the **slow end** with the file's ratio (~1.58), stated as a calculation.
   - `measured_ms_per_seed()` re-measured, not inferred: time the seed-building phase, or derive it from two
     runs with different seed counts, and say which you did.
   - **Then check the knock-on**: `seeds_affordable_in(pr budget)` must still be ≥ the declared minimum (12 at
     a 5000 ms budget with 381 ms/seed → 13). If your new per-seed cost drops it below, the file's note says
     raise the budget or lower the minimum **and say so**, rather than choosing a per-seed number that keeps
     the arithmetic comfortable.
   - If the honest conclusion is that CI is simply slower than any local slow end, say that and set the
     ceiling from the **CI** number (106 s) with the same ratio — CI is the environment the gate guards.
3. **Rewrite both comment blocks** the way they are written now: what you measured, on what, why the number
   moved, and what it costs. A future reader must be able to redo your measurement from the text.

## Exit checks

1. `make corpus_pr` green locally, **cold in a fresh clone**, and the measured value printed with margin.
2. `make corpus_rotating` green (it shares the constants).
3. `make dst DST_JOBS=1` — run **alone**, nothing else heavy — 0 NEW reds.
4. **mutgate** from a fresh clone, spec under `evidence/D11-CEIL/`: revert the ceiling → `corpus_pr` red;
   revert `measured_ms_per_seed()` → whichever check the seed arithmetic feeds → red. Known trap:
   `cmd | grep -q X` under `set -o pipefail` scores baseline red (exit 141).

## Last act

Commit `013 D11: re-measure the PR corpus cost; ceiling and per-seed constant moved together`, then print
`RESULT D11-CEIL` (head, commit, every sample, the two new constants with their arithmetic, the knock-on
check, the three target results, mutgate). Scope: `src/core/dst_corpus.ail` and `evidence/D11-CEIL/` — if a
declared minimum or budget must move, that is in the same file; nothing else. Stage only your own paths;
never `git stash`; do not touch pane `w3:p1`, tab `w3:t1`, pane `w3:pZ` or `/workspaces/motoko_agent-eval`.
