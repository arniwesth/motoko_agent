# T2, the herdr failure vocabulary: executed differential check (arm A, replicate 1)

**Result.** P2.1 fails on the real code in eight distinct ways, and two of them are single lines in
the TypeScript twin:

- `herdrMeansAgentGone` uses `endsWith("_not_found")` instead of `== "agent_not_found"`.
- `herdrFailureCode` uses `r.code <= 0` instead of `== 0`.

These two lines account for 16,215 of the 25,967 P2.1 disagreements in run 1 (measured by run 3, against a patched copy). Both also break a
stated property outside the twin pair, shown on production code paths:

- **A1-T2-2.** The real waiter replies `lost` for a `pane_not_found` failure, although its header
  says such a failure is `host_error` and never `lost`.
- **A1-T2-4.** The real herdr runner gives a herdr killed by a signal the success code `""`.

The other six P2.1 classes come from the two decoders. AILANG decides "this is herdr JSON" with
substring tests and then uses a permissive `std/json.decode`. TypeScript uses `trim()` followed by
the strict `JSON.parse`. Every finding has a repro that exits 1 on the tree as given. The
TypeScript-side repros exit 0 on a patched copy, and an AILANG mutant flips its repro too.

Before this run, both existing suites pass: `types.ail` inline tests 327/327
(`ailang test packages/motoko-ext-herdr/types.ail`), and `src/tui/src/wake-waiter.test.ts` 25/25
(bun 1.4.4). So none of these findings is caught by a test today.

## What was checked

| Twin | Code under test (unmodified) |
|---|---|
| TypeScript | `herdrFailureCode`, `herdrMeansAgentGone` (`src/tui/src/wake-waiter.ts:129`, `:142`) |
| AILANG | `failure_code`, `means_agent_gone` (`packages/motoko-ext-herdr/types.ail:1160`, `:1198`), via `failure_shape` (`:1127`) and `json_error_field` (`:1145`) |

| Property | Executable statement used |
|---|---|
| **P2.1** | For each case `(exit, stderr)` with no `spawnError`: `herdrMeansAgentGone({code: exit, stdout: "", stderr}) == means_agent_gone(exit, stderr)` |
| **P2.2** | Same cases: `herdrFailureCode(...) == failure_code(exit, stderr)` |
| **X-1** (exploratory) | `herdrFailureCode`'s doc comment (`wake-waiter.ts:128`, `"" on success`): for each result the real `createHerdrRunner` returns, `herdrFailureCode(r) == ""` implies `r.spawnError === undefined && r.code === 0` |
| **X-2** (exploratory) | `wake-waiter.ts:22-24`: when herdr fails with a code other than `agent_not_found`, the real waiter's reply is `host_error`, never `lost` |

`stdout` is set to `""` throughout because neither function reads it. `spawnError` cases are excluded
by P2.1's own precondition.

## Method

Every comparison calls the real functions. Nothing is modelled.

- **TypeScript half.** `harness/ts_twin.ts` imports `src/tui/src/wake-waiter.ts` from the tree with
  bun and adds `ts_code` and `ts_gone` to every case.
- **AILANG half.** `harness/ail_twin.ail` is run with
  `ailang run --relax-modules --caps IO --entry main --args-file <cases> <abs path>`. It imports
  `pkg/sunholo/motoko_ext_herdr/types` through a harness manifest, `out/ailang.toml`. That manifest
  has path dependencies on the tree's `packages/motoko-ext-herdr` and `packages/motoko-ext-abi`, so
  nothing in the tree is written. A stale `ailang.lock` hash only produces a warning, so the
  harness still runs after the tree changes.
- **No re-encoding.** Cases reach AILANG as the entry function's argument, which the runtime
  decodes. AILANG's own `std/json.decode` is part of what is under test, and it never touches the
  input. Agreement is decided inside AILANG with `==` against the TypeScript values, so neither
  side's output is escaped or re-parsed before the comparison.
- **Comparison.** `harness/compare.ts` joins the two halves and counts P2.1 and P2.2
  disagreements. It puts each disagreement in one *mechanism class*, using predicates on the input,
  so that witnesses are grouped by mechanism. The classes are only a reading aid. Every reported
  witness was then re-run through both real functions by `repro/twin_pair.ts`.
- **Orchestration.** `harness/run_diff.sh` runs all of the above, with the AILANG half in
  100k-case chunks, four in parallel.

### Generators and sizes

| Gen | What it produces | Exit codes | Cases (run 1) |
|---|---|---|---|
| **G1** grammar | Every combination of: 41 code values (17 herdr codes and near-misses of `agent_not_found` such as `pane_not_found`, `agent_not_running`, `""`, `AGENT_NOT_FOUND`, `xagent_not_found`, each as a plain and a `\u`-escaped JSON string, plus 7 non-string values) × 6 error-object forms (key order, a "nested herdr" message, duplicate `code` keys) × 11 envelope forms (key order, spacing, pretty-printing, escaped key, duplicate `error`, array or nested wrappers). On the first three error-object forms, also × 10 whitespace wrappers (JSON whitespace, BOM, NBSP, U+2028, VT, FF) × 9 prefixes and suffixes (trailing text, `killed by SIG…`, a second envelope, `Error: ` prefix). Plus 36 hand-picked non-JSON and near-JSON strings: single quotes, trailing commas, comments, NaN, `01`, `1e999`, `\x41`, lone and paired surrogate escapes, the measured plain-text shapes. | -1, 0, 1, 2, 3, 124, 137, 255 | 960,856 |
| **G2** mutation | Seven measured stderrs (herdr's `agent_not_found`, `server_not_running`, `timeout` and `agent_not_running` envelopes, the plain-text `--current…` and nested-herdr lines), each with every single-character deletion, plus every insertion and replacement drawn from a 14-character alphabet, at every position | -1, 1, 2 | 29,928 |
| **G3** fuzz | Seeded random concatenations (mulberry32) of 38 JSON-ish tokens, 1 to `maxtok` tokens long. Half of them are wrapped as the `code` or the `message` of an envelope. | -1, 0, 1, 2, 3, 137 | 179,147 (seed 43, 200k draws, maxtok 12) |
| **G4** valid JSON | The measured envelope carrying one extra valid JSON value (38 values: number-range edges, every escape, surrogate pairs, raw U+2028, 64- and 600-deep nesting), in 3 positions. Also the envelope with each whitespace-like code point ≤ U+3000 (`\s`, U+0085, U+180E, U+200B, U+FEFF) before or after it. | 1, 3 | 327 |

Duplicates are removed. Lone surrogates are dropped, because both production paths decode stderr
as UTF-8 and so cannot deliver one. The largest stderr is 1,259 characters (G4's 600-deep array);
G1, G2 and G3 strings are at most 183 characters in run 1.

### Runs

| Run | Corpus | P2.1 disagree | P2.2 disagree | Time |
|---|---|---|---|---|
| run 1 (`--fuzz 200000 --seed 43`) | 1,170,258 | **25,967** | 634,460 (611,994 with `gone` agreeing) | ~2 min |
| run 2 (`--fuzz 400000 --seed 7 --maxtok 24`) | 1,369,869 | **25,993** | 756,224 | ~2.5 min |
| run 3, run 1's corpus against a patched copy of `wake-waiter.ts` (`=== 0`, `=== "agent_not_found"`) | 1,170,258 | **9,752** | 581,591 | ~2 min, plus a serial re-run of 4 chunks |

Run 2 found the same eight P2.1 classes as run 1 and no new one; only G3's counts grew. Run 3 asks
which classes remain once the two TypeScript lines are fixed. Its patched copy lives in
`work/fixed-root/`, outside the tree.

**What run 3 shows.** The suffix class disappears entirely. What remains is exactly the six
decoder classes, with run 1's counts: 5,717, 1,277, 644, 380, 80 and 23. `compare.ts` still files
1,631 cases under "negative exit", because that test comes first. They are decoder cases at exit
-1: for 1,625 of them, the same stderr also disagrees at exit 1, and the other 6 have no exit-1
case in the corpus. So the two TypeScript lines account for 25,967 − 9,752 = **16,215** of run 1's
P2.1 disagreements.

**Four run-3 chunks were re-run.** The AILANG processes for chunks c002, c004, c005 and c006 were
`Killed` for memory: the host was shared with other sessions' `ailang` jobs. Each was re-run
serially to its full 100,000 lines before the comparison
(`work/run3-patched-ts.log`). Runs 1 and 2 had no such kill.

## Findings

### P2.1 classes (run 1 counts), most severe first

| Report | Class | Count | Which side says gone | Mechanism |
|---|---|---|---|---|
| A1-T2-1 (with A1-T2-2) | TS `_not_found` suffix | 15,621 | TS | `wake-waiter.ts:143` `endsWith("_not_found")` |
| A1-T2-3 (with A1-T2-4) | negative exit | 2,225 (594 from `<= 0`; the other 1,631 are decoder cases at exit -1, see run 3) | AILANG | `wake-waiter.ts:131` `r.code <= 0` |
| A1-T2-5 | AILANG decode accepts trailing text | 5,717 | AILANG | `std/json.decode` reads a JSON prefix and ignores the rest; `JSON.parse` rejects |
| A1-T2-6 | AILANG `{"error"` substring gate | 644 | TS | `types.ail:1140`: a spaced or reordered envelope is `plain_text` |
| A1-T2-7 | TS `trim()` strips non-JSON Unicode spaces | 1,277 | TS | leading U+1680, U+2000–U+200A, U+2028/9, U+202F, U+205F, U+3000 |
| A1-T2-8 | duplicate keys | 380 | either | JS keeps the last key, AILANG `get` the first |
| A1-T2-9 | AILANG "nested herdr" gate before JSON | 80 | TS | `types.ail:1139` |
| A1-T2-10 | number outside float64 range | 23 | TS | AILANG decode rejects `1e309`; JS reads `Infinity` |

**A1-T2-1 is the one that matters.** The comment on `means_agent_gone` says it is "narrow on
purpose", and the measurements note says "a code not seen here is by definition not evidence the
agent is gone". The TypeScript twin widens the gate to every `*_not_found` code. Two such codes
exist in this tree's herdr vocabulary: `pane_not_found` (handled from `pane close` at
`herdr.ail:818`) and `plugin_pane_not_found`. The second was observed against a *live* pane
(`HANDOFF-2026-09-02-run-file-truth-view-and-loop-guard.md:147`).

A1-T2-2 runs the production waiter, `defaultWakeWaiterFactory` with the real runner, with herdr
replaced by a stub. When `agent wait` fails with `pane_not_found`, the wake is `lost`, and its
detail says "herdr reports agent_not_found". With `server_not_running` the wake is `host_error`.

**A1-T2-3 and A1-T2-4.** `r.code <= 0` also matters outside the twin pair. The production runner
turns a herdr child killed by a signal into `{code: -1, stderr: "killed by SIGKILL"}` with no
`spawnError` (`wake-waiter.ts:514`), and `herdrFailureCode` returns `""` for it, which is the
success code. The waiter still replies `host_error`, because its callers test `r.code === 0`
themselves. The message the model receives reads `failed (exit -1, code ): killed by SIGKILL`.

**The other six P2.1 classes are decoder disagreements.** In each, valid or near-valid JSON takes a
different branch on the two sides. I found no evidence that herdr emits any of these shapes: the
measured output is compact, `error`-first, ASCII, with no numbers and no trailing text. The notes in
`reports.tsv` give the reachability for each.

### P2.2 (secondary)

The P2.2-only classes, where `gone` agrees and the code differs, follow. Run-1 counts:

| Report | Class | Count | K6? |
|---|---|---|---|
| A1-T2-11 | a stderr containing `{"error"` that is not JSON (for example truncated): AILANG `herdr_json_undecodable`, TS `herdr_cli_rejected` | 159,690 | borderline: not JSON, but it carries herdr's marker |
| A1-T2-3 | negative exit: TS `""` against anything | 157,835 | no, this is the `<= 0` defect |
| — | non-JSON stderr with surrounding Unicode spaces (for example `"1﻿"`) | 152,063 | yes, outside herdr's JSON |
| A1-T2-5 | decode leniency, with codes other than `agent_not_found` | 109,027 | no, same mechanism as A1-T2-5 |
| A1-T2-14 | plain text containing "nested herdr": AILANG `nested_herdr` | 17,500 | yes (known) |
| A1-T2-12 | valid JSON that is not an envelope (`{"id":…}`, `null`, `1`): TS `herdr_json_undecodable`, AILANG `herdr_cli_rejected` | 10,124 (with the P2.2 side of A1-T2-6) | yes |
| A1-T2-8 | duplicate keys, other codes | 5,750 | no, same as A1-T2-8 |
| A1-T2-13 | empty stderr: AILANG `herdr_failed_silently` | 5 | yes (known) |

The K6 rows (A1-T2-12, -13, -14) are in `reports.tsv` for completeness and are marked K6 in their
notes. Whether the twins are meant to agree there is still open. Inside herdr's JSON, every P2.2
disagreement I found shares a mechanism with a P2.1 report.

## Controls (the repros can tell present from absent)

- **Patched TypeScript copy** (`work/fixed-root/src/tui/src/wake-waiter.ts`, two lines changed):
  A1-T2-1, -2, -3 and -4 exit **0**. On the real tree they exit 1.
- **AILANG mutant** (`work/ail-mutant/`): a copy of the herdr package with `failure_shape`'s JSON
  test moved before its "nested herdr" test, with its own `ailang.toml`. A1-T2-9's witness then
  exits **0**; on the real package it exits 1. This shows the repro really loads and runs the
  AILANG code.
- **Agreeing witnesses** (`repro/control/*.json`): the measured `agent_not_found` and
  `server_not_running` envelopes, `timeout`, `agent_not_running`, exit 0, exit 2 usage, plain text,
  an envelope with a trailing newline. All 16 property/witness pairs exit **0**.
- **Harness faults** exit **2**, never 1. A failed import, crash or `ailang` error is caught: run
  from a directory that is not the tree, all three repro scripts exit 2.
- **Timing.** Each repro takes ≤ 0.6 s (`work/repro_check.txt`).

## Limits

- **Bounded, not exhaustive.** The input space is the four generators above, with the exit codes
  listed per generator; G1/G2/G3 stderr is at most 183 characters (run 1). An agreement outside
  these generators is not shown.
- **Reachability.** No real herdr was run. herdr's output shapes come from the tree's measurement
  notes. Whether `agent get` or `agent wait` can return `pane_not_found` or
  `plugin_pane_not_found` is not measured, so A1-T2-1 and -2 are shown on the code, with a real
  herdr code but a stubbed herdr.
- **Not covered.** `means_agent_gone`'s AILANG callers in `herdr.ail` (the dagr `lost` row) were
  only read, not executed. AILANG's `-1` (tool-runtime envelope failure, `herdr.ail:459`, `:478`) has its
  own handling at those callers, so A1-T2-3's witness is a property violation of the pure
  functions rather than a demonstrated AILANG-path outcome.
- **Route column.** `reading` means I saw the defect in the source before any run, and execution
  then confirmed it. `execution` means a harness run showed it first.

## How to reproduce

From the tree root, with bun 1.4.4 and ailang v0.54.14:

```sh
# the full differential (about 2 minutes); exit 1 if any P2.1 disagreement
/home/motoko/trial-043/s/t043-t2-a1/out/harness/run_diff.sh . /tmp/t2-run -- --fuzz 200000 --seed 43
# one finding
bun /home/motoko/trial-043/s/t043-t2-a1/out/repro/twin_pair.ts P2.1 /home/motoko/trial-043/s/t043-t2-a1/out/repro/witness/A1-T2-1.json
bun /home/motoko/trial-043/s/t043-t2-a1/out/repro/x2_waiter_outcome.ts pane_not_found
bun /home/motoko/trial-043/s/t043-t2-a1/out/repro/x1_signal_exit.ts
```

`ailang` needs an absolute path for the entry file: a `../` path fails with `LDR001`.

## Files

| Path | What it is |
|---|---|
| `reports.tsv` | 14 reports |
| `ailang.toml`, `ailang.lock` | the harness package: path dependencies on the tree's `motoko-ext-herdr` and `motoko-ext-abi` |
| `harness/gen_corpus.ts` | generators G1 to G4 |
| `harness/ts_twin.ts` | the TypeScript half (real `herdrFailureCode` / `herdrMeansAgentGone`) |
| `harness/ail_twin.ail` | the AILANG half (real `failure_code` / `means_agent_gone`), compared with AILANG `==` |
| `harness/compare.ts` | P2.1 / P2.2 counts and mechanism classes |
| `harness/run_diff.sh` | runs everything |
| `repro/twin_pair.ts` | one witness through both real twins; exit 1 = the property fails |
| `repro/x1_signal_exit.ts` | X-1 on the real `createHerdrRunner` |
| `repro/x2_waiter_outcome.ts` | X-2 on the real `defaultWakeWaiterFactory` |
| `repro/stub/` | the two stand-in `herdr` binaries (`HERDR_BIN_PATH`) |
| `repro/witness/` | one witness file per twin report |
| `repro/control/` | witnesses where the twins agree (controls) |
| `work/` | probes (`probe.ail`, `argprobe.ail`), run logs and `compare.txt` for runs 1 to 3, `make_reports.ts` (writes `reports.tsv`), `fixed-root/` (patched TypeScript copy), `ail-mutant/` (AILANG mutant), `repro_check.txt`, `types_inline_tests.json`, `corpus_sha256.txt`. The corpora, the TypeScript outputs and the AILANG chunk outputs (about 2 GB) were deleted after the runs. `run_diff.sh` regenerates them deterministically: run 3 regenerated run 1's corpus byte for byte, with the same sha256 |
