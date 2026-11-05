# T5: `path_up` and `find_entry`, executed checks (arm A, replicate 1)

Target: `path_up` (`src/core/journal.ail:1403`) and `find_entry` (`:1392`), against their comment
and ADR-003 D4 rule 1 ("From `leaf` to the root by `parent_id`, stopping at the first repeated
id; reversed. The first entry must be the `header`").

## Findings

| Report | Property | What |
|---|---|---|
| A1-T5-1 | P5.3 | On a parent cycle `path_up` returns `[]` instead of the path up to the first repeated id (`journal.ail:1405`, `then []` where the twin has `then acc`). Looks planted: the twin's SOURCE pin hashes to the body with `then acc`. Through the unmodified `fold_journal`, a cycle through the header makes resume refuse with `header`, while the eval reader's `eval_fold_journal` accepts the same lines |
| A1-T5-2 | P5.3 | Start id `""` that names an entry (id `""`) gives `[]`: the root-sentinel test runs before the lookup. Present in the twin too, so it was there before this snapshot. Low severity; needs a hand-edited journal |
| A1-T5-3 | X-5 | Time is quadratic in path length: a 4× longer path costs 12-20× the time, and `fold_journal` on writer journals took 0.85 s / 2.4 s / 8.2 s / 38 s at 254 / 504 / 1,004 / 2,004 lines on this (shared) machine. Real journal sizes not shown |

P5.1 (termination) and P5.2 (no repeated id) held on every input tried, and so did P5.3's chain
clause. `find_entry` returned the first entry with the id in every case (X-2), including
duplicate-id lists.

## Method: how the real functions are called

`path_up`, `find_entry` and their twins are module-private. AILANG v0.54.14 accepts a private
name in an import list, but the name is then undefined at the call site ("undefined variable:
path_up", reproduced by `probe_private.ail`). So:

- `gen_exports.sh` copies `src/core/journal.ail` and `src/eval/journal/reader.ail` byte for byte
  into `out/gen/`. It changes exactly three lines in each: the `module` line, and `export` added
  to `path_up`/`find_entry` (or `ev_path_up`/`ev_find_entry`). It exits 2 if the diff is
  anything else. Every harness regenerates the copies first, so they always match the tree.
- `out/ailang.toml` + `ailang.lock` are a manifest whose only dependency is
  `../tree/packages/motoko-ext-abi`. `out/src` is a symlink to `../tree/src`. Harnesses run with
  `out/` as the working directory, so `import src/core/...` loads the tree's own files.
- `fold_cycle.ail` (and `perf_path.ail`'s `fold`) import the **unmodified**
  `src/core/journal` and `src/eval/journal/reader`, with no copy.
- Nothing in the tree was modified, and no Lean or other model of the functions was written. The
  TypeScript checker states properties over the outputs and never computes a path.

## What was checked, with which generators, up to what size

Properties as executed (in `path_props.ail` and, independently, in `check_cases.ts`), on
`r = path_up(es, start, [], [])`:

- **P5.1**: every call returns (each harness run completes with one result per case; the random
  runner is checked for a full result count). For long paths: `depth_check.sh`.
- **P5.2**: no id twice in `r`.
- **P5.3c**: each entry's `parent_id` is the id of the entry before it.
- **P5.3l**: if some entry of `es` has id `start`, `r` is non-empty and ends with that id.
- **X-1 (maximal)**: `r = []` only if `start` is `""` or names no entry. Otherwise `r`'s first
  entry's `parent_id` is `""`, names no entry, or is an id already in `r`: D4 rule 1's three
  stopping points.
- **X-2 (first match)**: every entry of `r` is the first entry of `es` with its id.
- **X-3 (twin)**: `ev_path_up` (reader.ail) returns the same entries, by position.
- **X-4 (strict reader)**: where `strict_path` (reader.ail, exported) returns `Ok(p)`, `p` is
  the same entries.
- **X-5 (cost)**: walking a path 4× longer should cost about 4× the time, not ≥8×.

| Harness | Generator | Size | Result |
|---|---|---|---|
| `path_props.ail` `main` | Exhaustive: entries from id ∈ {a,b,c} × parent ∈ {"",a,b,c,z(missing)}, `seq` = position, `kind` = header iff parent is "". Every list of length 0..4, every start ∈ {a,b,c,"",z} | 271,205 (list, start) cases, 353 s (`runs/path_props_len4.txt`) | P5.1, P5.2, P5.3c, X-2, X-4 hold. P5.3l and X-1 fail on 44,970 cases, and X-3 disagrees on exactly the same 44,970 (all parent cycles) |
| `path_props.ail` `run {maxlen:3, empty:true}` | Same, with id `""` added to the id alphabet | 42,105 cases (`runs/path_props_len3_empty_true.txt`) | Additionally 4,805 P5.3l failures with start `""` (A1-T5-2), and 1,273 X-4 disagreements, all with start `""`. With start ≠ `""`, X-4 has 0 disagreements |
| `run_random.sh 7 2100` = `gen_cases.ts` → `run_cases.ail` → `check_cases.ts` | Seeded random (mulberry32), seven generators round-robin: `graph` (0-12 entries, ids from a pool of 1-5, so ids repeat), `weird` (ids `""`, `" "`, `","`, `"\""`, `"null"`, `"ü"`, `"0001"`), `chain` (the host writer's shape, 1-60 entries, from the leaf), `rootcycle` (header's parent = leaf), `backedge` (one parent pointing to a later id), `selfloop`, `dupid` (1-3 extra entries reusing existing ids, start = last line's id) | 2,100 cases, up to 60 entries, 60 s (`runs/random_s7_n2100.txt`) | P5.1, P5.2, P5.3c, X-2 hold on all. P5.3l: 1,000 failures (960 cycles + 40 start `""`). X-1/X-3: 960, all from cycle generators. X-4: 18, all start `""`. `chain` and `dupid`: 0 failures |
| `run_random.sh 11 4200` | Same seven generators, another seed | 4,200 cases, up to 60 entries, 49 s (`runs/random_s11_n4200.txt`) | Same picture: P5.1, P5.2, P5.3c, X-2 hold on all. P5.3l: 1,986 (1,921 cycles + 65 start `""`). X-1/X-3: 1,921. X-4: 29, all start `""`. `chain` and `dupid`: 0 failures |
| `fold_cycle.ail` (unmodified code) | `journal_lines_of_records` journals with 0-3 appended messages (6-9 lines), then the header's `parent_id` `""` → leaf id | 4 journals × 2 shapes × 2 folds | `fold_journal`: linear accepts, rootcycle refuses `header`. `eval_fold_journal`: accepts both with the same history length |
| `perf_path.ail` | Linear writer-shaped chain, walked from the leaf; `fold` builds a writer journal of n messages | `path_up` n = 300 … 4,000; `fold_journal` 254 … 2,004 lines (`runs/perf.txt`, `runs/perf_fold.txt`) | Quadratic. `path_up`: 4× the path costs 12.5×, 13.9×, 20.2× the time over three runs; n=4,000 took 62-124 s. `fold_journal`: 0.85, 2.4, 8.2, 38 s at 254, 504, 1,004, 2,004 lines. The machine was shared (load ~15 on 8 cores), so absolute times vary about 2×; the ratios are the claim |
| `depth_check.sh` | 300-entry chain under `--max-recursion-depth 20`, with a non-tail control | 1 | `path_up` completes (constant stack); the control dies with RT_REC_003 |
| `negative_control.sh` | Mutants of the generated copy only: M1 = `then acc` (the pinned body), M2 = M1 + look up `""` | Repros + `path_props` length ≤ 3 (`runs/negative_control.txt`) | Unmodified: all three repros and `path_props` exit 1. M1: body hash = the twin's pin `db222e4c…`; `repro/cycle.ail`, `fold_cycle.ail` (with `fold_journal` from the M1 copy) and `path_props` exit 0 (18,080 cases, all properties hold, twin agrees); `repro/empty_id.ail` still 1. M2: `repro/empty_id.ail` exits 0 |

## Evidence that A1-T5-1 is a change, not the design

`reader.ail:1225` pins `ev_path_up` to `src/core/journal.ail L1405-1412 … sha256:db222e4c…`.
Undoing the reader's documented renaming (`ev_` prefixes, `Ev` types) gives a body whose sha256 is
`db222e4c…` exactly, and that body has `then acc`. The core body differs from it only on that one
line. `find_entry` (`404f6f11…`) and `contains_string` (`8b56ed48…`) still match their pins.
`negative_control.sh` applies that one line to the generated copy and recomputes the hash on every run.

## Not shown

- **Reachability.** For A1-T5-1 and A1-T5-2, reachability was only read, not executed. The
  TypeScript host writer (`session-journal.ts` `append`, `adopt`, header completion) always writes
  `parent_id` = the previous leaf and zero-padded ids. So a cycle or an empty id needs a
  hand-edited or foreign journal, or a future branch/rewind operation (ADR-003 D8). Duplicate ids
  after two crashes look possible in the writer (`adopt` stops at a torn line and reuses its
  seq), but by reading, `parse_journal_text` refuses a torn line that is not the last one, so
  such a journal is refused before the walk. Duplicates without cycles satisfied every property
  here anyway.
- **A1-T5-3.** No evidence that real journals reach thousands of entries; the repo's evidence
  journals have 10-23 lines. The repro is timing-based and its exit-0 side (a linear-time walk)
  is untested.
- `fold_journal` was run only on writer-twin journals; the TypeScript writer's own output was
  not.
- `tools/eval_protected/protected.py` (the repo's pin-drift reporter) shells out to `git`, so it
  was not run. The pin hash is recomputed by `negative_control.sh` instead.

## Files

| File | What |
|---|---|
| `reports.tsv` | The three reports |
| `gen_exports.sh` | Regenerates `gen/journal_t5.ail`, `gen/reader_t5.ail` (export-only copies; checks the diff) |
| `path_props.ail` | Exhaustive enumerator and AILANG-side property checks (`main`, `with_empty`, `run {maxlen, empty}`) |
| `gen_cases.ts`, `run_cases.ail`, `check_cases.ts`, `run_random.sh` | Random generator (bun), runner of the real functions (AILANG), property checker (bun), driver |
| `fold_cycle.ail` | Whole-fold consequence on unmodified `fold_journal` / `eval_fold_journal` |
| `perf_path.ail`, `depth_check.sh` | Cost (X-5) and constant-stack (P5.1) checks |
| `probe_private.ail` | Shows that a private import of `path_up` from the unmodified module is unusable ("undefined variable: path_up") |
| `probe_deep.ail` | The first timing probe (path_up / find_entry on long chains), superseded by `perf_path.ail` |
| `negative_control.sh` | Mutants on the generated copy; pin-hash recomputation |
| `repro/run.sh`, `repro/cycle.ail`, `repro/empty_id.ail` | Repros: `bash ../out/repro/run.sh <program> [caps]` from the tree root (also takes `fold_cycle.ail`, and `perf_path.ail IO,Clock`); exit 1 present, 0 absent, 2 did not run |
| `runs/` | Outputs of the runs quoted above |
| `ailang.toml`, `ailang.lock`, `src` → `../tree/src`, `gen/` | Harness infrastructure (see Method) |
