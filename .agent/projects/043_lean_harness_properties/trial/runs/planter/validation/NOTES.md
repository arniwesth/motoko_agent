# Planter notes — choices made without asking

Seed-free on purpose: nothing below names a seed's location, change or witness. Those are in
`../manifest.tsv` and in `validation/<id>/`.

## What was read

- PLAN-001 §3, §4, §6, §7, Appendix C, A1 and A2 in that order, as briefed. I also read the rest
  of the plan, including **A3**, because it is part of the same frozen document and adds known
  defects K8-K10 to §4. No seed is placed so that its witness depends on K1-K10.
- The target functions in this worktree, their tests, and 039's operator list
  (`.agent/projects/039_systematic_mutation_testing/RESEARCH-…md` §4: statement removal,
  comparison and boolean flips, match-arm swaps, off-by-one, literal swaps). Every seed is one of
  those, or a unit confusion, as §6 rule 1 asks.

## How many seeds, and why not sixteen

**14 seeds: S1 3, S2 4, S3 3, S4 2, E 2.** One S2 and one S3 short of §6's table.
`s2_valid=4`, so §10 (a)'s `n2 >= 4` still holds.

The constraint that bound it, stated without naming sites:

- At most one seed per function, and the six targets have few functions. Two targets' functions
  can only carry slips whose witnesses are small lists (no new numeric constant, and nothing in
  them counts), so they can hold S1 and E seeds but no S2 or S3 seed.
- A seed whose witness does not show on the all-seeds tree `T` can never be detected (§8 detects
  a seed by `T` against `T−s`). Several candidate pairs masked each other on `T` (one seed
  bypassing, or reproducing, the other's defect). I kept only sets in which every S1-S3 seed's
  witness violates its property on `T` and holds on `T−s`, and checked that for every seed.
- Candidates that an existing gate catches were dropped (§6 rule 2): one by running the gates,
  two more by reading the tests that would have caught them.
- Two further candidates would have reached sixteen, but neither is a slip in 039's vocabulary
  (each adds a fallback path rather than mutating an operator, a comparison, a case or a value).
  I judged a realism breach worse than a short count, and left them out.

## Gates (§6 rule 2)

- Logs: `gates-base/` (unseeded), `gates-allseeds/` (all seeds, before the lock refresh below
  was added) and `gates-final/` (the final `seeds.patch`). `gates-comparison.txt` compares exit
  codes and every verdict line, timings stripped: the final run is the same as the unseeded one.
- **They run in the planter's git worktree, not in a copy.** `make check_core` ends with
  `verify_single_construction`, which lists files with git; in a tree without `.git` it stops
  with "not a git repository" before the type-check loop. The seeds were applied with
  `patch -p1`, the gates run, and the patch reversed; `git status` was clean before and after
  (apart from the `src/tui/node_modules` link the brief asks for). Nothing was committed.
- Same on both trees, and not caused by the seeds: `bun run test` exits 1 with the same 4
  suites failing to load (`depd`'s `callSite.getFileName` under bun) and all 472 tests passing;
  `ailang test` exits 1 with "No tests found" on the two edited modules that have no tests.
- The diffs left in `gates-comparison.txt` are timings, test-file order, and ailang's
  lock-hash warning (next item).

## The lock warning — blinding hygiene, not a seed

ailang prints `Warning: dependency <package> content changed` when a package's files no longer
match `ailang.lock`'s `content_hash`, and names only the first such package. On the unseeded tree
it names a package no seed touches. Editing a package's files would change which package it
names, which points an arm at the edit. So `seeds.patch` also refreshes `ailang.lock`'s
`content_hash` for each package whose files a seed changes (values computed with `ailang lock` on
the seeded tree; nothing else in the lock changes). On `T` the warning reads exactly as on the
unseeded tree. The per-seed patches do not carry the lock hunk, so a tree with one seed reversed
(`T−s`) may name another package in that warning; exit codes are unaffected.

## Validation method

- Trees: `B0` = the unseeded tree; `only-s` = B0 plus one seed; `T` = B0 plus `seeds.patch`;
  `T−s` = T with one seed's patch reversed (§8). Hardlinked copies under `work/trees/`.
- Every S1-S3 witness was run on all four. The manifest's witness is a property violation on
  `only-s` and `T`, and none on `B0` and `T−s`.
- S2 exhaustive searches use Appendix C's alphabets with only that seed applied. For the string
  target that is every string of at most 8 bytes over the six symbols (137,955 strings) times
  the five exit codes, on both sides. For the journal target it is Appendix C's 16,105
  appended-message histories through the real TypeScript writer and the real AILANG twin, each
  folded by `fold_journal`. Appendix C's journal alphabet has no checkpoint, resume or hybrid
  records, so it cannot exercise every path; a second, richer record alphabet (every emittable
  sequence of up to 5 records over seven record-producing actions, 1,677 sequences) was also
  searched and is reported beside it: 1,677 sequences of 1 to 5 records, 940 of them
  sequences a run can emit.
- E seeds: the target's registered properties give the same verdict on every input of the
  Appendix C alphabet with and without the seed, and the functions' outputs are identical too.
- Two target functions are module-private in AILANG. Their checks run on a copy of the tree with
  one exported wrapper appended to the module (shown in the log); the function under test is not
  touched, and the wrapper is not in the trial tree.
- AILANG harness files are copied into a `zz_planter/` directory of the validation copies only.
  The trial tree is built from git by `build_tree.sh` and has none of them.
- Sizes: strings in bytes; journal witnesses in wire records, the session's first seed counted
  as one record (Appendix C's prologue and epilogue add records that change nothing).

## Pre-existing findings met during validation (not seeds, reported for the adjudicator)

- In the richer journal alphabet, 4 unseeded sequences of 5 records show host and twin folding
  differently. All 4 resume a journal that the fold already refuses, which D6 refuses before any
  seed, so no run emits them; they are marked `ne` in the logs and excluded.
- K2 is visible in the clipping witness log on the unseeded tree, as §4 says.

## Reproducing

`harness/` holds every script the logs came from (`work/` layout: `base/` = the unseeded tree,
`trees/` = the validation trees). `patch-shape.log` checks §6 rule 1 (changed lines, no new
numeral) and that each per-seed patch applies to the base tree and reverses out of `T`.

## Blinding: what the operator has already seen

The session's interim status replies (one-liners sent while work was running) stayed clear of
locations, diffs and witnesses, but some of them said, in general terms, which targets carry
seeds, the class of some seeds, and the witness size of two. The operator's view of this session
is therefore partly unblinded. It matters for the operator's own calls under §8 (reachability,
same defect), not for the arms, whose deny rules cover this session's transcript.
