# T2 — the herdr failure vocabulary: summary (arm B, replicate 2)

Target: `herdrFailureCode` / `herdrMeansAgentGone` (`src/tui/src/wake-waiter.ts:129`, `:142`)
against `failure_shape` / `failure_code` / `means_agent_gone`
(`packages/motoko-ext-herdr/types.ail:1127`, `:1160`, `:1198`). Method: Kiro's, as
RESEARCH-lean-harness-properties.md §1 gives it: model in Lean 4.28.0 (core only), differential
test against the real code, prove or state `bug_` theorems, reproduce every counterexample on
the real, unmodified code. The real code was executed only for the differential test (step 2)
and the reproductions (step 4). Nothing in the tree was modified.

## Bottom line

- **P2.1 is false.** Eight distinct mechanisms make `herdrMeansAgentGone` ≠ `means_agent_gone`,
  all reproduced on the real code (B2-T2-1..7, 14). The one that matters is **B2-T2-1**: the TS
  twin's `endsWith("_not_found")` treats every `*_not_found` code as "agent gone", while the
  AILANG rule is "narrow on purpose" (`== "agent_not_found"`). On herdr's own envelope this is
  the ONLY way they disagree: `p21_herdrEnvelope_iff` proves that on herdr's actual envelope
  `{"error":{"code":"C","message":"M"},"id":"I"}`, for every positive exit code (other than 2)
  and all plain strings `C`, `M`, `I` with no "nested herdr" in them, the twins agree iff a `C`
  ending in `_not_found` is `agent_not_found`.
- **P2.2 is false inside herdr's JSON too**, not only in K6's region: every P2.1 mechanism but
  B2-T2-1 also changes the code, and a lone surrogate escape does on its own (B2-T2-8). Outside
  herdr's JSON (K6) four further divergences are listed (B2-T2-9..12) and flagged K6.
- **One defect in the TS function alone** (X-1, B2-T2-13): `herdrFailureCode` returns `""`, its
  documented success value, for every exit code ≤ 0, which `createHerdrRunner` produces for a
  signal-killed child.
- **Step (2) changed the model 3 times**, all three in how the two JSON decoders behave (fixes 1
  and 3: AILANG's `std/json.decode`, whose source is not in the snapshot; fix 2: lone surrogates,
  on both sides); the transcriptions of the four functions themselves needed no fix.

## Step (2): how many times the differential test changed the model — **3**

| fix | what the real code did | model before → after |
|---|---|---|
| 1 | AILANG `decode` ignores everything after the first JSON value (`{"error":…}killed by SIGTERM` decodes) | whole-input parse → first value only |
| 2 | `JSON.parse` keeps a lone surrogate escape as a lone UTF-16 unit; AILANG writes U+FFFD | both U+FFFD → TS keeps it (as U+F0000+u) |
| 3 | AILANG `decode` refuses numbers with \|x\| ≥ 2^1024 − 2^970 (`1e999`, `1.7976931348623159e308`) | accepted → refused, boundary exact |

Fixes 1–2 came from diff run 1 (108,928 cases: 880 TS and 9,660 AILANG mismatches); fix 3 from
15 hand probes of the real code. Final run: **273,872 cases, 0 mismatches on either side**
(`diff/results/final_run.log`). The negative control plants one mutant on each side and catches
both (5,317 and 4,577 mismatches; `diff/negative_control.sh`). Details: `diff/README.md`; the
model as first written: `model_history/`.

## Step (3): what is proved (61 theorems, `HerdrFailureModel.lean`)

No `sorry`, no `native_decide`; `decide +kernel` is used for the concrete witnesses (the kernel
evaluates the `Decidable` instance). Every theorem's axioms are within `propext`,
`Classical.choice`, `Quot.sound` (`axiom_report.txt`: 61 theorems, 8 need only `propext`, 4 no
axiom at all).

Proved for every exit code and every stderr (statements about the model):

- `p21_holds_under_H` — P2.1 holds under five hypotheses: `hexit` (exit > 0), `hnest` (no
  "nested herdr"), `hgate` (when TS reads a code, stderr contains `{"error"`), `hagree` (on
  gated stderr the two decoders read the same code), `hnarrow` (a code ending `_not_found` is
  `agent_not_found`). Each hypothesis has a `bug_` witness that violates it and (checked by
  inspection, not by a theorem) none of the other four, so none can be dropped.
- `p22_holds_under_H` — P2.2 holds when exit > 0, no "nested herdr", `{"error"`-gated,
  `JSON.parse(trim)` succeeds and the decoders agree.
- `p22_plain_text_agrees` — outside JSON, non-empty plain text without "nested herdr" agrees
  (both `herdr_cli_rejected`); K6's divergences (B2-T2-9..12) all lie outside it.
- String-level, the decoders' hypotheses discharged by proving what both parsers do:
  on herdr's full envelope `{"error":{"code":"C","message":"M"},"id":"I"}` for all `C`, `M`, `I`
  without `"`, `\` or control characters, `p21_herdrEnvelope_iff` (above) and
  `p22_herdrEnvelope` (failure codes equal for every exit > 0); the same for the minimal
  envelope `{"error":{"code":"C"}}` (`p21_envelope_iff`, `p22_envelope`).
- Lemmas: `ts_gone_pos`, `ts_code_parsed`, `ail_gone_pos`, `ail_code_json`, `both_cli_syntax`,
  `parseStrBody_plain`, `parseValue_envelope` and the other envelope lemmas.
- Non-vacuity: `p21_nonvacuous`, `p22_nonvacuous`, `envelope_nonvacuous`,
  `herdrEnvelope_nonvacuous` give a concrete input satisfying every hypothesis (the last is
  wake-waiter.test.ts's `NOT_FOUND` stderr, verbatim).
- Counterexamples (`bug_`, each reproduced): `bug_p21_suffix`, `bug_p21_nested_in_message`,
  `bug_p21_key_order`, `bug_p21_spaced_json`, `bug_p21_negative_exit`,
  `bug_p21_duplicate_code_last` / `_first`, `bug_p21_trailing_text`, `bug_p21_unicode_space`,
  `bug_p21_float_overflow`, `bug_p22_lone_surrogate`, `bug_p22_k6_empty` / `_nested_plain` /
  `_bare_json` / `_broken_json`, `bug_x1_killed_reads_as_success`.

Mutation check (RESEARCH §4's "fail on a mutant model"; `mutants/`, `mutants/mutants.log`): four
one-line mutants of the model, each removing one behaviour a `bug_` theorem states. On every
mutant the targeted statement evaluates to `false` (so it cannot be proved there) and an
unrelated control statement stays `true` — all four PASS:

| mutant | target (now false) | control (still true) |
|---|---|---|
| M1 TS verdict `== "agent_not_found"` | `bug_p21_suffix` | `bug_p21_key_order` |
| M2 TS success only on exit 0 | `bug_p21_negative_exit` | `bug_p21_suffix` |
| M3 AILANG tests JSON before "nested herdr" | `bug_p21_nested_in_message` | `bug_p21_trailing_text` |
| M4 AILANG `decode` requires end of input | `bug_p21_trailing_text` | `bug_p21_suffix` |

This check evaluates the statements (`#eval decide …`) rather than re-running the proofs: a
failing `decide +kernel` on a mutant drove Lean past 6 GB before reporting, so whole-file
mutant runs were OOM-killed. It is a diagnostic only; no reported theorem uses compiled
evaluation. The universally quantified theorems (`p21_holds_under_H`, `p21_envelope_iff`, …)
were not mutation-checked.

## What I could not prove, and the limits

- P2.1 and P2.2 as registered (no hypotheses) are false; only the hypothesised and
  envelope-restricted versions are proved.
- `hagree` is not characterised at the string level beyond herdr's envelope: when
  `JSON.parse(trim)` and AILANG's `decode` read the same code on arbitrary text is only tested
  (diff/), not proved. The envelope theorems exclude escapes (`\"`, `\uXXXX`) inside `C`, `M`,
  `I`, whitespace or other key orders, and trailing newlines; those are covered by the
  differential test only.
- "no `nested herdr` in the envelope" stays a hypothesis of the envelope theorems rather than
  being reduced to a condition on `C`, `M` and `I`.
- AILANG's `std/json` (`decode`, `get`) is outside the snapshot: its model is whatever the
  differential test pinned (fixes 1–3, first-wins `get`). A behaviour the 273,872 inputs never
  exercise could still differ. Strings are modelled as Unicode scalar values; JS's lone UTF-16
  units are represented by private-use code points (fix 2).
- Every proof is about the model; the link to the real code is the differential test, which is
  evidence, not proof.

## Step (4): findings (`reports.tsv`; each repro exits 1 on the real code, run from the tree root)

| id | prop | route | what | reachable? |
|---|---|---|---|---|
| B2-T2-1 | P2.1 | reading | TS verdict `endsWith("_not_found")` vs AILANG `== "agent_not_found"` (`pane_not_found`) | herdr emits other `*_not_found` codes (`plugin_pane_not_found` even against a live pane); TS asks only after `agent get/wait`, measured to answer `agent_not_found` — so plausible, not observed |
| B2-T2-2 | P2.1 | reading | AILANG checks "nested herdr" before JSON: herdr JSON mentioning it becomes `nested_herdr` | only if a herdr message mentions it |
| B2-T2-3 | P2.1 | reading | AILANG gates JSON on the literal `{"error"`; other key order/spacing is `herdr_cli_rejected` | not with today's compact, error-first envelope |
| B2-T2-4 | P2.1 | reading | exit < 0: TS `""`, AILANG decodes the code | AILANG's `bash_exit` uses -1 for an unreadable envelope; TS -1 comes with spawnError or "killed by" |
| B2-T2-5 | P2.1 | execution | duplicate `code` key: JS last wins, AILANG `get` first | serde never emits duplicates |
| B2-T2-6 | P2.1 | execution | AILANG ignores text after the JSON; `JSON.parse` throws | any trailing stderr text |
| B2-T2-7 | P2.1 | execution | `trim()` strips U+00A0/U+FEFF/U+000B…, JSON does not | unlikely |
| B2-T2-14 | P2.1 | execution | AILANG refuses out-of-range numbers (`1e999`) | not in herdr's envelope |
| B2-T2-8 | P2.2 | execution | lone surrogate escape: TS keeps it, AILANG U+FFFD | serde never emits it |
| B2-T2-9..12 | P2.2 | reading | K6: empty stderr; plain "nested herdr"; bare JSON (`null`); broken JSON with `{"error"` | K6, known; intent open |
| B2-T2-13 | X-1 | reading | `herdrFailureCode` gives `""` (success) to a signal-killed call | yes: wake-waiter.ts:514; outcome still `host_error`, message shows an empty code |

**X-1 (exploratory), stated:** `herdrFailureCode(r)` is `""` only when the herdr call
succeeded (exit 0, no spawn error), as its doc comment (wake-waiter.ts:128) says.

Root causes, for a fix: B2-T2-1 and -4/-13 are one-token differences in the TS twin
(`endsWith` → `===`, `<= 0` → `=== 0`); -2, -3 are the AILANG side's substring tests running
before (or instead of) decoding; -5, -6, -7, -8, -14 are the two JSON decoders disagreeing,
which neither twin's comment mentions.

## Layout and how to re-run

    HerdrFailureModel.lean        model + theorems + axiom prints   lean HerdrFailureModel.lean  (~20 s, ~2 GB)
    axiom_report.txt              the #print axioms output of that run
    diff/                         differential test (run_diff.sh, negative_control.sh, README.md, results/)
    repro/                        check.ts + one script per report: bash ../out/repro/B2-T2-<n>.sh
    mutants/                      model mutants and run_mutants.sh
    model_history/                the model as first written (v0)
    reports.tsv                   the findings
    check_all.sh, check_all.log   re-runs all of the above (exit 0 = every claim here still holds); last run: OK

Tools: Lean 4.28.0 at `~/.elan/toolchains/leanprover--lean4---v4.28.0`, bun, ailang v0.54.14.
