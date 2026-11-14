# T2, the herdr failure vocabulary: executed checks (arm A, replicate 2)

**Target.** `herdrFailureCode` / `herdrMeansAgentGone` (`src/tui/src/wake-waiter.ts:129`, `:142`)
against `failure_code` / `means_agent_gone` (`packages/motoko-ext-herdr/types.ail:1160`, `:1198`,
via `failure_shape` `:1127`).

**Method.** Execution only. Every check calls the real functions: bun imports the real
`wake-waiter.ts`, and `ailang run --relax-modules` imports the real `types.ail` as the package
`pkg/sunholo/motoko_ext_herdr/types`. There are no models and no Lean. Nothing under `tree/` was
modified, and `git` was not run. Toolchains: bun 1.4.4, AILANG v0.54.14.

**Result.** P2.1 fails on the real code, with **8 independent root causes (A–H)**. Five are in or
next to the TS twin (A, D, E, H, and X-1, which shares H's line). Two are in the AILANG twin's
shape gate and decoder (B, C). Two come from the two JSON decoders disagreeing (F, G). P2.2 also
fails inside herdr's JSON, but only through those same causes; no cause is P2.2-only. Outside
herdr's JSON the vocabularies differ exactly as K6 says (listed below, not reported).
`reports.tsv` has 11 rows: 8 for P2.1, 1 for P2.2, and 2 for exploratory properties.

## Root causes (P2.1)

| Tag | Report | Where | What splits the twins | Witness (exit, stderr) | Side that departs from intent | Reachability |
|---|---|---|---|---|---|---|
| A | A2-T2-1 | TS `:143` | `endsWith("_not_found")` vs `== "agent_not_found"` | `1`, `{"error":{"code":"pane_not_found",…}}` | TS ("narrow on purpose"; TS's own header `:22-24`) | `pane_not_found`/`plugin_not_found` are real herdr codes; unmeasured from `agent get/wait` |
| H | A2-T2-2 | TS `:131` | `code <= 0` is success in TS; only `0` in AILANG | `-1`, `{"error":{"code":"agent_not_found",…}}` | TS | The production runner returns `-1` (no `spawnError`) for a signal-killed herdr |
| B | A2-T2-3 | AIL `:1140` | herdr JSON recognised only by the literal `{"error"` | `1`, `{"id":"cli:agent:get","error":{"code":"agent_not_found",…}}` | AILANG (rejects valid herdr JSON) | Only if herdr reorders keys or adds whitespace; measured output has `error` first |
| C | A2-T2-4 | AIL `decode` | AILANG's decode reads the first value and ignores trailing text; `JSON.parse` refuses | `1`, `{…agent_not_found…}\nhint: see herdr --help` | AILANG (the less narrow side here) | The TS runner's own stderr for a killed child is `JSON + "killed by SIGTERM"` |
| E | A2-T2-5 | AIL `:1139` | `"nested herdr"` substring outranks herdr JSON; TS has no such test | `1`, `{"error":{"code":"agent_not_found","message":"nested herdr is disabled"}}` | TS (missing the AILANG branch) | Low |
| D | A2-T2-6 | TS `:134` | `String.prototype.trim` strips BOM/NBSP/U+2028/…; JSON does not allow them | `1`, `﻿{"error":{"code":"agent_not_found",…}}` | TS | Low |
| F | A2-T2-7 | both decoders | duplicate key: `JSON.parse` keeps the last, AILANG's decode the first | `1`, `{"error":{"code":"timeout","code":"agent_not_found"}}` | neither (RFC 8259 leaves it open) | Effectively none |
| G | A2-T2-8 | AIL `decode` | a number outside float64 range (`1e400`) makes AILANG's decode fail | `1`, `{"error":{"code":"agent_not_found","message":"x","n":1e400}}` | AILANG | Effectively none |

Exploratory properties, stated here as `reports.tsv` requires:

- **X-1.** `herdrFailureCode(r) === ""` only when `r` is a success (`code === 0` and no
  `spawnError`), as its doc comment says (`:128`, `"" on success`). It fails through the real
  production runner: `createHerdrRunner("/bin/sh")` on `sh -c 'kill -TERM $$'` returns
  `{code:-1, stderr:"killed by SIGTERM"}`, and that gets `""` (A2-T2-11). The line is the same as
  H's.
- **X-2.** On the real `startWakeWaiter`, a herdr failure other than `agent_not_found` yields
  `host_error`, never `lost` (the module's contract, `:22-24`). It fails through A. With
  `pane_not_found`, `workspace_not_found` or `session_not_found` from `agent get` (motoko) or
  `agent wait` (claude), the wake is `lost`, and its detail says "herdr reports
  agent_not_found" (A2-T2-9). 6 of the 10 scenarios fail.

Other findings from the executed runs:

- **Realistic P2.1 split.** `runner_signal.ts` runs the real runner on a child that prints
  herdr's agent_not_found JSON and is then SIGTERMed. The result is
  `{code:-1, stderr:'{…agent_not_found…}\nkilled by SIGTERM'}`. TS says *not gone* (H) and
  AILANG says *gone* (C). That is a P2.1 split on an input the production runner really
  produces.
- **K6 differences, not reported.** P2.2 outside herdr's JSON (neither twin decoded a herdr
  code). These are the structured run's groups:

  | TS | AILANG | Example | Count |
  |---|---|---|---|
  | `herdr_cli_rejected` | `herdr_json_undecodable` | truncated `{"error":{"code":"agent_not_found"` | 6,699 |
  | `herdr_json_undecodable` | `herdr_cli_rejected` | `null`, `1`, `"x"`, `[]`, `{}` | 869 |
  | `herdr_cli_rejected` | `nested_herdr` | `error: nested herdr is disabled by default.` | 627 |
  | `herdr_json_undecodable` | `nested_herdr` | herdr JSON with empty code and a "nested herdr" message | 154 |
  | `herdr_cli_rejected` | `herdr_failed_silently` | empty stderr | 11 |
  | `""` | various | any negative exit (cause H again) | 5,328 |

## Generators and sizes

Every case is `(exit_code, stderr)` with no `spawnError`, since P2.1 and P2.2 are stated without
one. Cases cross the language boundary as base64 of UTF-8, so no byte is lost to quoting.

| Run | Generator (`harness/gen.ts`) | Cases | P2.1 mismatches | Unexplained by A–H | P2.2 inside JSON / outside (K6) |
|---|---|---|---|---|---|
| structured | 17 exits (−2³¹, −256, −2, −1, 0, 1, 2, 3, 124, 127, 128, 130, 137, 143, 255, 256, 2³¹−1) × (39 plain stderrs + 63 envelopes × 30 `error.code` values + 1 envelope with no code) | 32,810 | 3,776 | 0 | 7,045 / 13,688 |
| tokens4 | every sequence of 0–4 tokens over 14 JSON-ish tokens, exits {−1, 0, 1, 2} | 165,484 | 0 | 0 | 0 / 53,239 |
| chunks5 | every sequence of 0–5 chunks over 14 chunks (5 chunks = a whole envelope), exits {1, −1} | 1,158,390 | 6 | 0 | 9 / 887,502 |
| random_s1–3 | seeded random herdr-like JSON (depth ≤ 3, random keys and values, JSON whitespace with 1/40 exotic whitespace, prefixes and suffixes), then 0–3 single-character mutations in 30% of cases | 3 × 200,000 | 5,344 / 5,366 / 5,359 | 0 | 13,256 / 92,830; 13,257 / 92,369; 13,278 / 92,840 |
| fixcheck_structured | the structured set against patched copies (below) | 32,810 | 780 | 0 (all C, F, G) | 4,380 / 10,935 |
| deep_nesting.sh | agent_not_found JSON with a message nested 10⁴, 10⁵, 10⁶ deep | 3 | 0 | — | — |
| runner_signal.ts | the real `createHerdrRunner` on `/bin/sh` scripts (signal kill, with and without herdr JSON first; exit 1 as control) | 3 | 1 (H + C) | — | — |
| waiter_outcome.ts | the real `startWakeWaiter`, herdr injected; motoko and claude × 5 codes | 10 | 6 X-2 failures | — | — |

In total, 1,956,684 (exit, stderr) pairs went through both real twins, plus 32,810 more on the patched copies.

**Envelopes in the structured run.** The JSON variants: key order; whitespace, pretty-printing
and CRLF; leading and trailing BOM, NBSP and U+2028; a prefix line; signal and garbage suffixes;
two objects or lines; "nested herdr" in the message or before the JSON; duplicate `code` and
`error` keys, first or last; keys spelled with escapes; upper-case keys; error under `result` or
in an array.

The JSON-grammar edge cases: trailing comma; truncation; 1e400; 30-digit integers; −0; a lone
surrogate; `\u0000`; raw tab and newline inside strings; `\/`; a bad escape; nesting depth 200
and 5,000; a trailing comment; single quotes; leading zeros; `+1`, `.5`, `1.`, NaN, Infinity and
hex; unquoted keys; inner comments; `True`; a missing colon or comma; emoji and surrogate pairs.

The code values: `agent_not_found` (also spelled with `\u` escapes), other `*_not_found` codes,
`agent_not_found` with spaces or a suffix, `server_not_running`, `timeout`, `""`, and non-strings
(`1`, `0`, `null`, `true`, `{}`, `[]`, arrays).

**Attribution (`compare.ts --explain`).** Each mismatch is tagged with the cause predicates that
hold on its input. The predicates read the input, plus which side decoded it; they do not read
the functions' bodies. A mismatch can carry several tags, so per-cause counts overlap. Structured
P2.1, by tag: A 2,552, B 528, D 472, F 504, H 432, C 264, E 132, G 132.

The random generator found one case the first predicate set did not explain: a duplicate key
spelled with an escape (`"error"` after `"error"`). The F predicate now compares unescaped
keys. After that, **no P2.1 mismatch and no inside-JSON P2.2 mismatch in any run was
unexplained.**

**What agrees.** Every exit 0 and exit 2 case agrees on both properties. The duplicate
generators also show both twins agree on the following:

- `\u` escapes inside the code value (`agent_not_found` reads as agent_not_found on both
  sides);
- deep nesting up to 10⁶;
- big integers;
- lone surrogates;
- every in-document leniency listed above, which AILANG's decode refuses just as `JSON.parse`
  does.

AILANG's decode is lenient only about what follows the first value (C) and strict about
out-of-range numbers (G).

## Fix check (negative control)

`fixcheck/` holds patched **copies**; the tree itself is untouched:

- `wake-waiter.fixed.ts` makes four changes:
  - `code === 0` (H);
  - `=== "agent_not_found"` (A);
  - the "nested herdr" test placed first (E);
  - JSON-whitespace trim (D).
- `pkgs/motoko-ext-herdr/types.ail` adds a decode-based herdr-JSON gate alongside the literal
  `{"error"` gate (B).

`T2_TS_MODULE` and `T2_AIL_ENTRY` point the harnesses at the copies.

- On the copies, A2-T2-1, -2, -3, -5, -6, -9, -10 and -11 exit 0, and A2-T2-4, -7 and -8 still
  exit 1. Those three are decoder behaviour (C, F, G), and no patch was attempted.
- The structured set on the copies leaves 780 P2.1 mismatches, all tagged C, F or G.
- So every repro exits 1 with its defect present and 0 once that defect is removed, wherever a
  removal was written. `runs/index.txt` records all of these exit codes.

These patches show that the repros discriminate. They are not proposed fixes; in particular, the
B patch keeps the literal gate.

## Files

- `reports.tsv`: the 11 reports.
- `witness/A2-T2-*.json`: `{"exit": …, "stderr": …}` for each repro.sh report.
- `harness/`:
  - `gen.ts`: the generators: structured, tokens, chunks, random, and `one <witness>`.
  - `ts_eval.ts`: the TS half, the real `herdrFailureCode`/`herdrMeansAgentGone`.
  - `ail_eval.ail`: the AILANG half, the real `failure_shape`/`failure_code`/`means_agent_gone`.
  - `compare.ts`: the P2.1/P2.2 check, with `--explain` attribution and the inside/outside-JSON
    split.
  - `run_diff.sh`: one differential run; exit 1 on any P2.1 mismatch.
  - `repro.sh`: one witness against one property.
  - `runner_signal.ts`: X-1, and the realistic runner output.
  - `waiter_outcome.ts`: X-2.
  - `deep_nesting.sh`: the nesting-depth check.
  - `by_label.ts`: a per-envelope table, used while finding causes.
  - `run_all.sh`: everything above, plus every repro on the tree and on the copies (about 8 min).
- `ailang.toml` and `ailang.lock`: let `ail_eval.ail`, which lives outside the tree, import
  `../tree/packages/motoko-ext-herdr`. Every script regenerates the lock first, because it pins
  the package by content hash.
- `runs/`: the logs of the final `run_all.sh`. Case files were deleted: chunks5 alone is about
  150 MB. Each log records its case file's sha256, and the generators are deterministic.

Reproduce from the tree root with `bash ../out/harness/run_all.sh`, or run a single repro from
`reports.tsv`.

## Limits

- **No real herdr.** Reachability rests on the repository's measurements
  (`.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-08-31-failure-codes.md`, 09-02, 09-03),
  on herdr output in fixtures and tests, and on the real TS runner driven with `/bin/sh`. I did
  not observe how AILANG's process port reports a signal-killed child.
- **`spawnError` cases were not generated**, since both properties exclude them.
- **Strings are valid Unicode.** TS strings from the runner are UTF-8-decoded, so invalid bytes
  are already U+FFFD and none were generated.
- **Exit codes.** Only the 17 listed values were tried. The twins branch only on `== 0`, `== 2`
  and the sign, and every class is covered.
- **Root causes are attributed, not proven.** A cause is attributed by input predicates plus the
  fix check. For C, F and G the decoders themselves were not inspected; the behaviour is observed.
- **`repro.sh` limit.** It passes the case through a shell variable, so a stderr over about 1 MB
  fails as a harness error (exit 3). `deep_nesting.sh` exists for those sizes.
- **Time.** About 33 minutes of the 2 hours, 19:51–20:24 UTC, including the final `run_all.sh`.
