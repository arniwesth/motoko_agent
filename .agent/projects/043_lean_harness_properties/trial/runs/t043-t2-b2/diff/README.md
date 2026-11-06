# Differential test for ../HerdrFailureModel.lean (target T2)

Three halves over the same deterministic inputs:

| half | what runs | file |
|---|---|---|
| model | `HerdrFailureModel.lean` up to `## Theorems`, plus `run_model.lean.tail`, under `lean --run` | `run_model.lean.tail` |
| real TS | `herdrFailureCode` / `herdrMeansAgentGone` imported from `src/tui/src/wake-waiter.ts` (bun) | `run_ts.ts` |
| real AILANG | `failure_code` / `means_agent_gone` imported from `packages/motoko-ext-herdr/types.ail` (ailang v0.54.14, `--package-dir` the tree) | `run_ail.ail` |

`gen.ts` writes the inputs (fixed xorshift seed): 8 exit codes (-1, 0, 1, 2, 3, 124, 127, 255)
times every stderr built from 46 envelope templates x 21 `code` values x 16 leading/trailing
wrappers (key order, spacing, pretty-printing, duplicate keys, nested-herdr messages, trailing
text, Unicode whitespace, NUL, lone and paired surrogate escapes, malformed JSON, JSON5-isms,
numbers at float64's boundary), 28 plain-text and bare-JSON stderrs, and N random mutations of
herdr-shaped JSON. `compare.py` fails on any model-vs-real mismatch and counts the real
cross-language disagreements as information.

    run_diff.sh [scratch dir] [random count]      # exit 0 = no model-vs-real mismatch
    negative_control.sh [scratch dir]             # exit 0 = both planted mutants are caught

## Runs (step 2 of the method)

| run | model | cases | TS mismatches | AILANG mismatches | outcome |
|---|---|---|---|---|---|
| 1 | v0, as first written (`../model_history/`) | 108,928 | 880 | 9,660 | fix 1 and fix 2 |
| 2 | v2 | 108,928 | 0 | 0 | — |
| probe | v2 (prediction) vs real code | 15 hand inputs | 0 | 4 (`1e999`, `-1e999`, `1E400`, `2e308`) | fix 3 |
| 3 | v3 = final | 143,872 | 0 | 0 | — |
| final | v3 = final | 273,872 (150,000 random) | 0 | 0 | `results/final_run.log` |

Model fixes (3 in all; every one on the AILANG `decode` / JSON side, none in the transcription of
the four functions themselves):

1. **AILANG `decode` ignores everything after the first JSON value.** v0 required end of input
   (as `JSON.parse` does). Seen as `{"error":{"code":"x"}}\nkilled by SIGTERM` -> real `x`, model
   `herdr_json_undecodable`.
2. **Lone surrogate escapes.** v0 decoded `\ud800` to U+FFFD on both sides. Real `JSON.parse`
   keeps the lone UTF-16 unit; real AILANG writes U+FFFD. The model now represents the TS unit u
   as the private-use code point U+F0000+u (`loneSurrogate`), and `compare.py` maps the real TS
   output the same way. Inputs never contain those code points.
3. **AILANG `decode` refuses a number outside float64's range** (|x| >= 2^1024 - 2^970).
   `numOverflows`; the boundary is pinned by the generator (`1.7976931348623158e308` accepted,
   `1.7976931348623159e308` refused, `100e307` refused, `1e-99999` accepted).

AILANG's `get` keeping the FIRST duplicate key was the model's guess from v0 and was confirmed,
not fixed. The cross-language disagreement counts in the final run (16,106 P2.1, 131,417 P2.2)
are the real code's, on these inputs; they are not mismatches of the model.

## Negative control

`negative_control.sh` plants one change on each side and requires the comparison to notice it
(2026-11-04, 90,928 cases):

- a mutant COPY of `wake-waiter.ts` (the tree is untouched) whose verdict is
  `=== "agent_not_found"`: 5,317 TS mismatches, 0 AILANG;
- a mutant copy of the model whose AILANG `get` keeps the last duplicate key: 0 TS mismatches,
  4,577 AILANG.
