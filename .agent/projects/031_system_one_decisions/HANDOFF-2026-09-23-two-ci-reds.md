# HANDOFF 2026-09-23 — two CI reds on `arniwesth/031-abi-8-0`, neither caused by 031 line R

Written by the 031 orchestrator at `R-G`. Both were shown **pre-existing** and were handed out under the
operator's ruling of 2026-09-23; line R is not blocked on either. Evidence: PLAN-001 §9 "CI at `42dc0c18`",
and the runs themselves.

## 1. D11's PR corpus ceiling — for 013 / the corpus owner

`make corpus_pr` fails in CI: **"the PR corpus target took 106000 ms against a declared ceiling of 80000 ms"**
(run `35884636365`, job `pr-corpus`). The target's whole wall clock is compared against
`pr_target_ceiling_ms()` in `src/core/dst_corpus.ail` (`:394`, 80000), and the seed minimums are arithmetic
over `measured_ms_per_seed()` (`:326`, 381).

- At **`2f3ee4d1`** (before line R) the same gate measured **exactly 80000 against 80000** — it was passing
  with zero margin (run `35505033482`).
- **Locally, on identical hardware, the target got faster across the migration**: 30000 ms at SWEEP
  (`75fefdcb`) → **26000 ms** at line R's head (`d78a7c3e`), same 80000 ceiling.
- `src/core/dst_corpus.ail` is **untouched** by line R (`git log 2f3ee4d1..HEAD -- src/core/dst_corpus.ail`
  is empty).

So this is a CI-runner-speed gate with no headroom, not a regression. The gate's own failure text says what
to do: **re-measure on CI and move `measured_ms_per_seed()` with the ceiling** — raising the ceiling alone
makes the seed minimums arithmetic over a stale constant. Several CI samples are needed for a trustworthy
number.

## 2. The `verify-extensions` job timeout — CI policy, the operator's

The job `verify_extensions + check_core + smoke_no_delegated_storm` has `timeout-minutes: 20`
(`.github/workflows/verify-extensions.yml:46`) and is **timed out** in step "DST AILANG gates" (GitHub
reports a timed-out job as *cancelled*):

- `42dc0c18`: runs `35884988739` (dispatch) and `35884636239` (PR), both 25 min, same step.
- **`2f3ee4d1`, before line R: run `35505033481`, 25 min, same step** — identical.
- `main`'s scheduled runs finish the same job in **2.4 min**, which is why they pass.

What *did* run on `42dc0c18` before the timeout: **`check_core` passed in CI**, as did the extension
verification and `smoke_no_delegated_storm`. Options: raise the limit, split the DST gates into their own
job, or narrow what the branch runs. Locally the full `make dst DST_JOBS=1` sweep at `d78a7c3e` is green in
1048 s, so the work itself completes — the 20-minute box is the constraint.
