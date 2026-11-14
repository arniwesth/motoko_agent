# Differential test for `HerdrFailureModel.lean` (target T2)

`run_diff.sh` runs three halves over the same cases: the model (`../HerdrFailureModel.lean`),
the real `herdrFailureCode` / `herdrMeansAgentGone` (`src/tui/src/wake-waiter.ts:129-144`,
through bun) and the real `failure_code` / `means_agent_gone`
(`packages/motoko-ext-herdr/types.ail:1127-1207`, through ailang). It compares the model's TS side
with the real TS, and the model's AILANG side with the real AILANG. Then it compares the two
real functions directly, which tests P2.1 and P2.2 on the real code with no model in between.

Nothing in the tree is written. The AILANG driver resolves the tree's real herdr package through
`gen/ailang.toml`, a path dependency (`../../../tree/packages/motoko-ext-herdr`), and its
`ailang.lock` lives in `gen/` too.

| File | What it is |
|---|---|
| `gen_corpus.py` | Writes the corpus as `gen/corpus.json` (TS), `gen/Corpus.lean` (Lean) and `gen/enumerate_herdr.ail` (AILANG, the stderr strings as literals). Deterministic (seeded) |
| `enumerate.ts` | TS half: prints `index\|exit\|herdrFailureCode\|herdrMeansAgentGone` |
| `enumerate.lean.tail` | Lean half: appended to the model and `gen/Corpus.lean`, prints both sides of the model |
| `gen/enumerate_herdr.ail` | AILANG half (generated) |
| `run_diff.sh` | Runs all three and diffs them. Exit 0 only when both model comparisons are clean |
| `show.py` | Lists model-vs-AILANG mismatches with their stderr. Used to find corrections 1 and 2 |
| `classify.py` | Attributes every real-TS-vs-real-AILANG P2.1 disagreement to the mechanisms of B1-T2-1..8 |
| `mutants/run_mutants.sh` | Negative control: mutants planted in copies of the real files |

## Corpus

1,661 stderr strings × 6 exit codes (−1, 0, 1, 2, 3, 127) = **9,966 cases**, aimed at what the
two functions read. That covers the exit-code tests (`<= 0`, `== 0`, `== 2`), the `nested herdr`
and `{"error"` substring sniffs, herdr's envelope in 17 layouts × 22 code encodings, the
whitespace `trim()` removes (on both sides of the edge of ECMAScript's set), trailing text,
duplicate keys, `\u` escapes, non-string codes, numbers either side of float64's range, and 600
seeded random mutations of the envelope.

## Runs (2026-11-04, the snapshot as given; Lean 4.28.0, bun 1.4.4, ailang v0.54.14)

| Run | Cases | Model vs real TS | Model vs real AILANG | Model change |
|---|---|---|---|---|
| 1 | 8,328 | 0 | **212** | Correction 1: AILANG `decode` reads the first value and ignores the rest (196 cases: `{...}x`, `{...}}`, `{...}\nkilled by SIGTERM`, …). Correction 2: AILANG `decode` refuses a number outside float64's range (16 cases, `1e400`) |
| 2 | 8,514 (+ float boundaries, trailing text) | 0 | 0 | none |
| 3 | 9,966 (+ whitespace-set edges) | 0 | 0 | none (`numDigits` rewritten without `toString` to drop `Classical.choice`. The Lean output was byte-identical, sha256 `4f4b68191000ab7b…` on run 2's corpus) |
| final | 9,966 | 0 | 0 | output sha256: ts `0fe979942b2ff7e8…`, lean `96580904138286f4…`, ail `11ccd1ab1b7a8f6d…` |

The model changed **twice**, both times after run 1, and never on the TS side.

**Real TS vs real AILANG (final run):** P2.1 differs on 1,889 of 9,966 cases and P2.2 on 4,661.
`classify.py` explains all 1,889 P2.1 disagreements; 0 are unexplained:

| Mechanism (report) | Applies to | Sole cause of |
|---|---|---|
| 1 `endsWith("_not_found")` (B1-T2-1) | 1,119 | 369 |
| 2 exit code `<= 0` (B1-T2-2) | 116 | 82 |
| 3 `nested herdr` sniff first (B1-T2-3) | 408 | 90 |
| 4 `{"error"` sniff (B1-T2-4) | 900 | 225 |
| 5 JS `trim()` whitespace (B1-T2-5) | 318 | 48 |
| 6 trailing text (B1-T2-6) | 158 | 60 |
| 7 duplicate keys (B1-T2-7) | 86 | 48 |
| 8 float64 overflow (B1-T2-8) | 18 | 18 |

## Negative control (`mutants/result.txt`)

One mutant at a time, in a copy of the real file under `mutants/work/` (the tree is not
touched). The mutant's half is re-run and compared with the unmutated model output:

| Mutant | Cases that mismatch the model |
|---|---|
| TS: `endsWith("_not_found")` → `=== "agent_not_found"` | 1,119 of 9,966 |
| TS: `r.code <= 0` → `r.code === 0` | 1,661 of 9,966 |
| TS: `JSON.parse(r.stderr.trim())` → `JSON.parse(r.stderr)` | 594 of 9,966 |
| AILANG: `nested_herdr` only when `{"error"` is absent | 588 of 9,966 |
| AILANG: sniff `"error"` instead of `{"error"` | 1,812 of 9,966 |

So the test can tell the real code apart from a twin that differs in any one of these rules.
