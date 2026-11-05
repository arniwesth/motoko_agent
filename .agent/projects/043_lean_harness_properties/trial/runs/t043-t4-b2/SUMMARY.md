# T4, the digest chain: summary (arm B, replicate 2)

Target: `src/core/journal.ail:242-300` in the snapshot at `/home/motoko/trial-043/s/t043-t4-b2/tree`,
plus `chain_empty_base` (`:322-324`), which `chain_digests_over` calls. Method: Kiro's, as
`.agent/projects/043_lean_harness_properties/RESEARCH-lean-harness-properties.md` §1 describes
it. Lean 4.28.0 (`7e01a1bf5c70`), core only, no Mathlib, no Lake. AILANG v0.54.14 (`e1ef33f`).

## Result

**One defect with one root cause, and it breaks both registered properties.**
`chain_digests_over(base, ms)` never reads `base`. Line 293 starts the fold from
`chain_empty_base()`:

```
export pure func chain_digests_over(base: string, ms: [Message]) -> [string] {
  List.foldl(chain_prefix_step, { last: chain_empty_base(), out: [] }, ms).out   -- :293
}
```

The function's own comment says it returns "the prefix chain", one per message, of the chain
`chain_digest_over(base, ms)` computes. That is only true when `base` is `chain_empty_base()`.

| Report | Property | Verdict on the code as written | Lean | Real code |
|---|---|---|---|---|
| B2-T4-1 | **P4.1** | **False** for every base, `chain_empty_base()` included, whenever `xs` and `ys` are both non-empty | `bug_P4_1`, `bug_P4_1_at_empty_base` | `repro/p4_1.sh` exits 1 |
| B2-T4-2 | **P4.2**, last element | **False** for every base other than `chain_empty_base()` and every non-empty `ms` | `bug_P4_2`, `bug_P4_2_last_ne` | `repro/p4_2.sh` exits 1 |
| — | **P4.2**, length | **Proved** for every base and list | `P4_2_length` | 0 length mismatches in the differential test |
| B2-T4-3 | X-1 (stale comment) | The comment at `:225-228` names the wrong digest for `history_seeded` | — (documentation) | `repro/x1.sh` exits 1 |

The fix is the one token `chain_empty_base()` → `base` on line 293. Proved for the fixed model:
P4.1 (`P4_1_fixed`) and P4.2 (`P4_2_fixed`) for every base. `real_eq_fixed_at_empty_base` proves
that at `chain_empty_base()` the code as written and the fix agree on every list, so the fix
changes no output any current caller sees. Both repro scripts exit 0 on a copy of `src/` with the
fix (`repro/check_on_fixed_copy.sh`) and 1 on the tree.

**Reachability: not reachable today, by reading.** All seven call sites pass
`chain_empty_base()`: `session.ail:3871` and `:4809`; `journal.ail:2734` (a test fixture),
`:3408` and `:3501`; `dst_invariants.ail:1186`; and `scripts/dst/invariants_dst.ail:1063`. None of
them composes two calls, so no current output is wrong (`real_eq_fixed_at_empty_base`). The defect
is latent. It would hit the first caller that asks for digests from any other base, such as a
chain rebased at a checkpoint (`fold_replace`, `journal.ail:1504-1505`, rebases to
`chain_digest_base(prefix ++ replacement)`) or a seed that continues an existing chain. A host
that copied those digests would write `digest_after` values that `fold_journal` refuses. Both
P4.1 counterexamples are cases of this: their second call starts from a non-empty chain.

**Why the research note's weaker statement would not have caught it.** RESEARCH §5.B states the
chain-prefix property as "`chain_digests_over(b, xs ++ ys)` *begins with*
`chain_digests_over(b, xs)`". That statement **holds** of the defective code
(`weak_prefix_holds`), because both sides make the same mistake. The registered P4.1 pins the
suffix too, and that is what exposes the defect.

## Exploratory properties

- **X-1: the comments in the span describe the code.** Violated at `journal.ail:225-228`. That
  comment says `chain_digest_base` (that is, `digest_messages`) "is the whole-history digest a
  `history_seeded` entry carries as `digest`". The field actually carries the chain quantity
  `chain_digest_over(chain_empty_base(), messages)`. `phase_vocab.ail:1074-1084` records that
  correction ("this sentence is CORRECTED from what P3 Part 1 wrote here"), `session.ail:3871`
  emits it, and `dst_invariants.ail:1173` pins it. The correction was not carried to this
  comment. On a one-message seed the two values differ (`sha256:3a6afc31…` against
  `sha256:258b1f42…`). Documentation only: no behaviour changes.
- **X-2: `chain_digest_after` is injective in (previous, message).** This is **an observation,
  not reported as a defect.** The step hashes `previous ++ frame` with no separator. For a
  `previous` that is not digest-shaped, one frame can be a proper suffix of another, so two
  different pairs give the same value whatever the hash is (`obs_X2_after_collides`, in
  `FrameModel.lean`). Reproduced on the real code (`repro/x2.sh` exits 1):
  `chain_digest_after("", user "m{role:4:user;content:0:")` and
  `chain_digest_after("m{role:4:user;content:24:", user "")` are both `sha256:db9ce534…`, and so
  are the matching `chain_digest_over` calls. This is not reported as a defect because the frame's
  own comment (`phase_vocab.ail:351-356`) states its precondition: "a frame is concatenated onto a
  previous digest". Every base the code passes is a 71-character `sha256:` digest, for which the
  concatenation is injective. It is a boundary to keep in mind if `base` ever comes from
  somewhere else.

## Other observations (no report)

- **`chain_digest_over` drifted from its pin, without changing behaviour.**
  `src/eval/journal/digests.ail:183` pins `chain_digest_over`'s body at commit A as
  `List.foldl(chain_step, base, ms)` (sha256 `3198f8c1…`, which I reproduced from that text).
  The snapshot folds `chain_digest_after` directly (`3e845a61…`). `chain_step` is now dead code.
  The two are equal (`chainStep_eq`, and the differential test), so this is not a defect. The
  evaluator's P1.4b tool will report the drift, as its design says it should. The other four
  pinned functions in the span (`chain_digest_base`, `chain_digest_after`, `chain_step`,
  `chain_empty_base`) are byte-identical to their pins.
- **Long histories.** Over 1,000, 4,000 and 16,000 messages, the real `chain_digest_over` and
  `chain_digests_over` match the model exactly (`diff/run_scale.sh`), with no stack failure. The
  `acc.out ++ [d]` append in `chain_prefix_step` showed no visible quadratic cost at these
  sizes. The wall times are dominated by AILANG start-up and vary from run to run, so I make no
  performance claim.

## Step (2): how many times the differential test changed the model

**Zero.** The first comparison of the model with the real code matched on all 1,820 lines, and
every later run matched too. The edits I did make were not step-(2) fixes:

- Before the first comparison, two compile errors: a `DecidableEq` derive that Lean cannot do
  for the nested `Json` type, and a lemma name that does not exist in core (`List.map_injective_iff`).
  Both were fixed in the proof, not in the modelled behaviour.
- Afterwards, a refactor: phase_vocab's frame moved from `Enumerate.lean.tail` into
  `FrameModel.lean` so X-2 could be stated against it. The re-run produced the same output.

A model that agrees the first time could also mean the test has no power. So the test carries
a **negative control** (039's practice): four mutants of the model, applied one at a time, must
each disagree with the real code. All four did:

| Mutant of the model | Lines that mismatch (of 1,820) |
|---|---|
| `chain_digests_over` starts from `base` (the fix) | 1,290 |
| `frame ++ previous` instead of `previous ++ frame` | 1,555 |
| `d :: out` instead of `out ++ [d]` | 1,512 |
| frame length prefix in UTF-8 bytes instead of runes | 1,220 |

The fix-mutant mismatches on exactly the 5 × 258 (non-empty-history base, non-empty list)
cases. That alone shows the real function ignores every base it was given except
`chain_empty_base()`.

What the test covered: every message list of length 0 to 3 over six messages, against six bases,
for 1,554 cases. The six messages cover all four roles, tool calls with empty and multi-byte
fields, two images, a newline, `;` and frame-like content. The six bases are
`chain_empty_base()`, `""`, `"x"`, a digest-shaped string, a real chain value and `"é"`. Each
case compares `chain_digest_over`, the whole `chain_digests_over` list, its length and
`encode(chain_digests_json(...))`. The test also compares `chain_empty_base()`, six single
`chain_digest_after` steps and 259 `chain_digest_base` values, plus the three long inputs above.
The model's hash is an executable SHA-256 written in Lean (`Sha256.lean`, checked against the
FIPS 180-4 vector), so the test compares actual digest strings.

## What is proved

The theorems are in `lean/ChainModel.lean`. 32 theorems, all kernel-checked, with no `sorry` and
no `native_decide`. `FrameModel.lean` adds three more. The axiom report is in `axioms.txt`:
nothing beyond `propext`, `Quot.sound` and `Classical.choice`, with no `sorryAx` and no
`Lean.ofReduceBool`. The `Classical.choice` comes from `simpa` in the two string-cancellation
lemmas and in what uses them.

`sha256Hex`, the message frame and the per-message canonical form are fields of `Env`, so every
theorem holds for every frame and every hash. The `bug_` theorems also assume `Env.h` is
injective, which is the target's stated treatment of `sha256Hex`, and nothing else.

| Theorem | Statement |
|---|---|
| `P4_2_length` | P4.2's length half, for the code as written: `length(chain_digests_over(b, ms)) = length(ms)` |
| `P4_2_last_at_empty_base` | P4.2's last-element half holds at `chain_empty_base()` |
| `bug_P4_1` | For every base `b` and messages `x`, `y`: `chain_digests_over(b, [x] ++ [y]) ≠ chain_digests_over(b, [x]) ++ chain_digests_over(chain_digest_over(b, [x]), [y])` |
| `bug_P4_1_at_empty_base` | The same at `b = chain_empty_base()` |
| `bug_P4_2` | At `b = ""` and any `m`, the last element of `chain_digests_over(b, [m])` is not `chain_digest_over(b, [m])` |
| `bug_P4_2_last_ne` | The same for every `b ≠ chain_empty_base()` |
| `real_eq_prefix_from_empty`, `real_ignores_base` | The code as written returns the prefix chain from `chain_empty_base()`, whatever `base` is |
| `real_eq_fixed_at_empty_base` | At `chain_empty_base()`, the code as written equals the fix (the reachability theorem) |
| `weak_prefix_holds` | RESEARCH §5.B's "begins with" statement holds even of the defective code |
| `P4_1_fixed`, `P4_2_fixed` | Both properties, in full, for every base, for the fix |
| `chainStep_eq`, `chainDigestOver_append` | `chain_step = chain_digest_after`; `chain_digest_over` splits over `++` |
| `chainDigestsJson_inj` | `chain_digests_json` keeps every digest, in order |
| `fold_prefix` and lemmas | The fold invariant behind all of the above |
| `witness_bug_P4_1`, `witness_bug_P4_2`, `idEnv_injective`, `witness_nonempty` | Non-vacuity: an injective hash exists, and every hypothesis above is satisfiable |
| `obs_X2_after_collides` (FrameModel) | X-2, for every hash |

A second check against vacuity, as RESEARCH §4 suggests, comes from the theorems' own structure:
the full P4.1 and P4.2 statements are proved of the fixed model (`P4_1_fixed`, `P4_2_fixed`) and
refuted of the model as written (`bug_P4_1`, `bug_P4_2`), so neither statement holds of
everything.

## What I could not do, and the limits

- **The transcription gap stays open.** The differential test is evidence on the inputs tried,
  not proof that the model is the code. In particular, AILANG's `List.foldl` argument order and
  list `++` are confirmed only by the test. So is the rune-counted frame length (the
  bytes-not-runes mutant shows the test can see it).
- **Strings that are not valid UTF-8 are out of reach.** Lean strings are always valid UTF-8 and
  AILANG's need not be (RESEARCH §7), so the model cannot represent them and the test does not
  include them.
- **`digest_content`'s `make[N]` normalisation is not modelled.** The alphabet avoids `make[`,
  so `chain_digest_base` is tested only on content it leaves unchanged. It is not part of
  P4.1 or P4.2.
- **The JSON encoder is modelled only on strings that need no escaping**, which digests never
  do.
- **Reachability is by reading** (the call sites above). I did not trace whether the TypeScript
  host could ever request digests from another base.

## Rule compliance

The real code was executed only for step (2) (`diff/enumerate_chain.ail`,
`diff/scale_chain.ail`) and step (4) (`repro/*.ail`, and `repro/check_on_fixed_copy.sh`, which
runs the repros on a patched copy to check that they exit 0 without the defect). The tree was
not modified: `diff/ail_run.sh` runs each harness from a throwaway root whose `src/`, `packages/`
and `ailang.toml` are symlinks to the tree's, created under `runs/` and removed afterwards. No
`git` was run.

Departures from "do not read outside the two directories":

- I listed `~/.elan/toolchains` once, to find the Lean 4.28.0 binary. The Lean and `ailang`
  binaries were executed from their install locations.
- Early on, I wrote intermediate outputs to the session scratchpad and read them back. All of
  those files were mine. After the harness denied two reads there, everything moved under
  `runs/`, and the recorded runs below use only `out/`.

## Files

| Path | What it is |
|---|---|
| `reports.tsv` | The three reports |
| `axioms.txt` | Axiom report: `#print axioms` for every theorem, written by `lean/check.sh` |
| `lean/ChainModel.lean` | The model of `journal.ail:242-300` and `:322-324`, all T4 theorems, `#print axioms` |
| `lean/FrameModel.lean` | phase_vocab's frame (`Env.frame` for the test), and X-2 |
| `lean/Sha256.lean` | Executable SHA-256, for the differential test only |
| `lean/Enumerate.lean.tail`, `lean/Scale.lean.tail` | The model's half of the differential test |
| `lean/check.sh` | Kernel-checks the models and writes `axioms.txt` |
| `diff/enumerate_chain.ail`, `diff/scale_chain.ail` | The real code's half of the differential test |
| `diff/run_diff.sh` | Model against real code over 1,820 lines, plus the four mutants |
| `diff/run_scale.sh` | Model against real code on 1,000, 4,000 and 16,000 messages |
| `diff/ail_run.sh` | Runs an AILANG harness from `out/` against the tree's unmodified code |
| `diff/count_p42.awk` | P4.2, read directly off the real code's output, per base |
| `repro/p4_1.{ail,sh}`, `repro/p4_2.{ail,sh}` | Reproductions for B2-T4-1 and B2-T4-2 |
| `repro/x1.{ail,sh}`, `repro/x2.{ail,sh}` | X-1 (reported) and X-2 (observation) |
| `repro/check_on_fixed_copy.sh` | The repros exit 0 on a copy with the fix |
| `run_all.sh` | Everything above, from the tree root; log in `runs/run_all.log` |
| `runs/` | Outputs of the recorded run |

To re-run, from the tree root with `lean` 4.28.0 and `ailang` v0.54.14 on `PATH`:
`bash /home/motoko/trial-043/s/t043-t4-b2/out/run_all.sh`.

## The recorded run

2026-11-04, from the tree root, `run_all.sh` (full log: `runs/run_all.log`). Lean 4.28.0 and
ailang v0.54.14, linux aarch64.

| Check | Result |
|---|---|
| `lean/check.sh` | Both files check. 35 theorems (32 + 3), no `sorryAx`, no `Lean.ofReduceBool`. Exit 0 |
| `diff/run_diff.sh` | Model and real code agree on 1,820 lines, 0 mismatches (both outputs sha256 `b9849c4b6e27294f…`, identical before and after the FrameModel refactor). Mutants: 1,290 / 1,555 / 1,512 / 1,220 mismatching lines. Exit 0 |
| `diff/count_p42.awk` (real output) | Last-element half of P4.2 fails on 258 of 258 non-empty lists at each of bases 1-5 and on 0 of 258 at `chain_empty_base()`. 0 length mismatches in 1,554 cases |
| `diff/run_scale.sh` | 1,000, 4,000 and 16,000 messages: 6 lines, 0 mismatches. Wall times 8.8-18.6 s per real run, with no trend in n (start-up dominated) |
| `repro/p4_1.sh` | `P4.1 VIOLATED`, exit 1 |
| `repro/p4_2.sh` | `P4.2 VIOLATED`, exit 1 |
| `repro/x1.sh` | Values differ and the comment is present, exit 1 |
| `repro/x2.sh` | Collision, exit 1 (observation) |
| `repro/check_on_fixed_copy.sh` | p4_1 and p4_2: exit 1 on the tree, exit 0 on the fixed copy. Exit 0 |

Each repro takes about 5-20 s, within the 120 s bound.
