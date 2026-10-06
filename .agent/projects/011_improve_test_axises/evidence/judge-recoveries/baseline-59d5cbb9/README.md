# Baseline at `59d5cbb9`: what is red before anything is built

Measured on 2026-10-06 for `../../../PLAN-judge-recoveries-on-real-runs.md` §1. Every work item of
that plan reads `make dst` and `make eval_matrix` as a difference against this.

## Is it still valid?

    git diff --stat 59d5cbb9 HEAD -- src scripts tools packages Makefile .github ailang.toml ailang.lock

| the diff shows | the sweep's failure set | the matrix |
|---|---|---|
| nothing | valid | valid |
| only the gate cluster's files: `scripts/dst/corpus_pr_dst.ail`, `scripts/dst/corpus_judge_dst.ail`, `Makefile`, `.github/workflows/dst-corpora.yml` | valid, with one more passing target, `corpus_judge` | valid, by reading: the matrix's suites compile `src/core` and the evaluator's own paths, and none of these four files |
| also the rules cluster's files: `src/core/dst_invariants.ail`, `scripts/dst/invariants_dst.ail`, `tools/verify_classify/contracts.register` | valid | **this is the reference**, the last tree without the two rules. A matrix run with them is compared against it, and must be identical |
| anything else | stale | stale |

When it is stale, measure again on a tree without the plan's commits: `run_baseline.sh` at the
commit before the first of them, or at the merge base.

## How it was run

A detached worktree at `59d5cbb9`, nothing edited, nothing untracked, on an empty compile cache.
`make dst` at the default `-j8`, then `make eval_matrix --logs`, one after the other, by
`run_baseline.sh`. AILANG v0.47.2 (`e939cba`), 8 cores. Another session was installing a Python
environment during the matrix half.

## Results

| run | result | wall |
|---|---|---|
| `make dst` | exit 2; 48 of 52 targets pass; red: `driver_plus_compose`, `driver_plus_no_ops`, `ext_hook_scope`, `ext_hook_scope_selftest` | 2,085 s |
| `corpus_pr`, alone, inside that sweep | passes; 82,000 ms against a ceiling of 180,000 | 82 s |
| `make eval_matrix` | fails; 621 rows: 419 credited, 129 equal, 29 failed, 33 missing, 11 inapplicable; 3 of 28 suites exit non-zero | 821 s |

The four red sweep targets have one cause: the registration-shape inventory cannot read
`packages/motoko-ext-test-dummy/register.ail`. `dst-summary.txt` has each target's own lines.

## Files

| file | what |
|---|---|
| `dst-summary.txt` | the sweep's closing summary, make's error lines, each red target's failing lines, and the corpus gate's sixteen rows and wire witness |
| `corpus_pr.wire.sha256` | line counts and SHA-256 of `corpus_pr`'s output with `duration_ms` masked, and the mask |
| `MATRIX.tsv`, `suites.json`, `join.tsv` | the matrix run's observations, suite exit codes and join statuses |
| `matrix.stdout.log` | the matrix run's own summary, with every missing and failed case id |
| `meta.txt`, `run_baseline.sh` | timings and the script |

The full sweep log (1.7 MB) and the per-suite matrix logs are not committed.

## Comparing a later run with it

    make eval_matrix EVAL_MATRIX_ARGS="--logs <dir>"
    cp src/eval/journal/testdata/MATRIX.tsv <dir>/
    ../compare_matrix.py . <dir>          # from this directory; exit 0 means no row differs

`MATRIX.tsv` under `src/eval/journal/testdata/` is generated and is not committed there. This
copy is evidence, outside the evaluator's paths.

For the sweep, compare the `FAILED` block of `make dst`'s closing summary with the four names
above. For `corpus_pr`, mask and hash `/tmp/corpus_pr.out` as `corpus_pr.wire.sha256` says.

## Two cross-checks against the spike

- `MATRIX.tsv`, `suites.json` and `join.tsv` are identical to the spike's unmutated run at
  `259265b5` (`compare_matrix.py`: 0 suites, 0 rows, 0 join statuses differ).
- `corpus_pr`'s output, masked, is identical line for line to the spike's comment-only control
  (`K0`): 1,871 lines, 1,609 of them JSON.

Both were compared with files in the spike's worktree, which are not in this repository.
