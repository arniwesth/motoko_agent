# T6 — compose's output clipping (`truncate_utf8_by_bytes`): summary

Arm/replicate B2. Method: Kiro's, as RESEARCH-lean-harness-properties.md §1 describes it: model,
then differential test, then prove or refute, then reproduce. Lean 4.28.0 (`7e01a1bf5c70`), core
only, no Mathlib, no Lake. AILANG v0.54.14 (`e1ef33fa`).

**The tree was not modified**, with one exception, since undone. An early probe,
`ailang run --entry truncate_utf8_by_bytes store.ail`, was run from inside
`packages/motoko-ext-compose`. It was refused, because the function is not exported. But
AILANG still wrote a compile cache, `packages/motoko-ext-compose/.ailang/`, at 22:01:36. Every
file in it was new, and it was deleted. Only that directory's mtime is left changed. All later
runs work from `out/` or scratch copies.

**Location drift.** The registration says `store.ail:19-29`. In this snapshot the function is at
`packages/motoko-ext-compose/store.ail:20-30`, one line lower. Its only caller,
`store_stdout_and_elide`, is at `:32-49`.

## Verdicts

| Property | Verdict | Evidence |
|---|---|---|
| **P6.1** byte length ≤ n (n ≥ 0) | **FALSE.** Reproduced on the real, unmodified code (B2-T6-1) | `bug_p6_1_e_acute`; the exact failure set is `p6_1_fails_iff`; 3,817 of 30,375 real cases |
| **P6.2** a prefix of the input, and the input unchanged when it fits | **PROVED** (model), for every byte string, valid UTF-8 or not, and every `max_bytes`, negative ones included | `p6_2_prefix`, `p6_2_fits`; 0 real violations in 30,375 cases |
| **P6.3** valid UTF-8 in gives valid UTF-8 out | **FALSE**, as registered (K2). Reproduced (B2-T6-2) | `bug_p6_3_split_char`; 187 of the 1,916 valid-input real cases |
| **X-1** (exploratory, below) | **FALSE.** Reproduced at compose's default cap (B2-T6-3) | `bug_store_elide_keeps_whole_output`, `bug_p6_1_default_cap` |

**X-1, stated.** In `store_stdout_and_elide`, for `max_stdout_bytes ≥ 0`: when the result has
`truncated = true`, the part of `stdout` before the elision notice is at most
`max_stdout_bytes` bytes. This is P6.1 as the only caller sees it. It has the same root cause
as B2-T6-1. It is reported separately because it is the visible, reachable form: the result
says the output was elided, but nothing was elided.

### The defect behind P6.1 and X-1

`store.ail:22` reads `let n = Str.length(s);`. `std/string.length` counts runes
(`utf8.RuneCountInString`, RESEARCH §7), but `max_bytes` is a byte count. An input whose rune
count fits the cap while its byte length does not is returned whole. The model makes this
exact. For `n ≥ 0`, the result is over the cap **iff** `runeCount s ≤ n < byteLength s`
(`p6_1_fails_iff`). The overshoot is at most 4× the cap (`p6_1_overshoot_le_four`), and 4×
is reached: one emoji under a cap of 1 comes back whole, 4 bytes (`bug_p6_1_fourfold`). On
ASCII input P6.1 holds (`p6_1_ascii`). `std/bytes.length` is already imported, and the caller
already uses it at `:37`.

The one-line fix is `let n = length(b);`. In the model, `byteCap_p6_1`, `byteCap_p6_2_prefix`
and `byteCap_p6_2_fits` prove it closes P6.1 and keeps P6.2. `truncate_ne_byteCap_iff` proves
the real function and the fix differ on exactly P6.1's failure set. On the real code,
`repro/check_fix.sh` applies the fix to a scratch copy: P6.1 and X-1 then exit 0, and P6.3
still exits 1. The differential mutant M1 is the same fix, applied to the model. It mismatches
the real code on exactly the 3,817 cases where P6.1 fails, and nowhere else.

**Reachability, by reading** (no live compose run with a model was made). `compose.ail:723`
passes `ran.raw_stdout` (the composed snippet's own stdout) and
`max_stdout_bytes = clamp_positive(authoring.stdout_max_bytes, 4000)` (`:851`). `stored.stdout`
and `stored.truncated` reach the `FinalResult` at `:753`. So any snippet that prints between
4,001 bytes and 4,000 runes of non-ASCII text is passed through unclipped, with the elision
notice attached. The repro uses 2001 × "é" (4,002 bytes). CJK text can exceed the cap 3×,
emoji 4×.

### P6.3 (K2)

The slice is taken at a raw byte offset, so it can end inside a character: "éa" with cap 1
gives `C3`. The one-line P6.1 fix does not cure it, and makes it more frequent ("é" with cap 1
then gives `C3` too; `bug_byteCap_p6_3`). The model's `truncateFixed` caps by bytes, then drops
trailing bytes until the prefix is valid. It is proved to satisfy P6.1, P6.2 and P6.3
(`fixed_p6_1`, `fixed_p6_2_prefix`, `fixed_p6_2_fits`, `fixed_p6_3`), and `fixed_on_witnesses`
shows it on the counterexamples. It is reachable at the default cap:
`repro.sh p6_3_default_cap P6.3` (3999 × 'a' + 2 × "é", cap 4000) returns 4,000 bytes ending
in a lone `C3`.

## Step (2): how many times the differential test changed the model

**Zero.** The model was written first (`history/TruncateModel.v0.lean`), from the source and
from RESEARCH §7's account of the builtins: `_str_len` is `RuneCountInString`, and
`bytes.toString` is `string(b)` with no U+FFFD repair, despite its documentation. The first
comparison, on both routes, gave 0 mismatches. The definitions of the decoder, `bytesSlice`,
`truncate` and `storeElide` are byte-identical between v0 and the final file. Everything added
since v0 is theorems, plus the two fixed variants (`truncateByteCap`, `truncateFixed`) beside
the model.

The harness did change, and those changes are not model fixes:

1. `enumerate.lean.tail` had a `Nat`/`Int` type error in `maxesFor`. Lean rejected it before
   anything was compared.
2. The AILANG harness package needed `ailang lock` and a wider `[effects].max`, because the
   borrowed `canned_ports()` carries effects in its type.
3. The X-1 checker in `check_props.py` was narrowed to caps ≥ 0, after it counted the
   unreachable `("", -1)` cases.

A run of 0 mismatches is only as good as the test's power, so there are negative controls.
Five mutant models each change one behaviour, and every one is caught against the real
output (`diff/mutants/`):

| Mutant (model side) | Mismatching cases of 30,375 |
|---|---|
| M1 compare byte length, not runes (the fix) | 3,817 |
| M2 lenient decoder (a lead byte's length is taken even if its tail is bad) | 6,289 |
| M3 2-byte sequences counted as 2 runes | 667 |
| M4 slice takes one byte too few | 12,919 |
| M5 caller guard `>=` instead of `>` | 3,271 |

## The differential test

`diff/run_diff.sh [--mutants] [scratch]` runs everything end to end in about 3 minutes, or
about 8 with mutants. It covers **30,375 cases**:

- every concatenation of 0 to 3 atoms from a 14-atom alphabet: ASCII, 2-, 3- and 4-byte
  characters, newline, a lone continuation byte, a lone lead, cut-short 3- and 4-byte
  sequences, `FF`, overlong 2- and 3-byte forms, a surrogate, and a code point above
  U+10FFFF;
- each with every cap from −1 to len+1;
- plus 3,000 LCG-random byte strings of up to 12 bytes, with caps from −2 to len+2.

Of these, 28,459 have invalid UTF-8 input and 6,838 fit the cap.

There are two routes into the real code:

- **caller**: the real, **unmodified** `store_stdout_and_elide`, with the conformance
  package's `canned_ports()`. It reaches `truncate_utf8_by_bytes` on every case whose byte
  length exceeds the cap (23,537 cases). This is necessary because the function is not
  exported.
- **direct**: the function itself, in a scratch copy of the package whose only change is
  `export` on `store.ail:20`. `diff/direct/make_exposed.sh` refuses to continue if any other
  byte differs. This route covers the inputs that fit, which the caller never passes on.

**Runs (2026-11-04).**

- **First full run**, 22:10, on the same definitions: model checks; **caller 0 mismatches,
  direct 0 mismatches**; all 5 mutants caught; exit 0. Output sha256: caller
  `8a399a5fa139a85b…`, direct `ec8e1fc3427d2190…`.
- **Final run**, `--mutants`, on the delivered model: also exit 0. `run_diff.sh` exits 0 only
  if the model checks, both routes have 0 mismatches and every mutant is caught. Its log was
  not readable afterwards, because the session's permissions denied the scratch directory, so
  the hashes above are from the first run.
Inputs are built in AILANG as `toString(fromInts(...))` and printed back through
`toInts(fromString(...))`, so any repair by `toString` would have shown up as a mismatch on
the input field. None did.

## Theorems and axioms

`TruncateModel.lean`: **37 theorems**, each with a `#print axioms` (`axioms.txt`). No
`sorry`, no `native_decide`: no theorem depends on `sorryAx` or `Lean.ofReduceBool`.
`run_diff.sh` refuses both. The axioms used are Lean's standard three:

| Axioms | Theorems |
|---|---|
| none | `take_prefix`, `bug_p6_1_e_acute`, `bug_store_elide_keeps_whole_output`, `bug_p6_1_fourfold`, `bug_p6_3_split_char`, `hyps_satisfiable`, `bug_byteCap_p6_3`, `backoff_valid`, `fixed_p6_2_fits`, `fixed_p6_3`, `fixed_on_witnesses`, `byteCap_p6_2_fits` |
| `propext` only | `p6_2_prefix`, `byteCap_p6_2_prefix`, `backoff_prefix`, `fixed_p6_2_prefix` |
| `propext`, `Quot.sound` | `seqLen_pos_of_decodeOk`, `width_pos`, `seqLen_le_four`, `width_le_four`, `runeCountAux_le`, `runeCount_le_length`, `length_le_four_runeCountAux`, `p6_2_fits`, `eAcutes_length`, `runeCountAux_ascii` |
| `propext`, `Classical.choice`, `Quot.sound` (from `omega` / `by_cases`) | `p6_1_when_runes_exceed`, `p6_1_fails_iff`, `p6_1_ascii`, `p6_1_overshoot_le_four`, `runeCountAux_eAcutes`, `runeCount_eAcutes`, `bug_p6_1_family`, `bug_p6_1_default_cap`, `byteCap_p6_1`, `fixed_p6_1`, `truncate_ne_byteCap_iff` |

`axioms.txt` is the exact list. **Non-vacuity:** every theorem with hypotheses has a concrete
input that meets them all, collected in `hyps_satisfiable` (and `bug_p6_1_default_cap` for the
family).

## What could not be done, and the gaps

- **The transcription gap stays open.** The proofs are about the model. The differential
  test ties the model to the code only on the 30,375 inputs tried, none longer than 12
  bytes. The large witnesses (4,002 and 4,003 bytes) were run on the real code directly, not
  through the model.
- **The direct route uses a one-word-modified copy.** Only the caller route, and every repro,
  run the unmodified tree.
- **`int` is modelled as `Int`.** Neither function does arithmetic on `max_bytes`, so 64-bit
  overflow cannot arise here, but the model would not see it.
- **`slice`'s out-of-range behaviour** is checked only on this call shape (start 0, end = cap,
  including negative caps, which give `None` and so `""`).
- **Ports are abstracted.** The model keeps only what decides `stdout` and `truncated`.
- **Reachability is by reading** (compose.ail:723, :851, :753). No live compose run with a
  model produced such output.
- **The proof of P6.3 for the full fix** is about `truncateFixed`, a model-only function. No
  AILANG patch for P6.3 was written or run.

## Observations not reported as defects

- **O-1. The elided `stdout` exceeds `max_stdout_bytes` by the notice's length.** The result
  is clipped part + `"\n[stdout elided; full output at …]"`. Whether the cap should include
  the notice is a question of intent (RESEARCH §7 raises it), so it is not a row.
- **O-2. `store_stdout_and_elide` ignores `made.ok` and `written.ok`.** The notice says the
  full output is at `raw_path` even when the write failed: with `canned_ports()`, whose
  `file_write` returns `ok: false`, the notice is still emitted. This was found by reading.
  It is outside T6's properties and not modelled (ports are abstracted).
- **O-3. A negative cap gives a meaningless "truncated" result.** `store_stdout_and_elide("", -1)`
  reports `truncated = true` with the notice. It is unreachable: the cap is clamped positive at
  `:851`.

## Files

| File | What it is |
|---|---|
| `TruncateModel.lean` | The model (header names source file and lines), all theorems, `#print axioms` |
| `history/TruncateModel.v0.lean` | The model as first written, before any execution |
| `axioms.txt` | The axiom report, written by `run_diff.sh` |
| `reports.tsv` | Three reports |
| `diff/run_diff.sh` | The whole differential test; `--mutants` adds the controls |
| `diff/enumerate.lean.tail`, `diff/enumerate_direct.lean.tail` | Lean halves (caller, direct) |
| `diff/caller/harness.ail` (+ `ailang.toml`, `ailang.lock`) | AILANG half via the real, unmodified caller |
| `diff/direct/harness.ail`, `diff/direct/make_exposed.sh` | AILANG half calling the function directly, in a checked one-word copy |
| `diff/check_props.py` | P6.1–P6.3 and X-1 counted on the real outputs alone |
| `diff/mutants/make_mutants.sh`, `run_mutants.sh` | Negative controls |
| `repro/repro.sh`, `repro/repro.ail`, `repro/verdict.py` (+ toml, lock) | Step (4): one command per report, from the tree root; exit 1 = defect present |
| `repro/check_fix.sh` | The repros against a scratch copy with the one-line fix: P6.1 and X-1 exit 0, P6.3 exits 1 |
