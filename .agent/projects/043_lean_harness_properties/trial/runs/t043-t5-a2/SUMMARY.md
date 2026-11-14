# T5, the fold's path: executed checks on `path_up` and `find_entry`

Arm A, replicate 2. Target: `find_entry` and `path_up` (`src/core/journal.ail:1392-1410`), against
their comment and ADR-003 D4 rule 1 ("From `leaf` to the root by `parent_id`, stopping at the first
repeated id; reversed"). Method: executed checks only, with no model of either function. AILANG
v0.54.14 and bun 1.4.4. The tree was neither edited nor run through `git`.

## Result

| Report | Property | What is wrong | Witness |
|---|---|---|---|
| `A2-T5-1` | P5.3 | On a parent cycle, `path_up` returns `[]`, not the path up to the first repeated id. The start entry is then missing from the result. | `[a<-a]` from `a` gives `[]`; `[a<-b, b<-a]` from `a` gives `[]` (the twin returns `[b, a]`) |
| `A2-T5-2` | X-2 | Effect of A2-T5-1 on the real, unmodified `fold_journal`: a journal whose header's `parent_id` points back into the leaf's chain is refused with `header`. Rule 1's path there starts at the header, and the eval twin folds the journal to the same state as the unmodified journal. | 7-entry writer-twin journal, `header.parent_id := leaf` |
| `A2-T5-3` | P5.3 | An entry whose id is `""` is never found: `if id == "" then acc` runs before the lookup. Shared with the twin. The reader's exported `strict_path` does find it (6,485 cases). | `[{id:"", parent_id:""}]` from `""` gives `[]` |
| `A2-T5-4` | X-3 | Efficiency: time grows quadratically with path length on host-shaped journals. | t(800)/t(200) ≈ 15-19, against 4-6 for a linear control |

**P5.1 (termination) and P5.2 (no repeated id) held on every input generated.** There are no
P5.1 or P5.2 reports.

A2-T5-1 is the likely planted change, because the eval twin's SOURCE pin dates it.
`src/eval/journal/reader.ail:1225` pins `path_up` as sha256 `db222e4c…`, which is the hash of the
current body (taken with the repo's own `tools/eval_protected/ailspan.py` span plus its newline)
**only when `then []` is changed back to `then acc`**. The pins of `find_entry`
(`404f6f11…`), `contains_string` (`8b56ed48…`) and `fold_journal` (`04d2c175…`) match the
current bytes exactly. So the core's cycle arm was edited after the twin was copied, and the two
now disagree on every input with a cycle on the path. A2-T5-3 and A2-T5-4 are shared with the
twin and predate the pin.

Reachability of A2-T5-1/2: the host writer (`session-journal.ts:368-384`) sets `parent_id` to the
previous leaf and assigns fresh zero-padded sequential ids, so it does not produce cycles. A cycle
requires a hand-edited, corrupt or foreign journal, or the branch/rewind operations D8 defers. The
observable effect is a wrong and misleading refusal, `[header] the first entry on the path is not a
header`, together with a core/eval disagreement on the same file. It is not a hang or a crash.

## How the real functions are reached

- **`out/` is a package root that points at the tree.** `out/ailang.toml`, `ailang.lock`, `src` and
  `packages` are symlinks to `../tree/…`, so `import src/core/journal` in a harness under `out/`
  loads the tree's own modules and nothing is written into the tree. Harnesses run from `out/`
  (`ailang run --relax-modules … harness/x.ail`).
- **Layer A: unmodified exported functions.** `fold_journal` (core, `path_up`'s only caller,
  `journal.ail:1684`) and `eval_fold_journal` (reader, which runs `ev_path_up`) are imported and
  called as they are: `harness/fold_cycle.ail` and `harness/fold_diff.ail`.
- **Layer B: the private functions themselves.** AILANG will not import a non-exported function,
  even under `--relax-modules` (`undefined variable: path_up`). `harness/expose.sh` therefore
  writes `out/gen/core_journal_exposed.ail` and `out/gen/eval_reader_exposed.ail` at every run,
  copied from the tree with two kinds of change: the `module` line, and `export ` in front of
  `path_up`, `find_entry` and `contains_string` (and the `ev_` twins). A diff guard exits 3 on any
  other difference, so the function bodies under test are the tree's bytes as they stand at run
  time, and a fix in the tree changes the next run's result. `path_direct.ail`, `path_scale.ail`
  and `path_timing.ail` import these copies. (`strict_path`, already exported, is imported from
  the same reader copy only so that its entry type matches `ev_path_up`'s; its body is unchanged.)

## The properties as executed (`harness/check.ts`)

`path_direct.ail` reads cases (`id<parent,…|start`; entry k gets `seq = k`). For each case it
prints the seq lists returned by the real `find_entry` (F), `path_up` (C), `ev_path_up` (T) and
the reader's exported `strict_path` (S, `!` when it refuses). `check.ts` judges them. It only
checks predicates over returned paths and never computes a path itself:

| Id | Executable statement |
|---|---|
| P5.1 | The run prints a line for every case plus `END`, within the caller's timeout (a non-terminating walk loses `END`). It also passes under a recursion cap of 50 (`depth_check.sh`). |
| P5.2 | The ids of `r` are pairwise distinct. |
| P5.3 | `es[r[i]].parent_id == es[r[i-1]].id` for i ≥ 1. If some entry has the start id, `r` is non-empty, its last entry has that id, and that entry is the one `find_entry` returns. |
| X-1 | Maximality, from D4's "stopping at the first repeated id": if `r` is non-empty, its first entry's `parent_id` is `""`, names no entry, or names an id already in `r`. |
| X-2 | Metamorphic, at the fold: pointing the header's `parent_id` at an id on the leaf's path leaves rule 1's path unchanged, so `fold_journal` must return what it returns for the unmodified journal. |
| X-3 | Efficiency: t(4N)/t(N) for `path_up` on a host-shaped chain stays below 10 (linear ≈ 4, quadratic ≈ 16). |
| TWIN | C == T. |
| STRICT | Where `strict_path` accepts (header-rooted, acyclic, complete chain), C == S. |

Violations are counted per function, property and class (start `""` or not; cycle on the path or
not), and each count comes with its first, shortest witness.

## Generators and sizes

Every `path_direct` suite calls `find_entry`, `path_up` and `ev_path_up` on every case, and the
batch3 reruns also call `strict_path`. Counts are cases, i.e. (entry list, start) pairs. No C or T
violation of P5.1, P5.2, the P5.3 chain clause or X-1 appeared in any suite. Every violation counted
below is P5.3's "last entry has the start id" clause.

| Run | Generator | Size | C violations | T violations |
|---|---|---|---|---|
| `e1_4` | exhaustive: ids `a,b,c`; parents `"",a,b,c,z`(absent); starts the same | every list of length 0-4: 271,205 | P5.3: 44,970, every cyclic case | none |
| `e1_5` | the same, length 0-5 | every list of length 0-5: 4,068,080 (18 min) | P5.3: 778,095, every cyclic case | none |
| `e2_4` | exhaustive with the empty id: ids `"",a,b`; parents `"",a,b,z`; starts the same | length 0-4: 90,484 | P5.3: 12,370 cyclic + 17,940 empty-id | P5.3: 17,940 empty-id |
| `r1` | random: N ≤ 40 entries, id pool 1-12 (so duplicate ids), parents 15% `""`, 5% absent | 20,000 | P5.3: 7,863, every cyclic case | none |
| `r2` | random: N ≤ 60, pool 1-25 | 100,000 | P5.3: 28,712, every cyclic case | none |
| `s20` | structured: the host's chain (zero-padded ids, root first) of length 1-20, the same with one `parent_id` redirected to every later-or-equal entry (every cycle length and position) or to an absent id; every start | 30,105 | P5.3: 16,170, every cyclic case | none |
| `long_N` | one host chain of N entries, and the same with root.parent = leaf, from the leaf | N = 250, 500, 1000, 2000 | P5.3 on the cyclic one, each N | none |
| `deep_N` | N root entries; starts at the last id and at an absent id (`find_entry` scans all N) | N = 100,000 (and the first case of 1,000,000; that run was stopped by me at 12.5 GB RSS, see below) | none | none |
| batch3 (`e1_4s`, `e2_4s`, `r1s`, `s20s`) | the four above rerun with the S column | 411,794 | same as above, plus STRICT: `strict_path` accepted 65,226 cases and agreed with C on all of them except 6,485 empty-id cases in `e2_4s`, where it returns the `""` entry and C returns `[]` | — |

At the fold (Layer A):

- `fold_cycle.ail` runs 6 variants of a 7-entry journal written by `journal_lines_of_records`.
  The 3 header-closing cycles are BAD: core `header`, eval `accept:3`. The 2 controls with a cycle
  below the header are OK: both refuse with `header`.
- `fold_diff.ail` is exhaustive: every entry t × every new parent (7 ids, `""`, absent) × every
  leaf, 441 journals, folded by both folds. 28 differ, which is exactly the header-closing cycles
  whose leaf lies at or below the redirect target. 413 agree.

P5.1 against the recursion ceiling (`depth_check.sh`): AILANG refuses non-tail recursion deeper
than 10,000 (`RT_REC_003`). With the cap lowered to 50, the real `path_up` still completes a
500-entry path and a 500-entry cycle, and a deliberately non-tail control of depth 500 fails. So
`path_up`, `find_entry` and `contains_string` run in constant stack depth, and no path length
reaches the ceiling. The comment's "recursion depth is the PATH length" is therefore conservative,
not wrong.

Timing (X-3, `path_timing.ail`, in-process `std/clock`, best of 2-3):

| N, 4N | `path_up` t(N) → t(4N) | ratio | Linear control (`find_entry` absent-id scan ×N) |
|---|---|---|---|
| 200, 800 | 590 → 9,017 ms; 145 → 2,701; 237 → 4,469; 112 → 1,883 (`runs/timing.log`) | 15.3, 18.6, 18.9, 16.8 | 6.0, 3.9, 4.3 |
| 400, 800 (2×) | 669 → 2,905 ms; 1,314 → 4,932 | 4.3, 3.8 (≈4 for 2×) | 1.6 (2×) |

Wall clock for whole `path_direct` runs of one host chain (core, twin and find, plus parsing):
8 s at 250, 15 s at 500, 36 s at 1,000, 99 s at 2,000.

## Negative controls

`harness/negative_control.sh` builds `runs/control_tree*/` from copies of the two modules and
checks each repro both ways:

| Repro | Tree | Control 1: `then []` → `then acc` (hash equals the twin's pin) | Control 2: also look `""` up |
|---|---|---|---|
| r1 | 1 | 0 | — |
| r2 (fold built from the control core) | 1 | 0 | — |
| r3 | 1 | 1 (not this fix) | 0 |

All 7 outcomes were as required. Throughout, the twin column acts as a whole-suite control:
`ev_path_up` *is* control 1, and it has no P5.x or X-1 violation in any suite except the shared
empty-id case.

## Caveats and what was not shown

- **Timing (A2-T5-4)** was measured on a shared machine while other sessions' `ailang` processes
  ran. The threshold is a ratio, chosen between the measured linear control and `path_up`. The
  real journals in the tree have 10-23 entries, so this matters only for long sessions.
- **Reachability** of A2-T5-1/2/3 from the host writer was checked by reading, not executing: the
  host never writes a cycle or an empty id. These findings concern hand-edited, corrupt or foreign
  journals and the planned branch operations. Duplicate ids, which `find_entry` resolves to the
  first occurrence, violated nothing registered and are not reported.
- `deep_1000000` was stopped by me (rc 143, so its `check` line reads "P5.1 VIOLATION or harness
  failure"). Its first case, `find_entry` over 1,000,000 entries, had completed (`F:999999`). It
  is not a P5.1 failure.
- `e1_3` (18,080 cases) was an early smoke run of the same generator.
- P5.3 is read as constraining entries 2..n of the result. The first entry's `parent_id` is X-1's
  business.

## Files

- `reports.tsv`: the four reports. Each `repro` runs from the tree root, exits 1 while the defect
  is present, and finishes in under 120 s (r1-r3 in about 1-10 s, r4 in about 20 s).
- `repro/`: `r1_cycle_empty_path.sh`, `r2_fold_header_refusal.sh`, `r3_empty_start_id.sh`,
  `r4_quadratic_time.sh`, `_common.sh`.
- `harness/`: `expose.sh` (Layer B copies), `path_direct.ail`, `gen.ts`, `check.ts`,
  `run_direct.sh`, `fold_cycle.ail`, `fold_diff.ail`, `path_scale.ail`, `depth_check.sh`,
  `depth_probe.ail`, `path_timing.ail`, `negative_control.sh` (writes `fold_cycle_control.ail`),
  `run_all.sh` (the whole campaign).
- `runs/`: every run's `.check` summary and log; `fold_cycle.out`, `fold_diff.out`,
  `negative_control.log`, `depth_check.log` and `timing.log`; `control_tree*/`, the controls'
  module copies. Removed (all regenerable with `gen.ts`): case and result files over 20 MB (`e1_5`), `deep_1000000.cases`, and the `*s.cases` files of batch3, which were byte-identical to the unsuffixed runs' cases. To re-judge `e1_4s.out`, pair it with `e1_4.cases`.
- `gen/`: written by `expose.sh` at every run. `.ailang/cache/` is ailang's compile cache. With a
  warm cache r1-r3 take about 1 s; a cold first run adds 5-20 s of compilation.
