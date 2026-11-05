# W4: the adjudication

PLAN-001 §8, run by the adjudicator, t043-adjudicator, on 2026-11-05. Read with
`../sequence.log`, which records each step and each decision as it was made.

## What is here

| File | What |
|---|---|
| `AUDIT.md` | The blinding audit (§7) and a ruling on every breach, refused attempt and note |
| `audit/` | `audit.py` re-run on each transcript (`<s>.txt`, identical to W2's), the adjudicator's sweep (`<s>.w4.txt`), and every result line that names another session (`other-sessions.txt`) |
| `table.tsv` | One row per report: its outcome on T, B0 and each T−s, and its §8 class |
| `summary.tsv` | Per session and arm: seeds detected by class, false reports, errors, real-defect reports |
| `runs.tsv` | Every run: session, report, tree, kind of run, status, exit code, wall clock, peak memory |
| `CALLS.md` | The same-defect and reachability calls (§8): the adjudicator's drafts and the operator's decisions |
| `../scripts/adjudicate.sh` | §8's procedure. Its header says how a reproduction is run |
| `../scripts/audit_w4.py` | The sweep behind `audit/<s>.w4.txt` |

Not in git: the trees, the work directories and the 2,000-odd run logs are under
`/home/motoko/trial-043/adjudication/` (`trees/`, `work/`, `results/<session>/<report>/<tree>.<kind>.log`,
`results/runs.jsonl`). `RESULTS.sha256` lists the sha256 of every log, and the size of the whole.

## How it was run

`adjudicate.sh all`, in stages:

1. **check.** The 24 output directories hash to their W2 values. Checked before and after.
2. **build.** B0 and T come from `build_tree.sh`, T with the revealed `seeds.patch`. B0 hashes to
   W0's unseeded tree and T to W1's `seeded_tree_sha256`. Each T−s is T with `seeds/<s>.patch`
   reversed. It keeps T's `ailang.lock`, as the planter's T−s did: the per-seed patches carry
   no lock hunk, and a stale lock hash is only a warning. The hashes are in `trees/HASHES`.
3. **prepare.** Each session gets a work directory with a pristine copy of its output directory,
   in which `/home/motoko/trial-043/s/<session>` is rewritten to the work directory, in text
   files and symlink targets. Nothing else in any file changes.
4. **run.** Every report runs on T, B0 and T−s01 to T−s14. Before each run the tree and the
   output copy are restored, so no run sees another's writes. The environment holds only the
   arms' PATH, HOME, the locale, TERM and a private TMPDIR. A run gets 120 s and 6 GiB.
   - A run that timed out, or was stopped because the machine ran short of memory, is run once
     more alone, and that result counts.
   - Each result that would decide a detection is run a second time, together with T. So is B0,
     where it decides real against interaction.
5. **pairs.** For a report §8 calls seed interaction, it runs on T−{s,t} for every pair.
6. **table.** The table applies §8's rules.

## §8's rules, as applied

| Class | Outcome |
|---|---|
| detects s | 1 on T, and 0 on T−s, the same on both runs |
| real defect | 1 on T and 1 on B0, and no seed detected |
| seed interaction | 1 on T and 0 on B0, and no seed detected; then pairs |
| false report | 0 on T, or interaction that no pair explains |
| error | anything but 0 or 1 on T: another exit code, a timeout, a memory kill |

## The results

There were 2,753 runs, in four kinds:

- 2,224 first runs: 139 reports on 16 trees.
- 347 confirmations.
- 182 pair runs.

No run timed out and none was killed for memory. Every confirmation gave the same result as the
run it repeats.

| Class | Reports |
|---|---|
| detects a seed | 69, each detecting exactly one seed |
| real defect | 68 |
| unclassified | 2 |
| false report | 0 |
| error on T | 0 |
| seed interaction | 0 |

**The two unclassified reports** are t043-t6-a2's A2-T6-1 and A2-T6-2. Each exits 1 on T and 2
on B0 and on T−s14. The cause is in the session's driver: it calls `Str.length` and relies on
`store.ail` importing `std/string as Str`, an import only seed s14 adds. By §8 an error is not a
detection.

**No report detects an E seed.**

### Seeds detected, by replicate

A replicate is its six sessions, one per target. A seed counts once per replicate.

| Replicate | S1 (of 3) | S2 (of 4) | S3 (of 3) | S4 (of 2) | Missing |
|---|---|---|---|---|---|
| A1 | 3 | 4 | 3 | 2 | none |
| A2 | 3 | 4 | 2 | 2 | s14 (see above) |
| B1 | 3 | 4 | 3 | 2 | none |
| B2 | 3 | 4 | 3 | 2 | none |

`summary.tsv` has the same per session, with the false, error and real-defect counts.

### Real defects

The 68 real-defect reports form 29 defects: 12 on primary properties, 7 on secondary properties
and 10 exploratory. Which reports are the same defect, which defects are known (§4), and which
unknown ones are reachable are the operator's calls. They are in `CALLS.md`.
