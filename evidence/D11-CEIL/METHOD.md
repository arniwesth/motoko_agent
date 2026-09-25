# D11-CEIL — how the two constants were re-measured

This is the text a future reader redoes the measurement from. It records the
method and the traps, not the numbers; the numbers are in `RESULT.md` beside it
and in the two comment blocks in `src/core/dst_corpus.ail`, which are the
authority.

## What is being measured, and why they are two different quantities

* `pr_target_ceiling_ms()` guards the WHOLE `make corpus_pr` target's wall
  clock: fifteen driver seeds plus the constructed member, every member
  persisted and loaded back, the mutation rows, the wire checks the Makefile
  greps out of the run's own output, and — on a cold tree — the AILANG
  compilation of the entire module graph the target imports.
* `measured_ms_per_seed()` is the marginal cost of ONE seed built through the
  real driver: generated, programmed, encoded, persisted and loaded back. The
  job minimums are arithmetic over it (`seeds_affordable_in`), so it is a cost
  per seed and not a share of the target.

A number measured for one is not a number for the other, and the second is a
small fraction of the first. That is the whole reason the file insists both are
re-measured rather than one being inferred from the other.

## The measurement trap that produces wrong numbers

`ailang.lock` is TRACKED, and its path dependencies are ABSOLUTE paths into the
checkout the lock was generated in. A plain `git clone` therefore carries a lock
pointing at the PRIMARY checkout: the clone compiles and runs the primary's
packages and measures nothing about the tree you think you are measuring.

Every sample must be:

    fresh clone  ->  make CI=1 sync_packages  ->  the target

`sync_packages` re-runs `./scripts/sync-extension-packages.sh` and `ailang lock`,
which re-points the lock at the clone. Assert it: `grep -q "$CLONE" ailang.lock`.

A SECOND run in the same clone is WARM — the `.ailang` compile cache is
populated — and is not this gate's number. Cold and warm differ by more than a
factor of two, which is larger than every other effect measured here.

## The trap that is NOT in the file, and cost this measurement a batch

`make corpus_pr`'s pass condition is WALL CLOCK, so it measures the machine's
load as much as the target — the Makefile says so at `DST_TIMED_TARGETS`. This
container runs other agents in the primary checkout, and their AILANG work
overlaps a sample and inflates it.

A contention detector that filters on the COMMAND LINE does not work: the target
runs `ailang run ... scripts/dst/corpus_pr_dst.ail` with a RELATIVE script path,
so a filter on the clone's path matches nothing and counts the sample's own
work as contention. Identify a foreign process by its WORKING DIRECTORY
(`/proc/<pid>/cwd`) instead, and record the peak count alongside every sample so
a contaminated sample can be discarded rather than averaged in.

`scripts/` in this directory holds the harness that does all of the above.

## The per-seed harness

`per_seed_bench.ail` builds N seeds through the same path `corpus_pr_dst.ail`'s
`build_seed` takes, with the driver plumbing copied verbatim rather than
reimplemented — a per-seed cost measured under a different profile, generator
version or bounds is a cost for a different seed. It asserts nothing; it exists
to be timed from the shell, and prints the seed count and a loaded-byte total so
a run that did no work cannot be mistaken for a fast one.

    MOTOKO_BENCH_SEEDS=N ailang run \
      --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
      --ai-stub --entry main evidence/D11-CEIL/per_seed_bench.ail

Run it at two counts in the SAME clone, after one priming run, so the module
graph is already compiled:

* the SLOPE, `(t(N2) - t(N1)) / (N2 - N1)`, is the marginal cost of a seed and
  cancels process start and compilation. This is the quantity
  `seeds_affordable_in(budget)` actually asks for.
* the AVERAGE, `t(100) / 100`, is the file's own method for the 381 it replaces
  ("100 seeds ... in 38.2 s of wall clock, one process start included") and is
  reported so the old and new constants are comparable.

Both are recorded in `RESULT.md`; the comment block says which one the constant
is set from.

## Where "cold" actually comes from

Not from the tree. The AILANG compile cache is GLOBAL — `~/.ailang/cache` — and
keyed so that a checkout at a NEW PATH misses it. That is the entire reason a
fresh clone is cold, and it has three consequences worth knowing before
re-measuring anything here:

* `rm -rf .ailang` inside the tree does NOT produce a cold run. The tree's own
  `.ailang` is ~112K of corpus store; the compiled modules are not in it. A
  measurement that relies on deleting it is measuring a warm run (~31 s) and
  will conclude the ceiling has enormous headroom.
* A fresh clone is cold ONCE. The first run populates the global cache for that
  path, so every later run in the same clone is warm. This is the same fact the
  file states as "a second run in the same clone is warm", but the mechanism
  matters: it is the path, not the directory contents.
* To force a cold run WITHOUT a new clone, point `AILANG_CACHE_DIR` at an empty
  directory — the mechanism the Makefile already uses for its per-target lanes.
  Verified: same clone, same code, 31 s on the shared cache and 87 s against an
  empty `AILANG_CACHE_DIR`. Remove the directory afterwards; a cold run leaves
  about 154 MB in it.

Do NOT clear `~/.ailang/cache` to get a cold run. It is shared with every other
agent working in the container, and emptying it makes their next compile pay for
this measurement.

## The scripts, as they were actually run

`scripts/` holds the harness verbatim, absolute scratchpad paths and all, rather
than a tidied-up version that was never executed:

* `cold_sample.sh` — one cold sample: clone, `sync_packages`, lock assertion,
  contention watcher, target, cleanup. `CONSTPATCH=<file>` copies a
  `dst_corpus.ail` into the clone before syncing, which is how the patched
  constants were measured.
* `cold_batch.sh` — N sequential samples.
* `coldwarm_and_bench.sh` — the cold/warm split in one clone and the per-seed
  bench at two counts.
* `dst_run.sh` — `make dst DST_JOBS=1` in a fresh clone, optionally with a
  patched `dst_corpus.ail`; used for both the baseline and the after run.
* `mutgate_run.sh` — pre-clones and SYNCS, then calls `mutgate.sh --repo`.
  Deliberately not `mutgate.sh --clone-from`, which does a plain `git clone`
  and would hand every row the primary checkout's packages.
