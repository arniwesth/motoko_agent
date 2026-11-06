# T1: the herdr environment gate, by Kiro's method

Target: `readHerdrEnvironment` (`src/tui/src/herdr-agent-state.ts:157-166`) and `herdr_env_ready`
(`packages/motoko-ext-herdr/types.ail:1425-1433`), the MOT-118 twins. Lean 4.28.0, core only,
no Mathlib, no Lake. Real code run with bun 1.4.4 and AILANG v0.54.14 (`e1ef33f`), only for
step (2), the differential test, and step (4), reproduction. The tree was not modified.
Report ids use arm and replicate `B2`, read from the snapshot's path (`t043-t1-b2`).

## Result

**P1.1 is false, and the model proves exactly where.** It fails in two families, one per side,
and in no others (`disagree_iff`). Both reproduce on the real, unmodified code. Following the
variables along the real path from pane to runtime adds two more disagreements (X-1, X-2), both
also reproduced.

| Report | Property | Witness | TS gate | AILANG gate | Theorem |
|---|---|---|---|---|---|
| B2-T1-1 | P1.1 | `HERDR_ENV=2`, bin and pane set | `null` | `true` | `bug_P1_1_env_two` |
| B2-T1-2 | P1.1 | `HERDR_ENV=1`, `HERDR_BIN_PATH=""`, pane set | `{paneId, bin: ""}` | `false` | `bug_P1_1_empty_bin` |
| B2-T1-3 | X-1 | `HERDR_ENV=1`, pane set, `HERDR_BIN_PATH` unset, end to end | `null` | tools advertised, `bin=herdr` | `bug_X1_bin_unset`, `register_gate_ignores_bin` |
| B2-T1-4 | X-2 | `HERDR_ENV=1`, bin set, `HERDR_PANE_ID=" "`, end to end | `{paneId: " ", …}` | no tools | `bug_X2_blank_pane` |

How each was first seen: all four by **reading**, before any proof or run. B2-T1-1 is
`herdr_env >= "1"` (a string order, not equality). B2-T1-2 is `bin === undefined` (it lets
`""` through), which contradicts the function's own comment, "a pane id with no binary cannot
report". X-1 is `getEnvOr("HERDR_BIN_PATH", "herdr")` in the gate's only caller. X-2 is the
`value.trim() !== ""` filter in `buildChildEnv`. The model then turned each into a kernel-checked
statement, and `disagree_iff` showed there are no others at the function level.

### Exploratory properties

- **X-1.** In the running system (the variables taken from the pane environment, passed
  through `buildChildEnv` to the AILANG runtime, and read by `register_with_config`), the TS gate
  is open iff the runtime's gate is open. This is P1.1 with the real caller's input mapping in
  place of "unset ↦ `""`". It fails on `HERDR_BIN_PATH` unset, because of the default `"herdr"`.
  `register_gate_ignores_bin` proves the general form: for anything `buildChildEnv` can forward,
  the bin-path conjunct of `herdr_env_ready` is never false. So in the running system the AILANG
  rule tests two variables, not the three both comments require, and when the variable is absent
  it falls back to a PATH lookup, which `register.ail:46-48` says it avoids.
- **X-2.** Same statement, failing on a blank pane id. The two functions agree on `" "` (both
  accept it), but the allowlist between them drops it. That allowlist is the one the intent
  comment names as "what stands between the two copies" (`herdr-agent-state.ts:152-156`).

X-1 and X-2 sit outside the two named functions. They are reported because the intent ("THEY
MUST MOVE TOGETHER") is about what the two copies decide in the running system, and they are
the path that comment points at.

### Reachability (step 6/7, by reading and by the chain repro)

- **B2-T1-1** is reachable end to end. `buildChildEnv` forwards `HERDR_ENV=2`, and the real
  `register_with_config` advertises `Delegate`/`DelegateCheck` while the host stays invisible to
  herdr (`chain_check.sh 2 /usr/local/bin/herdr w1:p7` exits 1). herdr itself injects `1`, so
  this needs some other writer of `HERDR_ENV`.
- **B2-T1-2** is real at the function level, and **masked end to end rather than absent**.
  `buildChildEnv` drops the empty value and `register.ail:49` defaults it to `"herdr"`, so both
  gates open (`chain_check.sh 1 '' w1:p7` exits 0), but with different binaries. On the host,
  `initHerdrReporter` returns `true`, and every report then calls `spawn("")`. That throws "The
  argument 'file' cannot be empty", and `fire`'s catch swallows it. Motoko believes it reports
  and herdr never sees it (`repro/b_consequence.ts`).
- **B2-T1-3** happens whenever `HERDR_ENV` and `HERDR_PANE_ID` are present and `HERDR_BIN_PATH`
  is not: a herdr that does not inject it, a hand-set environment, or the runtime started outside
  the TUI.
- **B2-T1-4**: herdr does not inject a blank pane id. Low.

## What was proved

All in `HerdrGateModel.lean`, 17 theorems, every one `#print axioms`-ed (`axioms.txt`). None
uses `sorry`, `sorryAx` or `native_decide`; `lean` exits 0 with no errors. Axioms used:
`propext`, `Quot.sound`, and `Classical.choice`. `Classical.choice` comes from core's
`String.decLE`, the decision procedure behind `≤` on `String` that the model's `strGe` uses. It
appears in that *definition*, not in any proof step: a two-line check shows `def f a b :=
decide (b ≤ a)` already depends on it.

| Theorem | Statement |
|---|---|
| `ail_inline_tests`, `ts_unit_tests` | The model passes `herdr_env_ready`'s five inline tests and `herdr-agent-state.test.ts`'s seven expectations. Neither suite contains a witness. |
| `tsOpen_iff`, `ailOpen_iff`, `truthy_iff` | Each side in closed form |
| `bug_P1_1_env_two` | Witness A: TS `none`, AILANG `true` |
| `bug_P1_1_empty_bin` | Witness B: TS `some ⟨"w1:p7", ""⟩`, AILANG `false` |
| `bug_P1_1` | `¬ P1_1`, where `P1_1 := ∀ env, tsOpen env = ailOpen env` |
| `disagree_iff` | **Every** disagreement: they differ iff the pane id is non-empty and either (A) `HERDR_ENV ≠ "1"`, `"1" ≤ HERDR_ENV` and the bin path is non-empty, or (B) `HERDR_ENV = "1"` and `HERDR_BIN_PATH = some ""` |
| `agree_off_the_witnesses` (+ `_not_vacuous`) | Outside A and B they agree. Both outcomes are witnessed. |
| `fixed_agree` | With `herdr_env == "1"` and `!paneId \|\| !bin`, the two sides are equal on **every** input: P1.1 holds for the fix |
| `fixed_ail_keeps_agreed` | The fix changes the AILANG side only on inputs where the sides disagreed |
| `fixed_passes_both_suites` | The fixed sides still pass both existing test suites |
| `bug_X1_bin_unset`, `register_gate_ignores_bin` | X-1, the witness and the general form (for any `blank`, with no hypothesis) |
| `bug_X2_blank_pane` | X-2, for any `blank` that counts `" "` as blank |

The people-facing statement is `P1_1` (`HerdrGateModel.lean`, "P1.1 is false"). It is the
registered property word for word: unset is `none` on the TS side and `orEmpty none = ""` on
the AILANG side.

## Step (2): the differential test, and how many times it changed the model

**Step (2) changed the model 0 times.** On its first run, the model as written matched both real
functions on every input:

| Run | Inputs | Mismatches |
|---|---|---|
| model `readHerdrEnvironment` vs real (bun), returned fields included | 226,981 triples | 0 |
| model `herdr_env_ready` vs real (ailang) | 226,981 triples | 0 |
| chain model `forwardEnv jsBlank` + TS gate vs real `buildChildEnv` + `readHerdrEnvironment` | 226,981 triples | 0 |
| chain model `registerGate` vs real `register_with_config` | 240 sampled forwarded triples (one `ailang run` each) | 0 |

The inputs are every triple of (unset, then 60 values) per variable: 61³ = 226,981. The 60
values are 45 fixed boundary values and 15 seeded random strings (`diff/gen_inputs.py`, seed
43). The fixed values are around `"1"`: `"0"`, `"2"`, `"10"`, `"01"`, `"1 "`, `" 1"`, `"1\n"`,
`"+1"`, `"true"`, letters, `~`, `/`. Around `""`: space, tab, newline, NBSP, U+3000. Non-ASCII,
where Lean's code-point order and Go's byte order could part: `é`, `日本`, `🙂`, U+FF11. Real
code on the same inputs: P1.1 fails on 139,299 triples (139,240 family A, 59 family B), exactly
the set `disagree_iff` predicts, since both model halves match. On the chain, over the 1,024
triples whose forwarded triple was sampled, the real host gate and the real runtime gate disagree
on 605 (598 runtime-only, the X-1 and family-A shapes; 7 TS-only, the X-2 shape: a pane id of
`" "`, `"  "` or a tab). Logs: `diff/run_seed43.log` and `diff/run_chain_seed43.log`, both
exit 0.

**Negative control** (`run_diff.sh --mutants`), so that 0 mismatches means something. One
behaviour was planted on the real-code side of each half, in a copy. TS `bin === undefined →
!bin` gave 59 mismatches. AILANG `>= "1" → == "1"` gave 139,240 mismatches. Both were caught.
Separately, `repro/control_fixed.sh` checks that each repro command exits 1 on the real tree and
0 on a copy with the candidate fix. All four do.

Things that did change, none of them the model: two proof scripts (tactic fixes before the
first check passed), an unused hypothesis dropped from `register_gate_ignores_bin` (it turned
out not to need one), and a harness bug in `run_diff.sh` (`head` under `pipefail` exited 141
after a run that had already reported 0 mismatches).

## What I could not do, and the limits

- **The transcription gap stays open.** Zero mismatches on 226,981 inputs is evidence that the
  model matches the code on those inputs, not proof. The functions are small enough that I
  believe the match. It is still a test.
- **String order.** AILANG `>=` is Go's byte-wise order, and the model uses Lean's code-point
  order. They coincide on valid UTF-8, and the non-ASCII values in the alphabet checked that.
  Strings that are not valid UTF-8 are outside Lean's `String`, so the model says nothing about
  them. Environment variables can hold such bytes, and the TS side would see them after Node's
  decoding, which is a different string again. Not explored.
- **`blank` is abstract** in the theorems. Only the differential test instantiates it, as
  ECMA-262's `trim` whitespace set (`jsBlank`). The X-2 theorem assumes only `blank " "`.
- **The chain runtime half is sampled**, not exhaustive. `register_with_config` reads its
  environment, so each input costs one `ailang run`.
- **Intent is a person's call** for the fixes. For B2-T1-1 and B2-T1-2 both comments state the
  rule ("exactly 1", "all three required"), so the fix is clear. X-1 has two possible repairs:
  default `""` in `register.ail:49`, or keep the PATH fallback and say so in both comments. X-2
  also has two: forward the gate variables verbatim, or have both gates treat a blank value as
  unset. Which is meant is a decision, not a proof.

## Files

- `HerdrGateModel.lean`: the model (header names files and lines), the theorems and
  `#print axioms`.
- `axioms.txt`: the axiom report, from `lean HerdrGateModel.lean` (exit 0).
- `reports.tsv`: the four reports.
- `diff/`: step (2).
  - `run_diff.sh [--mutants] [seed] [scratch]` (exit 0 = no mismatch), with `gen_inputs.py`
    (generates `alphabet.json`, `enumerate.lean.tail`, `enumerate_chain.lean.tail` and
    `enumerate_gate.ail`) and `enumerate.ts`.
  - `run_chain.sh [seed] [n] [scratch]`, with `enumerate_chain.ts` and
    `chain_ail_sample.py`.
  - `ailang.toml`/`ailang.lock` resolve `pkg/sunholo/motoko_ext_herdr` to the tree.
  - `run_seed43.log` and `run_chain_seed43.log` are the recorded runs; `run_seed43/` and
    `chain_seed43/` hold their raw outputs, gzipped (`diff/README.md` lists them).
- `repro/`: step (4).
  - `p11_check.sh E B P` (with `gate_ts.ts` and `gate_ail.ail`): the two functions on one input.
  - `chain_check.sh E B P` (with `chain_ts.ts` and `register_ail.ail`): the real pane → host →
    `buildChildEnv` → `register_with_config` path.
  - `b_consequence.ts`: what witness B does downstream.
  - `control_fixed.sh`: the fixed-copy control.
  - Arguments are values or `UNSET`. Run from the tree root; exit 1 = defect present.
