# T6 — compose's output clipping (`truncate_utf8_by_bytes`): summary

Snapshot: `/home/motoko/trial-043/s/t043-t6-b1/tree`, AILANG v0.54.14 (`e1ef33f`), Lean 4.28.0
(`7e01a1bf5c70`), core only. Arm/replicate: B1. Method: Kiro's, per
`RESEARCH-lean-harness-properties.md` §1, steps (1) to (5), plus step (8) (the fix, proved in the
model).

**Location note.** The task registers `store.ail:19-29`. In this snapshot the function runs from
`func truncate_utf8_by_bytes` on **line 20** to its `}` on **line 30**. The model's header names
20-30.

## Results

| Property | Verdict | Lean | Real code |
|---|---|---|---|
| **P6.1** result ≤ `n` bytes for `n ≥ 0` | **Violated** (new, B1-T6-1) | `bug_P6_1_two_byte`, `bug_P6_1_euro`, `bug_P6_1_family`; `p61_iff` proves the exact failure set | Reproduced: `repro/repro_p61.sh` exits 1 |
| **P6.2** byte prefix; unchanged when it fits | **Proved**, for every `Int` cap, not only `n ≥ 0` | `p62_prefix`, `p62_fits` | `repro/repro_p62.sh` exits 0 (a check on 3 inputs, not a finding) |
| **P6.3** valid UTF-8 in gives valid UTF-8 out | **Violated** (known K2, still present; B1-T6-2) | `bug_P6_3` | Reproduced: `repro/repro_p63.sh` exits 1 |

**B1-T6-1, the new defect.** The function decides whether the input fits with
`let n = Str.length(s)` (store.ail:22). That is a **rune** count
(`utf8.RuneCountInString`, RESEARCH §7), but `max_bytes` is a **byte** cap. So any input with
`runeCount ≤ max_bytes < byteLength` comes back whole, over the cap. `p61_iff` proves this is the
*only* way P6.1 fails: for `m ≥ 0`, `len(truncate s m) ≤ m ↔ len s ≤ m ∨ m < runeCount s`. On the
other branch the cut is exactly `m` bytes, so the cap holds there.

- Smallest witness: `"é"` (C3 A9) with cap 1 returns 2 bytes.
- At the shipped default cap of 4000: `"日" × 2000` (6000 bytes, 2000 runes) returns all 6000
  bytes. The real `store_stdout_and_elide` reports `truncated: true` for it while removing nothing.

**B1-T6-2 (K2).** When the rune count exceeds the cap, `slice(b, 0, max_bytes)` cuts at a byte
offset and can split a character. `"éé"` with cap 1 returns the lone lead byte C3. At cap 4000,
`"a" × 3999 + "日本"` ends in a bare E6. The P6.1 fix alone does not remove this: `bug_fix_P6_3`
shows it in the model, and `repro_p63.sh` still exits 1 on a fixA scratch copy.

**Reachability, from reading only (not run end to end):**

1. `compose.ail:723` passes `ran.raw_stdout` and
   `max_stdout_bytes = clamp_positive(stdout_max_bytes, 4000)`. Every shipped
   `.motoko/config/*/compose.json` sets 4000.
2. `stored.stdout` goes into the `FinalResult` item (`compose.ail:753`).

So a compose snippet that prints 1,334 to 4,000 CJK characters gets its whole output back, plus
the elision notice. I did not trace the runtime process seam's own output limit, which is outside
the tree. Both repros go through the real, unmodified export `store_stdout_and_elide`, the
function's only caller.

## How many times step (2) changed the model: **0**

The first full differential run matched the model to the real code with **0 mismatches on
23,315 cases** (output sha256 `d8cc5a73cc107b14…`), and the model has not changed since.

To be precise about what came before that run:

- I wrote the model from the source and from two outside sources: `ailang docs std/bytes` /
  `std/string` (signatures only), and RESEARCH §7's reading of the Go builtins. §7 says
  `toString` is `string(b)` with no repair (the docs suggest otherwise) and `Str.length` is
  `RuneCountInString`.
- Before writing the model I ran a **7-case smoke test of the harness itself** (`"é"`/1, `"éé"`/3,
  `"éé"`/1, `"ab"`/-1, `"a"`/0, `"ab"`/5, `FF 80 61`/2). Its outputs were what the reading
  predicted, so I count no model change from it. Still, it ran the real code before the model
  existed, and it is how I first *saw* the P6.1 witness execute. Route stays "reading": I spotted
  the defect in the source before that run.
- The two proof-side edits after the first check (removing unused `simp` arguments in
  `T6Model.lean`) changed no definition.

**What the differential test covers** (`diff/gen_cases.py`, fixed seed 43006):

- Random strings built from valid 1-4-byte runes and 22 invalid shapes: overlong, surrogate,
  > U+10FFFF, truncated, bad continuation.
- Uniform random bytes.
- Every single byte.
- Every lead byte against the accept-range edges.
- Caps at -2, -1, 0, 1, n-1, n, n+1, n+2 and random values.

15,335 of the cases have rune count < byte count. Each output line carries four fields: the input
bytes as AILANG sees them (so the harness can't repair input unnoticed), `Str.length`, and the
result bytes. That tests the rune-count model on its own, not only through the result.

**Negative controls** (`diff/controls.sh`, log in `diff/controls.log`): all 8 were caught.

- **Real side** (sed on the cut copy of the function only):
  - `Str.length(s)→length(b)`: 3,205 mismatches
  - `<=`→`<`: 726
  - `slice(…,max_bytes-1)`: 5,457
  - `None => s`: 4,283
- **Model side:**
  - 0xED accept range widened to admit surrogates: 2,073
  - repairing `toString`: 4,916
  - byte-length fits test: 3,205
  - rune count = byte count: 15,335

**How the real function is reached.** `truncate_utf8_by_bytes` has no `export`. Importing it
fails type-checking (`undefined variable: truncate_utf8_by_bytes`; checked with `ailang check`,
not run). So `diff/run_diff.sh` builds the AILANG half from three pieces:

1. store.ail's own `import std/...` lines
2. the function's text, cut verbatim from store.ail (11 lines, sha256 `b4e6ccc993e7a209…`)
3. a driver

The repros don't cut anything: they call the unmodified exported `store_stdout_and_elide` from a
throwaway package outside the tree, which depends on the tree's packages by path. The ports come
from `canned_ports()`, whose FS ports are no-ops. No file in the tree was written.

## Step 8: the fixes, proved in the model and matched to AILANG

- **fixA**, `let n = length(b)` (`truncateFix` in `T6Model.lean`). Proved: `fix_p61` and
  `fix_p62_prefix`/`fix_p62_fits`. `fix_agrees_when_p61` proves it changes nothing wherever the
  original already met P6.1. It does **not** fix P6.3 (`bug_fix_P6_3`).
- **fixAB**, fixA plus a `rune_cut` helper that backs the cut off a continuation byte
  (`truncateFix2` in `T6FixUtf8.lean`). Proved: `fix2_p61`, `fix2_p62_prefix`, `fix2_p62_fits`
  and **`fix2_p63`**. `fix2_p63` rests on `decode1_shape`, `valid_take_boundary` and
  `runeCutN_boundary`; together they show the prefix of valid UTF-8 up to a non-continuation byte
  is valid.
- `diff/fix_diff.sh` applies both fixes to **scratch copies** of store.ail and runs the same
  23,315 cases. **0 mismatches** for fixA against `truncateFix` and for fixAB against
  `truncateFix2`.
- Repro exit codes on scratch copies:

  | Copy | `repro_p61.sh` | `repro_p63.sh` | `repro_p62.sh` |
  |---|---|---|---|
  | fixA | 0 | 1 | 0 |
  | fixAB | 0 | 0 | 0 |

  So each repro exits 0 when its defect is gone. The fix is not applied to the tree.

## Theorems and axioms

Full report: `axioms.txt` (`#print axioms` for all 33 theorems in the two files, and a scan of
the code with comments stripped: no `sorry`, `native_decide`, `admit` or `axiom`). No theorem
uses anything beyond `propext`, `Classical.choice` and `Quot.sound`. `Classical.choice` comes from
`by_cases`/`omega`/`simp` on propositions. There is no `sorryAx` and no `Lean.ofReduceBool`. Every
`bug_` theorem and witness is closed by `decide` in the kernel and depends on no axioms.

Each proved theorem's hypotheses are shown satisfiable by a concrete input:

- `witness_p61_iff_hyp`, `witness_p62_fits_hyp`, `witness_family_hyp`
- `fix2_on_bug_inputs`

## What I could not do, and the limits

- **Not proved about the code, only about the model.** The differential test is evidence on
  23,315 inputs, not proof that the model matches.
  - `slice` is checked only with start 0. That is the only use.
  - `Str.length` = `RuneCountInString` and "`toString` does not repair" are checked on the
    generated inputs, not read from the Go source, which is outside the allowed directories.
- **Integers** are unbounded in the model. 64-bit overflow of `max_bytes` is out of scope; no
  caller passes anything near it.
- **Bytes** are `List Nat` in the model. Real inputs are 0..255, a subset of what the theorems
  cover.
- **Reachability** through a whole compose turn (an AI-authored snippet whose stdout passes the
  process seam) was not run, only read. The repros enter at `store_stdout_and_elide`.

## Observations, not filed as reports

1. **The elision notice is appended after clipping.** So the `stdout` that
   `store_stdout_and_elide` returns is longer than `max_stdout_bytes` by the notice's length,
   even with both fixes. RESEARCH §7 already raises this as a question about intent. It isn't a
   property of `truncate_utf8_by_bytes`, so I filed nothing.
2. **A negative cap returns `""`** (`truncate_neg`). This agrees with P6.2, and P6.1 doesn't
   register `n < 0`. The only caller clamps the cap positive.
3. **`truncated: true` with nothing removed** is a consequence of B1-T6-1, not a separate defect.

## Files

| File | What it is |
|---|---|
| `T6Model.lean` | Model (header names source and lines), P6.1/P6.2/P6.3 theorems, fixA, axiom prints |
| `T6FixUtf8.lean` | fixAB and its P6.1/P6.2/P6.3 proofs. Definitions repeat `T6Model.lean`'s verbatim (checked) |
| `axioms.txt` | The axiom report: Lean's full output for both files |
| `reports.tsv` | B1-T6-1 (P6.1), B1-T6-2 (P6.3) |
| `diff/run_diff.sh` | Step 2: model against the real function. Exit 0 = 0 mismatches. Log: `diff/run_diff.log` |
| `diff/gen_cases.py`, `diff/enumerate.lean.tail`, `diff/driver_*.ail.part` | Case generator, Lean half, AILANG driver |
| `diff/controls.sh` | Negative controls. Log: `diff/controls.log` |
| `diff/fix_diff.sh` | Fix models against fixed scratch copies. Log: `diff/fix_diff.log` |
| `repro/repro_p61.sh`, `repro/repro_p63.sh` | Step 4 repros. Exit 1 = defect present |
| `repro/repro_p62.sh` | Real-code check of the proved P6.2 |
| `repro/elide_driver.ail`, `repro/run_export.sh`, `repro/check.py` | Repro harness through the real export |

Rerun everything from the tree root:

```
bash ../out/diff/run_diff.sh
bash ../out/diff/controls.sh
bash ../out/diff/fix_diff.sh
bash ../out/repro/repro_p61.sh; bash ../out/repro/repro_p63.sh
```
