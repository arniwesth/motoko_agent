# LEG-CI-COVERAGE-CAP — `test_coverage` is flaky at the 300 s per-file cap on `session.ail`

You are a delegate of the 031 orchestrator (pane `w3:p5X`). This is a CI defect outside 031's line R, which
is complete. You do not edit the ADR or PLAN-001, you do not write the dagr run file, and you do not touch
other panes or worktrees.

## The failure

`make test_coverage` reports `src/core/session.ail` as **`[unrunnable]`** — *"`ailang test` did not finish
within 300s"* — and the gate goes red. The cap is `tools/test_coverage/derive.py:755` (`--timeout`,
default 300); the message is emitted at `:247` and classified `unrunnable` at `:297`.

**It is FLAKY, not deterministic, and that is the finding that matters.** Same tree, same cap, two CI runs
one hour apart, nothing in between touching `test_coverage`, `session.ail` or the cap (I checked the whole
diff):

| run | step duration | result |
|---|---|---|
| `36010382877` | **7 m 48 s** | RED — session.ail over 300 s |
| `36018131861` | **5 m 18 s** | GREEN |

A 2.5-minute swing on an unchanged tree. So the gate passes or fails on which runner you draw. **Do not
"fix" this by re-running it, and do not fix it by raising the cap until you know why the file is near it.**
A gate that passes half the time will eventually wave through a real regression in `session.ail`, which is
exactly what the cap exists to catch.

## Hypothesis I would test first — not verified, yours to confirm or kill

**Job contention, not file slowness.** `TEST_COVERAGE_JOBS ?= 6` (`Makefile:3354`) runs six `ailang test`
processes in parallel. **This dev box has 8 cores; a standard GitHub `ubuntu-latest` runner has 2.** Six
CPU-hungry processes on two cores stretch the slowest file's wall clock several-fold, and the per-file
timeout is measured in wall clock (`:244`). That predicts exactly what we see: fine locally, marginal in CI,
and swinging with whatever else the runner is doing.

If that is the cause, the honest fix is to make the job count fit the machine (`nproc`-derived, or pinned
lower in CI) rather than to raise a timeout that is doing its job. **Measure before you choose**: get
`session.ail`'s own wall time at `--jobs 1` and at `--jobs 6` on a 2-core machine, and say which of
contention or genuine file cost dominates. If `session.ail` really does need ~300 s of CPU on its own, that
is a different finding and worth saying plainly — the answer then is to make the file cheaper or to split
it, not to widen the cap.

Note there is a second parallelism knob to keep consistent: `Makefile:645` warns this target owns its lane
and "must not also be pinned to one outer lane". Read that comment before changing anything.

## Constraints

- **Heavy runs one at a time.** `make dst` and anything on real segments; the memory guard's `flock` is the
  rule. Do not start a second heavy run beside one already going.
- **Never run `git stash`** — other sessions have uncommitted work in this tree.
- **No session content, credentials or host addresses** in a brief, a record, a fixture or a commit. This
  repo is **public**.
- You may push to `arniwesth/031-abi-8-0` and dispatch CI. Use `gh api`, not the `gh pr`/`gh issue`
  porcelain: the token lacks `read:org`, which those subcommands demand for unrelated metadata.
- A flaky gate is proven fixed only by **repeated** CI runs. One green run proves nothing here — one green
  run is what the broken state already produces half the time.

## Done means

1. The cause is **named and measured**, not guessed: contention, genuine file cost, or something else.
2. A fix that makes the gate **deterministic** on a 2-core runner, with the reasoning in the recipe or the
   tool where the next reader will find it.
3. **At least three consecutive green CI runs** of `test_coverage` on an unchanged tree, with the step
   durations quoted — enough spread to show the margin, not one lucky draw. Say what the worst-case margin
   is (duration against cap), because that number is the whole point.
4. A `mutgate`-style check if one is meaningful: make the cap fail on a deliberately slow file and pass on
   restore, proving the gate still catches what it exists to catch. If a mutation gate is not meaningful
   here, say so and why rather than inventing a vacuous one.

Report a typed envelope: the cause with its measurements, the fix, the CI run ids, the worst-case margin,
and anything you touched beyond the above.
