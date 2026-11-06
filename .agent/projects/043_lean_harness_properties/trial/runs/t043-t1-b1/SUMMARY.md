# T1: the herdr environment gate (MOT-118). Summary

Arm/replicate **B1**, target **T1**. Snapshot: `/home/motoko/trial-043/s/t043-t1-b1/tree`, unchanged
(nothing in the tree was written, and `git` was not run). Method: Kiro's, as
`.agent/projects/043_lean_harness_properties/RESEARCH-lean-harness-properties.md` §1 describes it.
Toolchain: Lean 4.28.0 (`7e01a1bf5c70`, core only, no Mathlib, no Lake), bun 1.4.4, ailang v0.54.14
(`e1ef33f`).

## Result in one paragraph

**P1.1 is false on the real code, and I did not prove it. I proved that it is false.** The two copies
disagree on two classes of input, and Lean characterises both exactly (`disagree_iff`):

1. **`herdr_env_ready` uses `>=`, not `==`** (`types.ail:1433`). Any HERDR_ENV other than `"1"` whose
   first code point is at least `'1'` opens the AILANG gate and leaves the TypeScript gate null. Examples
   are `"2"`, `"10"`, `"1 "`, `"true"`, `"a"` and `"é"`.
2. **`readHerdrEnvironment` tests `bin === undefined`, not `!bin`** (`herdr-agent-state.ts:164`). An
   empty HERDR_BIN_PATH opens the TypeScript gate with `bin: ""` and leaves the AILANG gate closed.

On the real code, run directly with no model in between, 24,310 of the 46,656 generated triples
disagree: 24,276 in class 1 and 34 in class 2. Nothing outside those two classes disagrees.

I also took an exploratory property, **X-1**: P1.1 along the path the code really uses between the
copies, where the TUI's `process.env` goes through `buildChildEnv` to `register_with_config`. It is
false in two more ways:

- `register.ail:49` defaults an unset HERDR_BIN_PATH to `"herdr"`. As the runtime actually calls it,
  the AILANG gate therefore never depends on HERDR_BIN_PATH, and this is proved for every input.
- A whitespace-only HERDR_PANE_ID is truthy to the TypeScript copy but `buildChildEnv` drops it.

All four findings are reproduced by scripts on the unmodified code. None of them was first seen by
a proof. I saw all four by reading the code before modelling it, so every report's `route` is
`reading`. The proofs and the differential tests confirm them and measure them.

**The model needed no changes at step (2).** The first differential run matched the real code with 0
mismatches, for both the pure functions and the end-to-end model. See "How many times step (2)
changed the model" below.

## Properties

- **P1.1** (registered, primary). Each of `HERDR_ENV`, `HERDR_BIN_PATH` and `HERDR_PANE_ID` is unset or
  any string, and an unset one goes to the AILANG side as `""`. For every such value, the TypeScript
  gate is non-null iff `herdr_env_ready` is true. Lean: `P1_1`.
- **X-1** (exploratory). The TUI's `process.env` has each of the three variables unset or any string.
  For every such environment, `readHerdrEnvironment(process.env)` is non-null iff `register_with_config`
  advertises tools when the runtime is given the environment `buildChildEnv` builds
  (`runtime-process.ts:629-633`, forwarding a `HERDR_*` only when `value && value.trim() !== ""`).
  `register_with_config` reads the variables with `getEnvOr` and the defaults at
  `register.ail:45-50`, and decides at `:206`. This is the boundary that the intent comment at
  `herdr-agent-state.ts:150-155` names as "what stands between the two copies". Lean: `X_1`.

## Files

| Path | What |
|---|---|
| `HerdrGateModel.lean` | Steps (1) and (3). The model, with a header naming the source files and lines. Section 1 is `readHerdrEnvironment`, section 2 is `herdr_env_ready`, section 3 is P1.1, its counterexamples, the exact disagreement set and the fix. Section 4 is the end-to-end path (`forwarded`, `getEnvOr`, `registerGate`), X-1 and its fix. It ends with the `#print axioms` block |
| `axioms.txt` | The axiom report, the output of the `#print axioms` block, for all 23 theorems |
| `diff/run_diff.sh` | Step (2) for sections 1 and 2: the model against the real `readHerdrEnvironment` (bun) and the real `herdr_env_ready` (ailang) over 46,656 triples. It also checks P1.1 directly on the two real functions. `--control` runs the negative control |
| `diff/gen_alphabet.py` | Writes the 36-value alphabet: index 0 is unset, then 28 boundary strings and 7 seeded random strings. It writes the alphabet into each of the three halves (`alphabet.lean`, `alphabet.json`, `alphabet.ail`) |
| `diff/enumerate.lean.tail`, `diff/enumerate.ts`, `diff/enumerate_gate.ail(.head)` | The three halves of `run_diff.sh` |
| `diff/ailang.toml`, `diff/ailang.lock` | A throw-away package that imports the tree's `motoko-ext-herdr` by path, unchanged. Without it, a file outside the tree cannot import `pkg/sunholo/motoko_ext_herdr/*` |
| `diff/run_e2e.sh`, `diff/enumerate_e2e.ts`, `diff/enumerate_e2e.lean.tail`, `diff/register_gate.ail` | Step (2) for section 4: the real `readHerdrEnvironment`, the real `buildChildEnv` and the real `register_with_config` (one `ailang run` per environment) over 512 TUI environments, with every ambient `HERDR_*` removed |
| `repro/repro_p11.sh` | Step (4) for P1.1. One input goes to both real copies. Exits 1 if they disagree, 0 if they agree |
| `repro/repro_x1.sh` | Step (4) for X-1. One TUI environment goes through the real path. Exits 1 if the copies disagree, 0 if they agree |
| `runs/run_all.sh` | The recorded final run, with logs in `runs/*.log`, the real-vs-real P1.1 breakdown in `runs/p11_real_vs_real.txt`, the output hashes in `runs/outputs.sha256`, and the gzipped outputs |
| `reports.tsv` | The four reports |

To run everything: `PATH=<lean 4.28.0 bin>:$PATH out/runs/run_all.sh`, where `out` is
`/home/motoko/trial-043/s/t043-t1-b1/out`. Each repro is run from the tree root as `reports.tsv` gives
it, and takes 1–3 s (P1.1) or about 10–15 s (X-1). Nearly all of the X-1 time is `ailang lock` and the
type check of the herdr package.

## Step (1): the model

`HerdrGateModel.lean` follows each source statement for statement. The modelling choices that matter
are below; the header lists them all.

- **Strings are `List Char`.** In Lean 4.28 `String` is byte-backed, and its `toList` and `<` reduce
  in the kernel only through `Classical.choice`. A `List Char` keeps every concrete counterexample
  decidable by `decide`, with `propext` as the only axiom.
- **An unset variable is `none`.** P1.1's "unset is passed as `""`" is `Option.getD []`.
- **AILANG `>=` on strings is lexicographic on code points** (`strLt` and `strGe`). This is the
  order that Go's byte-wise comparison gives on valid UTF-8. It was an assumption, and step (2)
  checked it. Mutant M3 below shows the test can tell this order from a length-first one.
- **JS `!x`** is `falsy`. **JS `trim()`** is the ECMA-262 WhiteSpace ∪ LineTerminator set
  (`jsSpace`), and it is used only in section 4.

## Step (2): differential testing, and how many times it changed the model

**Step (2) changed the model 0 times.**

| Run | Inputs | Model vs real `readHerdrEnvironment` | Model vs real `herdr_env_ready` / `register_with_config` |
|---|---|---|---|
| `run_diff.sh` (first run, and the recorded run) | 46,656 triples (36³) | 0 mismatches | 0 mismatches |
| `run_e2e.sh` (first run, and the recorded run) | 512 TUI environments (8³), each with its real `buildChildEnv` output and one real `ailang run` | 0 mismatches (the TS field, and the forwarded value of each variable) | 0 mismatches |

One change to the model came **before** step (2), and it is not counted above. The first draft of
`strLt` compared `Char.val` (a `UInt32`), and `omega` cannot reason about that, so I changed it to
`Char.toNat`. That is the same order, and the change was made for the proof, not because of a
mismatch.

**Negative control (`run_diff.sh --control`).** The control mutates copies of the model, never the
real code, because I could not modify the tree. Each mutant has to produce mismatches against the
real code, or the test cannot see that kind of change:

| Mutant of the model | Mismatches |
|---|---|
| M1: `herdr_env == "1"` in place of `>=` (the AILANG fix) | 24,276 on the AILANG side |
| M2: `!bin` in place of `bin === undefined` (the TS fix) | 34 on the TS side |
| M3: `>=` read as length-first, then lexicographic | 6,936 on the AILANG side |

All 3 were caught.

## Step (3): what is proved

All 23 theorems check under Lean 4.28.0 with no `sorry` and no `native_decide`. The axioms each one
uses are in `axioms.txt` and in the table below. No theorem uses `sorryAx` or `Lean.ofReduceBool`.

| Theorem | Statement | Axioms |
|---|---|---|
| `model_passes_inline_tests` | The model passes the 5 inline `tests` of `herdr_env_ready` (non-vacuity) | none |
| `model_passes_ts_tests` | The model passes the cases in `herdr-agent-state.test.ts:27-43` | propext |
| `bug_P1_1_herdr_env_2` | HERDR_ENV=`"2"`: the TS gate is null and AILANG is true | propext |
| `bug_P1_1_herdr_env_more` | The same for `"10"`, `"1 "` and `"true"` | propext |
| `bug_P1_1_empty_bin` | HERDR_BIN_PATH=`""`: TS returns `{paneId, bin: ""}` and AILANG is false | propext |
| `not_P1_1` | `¬ P1_1` | propext |
| `one_toNat` | `'1'.toNat = 49` | none |
| `strGe_one_iff` | `s >= "1"` ⟺ `s` is non-empty and its first code point is ≥ 49 | propext, Quot.sound |
| `disagree_iff` | **For every input**, the copies disagree ⟺ (HERDR_ENV ≠ `"1"` ∧ HERDR_ENV ≥ `"1"` ∧ bin and pane non-empty) ∨ (HERDR_ENV = `"1"` ∧ HERDR_BIN_PATH = `""` ∧ pane non-empty) | propext, Classical.choice, Quot.sound |
| `P1_1_outside_disagreement` | P1.1 holds whenever HERDR_ENV is `"1"` or below `"1"` (unset, `""`, `"0"`, …) and HERDR_BIN_PATH ≠ `""` | propext, Classical.choice, Quot.sound |
| `fixed_P1_1` | With both fixes (`==` and `!bin`), P1.1 holds **for every input** | propext, Classical.choice, Quot.sound |
| `fixed_ts_keeps`, `fixed_ail_keeps` | Each fix leaves the copy's behaviour unchanged outside the disagreement set | propext, Classical.choice, Quot.sound |
| `bug_X_1_unset_bin` | HERDR_BIN_PATH unset: TS is null and `registerGate` is true | propext |
| `register_bin_never_empty` | As `register.ail` calls it, `bin_path` is never `""` | propext |
| `registerGate_ignores_bin` | **For every input**, the runtime's gate does not depend on HERDR_BIN_PATH | propext |
| `bug_X_1_blank_pane` | HERDR_PANE_ID=`" "`: TS is non-null and `registerGate` is false | propext |
| `bug_X_1_herdr_env_2` | Class 1 survives the real path | propext |
| `empty_bin_agrees_end_to_end` | Class 2 does **not** survive it: both gates are open (two defects cancel) | propext |
| `not_X_1` | `¬ X_1` | propext |
| `fwd_nonempty`, `fwd_one`, `fixed_X_1` | With `==`, a `""` default in `register.ail` and a blank test in TS, X-1 holds **for every input** | propext (+ Classical.choice, Quot.sound for the last two) |

The `Classical.choice` in some proofs comes from core `simp` lemmas about `≠` and `decide`. It is
not a `sorry`, and it does not widen the trusted base the way `native_decide` would. I did not spend
time removing it.

For every `bug_` theorem, the hypotheses are only concrete values, so none of them is vacuous. For the
universally quantified theorems, the inline tests give inputs that satisfy each hypothesis: for
example `["1", "/usr/local/bin/herdr", "w1:p7"]` for `P1_1_outside_disagreement`.

## Step (4): reproduction on the real code

| Report | Command (from the tree root) | Exit | Real output |
|---|---|---|---|
| B1-T1-1 | `bash ../out/repro/repro_p11.sh 2 /usr/local/bin/herdr w1:p7` | 1 | `readHerdrEnvironment -> null`, `herdr_env_ready -> true` |
| B1-T1-2 | `bash ../out/repro/repro_p11.sh 1 "" w1:p7` | 1 | `{"paneId":"w1:p7","bin":""}`, `false` |
| B1-T1-3 | `bash ../out/repro/repro_x1.sh 1 UNSET w1:p7` | 1 | TUI `null`; forwarded `{HERDR_ENV, HERDR_PANE_ID}`; tools `[Delegate,DelegateCheck]` |
| B1-T1-4 | `bash ../out/repro/repro_x1.sh 1 /usr/local/bin/herdr " "` | 1 | TUI `{"paneId":" ",…}`; forwarded without the pane; tools `[]` |
| controls | `repro_p11.sh 1 /usr/local/bin/herdr w1:p7`, `repro_p11.sh 0 …`, `repro_x1.sh 1 /usr/local/bin/herdr w1:p7`, `repro_x1.sh UNSET UNSET UNSET`, `repro_x1.sh 1 "" w1:p7` | 0 | The copies agree |

These scripts run the real functions from the tree. The AILANG side runs through a temp package that
depends on the tree's `packages/motoko-ext-herdr` by absolute path, and the TS side imports
`src/tui/src/*.ts` with bun. The X-1 script removes every ambient `HERDR_*` first, because the
session that ran it was itself inside a herdr pane. It also gives `register_with_config` exactly what
`buildChildEnv` produced, plus PATH, HOME, MOTOKO_WORKDIR and `HERDR_ORCHESTRATOR=off`, so that no
file is read. `register_with_config` runs no process.

## What I could not do, or did not do

- **P1.1 cannot be proved, because it is false.** What is proved is its negation, the exact set where
  it fails, that it holds everywhere else, and that the two one-line fixes make it hold for every input.
- **The proofs are about the model.** The differential test is evidence that the model matches the
  code, not proof. Its coverage:
  - The 36-value alphabet, crossed exhaustively in three variables. It includes `""`, `"1"`, the
    strings just below and above `"1"`, whitespace, non-ASCII on both sides of the BMP, and the
    characters each language escapes.
  - For the end-to-end model, 8 values per variable.
  - **Not tested:** strings containing NUL, which an environment cannot carry, and lone UTF-16
    surrogates, which a JS string can hold but AILANG cannot.
  - The order on code points was checked only through comparisons with `"1"`, which is all that
    `herdr_env_ready` does.
- **`getEnvOr` on a set-but-empty variable is not modelled.** On the TUI path it cannot arise, because
  `buildChildEnv` never forwards `""`. It does arise when the runtime is started directly with
  `ailang run` and a variable is set to `""`, as the Makefile's `verify_*` targets do. So the
  end-to-end statements are about the TUI path only.
- **Reachability (Kiro steps 6–7) is not shown for any finding.** herdr injects `HERDR_ENV=1` and all
  three variables, so every witness needs an environment that herdr itself does not produce: a
  different HERDR_ENV value, an empty or missing HERDR_BIN_PATH, or a blank pane id. Each is reproduced
  on the real code, but none is shown to come from a real herdr pane.
- **Some consequences were read, not executed.** For B1-T1-2, I read `fire()` but did not run it: with
  `bin: ""`, `initHerdrReporter` returns true and every report's `spawn("")` throws and is swallowed.
- **No code in the tree was mutated for the control,** because the tree is read-only for this task.
  The control mutates the model instead (M1–M3), which tests the same thing: whether the comparison
  can see a one-rule change on either side.
