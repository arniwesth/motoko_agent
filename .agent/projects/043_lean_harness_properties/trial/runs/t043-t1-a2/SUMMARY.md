# T1: the herdr environment gate (MOT-118), arm A replicate 2

Target: `readHerdrEnvironment` (`src/tui/src/herdr-agent-state.ts:157`) and `herdr_env_ready`
(`packages/motoko-ext-herdr/types.ail:1425`), with their real call sites:
`initHerdrReporter` → `readHerdrEnvironment(process.env)` (TS), `register_with_config`
(`packages/motoko-ext-herdr/register.ail:43`), and `buildChildEnv`
(`src/tui/src/runtime-process.ts:499`). The intent comment (`herdr-agent-state.ts:145`) says the
two gates "MUST MOVE TOGETHER" and calls `buildChildEnv`'s allowlist "what stands between the
two copies".

Method: executed checks only. Every check calls the real functions: bun imports the real
TypeScript module, and AILANG imports the real package through a scratch package whose
`ailang.toml` points at the tree's `packages/` by absolute path. No model of either function
was written. Toolchain: bun 1.4.4 and ailang v0.54.14 (`e1ef33f`).

No source file in the tree was modified. One side effect did happen and has been undone. The
real `buildChildEnv` creates `<workdir>/.motoko/exit` (`exitManifestPathFor`,
`runtime-process.ts:488`). The early call-site runs passed the tree root as the workdir, so they
created the empty directory `.motoko/exit` in the tree. I removed it, and `ts_side.ts` now passes
a throwaway workdir instead; the workdir does not affect the `HERDR_*` entries. After that
change, the full X-1/X-2 grid gave the same counts, and a timestamp check found no file in the
tree newer than the run.

## Results

Four defects are reported in `reports.tsv`. Two violate P1.1 directly. Two violate exploratory
properties at the real call sites.

| Report | Property | Defect | Witness |
|---|---|---|---|
| A2-T1-1 | P1.1 | `herdr_env >= "1"` in AILANG vs `=== "1"` in TS | `HERDR_ENV="2"` (also `"10"`, `"1 "`, `"true"`) |
| A2-T1-2 | P1.1 | TS rejects the binary only when `undefined`, so `""` passes | `HERDR_BIN_PATH=""` |
| A2-T1-3 | X-1 | `register.ail` defaults an unset `HERDR_BIN_PATH` to `"herdr"`, so the AILANG gate opens without it | `HERDR_BIN_PATH` unset |
| A2-T1-4 | X-2 | `buildChildEnv` drops whitespace-only `HERDR_*` values, so a pane id the TS gate accepts never reaches the runtime | `HERDR_PANE_ID=" "` |

All four were first seen by reading the code and then confirmed by execution, so `route` is
`reading` for each. The generators found no disagreement outside these classes: class `OTHER`
was 0 in every run on the unmodified tree.

## Properties

- **P1.1** (registered). For each of `HERDR_ENV`, `HERDR_BIN_PATH` and `HERDR_PANE_ID`, either
  unset or any string, with unset passed to AILANG as `""`:
  `readHerdrEnvironment(env) !== null` ⇔ `herdr_env_ready(e, b, p)`. Executable statement:
  `p11/compare_gate.ts`.
- **X-1** (exploratory: the twins at their real call sites). For every real process environment
  E, where each of the three variables is unset or a string:
  `readHerdrEnvironment(E) !== null`, which is what `initHerdrReporter` decides, ⇔
  `register_with_config()`, run under E with `std/env`, advertises a non-empty `ToolProvider`
  list (`gate_open`, `register.ail:206-207`). This is P1.1 without the "unset → `""`"
  convention, which the real AILANG caller does not follow for `HERDR_BIN_PATH`. Executable
  statement: `callsite/run_callsite.ts --prop X-1`.
- **X-2** (exploratory: end to end through the allowlist). For every TUI process environment E:
  `readHerdrEnvironment(E) !== null` ⇔ `register_with_config()`, run under the `HERDR_*`
  entries of the real `buildChildEnv(E)` (plus `PATH` and `HOME`), advertises tools. Executable
  statement: `callsite/run_callsite.ts --prop X-2`.

## What was checked, with which generators, up to what size

### P1.1: `p11/` (pure functions, in-process)

`gen_cases.ts` writes the cases once. `gate_ts.ts` runs the real `readHerdrEnvironment` on
them, where unset means the key is absent from the env object. `gate_ail.ail` runs the real
`herdr_env_ready` on them, where unset is `""` and each string is written as an AILANG literal
with `\u{hex}` escapes. Both halves print the code-point length of every field. The comparator
fails with exit 2 if the lengths differ, which would mean the literal encoding is broken; this
happened 0 times.

| Generator | What | Cases |
|---|---|---|
| G1 | Exhaustive product V×V×V over 29 values: unset, `""`, `"1"`, near misses (`"0" "2" "10" "11" "1 " " 1" "01" "true" "yes"`), `"a" "Z" "~"`, space, tab, newline, NUL, `"1\0"`, `é`, 😀, fullwidth `１`, `"${HERDR}"`, `"` and `\`, `w1:p7`, `/usr/local/bin/herdr`, `herdr` | 24,389 |
| G2 | Every `HERDR_ENV` string of length 0 to 3 over `{0,1,2,space,a,NUL,é}` (400 strings) × `HERDR_BIN_PATH` ∈ {unset, `""`, `/b`, `" "`} × `HERDR_PANE_ID` ∈ {unset, `""`, `p`, `" "`} | 6,400 |
| G3 | Seeded random (mulberry32, default seed 118). Each variable is unset with p=1/5, otherwise a string of length 0 to 6; each character is drawn half from a hot alphabet and half uniformly from all Unicode scalar values. A quarter of the `HERDR_ENV` values start with `"1"`; half of bin/pane are the realistic values | 20,000 by default |

Default run (`bash ../out/p11/run_p11.sh`): **50,789 cases**. 29,998 agree (1,897 with both
gates open) and **20,791 disagree**:

| Class | ts / ail | Count | G1 | G2 | G3 |
|---|---|---|---|---|---|
| ENV_GT_1 (A2-T1-1) | F / T | 20,687 | 11,664 | 908 | 8,115 |
| BIN_EMPTY (A2-T1-2) | T / F | 104 | 27 | 2 | 75 |
| OTHER | | 0 | | | |

In G2, the AILANG side admits exactly the 227 of 400 strings that sort after `"1"`: those
starting with `2`, `a` or `é`, plus `"1"` followed by anything. This matches a byte-wise
lexicographic `>=`.

Larger random runs (`--random 100000 --seed 1|2|3`, 130,789 cases each):

| Seed | Agree (both open) | Disagree | ENV_GT_1 | BIN_EMPTY | OTHER | Fidelity failures |
|---|---|---|---|---|---|---|
| 1 | 77,001 (6,709) | 53,788 | 53,386 | 402 | 0 | 0 |
| 2 | 76,880 (6,471) | 53,909 | 53,500 | 409 | 0 | 0 |
| 3 | 77,025 (6,475) | 53,764 | 53,369 | 395 | 0 | 0 |

Across the four runs, P1.1 was checked on **443,156 cases** (G1 and G2 repeat in each run).
Every disagreement falls into the two reported classes.

### X-1 and X-2: `callsite/` (real process environments)

`run_callsite.ts` runs each environment in the grid in three subprocesses. Every other variable
is stripped (`PATH` and `HOME` kept), and `HERDR_ORCHESTRATOR=off` ensures no run file is read.

1. `bun ts_side.ts` runs `readHerdrEnvironment(process.env)` and the real `buildChildEnv`.
2. `ailang run register_gate.ail` runs the real `register_with_config()` under the same
   environment (DIRECT, for X-1).
3. The same AILANG program runs under the child environment that `buildChildEnv` produced (E2E,
   for X-2).

The grid is `HERDR_ENV` ∈ {unset, `""`, `"1"`, `"2"`, `"1 "`, `"true"`} × `HERDR_BIN_PATH` ∈
{unset, `""`, `" "`, `/usr/local/bin/herdr`} × `HERDR_PANE_ID` ∈ {unset, `""`, `" "`, `w1:p7`}:
**96 environments**, run 3 × 96 times. The variables cannot contain NUL in a real environment.
`--grid small` (3×3×3 = 27) keeps one witness of every class, and the repros use it.

| Unmodified tree | Disagree | Classes |
|---|---|---|
| X-1 | 22 of 96 | ENV_GT_1 18, BIN_UNSET 2 (A2-T1-3), BIN_EMPTY 2 |
| X-2 | 16 of 96 | ENV_GT_1 12, BIN_UNSET 1, PANE_DROP 3 (A2-T1-4) |

Note on X-2: `HERDR_BIN_PATH=""` is BIN_EMPTY in P1.1 and X-1, but it agrees end to end.
`buildChildEnv` drops the empty value and `register.ail` defaults it to `"herdr"`, so both
gates open. The TS reporter still spawns `""`, and every report fails silently:
`p11/bin_empty_effect.ts` executes this and shows `initHerdrReporter` returning `true` while
`spawn("")` throws `ERR_INVALID_ARG_VALUE`.

## Negative controls

Each fix is applied with `sed` to a scratch copy of `src/tui/src` and
`packages/motoko-ext-{abi,herdr}` (`mkcopy.sh`). The harness is then run with that copy as the
tree root. `bash ../out/negative_controls.sh` reproduces the whole table.

| Copy | P1.1 disagreements (50,789) | X-1 (96) | X-2 (96) |
|---|---|---|---|
| unmodified | 20,791: ENV_GT_1 20,687, BIN_EMPTY 104 | 22: ENV_GT_1 18, BIN_UNSET 2, BIN_EMPTY 2 | 16: ENV_GT_1 12, BIN_UNSET 1, PANE_DROP 3 |
| envfix: `>=` → `==` | 104: BIN_EMPTY | 4: BIN_EMPTY 2, BIN_UNSET 2 | 4: BIN_UNSET 1, PANE_DROP 3 |
| binfix: `bin === undefined` → `!bin` | 20,687: ENV_GT_1 | 20: ENV_GT_1 18, BIN_UNSET 2 | 16: ENV_GT_1 12, BIN_UNSET 2, PANE_DROP 2 |
| regfix: default `"herdr"` → `""` | (pure function unchanged) | 14: ENV_GT_1 12, BIN_EMPTY 2 | 8: ENV_GT_1 3, PANE_DROP 3, BIN_DROP 2 |
| panefix: forward a non-empty `HERDR_PANE_ID` | (unchanged) | 22 (unchanged) | 26: ENV_GT_1 24, BIN_UNSET 2 |
| allfix: all four | **0** | **0** | 2: BIN_DROP |

Each fix clears exactly its own class, and the all-fixed copy satisfies P1.1 on all 50,789 cases
and X-1 on all 96 environments. In the regfix and panefix rows, some counts in other classes
rise. That is expected: a previously masked case now reaches the AILANG side differently. For
example, in panefix the forwarded `" "` pane id now opens the AILANG gate on `HERDR_ENV="2"`.

**Residual on allfix (X-2, class BIN_DROP).** With `HERDR_BIN_PATH=" "`, the TS gate opens
(`" "` is truthy), but `buildChildEnv` does not forward the value. Once the `"herdr"` default is
gone, the AILANG gate closes. On the unmodified tree this is masked by the default, so it is not
a present violation and is not reported separately. It does show that A2-T1-4's fix should cover
all three gate variables, or both gates should normalise whitespace the same way, and that
fixing A2-T1-3 alone would expose it. The BIN_DROP class was added to the classifier after this
was first seen as `OTHER` in the controls.

Repro exit codes (each repro under each copy; expectation: 1 under unmodified, 0 under its own
fix and under allfix):

| Report | unmodified | envfix | binfix | regfix | panefix | allfix |
|---|---|---|---|---|---|---|
| A2-T1-1 | 1 | **0** | 1 | 1 | 1 | **0** |
| A2-T1-2 | 1 | 1 | **0** | 1 | 1 | **0** |
| A2-T1-3 | 1 | 1 | 1 | **0** | 1 | **0** |
| A2-T1-4 | 1 | 1 | 1 | 1 | **0** | **0** |

`negative_controls.sh` ran all 24 cells in 184 s (exit 0). On the unmodified tree, the
uncontended repros took 9 s, 9 s, 6 s and 14 s. The BIN_DROP counts in the table above come
from a re-run of the full X-2 grid on the regfix and allfix copies with the final classifier.

## Files

| File | What it is |
|---|---|
| `reports.tsv` | The four reports |
| `p11/gen_cases.ts` | Generators G1–G3. Writes `cases.json` and AILANG batches `gate_cases.<k>.ail` (≤40,000 cases each) |
| `p11/gate_ts.ts` | TS half: the real `readHerdrEnvironment` |
| `p11/gate_ail.ail` | AILANG half: the real `herdr_env_ready` |
| `p11/compare_gate.ts` | The executable statement of P1.1, with classifier and fidelity check. Exit 1 on the selected class (`--class`) |
| `p11/run_p11.sh` | Runs the above. Repro for A2-T1-1 and A2-T1-2 (~10 s at the default size) |
| `p11/bin_empty_effect.ts` | Shows what the TS reporter does with `HERDR_BIN_PATH=""` |
| `callsite/register_gate.ail` | The real `register_with_config()` under the process environment. Prints `gate=T/F tools=n` |
| `callsite/ts_side.ts` | The real `readHerdrEnvironment(process.env)` and `buildChildEnv` |
| `callsite/run_callsite.ts` | X-1 and X-2 over the grid. Repro for A2-T1-3 and A2-T1-4 (`--grid small`: 6–30 s; full grid ~40 s) |
| `mkpkg.sh` | Makes a scratch AILANG package that depends on a given tree's packages, and locks it |
| `mkcopy.sh` | Minimal tree copy for negative controls |
| `negative_controls.sh` | All repros × all fixed copies |

## Notes and limits

- **Running the repros.** Run them from the tree root. `../out` is
  `/home/motoko/trial-043/s/t043-t1-a2/out`. Each repro makes its AILANG package in
  `$(mktemp -d)` and removes it afterwards. Exit code 2 means "no verdict" (a half failed to run
  or a fidelity check failed); it is never used for "absent".
- **Timing.** AILANG caches compiled modules per package in `.ailang/`. A cold compile of the
  call-site program takes about 4 s, so `run_callsite.ts` warms the cache with one run before
  its 8 parallel workers start. Without the warm-up, the full grid took about 100 s instead of
  about 40 s.
- **Session environment.** The session these checks ran in is itself inside a herdr pane
  (`HERDR_ENV=1` etc. are set). Every harness builds its environments from scratch, so the
  results do not depend on that.
- **Inline tests.** Read, not executed: the five inline tests of `herdr_env_ready` and the TS
  tests in `herdr-agent-state.test.ts` contain no value that separates the twins. They have no
  `HERDR_ENV` sorting above `"1"`, and the TS tests have no `HERDR_BIN_PATH=""`. That is why
  both defects pass the existing suites.
- **Not checked.** herdr's own behaviour with a blank pane id or binary. The callers of
  `buildChildEnv` beyond the function itself. Values containing NUL at the call sites, because
  a process environment cannot carry them; P1.1's pure check does cover them.
