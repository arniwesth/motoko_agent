# T4, the digest chain: summary (arm B, replicate 1)

**Target:** `src/core/journal.ail:242-300`: `chain_digest_base`, `chain_digest_after`,
`chain_step`, `chain_digest_over`, `chain_prefix_step`, `chain_digests_over` and
`chain_digests_json`, plus `chain_empty_base` (`:322-324`), which `chain_digests_over` calls.
**Method:** Kiro's, as RESEARCH-lean-harness-properties.md §1 describes it: model, differential
test, prove or `bug_` theorem, reproduce on the real code. Lean 4.28.0, core only.

## The finding

`chain_digests_over(base, ms)` **never reads `base`**. It folds from `chain_empty_base()`
(journal.ail:293):

```
List.foldl(chain_prefix_step, { last: chain_empty_base(), out: [] }, ms).out
```

So it returns the prefix chain of `ms` from the empty base, whatever `base` is
(`chainDigestsOver_eq`). Both registered properties fail because of that one token. The fix is
`{ last: base, out: [] }`.

| id | property | verdict | where it fails (Lean, for every injective `sha256Hex`) | repro |
|---|---|---|---|---|
| B1-T4-1 | **P4.2**, length half | **proved** (`P4_2_length`), for every hash and frame | never | — |
| B1-T4-1 | **P4.2**, last-element half | **falsified** (`bug_P4_2_last`, `bug_P4_2_witness`) | exactly when `ms ≠ []` and `base ≠ chain_empty_base()` (`P4_2_last_iff`) | `bash ../out/repro/repro_P4_2.sh` → exit 1 |
| B1-T4-2 | **P4.1** | **falsified** (`bug_P4_1`, `bug_P4_1_witness`) | exactly when `xs ≠ []` and `ys ≠ []`, **for every base**, including `chain_empty_base()` (`P4_1_iff`) | `bash ../out/repro/repro_P4_1.sh` → exit 1 |

Both repro commands run from the tree root. With the fix, both properties hold:
`fixed_P4_1`, `fixed_P4_2_length` and `fixed_P4_2_last` are proved for every hash and frame,
with no injectivity assumption. `fixed_agrees_at_empty_base` proves the fix changes nothing at
the base today's callers pass. On the real code, `repro/fix_check.sh` builds a symlinked copy
of the tree whose only difference is that token, and both repros exit **0** there.

**What the real code printed** (unmodified tree):

```
repro_P4_2: base = chain_digest_base([sys]) = sha256:84c69dca…
            last(chain_digests_over(base, [user])) = sha256:67fa342f…   (= chain_digest_over(chain_empty_base(), [user]))
            chain_digest_over(base, [user])        = sha256:246f4a39…   → P4.2 VIOLATED
repro_P4_1: b = chain_empty_base(), xs = [sys], ys = [user]
            LHS = [sha256:963eedc5…, sha256:fc15f0bf…]
            RHS = [sha256:963eedc5…, sha256:67fa342f…]                   → P4.1 VIOLATED
```

**Reachability.** No current caller reaches either failure. All six call sites pass
`chain_empty_base()` and a whole history: session.ail:3871 and :4809, journal.ail:2734, :3408
and :3501, and dst_invariants.ail:1186. At that base the output is the intended one
(`P4_2_last_at_empty_base`, `fixed_agrees_at_empty_base`), so no journal written today carries a
wrong digest. The risk is in the exported signature. After a `checkpoint` replacement the
fold's chain value is `chain_digest_base(prefix ++ messages)` (journal.ail:1476-1478,
:1505-1506), which is not the empty base. A caller that asks for the digests of the messages
appended after that point would get values the fold refuses with `Digest(seq)`. So would any
caller that builds a history's digests incrementally (prefix first, then the suffix from the
prefix's chain value). P4.1 shows the incremental route fails even from the empty base.

**Route.** Both were first seen by **reading**: the unused `base` is visible in the first
listing of the target. The Lean proofs then determined exactly where each property fails.
Lean's unused-variable linter flags `base` too. The differential test is also execution
evidence: on every case with a non-empty-base base and a non-empty list, the real code agrees
with a model that ignores `base`.

## The Lean files

- `ChainModel.lean`: the model, all theorems and the `#print axioms` block. The header names
  every source line it models. The chain functions are generic in the frame `F` and the hash
  `H`. Every property theorem holds for any frame, and for any hash or any injective hash as
  stated. The concrete witnesses instantiate `F := canonicalMessageFrame`.
- `axioms.txt`, written by `check_axioms.sh`. It has 34 theorems and 34 `#print axioms` lines.
  Every theorem uses at most `propext`, `Classical.choice` and `Quot.sound`. `inj_id` uses none.
  There is no `sorryAx` and no `Lean.ofReduceBool`, and no `sorry` or `native_decide` in the
  source. `./check_axioms.sh` exits 0.
- Non-vacuity. The only hypothesis on the hash is `Inj H`, and the identity satisfies it
  (`inj_id`), so `bug_P4_1_witness_id` and `bug_P4_2_witness_id` are fully concrete instances.
  The same property statements are proved for the fixed function, so they are not false of
  everything.

Theorem list:

- **Proved (registered):** `P4_2_length`.
- **Falsified (registered):** `bug_P4_2_last`, `bug_P4_1`, with witnesses `bug_P4_2_witness`,
  `bug_P4_2_witness_emptystr`, `bug_P4_1_witness` and the `_id` instances.
- **Exact characterisations:** `P4_2_last_iff`, `P4_1_iff`, `chainDigestsOver_eq`,
  `P4_2_last_at_empty_base`.
- **Fix (step 8):** `fixed_P4_1`, `fixed_P4_2_length`, `fixed_P4_2_last`,
  `fixed_agrees_at_empty_base`.
- **Lemmas:** `foldl_prefixStep`, `prefixChain_append`, `prefixChain_length`,
  `prefixChain_getLast?`, `chainDigestAfter_inj_prev`, `chainDigestOver_inj_base`,
  `chainDigestOver_ne_emptyBase` and the tagging lemmas.

## Step (2): the differential test, and how many times it changed the model

`diff/run_diff.sh SEED N` works in three stages:

1. `gen_cases.py` draws N seeded cases and writes each one twice: once as AILANG calling the
   **real** functions, once as Lean calling the model.
2. Lean runs the model with a real SHA-256 (`diff/Sha256.lean.tail`, self-tested against FIPS
   vectors) standing in for `sha256Hex`. The model includes the canonical frame, so concrete
   digests can be compared.
3. The two outputs are diffed line by line.

Each case prints `chain_digest_base(ms)`, `chain_digest_over(b, ms)`, `chain_digests_over(b, ms)`
with its length, and `encode(chain_digests_json(…))`. Bases are `chain_empty_base()`,
`chain_digest_base(ms)`, or literals (`""`, `"x"`, `"sha256:"`, 71-character fake digests,
multi-byte text, `"m-end;"`). Messages cover:

- multi-byte, astral and combining text, CR/LF and ZWJ sequences
- `make[N]` contents
- frame punctuation, quotes and backslashes
- empty fields
- up to 2 tool calls and 2 images per message, and up to 4 messages per case

**Step (2) changed the model twice, with net change zero.** The final model's functions are
the ones first written.

1. Seed 1 (60 cases) mismatched on 2 cases, both containing `"á"`. I changed
   `strLength` to count grapheme clusters, approximately: scalar values that are not combining
   marks. They still mismatched. That model is kept as `diff/runs/ChainModel.fix1-rejected.lean`.
2. I reverted `strLength` to scalar values. The cause was in the harness, not the model. AILANG
   normalises **string literals**: a source literal `"á"` arrives as `"á"`. Feeding the
   Lean half NFC-normalised literals made all 241 lines agree (`diff/runs/probe_nfc`).
   Strings built at run time are **not** normalised. `gen_cases.py` now builds
   `concat(["a", "́"])` and similar, and those match the model's plain scalar-value count.
   So std/string `length` counts scalar values, and the only normalisation is in the literal
   syntax.

The harness also changed twice in ways that did not touch the model:

- The AILANG entry file must sit under the tree's `ailang.toml`. It now runs from a symlink
  mirror inside `out/`, and the tree is never written.
- A single 400-statement `#eval` exceeded `maxRecDepth`, so cases are now emitted 40 per `#eval`.

**Recorded runs** (outputs and diffs are in `diff/runs/<run>/`):

| run | cases | lines compared | result |
|---|---|---|---|
| seed 1, n 60 (first model) | 60 | 241 | 8 lines differ (2 cases, `"á"`) → fix 1 |
| seed 1, n 60, model fix 1 | 60 | 241 | still differ → reverted (fix 2) |
| probe_nfc (harness: NFC literals) | 60 | 241 | 0 mismatches |
| seed 1, n 120 | 120 | 481 | **0 mismatches** |
| seed 2, n 400 | 400 | 1601 | **0 mismatches** |
| seed 3, n 400 | 400 | 1601 | **0 mismatches** |
| seed 4, n 400 | 400 | 1601 | **0 mismatches** |
| seed 5, n 400 | 400 | 1601 | **0 mismatches** |
| **total, final model** | **1,720** | **6,885** | **0 mismatches**; 753 of the cases have base ≠ `chain_empty_base()` and ms ≠ [] |
| negative control: seed 2, `MUTANT=fixed` (model uses the fixed function) | 400 | 1601 | fails as required: 178 cases mismatch, **exactly** the predicted set (base ≠ `chain_empty_base()`, ms ≠ []) |
| fixed model vs patched tree (`repro/.fixed_tree`), seed 3 | 400 | 1601 | **0 mismatches** |

## Step (4): reproduction on the real code

- **Repros:** `repro/repro_P4_1.ail` and `repro/repro_P4_2.ail` call the real, unmodified
  `src/core/journal.ail` through `repro/run_ail.sh`, which uses a symlink mirror under
  `out/repro/.mirror`.
- **Exit codes:** `repro/verdict.sh` exits 1 on `VIOLATED`, 0 on `HOLDS`, and 2 if the program
  did not run.
- **Timing:** each repro runs in about 12 s cold and under 1 s warm.
- **Fix check:** `repro/fix_check.sh` builds `repro/.fixed_tree`, where every path is a symlink
  to the tree except a patched copy of `journal.ail` (a one-line diff at :293). Both repros exit
  0 there.

## Observations, not reported as defects

1. **One step's digest does not determine the previous value when bases can differ in
   length.** `chain_digest_after` hashes `previous ++ frame(m)` with no separator.
   `chainDigestAfter_shift` shows that a base can absorb a prefix of the frame:
   `step(p, m) = step(p ++ X, m')` whenever `frame(m) = X ++ frame(m')`, and such pairs exist
   because `content` is free text. `chainDigestAfter_inj_eqlen` proves that with equal-length
   previous values, such as two 71-character digests, one step determines both the previous
   value and the frame. The frame's own comment (phase_vocab.ail:353-356) says the frame "is
   concatenated onto a previous digest", and every caller passes a digest. So this is a
   property of the exported signature, not a defect. I did not build a concrete collision.
2. **`chain_prefix_step` appends to a list accumulator.** `acc.out ++ [d]` is the pattern the
   std/list documentation says makes a `foldl` O(n²). The comment above `chain_digest_over`
   says "a history is unbounded". I found this by reading only and did not measure it. The
   SHA-256 per message probably dominates at realistic lengths.
3. **Drift against the evaluator's pinned copies.** `src/eval/journal/digests.ail` pins
   `chain_digest_over` by body hash (`3198f8c1…`, `List.foldl(chain_step, base, ms)`). The
   snapshot's body is `List.foldl(chain_digest_after, base, ms)` (hash `3e845a61…`). That is
   semantically the same, since `chain_step` is an eta-wrapper. The model and the differential
   test agree with that, but `chain_step` is now dead code. All pinned line numbers in the
   target are off by 2. `chain_digests_over` has no pin, so the evaluator's drift report cannot
   see the defect above.

## What was not done, and what the results rest on

- **What is proved.** Every proof is about the **model**. That the model matches the real
  functions rests on the differential test, which is evidence and not proof. The comparison
  covers 1,720 cases (6,885 output lines) with 0 mismatches on the final model, plus a negative control that fails exactly where
  predicted.
- **Assumptions.** `sha256Hex` is assumed injective (the task's black box). The `bug_`
  theorems need that assumption. `P4_2_length` and the `fixed_*` theorems do not.
- **The frame.** Its Lean model (`canonicalMessageFrame`, `digestContent` and the rest) is
  checked only by the differential test. No theorem depends on it beyond the witness
  instances.
- **Out of scope.** No property was stated about `chain_digest_base` or `chain_digests_json`
  beyond the differential test. The O(n²) observation was not measured.

## Files

| path | what |
|---|---|
| `reports.tsv` | the two reports (B1-T4-1 = P4.2, B1-T4-2 = P4.1) |
| `ChainModel.lean` | model, theorems, `#print axioms` block (`lean ChainModel.lean`) |
| `axioms.txt`, `check_axioms.sh` | axiom report and the audit that writes it (exit 0 = clean) |
| `diff/run_diff.sh`, `diff/gen_cases.py`, `diff/Sha256.lean.tail` | step (2): `diff/run_diff.sh SEED N`; `MUTANT=fixed` for the negative control; `TREE=…` to point at another tree |
| `diff/runs/` | every recorded run (cases, both outputs, diff); `ChainModel.fix1-rejected.lean`, `gen_probe_nfc.py`, `probe_nfc/` are the model-fix trail |
| `repro/repro_P4_{1,2}.{ail,sh}`, `repro/run_ail.sh`, `repro/verdict.sh` | step (4), run from the tree root: `bash ../out/repro/repro_P4_1.sh` |
| `repro/fix_check.sh` | step 8 on the real code: both repros exit 0 on a symlinked tree with the one-token fix |
