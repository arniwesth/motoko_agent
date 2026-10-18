# Baseline at `3ae506cc`: what is red before Phase 0

Measured on 2026-10-18 for `../../PLAN-001-effect-disclosure.md` W0.1. W0.7 runs the same two
targets at the pull request's head and compares them with this, row by row (standing rule 5).

## Is it still valid?

    git merge-base HEAD origin/main          # in W0's worktree

It is W0.7's "before" while that prints `3ae506cc`, the commit W0's branch was cut from. If the
branch is rebased onto a later `main`, measure again at the new base with `run_baseline.sh`.

## How it was run

W0's worktree, `/workspaces/motoko_agent-034-w0`, at `3ae506cc` before the branch's first commit:
nothing edited, nothing untracked, on an empty compile cache. `make dst` at the default `-j8`,
then `make eval_matrix --logs`, both under `env -u AILANG_FS_SANDBOX`, one after the other, by
`run_baseline.sh`. AILANG v0.52.5, 8 cores. No other heavy run was going when it started; a few
interactive Motoko and Claude sessions were open on the machine. `memory.current` was 3.6 GiB at
the start and at the end, and at most 7.3 GiB when sampled during `make dst`.

The worktree has tracked files only (no `ailang/`, no `.env`). Run W0.7's "after" the same way.

## Results

| run | result | wall |
|---|---|---|
| `make dst` | exit 0; all 54 targets pass; `dst-failed.txt` is empty | 1,193 s |
| `corpus_pr`, alone, inside that sweep | passes; 70,000 ms against a ceiling of 180,000 | |
| `make eval_matrix` | fails; 619 rows: 418 credited, 129 equal, 28 failed, 33 missing, 11 inapplicable; 2 of 28 suites exit non-zero | 350 s |

The two red suites are red at the base, and are not W0's to fix:

| suite | exit | its rows | first cause in its log |
|---|---|---|---|
| `tools/eval_protected/selftest.py` | 1 | the 33 missing, all `M7.*` | `eval_protected gen: parser cross-check FAILED`; each scratch copy fails to load with `package "sunholo/motoko_ext_abi" not found in ailang.lock` |
| `scripts/eval/test_candidate.py` | 1 | the 28 failed: 12 `M13.*`, 16 `M15.*` | 27 failed, 96 passed, 1 error; for example `Refused('ProtectedRegionTouched(changed:<imports:1>) src/core/session.ail ...')` |

## Reproduced

The script ran a second time at `3ae506cc`, in the same worktree right after the first, on the
warm compile cache the first left: `make dst` exit 0 in 402 s (`corpus_pr` 18,000 ms),
`make eval_matrix` exit 2 in 206 s. Its `MATRIX.tsv`, `suites.json`, `join.tsv`,
`dst-failed.txt` and `corpus_pr.wire.sha256` are byte-identical to the first run's, and
`compare_matrix.py` between the two prints `VERDICT: IDENTICAL` and exits 0. `matrix.stdout.log`
differs only in the logs path, `dst-summary.txt` only in the wall time and load. So at one commit
neither run has a noisy row: a row that differs in W0.7 differs because the tree did.

The committed files are the first run's.

## Against the last baseline, `59d5cbb9` (011)

`../../../011_improve_test_axises/evidence/judge-recoveries/baseline-59d5cbb9/`, measured 2026-10-06
on AILANG v0.47.2. These differences are between two commits, not noise:

- `make dst`: 4 red targets there (`driver_plus_compose`, `driver_plus_no_ops`,
  `ext_hook_scope`, `ext_hook_scope_selftest`), none here. 52 targets there, 54 here.
- `make eval_matrix` (`compare_matrix.py`, that directory against this one): the same 33
  missing case ids; of the 29 failed there, 28 fail here, and `M14.pure.K2.positions` went from
  failed to credited. 621 rows there, 619 here: the two `M11.*hybrid_extractions` rows are
  gone. `src/eval/journal/candidate_checks.ail` exited 1 there and exits 0 here. Eleven `M14.*`
  rows report a position one interaction earlier.

## Files

| file | what |
|---|---|
| `dst-failed.txt` | the names in the `FAILED` block of `make dst`'s closing summary, one per line; empty, because every target passed |
| `dst-summary.txt` | the sweep's closing summary, make's error lines (none), and the corpus gate's sixteen rows and wire witness |
| `corpus_pr.wire.sha256` | line counts and SHA-256 of `corpus_pr`'s output with `duration_ms` masked, and the mask |
| `MATRIX.tsv`, `suites.json`, `join.tsv` | the matrix run's observations, suite exit codes and join statuses |
| `matrix.stdout.log` | the matrix run's own summary: each suite's exit, the 33 missing case ids and the 7 failed ones it names (`join.tsv` has all 28) |
| `meta.txt` | timings, revision, toolchain, load and `memory.current` |
| `run_baseline.sh` | the script that wrote all of the above |
| `compare_matrix.py` | a copy of `../../../011_improve_test_axises/evidence/judge-recoveries/compare_matrix.py` |

The full sweep log (1.5 MB) and the per-suite matrix logs are not committed. To see one target's
own output at the base, run that target alone in a worktree at `3ae506cc`.

## W0.7: comparing the "after" with it

    REV=<head sha> WT=<worktree at it, no tracked change> OUT=<dir> ./run_baseline.sh

Without `WT`, the script adds a detached worktree at `/workspaces/motoko_agent-034-baseline-<REV>`.
    ./compare_matrix.py . <dir>                  # exit 0 means no matrix row differs
    diff dst-failed.txt <dir>/dst-failed.txt     # no output means the same targets are red
    diff <(tail -n +2 corpus_pr.wire.sha256) <(tail -n +2 <dir>/corpus_pr.wire.sha256)

Run from this directory. The script writes `src/eval/journal/testdata/MATRIX.tsv` into the
worktree as an untracked file; it is generated, and is not committed there.

`compare_matrix.py` does not compare the `commit` column. The corpus hash covers `corpus_pr`'s
output only: W0.7 expects `world_state` and `test_coverage` to gain rows, and both pass here, so
their gains show in the "after" run's own log and not in `dst-failed.txt`. Any other difference
is a finding, recorded in this directory with its cause.
